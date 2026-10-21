--!nonstrict
-- BRIEF (owner, 2026-10-12, dashboard card 75e286a3; docs/GAME_DESIGN_REQUIREMENTS.md "Duels (player vs player)",
-- contract docs/DUEL_SPEC.md): "A player requests a duel against another player; the other player accepts or
-- declines. The challenger is asked at once which track to race, and both players must have unlocked that track.
-- No stake." Spec section 4: "`duel` harness scenario: every refusal of rule 1, the unlock list of rule 2 and a
-- rejected out-of-list pick, both timeouts, decline, forfeit by stop and by leaving, winner by finish order, Money
-- and `Unbanked` unchanged for both players, `DuelWins` saved and loaded, stability rules on both cars."
-- Written before Shared/DuelConfig, Server/DuelService, options.Duel in RaceService.NewRun and Remotes.Duel exist:
-- red by design.
--
-- Test seams agreed with the implementation (the spec leaves them open): DuelService.SetClock(fn) (every timer of
-- the service reads it), DuelService.Tick() (timeouts, countdown release, forfeits, finished races),
-- DuelService.SetNotify(fn(player, message)) (every message a client would get), DuelService.PlayerLeft(player).
-- Refusal reasons: "Self", "NotLoaded", "NotOnFoot", "Busy", "Cooldown", "NoRequest", "BadTrack". Cancel reasons:
-- "PickTimeout", "InviteTimeout", "Declined", "NotOnFoot", "Left".
-- The players are fakes (a Folder plus an R6 rig given to CarService.OnCharacter), as in the auto_toggle scenario.
-- The duels race the LIVE route (RaceService.GetRoute()); the options.Duel run is tested alone on its own chain.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent
local Tests = {}

-- Spec section 2
local NUMBERS = {
	REQUEST_COOLDOWN = 10,
	PICK_TIMEOUT = 15,
	INVITE_TIMEOUT = 15,
	COUNTDOWN = 3,
	RACE_TIMEOUT = 180,
	PROMPT_DISTANCE = 10,
}
local API = {
	"Start",
	"Request",
	"Pick",
	"Respond",
	"StateOf",
	"Unlocked",
	"Choices",
	"Tick",
	"SetClock",
	"SetNotify",
	"PlayerLeft",
}
local RUN_ORIGIN = Vector3.new(40000, 0, 40000) -- the options.Duel run's own chain, far from every other scenario
local RUN_TRACKS = 3 -- the options.Duel run's chain: the first three tracks
local RUN_TRACK = 2 -- the run starts on the second one: not the first, and not the last (the route goes on after it)
local RUN_CAP = 40 -- s: the options.Duel run at MAX_STAT must finish its track within this
local RUN_AFTER = 0.5 -- s driven past the finish, to see OnFinish is not called again
local START_SLACK = 3 -- studs beyond RaceService.START_AHEAD from the track's start waypoint (as the admin /tp test)
local START_RADIUS = 25 -- studs (horizontal): a held duel car is at the picked track's start (as auto_toggle)
local GRACE = 3 -- s after a start before path deviation is measured (PhysicsTargets.race: "start (after 3 s)")
local TIME_SLACK = 1 -- s between a reported run time and the test's own clock
local SEAT_WAIT = 5 -- s for both avatars to be seated (CarService SEAT_TIMEOUT is 3)
local END_WAIT = 4 -- s for a decided duel to put both players back on foot (CarService UNSEAT_TIMEOUT is 1)
local WALK_SLACK = 8 -- studs (horizontal) from the walk spawn (CarService PLACE_SLACK; two fakes share the spot)
local GAP = 30 -- fake seconds between two requests: more than REQUEST_COOLDOWN
local SPAWN_CLEAR_RADIUS = 20
local SPAWN_CLEAR_LIFT = 80
local UID_SAVED = 990075001 -- fake user id of the saved player

local function module(parent, name)
	local source = parent:FindFirstChild(name)
	if not source then
		return nil
	end
	local ok, value = pcall(require, source)
	return ok and type(value) == "table" and value or nil
end

local function report(name)
	local r = { scenario = name, pass = true, checks = {}, metrics = {} }
	local function flag(label, ok, value, limit)
		table.insert(
			r.checks,
			{ name = label, pass = ok == true, value = value or (ok and 1 or 0), limit = limit or 1 }
		)
		r.pass = r.pass and ok == true
	end
	return r, flag
end

local function hdist(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function round(x)
	return math.round(x * 1000) / 1000
end

-- Runs each(t, dt) every Heartbeat for `seconds` (or until it returns true). Returns the seconds waited.
local function frames(seconds, each)
	local t = 0
	while t < seconds do
		local dt = RunService.Heartbeat:Wait()
		t += dt
		if each and each(t, dt) then
			break
		end
	end
	return t
end

-- Distance from p to the polyline pts between segments lo..hi.
local function polyDist(pts, p, lo, hi)
	local best = math.huge
	for i = math.max(lo, 1), math.min(hi, #pts - 1) do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		best = math.min(best, (p - (a + ab * t)).Magnitude)
	end
	return best
end

local function sameList(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then
		return false
	end
	for i, v in a do
		if b[i] ~= v then
			return false
		end
	end
	return true
end

local function seq(n)
	local list = {}
	for i = 1, n do
		list[i] = i
	end
	return list
end

-- A minimal R6 avatar (as the auto_toggle scenario's): root, torso, head, legs, Motor6D joints, a Humanoid.
local function newFakeCharacter(cf)
	local model = Instance.new("Model")
	model.Name = "CarTestDuelCharacter"
	local function part(name, size, offset, transparency, collide)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf * CFrame.new(offset)
		p.Transparency = transparency
		p.CanCollide = collide
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, 1, false)
	local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.zero, 0, true)
	local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), 0, true)
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), 0, false)
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), 0, false)
	local function motor(name, p0, p1, c0, c1)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = p0
	end
	motor("RootJoint", root, torso, CFrame.new(), CFrame.new())
	motor("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	motor("Left Hip", torso, leftLeg, CFrame.new(-1, -1, 0), CFrame.new(-0.5, 1, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(1, -1, 0), CFrame.new(0.5, 1, 0))
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	model.PrimaryPart = root
	model.Parent = Workspace
	return model, humanoid, root
end

-- Test isolation (as auto_toggle): real, unseated characters near the walk spawn wait anchored above it while the
-- fakes stand there. The returned release() puts them back; it is idempotent.
local function clearSpawnOfRealPlayers(center)
	local moved = {}
	local function sweep()
		for _, plr in Players:GetPlayers() do
			local char = plr.Character
			if char and char.Parent and not moved[char] then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local seated = hum ~= nil and hum.SeatPart ~= nil
				local okPivot, pivot = pcall(char.GetPivot, char)
				if not seated and okPivot and hdist(pivot.Position, center) <= SPAWN_CLEAR_RADIUS then
					local rootPart = char:FindFirstChild("HumanoidRootPart")
					moved[char] = {
						Pivot = pivot,
						Root = rootPart,
						Anchored = rootPart and rootPart:IsA("BasePart") and rootPart.Anchored or false,
					}
					pcall(function()
						if rootPart and rootPart:IsA("BasePart") then
							rootPart.Anchored = true
						end
						char:PivotTo(CFrame.new(center + Vector3.new(0, SPAWN_CLEAR_LIFT, 0)))
					end)
				end
			end
		end
	end
	sweep()
	local conn = RunService.Heartbeat:Connect(sweep)
	local released = false
	return function()
		if released then
			return
		end
		released = true
		conn:Disconnect()
		for char, saved in moved do
			if char.Parent then
				pcall(function()
					char:PivotTo(saved.Pivot)
					if saved.Root and saved.Root.Parent then
						saved.Root.Anchored = saved.Anchored
					end
				end)
			end
		end
	end
end

-- A fake PlayerData store (the data scenario's pattern): UpdateAsync hands the transform a copy and writes what
-- it returns.
local function newSaveStore(initial)
	local store = { data = initial or {} }
	function store:GetAsync(key)
		return self.data[key]
	end
	function store:SetAsync(key, value)
		self.data[key] = value
	end
	function store:UpdateAsync(key, transform)
		local current = self.data[key]
		local value = transform(type(current) == "table" and table.clone(current) or current)
		if value == nil then
			return nil
		end
		self.data[key] = value
		return value
	end
	return store
end

-- Spec section 3: `options.Duel = { Track = n, OnFinish = fn(run, time) }` is a non-NPC run that starts on track
-- n, pays no pad and ends at that track's FinishIndex. Driven alone, at MAX_STAT (the stability rules hold at
-- maximum stat speed too), on the second track of its own three-track chain.
local function duelRunAlone(r, flag, M)
	local specs = M.TrackRegistry.Chain()
	flag("duel_run_chain_has_three_tracks", #specs >= RUN_TRACKS, #specs, RUN_TRACKS)
	if #specs < RUN_TRACKS then
		return
	end
	local models, car, player, run = {}, nil, nil, nil
	local ok, err = pcall(function()
		local entries = {}
		local origin = CFrame.new(RUN_ORIGIN + Vector3.new(0, M.TrackBuilder.TRACK_LIFT or 0, 0))
		for i = 1, RUN_TRACKS do
			local model, layout = M.TrackBuilder.Build(specs[i], origin)
			model.Name = "CarTestDuelRunTrack" .. i
			model.Parent = Workspace
			table.insert(models, model)
			entries[i] = { Layout = layout, Origin = origin, Model = model, Number = specs[i].Number }
			origin = M.TrackBuilder.EndCFrame(layout, origin)
		end
		local route = M.RaceService.BuildRoute(entries)
		local wps = route.Path.WorldWaypoints
		local track = route.Tracks[RUN_TRACK]

		player = Instance.new("Folder")
		player.Name = "CarTestDuelRunPlayer"
		player.Parent = Workspace
		M.Money.Setup(player)
		M.PlayerData.Setup(player)
		player.BaseSpeed.Value = M.RaceConfig.MAX_STAT -- base Speed (owner 2026-10-21)
		player.leaderstats.Money.Value = 500
		player:SetAttribute("Unbanked", 0) -- as CarService.OnCharacter leaves it
		local earned0 = player:GetAttribute("MoneyEarned") or 0

		car = M.CarFactory.build(M.CarConfig)
		car.Name = "CarTestDuelRunCar"
		car:PivotTo(entries[1].Model.Start.CFrame + Vector3.new(0, M.CarConfig.RestHeight, 0))
		car.Parent = Workspace
		local chassis = car.PrimaryPart

		local elapsed = 0
		local finishes = {}
		run = M.RaceService.NewRun(car, route, player, {
			Duel = {
				Track = track.Number,
				OnFinish = function(finishedRun, seconds)
					table.insert(finishes, {
						Run = finishedRun,
						Time = seconds,
						At = elapsed,
						Index = run and run.Driver and run.Driver.Index or -1,
					})
				end,
			},
		})
		local fromStart = hdist(chassis.Position, wps[track.StartIndex])
		local startLimit = M.RaceService.START_AHEAD + START_SLACK
		local started = fromStart <= startLimit
		flag("duel_run_starts_on_track_n", started, round(fromStart), startLimit)
		flag("duel_run_is_not_an_npc_race", started and run.RaceTrack == nil)

		-- Only a run that really started on track n is driven (the red run would drive the whole chain)
		local minUp, dev, early, maxUnbanked = 1, 0, 0, 0
		local finishedAt = nil
		if started then
			frames(RUN_CAP, function(_, dt)
				elapsed += dt
				if run.Finished and #finishes == 0 and run.Driver.Index < track.FinishIndex then
					early += 1
				end
				maxUnbanked =
					math.max(maxUnbanked, tonumber(run.Unbanked) or 1, tonumber(player:GetAttribute("Unbanked")) or 1)
				if #finishes > 0 or run.Finished then
					finishedAt = finishedAt or elapsed
					return elapsed - finishedAt >= RUN_AFTER
				end
				minUp = math.min(minUp, chassis.CFrame.UpVector.Y)
				if elapsed > GRACE then
					local i = run.Driver.Index
					dev = math.max(dev, polyDist(wps, chassis.Position, i - 3, i + 3))
				end
				return false
			end)
		end
		r.metrics.duel_run_seconds = round(elapsed)
		local first = finishes[1] or {}
		flag("duel_run_finished_in_time", started and finishedAt ~= nil, round(elapsed), RUN_CAP)
		flag("duel_run_on_finish_called_exactly_once", #finishes == 1, #finishes, 1)
		flag("duel_run_on_finish_gets_the_run", first.Run ~= nil and first.Run == run)
		flag(
			"duel_run_finished_at_finish_index",
			run.Finished == true and first.Index ~= nil and first.Index >= track.FinishIndex and early == 0,
			first.Index or -1,
			track.FinishIndex
		)
		local reported = first.Time
		flag(
			"duel_run_time_is_seconds_from_start_to_finish",
			type(reported) == "number" and reported > 0 and math.abs(reported - first.At) <= TIME_SLACK,
			type(reported) == "number" and round(reported) or -1,
			round(first.At or 0)
		)
		-- The car passed this track's pad (it is before the finish) and, by index, the first track's pad
		flag(
			"duel_run_pays_no_pad",
			started and finishedAt ~= nil and run.Payouts == 0 and run.PaidTotal == 0,
			tonumber(run.PaidTotal) or -1,
			0
		)
		flag("duel_run_unbanked_stays_zero", started and finishedAt ~= nil and maxUnbanked == 0, maxUnbanked, 0)
		local strict = M.Targets.lap.MinUpYStrict
		local worstUp = math.min(minUp, tonumber(run.MinUpY) or -1)
		flag(
			"duel_run_never_tilted_at_max_stat",
			started and finishedAt ~= nil and worstUp >= strict,
			round(worstUp),
			strict
		)
		flag(
			"duel_run_no_flip_recoveries",
			started and finishedAt ~= nil and run.FlipRecoveries == 0,
			tonumber(run.FlipRecoveries) or -1,
			0
		)
		local maxDev = M.Targets.race.MaxPathDeviation
		flag("duel_run_sticks_to_path", started and finishedAt ~= nil and dev <= maxDev, round(dev), maxDev)
		run:Destroy()
		local money = player.leaderstats.Money.Value
		flag(
			"duel_run_money_unchanged_after_destroy",
			money == 500
				and (player:GetAttribute("MoneyEarned") or 0) == earned0
				and player:GetAttribute("Unbanked") == 0,
			money,
			500
		)
		flag("duel_run_on_finish_not_called_by_destroy", #finishes <= 1, #finishes, 1)
	end)
	if run then
		pcall(function()
			run:Destroy()
		end)
	end
	if car then
		car:Destroy()
	end
	if player then
		player:Destroy()
	end
	for _, model in models do
		model:Destroy()
	end
	flag("duel_run_no_runtime_error", ok, nil, ok and 1 or tostring(err))
end

function Tests.duel()
	local r, flag = report("duel")
	local config = module(Shared, "DuelConfig")
	local service = module(Server, "DuelService")
	local M = {
		CarService = module(Server, "CarService"),
		RaceService = module(Server, "RaceService"),
		PlayerData = module(Server, "PlayerData"),
		Money = module(Server, "MoneyService"),
		Gacha = module(Server, "GachaService"),
		Upgrades = module(Server, "UpgradeService"),
		RaceConfig = module(Shared, "RaceConfig"),
		TrackBuilder = module(Shared, "TrackBuilder"),
		TrackRegistry = module(Shared, "TrackRegistry"),
		CarFactory = module(Shared, "CarFactory"),
		CarConfig = module(Shared, "CarConfig"),
		Targets = module(Shared, "PhysicsTargets"),
	}
	local present = 0
	for _ in M do
		present += 1
	end
	local modulesOk = present == 12
		and type(M.Targets.lap) == "table"
		and type(M.Targets.lap.MinUpYStrict) == "number"
		and type(M.Targets.race) == "table"
		and type(M.Targets.race.MaxPathDeviation) == "number"
	flag("duel_existing_modules_present", modulesOk, present, 12)

	-- Numbers (spec section 2)
	flag("duel_config_exists", config ~= nil)
	local numbers = config or {}
	for name, value in NUMBERS do
		flag("duel_config_" .. string.lower(name), numbers[name] == value, tonumber(numbers[name]) or -1, value)
	end

	-- Remotes.Duel (spec section 3). Its client -> server payloads need real clients: multiplayer-tester.
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("Duel")
	flag("duel_remote_is_remote_event", remote ~= nil and remote:IsA("RemoteEvent"))

	-- Rule 1: every on-foot character carries the server-made DuelPrompt ("Duel", PROMPT_DISTANCE). Only real
	-- players have one, so this passes with nobody on foot (metric); the trigger itself is multiplayer-tester's.
	local promptChecked, promptMissing = 0, 0
	for _, plr in Players:GetPlayers() do
		local character = plr.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and plr:GetAttribute("AutoRacing") ~= true then
			promptChecked += 1
			local prompt = character:FindFirstChild("DuelPrompt", true)
			local promptOk = prompt ~= nil
				and prompt:IsA("ProximityPrompt")
				and (prompt.ActionText == "Duel" or prompt.ObjectText == "Duel")
				and prompt.MaxActivationDistance == NUMBERS.PROMPT_DISTANCE
			if not promptOk then
				promptMissing += 1
			end
		end
	end
	r.metrics.duel_prompt_characters_checked = promptChecked
	flag("duel_prompt_on_every_on_foot_character", promptMissing == 0, promptMissing, 0)

	if not modulesOk then
		return r
	end
	duelRunAlone(r, flag, M)

	-- Service API (spec section 3 + the agreed test seams)
	local api = service ~= nil and config ~= nil
	for _, name in API do
		api = api and type(service[name]) == "function"
	end
	flag("duel_api_exists", api == true)
	if not api then
		return r
	end
	local CarService, PlayerData = M.CarService, M.PlayerData
	local route = M.RaceService.GetRoute()
	local routeOk = type(route) == "table"
		and type(route.Tracks) == "table"
		and #route.Tracks >= 3
		and type(route.Path) == "table"
		and type(route.Path.WorldWaypoints) == "table"
	flag("duel_live_route_has_three_tracks", routeOk, routeOk and #route.Tracks or -1, 3)
	local okWalk, walkCF = pcall(CarService.WalkSpawnCFrame)
	flag("duel_walk_spawn_is_cframe", okWalk and typeof(walkCF) == "CFrame")
	if not (routeOk and okWalk and typeof(walkCF) == "CFrame") then
		return r
	end

	local wps = route.Path.WorldWaypoints
	local trackCount = #route.Tracks
	local function trackOf(number)
		for _, track in route.Tracks do
			if track.Number == number then
				return track
			end
		end
		return nil
	end
	local strict = M.Targets.lap.MinUpYStrict
	local maxDev = M.Targets.race.MaxPathDeviation
	local HALF = M.RaceConfig.HALF_STAT

	local fakes = {}
	local sent = {} -- every message the service sent, in order: { Player, Message }
	local now = 1000 -- the injected clock (seconds)
	local releaseSpawn = clearSpawnOfRealPlayers(walkCF.Position)

	local ok, err = pcall(function()
		service.SetClock(function()
			return now
		end)
		service.SetNotify(function(player, message)
			table.insert(sent, { Player = player, Message = message })
		end)

		local function attach(player)
			local character, humanoid, root = newFakeCharacter(CFrame.new(walkCF.Position + Vector3.new(0, 3, 0)))
			local f = { Player = player, Character = character, Humanoid = humanoid, Root = root }
			table.insert(fakes, f)
			CarService.OnCharacter(player, character)
			return f
		end
		local function newPlayer(tag)
			local p = Instance.new("Folder")
			p.Name = "CarTestDuel" .. tag
			p.Parent = Workspace
			M.Money.Setup(p)
			PlayerData.Setup(p)
			M.Gacha.Setup(p)
			M.Upgrades.Setup(p)
			return p
		end
		-- A loaded fake on foot at the walk spawn
		local function newFake(tag, stat, bestTrack)
			local p = newPlayer(tag)
			p.BaseSpeed.Value = stat
			p:SetAttribute("BestTrack", bestTrack)
			p:SetAttribute("DataLoaded", true)
			return attach(p)
		end
		local function state(f)
			return service.StateOf(f.Player)
		end
		local function both(a, b, want)
			return state(a) == want and state(b) == want
		end
		local function wins(f)
			return f.Player:GetAttribute("DuelWins") or 0
		end
		local function wallet(f)
			return {
				Money = f.Player.leaderstats.Money.Value,
				Earned = f.Player:GetAttribute("MoneyEarned") or 0,
			}
		end
		-- Money and MoneyEarned as before, Unbanked 0
		local function sameWallet(f, before)
			local w = wallet(f)
			return w.Money == before.Money and w.Earned == before.Earned and f.Player:GetAttribute("Unbanked") == 0
		end
		-- Messages to fake f (of one Type) sent after index `from`
		local function msgs(from, f, typ)
			local list = {}
			for i = from + 1, #sent do
				local s = sent[i]
				if s.Player == f.Player and type(s.Message) == "table" and (typ == nil or s.Message.Type == typ) then
					table.insert(list, s.Message)
				end
			end
			return list
		end
		-- No duel was offered to anybody after index `from`
		local function nothingOffered(from)
			for i = from + 1, #sent do
				local m = sent[i].Message
				if type(m) == "table" and (m.Type == "PickTrack" or m.Type == "Invite" or m.Type == "Countdown") then
					return false
				end
			end
			return true
		end
		-- Ticks the service every frame until done() or `seconds` passed. Returns done().
		local function settle(seconds, done)
			local deadline = os.clock() + seconds
			while true do
				service.Tick()
				if done() then
					return true
				end
				if os.clock() >= deadline then
					return false
				end
				RunService.Heartbeat:Wait()
			end
		end
		local function onFoot(f)
			return CarService.IsAutoRacing(f.Player) ~= true
				and f.Player:GetAttribute("AutoRacing") == false
				and f.Player:GetAttribute("RaceEvent") == "Off"
				and CarService.GetCar(f.Player) == nil
				and CarService.GetRun(f.Player) == nil
				and f.Humanoid.SeatPart == nil
		end
		local function atWalkSpawn(f)
			return hdist(f.Root.Position, CarService.WalkSpawnCFrame().Position) <= WALK_SLACK
		end
		local function stop(f)
			pcall(CarService.SetAutoRace, f.Player, false)
		end
		local function discard(f)
			pcall(service.PlayerLeft, f.Player)
			stop(f)
			f.Character:Destroy()
			f.Player:Destroy()
		end
		-- Request(a, b) must be refused with `want` (nil: any reason) and offer nothing to anybody.
		local function refused(label, a, b, want)
			local from = #sent
			local accepted, reason = service.Request(a.Player, b.Player)
			flag(
				"duel_refused_" .. label,
				accepted == false
					and (want == nil or reason == want)
					and type(reason) == "string"
					and nothingOffered(from),
				tostring(reason),
				want or "<a reason>"
			)
		end

		-- The players. B is LOADED from a save (DuelWins 4), so the saved count is what a win adds to.
		local A = newFake("A", 0, 2)
		A.Player.leaderstats.Money.Value = 123
		local saveStore = newSaveStore({
			[PlayerData.KeyFor(UID_SAVED)] = { Money = 77, Speed = HALF, BestTrack = 4, DuelWins = 4, Version = 8 },
		})
		PlayerData.SetStore(saveStore)
		local playerB = newPlayer("B")
		local loadedB = PlayerData.Load(playerB, UID_SAVED)
		PlayerData.SetStore(nil)
		flag(
			"duel_wins_loaded_from_save",
			loadedB == true and playerB:GetAttribute("DuelWins") == 4 and playerB:GetAttribute("DataLoaded") == true,
			tonumber(playerB:GetAttribute("DuelWins")) or -1,
			4
		)
		playerB:SetAttribute("DuelWins", 4) -- the later counts do not depend on the check above
		playerB:SetAttribute("DataLoaded", true)
		playerB:SetAttribute("BestTrack", 4)
		playerB.BaseSpeed.Value = HALF
		playerB.leaderstats.Money.Value = 77
		local B = attach(playerB)
		local C = newFake("C", 0, 0)
		RunService.Heartbeat:Wait()
		flag("duel_fakes_start_on_foot", onFoot(A) and onFoot(B) and onFoot(C))
		flag("duel_state_none_at_start", both(A, B, "None") and state(C) == "None", tostring(state(A)), "None")
		local walletA, walletB = wallet(A), wallet(B)

		-- Rule 2: Unlocked(p) = min(BestTrack + 1, number of tracks); Track 1 is always unlocked
		local function unlockedWith(best)
			C.Player:SetAttribute("BestTrack", best)
			return service.Unlocked(C.Player)
		end
		for _, case in
			{
				{ "best_0", 0, 1 },
				{ "best_2", 2, math.min(3, trackCount) },
				{ "last_track_won", trackCount - 1, trackCount },
				{ "all_tracks_won", trackCount, trackCount },
				{ "best_99", 99, trackCount },
			}
		do
			local got = unlockedWith(case[2])
			flag("duel_unlocked_" .. case[1], got == case[3], tonumber(got) or -1, case[3])
		end
		local gotBare = unlockedWith(nil)
		flag("duel_unlocked_without_best_track_is_1", gotBare == 1, tonumber(gotBare) or -1, 1)
		-- Choices(a, b) = 1 .. min(Unlocked(a), Unlocked(b)); A unlocked 3, B unlocked 5
		local wantAB = seq(math.min(3, trackCount))
		local function choicesText(list)
			return type(list) == "table" and table.concat(list, ",") or tostring(list)
		end
		local chAB, chBA = service.Choices(A.Player, B.Player), service.Choices(B.Player, A.Player)
		flag("duel_choices_are_1_to_min_unlocked", sameList(chAB, wantAB), choicesText(chAB), choicesText(wantAB))
		flag("duel_choices_same_both_ways", sameList(chBA, wantAB), choicesText(chBA), choicesText(wantAB))
		C.Player:SetAttribute("BestTrack", 0)
		local chCB = service.Choices(C.Player, B.Player)
		flag("duel_choices_track_1_only_for_new_player", sameList(chCB, { 1 }), choicesText(chCB), "1")
		C.Player:SetAttribute("BestTrack", 99)
		local chAll = service.Choices(C.Player, B.Player)
		local wantAll = seq(math.min(5, trackCount))
		flag("duel_choices_capped_by_track_count", sameList(chAll, wantAll), choicesText(chAll), choicesText(wantAll))
		C.Player:SetAttribute("BestTrack", 0)

		-- Rule 1: every refusal, for the requester and for the target. A refused request changes nothing.
		refused("self", A, A, "Self")
		C.Player:SetAttribute("DataLoaded", nil)
		refused("target_not_loaded", A, C, "NotLoaded")
		refused("requester_not_loaded", C, A, "NotLoaded")
		C.Player:SetAttribute("DataLoaded", true)
		C.Player:SetAttribute("DataFailed", true)
		refused("target_data_failed", A, C, "NotLoaded")
		refused("requester_data_failed", C, A, "NotLoaded")
		C.Player:SetAttribute("DataFailed", nil)
		-- not on foot: C starts an ordinary auto race (teleporting into the seat, then racing)
		local startedC = false
		task.spawn(function()
			pcall(CarService.SetAutoRace, C.Player, true)
			startedC = true
		end)
		r.metrics.duel_refusal_fixture_event = tostring(C.Player:GetAttribute("RaceEvent"))
		refused("target_teleporting_into_car", A, C, "NotOnFoot")
		refused("requester_teleporting_into_car", C, A, "NotOnFoot")
		frames(SEAT_WAIT, function()
			return startedC
		end)
		local racingC = C.Player:GetAttribute("RaceEvent") == "Racing" and CarService.IsAutoRacing(C.Player) == true
		flag("duel_refusal_fixture_is_auto_racing", racingC)
		refused("target_auto_racing", A, C, "NotOnFoot")
		refused("requester_auto_racing", C, A, "NotOnFoot")
		stop(C)
		settle(END_WAIT, function()
			return onFoot(C)
		end)
		-- dead: the spec names no reason of its own for it, so any refusal counts
		local D = newFake("Dead", 0, 0)
		D.Humanoid.Health = 0
		frames(0.3)
		refused("target_dead", A, D, nil)
		refused("requester_dead", D, A, nil)
		discard(D)
		flag(
			"duel_refused_requests_change_no_state",
			both(A, B, "None") and state(C) == "None" and onFoot(A) and onFoot(B) and onFoot(C)
		)

		-- An accepted request: the challenger is asked at once which track (refusals above started no cooldown)
		local t0 = now
		local from = #sent
		local accepted = service.Request(A.Player, B.Player)
		flag("duel_request_accepted", accepted == true)
		flag("duel_request_state_picking_for_both", both(A, B, "Picking"), tostring(state(A)), "Picking")
		local asked = msgs(from, A, "PickTrack")
		local ask = asked[1] or {}
		flag("duel_pick_track_sent_to_challenger_at_once", #asked == 1, #asked, 1)
		flag("duel_pick_track_names_opponent", ask.Opponent == B.Player.Name, tostring(ask.Opponent), B.Player.Name)
		flag(
			"duel_pick_track_lists_choices",
			sameList(ask.Tracks, wantAB),
			choicesText(ask.Tracks),
			choicesText(wantAB)
		)
		flag("duel_target_hears_nothing_before_the_pick", #msgs(from, B) == 0, #msgs(from, B), 0)
		-- in a pending request = busy, for both players and both directions
		refused("busy_requester_asked", C, A, "Busy")
		refused("busy_target_asked", C, B, "Busy")
		refused("busy_requester_asks", A, C, "Busy")
		refused("busy_target_asks", B, C, "Busy")
		refused("busy_target_asks_requester", B, A, "Busy")
		-- Pick / Respond without a matching pending state
		local function noRequest(label, fn, f, arg)
			local done, reason = fn(f.Player, arg)
			flag("duel_no_request_" .. label, done == false and reason == "NoRequest", tostring(reason), "NoRequest")
		end
		noRequest("pick_by_target", service.Pick, B, 1)
		noRequest("pick_by_stranger", service.Pick, C, 1)
		noRequest("respond_before_the_pick", service.Respond, B, true)
		noRequest("respond_by_stranger", service.Respond, C, true)
		flag("duel_wrong_calls_keep_picking", both(A, B, "Picking"), tostring(state(A)), "Picking")
		-- a pick outside the list is rejected and the request stays in Picking
		for _, bad in
			{
				{ "above_the_list", math.min(3, trackCount) + 1 },
				{ "above_the_track_count", trackCount + 1 },
				{ "zero", 0 },
				{ "negative", -1 },
				{ "fraction", 2.5 },
			}
		do
			local picked, reason = service.Pick(A.Player, bad[2])
			flag(
				"duel_pick_out_of_list_rejected_" .. bad[1],
				picked == false and reason == "BadTrack" and both(A, B, "Picking"),
				tostring(reason),
				"BadTrack"
			)
		end
		local junkKept = true
		for _, junk in { "1", {}, true, 0 / 0, math.huge } do
			local okJunk, picked = pcall(service.Pick, A.Player, junk)
			junkKept = junkKept and okJunk and picked == false and both(A, B, "Picking")
		end
		local okNil, pickedNil = pcall(service.Pick, A.Player, nil)
		flag("duel_pick_junk_rejected", junkKept and okNil and pickedNil == false and both(A, B, "Picking"))
		-- validated against a FRESHLY computed list: B's unlock drops to Track 1 after the list was sent
		B.Player:SetAttribute("BestTrack", 0)
		local staleTrack = math.min(3, trackCount)
		local pickedStale, staleReason = service.Pick(A.Player, staleTrack)
		flag(
			"duel_pick_validated_against_fresh_list",
			pickedStale == false and staleReason == "BadTrack" and both(A, B, "Picking"),
			tostring(staleReason),
			"BadTrack"
		)
		from = #sent
		local picked = service.Pick(A.Player, 1)
		B.Player:SetAttribute("BestTrack", 4)
		flag("duel_pick_accepted", picked == true)
		flag("duel_pick_state_invited_for_both", both(A, B, "Invited"), tostring(state(A)), "Invited")
		local invites = msgs(from, B, "Invite")
		local invite = invites[1] or {}
		flag("duel_invite_sent_to_target", #invites == 1, #invites, 1)
		flag(
			"duel_invite_names_challenger_and_track",
			invite.Opponent == A.Player.Name and invite.Track == 1,
			tostring(invite.Opponent) .. "/" .. tostring(invite.Track),
			A.Player.Name .. "/1"
		)
		noRequest("second_pick", service.Pick, A, 1)
		noRequest("respond_by_challenger", service.Respond, A, true)
		pcall(service.Respond, B.Player, nil) -- not a boolean: ignored
		pcall(service.Respond, B.Player, "yes")
		flag("duel_respond_junk_ignored", both(A, B, "Invited"), tostring(state(A)), "Invited")

		-- Decline
		now = t0 + 1
		from = #sent
		local declined = service.Respond(B.Player, false)
		flag("duel_decline_returns_true", declined == true)
		flag("duel_decline_state_none", both(A, B, "None"), tostring(state(A)), "None")
		local told = msgs(from, A, "Cancelled")
		flag(
			"duel_decline_challenger_is_told",
			#told == 1 and told[1].Reason == "Declined",
			tostring((told[1] or {}).Reason),
			"Declined"
		)
		flag("duel_decline_starts_no_race", onFoot(A) and onFoot(B) and #msgs(from, A, "Countdown") == 0)

		-- REQUEST_COOLDOWN since A's last request (the refused ones never count)
		refused("cooldown_after_1s", A, B, "Cooldown")
		now = t0 + NUMBERS.REQUEST_COOLDOWN - 0.01
		refused("cooldown_just_before_10s", A, B, "Cooldown")
		flag("duel_cooldown_refusal_changes_no_state", both(A, B, "None"), tostring(state(A)), "None")
		now = t0 + NUMBERS.REQUEST_COOLDOWN
		local t1 = now
		from = #sent
		flag("duel_request_accepted_after_cooldown", service.Request(A.Player, B.Player) == true)

		-- No pick within PICK_TIMEOUT cancels the request
		now = t1 + NUMBERS.PICK_TIMEOUT - 0.1
		service.Tick()
		flag("duel_pick_not_timed_out_before_15s", both(A, B, "Picking"), tostring(state(A)), "Picking")
		now = t1 + NUMBERS.PICK_TIMEOUT + 0.1
		service.Tick()
		flag("duel_pick_timeout_state_none", both(A, B, "None"), tostring(state(A)), "None")
		told = msgs(from, A, "Cancelled")
		flag(
			"duel_pick_timeout_challenger_is_told",
			#told == 1 and told[1].Reason == "PickTimeout",
			tostring((told[1] or {}).Reason),
			"PickTimeout"
		)
		local lateDone, lateReason = service.Pick(A.Player, 1)
		flag(
			"duel_pick_after_timeout_refused",
			lateDone == false and lateReason == "NoRequest",
			tostring(lateReason),
			"NoRequest"
		)

		-- No answer within INVITE_TIMEOUT is a decline (B challenges A this time: the cooldown is per requester)
		local t2 = now
		from = #sent
		local acceptedBA = service.Request(B.Player, A.Player)
		local askedB = msgs(from, B, "PickTrack")[1] or {}
		flag(
			"duel_request_by_other_player_asks_them",
			acceptedBA == true and askedB.Opponent == A.Player.Name and sameList(askedB.Tracks, wantAB),
			tostring(askedB.Opponent),
			A.Player.Name
		)
		flag("duel_pick_by_other_player_accepted", service.Pick(B.Player, 1) == true)
		local invitedA = msgs(from, A, "Invite")[1] or {}
		flag("duel_invite_goes_to_the_other_player", invitedA.Opponent == B.Player.Name and invitedA.Track == 1)
		now = t2 + NUMBERS.INVITE_TIMEOUT - 0.1
		service.Tick()
		flag("duel_invite_not_timed_out_before_15s", both(A, B, "Invited"), tostring(state(A)), "Invited")
		now = t2 + NUMBERS.INVITE_TIMEOUT + 0.1
		service.Tick()
		flag("duel_invite_timeout_state_none", both(A, B, "None"), tostring(state(A)), "None")
		told = msgs(from, B, "Cancelled")
		flag(
			"duel_invite_timeout_challenger_is_told",
			#told == 1 and told[1].Reason == "InviteTimeout",
			tostring((told[1] or {}).Reason),
			"InviteTimeout"
		)
		local lateAnswer, lateAnswerReason = service.Respond(A.Player, true)
		flag(
			"duel_respond_after_timeout_refused",
			lateAnswer == false and lateAnswerReason == "NoRequest" and onFoot(A) and onFoot(B),
			tostring(lateAnswerReason),
			"NoRequest"
		)

		-- Leaving during Invited / Picking cancels with "Left" and cleans the state
		now += GAP
		local L1 = newFake("LeftInvited", 0, 0)
		from = #sent
		local leftOk = service.Request(A.Player, L1.Player) == true and service.Pick(A.Player, 1) == true
		service.PlayerLeft(L1.Player)
		told = msgs(from, A, "Cancelled")
		flag(
			"duel_leave_while_invited_cancels",
			leftOk and both(A, L1, "None") and #told == 1 and told[1].Reason == "Left",
			tostring((told[1] or {}).Reason),
			"Left"
		)
		discard(L1)
		now += GAP
		local L2 = newFake("LeftPicking", 0, 0)
		local leftPicking = service.Request(L2.Player, B.Player) == true and both(L2, B, "Picking")
		service.PlayerLeft(L2.Player)
		flag("duel_leave_while_picking_cleans_state", leftPicking and both(L2, B, "None"), tostring(state(B)), "None")
		discard(L2)

		-- Rule 3: the conditions of rule 1 are checked again on accept (A starts an ordinary auto race meanwhile)
		now += GAP
		from = #sent
		local recheckOk = service.Request(A.Player, B.Player) == true and service.Pick(A.Player, 1) == true
		local startedA = false
		task.spawn(function()
			pcall(CarService.SetAutoRace, A.Player, true)
			startedA = true
		end)
		local answered, answer = false, nil
		task.spawn(function()
			local okAnswer, value = pcall(service.Respond, B.Player, true)
			answer = okAnswer and value
			answered = true
		end)
		settle(SEAT_WAIT, function()
			return answered and startedA
		end)
		told = msgs(from, A, "Cancelled")
		flag(
			"duel_accept_rechecks_rule_1",
			recheckOk
				and answered
				and answer ~= true
				and both(A, B, "None")
				and #told == 1
				and told[1].Reason == "NotOnFoot"
				and #msgs(from, A, "Countdown") == 0
				and #msgs(from, B, "Countdown") == 0,
			tostring((told[1] or {}).Reason),
			"NotOnFoot"
		)
		flag("duel_failed_accept_gives_target_no_car", onFoot(B))
		stop(A)
		settle(END_WAIT, function()
			return onFoot(A) and onFoot(B)
		end)

		-- Request -> pick -> accept, until both avatars are seated in their held cars and the Countdown was sent.
		local function begin(pre, a, b, number)
			now += GAP
			local d = { A = a, B = b, Track = trackOf(number), Number = number, From = #sent, T0 = now }
			d.WinsA, d.WinsB = wins(a), wins(b)
			local requested = service.Request(a.Player, b.Player)
			local chosen = service.Pick(a.Player, number)
			local done, value = false, nil
			task.spawn(function()
				local okAnswer, returned = pcall(service.Respond, b.Player, true)
				value = okAnswer and returned
				done = true
			end)
			-- a refused request or pick never seats anybody: do not wait for it
			local seated = requested == true
				and chosen == true
				and settle(SEAT_WAIT, function()
					return done and #msgs(d.From, a, "Countdown") >= 1 and #msgs(d.From, b, "Countdown") >= 1
				end)
			d.CarA, d.CarB = CarService.GetCar(a.Player), CarService.GetCar(b.Player)
			d.Ready = requested == true and chosen == true and value == true and seated and both(a, b, "Countdown")
			flag(pre .. "_accepted_and_countdown_sent_to_both", d.Ready, tostring(state(a)), "Countdown")
			return d
		end
		-- COUNTDOWN later on the clock, one Tick releases both cars: runs exist, chassis free, state Racing.
		local function release(pre, d)
			now = d.T0 + NUMBERS.COUNTDOWN
			service.Tick()
			d.RunA, d.RunB = CarService.GetRun(d.A.Player), CarService.GetRun(d.B.Player)
			d.CarA, d.CarB = CarService.GetCar(d.A.Player), CarService.GetCar(d.B.Player)
			local free = 0
			for _, car in { d.CarA, d.CarB } do
				if car and car.PrimaryPart and car.PrimaryPart.Anchored == false then
					free += 1
				end
			end
			d.Racing = type(d.RunA) == "table"
				and type(d.RunB) == "table"
				and d.RunA ~= d.RunB
				and free == 2
				and both(d.A, d.B, "Racing")
			flag(pre .. "_both_released_in_the_same_tick", d.Racing, free, 2)
			return d.Racing
		end
		-- The end of a duel: both on foot at the walk spawn, cars removed, one Result each, DuelWins, no Money.
		-- `gone` (left or died) is only checked for its car and its state.
		local function finish(pre, d, wantA, wantB, gone)
			local function stands(f)
				return f == gone or onFoot(f)
			end
			local ended = settle(END_WAIT, function()
				return both(d.A, d.B, "None")
					and stands(d.A)
					and stands(d.B)
					and CarService.GetCar(d.A.Player) == nil
					and CarService.GetCar(d.B.Player) == nil
			end)
			flag(pre .. "_ends_with_state_none", ended and both(d.A, d.B, "None"), tostring(state(d.A)), "None")
			local carsGone = 0
			for _, car in { d.CarA, d.CarB } do
				if car and car.Parent == nil then
					carsGone += 1
				end
			end
			flag(pre .. "_both_cars_removed", ended and carsGone == 2, carsGone, 2)
			local standing = true
			for _, f in { d.A, d.B } do
				if f ~= gone then
					standing = standing and onFoot(f) and atWalkSpawn(f)
				end
			end
			flag(pre .. "_players_on_foot_at_walk_spawn", standing)
			d.ResultA, d.ResultB = msgs(d.From, d.A, "Result"), msgs(d.From, d.B, "Result")
			local resultsOk = true
			for _, side in { { d.A, d.ResultA, wantA }, { d.B, d.ResultB, wantB } } do
				if side[1] ~= gone then
					local m = side[2][1] or {}
					resultsOk = resultsOk and #side[2] == 1 and m.Result == side[3] and m.Track == d.Number
				end
			end
			flag(
				pre .. "_result_sent",
				resultsOk,
				tostring((d.ResultA[1] or {}).Result) .. "/" .. tostring((d.ResultB[1] or {}).Result),
				wantA .. "/" .. wantB
			)
			local cancels = 0
			for _, f in { d.A, d.B } do
				if f ~= gone then
					cancels += #msgs(d.From, f, "Cancelled")
				end
			end
			flag(pre .. "_no_cancelled_message", cancels == 0, cancels, 0)
			local gainA = wantA == "Win" and 1 or 0
			local gainB = wantB == "Win" and 1 or 0
			flag(
				pre .. "_duel_wins",
				wins(d.A) == d.WinsA + gainA and wins(d.B) == d.WinsB + gainB,
				wins(d.A) .. "/" .. wins(d.B),
				(d.WinsA + gainA) .. "/" .. (d.WinsB + gainB)
			)
			local moneyOk = true
			for _, side in { { A, walletA }, { B, walletB } } do
				if side[1] == d.A or side[1] == d.B then
					moneyOk = moneyOk and sameWallet(side[1], side[2])
				end
			end
			flag(pre .. "_money_and_unbanked_unchanged", moneyOk)
		end

		-- Duel 1, Track 1 driven to the finish: A at stat 0 (BASE_SPEED), B at HALF_STAT: B reaches the finish first
		local track1 = trackOf(1)
		local d1 = begin("duel_race", A, B, 1)
		if d1.Ready then
			local countdowns = msgs(d1.From, A, "Countdown")
			local cd = countdowns[1] or {}
			local cdB = msgs(d1.From, B, "Countdown")[1] or {}
			flag(
				"duel_race_countdown_message",
				#countdowns == 1 and cd.Track == 1 and cdB.Track == 1 and type(cd.ServerStart) == "number",
				tostring(cd.Track),
				1
			)
			-- held: both cars at the picked track's start, anchored, the avatar seated, no run before the release
			local function held()
				local n = 0
				for _, side in { { A, d1.CarA }, { B, d1.CarB } } do
					local f, car = side[1], side[2]
					local chassis = car and car.PrimaryPart
					if
						chassis
						and chassis.Anchored
						and hdist(chassis.Position, wps[track1.StartIndex]) <= START_RADIUS
						and CarService.GetRun(f.Player) == nil
						and CarService.IsAutoRacing(f.Player) == true
						and f.Humanoid.SeatPart ~= nil
						and f.Humanoid.SeatPart == car:FindFirstChild("DriverSeat")
					then
						n += 1
					end
				end
				return n
			end
			flag("duel_race_cars_held_at_track_start", held() == 2 and d1.CarA ~= d1.CarB, held(), 2)
			now = d1.T0 + NUMBERS.COUNTDOWN - 0.1
			service.Tick()
			frames(0.1)
			flag(
				"duel_race_not_released_before_countdown",
				held() == 2 and both(A, B, "Countdown"),
				tostring(state(A)),
				"Countdown"
			)
			local stat0A, stat0B = PlayerData.SpeedStat(A.Player), PlayerData.SpeedStat(B.Player)
			if release("duel_race", d1) then
				local runA, runB = d1.RunA, d1.RunB
				local events = A.Player:GetAttribute("RaceEvent") == "Racing"
					and B.Player:GetAttribute("RaceEvent") == "Racing"
				flag("duel_race_race_event_racing", events)
				local strays = 0
				for _, car in { d1.CarA, d1.CarB } do
					for _, part in car:GetDescendants() do
						if part:IsA("BasePart") and part.CollisionGroup ~= "Cars" then
							strays += 1
						end
					end
				end
				flag("duel_race_cars_in_cars_group", strays == 0, strays, 0)
				flag(
					"duel_race_runs_have_no_npc",
					runA.RaceTrack == nil and runB.RaceTrack == nil and runA.Car == d1.CarA and runB.Car == d1.CarB
				)
				local length = 0
				for i = track1.StartIndex + 1, track1.FinishIndex do
					length += (wps[i] - wps[i - 1]).Magnitude
				end
				local cap = length / (0.5 * M.RaceConfig.SpeedFor(HALF)) + 10
				local sides = {
					{ Fake = A, Run = runA, Car = d1.CarA, MinUp = 1, Dev = 0, Unbanked = 0 },
					{ Fake = B, Run = runB, Car = d1.CarB, MinUp = 1, Dev = 0, Unbanked = 0 },
				}
				local elapsed = frames(cap, function(t)
					for _, s in sides do
						local chassis = s.Car.PrimaryPart
						if chassis and chassis.Parent and s.Car.Parent and not s.Run.Finished then
							s.MinUp = math.min(s.MinUp, chassis.CFrame.UpVector.Y)
							if t > GRACE then
								local i = s.Run.Driver.Index
								s.Dev = math.max(s.Dev, polyDist(wps, chassis.Position, i - 3, i + 3))
							end
						end
						s.Unbanked = math.max(
							s.Unbanked,
							tonumber(s.Run.Unbanked) or 1,
							tonumber(s.Fake.Player:GetAttribute("Unbanked")) or 1
						)
					end
					return state(A) ~= "Racing"
				end)
				r.metrics.duel_race_seconds = round(elapsed)
				flag("duel_race_decided_in_time", state(A) ~= "Racing", round(elapsed), round(cap))
				finish("duel_race", d1, "Lose", "Win")
				flag(
					"duel_race_winner_reached_finish_index",
					runB.Finished == true and runB.Driver.Index >= track1.FinishIndex,
					runB.Driver.Index,
					track1.FinishIndex
				)
				flag(
					"duel_race_loser_had_not_finished",
					runA.Finished ~= true and runA.Driver.Index < track1.FinishIndex,
					runA.Driver.Index,
					track1.FinishIndex
				)
				local resA, resB = d1.ResultA[1] or {}, d1.ResultB[1] or {}
				flag(
					"duel_race_result_time_is_winner_run_time",
					type(resB.Time) == "number" and resB.Time > 0 and math.abs(resB.Time - elapsed) <= TIME_SLACK,
					type(resB.Time) == "number" and round(resB.Time) or -1,
					round(elapsed)
				)
				flag(
					"duel_race_loser_gets_winner_time",
					type(resB.Time) == "number" and resA.OpponentTime == resB.Time,
					tonumber(resA.OpponentTime) or -1,
					tonumber(resB.Time) or -1
				)
				-- no stake: the winner drove past Track 1's pad and nothing was paid or banked
				local paid = runA.Payouts + runA.PaidTotal + runB.Payouts + runB.PaidTotal
				flag("duel_race_pays_no_pad", paid == 0, paid, 0)
				local banked = math.max(sides[1].Unbanked, sides[2].Unbanked)
				flag("duel_race_unbanked_stays_zero", banked == 0, banked, 0)
				-- Speed gain continues as in any race
				local gainA = PlayerData.SpeedStat(A.Player) - stat0A
				local gainB = PlayerData.SpeedStat(B.Player) - stat0B
				flag("duel_race_both_gain_speed", gainA > 0 and gainB > 0, round(math.min(gainA, gainB)), 0)
				-- stability rules on both cars
				for _, s in sides do
					local tag = s.Fake == A and "a" or "b"
					local worst = math.min(s.MinUp, tonumber(s.Run.MinUpY) or -1)
					flag("duel_race_" .. tag .. "_never_tilted", worst >= strict, round(worst), strict)
					flag(
						"duel_race_" .. tag .. "_no_flip_recoveries",
						s.Run.FlipRecoveries == 0,
						tonumber(s.Run.FlipRecoveries) or -1,
						0
					)
					flag("duel_race_" .. tag .. "_sticks_to_path", s.Dev <= maxDev, round(s.Dev), maxDev)
				end
			end
		end

		-- Duel 2, forfeit by Stop Auto during the race: the other player wins
		local d2 = begin("duel_forfeit_stop", A, B, 1)
		if d2.Ready and release("duel_forfeit_stop", d2) then
			frames(1)
			flag("duel_forfeit_stop_still_racing_before_stop", both(A, B, "Racing"), tostring(state(A)), "Racing")
			stop(B)
			finish("duel_forfeit_stop", d2, "Win", "Lose")
		end

		-- Duel 3, Track 3, nobody finishes within RACE_TIMEOUT: a draw
		local track3 = trackOf(3)
		local d3 = begin("duel_timeout", A, B, 3)
		if d3.Ready then
			local near = 0
			for _, car in { d3.CarA, d3.CarB } do
				local chassis = car and car.PrimaryPart
				if chassis and chassis.Anchored and hdist(chassis.Position, wps[track3.StartIndex]) <= START_RADIUS then
					near += 1
				end
			end
			flag("duel_timeout_cars_held_at_picked_track_start", near == 2, near, 2)
			if release("duel_timeout", d3) then
				frames(0.3)
				local onTrack = 0
				for _, run in { d3.RunA, d3.RunB } do
					local i = run.Driver.Index
					if i >= track3.StartIndex and i < track3.FinishIndex and not run.Finished then
						onTrack += 1
					end
				end
				flag("duel_timeout_runs_drive_the_picked_track", onTrack == 2, onTrack, 2)
				now = d3.T0 + NUMBERS.COUNTDOWN + NUMBERS.RACE_TIMEOUT - 10
				service.Tick()
				frames(0.1)
				flag("duel_timeout_not_before_180s", both(A, B, "Racing"), tostring(state(A)), "Racing")
				now = d3.T0 + NUMBERS.COUNTDOWN + NUMBERS.RACE_TIMEOUT + 1
				finish("duel_timeout", d3, "Draw", "Draw")
			end
		end

		-- Duel 4, both cars reach the finish in the same step (forced, as a fixed outcome): the lower finish time
		-- wins, equal times are a draw
		local d4 = begin("duel_same_step", A, B, 1)
		if d4.Ready and release("duel_same_step", d4) then
			frames(0.1)
			d4.RunA.Driver.Index = track1.FinishIndex
			d4.RunB.Driver.Index = track1.FinishIndex
			settle(END_WAIT, function()
				return both(A, B, "None")
			end)
			local resA = msgs(d4.From, A, "Result")[1] or {}
			local resB = msgs(d4.From, B, "Result")[1] or {}
			local timesOk = type(resA.Time) == "number" and type(resB.Time) == "number"
			flag(
				"duel_same_step_both_times_reported",
				timesOk and resA.OpponentTime == resB.Time and resB.OpponentTime == resA.Time,
				tostring(resA.Time) .. "/" .. tostring(resB.Time)
			)
			local wantA, wantB = "Draw", "Draw"
			if timesOk and resA.Time < resB.Time then
				wantA, wantB = "Win", "Lose"
			elseif timesOk and resB.Time < resA.Time then
				wantA, wantB = "Lose", "Win"
			end
			r.metrics.duel_same_step_outcome = wantA .. "/" .. wantB
			finish("duel_same_step", d4, wantA, wantB)
		end

		-- Duel 5, forfeit by leaving during the countdown: the other player wins
		local L3 = newFake("LeftCountdown", 0, 0)
		local d5 = begin("duel_forfeit_leave", L3, B, 1)
		if d5.Ready then
			service.PlayerLeft(L3.Player)
			finish("duel_forfeit_leave", d5, "Lose", "Win", L3)
		end
		discard(L3)

		-- Duel 6, forfeit by death during the race: the other player wins
		local L4 = newFake("Died", 0, 0)
		local d6 = begin("duel_forfeit_death", A, L4, 1)
		if d6.Ready and release("duel_forfeit_death", d6) then
			frames(0.5)
			L4.Humanoid.Health = 0
			finish("duel_forfeit_death", d6, "Win", "Lose", L4)
		end
		discard(L4)

		-- No stake, over everything above
		flag("duel_money_unchanged_after_all_duels", sameWallet(A, walletA) and sameWallet(B, walletB))

		-- DuelWins is saved and loaded (B was loaded with 4 and won since)
		local wonB = wins(B)
		PlayerData.SetStore(saveStore)
		local saved = PlayerData.Save(B.Player, UID_SAVED)
		local record = saveStore.data[PlayerData.KeyFor(UID_SAVED)]
		local savedWins = type(record) == "table" and record.DuelWins or nil
		flag("duel_wins_saved", saved == true and wonB > 4 and savedWins == wonB, tonumber(savedWins) or -1, wonB)
		flag("duel_saved_money_unchanged", type(record) == "table" and record.Money == 77)
		local again = Instance.new("Folder")
		again.Name = "CarTestDuelReload"
		again.Parent = Workspace
		table.insert(fakes, { Player = again, Character = Instance.new("Model") })
		local reloaded = PlayerData.Load(again, UID_SAVED)
		PlayerData.SetStore(nil)
		flag(
			"duel_wins_loaded_again",
			reloaded == true and wonB > 4 and again:GetAttribute("DuelWins") == wonB,
			tonumber(again:GetAttribute("DuelWins")) or -1,
			wonB
		)
	end)

	-- Restore everything, also after a failure
	for _, f in fakes do
		pcall(service.PlayerLeft, f.Player)
	end
	pcall(service.Tick)
	pcall(service.SetClock, nil)
	pcall(service.SetNotify, nil)
	pcall(PlayerData.SetStore, nil)
	for _, f in fakes do
		pcall(CarService.SetAutoRace, f.Player, false)
		local okCar, car = pcall(CarService.GetCar, f.Player)
		if okCar and car then
			car:Destroy()
		end
		f.Character:Destroy()
		f.Player:Destroy()
	end
	releaseSpawn()
	flag("duel_no_runtime_error", ok, nil, ok and 1 or tostring(err))
	return r
end

return Tests
