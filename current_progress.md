# Current Progress

## Completed
1. 2026-10-01 — Alex Nguyen — Shared the Claude Code tooling with collaborators: test/compat subagents, slash commands, hooks and the main-branch compatibility gate (/compat-check, tools/compat.py, .githooks/pre-push).
2. 2026-10-01 — Alex Nguyen — Added the ui-test-writer subagent and made ui-tester run its UI compatibility tests during /compat-check.
3. 2026-10-01 — Alex Nguyen — Shipped the car gacha, index and stat points, NPC racers, admin chat commands and the UI test suite with an ALL GREEN /compat-check (harness 20/0, UI 12/0 + 16 clicks, multiplayer, world).
4. 2026-10-01 — Alex Nguyen — Created the `main` branch on GitHub from `initial-import` through the compat gate (stamp 076fe6662e79).
5. 2026-10-02 — Alex Nguyen — Shipped the purple spawn area with a walk-on StartPad, banked race winnings paid on Stop, turbo luck (every 10th roll x5) and the clickable roll showcase, plus a teleport-then-seat race start, with an ALL GREEN /compat-check (stamp 736c261dea05) on branch `feature/spawn-area-rolls`.

## What's next
**Merge `feature/spawn-area-rolls` into `initial-import` and `main` (PR or fast-forward through the compat gate, stamp 736c261dea05).**

**Why this is next:** the spawn area, banking and roll showcase only exist on the feature branch; collaborators pulling `initial-import`/`main` won't get them, and the next work (real DataStore verification, car models for the showcase) should build on the merged code.
