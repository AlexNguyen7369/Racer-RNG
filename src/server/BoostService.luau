--!nonstrict
-- Server-owned consumable boosts. Every potion is a one-minute, tiered item.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.BoostConfig)

local BoostService = {}
BoostService.REMOTE_COOLDOWN = 0.25
local lastRequest = setmetatable({}, { __mode = "k" })

local function cleanCount(value)
	return type(value) == "number" and value == value and math.clamp(math.floor(value), 0, 1000000) or 0
end

local function now()
	return os.time()
end

local function eachItem(fn)
	for _, category in Config.Order do
		for _, item in Config.ItemsFor(category) do
			fn(item)
		end
	end
end

local function setupAttributes(player)
	eachItem(function(item)
		if player:GetAttribute("Boost_" .. item.Id) == nil then
			player:SetAttribute("Boost_" .. item.Id, 0)
		end
		if player:GetAttribute("BoostUntil_" .. item.Id) == nil then
			player:SetAttribute("BoostUntil_" .. item.Id, 0)
		end
	end)
end

function BoostService.Setup(player)
	setupAttributes(player)
end

function BoostService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	local counts = type(saved.Boosts) == "table" and saved.Boosts or {}
	local active = type(saved.ActiveBoosts) == "table" and saved.ActiveBoosts or {}
	eachItem(function(item)
		local count = counts[item.Id]
		if count == nil and item.Tier == 1 then
			count = counts[item.Category]
		end
		local untilAt = active[item.Id]
		if untilAt == nil and item.Tier == 1 then
			untilAt = active[item.Category]
		end
		player:SetAttribute("Boost_" .. item.Id, cleanCount(count))
		player:SetAttribute(
			"BoostUntil_" .. item.Id,
			type(untilAt) == "number" and untilAt > now() and math.floor(untilAt) or 0
		)
	end)
	BoostService.Setup(player)
end

function BoostService.Snapshot(player)
	local counts, active = {}, {}
	eachItem(function(item)
		local id = item.Id
		counts[id] = cleanCount(player:GetAttribute("Boost_" .. id))
		local untilAt = player:GetAttribute("BoostUntil_" .. id)
		if type(untilAt) == "number" and untilAt > now() then
			active[id] = math.floor(untilAt)
		end
	end)
	for _, category in Config.Order do
		local tierOne = Config.ItemsFor(category)[1]
		counts[category] = counts[tierOne.Id]
		if active[tierOne.Id] then
			active[category] = active[tierOne.Id]
		end
	end
	return { Boosts = counts, ActiveBoosts = active }
end

function BoostService.Count(player, id)
	local item = Config.Get(id)
	return item and cleanCount(player:GetAttribute("Boost_" .. item.Id)) or 0
end

function BoostService.Multiplier(player, category)
	local best = 1
	for _, item in Config.ItemsFor(category) do
		local untilAt = player:GetAttribute("BoostUntil_" .. item.Id)
		if type(untilAt) == "number" and untilAt > now() and item.Multiplier > best then
			best = item.Multiplier
		end
	end
	return best
end

function BoostService.Add(player, id, count)
	local item = Config.Get(id)
	if not item then
		return false
	end
	BoostService.Setup(player)
	local key = "Boost_" .. item.Id
	player:SetAttribute(key, cleanCount((player:GetAttribute(key) or 0) + (count or 1)))
	return true
end

function BoostService.Use(player, id)
	local item = Config.Get(id)
	if not item then
		return false, "Unknown boost"
	end
	if player:GetAttribute("DataFailed") or not player:GetAttribute("DataLoaded") then
		return false, "Data not loaded"
	end
	BoostService.Setup(player)
	local key = "Boost_" .. item.Id
	local count = cleanCount(player:GetAttribute(key))
	if count < 1 then
		return false, "You do not own that potion"
	end
	local untilKey = "BoostUntil_" .. item.Id
	local current = player:GetAttribute(untilKey) or 0
	player:SetAttribute(key, count - 1)
	player:SetAttribute(untilKey, math.max(now(), current) + item.Duration)
	return true, item.Duration
end

function BoostService.Purchase(player, id)
	local item = Config.Get(id)
	if not item then
		return false, "Unknown boost"
	end
	if player:GetAttribute("DataFailed") or not player:GetAttribute("DataLoaded") then
		return false, "Data not loaded"
	end
	local at = os.clock()
	if lastRequest[player] and at - lastRequest[player] < BoostService.REMOTE_COOLDOWN then
		return false, "Please wait"
	end
	lastRequest[player] = at
	local stats = player:FindFirstChild("leaderstats")
	local money = stats and stats:FindFirstChild("Money")
	if not money or money.Value < item.Price then
		return false, "Not enough Money"
	end
	money.Value -= item.Price
	BoostService.Add(player, item.Id)
	return true, BoostService.Count(player, item.Id)
end

function BoostService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local buy = remotes:FindFirstChild("PurchaseBoost") or Instance.new("RemoteFunction")
	buy.Name = "PurchaseBoost"
	buy.Parent = remotes
	buy.OnServerInvoke = BoostService.Purchase
	local use = remotes:FindFirstChild("UseBoost") or Instance.new("RemoteFunction")
	use.Name = "UseBoost"
	use.Parent = remotes
	use.OnServerInvoke = BoostService.Use
	Players.PlayerAdded:Connect(BoostService.Setup)
	for _, player in Players:GetPlayers() do
		BoostService.Setup(player)
	end
end

return BoostService
