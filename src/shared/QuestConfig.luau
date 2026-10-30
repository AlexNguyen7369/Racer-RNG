--!nonstrict
-- Daily and weekly quest pools (docs/QUESTS_SPEC.md "Rotation"). IDs are permanent save keys; pool values and
-- PICK are placeholders.
local QuestConfig = {}

QuestConfig.PICK = 3

QuestConfig.DAILY_SECONDS = 86400
QuestConfig.WEEKLY_SECONDS = 604800
QuestConfig.Daily = {
	{ Id = "daily_races", Metric = "Races", Target = 3, Name = "Finish 3 races", Reward = "LuckI", RewardCount = 1 },
	{ Id = "daily_rolls", Metric = "Rolls", Target = 5, Name = "Complete 5 rolls", Reward = "MoneyI", RewardCount = 1 },
	{
		Id = "daily_discover",
		Metric = "Discoveries",
		Target = 1,
		Name = "Discover 1 car",
		Reward = "SpeedI",
		RewardCount = 1,
	},
	{
		Id = "daily_races_long",
		Metric = "Races",
		Target = 8,
		Name = "Finish 8 races",
		Reward = "SpeedI",
		RewardCount = 1,
	},
	{
		Id = "daily_rolls_long",
		Metric = "Rolls",
		Target = 25,
		Name = "Complete 25 rolls",
		Reward = "LuckI",
		RewardCount = 1,
	},
	{ Id = "daily_potions", Metric = "Potions", Target = 1, Name = "Use 1 potion", Reward = "MoneyI", RewardCount = 1 },
}
QuestConfig.Weekly = {
	{
		Id = "weekly_races",
		Metric = "Races",
		Target = 20,
		Name = "Finish 20 races",
		Reward = "MoneyI",
		RewardCount = 2,
	},
	{
		Id = "weekly_discover",
		Metric = "Discoveries",
		Target = 5,
		Name = "Discover 5 cars",
		Reward = "LuckI",
		RewardCount = 2,
	},
	{
		Id = "weekly_potions",
		Metric = "Potions",
		Target = 3,
		Name = "Use 3 potions",
		Reward = "SpeedI",
		RewardCount = 2,
	},
	{
		Id = "weekly_races_long",
		Metric = "Races",
		Target = 50,
		Name = "Finish 50 races",
		Reward = "LuckI",
		RewardCount = 2,
	},
	{
		Id = "weekly_rolls",
		Metric = "Rolls",
		Target = 150,
		Name = "Complete 150 rolls",
		Reward = "MoneyI",
		RewardCount = 2,
	},
	{
		Id = "weekly_discover_long",
		Metric = "Discoveries",
		Target = 10,
		Name = "Discover 10 cars",
		Reward = "SpeedI",
		RewardCount = 2,
	},
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

-- The PICK quests active this period: a Random seeded only by the period key shuffles the pool, so every server
-- gets the same pick. Returns the pool's own tables.
function QuestConfig.Active(weekly, now)
	local pool = weekly and QuestConfig.Weekly or QuestConfig.Daily
	local key = QuestConfig.PeriodKey(now, weekly)
	local rng = Random.new(weekly and key + 1000000 or key)
	local order = table.clone(pool)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	return table.move(order, 1, math.min(QuestConfig.PICK, #order), 1, {})
end

return QuestConfig
