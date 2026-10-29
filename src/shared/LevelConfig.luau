--!nonstrict
-- Level and rebirth milestones from the game design requirements.

local LevelConfig = {}

LevelConfig.START_LEVEL = 1
LevelConfig.START_XP = 0
LevelConfig.XP_PER_SECOND = 1
-- XP to next level (owner 2026-10-27, placeholders): XP_LINEAR x level up to XP_KNEE, then x10 every XP_DECADE levels,
-- so late rebirths (x10 multi each) cost about 40 levels each like the rebirth table.
-- Owner 2026-10-28: XP_LINEAR 122 and XP_DECADE 37.2 from the balance sim fit (tools/balance_sim.py), was 10 / 40.
LevelConfig.XP_LINEAR = 122
LevelConfig.XP_KNEE = 225
LevelConfig.XP_DECADE = 37.2
LevelConfig.MAX_LEVEL = 10000

function LevelConfig.CleanLevel(value)
	if type(value) ~= "number" or value ~= value then
		return LevelConfig.START_LEVEL
	end
	return math.floor(math.clamp(value, LevelConfig.START_LEVEL, LevelConfig.MAX_LEVEL))
end

function LevelConfig.CleanXP(value)
	if type(value) ~= "number" or value ~= value or value < 0 then
		return LevelConfig.START_XP
	end
	return math.min(value, 1e300) -- late rebirths need far more than 1e15 XP
end

function LevelConfig.XPToNext(level)
	level = LevelConfig.CleanLevel(level)
	if level <= LevelConfig.XP_KNEE then
		return LevelConfig.XP_LINEAR * level
	end
	return LevelConfig.XP_LINEAR * LevelConfig.XP_KNEE * 10 ^ ((level - LevelConfig.XP_KNEE) / LevelConfig.XP_DECADE)
end

-- Level needed for the next rebirth (owner 2026-10-27 rev. 4, docs/REBIRTH_SPEC.md); past the last one the final value.
local REBIRTH_LEVELS = { 15, 25, 40, 60, 75, 100, 125, 150, 175, 200, 225, 260, 300, 340, 380, 420, 465, 510, 560, 600 }
function LevelConfig.RebirthLevelRequirement(rebirthLevel)
	rebirthLevel = math.max(0, math.floor(tonumber(rebirthLevel) or 0))
	return REBIRTH_LEVELS[math.min(rebirthLevel + 1, #REBIRTH_LEVELS)]
end

return LevelConfig
