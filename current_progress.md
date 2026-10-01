# Current Progress

## Completed
1. 2026-10-01 — Alex Nguyen — Shared the Claude Code tooling with collaborators: test/compat subagents, slash commands, hooks and the main-branch compatibility gate (/compat-check, tools/compat.py, .githooks/pre-push).
2. 2026-10-01 — Alex Nguyen — Added the ui-test-writer subagent and made ui-tester run its UI compatibility tests during /compat-check.
3. 2026-10-01 — Alex Nguyen — Shipped the car gacha, index and stat points, NPC racers, admin chat commands and the UI test suite with an ALL GREEN /compat-check (harness 20/0, UI 12/0 + 16 clicks, multiplayer, world).
4. 2026-10-01 — Alex Nguyen — Created the `main` branch on GitHub from `initial-import` through the compat gate (stamp 076fe6662e79).

## What's next
**Enable Studio API access (Game Settings > Security) and verify real DataStore saving and loading of the version 3 save (Money, Speed, Cars, Equipped, Rolls, StatAlloc), including an old version 2 save.**

**Why this is next:** every save/load path is only tested against a fake store; the gacha inventory and stat points are lost for real players if PlayerData's v3 format fails against the real DataStore, and later features (rebirths, workshop) add more saved fields on top of it.
