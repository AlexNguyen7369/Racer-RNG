--!nonstrict
-- Rebirth progression knobs. All thresholds and permanent effects live here so
-- the server and presentation can describe the same progression.

local RebirthConfig = {}
local LevelConfig = require(script.Parent.LevelConfig)

RebirthConfig.DEFAULT_LEVEL = 0
RebirthConfig.MAX_LEVEL = 100
RebirthConfig.GAIN_PER_LEVEL = 0.10 -- +10% passive racing Speed gain per rebirth
RebirthConfig.LUCK_GAIN_PER_LEVEL = 0.10 -- +10% roll luck per rebirth

function RebirthConfig.CleanLevel(level)
	if type(level) ~= "number" or level ~= level then
		return RebirthConfig.DEFAULT_LEVEL
	end
	return math.floor(math.clamp(level, RebirthConfig.DEFAULT_LEVEL, RebirthConfig.MAX_LEVEL))
end

function RebirthConfig.SpeedGainMulti(level)
	level = RebirthConfig.CleanLevel(level)
	return 1 + level * RebirthConfig.GAIN_PER_LEVEL
end

function RebirthConfig.MoneyMulti(level)
	return RebirthConfig.SpeedGainMulti(level)
end

function RebirthConfig.LuckMulti(level)
	level = RebirthConfig.CleanLevel(level)
	return 1 + level * RebirthConfig.LUCK_GAIN_PER_LEVEL
end

function RebirthConfig.Requirements(level)
	level = RebirthConfig.CleanLevel(level)
	return {
		Level = LevelConfig.RebirthLevelRequirement(level),
	}
end

function RebirthConfig.CanRebirth(level, playerLevel)
	local required = RebirthConfig.Requirements(level)
	return type(playerLevel) == "number" and playerLevel >= required.Level
end

return RebirthConfig
