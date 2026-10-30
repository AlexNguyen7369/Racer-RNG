# Spawn area redesign (replaces the flat purple floor)

- **Type:** environment
- **Status:** draft (design proposal only, no code, no Blender file yet)
- **Blender file:** none yet; later `drafts/environments/spawn-area-redesign/paddock_props.blend`
- **Scale:** 1 Blender unit = 1 stud
- **Matches spec:** `docs/SPAWN_AND_ROLLS_SPEC.md` section 1, `src/shared/SpawnArea.luau`, `docs/WORKSHOP_SPEC.md`,
  `docs/CHECKPOINT_SPEC.md` section 2, `docs/BIOME_DRESSING_SPEC.md`, `docs/RENDERING_SPEC.md` section 2,
  `docs/WORLDS_SPEC.md` section 5

## What this is
The owner asked (2026-10-30) for "a spawn area design instead of the current purple". This draft describes the
spawn area today, offers three themes, recommends one with a layout plan, and lists the rules the owner must
write into the design doc and `SPAWN_AND_ROLLS_SPEC.md` before any code changes. Nothing here is a rule yet.

## 1. The spawn area today
All coordinates are local (x, z) of Track 1's flattened `Start` (local -Z is down the start straight, +X is right).
- `Floor`: one anchored `SmoothPlastic` Part, purple `SpawnArea.COLOR` (140, 70, 220), from `AREA_MIN` (24, -188)
  to `AREA_MAX` (252, 44), 228 x 232 studs, top at `TOP_Y` = 1, 3 studs thick. Low purple `Edge*` walls (2 high,
  1 wide) run along z = -188, z = 44 (with a gap where the pad crosses) and x = 252; the x = 24 road side is open.
- Hub: `HUB_MIN` (24, -100) to `HUB_MAX` (184, 44), 160 x 144, free of plots. The purple 12 x 12 `Spawn`
  (the only `SpawnLocation`) and the walk spawn sit at its centre, (104, -28).
- `StartPad`: green Neon (60, 220, 110), centred on `PAD_CENTER` (34.30, 28.50), footprint +/- (18, 22), under the
  `RaceStartPavilion` meshes (11 MeshParts, among them `RoofPurple`, `DeckTeal`, `CheckerPanels`) with cyan
  (80, 240, 255) `RaceGlow` lights. Its sign faces +X into the hub.
- Marketplace: 37 MeshParts from `SpawnMarketplace.rbxmx` (wood, red, gold, cyan, cream, amber), centred (50, -70),
  48 x 44 turned 90 degrees, so it covers about x 28..72, z -94..-46; the amber Neon `MarketPad` is (42..58, -76..-64);
  warm (255, 201, 117) lanterns.
- Four leaderboard signs (32 x 20, dark purple (28, 22, 48)) at z = 40, x = 72 / 104 / 136 / 168.
- Best Roll Ever pedestal (150, -70), radius 12, blue (40, 70, 190) and cream (255, 240, 170). Pass car stands
  (radius 6) at (162, -48) Ember Wyvern and (129, -84) Singularity.
- `CheckpointNpc` at (32, -6) on a purple Neon ring (190, 90, 255), facing the hub centre.
- Seven 48 x 48 workshop plots in an L: plots 1-4 at x 200..248 (z 36 down to -180), open to -X; plots 5-7 at
  z -180..-132 (x 144..192, 88..136, 32..80), open to +Z. Their fronts face a 16-stud strip (x 184..200) and a
  32-stud strip (z -132..-100) that are plain purple floor today.
- Nothing marks walkways, the plot fronts or a future portal; from the tracks the area reads as one purple slab.

## 2. Three themes

### Theme A: Pit-lane paddock plaza (recommended)
- **Idea:** the hub is the paddock behind a racing pit lane. The workshop plots become numbered pit garages, the
  StartPad pavilion is the pit exit, and a timing tower is the landmark seen from every track.
- **Palette:** paddock floor charcoal (64, 68, 78); walkway paint light grey (150, 156, 168); pit-lane surface
  dark asphalt (44, 46, 52); line white (235, 235, 235); kerb red (215, 45, 45) and white; accent teal
  (40, 200, 190, matches the pavilion `DeckTeal`); highlight amber (255, 190, 65, the existing `MarketPad`).
- **Materials:** floor `SmoothPlastic` today, `Concrete` if the owner allows (see question 2); paint overlays
  `SmoothPlastic`; tower and masts `Metal`; tyre stacks a mesh with a rubber texture; Neon only for the existing
  pads, the tower's top band and the portal ring.
- **Floor pattern:** charcoal base; painted 12-stud walkways from the spawn to the pad, market, portal and pit lane;
  a dark pit lane along the plot fronts with a white edge line and a red/white kerb strip on its hub side; a painted
  pit box (32 x 10, white outline, plot number) in front of each plot; a white starting-grid box around the spawn.
- **Landmarks:** a 40-stud timing tower; three floodlight masts; tyre-stack walls; a checkered pit-exit banner
  on the pavilion's hub side; red/white kerbs.
- **Lighting feel:** midday race-day paddock, lit by the global `LightingConfig` baseline only. Local lights: the
  existing pavilion and market lights plus at most 3 mast `SpotLight`s and 1 portal `PointLight`, all
  `Shadows = false`.
- **Ties it together:** walkways connect every station; plot fronts become pit boxes on one pit lane; the pavilion's
  teal and checkers become the theme accent; the market keeps its warm wood and amber as the "paddock shop"; the
  CheckpointNpc ring turns teal ("race control"); the portal stands at the end of its own walkway as a gantry.

### Theme B: Neon garage district
- **Idea:** a night-time tuner street. Plots are garages with roller doors and neon signs; the floor is wet street.
- **Palette:** street (30, 28, 44); kerb lines (90, 90, 110); neon cyan (60, 230, 255), magenta (255, 60, 200),
  lime (150, 255, 90).
- **Materials:** `SmoothPlastic` floor (a `Slate`-like wet look would need the material rule), many `Neon` strips.
- **Floor pattern:** a two-lane painted street through the hub, crosswalks at each station, neon edge strips.
- **Landmarks:** a rooftop sign arch over the spawn; vending-machine props; a neon-framed portal.
- **Lighting feel:** it only reads at night, but `LightingConfig` holds `ClockTime` 14.5 and props must not touch
  global Lighting, so it needs many local lights. That is costly on phones, and it fights the weather events.
- **Ties it together:** neon colour coding (cyan = race, amber = market, magenta = portal, lime = workshops).

### Theme C: Speedway park plaza
- **Idea:** a sunny fan plaza outside a stadium, in the green of Track 1's meadow.
- **Palette:** paving (226, 220, 206); grass beds (88, 140, 70, the Track 1 ground family); flower accents
  (250, 120, 90) and (255, 215, 80); bench wood (140, 100, 70).
- **Materials:** `SmoothPlastic` paving (or `Pavement`), `Grass` beds, wood benches, a trophy statue in `Metal`.
- **Floor pattern:** a circular plaza around the spawn with radial paths; planter beds between stations.
- **Landmarks:** a fountain with a giant trophy at the plaza edge; trees; a grandstand stub behind the leaderboards.
- **Lighting feel:** bright daytime. It suits the baseline best but has the weakest "car game" identity.
- **Ties it together:** paths radiate from the spawn; plots are garden garages; the portal sits in a hedge arch.

**Why A:** it matches what the player does (race, upgrade in a garage, roll cars). It reuses the pavilion's teal
and checkers and the market's amber, so no existing mesh must be rebuilt. It reads well in the daytime baseline,
and its landmarks are few large pieces, which are cheap on phones. B needs night lighting the rules do not allow
in World 1. C is pleasant but generic.

## 3. Recommended layout (Theme A)
Top view, local (x, z). Up is +Z (towards Track 1's finish), left is x = 24 (the Track 1 start straight).
```
 x=24        72       104       136       168  184 200          248 252
z=44 +--[PAD]--[LB 72 ]-[LB 104]-[LB 136]-[LB 168]--+----+-------------+  edge
     | PAD 16..52 |                                  | P  |  PLOT 1     |
     | z 6..50    |                                  | I  |  open -X    |
z=6  |   \walk                                       | T  +-------------+
     | CN(32,-6)   \        [GRID]                   |    |  PLOT 2     |
     |              ======= SPAWN (104,-28) ======== | L  |             |
z=-46| +--MARKET--+     /      |     WY(162,-48)     | A  +-------------+
     | | 28..72   |====/       |                     | N  |  PLOT 3     |
     | | (50,-70) |      |  BR(150,-70)              | E  |             |
     | +----------+  PORTAL     SG(129,-84)  TT(176,-92) |+-------------+
z=-100+--------------(96,-88)----------------------+----+  PLOT 4     |
     |============= PIT LANE z -132..-116, kerb at z -116 ============|  open -X    |
z=-132+--PLOT 7--+ +--PLOT 6--+ +--PLOT 5--+       |    |             |
     |  32..80  | | 88..136  | | 144..192 |  open +Z    |             |
z=-188+----------------------------------------------------------------+  M at 3 corners
```
Placed pieces (all inside `AREA_MIN..AREA_MAX`, none inside a plot rect, the pad, market or any stand):

| Piece | Centre (x, z) | Footprint | Height | Notes |
|---|---|---|---|---|
| Floor | unchanged | 228 x 232 | 3 thick | colour (64, 68, 78) |
| Spawn grid box | (104, -28) | 20 x 20 outline, 1-stud lines | 0.1 | `Spawn` itself unchanged in size and place |
| Walkway to pad | (104, -28) to (52, 20) | 12 wide | 0.1 | ends at the pavilion's 20-stud hub entrance |
| Walkway to market | (104, -28) to (72, -60) | 12 wide | 0.1 | |
| Walkway to portal | (104, -28) to (96, -82) | 12 wide | 0.1 | |
| Pit lane (vertical) | x 184..200, z 36..-132 | 16 wide | 0.1 | dark asphalt, white line at x 200 |
| Pit lane (horizontal) | z -132..-116, x 32..200 | 16 deep | 0.1 | white line at z -132 |
| Kerb strip | x 182..184 and z -116..-114 | 2 wide | 0.1 | red/white, 4-stud blocks |
| Pit boxes 1-7 | in the lane in front of each plot | 10 x 32 | 0.1 | white outline, plot number |
| Timing tower | (176, -92) | 6 x 6 | 40 | Neon teal top band, checkered faces |
| Floodlight masts | (249, 41), (249, -185), (28, -185) | 2 x 2 | 30 | 1 `SpotLight` each, `Shadows = false` |
| Tyre stacks | 3-stud strip x 248..251 behind plots 1-4 | 3 x 3 each | 3 | 12 stacks, one reused mesh |
| Pit-exit banner | pavilion hub side, above the entrance | 20 x 3 | top at 14 | checkered, on the pavilion's own frame |
| WorldPortal gantry | (96, -88) | 24 x 12 | 20 | reserved spot, built by the World 2 task |

- The `SpawnLocation` stays at hub centre (104, -28), the `StartPad` stays at `PAD_CENTER`, and plots and their open
  fronts are unchanged. The pit lane only paints the strips in front of the plots, so every plot front stays free.
- Flat paint (0.1 high, top at `TOP_Y + 0.05`) is `CanCollide = false`, so the floor still carries the player and
  overlays never trip anyone. Paint never covers the pads (pad tops are at `TOP_Y + 0.2` and `+ 0.15`).
- Tall pieces (tower, masts, portal posts, tyre stacks) use one invisible box boundary each, like
  `MarketplaceBuilder`, with `CanTouch = false`.
- Nothing extends past the floor footprint at any height. `BiomeDressing.Prune` already blocks the whole spawn area
  at every height, so its pruned region and every track's dressing stay the same. The nearest track parts are the
  Track 1 walls at x = +/-21; every new piece is at x >= 24 + 4, and the area never overlaps any road.
- No piece within 10 studs of the walk spawn is taller than 0.1, and no piece stands on a straight line from the
  spawn to the pavilion entrance, the market counters or a plot front.
- Retints (only with owner approval, question 3): `CheckpointNpc` ring (190, 90, 255) to teal (40, 200, 190);
  leaderboard sign backs (28, 22, 48) to charcoal (36, 38, 46); edge walls to the kerb red/white.

## 4. Rules the owner must write first (all "proposed")
These go into `docs/GAME_DESIGN_REQUIREMENTS.md` (spawn area entry) and `docs/SPAWN_AND_ROLLS_SPEC.md` section 1,
dated, before any code. Each value is a placeholder unless the owner fixes it.
1. **Proposed:** the spawn area theme is a pit-lane paddock plaza. It replaces the owner's 2026-10-01 brief
   "relatively large and purple for now".
2. **Proposed:** `SpawnArea.COLOR` becomes paddock charcoal (64, 68, 78). The `Spawn` part gets its own
   `SpawnArea.SPAWN_COLOR` (235, 235, 235, white with the grid box) instead of `COLOR`.
3. **Proposed:** the floor material is `Concrete`. This conflicts with `docs/RENDERING_SPEC.md` section 2 ("The
   spawn-area floor stays `SmoothPlastic`"), so either that line changes or the floor stays `SmoothPlastic`.
4. **Proposed:** a `Decor` folder under `Workspace.SpawnArea` holds every theme piece. Every decor part is anchored
   with `CanTouch = false`; flat paint is `CanCollide = false` and `CanQuery = false`; tall pieces collide only
   through box boundaries. No decor part lies inside a plot rect, the placed pad footprint, the marketplace
   footprint, a pedestal radius, or outside `AREA_MIN..AREA_MAX` at any height.
5. **Proposed:** decor never changes `Lighting`, `Atmosphere`, `Sky` or post effects (the World 1 rule). Local lights
   are capped at 4 new lights, all with `Shadows = false`.
6. **Proposed budget:** at most 250 new BaseParts and 20,000 triangles of new meshes in `Decor`.
7. **Proposed:** the World 1 `WorldPortal` pad stands at local (96, -88), 24 x 12, inside the hub, facing +Z.
   `docs/WORLDS_SPEC.md` section 5 gives no position today.
8. **Proposed:** the pit lane in front of the plots (x 184..200 and z -132..-116) stays free of any part taller
   than 0.1, so plot fronts are never blocked.

## 5. Open questions for the owner
1. Which theme: A (pit-lane paddock, recommended), B (neon garage) or C (speedway park)?
2. May the floor become `Concrete`? That means changing `RENDERING_SPEC.md` section 2. Otherwise it stays
   `SmoothPlastic` in the new colour.
3. May the purple accents that remain be retinted to the new palette: the pavilion's `RoofPurple` mesh (a colour
   change, no rebuild), the `CheckpointNpc` ring and the leaderboard sign backs?
4. Is (96, -88) the right spot for the World 1 portal, or should it sit closer to the spawn or the pad?
5. Is a 40-stud timing tower visible from the tracks acceptable, or should landmarks stay below the leaderboard
   signs (20 studs)?
6. The x = 24 road side has no edge wall today. Should it stay open, or get a low pit wall with a gap at the pad?
7. Should the World 2 hub reuse this theme in its own palette, or get its own design later?
8. Should the timing tower show live data (for example the hub's 7 plot owners), or stay purely decorative? This
   draft assumes decorative, because a live display is a new feature that needs its own spec.

## 6. Build plan (after the owner signs the rules)
- **Files:** `src/shared/SpawnArea.luau` (colours, `SPAWN_COLOR`, material, call a new builder);
  a new `src/shared/SpawnDecor.luau` (pure layout table plus builder, the `MarketplaceBuilder` pattern);
  `src/shared/CheckpointConfig.luau` or the `SpawnArea` ring colour; `src/shared/LeaderboardConfig.luau` or the sign
  colour in `SpawnArea` (only if question 3 is yes); `docs/SPAWN_AND_ROLLS_SPEC.md`, `ProjectContext.luau`,
  `tools/dashboard/data/todo.json`, `data/tests_explained.json` for the new check.
- **Art:** paint, kerbs, pit boxes and masts are plain Parts. The tower, tyre stack and portal gantry are meshes built
  through the Blender MCP in `paddock_props.blend`, at 1 unit = 1 stud. They go through the marketplace pipeline:
  upload, ids in a `SpawnDecorMeshAssets` module, an rbxmx in `assets/studio/`, and Box collision fidelity. The
  roof retint is a `Color` change in the existing rbxmx if the mesh has no texture; otherwise a texture swap.
- **Budget:** about 120 paint and kerb Parts, about 20 structural Parts, 4 meshes (tower 4,000 tris, tyre stack 600
  tris x 12 instances, mast 800 x 3, portal 6,000), so about 20,000 triangles and 140 Parts in total.
- **Phone note:** every player spawns here, so this area is always streamed in. Paint parts and small pieces have
  `CastShadow = false` (the `RENDERING_SPEC` rule for `Size.Magnitude` <= 30). Textures are at most 512 x 512, and
  one tyre mesh is reused. The new lights do not cast shadows. Check frame time on the phone emulator at
  844 x 390 before and after.
- **Tests that must stay green:** `spawn_area`, `workshop`, `environment` (prune, clearance and Lighting
  unchanged), the `leaderboard` best-roll and pass-car clearance checks, `npc`, `multiplayer`, the world tests in
  `WorldTests.luau`, and the UI suite's CheckpointUi and billboard checks run by `ui-tester`.
  `spawn_area` today pins `spawn_floor_purple`, `spawn_color` and `spawn_floor_smooth_plastic`. Only
  `test-writer` may change those, and only after the owner writes rules 2 and 3.
- **New check for test-writer (`spawn_decor`, red first):**
  - `Workspace.SpawnArea.Decor` exists, and its BasePart count and mesh triangle total are within rule 6.
  - Every decor part is anchored with `CanTouch = false`; paint parts are non-colliding.
  - No decor box overlaps a plot rect, the pad footprint, the marketplace box, a pedestal radius, the pit lane
    (if taller than 0.1), or the 10-stud spawn clearance.
  - Every decor box is inside `AREA_MIN..AREA_MAX` and clears every track road or wall by at least 4 studs.
  - `Lighting` and its children match the `LightingConfig` baseline after the build.
  - Two builds give the same decor names and CFrames.

## Left for full implementation
- The owner's choice of theme and answers to section 5, then the rules written into the docs.
- The Blender meshes, uploads and the rbxmx, the `SpawnDecor` module and the `spawn_decor` test.
- A screenshot pass from the walk spawn, from the pad and from Track 1's start straight.

## Notes
- Coordinates come from `SpawnArea.luau`, `WorkshopConfig.luau`, `MarketplaceBuilder.luau`,
  `LeaderboardConfig.luau`, `PassCarConfig.luau` and `CheckpointConfig.luau` as of 2026-10-30.
- The marketplace footprint (x 28..72, z -94..-46) is computed from its 48 x 44 size turned 90 degrees. Check it in
  Studio before placing walkways.
