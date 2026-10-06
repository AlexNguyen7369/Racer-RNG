# Codex dashboard integration — 2026-10-06

Implemented by Codex for Alex Nguyen on `feature/alex/codex-dashboard`.
The branch is based on `02a15de` on `initial-import`, because the dashboard's
Team & branches integration (`tools/collab.py`) is not on `origin/main` yet.
Review or cherry-pick the Codex integration commit onto a branch containing that
dependency; this branch also contains the existing committed `initial-import`
history. Its new commit does not include the unrelated uncommitted gameplay/UI work.

## What changed

- `AGENTS.md`: shared Codex repository instructions referencing `CLAUDE.md`.
- `tools/dashboard/codex_activity.py`: workspace-filtered local rollout adapter;
  main/subagent cards, messages, tools and reports; resumed-turn status handling.
- `tools/dashboard/server.py`: combined Claude/Codex sessions and API routing.
- `tools/dashboard/static/`: source labels in the session menu and neutral agent wording.
- `tools/dashboard/client.py`: dependency-free localhost API reader/editor.
- `tools/dashboard/test_integration.py`: seven regression tests for workspace isolation,
  transcript filtering, resumed turns, partial logs, Claude compatibility, board/README
  edits, and network write restrictions.
- Dashboard guide, README, ProjectContext, TODO board, and progress log updated.

## Claude access and verification

Claude can read this handoff, `current_progress.md`, `context/ProjectContext.luau`,
and the completed TODO item `0e1c0f5c`. The same API works for both agents:

```sh
python3 tools/dashboard/client.py meta
python3 tools/dashboard/client.py todo
python3 tools/dashboard/client.py agents --session codex-<session-uuid>
python3 tools/dashboard/client.py messages --session codex-<session-uuid>
python3 -m unittest discover -s tools/dashboard -p 'test_*.py'
python3 tools/readme_sync.py --check
node --check tools/dashboard/static/app.js
```

Seven integration tests passed. JavaScript syntax and README synchronization
checks passed. Live `/api/meta`, agent timeline and board reads passed; a real
TODO add/completion verified write access and generated README synchronization.
These checks validate dashboard tooling, not Roblox gameplay compatibility.

## Runtime and limitations

The development dashboard was restarted on `http://127.0.0.1:8765` with
`--no-fetch --no-auto-branch`. This is a process setting, not a change to defaults.
Start it with those flags for board upkeep without automatic GitHub actions.
After pulling a changed server, restart it and refresh the browser.

Codex activity is read from local `$CODEX_HOME/sessions` (default `~/.codex/sessions`).
Logs are not checked into Git; teammates see their own sessions. Codex rollout
format is internal and may change. Unknown records, system/developer messages,
and reasoning are excluded. Main activity always appears; subagents appear when
their rollouts include supported parent metadata. No browser or Studio control
is added by this integration, and a completed agent turn is not a green test.

No credentials or local transcripts are included in this change. Existing
gameplay/UI edits in the shared workspace were left untouched. The pending Racer
UI and game compatibility work remains the next game task; do not interpret this
dashboard commit as certification for pushing gameplay to `main`.
