# Track 2: Hill Circuit

- **Type:** track
- **Status:** implemented in Roblox as point-to-point Track 2 (the Blender draft is still the closed loop)
- **Blender file:** `track_02_hill.blend` (export: `export/track_02_hill.glb`, preview: `preview.png`)
- **Scale:** 1 Blender unit = 1 stud (forward is +Y in Blender, -Z in Roblox)
- **Matches spec:** `src/shared/Tracks/Hill.luau` (Number 2), test `src/server/CarTest/TrackTests/Hill.luau`. The built track differs from this draft: it is NOT a closed loop. It has one right-hand 180 turn, then a second hill leg that ends at a checkpoint 160 studs from the start, and it starts at Track 1's finish checkpoint.

## What this is
Second track: an oval like Track 1, but each long straight has a 30-stud hill to drive up and down. About 1,620 studs a lap, 40 wide, peak height 30, steepest grade about 16 degrees.

## Intended spec (for `src/shared/Tracks/Hill.luau`)
```lua
local side = {
	{ Type = "Straight", Length = 100 },
	{ Type = "Slope", Length = 160, Rise = 30 },
	{ Type = "Straight", Length = 40 },   -- crest
	{ Type = "Slope", Length = 160, Rise = -30 },
	{ Type = "Straight", Length = 100 },
}
-- Width = 40, Closed = true: side, Turn 180 R80, side, Turn 180 R80
```
Suggested test expectations for `test-writer`: `Closed`, `MinLength` ~1500, `MinPeakHeight` 25, `MaxGradeDeg` 20, `MinRadius` 60, lap time band from the bot.

## What the draft includes
- Road ribbon following the smooth (cosine) hill profile, with green earth fill under the hills
- Both walls, pink/white kerbs on the corners, start line and arch
- Starter car at x3 scale next to the line

## Left for full implementation
- Playtest whether the car can climb 16 degrees at speed and stay planted over the crest (the `accel` limits may need to allow for climbing)
- Scenery for the environment, and a proper support look under the hills instead of flat fill blocks

## Notes
- Built with `drafts/_tools/blender_track_builder.py` (spec: `("H", 160, 30)` = `Slope`).
