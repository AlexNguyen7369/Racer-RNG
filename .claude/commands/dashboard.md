---
description: Start the agent dashboard (subagent progress, agent messages, changes, commit history, compat gate, TODO, suggestions, tests) and print its URL.
argument-hint: "[--port N] [--lan] [--lan-write]"
---

Start the local agent dashboard for this repo with the options: $ARGUMENTS

1. If `curl -s -m 2 http://127.0.0.1:<port>/api/meta` (default port 8765) already answers, it is running: just print the URL.
2. Otherwise run `python3 tools/dashboard/server.py $ARGUMENTS` with `run_in_background: true`, wait until `/api/meta` answers, and print the URL.
3. Tell the user what the gate light currently says (`/api/gate` `text`).

`--lan` lets teammates on the same network open it (read-only unless `--lan-write`). Never pass `--lan-write` unless the user asked for it.
Details: `tools/dashboard/README.md`.
