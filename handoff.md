# Agent handoff

This file is the short, durable bridge between agent sessions. Read it at the
start of every session. Update it before context limits, pausing, or handing
work to another agent. Keep entries factual and concise; link to files and
include exact commands when they matter.

## Session goal

- Implement the spawn-area Market from the design document.
- Provide both a physical proximity interaction and a right-side Market button.
- Sell and equip aura/trail items, persist ownership, apply their visual effects
  to the car, and multiply base/cruise speed.

## Active files

- `src/shared/SpawnArea.luau` — physical Market pad and prompt.
- `src/shared/MarketConfig.luau` — aura/trail catalog and speed multiplier.
- `src/shared/VehicleEffects.luau` — replicated aura/trail car visuals.
- `src/server/MarketService.luau` — server purchase/equip validation and remotes.
- `src/server/PlayerData.luau` — version 5 persistence fields.
- `src/server/CarService.luau` — applies effects to spawned cars and refreshes them.
- `src/server/RaceService.luau` — applies aura multiplier to cruise targets.
- `src/client/MarketUi.client.luau` — Market button and purchase/equip modal.
- `src/server/Main.server.luau` — starts MarketService.
- `src/server/CarTest/Scenarios.luau`, `src/server/CarTest/Phase2Tests.luau` — save-version expectations.

## Changes made

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
- Updated save-version test expectations and notified Claude through the bus.
- Preserved Claude's active UI files; the only overlapping tracked test diff is
  the required save-version update from 4 to 5.

## Failed attempts / blockers

- The first live `client.py` check found no dashboard process listening; the
  documented `--no-fetch --no-auto-branch` server was started and verified.
- No source blockers known. Live Roblox Studio visual/gameplay checks and the
  full `/compat-check` suites remain to be performed by a developer/tester.
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

5. Refresh this file with the current goal, active files, changes, failures,
   and exact next steps before the session ends or reaches its limit.

## Last handoff

- Updated: 2026-10-08
- Owner: Codex
- State: expanded market implementation and fresh Studio validation complete;
  full compatibility suite remains a separate developer gate.
- Validation: Stylua and selene passed with 0 errors/0 warnings; Rojo built
  `default.project.json`; `git diff --check` passed. Dashboard/agent-bus access
  was permission-blocked while attempting the required live check; the final
  static checks and Rojo build pass after formatting, the anchored-preview fix,
  and the compact card layout fix.
