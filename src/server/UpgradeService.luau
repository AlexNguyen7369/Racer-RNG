--!nonstrict
-- Upgrade tree, server side (docs/UPGRADE_TREE_DESIGN.md). The server owns all of it; clients only see:
--   player.Upgrades: one StringValue per owned tile id
--   player attributes: BestTrack, TurboCount, TurboEvery, TurboMulti, UpgradesBuyable (the badge)
-- Remotes.BuyUpgrade(tileId) -> ok, reason. The client never sends a price.
-- Requires shared modules only: GachaService, MoneyService and CarService require this module, so it reads and writes
-- leaderstats.Money itself and tells CarService about WalkSpeed changes through OnChanged.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeTree = require(Shared.UpgradeTree)
local UpgradeConfig = require(Shared.UpgradeConfig)

local UpgradeService = {}

UpgradeService.REMOTE_COOLDOWN = 0.15 -- seconds between accepted BuyUpgrade requests per player

local MAX_COUNT = 1e9
local MAX_ID_LENGTH = 64

local trackCount = 0 -- number of tracks in the chain, set by Main (the gate needs it, UpgradeTree fails open at 0)
local lastRequest = setmetatable({}, { __mode = "k" }) -- player -> os.clock()
local watchedMoney = setmetatable({}, { __mode = "k" }) -- player -> the Money value whose Changed refreshes the badge
local listeners = {}

local function cleanCount(n)
	if type(n) ~= "number" or n ~= n or n < 0 then
		return 0
	end
	return math.floor(math.min(n, MAX_COUNT))
end

local function folder(player)
	local data = player:FindFirstChild("Upgrades")
	if not data then
		data = Instance.new("Folder")
		data.Name = "Upgrades"
		data.Parent = player
	end
	return data
end

-- leaderstats.Money, created like MoneyService.Setup does (same shape, so either can come first).
local function moneyValue(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local money = stats:FindFirstChild("Money")
	if not money then
		money = Instance.new("IntValue")
		money.Name = "Money"
		money.Value = 0
		money.Parent = stats
	end
	return money
end

-- The chain length the gate uses (Main passes #chain).
function UpgradeService.SetTrackCount(n)
	trackCount = cleanCount(n)
end

function UpgradeService.TrackCount()
	return trackCount
end

-- fn(player) runs after the player's tiles or BestTrack change (CarService re-applies WalkSpeed).
function UpgradeService.OnChanged(fn)
	table.insert(listeners, fn)
end

-- Set { [tileId] = true } of the player's tiles (Start included).
function UpgradeService.Owned(player)
	local owned = { [UpgradeConfig.START_ID] = true }
	local data = player:FindFirstChild("Upgrades")
	if data then
		for _, entry in data:GetChildren() do
			owned[entry.Name] = true
		end
	end
	return owned
end

local function state(player)
	return {
		Owned = UpgradeService.Owned(player),
		Money = moneyValue(player).Value,
		BestTrack = cleanCount(player:GetAttribute("BestTrack")),
		TrackCount = trackCount,
	}
end

-- Effects, read by GachaService (Bonuses, RollInterval, Turbo) and CarService (WalkSpeed).
function UpgradeService.Bonuses(player)
	return UpgradeTree.Bonuses(UpgradeService.Owned(player))
end

function UpgradeService.RollInterval(player)
	return UpgradeTree.RollInterval(UpgradeService.Owned(player))
end

function UpgradeService.Turbo(player)
	return UpgradeTree.Turbo(UpgradeService.Owned(player))
end

function UpgradeService.WalkSpeed(player)
	return UpgradeTree.WalkSpeed(UpgradeService.Owned(player))
end

-- Recomputes the replicated attributes: turbo tier (progress capped below its Every) and the badge.
function UpgradeService.Refresh(player)
	local turbo = UpgradeService.Turbo(player)
	player:SetAttribute("TurboEvery", turbo.Every)
	player:SetAttribute("TurboMulti", turbo.Multi)
	player:SetAttribute("TurboCount", math.min(cleanCount(player:GetAttribute("TurboCount")), turbo.Every - 1))
	player:SetAttribute("UpgradesBuyable", UpgradeTree.BuyableCount(state(player)))
end

local function changed(player)
	UpgradeService.Refresh(player)
	for _, fn in listeners do
		task.spawn(fn, player)
	end
end

-- Creates player.Upgrades and the attributes (idempotent). Works on any Instance.
function UpgradeService.Setup(player)
	local data = folder(player)
	if player:GetAttribute("BestTrack") == nil then
		player:SetAttribute("BestTrack", 0)
	end
	if player:GetAttribute("TurboCount") == nil then
		player:SetAttribute("TurboCount", 0)
	end
	-- The badge follows Money (wins, cash-outs, admin): watch this player's Money value once
	local money = moneyValue(player)
	if watchedMoney[player] ~= money then
		watchedMoney[player] = money
		money.Changed:Connect(function()
			if player.Parent or not player:IsA("Player") then
				player:SetAttribute("UpgradesBuyable", UpgradeTree.BuyableCount(state(player)))
			end
		end)
	end
	UpgradeService.Refresh(player)
	return data
end

-- The turbo state of the player's next roll, then advances it: returns the luck multi for that roll (1 on a normal
-- roll, the tier's Multi on a turbo roll). Turbo when TurboCount + 1 >= Every, which resets TurboCount to 0.
function UpgradeService.AdvanceTurbo(player)
	local turbo = UpgradeService.Turbo(player)
	local count = math.min(cleanCount(player:GetAttribute("TurboCount")), turbo.Every - 1)
	local multi = 1
	if count + 1 >= turbo.Every then
		multi = turbo.Multi
		count = 0
	else
		count += 1
	end
	player:SetAttribute("TurboCount", count)
	player:SetAttribute("TurboEvery", turbo.Every)
	player:SetAttribute("TurboMulti", turbo.Multi)
	return multi
end

local function accept(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < UpgradeService.REMOTE_COOLDOWN then
		return false
	end
	lastRequest[player] = now
	return true
end

-- Validated purchase: takes the price from leaderstats.Money exactly once and grants the tile. ok, reason.
-- Reasons: "cooldown" (too soon after the last request), then UpgradeTree.CanBuy's ("unknown", "owned", "locked",
-- "gated", "money"). A rejected request changes nothing.
function UpgradeService.Buy(player, tileId)
	if not accept(player) then
		return false, "cooldown"
	end
	UpgradeService.Setup(player)
	local ok, reason = UpgradeTree.CanBuy(state(player), tileId)
	if not ok then
		return false, reason
	end
	local money = moneyValue(player)
	money.Value -= UpgradeTree.Price(tileId)
	local entry = Instance.new("StringValue")
	entry.Name = tileId
	entry.Value = tileId
	entry.Parent = folder(player)
	changed(player)
	return true, nil
end

-- Raises BestTrack to trackNumber if higher (called by RaceService on a won / finished track).
function UpgradeService.ReachTrack(player, trackNumber)
	if type(trackNumber) ~= "number" or trackNumber ~= trackNumber then
		return
	end
	local n = cleanCount(trackNumber)
	if n > cleanCount(player:GetAttribute("BestTrack")) then
		player:SetAttribute("BestTrack", n)
		changed(player)
	end
end

-- Save format (PlayerData VERSION 4): { Upgrades = { id, ... } (sorted), BestTrack = n, TurboCount = n }.
function UpgradeService.Snapshot(player)
	local ids = {}
	local data = player:FindFirstChild("Upgrades")
	if data then
		for _, entry in data:GetChildren() do
			table.insert(ids, entry.Name)
		end
		table.sort(ids)
	end
	return {
		Upgrades = ids,
		BestTrack = cleanCount(player:GetAttribute("BestTrack")),
		TurboCount = cleanCount(player:GetAttribute("TurboCount")),
	}
end

-- Loads a saved table (anything else gives a fresh tree). Unknown tile ids are kept (permanent save keys) but never
-- count. A save without TurboCount (version 3) continues the old every-10th-roll bar: Rolls % 10.
function UpgradeService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	local data = folder(player)
	data:ClearAllChildren()
	if type(saved.Upgrades) == "table" then
		for _, id in saved.Upgrades do
			if
				type(id) == "string"
				and id ~= ""
				and id ~= UpgradeConfig.START_ID
				and #id <= MAX_ID_LENGTH
				and not data:FindFirstChild(id)
			then
				local entry = Instance.new("StringValue")
				entry.Name = id
				entry.Value = id
				entry.Parent = data
			end
		end
	end
	player:SetAttribute("BestTrack", cleanCount(saved.BestTrack))
	local turboCount = saved.TurboCount
	if type(turboCount) ~= "number" then
		turboCount = cleanCount(saved.Rolls) % UpgradeConfig.BASE_TURBO.Every
	end
	player:SetAttribute("TurboCount", cleanCount(turboCount))
	UpgradeService.Setup(player) -- watches Money for the badge (also refreshes the attributes)
	changed(player)
end

-- Creates Remotes.BuyUpgrade and keeps UpgradesBuyable current.
function UpgradeService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local buy = remotes:FindFirstChild("BuyUpgrade")
	if not buy then
		buy = Instance.new("RemoteFunction")
		buy.Name = "BuyUpgrade"
		buy.Parent = remotes
	end
	buy.OnServerInvoke = function(player, tileId)
		return UpgradeService.Buy(player, tileId)
	end

	local function onPlayer(player)
		UpgradeService.Setup(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return UpgradeService
