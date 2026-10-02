# Current Progress

## Completed
1. 2026-10-01 — Alex Nguyen — Shared the Claude Code tooling with collaborators: test/compat subagents, slash commands, hooks and the main-branch compatibility gate (/compat-check, tools/compat.py, .githooks/pre-push).
2. 2026-10-01 — Alex Nguyen — Added the ui-test-writer subagent and made ui-tester run its UI compatibility tests during /compat-check.
3. 2026-10-01 — Alex Nguyen — Shipped the car gacha, index and stat points, NPC racers, admin chat commands and the UI test suite with an ALL GREEN /compat-check (harness 20/0, UI 12/0 + 16 clicks, multiplayer, world).
4. 2026-10-01 — Alex Nguyen — Created the `main` branch on GitHub from `initial-import` through the compat gate (stamp 076fe6662e79).
5. 2026-10-02 — Alex Nguyen — Shipped the purple spawn area with a walk-on StartPad, banked race winnings paid on Stop, turbo luck (every 10th roll x5) and the clickable roll showcase, plus a teleport-then-seat race start, with an ALL GREEN /compat-check (stamp 736c261dea05) on branch `feature/spawn-area-rolls`.
6. 2026-10-02 — Alex Nguyen — Merged `feature/spawn-area-rolls` into `initial-import` and `main` (fast-forward to d591441 through the compat gate, stamp 736c261dea05).
7. 2026-10-02 — Alex Nguyen — Queued the money upgrade tree (Luck %, roll speed to 2 s, Speed %, turbo x10-x1000, walkspeed, Money %) with a confirmed design spec in docs/UPGRADE_TREE_SPEC.md and RNG Heroes references.
8. 2026-10-02 — Alex Nguyen — Queued the roll animation and roll UI with the owner's decisions (emphasized rolls, global chat announce, compact card under Auto Race, click-anywhere to close) in docs/ROLL_ANIMATION_SPEC.md, and aligned the design doc's turbo rules with the game.

## What's next
**Build the roll animation and roll UI from docs/ROLL_ANIMATION_SPEC.md (in progress in a parallel session): compact card under Auto Race, enlarged reveal with click-anywhere to close, emphasized rolls with the global chat announce.**

**Why this is next:** a parallel session has already started it against this spec, and the bottom HUD rework (Garage, ROLL, Upgrades) and the upgrade tree's turbo tiers both plug into the roll UI it builds, so its layout has to land first.
