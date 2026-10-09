--!nonstrict
-- Level and rebirth milestones from the game design requirements.

local LevelConfig = {}

LevelConfig.START_LEVEL = 1
LevelConfig.START_XP = 0
LevelConfig.XP_PER_SECOND = 1
LevelConfig.XP_BASE = 100
LevelConfig.XP_GROWTH = 1.15
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
	return math.min(value, 1e15)
end

function LevelConfig.XPToNext(level)
	level = LevelConfig.CleanLevel(level)
	return LevelConfig.XP_BASE * LevelConfig.XP_GROWTH ^ (level - 1)
end

function LevelConfig.RebirthLevelRequirement(rebirthLevel)
	rebirthLevel = math.max(0, math.floor(tonumber(rebirthLevel) or 0))
	local milestones = { 10, 25, 50, 75, 100 }
	if rebirthLevel < #milestones then
		return milestones[rebirthLevel + 1]
	end
	return milestones[#milestones] + (rebirthLevel - #milestones + 1) * 25
end

return LevelConfig
