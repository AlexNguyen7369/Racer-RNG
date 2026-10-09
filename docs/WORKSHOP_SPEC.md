# Mechanical Workshop and plots

Status: phases 1 and 2 implemented; full compatibility and real DataStore persistence remain unverified.
The 2026-10-08 harness passed workshop, workshop_offline and workshop_phase2; its data scenario failed one
level-boundary expectation and is under audit. Originally drafted 2026-10-06 from the design doc and owner's brief.
Numbers marked *placeholder* are tunable in `Shared/WorkshopConfig` and remain pending owner balancing feedback.

## Owner's brief (2026-10-06)
- Start the Mechanical Workshop, with a dedicated area in the spawn area for players' workshops.
- Every player in the server has their own plot of land in the spawn area.
- **7 plots, all in the spawn area; servers hold at most 7 players** (one plot per player, always enough).
- A player's workshop loads when they join. With one player in the server: 1 plot with their workshop, 6 empty plots.
- For now everyone gets the starter workshop (level 1).

## From the design doc (requirements)
- Every player gets their own workshop at their base; server size matches the number of plots.
- Speed is earned **only while the player stands inside their workshop zone**; leaving the zone stops the gain.
- Gain per second uses the full Speed formula including the workshop multi W.
- Money upgrades raise W in big jumps (*placeholder*: each level doubles W and costs 5x the last). Gold / Diamond / Void
  gamepasses add a permanent W boost (monetization, later).
- The zone check is done **on the server on a timer** from the character's position, never from client touch events.
- The `Workshop` stat point (`Alloc_Workshop`, +0.2x per point, `GachaConfig.PER_POINT`) boosts workshop gain only.
- Offline earnings: 25 % of workshop gain, capped at 8 h, with a welcome-back screen (phase 2 implemented).

## 1. Layout (`Shared/SpawnArea` + `Shared/WorkshopConfig`)
All positions are local (x, z) of Track 1's flattened Start, like the rest of the spawn area. Track 1 (Oval) turns LEFT
(-X) at z = -240 and Track 2 runs along z ~ 90, so the area can grow outward (+X) and forward (-Z) without touching a road.

| Constant | Old | New |
|---|---|---|
| `SpawnArea.AREA_MIN` / `AREA_MAX` (the purple floor) | (24, -100) / (184, 44), 160 x 144 | **(24, -188) / (252, 44), 228 x 232** |
| `SpawnArea.HUB_MIN` / `HUB_MAX` (new: the old floor, kept free of plots) | | (24, -100) / (184, 44) |
| Walk spawn / `Spawn` part | centre of the area | **centre of the HUB** (unchanged position: (104, -28)) |
| `StartPad` | (-20, 2) / (24, 38) | unchanged |
| Upgrade pad (upgrade tree phase 3) | ~(150, -70) | unchanged, inside the hub |

Edges move to the new outer sides (far z = -188, near z = 44, outer x = 252); the side facing the road stays open.

**Plots** (`WorkshopConfig.PLOT_SIZE = 48`, 8-stud gaps, 4 studs from the edges). Index order = assignment order:

| Plot | local x | local z | Opens toward (front) |
|---|---|---|---|
| 1 | 200 .. 248 | -12 .. 36 | -X (the hub) |
| 2 | 200 .. 248 | -68 .. -20 | -X |
| 3 | 200 .. 248 | -124 .. -76 | -X |
| 4 | 200 .. 248 | -180 .. -132 | -X |
| 5 | 144 .. 192 | -180 .. -132 | +Z (the hub) |
| 6 | 88 .. 136 | -180 .. -132 | +Z |
| 7 | 32 .. 80 | -180 .. -132 | +Z |

Rules (tests): plots never overlap each other, the hub, the Spawn, the StartPad or any road / wall / checkpoint of any
chained track; every plot lies inside the floor; walking from the spawn to every plot is unobstructed (no edge or wall
between the hub and a plot's open front).

## 2. Plots and workshops in the world
`Workspace.Workshops` (Folder) holds `Plot_1` .. `Plot_7` (Models), built by `Server/WorkshopService.Start` after the
spawn area:
- `Base`: anchored slab covering the plot, slightly darker than the floor, top a hair above the floor (no z-fight).
- `Sign`: a `BillboardGui` (finite `MaxDistance`): **"EMPTY PLOT"** when free, **"<DisplayName>'s Workshop"** when owned.
- Attribute `Owner` (UserId, 0 when free), tag `WorkshopPlot`.
- When owned, a `Workshop` model of the owner's level (`Shared/WorkshopBuilder.Build(level, plotCFrame)`), level 1 = the
  starter workshop: concrete floor, back and side walls with an OPEN FRONT facing the hub, a roof frame (beams only,
  so the camera never clips), a workbench and tyre stack props, and a neon outline marking the `Zone`.
  - `Zone`: invisible, `CanCollide = false`, `CanQuery = false`, `CanTouch = false` part showing the gain zone
    (`WorkshopConfig.ZONE_SIZE` = 32 x 12 x 32, centred in the plot). The server uses the maths rect, not the part.
  - A `BillboardGui` `Rate` above the zone: "+N Speed/s" (the owner's rate, server-written text).

## 3. Assignment (`Server/WorkshopService`)
- **Join:** after `PlayerData` finishes loading, the player gets the lowest free plot (`Plot` attribute on the
  player = index) and their workshop is built at their saved level. If the load failed, they still get a plot (level 1)
  but nothing is saved (PlayerData rule).
- **Leave:** the workshop is removed and the plot goes back to "EMPTY PLOT" (after the save).
- **Full server** (should not happen with Max Players = 7): no plot, attribute `Plot = 0`, no workshop gain. Logged.
- One plot per player, one player per plot, never two (a plot whose owner is gone is freed on the next assignment).

## 4. Speed gain (server only)
Every `WorkshopConfig.TICK` (0.5 s) for each player with a plot:
- In the zone = alive character, NOT auto-racing (`CarService.IsAutoRacing` false), HumanoidRootPart inside the zone
  rect (x, z) and between the floor and `ZONE_SIZE.Y` above it. Sets player attribute `InWorkshop`.
- While in the zone: `PlayerData.AddSpeed(player, rate * dt)`, with
  `rate = BASE_RATE x GachaService.SpeedMulti(player) x LevelMulti(level) x WorkshopPointsMulti / (1 + stat / RaceConfig.GAIN_SOFT)`
  - `BASE_RATE` = 1 Speed/s (*placeholder*, design doc "B")
  - `SpeedMulti` = equipped car x (Speed points + upgrade tree Speed %), the same multi racing uses
  - `LevelMulti` = W of the workshop level (level 1 = 1)
  - `WorkshopPointsMulti` = `GachaConfig.Multis(alloc).Workshop` (1 + 0.2 per point)
  - divided by the same diminishing-returns term racing uses, so idling and racing climb the same curve and cruise speed
    (`RaceConfig.SpeedFor`) still never passes `MAX_SPEED` (stability rules untouched)
- Player attribute `WorkshopRate` = the current rate (shown on the plot's `Rate` billboard and HUD line).
- Leaving the zone stops the gain at the next tick. Nothing a client sends changes the rate or the zone check.

## 5. Levels and purchases
`WorkshopConfig.Levels`: level 1 = `{ Multi = 1, Price = 0 }` (starter), with ten configurable levels.
Level 2 costs $500; each later price is 5x the previous price and W doubles at each level. These defaults are not
approved balancing. Saved as `WorkshopLevel` (PlayerData VERSION 4, shared with the upgrade tree's fields).
An owned workshop has an `UPGRADE` slab and E prompt. Its modal requests the next level only; the server validates
loaded data, ownership, a living on-foot character within 12 studs, available level and Money, and rate-limits
remote requests. Invalid numbers (including NaN and infinities) load as level 1; finite levels floor and clamp to 1..10.

## 6. Manual step
Studio: Game Settings > Places > Server Size (Max Players) = **7** (Rojo can not set it). Listed on the dashboard
"Needs you" tab.

## 7. Tests (written first by test-writer / ui-test-writer)
- `spawn_area` (updated for the new area): floor (24, -188)..(252, 44), hub constants, spawn at the hub centre, edges on
  the new outer sides, still no overlap with any track.
- `workshop` (new): 7 plots with the table's rects, no overlaps (plots, hub, spawn, StartPad, tracks), plot opens toward
  the hub; assignment (lowest free, freed on leave, one plot each, 8th player gets 0); the `Workshop` model and signs
  ("EMPTY PLOT" / owner name); zone gain on the server (in zone gains `rate x dt`, out of zone / auto-racing / dead
  gains 0); the rate formula with car, Speed points, Workshop points and the diminishing term; `WorkshopLevel` save.
- `data`: VERSION 4 round trip including `WorkshopLevel` (missing = 1, out of range clamped).
- World (`world-tester`): plots and workshop parts anchored, nothing blocks walking from the spawn to a plot.

## 8. Phases
1. **Plots + starter workshop + idle gain** (implemented): WorkshopConfig, layout, WorkshopBuilder, WorkshopService,
   PlayerData v4 field, tests above.
2. Workshop HUD line, level upgrades bought with Money (configurable defaults pending owner feedback), offline earnings
   and the welcome-back screen.
3. Gold / Diamond / Void passes (monetization).

## Phase 2 implementation defaults (2026-10-07)

Ten levels are configured, with level 2 costing $500 and subsequent prices growing ×5. Every level doubles W. These are configurable defaults pending owner feedback, rather than a record of approved balancing. The E prompt on an owned plot opens the upgrade modal; the server checks load state, ownership, life, racing state, distance and Money before buying the next level. No client price or requested level is accepted.

The HUD shows the server's current workshop rate, and Workshop stat allocation is enabled. Offline earnings integrate the diminishing gain formula at 25%, capped at eight hours. Saves include `OfflineAt`; an atomic DataStore claim persists the credited Speed and new timestamp before exposing rewards. Missing or invalid legacy timestamps grant no offline reward. Repeated loads do not replay rewards or reset live progress. The welcome panel reports the credited Speed and capped duration. Workshop harness scenarios passed on the synced sources; UI diagnostics, full compatibility and real-store verification remain pending.

## Open questions for the owner
- `BASE_RATE` (1 Speed/s now; driving at base speed gains ~1.5/s): should idling beat racing for Speed?
- Level prices and how many levels; do workshop levels reset on rebirth?
- Offline earnings: yes/no, percent and cap.
