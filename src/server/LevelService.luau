--!nonstrict
-- Server-owned Level/XP progression. XP is earned from current Speed over time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelConfig = require(ReplicatedStorage.Shared.LevelConfig)

local LevelService = {}

local function stats(player)
	local folder = player:FindFirstChild("leaderstats")
	return folder, folder and folder:FindFirstChild("Speed"), folder and folder:FindFirstChild("Level")
end

function LevelService.Setup(player)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	local level = folder:FindFirstChild("Level")
	if not level then
		level = Instance.new("IntValue")
		level.Name = "Level"
		level.Value = LevelConfig.START_LEVEL
		level.Parent = folder
	end
	if player:GetAttribute("XP") == nil then
		player:SetAttribute("XP", LevelConfig.START_XP)
	end
	player:SetAttribute("Level", level.Value)
	player:SetAttribute("XPToNext", LevelConfig.XPToNext(level.Value))
	return level
end

function LevelService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	local level = LevelConfig.CleanLevel(saved.Level)
	local xp = LevelConfig.CleanXP(saved.XP)
	LevelService.Setup(player)
	local folder, _, value = stats(player)
	if not folder or not value then
		return
	end
	value.Value = level
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", xp)
	player:SetAttribute("XPToNext", LevelConfig.XPToNext(level))
end

function LevelService.Snapshot(player)
	local _, _, value = stats(player)
	return {
		Level = LevelConfig.CleanLevel(value and value.Value),
		XP = LevelConfig.CleanXP(player:GetAttribute("XP")),
	}
end

function LevelService.AddXP(player, amount)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	local level = LevelService.Setup(player)
	local xp = LevelConfig.CleanXP(player:GetAttribute("XP")) + amount
	while level.Value < LevelConfig.MAX_LEVEL and xp >= LevelConfig.XPToNext(level.Value) do
		xp -= LevelConfig.XPToNext(level.Value)
		level.Value += 1
	end
	player:SetAttribute("Level", level.Value)
	player:SetAttribute("XP", xp)
	player:SetAttribute("XPToNext", LevelConfig.XPToNext(level.Value))
	return true
end

function LevelService.Tick(player, dt)
	if type(dt) ~= "number" or dt <= 0 then
		return false
	end
	local _, speed = stats(player)
	local currentSpeed = speed and math.max(0, speed.Value) or 0
	return LevelService.AddXP(player, LevelConfig.XP_PER_SECOND * math.sqrt(currentSpeed) * dt)
end

function LevelService.Start()
	Players.PlayerAdded:Connect(LevelService.Setup)
	for _, player in Players:GetPlayers() do
		LevelService.Setup(player)
	end
end

return LevelService
