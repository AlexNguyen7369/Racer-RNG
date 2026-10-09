--!nonstrict
-- Chat admin commands (/money, /speed, /give, /tp, ...; /help lists them). The server decides everything:
-- a command runs only if AdminService.IsAdmin(sender) (Server/AdminConfig), and the only remote is the
-- reply to the sender (Remotes.AdminMessage, shown in chat by Client/AdminChat). Spec: docs/ADMIN_COMMANDS_SPEC.md.
-- From Studio's command bar (server): require(game.ServerScriptService.Server.AdminService).Run(player, "/money 1m")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared.CarCatalog)
local RaceConfig = require(Shared.RaceConfig)
local AdminConfig = require(script.Parent.AdminConfig)
local CarService = require(script.Parent.CarService)
local GachaService = require(script.Parent.GachaService)
local MoneyService = require(script.Parent.MoneyService)
local PlayerData = require(script.Parent.PlayerData)
local UpgradeService = require(script.Parent.UpgradeService)

local AdminService = {}

AdminService.AllowStudio = AdminConfig.ALLOW_IN_STUDIO == true

local MAX_MONEY = 1e15
local SUFFIX = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }

local groupRank = setmetatable({}, { __mode = "k" }) -- player -> rank in the owning group (cached)
local replyRemote = nil -- Remotes.AdminMessage, made by Start()

-- The race run a /tp moves. Tests may swap this out.
function AdminService.RunOf(player)
	return CarService.GetRun(player)
end

local function userIdOf(player)
	local ok, id = pcall(function()
		if player:IsA("Player") then
			return player.UserId
		end
		return player:GetAttribute("UserId")
	end)
	return ok and type(id) == "number" and id or nil
end

function AdminService.IsAdmin(player)
	if typeof(player) ~= "Instance" or player.Parent == nil then
		return false -- nil, or a player that left / a destroyed stand-in
	end
	local id = userIdOf(player)
	if id then
		if table.find(AdminConfig.UserIds, id) then
			return true
		end
		if game.CreatorId ~= 0 then
			if game.CreatorType == Enum.CreatorType.User and id == game.CreatorId then
				return true
			end
			if game.CreatorType == Enum.CreatorType.Group and player:IsA("Player") then
				if groupRank[player] == nil then
					local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
					groupRank[player] = ok and rank or 0
				end
				if groupRank[player] >= AdminConfig.GROUP_MIN_RANK then
					return true
				end
			end
		end
	end
	return AdminService.AllowStudio == true and RunService:IsStudio()
end

-- "/Money 5 me" -> "money", { "5", "me" }. nil for anything that is not a "/" command.
function AdminService.Parse(text)
	if type(text) ~= "string" or text:sub(1, 1) ~= "/" then
		return nil
	end
	local words = {}
	for word in text:sub(2):gmatch("%S+") do
		table.insert(words, word)
	end
	if #words == 0 then
		return nil
	end
	return table.remove(words, 1):lower(), words
end

-- "1500", "1,500", "1.5k", "2m", "3B", "1t", "1e6", "-50" -> number. nil for anything else.
function AdminService.ParseNumber(s)
	if type(s) ~= "string" then
		return nil
	end
	s = s:gsub(",", ""):lower()
	local scale = 1
	local last = s:sub(-1)
	if SUFFIX[last] then
		scale = SUFFIX[last]
		s = s:sub(1, -2)
	end
	if not s:match("^[%+%-]?%d*%.?%d+$") and not s:match("^[%+%-]?%d+%.?%d*e[%+%-]?%d+$") then
		return nil
	end
	local n = tonumber(s)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	n *= scale
	if n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return n
end

-- me (default) / all / the start of a Name or DisplayName (one match). Returns a list or nil, message.
local function resolveTargets(sender, word)
	if word == nil or word:lower() == "me" then
		return { sender }
	end
	local lower = word:lower()
	if lower == "all" then
		local list = Players:GetPlayers()
		return #list > 0 and list or { sender }
	end
	local found = {}
	local candidates = Players:GetPlayers()
	if not table.find(candidates, sender) then
		table.insert(candidates, sender)
	end
	for _, p in candidates do
		local display = p:IsA("Player") and p.DisplayName or p.Name
		if p.Name:lower():sub(1, #lower) == lower or display:lower():sub(1, #lower) == lower then
			table.insert(found, p)
		end
	end
	if #found == 1 then
		return found
	end
	return nil, #found == 0 and ("No player matches '" .. word .. "'.") or ("'" .. word .. "' matches several players.")
end

local function moneyValue(player)
	return MoneyService.Setup(player)
end

local function speedValue(player)
	return PlayerData.Setup(player)
end

local function cleanSpeed(n)
	return math.floor(math.clamp(n, 0, RaceConfig.MAX_STAT) * 1000 + 0.5) / 1000
end

local function amount(args)
	return AdminService.ParseNumber(args[1])
end

-- Each command: Usage, Help, Min/Max arguments before the optional target, Check(args) -> value or nil
-- (validated before anything changes) and Apply(target, value) -> ok, message.
AdminService.Commands = {
	help = {
		Usage = "/help",
		Help = "list the admin commands",
		Min = 0,
		Max = 0,
		NoTarget = true,
	},
	money = {
		Usage = "/money <amount> [player]",
		Help = "set Money (1.5k, 2m, 3b work)",
		Min = 1,
		Max = 1,
		Check = function(args)
			local n = amount(args)
			return n and n >= 0 and n <= MAX_MONEY and math.floor(n) or nil
		end,
		Apply = function(p, n)
			moneyValue(p).Value = n
			return true, "Money = " .. n
		end,
	},
	addmoney = {
		Usage = "/addmoney <amount> [player]",
		Help = "add (or with a minus, take) Money",
		Min = 1,
		Max = 1,
		Check = function(args)
			local n = amount(args)
			return n and math.abs(n) <= MAX_MONEY and (n >= 0 and math.floor(n) or -math.floor(-n)) or nil
		end,
		Apply = function(p, n)
			local money = moneyValue(p)
			money.Value = math.clamp(money.Value + n, 0, MAX_MONEY)
			return true, "Money = " .. money.Value
		end,
	},
	speed = {
		Usage = "/speed <amount> [player]",
		Help = "set the Speed stat",
		Min = 1,
		Max = 1,
		Check = function(args)
			local n = amount(args)
			return n and cleanSpeed(n)
		end,
		Apply = function(p, n)
			speedValue(p).Value = n
			return true, "Speed = " .. n
		end,
	},
	addspeed = {
		Usage = "/addspeed <amount> [player]",
		Help = "add (or with a minus, take) Speed stat",
		Min = 1,
		Max = 1,
		Check = function(args)
			return amount(args)
		end,
		Apply = function(p, n)
			local speed = speedValue(p)
			speed.Value = cleanSpeed(speed.Value + n)
			return true, "Speed = " .. speed.Value
		end,
	},
	give = {
		Usage = "/give <carId|all> [player]",
		Help = "add a car (or every car) to the index",
		Min = 1,
		Max = 1,
		Check = function(args)
			local id = args[1]:lower()
			if id == "all" then
				return id
			end
			local spec = CarCatalog.Get(id)
			return spec and spec.Rollable and id or nil
		end,
		Apply = function(p, id)
			GachaService.Setup(p)
			if id == "all" then
				for _, spec in CarCatalog.Rollable() do
					GachaService.Grant(p, spec.Id)
				end
				return true, "gave every car"
			end
			local isNew = GachaService.Grant(p, id)
			return true, isNew and ("gave " .. id) or (id .. " already owned")
		end,
	},
	equip = {
		Usage = "/equip <carId> [player]",
		Help = "equip an owned car",
		Min = 1,
		Max = 1,
		Check = function(args)
			local id = args[1]:lower()
			return CarCatalog.Get(id) and id or nil
		end,
		Apply = function(p, id)
			if GachaService.Equip(p, id) then
				return true, "equipped " .. id
			end
			return false, id .. " is not owned (use /give " .. id .. ")"
		end,
	},
	roll = {
		Usage = "/roll [count] [player]",
		Help = "roll the gacha now (1-" .. AdminConfig.MAX_ROLLS .. " times)",
		Min = 0,
		Max = 1,
		TargetIfNotNumber = true,
		Check = function(args)
			local n = args[1] == nil and 1 or amount(args)
			return n and n == math.floor(n) and n >= 1 and n <= AdminConfig.MAX_ROLLS and n or nil
		end,
		Apply = function(p, n)
			local got = {}
			for _ = 1, n do
				local id, isNew = GachaService.Roll(p)
				if isNew then
					table.insert(got, id)
				end
			end
			return true, ("rolled %d; new: %s"):format(n, #got > 0 and table.concat(got, ", ") or "none")
		end,
	},
	wipe = {
		Usage = "/wipe [player]",
		Help = "reset Money, Speed, cars, stat points and upgrades",
		Min = 0,
		Max = 0,
		Check = function()
			return true
		end,
		Apply = function(p)
			moneyValue(p).Value = 0
			speedValue(p).Value = 0
			p:SetAttribute("RebirthLevel", 0)
			local stats = p:FindFirstChild("leaderstats")
			local rebirth = stats and stats:FindFirstChild("Rebirth")
			if rebirth then
				rebirth.Value = 0
			end
			for _, id in { "Luck", "Money", "Speed" } do
				p:SetAttribute("Boost_" .. id, 0)
				p:SetAttribute("BoostUntil_" .. id, 0)
			end
			p:SetAttribute("DailyStreak", 0)
			p:SetAttribute("DailyLast", -1)
			GachaService.Apply(p, {})
			UpgradeService.Apply(p, {}) -- after the gacha reset, so TurboCount starts from Rolls = 0
			return true, "wiped"
		end,
	},
	tp = {
		Usage = "/tp <track number> [player]",
		Help = "move the racing car to the start of a track",
		Min = 1,
		Max = 1,
		Check = function(args)
			local n = amount(args)
			return n and n == math.floor(n) and n >= 1 and n or nil
		end,
		Apply = function(p, n)
			local run = AdminService.RunOf(p)
			if not run or type(run.JumpToTrack) ~= "function" then
				return false, "no car is racing"
			end
			if run:JumpToTrack(n) then
				return true, "at the start of Track " .. n
			end
			return false, "there is no Track " .. n
		end,
	},
}

local ORDER = { "help", "money", "addmoney", "speed", "addspeed", "give", "equip", "roll", "wipe", "tp" }

local function helpText()
	local lines = { "Admin commands:" }
	for _, name in ORDER do
		local cmd = AdminService.Commands[name]
		table.insert(lines, cmd.Usage .. "  " .. cmd.Help)
	end
	return table.concat(lines, "\n")
end

local function execute(sender, text)
	if not AdminService.IsAdmin(sender) then
		return false, "You are not an admin."
	end
	local name, args = AdminService.Parse(text)
	local cmd = name and AdminService.Commands[name]
	if not cmd then
		return false, "Unknown command. Type /help."
	end
	if name == "help" then
		return true, helpText()
	end

	-- The last word is a target when there is one argument too many, or (for /roll) when it is not a number
	local targetWord = nil
	local extra = #args == cmd.Max + 1
	local wordNotCount = cmd.TargetIfNotNumber and #args == 1 and AdminService.ParseNumber(args[1]) == nil
	if extra or wordNotCount then
		targetWord = table.remove(args)
	end
	if #args < cmd.Min or #args > cmd.Max then
		return false, "Usage: " .. cmd.Usage
	end
	local value = cmd.Check(args)
	if value == nil then
		return false, "Usage: " .. cmd.Usage
	end
	local targets, err = resolveTargets(sender, targetWord)
	if not targets then
		return false, err
	end

	local anyOk, lastMessage = false, ""
	for _, target in targets do
		local ok, message = cmd.Apply(target, value)
		anyOk = anyOk or ok
		lastMessage = (#targets > 1 and (target.Name .. ": ") or "") .. message
	end
	if #targets > 1 then
		lastMessage = ("%s for %d players"):format(anyOk and "done" or "failed", #targets)
	end
	if anyOk then
		print("[ADMIN] " .. sender.Name .. ": " .. text)
	end
	return anyOk, lastMessage
end

-- Runs one command for `sender`. Returns ok, message. Never errors.
function AdminService.Run(sender, text)
	local ok, result, message = pcall(execute, sender, text)
	if not ok then
		warn("[ADMIN] " .. tostring(result))
		return false, "Command failed."
	end
	return result == true, type(message) == "string" and message or ""
end

local function reply(player, message)
	if replyRemote and typeof(player) == "Instance" and player:IsA("Player") then
		replyRemote:FireClient(player, message)
	end
end

function AdminService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	replyRemote = remotes:FindFirstChild("AdminMessage")
	if not replyRemote then
		replyRemote = Instance.new("RemoteEvent")
		replyRemote.Name = "AdminMessage"
		replyRemote.Parent = remotes
	end

	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local folder = TextChatService:FindFirstChild("AdminCommands")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "AdminCommands"
			folder.Parent = TextChatService
		end
		for _, name in ORDER do
			if not folder:FindFirstChild("Admin_" .. name) then
				local command = Instance.new("TextChatCommand")
				command.Name = "Admin_" .. name
				command.PrimaryAlias = "/" .. name
				command.AutocompleteVisible = false
				command.Triggered:Connect(function(source, text)
					local player = Players:GetPlayerByUserId(source.UserId)
					if player then
						local _, message = AdminService.Run(player, text)
						reply(player, message)
					end
				end)
				command.Parent = folder
			end
		end
	else
		local function watch(player)
			player.Chatted:Connect(function(text)
				local name = AdminService.Parse(text)
				if name and AdminService.Commands[name] then
					local _, message = AdminService.Run(player, text)
					reply(player, message)
				end
			end)
		end
		Players.PlayerAdded:Connect(watch)
		for _, player in Players:GetPlayers() do
			watch(player)
		end
	end
end

return AdminService
