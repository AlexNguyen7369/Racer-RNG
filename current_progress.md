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
9. 2026-10-02 — Alex Nguyen — Drafted the Rusty Hatchback car model in Blender from a CC0 Poly Pizza asset (rusty restyle, game wheel naming) and set the vehicle-skins rule that any model can sit on a shared physics body (docs/VEHICLE_SKINS_SPEC.md).
10. 2026-10-02 — Alex Nguyen — Changed the roll animation spec and design doc so the compact auto roll shows only the car model with its "1 in N" odds and the stats card appears only when enlarged, and limited the current roll build to finishing its UI round and compat-check.
11. 2026-10-02 — Alex Nguyen — Specified that the compact roll animation is smaller (about 12% of screen width) and stays visible through every HUD click and open panel, with panels moved below it, in the roll animation spec and design doc.
12. 2026-10-02 — Alex Nguyen — Implemented the roll animation (bare-model compact roll under Auto Race, enlarged card with AUTO toggle, emphasized rolls announced in chat, panels moved below the roll) and pushed it to `main` on the owner's exception without a green /compat-check (harness roll tests green before decision 6; the final-design UI tests never completed a run).
13. 2026-10-05 — Alex Nguyen — Added the agent dashboard for all collaborators (tools/dashboard, /dashboard): compat gate light, live subagents and agent messages, changes and commit history, a shared TODO board, trend-based feature suggestions (/refresh-suggestions) and every test explained.

## What's next
**Resume the roll animation verification: run the full UI suite on the final design (decisions 4 and 6), fix RollToast and the Index/Stats panels until green, then the full harness and an ALL GREEN /compat-check.**

**Why this is next:** `main` now carries the roll animation unverified (see the URGENT block in context/ProjectContext.luau), and the bottom HUD rework and the upgrade tree's turbo tiers build on this roll UI, so it has to be proven green before anything else lands on top of it.
