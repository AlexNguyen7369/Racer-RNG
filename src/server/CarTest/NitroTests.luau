--!nonstrict
-- BRIEF (Vic2CS, 2026-11-19, approved on branch feature/vic2cs/dev-changes; design doc "Timed nitro boost",
-- docs/NITRO_SPEC.md): "While auto racing against an NPC, a bar with a sweeping needle shows above the Speed readout.
-- Pressing while the needle is in the green zone gives a boost: cruise speed x1.4 for 2 seconds, x1.7 in the gold
-- centre. A press outside the green locks the bar for 6 seconds, as long as the recharge after a boost (Vic2CS
-- 2026-11-20, was 2 seconds, so spamming no longer pays); after a boost the bar recharges for 6 seconds. The gold zone
-- is a little wider (placeholder 0.11 of the half-bar, was 0.08), and after each boost the bar shows the time it saved.
-- All numbers are placeholders. A boost gets the car to the finish sooner, so a well-timed boost can win a race
-- against an NPC that is slightly faster. It never changes the Speed stat, its gain, Money or payouts. Not in duels.
-- The server grades every press from the needle position at the press time."
--
-- Every number is read live from Shared/NitroConfig (placeholders), except the brief's gold zone width (0.11). Parts:
--   1. NitroConfig maths: NeedleAt is a constant-rate triangle wave that starts at the left edge (-1), Grade zones,
--      MultiFor, MISS_COOLDOWN = RECHARGE, SavedSeconds(multi, s) = (multi - 1) x s.
--   2. RaceService run:Nitro(multi, seconds) on real runs (fake Folder players, synthetic straight routes on their own
--      floors, like the npc / race_progress_map scenarios build them): the rail holds TargetSpeed x multi for `seconds`
--      of run time, then cruise again; bad arguments, a run without an NPC, a duel and a finished / stopped run refuse
--      it; a boosted car finishes sooner by DURATION x (multi - 1), and turns a loss against an NPC slightly faster
--      than cruise speed (options.NpcSpeeds) into a win; Speed gain and the NPC are unchanged; a loss ends the boost.
--   3. NitroService.Press grading: CarService.IsAutoRacing / GetRun are wrapped for ONE fake player only (every other
--      player still gets the real answer) and restored afterwards. A decided run (Finished, or Lost while the loser
--      screen shows) ignores presses. NitroSaved / NitroSavedAt: set when a boost ends, the nominal saving for a full
--      boost, the smaller real one when a reset (JumpToTrack) cuts it short.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent

local Tests = {}

local ORIGIN = Vector3.new(0, 3000, 46000) -- far from the play area and every other scenario origin
local LANE_GAP = 80 -- studs between the parallel test routes
local SPACING = 2 -- studs between route waypoints
local STAT = 0 -- Speed stat of every test racer: a beginner at RaceConfig.BASE_SPEED
local BOOST_AT = 1 -- s after the run starts that the test boost begins
local WINDOW_EDGE = 0.25 -- s left out at both ends of a speed-measuring window
local SPEED_TOLERANCE = 0.05 -- relative: mean rail speed over a window vs the expected speed
local LEFT_EDGE = 0.15 -- s before / after the boost's end at which NitroLeft is read
local TIME_SAVED_TOLERANCE = 0.15 -- relative (at least 0.1 s): time saved by a boost vs DURATION x (multi - 1)
local PERFECT_ZONE_BRIEF = 0.11 -- brief Vic2CS 2026-11-20: the gold zone's half-width (was 0.08)
local CUT_AFTER = 0.5 -- s of a real boost driven before JumpToTrack cuts it short
local SAVED_TOLERANCE = 0.1 -- s of boost time (one or two frames plus scheduling) for the cut boost's saving
local LOSE_SCREEN = 1 -- s: LoseScreenSeconds of the loss run (RaceService test hook)
local SLOW_NPC = 0.001 -- studs/s: an NPC every test racer beats
local FAST_NPC = 1e12 -- studs/s: an NPC no test racer beats

local function finite(x)
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

local function round(x)
	if not finite(x) then
		return -1
	end
	return math.round(x * 10000) / 10000
end

local function check(list, name, value, limit, ok)
	if type(value) == "boolean" then
		value = value and 1 or 0
	end
	table.insert(list, { name = name, value = round(value), limit = limit, pass = ok == true })
end

local function result(name, checks, metrics)
	local pass = true
	for _, c in checks do
		pass = pass and c.pass
	end
	return { scenario = name, pass = pass, checks = checks, metrics = metrics }
end

local function load(parent, name)
	local source = parent:FindFirstChild(name)
	local ok, value = pcall(function()
		return source and require(source)
	end)
	return ok and type(value) == "table" and value or nil
end

local function near(a, b, tolerance)
	return finite(a) and finite(b) and math.abs(a - b) <= tolerance
end

-- Part 1: pure maths.
local function configChecks(checks, NitroConfig, metrics)
	local P = NitroConfig.PERIOD
	local PZ, GZ = NitroConfig.PERFECT_ZONE, NitroConfig.GOOD_ZONE
	local PM, GM = NitroConfig.PERFECT_MULTI, NitroConfig.GOOD_MULTI
	local positive = true
	for _, key in { "PERIOD", "DURATION", "RECHARGE", "MISS_COOLDOWN", "START_DELAY", "LATENCY_WINDOW" } do
		local v = NitroConfig[key]
		positive = positive and finite(v) and v > 0
	end
	check(checks, "nitro_config_times_positive", positive, 1, positive)
	local zonesOk = finite(PZ) and finite(GZ) and PZ > 0 and PZ < GZ and GZ < 1
	check(checks, "nitro_config_zones_ordered", zonesOk, 1, zonesOk) -- 0 < Perfect < Good < 1 (bar half-width)
	local multisOk = finite(PM) and finite(GM) and GM > 1 and PM > GM
	check(checks, "nitro_config_multis_ordered", multisOk, 1, multisOk) -- Perfect boosts more than Good, both > 1
	local api = type(NitroConfig.NeedleAt) == "function"
		and type(NitroConfig.Grade) == "function"
		and type(NitroConfig.MultiFor) == "function"
		and type(NitroConfig.NewTarget) == "function"
		and type(NitroConfig.SavedSeconds) == "function"
	check(checks, "nitro_config_api", api, 1, api)
	if not (api and positive and zonesOk and multisOk) then
		return false
	end

	-- NeedleAt: starts at the left edge, sweeps left -> right -> left once per PERIOD at a constant rate
	local readyAt = 1000.25
	local function at(phase)
		return NitroConfig.NeedleAt(readyAt + phase * P, readyAt)
	end
	check(checks, "nitro_needle_starts_left", at(0), -1, near(at(0), -1, 1e-9))
	local keyOk = near(at(0.25), 0, 1e-9) and near(at(0.5), 1, 1e-9) and near(at(0.75), 0, 1e-9)
	check(checks, "nitro_needle_quarter_points", at(0.5), 1, keyOk) -- centre, right edge, centre
	check(checks, "nitro_needle_period_wraps_left", at(1), -1, near(at(1), -1, 1e-9) and near(at(3), -1, 1e-9))
	-- constant rate: rising 4 / PERIOD bar units per second on the way out, falling as fast on the way back
	local worstLinear, inRange = 0, true
	for k = 0, 200 do
		local phase = k / 200
		local want = phase <= 0.5 and 4 * phase - 1 or 3 - 4 * phase
		local got = at(phase)
		worstLinear = math.max(worstLinear, finite(got) and math.abs(got - want) or math.huge)
		inRange = inRange and finite(got) and got >= -1 - 1e-9 and got <= 1 + 1e-9
	end
	check(checks, "nitro_needle_triangle_constant_rate", worstLinear, 1e-9, worstLinear <= 1e-9)
	check(checks, "nitro_needle_in_bar", inRange, 1, inRange)
	local periodic = near(at(0.3 + 5), at(0.3), 1e-6) and near(at(0.8 + 2), at(0.8), 1e-6)
	check(checks, "nitro_needle_periodic", periodic, 1, periodic)

	-- Grade: Perfect within PERFECT_ZONE of the centre, Good within GOOD_ZONE, Miss elsewhere (symmetric)
	local gradeCases = {
		{ 0, "Perfect" },
		{ PZ * 0.99, "Perfect" },
		{ -PZ * 0.99, "Perfect" },
		{ PZ + (GZ - PZ) * 0.01, "Good" },
		{ -(PZ + (GZ - PZ) * 0.01), "Good" },
		{ (PZ + GZ) / 2, "Good" },
		{ GZ * 0.99, "Good" },
		{ -GZ * 0.99, "Good" },
		{ GZ + (1 - GZ) * 0.01, "Miss" },
		{ -(GZ + (1 - GZ) * 0.01), "Miss" },
		{ 1, "Miss" },
		{ -1, "Miss" },
	}
	local gradeBad = 0
	for _, c in gradeCases do
		local ok, g = pcall(NitroConfig.Grade, c[1])
		if not ok or g ~= c[2] then
			gradeBad += 1
		end
	end
	check(checks, "nitro_grade_zones", gradeBad, 0, gradeBad == 0)

	-- Target (Vic2CS 2026-11-19, NITRO_SPEC "Target"): TARGET_RANGE = 1 - GOOD_ZONE, so the whole green zone fits on
	-- the bar; TARGET_MIN_MOVE > 0 and no bigger than TARGET_RANGE (else no far-enough target exists from the centre).
	local TR, TM = NitroConfig.TARGET_RANGE, NitroConfig.TARGET_MIN_MOVE
	local targetCfgOk = finite(TR) and finite(TM) and math.abs(TR - (1 - GZ)) <= 1e-12 and TM > 0 and TM <= TR
	check(checks, "nitro_target_config", targetCfgOk, 1, targetCfgOk)
	if targetCfgOk then
		-- Grade(position, target): the zones are measured from the target, on both sides of it (nil target = 0: above)
		local offsets = {
			{ 0, "Perfect" },
			{ PZ * 0.99, "Perfect" },
			{ -PZ * 0.99, "Perfect" },
			{ PZ + (GZ - PZ) * 0.01, "Good" },
			{ -(PZ + (GZ - PZ) * 0.01), "Good" },
			{ (PZ + GZ) / 2, "Good" },
			{ -(PZ + GZ) / 2, "Good" },
			{ GZ * 0.99, "Good" },
			{ -GZ * 0.99, "Good" },
			{ GZ + (1 - GZ) * 0.01, "Miss" },
			{ -(GZ + (1 - GZ) * 0.01), "Miss" },
		}
		local targetGradeBad, targetGradeCases = 0, 0
		for _, target in { -TR, -TR / 2, TR / 3, TR } do
			for _, c in offsets do
				local position = target + c[1]
				if position >= -1 and position <= 1 then -- only needle positions on the bar
					targetGradeCases += 1
					local ok, g = pcall(NitroConfig.Grade, position, target)
					if not ok or g ~= c[2] then
						targetGradeBad += 1
					end
				end
			end
			-- the bar centre is not special: far from the target it is a Miss
			if math.abs(target) > GZ then
				targetGradeCases += 1
				local ok, g = pcall(NitroConfig.Grade, 0, target)
				if not ok or g ~= "Miss" then
					targetGradeBad += 1
				end
			end
		end
		metrics.target_grade_cases = targetGradeCases
		check(checks, "nitro_grade_from_target", targetGradeBad, 0, targetGradeBad == 0 and targetGradeCases >= 30)

		-- NewTarget(rng, previous): always inside [-TARGET_RANGE, TARGET_RANGE] and at least TARGET_MIN_MOVE from
		-- `previous`. Seeded Random (deterministic): 2000 chained draws, 300 draws from each fixed previous target (both
		-- edges, the centre and spots between), 200 first targets (previous nil); and a stub rng whose every draw is the
		-- previous target itself (the too-close fallback path).
		local EPS = 1e-9
		local outOfRange, tooClose, draws, errors = 0, 0, 0, 0
		local lo, hi = math.huge, -math.huge
		local function judge(previous, t)
			draws += 1
			if not finite(t) or t < -TR - EPS or t > TR + EPS then
				outOfRange += 1
			end
			if type(previous) == "number" and (not finite(t) or math.abs(t - previous) < TM - EPS) then
				tooClose += 1
			end
		end
		local rng = Random.new(20261119)
		local previous = nil
		for _ = 1, 2000 do
			local ok, t = pcall(NitroConfig.NewTarget, rng, previous)
			if ok then
				judge(previous, t)
				if finite(t) then
					lo, hi = math.min(lo, t), math.max(hi, t)
				end
				previous = finite(t) and t or nil
			else
				errors += 1
			end
		end
		for _, fixed in { -TR, -TR + TM / 2, -TM / 2, 0, TM / 2, TR - TM / 2, TR } do
			for _ = 1, 300 do
				local ok, t = pcall(NitroConfig.NewTarget, rng, fixed)
				if ok then
					judge(fixed, t)
				else
					errors += 1
				end
			end
		end
		for _ = 1, 200 do
			local ok, t = pcall(NitroConfig.NewTarget, rng, nil)
			if ok then
				judge(nil, t)
			else
				errors += 1
			end
		end
		metrics.new_target_draws = draws
		check(checks, "nitro_new_target_in_range", outOfRange + errors, 0, outOfRange == 0 and errors == 0)
		check(checks, "nitro_new_target_moves_min", tooClose, 0, tooClose == 0 and draws >= 4300)
		-- a new random spot: the chained draws reach both outer thirds of the range
		local varies = lo < -TR / 3 and hi > TR / 3
		check(checks, "nitro_new_target_varies", varies, 1, varies)
		local fallbackBad = 0
		for _, fixed in { -TR, -TR / 2, -TM / 2, 0, TM / 2, TR / 2, TR } do
			local stub = {
				NextNumber = function(_, a, b)
					return math.clamp(fixed, math.min(a, b), math.max(a, b))
				end,
			}
			local ok, t = pcall(NitroConfig.NewTarget, stub, fixed)
			if not (ok and finite(t) and t >= -TR - EPS and t <= TR + EPS and math.abs(t - fixed) >= TM - EPS) then
				fallbackBad += 1
			end
		end
		check(checks, "nitro_new_target_fallback", fallbackBad, 0, fallbackBad == 0)
	end

	-- MultiFor: Perfect / Good multis, 1 (no boost) for a miss and anything else
	local multiOk = NitroConfig.MultiFor("Perfect") == PM
		and NitroConfig.MultiFor("Good") == GM
		and NitroConfig.MultiFor("Miss") == 1
	check(checks, "nitro_multi_for_grades", multiOk, 1, multiOk)
	local junkOk = true
	for _, junk in { "perfect", "", 5, true } do
		local ok, m = pcall(NitroConfig.MultiFor, junk)
		junkOk = junkOk and ok and m == 1
	end
	local okNil, mNil = pcall(NitroConfig.MultiFor, nil)
	junkOk = junkOk and okNil and mNil == 1
	check(checks, "nitro_multi_for_unknown_is_1", junkOk, 1, junkOk)

	-- Miss rule (Vic2CS 2026-11-20): a miss locks the bar exactly as long as the recharge after a boost
	local missOk = NitroConfig.MISS_COOLDOWN == NitroConfig.RECHARGE
	check(checks, "nitro_miss_cooldown_is_recharge", NitroConfig.MISS_COOLDOWN, NitroConfig.RECHARGE, missOk)
	-- Gold zone (brief Vic2CS 2026-11-20): half-width 0.11 of the half-bar
	check(checks, "nitro_perfect_zone_brief", PZ, PERFECT_ZONE_BRIEF, near(PZ, PERFECT_ZONE_BRIEF, 1e-9))

	-- SavedSeconds(multi, seconds): a boost covers (multi - 1) x seconds of extra cruise distance, so it saves that
	-- much track time at constant cruise speed; 0 for anything that is not a boost
	local D = NitroConfig.DURATION
	local savedGood, savedPerfect = NitroConfig.SavedSeconds(GM, D), NitroConfig.SavedSeconds(PM, D)
	metrics.saved_good = round(savedGood)
	metrics.saved_perfect = round(savedPerfect)
	local savedOk = near(savedGood, (GM - 1) * D, 1e-9)
		and near(savedPerfect, (PM - 1) * D, 1e-9)
		and near(NitroConfig.SavedSeconds(PM, D / 4), (PM - 1) * D / 4, 1e-9)
		and near(NitroConfig.SavedSeconds(2.5, 3), 4.5, 1e-9)
	check(checks, "nitro_saved_seconds_maths", savedPerfect, (PM - 1) * D, savedOk)
	local savedJunkBad = 0
	for _, args in
		{ { 1, D }, { 0.5, D }, { PM, 0 }, { PM, -1 }, { 0 / 0, D }, { PM, 0 / 0 }, { math.huge, D }, { "1.7", D } }
	do
		local ok, v = pcall(NitroConfig.SavedSeconds, args[1], args[2])
		if not (ok and v == 0) then
			savedJunkBad += 1
		end
	end
	local okNilS, vNilS = pcall(NitroConfig.SavedSeconds, nil, nil)
	if not (okNilS and vNilS == 0) then
		savedJunkBad += 1
	end
	check(checks, "nitro_saved_seconds_no_boost_is_0", savedJunkBad, 0, savedJunkBad == 0)
	return true
end

-- A straight route of `length` studs along -Z from `base`, on its own anchored floor, with ONE track whose NPC lane
-- is the same line (so the NPC's time on a straight is exactly lane length / NPC speed).
local function makeRoute(ctx, base, length)
	local dir = Vector3.new(0, 0, -1)
	local count = math.max(2, math.ceil(length / SPACING))
	local points, curvature = {}, {}
	for i = 0, count do
		table.insert(points, base + dir * (i * length / count))
		table.insert(curvature, 0)
	end
	local floor = Instance.new("Part")
	floor.Name = "CarTestNitroFloor"
	floor.Anchored = true
	floor.Size = Vector3.new(40, 2, length + 80)
	floor.CFrame = CFrame.new(base + dir * (length / 2) - Vector3.new(0, 1, 0))
	floor.Material = Enum.Material.Concrete
	floor.Parent = Workspace
	table.insert(ctx.cleanup, floor)
	local npcPath = { Waypoints = table.clone(points), Curvature = table.clone(curvature), Length = length }
	local config = ctx.NpcConfig.For(1)
	return {
		Path = { WorldWaypoints = points, Curvature = curvature, Width = 40, Closed = false },
		Pads = {},
		Tracks = {
			{
				Number = 1,
				StartIndex = 1,
				FinishIndex = #points,
				Npc = { Config = config, Path = npcPath, Profile = ctx.NpcRacer.Profile(npcPath, config.Speed) },
			},
		},
		Dir = dir,
		Base = base,
		Length = length,
	}
end

-- One test racer: a real car and a fake Folder player at STAT, a RaceService run with `options`, every race event.
local function newRacer(ctx, route, tag, options)
	local car = ctx.CarFactory.build(ctx.CarConfig)
	car.Name = "CarTestNitroCar_" .. tag
	car:PivotTo(CFrame.new(route.Base + Vector3.new(0, ctx.CarConfig.RestHeight + 0.5, 0)))
	car.Parent = Workspace
	table.insert(ctx.cleanup, car)
	local player = Instance.new("Folder")
	player.Name = "CarTestNitroPlayer_" .. tag
	player.Parent = Workspace
	table.insert(ctx.cleanup, player)
	ctx.MoneyService.Setup(player)
	ctx.PlayerData.Setup(player)
	player.BaseSpeed.Value = STAT
	local r = { Tag = tag, Car = car, Player = player, Events = {}, Route = route, Windows = {} }
	options = options or {}
	options.OnRaceEvent = function(ev)
		if type(ev) == "table" then
			table.insert(r.Events, ev)
		end
	end
	r.Run = ctx.RaceService.NewRun(car, route, player, options)
	table.insert(ctx.runs, r.Run)
	return r
end

-- Stops a racer's run and removes its car (a parked car left on a shared floor could be hit by the next one).
local function done(r)
	pcall(function()
		r.Run:Destroy()
	end)
	r.Car:Destroy()
end

local function along(r)
	local chassis = r.Car.PrimaryPart
	return chassis and (chassis.Position - r.Route.Base):Dot(r.Route.Dir) or 0
end

local function firstResult(r)
	return type(r.Run.Results) == "table" and r.Run.Results[1] or nil
end

-- A speed-measuring window [from, to] (test seconds); its mean speed is the distance along the route / the time.
local function addWindow(r, name, from, to)
	r.Windows[name] = { From = from, To = to }
end

local function sampleWindows(r, t)
	for _, w in r.Windows do
		if w.S0 == nil and t >= w.From then
			w.S0, w.T0 = along(r), t
		elseif w.S0 ~= nil and w.S1 == nil and t >= w.To then
			w.S1, w.T1 = along(r), t
			w.Target = r.Run.TargetSpeed
		end
	end
end

local function windowSpeed(r, name)
	local w = r.Windows[name]
	if not (w and w.S1 and w.T1 > w.T0) then
		return nil, nil
	end
	return (w.S1 - w.S0) / (w.T1 - w.T0), w.Target
end

local function step(seconds, each)
	local t = 0
	while t < seconds do
		local dt = RunService.Heartbeat:Wait()
		t += dt
		if each(t, dt) == "stop" then
			break
		end
	end
	return t
end

-- Part 2: run:Nitro on real runs.
local function runChecks(ctx, checks, metrics)
	local NitroConfig, RaceConfig = ctx.NitroConfig, ctx.RaceConfig
	local GOOD, DUR = NitroConfig.GOOD_MULTI, NitroConfig.DURATION
	local cruise0 = RaceConfig.SpeedFor(STAT)
	-- long enough that the whole boost and a second of cruise after it happen before the finish
	local length = cruise0 * (BOOST_AT + DUR * math.max(GOOD, NitroConfig.PERFECT_MULTI) + 4) + 10
	metrics.route_length = round(length)
	local lane = 0
	local function nextRoute()
		lane += 1
		return makeRoute(ctx, ORIGIN + Vector3.new(lane * LANE_GAP, 0, 0), length)
	end
	local cap = 2 * length / cruise0 + 10

	-- (a) The rail: cruise, then TargetSpeed x GOOD for DURATION, then cruise again. A twin run without a boost at the
	-- same stat, in the same frames, measures the unboosted time and the Speed gain.
	local cal = newRacer(ctx, nextRoute(), "Cruise", { Npc = true, NpcSpeeds = { [1] = SLOW_NPC } })
	local boost = newRacer(ctx, nextRoute(), "Boost", { Npc = true, NpcSpeeds = { [1] = SLOW_NPC } })
	local apiOk = type(boost.Run.Nitro) == "function" and boost.Run.NitroLeft == 0 and boost.Run.NitroMulti == 1
	check(checks, "nitro_run_api", apiOk, 1, apiOk) -- run:Nitro exists, NitroLeft 0 and NitroMulti 1 at the start
	if not apiOk then
		return
	end
	addWindow(boost, "before", WINDOW_EDGE, BOOST_AT)
	local tb, accepted, leftAtStart, multiAtStart = nil, nil, nil, nil
	local leftDuring, leftAfter, gainCal, gainBoost, statCal, statBoost = nil, nil, nil, nil, nil, nil
	step(cap, function(t)
		sampleWindows(boost, t)
		if tb == nil and t >= BOOST_AT then
			tb = t
			accepted = boost.Run:Nitro(GOOD, DUR)
			leftAtStart, multiAtStart = boost.Run.NitroLeft, boost.Run.NitroMulti
			addWindow(boost, "boost", tb + WINDOW_EDGE, tb + DUR - WINDOW_EDGE)
			addWindow(boost, "after", tb + DUR + WINDOW_EDGE, tb + DUR + WINDOW_EDGE + 1)
		end
		if tb and leftDuring == nil and t >= tb + DUR - LEFT_EDGE then
			leftDuring = boost.Run.NitroLeft
		end
		if tb and leftAfter == nil and t >= tb + DUR + LEFT_EDGE then
			leftAfter = boost.Run.NitroLeft
		end
		if tb and gainBoost == nil and t >= tb + DUR + 0.5 then
			gainCal, gainBoost = cal.Run.Gained, boost.Run.Gained
			statCal, statBoost = cal.Player.BaseSpeed.Value, boost.Player.BaseSpeed.Value
		end
		if firstResult(cal) and firstResult(boost) then
			return "stop"
		end
	end)
	check(checks, "nitro_accepts_valid_boost", accepted, 1, accepted == true)
	local startOk = leftAtStart == DUR and multiAtStart == GOOD
	check(checks, "nitro_boost_state_set", leftAtStart or -1, DUR, startOk) -- NitroLeft = seconds, NitroMulti = multi
	local vBefore, tBefore = windowSpeed(boost, "before")
	check(
		checks,
		"nitro_cruise_before_boost",
		vBefore or -1,
		tBefore or -1,
		vBefore ~= nil and math.abs(vBefore - tBefore) <= SPEED_TOLERANCE * tBefore
	)
	local vBoost, tBoost = windowSpeed(boost, "boost")
	local wantBoost = tBoost and tBoost * GOOD or -1
	check(
		checks,
		"nitro_rail_speed_is_target_x_multi",
		vBoost or -1,
		wantBoost,
		vBoost ~= nil and math.abs(vBoost - wantBoost) <= SPEED_TOLERANCE * wantBoost
	)
	check(
		checks,
		"nitro_left_counts_down_in_run_time",
		leftDuring or -1,
		0,
		finite(leftDuring) and leftDuring > 0 and leftDuring <= DUR and leftAfter == 0
	)
	metrics.nitro_left_after = leftAfter
	local vAfter, tAfter = windowSpeed(boost, "after")
	check(
		checks,
		"nitro_back_to_cruise_after_seconds",
		vAfter or -1,
		tAfter or -1,
		vAfter ~= nil and math.abs(vAfter - tAfter) <= SPEED_TOLERANCE * tAfter
	)
	-- Speed gain is flat per second: a boost never changes it (same frames, same stat, same gain)
	local gainOk = finite(gainCal)
		and finite(gainBoost)
		and gainCal > 0
		and math.abs(gainBoost - gainCal) <= 1e-9 * math.max(1, gainCal)
		and statBoost == statCal
	check(checks, "nitro_speed_gain_unchanged", gainBoost or -1, gainCal or -1, gainOk)
	local resCal, resBoost = firstResult(cal), firstResult(boost)
	local bothWon = resCal ~= nil and resBoost ~= nil and resCal.Result == "Win" and resBoost.Result == "Win"
	check(checks, "nitro_twin_runs_finished", bothWon, 1, bothWon)
	if not bothWon then
		return
	end
	local T0, T1 = resCal.PlayerTime, resBoost.PlayerTime
	metrics.time_unboosted = round(T0)
	metrics.time_boosted = round(T1)
	check(checks, "nitro_boosted_finishes_sooner", T1, T0, finite(T0) and finite(T1) and T1 < T0)
	local wantSaved = DUR * (GOOD - 1)
	local saved = T0 - T1
	check(
		checks,
		"nitro_time_saved_is_duration_x_extra",
		saved,
		wantSaved,
		finite(saved) and math.abs(saved - wantSaved) <= math.max(0.1, TIME_SAVED_TOLERANCE * wantSaved)
	)
	-- the finished run refuses a boost (past the last finish the car rolls out on its physics)
	local finishedRefused = cal.Run.Finished == true and cal.Run:Nitro(GOOD, DUR) == false
	check(checks, "nitro_refused_after_finish", finishedRefused, 1, finishedRefused)
	done(cal)
	done(boost)

	-- (b) A loss into a win: an NPC slightly faster than cruise (its time halfway between the boosted and unboosted
	-- times) beats the unboosted car and loses to the boosted one, at the same stat.
	local weather = load(Server, "WeatherService")
	local npcWeather = 1
	if weather and type(weather.Multipliers) == "function" then
		local okW, m = pcall(weather.Multipliers)
		npcWeather = okW and type(m) == "table" and finite(m.NpcSpeed) and m.NpcSpeed > 0 and m.NpcSpeed or 1
	end
	local npcTarget = T0 - wantSaved / 2
	local routeLose, routeWin = nextRoute(), nextRoute()
	local npcSpeed = routeLose.Tracks[1].Npc.Path.Length / npcTarget / npcWeather
	metrics.close_npc_speed = round(npcSpeed * npcWeather)
	local lose = newRacer(ctx, routeLose, "Lose", { Npc = true, NpcSpeeds = { [1] = npcSpeed } })
	local win = newRacer(ctx, routeWin, "Win", { Npc = true, NpcSpeeds = { [1] = npcSpeed } })
	local cruiseAtStart = win.Run.TargetSpeed
	local ratio = npcSpeed * npcWeather / cruiseAtStart
	check(checks, "nitro_close_npc_slightly_faster", ratio, GOOD, ratio > 1 and ratio < GOOD)
	local boosted = nil
	step(cap, function(t)
		if boosted == nil and t >= BOOST_AT then
			boosted = win.Run:Nitro(GOOD, DUR)
		end
		if firstResult(lose) and firstResult(win) then
			return "stop"
		end
	end)
	local rl, rw = firstResult(lose), firstResult(win)
	check(checks, "nitro_close_npc_boost_accepted", boosted, 1, boosted == true)
	local lost = rl ~= nil and rl.Result == "Lose" and finite(rl.PlayerTime) and rl.PlayerTime >= rl.NpcTime
	check(checks, "nitro_unboosted_loses_close_npc", rl and rl.PlayerTime or -1, rl and rl.NpcTime or -1, lost)
	local won = rw ~= nil and rw.Result == "Win" and finite(rw.PlayerTime) and rw.PlayerTime < rw.NpcTime
	check(checks, "nitro_boost_beats_close_npc", rw and rw.PlayerTime or -1, rw and rw.NpcTime or -1, won)
	local npcSame = rl ~= nil
		and rw ~= nil
		and near(rl.NpcTime, rw.NpcTime, 1e-9)
		and near(rw.NpcTime, npcTarget, 0.01 * npcTarget)
	check(checks, "nitro_npc_time_unchanged", rw and rw.NpcTime or -1, npcTarget, npcSame) -- the boost never moves the NPC
	done(lose)
	done(win)

	-- (c) Refusals on a fresh NPC run: every bad argument returns false and starts nothing
	local routeQuick = nextRoute()
	local quick = newRacer(ctx, routeQuick, "Args", { Npc = true, NpcSpeeds = { [1] = SLOW_NPC } })
	local nan = 0 / 0
	local bad = {
		{ 1, DUR },
		{ 0.5, DUR },
		{ 0, DUR },
		{ -2, DUR },
		{ nan, DUR },
		{ math.huge, DUR },
		{ nil, DUR },
		{ "1.4", DUR },
		{ GOOD, 0 },
		{ GOOD, -1 },
		{ GOOD, nan },
		{ GOOD, math.huge },
		{ GOOD, nil },
		{ GOOD, "2" },
	}
	local badAccepted = 0
	for _, args in bad do
		local ok, accepted2 = pcall(quick.Run.Nitro, quick.Run, args[1], args[2])
		if not ok or accepted2 ~= false or quick.Run.NitroLeft ~= 0 or quick.Run.NitroMulti ~= 1 then
			badAccepted += 1
		end
	end
	check(checks, "nitro_refuses_bad_args", badAccepted, 0, badAccepted == 0)
	local validAfter = quick.Run:Nitro(GOOD, DUR) == true and quick.Run.NitroLeft == DUR
	check(checks, "nitro_args_run_accepts_valid", validAfter, 1, validAfter)
	done(quick)
	local stoppedRefused = quick.Run:Nitro(GOOD, DUR) == false
	check(checks, "nitro_refused_after_stop", stoppedRefused, 1, stoppedRefused)

	-- a run without an NPC (the race test's mode) and a duel run refuse it
	local plain = newRacer(ctx, routeQuick, "NoNpc", {})
	local plainRefused = plain.Run:Nitro(GOOD, DUR) == false and plain.Run.NitroLeft == 0
	check(checks, "nitro_refused_without_npc", plainRefused, 1, plainRefused)
	done(plain)
	local duel = newRacer(ctx, routeQuick, "Duel", { Duel = { Track = 1 } })
	local duelRefused = duel.Run:Nitro(GOOD, DUR) == false and duel.Run.NitroLeft == 0
	check(checks, "nitro_refused_in_duel", duelRefused, 1, duelRefused)
	done(duel)

	-- (d) A loss (back to the start) ends any boost, and the car is back at cruise speed
	-- (the loser screen may hold the reset back for LoseScreenSeconds; the boost is over once the car is reset)
	local lossSpeeds = { [1] = FAST_NPC }
	local loss =
		newRacer(ctx, nextRoute(), "Loss", { Npc = true, NpcSpeeds = lossSpeeds, LoseScreenSeconds = LOSE_SCREEN })
	local lossBoost = loss.Run:Nitro(GOOD, DUR)
	RunService.PostSimulation:Wait()
	loss.Run.Driver.Index = loss.Route.Tracks[1].FinishIndex
	local waited = 0
	while not (firstResult(loss) and loss.Run.Resets >= 1) and waited < LOSE_SCREEN + 2 do
		-- Since 2026-11-20 a race is lost the moment the NPC's time is up, so the restarted Track 1 race would be lost
		-- again in its first frame against FAST_NPC and the car would brake on a new loser screen. Once the loss is
		-- decided, the restarted race gets an NPC the car beats (RaceService reads NpcSpeeds at every race start), so
		-- the window below measures the cruise after the reset, as before.
		if firstResult(loss) then
			lossSpeeds[1] = SLOW_NPC
		end
		waited += RunService.PostSimulation:Wait()
	end
	local lr = firstResult(loss)
	local ended = lossBoost == true and lr ~= nil and lr.Result == "Lose" and loss.Run.Resets == 1
	check(checks, "nitro_loss_ends_boost", loss.Run.NitroLeft, 0, ended and loss.Run.NitroLeft == 0)
	addWindow(loss, "reset", WINDOW_EDGE, WINDOW_EDGE + 0.6)
	step(1.2, function(t)
		sampleWindows(loss, t)
	end)
	local vReset, tReset = windowSpeed(loss, "reset")
	check(
		checks,
		"nitro_loss_back_to_cruise",
		vReset or -1,
		tReset or -1,
		ended and vReset ~= nil and math.abs(vReset - tReset) <= SPEED_TOLERANCE * tReset
	)
	done(loss)
end

-- Part 3: NitroService.Press for one fake player, CarService.IsAutoRacing / GetRun wrapped for that player only.
local function pressChecks(ctx, checks, metrics)
	local NitroConfig, NitroService, CarService = ctx.NitroConfig, ctx.NitroService, ctx.CarService
	local P, LW = NitroConfig.PERIOD, NitroConfig.LATENCY_WINDOW
	local PZ, GZ = NitroConfig.PERFECT_ZONE, NitroConfig.GOOD_ZONE
	local DUR, RECHARGE, MISS = NitroConfig.DURATION, NitroConfig.RECHARGE, NitroConfig.MISS_COOLDOWN
	local fake = Instance.new("Folder")
	fake.Name = "CarTestNitroPressPlayer"
	fake.Parent = Workspace
	table.insert(ctx.cleanup, fake)
	local calls, accept = {}, true
	local fakeRun = {
		Nitro = function(_, multi, seconds)
			table.insert(calls, { multi, seconds })
			return accept
		end,
	}
	local state = { racing = true, run = fakeRun }
	local origRacing, origGetRun = CarService.IsAutoRacing, CarService.GetRun
	CarService.IsAutoRacing = function(player, ...)
		if player == fake then
			return state.racing
		end
		return origRacing(player, ...)
	end
	CarService.GetRun = function(player, ...)
		if player == fake then
			return state.run
		end
		return origGetRun(player, ...)
	end
	local function now()
		return Workspace:GetServerTimeNow()
	end
	-- The bar is ready (not boosting), its zones are centred on `target` (0 when nil; set explicitly every time,
	-- because the service picks a new NitroTarget after every graded press) and the needle is at `x` at server time
	-- `at` (rising half of the sweep).
	local function prime(x, at, target)
		fake:SetAttribute("NitroTarget", target or 0)
		fake:SetAttribute("NitroUntil", 0)
		fake:SetAttribute("NitroReadyAt", at - P * (1 + (x + 1) / 4))
	end
	local function presses()
		return fake:GetAttribute("NitroPresses") or 0
	end
	-- Presses with the claim `claim(t0)`; returns grade, t0 (just before) and t1 (just after the call).
	local function press(claim)
		local t0 = now()
		local claimed = claim(t0)
		local ok, grade = pcall(NitroService.Press, fake, claimed)
		if not ok then
			grade = "error" -- Press threw; nil stays nil (an ignored press)
		end
		return grade, t0, now()
	end
	local okBody, err = xpcall(function()
		local apiOk = type(NitroService.Press) == "function"
		check(checks, "nitro_press_api", apiOk, 1, apiOk)
		if not apiOk then
			return
		end

		-- Claimed press time inside the latency window is used: a press LW/2 ago at the centre is Perfect, although
		-- the needle has left the gold centre by the time it arrives.
		local d = LW / 2
		local t0 = now()
		prime(0, t0 - d)
		local readyFirst = fake:GetAttribute("NitroReadyAt")
		local arrivalGrade = NitroConfig.Grade(NitroConfig.NeedleAt(t0, readyFirst), 0)
		metrics.press_arrival_grade = arrivalGrade
		local before = presses()
		local okP, grade = pcall(NitroService.Press, fake, t0 - d)
		local t1 = now()
		if not okP then
			grade = "error"
		end
		check(checks, "nitro_press_perfect", grade == "Perfect", 1, grade == "Perfect")
		check(
			checks,
			"nitro_press_uses_claimed_time_in_window",
			grade == "Perfect" and arrivalGrade ~= "Perfect",
			1,
			grade == "Perfect" and arrivalGrade ~= "Perfect"
		)
		local last = calls[#calls]
		local callOk = #calls == 1 and last[1] == NitroConfig.PERFECT_MULTI and last[2] == DUR
		check(checks, "nitro_press_perfect_boosts_run", #calls, 1, callOk) -- run:Nitro(PERFECT_MULTI, DURATION)
		local untilT = fake:GetAttribute("NitroUntil")
		local attrsOk = finite(untilT)
			and untilT >= t0 + DUR - 1e-6
			and untilT <= t1 + DUR + 1e-6
			and fake:GetAttribute("NitroMulti") == NitroConfig.PERFECT_MULTI
			and near(fake:GetAttribute("NitroReadyAt"), untilT + RECHARGE, 1e-6)
			and fake:GetAttribute("NitroGrade") == "Perfect"
			and presses() == before + 1
		check(checks, "nitro_press_perfect_attributes", attrsOk, 1, attrsOk) -- until, multi, recharge, grade, count
		-- Press marker (NITRO_SPEC "Press marker"): NitroPressPos is the needle position that was graded, i.e. at
		-- the CLAIMED time inside the window (the centre here), not at the arrival
		local markFirst = fake:GetAttribute("NitroPressPos")
		local wantMarkFirst = NitroConfig.NeedleAt(t0 - d, readyFirst)
		local markFirstOk = finite(markFirst) and math.abs(markFirst - wantMarkFirst) <= 1e-9
		check(checks, "nitro_press_marker_at_claimed_time", markFirst or -9, wantMarkFirst, markFirstOk)

		-- Ignored presses (below) never move the target or the marker: only a graded press does
		local keepBad = 0
		local function keep(fn)
			local target0, mark0 = fake:GetAttribute("NitroTarget"), fake:GetAttribute("NitroPressPos")
			local g = fn()
			if
				g ~= nil
				or fake:GetAttribute("NitroTarget") ~= target0
				or fake:GetAttribute("NitroPressPos") ~= mark0
			then
				keepBad += 1
			end
			return g
		end

		-- a press while the boost lasts does nothing and costs nothing (bar ready again, boost not over yet)
		fake:SetAttribute("NitroReadyAt", now() - P)
		fake:SetAttribute("NitroUntil", now() + DUR)
		local n0, c0 = presses(), #calls
		local gBoosting = keep(function()
			return press(function(t)
				return t
			end)
		end)
		local boostingOk = gBoosting == nil and presses() == n0 and #calls == c0
		check(checks, "nitro_press_ignored_while_boosting", boostingOk, 1, boostingOk)

		-- charging / locked: the bar is not ready yet
		fake:SetAttribute("NitroUntil", 0)
		fake:SetAttribute("NitroReadyAt", now() + 5)
		local readyBefore = fake:GetAttribute("NitroReadyAt")
		local gCharging = keep(function()
			return press(function(t)
				return t
			end)
		end)
		local chargingOk = gCharging == nil
			and presses() == n0
			and #calls == c0
			and fake:GetAttribute("NitroReadyAt") == readyBefore
		check(checks, "nitro_press_ignored_while_charging", chargingOk, 1, chargingOk)

		-- Good: inside the green zone, outside the gold centre
		local gx = (PZ + GZ) / 2
		local gGood = press(function(t)
			prime(gx, t)
			return t
		end)
		last = calls[#calls]
		local goodOk = gGood == "Good"
			and #calls == c0 + 1
			and last[1] == NitroConfig.GOOD_MULTI
			and last[2] == DUR
			and fake:GetAttribute("NitroMulti") == NitroConfig.GOOD_MULTI
			and fake:GetAttribute("NitroGrade") == "Good"
		check(checks, "nitro_press_good", goodOk, 1, goodOk)

		-- Miss: outside the green zone. No boost, the bar is locked for MISS_COOLDOWN.
		local mx = (GZ + 1) / 2
		local c1, n1 = #calls, presses()
		local gMiss, m0, m1 = press(function(t)
			prime(mx, t)
			return t
		end)
		local readyMiss = fake:GetAttribute("NitroReadyAt")
		local missOk = gMiss == "Miss"
			and #calls == c1
			and finite(readyMiss)
			and readyMiss >= m0 + MISS - 1e-6
			and readyMiss <= m1 + MISS + 1e-6
			and fake:GetAttribute("NitroUntil") == 0
			and fake:GetAttribute("NitroGrade") == "Miss"
			and presses() == n1 + 1
		check(checks, "nitro_press_miss_locks_bar", missOk, 1, missOk)

		-- A good press the run refuses (a duel, a stopped run) counts as a Miss and locks the bar (MISS_COOLDOWN).
		accept = false
		local c2 = #calls
		local gRefused, r0, r1 = press(function(t)
			prime(0, t)
			return t
		end)
		accept = true
		local readyRefused = fake:GetAttribute("NitroReadyAt")
		local refusedOk = gRefused == "Miss"
			and #calls == c2 + 1
			and finite(readyRefused)
			and readyRefused >= r0 + MISS - 1e-6
			and readyRefused <= r1 + MISS + 1e-6
			and fake:GetAttribute("NitroUntil") == 0
			and fake:GetAttribute("NitroGrade") == "Miss"
		check(checks, "nitro_press_refused_run_is_miss", refusedOk, 1, refusedOk)

		-- A claim older than the latency window is ignored: the arrival time is graded. The claim would be at the
		-- right edge (a Miss); the arrival is at the centre (Perfect).
		local stale = 0.75 * P
		while stale <= LW + 0.05 do
			stale += P
		end
		local gStale = press(function(t)
			prime(0, t)
			return t - stale
		end)
		check(checks, "nitro_press_stale_claim_uses_arrival", gStale == "Perfect", 1, gStale == "Perfect")
		-- A claim in the future is ignored too: the claim would be at the centre, the arrival is at the right edge.
		local ahead = 0.75 * P
		while ahead <= 0.1 do
			ahead += P
		end
		local gFuture = press(function(t)
			prime(1, t)
			return t + ahead
		end)
		check(checks, "nitro_press_future_claim_uses_arrival", gFuture == "Miss", 1, gFuture == "Miss")
		-- Junk claims fall back to the arrival time (centre: Perfect)
		local junkBad = 0
		for _, junk in { "nope", 0 / 0, math.huge, -math.huge, true, {} } do
			local g = press(function(t)
				prime(0, t)
				return junk
			end)
			if g ~= "Perfect" then
				junkBad += 1
			end
		end
		local gNil = press(function(t)
			prime(0, t)
			return nil
		end)
		if gNil ~= "Perfect" then
			junkBad += 1
		end
		check(checks, "nitro_press_junk_claim_uses_arrival", junkBad, 0, junkBad == 0)

		-- Target (Vic2CS 2026-11-19, NITRO_SPEC "Target" / "Press marker"): a press is graded against the CURRENT
		-- NitroTarget (zones on both sides of it); right after grading, the server sets a new NitroTarget for the next
		-- bar (inside TARGET_RANGE, at least TARGET_MIN_MOVE from the graded one, after a Miss too) and NitroPressPos =
		-- NeedleAt(press time), the graded needle position. Each case: { target, needle - target, grade }.
		local TR, TM = NitroConfig.TARGET_RANGE, NitroConfig.TARGET_MIN_MOVE
		local G = (PZ + GZ) / 2 -- inside the green zone, outside the gold
		local targetOk = finite(TR) and finite(TM) -- (nitro_target_config judges the values)
		local cases = targetOk
				and {
					{ TR, 0, "Perfect" }, -- far right target: Perfect there (from the bar centre it would be a Miss)
					{ TR, -G, "Good" },
					{ TR, G, "Good" },
					{ -TR, 0, "Perfect" },
					{ -TR, G, "Good" },
					{ -TR, -G, "Good" },
					{ TR / 2, PZ / 2, "Perfect" },
					{ -TR / 2, -PZ / 2, "Perfect" },
					{ TR / 2, -(GZ + (1 - GZ) * 0.01), "Miss" },
					{ -TR / 2, GZ + (1 - GZ) * 0.01, "Miss" },
				}
			or {}
		if targetOk and TR > GZ then
			-- the needle at the bar centre is a Miss when the target is far from it (Perfect against target 0)
			table.insert(cases, { TR, -TR, "Miss" })
			table.insert(cases, { -TR, TR, "Miss" })
		end
		local gradeBad, moveBad, markBad = 0, 0, 0
		local EPS = 1e-9
		for _, c in cases do
			local target, x = c[1], c[1] + c[2]
			local readyAt = nil
			local g, tPress = press(function(t)
				prime(x, t, target)
				readyAt = fake:GetAttribute("NitroReadyAt")
				return t -- inside the window: graded at exactly this time
			end)
			if g ~= c[3] then
				gradeBad += 1
			end
			local nextTarget = fake:GetAttribute("NitroTarget")
			if
				not (
					finite(nextTarget)
					and nextTarget >= -TR - EPS
					and nextTarget <= TR + EPS
					and math.abs(nextTarget - target) >= TM - EPS
				)
			then
				moveBad += 1
			end
			local mark = fake:GetAttribute("NitroPressPos")
			local wantMark = readyAt and NitroConfig.NeedleAt(tPress, readyAt) or math.huge
			if not (finite(mark) and math.abs(mark - wantMark) <= EPS and math.abs(mark - x) <= 1e-3) then
				markBad += 1
			end
		end
		check(checks, "nitro_press_grades_against_target", gradeBad, 0, targetOk and gradeBad == 0)
		check(checks, "nitro_press_sets_new_target", moveBad, 0, targetOk and moveBad == 0)
		check(checks, "nitro_press_marker_is_graded_needle", markBad, 0, targetOk and markBad == 0)

		-- Ignored presses: not auto racing, no bar (NitroReadyAt unset), no run, a run without Nitro
		local n2, c3 = presses(), #calls
		local function pressNow()
			return press(function(t)
				return t
			end)
		end
		state.racing = false
		prime(0, now())
		local gNotRacing = keep(pressNow)
		state.racing = true
		fake:SetAttribute("NitroReadyAt", nil)
		local gNoBar = keep(pressNow)
		state.run = nil
		prime(0, now())
		local gNoRun = keep(pressNow)
		state.run = {}
		prime(0, now())
		local gNoNitro = keep(pressNow)
		state.run = fakeRun
		-- A decided race ignores presses (no grade, no lock, no boost): a finished run, and a lost race waiting for
		-- its reset (run.Lost, from the NPC's finish until the reset, while the loser screen shows)
		local decidedBad = 0
		for _, field in { "Finished", "Lost" } do
			fakeRun[field] = true
			prime(0, now())
			local readyDecided = fake:GetAttribute("NitroReadyAt")
			local g = keep(pressNow)
			if g ~= nil or fake:GetAttribute("NitroReadyAt") ~= readyDecided then
				decidedBad += 1
			end
			fakeRun[field] = nil
		end
		check(checks, "nitro_press_ignored_when_race_decided", decidedBad, 0, decidedBad == 0)
		local ignoredOk = gNotRacing == nil
			and gNoBar == nil
			and gNoRun == nil
			and gNoNitro == nil
			and presses() == n2
			and #calls == c3
		check(checks, "nitro_press_ignored_when_not_racing", ignoredOk, 1, ignoredOk)
		check(checks, "nitro_press_ignored_keeps_target", keepBad, 0, keepBad == 0) -- and NitroPressPos

		-- With real runs: a Perfect press boosts a real NPC run; a real duel run refuses it (Miss)
		local route = makeRoute(ctx, ORIGIN + Vector3.new(-LANE_GAP, 0, 0), 200)
		local real = newRacer(ctx, route, "PressNpc", { Npc = true, NpcSpeeds = { [1] = SLOW_NPC } })
		state.run = real.Run
		local gReal = press(function(t)
			prime(0, t)
			return t
		end)
		local realOk = gReal == "Perfect"
			and real.Run.NitroLeft == DUR
			and real.Run.NitroMulti == NitroConfig.PERFECT_MULTI
		check(checks, "nitro_press_boosts_real_run", real.Run.NitroLeft, DUR, realOk)
		done(real)
		local duel = newRacer(ctx, route, "PressDuel", { Duel = { Track = 1 } })
		state.run = duel.Run
		local gDuel = press(function(t)
			prime(0, t)
			return t
		end)
		local duelOk = gDuel == "Miss" and duel.Run.NitroLeft == 0
		check(checks, "nitro_press_duel_is_miss", duelOk, 1, duelOk)
		done(duel)

		-- Saved time (Vic2CS 2026-11-20, NITRO_SPEC "Saved time"): when a boost ends the server sets NitroSaved =
		-- SavedSeconds(multi, run time really boosted) and NitroSavedAt = the end. A full boost saves the nominal
		-- (multi - 1) x DURATION; a reset (JumpToTrack) cuts it short and the saving is that of the part driven.
		local PM = NitroConfig.PERFECT_MULTI
		local nominal = NitroConfig.SavedSeconds(PM, DUR)
		local cruise0 = ctx.RaceConfig.SpeedFor(STAT)
		local longLength = cruise0 * (DUR * PM + 4) + 10
		local function savedAt()
			return fake:GetAttribute("NitroSavedAt")
		end
		local function waitSaved(since, seconds)
			local waited = 0
			while savedAt() == since and waited < seconds do
				waited += RunService.Heartbeat:Wait()
			end
			return savedAt() ~= since
		end
		local full = newRacer(
			ctx,
			makeRoute(ctx, ORIGIN + Vector3.new(-2 * LANE_GAP, 0, 0), longLength),
			"SavedFull",
			{ Npc = true, NpcSpeeds = { [1] = SLOW_NPC } }
		)
		state.run = full.Run
		local savedBefore = savedAt()
		local gFull = press(function(t)
			prime(0, t)
			return t
		end)
		local untilFull = fake:GetAttribute("NitroUntil")
		local endedFull = gFull == "Perfect" and waitSaved(savedBefore, DUR + 1.5)
		local savedFull, atFull = fake:GetAttribute("NitroSaved"), savedAt()
		metrics.saved_full = round(savedFull)
		local fullOk = endedFull
			and near(savedFull, nominal, 1e-6)
			and finite(untilFull)
			and finite(atFull)
			and atFull >= untilFull - SAVED_TOLERANCE
			and atFull <= untilFull + 1
			and fake:GetAttribute("NitroUntil") == untilFull
		check(checks, "nitro_saved_full_boost_nominal", savedFull or -1, nominal, fullOk)
		done(full)

		local cut = newRacer(
			ctx,
			makeRoute(ctx, ORIGIN + Vector3.new(-3 * LANE_GAP, 0, 0), longLength),
			"SavedCut",
			{ Npc = true, NpcSpeeds = { [1] = SLOW_NPC } }
		)
		state.run = cut.Run
		savedBefore = savedAt()
		local gCut = press(function(t)
			prime(0, t)
			return t
		end)
		local untilCut = fake:GetAttribute("NitroUntil")
		step(CUT_AFTER, function() end)
		local leftAtCut = cut.Run.NitroLeft
		local jumped = cut.Run:JumpToTrack(1)
		local endedCut = gCut == "Perfect" and jumped == true and waitSaved(savedBefore, 1)
		local savedCut = fake:GetAttribute("NitroSaved")
		local wantCut = finite(leftAtCut) and NitroConfig.SavedSeconds(PM, DUR - leftAtCut) or -1
		metrics.saved_cut = round(savedCut)
		metrics.saved_cut_want = round(wantCut)
		local cutOk = endedCut
			and cut.Run.NitroLeft == 0
			and finite(savedCut)
			and math.abs(savedCut - wantCut) <= (PM - 1) * SAVED_TOLERANCE
			and savedCut < nominal
			and finite(untilCut)
			and fake:GetAttribute("NitroUntil") < untilCut -- the drawn boost ends at the cut
			and fake:GetAttribute("NitroUntil") <= now()
		check(checks, "nitro_saved_cut_boost_is_real_part", savedCut or -1, wantCut, cutOk)
		done(cut)
		state.run = fakeRun
	end, debug.traceback)
	CarService.IsAutoRacing, CarService.GetRun = origRacing, origGetRun
	local restored = CarService.IsAutoRacing == origRacing and CarService.GetRun == origGetRun
	check(checks, "nitro_press_carservice_restored", restored, 1, restored)
	check(checks, "nitro_press_no_error", okBody, 1, okBody)
	if not okBody then
		metrics.press_error = tostring(err)
	end
end

function Tests.nitro()
	local checks, metrics = {}, {}
	local ctx = {
		NitroConfig = load(Shared, "NitroConfig"),
		NpcConfig = load(Shared, "NpcConfig"),
		NpcRacer = load(Shared, "NpcRacer"),
		RaceConfig = load(Shared, "RaceConfig"),
		CarConfig = load(Shared, "CarConfig"),
		CarFactory = load(Shared, "CarFactory"),
		RaceService = load(Server, "RaceService"),
		MoneyService = load(Server, "MoneyService"),
		PlayerData = load(Server, "PlayerData"),
		CarService = load(Server, "CarService"),
		NitroService = load(Server, "NitroService"),
		cleanup = {},
		runs = {},
	}
	local missing = {}
	for _, key in
		{
			"NitroConfig",
			"NpcConfig",
			"NpcRacer",
			"RaceConfig",
			"CarConfig",
			"CarFactory",
			"RaceService",
			"MoneyService",
			"PlayerData",
			"CarService",
			"NitroService",
		}
	do
		if ctx[key] == nil then
			table.insert(missing, key)
		end
	end
	metrics.missing_modules = table.concat(missing, ",")
	check(checks, "nitro_modules_exist", #missing, 0, #missing == 0)
	if #missing > 0 then
		return result("nitro", checks, metrics)
	end

	local okBody, err = xpcall(function()
		if configChecks(checks, ctx.NitroConfig, metrics) then
			runChecks(ctx, checks, metrics)
			pressChecks(ctx, checks, metrics)
		end
	end, debug.traceback)
	for _, run in ctx.runs do
		pcall(function()
			run:Destroy()
		end)
	end
	for _, inst in ctx.cleanup do
		pcall(function()
			inst:Destroy()
		end)
	end
	check(checks, "nitro_no_error", okBody, 1, okBody)
	if not okBody then
		metrics.error = tostring(err)
	end
	return result("nitro", checks, metrics)
end

return Tests
