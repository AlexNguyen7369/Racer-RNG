#!/usr/bin/env python3
"""Compatibility gate. Nothing reaches `main` on GitHub unless the full compatibility check (/compat-check) was ALL
GREEN for exactly the code being pushed.

The fingerprint covers everything that ships into the game: every git blob under src/ plus default.project.json.
It is computed from git blob hashes, so the working tree (when the check ran) and a commit (when it is pushed)
give the same fingerprint for the same content.

  python3 tools/compat.py fingerprint [--rev SHA]   print the fingerprint (working tree, or a commit)
  python3 tools/compat.py record RESULTS.json       write the green stamp; refuses unless every suite passed
  python3 tools/compat.py status                    is the working tree green? (exit 0 yes, 1 no)
  python3 tools/compat.py verify SHA                is commit SHA green? (exit 0 yes, 1 no) - used by pre-push

RESULTS.json (written by /compat-check from the testers' reports):
  { "suites": { "<suite>": { "pass": true, "end_line": "[CARTEST] END pass=N fail=0" | null, "summary": "..." } } }
Required suites: harness, ui, multiplayer, world. The harness suite must quote an END line with fail=0.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAMP = os.path.join(ROOT, ".compat", "green.json")
PATHS = ["src", "default.project.json"]
REQUIRED = ["harness", "ui", "multiplayer", "world"]


def git(*args, stdin=None):
    return subprocess.run(
        ["git", *args], cwd=ROOT, input=stdin, capture_output=True, text=True, check=True
    ).stdout


def digest(entries):
    h = hashlib.sha256()
    for path, blob in sorted(entries):
        h.update(f"{path}\0{blob}\n".encode())
    return h.hexdigest()


def fingerprint_rev(rev):
    out = git("ls-tree", "-r", rev, "--", *PATHS)
    entries = []
    for line in out.splitlines():
        meta, path = line.split("\t", 1)
        entries.append((path, meta.split()[2]))
    return digest(entries)


def fingerprint_worktree():
    # tracked + untracked (not ignored) files, as they are on disk now
    files = git("ls-files", "--cached", "--others", "--exclude-standard", "--", *PATHS).splitlines()
    files = sorted({f for f in files if os.path.isfile(os.path.join(ROOT, f))})
    if not files:
        return digest([])
    blobs = git("hash-object", "--stdin-paths", stdin="\n".join(files) + "\n").split()
    return digest(zip(files, blobs))


def load_stamp():
    try:
        with open(STAMP) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def record(results_path):
    with open(results_path) as f:
        results = json.load(f)
    suites = results.get("suites") or {}
    problems = []
    for name in REQUIRED:
        s = suites.get(name)
        if not s:
            problems.append(f"suite '{name}' missing")
        elif s.get("pass") is not True:
            problems.append(f"suite '{name}' not green")
    end = (suites.get("harness") or {}).get("end_line") or ""
    m = re.search(r"END pass=(\d+) fail=(\d+)", end)
    if not m or int(m.group(2)) != 0 or int(m.group(1)) == 0:
        problems.append(f"harness END line is not a green full run: {end!r}")
    for name, s in suites.items():
        if s.get("pass") is not True:
            problems.append(f"suite '{name}' not green")
    if problems:
        print("NOT recording a green stamp:\n  " + "\n  ".join(sorted(set(problems))))
        return 1
    stamp = {
        "fingerprint": fingerprint_worktree(),
        "head": git("rev-parse", "HEAD").strip(),
        "recorded_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "suites": suites,
    }
    os.makedirs(os.path.dirname(STAMP), exist_ok=True)
    with open(STAMP, "w") as f:
        json.dump(stamp, f, indent=2)
    print(f"GREEN stamp recorded for fingerprint {stamp['fingerprint'][:12]}")
    return 0


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd = argv[1]
    if cmd == "fingerprint":
        if len(argv) == 4 and argv[2] == "--rev":
            print(fingerprint_rev(argv[3]))
        else:
            print(fingerprint_worktree())
        return 0
    if cmd == "record" and len(argv) == 3:
        return record(argv[2])
    stamp = load_stamp()
    if cmd == "status":
        fp = fingerprint_worktree()
        if stamp and stamp.get("fingerprint") == fp:
            print(f"GREEN: compat check passed for the current code ({stamp.get('recorded_at')})")
            return 0
        print("NOT GREEN: the current code has no passing /compat-check run")
        return 1
    if cmd == "verify" and len(argv) == 3:
        fp = fingerprint_rev(argv[2])
        if stamp and stamp.get("fingerprint") == fp:
            return 0
        print(f"NOT GREEN: commit {argv[2][:10]} has no passing /compat-check run (fingerprint {fp[:12]})")
        return 1
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
