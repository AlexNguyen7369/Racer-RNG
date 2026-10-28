---
# Project config for the universal `orchestrator` skill (~/.claude/skills/orchestrator). Run with /orchestrate.
rules:
  top: docs/GAME_DESIGN_REQUIREMENTS.md
  specs: docs/*_SPEC.md
  tunable_marks: ["placeholder", "proposed", "open question"]
handoff: handoff.md
goals: docs/ORCHESTRATOR_GOALS.md               # owner-confirmed end goals + deliverables (orchestrator asks, then writes)
state: .agents/orchestrator.json                # git-ignored; drawn by the dashboard Orchestration tab
worktrees_dir: ../RobloxGames-orch               # one worktree per task: ../RobloxGames-orch/<task-id>
board: tools/dashboard/data/todo.json            # statuses: doing, next, backlog, done
bugs: python3 tools/dashboard/bugs.py add --name ... --kind fault|failure --file <path> --line N --found-by <agent> --summary "..."
owner_channel:
  file: tools/dashboard/data/manual.json         # items: id, title, category, priority, why, blocks, when, steps
  bus: python3 tools/dashboard/agent_bus.py send --from claude --to user "..."
bus:
  context: python3 tools/dashboard/agent_bus.py context --agent claude
  inbox: python3 tools/dashboard/agent_bus.py inbox --agent claude
  send: python3 tools/dashboard/agent_bus.py send --from claude --to codex|user|all "..." --re <id>
  claim: python3 tools/dashboard/agent_bus.py status --agent claude --task "..." --files a,b
  release: python3 tools/dashboard/agent_bus.py status --agent claude --clear
overview: python3 tools/collab.py overview
branch_start: python3 tools/collab.py start "<title>" --todo <id>
push: python3 tools/collab.py push
protected_branches: [main, initial-import]
tests:
  always: ["stylua src", "selene src"]
  harness: physics-tester agent ([CARTEST] END fail=0)
  ui: ui-tester agent ([UITEST] END fail=0)
  large_change: /compat-check
exclusive_resources:
  studio:
    # Owner 2026-10-27: test each task branch asynchronously in its OWN Studio when possible; else queue for the shared one.
    isolate:
      max_parallel: 3                              # placeholder; each Studio uses ~2-4 GB RAM
      ports: 34873-34883                           # one `rojo serve --port` per task (34872 = shared Studio)
      steps:
        - cp IdleVehicleSimulator.rbxl <worktree>/.orch/<task-id>.rbxl   # place copy; keeps Studio-only content (MeshParts, settings)
        - open -n -a RobloxStudio <worktree>/.orch/<task-id>.rbxl
        - wait until mcp list_roblox_studios shows a new id whose name contains <task-id> (timeout 180 s); record it as the task's studio_id
        - (cd <worktree> && rojo serve --port <port>) in the background
        - connect that Studio's Rojo plugin to <port> (Studio MCP input on that studio_id); confirm a synced script's source matches the worktree file
        - every Studio MCP call for the task passes that studio_id, and only that one
        - when the task is finished: stop its rojo serve and close its Studio; never close a Studio you did not open
      fallback_when: any step above fails, the confirm check does not match, max_parallel is reached, or the task needs the live save / DataStore
    queue:
      # The shared Studio (the one Rojo serves from the main tree) runs one test at a time, in FIFO order.
      order: state file `studio_queue` (task ids)
      claim: python3 tools/dashboard/agent_bus.py status --agent claude --task "studio-test <task-id>"
      rule: check bus context first; wait while another session or task holds it; if a task is stuck or broken, it moves to the back of the queue
    always_shared: final /compat-check and regression-tester on the integration branch
auditor: rules-auditor
roster:
  track: /build-track
  car_physics: /car-loop
  ui: ui-test-writer (red) -> implement -> ui-tester
  world: world-builder -> world-tester
  multiplayer: multiplayer-tester
  tests_write: test-writer
  final: regression-tester
  general: general-purpose
forbidden:
  - src/shared/PhysicsTargets.luau (owner feel decisions)
  - test files, except by test-writer / ui-test-writer
  - re-enabling SpeedHud, AutoRaceButton, IndexUi, StatsUi, RollUi
  - renaming or reusing a car Id in src/shared/Cars/
  - README TODO block (generated)
  - suggestions marked added / dismissed in tools/dashboard/data/suggestions.json
post_commit: [/progress-tracker]
bookkeeping:
  - context/ProjectContext.luau (change log, dated test results, known issues)
  - tools/dashboard/data/todo.json
  - tools/dashboard/data/tests_explained.json (new test scenarios)
  - README.md "Features implemented" (when a feature ships)
---

# Notes for the orchestrator

- Read `CLAUDE.md` once per session. It holds the full rule set. This file only maps the skill onto it.
- A new feature goes into the design doc and its spec before any code. Only the owner writes rules, so missing rules go to the owner channel.
- Studio testing: isolate first. A task worktree gets its own place copy, its own Studio and its own `rojo serve` port, so VFX, SFX, UI and world tasks test in parallel. Any break in that setup sends the task to the shared Studio queue. The shared Studio is the one Rojo serves from the main tree.
- Isolated Studios must not load or write a real player's save. The session lock (`docs/SAVE_SPEC.md`) would block the other instance. Use Studio with API access off, or the harness's test data only.
- Commit or stash tracked changes before switching branches, so that Rojo never syncs a mix.
- `/compat-check` is not a gate. Run it after large changes, not before every commit.
