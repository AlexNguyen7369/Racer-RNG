--!nonstrict
-- Saved player stats: Money, Speed, the car gacha (inventory, equipped car, rolls, stat allocation), the upgrade tree
-- (owned tiles, BestTrack, TurboCount) and the workshop level. Speed is a continuous stat that grows while the car drives and sets the
-- auto-race cruise speed, see RaceConfig). The server owns them: leaderstats replicate down to clients, nothing a client sends ever changes a value. Data is
-- kept in a DataStore; if the store cannot be read (Studio without API access, outage) the player is
-- flagged DataFailed and their stats are never written, so a failed load can not wipe a save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaceConfig = require(Shared:WaitForChild("RaceConfig"))
local RebirthConfig = require(Shared:WaitForChild("RebirthConfig"))
local Workshop = require(Shared:WaitForChild("Workshop"))
local MoneyService = require(script.Parent.MoneyService)
local GachaService = require(script.Parent.GachaService)
local UpgradeService = require(script.Parent.UpgradeService)
local MarketService = require(script.Parent.MarketService)
local RebirthService = require(script.Parent.RebirthService)
local BoostService = require(script.Parent.BoostService)
local DailyLoginService = require(script.Parent.DailyLoginService)
local LevelService = require(script.Parent.LevelService)

local PlayerData = {}

local STORE_NAME = "PlayerStats_v1"
local VERSION = 7 -- 3: gacha; 4: upgrades/workshop; 5: market; 6: rebirth/boosts/daily login; 7: level/xp
local MAX_MONEY = 1e12
local MAX_ADD = 1e6 -- most a single AddSpeed call may add
local AUTOSAVE_SECONDS = 60

local store = nil
local clock = os.time

function PlayerData.SetClock(fn)
	clock = fn or os.time
end

local leaveHooks = {}

function PlayerData.SetStore(newStore)
	store = newStore
end

local function getStore()
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		end
	end
	return store
end

function PlayerData.KeyFor(userId)
	return "Player_" .. tostring(userId)
end

-- Integer in [lo, hi]; anything that is not a real number becomes the default.
local function cleanInt(value, lo, hi, default)
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return math.floor(math.clamp(value, lo, hi))
end

-- The Speed stat: a number in [0, MAX_STAT] rounded to 3 decimals; anything else becomes 0.
local function cleanStat(value)
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.floor(math.min(value, RaceConfig.MAX_STAT) * 1000 + 0.5) / 1000
end

local function speedValue(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local speed = stats:FindFirstChild("Speed")
	if not speed then
		speed = Instance.new("NumberValue")
		speed.Name = "Speed"
		speed.Value = 0
		speed.Parent = stats
	end
	return speed
end

-- Creates leaderstats with Money and Speed (idempotent). Works on any Instance.
function PlayerData.Setup(player)
	LevelService.Setup(player)
	MoneyService.Setup(player)
	RebirthService.Setup(player)
	BoostService.Setup(player)
	DailyLoginService.Setup(player)
	if player:GetAttribute("RebirthLevel") == nil then
		player:SetAttribute("RebirthLevel", RebirthConfig.DEFAULT_LEVEL)
	end
	return speedValue(player)
end

-- Returns true if the stats were loaded (or newly created). Yields.
function PlayerData.Load(player, userId)
	if player:GetAttribute("DataLoaded") then
		return true
	end
	userId = userId or player.UserId
	local money = MoneyService.Setup(player)
	local speed = speedValue(player)
	local dataStore = getStore()
	local ok, data
	if dataStore then
		ok, data = pcall(function()
			return dataStore:GetAsync(PlayerData.KeyFor(userId))
		end)
	end
	if not ok then
		player:SetAttribute("DataFailed", true)
		return false
	end
	if type(data) ~= "table" then
		data = {}
	end
	money.Value = cleanInt(data.Money, 0, MAX_MONEY, 0)
	speed.Value = cleanStat(data.Speed)
	GachaService.Apply(player, data) -- older saves have no gacha fields: starter car, nothing allocated
	UpgradeService.Apply(player, data) -- version 3 and older: no tiles, BestTrack 0, TurboCount from Rolls % 10
	MarketService.Apply(player, data)
	player:SetAttribute("WorkshopLevel", Workshop.CleanLevel(data.WorkshopLevel)) -- missing = the starter workshop
	RebirthService.Apply(player, data)
	BoostService.Apply(player, data)
	DailyLoginService.Apply(player, data)
	LevelService.Apply(player, data)
	local at = clock()
	local offlineAt = data.OfflineAt
	local seconds = type(offlineAt) == "number"
			and offlineAt == offlineAt
			and offlineAt >= 0
			and offlineAt <= at
			and math.min(at - offlineAt, Workshop.Config.OFFLINE_CAP)
		or 0
	local gain = Workshop.OfflineGain(
		speed.Value,
		GachaService.SpeedMulti(player),
		data.WorkshopLevel,
		GachaService.WorkshopMulti(player),
		seconds
	)
	local moneyGain =
		Workshop.OfflineMoney(
			speed.Value,
			GachaService.SpeedMulti(player),
			data.WorkshopLevel,
			GachaService.WorkshopMulti(player),
			seconds
		)
	if gain > 0 or moneyGain > 0 then
		-- Persist the claim before exposing it. UpdateAsync retries can never award the same saved absence twice.
		local claimed = 0
		local claimedMoney = 0
		local claimOk, updated = pcall(function()
			return dataStore:UpdateAsync(PlayerData.KeyFor(userId), function(current)
				claimed = 0
				claimedMoney = 0
				if type(current) ~= "table" or current.OfflineAt ~= offlineAt then
					return nil
				end
				local result = table.clone(current)
				claimed = gain
				claimedMoney = moneyGain
				result.Speed = cleanStat(cleanStat(current.Speed) + gain)
				result.Money = cleanInt(cleanInt(current.Money, 0, MAX_MONEY, 0) + moneyGain, 0, MAX_MONEY, 0)
				result.OfflineAt = at
				return result
			end)
		end)
		if not claimOk then
			player:SetAttribute("DataFailed", true)
			return false
		end
		if type(updated) ~= "table" then
			player:SetAttribute("DataFailed", true)
			return false -- competing load: don't overwrite a save whose claim changed under us
		end
		speed.Value = cleanStat(updated.Speed)
		money.Value = cleanInt(updated.Money, 0, MAX_MONEY, 0)
		GachaService.Apply(player, updated)
		UpgradeService.Apply(player, updated)
		MarketService.Apply(player, updated)
		player:SetAttribute("WorkshopLevel", Workshop.CleanLevel(updated.WorkshopLevel))
		RebirthService.Apply(player, updated)
		BoostService.Apply(player, updated)
		DailyLoginService.Apply(player, updated)
		LevelService.Apply(player, updated)
		gain = claimed
		moneyGain = claimedMoney
	end
	player:SetAttribute("OfflineSpeed", gain)
	player:SetAttribute("OfflineMoney", moneyGain)
	player:SetAttribute("OfflineSeconds", seconds)
	player:SetAttribute("DataFailed", nil)
	player:SetAttribute("DataLoaded", true)
	return true
end

-- Returns true if the stats were written. Never writes for a player whose load failed or has not finished.
function PlayerData.Save(player, userId)
	userId = userId or player.UserId
	-- Never write before the load finished: a leaving player whose GetAsync is still pending would
	-- otherwise overwrite their real save with defaults.
	if player:GetAttribute("DataFailed") or not player:GetAttribute("DataLoaded") then
		return false
	end
	local dataStore = getStore()
	if not dataStore then
		return false
	end
	local money = MoneyService.Setup(player)
	local speed = speedValue(player)
	local gacha = GachaService.Snapshot(player)
	local upgrades = UpgradeService.Snapshot(player)
	local market = MarketService.Snapshot(player)
	local boosts = BoostService.Snapshot(player)
	local daily = DailyLoginService.Snapshot(player)
	local level = LevelService.Snapshot(player)
	local payload = {
		Money = cleanInt(money.Value, 0, MAX_MONEY, 0),
		Speed = cleanStat(speed.Value),
		Cars = gacha.Cars,
		Equipped = gacha.Equipped,
		Rolls = gacha.Rolls,
		StatAlloc = gacha.StatAlloc,
		Upgrades = upgrades.Upgrades,
		BestTrack = upgrades.BestTrack,
		TurboCount = upgrades.TurboCount,
		WorkshopLevel = Workshop.CleanLevel(player:GetAttribute("WorkshopLevel")),
		RebirthLevel = RebirthConfig.CleanLevel(player:GetAttribute("RebirthLevel")),
		Boosts = boosts.Boosts,
		ActiveBoosts = boosts.ActiveBoosts,
		DailyStreak = daily.DailyStreak,
		DailyLast = daily.DailyLast,
		Level = level.Level,
		XP = level.XP,
		OwnedAuras = market.OwnedAuras,
		OwnedTrails = market.OwnedTrails,
		EquippedAura = market.EquippedAura,
		EquippedTrail = market.EquippedTrail,
		OfflineAt = clock(),
		Version = VERSION,
	}
	local ok = pcall(function()
		dataStore:SetAsync(PlayerData.KeyFor(userId), payload)
	end)
	return ok
end

-- The player's Speed stat, a number in [0, MAX_STAT] (0 if they have none).
function PlayerData.SpeedStat(player)
	local stats = player:FindFirstChild("leaderstats")
	local speed = stats and stats:FindFirstChild("Speed")
	return cleanStat(speed and speed.Value)
end

-- Adds to the Speed stat. Only the server calls this. The amount must be a finite number in (0, MAX_ADD];
-- returns the new stat, or nil (and changes nothing) for anything else.
function PlayerData.AddSpeed(player, amount)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount > MAX_ADD then
		return nil
	end
	local speed = PlayerData.Setup(player)
	speed.Value = math.min(speed.Value + amount, RaceConfig.MAX_STAT)
	return speed.Value
end

-- Waits until the player's stats finished loading (or failed). Returns true if loaded.
function PlayerData.WaitLoaded(player, timeout)
	local deadline = os.clock() + (timeout or 10)
	while os.clock() < deadline do
		if player:GetAttribute("DataLoaded") then
			return true
		end
		if player:GetAttribute("DataFailed") or not player.Parent then
			return false
		end
		task.wait(0.1)
	end
	return false
end

-- Runs `fn(player)` when a player leaves, just before their stats are saved.
function PlayerData.OnLeaving(fn)
	table.insert(leaveHooks, fn)
end

function PlayerData.Start()
	local loading = {}
	local function onPlayer(player)
		if loading[player] then
			return -- joined between the PlayerAdded connect and the GetPlayers loop
		end
		loading[player] = true
		task.spawn(PlayerData.Load, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, hook in leaveHooks do
			pcall(hook, player) -- e.g. CarService stops the run, committing its last Speed gain
		end
		PlayerData.Save(player)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			PlayerData.Save(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, player in Players:GetPlayers() do
				PlayerData.Save(player)
			end
		end
	end)
end

return PlayerData
