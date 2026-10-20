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
4. **Gate:** a themed arch over the road on the track's first straight. It stands at waypoint `GATE_INDEX` (4), or at the theme's `Gate.Index` when that spot is not clear (Track 1 uses 18, past the spawn-area floor). It marks the biome change along the chain.
5. **Ambient motion (client only):** `Client/BiomeAmbience` spins parts tagged `BiomeSpin` and bobs parts tagged `BiomeBob`. It only animates props within `AMBIENCE_DISTANCE` (300 studs) of the camera. Server parts never move.
6. **Ground:** the theme sets the track's `Ground` material and colour.

## Rules

- Props are visual only: `Anchored`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`.
  Small props have `CastShadow = false`.
- **Clearance:** after the whole chain and the spawn area are built, `BiomeDressing.Prune` removes every
  prop whose box, grown by `CLEARANCE` (placeholder 8 studs) on every side, touches a road, wall,
  checkpoint or win pad part of ANY track, or the spawn area. The gate follows the same rule. Its posts
  stand outside the clearance, and its beam spans the road at `GATE_HEIGHT` (placeholder 28) studs, high
  above the road and walls.
- **Budget (placeholder):** at most 400 BaseParts per track `Environment` folder.
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
- In Blender (1 unit = 1 stud): origin at the base centre, forward -Z, about 8-15 props per theme, at most 2k triangles per prop.
  Export one FBX per theme to `assets/meshes/biomes/<Biome>.fbx`, with each prop named `<Biome>_<Prop>`.
  Keep a draft per theme in `drafts/environments/<biome>/DRAFT.md`.
- The owner uploads the FBX files with Studio's 3D Importer. The mesh ids go into `Shared/BiomeMeshAssets`
  (`{ [<Biome>_<Prop>] = "rbxassetid://..." }`). `BiomeDressing` loads them with
  `AssetService:CreateMeshPartAsync`, the same way as `MarketplaceBuilder`, and scales each one to the
  prop's size. If a mesh has no id or fails to load, the prop is a plain part built from its `Fallback`, so the track always builds.

## Acceptance (harness scenario `environment`)

For every chain track: an `Environment` folder exists and the `Biome` attribute is set; every BasePart in it is
anchored and has `CanCollide`, `CanTouch` and `CanQuery` false; after `Prune` no prop is within `CLEARANCE` of any road,
wall, checkpoint, pad or spawn-area part; the part count is within the budget; two builds give the same prop names
and CFrames; and `Lighting` is unchanged. The full harness (chain, race, laps, npc) stays green.
