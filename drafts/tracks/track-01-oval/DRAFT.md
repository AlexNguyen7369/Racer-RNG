# Track 1: Oval (starter track)

- **Type:** track
- **Status:** draft
- **Blender file:** `track_01_oval.blend` (export: `export/track_01_oval.glb`, preview: `preview.png`)
- **Scale:** 1 Blender unit = 1 stud (forward is +Y in Blender, -Z in Roblox)
- **Matches spec (drifted):** the built Track 1 is now point-to-point (Straight 240, 180 turn, Straight 240, 90 turn, Straight 60, checkpoint at the finish), so this closed-loop draft is out of date. `src/shared/Tracks/Oval.luau`, test `src/server/CarTest/TrackTests/Oval.luau`

## What this is
The beginner track for the NPC race ladder: two 240-stud straights joined by two wide 180 degree hairpins (radius 90), 40 studs wide, about 1,050 studs per lap. Built with the same centreline maths as `TrackBuilder.Layout`, so the Blender shape and the Roblox track line up.

## What the draft includes
- Road ribbon with a skirt down to the grass (road top at 0, grass at -1, as in `TrackBuilder`)
- Both side walls (5 high, 2 thick)
- Pink and white kerbs on the corners
- Checkered start/finish line and a baby-blue start arch
- The starter car scaled x3 next to the line as a size reference
- Flat-colour pastel materials named `T1_*`

## Left for full implementation
- Real road markings (centre dashes, edge lines) and a tyre-wear look
- Walls that follow the inside of tight corners without clipping (the Roblox version uses straight slabs)
- Scenery for the first environment (City): buildings, trees, crowd blocks
- Split into MeshParts and UV/texture pass before import to Studio
- Decide whether Studio uses this mesh or keeps generating the track from `TrackBuilder`. Generated parts keep the spec and the tests in sync, so that is the default.

## Notes
- If `Oval.luau` changes (width, lengths, radii), re-run the build script for this draft so the two match.
- Draft numbers to keep in sync: width 40, straights 240, hairpin radius 90.
