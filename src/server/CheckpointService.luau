--!nonstrict
-- Checkpoints (docs/CHECKPOINT_SPEC.md): Remotes.SetCheckpoint(n) picks the track the player's next auto race starts
-- on. Only beaten tracks (and Track 1) are accepted; the player attribute Checkpoint is saved by PlayerData.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CheckpointConfig = require(ReplicatedStorage.Shared.CheckpointConfig)
local RaceService = require(script.Parent.RaceService)

local CheckpointService = {}

local lastPick = {} -- player -> os.clock() of the last accepted pick

local function trackCount()
	local route = RaceService.GetRoute()
	return route and route.Tracks and #route.Tracks or 0
end

-- ok, reason
function CheckpointService.Set(player, number)
	if not player:GetAttribute("DataLoaded") then
		return false, "Loading"
	end
	if not CheckpointConfig.IsOpen(number, player:GetAttribute("BestTrack"), trackCount()) then
		return false, "Locked"
	end
	local now = os.clock()
	if lastPick[player] and now - lastPick[player] < CheckpointConfig.PICK_COOLDOWN then
		return false, "Please wait"
	end
	lastPick[player] = now
	player:SetAttribute("Checkpoint", number)
	return true
end

function CheckpointService.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("SetCheckpoint") or Instance.new("RemoteFunction")
	remote.Name = "SetCheckpoint"
	remote.Parent = remotes
	remote.OnServerInvoke = CheckpointService.Set
	Players.PlayerRemoving:Connect(function(player)
		lastPick[player] = nil
	end)
end

return CheckpointService
