--!nonstrict
-- Car gacha, index and stat allocation. The server owns all of it; clients only see:
--   player.GachaData: one StringValue per owned car Id (discovering a car = owning it); attribute Copies = the
--   duplicates rolled since (docs/WORKSHOP_SPEC.md "Showcase": never sold, they power the workshop Showcase)
--   player attributes: EquippedCar, Rolls, StatPoints (free points), Alloc_<Stat> for each GachaConfig.STATS,
--   AutoRoll (the AUTO toggle of the roll view, true on join, not saved), Showcase (shown car ids joined by ","),
--   ShowcaseMulti, SpeedGainMulti, LuckMulti (live permanent multiplier snapshots)
-- Every unique car in the index counts towards stat points (GachaConfig.EarnedPoints); earned points are
-- never stored, only what was allocated, so the two can not drift apart. Saved by PlayerData (Snapshot/Apply).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared.CarCatalog)
local GachaConfig = require(Shared.GachaConfig)
local MarketConfig = require(Shared.MarketConfig)
local RebirthConfig = require(Shared.RebirthConfig)
local RollAnimConfig = require(Shared.RollAnimConfig)
local UpgradeService = require(script.Parent.UpgradeService)

local GachaService = {}
local QuestService = require(script.Parent.QuestService)

GachaService.REMOTE_COOLDOWN = 0.15 -- seconds between accepted EquipCar / AllocateStat requests per player

local MAX_COUNT = 1e9
local STARTER = CarCatalog.STARTER_ID

local rng = Random.new()
local watched = setmetatable({}, { __mode = "k" }) -- players whose ShownSpeedMulti is kept current
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
	if player:GetAttribute("Showcase") == nil then
		player:SetAttribute("Showcase", "")
		player:SetAttribute("ShowcaseMulti", 1)
	end
	if not watched[player] then
		watched[player] = true
		local function refresh()
			player:SetAttribute("ShownSpeedMulti", GachaService.ShownSpeedMulti(player))
			player:SetAttribute("SpeedGainMulti", GachaService.SpeedGainMulti(player))
			player:SetAttribute("LuckMulti", RebirthConfig.LuckMulti(player:GetAttribute("RebirthLevel")))
		end
		player.AttributeChanged:Connect(function(name)
			if
				name == "EquippedCar"
				or name == "EquippedAura"
				or name == "RebirthLevel"
				or string.sub(name, 1, 5) == "Pass_"
				or string.sub(name, 1, 6) == "Alloc_"
			then
				refresh()
			end
		end)
		data.ChildAdded:Connect(refresh)
		data.ChildRemoved:Connect(refresh)
		refresh()
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
		+ RebirthConfig.Points(player:GetAttribute("RebirthLevel"))
end

function GachaService.FreePoints(player)
	return math.max(0, GachaService.EarnedPoints(player) - allocSum(alloc(player)))
end

local function refreshPoints(player)
	player:SetAttribute("StatPoints", GachaService.FreePoints(player))
end
GachaService.RefreshPoints = refreshPoints -- RebirthService calls it when RebirthLevel changes

local function cleanCopies(n)
	if type(n) ~= "number" or n ~= n or n < 0 then
		return 0
	end
	return math.floor(math.min(n, GachaConfig.MAX_SAVED_COPIES))
end

-- Duplicates of an owned car rolled after discovering it (0 when not owned).
function GachaService.Copies(player, id)
	local data = player:FindFirstChild("GachaData")
	local entry = data and type(id) == "string" and data:FindFirstChild(id)
	return entry and cleanCopies(entry:GetAttribute("Copies")) or 0
end

local function owns(player, id)
	if id == STARTER then
		return true
	end
	local spec = CarCatalog.Get(id)
	if spec and spec.GamepassId then
		return player:GetAttribute("Pass_" .. id) == true -- set by PassCarService from Roblox, never saved
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
	local entry = data:FindFirstChild(id)
	if entry then
		entry:SetAttribute("Copies", cleanCopies(cleanCopies(entry:GetAttribute("Copies")) + 1))
		if GachaService.ShowcaseIds(player)[id] then
			GachaService.RefreshShowcase(player)
		end
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
-- whether it was new, the turbo multi (1 on a normal roll), whether it is emphasized (GachaConfig.IsEmphasized:
-- played enlarged and announced to the whole server), 0 (duplicates used to pay scrap Money; they now add a copy,
-- owner 2026-10-22) and the roll's luck without
-- the turbo multi (the client divides the displayed odds by it, docs/WEATHER_EVENTS_SPEC.md).
function GachaService.Roll(player, roller)
	GachaService.Setup(player)
	local rollNumber = math.min(cleanCount(player:GetAttribute("Rolls")) + 1, MAX_COUNT)
	local turboMulti = UpgradeService.AdvanceTurbo(player)
	local event = require(script.Parent.WeatherService).Current()
	local luck = GachaService.Luck(player)
	local id = GachaConfig.Roll(roller or rng, luck * turboMulti, event)
	local emphasized = GachaConfig.IsEmphasized(id, ownedIds(player))
	player:SetAttribute("Rolls", rollNumber)
	local isNew = GachaService.Grant(player, id)
	QuestService.Progress(player, "Rolls")
	if isNew then
		QuestService.Progress(player, "Discoveries")
	end
	local scrapMoney = 0
	if rollRemote and player:IsA("Player") then
		rollRemote:FireClient(player, id, isNew, turboMulti, emphasized, scrapMoney, luck)
	end
	if emphasized then
		GachaService.Announce(player, id, rollNumber)
	end
	return id, isNew, turboMulti, emphasized, scrapMoney, luck
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

-- Cruise speed and Speed-gain are separate progression paths. The equipped car
-- and shop cruise effects never enter the Speed-gain multiplier.
function GachaService.CarSpeedMulti(player)
	local spec = CarCatalog.Get(player:GetAttribute("EquippedCar"))
	local carMulti = spec and owns(player, spec.Id) and spec.SpeedMulti or 1
	return carMulti
end

-- Cruise-only multiplier: equipped car x aura. Published as the player attribute ShownSpeedMulti;
-- it never changes the saved/displayed Speed stat or its gain rate.
function GachaService.ShownSpeedMulti(player)
	return GachaService.CarSpeedMulti(player) * MarketConfig.SpeedMulti(player)
end

function GachaService.SpeedGainMulti(player)
	local multis = GachaConfig.Multis(alloc(player), UpgradeService.Bonuses(player))
	-- Only the permanent Speed-gain stat/tree upgrade and rebirth bonus apply here.
	return multis.Speed * RebirthConfig.SpeedGainMulti(player:GetAttribute("RebirthLevel"))
end

-- Refresh the replicated permanent multiplier snapshots immediately after a rebirth or allocation change.
-- Gameplay callers still calculate from source attributes, so these are observability/UI values rather than a cache.
function GachaService.RefreshMultipliers(player)
	player:SetAttribute("SpeedGainMulti", GachaService.SpeedGainMulti(player))
	player:SetAttribute("LuckMulti", RebirthConfig.LuckMulti(player:GetAttribute("RebirthLevel")))
end

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
	local luck = GachaConfig.Multis(alloc(player), UpgradeService.Bonuses(player)).Luck
		* RebirthConfig.LuckMulti(player:GetAttribute("RebirthLevel"))
		* require(script.Parent.BoostService).Multiplier(player, "Luck")
		* require(script.Parent.WeatherService).Multipliers().Luck
	if player:GetAttribute("InWorkshop") == true then
		local WorkshopConfig = require(Shared.WorkshopConfig)
		luck *= WorkshopConfig.LuckMulti(player:GetAttribute("WorkshopLevel"))
	end
	local adminLuck = player:GetAttribute("AdminLuck")
	if type(adminLuck) == "number" and adminLuck >= 1 and adminLuck == adminLuck then
		luck *= adminLuck
	end
	return luck
end

-- The showcased ids as a set, read from the Showcase attribute.
function GachaService.ShowcaseIds(player)
	local set = {}
	local value = player:GetAttribute("Showcase")
	if type(value) == "string" then
		for id in string.gmatch(value, "[^,]+") do
			set[id] = true
		end
	end
	return set
end

-- The showcased ids in slot order.
function GachaService.ShowcaseList(player)
	local list = {}
	local value = player:GetAttribute("Showcase")
	if type(value) == "string" then
		for id in string.gmatch(value, "[^,]+") do
			table.insert(list, id)
		end
	end
	return list
end

-- 1 + the slot bonuses of the showcased cars (GachaConfig.SlotBonus).
function GachaService.ShowcaseMulti(player)
	local slots = {}
	for _, id in GachaService.ShowcaseList(player) do
		table.insert(slots, { Spec = CarCatalog.Get(id), Copies = GachaService.Copies(player, id) })
	end
	return GachaConfig.ShowcaseMulti(slots)
end

function GachaService.RefreshShowcase(player)
	player:SetAttribute("ShowcaseMulti", GachaService.ShowcaseMulti(player))
end

local function showcaseable(player, id)
	local spec = type(id) == "string" and CarCatalog.Get(id) or nil
	local data = player:FindFirstChild("GachaData")
	return spec ~= nil
		and spec.Rollable == true
		and not spec.GamepassId
		and data ~= nil
		and data:FindFirstChild(id) ~= nil
end

-- Sets the showcased cars: an array of at most SHOWCASE_SLOTS distinct owned rollable car ids. Anything else changes
-- nothing. Returns ok, reason.
function GachaService.SetShowcase(player, ids)
	if type(ids) ~= "table" or #ids > GachaConfig.SHOWCASE_SLOTS then
		return false, "Pick up to " .. GachaConfig.SHOWCASE_SLOTS .. " cars"
	end
	local seen, count = {}, 0
	for key, id in ids do
		count += 1
		if type(key) ~= "number" or not showcaseable(player, id) or seen[id] then
			return false, "Not a car you own"
		end
		seen[id] = true
	end
	if count ~= #ids then
		return false, "Not a car you own"
	end
	player:SetAttribute("Showcase", table.concat(ids, ","))
	GachaService.RefreshShowcase(player)
	return true, "Showcase updated"
end

-- The Workshop multi: Workshop stat points (the tree has no Workshop branch) x the Showcase multi. Used by
-- WorkshopService and the offline Speed credit.
function GachaService.WorkshopMulti(player)
	return GachaConfig.Multis(alloc(player)).Workshop * GachaService.ShowcaseMulti(player)
end

-- The save format: { Cars = { id, ... } (sorted), Copies = { [id] = n }, Showcase = { id, ... }, Equipped = id,
-- Rolls = n, StatAlloc = { [stat] = n } }.
function GachaService.Snapshot(player)
	local cars = {}
	local data = player:FindFirstChild("GachaData")
	if data then
		for _, entry in data:GetChildren() do
			table.insert(cars, entry.Name)
		end
		table.sort(cars)
	end
	local copies = {}
	for _, id in cars do
		local n = GachaService.Copies(player, id)
		if n > 0 then
			copies[id] = n
		end
	end
	local equipped = player:GetAttribute("EquippedCar")
	return {
		Cars = cars,
		Copies = copies,
		Showcase = GachaService.ShowcaseList(player),
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
			local spec = type(id) == "string" and CarCatalog.Get(id)
			if spec and spec.GamepassId then
				id = nil -- a gamepass car is owned through Roblox, never through the save
			end
			if type(id) == "string" and id ~= "" and id ~= STARTER and #id <= 64 and not data:FindFirstChild(id) then
				addEntry(data, id)
			end
		end
	end
	if type(saved.Copies) == "table" then
		for id, n in saved.Copies do
			local entry = type(id) == "string" and data:FindFirstChild(id)
			if entry and cleanCopies(n) > 0 then
				entry:SetAttribute("Copies", cleanCopies(n))
			end
		end
	end
	local showcase = {}
	if type(saved.Showcase) == "table" then
		for _, id in saved.Showcase do
			if #showcase < GachaConfig.SHOWCASE_SLOTS and showcaseable(player, id) and not table.find(showcase, id) then
				table.insert(showcase, id)
			end
		end
	end
	player:SetAttribute("Showcase", table.concat(showcase, ","))
	GachaService.RefreshShowcase(player)
	player:SetAttribute("Rolls", cleanCount(saved.Rolls))

	local a = {}
	local savedAlloc = type(saved.StatAlloc) == "table" and saved.StatAlloc or {}
	for _, stat in GachaConfig.STATS do
		a[stat] = cleanCount(savedAlloc[stat])
	end
	-- RebirthService.Apply runs after this, so count the saved rebirths here or their allocations would be cut
	local over = allocSum(a)
		- GachaConfig.EarnedPoints(GachaService.UniqueCount(player))
		- RebirthConfig.Points(saved.RebirthLevel)
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
	local spec = type(equipped) == "string" and CarCatalog.Get(equipped)
	-- A saved gamepass car stays until PassCarService has asked Roblox; it resets the car when the pass is not owned
	if not spec or not (spec.GamepassId or owns(player, equipped)) then
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

	local showcaseRemote = remotes:FindFirstChild("SetShowcase") or Instance.new("RemoteFunction")
	showcaseRemote.Name = "SetShowcase"
	showcaseRemote.Parent = remotes
	local lastShowcase = setmetatable({}, { __mode = "k" })
	showcaseRemote.OnServerInvoke = function(player, ids)
		local now = os.clock()
		if lastShowcase[player] and now - lastShowcase[player] < GachaConfig.SHOWCASE_COOLDOWN then
			return false, "Please wait"
		end
		lastShowcase[player] = now
		return GachaService.SetShowcase(player, ids)
	end

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
