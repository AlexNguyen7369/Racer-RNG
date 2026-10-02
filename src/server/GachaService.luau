--!nonstrict
-- Car gacha, index and stat allocation. The server owns all of it; clients only see:
--   player.GachaData: one StringValue per owned car Id (discovering a car = owning it; no duplicate counts)
--   player attributes: EquippedCar, Rolls, StatPoints (free points), Alloc_<Stat> for each GachaConfig.STATS
-- Every unique car in the index counts towards stat points (GachaConfig.EarnedPoints); earned points are
-- never stored, only what was allocated, so the two can not drift apart. Saved by PlayerData (Snapshot/Apply).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared.CarCatalog)
local GachaConfig = require(Shared.GachaConfig)

local GachaService = {}

GachaService.REMOTE_COOLDOWN = 0.15 -- seconds between accepted EquipCar / AllocateStat requests per player

local MAX_COUNT = 1e9
local STARTER = CarCatalog.STARTER_ID

local rng = Random.new()
local lastRequest = setmetatable({}, { __mode = "k" }) -- player -> os.clock()
local autoRolls = setmetatable({}, { __mode = "k" }) -- player -> handle
local rollRemote = nil -- Remotes.RollResult, made by Start(): tells the player what they rolled

local function cleanCount(n)
	if type(n) ~= "number" or n ~= n or n < 0 then
		return 0
	end
	return math.floor(math.min(n, MAX_COUNT))
end

local function addEntry(data, id)
	local entry = Instance.new("StringValue")
	entry.Name = id
	entry.Value = id
	entry.Parent = data
end

local function folder(player)
	local data = player:FindFirstChild("GachaData")
	if not data then
		data = Instance.new("Folder")
		data.Name = "GachaData"
		data.Parent = player
	end
	return data
end

-- Creates GachaData and the attributes (idempotent). Works on any Instance.
function GachaService.Setup(player)
	local data = folder(player)
	if player:GetAttribute("EquippedCar") == nil then
		player:SetAttribute("EquippedCar", STARTER)
	end
	if player:GetAttribute("Rolls") == nil then
		player:SetAttribute("Rolls", 0)
	end
	for _, stat in GachaConfig.STATS do
		if player:GetAttribute("Alloc_" .. stat) == nil then
			player:SetAttribute("Alloc_" .. stat, 0)
		end
	end
	if player:GetAttribute("StatPoints") == nil then
		player:SetAttribute("StatPoints", 0)
	end
	return data
end

local function alloc(player)
	local a = {}
	for _, stat in GachaConfig.STATS do
		a[stat] = cleanCount(player:GetAttribute("Alloc_" .. stat))
	end
	return a
end

local function allocSum(a)
	local sum = 0
	for _, stat in GachaConfig.STATS do
		sum += a[stat]
	end
	return sum
end

-- Number of distinct catalog cars the player has discovered (unknown ids from old saves do not count).
function GachaService.UniqueCount(player)
	local data = player:FindFirstChild("GachaData")
	if not data then
		return 0
	end
	local n = 0
	for _, entry in data:GetChildren() do
		local spec = CarCatalog.Get(entry.Name)
		if spec and spec.Rollable then
			n += 1
		end
	end
	return n
end

function GachaService.EarnedPoints(player)
	return GachaConfig.EarnedPoints(GachaService.UniqueCount(player))
end

function GachaService.FreePoints(player)
	return math.max(0, GachaService.EarnedPoints(player) - allocSum(alloc(player)))
end

local function refreshPoints(player)
	player:SetAttribute("StatPoints", GachaService.FreePoints(player))
end

local function owns(player, id)
	if id == STARTER then
		return true
	end
	local data = player:FindFirstChild("GachaData")
	return data ~= nil and data:FindFirstChild(id) ~= nil
end

-- Discovers a catalog car. Returns true if it is new to the index, false if already owned (nothing changes),
-- nil (and changes nothing) for anything that is not a rollable car Id.
function GachaService.Grant(player, id)
	if type(id) ~= "string" then
		return nil
	end
	local spec = CarCatalog.Get(id)
	if not spec or not spec.Rollable then
		return nil
	end
	local data = GachaService.Setup(player)
	if data:FindFirstChild(id) then
		return false
	end
	addEntry(data, id)
	refreshPoints(player)
	return true
end

-- One roll at the player's luck, times GachaConfig.TURBO_LUCK on every TURBO_EVERY-th roll. Returns the car Id,
-- whether it was new and the turbo multi (1 on a normal roll).
function GachaService.Roll(player, roller)
	GachaService.Setup(player)
	local rollNumber = math.min(cleanCount(player:GetAttribute("Rolls")) + 1, MAX_COUNT)
	local turboMulti = GachaConfig.IsTurbo(rollNumber) and GachaConfig.TURBO_LUCK or 1
	local id = GachaConfig.Roll(roller or rng, GachaService.Luck(player) * turboMulti)
	player:SetAttribute("Rolls", rollNumber)
	local isNew = GachaService.Grant(player, id)
	if rollRemote and player:IsA("Player") then
		rollRemote:FireClient(player, id, isNew, turboMulti)
	end
	return id, isNew, turboMulti
end

-- Equips the starter or an owned car. Returns true if it is now equipped.
function GachaService.Equip(player, id)
	if type(id) ~= "string" or not CarCatalog.Get(id) or not owns(player, id) then
		return false
	end
	GachaService.Setup(player)
	player:SetAttribute("EquippedCar", id)
	return true
end

-- Spends one free stat point on a stat in GachaConfig.STATS. Returns true if spent.
function GachaService.Allocate(player, stat)
	if type(stat) ~= "string" or GachaConfig.PER_POINT[stat] == nil then
		return false
	end
	GachaService.Setup(player)
	if GachaService.FreePoints(player) < 1 then
		return false
	end
	player:SetAttribute("Alloc_" .. stat, cleanCount(player:GetAttribute("Alloc_" .. stat)) + 1)
	refreshPoints(player)
	return true
end

-- Equipped car's multi times the Speed stat multi. 1 for a fresh player.
function GachaService.SpeedMulti(player)
	local spec = CarCatalog.Get(player:GetAttribute("EquippedCar"))
	local carMulti = spec and owns(player, spec.Id) and spec.SpeedMulti or 1
	return carMulti * GachaConfig.Multis(alloc(player)).Speed
end

function GachaService.MoneyMulti(player)
	return GachaConfig.Multis(alloc(player)).Money
end

function GachaService.Luck(player)
	return GachaConfig.Multis(alloc(player)).Luck
end

-- The save format: { Cars = { id, ... } (sorted), Equipped = id, Rolls = n, StatAlloc = { [stat] = n } }.
function GachaService.Snapshot(player)
	local cars = {}
	local data = player:FindFirstChild("GachaData")
	if data then
		for _, entry in data:GetChildren() do
			table.insert(cars, entry.Name)
		end
		table.sort(cars)
	end
	local equipped = player:GetAttribute("EquippedCar")
	return {
		Cars = cars,
		Equipped = type(equipped) == "string" and equipped or STARTER,
		Rolls = cleanCount(player:GetAttribute("Rolls")),
		StatAlloc = alloc(player),
	}
end

local TRIM_ORDER = { "Workshop", "Money", "Luck", "Speed" } -- over-allocation is removed in this order

-- Loads a saved table (anything else gives a fresh player). Unknown car ids are kept so a car taken out of
-- the catalog is not wiped from saves, but they never count for points or multis.
function GachaService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	local data = folder(player)
	data:ClearAllChildren()
	-- Cars is an array of ids; early saves used a map { [id] = count } (count > 0 or true = owned)
	if type(saved.Cars) == "table" then
		for key, value in saved.Cars do
			local id = nil
			if type(key) == "number" then
				id = value
			elseif value == true or (type(value) == "number" and value == value and value > 0) then
				id = key
			end
			if type(id) == "string" and id ~= "" and id ~= STARTER and #id <= 64 and not data:FindFirstChild(id) then
				addEntry(data, id)
			end
		end
	end
	player:SetAttribute("Rolls", cleanCount(saved.Rolls))

	local a = {}
	local savedAlloc = type(saved.StatAlloc) == "table" and saved.StatAlloc or {}
	for _, stat in GachaConfig.STATS do
		a[stat] = cleanCount(savedAlloc[stat])
	end
	local over = allocSum(a) - GachaConfig.EarnedPoints(GachaService.UniqueCount(player))
	for _, stat in TRIM_ORDER do
		if over <= 0 then
			break
		end
		local cut = math.min(a[stat], over)
		a[stat] -= cut
		over -= cut
	end
	for _, stat in GachaConfig.STATS do
		player:SetAttribute("Alloc_" .. stat, a[stat])
	end

	local equipped = saved.Equipped
	if type(equipped) ~= "string" or not CarCatalog.Get(equipped) or not owns(player, equipped) then
		equipped = STARTER
	end
	player:SetAttribute("EquippedCar", equipped)
	refreshPoints(player)
end

-- Rolls once every GachaConfig.ROLL_INTERVAL seconds until handle:Stop() (or the player is gone).
function GachaService.StartAutoRoll(player)
	local handle = { Running = true }
	function handle:Stop()
		self.Running = false
	end
	task.spawn(function()
		while handle.Running and player.Parent do
			task.wait(GachaConfig.ROLL_INTERVAL)
			if handle.Running and player.Parent then
				GachaService.Roll(player)
			end
		end
	end)
	return handle
end

local function accept(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < GachaService.REMOTE_COOLDOWN then
		return false
	end
	lastRequest[player] = now
	return true
end

local function remote(remotes, name)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r
end

function GachaService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	rollRemote = remote(remotes, "RollResult")
	remote(remotes, "EquipCar").OnServerEvent:Connect(function(player, id)
		if accept(player) then
			GachaService.Equip(player, id)
		end
	end)
	remote(remotes, "AllocateStat").OnServerEvent:Connect(function(player, stat)
		if accept(player) then
			GachaService.Allocate(player, stat)
		end
	end)

	local function onPlayer(player)
		GachaService.Setup(player)
		-- Rolling before the save is loaded would be overwritten by the load: wait for it (or for it to fail,
		-- then the player still rolls but nothing is saved).
		task.spawn(function()
			while player.Parent and not player:GetAttribute("DataLoaded") and not player:GetAttribute("DataFailed") do
				task.wait(0.2)
			end
			if player.Parent and not autoRolls[player] then
				autoRolls[player] = GachaService.StartAutoRoll(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local handle = autoRolls[player]
		if handle then
			handle:Stop()
			autoRolls[player] = nil
		end
	end)
end

return GachaService
