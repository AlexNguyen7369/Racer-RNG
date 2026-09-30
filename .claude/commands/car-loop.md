---
description: Run the car physics loop (test-first) until every scenario is green. For track builds use /build-track.
argument-hint: "[what to fix or add, e.g. 'car understeers' or 'add handbrake drift test']"
---

Run the physics development loop for: $ARGUMENTS

Same rules as `/build-track` (read `.claude/commands/build-track.md`), without `track-designer`. The auto-race system (`PathDriver`, `RaceService`, `RaceConfig`) counts as car work: its `race` scenario must stay green, and any `CarConfig`/`CarPhysics` change must be re-checked against it, and against the stability rules in `CLAUDE.md` (never flip/tilt, stay on the path, at max stat speed too):
1. `test-writer` (WRITE mode) adds the failing check for the request in `Scenarios.luau` / `PhysicsTargets.luau`. `physics-tester` confirms it is red.
2. Loop: `physics-tuner` edits `CarConfig.luau` -> `test-writer` AUDIT -> `physics-tester` on the FULL suite. Repeat.
3. Exit only when a full run ends `[CARTEST] END fail=0`. No round limit; same progress guard (identical failures three rounds in a row means change strategy, then escalate to the user).
4. At exit (and after every full run) update `context/ProjectContext.luau` (change log, dated results, known issues) and tell the user it lives at `ServerScriptService > ProjectContext`.
5. `PhysicsTargets.luau` values are game-feel decisions: only `test-writer` may add new ones, and nobody may loosen an existing one to get green.
