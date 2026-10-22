--!nonstrict
-- Rebirth progression knobs. All thresholds and permanent effects live here so
-- the server and presentation can describe the same progression.

local RebirthConfig = {}
local LevelConfig = require(script.Parent.LevelConfig)

RebirthConfig.DEFAULT_LEVEL = 0
-- Rebirth milestones continue forever. Keep this compatibility sentinel for older
-- UI/test callers, but it is not a gameplay cap.
RebirthConfig.MAX_LEVEL = math.huge
-- Per-rebirth factors: the first few prestiges accelerate sharply, then settle at a
-- repeatable 7.5x factor so high-rebirth players rocket through early levels without
-- making the next rebirth an unbounded one-off jump.
RebirthConfig.REBIRTH_MULTIPLIERS = { 5, 7.5, 7.5, 10, 10, 7.5 }
RebirthConfig.REPEAT_MULTIPLIER = 7.5
RebirthConfig.SPEED_GAIN_MULTIPLIER = RebirthConfig.REBIRTH_MULTIPLIERS[1]
RebirthConfig.LUCK_MULTIPLIER = RebirthConfig.REBIRTH_MULTIPLIERS[1]
RebirthConfig.MAX_EFFECTIVE_MULTIPLIER = 1e100 -- keep race gain and roll math finite at extreme rebirth counts
RebirthConfig.POINTS_PER_REBIRTH = 1 -- stat points per rebirth (placeholder, owner 2026-10-15; docs/REBIRTH_SPEC.md)

function RebirthConfig.CleanLevel(level)
	if type(level) ~= "number" or level ~= level or level == math.huge or level == -math.huge then
		return RebirthConfig.DEFAULT_LEVEL
	end
	return math.max(RebirthConfig.DEFAULT_LEVEL, math.floor(level))
end

function RebirthConfig.SpeedGainMulti(level)
	level = RebirthConfig.CleanLevel(level)
	local multi = 1
	for rebirth = 1, math.min(level, 256) do
		local factor = RebirthConfig.REBIRTH_MULTIPLIERS[rebirth] or RebirthConfig.REPEAT_MULTIPLIER
		multi = math.min(multi * factor, RebirthConfig.MAX_EFFECTIVE_MULTIPLIER)
		if multi >= RebirthConfig.MAX_EFFECTIVE_MULTIPLIER then
			break
		end
	end
	return multi
end

function RebirthConfig.MoneyMulti(_level)
	return 1
end

function RebirthConfig.LuckMulti(level)
	return RebirthConfig.SpeedGainMulti(level)
end

-- Factor shown for the next rebirth. The UI uses this instead of hard-coding a
-- single value so the staged progression stays visible and truthful.
function RebirthConfig.NextMultiplier(level)
	level = RebirthConfig.CleanLevel(level)
	return RebirthConfig.REBIRTH_MULTIPLIERS[level + 1] or RebirthConfig.REPEAT_MULTIPLIER
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
