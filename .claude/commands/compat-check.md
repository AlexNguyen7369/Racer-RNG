---
description: Full compatibility check of the whole game (harness + UI + other players + world/object physics + final regression). Must be ALL GREEN before anything is pushed or merged to main.
argument-hint: "[what changed, optional]"
---

Run the full compatibility check for the current code. Changes since the last green run: $ARGUMENTS

This is the gate for `main`: `.claude/hooks/compat-gate.py` blocks `git push` to main and `gh pr merge` from Claude, and `.githooks/pre-push` blocks the push in git itself, unless `tools/compat.py` holds an ALL GREEN stamp for exactly this code (`src/` + `default.project.json`). The Stop hook asks for this run whenever shipped code changed. Run it after every change, not only before a push.

## Suites (all five required, all must be green; regression runs last)
| Suite | Who | Covers |
|---|---|---|
| `harness` | `physics-tester` | every scenario in `TestConfig.Scenarios` + every `track:*`: car physics, tracks, race, NPC races, money, data, HUD formatting, toggle, multiplayer (fake players) |
| `ui` | `ui-tester` | every ScreenGui / BillboardGui live on the client: exists, shows the server's truth, no overlaps |
| `multiplayer` | `multiplayer-tester` | other players' perspective: per-player NPCs and state, pass-through, remotes fire to their owner only |
| `world` | `world-tester` | objects and physics in the live world: anchoring, collision groups, nothing falls or blocks cars, NPC ghosts |
| `regression` | `regression-tester` | final focused smoke/regression pass over changed behavior and previously working paths; runs only after the four suites above are green |

## Steps
1. **Preconditions.** `mcp__Roblox_Studio__list_roblox_studios` lists the project's Studio, and Rojo is synced (a distinctive line of a recently changed file matches in Studio). `stylua --check src` and `selene src` are clean. Only ONE run may use Studio at a time: if another session or agent is running the harness or restarting play (`[CARTEST] START` lines you did not trigger, or play restarts), stop and tell the user. Never kill someone else's run.
2. **Fingerprint.** `python3 tools/compat.py fingerprint`: note it. Do not edit `src/` during the run; if anything in `src/` changes, the run is void.
3. **Harness.** Restart play so the server runs the current code, then launch `physics-tester` for the FULL suite. Wait for `[CARTEST] END pass=N fail=N`.
5. **Prerequisite verdict.** Copy each of the four live-suite results exactly from the agents' final lines (`... SUITE: GREEN` / `RED`, harness `fail=0`). Never launch `regression-tester` unless harness, UI, multiplayer, and world are all green and the fingerprint still matches step 2.
6. **Final regression.** Keep the same play session and launch `regression-tester` only after step 5 is green. It must end with `REGRESSION SUITE: GREEN` or `REGRESSION SUITE: RED`; blocked or missing evidence is not green.
7. **Verdict.** Write `.compat/results.json`:
   `{ "suites": { "harness": { "pass": <END fail=0>, "end_line": "<exact END line>", "summary": "..." }, "ui": { "pass": ..., "summary": "..." }, "multiplayer": {...}, "world": {...}, "regression": { "pass": <REGRESSION SUITE: GREEN>, "summary": "..." } } }`
   Copy each `pass` exactly from the agents' final lines. Never mark a suite green that was skipped, partial or interrupted.
8. Check that `python3 tools/compat.py fingerprint` still equals step 2. Then run `python3 tools/compat.py record .compat/results.json`. It refuses unless all five suites are green and the END line says `fail=0`.
9. **Not green:** route the failures like `/build-track` and `/car-loop` (tests to `test-writer`, tracks to `track-designer`, car to `physics-tuner`, race, UI and server code fixed by the caller and then audited by `test-writer`), then run `/compat-check` again from step 1. No round cap; three identical red rounds means change strategy, then escalate to the user.
10. **Always** update `context/ProjectContext.luau` TEST RESULTS with the date, the fingerprint (first 12 characters), each suite's verdict and what is unverified.

Rules: never edit tests or `PhysicsTargets.luau` to get green (only `test-writer` adds or tightens). Never hand-write `.compat/green.json`. Never bypass the hooks (`--no-verify`, a changed `core.hooksPath`, editing the gate) without the user explicitly asking.
