#!/usr/bin/env python3
"""Agent dashboard: a local web page that shows subagent progress, the messages between agents, code changes,
commit history, the compat gate, the TODO list, feature suggestions and the tests.

  python3 tools/dashboard/server.py                 http://127.0.0.1:8765
  python3 tools/dashboard/server.py --port 9000
  python3 tools/dashboard/server.py --lan           also reachable from your network (read-only for others)
  python3 tools/dashboard/server.py --lan --lan-write   others on the network may also edit TODO / suggestions

Stdlib only. Reads Claude Code transcripts, workspace-filtered Codex rollouts, git, .compat/ and the repo files.
Writes only tools/dashboard/data/todo.json, suggestions.json and manual.json (checked in, so the team shares them),
plus the generated TODO section of README.md after every TODO change (tools/readme_sync.py).
Team tab (tools/collab.py): fetches origin every FETCH_SECONDS, lists everyone's branches, and from this machine only
(never from the network) starts labelled feature branches, pushes the current branch and switches branches.
Moving a TODO card to Doing starts its feature branch automatically (--no-auto-branch turns that off).
"""
import argparse
import datetime
import glob
import json
import os
import re
import subprocess
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
STATIC = os.path.join(HERE, "static")
DATA = os.path.join(HERE, "data")
TODO_FILE = os.path.join(DATA, "todo.json")
SUGGEST_FILE = os.path.join(DATA, "suggestions.json")
MANUAL_FILE = os.path.join(DATA, "manual.json")
EXPLAIN_FILE = os.path.join(DATA, "tests_explained.json")
TRANSCRIPTS = os.path.join(os.path.expanduser("~"), ".claude", "projects", re.sub(r"[^A-Za-z0-9]", "-", ROOT))

sys.path.insert(0, os.path.join(ROOT, "tools"))
import collab  # noqa: E402  (feature branches, GitHub sync, everyone's branches)
import compat  # noqa: E402  (fingerprints and the green stamp)
import readme_sync  # noqa: E402  (README.md TODO section mirrors todo.json)
from codex_activity import CodexActivity

CODEX = CodexActivity(ROOT)

RUNNING_SECONDS = 120  # a transcript written to this recently, without a final report, counts as running
WRITE_LOCK = threading.RLock()  # re-entrant: adding a suggestion writes the TODO inside the same lock
SUITES = ["harness", "ui", "multiplayer", "world"]
FETCH_SECONDS = 120  # background `git fetch origin`, so collaborators' pushes show up without anyone clicking
FETCH = {"at": None, "error": None, "running": False}
AUTO_BRANCH = True  # moving a TODO card to Doing (or adding one there) starts its feature branch


# ---------------------------------------------------------------------------------------------------------------
# helpers


def git(*args, check=True):
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
    if check and r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return r.stdout


def read_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def write_json(path, data):
    tmp = f"{path}.{uuid.uuid4().hex}.tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)


def read_text(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return ""


def now_iso():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def developer():
    try:
        return git("config", "user.name").strip() or "unknown"
    except RuntimeError:
        return "unknown"


def clip(s, n):
    s = s if isinstance(s, str) else json.dumps(s)
    return s if len(s) <= n else s[:n] + " …"


# ---------------------------------------------------------------------------------------------------------------
# transcripts (cached by path + mtime + size)

_cache = {}


def load_lines(path):
    try:
        st = os.stat(path)
    except OSError:
        return []
    key = (st.st_mtime, st.st_size)
    hit = _cache.get(path)
    if hit and hit[0] == key:
        return hit[1]
    out = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                out.append(json.loads(line))
            except ValueError:
                pass
    _cache[path] = (key, out)
    return out


def blocks(entry):
    c = (entry.get("message") or {}).get("content")
    if isinstance(c, str):
        return [{"type": "text", "text": c}]
    return c if isinstance(c, list) else []


def result_text(block):
    c = block.get("content")
    if isinstance(c, list):
        return "\n".join(b.get("text", "") for b in c if isinstance(b, dict))
    return c if isinstance(c, str) else ""


def tool_summary(name, inp):
    if not isinstance(inp, dict):
        return clip(inp, 160)
    for k in ("description", "command", "file_path", "pattern", "query", "code", "message", "prompt"):
        if k in inp:
            return clip(str(inp[k]), 160)
    return clip(inp, 160)


def sessions():
    files = glob.glob(os.path.join(TRANSCRIPTS, "*.jsonl"))
    files.sort(key=os.path.getmtime, reverse=True)
    out = []
    for path in files[:15]:
        sid = os.path.basename(path)[:-6]
        title = ""
        for e in load_lines(path):
            if e.get("type") == "ai-title":
                title = e.get("aiTitle") or e.get("title") or title
        n = len(glob.glob(os.path.join(TRANSCRIPTS, sid, "subagents", "*.jsonl")))
        out.append({"id": sid, "title": title, "source": "claude", "agents": n, "updated": os.path.getmtime(path)})
    return sorted(out + CODEX.sessions(), key=lambda s: s["updated"], reverse=True)[:30]


def verdict_of(text):
    m = re.findall(r"END pass=(\d+) fail=(\d+)", text)
    if m:
        return "fail" if int(m[-1][1]) > 0 else "pass"
    up = text.upper()
    if re.search(r"\bALL GREEN\b|SUITE: GREEN|\bGREEN\b", up) and not re.search(r"\bNOT GREEN\b|\bRED\b|SUITE: RED", up):
        return "pass"
    if re.search(r"\bRED\b|\bFAIL(ED|S)?\b", up):
        return "fail"
    return None


def agent_info(session, path):
    aid = os.path.basename(path)[len("agent-") : -len(".jsonl")]
    meta = read_json(path[: -len(".jsonl")] + ".meta.json", {})
    lines = load_lines(path)
    prompt, report, last_tool, start, end = "", "", "", None, None
    for e in lines:
        ts = e.get("timestamp")
        if ts:
            start = start or ts
            end = ts
        for b in blocks(e):
            if e.get("type") == "user" and b.get("type") == "text" and not prompt:
                prompt = b.get("text", "")
            if b.get("type") == "tool_use":
                last_tool = f"{b.get('name')}: {tool_summary(b.get('name'), b.get('input'))}"
                if b.get("name") == "SubagentHandback":
                    report = (b.get("input") or {}).get("message", "")
            if e.get("type") == "assistant" and b.get("type") == "text":
                final_text = b.get("text", "")
                if (e.get("message") or {}).get("stop_reason") == "end_turn":
                    report = report or final_text
    age = time.time() - os.path.getmtime(path)
    status = "done" if report else ("running" if age < RUNNING_SECONDS else "stopped")
    return {
        "id": aid,
        "session": session,
        "type": meta.get("agentType") or "agent",
        "description": meta.get("description") or clip(prompt, 60),
        "toolUseId": meta.get("toolUseId"),
        "status": status,
        "verdict": verdict_of(report) if report else None,
        "start": start,
        "end": end,
        "lastTool": last_tool,
        "steps": sum(1 for e in lines if e.get("type") == "assistant"),
        "report": clip(report, 400),
    }


def agents(session):
    if session.startswith("codex-"):
        return CODEX.agents(session)
    paths = glob.glob(os.path.join(TRANSCRIPTS, session, "subagents", "agent-*.jsonl"))
    out = [agent_info(session, p) for p in paths]
    out.sort(key=lambda a: a["start"] or "", reverse=True)
    return out


def agent_timeline(session, aid):
    if session.startswith("codex-"):
        return CODEX.agent_timeline(session, aid)
    path = os.path.join(TRANSCRIPTS, session, "subagents", f"agent-{aid}.jsonl")
    if not re.fullmatch(r"[A-Za-z0-9]+", aid) or not os.path.isfile(path):
        return None
    meta = read_json(path[: -len(".jsonl")] + ".meta.json", {})
    kind = meta.get("agentType") or "agent"
    items = []
    for e in load_lines(path):
        ts = e.get("timestamp")
        for b in blocks(e):
            t = b.get("type")
            if e.get("type") == "user" and t == "text":
                items.append({"kind": "prompt", "from": "main", "to": kind, "text": b.get("text", ""), "ts": ts})
            elif t == "text" and e.get("type") == "assistant" and b.get("text", "").strip():
                items.append({"kind": "say", "from": kind, "text": b["text"], "ts": ts})
            elif t == "tool_use":
                name = b.get("name")
                if name == "SubagentHandback":
                    items.append({"kind": "report", "from": kind, "to": "main", "text": (b.get("input") or {}).get("message", ""), "ts": ts})
                else:
                    items.append({"kind": "tool", "from": kind, "name": name, "text": tool_summary(name, b.get("input")), "ts": ts})
            elif t == "tool_result":
                items.append({"kind": "result", "from": kind, "text": clip(result_text(b), 1500), "error": bool(b.get("is_error")), "ts": ts})
    return {"id": aid, "type": kind, "description": meta.get("description"), "items": items}


def messages(session):
    """Messages between agents: the main thread's Agent / SendMessage calls and what came back."""
    if session.startswith("codex-"):
        return CODEX.messages(session)
    path = os.path.join(TRANSCRIPTS, f"{session}.jsonl")
    calls, out = {}, []
    for e in load_lines(path):
        ts = e.get("timestamp")
        for b in blocks(e):
            if b.get("type") == "tool_use" and b.get("name") in ("Agent", "Task", "SendMessage"):
                inp = b.get("input") or {}
                to = inp.get("subagent_type") or inp.get("to") or "general-purpose"
                calls[b.get("id")] = to
                out.append({"from": "main", "to": to, "kind": "send" if b["name"] == "SendMessage" else "spawn",
                    "title": inp.get("description") or "", "text": clip(inp.get("prompt") or inp.get("message") or "", 3000), "ts": ts})
            elif b.get("type") == "tool_result" and b.get("tool_use_id") in calls:
                txt = result_text(b)
                if txt.startswith("Async agent launched"):
                    continue  # background agent: its real report comes through SubagentHandback below
                out.append({"from": calls[b["tool_use_id"]], "to": "main", "kind": "reply", "title": "",
                    "text": clip(txt, 3000), "verdict": verdict_of(txt), "ts": ts})
    # background agents deliver their final report through SubagentHandback in their own transcript
    for a in agents(session):
        if a["status"] == "done" and a["report"]:
            full = agent_timeline(session, a["id"])
            rep = next((i for i in reversed(full["items"]) if i["kind"] == "report"), None) if full else None
            if rep:
                out.append({"from": a["type"], "to": "main", "kind": "report", "title": a["description"],
                    "text": clip(rep["text"], 3000), "verdict": a["verdict"], "ts": rep["ts"]})
    out.sort(key=lambda m: m["ts"] or "")
    return out


# ---------------------------------------------------------------------------------------------------------------
# git: changes, history, gate


def changes():
    out = []
    for line in git("status", "--porcelain=v1", "-uall").splitlines():
        code, path = line[:2], line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        out.append({"path": path.strip('"'), "status": code.strip() or "?", "add": 0, "del": 0})
    stats = {}
    for line in git("diff", "HEAD", "--numstat").splitlines():
        a, d, p = line.split("\t", 2)
        stats[p] = (a, d)
    for c in out:
        if c["path"] in stats:
            a, d = stats[c["path"]]
            c["add"], c["del"] = (int(a) if a.isdigit() else 0), (int(d) if d.isdigit() else 0)
        elif c["status"] == "??":
            c["add"] = read_text(os.path.join(ROOT, c["path"])).count("\n")
    return out


def diff(path):
    if path not in {c["path"] for c in changes()}:
        return None
    if git("ls-files", "--", path).strip():
        return git("diff", "HEAD", "--", path)
    body = read_text(os.path.join(ROOT, path))
    return f"new file {path}\n" + "".join("+" + l + "\n" for l in body.splitlines())


_fp_cache = {}


def commit_green(sha, stamp_fp):
    if not stamp_fp:
        return False
    if sha not in _fp_cache:
        try:
            _fp_cache[sha] = compat.fingerprint_rev(sha)
        except Exception:
            _fp_cache[sha] = None
    return _fp_cache[sha] == stamp_fp


def history(limit, author=None, branch=None):
    fmt = "%x1e%H%x1f%h%x1f%an%x1f%aI%x1f%D%x1f%s"
    args = ["log", f"-n{limit}", f"--format={fmt}", "--numstat"]
    args += [branch] if branch else ["--all"]
    if author:
        args.append(f"--author={author}")
    raw = git(*args, check=False)
    pushed = set(git("rev-list", "--remotes", "-n", "2000", check=False).split())
    stamp = compat.load_stamp() or {}
    out = []
    for rec in raw.split("\x1e")[1:]:
        head, _, rest = rec.partition("\n")
        sha, short, name, date, refs, subject = head.split("\x1f")
        files = []
        for l in rest.strip().splitlines():
            parts = l.split("\t", 2)
            if len(parts) == 3:
                files.append({"path": parts[2], "add": parts[0], "del": parts[1]})
        out.append({"sha": sha, "short": short, "author": name, "date": date, "refs": refs, "subject": subject,
            "files": files, "pushed": sha in pushed, "green": commit_green(sha, stamp.get("fingerprint"))})
    authors = sorted(set(git("log", "--all", "--format=%an", check=False).split("\n")) - {""})
    branches = [b.strip() for b in git("branch", "-a", "--format=%(refname:short)", check=False).splitlines() if b.strip()]
    return {"commits": out, "authors": authors, "branches": branches}


def show_commit(sha):
    if not re.fullmatch(r"[0-9a-f]{7,40}", sha):
        return None
    return git("show", "--stat", "--patch", "--format=%H%n%an  %aI%n%n%B", sha, check=False)


def gate():
    stamp = compat.load_stamp() or {}
    results = read_json(os.path.join(ROOT, ".compat", "results.json"), {}).get("suites", {})
    fp = compat.fingerprint_worktree()
    matches = bool(stamp) and stamp.get("fingerprint") == fp
    suites = []
    for name in SUITES:
        s = results.get(name) or (stamp.get("suites") or {}).get(name) or {}
        suites.append({"name": name, "pass": s.get("pass"), "summary": s.get("summary", ""), "end": s.get("end_line")})
    if matches:
        verdict, text = "green", "Ready to commit & push: this exact code passed /compat-check"
    elif any(s["pass"] is False for s in suites):
        verdict, text = "red", "Blocked: a compat suite failed"
    else:
        verdict, text = "stale", "Code changed since the last green /compat-check: rerun it before pushing to main"
    ahead = git("rev-list", "--count", "origin/main..HEAD", check=False).strip() or "?"
    return {"verdict": verdict, "text": text, "suites": suites, "stampAt": stamp.get("recorded_at"),
        "stampHead": (stamp.get("head") or "")[:10], "fingerprint": fp[:12], "aheadOfMain": ahead,
        "branch": git("rev-parse", "--abbrev-ref", "HEAD", check=False).strip()}


# ---------------------------------------------------------------------------------------------------------------
# need to know, tests


def block_between(text, start_pat, end_pat):
    m = re.search(start_pat, text, re.M)
    if not m:
        return ""
    rest = text[m.start() :]
    e = re.search(end_pat, rest[1:], re.M)
    return rest[: e.start() + 1].strip() if e else rest.strip()


def need_to_know():
    ctx = read_text(os.path.join(ROOT, "context", "ProjectContext.luau"))
    prog = read_text(os.path.join(ROOT, "current_progress.md"))
    completed = re.findall(r"^\d+\.\s+(.*)$", block_between(prog, r"^## Completed", r"^## "), re.M)
    return {
        "urgent": block_between(ctx, r"^!!! URGENT", r"^TODO \(in order\)"),
        "known": block_between(ctx, r"^KNOWN ISSUES", r"^HOW TO RUN TESTS"),
        "next": block_between(prog, r"^## What's next", r"^## (?!What)"),
        "completed": completed[::-1],
        "updated": re.search(r"Last updated: (.*)", ctx).group(1) if "Last updated:" in ctx else "",
    }


def luau_list(text, key):
    m = re.search(key + r"\s*=\s*\{(.*?)\n\t?\}", text, re.S)
    return re.findall(r'"([a-z_:A-Za-z0-9]+)"', m.group(1)) if m else []


def latest_reports(kinds):
    """Newest final reports from tester subagents across recent sessions (newest first)."""
    out = []
    for s in sessions()[:8]:
        for a in agents(s["id"]):
            if a["type"] in kinds and a["status"] == "done":
                tl = agent_timeline(s["id"], a["id"])
                rep = next((i["text"] for i in reversed(tl["items"]) if i["kind"] in ("report", "say")), "")
                out.append((a["end"] or "", a, rep))
    out.sort(key=lambda x: x[0], reverse=True)
    return out


def scenario_status(name, report):
    m = re.search(r'\\?"scenario\\?":\s*\\?"' + re.escape(name) + r'\\?",\s*\\?"pass\\?":\s*(true|false)', report)
    if m:
        return "pass" if m.group(1) == "true" else "fail"
    for line in report.splitlines():
        if re.search(r"(?<![A-Za-z_])" + re.escape(name) + r"(?![A-Za-z_])", line):
            low = line.lower()
            if re.search(r"\bfail(ed|s)?\b|❌|\bred\b", low) and "fail=0" not in low:
                return "fail"
            if re.search(r"\bpass(ed|es)?\b|✅|\bgreen\b|\bok\b", low):
                return "pass"
    return None


def tests():
    explain = read_json(EXPLAIN_FILE, {})
    cfg = read_text(os.path.join(ROOT, "src", "server", "CarTest", "TestConfig.luau"))
    ui = read_text(os.path.join(ROOT, "src", "client", "UiTest", "UiScenarios.luau"))
    harness = luau_list(cfg, "Scenarios")
    tracks = ["track:" + os.path.basename(p)[:-5] for p in sorted(glob.glob(os.path.join(ROOT, "src", "server", "CarTest", "TrackTests", "*.luau")))]
    uis = luau_list(ui, "UiScenarios.Names")
    reports = {
        "harness": latest_reports({"physics-tester"}),
        "ui": latest_reports({"ui-tester"}),
    }

    def row(name, group, suite):
        # newest tester report that says something about this scenario
        status, at = None, None
        for end, _a, rep in reports[suite]:
            status = scenario_status(name, rep)
            if status:
                at = end
                break
        e = explain.get(name) or explain.get(name.split(":")[0] + ":*") or {}
        return {"name": name, "group": group, "status": status, "from": at, **e}

    groups = [
        {"name": "Harness (server, CarTest)", "rows": [row(n, "harness", "harness") for n in harness]},
        {"name": "Tracks (CarTest/TrackTests)", "rows": [row(n, "track", "harness") for n in tracks]},
        {"name": "UI (client, UiTest)", "rows": [row(n, "ui", "ui") for n in uis]},
    ]
    latest = {}
    for suite, reps in reports.items():
        if reps:
            end = re.findall(r"\[(?:CAR|UI)TEST\] END pass=\d+ fail=\d+", reps[0][2])
            latest[suite] = {"at": reps[0][0], "end": end[-1] if end else None, "verdict": reps[0][1]["verdict"],
                "summary": clip(reps[0][2], 600)}
    return {"groups": groups, "latest": latest, "compat": gate()["suites"], "guide": explain.get("_guide", [])}


# ---------------------------------------------------------------------------------------------------------------
# TODO and suggestions (shared, checked-in JSON)

TODO_STATUSES = ("doing", "next", "backlog", "done")


def todo_action(body):
    with WRITE_LOCK:
        data = read_json(TODO_FILE, {"items": []})
        items = data["items"]
        act = body.get("action")
        by, at = developer(), now_iso()
        if act == "add":
            title = (body.get("title") or "").strip()
            if not title:
                return {"error": "title required"}
            items.append({"id": uuid.uuid4().hex[:8], "title": title[:200], "detail": (body.get("detail") or "")[:4000],
                "status": body.get("status") if body.get("status") in TODO_STATUSES else "backlog",
                "source": body.get("source") or "manual", "by": by, "added": at, "updated": at})
        else:
            item = next((i for i in items if i["id"] == body.get("id")), None)
            if not item:
                return {"error": "no such item"}
            if act == "move" and body.get("status") in TODO_STATUSES:
                item["status"] = body["status"]
                if body["status"] == "done":
                    item["done"] = at
            elif act == "delete":
                items.remove(item)
            else:
                return {"error": "bad action"}
            item["updated"], item["updatedBy"] = at, by
        write_json(TODO_FILE, data)
        readme_sync.sync()
        return data


def suggestion_action(sid, body):
    with WRITE_LOCK:
        data = read_json(SUGGEST_FILE, {"items": []})
        s = next((i for i in data["items"] if i["id"] == sid), None)
        act = body.get("action")
        if not s or act not in ("add", "dismiss", "reopen"):
            return {"error": "bad request"}
        if act == "add" and s.get("status") != "added":
            detail = f"{s.get('description', '')}\n\nFits this game: {s.get('fit', '')}\nInspired by: {s.get('inspiredBy', '')}"
            todo_action({"action": "add", "title": s["title"], "detail": detail, "status": "backlog", "source": f"suggestion:{sid}"})
        s["status"] = {"add": "added", "dismiss": "dismissed", "reopen": "open"}[act]
        s["decidedBy"], s["decidedAt"] = developer(), now_iso()
        write_json(SUGGEST_FILE, data)
        return data


def manual_action(mid, body):
    """Tasks only the developer can do by hand (Studio imports, settings, accounts): mark done or reopen."""
    with WRITE_LOCK:
        data = read_json(MANUAL_FILE, {"items": []})
        m = next((i for i in data["items"] if i["id"] == mid), None)
        act = body.get("action")
        if not m or act not in ("done", "reopen"):
            return {"error": "bad request"}
        m["status"] = "done" if act == "done" else "open"
        m["doneBy"], m["doneAt"] = (developer(), now_iso()) if act == "done" else (None, None)
        write_json(MANUAL_FILE, data)
        return data


# ---------------------------------------------------------------------------------------------------------------
# team: GitHub sync and feature branches (tools/collab.py)


def do_fetch():
    if FETCH["running"]:
        return
    FETCH["running"] = True
    try:
        collab.fetch()
        FETCH["at"], FETCH["error"] = now_iso(), None
    except collab.GitError as e:
        FETCH["error"] = str(e)
    finally:
        FETCH["running"] = False


def fetch_loop():
    while True:
        do_fetch()
        time.sleep(FETCH_SECONDS)


def team_view():
    return {**collab.overview(), "fetch": dict(FETCH)}


def start_branch(todo_id, title=None, detail=""):
    """Start a labelled feature branch and link it to its TODO item (a new Doing item when todo_id is None)."""
    with WRITE_LOCK:
        if todo_id:
            item = next((i for i in read_json(TODO_FILE, {"items": []})["items"] if i["id"] == todo_id), None)
            if not item:
                return {"error": "no such TODO item"}
            if item.get("branch"):
                return {"error": f"already on {item['branch']}"}
            title, detail = item["title"], item.get("detail", "")
        try:
            info = collab.start_feature(title, detail, todo_id)
        except collab.GitError as e:
            return {"error": str(e)}
        collab.link_todo(info, todo_id, detail)
        return {"started": info, "todo": read_json(TODO_FILE, {"items": []})}


def team_action(action, body):
    try:
        if action == "sync":
            do_fetch()
            return {"error": FETCH["error"]} if FETCH["error"] else {"ok": True, "fetch": dict(FETCH)}
        if action == "start":
            return start_branch(body.get("todo"), (body.get("title") or "").strip()[:120], (body.get("detail") or "")[:4000])
        if action == "push":
            return collab.push_current()
        if action == "switch":
            return collab.switch(body.get("branch") or "")
    except collab.GitError as e:
        return {"error": str(e)}
    return {"error": "bad action"}


# ---------------------------------------------------------------------------------------------------------------
# HTTP

CONTENT_TYPES = {".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8"}


class Handler(BaseHTTPRequestHandler):
    lan_write = False

    def log_message(self, *args):
        pass

    def send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        u = urlparse(self.path)
        q = {k: v[0] for k, v in parse_qs(u.query).items()}
        p = u.path
        try:
            if p == "/" or p.startswith("/static/"):
                name = "index.html" if p == "/" else os.path.basename(p)
                fp = os.path.join(STATIC, name)
                if not os.path.isfile(fp):
                    return self.send(404, {"error": "not found"})
                with open(fp, "rb") as f:
                    return self.send(200, f.read(), CONTENT_TYPES.get(os.path.splitext(name)[1], "application/octet-stream"))
            ss = sessions()
            sid = q.get("session") or (ss[0]["id"] if ss else "")
            if sid and not re.fullmatch(r"(?:codex-)?[0-9a-f-]{36}", sid):
                return self.send(400, {"error": "bad session"})
            routes = {
                "/api/meta": lambda: {"developer": developer(), "root": ROOT, "sessions": ss, "session": sid,
                    "canWrite": self.can_write(), "local": self.is_local(), "autoBranch": AUTO_BRANCH,
                    "transcripts": TRANSCRIPTS, "codexTranscripts": os.path.join(CODEX.home, "sessions")},
                "/api/team": team_view,
                "/api/agents": lambda: agents(sid) if sid else [],
                "/api/messages": lambda: messages(sid) if sid else [],
                "/api/changes": changes,
                "/api/gate": gate,
                "/api/needtoknow": need_to_know,
                "/api/todo": lambda: read_json(TODO_FILE, {"items": []}),
                "/api/suggestions": lambda: read_json(SUGGEST_FILE, {"items": []}),
                "/api/manual": lambda: read_json(MANUAL_FILE, {"items": []}),
                "/api/tests": tests,
                "/api/history": lambda: history(min(int(q.get("limit", 60)), 300), q.get("author"), q.get("branch")),
            }
            if p in routes:
                return self.send(200, routes[p]())
            if p.startswith("/api/agent/"):
                r = agent_timeline(sid, p.rsplit("/", 1)[1])
                return self.send(200, r) if r else self.send(404, {"error": "no such agent"})
            if p == "/api/diff":
                d = diff(q.get("path", ""))
                return self.send(200, {"diff": d}) if d is not None else self.send(403, {"error": "not a changed file"})
            if p.startswith("/api/commit/"):
                d = show_commit(p.rsplit("/", 1)[1])
                return self.send(200, {"diff": d}) if d is not None else self.send(400, {"error": "bad sha"})
            self.send(404, {"error": "not found"})
        except Exception as e:  # keep the page alive; show the error in the panel
            self.send(500, {"error": str(e)})

    def is_local(self):
        return self.client_address[0] in ("127.0.0.1", "::1")

    def can_write(self):
        return self.is_local() or self.lan_write

    def do_POST(self):
        if not self.can_write():
            return self.send(403, {"error": "read-only from the network (start the server with --lan-write)"})
        try:
            n = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(min(n, 100_000)) or b"{}")
        except ValueError:
            return self.send(400, {"error": "bad json"})
        p = urlparse(self.path).path
        if p.startswith("/api/team/"):
            # git actions run as this machine's git identity, so only its own developer may trigger them
            if not self.is_local():
                return self.send(403, {"error": "git actions only from the machine running the dashboard"})
            r = team_action(p.rsplit("/", 1)[1], body)
        elif p == "/api/todo":
            r = todo_action(body)
            if "error" not in r and AUTO_BRANCH and self.is_local() and body.get("status") == "doing" \
                    and body.get("action") in ("add", "move"):
                tid = body.get("id") if body.get("action") == "move" else r["items"][-1]["id"]
                item = next((i for i in r["items"] if i["id"] == tid), {})
                if not item.get("branch"):
                    started = start_branch(tid)
                    r = {**(started.get("todo") or r), "started": started.get("started"), "branchError": started.get("error")}
        elif p.startswith("/api/manual/"):
            r = manual_action(p.rsplit("/", 1)[1], body)
        elif p.startswith("/api/suggestions/"):
            r = suggestion_action(p.rsplit("/", 1)[1], body)
        else:
            return self.send(404, {"error": "not found"})
        self.send(400 if "error" in r else 200, r)


def main():
    ap = argparse.ArgumentParser(description="Agent dashboard")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--lan", action="store_true", help="listen on all interfaces (others can view)")
    ap.add_argument("--lan-write", action="store_true", help="with --lan: others may also edit TODO / suggestions")
    ap.add_argument("--no-fetch", action="store_true", help="never fetch origin in the background")
    ap.add_argument("--no-auto-branch", action="store_true", help="moving a TODO card to Doing does not start a branch")
    a = ap.parse_args()
    global AUTO_BRANCH
    AUTO_BRANCH = not a.no_auto_branch
    Handler.lan_write = a.lan and a.lan_write
    if not a.no_fetch:
        threading.Thread(target=fetch_loop, daemon=True).start()
    host = "0.0.0.0" if a.lan else "127.0.0.1"
    srv = ThreadingHTTPServer((host, a.port), Handler)
    print(f"Agent dashboard on http://127.0.0.1:{a.port}" + ("  (also on your LAN)" if a.lan else ""))
    print(f"Transcripts: {TRANSCRIPTS}")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
