--!nonstrict
-- Saved player stats: Money and Speed (a continuous stat that grows while the car drives and sets the
-- auto-race cruise speed, see RaceConfig). The server owns them: leaderstats replicate down to clients, nothing a client sends ever changes a value. Data is
-- kept in a DataStore; if the store cannot be read (Studio without API access, outage) the player is
-- flagged DataFailed and their stats are never written, so a failed load can not wipe a save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceConfig"))
local MoneyService = require(script.Parent.MoneyService)

local PlayerData = {}

local STORE_NAME = "PlayerStats_v1"
local VERSION = 2
local MAX_MONEY = 1e12
local MAX_ADD = 1e6 -- most a single AddSpeed call may add
local AUTOSAVE_SECONDS = 60

local store = nil

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
	MoneyService.Setup(player)
	return speedValue(player)
end

-- Returns true if the stats were loaded (or newly created). Yields.
function PlayerData.Load(player, userId)
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
	local payload = {
		Money = cleanInt(money.Value, 0, MAX_MONEY, 0),
		Speed = cleanStat(speed.Value),
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
