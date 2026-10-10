--!nonstrict
-- Server-owned prestige reset. Cars, upgrades and workshop ownership survive;
-- Money resets, Speed is preserved, and the permanent rebirth level increases.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.RebirthConfig)

local RebirthService = {}
local lastRequest = setmetatable({}, { __mode = "k" })
RebirthService.REMOTE_COOLDOWN = 0.5

local function stats(player)
	local folder = player:FindFirstChild("leaderstats")
	return folder, folder and folder:FindFirstChild("Money"), folder and folder:FindFirstChild("Speed")
end

function RebirthService.Setup(player)
	if player:GetAttribute("RebirthLevel") == nil then
		player:SetAttribute("RebirthLevel", Config.DEFAULT_LEVEL)
	end
	-- Rebirth is replicated as an attribute; leaderstats is reserved for Money
	-- and Speed, the two HUD stats.
end

function RebirthService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	local level = Config.CleanLevel(saved.RebirthLevel)
	player:SetAttribute("RebirthLevel", level)
	RebirthService.Setup(player)
end

function RebirthService.Requirements(player)
	return Config.Requirements(player:GetAttribute("RebirthLevel"))
end

function RebirthService.Rebirth(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < RebirthService.REMOTE_COOLDOWN then
		return false, "Please wait"
	end
	lastRequest[player] = now
	if player:GetAttribute("DataFailed") or not player:GetAttribute("DataLoaded") then
		return false, "Data not loaded"
	end
	if player:GetAttribute("AutoRacing") == true then
		return false, "Stop Auto before rebirthing"
	end
	local folder, money = stats(player)
	if not folder or not money then
		return false, "Stats not ready"
	end
	local level = Config.CleanLevel(player:GetAttribute("RebirthLevel"))
	local playerLevel = math.max(1, math.floor(tonumber(player:GetAttribute("Level")) or 1))
	if level >= Config.MAX_LEVEL then
		return false, "Maximum rebirth"
	end
	if not Config.CanRebirth(level, playerLevel) then
		local required = Config.Requirements(level)
		return false, string.format("Reach Level %d", required.Level)
	end
	local nextLevel = level + 1
	money.Value = 0
	-- Speed is lifetime progression and survives rebirth.
	player:SetAttribute("RebirthLevel", nextLevel)
	local rebirth = folder:FindFirstChild("Rebirth")
	if rebirth then
		rebirth.Value = nextLevel
	end
	return true, nextLevel
end

function RebirthService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local remote = remotes:FindFirstChild("Rebirth") or Instance.new("RemoteFunction")
	remote.Name = "Rebirth"
	remote.Parent = remotes
	remote.OnServerInvoke = RebirthService.Rebirth
	Players.PlayerAdded:Connect(RebirthService.Setup)
	for _, player in Players:GetPlayers() do
		RebirthService.Setup(player)
	end
end

return RebirthService
