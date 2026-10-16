# Tracks 6–10: biome ladder specification

## Contract

Tracks 6–10 extend the existing numbered point-to-point chain. Track 6 starts at
Track 5's finish, and each later track starts at the previous track's finish. They
use the existing right-hand player lane, left-side winnings pad, wide checkpoint,
server-authoritative NPC race, and `TrackBuilder` physics. Biome dressing is
procedural, deterministic, anchored, and non-colliding; it must never change car
grip, gravity, payout rules, or race resolution.

All five tracks target 1,400–1,900 studs, have straight entry and finish segments,
are at least 36 studs wide, and increase technical difficulty in number order.

## Track briefs

| Number | Biome | Identity | Geometry target |
|---:|---|---|---|
| 6 | City | Neon towers, streetlights, signs, and broad city blocks | Four broad 90° turns and long straights; introductory new-tier track |
| 7 | Desert | Canyon walls, mesas, sand, and dry hills | Long climbs, a wide hairpin, and sweeping canyon bends |
| 8 | Snow | Snowbanks, pines, ice cliffs, and cold blue light | Alternating bends, rolling slopes, and a large mountain hairpin |
| 9 | Volcano | Basalt, lava channels, smoke, and glowing rock | Steep safe slopes, technical bends, and a long crater approach |
| 10 | Space | Orbital platforms, pylons, stars, and luminous structures | Long straights, elevation changes, a high-radius hairpin, and the capstone turn sequence |

## Environment rules

- Every spec has a `Biome` string consumed by `BiomeDressing`.
- Props are visual only: `Anchored = true`, `CanCollide = false`, `CanTouch = false`,
  and `CanQuery = false`.
- Props are placed outside the road, walls, checkpoint apron, and winnings pad.
- Dressing is generated from layout waypoints with no randomness, so builds and tests
  are reproducible.
- Biomes may use palette, material, shape, and lighting metadata, but no biome adds a
  new hazard or changes the shared physics model.

## Acceptance

Each track gets a `TrackTests/<Name>` contract before its implementation. The full
chain must validate with no self-overlap, no chain overlap, straight-to-straight
joins, correct checkpoint/pad placement, and a stable live lap. The chain and NPC
tests must cover all ten tracks.
