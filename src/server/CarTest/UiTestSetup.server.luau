--!nonstrict
-- UI test setups, run INSIDE the real server (same module cache as Main), so the live GachaService / CarService /
-- RaceService state is the one being changed. execute_luau snippets get separate module copies and can't do this.
--
-- Studio only. Trigger: ReplicatedStorage attribute UiTestSetup = "<id>:<nonce>". The setup <id> runs for every
-- Player, then ReplicatedStorage UiTestSetupDone = the same string. On error UiTestSetupError =
-- "<id>:<nonce>:<message>" is set first, and Done is still set.
--
-- Ids: snapshot, restore, spy, index_states, stat_points, no_stat_points, auto_racing, lose_event, turbo_next,
-- emphasized_next, auto_roll_on.
-- (Ported from the ServerSetup snippets in Client/UiTest/UiSpec.luau.)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local Server = script.Parent.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")

local function live(name)
	return require(Server:WaitForChild(name))
end

local snapshots = {} -- [Player] = { gacha, money, speed, autoRacing, autoRoll, upgrades }
local spied = {} -- [RemoteEvent] = connection (never connect twice)
local functionSpies = {} -- original RemoteFunction -> { name, proxy }; original callback is untouched.
local progressionSnapshots = {}
local weatherSnapshot = nil

local function stat(player, name)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild(name)
end

local function removeSpy()
	for remote, entry in functionSpies do
		entry.proxy:Destroy()
		remote.Name = entry.name
	end
	table.clear(functionSpies)
	for _, conn in spied do
		conn:Disconnect()
	end
	table.clear(spied)
	local f = ReplicatedStorage:FindFirstChild("UiTestSpy")
	if f then
		f:Destroy()
	end
end

-- Every catalog car but the rarest (stays "???"), the first equipped, all stat points freed (>= 1).
local function indexStates(player)
	local G = live("GachaService")
	local C = require(Shared.CarCatalog)
	local GachaConfig = require(Shared.GachaConfig)
	local rarest = C.Rollable()[1].Id
	for _, s in C.All() do
		if s.Id ~= rarest then
			G.Grant(player, s.Id)
		end
	end
	local all = C.All()
	G.Equip(player, all[1].Id ~= rarest and all[1].Id or all[2].Id)
	for _, st in GachaConfig.STATS do
		player:SetAttribute("Alloc_" .. st, 0)
	end
	player:SetAttribute("StatPoints", G.FreePoints(player))
end

-- AUTO toggle (docs/ROLL_ANIMATION_CONTRACT.md): through GachaService.SetAutoRoll when it exists, else the
-- AutoRoll attribute the auto-roll loop reads.
local function setAutoRoll(player, on)
	local G = live("GachaService")
	if type(G.SetAutoRoll) == "function" then
		G.SetAutoRoll(player, on)
	else
		player:SetAttribute("AutoRoll", on)
	end
end

local setups = {}

-- Global (not per player): logs every RemoteEvent call into ReplicatedStorage.UiTestSpy attributes,
-- one JSON array per remote name: [{ user = UserId, args = {...} }, ...]. The real handlers still run.
local function spy()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local f = ReplicatedStorage:FindFirstChild("UiTestSpy")
	if not f then
		f = Instance.new("Folder")
		f.Name = "UiTestSpy"
		f.Parent = ReplicatedStorage
	end
	for _, r in remotes:GetChildren() do
		if r:IsA("RemoteEvent") then
			f:SetAttribute(r.Name, "[]")
			if not spied[r] then
				spied[r] = r.OnServerEvent:Connect(function(p, ...)
					local folder = ReplicatedStorage:FindFirstChild("UiTestSpy")
					if not folder then
						return
					end
					local log = HttpService:JSONDecode(folder:GetAttribute(r.Name) or "[]")
					table.insert(log, { user = p.UserId, args = { ... } })
					folder:SetAttribute(r.Name, HttpService:JSONEncode(log))
				end)
			end
		end
	end
end

-- Run once per test session: the baseline is kept until 'restore' (a second snapshot must never overwrite it with
-- state the tests already changed, e.g. after emphasized_next or turbo_next).
function setups.snapshot(player)
	if snapshots[player] then
		return
	end
	local G = live("GachaService")
	local money, speed = stat(player, "Money"), stat(player, "Speed")
	snapshots[player] = {
		gacha = G.Snapshot(player),
		money = money and money.Value or nil,
		speed = speed and speed.Value or nil,
		autoRacing = player:GetAttribute("AutoRacing"),
		autoRoll = player:GetAttribute("AutoRoll"),
		-- Upgrade tree state (owned upgrades, BestTrack, TurboCount): turbo_next and the progression fixtures change it
		upgrades = live("UpgradeService").Snapshot(player),
	}
end

function setups.restore(player)
	local snap = snapshots[player]
	if not snap then
		error(
			"no snapshot for " .. player.Name .. " (restore consumes it: run 'snapshot' again before the next fixture)"
		)
	end
	live("GachaService").Apply(player, snap.gacha)
	local progression = progressionSnapshots[player]
	if progression then
		live("UpgradeService").Apply(player, progression.upgrades)
		for name, entry in progression.attributes do
			player:SetAttribute(name, entry.value)
		end
		progressionSnapshots[player] = nil
		if progression.root and player.Character then
			local root = player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = progression.root
			end
		end
	end
	if snap.upgrades then
		-- The baseline taken before any fixture (TurboCount after turbo_next included)
		live("UpgradeService").Apply(player, snap.upgrades)
	end
	if weatherSnapshot then
		for name, entry in weatherSnapshot do
			ReplicatedStorage:SetAttribute(name, entry.value)
		end
		weatherSnapshot = nil
	end
	local money, speed = stat(player, "Money"), stat(player, "Speed")
	if money and snap.money ~= nil then
		money.Value = snap.money
	end
	if speed and snap.speed ~= nil then
		speed.Value = snap.speed
	end
	live("CarService").SetAutoRace(player, snap.autoRacing == true)
	if snap.autoRoll ~= nil then
		setAutoRoll(player, snap.autoRoll == true)
	end
	snapshots[player] = nil
	removeSpy()
end

function setups.index_states(player)
	indexStates(player)
end

function setups.stat_points(player)
	indexStates(player)
end

function setups.no_stat_points(player)
	local G = live("GachaService")
	player:SetAttribute("Alloc_Speed", (player:GetAttribute("Alloc_Speed") or 0) + G.FreePoints(player))
	player:SetAttribute("StatPoints", G.FreePoints(player))
end

function setups.auto_racing(player)
	local CarService = live("CarService")
	if CarService.IsAutoRacing(player) ~= true then
		CarService.SetAutoRace(player, true)
	end
end

-- A fake loss sent to the client only (the real run's state is never touched): Result/Lose now, then after
-- NpcConfig.LOSE_SCREEN_SECONDS a Reset to Track 1 and a Start for Track 1, shaped like RaceService's events.
-- Done is set right after the Result is sent, so the loser screen can be checked while it shows.
function setups.lose_event(player)
	local NpcConfig = require(Shared.NpcConfig)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NpcRace")
	local run = live("CarService").GetRun(player)
	local track = type(run) == "table" and type(run.RaceTrack) == "number" and run.RaceTrack or 1
	remote:FireClient(player, {
		Type = "Result",
		Track = track,
		Result = "Lose",
		PlayerTime = 31.5,
		NpcTime = 30,
		Banked = 0, -- SPAWN_AND_ROLLS_SPEC section 3: a loss banks nothing...
		Unbanked = 0, -- ...and clears the bank
	})
	task.delay(NpcConfig.LOSE_SCREEN_SECONDS, function()
		if player.Parent ~= Players then
			return
		end
		remote:FireClient(player, { Type = "Reset", Track = 1 })
		local cfg = NpcConfig.For(1)
		remote:FireClient(player, {
			Type = "Start",
			Track = 1,
			ServerStart = workspace:GetServerTimeNow(),
			Speed = cfg.Speed,
			Color = cfg.Color,
			Label = cfg.Label,
			Model = cfg.Model,
		})
	end)
end

-- Turbo luck: the upgrade tree decides it (UpgradeService.AdvanceTurbo: turbo when TurboCount + 1 >= Every of
-- UpgradeService.Turbo(player)), so TurboCount = Every - 1 makes the next auto roll a turbo roll. Rolls alone no
-- longer does. 'restore' puts the snapshot's upgrade state (TurboCount included) back.
function setups.turbo_next(player)
	local U = live("UpgradeService")
	local turbo = U.Turbo(player)
	local every = type(turbo) == "table" and turbo.Every
	if type(every) ~= "number" or every < 1 then
		error("UpgradeService.Turbo(player).Every missing")
	end
	player:SetAttribute("TurboEvery", every)
	player:SetAttribute("TurboCount", every - 1)
end

-- Roll animation (docs/ROLL_ANIMATION_CONTRACT.md): the next auto roll is an emphasized roll. Owning no rollable car
-- makes any roll new and, with fewer than 5 cars owned, emphasized (GachaConfig.IsEmphasized). As soon as that roll
-- happened (Rolls changed) exactly the cars owned before are given back (the rolled one is not kept), with the new
-- roll count, so later rolls are not emphasized by accident and no car is gained.
function setups.emphasized_next(player)
	local G = live("GachaService")
	local before = G.Snapshot(player)
	local empty = table.clone(before)
	empty.Cars = {}
	G.Apply(player, empty)
	local rolls0 = player:GetAttribute("Rolls")
	task.spawn(function()
		local deadline = os.clock() + 60
		while player.Parent == Players and player:GetAttribute("Rolls") == rolls0 and os.clock() < deadline do
			task.wait(0.05)
		end
		if player.Parent ~= Players then
			return
		end
		before.Rolls = player:GetAttribute("Rolls")
		G.Apply(player, before)
	end)
end

function setups.auto_roll_on(player)
	setAutoRoll(player, true)
end

local function progressionSnapshot(player)
	if not snapshots[player] then
		error("snapshot required before progression fixtures ('restore' consumes it: take a fresh 'snapshot')")
	end
	if progressionSnapshots[player] then
		return
	end
	local attributes = {}
	for _, name in { "WorkshopLevel", "OfflineSpeed", "OfflineSeconds", "UiTestProgressionFixture" } do
		attributes[name] = { value = player:GetAttribute(name) }
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	progressionSnapshots[player] =
		{ upgrades = live("UpgradeService").Snapshot(player), attributes = attributes, root = root and root.CFrame }
end

function setups.progression_buyable(player)
	progressionSnapshot(player)
	live("UpgradeService").Apply(player, { Upgrades = {}, BestTrack = 0, TurboCount = 0 })
	local money = assert(stat(player, "Money"), "Money required")
	money.Value = 100000
	live("UpgradeService").Refresh(player)
end

function setups.progression_no_money(player)
	setups.progression_buyable(player)
	stat(player, "Money").Value = 0
	live("UpgradeService").Refresh(player)
end

function setups.offline_welcome(player)
	progressionSnapshot(player)
	player:SetAttribute("OfflineSeconds", 3661)
	player:SetAttribute("OfflineSpeed", 1234)
end

function setups.offline_zero(player)
	progressionSnapshot(player)
	player:SetAttribute("OfflineSpeed", 0)
	player:SetAttribute("OfflineSeconds", 0)
end

-- World fixtures must END with the avatar at the spot, not just teleport once: a Stop (CarService.SetAutoRace false,
-- e.g. from 'restore') keeps pulling a real player's avatar back to the walk spawn for CarService PLACE_HOLD (2 s), and
-- the client owns its character's physics, so it can send back an older position. The avatar is re-placed until its
-- REPLICATED position (the client's, since the client owns it) has stayed at the spot for MOVE_STABLE seconds, and
-- within `maxDistance` of the pad when a prompt must be usable. Otherwise the setup errors (never a silent "done").
local MOVE_TIMEOUT = 8 -- seconds; well above CarService PLACE_HOLD
local MOVE_STABLE = 1 -- seconds the avatar must stay put (several client -> server replication steps)
local MOVE_SLACK = 3 -- studs (horizontal) from the placement spot
local MOVE_REPLACE = 0.25 -- seconds between re-placements while it is elsewhere

local function moveTo(player, pad, fixture, outside, maxDistance)
	progressionSnapshot(player)
	assert(player:GetAttribute("AutoRacing") ~= true, "on-foot player required for world fixtures; stop auto first")
	assert(player.Character and player.Character:FindFirstChild("HumanoidRootPart"), "character root required")
	local target = pad.CFrame * CFrame.new(outside and pad.Size.X + 12 or 0, pad.Size.Y / 2 + 3, 0)
	local function rootOf()
		return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	end
	local function place()
		local root = rootOf()
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = target
		end
	end
	local function where()
		local root = rootOf()
		if not root then
			return false, "no character root"
		end
		local off = root.Position - target.Position
		local flat = Vector2.new(off.X, off.Z).Magnitude
		local toPad = (root.Position - pad.Position).Magnitude
		local ok = flat <= MOVE_SLACK and (maxDistance == nil or toPad <= maxDistance)
		return ok,
			string.format("%.1f studs from the spot, %.1f from the pad (limit %s)", flat, toPad, tostring(maxDistance))
	end
	place()
	player:SetAttribute("UiTestProgressionFixture", fixture)
	local start = os.clock()
	local lastPlace, stableSince, why = start, nil, "not checked"
	while os.clock() - start < MOVE_TIMEOUT do
		RunService.Heartbeat:Wait()
		if player.Parent ~= Players then
			error("player left during " .. fixture)
		end
		local ok, detail = where()
		why = detail
		local now = os.clock()
		if ok then
			stableSince = stableSince or now
			if now - stableSince >= MOVE_STABLE then
				return
			end
		else
			stableSince = nil
			if now - lastPlace >= MOVE_REPLACE then
				place()
				lastPlace = now
			end
		end
	end
	error(fixture .. ": avatar did not stay at the spot within " .. MOVE_TIMEOUT .. " s (" .. why .. ")")
end

for _, own in { true, false } do
	local id = own and "workshop_owner_prompt" or "workshop_foreign_prompt"
	setups[id] = function(player)
		local plots = assert(workspace:FindFirstChild("Workshops"), "Workshops required")
		local target = nil
		for _, plot in plots:GetChildren() do
			local owner = plot:GetAttribute("Owner")
			if
				(own and owner == player.UserId)
				or (not own and type(owner) == "number" and owner > 0 and owner ~= player.UserId)
			then
				target = plot:FindFirstChild("UpgradePad", true)
				break
			end
		end
		assert(target, own and "owned UpgradePad required" or "second player's workshop required; never fake ownership")
		-- E only works inside the prompt's MaxActivationDistance: that is the distance verified, not a guess
		local prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
		assert(prompt, "UpgradePad ProximityPrompt required")
		moveTo(player, target, id, false, prompt.MaxActivationDistance)
	end
end

for _, outside in { false, true } do
	local id = outside and "upgrade_world_leave" or "upgrade_world_enter"
	setups[id] = function(player)
		local pad = nil
		for _, candidate in game:GetService("CollectionService"):GetTagged("UpgradePad") do
			if candidate:IsDescendantOf(workspace) and not candidate:FindFirstAncestor("Workshops") then
				pad = candidate
				break
			end
		end
		moveTo(player, assert(pad, "spawn UpgradePad required"), id, outside)
	end
end

for _, event in { "rain", "night", "gold", "clear" } do
	setups["weather_" .. event] = function(player)
		progressionSnapshot(player)
		if not weatherSnapshot then
			weatherSnapshot = {}
			for _, name in { "WeatherEvent", "WeatherEndsAt" } do
				weatherSnapshot[name] = { value = ReplicatedStorage:GetAttribute(name) }
			end
		end
		ReplicatedStorage:SetAttribute("WeatherEvent", event == "clear" and "" or event)
		ReplicatedStorage:SetAttribute("WeatherEndsAt", event == "clear" and 0 or workspace:GetServerTimeNow() + 180)
	end
end

function setups.workshop_open(player)
	local remote = ReplicatedStorage.Remotes:FindFirstChild("WorkshopOpen")
	assert(remote and remote:IsA("RemoteEvent"), "WorkshopOpen RemoteEvent required")
	remote:FireClient(player, player:GetAttribute("Plot"))
end

local function progressionSpy()
	local folder = assert(ReplicatedStorage:FindFirstChild("UiTestSpy"), "spy setup required first")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in { "BuyUpgrade", "WorkshopUpgrade" } do
		local target = remotes:FindFirstChild(name)
		assert(target and target:IsA("RemoteFunction"), name .. " RemoteFunction required")
		folder:SetAttribute(name, "[]")
		if target:GetAttribute("UiTestIntercepted") ~= true then
			-- ProgressionUi resolves both targets with WaitForChild inside Activated, so a same-name proxy
			-- intercepts every argument while keeping the original callback and its cooldown closure intact.
			target.Name = "UiTestOriginal_" .. name
			local proxy = Instance.new("RemoteFunction")
			proxy.Name = name
			proxy:SetAttribute("UiTestIntercepted", true)
			functionSpies[target] = { name = name, proxy = proxy }
			proxy.OnServerInvoke = function(player, ...)
				local log = HttpService:JSONDecode(folder:GetAttribute(name) or "[]")
				table.insert(log, { user = player.UserId, args = { ... } })
				folder:SetAttribute(name, HttpService:JSONEncode(log))
				return false, "money"
			end
			proxy.Parent = remotes
		end
	end
	folder:SetAttribute("ProgressionIntercepted", true)
end

local function runSetup(request)
	local id = string.match(request, "^([^:]+):")
	ReplicatedStorage:SetAttribute("UiTestSetupError", nil)
	local ok, err = pcall(function()
		if id == "spy" then
			spy()
			return
		end
		if id == "progression_spy" then
			progressionSpy()
			return
		end
		local fn = id and setups[id]
		if not fn then
			error("unknown setup id " .. tostring(id))
		end
		for _, player in Players:GetPlayers() do
			fn(player)
		end
	end)
	if not ok then
		ReplicatedStorage:SetAttribute("UiTestSetupError", request .. ":" .. tostring(err))
	end
	ReplicatedStorage:SetAttribute("UiTestSetupDone", request)
end

local queue, busy = {}, false
local function onRequest()
	local request = ReplicatedStorage:GetAttribute("UiTestSetup")
	if type(request) ~= "string" or request == "" then
		return
	end
	table.insert(queue, request)
	if busy then
		return
	end
	busy = true
	while #queue > 0 do
		runSetup(table.remove(queue, 1))
	end
	busy = false
end

ReplicatedStorage:GetAttributeChangedSignal("UiTestSetup"):Connect(onRequest)
