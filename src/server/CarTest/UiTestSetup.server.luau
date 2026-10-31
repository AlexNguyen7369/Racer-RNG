--!nonstrict
-- UI test setups, run INSIDE the real server (same module cache as Main), so the live GachaService / CarService /
-- RaceService state is the one being changed. execute_luau snippets get separate module copies and can't do this.
--
-- Studio only. Trigger: ReplicatedStorage attribute UiTestSetup = "<id>:<nonce>". The setup <id> runs for every
-- Player, then ReplicatedStorage UiTestSetupDone = the same string. On error UiTestSetupError =
-- "<id>:<nonce>:<message>" is set first, and Done is still set.
--
-- Ids: snapshot, restore, spy, index_states, daily_unclaimed, daily_claimed, checkpoint_locked, checkpoint_open, quest_incomplete, quest_complete, stat_points, no_stat_points, auto_racing, on_foot, lose_event, turbo_next,
-- emphasized_next, auto_roll_on, rebirth_eligible, rebirth_not_eligible, duel_* (every id: UiSpec.ServerSetup), roll_odds_*, weather_* (rain, night, gold, aurora, clear, clear_event, rain_roll).
-- friends_0, friends_1, friends_4, friends_6, friends_4_potions, friends_clear (UiSpec.FriendsChip).
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
local questSnapshots = {} -- [Player] = QuestService.Snapshot before a quest_* fixture

-- Friends chip fixtures (UiSpec.FriendsChip, docs/FRIENDS_BOOST_SPEC.md section 5): the override and the planted
-- potions from before the first friends_* fixture. friends_clear and 'restore' put them back.
local friendsSnapshot = nil -- { count = { value }, boosts = { [Player] = { [attr] = value } } }
local function friendsRestore()
	if not friendsSnapshot then
		return
	end
	ReplicatedStorage:SetAttribute("FriendBoostTestCount", friendsSnapshot.count.value)
	for player, attrs in friendsSnapshot.boosts do
		if player.Parent then
			for name, value in attrs do
				player:SetAttribute(name, value)
			end
		end
	end
	friendsSnapshot = nil
end

local function stat(player, name)
	if name == "Speed" then
		return player:FindFirstChild("BaseSpeed") -- the base Speed; leaderstats.Speed is display only (owner 2026-10-21)
	end
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
	-- Reset the catalog portion first: a reused Studio player can already own every car,
	-- which would make this fixture unable to establish the required hidden rarest tile.
	local data = player:FindFirstChild("GachaData")
	if data then
		for _, entry in data:GetChildren() do
			if C.Get(entry.Name) and C.Get(entry.Name).Rollable then
				entry:Destroy()
			end
		end
	end
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
	if questSnapshots[player] then
		live("QuestService").Apply(player, questSnapshots[player])
		questSnapshots[player] = nil
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
	player:SetAttribute("UiTestRollOdds", nil) -- UiSpec.RollOdds.Attr
	friendsRestore() -- UiSpec.FriendsChip: the override and the planted potions (no-op without a snapshot)
	ReplicatedStorage:SetAttribute("UiTestFriendsFixture", nil) -- always, also after friends_clear (bug e5deb113)
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

-- UiSpec.ServerSetup on_foot (ui_speed_dial at rest): auto race stopped through the real Stop path, avatar on foot
-- with no car. Done is only set once that holds; 'restore' puts AutoRacing back (snap.autoRacing).
local ON_FOOT_TIMEOUT = 5 -- seconds
function setups.on_foot(player)
	assert(snapshots[player], "snapshot required before on_foot ('restore' consumes it: take a fresh 'snapshot')")
	local CarService = live("CarService")
	CarService.SetAutoRace(player, false)
	local start = os.clock()
	while
		CarService.IsAutoRacing(player)
		or player:GetAttribute("AutoRacing") == true
		or CarService.GetCar(player) ~= nil
	do
		if player.Parent ~= Players or os.clock() - start > ON_FOOT_TIMEOUT then
			error("on_foot: player still racing or still has a car after " .. ON_FOOT_TIMEOUT .. " s")
		end
		RunService.Heartbeat:Wait()
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

-- The Rebirth panel's button state (UiSpec.ServerSetup rebirth_*): the player's Level attribute set to the rebirth
-- requirement (eligible) or one below it (not eligible). Level / XP / XPToNext come back on 'restore'.
-- Auto-roll goes off so no duplicate-car sale (MoneyService.Award) moves Money during the click
-- (rebirth_money_not_reset is exact); 'restore' turns it back to the 'snapshot' value (snap.autoRoll).
local function rebirthLevelFixture(player, offset)
	progressionSnapshot(player)
	setAutoRoll(player, false)
	local attributes = progressionSnapshots[player].attributes
	for _, name in { "Level", "XP", "XPToNext" } do
		if attributes[name] == nil then
			attributes[name] = { value = player:GetAttribute(name) }
		end
	end
	local LevelConfig = require(Shared.LevelConfig)
	local need = LevelConfig.RebirthLevelRequirement(player:GetAttribute("RebirthLevel") or 0)
	player:SetAttribute("Level", need + offset)
end

function setups.rebirth_eligible(player)
	rebirthLevelFixture(player, 0)
end

function setups.rebirth_not_eligible(player)
	rebirthLevelFixture(player, -1)
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

-- Daily reward fixtures (UiSpec.ServerSetup daily_*): unsaved DailyLast; 'restore' puts DailyLast / DailyStreak back.
local function dailyFixture(player, last)
	progressionSnapshot(player)
	local attributes = progressionSnapshots[player].attributes
	for _, name in { "DailyLast", "DailyStreak" } do
		if attributes[name] == nil then
			attributes[name] = { value = player:GetAttribute(name) }
		end
	end
	player:SetAttribute("DailyLast", last)
end

function setups.daily_unclaimed(player)
	dailyFixture(player, -1)
end

function setups.daily_claimed(player)
	dailyFixture(player, math.floor(os.time() / 86400)) -- DailyLoginService dayNumber
end

-- Checkpoint fixtures (UiSpec checkpoint_*, docs/CHECKPOINT_SPEC.md): racing and rolls paused (a finish would raise
-- BestTrack), unsaved Checkpoint = 1 and BestTrack. 'restore' puts Checkpoint, BestTrack (the upgrade snapshot),
-- AutoRacing and AutoRoll back.
local function checkpointFixture(player, best)
	progressionSnapshot(player)
	local attributes = progressionSnapshots[player].attributes
	if attributes.Checkpoint == nil then
		attributes.Checkpoint = { value = player:GetAttribute("Checkpoint") }
	end
	setups.on_foot(player)
	setAutoRoll(player, false)
	player:SetAttribute("Checkpoint", 1)
	player:SetAttribute("BestTrack", best)
end

function setups.checkpoint_locked(player)
	checkpointFixture(player, 0)
end

function setups.checkpoint_open(player)
	checkpointFixture(player, 2)
end

-- Quest fixtures (UiSpec quest_claim_*, docs/QUESTS_SPEC.md): today's daily_races quest unclaimed with progress 0
-- (incomplete: Claim disabled) or at its Target (complete: Claim enabled). Unsaved; 'restore' applies the
-- QuestService snapshot taken before the first quest fixture.
local function questFixture(player, complete)
	assert(
		snapshots[player],
		"snapshot required before quest fixtures ('restore' consumes it: take a fresh 'snapshot')"
	)
	local QuestService = live("QuestService")
	local saved = QuestService.Snapshot(player)
	if not questSnapshots[player] then
		questSnapshots[player] = saved
	end
	local target
	for _, quest in require(Shared.QuestConfig).Daily do
		if quest.Id == "daily_races" then
			target = quest.Target
		end
	end
	assert(target, "QuestConfig.Daily has no daily_races")
	local fixture = table.clone(saved)
	fixture.QuestDaily = table.clone(saved.QuestDaily)
	fixture.QuestDailyClaimed = table.clone(saved.QuestDailyClaimed)
	fixture.QuestDaily.daily_races = complete and target or 0
	fixture.QuestDailyClaimed.daily_races = nil
	QuestService.Apply(player, fixture)
end

function setups.quest_incomplete(player)
	questFixture(player, false)
end

function setups.quest_complete(player)
	questFixture(player, true)
end

function setups.offline_welcome(player)
	progressionSnapshot(player)
	player:SetAttribute("OfflineSeconds", 3661)
	player:SetAttribute("OfflineSpeed", 1234)
end

-- OFFLINE_DOUBLE_SPEC section 2: the server opens the Double window with OfflineDoubleOpen = true, OfflineDoubled = nil.
-- Only the attributes are set (ShopService.SetOfflineReward is not called), so no reward is remembered and no receipt
-- can grant Speed; 'restore' puts both attributes back.
function setups.offline_double_open(player)
	setups.offline_welcome(player)
	local attributes = progressionSnapshots[player].attributes
	for _, name in { "OfflineDoubleOpen", "OfflineDoubled" } do
		if attributes[name] == nil then
			attributes[name] = { value = player:GetAttribute(name) }
		end
	end
	player:SetAttribute("OfflineDoubled", nil)
	player:SetAttribute("OfflineDoubleOpen", true)
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

-- weather_clear = no weather (""); weather_clear_event = the weather id "clear", running like any other
for _, event in { "rain", "night", "gold", "aurora", "clear", "clear_event" } do
	local id = event == "clear" and "" or event == "clear_event" and "clear" or event
	setups["weather_" .. event] = function(player)
		progressionSnapshot(player)
		if not weatherSnapshot then
			weatherSnapshot = {}
			for _, name in { "WeatherEvent", "WeatherEndsAt" } do
				weatherSnapshot[name] = { value = ReplicatedStorage:GetAttribute(name) }
			end
		end
		ReplicatedStorage:SetAttribute("WeatherEvent", id)
		ReplicatedStorage:SetAttribute("WeatherEndsAt", id == "" and 0 or workspace:GetServerTimeNow() + 180)
	end
end

function setups.workshop_open(player)
	local remote = ReplicatedStorage.Remotes:FindFirstChild("WorkshopOpen")
	assert(remote and remote:IsA("RemoteEvent"), "WorkshopOpen RemoteEvent required")
	remote:FireClient(player, player:GetAttribute("Plot"))
end

-- Duel UI fixtures (UiSpec.Duel.Fixture / FixtureChecks): fire Remotes.Duel at the test client only, DUEL_GAP
-- seconds between messages. DuelService is never called, so no real duel starts and no state needs a restore.
do
	local DuelConfig = require(Shared.DuelConfig)
	local DUEL_GAP = 0.6
	local OPPONENT, TRACKS, TRACK, SECOND_TRACKS = "UiTestRival", { 1, 2, 3 }, 2, { 2 } -- UiSpec.Duel.Fixture

	local function pick(tracks)
		return { Type = "PickTrack", Opponent = OPPONENT, Tracks = tracks or TRACKS }
	end
	local invite = { Type = "Invite", Opponent = OPPONENT, Track = TRACK }
	local function result(outcome, time, opponentTime, probe)
		return {
			Type = "Result",
			Result = outcome,
			Track = TRACK,
			Time = time,
			OpponentTime = opponentTime,
			UiTestPanelProbe = probe, -- UiSpec.Duel.ProbeField
		}
	end
	local function countdown()
		return { Type = "Countdown", Track = TRACK, ServerStart = workspace:GetServerTimeNow() + DuelConfig.COUNTDOWN }
	end

	-- A step is a message, a function that builds one when it is sent, or the PanelSwitch name the harness opens first
	local steps = {
		duel_pick = { pick() },
		duel_pick_replaced = { pick(), pick(SECOND_TRACKS) },
		duel_pick_over_index = { "Index", pick() },
		duel_invite = { invite },
		duel_invite_over_stats = { "Stats", invite },
		duel_invite_over_pick = { pick(), invite },
		duel_countdown = { invite, countdown },
		duel_result_win = { pick(), result("Win", 12.3, 13.1) },
		duel_result_lose = { pick(), result("Lose", 13.1, 12.3) },
		duel_result_draw = { pick(), result("Draw", 12.3, 12.3) },
		duel_toast_panel = { result("Win", 12.3, 13.1, "Index") },
		duel_cancel_unknown = { invite, { Type = "Cancelled", Reason = "UiTestUnknownReason" } },
	}
	-- UiSpec.Duel.CancelText
	for _, reason in
		{ "Declined", "InviteTimeout", "PickTimeout", "Left", "NotOnFoot", "Busy", "Cooldown", "NotLoaded" }
	do
		steps["duel_cancel_" .. string.lower(reason)] = { invite, { Type = "Cancelled", Reason = reason } }
	end

	for id, list in steps do
		setups[id] = function(player)
			local remote = ReplicatedStorage.Remotes:FindFirstChild("Duel")
			assert(remote and remote:IsA("RemoteEvent"), "Duel RemoteEvent required")
			for i, step in list do
				if i > 1 then
					task.wait(DUEL_GAP)
				end
				if type(step) == "string" then
					-- UiSpec.Duel.PrepAttr
					player:SetAttribute("UiTestDuelPrep", step .. ":" .. HttpService:GenerateGUID(false))
				else
					remote:FireClient(player, type(step) == "function" and step() or step)
				end
			end
		end
	end
end

-- Displayed-odds fixtures (UiSpec.RollOdds; docs/ROLL_ANIMATION_CONTRACT.md: RollResult's 6th argument is the roll's
-- luck). They only fire Remotes.RollResult at the test client: nothing is rolled, granted or paid. AutoRoll goes off
-- so no real roll covers the planted ones; 'restore' turns it back on and clears the attribute.
do
	local CarCatalog = require(Shared.CarCatalog)
	local RollAnimConfig = require(Shared.RollAnimConfig)
	local WeatherConfig = require(Shared.WeatherConfig)
	local GAP = 1 -- seconds between two animations

	-- The most common rollable car with a Chance >= 100 for `event` (nil = a car of no event), else any with a Chance
	local function carWithChance(event)
		local pick, fallback = nil, nil
		for _, spec in CarCatalog.Rollable() do -- rarest first
			if type(spec.Chance) == "number" and spec.Event == event then
				fallback = fallback or spec
				if spec.Chance >= 100 then
					pick = spec
				end
			end
		end
		return pick or fallback
	end

	local function catchAll()
		for _, spec in CarCatalog.Rollable() do
			if spec.Chance == nil and spec.Event == nil then
				return spec
			end
		end
		return nil
	end

	-- A compact roll, then an emphasized one (it plays on the enlarged card), both with `luck` as the 6th argument
	local function plant(player, fixture, spec, luck)
		assert(snapshots[player], "snapshot required before " .. fixture .. " ('restore' turns AutoRoll back on)")
		assert(spec, "no catalog car for " .. fixture)
		local remote = ReplicatedStorage.Remotes:FindFirstChild("RollResult")
		assert(remote and remote:IsA("RemoteEvent"), "RollResult RemoteEvent required")
		setAutoRoll(player, false)
		player:SetAttribute(
			"UiTestRollOdds",
			HttpService:JSONEncode({
				fixture = fixture,
				id = spec.Id,
				luck = luck,
				nonce = HttpService:GenerateGUID(false),
			})
		)
		task.spawn(function()
			task.wait(RollAnimConfig.Duration("Secret", true) + GAP) -- a real roll may still be playing
			for _, emphasized in { false, true } do
				if player.Parent ~= Players then
					return
				end
				remote:FireClient(player, spec.Id, false, 1, emphasized, 0, luck)
				task.wait(RollAnimConfig.Duration(spec.Rarity, emphasized) + GAP)
			end
		end)
	end

	-- UiSpec.RollOdds.Fixtures
	local lucks = {
		roll_odds_luck2 = function()
			return 2
		end,
		roll_odds_round = function()
			return 3
		end,
		roll_odds_clamp = function(spec)
			return spec.Chance * 4
		end,
		roll_odds_luck1 = function()
			return 1
		end,
		roll_odds_no_luck = function()
			return nil
		end,
	}
	for id, luck in lucks do
		setups[id] = function(player)
			local spec = assert(carWithChance(nil), "no rollable car with a Chance")
			plant(player, id, spec, luck(spec))
		end
	end

	function setups.roll_odds_catchall(player)
		plant(player, "roll_odds_catchall", catchAll(), 2)
	end

	-- What the server sends for a roll during Rain: this player's luck with the Rain multi in it
	function setups.weather_rain_roll(player)
		setups.weather_rain(player)
		local luck = live("GachaService").Luck(player)
		if live("WeatherService").Current() ~= "rain" then
			luck *= WeatherConfig.Events.rain.Luck -- the fixture only replicates the event, WeatherService is not in it
		end
		plant(player, "weather_rain_roll", carWithChance("rain") or carWithChance(nil), luck)
	end
end

local function progressionSpy()
	local folder = assert(ReplicatedStorage:FindFirstChild("UiTestSpy"), "spy setup required first")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	-- Rebirth too: the rebirth_* clicks must never really reset Money / Speed (UiSpec rebirth clicks, Intercept)
	-- UiSpec.RemoteFunctions: the rest must never really buy, equip, use a potion, claim or redeem (market_action_buy and
	-- the other Intercept clicks). Missing ones are skipped here; the client's Intercept check then reports them.
	local required = { BuyUpgrade = true, WorkshopUpgrade = true, Rebirth = true }
	for _, name in
		{
			"BuyUpgrade",
			"WorkshopUpgrade",
			"Rebirth",
			"MarketPurchase",
			"MarketEquip",
			"UseBoost",
			"DailyClaim",
			"QuestClaim",
			"RedeemCode",
			"SetCheckpoint",
			"PrepareGift",
		}
	do
		local target = remotes:FindFirstChild(name)
		if not required[name] and not (target and target:IsA("RemoteFunction")) then
			continue
		end
		assert(target and target:IsA("RemoteFunction"), name .. " RemoteFunction required")
		folder:SetAttribute(name, "[]")
		if target:GetAttribute("UiTestIntercepted") ~= true then
			-- ProgressionUi and RacerUiController resolve their targets with WaitForChild inside Activated, so a same-name proxy
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
				-- shop_redeem_invalid_code must see the server's real reply: a UiSpec.Shop.TestCode-style code (prefix
				-- "UITEST-", never a real code) goes to the real ShopService.Redeem, which answers and saves nothing.
				local text = ...
				if name == "RedeemCode" and type(text) == "string" and string.sub(text, 1, 7) == "UITEST-" then
					return live("ShopService").Redeem(player, text)
				end
				return false, "money"
			end
			proxy.Parent = remotes
		end
	end
	folder:SetAttribute("ProgressionIntercepted", true)
end

-- Workshop Showcase fixtures (UiSpec.WorkshopShowcase): unsaved, 'restore' puts the snapshot's cars back.
function setups.showcase_owned(player)
	assert(snapshots[player], "snapshot required before showcase fixtures")
	local G = live("GachaService")
	local CarCatalog = require(Shared.CarCatalog)
	local copies = { 0, 3, 7, 1, 12 }
	for i, spec in CarCatalog.Rollable() do
		if i > #copies then
			break
		end
		G.Grant(player, spec.Id)
		player.GachaData[spec.Id]:SetAttribute("Copies", copies[i])
	end
	player:SetAttribute("Showcase", "")
	G.RefreshShowcase(player)
end

function setups.showcase_filled(player)
	setups.showcase_owned(player)
	local G = live("GachaService")
	local CarCatalog = require(Shared.CarCatalog)
	local GachaConfig = require(Shared.GachaConfig)
	local owned = {}
	for _, entry in player.GachaData:GetChildren() do
		local spec = CarCatalog.Get(entry.Name)
		if spec and spec.Rollable and not spec.GamepassId then
			table.insert(owned, { Id = spec.Id, Bonus = GachaConfig.SlotBonus(spec, G.Copies(player, spec.Id)) })
		end
	end
	table.sort(owned, function(a, b)
		if a.Bonus ~= b.Bonus then
			return a.Bonus < b.Bonus
		end
		return a.Id < b.Id
	end)
	local ids = {}
	for i = 1, math.min(3, #owned) do
		ids[i] = owned[i].Id
	end
	player:SetAttribute("Showcase", table.concat(ids, ","))
	G.RefreshShowcase(player)
end

-- A same-name proxy for Remotes.SetShowcase that logs every call and then runs the REAL GachaService.SetShowcase.
local function showcaseSpy()
	local folder = assert(ReplicatedStorage:FindFirstChild("UiTestSpy"), "spy setup required first")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local target = remotes:FindFirstChild("SetShowcase")
	assert(target and target:IsA("RemoteFunction"), "SetShowcase RemoteFunction required")
	folder:SetAttribute("SetShowcase", "[]")
	if target:GetAttribute("UiTestSpied") == true then
		return
	end
	target.Name = "UiTestOriginal_SetShowcase"
	local proxy = Instance.new("RemoteFunction")
	proxy.Name = "SetShowcase"
	proxy:SetAttribute("UiTestSpied", true)
	functionSpies[target] = { name = "SetShowcase", proxy = proxy }
	proxy.OnServerInvoke = function(player, ...)
		local log = HttpService:JSONDecode(folder:GetAttribute("SetShowcase") or "[]")
		table.insert(log, { user = player.UserId, args = { ... } })
		folder:SetAttribute("SetShowcase", HttpService:JSONEncode(log))
		return live("GachaService").SetShowcase(player, ...)
	end
	proxy.Parent = remotes
end

-- friends_<n>: ReplicatedStorage.FriendBoostTestCount = n (FriendBoostService refreshes FriendsInServer and
-- FriendBoost at once). friends_4_potions also starts one potion per BoostConfig category (BoostUntil_<id>), so the
-- chip is judged beside real potion icons. UiTestFriendsFixture (ReplicatedStorage) names the fixture being judged.
for _, item in
	{ { "friends_0", 0 }, { "friends_1", 1 }, { "friends_4", 4 }, { "friends_6", 6 }, { "friends_4_potions", 4 } }
do
	setups[item[1]] = function(player)
		if not friendsSnapshot then
			friendsSnapshot =
				{ count = { value = ReplicatedStorage:GetAttribute("FriendBoostTestCount") }, boosts = {} }
		end
		if item[1] == "friends_4_potions" and not friendsSnapshot.boosts[player] then
			local BoostConfig = require(Shared.BoostConfig)
			local attrs = {}
			for _, category in BoostConfig.Order do
				local first = BoostConfig.ItemsFor(category)[1]
				if first then
					local name = "BoostUntil_" .. first.Id
					attrs[name] = player:GetAttribute(name)
					player:SetAttribute(name, workspace:GetServerTimeNow() + 600)
				end
			end
			friendsSnapshot.boosts[player] = attrs
		end
		ReplicatedStorage:SetAttribute("FriendBoostTestCount", item[2])
		ReplicatedStorage:SetAttribute("UiTestFriendsFixture", item[1])
	end
end
function setups.friends_clear(_player)
	friendsRestore()
	ReplicatedStorage:SetAttribute("UiTestFriendsFixture", "friends_clear")
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
		if id == "showcase_spy" then
			showcaseSpy()
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
