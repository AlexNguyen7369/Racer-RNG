--!nonstrict
-- The NPC racer of every track: one per track number, racing each player on their own (see Shared/NpcRacer and
-- Server/RaceService). Change speeds, colours, labels and models here.
--
-- Tracks[n] overrides the defaults for track n:
--   Color  Color3 of the starter car body
--   Speed  cruise speed, studs/s (the NPC slows only where corner grip requires it)
--   Label  floating text above the NPC
--   Model  name of a Model under ReplicatedStorage.NpcModels, or a car catalog id (skinned like the player's car)

local NpcConfig = {}

NpcConfig.BASE_SPEED = 45 -- Track 1, studs/s: a stat-0 starter car (12) loses decisively
NpcConfig.SPEED_GROWTH = 2.5 -- every later track's NPC is this many times faster; each jump is a major hurdle
NpcConfig.LABEL_DISTANCE = 200 -- studs: the label only shows when the player is this close (owner 2026-10-20, was 60)
NpcConfig.LOSE_SCREEN_SECONDS = 3 -- loser screen time before the player is sent back to the spawn
NpcConfig.LABEL_FORMAT = "track%02d_NPC"

-- Default colours by track number, used when Tracks[n].Color is not set (wraps around after the last).
NpcConfig.PALETTE = {
	Color3.fromRGB(230, 45, 45), -- red
	Color3.fromRGB(255, 150, 30), -- orange
	Color3.fromRGB(60, 190, 80), -- green
	Color3.fromRGB(150, 70, 220), -- purple
	Color3.fromRGB(250, 215, 40), -- yellow
	Color3.fromRGB(240, 90, 180), -- pink
	Color3.fromRGB(40, 40, 50), -- black
	Color3.fromRGB(245, 245, 245), -- white
}

-- Owner 2026-10-20: tracks 1-10 drive imported car models, rarer on every later track.
NpcConfig.Tracks = {
	[1] = { Color = Color3.fromRGB(230, 45, 45), Model = "rusty_hatchback" }, -- red
	[2] = { Model = "wooden_car" },
	[3] = { Model = "go_kart" },
	[4] = { Model = "rain_runner" },
	[5] = { Model = "street_racer" },
	[6] = { Model = "midnight_kart" },
	[7] = { Model = "golden_racer" },
	[8] = { Model = "rocket_car" },
	[9] = { Model = "hover_car" },
	[10] = { Model = "void_racer" },
}

-- Everything about track `number`'s NPC: { Number, Speed, Color, Label, Model }.
function NpcConfig.For(number)
	number = math.max(1, math.floor(tonumber(number) or 1))
	local o = NpcConfig.Tracks[number] or {}
	local palette = NpcConfig.PALETTE
	return {
		Number = number,
		Speed = o.Speed or NpcConfig.BASE_SPEED * NpcConfig.SPEED_GROWTH ^ (number - 1),
		Color = o.Color or palette[(number - 1) % #palette + 1],
		Label = o.Label or string.format(NpcConfig.LABEL_FORMAT, number),
		Model = o.Model,
	}
end

return NpcConfig
