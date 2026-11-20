--!nonstrict
-- The NPC racer of every track: one per track number, racing each player on their own (see Shared/NpcRacer and
-- Server/RaceService). Change speeds, colours, labels and models here.
--
-- Tracks[n] overrides the defaults for track n:
--   Color  Color3 of the starter car body
--   Speed  cruise speed, studs/s (the NPC slows only where corner grip requires it)
--   Label  floating text above the NPC
--   Model  name of a Model under ReplicatedStorage.NpcModels, or a car catalog id (skinned like the player's car)

local RaceConfig = require(script.Parent.RaceConfig)

local NpcConfig = {}

-- studs/s, the formula's Track 1 (owner 2026-10-21: 16), x the movement scale so a track needs the same Speed;
-- tracks 1..EARLY_TRACKS use the curve below
NpcConfig.BASE_SPEED = 16 * RaceConfig.SPEED_SCALE
NpcConfig.SPEED_GROWTH = 1.75 -- every later track's NPC is this many times faster (owner 2026-10-21, was 1.37)
-- Early-track Speed curve (proposed by Vic2CS, 2026-11-19; design doc "Early-track Speed curve", placeholders): the
-- Speed a track needs (raw multi 1) is EARLY_FIRST_STAT on Track 1 and grows by one fixed factor per track, landing
-- exactly on what the formula above needs on Track EARLY_TRACKS + 1, so that track and every later one are unchanged.
NpcConfig.EARLY_TRACKS = 5
NpcConfig.EARLY_FIRST_STAT = 300 -- Track 1: ~2.5 minutes of racing for a new player; a stat-0 car (RaceConfig.BASE_SPEED) loses without nitro
NpcConfig.LABEL_DISTANCE = 200 -- studs: the label only shows when the player is this close (owner 2026-10-20, was 60)
-- Loser screen time: a lost race ends when the NPC's time is up, the car stops, and after this long it goes back to
-- the run's start track (Vic2CS proposal 2026-11-20, design doc "Playtest follow-ups", needs owner agreement)
NpcConfig.LOSE_SCREEN_SECONDS = 3
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

local function formulaSpeed(number)
	return NpcConfig.BASE_SPEED * NpcConfig.SPEED_GROWTH ^ (number - 1)
end

-- The factor each early track's needed Speed is multiplied by (about 6 with the placeholders).
function NpcConfig.EarlyGrowth()
	local joinStat = RaceConfig.StatFor(formulaSpeed(NpcConfig.EARLY_TRACKS + 1))
	return (joinStat / NpcConfig.EARLY_FIRST_STAT) ^ (1 / NpcConfig.EARLY_TRACKS)
end

-- Track `number`'s NPC speed before any Tracks[n].Speed override: the early curve, then the formula.
function NpcConfig.DefaultSpeed(number)
	if number <= NpcConfig.EARLY_TRACKS then
		return RaceConfig.SpeedFor(NpcConfig.EARLY_FIRST_STAT * NpcConfig.EarlyGrowth() ^ (number - 1))
	end
	return formulaSpeed(number)
end

-- Everything about track `number`'s NPC: { Number, Speed, Color, Label, Model }.
function NpcConfig.For(number)
	number = math.max(1, math.floor(tonumber(number) or 1))
	local o = NpcConfig.Tracks[number] or {}
	local palette = NpcConfig.PALETTE
	return {
		Number = number,
		Speed = o.Speed or NpcConfig.DefaultSpeed(number),
		Color = o.Color or palette[(number - 1) % #palette + 1],
		Label = o.Label or string.format(NpcConfig.LABEL_FORMAT, number),
		Model = o.Model,
	}
end

-- The Speed track `number` needs, as the track gate's REC. SPEED sign shows it: the shown Speed at which a car with
-- raw multi 1 cruises at the NPC's speed (design doc "Faster race Speed gain", gate signs). The loser screen's
-- progress guide uses the same number.
function NpcConfig.RecommendedSpeed(number)
	return RaceConfig.StatFor(NpcConfig.For(number).Speed)
end

return NpcConfig
