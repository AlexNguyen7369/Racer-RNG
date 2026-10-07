# Agent dashboard

A local web page for everyone working on this repo: what the subagents are doing, the messages between agents, uncommitted changes, commit history (who committed what and when), the compat gate to `main`, the shared TODO list, suggested features, and every test with a plain-English explanation.

```
python3 tools/dashboard/server.py              # http://127.0.0.1:8765
python3 tools/dashboard/server.py --port 9000
python3 tools/dashboard/server.py --lan        # teammates on your network can view (read-only)
python3 tools/dashboard/server.py --lan --lan-write   # ...and edit the TODO / suggestions
```
Or `/dashboard` in Claude Code. Codex can start the same script directly; Claude
does not need to be running. Needs only `python3` and `git` (no packages).

For board upkeep without background fetching or automatic GitHub branch creation:
`python3 tools/dashboard/server.py --no-fetch --no-auto-branch`.

Tabs (`#manual`, `#agents`, `#analytics`, `#changes`, `#todo`, `#tests` in the URL open one directly):

| Tab | Shows | Source |
|---|---|---|
| Team & branches | who is on the team; every unmerged branch with who started it (`Initiated-By` trailer, else the first commit's author) and who commits on it, systems touched, ahead/behind main, files that overlap your uncommitted or branch work, real merge conflicts (`git merge-tree`) with your branch and with main, Rojo/Studio warnings, handoff notes, compare-on-GitHub link; Sync with GitHub, Push my branch, Switch to it, and a form that starts a labelled feature branch | git (fetched from origin every 2 min), `tools/collab.py`, `data/team.json` |
| Needs you | tasks only the developer can do by hand (Studio imports, settings, accounts, decisions), each with why, what it unblocks, when, and numbered steps (click a `code` path to copy it); Mark done / Reopen. The header pill shows how many are open | `data/manual.json` (Claude adds and closes items) |
| Agents | Claude subagent cards and Codex main/subagent activity; prompts, messages, tool calls, results, final reports, Need to know; sessions labelled Claude or Codex | Claude transcripts in `~/.claude/projects/<this repo>/`, Codex rollouts in `$CODEX_HOME/sessions` (default `~/.codex/sessions`), `context/ProjectContext.luau`, `current_progress.md` |
| Analytics | Claude/Codex model usage, token and tool-call totals, live tasks, inferred paused tasks, and recently completed tasks; scoped to this workspace and local provider logs | `GET /api/analytics`, Claude transcripts, workspace-filtered Codex rollouts |
| Changes & history | uncommitted files with diffs; commits on all branches with developer, date and time, files, `green` (that commit's game code passed /compat-check) and `local` (not pushed) | git, `tools/compat.py` |
| TODO & ideas | Doing / Up next / Backlog / Done board; suggested features that expand and can be added to the backlog or dismissed | `data/todo.json`, `data/suggestions.json` |
| Tests | how testing works, latest tester runs, the five compat suites (including the final regression pass), every scenario with its last status and what it checks | `src/server/CarTest/`, `src/client/UiTest/`, tester reports, `.compat/`, `data/tests_explained.json` |

Top bar: the gate light. Green = this exact code passed `/compat-check`, you can commit and push to `main`. Amber = code changed since the last green run. Red = a suite failed.

## Feature branches
Starting a feature (Team tab form, a TODO card's Branch button, moving a card to Doing, `/feature`, or `python3 tools/collab.py start "Title"`) creates `feature/<handle>/<slug>` from `origin/main` without touching your working tree. Its first commit is empty and carries `Feature-Title` / `Initiated-By` trailers, so GitHub itself records who started what. It is pushed to origin and the TODO card shows the owner and the branch. Git actions (start, push, switch, sync) only run for the browser on the machine that runs the server, never from `--lan`, because they use that machine's git identity. `--no-auto-branch` stops cards moved to Doing from starting branches; `--no-fetch` stops the background fetch.

## Shared vs per machine
- `data/*.json` is checked in: commit it so the team shares the TODO list and suggestion decisions. Each change records who (`git config user.name`) and when.
- The Agents tab reads your own Claude and Codex transcripts, so each developer sees their own sessions. Codex logs are filtered to this workspace (including its subdirectories); system/developer instructions and reasoning records are excluded. Local rollout formats are internal and may change. Unsupported records are ignored. Use `--lan` to show your activity to a teammate.
- Nothing here is under `src/`, so the dashboard never changes the compat fingerprint.

## Upkeep
- Claude moves TODO items at the end of every loop (see CLAUDE.md).
- `/refresh-suggestions` redoes the trend research.
- A new test scenario appears automatically; add its explanation to `data/tests_explained.json`.

## Codex / terminal access

The page and command-line client use the same API and write permissions. Local
requests can edit the board, suggestions, and manual task status. No OpenAI API
key, additional package, or Claude session is required.

```sh
python3 tools/dashboard/client.py meta
python3 tools/dashboard/client.py todo
python3 tools/dashboard/client.py gate
python3 tools/dashboard/client.py agents --session codex-<session-uuid>
python3 tools/dashboard/client.py messages --session codex-<session-uuid>
python3 tools/dashboard/client.py todo --json '{"action":"add","title":"Example task","status":"backlog"}'
python3 tools/dashboard/client.py todo --json '{"action":"move","id":"<todo-id>","status":"done"}'
python3 tools/dashboard/client.py manual/<task-id> --json '{"action":"done"}'
```

GET endpoints: `meta`, `agents`, `messages`, `agent/<id>`, `changes`, `history`,
`gate`, `needtoknow`, `todo`, `suggestions`, `manual`, `tests`, `team`.
POST endpoints: `todo` (`add`, `move`, `delete`), `suggestions/<id>` (`add`,
`dismiss`, `reopen`), `manual/<id>` (`done`, `reopen`). The separate `team/sync`,
`team/start`, `team/push`, `team/switch` endpoints perform Git actions; use only
when requested. With automatic branches enabled, moving a TODO to Doing can
also create and push a branch.

The Codex main agent appears as a card as well as in the shared timeline. A new
turn clears its prior completion status. A finished turn is shown as done, not
as a passed compatibility test. Subagent rollouts with parent metadata are
grouped under their parent's session. Logs refresh as they are written; resumed
sessions remain selectable in the Session menu. This integration displays local
logs; it does not launch agents or grant extra Studio/browser capabilities.

## Claude <-> Codex

Both agents see each other and talk through `agent_bus.py` (stdlib, plain files in the git-ignored
`.agents/`: `messages.jsonl`, `status.json`, `cursors.json`; no server needed):

```sh
python3 tools/dashboard/agent_bus.py context --agent codex      # the other agent's activity + your unread mail
python3 tools/dashboard/agent_bus.py send --from claude --to codex "..." [--re <id>] [--model <id>]
python3 tools/dashboard/agent_bus.py status --agent claude --task "..." --files a,b   # or --clear
python3 tools/dashboard/agent_bus.py inbox --agent claude --all
```

- Claude gets new messages automatically: `.claude/settings.json` runs `agent_bus.py hook --agent claude` at
  SessionStart and UserPromptSubmit (quiet unless there is unread mail or Codex is running). Codex is told by
  `AGENTS.md` to run `context` at the start and end of each task.
- Agents tab, top panel: each agent's presence (model, running / done / stopped, its latest task, last tool or
  reply, what it SAYS it is working on, and the uncommitted files it changed), the message thread, and a form to
  message Claude, Codex or both. API: `GET /api/bus`, `POST /api/bus` (`send`, `status`).
- Changes & history: every uncommitted file carries chips such as `Claude · Opus 5.5 · test-writer` or
  `Codex · gpt-6.1-sol` for each agent that edited it since its last commit (Claude Edit/Write tool calls, Codex
  FileChange records). `no agent` means a person or a shell-command edit. Commits are labelled from their trailers
  (`Co-Authored-By: Claude <model>`, `Agent: Codex (<model>)`) and from `git commit` output in either agent's log.
  The history has an agent filter.

Run integration checks: `python3 -m unittest discover -s tools/dashboard -p 'test_*.py'`.
