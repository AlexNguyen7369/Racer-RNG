--!nonstrict
-- Server-authoritative daily and weekly quest progress and claims.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.QuestConfig)
local BoostService = require(script.Parent.BoostService)

local QuestService = {}
local state = setmetatable({}, { __mode = "k" })
local lastRequest = setmetatable({}, { __mode = "k" })
QuestService.REMOTE_COOLDOWN = 0.2

local function cleanMap(value)
	local result = {}
	if type(value) == "table" then
		for id, amount in value do
			if type(id) == "string" and type(amount) == "number" and amount >= 0 then
				result[id] = math.floor(amount)
			end
		end
	end
	return result
end

local function ensure(player)
	local current = state[player]
	if current then
		return current
	end
	current = {
		DailyKey = Config.PeriodKey(os.time()),
		WeeklyKey = Config.PeriodKey(os.time(), true),
		Daily = {},
		Weekly = {},
		ClaimedDaily = {},
		ClaimedWeekly = {},
	}
	state[player] = current
	return current
end

local function reset(current, now)
	local dailyKey = Config.PeriodKey(now)
	local weeklyKey = Config.PeriodKey(now, true)
	if current.DailyKey ~= dailyKey then
		current.DailyKey, current.Daily, current.ClaimedDaily = dailyKey, {}, {}
	end
	if current.WeeklyKey ~= weeklyKey then
		current.WeeklyKey, current.Weekly, current.ClaimedWeekly = weeklyKey, {}, {}
	end
end

local function publish(player)
	local current = ensure(player)
	reset(current, os.time())
	player:SetAttribute("QuestDailyKey", current.DailyKey)
	player:SetAttribute("QuestWeeklyKey", current.WeeklyKey)
	player:SetAttribute("QuestDailyProgress", game:GetService("HttpService"):JSONEncode(current.Daily))
	player:SetAttribute("QuestWeeklyProgress", game:GetService("HttpService"):JSONEncode(current.Weekly))
	player:SetAttribute("QuestDailyClaimed", game:GetService("HttpService"):JSONEncode(current.ClaimedDaily))
	player:SetAttribute("QuestWeeklyClaimed", game:GetService("HttpService"):JSONEncode(current.ClaimedWeekly))
end

local function list(weekly)
	return weekly and Config.Weekly or Config.Daily
end

function QuestService.Setup(player)
	ensure(player)
	publish(player)
end

function QuestService.Apply(player, saved)
	local current = ensure(player)
	saved = type(saved) == "table" and saved or {}
	current.DailyKey = tonumber(saved.QuestDailyKey) or Config.PeriodKey(os.time())
	current.WeeklyKey = tonumber(saved.QuestWeeklyKey) or Config.PeriodKey(os.time(), true)
	current.Daily = cleanMap(saved.QuestDaily)
	current.Weekly = cleanMap(saved.QuestWeekly)
	current.ClaimedDaily = cleanMap(saved.QuestDailyClaimed)
	current.ClaimedWeekly = cleanMap(saved.QuestWeeklyClaimed)
	publish(player)
end

function QuestService.Snapshot(player)
	local current = ensure(player)
	reset(current, os.time())
	return {
		QuestDailyKey = current.DailyKey,
		QuestWeeklyKey = current.WeeklyKey,
		QuestDaily = table.clone(current.Daily),
		QuestWeekly = table.clone(current.Weekly),
		QuestDailyClaimed = table.clone(current.ClaimedDaily),
		QuestWeeklyClaimed = table.clone(current.ClaimedWeekly),
	}
end

function QuestService.Progress(player, metric, amount)
	if typeof(player) ~= "Instance" or type(metric) ~= "string" then
		return
	end
	local current = ensure(player)
	reset(current, os.time())
	amount = math.max(1, math.floor(tonumber(amount) or 1))
	for _, weekly in { false, true } do
		local progress = weekly and current.Weekly or current.Daily
		for _, quest in list(weekly) do
			if
				quest.Metric == metric
				and not (weekly and current.ClaimedWeekly[quest.Id] or current.ClaimedDaily[quest.Id])
			then
				progress[quest.Id] = math.min(quest.Target, (progress[quest.Id] or 0) + amount)
			end
		end
	end
	publish(player)
end

local function find(weekly, id)
	for _, quest in list(weekly) do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

function QuestService.Claim(player, weekly, id)
	if type(weekly) ~= "boolean" or type(id) ~= "string" then
		return false, "Invalid quest"
	end
	local at = os.clock()
	if lastRequest[player] and at - lastRequest[player] < QuestService.REMOTE_COOLDOWN then
		return false, "Please wait"
	end
	lastRequest[player] = at
	local current = ensure(player)
	reset(current, os.time())
	local quest = find(weekly, id)
	local progress = weekly and current.Weekly or current.Daily
	local claimed = weekly and current.ClaimedWeekly or current.ClaimedDaily
	if not quest then
		return false, "Unknown quest"
	end
	if claimed[id] then
		return false, "Already claimed"
	end
	if (progress[id] or 0) < quest.Target then
		return false, "Quest incomplete"
	end
	claimed[id] = 1
	BoostService.Add(player, quest.Reward, quest.RewardCount)
	publish(player)
	return true, quest.Reward
end

function QuestService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local claim = remotes:FindFirstChild("QuestClaim") or Instance.new("RemoteFunction")
	claim.Name = "QuestClaim"
	claim.Parent = remotes
	claim.OnServerInvoke = QuestService.Claim
	Players.PlayerAdded:Connect(QuestService.Setup)
	for _, player in Players:GetPlayers() do
		QuestService.Setup(player)
	end
end

return QuestService
