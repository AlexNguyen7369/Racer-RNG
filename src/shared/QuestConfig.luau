--!nonstrict
-- Starter daily and weekly quests. IDs are permanent save keys.
local QuestConfig = {}

QuestConfig.DAILY_SECONDS = 86400
QuestConfig.WEEKLY_SECONDS = 604800
QuestConfig.Daily = {
	{ Id = "daily_races", Metric = "Races", Target = 3, Name = "Finish 3 races", Reward = "LuckI", RewardCount = 1 },
	{ Id = "daily_rolls", Metric = "Rolls", Target = 5, Name = "Complete 5 rolls", Reward = "MoneyI", RewardCount = 1 },
	{ Id = "daily_discover", Metric = "Discoveries", Target = 1, Name = "Discover 1 car", Reward = "SpeedI", RewardCount = 1 },
}
QuestConfig.Weekly = {
	{ Id = "weekly_races", Metric = "Races", Target = 20, Name = "Finish 20 races", Reward = "MoneyI", RewardCount = 2 },
	{ Id = "weekly_discover", Metric = "Discoveries", Target = 5, Name = "Discover 5 cars", Reward = "LuckI", RewardCount = 2 },
	{ Id = "weekly_potions", Metric = "Potions", Target = 3, Name = "Use 3 potions", Reward = "SpeedI", RewardCount = 2 },
}

function QuestConfig.PeriodKey(now, weekly)
	now = math.floor(tonumber(now) or os.time())
	if weekly then
		return math.floor((now + 3 * 86400) / QuestConfig.WEEKLY_SECONDS)
	end
	return math.floor(now / QuestConfig.DAILY_SECONDS)
end

function QuestConfig.SecondsUntil(now, weekly)
	now = math.floor(tonumber(now) or os.time())
	local seconds = weekly and QuestConfig.WEEKLY_SECONDS or QuestConfig.DAILY_SECONDS
	local key = QuestConfig.PeriodKey(now, weekly)
	return math.max(0, (key + 1) * seconds - (weekly and 3 * 86400 or 0) - now)
end

return QuestConfig
