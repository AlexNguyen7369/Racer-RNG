--!nonstrict
-- The NPC racer of every track: one per track number, racing each player on their own (see Shared/NpcRacer and
-- Server/RaceService). Change speeds, colours, labels and models here.
--
-- Tracks[n] overrides the defaults for track n:
--   Color  Color3 of the starter car body
--   Speed  cruise speed, studs/s (the NPC slows only where corner grip requires it)
--   Label  floating text above the NPC
--   Model  name of a Model under ReplicatedStorage.NpcModels to use instead of the starter car

local NpcConfig = {}

NpcConfig.BASE_SPEED = 20 -- Track 1, studs/s: very easy (the player starts at RaceConfig.BASE_SPEED = 30)
NpcConfig.SPEED_STEP = 12 -- studs/s added for every later track
NpcConfig.LABEL_DISTANCE = 60 -- studs: the label only shows when the player is this close
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

NpcConfig.Tracks = {
	[1] = { Color = Color3.fromRGB(230, 45, 45) }, -- red
}

-- Everything about track `number`'s NPC: { Number, Speed, Color, Label, Model }.
function NpcConfig.For(number)
	number = math.max(1, math.floor(tonumber(number) or 1))
	local o = NpcConfig.Tracks[number] or {}
	local palette = NpcConfig.PALETTE
	return {
		Number = number,
		Speed = o.Speed or NpcConfig.BASE_SPEED + NpcConfig.SPEED_STEP * (number - 1),
		Color = o.Color or palette[(number - 1) % #palette + 1],
		Label = o.Label or string.format(NpcConfig.LABEL_FORMAT, number),
		Model = o.Model,
	}
end

return NpcConfig
