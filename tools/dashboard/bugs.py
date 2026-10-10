#!/usr/bin/env python3
"""Bug log for the dashboard's Bugs tab: every bug a subagent found, with the source it is in.

Works WITHOUT the dashboard server (plain file, stdlib only), so a tester subagent can log a bug from its shell.

  python3 tools/dashboard/bugs.py add --name "Car tilts on Hill crest" --kind failure \
      --file src/shared/CarPhysics.luau --line 120-128 --found-by physics-tester \
      --summary "What goes wrong and how it affects the game" [--error "console text"] [--at <ISO time>]
  python3 tools/dashboard/bugs.py list [--all]
  python3 tools/dashboard/bugs.py fixed <id> [--note "how"]
  python3 tools/dashboard/bugs.py reopen <id>

Kinds: fault   = the defect in the code itself (the cause: a wrong number, a missing check, a race).
       failure = the wrong behaviour seen when the game runs (the effect: a test fails, the car flips, money is lost).
The source lines are copied when the bug is logged, so the tab still shows the buggy code after it is fixed.
Storage: tools/dashboard/data/bugs.json (checked in, so the team shares it).
"""
import argparse
import contextlib
import datetime
try:
    import fcntl
except ImportError:  # Windows
    fcntl = None
    import msvcrt
import json
import os
import subprocess
import sys
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BUGS_FILE = os.path.join(HERE, "data", "bugs.json")
LOCK_FILE = os.path.join(ROOT, ".agents", "bugs.lock")  # git-ignored, like the agent bus
KINDS = ("fault", "failure")
STATUSES = ("open", "fixed")
CONTEXT_LINES = 4  # lines of code shown above and below the bug
MAX_SNIPPET = 80


def now_iso():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def developer():
    r = subprocess.run(["git", "config", "user.name"], cwd=ROOT, capture_output=True, text=True)
    return r.stdout.strip() or "unknown"


@contextlib.contextmanager
def locked():
    os.makedirs(os.path.dirname(LOCK_FILE), exist_ok=True)
    with open(LOCK_FILE, "w") as lk:
        if fcntl:
            fcntl.flock(lk, fcntl.LOCK_EX)
        else:
            msvcrt.locking(lk.fileno(), msvcrt.LK_LOCK, 1)
        try:
            yield
        finally:
            if fcntl:
                fcntl.flock(lk, fcntl.LOCK_UN)
            else:
                lk.seek(0)
                msvcrt.locking(lk.fileno(), msvcrt.LK_UNLCK, 1)


def load():
    try:
        with open(BUGS_FILE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {"items": []}


def save(data):
    tmp = f"{BUGS_FILE}.{uuid.uuid4().hex}.tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, BUGS_FILE)


def repo_path(path):
    """A repo-relative path inside ROOT, or None."""
    if not path:
        return None
    full = os.path.realpath(os.path.join(ROOT, path))
    if not full.startswith(os.path.realpath(ROOT) + os.sep):
        return None
    return os.path.relpath(full, os.path.realpath(ROOT))


def parse_lines(spec):
    """'120' or '120-128' -> (120, 128)."""
    if spec in (None, ""):
        return None, None
    a, _, b = str(spec).partition("-")
    start = int(a)
    end = int(b) if b else start
    if start < 1 or end < start:
        raise ValueError("line must be N or N-M with 1 <= N <= M")
    return start, end


def read_lines(rel):
    try:
        with open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace") as f:
            return f.read().splitlines()
    except OSError:
        return None


def snippet(rel, start, end):
    lines = read_lines(rel)
    if lines is None or start is None:
        return None
    first = max(1, start - CONTEXT_LINES)
    last = min(len(lines), end + CONTEXT_LINES, first + MAX_SNIPPET - 1)
    return {"from": first, "lines": lines[first - 1:last]}


def add(body):
    name = (body.get("name") or "").strip()
    summary = (body.get("summary") or "").strip()
    kind = body.get("kind")
    found_by = (body.get("foundBy") or "").strip()
    if not name or not summary or not found_by:
        return {"error": "name, summary and foundBy are required"}
    if kind not in KINDS:
        return {"error": "kind must be fault or failure"}
    rel = repo_path(body.get("file"))
    if body.get("file") and not rel:
        return {"error": "file must be a path inside the repo"}
    try:
        start, end = parse_lines(body.get("line"))
    except ValueError as e:
        return {"error": str(e)}
    snip = snippet(rel, start, end) if rel else None
    if rel and start and not snip:
        return {"error": f"cannot read {rel}"}
    item = {"id": uuid.uuid4().hex[:8], "name": name[:200], "kind": kind, "status": "open",
        "file": rel, "line": start, "endLine": end, "snippet": snip,
        "summary": summary[:4000], "error": (body.get("error") or "")[:4000],
        "foundBy": found_by[:80], "foundAt": body.get("foundAt") or now_iso(), "loggedBy": developer()}
    with locked():
        data = load()
        data["items"].append(item)
        save(data)
    return {**data, "added": item["id"]}


def set_status(bid, status, note=""):
    if status not in STATUSES:
        return {"error": "bad status"}
    with locked():
        data = load()
        b = next((i for i in data["items"] if i["id"] == bid), None)
        if not b:
            return {"error": "no such bug"}
        b["status"] = status
        if status == "fixed":
            b["fixedAt"], b["fixedBy"], b["fixNote"] = now_iso(), developer(), note[:2000]
        else:
            for k in ("fixedAt", "fixedBy", "fixNote"):
                b.pop(k, None)
        save(data)
    return data


def view():
    """For the dashboard: each bug plus whether its file still has the logged lines where they were."""
    data = load()
    for b in data["items"]:
        snip = b.get("snippet")
        if not (b.get("file") and snip):
            b["codeNow"] = None
            continue
        lines = read_lines(b["file"])
        if lines is None:
            b["codeNow"] = "missing"
        else:
            now = lines[snip["from"] - 1:snip["from"] - 1 + len(snip["lines"])]
            b["codeNow"] = "same" if now == snip["lines"] else "changed"
    return data


def action(bid, body):
    act = body.get("action")
    if act == "add":
        return add(body)
    if act in ("fixed", "reopen"):
        return set_status(bid, "fixed" if act == "fixed" else "open", body.get("note") or "")
    return {"error": "bad action"}


def main():
    ap = argparse.ArgumentParser(description="Dashboard bug log")
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add")
    a.add_argument("--name", required=True)
    a.add_argument("--kind", choices=KINDS, required=True)
    a.add_argument("--summary", required=True, help="what fails and how it affects the system")
    a.add_argument("--found-by", required=True, help="the subagent that found it, e.g. physics-tester")
    a.add_argument("--file", help="repo-relative source file")
    a.add_argument("--line", help="N or N-M")
    a.add_argument("--error", default="", help="error text / console output")
    a.add_argument("--at", help="discovery time (ISO 8601); default now")
    ls = sub.add_parser("list")
    ls.add_argument("--all", action="store_true", help="include fixed bugs")
    f = sub.add_parser("fixed")
    f.add_argument("id")
    f.add_argument("--note", default="")
    r = sub.add_parser("reopen")
    r.add_argument("id")
    args = ap.parse_args()

    if args.cmd == "add":
        res = add({"name": args.name, "kind": args.kind, "summary": args.summary, "foundBy": args.found_by,
            "file": args.file, "line": args.line, "error": args.error, "foundAt": args.at})
        if "error" in res:
            print(res["error"], file=sys.stderr)
            return 1
        print(f"logged bug {res['added']}")
        return 0
    if args.cmd == "list":
        for b in load()["items"]:
            if args.all or b["status"] == "open":
                where = f"{b['file']}:{b['line']}" if b.get("file") else "-"
                print(f"{b['id']}  {b['status']:5}  {b['kind']:7}  {b['foundBy']:18}  {where}  {b['name']}")
        return 0
    res = set_status(args.id, "fixed" if args.cmd == "fixed" else "open", getattr(args, "note", ""))
    if "error" in res:
        print(res["error"], file=sys.stderr)
        return 1
    print(f"{args.id}: {'fixed' if args.cmd == 'fixed' else 'open'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
