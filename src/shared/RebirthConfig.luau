--!nonstrict
-- Rebirth progression knobs. All thresholds and permanent effects live here so
-- the server and presentation can describe the same progression.

local RebirthConfig = {}
local LevelConfig = require(script.Parent.LevelConfig)

RebirthConfig.DEFAULT_LEVEL = 0
-- Rebirth milestones continue forever. Keep this compatibility sentinel for older
-- UI/test callers, but it is not a gameplay cap.
RebirthConfig.MAX_LEVEL = math.huge
-- Total Speed Gain / Luck multi per rebirth level (owner 2026-10-27 rev. 2, docs/REBIRTH_SPEC.md): grows by
-- addition only: +EARLY_STEP per rebirth up to ADD_UNTIL, then capped (ADD_UNTIL * EARLY_STEP = x100).
RebirthConfig.EARLY_STEP = 5
RebirthConfig.ADD_UNTIL = 20
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
	return math.min(level, RebirthConfig.ADD_UNTIL) * RebirthConfig.EARLY_STEP
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
	local required = RebirthConfig.Requirements(level)
	return type(playerLevel) == "number" and playerLevel >= required.Level
end

return RebirthConfig
