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
  suggestions, "Needs you" tasks and every test explained.
- **Car art pipeline** in Blender (`CAR_MODELING_WORKFLOW.md`); the Rusty Hatchback is exported and awaiting import.

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

### In progress (2)

- **Money upgrade tree**: Design: docs/UPGRADE_TREE_DESIGN.md. Phase 1 GREEN 2026-10-05: UpgradeConfig + UpgradeTree implemented, `upgrades` 49/49 after a red run, audit OK. Next: phase 2 (UpgradeService, effects in Gacha/Car/RaceService, TurboCount, PlayerData v4) test-first; then UI (phase 3) and /compat-check.
- **Bring the Racer HUD into the repo**: Finalized source, UI specs, generator, atlas, settings icon and Studio UI snapshots added on studio/draft05-cars-ui. Rojo build and structural checks passed. Next: revise UiSpec for this layout, live-check and run full compat before merging.

### Up next (3)

- **Bottom HUD rework**: Draft05 HUD source and authored UI snapshots added on studio/draft05-cars-ui. Compile/build checks passed; full new-layout compatibility remains pending.
- **Vehicle skins on a shared physics body**: Draft05 cosmetic equipment source and seven imported templates added on studio/draft05-cars-ui; original physics chassis and seat retained. Full branch integration/compatibility remains pending.
- **Fix static_settle vertical jitter at rest**: Fails ~1 in 3 cold starts (up to 1.375 vs 0.5): the parked chassis gets periodic ~0.8 stud/s vertical kicks on its suspension. RollingDrag 1.0 did not fix it (it acts on the look axis). physics-tuner: spring/contact at rest in CarPhysics, through /car-loop.

### Backlog (future work) (6)

- **Test real DataStore saving**: Studio: Game Settings > Security > Enable Studio Access to API Services. Only a stubbed store is tested now.
- **Bring Circuit and Serpentine up to the track rules**: Through /build-track (test-first).
- **static_settle cold-start flake**: Failed 4 of ~8 cold starts (0.58-0.78 vs 0.5). DampingRatio raised to 1.0, not yet re-verified.
- **Live-check the NPC client view and LoserScreen**: ui-tester / multiplayer-tester have not checked them live.
- **Slack bot setup for test results**: Revoke the exposed token, install the app with bot scopes, re-add the MCP, post results after each green run.
- **Hill supports poke above the road**: world-tester: some Hill upslope support tops are up to 0.17 studs above the road surface (Support12 under right-lane waypoint 20). Small suspension bumps; track-designer via /build-track.

### Recently done (2)

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
