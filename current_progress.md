# Current Progress

## Completed
1. 2026-10-01 — Alex Nguyen — Shared the Claude Code tooling with collaborators: test/compat subagents, slash commands, hooks and the main-branch compatibility gate (/compat-check, tools/compat.py, .githooks/pre-push).
2. 2026-10-01 — Alex Nguyen — Added the ui-test-writer subagent and made ui-tester run its UI compatibility tests during /compat-check.
3. 2026-10-01 — Alex Nguyen — Shipped the car gacha, index and stat points, NPC racers, admin chat commands and the UI test suite with an ALL GREEN /compat-check (harness 20/0, UI 12/0 + 16 clicks, multiplayer, world).
4. 2026-10-01 — Alex Nguyen — Created the `main` branch on GitHub from `initial-import` through the compat gate (stamp 076fe6662e79).
5. 2026-10-02 — Alex Nguyen — Shipped the purple spawn area with a walk-on StartPad, banked race winnings paid on Stop, turbo luck (every 10th roll x5) and the clickable roll showcase, plus a teleport-then-seat race start, with an ALL GREEN /compat-check (stamp 736c261dea05) on branch `feature/spawn-area-rolls`.
6. 2026-10-02 — Alex Nguyen — Merged `feature/spawn-area-rolls` into `initial-import` and `main` (fast-forward to d591441 through the compat gate, stamp 736c261dea05).

## What's next
**Enable Studio API access (Game Settings > Security) and verify real DataStore saving and loading of the version 3 save (Money, Speed, Cars, Equipped, Rolls, StatAlloc), including that banked winnings cashed out on leave are in the saved Money.**

**Why this is next:** every save/load path is still only tested against a fake store; the leave cash-out added in this release depends on the leave save, so real players could lose won money or gacha progress if it fails against the real DataStore, and later features (rebirths, workshop, car models) add more saved fields on top of it.
