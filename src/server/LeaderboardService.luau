--!nonstrict
-- Global leaderboards (docs/LEADERBOARD_SPEC.md). Server only, no remote: scores go to one OrderedDataStore per
-- board when a player leaves and every WRITE_INTERVAL; the top rows are read every REFRESH and written on the
-- signs in the spawn area (Shared/SpawnArea builds them). Every DataStore call is in pcall: a failure keeps the
-- last good rows, and without a store the signs say "No data yet".

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarAppearance = require(Shared.CarAppearance)
local CarCatalog = require(Shared.CarCatalog)
local Config = require(Shared.LeaderboardConfig)
local HudFormat = require(Shared.HudFormat)
local PlayerData = require(script.Parent.PlayerData)

local LeaderboardService = {}

local storeLookup = nil -- nil: the real DataStore; false: no store; function(storeName): tests
local nameLookup = nil
local names = {} -- userId -> name (successful lookups only)
local tops = {} -- board id -> rows of the last successful read
local started = false

-- Tests: fn(storeName) returns an OrderedDataStore-like object. false = no store, nil = the real DataStore.
function LeaderboardService.SetStore(fn)
	storeLookup = fn
	if fn == false then
		tops = {}
	end
end

-- Tests: fn(userId) -> name. nil = Players:GetNameFromUserIdAsync.
function LeaderboardService.SetNameLookup(fn)
	nameLookup = fn
	names = {}
end

local function storeFor(board)
	if storeLookup == false then
		return nil
	end
	local ok, store = pcall(function()
		if storeLookup then
			return storeLookup(board.Store)
		end
		return DataStoreService:GetOrderedDataStore(board.Store)
	end)
	return ok and store or nil
end

local function userIdOf(player)
	if player:IsA("Player") then
		return player.UserId
	end
	return player:GetAttribute("UserId") -- fake players (tests)
end

local function whole(value)
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

-- The player's score on every board, as integers.
function LeaderboardService.Scores(player)
	local stats = player:FindFirstChild("leaderstats")
	local speed = stats and stats:FindFirstChild("Speed")
	local rarest = 0
	local owned = player:FindFirstChild("GachaData")
	for _, car in owned and owned:GetChildren() or {} do
		local spec = CarCatalog.Get(car.Name)
		if spec and type(spec.Chance) == "number" then
			rarest = math.max(rarest, spec.Chance)
		end
	end
	return {
		Speed = whole(speed and speed.Value),
		MoneyEarned = whole(player:GetAttribute("MoneyEarned")),
		Rolls = whole(player:GetAttribute("Rolls")),
		RarestCar = whole(rarest),
	}
end

-- Writes the player's scores. Returns true when at least one board was written.
function LeaderboardService.Write(player)
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("DataFailed") == true then
		return false -- never from a save that did not load
	end
	local userId = userIdOf(player)
	if type(userId) ~= "number" then
		return false
	end
	local key = tostring(userId)
	local scores = LeaderboardService.Scores(player)
	local wrote = false
	for _, board in Config.Boards do
		local score = scores[board.Id]
		local store = score > 0 and storeFor(board)
		if store then
			local ok = pcall(function()
				if board.Id == "Speed" then
					-- A rebirth resets Speed: the board keeps the best value ever reached
					store:UpdateAsync(key, function(old)
						if type(old) == "number" and old >= score then
							return nil
						end
						return score
					end)
				else
					store:SetAsync(key, score)
				end
			end)
			wrote = wrote or ok
		end
	end
	return wrote
end

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		if nameLookup then
			return nameLookup(userId)
		end
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(name) == "string" and name ~= "" then
		names[userId] = name
		return name
	end
	return "Player " .. tostring(userId)
end

-- The catalog car a RarestCar score stands for, or nil.
local function carByChance(score)
	for _, spec in CarCatalog.All() do
		if spec.Chance == score then
			return spec
		end
	end
	return nil
end

local function rowText(board, rank, entry)
	local head = string.format("%d. %s", rank, entry.Name)
	if board.Id == "RarestCar" then
		local spec = carByChance(entry.Score)
		return head .. "  " .. (spec and spec.Name .. "  " or "") .. HudFormat.Odds(entry.Score)
	elseif board.Id == "MoneyEarned" then
		return head .. "  " .. HudFormat.MoneyText(entry.Score)
	end
	return head .. "  " .. HudFormat.SpeedText(entry.Score)
end

local function render(board)
	local area = Workspace:FindFirstChild("SpawnArea")
	local signs = area and area:FindFirstChild("Leaderboards")
	local sign = signs and signs:FindFirstChild("Board_" .. board.Id)
	local gui = sign and sign:FindFirstChild("Board")
	if not gui then
		return
	end
	local rows = tops[board.Id] or {}
	for i = 1, Config.TOP_N do
		local label = gui:FindFirstChild("Row" .. i, true)
		if label then
			if rows[i] then
				label.Text = rowText(board, i, rows[i])
			else
				label.Text = (i == 1 and #rows == 0) and Config.NO_DATA or ""
			end
		end
	end
end

-- Best Roll Ever pedestal (docs/LEADERBOARD_SPEC.md 3a): row 1 of the RarestCar board, with its car on the platform.
local function renderBestRoll()
	local area = Workspace:FindFirstChild("SpawnArea")
	local best = area and area:FindFirstChild("BestRoll")
	local pedestal = best and best:FindFirstChild("Pedestal")
	local stats = pedestal and pedestal:FindFirstChild("Stats")
	local mount = pedestal and pedestal:FindFirstChild("CarMount")
	if not (stats and mount) then
		return
	end
	local row = (tops.RarestCar or {})[1]
	local spec = row and carByChance(row.Score)
	stats.Odds.Text = row and HudFormat.Odds(row.Score) or Config.NO_DATA
	stats.Car.Text = spec and spec.Name or ""
	stats.Player.Text = row and "by " .. row.Name or ""
	local id = spec and spec.Id or nil
	if best:GetAttribute("CarId") == id then
		return -- same car: keep the model the clients are turning
	end
	best:SetAttribute("CarId", id)
	local old = best:FindFirstChild("Car")
	if old then
		old:Destroy()
	end
	local car = CarAppearance.Display(spec, mount.WorldCFrame, Config.BEST_ROLL.CAR_SCALE)
	if car then
		car.Parent = best
	end
end

-- Reads every board and writes the signs. Yields (DataStore, name lookups).
function LeaderboardService.Refresh()
	for _, board in Config.Boards do
		local store = storeFor(board)
		if store then
			local ok, page = pcall(function()
				return store:GetSortedAsync(false, Config.TOP_N):GetCurrentPage()
			end)
			if ok and type(page) == "table" then
				local rows = {}
				for i = 1, math.min(#page, Config.TOP_N) do
					local userId = tonumber(page[i].key)
					if userId and type(page[i].value) == "number" then
						table.insert(rows, { UserId = userId, Name = nameOf(userId), Score = page[i].value })
					end
				end
				tops[board.Id] = rows
			end
		end
		render(board)
	end
	renderBestRoll()
end

-- The last successful read of a board: { { UserId, Name, Score }, ... }, highest first, at most TOP_N.
function LeaderboardService.Top(id)
	return table.clone(tops[id] or {})
end

function LeaderboardService.Start()
	if started then
		return
	end
	started = true
	PlayerData.OnLeaving(function(player)
		LeaderboardService.Write(player)
	end)
	local function quiet()
		return ReplicatedStorage:GetAttribute("CarTestRunning") ~= true -- the harness drives it with a fake store
	end
	task.spawn(function()
		while true do
			if quiet() then
				LeaderboardService.Refresh()
			end
			task.wait(Config.REFRESH)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.WRITE_INTERVAL)
			if quiet() then
				for _, player in Players:GetPlayers() do
					LeaderboardService.Write(player)
				end
			end
		end
	end)
end

return LeaderboardService
