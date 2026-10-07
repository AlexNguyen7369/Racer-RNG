#!/usr/bin/env python3
"""Claude <-> Codex bus: messages between the two agents, what each says it is working on, and what each is doing.

Works WITHOUT the dashboard server (plain files, stdlib only), so a sandboxed agent that cannot reach localhost
can still use it. The dashboard shows the same data on its Agents tab and the user can post from there.

  python3 tools/dashboard/agent_bus.py context --agent codex        what the other agent is doing + your unread messages
  python3 tools/dashboard/agent_bus.py send --from codex --to claude "text" [--re <message id>]
  python3 tools/dashboard/agent_bus.py inbox --agent claude [--all] [--keep-unread]
  python3 tools/dashboard/agent_bus.py status --agent claude --task "what I am doing" [--files a.luau,b.py] [--note ...]
  python3 tools/dashboard/agent_bus.py status --agent claude --clear
  python3 tools/dashboard/agent_bus.py hook --agent claude          (Claude Code hook: prints unread mail + the other agent's activity)

Storage (per machine, git-ignored like transcripts): .agents/messages.jsonl, .agents/status.json, .agents/cursors.json.
"""
import argparse
import contextlib
import datetime
import fcntl
import json
import os
import re
import sys
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BUS = os.path.join(ROOT, ".agents")
AGENTS = ("claude", "codex")
SENDERS = AGENTS + ("user",)
TARGETS = AGENTS + ("all",)
MAX_TEXT = 8000


def bus_dir():
    os.makedirs(BUS, exist_ok=True)
    return BUS


def now_iso():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


@contextlib.contextmanager
def locked():
    with open(os.path.join(bus_dir(), ".lock"), "w") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


def _read_json(name, default):
    try:
        with open(os.path.join(BUS, name)) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def _write_json(name, data):
    path = os.path.join(bus_dir(), name)
    tmp = f"{path}.{uuid.uuid4().hex}.tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)


# ---------------------------------------------------------------------------------------------------------------
# model labels (shared with the dashboard)


def model_label(model):
    """claude-opus-5-5 -> Opus 5.5, claude-haiku-4-5-20251001 -> Haiku 4.5; other vendors' ids stay as they are."""
    if not model or model.startswith("<"):
        return ""
    m = re.fullmatch(r"claude-([a-z]+)-(\d+)-(\d+)(?:-\d{8})?(?:\[.*\])?", model)
    if m:
        return f"{m.group(1).capitalize()} {m.group(2)}.{m.group(3)}"
    return model


def agent_of_trailer(value):
    """A commit trailer (Co-Authored-By / Agent) -> (agent, model label) or None."""
    v = value.strip()
    m = re.match(r"(?i)claude\b\s*([^<]*)", v)
    if m:
        return "claude", m.group(1).strip()
    m = re.match(r"(?i)codex\b[\s(]*([^<)]*)", v)
    if m:
        return "codex", m.group(1).strip()
    return None


# ---------------------------------------------------------------------------------------------------------------
# messages


def messages(limit=200):
    out = []
    try:
        with open(os.path.join(BUS, "messages.jsonl"), encoding="utf-8") as f:
            for n, line in enumerate(f):
                try:
                    out.append({**json.loads(line), "n": n})
                except ValueError:
                    pass
    except OSError:
        pass
    return out[-limit:]


def send(sender, to, text, re_id=None, model=None):
    sender, to, text = (sender or "").lower(), (to or "").lower(), (text or "").strip()
    if sender not in SENDERS or to not in TARGETS or sender == to or not text:
        return {"error": f"from must be one of {SENDERS}, to one of {TARGETS} (not yourself), text required"}
    msg = {"id": uuid.uuid4().hex[:10], "ts": now_iso(), "from": sender, "to": to, "text": text[:MAX_TEXT]}
    if re_id:
        msg["re"] = str(re_id)[:20]
    if model:
        msg["model"] = model_label(model)[:60]
    with locked():
        with open(os.path.join(bus_dir(), "messages.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps(msg) + "\n")
    return msg


def for_agent(msg, agent):
    return msg["from"] != agent and msg["to"] in (agent, "all")


def unread(agent):
    cursor = _read_json("cursors.json", {}).get(agent, 0)
    cursor = cursor if isinstance(cursor, int) else 0
    return [m for m in messages(10_000) if for_agent(m, agent) and m["n"] >= cursor]


def mark_read(agent, mail):
    """Everything up to the newest message in `mail` has been seen by `agent`."""
    if not mail:
        return
    with locked():
        cursors = _read_json("cursors.json", {})
        cursors[agent] = max(int(cursors.get(agent, 0) or 0), max(m["n"] for m in mail) + 1)
        _write_json("cursors.json", cursors)


# ---------------------------------------------------------------------------------------------------------------
# status: what each agent SAYS it is working on (activity read from transcripts is separate, see activity())


def statuses():
    return _read_json("status.json", {})


def set_status(agent, task=None, files=None, note=None, clear=False, model=None):
    if agent not in AGENTS:
        return {"error": f"agent must be one of {AGENTS}"}
    with locked():
        data = statuses()
        if clear:
            data.pop(agent, None)
        else:
            cur = data.get(agent, {})
            if task is not None:
                cur["task"] = task.strip()[:500]
            if files is not None:
                cur["files"] = [f.strip() for f in files if f.strip()][:50]
            if note is not None:
                cur["note"] = note.strip()[:2000]
            if model:
                cur["model"] = model_label(model)
            cur["updated"] = now_iso()
            data[agent] = cur
        _write_json("status.json", data)
        return data


def activity():
    """What each agent is actually doing, from its own transcripts (the dashboard server's readers)."""
    sys.path.insert(0, HERE)
    import server  # noqa: E402  (heavy import, only needed here)

    return server.presence()


# ---------------------------------------------------------------------------------------------------------------
# context: the one call an agent makes to catch up on the other


def fmt_msg(m):
    model = f" ({m['model']})" if m.get("model") else ""
    re_part = f" re {m['re']}" if m.get("re") else ""
    return f"[{m['id']}] {m['ts']} {m['from']}{model} -> {m['to']}{re_part}:\n{m['text']}"


def context(agent, brief=False):
    other = "codex" if agent == "claude" else "claude"
    lines = []
    try:
        act = activity().get(other)
    except Exception as e:  # transcripts unreadable: still deliver the mail
        act, lines = None, [f"(could not read {other}'s transcripts: {e})"]
    st = statuses().get(other)
    title = other.capitalize()
    if st:
        lines.append(f"{title} says it is working on: {st.get('task') or '-'} (updated {st.get('updated')})")
        if st.get("files"):
            lines.append("  files: " + ", ".join(st["files"]))
        if st.get("note"):
            lines.append("  note: " + st["note"])
    if act:
        model = f" · {act['model']}" if act.get("model") else ""
        lines.append(f"{title} activity: {act['status']}{model} · session {act['session']} \"{act.get('title') or ''}\" · last write {act.get('updatedIso')}")
        if act.get("prompt"):
            lines.append("  current task (latest user prompt): " + clip(act["prompt"], 300 if brief else 1200))
        if act.get("lastTool"):
            lines.append("  last tool: " + clip(act["lastTool"], 200))
        if act.get("files"):
            lines.append("  files it edited that are still uncommitted: " + ", ".join(act["files"][:25]))
        if act.get("report") and not brief:
            lines.append("  latest reply: " + clip(act["report"], 1200))
    elif not st:
        lines.append(f"No {title} activity found for this workspace.")
    mail = unread(agent)
    if mail:
        lines.append(f"\nUnread messages for {agent} ({len(mail)}):")
        lines += [fmt_msg(m) for m in mail]
        lines.append(f"Reply: python3 tools/dashboard/agent_bus.py send --from {agent} --to <claude|codex|user> \"...\" --re <id>")
    else:
        lines.append(f"\nNo unread messages for {agent}.")
    return "\n".join(lines), mail


def clip(s, n):
    s = " ".join(str(s).split())
    return s if len(s) <= n else s[:n] + " …"


def hook(agent):
    """Claude Code hook (SessionStart / UserPromptSubmit): stdout becomes context. Quiet when there is nothing new."""
    try:
        sys.stdin.read()  # the hook payload; not needed
    except OSError:
        pass
    mail = unread(agent)
    other = "codex" if agent == "claude" else "claude"
    try:
        act = activity().get(other)
    except Exception:
        act = None
    recent = act and act.get("status") == "running"
    if not mail and not recent:
        return
    text, mail = context(agent, brief=True)
    print(f"<agent-bus from=\"{other}\">\n{text}\n</agent-bus>")
    if mail:
        mark_read(agent, mail)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("send")
    p.add_argument("--from", dest="sender", required=True, choices=SENDERS)
    p.add_argument("--to", required=True, choices=TARGETS)
    p.add_argument("--re")
    p.add_argument("--model", help="your model id, shown next to the message")
    p.add_argument("text")
    p = sub.add_parser("inbox")
    p.add_argument("--agent", required=True, choices=AGENTS)
    p.add_argument("--all", action="store_true", help="the whole thread, not only unread")
    p.add_argument("--keep-unread", action="store_true")
    p = sub.add_parser("status")
    p.add_argument("--agent", required=True, choices=AGENTS)
    p.add_argument("--task")
    p.add_argument("--files", help="comma separated")
    p.add_argument("--note")
    p.add_argument("--model")
    p.add_argument("--clear", action="store_true")
    for name in ("context", "hook"):
        p = sub.add_parser(name)
        p.add_argument("--agent", required=True, choices=AGENTS)
        if name == "context":
            p.add_argument("--keep-unread", action="store_true")
            p.add_argument("--json", action="store_true")
    a = ap.parse_args()

    if a.cmd == "send":
        r = send(a.sender, a.to, a.text, a.re, a.model)
        print(json.dumps(r, indent=2))
        return 1 if "error" in r else 0
    if a.cmd == "inbox":
        mail = [m for m in messages(10_000) if m["to"] in (a.agent, "all") or m["from"] == a.agent] if a.all else unread(a.agent)
        print("\n\n".join(fmt_msg(m) for m in mail) or "No unread messages.")
        new = [m for m in mail if for_agent(m, a.agent)]
        if new and not a.keep_unread:
            mark_read(a.agent, new)
        return 0
    if a.cmd == "status":
        files = a.files.split(",") if a.files is not None else None
        r = set_status(a.agent, a.task, files, a.note, a.clear, a.model)
        print(json.dumps(r, indent=2))
        return 1 if "error" in r else 0
    if a.cmd == "context":
        text, mail = context(a.agent)
        if a.json:
            print(json.dumps({"text": text, "unread": mail, "status": statuses(), "activity": activity()}, indent=2))
        else:
            print(text)
        if mail and not a.keep_unread:
            mark_read(a.agent, mail)
        return 0
    if a.cmd == "hook":
        hook(a.agent)
        return 0


if __name__ == "__main__":
    sys.exit(main())
