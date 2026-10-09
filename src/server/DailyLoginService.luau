--!nonstrict
-- One UTC claim per day. The server owns claim timing and reward selection.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.DailyLoginConfig)
local MoneyService = require(script.Parent.MoneyService)
local GachaService = require(script.Parent.GachaService)
local BoostService = require(script.Parent.BoostService)
local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)

local Daily = { REMOTE_COOLDOWN = 0.5 }
local lastRequest = setmetatable({}, { __mode = "k" })

local function dayNumber(at)
	return math.floor((at or os.time()) / 86400)
end

function Daily.Setup(player)
	if player:GetAttribute("DailyStreak") == nil then
		player:SetAttribute("DailyStreak", 0)
	end
	if player:GetAttribute("DailyLast") == nil then
		player:SetAttribute("DailyLast", -1)
	end
end

function Daily.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	player:SetAttribute("DailyStreak", math.clamp(math.floor(tonumber(saved.DailyStreak) or 0), 0, #Config.Rewards))
	player:SetAttribute("DailyLast", math.floor(tonumber(saved.DailyLast) or -1))
	Daily.Setup(player)
end

function Daily.Snapshot(player)
	return {
		DailyStreak = math.clamp(math.floor(player:GetAttribute("DailyStreak") or 0), 0, #Config.Rewards),
		DailyLast = math.floor(player:GetAttribute("DailyLast") or -1),
	}
end

local function grantRare(player)
	local data = player:FindFirstChild("GachaData")
	local owned = {}
	if data then
		for _, entry in data:GetChildren() do
			owned[entry.Name] = true
		end
	end
	for _, spec in CarCatalog.Rollable() do
		if spec.Chance and not owned[spec.Id] then
			return GachaService.Grant(player, spec.Id) == true and spec.Name or nil
		end
	end
	return nil
end

function Daily.Claim(player)
	local at = os.time()
	local today = dayNumber(at)
	local requestAt = os.clock()
	if lastRequest[player] and requestAt - lastRequest[player] < Daily.REMOTE_COOLDOWN then
		return false, "Please wait"
	end
	lastRequest[player] = requestAt
	Daily.Setup(player)
	if player:GetAttribute("DataFailed") or not player:GetAttribute("DataLoaded") then
		return false, "Data not loaded"
	end
	if player:GetAttribute("DailyLast") == today then
		return false, "Already claimed today"
	end
	local previous = player:GetAttribute("DailyLast")
	local streak = player:GetAttribute("DailyStreak") or 0
	streak = previous == today - 1 and math.min(streak + 1, #Config.Rewards) or 1
	local reward = Config.Rewards[streak]
	player:SetAttribute("DailyLast", today)
	player:SetAttribute("DailyStreak", streak)
	local paid = MoneyService.Award(player, reward.Money or 0) or 0
	if reward.Boost then
		BoostService.Add(player, reward.Boost, reward.BoostCount or 1)
	end
	local rare = reward.GuaranteedRare and grantRare(player) or nil
	return true, { Day = streak, Money = paid, Boost = reward.Boost, Rare = rare }
end

function Daily.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local claim = remotes:FindFirstChild("DailyClaim") or Instance.new("RemoteFunction")
	claim.Name = "DailyClaim"
	claim.Parent = remotes
	claim.OnServerInvoke = Daily.Claim
	Players.PlayerAdded:Connect(Daily.Setup)
	for _, player in Players:GetPlayers() do
		Daily.Setup(player)
	end
end

return Daily
