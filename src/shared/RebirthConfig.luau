--!nonstrict
-- Rebirth progression knobs. All thresholds and permanent effects live here so
-- the server and presentation can describe the same progression.

local RebirthConfig = {}
local LevelConfig = require(script.Parent.LevelConfig)

RebirthConfig.DEFAULT_LEVEL = 0
-- Total Speed Gain / XP / Luck multi per rebirth level (owner 2026-10-27 rev. 4, docs/REBIRTH_SPEC.md):
-- the "+1 Speed" genre table; rebirth 20 is the last one.
RebirthConfig.TOTALS = { 1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7.5, 10, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11 }
RebirthConfig.MAX_LEVEL = #RebirthConfig.TOTALS
RebirthConfig.POINTS_PER_REBIRTH = 1 -- stat points per rebirth (placeholder, owner 2026-10-15; docs/REBIRTH_SPEC.md)

function RebirthConfig.CleanLevel(level)
	if type(level) ~= "number" or level ~= level or level == math.huge or level == -math.huge then
		return RebirthConfig.DEFAULT_LEVEL
	end
	return math.max(RebirthConfig.DEFAULT_LEVEL, math.floor(level))
end

function RebirthConfig.SpeedGainMulti(level)
	level = RebirthConfig.CleanLevel(level)
	if level == 0 then
		return 1
	end
	return RebirthConfig.TOTALS[math.min(level, RebirthConfig.MAX_LEVEL)]
end

function RebirthConfig.MoneyMulti(_level)
	return 1
end

function RebirthConfig.LuckMulti(level)
	return RebirthConfig.SpeedGainMulti(level)
end

-- Total multi after the next rebirth, shown on the Rebirth panel so the UI never hard-codes it.
function RebirthConfig.NextMultiplier(level)
	return RebirthConfig.SpeedGainMulti(RebirthConfig.CleanLevel(level) + 1)
end

-- Stat points earned from rebirths, added to the car-index points (never saved: derived from the rebirth count)
function RebirthConfig.Points(level)
	return RebirthConfig.CleanLevel(level) * RebirthConfig.POINTS_PER_REBIRTH
end

function RebirthConfig.Requirements(level)
	level = RebirthConfig.CleanLevel(level)
	return {
		Level = LevelConfig.RebirthLevelRequirement(level),
	}
end

function RebirthConfig.CanRebirth(level, playerLevel)
	if RebirthConfig.CleanLevel(level) >= RebirthConfig.MAX_LEVEL then
		return false
	end
	local required = RebirthConfig.Requirements(level)
	return type(playerLevel) == "number" and playerLevel >= required.Level
end

return RebirthConfig
