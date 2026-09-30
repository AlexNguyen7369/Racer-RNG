# Element: Vertical Loop

- **Type:** track element (reusable piece)
- **Status:** draft (Blender only; not built or tested in Roblox)
- **Blender file:** `vertical_loop.blend` (export: `export/vertical_loop.glb`, preview: `preview.png`)
- **Scale:** 1 Blender unit = 1 stud
- **Matches spec:** the `Loop` segment in `src/shared/TrackBuilder.luau`

## What this is
A loop-the-loop between two straights: radius 40 (80 studs tall), sideways shift 50 so the entry and exit lanes clear each other, 40-stud road. Draft segments: `S150, Loop(R40, shift 50), S150`.

```lua
{ Type = "Straight", Length = 150 },
{ Type = "Loop", Radius = 40, Shift = 50, Direction = "Left" },
{ Type = "Straight", Length = 150 },
```

## Physics note
A real car cannot do this: at 90 studs/s it would need about 177 studs/s to climb 80 studs. Loop road parts carry a `LoopAssist` attribute, and `CarPhysics` cancels gravity while a wheel touches one. The car stays pressed into the road by inertia. This has not been run in Studio yet.

## What the draft includes
- Full 360 degree road with walls that follow the road surface, and a skirt under it
- Lateral drift smoothed to zero at both ends so there is no kink where the loop joins the straights
- Start line, arch, and the starter car for scale

## Left for full implementation
- Playtest in Studio: entry and exit smoothness, whether the bot stays on the road, camera behaviour when upside down (default camera may spin or flip)
- Support pillars for the loop, and a decorative look
- Decide loop size limits and where loops are allowed on the race ladder

## Notes
- Built with `drafts/_tools/blender_track_builder.py` (spec: `("L", 40, 50)` = `Loop`).
