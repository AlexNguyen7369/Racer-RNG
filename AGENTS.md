# Racer-RNG: Codex workspace instructions

Read `CLAUDE.md` for the shared game architecture, Studio/Rojo rules, compatibility
gate, feature-branch workflow, and context/TODO upkeep requirements. Preserve
existing collaborator edits. Read `context/ProjectContext.luau` before game work.

## Dashboard

The dashboard works independently of Claude. See `tools/dashboard/README.md`.
Check it with `python3 tools/dashboard/client.py meta`. If unavailable, start
`python3 tools/dashboard/server.py --no-fetch --no-auto-branch` as a persistent
process and verify `/api/meta` before reporting that it is running.

Use `tools/dashboard/client.py` to read TODOs, suggestions, manual tasks, agents,
tests, changes, history, and the compatibility gate. Use `--json` for requested
edits. TODO edits through the API regenerate the README's TODO block. If editing
`todo.json` directly, run `python3 tools/readme_sync.py`; never hand-edit that block.
Preserve suggestion decisions marked `added` or `dismissed`. Complete manual
tasks only after verifying the developer's result.

Codex sessions for this workspace appear in the Session menu and Agents tab
from local `$CODEX_HOME/sessions` (default `~/.codex/sessions`). The session ID in
the API starts with `codex-`. Supply it with the client's `--session` option to
inspect Codex activity. These transcripts are read-only inputs, not dashboard
state to modify. Do not mark a game test green based on general agent completion.

Git actions such as branch creation, push, and switch need an explicit relevant
user request. Check the dirty working tree and Rojo implications before switching.
Moving TODOs to Doing can create and push branches when `autoBranch` is enabled;
inspect `/api/meta` before making that change. Prefer `--no-auto-branch` for board
upkeep that does not request a GitHub action.
