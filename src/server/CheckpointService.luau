--!nonstrict
-- Checkpoints (docs/CHECKPOINT_SPEC.md): Remotes.SetCheckpoint(n) picks the track the player's next auto race starts
-- on. Only beaten tracks (and Track 1) are accepted; the player attribute Checkpoint is saved by PlayerData.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CheckpointConfig = require(ReplicatedStorage.Shared.CheckpointConfig)
local RaceService = require(script.Parent.RaceService)
local MoneyService = require(script.Parent.MoneyService)

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

-- What each track's pad pays this player right now: { [tostring(Number)] = MoneyService.Quote } (Cash x Money multi,
-- the same number a win pays). Read-only, for the Checkpoints cards; the client never sends an amount.
local quoteCache = {} -- player -> { At = os.clock(), Quotes = {...} }
function CheckpointService.Payouts(player)
	local cached = quoteCache[player]
	if cached and os.clock() - cached.At < 0.25 then
		return cached.Quotes
	end
	local quotes = {}
	local route = RaceService.GetRoute()
	for _, track in route and route.Tracks or {} do
		if track.Pad and track.Number then
			quotes[tostring(track.Number)] = MoneyService.Quote(player, track.Pad)
		end
	end
	quoteCache[player] = { At = os.clock(), Quotes = quotes }
	return quotes
end

function CheckpointService.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("SetCheckpoint") or Instance.new("RemoteFunction")
	remote.Name = "SetCheckpoint"
	remote.Parent = remotes
	remote.OnServerInvoke = CheckpointService.Set
	local payouts = remotes:FindFirstChild("CheckpointPayouts") or Instance.new("RemoteFunction")
	payouts.Name = "CheckpointPayouts"
	payouts.Parent = remotes
	payouts.OnServerInvoke = CheckpointService.Payouts
	Players.PlayerRemoving:Connect(function(player)
		lastPick[player] = nil
		quoteCache[player] = nil
	end)
end

return CheckpointService
