--!nonstrict
-- BRIEF: docs/WORLDS_SPEC.md section 1 (owner, 2026-10-27): "RaceConfig.MAX_CRUISE = 800 studs/s (set 2026-10-27:
-- speed_probe was green at every probe up to 1000 ...). Rule: the speed_probe scenario gives the highest speed with 0
-- flips, up-vector Y >= PhysicsTargets.lap.MinUpYStrict and path deviation <= race.MaxPathDeviation on every track,
-- minus 10 %, kept within 700 .. 800)."
--
-- speed_probe is a MEASUREMENT, run on demand (not in TestConfig.Scenarios: it drives the whole chain five times).
-- For each probe speed the whole track chain (TrackRegistry.Chain, every track, so every lap:<Track> route plus the
-- joints) is auto-raced by RaceService with RaceConfig.SpeedFor stubbed to return that speed (restored afterwards,
-- as the race scenario's huge_multi run does). Per speed it records flips, the minimum body up-vector Y outside
-- loops, the max distance to the route (start to the last finish) and whether the car reached the end, overall and
-- per track. highest_green = the highest probe speed that finished with 0 flips, minUpY >= lap.MinUpYStrict and
-- maxDev <= race.MaxPathDeviation on every track. Only speed_probe_ran and speed_probe_600_green can fail;
-- 900 / 1000 results are data.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent

local SPEEDS = { 600, 700, 800, 900, 1000 } -- studs/s, WORLDS_SPEC section 1 (MAX_CRUISE 700 .. 800)
local MUST_BE_GREEN = 600 -- far below today's max cruise
local ORIGIN = Vector3.new(-20000, 0, 20000) -- the race scenario's corner, far from the play area
local SAMPLE_AFTER_STUDS = 30 -- as Scenarios.race: route samples start after 30 studs of travel
local MIN_TRACK_SAMPLES = 5 -- a track with fewer measured frames was not driven, so it can not be green
local RESYNC = 30 -- studs: the windowed nearest-waypoint search lost the car (a frame hitch), search all
local STALL_SECONDS = 8 -- no waypoint progress for this long ends the run (unfinished)
local TIMEOUT_MARGIN = 30 -- seconds on top of route length / speed

local function round(x)
	return math.round(x * 1000) / 1000
end

local function nearestOnPolyline(pts, p, lo, hi)
	local bestD, bestI = math.huge, lo
	for i = math.max(lo, 1), math.min(hi, #pts - 1) do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local len2 = ab:Dot(ab)
		if len2 > 1e-6 then
			local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
			local d = (p - (a + ab * t)).Magnitude
			if d < bestD then
				bestD, bestI = d, i
			end
		end
	end
	return bestD, bestI
end

local function speedProbe()
	local report, flag = H.report("speed_probe")
	local PT = require(Shared.PhysicsTargets)
	local CarConfig = require(Shared.CarConfig)
	local CarFactory = require(Shared.CarFactory)
	local TrackBuilder = require(Shared.TrackBuilder)
	local TrackRegistry = require(Shared.TrackRegistry)
	local RaceConfig = H.module(Shared, "RaceConfig")
	local RaceService = H.module(Server, "RaceService")
	local Money = H.module(Server, "MoneyService")
	local PlayerData = H.module(Server, "PlayerData")
	local strict, maxDevLimit, flipUp = PT.lap.MinUpYStrict, PT.race.MaxPathDeviation, PT.lap.MinUpY
	local specs = type(TrackRegistry.Chain) == "function" and TrackRegistry.Chain() or {}
	local apiOk = RaceConfig ~= nil
		and RaceService ~= nil
		and Money ~= nil
		and PlayerData ~= nil
		and type(RaceConfig.SpeedFor) == "function"
		and type(RaceService.BuildRoute) == "function"
		and type(RaceService.NewRun) == "function"
		and #specs >= 1
	if not apiOk then
		flag("speed_probe_ran", false, 0, #SPEEDS)
		flag("speed_probe_600_green", false, 0, 1)
		return report
	end

	-- the whole chain, built once and driven at every probe speed
	local models, entries = {}, {}
	local origin = CFrame.new(ORIGIN + Vector3.new(0, TrackBuilder.TRACK_LIFT or 0, 0))
	for i, spec in specs do
		local model, layout = TrackBuilder.Build(spec, origin)
		model.Name = "CarTestProbeTrack" .. i
		model.Parent = Workspace
		table.insert(models, model)
		entries[i] = { Layout = layout, Origin = origin, Model = model, Number = spec.Number }
		origin = TrackBuilder.EndCFrame(layout, origin)
	end
	local function cleanup()
		for _, m in models do
			m:Destroy()
		end
	end
	local okRoute, route = pcall(RaceService.BuildRoute, entries)
	if not okRoute or type(route) ~= "table" or type(route.Tracks) ~= "table" then
		cleanup()
		flag("speed_probe_ran", false, 0, #SPEEDS)
		flag("speed_probe_600_green", false, 0, 1)
		return report
	end
	local wps = route.Path.WorldWaypoints
	local n = #wps
	local totalLen = 0
	for i = 2, n do
		totalLen += (wps[i] - wps[i - 1]).Magnitude
	end
	-- route waypoint index -> track position in the chain
	local trackOf = table.create(n, 1)
	for t, track in route.Tracks do
		for i = math.max(track.StartIndex or 1, 1), math.min(track.FinishIndex or n, n) do
			trackOf[i] = t
		end
	end
	local startCF = models[1].Start.CFrame + Vector3.new(0, CarConfig.RestHeight, 0)

	local function drive(speed)
		local st = { ok = false, flips = 0, minUpY = 1, maxDev = 0, finished = false, tracks = {} }
		for t, track in route.Tracks do
			st.tracks[t] = { number = track.Number, flips = 0, minUpY = 1, maxDev = 0, samples = 0 }
		end
		local car = CarFactory.build(CarConfig)
		car.Name = "CarTestProbeCar"
		car:PivotTo(startCF)
		car.Parent = Workspace
		local player = Instance.new("Folder")
		player.Name = "CarTestProbePlayer"
		player.Parent = Workspace
		pcall(function()
			Money.Setup(player)
			PlayerData.Setup(player)
		end)
		local okRun, run = pcall(RaceService.NewRun, car, route, player, nil)
		if not okRun or type(run) ~= "table" then
			st.err = tostring(run)
			car:Destroy()
			player:Destroy()
			return st
		end
		st.initialTarget = run.TargetSpeed
		st.ok = type(run.TargetSpeed) == "number" and math.abs(run.TargetSpeed - speed) <= 0.01
		local chassis = car.PrimaryPart
		local idx, best, dist, t, idle = 1, 1, 0, 0, 0
		local flippedFor, wasFlipped = 0, false
		local timeout = totalLen / speed + TIMEOUT_MARGIN
		while t < timeout do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			local pos = chassis.Position
			dist += chassis.AssemblyLinearVelocity.Magnitude * dt
			local d, seg = nearestOnPolyline(wps, pos, math.max(idx - 3, 1), math.min(idx + 25, n - 1))
			if d > RESYNC then
				d, seg = nearestOnPolyline(wps, pos, 1, n - 1)
			end
			idx = seg
			if idx > best then
				best, idle = idx, 0
			else
				idle += dt
			end
			local tr = st.tracks[trackOf[idx]]
			local up = chassis.CFrame.UpVector.Y
			if not (run.Physics and run.Physics.LoopAssist) then -- upside down inside a loop is intended
				st.minUpY = math.min(st.minUpY, up)
				tr.minUpY = math.min(tr.minUpY, up)
			end
			if up < flipUp and not (run.Physics and run.Physics.LoopAssist) then
				flippedFor += dt
				if not wasFlipped and flippedFor > 1 then
					st.flips += 1
					tr.flips += 1
					wasFlipped = true
				end
			else
				flippedFor, wasFlipped = 0, false
			end
			if run.Finished == true then
				break
			end
			if dist >= SAMPLE_AFTER_STUDS then
				st.maxDev = math.max(st.maxDev, d)
				tr.maxDev = math.max(tr.maxDev, d)
				tr.samples += 1
			end
			if idle > STALL_SECONDS then
				break
			end
		end
		st.finished = run.Finished == true
		st.elapsed = t
		st.recoveries = run.FlipRecoveries
		st.runMinUpY = run.MinUpY
		st.runMaxDev = run.MaxPathDeviation
		pcall(function()
			run:Destroy()
		end)
		car:Destroy()
		player:Destroy()
		return st
	end

	local realSpeedFor = RaceConfig.SpeedFor
	local metrics = { speeds = {}, highest_green = 0, route_length = round(totalLen), tracks = #route.Tracks }
	local ran, green600 = 0, false
	for _, speed in SPEEDS do
		RaceConfig.SpeedFor = function()
			return speed
		end
		local okDrive, st = pcall(drive, speed)
		RaceConfig.SpeedFor = realSpeedFor
		if not okDrive then
			st = { ok = false, err = tostring(st), flips = 0, minUpY = 1, maxDev = 0, finished = false, tracks = {} }
		end
		local green = st.ok and st.finished and #st.tracks == #route.Tracks
		local perTrack = {}
		for _, tr in st.tracks do
			local trGreen = tr.flips == 0 and tr.minUpY >= strict and tr.maxDev <= maxDevLimit
			green = green and trGreen and tr.samples >= MIN_TRACK_SAMPLES
			perTrack[tostring(tr.number)] = {
				flips = tr.flips,
				minUpY = round(tr.minUpY),
				maxDev = round(tr.maxDev),
				samples = tr.samples,
				green = trGreen,
			}
		end
		if st.ok then
			ran += 1
		end
		if green then
			metrics.highest_green = math.max(metrics.highest_green, speed)
		end
		if speed == MUST_BE_GREEN then
			green600 = green
		end
		metrics.speeds[tostring(speed)] = {
			flips = st.flips,
			minUpY = round(st.minUpY),
			maxDev = round(st.maxDev),
			finished = st.finished,
			green = green,
			recoveries = st.recoveries,
			runMinUpY = type(st.runMinUpY) == "number" and round(st.runMinUpY) or nil,
			runMaxDev = type(st.runMaxDev) == "number" and round(st.runMaxDev) or nil,
			elapsed = st.elapsed and round(st.elapsed) or nil,
			target = st.initialTarget,
			err = st.err,
			tracks = perTrack,
		}
	end
	cleanup()

	flag("speed_probe_ran", ran == #SPEEDS, ran, #SPEEDS)
	flag("speed_probe_speedfor_restored", RaceConfig.SpeedFor == realSpeedFor)
	flag("speed_probe_600_green", green600, green600 and 1 or 0, 1)
	report.metrics = metrics
	return report
end

return { speed_probe = speedProbe }
