# Idle Vehicle Simulator

A Roblox idle racing game where everything feeds one number: **Speed**.

## Project vision

Idle Vehicle Simulator is about watching a number climb and making smart bets to make it climb faster. Players
earn Speed while their car races on its own, race NPCs for Money, roll for faster cars, spend Money on
multipliers, and eventually rebirth for bigger permanent boosts.

**Design pillars** (from `Idle Vehicle Simulator — Game Design Requirements.pdf`):

- **Speed is the score.** Every system either raises Speed gain or is unlocked by it.
- **Progress while idle.** Auto-racing, auto-rolling and (later) the workshop keep paying out while the player is AFK.
- **Push your luck.** Race winnings are banked during a run and lost on a defeat; cashing out is a choice.
- **Resets that feel huge.** Each rebirth wipes Money and Speed but makes the next run dramatically faster.

**The loop:** idle for Speed, race to turn Speed into Money, spend Money on multipliers, roll for faster cars,
then rebirth at a level milestone.

```
Auto race / workshop ──Speed/sec──▶ SPEED ──▶ Race the NPC ladder ──cash out──▶ MONEY
        ▲                                                                         │
        │                     multipliers ◀── upgrades, fuel, auras, spoilers ◀───┘
        ├──────── car multi ◀── auto-roll car gacha (luck, turbo rolls)
        └──────── rebirth multis + stat points ◀── level milestones ◀── XP from Speed
```

**Principles we hold to:**

- **The server decides every number** (Speed, Money, rolls, race results); the client only displays.
- **The car never flips and never leaves its route**, at any stat speed. Tests enforce it.
- **Nothing reaches `main` without a green compatibility check** (`/compat-check`: physics harness, UI, multiplayer, world).
- **Test-first** for every track and every car-physics change (`/build-track`, `/car-loop`).

## Features implemented

Current worktree additions (2026-10-07) still require live compatibility verification: five-track chain,
workshop E upgrades and exact offline earnings, Workshop stat allocation, the hex money-upgrade panel and
hub pad, plus server weather events and three event-only car variants. Local formatting, lint, compilation
and builds pass; these additions are not a current ALL GREEN stamp. See
[workshop defaults](docs/WORKSHOP_SPEC.md) and [event rules](docs/WEATHER_EVENTS_SPEC.md).

### Draft05 UI and car handoff

The redesigned Racer UI, original car icon atlas, seven rounded Blender car models, uploaded Studio templates, and local place snapshot are included in this branch. See [the handoff notes](docs/DRAFT05_HANDOFF.md) for synchronization and validation limitations before merging or publishing.

### Racing
- **Auto race:** the player's avatar becomes a small blocky car that the server drives along a chain of
  point-to-point tracks (Track 1 Oval, Track 2 Hill), looping back to Track 1 after the last finish. Real
  raycast-suspension physics (`CarPhysics`) steered by `PathDriver` in the right-hand lane.
- **Track rules:** numbered ladder, separate start and finish, each finish is the next track's start, a wide
  checkpoint area with a yellow `$` winnings pad, validated by `TrackValidator` (min radius, closure, no overlap).
- **NPC racers:** one per track (Track 1 red and very easy, faster on every later track), driving the left lane,
  visible only to their owner. Beat the NPC to the finish or lose the run and go back to Track 1.
- **Banked winnings:** each won track adds its pad value to the run's bank (UNBANKED in the HUD); a loss empties
  it, and Stop, death or leaving pays it out.
- **Stability:** flip watchdog that rights the car on the path; tests check up-vector and path deviation at
  normal and maximum stat speed.

### Progression and economy
- **Speed stat** grows while driving, proportional to actual speed with diminishing returns; cruise speed rises
  with the stat up to a cap. Smooth count-up HUD on the left.
- **Money** from race winnings, scaled by track number and the Money multi.
- **Saving:** `PlayerData` saves Money, Speed, cars, equipped car, rolls and stat allocation (save version 3).
- **Upgrade tree, phase 1:** pure rules and numbers (`UpgradeConfig`, `UpgradeTree`) for Luck %, roll speed,
  Speed %, turbo tiers, walkspeed and Money %. Server effects and UI are still to come (see TODO).

### Car gacha
- **Free auto-roll** every 3 seconds; rarer cars are checked first with `min(1, luck / chance)`.
- **Seven cars:** Rusty Hatchback (Common) to Void Racer (Secret, 1 in 100,000), each with a Speed multi.
- **Turbo luck:** every 10th roll gets x5 luck, with a filling turbo bar and a "TURBO x5!" pop.
- **Roll animation and showcase:** compact roll toast, click to open a big card with the car model, odds, rarity
  and multi; emphasized rolls announced in chat.
- **Index and stat points:** discovering cars earns stat points to spend on Speed, Money and Luck multis.

### World and UI
- **Spawn area:** purple floor beside Track 1's start; walk onto the green RACE pad (or press Auto Race) to start.
- **HUD and panels:** Speed HUD, Auto Race button, Index and Stats panels, turbo bar, roll toast and showcase,
  loser screen.
- **Admin chat commands:** `/help /money /addmoney /speed /addspeed /give /equip /roll /wipe /tp` for admins only.

### Tooling
- **Test harness** (24 scenarios: physics, tracks, money, race, NPC, bank, gacha, data, admin, multiplayer...)
  and a **UI test suite** checking overlap, hitboxes and that every button does what it shows.
- **Claude Code subagents and slash commands** for test-first track and physics loops and the compat check.
- **Main-branch gate:** `.githooks/pre-push` refuses a push to `main` unless `/compat-check` was ALL GREEN for
  exactly that code.
- **Agent dashboard** (`/dashboard`): subagent progress, changes, commits, compat light, TODO board, feature
  suggestions, "Needs you" tasks and every test explained. Supports workspace-filtered Codex sessions
  alongside Claude, plus a local read/write client (`python3 tools/dashboard/client.py`).
- **Car art pipeline** in Blender (`CAR_MODELING_WORKFLOW.md`); the Rusty Hatchback and the six other Draft05 cars are in the game (`assets/studio/CarModels.rbxm`, shown in rolls and as the racing car's look).

## Future features

The live work queue is the TODO section below. Beyond it, the design document plans these layers:

| Layer | What it adds |
|---|---|
| Upgrade tree (phases 2-3) | Server effects, PlayerData v4 and the hex-tile upgrade UI |
| Mechanical Workshop | A personal base zone that earns Speed while you stand in it, with money upgrades |
| More environments | City, Desert, Snow, Volcano, Space: each a ladder of tracks with faster NPCs |
| Cash out or continue | A real gamble after each win: take the pot home or risk it on a harder race |
| Money shop | Fuel, auras and spoilers, each a Speed multiplier with a visual |
| Levels and rebirth | XP from Speed, rebirths at level milestones, Rebirth Points for permanent stats |
| Vehicle skins | Any car model welded on a shared physics body (`docs/VEHICLE_SKINS_SPEC.md`) |
| Offline earnings | A welcome-back payout for time away, so the AFK kick feels like a reward |
| Monetization | Gamepasses (2x auto-roll, extra rolls, Speed Doubler, 2x Money, luck), Server Luck, odds display and paid-luck compliance |

## TODO

Generated from the team TODO board (`tools/dashboard/data/todo.json`, also shown in the agent dashboard). It
updates automatically whenever the board changes; do not edit this block by hand.

<!-- TODO:START (generated by tools/readme_sync.py from tools/dashboard/data/todo.json; edit the board, not this block) -->

### In progress (20)

- **UI tests for Isaac's Racer UI**: Owner decision 2026-10-06: the merged Racer UI (RacerHud/Index/Stats/Settings/Rebirth, new RollShowcase) is the UI spec. ui-test-writer rewrites UiSpec/UiScenarios for it (old SpeedHud/AutoRaceButton/IndexUi/StatsUi/RollUi tests are obsolete). Then update CLAUDE.md HUD rules (Speed now bottom centre) and docs/ROLL_ANIMATION_CONTRACT.md, and run /compat-check. Blocks the green stamp for the money tree + workshop round.
- **Mechanical Workshop: 7 plots in the spawn area**: Spec: docs/WORKSHOP_SPEC.md. Phase 1 (2026-10-06) IMPLEMENTED, NOT VERIFIED: spawn floor grown to 228 x 232 with the old floor kept as the hub, 7 plots (WorkshopConfig), each joining player gets the lowest free plot with a level-1 workshop, empty plots show EMPTY PLOT, server-side zone check pays idle Speed (BASE_RATE 1/s x Speed multi x W x Workshop points, same diminishing term as racing), WorkshopLevel saved in PlayerData v4. Next: full harness in Studio (`workshop`, `spawn_area`, `data`), world-tester walk check. Open: BASE_RATE, level prices, offline earnings.
- **Workshop phase 2: HUD line, level upgrades, offline earnings**: IMPLEMENTED 2026-10-08, NOT FULLY VERIFIED: WorkshopRate HUD, owner E prompt/modal, guarded next-level purchase, enabled Workshop points, ten configurable levels (level 2 $500, later costs x5, gain x2), exact 25% offline gain capped at 8h, atomic OfflineAt claims and welcome panel. test-writer added workshop_offline/workshop_phase2; ui-test-writer added progression and purchase checks. Full Studio tests blocked by execute_luau approval policy never; real DataStore access disabled. Pricing remains configurable pending owner feedback.
- **Money upgrade tree**: Design: docs/UPGRADE_TREE_DESIGN.md. Phase 1 historical GREEN; server effects and PlayerData v4 present. Phase 3 IMPLEMENTED 2026-10-08, NOT FULLY VERIFIED: hex scrolling tree, truthful prices/gates/owned states, UPGRADES badge, exclusive panel, feedback and hub world pad. UI tests authored; current sources synced and UI ready. Full harness, UI clicks and compatibility blocked by execute_luau approval policy never. No current ALL GREEN stamp.
- **Bottom HUD rework**: Draft05 HUD source and authored UI snapshots added on studio/draft05-cars-ui. Compile/build checks passed; full new-layout compatibility remains pending.
- **Vehicle skins on a shared physics body**: Draft05 cosmetic equipment source and seven imported templates added on studio/draft05-cars-ui; original physics chassis and seat retained. Full branch integration/compatibility remains pending.
- **Test real DataStore saving**: Studio: Game Settings > Security > Enable Studio Access to API Services. Only a stubbed store is tested now.
- **Bring Circuit and Serpentine up to the track rules**: Through /build-track (test-first).
- **Fix static_settle vertical jitter at rest**: Fails ~1 in 3 cold starts (up to 1.375 vs 0.5): the parked chassis gets periodic ~0.8 stud/s vertical kicks on its suspension. RollingDrag 1.0 did not fix it (it acts on the look axis). physics-tuner: spring/contact at rest in CarPhysics, through /car-loop.
- **Bring the Racer HUD into the repo**: Finalized source, UI specs, generator, atlas, settings icon and Studio UI snapshots added on studio/draft05-cars-ui. Rojo build and structural checks passed. Next: revise UiSpec for this layout, live-check and run full compat before merging.
- **Review and merge Isaac's studio/draft05-cars-ui (Draft05 cars + Racer UI)**: Isaac Li (@issacli), 2 commits on 2026-10-06, 2 ahead / 0 behind main. Adds 7 Blender cars (assets/studio/CarModels.rbxm), redesigned Racer UI under RollToast (8 UI modules + StarterGui.rbxm), Shared/CarAppearance (cosmetic model welded on the physics chassis; CarService applies it on spawn and on EquippedCar change), and default.project.json maps CarModels + StarterGui and disables 5 legacy client scripts. Not compat-checked (his handoff says so). Overlaps our uncommitted CarService, ProjectContext, README, todo.json; git conflict with current_progress.md. His branch does not touch src/client/UiTest, and UiSpec still expects the IndexUi / StatsUi / AutoRaceButton ScreenGuis whose scripts he disables, so the UI suite will likely fail until ui-test-writer updates it. Handoff: docs/DRAFT05_HANDOFF.md on his branch. MERGED into initial-import 2026-10-06 (conflicts only in notes files). Fixed on merge: Racer HUD turbo bar now reads the upgrade tree's TurboCount / TurboEvery. Next: ui-test-writer rewrites UiSpec for the Racer UI, then full /compat-check.
- **Show roll rarity as odds**: IMPLEMENTATION STARTED: the roll animation and roll announcement now use HudFormat.Odds, including `1 in ?` for catch-all cars. Full Studio compatibility still pending.
- **Add an Upgrade slab outside each workshop**: After the current compatibility check passes and changes are pushed, place a clearly labeled `UPGRADE` slab outside each player's workshop area. Keep the presentation readable and visually integrated with the workshop.
- **Draft Track 3 as a short straight drag race**: IMPLEMENTATION STARTED: added Shared/Tracks/DragRace.luau as a short straight Number 3 segment chained after Hill, with a sunset palette. Full route and Studio validation still pending.
- **Begin implementing the upgrade tree**: After the current compatibility check passes and changes are pushed, begin the upgrade-tree implementation: define the progression, costs, effects, persistence, and UI/world interaction. Coordinate with the workshop upgrade economy so costs and Speed/s effects do not conflict.
- **Add an aesthetic Race-area overhang for manual auto racing**: IMPLEMENTATION STARTED: SpawnArea now builds an open RaceOverhang canopy with posts, neon trim, and a readable RACE sign around the manual StartPad. Full Studio walk check still pending.
- **Move roll controls into the top-centre roll animation**: IMPLEMENTATION STARTED: bottom HUD roll controls are hidden, the compact top-centre roll remains the entry point, and AUTO remains in the enlarged showcase. Compatibility scenario inventory updated.
- **Add a top-down auto-racing camera setting**: IMPLEMENTATION STARTED: Settings exposes a local TOP-DOWN VIEW toggle; during auto racing the client tracks the car from above, mouse-wheel changes height, and the normal camera is restored afterward. Live camera validation still pending.
- **Theme Tracks 01, 02, and 03 with distinct palettes**: IMPLEMENTATION STARTED: TrackBuilder accepts per-track palettes; Oval is red/grey with checkered accents, Hill is teal/cyan, and DragRace is sunset purple/orange. Full Studio visual check still pending.
- **Rotating weather / biome events that boost luck**: Every 10-20 minutes a server-wide event runs for a few minutes (Rain: x2 luck, Night Race: NPCs faster but pads pay x2, Gold Rush: Money x3). A banner and a skybox / lighting change show it; some cars can only be rolled during an event. Fits this game: Rolling is free and automatic, so events give players a reason to stay online at a given moment. Plugs straight into GachaConfig luck and MoneyService multipliers. Inspired by: Sol's RNG biomes, Grow a Garden weather events

### Up next (0)

_Nothing here right now._

### Backlog (future work) (6)

- **static_settle cold-start flake**: Failed 4 of ~8 cold starts (0.58-0.78 vs 0.5). DampingRatio raised to 1.0, not yet re-verified.
- **Live-check the NPC client view and LoserScreen**: ui-tester / multiplayer-tester have not checked them live.
- **Slack bot setup for test results**: Revoke the exposed token, install the app with bot scopes, re-add the MCP, post results after each green run.
- **Hill supports poke above the road**: world-tester: some Hill upslope support tops are up to 0.17 studs above the road surface (Support12 under right-lane waypoint 20). Small suspension bumps; track-designer via /build-track.
- **Automatic bus delivery for Codex**: Claude receives bus messages via a hook; Codex only when it follows AGENTS.md and runs agent_bus.py context. If the Codex CLI's hook support covers session start / prompt submit, wire `agent_bus.py hook --agent codex` there. Also: edits made via shell commands (sed, heredoc, python rewrites) are not attributed; consider attributing via git diff snapshots per tool call.
- **Implement workshop upgrades with E interaction**: After the current compatibility check passes and changes are pushed, let the owner approach the Upgrade slab and press E to open an upgrade modal. Show the next workshop level and required Money; increase workshop Speed/s exponentially as level rises, with a correspondingly increasing cost. Define and document the exact progression before implementation.

### Recently done (5)

- ~~Codex dashboard integration~~ (2026-10-07)
- ~~Claude <-> Codex bus and per-change agent/model labels~~ (2026-10-06)
- ~~Dashboard Team tab: GitHub sync, labelled feature branches, collaborator overview~~ (2026-10-06)
- ~~Import the Rusty Hatchback into Studio~~ (2026-10-06)
- ~~Verify the roll animation (UI suite, harness, /compat-check)~~ (2026-10-05)

<!-- TODO:END -->

## Getting started

Needs Roblox Studio with the Rojo plugin and the Roblox Studio MCP, plus `stylua`, `selene` and `python3`
(and the Blender MCP for art work).

```
git config core.hooksPath .githooks   # once per clone (Claude Code does this for you)
rojo serve                            # then click Connect in Studio's Rojo plugin
stylua src                            # format
selene src                            # lint
python3 tools/dashboard/server.py     # agent dashboard at http://127.0.0.1:8765
```

Run the test harness during play with `ReplicatedStorage:SetAttribute("CarTestRun", true)`; results print as
`[CARTEST]` lines in the Studio console.

## Project layout

| Path | What lives there |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared`: car physics and config, tracks, gacha and upgrade rules |
| `src/server` | `ServerScriptService.Server`: race, car, money, gacha, upgrade, admin services, saving, test harness |
| `src/client` | `StarterPlayerScripts.Client`: HUD, panels, roll UI, NPC view, UI tests |
| `docs/` | Feature specs (spawn and rolls, NPC racers, admin commands, roll animation, upgrade tree, vehicle skins) |
| `tools/` | Compat gate (`compat.py`), agent dashboard, README sync |
| `blender/`, `assets/`, `references/`, `drafts/` | Car art pipeline and rough drafts |
| `context/ProjectContext.luau` | Collaborator context synced into Studio: rules, change log, latest test results |

More detail for contributors and Claude Code is in `CLAUDE.md`; progress history is in `current_progress.md`.
