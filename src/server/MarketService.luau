--!nonstrict
-- Server-owned Market purchases and equipment. The client never supplies a price or effect.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MarketConfig = require(Shared.MarketConfig)
local MoneyService = require(script.Parent.MoneyService)
local BoostService = require(script.Parent.BoostService)

local MarketService = {}
MarketService.REMOTE_COOLDOWN = 0.25
local lastRequest = setmetatable({}, { __mode = "k" })

local function owns(player, kind, id)
	return player:GetAttribute("Own" .. kind .. "_" .. id) == true
end

local function setOwned(player, kind, id, value)
	player:SetAttribute("Own" .. kind .. "_" .. id, value == true and true or nil)
end

function MarketService.Snapshot(player)
	local ownedAuras, ownedTrails = {}, {}
	for _, item in MarketConfig.Items.Aura do
		if owns(player, "Aura", item.Id) then
			table.insert(ownedAuras, item.Id)
		end
	end
	for _, item in MarketConfig.Items.Trail do
		if owns(player, "Trail", item.Id) then
			table.insert(ownedTrails, item.Id)
		end
	end
	return {
		OwnedAuras = ownedAuras,
		OwnedTrails = ownedTrails,
		EquippedAura = player:GetAttribute("EquippedAura"),
		EquippedTrail = player:GetAttribute("EquippedTrail"),
	}
end

function MarketService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	for _, item in MarketConfig.Items.Aura do
		setOwned(player, "Aura", item.Id, false)
	end
	for _, item in MarketConfig.Items.Trail do
		setOwned(player, "Trail", item.Id, false)
	end
	for _, id in type(saved.OwnedAuras) == "table" and saved.OwnedAuras or {} do
		if MarketConfig.Get("Aura", id) then
			setOwned(player, "Aura", id, true)
		end
	end
	for _, id in type(saved.OwnedTrails) == "table" and saved.OwnedTrails or {} do
		if MarketConfig.Get("Trail", id) then
			setOwned(player, "Trail", id, true)
		end
	end
	local aura = saved.EquippedAura
	local trail = saved.EquippedTrail
	player:SetAttribute("EquippedAura", MarketConfig.Get("Aura", aura) and owns(player, "Aura", aura) and aura or nil)
	player:SetAttribute(
		"EquippedTrail",
		MarketConfig.Get("Trail", trail) and owns(player, "Trail", trail) and trail or nil
	)
end

function MarketService.Purchase(player, kind, id)
	local item = MarketConfig.Get(kind, id)
	if not item then
		return false, "Already owned or unavailable"
	end
	if kind == "Potion" then
		local ok, result = BoostService.Purchase(player, id)
		return ok, ok and ("Purchased " .. item.Name .. " • Bag x" .. tostring(result)) or result
	end
	if owns(player, kind, id) then
		return false, "Already owned or unavailable"
	end
	local money = MoneyService.Setup(player)
	if money.Value < item.Price then
		return false, "Not enough money"
	end
	money.Value -= item.Price
	setOwned(player, kind, id, true)
	return true, "Purchased " .. item.Name
end

function MarketService.Equip(player, kind, id)
	local item = MarketConfig.Get(kind, id)
	if not item or not owns(player, kind, id) then
		return false, "Buy it first"
	end
	player:SetAttribute("Equipped" .. kind, id)
	return true, "Equipped " .. item.Name
end

local function allowed(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < MarketService.REMOTE_COOLDOWN then
		return false
	end
	lastRequest[player] = now
	return true
end

function MarketService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local open = remotes:FindFirstChild("MarketOpen") or Instance.new("RemoteEvent")
	open.Name = "MarketOpen"
	open.Parent = remotes
	local purchase = remotes:FindFirstChild("MarketPurchase") or Instance.new("RemoteFunction")
	purchase.Name = "MarketPurchase"
	purchase.Parent = remotes
	purchase.OnServerInvoke = function(player, kind, id)
		if not allowed(player) then
			return false, "Please wait"
		end
		return MarketService.Purchase(player, kind, id)
	end
	local equip = remotes:FindFirstChild("MarketEquip") or Instance.new("RemoteFunction")
	equip.Name = "MarketEquip"
	equip.Parent = remotes
	equip.OnServerInvoke = function(player, kind, id)
		if not allowed(player) then
			return false, "Please wait"
		end
		return MarketService.Equip(player, kind, id)
	end
	local function watch(part)
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				open:FireClient(player)
			end)
		end
	end
	CollectionService:GetInstanceAddedSignal("MarketPad"):Connect(watch)
	for _, part in CollectionService:GetTagged("MarketPad") do
		watch(part)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return MarketService
