--!nonstrict
-- Saved player stats: Money, Speed, the car gacha (inventory, equipped car, rolls, stat allocation), the upgrade tree
-- (owned tiles, BestTrack, TurboCount) and the workshop level. Speed is a continuous stat that grows while the car drives and sets the
-- auto-race cruise speed, see RaceConfig). The server owns them: leaderstats replicate down to clients, nothing a client sends ever changes a value. Data is
-- kept in a DataStore; if the store cannot be read (Studio without API access, outage) the player is
-- flagged DataFailed and their stats are never written, so a failed load can not wipe a save.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
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
local QuestService = require(script.Parent.QuestService)
local ShopService = require(script.Parent.ShopService)
local GiftMailbox = require(script.Parent.GiftMailbox)
local RaceTimeService = require(script.Parent.RaceTimeService)

local PlayerData = {}

local STORE_NAME = "PlayerStats_v1"
local VERSION = 11 -- 11: per-track NPC race personal bests
-- 8: session lock, MoneyEarned, DuelWins; 9: Receipts, Codes (docs/SAVE_SPEC.md)
local MAX_MONEY = 1e12
local MAX_ADD = 1e6 -- most a single AddSpeed call may add
local AUTOSAVE_SECONDS = 60
local MAX_DUEL_WINS = 1e9

-- Session lock (docs/SAVE_SPEC.md): the saved record names the server that holds it, so two servers never
-- write the same save.
PlayerData.LOCK_TIMEOUT = 120 -- seconds: a lock this old is dead and may be taken
PlayerData.LOAD_RETRIES = 3 -- attempts in total
PlayerData.LOAD_RETRY_WAIT = 2 -- seconds between attempts

local store = nil
local clock = os.time
local saving = setmetatable({}, { __mode = "k" })
local giftReceipts = setmetatable({}, { __mode = "k" })

function PlayerData.SetClock(fn)
	clock = fn or os.time
end

local leaveHooks = {}

local defaultSession = nil
local sessionId = nil

-- This server's id in save locks: game.JobId, or a GUID made once when JobId is empty (Studio).
function PlayerData.SessionId()
	if sessionId then
		return sessionId
	end
	if not defaultSession then
		defaultSession = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)
	end
	return defaultSession
end

-- Tests: act as another server. nil restores the default.
function PlayerData.SetSessionId(id)
	sessionId = id
end

-- True when another server holds a lock that has not timed out.
local function lockedElsewhere(record, at)
	local lock = type(record) == "table" and record.Lock
	return type(lock) == "table"
		and lock.Id ~= PlayerData.SessionId()
		and type(lock.At) == "number"
		and at - lock.At < PlayerData.LOCK_TIMEOUT
end

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

-- The Speed stat: any finite number >= 0 (no cap) rounded to 3 decimals; anything else becomes 0.
local function cleanStat(value)
	return RaceConfig.CleanStat(value) or 0
end

local shownWired = setmetatable({}, { __mode = "k" }) -- players whose leaderstats.Speed follows BaseSpeed

-- The base Speed (earned, saved, reset by rebirth) is player.BaseSpeed. leaderstats.Speed is display only: base x
-- the ShownSpeedMulti attribute (equipped car x aura), so the HUD and player list show Speed after what the player
-- equips (design doc Core stat model, owner 2026-10-21).
local function speedValue(player)
	local base = player:FindFirstChild("BaseSpeed")
	if not base then
		base = Instance.new("NumberValue")
		base.Name = "BaseSpeed"
		base.Value = 0
		base.Parent = player
	end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local shown = stats:FindFirstChild("Speed")
	if not shown then
		shown = Instance.new("NumberValue")
		shown.Name = "Speed"
		shown.Parent = stats
	end
	if not shownWired[player] then
		shownWired[player] = true
		local function refresh()
			local multi = player:GetAttribute("ShownSpeedMulti")
			shown.Value = base.Value * (type(multi) == "number" and multi > 0 and multi < math.huge and multi or 1)
		end
		base.Changed:Connect(refresh)
		player:GetAttributeChangedSignal("ShownSpeedMulti"):Connect(refresh)
		refresh()
	end
	return base
end

-- Creates leaderstats with Money and Speed plus BaseSpeed (idempotent); returns BaseSpeed. Works on any Instance.
function PlayerData.Setup(player)
	RaceTimeService.Setup(player)
	LevelService.Setup(player)
	MoneyService.Setup(player)
	RebirthService.Setup(player)
	BoostService.Setup(player)
	DailyLoginService.Setup(player)
	QuestService.Setup(player)
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
	if not dataStore then
		player:SetAttribute("DataFailed", true)
		return false
	end

	local function apply(data)
		money.Value = cleanInt(data.Money, 0, MAX_MONEY, 0)
		speed.Value = cleanStat(data.Speed)
		GachaService.Apply(player, data) -- older saves have no gacha fields: starter car, nothing allocated
		UpgradeService.Apply(player, data) -- version 3 and older: no tiles, BestTrack 0, TurboCount from Rolls % 10
		MarketService.Apply(player, data)
		player:SetAttribute("WorkshopLevel", Workshop.CleanLevel(data.WorkshopLevel)) -- missing = the starter workshop
		RebirthService.Apply(player, data)
		BoostService.Apply(player, data)
		DailyLoginService.Apply(player, data)
		QuestService.Apply(player, data)
		RaceTimeService.Apply(player, data)
		LevelService.Apply(player, data)
		ShopService.Apply(player, data) -- version 8 and older: no receipts, no codes
		giftReceipts[player] = type(data.GiftReceipts) == "table" and table.clone(data.GiftReceipts) or {}
		player:SetAttribute("MoneyEarned", cleanInt(data.MoneyEarned, 0, MAX_MONEY, 0))
		player:SetAttribute("DuelWins", cleanInt(data.DuelWins, 0, MAX_DUEL_WINS, 0))
		player:SetAttribute("Checkpoint", cleanInt(data.Checkpoint, 1, MAX_DUEL_WINS, 1)) -- docs/CHECKPOINT_SPEC.md
	end

	-- One UpdateAsync per attempt takes the lock and claims the offline Speed together, so a retried or competing
	-- load can never pay the same absence twice. Nothing in the transform yields.
	local gain, seconds = 0, 0
	local updated = nil
	for attempt = 1, PlayerData.LOAD_RETRIES do
		local refused = false
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(PlayerData.KeyFor(userId), function(current)
				local at = clock()
				refused = lockedElsewhere(current, at)
				if refused then
					return nil
				end
				local record = type(current) == "table" and table.clone(current) or {}
				apply(record) -- the multis below read the player's loaded cars, points and upgrades
				local offlineAt = record.OfflineAt
				seconds = type(offlineAt) == "number"
						and offlineAt == offlineAt
						and offlineAt >= 0
						and offlineAt <= at
						and math.min(at - offlineAt, Workshop.Config.OFFLINE_CAP)
					or 0
				gain = Workshop.OfflineGain(
					speed.Value,
					GachaService.SpeedMulti(player),
					record.WorkshopLevel,
					GachaService.WorkshopMulti(player),
					seconds
				)
				if gain > 0 then
					record.Speed = cleanStat(speed.Value + gain)
					record.OfflineAt = at
				end
				record.Lock = { Id = PlayerData.SessionId(), At = at }
				return record
			end)
		end)
		if not ok then
			break -- store error: never guess a save
		end
		if not refused and type(result) == "table" then
			updated = result
			break
		end
		if attempt < PlayerData.LOAD_RETRIES then
			task.wait(PlayerData.LOAD_RETRY_WAIT) -- another server may be saving this player out right now
		end
	end
	if not updated then
		player:SetAttribute("DataFailed", true)
		return false
	end
	apply(updated)
	player:SetAttribute("OfflineSpeed", gain)
	player:SetAttribute("OfflineSeconds", seconds)
	player:SetAttribute("DataFailed", nil)
	player:SetAttribute("DataLoaded", true)
	-- The mailbox was persisted even if the recipient was offline. Claim through the same
	-- atomic save path; a failed claim stays in the mailbox for the next autosave.
	if type(updated.GiftMailbox) == "table" and next(updated.GiftMailbox) then
		PlayerData.Save(player, userId)
	end
	return true
end

-- Server-only: enqueue without touching the recipient's session lock or other fields.
function PlayerData.EnqueueGift(userId, purchaseId, gift)
	if
		type(userId) ~= "number"
		or userId <= 0
		or userId % 1 ~= 0
		or type(purchaseId) ~= "string"
		or purchaseId == ""
		or #purchaseId > 200
		or not GiftMailbox.Valid(gift)
	then
		return false
	end
	local dataStore = getStore()
	if not dataStore then
		return false
	end
	local ok, result = pcall(function()
		return dataStore:UpdateAsync(PlayerData.KeyFor(userId), function(current)
			local record = type(current) == "table" and table.clone(current) or {}
			record.GiftMailbox = type(record.GiftMailbox) == "table" and table.clone(record.GiftMailbox) or {}
			if not record.GiftMailbox[purchaseId] then
				local entry = table.clone(gift)
				entry.Grants = table.clone(gift.Grants)
				record.GiftMailbox[purchaseId] = entry
			end
			return record
		end)
	end)
	return ok and type(result) == "table" and result.GiftMailbox[purchaseId] ~= nil
end

-- Returns true if the stats were written. Never writes for a player whose load failed or has not finished, or
-- when another server took the session lock. `release` (leave, shutdown) writes the record without a lock.
local function save(player, userId, release)
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
	local quests = QuestService.Snapshot(player)
	local level = LevelService.Snapshot(player)
	local shop = ShopService.Snapshot(player)
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
		QuestDailyKey = quests.QuestDailyKey,
		QuestWeeklyKey = quests.QuestWeeklyKey,
		QuestDaily = quests.QuestDaily,
		QuestWeekly = quests.QuestWeekly,
		QuestDailyClaimed = quests.QuestDailyClaimed,
		QuestWeeklyClaimed = quests.QuestWeeklyClaimed,
		Level = level.Level,
		XP = level.XP,
		OwnedAuras = market.OwnedAuras,
		OwnedTrails = market.OwnedTrails,
		EquippedAura = market.EquippedAura,
		EquippedTrail = market.EquippedTrail,
		MoneyEarned = cleanInt(player:GetAttribute("MoneyEarned"), 0, MAX_MONEY, 0),
		DuelWins = cleanInt(player:GetAttribute("DuelWins"), 0, MAX_DUEL_WINS, 0),
		Receipts = shop.Receipts,
		Codes = shop.Codes,
		Checkpoint = cleanInt(player:GetAttribute("Checkpoint"), 1, MAX_DUEL_WINS, 1),
		RaceBestTimes = RaceTimeService.Snapshot(player),
		OfflineAt = clock(),
		Version = VERSION,
	}
	local refused = false
	local known = giftReceipts[player] or {}
	local ok, result = pcall(function()
		return dataStore:UpdateAsync(PlayerData.KeyFor(userId), function(current)
			local at = clock()
			refused = lockedElsewhere(current, at)
			if refused then
				return nil -- this server lost the session: never overwrite the other server's save
			end
			local merged = GiftMailbox.Merge(table.clone(payload), type(current) == "table" and current or {}, known)
			merged.Lock = if release then nil else { Id = PlayerData.SessionId(), At = at }
			return merged
		end)
	end)
	if ok and not refused and type(result) == "table" then
		-- Preserve any legitimate potion changes made while UpdateAsync yielded.
		for id, count in result.Boosts do
			local delta = count - (boosts.Boosts[id] or 0)
			local item = require(Shared.BoostConfig).Get(id)
			if item and item.Id == id and delta > 0 then
				BoostService.Add(player, id, delta)
			end
		end
		giftReceipts[player] = result.GiftReceipts
		return true
	end
	return false
end

function PlayerData.Save(player, userId, release)
	while saving[player] do
		task.wait()
	end
	saving[player] = true
	local ok, result = pcall(save, player, userId, release)
	saving[player] = nil
	if not ok then
		warn("PlayerData save failed: " .. tostring(result))
		return false
	end
	return result
end

-- The player's Speed stat, a finite number >= 0 (0 if they have none).
function PlayerData.SpeedStat(player)
	local speed = player:FindFirstChild("BaseSpeed")
	return cleanStat(speed and speed.Value)
end

-- Adds to the Speed stat. Only the server calls this. The amount must be a finite number in (0, MAX_ADD];
-- returns the new stat, or nil (and changes nothing) for anything else.
function PlayerData.AddSpeed(player, amount)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount > MAX_ADD then
		return nil
	end
	local speed = PlayerData.Setup(player)
	local new = speed.Value + amount
	if new == math.huge then
		return nil
	end
	speed.Value = new
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
		PlayerData.Save(player, nil, true)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			PlayerData.Save(player, nil, true)
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
