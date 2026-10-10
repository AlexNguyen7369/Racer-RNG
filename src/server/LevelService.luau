--!nonstrict
-- Server-owned Level/XP progression. XP is earned from current Speed over time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelConfig = require(ReplicatedStorage.Shared.LevelConfig)

local LevelService = {}

local function stats(player)
	local folder = player:FindFirstChild("leaderstats")
	return folder, folder and folder:FindFirstChild("Speed")
end

function LevelService.Setup(player)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	local level = LevelConfig.CleanLevel(player:GetAttribute("Level"))
	if player:GetAttribute("Level") == nil then
		level = LevelConfig.START_LEVEL
	end
	if player:GetAttribute("XP") == nil then
		player:SetAttribute("XP", LevelConfig.START_XP)
	end
	player:SetAttribute("Level", level)
	player:SetAttribute("XPToNext", LevelConfig.XPToNext(level))
	return level
end

function LevelService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	local level = LevelConfig.CleanLevel(saved.Level)
	local xp = LevelConfig.CleanXP(saved.XP)
	LevelService.Setup(player)
	local folder = stats(player)
	if not folder then
		return
	end
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", xp)
	player:SetAttribute("XPToNext", LevelConfig.XPToNext(level))
end

function LevelService.Snapshot(player)
	return {
		Level = LevelConfig.CleanLevel(player:GetAttribute("Level")),
		XP = LevelConfig.CleanXP(player:GetAttribute("XP")),
	}
end

function LevelService.AddXP(player, amount)
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount == -math.huge or amount <= 0 then
		return false
	end
	local level = LevelService.Setup(player)
	local xp = LevelConfig.CleanXP(player:GetAttribute("XP")) + amount
	while level < LevelConfig.MAX_LEVEL and xp >= LevelConfig.XPToNext(level) do
		xp -= LevelConfig.XPToNext(level)
		level += 1
	end
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", xp)
	player:SetAttribute("XPToNext", LevelConfig.XPToNext(level))
	return true
end

function LevelService.Tick(player, dt)
	if type(dt) ~= "number" or dt ~= dt or dt == math.huge or dt == -math.huge or dt <= 0 then
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
