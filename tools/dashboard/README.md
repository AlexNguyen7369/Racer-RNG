# Agent dashboard

A local web page for everyone working on this repo: what the subagents are doing, the messages between agents, uncommitted changes, commit history (who committed what and when), the compat gate to `main`, the shared TODO list, suggested features, and every test with a plain-English explanation.

```
python3 tools/dashboard/server.py              # http://127.0.0.1:8765
python3 tools/dashboard/server.py --port 9000
python3 tools/dashboard/server.py --lan        # teammates on your network can view (read-only)
python3 tools/dashboard/server.py --lan --lan-write   # ...and edit the TODO / suggestions
```
Or `/dashboard` in Claude Code. Needs only `python3` and `git` (no packages).

Tabs (`#manual`, `#agents`, `#changes`, `#todo`, `#tests` in the URL open one directly):

| Tab | Shows | Source |
|---|---|---|
| Team & branches | who is on the team; every unmerged branch with who started it (`Initiated-By` trailer, else the first commit's author) and who commits on it, systems touched, ahead/behind main, files that overlap your uncommitted or branch work, real merge conflicts (`git merge-tree`) with your branch and with main, Rojo/Studio warnings, handoff notes, compare-on-GitHub link; Sync with GitHub, Push my branch, Switch to it, and a form that starts a labelled feature branch | git (fetched from origin every 2 min), `tools/collab.py`, `data/team.json` |
| Needs you | tasks only the developer can do by hand (Studio imports, settings, accounts, decisions), each with why, what it unblocks, when, and numbered steps (click a `code` path to copy it); Mark done / Reopen. The header pill shows how many are open | `data/manual.json` (Claude adds and closes items) |
| Agents | subagent cards (colour per agent, running / passed / failed), every message between main and the agents, one agent's full timeline (prompt, tool calls, results, report), Need to know | Claude Code transcripts in `~/.claude/projects/<this repo>/`, `context/ProjectContext.luau`, `current_progress.md` |
| Changes & history | uncommitted files with diffs; commits on all branches with developer, date and time, files, `green` (that commit's game code passed /compat-check) and `local` (not pushed) | git, `tools/compat.py` |
| TODO & ideas | Doing / Up next / Backlog / Done board; suggested features that expand and can be added to the backlog or dismissed | `data/todo.json`, `data/suggestions.json` |
| Tests | how testing works, latest tester runs, the four compat suites, every scenario with its last status and what it checks | `src/server/CarTest/`, `src/client/UiTest/`, tester reports, `.compat/`, `data/tests_explained.json` |

Top bar: the gate light. Green = this exact code passed `/compat-check`, you can commit and push to `main`. Amber = code changed since the last green run. Red = a suite failed.

## Feature branches
Starting a feature (Team tab form, a TODO card's Branch button, moving a card to Doing, `/feature`, or `python3 tools/collab.py start "Title"`) creates `feature/<handle>/<slug>` from `origin/main` without touching your working tree. Its first commit is empty and carries `Feature-Title` / `Initiated-By` trailers, so GitHub itself records who started what. It is pushed to origin and the TODO card shows the owner and the branch. Git actions (start, push, switch, sync) only run for the browser on the machine that runs the server, never from `--lan`, because they use that machine's git identity. `--no-auto-branch` stops cards moved to Doing from starting branches; `--no-fetch` stops the background fetch.

## Shared vs per machine
- `data/*.json` is checked in: commit it so the team shares the TODO list and suggestion decisions. Each change records who (`git config user.name`) and when.
- The Agents tab reads your own Claude Code transcripts, so each developer sees their own sessions. Use `--lan` to show yours to a teammate.
- Nothing here is under `src/`, so the dashboard never changes the compat fingerprint.

## Upkeep
- Claude moves TODO items at the end of every loop (see CLAUDE.md).
- `/refresh-suggestions` redoes the trend research.
- A new test scenario appears automatically; add its explanation to `data/tests_explained.json`.
