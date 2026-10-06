"""Adapt local Codex rollouts to the dashboard's existing agent/timeline schema.

Rollout files are an internal format: ignore unknown records and never expose
system/developer instructions, reasoning, or sessions from other workspaces.
"""
import glob
import json
import os
import time


class CodexActivity:
    def __init__(self, root, home=None):
        self.root = os.path.realpath(root)
        self.home = home or os.environ.get("CODEX_HOME") or os.path.expanduser("~/.codex")
        self._metadata = {}
        self._lines = {}

    def catalog(self):
        found = {}
        for path in glob.glob(os.path.join(self.home, "sessions", "**", "rollout-*.jsonl"), recursive=True):
            try:
                st = os.stat(path)
                if path not in self._metadata:
                    with open(path, encoding="utf-8") as f:
                        entry = json.loads(f.readline())
                    self._metadata[path] = entry.get("payload", {}) if entry.get("type") == "session_meta" else {}
                meta = self._metadata[path]
                cwd = meta.get("cwd")
                if not cwd or os.path.commonpath([self.root, os.path.realpath(cwd)]) != self.root:
                    continue
                sid = meta.get("id") or meta.get("session_id")
                if not sid:
                    continue
                source = meta.get("source")
                spawn = ((source.get("subagent") or {}).get("thread_spawn") or {}) if isinstance(source, dict) else {}
                found[sid] = {"path": path, "meta": meta, "updated": st.st_mtime,
                              "parent": spawn.get("parent_thread_id"),
                              "type": spawn.get("agent_role") or meta.get("agent_role") or "codex"}
            except (OSError, ValueError, TypeError):
                continue
        return found

    def lines(self, path):
        try:
            st = os.stat(path)
            key = (st.st_mtime_ns, st.st_size)
            cached = self._lines.get(path)
            if cached and cached[0] == key:
                return cached[1]
            lines = []
            with open(path, encoding="utf-8", errors="replace") as f:
                for line in f:
                    try:
                        entry = json.loads(line)
                        if isinstance(entry, dict):
                            lines.append(entry)
                    except ValueError:
                        pass  # the writer may not have finished its latest record
            self._lines[path] = (key, lines)
            return lines
        except OSError:
            return []

    def timeline(self, record):
        items = []
        kind = record["type"]
        for entry in self.lines(record["path"]):
            if entry.get("type") != "response_item":
                continue
            p = entry.get("payload") or {}
            typ = p.get("type")
            item = {"from": kind, "ts": entry.get("timestamp")}
            if typ == "message" and p.get("role") in ("user", "assistant"):
                text = "\n".join(b.get("text", "") for b in p.get("content", [])
                                 if b.get("type") in ("input_text", "output_text", "text"))
                if not text.strip() or text.startswith(("<environment_context>", "# AGENTS.md instructions")):
                    continue
                user = p["role"] == "user"
                item.update(kind="prompt" if user else "report" if p.get("phase") == "final_answer" else "say",
                            text=text, **({"from": "user", "to": kind} if user else {}))
            elif typ in ("function_call", "custom_tool_call"):
                args = p.get("arguments", p.get("input", ""))
                item.update(kind="tool", name=p.get("name", "tool"),
                            text=(args if isinstance(args, str) else json.dumps(args))[:4000])
            elif typ in ("function_call_output", "custom_tool_call_output"):
                output = p.get("output", "")
                item.update(kind="result", text=(output if isinstance(output, str) else json.dumps(output))[:1500])
            else:
                continue
            items.append(item)
        return items

    def sessions(self):
        catalog = self.catalog()
        titles = {}
        try:
            with open(os.path.join(self.home, "session_index.jsonl"), encoding="utf-8") as f:
                for line in f:
                    try:
                        row = json.loads(line)
                        titles[row.get("id")] = row.get("thread_name", "")
                    except ValueError:
                        pass
        except OSError:
            pass
        records = sorted(catalog.items(), key=lambda r: r[1]["updated"], reverse=True)
        out = []
        for sid, record in records:
            if record["parent"]:
                continue
            out.append({"id": "codex-" + sid, "title": titles.get(sid) or "Codex session",
                        "source": "codex", "agents": 1 + sum(r["parent"] == sid for r in catalog.values()),
                        "updated": record["updated"]})
            if len(out) == 15:
                break
        return out

    def records(self, session):
        sid = session.removeprefix("codex-")
        catalog = self.catalog()
        if sid not in catalog or catalog[sid]["parent"]:
            return []
        return [(sid, catalog[sid])] + [(aid, r) for aid, r in catalog.items() if r["parent"] == sid]

    def agents(self, session):
        out = []
        for aid, record in self.records(session):
            items = self.timeline(record)
            prompt = next((i["text"] for i in items if i["kind"] == "prompt"), "Codex session")
            report = ""
            active = False
            finished = False
            for entry in self.lines(record["path"]):
                p = entry.get("payload") or {}
                if entry.get("type") == "event_msg":
                    if p.get("type") == "task_started":
                        active, finished, report = True, False, ""
                    elif p.get("type") == "task_complete":
                        active, finished = False, True
                        report = p.get("last_agent_message") or ""
                    elif p.get("type") == "turn_aborted":
                        active, finished = False, False
                elif entry.get("type") == "response_item" and p.get("type") == "message" \
                        and p.get("role") == "assistant" and p.get("phase") == "final_answer":
                    report = "\n".join(b.get("text", "") for b in p.get("content", []) if b.get("type") == "output_text")
                    active, finished = False, True
            status = "running" if active and time.time() - record["updated"] < 120 else "done" if finished else "stopped"
            tools = [i for i in items if i["kind"] == "tool"]
            out.append({"id": aid, "session": session, "type": record["type"], "source": "codex",
                        "description": prompt[:100], "status": status, "verdict": None,
                        "start": items[0]["ts"] if items else None, "end": items[-1]["ts"] if items else None,
                        "lastTool": f"{tools[-1]['name']}: {tools[-1]['text'][:160]}" if tools else "",
                        "steps": len(tools), "report": report[:400]})
        return out

    def agent_timeline(self, session, aid):
        record = next((r for sid, r in self.records(session) if sid == aid), None)
        if not record:
            return None
        return {"id": aid, "type": record["type"], "description": "Codex activity", "items": self.timeline(record)}

    def messages(self, session):
        items = [item for _, record in self.records(session) for item in self.timeline(record)]
        return sorted(items, key=lambda i: i["ts"] or "")
