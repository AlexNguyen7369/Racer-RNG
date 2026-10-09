# Agent handoff

This file is the short, durable bridge between agent sessions. Read it at the
start of every session. Update it before context limits, pausing, or handing
work to another agent. Keep entries factual and concise; link to files and
include exact commands when they matter.

## Session goal

- Record, commit, and push all current worktree changes on `main` at the owner's
  explicit request, bypassing the green compatibility gate for this delivery.

## Active files

- `src/shared/SpawnArea.luau` — physical Market pad and prompt.
- `src/shared/MarketConfig.luau` — aura/trail catalog and speed multiplier.
- `src/shared/VehicleEffects.luau` — replicated aura/trail car visuals.
- `src/server/MarketService.luau` — server purchase/equip validation and remotes.
- `src/server/PlayerData.luau` — version 6 persistence fields.
- `src/server/CarService.luau` — applies effects to spawned cars and refreshes them.
- `src/server/RaceService.luau` — applies aura multiplier to cruise targets.
- `src/client/MarketUi.client.luau` — Market button and purchase/equip modal.
- `src/server/Main.server.luau` — starts MarketService.
- `src/server/CarTest/Scenarios.luau`, `src/server/CarTest/Phase2Tests.luau` — save-version expectations.
- `src/shared/RebirthConfig.luau`, `src/server/RebirthService.luau` — prestige thresholds, reset, and multiplier.
- `src/shared/BoostConfig.luau`, `src/server/BoostService.luau` — saved timed potion inventory and remotes.
- `src/shared/DailyLoginConfig.luau`, `src/server/DailyLoginService.luau` — UTC streak rewards and claim.
- `src/client/RollToast/RacerUiController.luau`, `src/client/RollToast/init.client.luau`, `src/client/BoostDailyUi.client.luau` — progression presentation.

## Changes made

- 2026-10-09 delivery snapshot: the worktree contains the progression systems
  (Level/XP, rebirth, boosts, daily login), Market potion inventory/purchases,
  duplicate-roll Money payouts, workshop offline Money, Hill support geometry,
  Racer UI/roll-toast updates, and their related shared/server/client configs.
- The snapshot also includes updates to `README.md`, the three gameplay specs,
  dashboard `manual.json`, `suggestions.json`, and `todo.json`, plus these new
  source files: `src/client/BoostDailyUi.client.luau`,
  `src/server/BoostService.luau`, `src/server/DailyLoginService.luau`,
  `src/server/LevelService.luau`, `src/server/RebirthService.luau`,
  `src/shared/BoostConfig.luau`, `src/shared/DailyLoginConfig.luau`, and
  `src/shared/LevelConfig.luau`.
- The owner explicitly authorized committing and pushing the complete current
  worktree on `main` with the pre-push compatibility hook bypassed. This is an
  exception, not a green compatibility result; the current source still needs
  a fresh Studio/Rojo run and reconciliation of stale test expectations.

- Previous session added the persistent handoff workflow and dashboard Handoff
  tab; those changes are already present and must be preserved.
- Expanded `MarketConfig` with Azure, Ember, and Galaxy auras plus Rainbow, Solar,
  and Void trails. Each item now has an accent color and description.
- Added `MarketService` purchase/equip remotes and save/load fields (data
  version 5), plus `MarketUi.client.luau` with a right-side button and modal.
- Added a physical `SpawnArea.MarketPad` with a ProximityPrompt.
- Added `VehicleEffects` so brighter aura orbs, rings, orbit particles, trail
  ribbons, and trail sparks are welded to the replicated car chassis; applied
  aura multiplier to RaceService cruise targets.
- Reworked `MarketUi.client.luau` into Fuel Type folder navigation with Trails
  and Aura sections. Each card now includes a small ViewportFrame projection of
  the effect before purchase/equip; preview geometry is anchored so it remains
  visible in the modal. Card spacing now uses a compact responsive layout so
  preview, description, and action controls remain usable at narrower widths.
- Added save VERSION 6 fields for rebirth, boosts, and daily login.
- Rebirth resets Money only, preserves Speed, and requires the design Level
  milestone; cars, upgrades, market, and workshop remain intact.
- Replaced category-only potions with Luck/Money/Speed I, II, and III tiers.
  Every tier lasts exactly 60 seconds, is server-owned, saved, buyable, and usable
  inside the Bag modal. Legacy category save keys remain readable.
- Replaced the compact potion/daily buttons with a Bag modal and a seven-day
  Daily Rewards modal. The daily modal is manual while the UTC timer runs and
  auto-opens when the next claim window begins.
- Boost multipliers feed server-side luck, Money payout, and passive Speed gain.
- Track wins now award one deterministic potion (Luck/Money/Speed cycling by
  track), and the compact boost UI refreshes active countdown timers every second.
- Corrected sloped Hill support placement: support tops now use the lowest road
  underside across each piece minus 0.05 studs of clearance. Full track/world
  validation is still pending because Studio is not Rojo-synced.
- Duplicate Gacha rolls award base Money by rarity (Common $100 through Secret
  $250,000) and the roll card displays the awarded amount.
- Offline workshop claims now atomically credit capped Speed plus Money at 10% of
  the integrated Speed result; `OfflineMoney` is replicated and shown in the
  welcome panel. `docs/WORKSHOP_SPEC.md` and dashboard TODO text describe it.
- Updated `docs/SPAWN_AND_ROLLS_SPEC.md` and
  `docs/ROLL_ANIMATION_CONTRACT.md` to document the duplicate-roll
  `scrapMoney` payload and direct Money semantics. Daily login UI now reports
  potion and guaranteed-rare rewards in its claim result.
- Asked Claude through the bus to have test-writer update save-version expectations
  and add focused scenarios; no test files were edited in this session.

## Failed attempts / blockers

- 2026-10-09: the dashboard API was unavailable (`Connection refused`), so
  dashboard state could not be refreshed; the local agent bus remained usable.
- 2026-10-09: no current green compatibility stamp exists for this source
  fingerprint. The requested push is therefore being performed with
  `git push --no-verify` as an explicit owner exception.

- The first live `client.py` check found no dashboard process listening; the
  documented `--no-fetch --no-auto-branch` server was started and verified.
- 2026-10-08 current-source Studio Play verification completed after Rojo
  reconnect. CarTest ended `pass=24 fail=7`; gameplay/race/bank/track/gacha
  paths passed. Remaining failures are stale index multiplier expectations,
  two offline persistence assertions, and weather catalog-equip fixtures.
  UiTest ended `pass=16 fail=6`; remaining failures are stale label/HUD
  expectations, while animation, progression, workshop, weather, and layout
  scenarios passed. Six manual checks are MCP limitations.
  On 2026-10-08 the dashboard client and documented server startup both failed
  with local `Operation not permitted` socket/lock errors.
- A connected Studio Play session was inspected on 2026-10-08: the server had
  the MarketPad, prompt, remotes, and saved Azure/Rainbow equipment, but its
  client still had the pre-folder MarketUi and its replicated MarketConfig had
  only one aura/trail. The Play session was restarted; a fresh client-side
  inspection was unavailable because the Studio execute tool then required a
  disallowed approval. Runtime acceptance therefore remains pending a Rojo
  resync plus a fresh Play check.
- 2026-10-08 fresh Play verification after restarting the Rojo server: live
  `MarketConfig` has 3 auras and 3 trails; the client MarketUi has Fuel Type,
  TrailFolder, and AuraFolder nodes; all three Trail cards and all three Aura
  cards contain anchored ViewportFrame previews; the MarketPad/prompt/remotes
  exist; and the running StarterCar has AuraGlow, AuraRing, AuraParticles,
  AuraOrbit, a Trail instance, AuraLight, and TrailSparks attached to the car's
  effect folder/chassis attachments.
- 2026-10-08 progression static verification: StyLua and Selene report 0 errors/
  0 warnings; `rojo build default.project.json --output /tmp/racer.rbxmx` and
  `git diff --check` pass. Studio validation for the new remotes and save fields
  remains pending.
- 2026-10-08 Studio re-audit: the available Play/Edit place still has only the
  previous Market-era server tree and no RebirthService/BoostService/
  DailyLoginService. `rojo serve default.project.json` is running on localhost:
  34872, but the Studio Rojo plugin needs to reconnect before a live run can
  represent this worktree. The manual dashboard task `rojo-connect` was reopened.
- A Studio unit-test subagent was asked to update VERSION 6 expectations and add
  focused progression scenarios, but returned a generic error with no result or
  file changes. The on-disk expectation remains `DATA_VERSION = 5` in
  `src/server/CarTest/Scenarios.luau`.
- Offline Money is live-verified for exact integral, replay prevention,
  repeated load, stale/future/malformed timestamps, and failed atomic claim;
  two legacy persistence-capture assertions still fail.
- Current Studio Play server tree contains `RebirthService`, `BoostService`,
  and `DailyLoginService`; the source is now synced and live-tested.
- Rojo remains reachable at `localhost:34872`, and `rojo sourcemap` confirms all
  progression services/configs and `BoostDailyUi` are mapped from the worktree.
  Dashboard integration tests pass (`13` tests).
- 2026-10-09: Studio visibility issue traced to no running Rojo process. Restarted
  `rojo serve default.project.json`; verified the live server at `localhost:34872`
  and confirmed the source map contains the progression services/configs and Bag UI.
  Studio must reconnect the Rojo plugin and start a fresh Play session.
- 2026-10-09: Reworked inventory ownership: Market now has a Potion category with
  all Luck/Money/Speed I/II/III purchases and routes them through BoostService into
  saved Bag counts. Bag is inventory-only: it shows only owned or active potions and
  only offers Use; no purchase controls or unowned rows remain.
- 2026-10-09: Read `Idle Vehicle Simulator — Game Design Requirements.pdf` and
  replaced the provisional BestTrack rebirth gate with the designed Level/XP
  system. Level starts at 1, XP uses `1 * sqrt(Speed)` per second, thresholds are
  `100 * 1.15^(level-1)`, and rebirth milestones are 10/25/50/75/100/every 25.
  Added saved `Level`/`XP` fields (VERSION 7), server LevelService ticks in race
  and workshop, and updated the Rebirth panel to show the player-level gate.
- 2026-10-09: Added the permanent rebirth Luck multiplier: +10% roll Luck per
  rebirth level, alongside the +10% passive Speed-gain multiplier. GachaService
  applies it server-side and the Rebirth panel displays both next-rebirth bonuses.

## Specific next steps when resuming

1. Run `python3 tools/dashboard/agent_bus.py context --agent codex` (or the
   Claude equivalent) and inspect collaborator activity before editing.
2. Read `AGENTS.md`, `CLAUDE.md`, and this file; preserve files listed as active
   in another agent's status.
3. In Studio, verify Market button and E prompt open the same modal, buy/equip
   with enough Money, the aura/trail appear on the car, and the aura changes
   cruise speed by exactly 1.25x relative to the same Speed/car state.
4. Run `/compat-check` (or the repository's equivalent full suites) before
   merging; the current static checks passed.
5. Verify Rebirth, potion purchase/use/expiry, daily streak claim/reset, and
   duplicate rarity payout in Studio; then rerun the full gate with VERSION 6.

5. Have the test-writer reconcile the stale index/weather/UI expectations with
   the owner contract; investigate the two offline persistence-capture checks
   without editing tests in Codex.
6. Refresh this file with the current goal, active files, changes, failures,
   and exact next steps before the session ends or reaches its limit.

## Last handoff

- Updated: 2026-10-09
- Owner: Codex
- State: all current worktree changes are recorded for the requested commit and
  push. Progression features, track-win potion rewards, offline Money, and Hill
  support geometry are implemented; fresh Studio validation and test-writer
  reconciliation remain required.
- Validation: prior static checks passed, but no current green compatibility
  stamp exists for this source fingerprint; the owner authorized bypassing the
  pre-push gate for this delivery.
