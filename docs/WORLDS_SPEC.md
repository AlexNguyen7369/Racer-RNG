# Worlds: cruise cap, World 1 / World 2 (contract for tests and implementation)

Design rule: `docs/GAME_DESIGN_REQUIREMENTS.md` "Worlds" (owner decision, 2026-10-27). Values marked
placeholder are tuned by `tools/balance_sim.py` and the speed probe, then approved by the owner.

## 1. Cruise cap

- `RaceConfig.MAX_CRUISE` = 800 studs/s (set 2026-10-27: `speed_probe` was green at every probe up to 1000, tightest
  Track 9 minUpY 0.902 at 1000; 1000 - 10 % = 900, clamped to the 800 maximum). Rule: the `speed_probe` scenario gives the highest speed
  with 0 flips, up-vector Y >= `PhysicsTargets.lap.MinUpYStrict` and path deviation <= `race.MaxPathDeviation` on
  every track, minus 10 %, kept within 700 .. 800).
- `RaceConfig.SpeedFor(stat, multi) = min(curve(stat) x CruiseStatMulti(multi), MAX_CRUISE)`.
- `RaceConfig.StatFor(speed)` returns `math.huge` for a speed above `MAX_CRUISE`.
- Every NPC drives below `MAX_CRUISE`.

## 2. Worlds

| | World 1 | World 2 |
|---|---|---|
| Place | the current place | a second place in the same universe |
| Rebirths done here | 0 -> 10 | 10 -> 20 |
| Unlock | always | `RebirthLevel >= 10` |
| Tracks | `Shared/Tracks/World1/*` (today's 10) | `Shared/Tracks/World2/*` (10 new) |
| Cruise table | BASE 10, MAX_SPEED 88, HALF_STAT 10,000 | BASE 150, MAX_SPEED 300, HALF_STAT fitted by the sim (owner 2026-10-27: start at 150 studs/s) |
| NPC ladder | 16 x 1.51^(n-1), Track 10 = 653 | 160 x 1.18^(n-1), Track 10 = 711 |
| Payout of track n | `PayoutCurve.Cash(n)` | `PayoutCurve.Cash(10 + n)` |
| Pacing target | about 30 h | about 35 h |

- `Shared/WorldConfig.Current()` returns 1 or 2 from `game.PlaceId` (`WorldConfig.PLACE_IDS`); the ReplicatedStorage
  attribute `WorldOverride` (1 or 2) wins, for Studio and the harness.
- World 1 refuses a rebirth at `RebirthLevel >= 10` with "Unlock World 2"; World 2 refuses below 10 (cannot happen
  through the portal) and at 20 ("Max rebirth"). `RebirthConfig.TOTALS` is shared.
- Interim rule (owner 2026-10-28): until WorldService and World 2 ship, the single place allows rebirths 1-20
  and refuses only at 20 ("Max rebirth"); the World 1 cap at 10 starts with the World 2 release.

## 3. Kept per world / shared

- Per world (saved under `Worlds[tostring(id)]`): `Speed`, `BestTrack`, `Checkpoint`, `RaceBestTimes`, `Level`, `XP`.
- Shared (flat, as today): cars, `Copies`, `Showcase`, `Equipped`, `Money`, `MoneyEarned`, `RebirthLevel`, stat
  allocations, upgrades, auras, trails, passes, workshop level, daily login, duels, receipts, codes.

## 4. Save (PlayerData VERSION 13)

- Migration from 12: the flat per-world fields move into `Worlds["1"]`; `Worlds["2"]` starts empty (Speed 0, Level 1,
  XP 0, BestTrack 0, Checkpoint 1). Shared fields are untouched.
- Both places use the same DataStore and key (DataStores are universe-wide) and the same session lock
  (`docs/SAVE_SPEC.md`).

## 5. Portal and teleport

- Each hub has a portal pad (tag `WorldPortal`, attribute `ToWorld`). `Server/WorldService` decides: data loaded, not
  auto racing, World 2 needs `RebirthLevel >= 10`; then it saves and releases the lock (`PlayerData` leave path) and
  calls `TeleportService:TeleportAsync(WorldConfig.PLACE_IDS[to], { player })` with up to 3 tries.
- On arrival the normal load runs; a lock still held by the old server is waited out by the existing retry path.
- At rebirth 10 the World 1 rebirth panel shows "Unlock World 2" and points at the portal.
- Admin `/world 1|2` (`docs/ADMIN_COMMANDS_SPEC.md`).
- TeleportService does not run in Studio: the harness tests the decision and the save, the jump itself is checked
  by hand on the published places.

## 6. World 2 content: mega biomes (owner approved 2026-10-27: "even bigger", per-biome lighting, the 10 biomes)

Owner theme: long, very wide tracks that run through massive, beautiful mega biomes.

### Scale
| | World 1 today | World 2 (proposed placeholders) |
|---|---|---|
| Road width | 36-40 studs | 160 studs (lane offset 40, NPC lane -40) |
| Track length | 320-1,600 studs (about 1-2 s at the cap) | 30,000 studs (Track 1) rising to 60,000 (Track 10): about 40-80 s at 750 studs/s |
| Tightest corner | `MIN_RADIUS` 28 | 400 studs, sweepers 600-1,500 (speed near the cap; the speed probe confirms) |
| Grades | up to 25 deg | up to 12 deg, long climbs and descents of 200-600 studs |
| Scenery | parts budget 1,200 per track | Terrain (mountains, water, grass, snow) baked into the World 2 place, plus mesh props streamed near the camera |

### Layout: biome tiles
- A track 30-60k studs long cannot run in one straight chain: 10 of them end to end would reach about 450k studs from
  the origin, where physics loses precision. Instead each track fills its own 14,000 x 14,000 stud TILE with sweeping
  curves, and the tiles sit in a 5 x 2 snake-shaped grid around the World 2 hub (furthest point about 38k studs from
  the origin). Heavier on phones: the W2-B pilot measures it before tracks 2-10 are built.
- Track n finishes at the tile edge where tile n+1 begins, so track rule 3 still holds (the finish is the next start)
  and the drive is continuous, with no warp.
- Every tile has its own Terrain, sky look and props; the road and walls stay the shared `TrackBuilder` kit, scaled up.
- `StreamingEnabled` is on in the World 2 place so a client loads only the tiles near the car.

### The 10 mega biomes (one per track, in order)
1. Meadow Valleys: rolling green hills, wildflower fields, waterfalls into a river the road follows.
2. Blossom Terraces: pink-canopy hillsides, stepped ponds, floating lanterns.
3. Coral Lagoon: shallow turquoise water, sandbars, reef arches, long low bridges.
4. Titan Redwoods: giant trees, light shafts through mist, fern floor, a road through a hollow trunk.
5. Crystal Caverns: one huge glowing cave, crystal pillars, an underground river.
6. Sky Archipelago: floating islands above a sea of clouds, linked by long bridges.
7. Aurora Glacier: ice fields and ice arches under a moving aurora.
8. Sunset Mesas: red-rock canyon, natural arches, long sweeping descents.
9. Glowshroom Marsh: night swamp, bioluminescent giant fungi, low mist.
10. Nebula Rift: the finale; planets, a river of stars, the road over a cosmic gap.

### New rules (owner approved 2026-10-27)
- World 2 track rules: width 160, minimum radius 400, max grade 12 deg, tile bounds; enforced by `TrackValidator`
  per world. World 1 rules stay unchanged.
- Per-biome lighting (approved): in World 2 only, the client blends of Lighting / Atmosphere / Sky by the tile the camera is in
  (`Client/BiomeAmbience` extended). Weather still applies on top.
- Scenery budget per track raised for World 2 (parts plus Terrain); the client frame-rate budget is set by a
  `/compat-check` run on a phone-size device.

### Build order
1. W2-A: the World 2 rules and the tile grid in `TrackValidator` / `TrackBuilder` (tests first).
2. W2-B pilot: Track 1 Meadow Valleys end to end (tile, Terrain, props, lighting, NPC race at the cap) through
   `/build-track`; measure server physics, client FPS and memory on desktop and phone.
3. W2-C: tracks 2-10 through `/build-track`, one at a time, each green on the full suite.
4. W2-D: lighting and ambience polish, horizon pieces linking neighbouring tiles, `/compat-check`.
