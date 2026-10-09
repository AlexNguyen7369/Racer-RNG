--!nonstrict
-- Car gacha, index and stat allocation. The server owns all of it; clients only see:
--   player.GachaData: one StringValue per owned car Id (discovering a car = owning it; no duplicate counts)
--   player attributes: EquippedCar, Rolls, StatPoints (free points), Alloc_<Stat> for each GachaConfig.STATS,
--   AutoRoll (the AUTO toggle of the roll view, true on join, not saved)
-- Every unique car in the index counts towards stat points (GachaConfig.EarnedPoints); earned points are
-- never stored, only what was allocated, so the two can not drift apart. Saved by PlayerData (Snapshot/Apply).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared.CarCatalog)
local GachaConfig = require(Shared.GachaConfig)
local RebirthConfig = require(Shared.RebirthConfig)
local RollAnimConfig = require(Shared.RollAnimConfig)
local UpgradeService = require(script.Parent.UpgradeService)

local GachaService = {}

GachaService.REMOTE_COOLDOWN = 0.15 -- seconds between accepted EquipCar / AllocateStat requests per player

local MAX_COUNT = 1e9
local STARTER = CarCatalog.STARTER_ID

local rng = Random.new()
local lastRequest = setmetatable({}, { __mode = "k" }) -- player -> os.clock()
local autoRolls = setmetatable({}, { __mode = "k" }) -- player -> handle
local rollRemote = nil -- Remotes.RollResult, made by Start(): tells the player what they rolled
local announceRemote = nil -- Remotes.RollAnnounce, made by Start(): an emphasized roll, to everyone in the server

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
	if player:GetAttribute("AutoRoll") == nil then
		player:SetAttribute("AutoRoll", true)
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

function GachaService.ScrapValue(id)
	return GachaConfig.ScrapMoney(CarCatalog.Get(id))
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

local function ownedIds(player)
	local ids = {}
	local data = player:FindFirstChild("GachaData")
	if data then
		for _, entry in data:GetChildren() do
			table.insert(ids, entry.Name)
		end
	end
	return ids
end

-- Tells everyone in the server about an emphasized roll (Client/RollAnnounce shows it in chat). `rolls` is the
-- player's Rolls after it. Does nothing for anything that is not a real Player (test fakes).
function GachaService.Announce(player, id, rolls)
	if announceRemote and typeof(player) == "Instance" and player:IsA("Player") then
		announceRemote:FireAllClients(player.UserId, player.DisplayName, id, rolls)
	end
end

-- One roll at the player's luck, times the Turbo tier's Multi on every turbo roll (UpgradeService.AdvanceTurbo: the
-- player's TurboCount reaches the tier's Every; x5 every 10th roll with no Turbo tier). Returns the car Id,
-- whether it was new, the turbo multi (1 on a normal roll) and whether it is emphasized (GachaConfig.IsEmphasized:
-- played enlarged and announced to the whole server).
function GachaService.Roll(player, roller)
	GachaService.Setup(player)
	local rollNumber = math.min(cleanCount(player:GetAttribute("Rolls")) + 1, MAX_COUNT)
	local turboMulti = UpgradeService.AdvanceTurbo(player)
	local event = require(script.Parent.WeatherService).Current()
	local id = GachaConfig.Roll(roller or rng, GachaService.Luck(player) * turboMulti, event)
	local emphasized = GachaConfig.IsEmphasized(id, ownedIds(player))
	player:SetAttribute("Rolls", rollNumber)
	local isNew = GachaService.Grant(player, id)
	local scrapMoney = 0
	if isNew == false then
		-- MoneyService requires GachaService for payout multis, so load it lazily.
		local MoneyService = require(script.Parent.MoneyService)
		scrapMoney = GachaService.ScrapValue(id)
		MoneyService.Award(player, scrapMoney)
	end
	if rollRemote and player:IsA("Player") then
		rollRemote:FireClient(player, id, isNew, turboMulti, emphasized, scrapMoney)
	end
	if emphasized then
		GachaService.Announce(player, id, rollNumber)
	end
	return id, isNew, turboMulti, emphasized, scrapMoney
end

-- The AUTO toggle: while false the auto-roll loop makes no roll. Returns true if the value was applied.
function GachaService.SetAutoRoll(player, on)
	if type(on) ~= "boolean" then
		return false
	end
	GachaService.Setup(player)
	player:SetAttribute("AutoRoll", on)
	return true
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

-- The equipped car changes base/cruise speed only. It must not affect passive
-- racing or workshop gain.
function GachaService.CarSpeedMulti(player)
	local spec = CarCatalog.Get(player:GetAttribute("EquippedCar"))
	local carMulti = spec and owns(player, spec.Id) and spec.SpeedMulti or 1
	return carMulti
end

-- Passive racing gain is determined by rebirth level. Car models and car/stat
-- allocation do not multiply this value.
function GachaService.SpeedGainMulti(player)
	return RebirthConfig.SpeedGainMulti(player:GetAttribute("RebirthLevel"))
end

-- Compatibility entry point for callers that ask for the passive racing
-- multiplier. It intentionally excludes the equipped car and stat allocation.
function GachaService.SpeedMulti(player)
	return GachaService.SpeedGainMulti(player)
end

function GachaService.MoneyMulti(player)
	return GachaConfig.Multis(alloc(player), UpgradeService.Bonuses(player)).Money
		* RebirthConfig.MoneyMulti(player:GetAttribute("RebirthLevel"))
		* require(script.Parent.BoostService).Multiplier(player, "Money")
		* require(script.Parent.WeatherService).Multipliers().Money
end

function GachaService.Luck(player)
	return GachaConfig.Multis(alloc(player), UpgradeService.Bonuses(player)).Luck
		* RebirthConfig.LuckMulti(player:GetAttribute("RebirthLevel"))
		* require(script.Parent.BoostService).Multiplier(player, "Luck")
		* require(script.Parent.WeatherService).Multipliers().Luck
end

-- The Workshop multi: Workshop stat points (the tree has no Workshop branch). Used by WorkshopService.
function GachaService.WorkshopMulti(player)
	return GachaConfig.Multis(alloc(player)).Workshop
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

-- Seconds between rolls for a player: UpgradeService.RollInterval (3 s, down to 2 s with Roll Speed tiers);
-- GachaConfig.ROLL_INTERVAL when no player is given.
function GachaService.RollInterval(player)
	if typeof(player) == "Instance" then
		return UpgradeService.RollInterval(player)
	end
	return GachaConfig.ROLL_INTERVAL
end

-- Seconds to wait after a roll before the next one: the player's roll interval, longer when that roll's animation is
-- longer (RollAnimConfig.ExtraPause), so the next roll never covers one still playing.
function GachaService.WaitAfter(id, emphasized, player)
	local spec = CarCatalog.Get(id)
	return GachaService.RollInterval(player) + RollAnimConfig.ExtraPause(spec and spec.Rarity, emphasized == true)
end

-- Rolls every GachaService.WaitAfter(last roll) seconds while the player's AutoRoll is on, until handle:Stop() (or
-- the player is gone). `roller` (optional) is the Random the rolls use (tests).
function GachaService.StartAutoRoll(player, roller)
	local handle = { Running = true, Rolls = 0 }
	function handle:Stop()
		self.Running = false
	end
	task.spawn(function()
		local wait = GachaService.RollInterval(player)
		while handle.Running and player.Parent do
			task.wait(wait)
			wait = GachaService.RollInterval(player) -- read every roll: a Roll Speed purchase applies at once
			if handle.Running and player.Parent and player:GetAttribute("AutoRoll") ~= false then
				local id, _, _, emphasized = GachaService.Roll(player, roller)
				handle.Rolls += 1
				wait = GachaService.WaitAfter(id, emphasized, player)
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

-- What Remotes.SetAutoRoll does: rate-limited like AllocateStat, booleans only. Returns true if applied.
function GachaService.RequestSetAutoRoll(player, on)
	return accept(player) and GachaService.SetAutoRoll(player, on)
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
	announceRemote = remote(remotes, "RollAnnounce")
	remote(remotes, "SetAutoRoll").OnServerEvent:Connect(GachaService.RequestSetAutoRoll)
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
		UpgradeService.Setup(player)
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
