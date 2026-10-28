# Biome dressing: drive-by scenery for every track

Owner decision 2026-10-20: every track has its own visual theme, and real low-poly CC0 assets
from kenney.nl and itch.io dress it so the auto-driven car gives an immersive drive-by. This
spec follows the design doc "Racing" > "Track environments". It replaces the "Environment rules"
in `TRACKS_6_10_SPEC.md` and keeps every rule there.

## Themes

`spec.Biome` names the theme. `Shared/BiomeThemes` holds the data and `Shared/BiomeDressing` builds it.

| # | Track | Biome | Rhythm (roadside) | Landmarks (turns, climbs) | Horizon |
|---:|---|---|---|---|---|
| 1 | Oval | `Speedway` | tyre stacks, flags | grandstands, pit garages | stadium light towers |
| 2 | Hill | `Forest` | pines, rocks | log cabin, lookout tower | tree hills |
| 3 | DragRace | `Docks` | lamps, cones | cranes, warehouses | smokestacks |
| 4 | Circuit | `Suburb` | hedges, streetlamps | houses, gas station | rooftops |
| 5 | Serpentine | `PirateCoast` | palms, barrels | ships, lighthouse | islands |
| 6 | City | `City` | streetlights, signs | towers, billboards | skyline |
| 7 | Desert | `Desert` | cacti, rocks | mesas, windmill | canyon walls |
| 8 | Snow | `Snow` | snowy pines, snowmen | cabins, ice cliffs | peaks |
| 9 | Volcano | `Volcano` | basalt spikes, glow cracks | lava falls, crater | volcano cone |
| 10 | Space | `Space` | pylons, light strips | domes, dishes | planets |

Prop lists, sizes, colours and spacing are placeholders that can be tuned.

## Layers

1. **Rhythm:** small props repeat along both sides of the road at a steady waypoint spacing, so the player feels the car's speed.
2. **Landmarks:** one hero prop at the middle of each corner, on the outside of the turn, and one at the top of each climb. These are where the car slows down or the view opens up.
3. **Horizon:** large silhouettes far out on the outside of each corner, so a new view opens as the car comes round.
4. **Gate:** a themed arch over the road on the track's first straight. It stands at waypoint `GATE_INDEX` (4), or at the theme's `Gate.Index` when that spot is not clear (Track 1 uses 18, past the spawn-area floor; Track 2 uses 9, past the race-start pavilion). It marks the biome change along the chain. **Sign (owner 2026-10-21):** a `SurfaceGui` on the `GateSign` faces the oncoming car and shows the biome name (big) and `REC. SPEED <n>` using a universal 1x cruise baseline, independent of the equipped car or aura. The number is the base Speed whose cruise speed equals `NpcConfig.For(Number).Speed`, inverted from `RaceConfig.SpeedFor`, formatted like the HUD Speed. Visual only, like the rest of the gate.
5. **Ambient motion (client only):** `Client/BiomeAmbience` spins parts tagged `BiomeSpin` and bobs parts tagged `BiomeBob`. It only animates props within `AMBIENCE_DISTANCE` (300 studs) of the camera. Server parts never move.
6. **Ground:** the theme sets the track's `Ground` material and colour.
7. **Scatter (owner 2026-10-26):** fills the ground beyond the rhythm so the view is never an empty plain. Theme
   `Scatter = { Every, Near, Far, Props, Patches }`. Every `Every` waypoints, on each side, one prop stands between
   `Near` and `Far` studs from the road edge; the waypoint index picks the prop, its distance and its yaw (no
   randomness). Every other spot also lays a flat ground patch from `Patches` (`{ Name, Size, Color, Material }`: a
   slab 0.2 studs thick on the ground, such as flowers, dirt, puddles, lava pools or ice). Scatter is built last and only
   fills what the budget leaves, so it never displaces the other layers. A scatter prop may reuse a rhythm or landmark
   prop (same table, so the same mesh).
8. **Particles (owner 2026-10-26):** theme `Particles` (one `ParticleEmitter` setting per biome: fireflies, dust,
   snowfall, embers, star twinkle ...). One emitter per landmark, on its first part, named `BiomeParticles`, with
   `Rate` at most `PARTICLE_MAX_RATE` (placeholder 8 per second). Built-in particle textures only. Particles are local
   to the landmark: no screen-wide or Lighting effect.
9. **Blocks (owner 2026-10-27, populated city):** theme `Blocks = { Spacing, Near, Rows, RowDepth, Props }` lines both
   sides of the road with street-wall rows of low-rise buildings. Walking the road centre line, a slot opens every
   `Spacing` studs on each side; row r (1..`Rows`) stands `Near + (r - 1) * RowDepth` studs beyond the road edge, the
   front face toward the road. The slot, side and row pick the prop (no randomness). A building is skipped when its
   footprint overlaps one already placed in this layer (inside corners), and the usual ground and clearance rules
   apply; landmarks and horizon pieces count as placed, so a row breaks around a tower. Blocks are built after the
   rhythm and before the scatter, unscaled; City scatter starts beyond the second row.
   **Every biome (owner 2026-10-27, giant scenery):** every theme has a `Blocks` layer. The City's rows are its
   low-rise street walls; every other biome's rows hold giant props, 40 to 130 studs tall (giant trees, rock
   pillars, floodlight towers, gantry cranes, sea stacks, ice spires, basalt columns, crystal spires ...), spaced
   wider than the City so gaps show the small rhythm and scatter props between them: a mix of small and big. Giants
   use few, large parts so they fit the normal `BUDGET`. Sizes, spacing and rows are placeholders.

## Rules

- Props are visual only: `Anchored`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`.
  Small props have `CastShadow = false`.
- **Clearance:** after the whole chain and the spawn area are built, `BiomeDressing.Prune` removes every
  prop whose box, grown by `CLEARANCE` (placeholder 8 studs) on every side, touches a road, wall,
  checkpoint or win pad part of ANY track, or the spawn area. The gate follows the same rule. Its posts
  stand outside the clearance, and its beam spans the road at `GATE_HEIGHT` (placeholder 28) studs, high
  above the road and walls. **Oriented boxes (2026-10-26):** the test is an oriented-box (separating axis)
  overlap of each prop part, grown in its own axes, against each blocker part, the same test as the acceptance
  scenario. The earlier axis-aligned shortcut removed about half the roadside props beside diagonal roads.
- **Horizon fit (2026-10-26):** a horizon piece that does not fit on its track's ground at its `Offset` moves in
  toward the road (3/4, 1/2, then 1/3 of `Offset`, never nearer than the landmark `Offset`) before it is skipped.
- **Short tracks (2026-10-26):** landmark spacing starts at `min(Landmarks.Every, #waypoints // 2)` and horizon
  spacing at `min(HORIZON_EVERY, #waypoints // 2)`, so a short straight track (Track 3) still gets both.
- **Theme budget (owner 2026-10-27, placeholder):** a theme may set its own `Budget`, which replaces `BUDGET` for its
  track. City: 2600, for the Blocks layer.
- **Budget (placeholder):** at most 1200 BaseParts per track `Environment` folder (owner 2026-10-27: was 800, and
  400 before 2026-10-26; bigger scenery in mass and the detailed City towers need the room).
- **Scale (owner 2026-10-27, placeholders):** `BiomeDressing.SCALE` grows every prop of a layer, parts and offsets
  within the prop alike: Landmarks x1.75, Horizon x2, Scatter x1.5. Rhythm and the gate keep their sizes (the
  rhythm sits beside the wall and is the speed cue). A baked mesh follows its prop's scaled height. Placement
  distances are measured to the scaled footprint, so clearance and the on-ground rule are unchanged.
  A horizon piece that does not fit on its ground at any `HORIZON_FIT` offset shrinks by 0.25 steps toward x1
  and tries again (Track 2's 160-stud tree hills only fit at about x1.25).
- **City skyscrapers (owner 2026-10-27):** City landmarks, scatter blocks and the skyline are built by
  `BiomeThemes`' `skyscraper` helper: a podium with a glass lobby on the road side, one or two setback tiers, a glass
  window band every few studs on each tier, corner and centre fins, a neon crown ring and rooftop equipment (AC
  units, an antenna with a lit tip, and a water tower or spire by variant). They have no baked mesh (the Kenney
  skyscraper meshes were plain).
  The City billboards stand in the scatter layer, so every City landmark is a skyscraper.
- **On the ground (owner 2026-10-20):** a prop is only placed when its whole footprint lies on its own track's
  `Ground`; a prop that would hang past the ground's edge is skipped, so nothing floats over the void or the Baseplate.
- **Deterministic:** no randomness. Variety comes from the waypoint index, so two builds are identical.
- **No global lighting:** dressing never changes `Lighting`, `Atmosphere`, `Sky` or `Terrain.Clouds`
  (weather owns those, `WEATHER_EVENTS_SPEC.md`). Glow comes only from Neon parts and from local
  `PointLight`s with `Shadows = false`.
- No hazard, and no change to grip, gravity, payout, NPC or race results.

## Assets

- **CC0 only.** Before use, check each pack page. Record its URL, author, license and download date in
  `references/biome_packs/SOURCES.md` and keep its license file. Raw downloads are git-ignored.
- Candidate packs (check at download time): Kenney Racing Kit, Car Kit, Nature Kit, Mini Forest,
  City Kit (Roads / Commercial / Suburban / Industrial), Factory Kit, Pirate Kit, Holiday Kit, Modular
  Cave Kit, Space Kit, Modular Space Kit; on itch.io KayKit City Builder Bits / Space Base Bits and
  Quaternius nature / space packs.
- `blender/biomes/export_biome_props.py` runs Blender headless with `drafts/environments/biome-props/props.json`
  (prop -> pack model and height). For each prop it: scales to the height (1 unit = 1 stud, origin at the base
  centre), decimates to at most 600 faces, bakes one 256 px colour texture, and writes:
  `assets/meshes/biomes/<Biome>.fbx` (reference / manual import), `textures/<Biome>_<Prop>.png`, and the
  geometry as data in `Shared/BiomeMeshData/<Biome>` (generated, do not edit).
- Textures are uploaded with the Studio MCP image upload. `blender/biomes/write_texture_ids.py` writes the ids to
  `Shared/BiomeMeshAssets`.
- **Runtime meshes (2026-10-20; the tooling has no mesh upload):** the server builds every prop
  from its fallback parts. When the prop has mesh data, the server also adds an invisible `MeshBounds` part at
  the mesh's real size (scaled to the prop height, proportions kept), the attribute `Mesh = "<Biome>_<Prop>"` and
  the tag `BiomeMesh`. `Prune` and placement use that real size. `Client/BiomeMeshes` builds each mesh with
  `EditableMesh` (a fixed-size copy, to save memory) only while a prop using it is within `LOAD_DISTANCE`
  (placeholder 450 studs) of the camera, nearest first. It shows the mesh in `MeshBounds` (the decoded geometry is centred on its own box, because a MeshPart keeps the
  mesh origin as its centre and the baked origin is the prop's base), hides the fallback
  locally, and destroys the mesh when no prop that uses it is in range. If the client's editable memory budget
  is full, the fallback stays visible.
- Published games need **Mesh / Image APIs** enabled in the experience settings (Security). Without it, the
  fallback parts show.
- **Ground step:** overlapping track grounds sit `GROUND_STEP` (0.02 studs) x track number lower, so that
  their themed colours never z-fight.

## Acceptance (harness scenario `environment`)

For every chain track: an `Environment` folder exists and the `Biome` attribute is set; every BasePart in it is
anchored and has `CanCollide`, `CanTouch` and `CanQuery` false; after `Prune` no prop is within `CLEARANCE` of any road,
wall, checkpoint, pad or spawn-area part; the part count is within the budget; two builds give the same prop names
and CFrames; and `Lighting` is unchanged. The full harness (chain, race, laps, npc) stays green.
Added 2026-10-26: after `Prune` every track keeps at least one landmark, at least one horizon piece and at least
10 scatter props (`Scatter_*`) and 5 ground patches (`Patch_*`); every patch is at most 0.2 studs thick and sits on its
track's ground top; every `ParticleEmitter` in an Environment is named `BiomeParticles`, sits inside a `Landmark_*`
model (one at most per landmark) and has a `Rate` of at most 8.
