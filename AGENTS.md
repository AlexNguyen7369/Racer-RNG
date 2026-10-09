# Racer-RNG: Codex workspace instructions

Read `CLAUDE.md` for the shared game architecture, Studio/Rojo rules, compatibility
gate, feature-branch workflow, and context/TODO upkeep requirements. Preserve
existing collaborator edits. Read `context/ProjectContext.luau` before game work.
Read `handoff.md` at the start of every session. Before context limits, pausing,
or handing work to another agent, update it with the session goal, active files,
changes made, failed attempts/blockers, and specific resume steps. Keep it factual
and treat the dashboard Handoff tab as the same shared source of truth.

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

## Working alongside Claude (agent bus)

Claude Code and Codex share this workspace and can talk through `tools/dashboard/agent_bus.py`.
It uses plain files in the git-ignored `.agents/` folder, so it works even when the sandbox
cannot reach the dashboard on localhost. The dashboard's Agents tab shows the same data.

- **At the start of every task and before your final answer**, run
  `python3 tools/dashboard/agent_bus.py context --agent codex`. It prints what Claude says it is
  working on, what Claude is actually doing (latest prompt, model, status, last tool, the
  uncommitted files it changed) and your unread messages (then marks them read).
- Say what you are working on before editing shared files, and clear it when done:
  `python3 tools/dashboard/agent_bus.py status --agent codex --model <your model id> --task "..." --files a,b`
  and `... status --agent codex --clear`.
- Message Claude (or the developer): `python3 tools/dashboard/agent_bus.py send --from codex --to claude --model <your model id> "..." [--re <message id>]`.
  `--to user` reaches the developer on the dashboard, `--to all` reaches both.
- If Claude lists a file you are about to edit, re-read it right before editing and tell Claude.
  Never overwrite edits you did not make.
- Commits you make end with the trailer `Agent: Codex (<model id>)`, so the dashboard labels them
  (Claude's commits carry `Co-Authored-By: Claude <model>`). The dashboard also labels every
  uncommitted file with the agent and model that changed it, from both agents' logs.
