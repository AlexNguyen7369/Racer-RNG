--!nonstrict
-- Physics scenarios. Each one builds an isolated rig far from the play area, drives it with scripted
-- input on the server (network owner nil), measures, and returns { name, pass, checks, metrics }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local CarFactory = require(Shared.CarFactory)
local CarPhysics = require(Shared.CarPhysics)
local PhysicsTargets = require(Shared.PhysicsTargets)
local TrackBuilder = require(Shared.TrackBuilder)
local TrackRegistry = require(Shared.TrackRegistry)
local TrackValidator = require(Shared.TrackValidator)
local Bot = require(script.Parent.Bot)

local Scenarios = {}

local TEST_ORIGIN = Vector3.new(20000, 0, 20000)
local LAP_ORIGIN = Vector3.new(20000, 0, -20000)

local function round(x)
	return math.round(x * 1000) / 1000
end

local function check(list, name, value, limit, ok)
	table.insert(list, { name = name, value = round(value), limit = limit, pass = ok })
end

local function tiltDeg(chassis)
	return math.deg(math.acos(math.clamp(chassis.CFrame.UpVector.Y, -1, 1)))
end

local function newFlatGround()
	local ground = Instance.new("Part")
	ground.Name = "CarTestGround"
	ground.Anchored = true
	ground.Size = Vector3.new(6000, 2, 6000)
	ground.CFrame = CFrame.new(TEST_ORIGIN + Vector3.new(0, -1, 0))
	ground.Material = Enum.Material.Concrete
	ground.Parent = Workspace
	return ground
end

-- A driven car: spawned, physics stepped every PreSimulation, input mutated by the scenario.
local function newRig(cframe)
	local model = CarFactory.build(CarConfig)
	model:PivotTo(cframe)
	model.Name = "CarTestRig"
	model.Parent = Workspace
	model.PrimaryPart:SetNetworkOwner(nil)
	local physics = CarPhysics.new(model, CarConfig)
	local rig = {
		Model = model,
		Chassis = model.PrimaryPart,
		Physics = physics,
		Input = { Throttle = 0, Steer = 0, Brake = 0, Handbrake = false },
	}
	rig.Connection = RunService.PreSimulation:Connect(function(dt)
		if rig.Driver then
			rig.Input = rig.Driver(dt)
		end
		physics:Step(rig.Input, dt)
	end)
	function rig:Destroy()
		self.Connection:Disconnect()
		self.Model:Destroy()
	end
	return rig
end

local MAX_NO_PROGRESS = 8 -- seconds without new waypoint progress before a lap is abandoned
local NO_PROGRESS_GRACE = 3 -- seconds at the start of a lap where a slow launch is allowed

local function frames(seconds, each)
	local t = 0
	while t < seconds do
		local dt = RunService.Heartbeat:Wait()
		t += dt
		if each and each(t, dt) == "stop" then
			break
		end
	end
	return t
end

local function result(name, checks, metrics)
	local pass = true
	for _, c in checks do
		pass = pass and c.pass
	end
	return { scenario = name, pass = pass, checks = checks, metrics = metrics }
end

local function spawnPose()
	return CFrame.new(TEST_ORIGIN + Vector3.new(0, CarConfig.RestHeight + 0.5, 0))
end

function Scenarios.static_settle()
	local T = PhysicsTargets.static_settle
	local ground = newFlatGround()
	local rig = newRig(spawnPose())
	frames(3)
	local speed = rig.Chassis.AssemblyLinearVelocity.Magnitude
	local minC, maxC = math.huge, 0
	for _, w in rig.Physics.Wheels do
		local comp = (CarConfig.SuspensionRest - w.SpringLen) / CarConfig.SuspensionRest
		minC, maxC = math.min(minC, comp), math.max(maxC, comp)
	end
	local tilt = tiltDeg(rig.Chassis)
	local checks = {}
	check(checks, "settle_speed", speed, T.MaxSettleSpeed, speed <= T.MaxSettleSpeed)
	check(checks, "min_compression", minC, T.MinCompression, minC >= T.MinCompression)
	check(checks, "max_compression", maxC, T.MaxCompression, maxC <= T.MaxCompression)
	check(checks, "tilt_deg", tilt, T.MaxTiltDeg, tilt <= T.MaxTiltDeg)
	local out = result(
		"static_settle",
		checks,
		{ minCompression = round(minC), maxCompression = round(maxC), tiltDeg = round(tilt) }
	)
	rig:Destroy()
	ground:Destroy()
	return out
end

function Scenarios.accel()
	local T = PhysicsTargets.accel
	local ground = newFlatGround()
	local rig = newRig(spawnPose())
	frames(1.5) -- settle
	local startX = rig.Chassis.Position.X
	rig.Input = { Throttle = 1, Steer = 0, Brake = 0, Handbrake = false }
	local timeTo40, topSpeed, maxDrift = nil, 0, 0
	frames(12, function(t)
		local v = rig.Physics.ForwardSpeed
		topSpeed = math.max(topSpeed, v)
		if not timeTo40 and v >= 40 then
			timeTo40 = t
		end
		maxDrift = math.max(maxDrift, math.abs(rig.Chassis.Position.X - startX))
	end)
	local checks = {}
	local t40 = timeTo40 or math.huge
	check(checks, "time_to_40", t40, T.MaxTimeTo40, t40 <= T.MaxTimeTo40)
	local needTop = T.MinTopSpeedFrac * CarConfig.TopSpeed
	check(checks, "top_speed", topSpeed, needTop, topSpeed >= needTop)
	check(checks, "drift", maxDrift, T.MaxDrift, maxDrift <= T.MaxDrift)
	local out = result(
		"accel",
		checks,
		{ timeTo40 = t40 == math.huge and -1 or round(t40), topSpeed = round(topSpeed), drift = round(maxDrift) }
	)
	rig:Destroy()
	ground:Destroy()
	return out
end

function Scenarios.brake()
	local T = PhysicsTargets.brake
	local ground = newFlatGround()
	local rig = newRig(spawnPose())
	frames(1.5)
	rig.Input = { Throttle = 1, Steer = 0, Brake = 0, Handbrake = false }
	frames(12, function()
		if rig.Physics.ForwardSpeed >= T.FromSpeed then
			return "stop"
		end
	end)
	local startPos = rig.Chassis.Position
	local reached = rig.Physics.ForwardSpeed
	rig.Input = { Throttle = 0, Steer = 0, Brake = 1, Handbrake = false }
	frames(6, function()
		if rig.Physics.Speed < 1 then
			return "stop"
		end
	end)
	local delta = rig.Chassis.Position - startPos
	local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local drift = math.abs(delta.X)
	local checks = {}
	check(checks, "reached_speed", reached, T.FromSpeed, reached >= T.FromSpeed - 2)
	check(checks, "stop_distance", dist, T.MaxStopDistance, dist <= T.MaxStopDistance)
	check(checks, "drift", drift, T.MaxDrift, drift <= T.MaxDrift)
	local out =
		result("brake", checks, { reachedSpeed = round(reached), stopDistance = round(dist), drift = round(drift) })
	rig:Destroy()
	ground:Destroy()
	return out
end

function Scenarios.skidpad()
	local T = PhysicsTargets.skidpad
	local ground = newFlatGround()
	local rig = newRig(spawnPose())
	frames(1.5)
	rig.Driver = function()
		local err = T.Speed - rig.Physics.ForwardSpeed
		return { Throttle = math.clamp(err * 0.2, -1, 1), Steer = 1, Brake = 0, Handbrake = false }
	end
	local radii, minUp = {}, 1
	frames(7, function(t)
		minUp = math.min(minUp, rig.Chassis.CFrame.UpVector.Y)
		if t > 4 then
			local yaw = math.abs(rig.Chassis.AssemblyAngularVelocity.Y)
			if yaw > 0.01 then
				table.insert(radii, rig.Physics.Speed / yaw)
			end
		end
	end)
	local sum = 0
	for _, r in radii do
		sum += r
	end
	local radius = #radii > 0 and sum / #radii or math.huge
	local checks = {}
	check(checks, "radius", radius, T.MaxRadius, radius <= T.MaxRadius)
	check(checks, "min_up_y", minUp, T.MinUpY, minUp >= T.MinUpY)
	local out =
		result("skidpad", checks, { radius = radius == math.huge and -1 or round(radius), minUpY = round(minUp) })
	rig:Destroy()
	ground:Destroy()
	return out
end

-- expect (optional, from CarTest/TrackTests) may add MaxLapTime / MinLapTime on top of PhysicsTargets.lap.
-- label (optional) is the scenario name reported, so `track:<Name>` can reuse this.
function Scenarios.lap(trackName, expect, label)
	local T = PhysicsTargets.lap
	expect = expect or {}
	label = label or ("lap:" .. tostring(trackName))
	local spec = TrackRegistry.Get(trackName)
	if not spec then
		return result(label, { { name = "track_exists", value = 0, limit = 1, pass = false } }, {})
	end

	local origin = CFrame.new(LAP_ORIGIN)
	local model, layout = TrackBuilder.Build(spec, origin)
	model.Name = "CarTestTrack"
	model.Parent = Workspace

	local validation = TrackValidator.Validate(spec, layout)
	local checks = {}
	check(checks, "track_valid", #validation.Issues, 0, validation.Ok)
	if not validation.Ok then
		model:Destroy()
		return result(label, checks, { issues = validation.Issues })
	end

	local rig = newRig(model.Start.CFrame + Vector3.new(0, CarConfig.RestHeight, 0))
	local bot = Bot.new(layout, CarConfig)
	local flips, flippedTime, stuckTime = 0, 0, 0
	local lapClock, bestProgress, idleTime, longestIdle = 0, 0, 0, 0
	local wasFlipped = false
	local minUp = 1
	rig.Driver = function(dt)
		lapClock += dt
		local input = bot:Control(rig.Chassis, dt)
		local up = rig.Chassis.CFrame.UpVector.Y
		if not rig.Physics.LoopAssist then -- upside down inside a loop is intended
			minUp = math.min(minUp, up)
		end
		if up < T.MinUpY and not rig.Physics.LoopAssist then
			flippedTime += dt
			if not wasFlipped and flippedTime > 1 then
				flips += 1
				wasFlipped = true
			end
		else
			flippedTime, wasFlipped = 0, false
		end
		if rig.Physics.Speed < 1 and bot.Index > 1 then
			stuckTime += dt
		else
			stuckTime = 0
		end
		-- waypoint high-water mark: rolling backwards or creeping in place is not progress
		local progress = bot.Wraps * #layout.Waypoints + bot.Index
		if progress > bestProgress or lapClock < NO_PROGRESS_GRACE then
			bestProgress = math.max(bestProgress, progress)
			idleTime = 0
		else
			idleTime += dt
			longestIdle = math.max(longestIdle, idleTime)
		end
		return input
	end

	local timeout = layout.Length / (0.25 * CarConfig.TopSpeed) + 30
	local elapsed = frames(timeout, function()
		if bot.Done or stuckTime > 4 or idleTime > MAX_NO_PROGRESS or flips > 0 then
			return "stop"
		end
	end)

	check(checks, "completed", bot.Done and 1 or 0, 1, bot.Done)
	check(
		checks,
		"off_track_seconds",
		bot.OffTrackSeconds,
		T.MaxOffTrackSeconds,
		bot.OffTrackSeconds <= T.MaxOffTrackSeconds
	)
	check(checks, "flips", flips, T.MaxFlips, flips <= T.MaxFlips)
	-- user: the car must not flip or tilt by any means (loops excluded, minUp is not sampled inside them)
	local strict = T.MinUpYStrict
	check(checks, "never_tilted", minUp, strict or -1, type(strict) == "number" and strict >= 0.9 and minUp >= strict)
	check(checks, "stuck_seconds", stuckTime, 4, stuckTime <= 4)
	check(checks, "no_progress_seconds", longestIdle, MAX_NO_PROGRESS, longestIdle <= MAX_NO_PROGRESS)
	if expect.MaxLapTime then
		check(checks, "max_lap_time", elapsed, expect.MaxLapTime, bot.Done and elapsed <= expect.MaxLapTime)
	end
	if expect.MinLapTime then
		check(checks, "min_lap_time", elapsed, expect.MinLapTime, bot.Done and elapsed >= expect.MinLapTime)
	end
	local out = result(label, checks, {
		lapTime = round(elapsed),
		length = round(layout.Length),
		progress = round(bot.Index / #layout.Waypoints),
		minUpY = round(minUp),
	})
	rig:Destroy()
	model:Destroy()
	return out
end

local function flatV(v)
	return Vector3.new(v.X, 0, v.Z)
end

local FAIL_RACE_PATH_CHECKS = {
	"race_path_ends_at_finish",
	"race_path_starts_at_start",
	"race_path_arrives_straight",
	"race_path_is_right_lane",
	"race_path_right_of_centre",
	"race_path_curvature_shifted",
	"race_path_inside_road",
	"pad_off_racing_line",
	"race_path_abeam_of_pad",
	"race_path_pad_index",
	"race_path_spacing",
	"race_path_smooth",
	"race_path_curvature_matches",
}

-- Wide checkpoint, left pad and race path (CLAUDE.md track rules 4-5). Every constant/API is guarded:
-- a missing one fails a check, it never errors.
local function checkWideCheckpoint(checks, layout, model, origin, area, pad, line, requireSpec)
	local APRON = TrackBuilder.CHECKPOINT_APRON
	local LEN = TrackBuilder.CHECKPOINT_LENGTH
	local OFFSET = TrackBuilder.PAD_LEFT_OFFSET
	local haveConsts = type(APRON) == "number" and type(LEN) == "number" and type(OFFSET) == "number"
	check(checks, "checkpoint_constants", haveConsts and 1 or 0, 1, haveConsts)
	-- Brief change (user): the car no longer swings over the pad, so the zone shrinks from [150,220] to [40,100].
	check(
		checks,
		"checkpoint_length_reasonable",
		type(LEN) == "number" and LEN or -1,
		40,
		type(LEN) == "number" and LEN >= 40 and LEN <= 100
	)
	local lastSeg = requireSpec and requireSpec.Segments and requireSpec.Segments[#requireSpec.Segments]
	local needLen = (type(LEN) == "number" and LEN or 0) + 4
	check(
		checks,
		"last_straight_covers_checkpoint",
		lastSeg and lastSeg.Length or 0,
		needLen,
		type(LEN) == "number" and lastSeg ~= nil and lastSeg.Type == "Straight" and (lastSeg.Length or 0) >= needLen
	)
	APRON, LEN, OFFSET = APRON or math.huge, LEN or 0, OFFSET or 0
	local W = layout.Width
	local endCF = origin * CFrame.new(layout.EndPosition) * CFrame.Angles(0, layout.EndHeading, 0)

	if area and area:IsA("BasePart") then
		check(checks, "checkpoint_wide", area.Size.X, W + 2 * APRON, haveConsts and area.Size.X >= W + 2 * APRON - 0.01)
		check(checks, "checkpoint_area_length", area.Size.Z, LEN, haveConsts and math.abs(area.Size.Z - LEN) <= 1)
		local rel = endCF:PointToObjectSpace(area.Position)
		-- behind the finish (local +Z is back along the road), centred on the road
		check(
			checks,
			"checkpoint_area_ends_at_finish",
			rel.Z,
			LEN / 2,
			haveConsts and rel.Z > 0 and math.abs(rel.Z - LEN / 2) <= 1 and math.abs(rel.X) <= 1
		)
		local top = area.CFrame:PointToWorldSpace(Vector3.new(0, area.Size.Y / 2, 0)).Y
		local roadTop = origin:PointToWorldSpace(layout.EndPosition).Y
		check(checks, "area_top_flush", top - roadTop, 0.1, math.abs(top - roadTop) <= 0.1)
		check(checks, "area_collides", area.CanCollide and 1 or 0, 1, area.CanCollide == true)

		-- Any wall whose bounding box (8 corners in the finish-pose local frame) overlaps the footprint
		-- rectangle X in +-area.Size.X/2, Z in [0, LEN] (local +Z is back along the road) is a failure.
		local inside, wallCount = 0, 0
		local walls = model:FindFirstChild("Walls")
		if walls then
			local halfX = area.Size.X / 2
			for _, w in walls:GetChildren() do
				if w:IsA("BasePart") then
					wallCount += 1
					local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
					for sx = -1, 1, 2 do
						for sz = -1, 1, 2 do
							local p = endCF:PointToObjectSpace(
								w.CFrame:PointToWorldSpace(Vector3.new(sx * w.Size.X / 2, 0, sz * w.Size.Z / 2))
							)
							minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
							minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
						end
					end
					if maxX > -halfX and minX < halfX and maxZ > 0 and minZ < LEN then
						inside += 1
					end
				end
			end
		end
		check(checks, "walls_open_at_checkpoint", inside, 0, inside == 0)
		check(checks, "walls_still_exist", wallCount, 1, wallCount >= 1)

		if pad and pad:IsA("BasePart") then
			local r = area.CFrame:PointToObjectSpace(pad.Position)
			check(
				checks,
				"pad_on_area",
				math.abs(r.X),
				area.Size.X / 2,
				math.abs(r.X) <= area.Size.X / 2 and math.abs(r.Z) <= area.Size.Z / 2
			)
		end
	else
		for _, name in
			{
				"checkpoint_wide",
				"checkpoint_area_length",
				"checkpoint_area_ends_at_finish",
				"area_top_flush",
				"area_collides",
				"walls_open_at_checkpoint",
				"walls_still_exist",
				"pad_on_area",
			}
		do
			check(checks, name, 0, 1, false)
		end
	end

	if line and line:IsA("BasePart") then
		check(checks, "finish_line_spans_road", line.Size.X, W, line.Size.X >= W - 0.01)
	else
		check(checks, "finish_line_spans_road", 0, W, false)
	end

	if pad and pad:IsA("BasePart") then
		local lateral = (pad.Position - origin:PointToWorldSpace(layout.EndPosition)):Dot(-endCF.RightVector)
		check(checks, "pad_on_left", lateral, W / 2, haveConsts and lateral >= W / 2 and lateral <= W / 2 + APRON)
		check(checks, "pad_not_centred", math.abs(lateral), W / 2, math.abs(lateral) >= W / 2)
		check(checks, "pad_offset_matches", lateral, OFFSET, haveConsts and math.abs(lateral - OFFSET) <= 0.5)
	else
		for _, name in { "pad_on_left", "pad_not_centred", "pad_offset_matches" } do
			check(checks, name, 0, 1, false)
		end
	end

	-- Race path (local space of the track)
	local okRP, rp = false, nil
	if type(TrackBuilder.RacePath) == "function" then
		okRP, rp = pcall(TrackBuilder.RacePath, layout)
	end
	local wps = okRP and type(rp) == "table" and type(rp.Waypoints) == "table" and rp.Waypoints or nil
	local valid = wps ~= nil and #wps >= 2 and typeof(wps[1]) == "Vector3"
	check(checks, "race_path_exists", valid and 1 or 0, 1, valid)
	if not valid then
		for _, name in FAIL_RACE_PATH_CHECKS do
			check(checks, name, 0, 1, false)
		end
		return
	end
	local n = #wps
	local endLocal = CFrame.new(layout.EndPosition) * CFrame.Angles(0, layout.EndHeading, 0)

	-- User change: the car drives in a right-hand lane, LANE_OFFSET studs to the right of the road centre line.
	local LANE = TrackBuilder.LANE_OFFSET
	local laneOk = type(LANE) == "number" and LANE > 0
	check(checks, "lane_offset_constant", laneOk and LANE or -1, 10, laneOk and LANE == 10)
	LANE = laneOk and LANE or 0
	local endRight = endLocal.RightVector
	local gapEnd = (wps[n] - (layout.EndPosition + endRight * LANE)).Magnitude
	check(checks, "race_path_ends_at_finish", gapEnd, 1, laneOk and gapEnd <= 1)
	local gapStart = (wps[1] - (layout.Waypoints[1] + Vector3.xAxis * LANE)).Magnitude
	check(checks, "race_path_starts_at_start", gapStart, 1, laneOk and gapStart <= 1)
	local step = flatV(wps[n] - wps[n - 1])
	local fwd = flatV(endLocal.LookVector)
	local dot = (step.Magnitude > 0 and fwd.Magnitude > 0) and step.Unit:Dot(fwd.Unit) or -1
	check(checks, "race_path_arrives_straight", dot, 0.99, dot >= 0.99)

	local padLocal = origin:PointToObjectSpace(pad and pad.Position or Vector3.zero)
	-- The race path is the centre line shifted LANE studs to the RIGHT of the local travel direction.
	local lw = layout.Waypoints
	local same = type(lw) == "table" and #lw == n
	local function rightAt(i)
		local a, b = lw[math.max(i - 1, 1)], lw[math.min(i + 1, #lw)]
		local t = flatV(b - a)
		if t.Magnitude < 1e-6 then
			return nil
		end
		return t.Unit:Cross(Vector3.yAxis) -- heading 0 (-Z): right = +X
	end
	local worstDiff, worstSide, leftOrZero = same and 0 or math.huge, 0, 0
	local worstCurv = same and 0 or math.huge
	if same and laneOk then
		for i = 1, n do
			local r = rightAt(i)
			if r then
				worstDiff = math.max(worstDiff, (wps[i] - (lw[i] + r * LANE)).Magnitude)
				local side = flatV(wps[i] - lw[i]):Dot(r)
				worstSide = math.max(worstSide, math.abs(side - LANE))
				if side <= 0.01 then
					leftOrZero += 1
				end
			else
				worstDiff = math.huge
			end
		end
		-- curvature of a path shifted to the right: a left turn (R) becomes R + LANE, a right turn R - LANE
		local curv = rp.Curvature
		if type(curv) == "table" and #curv == n and type(layout.Curvature) == "table" and #layout.Curvature == n then
			for i = 1, n do
				local c0, c1 = layout.Curvature[i], curv[i]
				if type(c1) ~= "number" or c1 ~= c1 then
					worstCurv = math.huge
				elseif c0 == 0 then
					worstCurv = math.max(worstCurv, c1 == 0 and 0 or math.huge)
				else
					local prev, nxt = lw[math.max(i - 1, 1)], lw[math.min(i + 1, n)]
					local a, b = flatV(lw[i] - prev), flatV(nxt - lw[i])
					local turn = a:Cross(b).Y -- > 0: left turn
					if turn == 0 or a.Magnitude == 0 or b.Magnitude == 0 then
						worstCurv = math.huge
					else
						local radius = 1 / c0
						local shifted = turn > 0 and radius + LANE or radius - LANE
						if shifted <= 0 then
							worstCurv = math.huge
						else
							worstCurv = math.max(worstCurv, math.abs(c1 * shifted - 1))
						end
					end
				end
			end
		else
			worstCurv = math.huge
		end
	elseif same then
		worstDiff, worstSide, worstCurv = math.huge, math.huge, math.huge
	else
		worstSide = math.huge
	end
	check(
		checks,
		"race_path_is_right_lane",
		worstDiff == math.huge and -1 or worstDiff,
		0.5,
		same and laneOk and worstDiff <= 0.5
	)
	check(
		checks,
		"race_path_right_of_centre",
		worstSide == math.huge and -1 or worstSide,
		0.5,
		same and laneOk and worstSide <= 0.5 and leftOrZero == 0
	)
	check(
		checks,
		"race_path_curvature_shifted",
		worstCurv == math.huge and -1 or worstCurv,
		0.03,
		same and laneOk and worstCurv <= 0.03
	)
	-- a car that strays MaxPathDeviation from its lane must still be on the road
	local R = PhysicsTargets.race
	local maxDev = R and R.MaxPathDeviation
	check(
		checks,
		"race_path_inside_road",
		laneOk and type(maxDev) == "number" and LANE + maxDev or -1,
		W / 2,
		laneOk and type(maxDev) == "number" and LANE + maxDev < W / 2
	)

	-- The pad sits beside the racing line, never on it.
	local nearest = math.huge
	for _, p in wps do
		nearest = math.min(nearest, flatV(p - padLocal).Magnitude)
	end
	check(
		checks,
		"pad_off_racing_line",
		nearest == math.huge and -1 or nearest,
		W / 2 - 0.5,
		pad ~= nil and nearest >= W / 2 - 0.5
	)

	local pi = rp.PadIndex
	local piOk = type(pi) == "number" and pi >= 1 and pi <= n and pi == math.floor(pi)
	check(checks, "race_path_pad_index", piOk and pi or -1, n, piOk)
	local longi, lat = math.huge, -math.huge
	if piOk and pad then
		local a1, a2 = wps[math.max(pi - 1, 1)], wps[math.min(pi + 1, n)]
		local tangent = flatV(a2 - a1)
		if tangent.Magnitude > 0 then
			local f = tangent.Unit
			local right = f:Cross(Vector3.yAxis)
			local d = flatV(padLocal - wps[pi])
			longi = math.abs(d:Dot(f))
			lat = -d:Dot(right) -- positive = pad is LEFT of the path
		end
	end
	check(
		checks,
		"race_path_abeam_of_pad",
		longi == math.huge and -1 or longi,
		6,
		pad ~= nil and piOk and laneOk and longi <= 6 and math.abs(lat - (OFFSET + LANE)) <= 0.5
	)

	-- arc distance back from the finish
	local arc = table.create(n, 0)
	local worstGap = 0
	for i = n - 1, 1, -1 do
		local seg = (wps[i + 1] - wps[i]).Magnitude
		arc[i] = arc[i + 1] + seg
		worstGap = math.max(worstGap, seg)
	end
	check(checks, "race_path_spacing", worstGap, 15, worstGap <= 15)

	local worstStep = 0
	for i = 1, n - 1 do
		if arc[i] <= LEN + 15 then
			local a = endLocal:PointToObjectSpace(wps[i]).X
			local b = endLocal:PointToObjectSpace(wps[i + 1]).X
			worstStep = math.max(worstStep, math.abs(a - b))
		end
	end
	check(checks, "race_path_smooth", worstStep, 8, worstStep <= 8)

	local curvOk = type(rp.Curvature) == "table" and #rp.Curvature == n
	if curvOk then
		for _, c in rp.Curvature do
			if type(c) ~= "number" or c ~= c or c < 0 then
				curvOk = false
			end
		end
	end
	check(checks, "race_path_curvature_matches", curvOk and 1 or 0, 1, curvOk)
end

-- Checkpoint rules (CLAUDE.md track rules 4-6): builds the track far away and inspects the Checkpoint model.
local function checkCheckpoint(checks, spec, layout, expect)
	local origin = CFrame.new(LAP_ORIGIN + Vector3.new(0, 0, -6000))
	local model = TrackBuilder.Build(spec, origin)
	model.Parent = Workspace
	local function find(name)
		return model:FindFirstChild(name, true)
	end
	local checkpoint = find("Checkpoint")
	check(checks, "checkpoint_exists", checkpoint and 1 or 0, 1, checkpoint ~= nil)
	local line, area, pad = find("FinishLine"), find("CheckpointArea"), find("WinPad")
	check(checks, "finish_line_exists", line and 1 or 0, 1, line ~= nil and line:IsA("BasePart"))
	check(checks, "checkpoint_area_exists", area and 1 or 0, 1, area ~= nil and area:IsA("BasePart"))
	check(checks, "win_pad_exists", pad and 1 or 0, 1, pad ~= nil and pad:IsA("BasePart"))
	if checkpoint then
		local inside = (line and line:IsDescendantOf(checkpoint))
			and (area and area:IsDescendantOf(checkpoint))
			and (pad and pad:IsDescendantOf(checkpoint))
		check(checks, "checkpoint_contains_parts", inside and 1 or 0, 1, inside == true)
	end
	local cash = type(TrackBuilder.CashFor) == "function" and TrackBuilder.CashFor(spec.Number) or nil
	local perTrack = type(TrackBuilder.CashFor) == "function" and TrackBuilder.CashFor(1) or 0
	local double = type(TrackBuilder.CashFor) == "function" and TrackBuilder.CashFor(2) or 0
	check(checks, "cash_per_track_min", perTrack, 1, perTrack >= 1)
	local wantCash = (spec.Number or 0) * (TrackBuilder.CASH_PER_TRACK or 0)
	check(
		checks,
		"cash_equal_number_times_rate",
		cash or -1,
		wantCash,
		cash ~= nil and wantCash >= 1 and cash == wantCash
	)
	check(checks, "cash_scale_linear", double, 2 * perTrack, perTrack >= 1 and double == 2 * perTrack)
	if pad and pad:IsA("BasePart") then
		check(checks, "pad_neon", pad.Material == Enum.Material.Neon and 1 or 0, 1, pad.Material == Enum.Material.Neon)
		local c = pad.Color
		local r, g, b = c.R * 255, c.G * 255, c.B * 255
		check(checks, "pad_yellow", r, 200, r >= 200 and g >= 170 and b <= 120)
		check(checks, "pad_no_collide", pad.CanCollide and 1 or 0, 0, pad.CanCollide == false)
		local biggest = math.max(pad.Size.X, pad.Size.Y, pad.Size.Z)
		check(checks, "pad_small", biggest, 16, biggest <= 16)
		local tagged = CollectionService:HasTag(pad, "WinPad")
		check(checks, "pad_tagged", tagged and 1 or 0, 1, tagged)
		local attr = pad:GetAttribute("Cash")
		check(checks, "pad_cash_attr", type(attr) == "number" and attr or -1, cash or -1, cash ~= nil and attr == cash)
		local gui = pad:FindFirstChildWhichIsA("BillboardGui", true)
		check(checks, "pad_billboard", gui and 1 or 0, 1, gui ~= nil)
		if gui then
			local label = gui:FindFirstChildWhichIsA("TextLabel", true)
			local want = cash and ("$" .. cash) or "?"
			check(checks, "pad_text", label and 1 or 0, 1, label ~= nil and label.Text == want)
			local d = gui.MaxDistance
			-- user asked for +20 studs: 40 -> 60
			check(checks, "pad_text_distance", d, 60, d == 60)
			local wd = TrackBuilder.WIN_TEXT_DISTANCE
			check(checks, "pad_text_distance_const", wd or -1, 60, wd == 60 and d == wd)
		end
		local endWorld = origin:PointToWorldSpace(layout.EndPosition)
		local gap = (pad.Position - endWorld).Magnitude
		-- Brief-driven: the checkpoint zone is long (CHECKPOINT_LENGTH) so the car can swing over the pad and
		-- back within its cornering limit; the pad may sit anywhere in that zone (pad_on_area bounds it).
		local zone = TrackBuilder.CHECKPOINT_LENGTH
		check(checks, "pad_near_finish", gap, zone or -1, type(zone) == "number" and gap <= zone)
	end
	if expect and expect.WidePad then
		checkWideCheckpoint(checks, layout, model, origin, area, pad, line, spec)
	end
	model:Destroy()
end

-- Track acceptance test: the spec written first by test-writer in CarTest/TrackTests/<Name>.luau.
-- Red until the track exists and meets every expectation; then also drives a lap.
-- Decor never blocks a car (StartLine, FinishLine, Start marker, WinPad are CanCollide == false); the drivable
-- road and the CheckpointArea stay solid. Built on its own, away from everything else.
local DECOR_NO_COLLIDE = {
	{ "StartLine", "start_line_no_collide" },
	{ "FinishLine", "finish_line_no_collide" },
	{ "Start", "start_marker_no_collide" },
	{ "WinPad", "win_pad_decor_no_collide" },
}
local function checkTrackCollision(checks, spec)
	local okBuild, model = pcall(TrackBuilder.Build, spec, CFrame.new(LAP_ORIGIN + Vector3.new(-9000, 0, 0)))
	if not okBuild or typeof(model) ~= "Instance" then
		check(checks, "decor_track_builds", 0, 1, false)
		return
	end
	model.Name = "CarTestDecorTrack"
	model.Parent = Workspace
	for _, pair in DECOR_NO_COLLIDE do
		local found, colliding = 0, 0
		for _, d in model:GetDescendants() do
			if d.Name == pair[1] and d:IsA("BasePart") then
				found += 1
				if d.CanCollide then
					colliding += 1
				end
			end
		end
		check(checks, pair[2], found == 0 and -1 or colliding, 0, found >= 1 and colliding == 0)
	end
	local road = model:FindFirstChild("Road")
	local roadParts, roadSolid = 0, 0
	if road then
		for _, d in road:GetDescendants() do
			if d:IsA("BasePart") then
				roadParts += 1
				if d.CanCollide then
					roadSolid += 1
				end
			end
		end
	end
	check(checks, "road_collides", roadSolid, roadParts, roadParts >= 1 and roadSolid == roadParts)
	local area = model:FindFirstChild("CheckpointArea", true)
	local areaOk = area ~= nil and area:IsA("BasePart") and area.CanCollide == true
	check(checks, "checkpoint_area_still_collides", areaOk and 1 or 0, 1, areaOk)
	model:Destroy()
end

function Scenarios.track(trackName)
	local label = "track:" .. trackName
	local testModule = script.Parent.TrackTests:FindFirstChild(trackName)
	if not testModule then
		return result(label, { { name = "test_file_exists", value = 0, limit = 1, pass = false } }, {})
	end
	local expect = require(testModule)
	local spec = TrackRegistry.Get(trackName)
	if not spec then
		return result(label, { { name = "track_exists", value = 0, limit = 1, pass = false } }, {})
	end

	local layout = TrackBuilder.Layout(spec)
	local checks = {}
	if expect.Closed ~= nil then
		check(checks, "closed", layout.Closed and 1 or 0, expect.Closed and 1 or 0, layout.Closed == expect.Closed)
	end
	if expect.MinLength then
		check(checks, "min_length", layout.Length, expect.MinLength, layout.Length >= expect.MinLength)
	end
	if expect.MaxLength then
		check(checks, "max_length", layout.Length, expect.MaxLength, layout.Length <= expect.MaxLength)
	end
	if expect.MinWidth then
		check(checks, "min_width", layout.Width, expect.MinWidth, layout.Width >= expect.MinWidth)
	end
	if expect.MinRadius then
		local smallest = math.huge
		for _, seg in spec.Segments do
			if seg.Type == "Turn" then
				smallest = math.min(smallest, seg.Radius)
			end
		end
		check(checks, "min_radius", smallest, expect.MinRadius, smallest >= expect.MinRadius)
	end
	if expect.MinPeakHeight then
		check(checks, "min_peak_height", layout.Peak, expect.MinPeakHeight, layout.Peak >= expect.MinPeakHeight)
	end
	if expect.MaxGradeDeg then
		check(checks, "max_grade_deg", layout.MaxGradeDeg, expect.MaxGradeDeg, layout.MaxGradeDeg <= expect.MaxGradeDeg)
	end
	if expect.MinLoops then
		check(checks, "min_loops", layout.LoopCount, expect.MinLoops, layout.LoopCount >= expect.MinLoops)
	end
	if expect.MinTurns then
		local turns = 0
		for _, seg in spec.Segments do
			if seg.Type == "Turn" then
				turns += 1
			end
		end
		check(checks, "min_turns", turns, expect.MinTurns, turns >= expect.MinTurns)
	end
	if expect.Number then
		check(checks, "number", spec.Number or -1, expect.Number, spec.Number == expect.Number)
	end
	if expect.MinStartFinishGap then
		local gap = layout.EndPosition.Magnitude
		local need = expect.MinStartFinishGap * layout.Width
		check(checks, "start_finish_gap", gap, need, gap >= need)
	end
	if expect.StraightEndsMin then
		local segs = spec.Segments
		local first, last = segs[1], segs[#segs]
		local okFirst = first ~= nil and first.Type == "Straight" and (first.Length or 0) >= expect.StraightEndsMin
		local okLast = last ~= nil and last.Type == "Straight" and (last.Length or 0) >= expect.StraightEndsMin
		check(checks, "first_segment_straight", first and first.Length or 0, expect.StraightEndsMin, okFirst)
		check(checks, "last_segment_straight", last and last.Length or 0, expect.StraightEndsMin, okLast)
	end
	if expect.Checkpoint then
		checkCheckpoint(checks, spec, layout, expect)
	end
	checkTrackCollision(checks, spec)

	local lap = Scenarios.lap(trackName, expect, label)
	for _, c in lap.checks do
		table.insert(checks, c)
	end
	return result(label, checks, lap.metrics)
end

-- Chain: tracks joined finish-to-start in Number order must connect and never overlap. Layout-only.
function Scenarios.chain()
	local checks = {}
	local specs = type(TrackRegistry.Chain) == "function" and TrackRegistry.Chain() or {}
	check(checks, "chain_length", #specs, 2, #specs >= 2)
	check(checks, "track_lift", TrackBuilder.TRACK_LIFT or -1, 1, TrackBuilder.TRACK_LIFT == 1)
	if #specs < 2 or type(TrackBuilder.EndCFrame) ~= "function" then
		check(checks, "end_cframe_api", 0, 1, false)
		return result("chain", checks, {})
	end

	local seen, unique = {}, true
	for _, spec in specs do
		if seen[spec.Number] then
			unique = false
		end
		seen[spec.Number] = true
	end
	check(checks, "unique_numbers", unique and 1 or 0, 1, unique)

	local tracks = {}
	local origin = CFrame.new(0, TrackBuilder.TRACK_LIFT or 0, 0)
	local racePathsOk = type(TrackBuilder.RacePath) == "function"
	for i, spec in specs do
		local layout = TrackBuilder.Layout(spec)
		local world = table.create(#layout.Waypoints)
		for j, p in layout.Waypoints do
			world[j] = origin:PointToWorldSpace(p)
		end
		local raceWorld = {}
		if racePathsOk then
			local okRP, rp = pcall(TrackBuilder.RacePath, layout)
			if okRP and type(rp) == "table" and type(rp.Waypoints) == "table" and #rp.Waypoints >= 2 then
				for j, p in rp.Waypoints do
					raceWorld[j] = origin:PointToWorldSpace(p)
				end
			else
				racePathsOk = false
			end
		end
		tracks[i] = {
			Layout = layout,
			Points = world,
			Race = raceWorld,
			End = origin:PointToWorldSpace(layout.EndPosition),
		}
		origin = TrackBuilder.EndCFrame(layout, origin)
	end
	check(checks, "chain_race_paths", racePathsOk and 1 or 0, 1, racePathsOk)

	local worstJoint = 0
	for i = 1, #tracks - 1 do
		local a, b = tracks[i].Points, tracks[i + 1].Points
		worstJoint = math.max(worstJoint, (b[1] - a[#a]).Magnitude)
	end
	check(checks, "tracks_connect", worstJoint, 1, worstJoint <= 1)

	-- The race path must join too: track N's path ends where track N+1's path starts, heading straight on.
	if racePathsOk then
		local worstRaceJoint, worstRaceTurn = 0, 1
		for i = 1, #tracks - 1 do
			local a, b = tracks[i].Race, tracks[i + 1].Race
			worstRaceJoint = math.max(worstRaceJoint, (b[1] - a[#a]).Magnitude)
			local into = flatV(a[#a] - a[#a - 1])
			local out = flatV(b[2] - b[1])
			if into.Magnitude > 0 and out.Magnitude > 0 then
				worstRaceTurn = math.min(worstRaceTurn, into.Unit:Dot(out.Unit))
			else
				worstRaceTurn = -1
			end
		end
		check(checks, "race_paths_connect", worstRaceJoint, 1, worstRaceJoint <= 1)
		check(checks, "race_paths_heading_continuous", worstRaceTurn, 0.99, worstRaceTurn >= 0.99)
	else
		check(checks, "race_paths_connect", -1, 1, false)
		check(checks, "race_paths_heading_continuous", -1, 0.99, false)
	end

	-- Heading continuity: the next track must leave in the direction the previous one arrived
	-- (a joint that only matches by position could still turn the road 90 degrees).
	local worstTurn = 1
	for i = 1, #tracks - 1 do
		local a, b = tracks[i].Points, tracks[i + 1].Points
		if #a >= 2 and #b >= 2 then
			local into = (a[#a] - a[#a - 1]) * Vector3.new(1, 0, 1)
			local out = (b[2] - b[1]) * Vector3.new(1, 0, 1)
			if into.Magnitude > 0 and out.Magnitude > 0 then
				worstTurn = math.min(worstTurn, into.Unit:Dot(out.Unit))
			else
				worstTurn = -1
			end
		end
	end
	check(checks, "joint_heading_continuous", worstTurn, 0.99, worstTurn >= 0.99)

	-- Overlap: centre waypoints AND race-path waypoints of different tracks stay a road width + 8 apart
	-- (except near the joint they share).
	local minClear, clearOk = math.huge, true
	for i = 1, #tracks do
		for j = i + 1, #tracks do
			local need = math.max(tracks[i].Layout.Width, tracks[j].Layout.Width) + 8
			local pa, pb = table.clone(tracks[i].Points), table.clone(tracks[j].Points)
			table.move(tracks[i].Race, 1, #tracks[i].Race, #pa + 1, pa)
			table.move(tracks[j].Race, 1, #tracks[j].Race, #pb + 1, pb)
			local joint = j == i + 1 and tracks[i].End or nil
			for _, p in pa do
				if not joint or (p - joint).Magnitude > 60 then
					for _, q in pb do
						if not joint or (q - joint).Magnitude > 60 then
							local d = (p - q).Magnitude
							minClear = math.min(minClear, d)
							if d < need then
								clearOk = false
							end
						end
					end
				end
			end
		end
	end
	check(checks, "chain_no_overlap", minClear == math.huge and -1 or minClear, 44, clearOk)

	-- Apron clear: nothing else drives through a track's wide checkpoint area. Waypoints more than 100
	-- studs of path from a finish point F (own track: before F; next track: after its start) must stay
	-- outside the apron (Width/2 + APRON) plus a road half-width and a 4 stud margin.
	local APRON = TrackBuilder.CHECKPOINT_APRON
	local apronOk = type(APRON) == "number"
	local worstApron = math.huge
	if apronOk then
		local arcs = {}
		for i, t in tracks do
			local a = table.create(#t.Points, 0)
			for k = 2, #t.Points do
				a[k] = a[k - 1] + (t.Points[k] - t.Points[k - 1]).Magnitude
			end
			arcs[i] = a
		end
		for i = 1, #tracks do
			local F = tracks[i].End
			for j = 1, #tracks do
				local need = tracks[i].Layout.Width / 2 + APRON + tracks[j].Layout.Width / 2 + 4
				for k, p in tracks[j].Points do
					local skip = false
					if j == i then
						skip = arcs[j][#arcs[j]] - arcs[j][k] <= 100
					elseif j == i + 1 then
						skip = arcs[j][k] <= 100
					end
					if not skip then
						local d = (p - F).Magnitude
						worstApron = math.min(worstApron, d - need)
					end
				end
			end
		end
	end
	check(checks, "apron_clear", worstApron == math.huge and -1 or worstApron, 0, apronOk and worstApron >= 0)
	return result("chain", checks, { tracks = #tracks })
end

-- Money: MoneyService contract (cooldown, award validation, server-side pad payout).
function Scenarios.money()
	local checks = {}
	local serverFolder = script.Parent.Parent
	local moduleScript = serverFolder:FindFirstChild("MoneyService")
	local ok, Money = false, nil
	if moduleScript then
		ok, Money = pcall(require, moduleScript)
	end
	check(checks, "money_service_exists", ok and type(Money) == "table" and 1 or 0, 1, ok and type(Money) == "table")
	if not (ok and type(Money) == "table") then
		return result("money", checks, {})
	end

	local cleanup = {}
	local function track(inst)
		table.insert(cleanup, inst)
		return inst
	end
	local function balanceOf(player)
		local stats = player:FindFirstChild("leaderstats")
		local m = stats and stats:FindFirstChild("Money")
		return m and m.Value or -1
	end
	local function buildPad(name, x)
		local spec = TrackRegistry.Get(name)
		if not spec then
			return nil, nil
		end
		local model = track(TrackBuilder.Build(spec, CFrame.new(LAP_ORIGIN + Vector3.new(x, 0, -9000))))
		model.Parent = Workspace
		return model:FindFirstChild("WinPad", true), spec
	end

	local cooldown = Money.COOLDOWN
	check(
		checks,
		"money_cooldown_positive",
		type(cooldown) == "number" and cooldown or -1,
		0,
		type(cooldown) == "number" and cooldown > 0 and cooldown < math.huge
	)
	cooldown = type(cooldown) == "number" and cooldown > 0 and cooldown or 1

	local player = track(Instance.new("Folder"))
	player.Name = "CarTestFakePlayer"
	player.Parent = Workspace
	Money.Setup(player)
	Money.Setup(player) -- idempotent
	local stats = player:FindFirstChild("leaderstats")
	local money = stats and stats:FindFirstChild("Money")
	check(
		checks,
		"leaderstats_folder",
		stats and stats:IsA("Folder") and 1 or 0,
		1,
		stats ~= nil and stats:IsA("Folder")
	)
	check(
		checks,
		"money_is_intvalue",
		money and money:IsA("IntValue") and 1 or 0,
		1,
		money ~= nil and money:IsA("IntValue")
	)
	check(checks, "money_starts_zero", balanceOf(player), 0, balanceOf(player) == 0)
	local count = 0
	for _, child in player:GetChildren() do
		if child.Name == "leaderstats" then
			count += 1
		end
	end
	check(checks, "setup_idempotent", count, 1, count == 1)

	-- Award validation
	local before = balanceOf(player)
	local bad = { -5, 0, 0 / 0, math.huge, 2e9, "100", true }
	local allRejected = true
	for _, v in bad do
		local r = Money.Award(player, v)
		if r ~= nil or balanceOf(player) ~= before then
			allRejected = false
		end
	end
	check(checks, "award_rejects_invalid", allRejected and 1 or 0, 1, allRejected)
	local paid = Money.Award(player, 25)
	check(
		checks,
		"award_valid_returns_balance",
		paid or -1,
		before + 25,
		paid == before + 25 and balanceOf(player) == before + 25
	)

	-- Pad payout
	local pad1, spec1 = buildPad("Oval", 0)
	local pad2, spec2 = buildPad("Hill", 400)
	check(checks, "money_pads_exist", (pad1 and pad2) and 1 or 0, 1, pad1 ~= nil and pad2 ~= nil)
	if pad1 and pad2 and type(TrackBuilder.CashFor) == "function" then
		local want1 = TrackBuilder.CashFor(spec1.Number)
		local want2 = TrackBuilder.CashFor(spec2.Number)
		local t0 = 1000
		local p1 = Money.Collect(player, pad1, t0)
		check(checks, "collect_pays_pad_cash", p1 or -1, want1, want1 >= 1 and p1 == want1)
		check(checks, "collect_adds_to_balance", balanceOf(player), 25 + want1, balanceOf(player) == 25 + want1)
		local p1b = Money.Collect(player, pad1, t0 + cooldown * 0.5)
		check(checks, "collect_cooldown_blocks", p1b or -1, 0, p1b == 0)
		check(checks, "cooldown_no_balance_change", balanceOf(player), 25 + want1, balanceOf(player) == 25 + want1)
		local p1c = Money.Collect(player, pad1, t0 + cooldown + 0.01)
		check(checks, "collect_after_cooldown_pays", p1c or -1, want1, p1c == want1)

		-- cooldown is per pad: another pad pays immediately
		local p2 = Money.Collect(player, pad2, t0 + cooldown + 0.02)
		check(
			checks,
			"track2_pays_double_track1",
			p2 or -1,
			2 * want1,
			want1 >= 1 and want2 == 2 * want1 and p2 == 2 * want1
		)

		-- cooldown is per player
		local other = track(Instance.new("Folder"))
		other.Name = "CarTestFakePlayer2"
		other.Parent = Workspace
		Money.Setup(other)
		local po = Money.Collect(other, pad1, t0 + cooldown + 0.03)
		check(checks, "cooldown_is_per_player", po or -1, want1, po == want1 and balanceOf(other) == want1)

		-- Untagged / cashless pads pay nothing
		local before2 = balanceOf(player)
		local fake = track(Instance.new("Part"))
		fake.Anchored = true
		fake:SetAttribute("Cash", 500)
		fake.Parent = Workspace
		local pf = Money.Collect(player, fake, t0 + 10 * cooldown)
		check(checks, "collect_untagged_pays_zero", pf or -1, 0, pf == 0 and balanceOf(player) == before2)
		fake:AddTag("WinPad")
		fake:SetAttribute("Cash", nil)
		local pn = Money.Collect(player, fake, t0 + 20 * cooldown)
		check(checks, "collect_no_cash_pays_zero", pn or -1, 0, pn == 0 and balanceOf(player) == before2)
		fake:SetAttribute("Cash", -50)
		local pneg = Money.Collect(player, fake, t0 + 30 * cooldown)
		check(checks, "collect_negative_cash_pays_zero", pneg or -1, 0, pneg == 0 and balanceOf(player) == before2)

		-- Huge or non-numeric Cash on a pad (tampered attribute) pays nothing
		for i, bogus in { 2e9, 1e9 + 1, math.huge, 0 / 0, "500", true } do
			fake:SetAttribute("Cash", bogus)
			local pb = Money.Collect(player, fake, t0 + (40 + i) * cooldown)
			local name = "collect_bogus_cash_pays_zero_" .. i
			check(checks, name, pb or -1, 0, pb == 0 and balanceOf(player) == before2)
		end
		-- a huge tamper on a real track pad is also ignored, for a fresh player
		local victim = track(Instance.new("Folder"))
		victim.Name = "CarTestFakePlayer3"
		victim.Parent = Workspace
		Money.Setup(victim)
		pad1:SetAttribute("Cash", 2e9)
		local ph = Money.Collect(victim, pad1, t0 + 100 * cooldown)
		check(checks, "collect_huge_cash_ignored", ph or -1, 0, ph == 0 and balanceOf(victim) == 0)
		-- a rejected collect must not start the cooldown
		pad1:SetAttribute("Cash", want1)
		local pr = Money.Collect(victim, pad1, t0 + 100 * cooldown + 0.001)
		check(checks, "rejected_collect_no_cooldown", pr or -1, want1, pr == want1 and balanceOf(victim) == want1)

		-- Fractional amounts: balance stays whole, reported == actually paid
		local fb = balanceOf(player)
		local fr = Money.Award(player, 2.7)
		check(checks, "award_fraction_floors", fr or -1, fb + 2, fr == fb + 2 and balanceOf(player) == fb + 2)
		fb = balanceOf(player)
		local tiny = Money.Award(player, 0.5)
		check(checks, "award_subunit_rejected", tiny == nil and 1 or 0, 1, tiny == nil and balanceOf(player) == fb)
		fake:SetAttribute("Cash", 7.9)
		local pfr = Money.Collect(player, fake, t0 + 200 * cooldown)
		check(checks, "collect_fraction_reported_equals_paid", pfr or -1, 7, pfr == 7 and balanceOf(player) == fb + 7)
		fb = balanceOf(player)
		fake:SetAttribute("Cash", 0.5)
		local psub = Money.Collect(player, fake, t0 + 300 * cooldown)
		check(checks, "collect_subunit_cash_pays_zero", psub or -1, 0, psub == 0 and balanceOf(player) == fb)
	else
		check(checks, "cash_api", 0, 1, false)
	end

	-- PlayerFromPart: unrelated parts resolve to nil
	local stray = track(Instance.new("Part"))
	stray.Parent = Workspace
	check(
		checks,
		"player_from_stray_part_nil",
		Money.PlayerFromPart(stray) == nil and 1 or 0,
		1,
		Money.PlayerFromPart(stray) == nil
	)
	local car = track(Instance.new("Model"))
	car:SetAttribute("Owner", -987654321) -- no such player connected
	local carPart = Instance.new("Part")
	carPart.Parent = car
	car.Parent = Workspace
	check(
		checks,
		"player_from_unowned_car_nil",
		Money.PlayerFromPart(carPart) == nil and 1 or 0,
		1,
		Money.PlayerFromPart(carPart) == nil
	)

	for _, inst in cleanup do
		inst:Destroy()
	end
	return result("money", checks, {})
end

local RACE_ORIGIN = Vector3.new(-20000, 0, 20000)
local RACE_LOOKAHEAD_FLAT = 30 -- studs of path that must be level for a "flat straight" sample
local RACE_LOOKAHEAD_STRAIGHT = 80 -- studs of path that must be curvature-free for a sample
local RACE_MIN_SAMPLES = 30

local function tryRequire(parent, name)
	local module = parent:FindFirstChild(name)
	if not module then
		return nil
	end
	local ok, res = pcall(require, module)
	if ok and type(res) == "table" then
		return res
	end
	return nil
end

local function serverModule(name)
	return tryRequire(script.Parent.Parent, name)
end

local function sharedModule(name)
	return tryRequire(Shared, name)
end

-- Distance from point p to the polyline through pts, looking only at segments lo..hi (3D). Returns distance,
-- the segment index, the closest point and the segment direction.
local function nearestOnPolyline(pts, p, lo, hi)
	local bestD, bestI, bestQ, bestDir = math.huge, lo, pts[lo], Vector3.zero
	for i = math.max(lo, 1), math.min(hi, #pts - 1) do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local len2 = ab:Dot(ab)
		if len2 > 1e-6 then
			local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
			local q = a + ab * t
			local d = (p - q).Magnitude
			if d < bestD then
				bestD, bestI, bestQ, bestDir = d, i, q, ab
			end
		end
	end
	return bestD, bestI, bestQ, bestDir
end

-- Stability, route and lane checks for one race drive `st` (see Scenarios.race drive()). `prefix` names them.
local function checkStability(checks, prefix, st)
	local R = PhysicsTargets.race or {}
	local minUp = R.MinUpY or 1
	local maxDev = R.MaxPathDeviation or 0
	local spacing = 12 -- TrackBuilder WAYPOINT_SPACING: the driver's nearest-waypoint distance is up to half of it
	local pre = prefix == "race" and "race_" or (prefix .. "_")
	local rm = type(st.runMinUpY) == "number" and st.runMinUpY or -1
	check(checks, pre .. "never_tilted", rm, minUp, R.MinUpY ~= nil and rm >= minUp)
	check(checks, pre .. "body_never_tilted", st.minUpOwn, minUp, R.MinUpY ~= nil and st.minUpOwn >= minUp)
	local rec = type(st.recoveries) == "number" and st.recoveries or -1
	check(checks, pre .. "no_flip_recoveries", rec, 0, rec == 0)
	check(checks, pre .. "flips_limit", st.flips, R.MaxFlips or 0, R.MaxFlips ~= nil and st.flips <= R.MaxFlips)
	check(checks, pre .. "sticks_to_path", st.dev, maxDev, R.MaxPathDeviation ~= nil and st.dev <= maxDev)
	check(checks, pre .. "sticks_to_path_track1", st.dev1, maxDev, R.MaxPathDeviation ~= nil and st.dev1 <= maxDev)
	check(checks, pre .. "sticks_to_path_track2", st.dev2, maxDev, R.MaxPathDeviation ~= nil and st.dev2 <= maxDev)
	-- run.MaxPathDeviation (driver.DistanceToCenter, nearest waypoint) must be reported and consistent with ours
	local rd = type(st.runMaxDev) == "number" and st.runMaxDev or -1
	check(
		checks,
		pre .. "run_reports_path_deviation",
		rd,
		maxDev + spacing / 2,
		rd >= 0 and rd >= st.dev - 0.5 and rd <= maxDev + spacing / 2
	)
	-- lane: right of the road centre line on straights, never on or across the centre line
	local mean = st.laneN > 0 and st.laneSum / st.laneN or -99
	check(checks, pre .. "drives_right_of_centre", mean, 10, st.laneN >= RACE_MIN_SAMPLES and mean >= 7 and mean <= 13)
	local minS = st.minSigned == math.huge and -99 or st.minSigned
	check(checks, pre .. "never_left_of_centre", minS, 0, st.minSigned ~= math.huge and minS > 0)
end

-- Auto race on the Speed stat economy: the real chain (Oval then Hill) driven by RaceService's PathDriver at
-- RaceConfig.SpeedFor(stat). The stat grows while driving (GainPerSecond of the ACTUAL speed) and the target follows it.
-- Entries given to RaceService.BuildRoute / PathDriver.Chain are { Layout, Origin, Model, Number }.
function Scenarios.race()
	local T = PhysicsTargets.lap
	local checks = {}
	local RaceService = serverModule("RaceService")
	local RaceConfig = sharedModule("RaceConfig")
	local PathDriver = sharedModule("PathDriver")
	local Money = serverModule("MoneyService")
	local PlayerData = serverModule("PlayerData")
	local apiOk = RaceService ~= nil
		and RaceConfig ~= nil
		and PathDriver ~= nil
		and Money ~= nil
		and PlayerData ~= nil
		and type(RaceService.BuildRoute) == "function"
		and type(RaceService.NewRun) == "function"
		and type(RaceConfig.SpeedFor) == "function"
		and type(RaceConfig.GainPerSecond) == "function"
		and type(RaceConfig.HALF_STAT) == "number"
		and type(RaceConfig.GAIN_SOFT) == "number"
		and type(PlayerData.Setup) == "function"
		and type(PlayerData.SpeedStat) == "function"
		and type(PlayerData.AddSpeed) == "function"
		and type(PathDriver.Chain) == "function"
		and type(TrackBuilder.CashFor) == "function"
	check(checks, "race_api_exists", apiOk and 1 or 0, 1, apiOk)
	local specs = type(TrackRegistry.Chain) == "function" and TrackRegistry.Chain() or {}
	check(checks, "race_chain_has_two_tracks", #specs, 2, #specs >= 2)
	if not apiOk or #specs < 2 then
		return result("race", checks, {})
	end

	local HALF = RaceConfig.HALF_STAT
	local BIG = 10 * RaceConfig.GAIN_SOFT
	local targetHalf = RaceConfig.SpeedFor(HALF)
	if type(targetHalf) ~= "number" then
		check(checks, "race_speed_for_number", 0, 1, false)
		return result("race", checks, {})
	end

	local models = {}
	local entries = {}
	local origin = CFrame.new(RACE_ORIGIN + Vector3.new(0, TrackBuilder.TRACK_LIFT or 0, 0))
	for i = 1, 2 do
		local model, layout = TrackBuilder.Build(specs[i], origin)
		model.Name = "CarTestRaceTrack" .. i
		model.Parent = Workspace
		table.insert(models, model)
		entries[i] = { Layout = layout, Origin = origin, Model = model, Number = specs[i].Number }
		origin = TrackBuilder.EndCFrame(layout, origin)
	end
	local function cleanup()
		for _, m in models do
			m:Destroy()
		end
	end

	local okRoute, route = pcall(RaceService.BuildRoute, entries)
	local routeOk = okRoute
		and type(route) == "table"
		and type(route.Path) == "table"
		and type(route.Path.WorldWaypoints) == "table"
		and type(route.Path.Curvature) == "table"
		and type(route.Pads) == "table"
	check(checks, "route_built", routeOk and 1 or 0, 1, routeOk)
	if not routeOk then
		cleanup()
		return result("race", checks, {})
	end
	check(checks, "route_has_two_pads", #route.Pads, 2, #route.Pads == 2)

	local wps, curv = route.Path.WorldWaypoints, route.Path.Curvature
	local n = #wps
	local totalLen = 0
	for i = 2, n do
		totalLen += (wps[i] - wps[i - 1]).Magnitude
	end
	-- per waypoint: is the road ahead a flat straight (curvature 0 and level), so speed must equal target
	local flatAhead = table.create(n, false)
	for i = 1, n do
		local acc, k, level, straight = 0, i, true, curv[i] == 0
		while k < n and acc < RACE_LOOKAHEAD_STRAIGHT do
			acc += (wps[k + 1] - wps[k]).Magnitude
			k += 1
			if curv[k] ~= 0 then
				straight = false
			end
			if acc <= RACE_LOOKAHEAD_FLAT and math.abs(wps[k].Y - wps[i].Y) >= 1 then
				level = false
			end
		end
		flatAhead[i] = straight and level and acc >= RACE_LOOKAHEAD_STRAIGHT - 0.01
	end
	local joint = TrackBuilder.EndCFrame(entries[1].Layout, entries[1].Origin).Position
	local startCF = entries[1].Model.Start.CFrame + Vector3.new(0, CarConfig.RestHeight, 0)
	local padPositions = {}
	for _, m in models do
		local pad = m:FindFirstChild("WinPad", true)
		if pad and pad:IsA("BasePart") then
			table.insert(padPositions, pad.Position)
		end
	end

	-- One drive along the route from a given starting stat. Always cleans up its car and player.
	-- The road centre line of the whole chain (world space) and its curvature, to measure the lane position.
	local centre, centreCurv = {}, {}
	for i, entry in entries do
		local lw = entry.Layout.Waypoints
		for k = (i == 1 and 1 or 2), #lw do
			table.insert(centre, entry.Origin:PointToWorldSpace(lw[k]))
			table.insert(centreCurv, entry.Layout.Curvature[k])
		end
	end
	-- first route waypoint at or after the joint between the two tracks (splits the deviation per track)
	local splitIdx = 1
	do
		local best = math.huge
		for i = 1, n do
			local d = (wps[i] - joint).Magnitude
			if d < best then
				best, splitIdx = d, i
			end
		end
	end

	local function drive(startStat, seconds, untilFinished)
		local car = CarFactory.build(CarConfig)
		car.Name = "CarTestRaceCar"
		car:PivotTo(startCF)
		car.Parent = Workspace
		local player = Instance.new("Folder")
		player.Name = "CarTestRacePlayer"
		player.Parent = Workspace
		local st = {
			ok = false,
			flips = 0,
			maxStuck = 0,
			maxSpeed = 0,
			maxTarget = 0,
			targetSum = 0,
			targetN = 0,
			flatSum = 0,
			flatTargetSum = 0,
			flatN = 0,
			jointMin = math.huge,
			speedAt8 = nil,
			startStat = startStat,
			integral = 0,
			minPadDist = math.huge,
			distinct = {},
			distinctCount = 0,
			monotonic = true,
			minUpOwn = 1,
			dev = 0,
			dev1 = 0,
			dev2 = 0,
			laneSum = 0,
			laneN = 0,
			minSigned = math.huge,
			maxSigned = -math.huge,
		}
		local okSetup = pcall(function()
			Money.Setup(player)
			PlayerData.Setup(player)
			player.leaderstats.Speed.Value = startStat
		end)
		local speedValue = okSetup
			and player:FindFirstChild("leaderstats")
			and player.leaderstats:FindFirstChild("Speed")
		if not speedValue then
			st.err = "no leaderstats.Speed after PlayerData.Setup"
			car:Destroy()
			player:Destroy()
			return st
		end
		local okRun, run = pcall(RaceService.NewRun, car, route, player, nil)
		if not okRun or type(run) ~= "table" then
			st.err = tostring(run)
			car:Destroy()
			player:Destroy()
			return st
		end
		st.ok = true
		st.initialTarget = run.TargetSpeed
		local chassis = car.PrimaryPart
		st.autoRace = car:GetAttribute("AutoRace") == true
		local seatPart = car:FindFirstChild("DriverSeat")
		st.seatDisabled = seatPart ~= nil and seatPart.Disabled == true
		local okOwner, owner = pcall(function()
			return chassis:GetNetworkOwner()
		end)
		st.serverOwned = okOwner and owner == nil
		local idx, stuck, flippedFor, wasFlipped = 1, 0, 0, false
		local cIdx = 1
		local lastStat = speedValue.Value
		st.elapsed = frames(seconds, function(t, dt)
			local pos = chassis.Position
			local speed = chassis.AssemblyLinearVelocity.Magnitude
			local bestD = math.huge
			for i = idx, math.min(idx + 25, n) do
				local d = (wps[i] - pos).Magnitude
				if d < bestD then
					bestD, idx = d, i
				end
			end
			local target = type(run.TargetSpeed) == "number" and run.TargetSpeed or 0
			st.maxSpeed = math.max(st.maxSpeed, speed)
			st.maxTarget = math.max(st.maxTarget, target)
			st.targetSum += target
			st.targetN += 1
			if t >= 8 and st.speedAt8 == nil then
				st.speedAt8 = speed
				st.gainAt8 = speedValue.Value - startStat
			end
			-- our own integral of the gain formula using the committed stat and the ACTUAL speed
			local g = RaceConfig.GainPerSecond(speedValue.Value, speed)
			if type(g) == "number" and g == g then
				st.integral += g * dt
			end
			local now = speedValue.Value
			if now < lastStat - 1e-9 then
				st.monotonic = false
			end
			lastStat = now
			if not st.distinct[now] then
				st.distinct[now] = true
				st.distinctCount += 1
			end
			for _, pp in padPositions do
				local d = Vector3.new(pos.X - pp.X, 0, pos.Z - pp.Z).Magnitude
				st.minPadDist = math.min(st.minPadDist, d)
			end
			if t > 3 then
				if flatAhead[idx] then
					st.flatSum += speed
					st.flatTargetSum += target
					st.flatN += 1
				end
				if (pos - joint).Magnitude <= 40 then
					st.jointMin = math.min(st.jointMin, speed)
				end
				if speed < 1 and idx > 1 then
					stuck += dt
					st.maxStuck = math.max(st.maxStuck, stuck)
				else
					stuck = 0
				end
			end
			local upY = chassis.CFrame.UpVector.Y
			local inLoop = run.Physics and run.Physics.LoopAssist
			if not inLoop then
				st.minUpOwn = math.min(st.minUpOwn, upY)
			end
			if t > 3 then
				-- how far the car is from the route (to the nearest SEGMENT, not just the nearest waypoint)
				local dist, seg = nearestOnPolyline(wps, pos, math.max(idx - 3, 1), math.min(idx + 3, n - 1))
				st.dev = math.max(st.dev, dist)
				if seg < splitIdx then
					st.dev1 = math.max(st.dev1, dist)
				else
					st.dev2 = math.max(st.dev2, dist)
				end
				-- signed lateral position against the ROAD centre line: positive = right of centre
				local _, ci, q, dir =
					nearestOnPolyline(centre, pos, math.max(cIdx - 3, 1), math.min(cIdx + 25, #centre - 1))
				cIdx = ci
				local f = flatV(dir)
				if f.Magnitude > 1e-6 then
					local signed = flatV(pos - q):Dot(f.Unit:Cross(Vector3.yAxis))
					st.minSigned = math.min(st.minSigned, signed)
					st.maxSigned = math.max(st.maxSigned, signed)
					local straight = true
					for k = math.max(ci - 2, 1), math.min(ci + 4, #centre) do
						if centreCurv[k] ~= 0 then
							straight = false
						end
					end
					if straight then
						st.laneSum += signed
						st.laneN += 1
					end
				end
			end
			if upY < T.MinUpY then
				flippedFor += dt
				if not wasFlipped and flippedFor > 1 then
					st.flips += 1
					wasFlipped = true
				end
			else
				flippedFor, wasFlipped = 0, false
			end
			if untilFinished and run.Finished == true then
				return "stop"
			end
		end)
		if untilFinished then
			frames(1) -- linger by the last pad: the cooldown must stop a second payout
		end
		st.finished = run.Finished == true
		st.runMinUpY = run.MinUpY
		st.runMaxDev = run.MaxPathDeviation
		st.recoveries = run.FlipRecoveries
		st.payouts = run.Payouts
		st.paidTotal = run.PaidTotal
		st.offTrack = run.OffTrackSeconds
		st.targetSpeed = run.TargetSpeed
		st.runGained = run.Gained
		st.finalStat = speedValue.Value
		st.statViaApi = PlayerData.SpeedStat(player)
		local money = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Money")
		st.balance = money and money.Value or -1
		st.unbanked = run.Unbanked
		st.unbankedAttr = player:GetAttribute("Unbanked")
		pcall(function()
			run:Destroy()
		end)
		st.balanceAfterDestroy = money and money.Value or -1
		car:Destroy()
		player:Destroy()
		return st
	end

	local timeout = totalLen / (0.5 * targetHalf) + 40
	local fast = drive(HALF, timeout, true)
	check(checks, "run_started", fast.ok and 1 or 0, 1, fast.ok)
	if fast.ok then
		local want1, want2 = TrackBuilder.CashFor(1), TrackBuilder.CashFor(2)
		local meanTarget = fast.targetN > 0 and fast.targetSum / fast.targetN or targetHalf
		check(checks, "finished", fast.finished and 1 or 0, 1, fast.finished)
		check(checks, "flips", fast.flips, T.MaxFlips, fast.flips <= T.MaxFlips)
		checkStability(checks, "race", fast)
		local off = type(fast.offTrack) == "number" and fast.offTrack or math.huge
		check(checks, "off_track_seconds", off, T.MaxOffTrackSeconds, off <= T.MaxOffTrackSeconds)
		check(checks, "stuck_seconds", fast.maxStuck, 4, fast.maxStuck <= 4)
		check(
			checks,
			"run_initial_target",
			fast.initialTarget or -1,
			targetHalf,
			type(fast.initialTarget) == "number" and math.abs(fast.initialTarget - targetHalf) <= 0.01
		)
		local mean = fast.flatN > 0 and fast.flatSum / fast.flatN or 0
		local meanFlatTarget = fast.flatN > 0 and fast.flatTargetSum / fast.flatN or targetHalf
		check(
			checks,
			"speed_held",
			mean,
			meanFlatTarget,
			fast.flatN >= RACE_MIN_SAMPLES and math.abs(mean - meanFlatTarget) <= 0.1 * meanFlatTarget
		)
		check(checks, "speed_held_samples", fast.flatN, RACE_MIN_SAMPLES, fast.flatN >= RACE_MIN_SAMPLES)
		check(checks, "max_speed_cap", fast.maxSpeed, fast.maxTarget * 1.15, fast.maxSpeed <= fast.maxTarget * 1.15)
		check(
			checks,
			"paid_once_per_pad",
			fast.payouts or -1,
			2,
			fast.payouts == 2 and fast.balance == want1 + want2 and fast.paidTotal == want1 + want2
		)
		-- SPAWN_AND_ROLLS_SPEC section 3: banking is NPC mode only; a run without NPC pays pads directly, so it
		-- never banks and its Destroy has nothing left to pay
		local noBank = (fast.unbanked == nil or fast.unbanked == 0)
			and (fast.unbankedAttr == nil or fast.unbankedAttr == 0)
		check(checks, "race_no_bank_without_npc", type(fast.unbanked) == "number" and fast.unbanked or 0, 0, noBank)
		check(
			checks,
			"race_destroy_pays_nothing_more",
			fast.balanceAfterDestroy - fast.balance,
			0,
			fast.balanceAfterDestroy == fast.balance
		)
		local jm = fast.jointMin == math.huge and -1 or fast.jointMin
		check(
			checks,
			"joint_ok",
			jm,
			0.5 * meanTarget,
			fast.jointMin ~= math.huge and fast.jointMin >= 0.5 * meanTarget
		)
		check(checks, "autorace_attr", fast.autoRace and 1 or 0, 1, fast.autoRace)
		-- Disabling a VehicleSeat ejects whoever sits in it (the hidden character would fall off the car and
		-- the camera would lose it). The server ignores seat input anyway, so the seat must stay enabled.
		check(checks, "seat_not_disabled", fast.seatDisabled and 1 or 0, 0, fast.seatDisabled == false)
		check(checks, "server_owned", fast.serverOwned and 1 or 0, 1, fast.serverOwned)

		-- The pad is beside the racing line: the money comes from passing it, the car never drives over it.
		local mp = fast.minPadDist == math.huge and -1 or fast.minPadDist
		check(checks, "car_never_on_pad", mp, 12, #padPositions == 2 and fast.minPadDist > 12)

		-- Speed stat economy
		local gained = (fast.finalStat or 0) - HALF
		check(checks, "speed_stat_gains", gained, 0, gained > 0)
		local lo, hi = 0.8 * fast.integral, 1.2 * fast.integral
		check(
			checks,
			"gain_matches_speed_integral",
			gained,
			fast.integral,
			fast.integral > 0 and gained >= lo and gained <= hi
		)
		local rg = type(fast.runGained) == "number" and fast.runGained or -1
		check(checks, "run_gained_matches_stat", rg, gained, rg >= 0 and math.abs(rg - gained) <= 0.05 * gained + 0.5)
		local wantTarget = RaceConfig.SpeedFor(fast.finalStat)
		check(
			checks,
			"target_follows_stat",
			fast.targetSpeed or -1,
			wantTarget,
			type(fast.targetSpeed) == "number"
				and type(wantTarget) == "number"
				and math.abs(fast.targetSpeed - wantTarget) <= 0.5
		)
		check(checks, "stat_commit_granular", fast.distinctCount, 50, fast.distinctCount >= 50 and fast.monotonic)
		check(
			checks,
			"stat_api_matches_value",
			fast.statViaApi or -1,
			fast.finalStat or -1,
			type(fast.statViaApi) == "number"
				and type(fast.finalStat) == "number"
				and math.abs(fast.statViaApi - fast.finalStat) <= 1e-3
		)
	end

	-- User: the car also stays on the road, upright and in its lane at MAXIMUM stat speed (~75 studs/s).
	if fast.ok then
		local targetMax = RaceConfig.SpeedFor(RaceConfig.MAX_STAT)
		local maxRun = drive(RaceConfig.MAX_STAT, totalLen / (0.5 * targetMax) + 40, true)
		check(checks, "max_speed_run_started", maxRun.ok and 1 or 0, 1, maxRun.ok)
		if maxRun.ok then
			check(
				checks,
				"max_speed_target",
				maxRun.initialTarget or -1,
				targetMax,
				type(maxRun.initialTarget) == "number" and maxRun.initialTarget >= 0.98 * targetMax
			)
			check(checks, "max_speed_finished", maxRun.finished and 1 or 0, 1, maxRun.finished)
			check(checks, "max_speed_flips", maxRun.flips, T.MaxFlips, maxRun.flips <= T.MaxFlips)
			local off = type(maxRun.offTrack) == "number" and maxRun.offTrack or math.huge
			check(checks, "max_speed_off_track_seconds", off, T.MaxOffTrackSeconds, off <= T.MaxOffTrackSeconds)
			checkStability(checks, "max_speed", maxRun)
		end
	end

	-- Fresh player (stat 0) for 8 s: slower than the HALF_STAT run at 8 s, and it gains stat.
	local slow = drive(0, 8, false)
	check(checks, "slow_run_started", slow.ok and 1 or 0, 1, slow.ok)
	if slow.ok then
		check(
			checks,
			"slow_run_initial_target",
			slow.initialTarget or -1,
			RaceConfig.BASE_SPEED or -1,
			type(slow.initialTarget) == "number" and slow.initialTarget == RaceConfig.BASE_SPEED
		)
		local s0, sH = slow.speedAt8 or math.huge, fast.speedAt8 or -1
		check(
			checks,
			"stat_scales_speed_at_8s",
			s0,
			sH,
			fast.ok and slow.speedAt8 ~= nil and fast.speedAt8 ~= nil and s0 < sH
		)
		local g0 = slow.gainAt8 or -1
		check(checks, "fresh_player_gains", g0, 0, g0 > 0)

		-- Diminishing returns end to end: a player with a 10x larger stat drives faster yet gains LESS.
		local big = drive(BIG, 8, false)
		check(checks, "big_run_started", big.ok and 1 or 0, 1, big.ok)
		if big.ok then
			local gb = big.gainAt8 or math.huge
			check(checks, "diminishing_gain_in_8s", gb, g0, slow.gainAt8 ~= nil and big.gainAt8 ~= nil and gb < g0)
		end
	end

	cleanup()
	return result("race", checks, {
		target = round(targetHalf),
		routeLength = round(totalLen),
		elapsed = fast.elapsed and round(fast.elapsed) or -1,
		meanFlatSpeed = fast.flatN and fast.flatN > 0 and round(fast.flatSum / fast.flatN) or -1,
		statGained = fast.finalStat and round(fast.finalStat - HALF) or -1,
		speedIntegral = fast.integral and round(fast.integral) or -1,
	})
end

-- Flip recovery: a car that ends up upside down or on its side during a race must be put upright back on the
-- path by RaceService within PhysicsTargets.race.FlipRecoverySeconds, and keep racing.
local FLIP_RACE_ORIGIN = Vector3.new(-20000, 0, -20000)

function Scenarios.flip_recovery()
	local checks = {}
	local RaceService = serverModule("RaceService")
	local RaceConfig = sharedModule("RaceConfig")
	local PathDriver = sharedModule("PathDriver")
	local Money = serverModule("MoneyService")
	local PlayerData = serverModule("PlayerData")
	local R = PhysicsTargets.race
	local apiOk = RaceService ~= nil
		and RaceConfig ~= nil
		and PathDriver ~= nil
		and Money ~= nil
		and PlayerData ~= nil
		and R ~= nil
		and type(R.FlipRecoverySeconds) == "number"
		and type(R.MaxPathDeviation) == "number"
		and type(RaceService.BuildRoute) == "function"
		and type(RaceService.NewRun) == "function"
		and type(PlayerData.Setup) == "function"
	check(checks, "flip_api_exists", apiOk and 1 or 0, 1, apiOk)
	local specs = type(TrackRegistry.Chain) == "function" and TrackRegistry.Chain() or {}
	check(checks, "flip_chain_has_track", #specs, 1, #specs >= 1)
	if not apiOk or #specs < 1 then
		return result("flip_recovery", checks, {})
	end

	local origin = CFrame.new(FLIP_RACE_ORIGIN + Vector3.new(0, TrackBuilder.TRACK_LIFT or 0, 0))
	local model, layout = TrackBuilder.Build(specs[1], origin) -- the first track (the Oval)
	model.Name = "CarTestFlipTrack"
	model.Parent = Workspace
	local okRoute, route = pcall(RaceService.BuildRoute, {
		{ Layout = layout, Origin = origin, Model = model, Number = specs[1].Number },
	})
	local routeOk = okRoute and type(route) == "table" and type(route.Path) == "table"
	check(checks, "flip_route_built", routeOk and 1 or 0, 1, routeOk)
	if not routeOk then
		model:Destroy()
		return result("flip_recovery", checks, {})
	end
	local wps = route.Path.WorldWaypoints
	local startCF = model.Start.CFrame + Vector3.new(0, CarConfig.RestHeight, 0)
	local RECOVER = R.FlipRecoverySeconds

	-- roll: radians about the car's forward axis (pi = upside down, pi/2 = on its side)
	local function flipTest(tag, roll)
		local car = CarFactory.build(CarConfig)
		car.Name = "CarTestFlipCar"
		car:PivotTo(startCF)
		car.Parent = Workspace
		local player = Instance.new("Folder")
		player.Name = "CarTestFlipPlayer"
		player.Parent = Workspace
		local okSetup = pcall(function()
			Money.Setup(player)
			PlayerData.Setup(player)
			player.leaderstats.Speed.Value = RaceConfig.HALF_STAT
		end)
		local okRun, run = false, nil
		if okSetup then
			okRun, run = pcall(RaceService.NewRun, car, route, player, nil)
		end
		check(
			checks,
			tag .. "_run_started",
			okSetup and okRun and type(run) == "table" and 1 or 0,
			1,
			okSetup and okRun and type(run) == "table"
		)
		if not (okSetup and okRun and type(run) == "table") then
			car:Destroy()
			player:Destroy()
			return
		end
		local chassis = car.PrimaryPart
		local target = RaceConfig.SpeedFor(RaceConfig.HALF_STAT)
		frames(5)
		local speedBefore = chassis.AssemblyLinearVelocity.Magnitude
		check(checks, tag .. "_was_driving", speedBefore, 5, speedBefore > 5)
		local before = type(run.FlipRecoveries) == "number" and run.FlipRecoveries or 0

		local pivot = car:GetPivot()
		car:PivotTo(CFrame.new(pivot.Position + Vector3.new(0, 3, 0)) * pivot.Rotation * CFrame.Angles(0, 0, roll))
		chassis.AssemblyLinearVelocity = Vector3.zero
		chassis.AssemblyAngularVelocity = Vector3.zero
		local upAfter = chassis.CFrame.UpVector.Y
		check(checks, tag .. "_flip_applied", upAfter, 0.5, upAfter < 0.5)

		local tRecovery, tUpright, distAtUpright, idxAtUpright, tUprightAt = nil, nil, nil, nil, nil
		local peakAfter, idxEnd = 0, nil
		frames(RECOVER + 2 + 4 + 1, function(t)
			local rec = type(run.FlipRecoveries) == "number" and run.FlipRecoveries or 0
			if not tRecovery and rec > before then
				tRecovery = t
			end
			local up = chassis.CFrame.UpVector.Y
			if not tUpright and t > 0.05 and up >= 0.9 then
				tUpright, tUprightAt = t, t
				distAtUpright = nearestOnPolyline(wps, chassis.Position, 1, #wps - 1)
				idxAtUpright = run.Driver and run.Driver.Index or 0
			end
			if tUpright then
				if t - tUprightAt <= 4 then
					peakAfter = math.max(peakAfter, chassis.AssemblyLinearVelocity.Magnitude)
					idxEnd = run.Driver and run.Driver.Index or idxEnd
				end
			end
		end)
		local finalUp = chassis.CFrame.UpVector.Y
		check(
			checks,
			tag .. "_recovery_counted",
			tRecovery or -1,
			RECOVER,
			tRecovery ~= nil and tRecovery <= RECOVER + 0.05
		)
		check(checks, tag .. "_upright_again", tUpright or -1, RECOVER + 2, tUpright ~= nil and tUpright <= RECOVER + 2)
		check(
			checks,
			tag .. "_back_on_path",
			distAtUpright or -1,
			R.MaxPathDeviation + 3,
			distAtUpright ~= nil and distAtUpright <= R.MaxPathDeviation + 3
		)
		local progressed = (idxEnd or 0) - (idxAtUpright or 0)
		check(checks, tag .. "_keeps_progressing", progressed, 5, tUpright ~= nil and progressed >= 5)
		check(checks, tag .. "_keeps_driving", peakAfter, 0.5 * target, tUpright ~= nil and peakAfter > 0.5 * target)
		check(checks, tag .. "_ends_upright", finalUp, 0.9, finalUp >= 0.9)
		pcall(function()
			run:Destroy()
		end)
		car:Destroy()
		player:Destroy()
	end

	flipTest("upside_down", math.pi)
	flipTest("on_side", math.pi / 2)
	model:Destroy()
	return result("flip_recovery", checks, {})
end

-- Auto race toggle (the "Stop Auto" / "Auto Race" button). BRIEF (user): "Implement a button that says 'Stop Auto'
-- on the top center of the screen. This should stop the car auto pilot and return the user back in its avatar state
-- outside of the track, able to walk around. The button while in avatar state is replaced with 'Auto Race' button
-- that resumes auto race. User should keep speed stat that was gained during auto racing. Confirm UI is flush with
-- game logic and car doesn't bug when swapping in and out of auto racing. Money stat is displayed under speed stat
-- on the left."
-- A fake player (Folder) with a fake R6 character is attached by CarService to a real car on the LIVE chain
-- (Workspace.Track, RaceService's route), stopped, resumed, toggled rapidly and fed bad input.
local AUTO_BESIDE_START = 150 -- studs (horizontal) from Track 1's Start: "beside the start of Track 1"
local AUTO_SPAWN_MAX_HEIGHT = 8 -- studs the walk spawn may be above the ground under it ("a few studs")
local AUTO_SPAWN_MATCH = 4 -- studs (horizontal) the avatar may be from WalkSpawnCFrame after the stop
local AUTO_FLOOR_TOP = 1 -- SPAWN_AND_ROLLS_SPEC: the walk spawn stands on Workspace.SpawnArea, floor top SpawnArea.TOP_Y
local AUTO_START_RADIUS = 25 -- studs: a resumed car spawns at the Track 1 start
local AUTO_WALK_SPEED = 16 -- StarterPlayer defaults
-- SPAWN_AND_ROLLS_SPEC section 2, "Start is an event" (owner, 2026-10-01: a fast Stop then Auto Race made the car
-- path from the spawn area instead of starting at the start line)
local AUTO_SEAT_TIMEOUT = 3 -- spec SEAT_TIMEOUT: not seated within this -> no race, back on foot
local AUTO_SPAWN_KEEP_OUT = 60 -- studs (horizontal): a fresh run's car never comes this close to the walk spawn
local AUTO_EVENT_WATCH = 1 -- seconds of a fresh run watched for drifting towards the spawn area
local AUTO_RAPID_CYCLES = 4 -- Stop -> Auto Race cycles with no wait between them
local AUTO_AREA_MIN = Vector2.new(24, -100) -- spec section 1: spawn floor, local (x, z) of Track 1's flattened Start
local AUTO_AREA_MAX = Vector2.new(184, 44)
local AUTO_JUMP_HEIGHT = 7.2

local function hdist(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Horizontal distance from p to the polyline pts.
local function hPolyDist(pts, p)
	if #pts == 1 then
		return hdist(pts[1], p)
	end
	local q = Vector2.new(p.X, p.Z)
	local best = math.huge
	for i = 1, #pts - 1 do
		local a = Vector2.new(pts[i].X, pts[i].Z)
		local ab = Vector2.new(pts[i + 1].X, pts[i + 1].Z) - a
		local len2 = ab:Dot(ab)
		local t = len2 > 1e-9 and math.clamp((q - a):Dot(ab) / len2, 0, 1) or 0
		best = math.min(best, (q - (a + ab * t)).Magnitude)
	end
	return best
end

-- Hidden-avatar collision: a part of an auto-racing (hidden) character must never collide with other players'
-- cars nor with the world: it is CanCollide == false, or in a collision group that collides with neither "Cars"
-- nor "Default" (a seated Humanoid keeps re-enabling torso CanCollide, so the group is what has to hold).
local AVATAR_REENABLE_PARTS = { "Torso", "UpperTorso", "LowerTorso", "Head", "HumanoidRootPart" }
local function groupCollidesWithCarsOrWorld(group)
	local PhysicsService = game:GetService("PhysicsService")
	for _, other in { "Cars", "Default" } do
		local ok, collides = pcall(function()
			return PhysicsService:CollisionGroupsAreCollidable(group, other)
		end)
		if not ok or collides ~= false then
			return true
		end
	end
	return false
end
local function avatarCarCollidingParts(character)
	local n, names = 0, {}
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") and d.CanCollide and groupCollidesWithCarsOrWorld(d.CollisionGroup) then
				n += 1
				table.insert(names, d.Name)
			end
		end
	end
	return n, table.concat(names, ",")
end
-- What a seated Humanoid does over time: switches the torso parts' collision back on.
local function reenableAvatarCollision(character)
	for _, name in AVATAR_REENABLE_PARTS do
		local part = character and character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.CanCollide = true
		end
	end
end
-- Every real player who is auto-racing right now: parts of their characters that would hit other cars.
local function realRacersCollidingParts()
	local n = 0
	for _, plr in game:GetService("Players"):GetPlayers() do
		if plr:GetAttribute("AutoRacing") == true and plr.Character then
			n += avatarCarCollidingParts(plr.Character)
		end
	end
	return n
end

-- A minimal R6 avatar: HumanoidRootPart (invisible), Torso, Head with a face decal, two legs, Motor6D joints,
-- plus R15-style UpperTorso/LowerTorso so the hidden-avatar collision checks cover R15 parts too.
local function newFakeCharacter(cf)
	local model = Instance.new("Model")
	model.Name = "CarTestAutoCharacter"
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
	local upperTorso = part("UpperTorso", Vector3.new(2, 1, 1), Vector3.new(0, 0.5, 0), 0, true)
	local lowerTorso = part("LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, -0.8, 0), 0, true)
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
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
	motor("Waist", torso, upperTorso, CFrame.new(0, 0.5, 0), CFrame.new())
	motor("Root", torso, lowerTorso, CFrame.new(0, -0.8, 0), CFrame.new())
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	model.PrimaryPart = root
	model.Parent = Workspace
	return model, humanoid, root, head, face
end

function Scenarios.auto_toggle()
	local checks = {}
	local metrics = {}
	local CarService = serverModule("CarService")
	local RaceService = serverModule("RaceService")
	local PlayerData = serverModule("PlayerData")
	local Money = serverModule("MoneyService")
	local RaceConfig = sharedModule("RaceConfig")
	local R = PhysicsTargets.race
	local L = PhysicsTargets.lap
	local apiOk = CarService ~= nil
		and RaceService ~= nil
		and PlayerData ~= nil
		and Money ~= nil
		and RaceConfig ~= nil
		and R ~= nil
		and L ~= nil
		and type(L.MinUpYStrict) == "number"
		and type(R.MaxPathDeviation) == "number"
		and type(CarService.Attach) == "function"
		and type(CarService.SetAutoRace) == "function"
		and type(CarService.IsAutoRacing) == "function"
		and type(CarService.GetCar) == "function"
		and type(CarService.GetRun) == "function"
		and type(CarService.WalkSpawnCFrame) == "function"
		and type(RaceService.NewRun) == "function"
		and type(PlayerData.Setup) == "function"
		and type(RaceConfig.SpeedFor) == "function"
		and type(RaceConfig.GainPerSecond) == "function"
	check(checks, "auto_api_exists", apiOk and 1 or 0, 1, apiOk)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("SetAutoRace")
	local remoteOk = remote ~= nil and remote:IsA("RemoteEvent")
	check(checks, "auto_remote_is_remote_event", remoteOk and 1 or 0, 1, remoteOk)
	local cooldown = CarService and CarService.TOGGLE_COOLDOWN
	local cooldownOk = type(cooldown) == "number" and cooldown > 0 and cooldown <= 1
	check(checks, "auto_toggle_cooldown_range", cooldownOk and cooldown or -1, 1, cooldownOk)
	local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	local clientFolder = sps and sps:FindFirstChild("Client")
	local buttonScript = clientFolder and clientFolder:FindFirstChild("AutoRaceButton")
	local buttonOk = buttonScript ~= nil and buttonScript:IsA("LocalScript")
	check(checks, "auto_button_script_exists", buttonOk and 1 or 0, 1, buttonOk)

	-- The live chain's road centre lines, rebuilt the way Main builds it (TRACK_LIFT above the baseplate,
	-- each track at the previous one's EndCFrame). Checked against Track 1's Start part in Workspace.Track.
	local trackFolder = Workspace:FindFirstChild("Track")
	local specs = type(TrackRegistry.Chain) == "function" and TrackRegistry.Chain() or {}
	local roads = {}
	local chainOrigin = CFrame.new(0, TrackBuilder.TRACK_LIFT or 0, 0)
	for _, spec in specs do
		local okLayout, layout = pcall(TrackBuilder.Layout, spec)
		if okLayout then
			local pts = {}
			for i, p in layout.Waypoints do
				pts[i] = chainOrigin:PointToWorldSpace(p)
			end
			table.insert(roads, { Points = pts, Width = layout.Width })
			chainOrigin = TrackBuilder.EndCFrame(layout, chainOrigin)
		end
	end
	local track1 = trackFolder and specs[1] and trackFolder:FindFirstChild(specs[1].Name)
	local startPart = track1 and track1:FindFirstChild("Start", true)
	local chainOk = startPart ~= nil
		and #roads >= 1
		and #roads == #specs
		and hdist(startPart.Position, roads[1].Points[1]) <= 5
	check(checks, "auto_live_chain_present", chainOk and 1 or 0, 1, chainOk)
	if not (apiOk and chainOk) then
		return result("auto_toggle", checks, metrics)
	end
	local startPos = startPart.Position
	local strict = L.MinUpYStrict
	local maxDev = R.MaxPathDeviation

	local function call(fn, ...)
		local ok, r = pcall(fn, ...)
		if ok then
			return r
		end
		return nil
	end

	-- Every car model (a Model with a VehicleSeat called DriverSeat). Cars present before the scenario (the real
	-- player's) are ignored; any car that appears during it belongs to the fake player.
	local function carModels()
		local list = {}
		for _, d in Workspace:GetDescendants() do
			if d:IsA("Model") then
				local seat = d:FindFirstChild("DriverSeat")
				if seat and seat:IsA("VehicleSeat") then
					table.insert(list, d)
				end
			end
		end
		return list
	end
	local baseline = {}
	for _, m in carModels() do
		baseline[m] = true
	end
	local function ourCars()
		local list = {}
		for _, m in carModels() do
			if not baseline[m] then
				table.insert(list, m)
			end
		end
		return list
	end

	local player = Instance.new("Folder")
	player.Name = "CarTestAutoPlayer"
	player.Parent = Workspace
	local okSetup = pcall(function()
		Money.Setup(player)
		PlayerData.Setup(player)
		player.leaderstats.Speed.Value = 0
	end)
	local function speedRaw()
		local stats = player:FindFirstChild("leaderstats")
		local v = stats and stats:FindFirstChild("Speed")
		return v and v.Value or -1
	end

	-- Every run RaceService starts for this player (restored in cleanup)
	local runs = {}
	local seatlessPlayer = nil -- the second fake player of the seat-failure test (section 11b)
	local seatlessRuns = {}
	local origNewRun = RaceService.NewRun
	RaceService.NewRun = function(car, route, p, options)
		local run = origNewRun(car, route, p, options)
		if p == player and type(run) == "table" then
			table.insert(runs, run)
		elseif p ~= nil and p == seatlessPlayer and type(run) == "table" then
			table.insert(seatlessRuns, run)
		end
		return run
	end
	local function activeRuns()
		local seen, n = {}, 0
		local current = call(CarService.GetRun, player)
		local all = table.clone(runs)
		if type(current) == "table" then
			table.insert(all, current)
		end
		for _, r in all do
			if not seen[r] then
				seen[r] = true
				if r.Connection ~= nil then
					n += 1
				end
			end
		end
		return n
	end

	local okWalk, walkCF = pcall(CarService.WalkSpawnCFrame)
	local walkOk = okWalk and typeof(walkCF) == "CFrame"
	check(checks, "walk_spawn_is_cframe", walkOk and 1 or 0, 1, walkOk)
	if not walkOk then
		walkCF = CFrame.new(startPos + Vector3.new(0, 3, 0))
	end
	local character, humanoid, root, head, face = newFakeCharacter(CFrame.new(walkCF.Position + Vector3.new(0, 3, 0)))
	local before = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			before[d] = {
				Transparency = d.Transparency,
				CanCollide = d.CanCollide,
				Massless = d.Massless,
				CollisionGroup = d.CollisionGroup,
			}
		end
	end

	local function isRacing()
		return call(CarService.IsAutoRacing, player) == true
	end
	local function attr()
		return player:GetAttribute("AutoRacing")
	end
	local function seatedIn(car)
		local seat = car and car:FindFirstChild("DriverSeat")
		return seat ~= nil and humanoid.SeatPart == seat
	end
	-- One car for this player, GetCar returns it, it is AutoRace, the character sits in it, one active run on it
	local function checkRacingState(pre, oldCar, oldRun)
		local cars = ourCars()
		local car = call(CarService.GetCar, player)
		local run = call(CarService.GetRun, player)
		local stateOk = isRacing() and attr() == true
		check(checks, pre .. "_is_auto_racing", stateOk and 1 or 0, 1, stateOk)
		check(checks, pre .. "_one_car", #cars, 1, #cars == 1)
		local carOk = car ~= nil and car == cars[1] and car.Parent ~= nil and car ~= oldCar
		check(checks, pre .. "_get_car_matches", carOk and 1 or 0, 1, carOk)
		local autoOk = car ~= nil and car:GetAttribute("AutoRace") == true
		check(checks, pre .. "_car_auto_race", autoOk and 1 or 0, 1, autoOk)
		check(checks, pre .. "_seated", seatedIn(car) and 1 or 0, 1, seatedIn(car))
		local hiddenOk = head.Transparency == 1 and face.Transparency == 1
		check(checks, pre .. "_avatar_hidden", hiddenOk and 1 or 0, 1, hiddenOk)
		local bad, badNames = avatarCarCollidingParts(character)
		check(checks, pre .. "_avatar_no_collide_with_cars", bad, 0, bad == 0)
		if bad > 0 then
			metrics[pre .. "_avatar_colliding_parts"] = badNames
		end
		local runOk = type(run) == "table" and run.Connection ~= nil and run.Car == car and run ~= oldRun
		check(checks, pre .. "_run_active", runOk and 1 or 0, 1, runOk)
		local ev = player:GetAttribute("RaceEvent")
		check(checks, pre .. "_race_event_racing", ev == "Racing" and 1 or 0, 1, ev == "Racing")
		local released = car ~= nil and car.PrimaryPart ~= nil and car.PrimaryPart.Anchored == false
		check(checks, pre .. "_chassis_released", released and 1 or 0, 1, released)
		-- NPC spec: a real player's run races Track 1's NPC from the start (RaceService.Attach passes Npc = true)
		local raceTrack = type(run) == "table" and run.RaceTrack or nil
		local npcOn = raceTrack == 1 and type(run.Results) == "table"
		check(checks, pre .. "_npc_race_on", type(raceTrack) == "number" and raceTrack or -1, 1, npcOn)
		local n = activeRuns()
		check(checks, pre .. "_one_active_run", n, 1, n == 1)
		return car, run
	end
	-- Drives `seconds` and checks the car stayed upright, never needed a flip recovery and kept driving
	local function checkDrive(pre, car, run, seconds, statFrom)
		local chassis = car and car.PrimaryPart
		if not chassis or type(run) ~= "table" then
			check(checks, pre .. "_drive_possible", 0, 1, false)
			return
		end
		local minUp, peak = 1, 0
		local idx0 = run.Driver and run.Driver.Index or 0
		reenableAvatarCollision(character)
		frames(seconds, function()
			if chassis.Parent then
				minUp = math.min(minUp, chassis.CFrame.UpVector.Y)
				peak = math.max(peak, chassis.AssemblyLinearVelocity.Magnitude)
			end
		end)
		check(checks, pre .. "_never_tilted", minUp, strict, minUp >= strict)
		local runUp = type(run.MinUpY) == "number" and run.MinUpY or -1
		check(checks, pre .. "_run_never_tilted", runUp, strict, runUp >= strict)
		local rec = type(run.FlipRecoveries) == "number" and run.FlipRecoveries or -1
		check(checks, pre .. "_no_flip_recoveries", rec, 0, rec == 0)
		local dev = type(run.MaxPathDeviation) == "number" and run.MaxPathDeviation or math.huge
		check(checks, pre .. "_sticks_to_path", dev == math.huge and -1 or dev, maxDev, dev <= maxDev)
		local target = RaceConfig.SpeedFor(statFrom)
		check(checks, pre .. "_keeps_driving", peak, 0.5 * target, peak >= 0.5 * target)
		local progressed = (run.Driver and run.Driver.Index or 0) - idx0
		check(checks, pre .. "_progresses", progressed, 5, progressed >= 5)
		local statNow = speedRaw()
		check(checks, pre .. "_stat_grew", statNow, statFrom, statNow > statFrom)
		check(checks, pre .. "_still_seated", seatedIn(car) and 1 or 0, 1, seatedIn(car))
		local bad, badNames = avatarCarCollidingParts(character)
		check(checks, pre .. "_avatar_no_collide_after_drive", bad, 0, bad == 0)
		if bad > 0 then
			metrics[pre .. "_avatar_colliding_after_drive"] = badNames
		end
		local realBad = realRacersCollidingParts()
		check(checks, pre .. "_real_racers_no_collide_with_cars", realBad, 0, realBad == 0)
	end

	local function body()
		check(checks, "auto_fake_player_setup", okSetup and 1 or 0, 1, okSetup)
		check(checks, "initial_not_racing", isRacing() and 0 or 1, 1, not isRacing())

		-- 1. Attach: a car, the character hidden and seated in it, a run driving it
		local okAttach = pcall(CarService.Attach, player, character)
		check(checks, "attach_no_error", okAttach and 1 or 0, 1, okAttach)
		RunService.Heartbeat:Wait()
		local car, run = checkRacingState("attach", nil, nil)

		-- 2. Driving grows the stat
		local stat0 = speedRaw()
		reenableAvatarCollision(character)
		frames(3)
		local stat1 = speedRaw()
		check(checks, "drive_stat_grew", stat1, stat0, stat1 > stat0)
		local driveBad, driveBadNames = avatarCarCollidingParts(character)
		check(checks, "drive_avatar_no_collide_with_cars", driveBad, 0, driveBad == 0)
		if driveBad > 0 then
			metrics.drive_avatar_colliding_parts = driveBadNames
		end
		local realBad = realRacersCollidingParts()
		check(checks, "drive_real_racers_no_collide_with_cars", realBad, 0, realBad == 0)

		-- 3. Stop: back on foot beside Track 1, off every road, stat kept, no car, no run
		local statBeforeStop = speedRaw()
		local okStop, stopRet = pcall(CarService.SetAutoRace, player, false)
		check(checks, "stop_returns_false", okStop and stopRet == false and 1 or 0, 1, okStop and stopRet == false)
		RunService.Heartbeat:Wait()
		local statAfterStop = speedRaw()
		metrics.stat_before_stop = round(statBeforeStop)
		metrics.stat_after_stop = round(statAfterStop)
		check(checks, "stop_stat_kept", statAfterStop, statBeforeStop, statAfterStop >= statBeforeStop)
		local notRacing = not isRacing() and attr() == false
		check(checks, "stop_not_racing", notRacing and 1 or 0, 1, notRacing)
		local oldCarGone = car ~= nil and car.Parent == nil
		check(checks, "stop_car_destroyed", oldCarGone and 1 or 0, 1, oldCarGone)
		local noCar = call(CarService.GetCar, player) == nil and #ourCars() == 0
		check(checks, "stop_no_car", #ourCars(), 0, noCar)
		local runStopped = type(run) == "table" and run.Connection == nil
		check(checks, "stop_run_stopped", runStopped and 1 or 0, 1, runStopped)
		check(checks, "stop_no_active_run", activeRuns(), 0, activeRuns() == 0)
		local evStop = player:GetAttribute("RaceEvent")
		check(checks, "stop_race_event_off", evStop == "Off" and 1 or 0, 1, evStop == "Off")

		local visOk, collideOk, massOk, groupOk = true, true, true, true
		for part, b in before do
			if part.CollisionGroup ~= b.CollisionGroup then
				groupOk = false
			end
			if part.Transparency ~= b.Transparency then
				visOk = false
			end
			if part.CanCollide ~= b.CanCollide then
				collideOk = false
			end
			if part.Massless ~= b.Massless then
				massOk = false
			end
		end
		check(checks, "stop_avatar_visible", visOk and 1 or 0, 1, visOk and head.Transparency == 0)
		check(checks, "stop_root_stays_hidden", root.Transparency, 1, root.Transparency == 1)
		check(checks, "stop_face_visible", face.Transparency, 0, face.Transparency == 0)
		check(checks, "stop_parts_collide_restored", collideOk and 1 or 0, 1, collideOk)
		check(checks, "stop_parts_massless_restored", massOk and 1 or 0, 1, massOk)
		check(checks, "stop_parts_group_restored", groupOk and 1 or 0, 1, groupOk)
		local unseated = humanoid.Sit == false and humanoid.SeatPart == nil
		check(checks, "stop_unseated", unseated and 1 or 0, 1, unseated)
		check(checks, "stop_walk_speed", humanoid.WalkSpeed, AUTO_WALK_SPEED, humanoid.WalkSpeed == AUTO_WALK_SPEED)
		local jh = humanoid.JumpHeight
		check(checks, "stop_jump_height", jh, AUTO_JUMP_HEIGHT, math.abs(jh - AUTO_JUMP_HEIGHT) <= 1e-3)
		local viewer = humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.Viewer
		check(checks, "stop_name_display_viewer", viewer and 1 or 0, 1, viewer)
		local atSpawn = hdist(root.Position, walkCF.Position)
		check(checks, "stop_at_walk_spawn", atSpawn, AUTO_SPAWN_MATCH, atSpawn <= AUTO_SPAWN_MATCH)
		local ub = player:GetAttribute("Unbanked")
		check(checks, "stop_unbanked_zero", type(ub) == "number" and ub or -1, 0, ub == 0)

		-- The walk spawn: off every road of the live chain (and its checkpoint aprons), beside Track 1's start,
		-- on the baseplate, a few studs above it
		local worst, worstNeed = math.huge, 0
		for _, road in roads do
			local need = road.Width / 2 + TrackBuilder.CHECKPOINT_APRON
			local d = hPolyDist(road.Points, walkCF.Position)
			if d - need < worst - worstNeed then
				worst, worstNeed = d, need
			end
		end
		check(checks, "walk_spawn_off_road", worst, worstNeed, worst > worstNeed)
		local beside = hdist(walkCF.Position, startPos)
		check(checks, "walk_spawn_beside_track1_start", beside, AUTO_BESIDE_START, beside <= AUTO_BESIDE_START)
		local exclude = { character }
		for _, m in carModels() do
			table.insert(exclude, m)
		end
		for _, p in game:GetService("Players"):GetPlayers() do
			if p.Character then
				table.insert(exclude, p.Character)
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(walkCF.Position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
		-- SPAWN_AND_ROLLS_SPEC section 1: the walk spawn is in the purple spawn area now, not on the baseplate
		local spawnArea = Workspace:FindFirstChild("SpawnArea")
		local onFloor = hit ~= nil
			and spawnArea ~= nil
			and hit.Instance:IsDescendantOf(spawnArea)
			and math.abs(hit.Position.Y - AUTO_FLOOR_TOP) <= 0.25
		check(checks, "walk_spawn_on_spawn_area_floor", hit and hit.Position.Y or -999, AUTO_FLOOR_TOP, onFloor)
		local height = hit and walkCF.Position.Y - hit.Position.Y or -1
		check(
			checks,
			"walk_spawn_height",
			height,
			AUTO_SPAWN_MAX_HEIGHT,
			hit ~= nil and height >= 0 and height <= AUTO_SPAWN_MAX_HEIGHT
		)

		-- 4. Walking for 2 s: the stat does not move, no car comes back, the avatar stands at the spawn
		frames(2)
		local statWalk = speedRaw()
		check(checks, "walk_stat_frozen", statWalk, statAfterStop, statWalk == statAfterStop)
		local stillNoCar = #ourCars() == 0 and call(CarService.GetCar, player) == nil and activeRuns() == 0
		check(checks, "walk_still_no_car", #ourCars(), 0, stillNoCar)
		local stillWalking = not isRacing() and attr() == false and humanoid.SeatPart == nil
		check(checks, "walk_still_not_racing", stillWalking and 1 or 0, 1, stillWalking)
		local ground = hit and hit.Position.Y or AUTO_FLOOR_TOP
		local standH = root.Position.Y - ground
		check(checks, "walk_standing_height", standH, 3, standH >= 1.5 and standH <= 5)
		local rootSpeed = root.AssemblyLinearVelocity.Magnitude
		check(checks, "walk_at_rest", rootSpeed, 2, rootSpeed < 2)
		check(checks, "walk_humanoid_alive", humanoid.Health, 0, humanoid.Health > 0)
		local stay = hdist(root.Position, walkCF.Position)
		check(checks, "walk_stays_at_spawn", stay, AUTO_SPAWN_MATCH, stay <= AUTO_SPAWN_MATCH)

		-- 5. Bad input while walking changes nothing
		local badWalkOk = true
		for _, v in { "yes", 1, 0, "true", {} } do
			local ok, ret = pcall(CarService.SetAutoRace, player, v)
			if not ok or ret ~= false then
				badWalkOk = false
			end
		end
		local okNil, retNil = pcall(CarService.SetAutoRace, player, nil)
		badWalkOk = badWalkOk and okNil and retNil == false
		RunService.Heartbeat:Wait()
		badWalkOk = badWalkOk and not isRacing() and attr() == false and #ourCars() == 0 and humanoid.SeatPart == nil
		check(checks, "bad_input_ignored_walking", badWalkOk and 1 or 0, 1, badWalkOk)

		-- 6. Resume: a fresh car at Track 1's start, the stat exactly as it was, then 5 s of clean driving
		local stoppedStat = speedRaw()
		local minSeen = stoppedStat
		local speedObj = player.leaderstats.Speed
		local watch = speedObj:GetPropertyChangedSignal("Value"):Connect(function()
			minSeen = math.min(minSeen, speedObj.Value)
		end)
		local okRes, resRet = pcall(CarService.SetAutoRace, player, true)
		local statAtResume = speedRaw()
		check(checks, "resume_returns_true", okRes and resRet == true and 1 or 0, 1, okRes and resRet == true)
		local slack = RaceConfig.GainPerSecond(stoppedStat, CarConfig.TopSpeed or 200) * 1
		check(
			checks,
			"resume_stat_kept",
			statAtResume,
			stoppedStat,
			statAtResume >= stoppedStat - 1e-6 and statAtResume <= stoppedStat + slack
		)
		RunService.Heartbeat:Wait()
		local car2, run2 = checkRacingState("resume", car, run)
		local chassis2 = car2 and car2.PrimaryPart
		local fromStart = chassis2 and hdist(chassis2.Position, startPos) or math.huge
		check(
			checks,
			"resume_car_at_track1_start",
			fromStart == math.huge and -1 or fromStart,
			AUTO_START_RADIUS,
			fromStart <= AUTO_START_RADIUS
		)
		checkDrive("resume", car2, run2, 5, stoppedStat)
		watch:Disconnect()
		check(checks, "resume_stat_never_dropped", minSeen, stoppedStat, minSeen >= stoppedStat - 1e-6)

		-- 7. Rapid toggling from concurrent requests: the last one wins, one car, one run, seated, drives cleanly
		for _, v in { false, true, false, true, true, false, true } do
			task.spawn(function()
				pcall(CarService.SetAutoRace, player, v)
			end)
			RunService.Heartbeat:Wait()
		end
		frames(2)
		local car3, run3 = checkRacingState("rapid", nil, nil)
		checkDrive("rapid", car3, run3, 3, speedRaw())

		-- 8. Bad input while racing changes nothing (same car, same run)
		local badRaceOk = true
		for _, v in { "yes", 1, 0, "false", {} } do
			local ok, ret = pcall(CarService.SetAutoRace, player, v)
			if not ok or ret ~= true then
				badRaceOk = false
			end
		end
		local okNil2, retNil2 = pcall(CarService.SetAutoRace, player, nil)
		badRaceOk = badRaceOk and okNil2 and retNil2 == true
		RunService.Heartbeat:Wait()
		badRaceOk = badRaceOk
			and isRacing()
			and attr() == true
			and call(CarService.GetCar, player) == car3
			and car3 ~= nil
			and car3.Parent ~= nil
			and call(CarService.GetRun, player) == run3
			and run3 ~= nil
			and run3.Connection ~= nil
			and #ourCars() == 1
		check(checks, "bad_input_ignored_racing", badRaceOk and 1 or 0, 1, badRaceOk)

		-- 9. Idempotent: stop twice leaves no car, start twice leaves exactly one
		local okA, rA = pcall(CarService.SetAutoRace, player, false)
		local okB, rB = pcall(CarService.SetAutoRace, player, false)
		RunService.Heartbeat:Wait()
		local stopTwice = okA and okB and rA == false and rB == false
		check(checks, "double_stop_returns_false", stopTwice and 1 or 0, 1, stopTwice)
		local zero = #ourCars() == 0 and activeRuns() == 0 and not isRacing() and attr() == false
		check(checks, "double_stop_no_car", #ourCars(), 0, zero)
		local unseated2 = humanoid.SeatPart == nil and humanoid.Sit == false
		check(checks, "double_stop_unseated", unseated2 and 1 or 0, 1, unseated2)
		local evStop2 = player:GetAttribute("RaceEvent")
		check(checks, "double_stop_race_event_off", evStop2 == "Off" and 1 or 0, 1, evStop2 == "Off")
		local okC, rC = pcall(CarService.SetAutoRace, player, true)
		local okD, rD = pcall(CarService.SetAutoRace, player, true)
		RunService.Heartbeat:Wait()
		local startTwice = okC and okD and rC == true and rD == true
		check(checks, "double_start_returns_true", startTwice and 1 or 0, 1, startTwice)
		checkRacingState("double_start", nil, nil)

		-- 10. Accessories that load while the avatar is hidden are hidden too, and come back when it stops;
		-- one added while on foot stays visible (regression: swap in/out must track late descendants)
		local function newAccessory(name)
			local acc = Instance.new("Accessory")
			acc.Name = name
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.new(1, 0.4, 1)
			handle.Transparency = 0
			handle.CanCollide = false
			handle.Massless = false
			handle.CFrame = head.CFrame * CFrame.new(0, 0.7, 0)
			handle.Parent = acc
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = head
			weld.Parent = handle
			local decal = Instance.new("Decal")
			decal.Name = "Logo"
			decal.Transparency = 0
			decal.Parent = handle
			acc.Parent = character
			return handle, decal
		end
		local hatHandle, hatDecal = newAccessory("CarTestLateHat")
		RunService.Heartbeat:Wait()
		RunService.Heartbeat:Wait()
		local lateHidden = hatHandle.Transparency == 1 and hatDecal.Transparency == 1 and hatHandle.Massless == true
		check(checks, "late_accessory_hidden_while_racing", lateHidden and 1 or 0, 1, lateHidden)
		local okS, rS = pcall(CarService.SetAutoRace, player, false)
		RunService.Heartbeat:Wait()
		local lateShown = okS
			and rS == false
			and hatHandle.Transparency == 0
			and hatDecal.Transparency == 0
			and hatHandle.Massless == false
			and hatHandle.CanCollide == false
		check(checks, "late_accessory_restored_on_stop", lateShown and 1 or 0, 1, lateShown)
		local footHandle, footDecal = newAccessory("CarTestFootHat")
		RunService.Heartbeat:Wait()
		RunService.Heartbeat:Wait()
		local footVisible = footHandle.Transparency == 0 and footDecal.Transparency == 0 and head.Transparency == 0
		check(checks, "foot_accessory_stays_visible", footVisible and 1 or 0, 1, footVisible)

		-- 11. A player with no avatar attached can not start a car
		local ghost = Instance.new("Folder")
		ghost.Name = "CarTestAutoGhost"
		ghost.Parent = Workspace
		local okG, rG = pcall(CarService.SetAutoRace, ghost, true)
		RunService.Heartbeat:Wait()
		local ghostCar = call(CarService.GetCar, ghost)
		local ghostOk = okG
			and rG == false
			and ghostCar == nil
			and call(CarService.GetRun, ghost) == nil
			and call(CarService.IsAutoRacing, ghost) ~= true
		check(checks, "unattached_enable_refused", ghostOk and 1 or 0, 1, ghostOk)
		if ghostCar then
			pcall(function()
				ghostCar:Destroy()
			end)
		end
		ghost:Destroy()

		-- 11b. Start is an event (SPAWN_AND_ROLLS_SPEC section 2; owner's bug 2026-10-01: Stop then Auto Race
		-- quickly made the car path from the spawn area instead of first being put at the start line).
		-- The car waits at the start line with its chassis anchored, the avatar is teleported in until the server
		-- sees it seated, only then the chassis is released and the run starts. RaceEvent: Teleporting/Racing/Off.
		local function raceEvent()
			return player:GetAttribute("RaceEvent")
		end
		local look = startPart.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, -1)
		local flatStart = Vector3.new(startPos.X, 0, startPos.Z)
		local areaBase = CFrame.lookAt(flatStart, flatStart + flat)
		local function overSpawnFloor(pos)
			local l = areaBase:PointToObjectSpace(Vector3.new(pos.X, 0, pos.Z))
			return l.X >= AUTO_AREA_MIN.X
				and l.X <= AUTO_AREA_MAX.X
				and l.Z >= AUTO_AREA_MIN.Y
				and l.Z <= AUTO_AREA_MAX.Y
		end
		local function atWalkSpawnNow()
			character:PivotTo(walkCF)
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") then
					d.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
		-- Watches a fresh run's car for AUTO_EVENT_WATCH seconds: closest horizontal distance to the walk spawn and
		-- frames spent over the spawn floor
		local function watchFreshRun(freshCar)
			local chassis = freshCar and freshCar.PrimaryPart
			local closest, over = math.huge, 0
			local function sample()
				if chassis and chassis.Parent then
					closest = math.min(closest, hdist(chassis.Position, walkCF.Position))
					if overSpawnFloor(chassis.Position) then
						over += 1
					end
				end
			end
			sample()
			frames(AUTO_EVENT_WATCH, sample)
			return closest, over
		end

		-- On foot (after the stop in step 10): RaceEvent "Off"
		local evFoot = raceEvent()
		check(checks, "event_on_foot_race_event_off", evFoot == "Off" and 1 or 0, 1, evFoot == "Off")

		-- The teleport phase, observed every frame from a parallel connection and right after the call yielded
		atWalkSpawnNow()
		local tele = { Frames = 0, RunSeen = 0, Unanchored = 0, NoCar = 0, AwayFromStart = 0, Racing = 0, Bad = 0 }
		local observer = RunService.Heartbeat:Connect(function()
			local ev = raceEvent()
			if ev == "Teleporting" then
				tele.Frames += 1
				if call(CarService.GetRun, player) ~= nil then
					tele.RunSeen += 1
				end
				local c = call(CarService.GetCar, player)
				local ch = c and c.PrimaryPart
				if not ch then
					tele.NoCar += 1
				else
					if not ch.Anchored then
						tele.Unanchored += 1
					end
					if hdist(ch.Position, startPos) > AUTO_START_RADIUS then
						tele.AwayFromStart += 1
					end
				end
			elseif ev == "Racing" then
				tele.Racing += 1
				if type(call(CarService.GetRun, player)) ~= "table" then
					tele.Bad += 1
				end
			end
		end)
		local evDone, evRet = false, nil
		task.spawn(function()
			local okE, rE = pcall(CarService.SetAutoRace, player, true)
			evRet = okE and rE
			evDone = true
		end)
		-- Right after the call yielded: still teleporting, no run, the car held at the start line
		local snapEv = raceEvent()
		local snapRun = call(CarService.GetRun, player)
		local snapCar = call(CarService.GetCar, player)
		local snapChassis = snapCar and snapCar.PrimaryPart
		check(checks, "event_teleport_phase_observed", snapEv == "Teleporting" and 1 or 0, 1, snapEv == "Teleporting")
		check(checks, "event_teleport_no_run_yet", snapRun == nil and 1 or 0, 1, snapRun == nil)
		local snapHeld = snapChassis ~= nil and snapChassis.Anchored == true
		check(checks, "event_teleport_chassis_anchored", snapHeld and 1 or 0, 1, snapHeld)
		local snapFrom = snapChassis and hdist(snapChassis.Position, startPos) or math.huge
		check(
			checks,
			"event_teleport_car_at_start",
			snapFrom == math.huge and -1 or snapFrom,
			AUTO_START_RADIUS,
			snapFrom <= AUTO_START_RADIUS
		)
		local deadline = os.clock() + AUTO_SEAT_TIMEOUT + 1
		while not evDone and os.clock() < deadline do
			RunService.Heartbeat:Wait()
		end
		-- After SetAutoRace(true) returned: racing, seated, a run, the chassis released, the car at the start line
		local evCar = call(CarService.GetCar, player)
		local evChassis = evCar and evCar.PrimaryPart
		local evRun = call(CarService.GetRun, player)
		check(checks, "event_start_returned", evDone and 1 or 0, 1, evDone)
		check(checks, "event_start_returns_true", evRet == true and 1 or 0, 1, evRet == true)
		local evNow = raceEvent()
		check(checks, "event_start_race_event_racing", evNow == "Racing" and 1 or 0, 1, evNow == "Racing")
		check(checks, "event_start_seated", seatedIn(evCar) and 1 or 0, 1, seatedIn(evCar))
		local evRunOk = type(evRun) == "table" and evRun.Connection ~= nil and evRun.Car == evCar
		check(checks, "event_start_run_exists", evRunOk and 1 or 0, 1, evRunOk)
		local evReleased = evChassis ~= nil and evChassis.Anchored == false
		check(checks, "event_start_chassis_released", evReleased and 1 or 0, 1, evReleased)
		local evFrom = evChassis and hdist(evChassis.Position, startPos) or math.huge
		check(
			checks,
			"event_start_car_at_track1_start",
			evFrom == math.huge and -1 or evFrom,
			AUTO_START_RADIUS,
			evFrom <= AUTO_START_RADIUS
		)
		local evClosest, evOver = watchFreshRun(evCar)
		observer:Disconnect()
		metrics.event_teleport_frames = tele.Frames
		metrics.event_teleport_frames_without_car = tele.NoCar
		check(checks, "event_teleport_never_has_run", tele.RunSeen, 0, tele.RunSeen == 0)
		check(checks, "event_teleport_chassis_always_anchored", tele.Unanchored, 0, tele.Unanchored == 0)
		check(checks, "event_teleport_car_always_at_start", tele.AwayFromStart, 0, tele.AwayFromStart == 0)
		check(checks, "event_racing_always_has_run", tele.Bad, 0, tele.Racing > 0 and tele.Bad == 0)
		check(
			checks,
			"event_start_keeps_away_from_walk_spawn",
			evClosest == math.huge and -1 or evClosest,
			AUTO_SPAWN_KEEP_OUT,
			evClosest > AUTO_SPAWN_KEEP_OUT and evClosest ~= math.huge
		)
		check(checks, "event_start_never_over_spawn_floor", evOver, 0, evOver == 0)

		-- Rapid Stop -> Auto Race, with the avatar standing at the walk spawn right before each start: every run
		-- starts at the start line and never heads for the spawn area
		local rapidFar, rapidClosest, rapidOver, rapidBad = 0, math.huge, 0, 0
		for cycle = 1, AUTO_RAPID_CYCLES do
			local okCycleStop = pcall(CarService.SetAutoRace, player, false)
			local evOff = raceEvent()
			if not okCycleStop or evOff ~= "Off" then
				rapidBad += 1
			end
			if cycle % 2 == 0 then
				atWalkSpawnNow() -- standing at the walk spawn (Stop already put it there; again, explicitly)
			end
			if cycle == 3 then
				RunService.Heartbeat:Wait() -- one frame between Stop and Auto Race
			end
			local okGo, rGo = pcall(CarService.SetAutoRace, player, true)
			local c = call(CarService.GetCar, player)
			local ch = c and c.PrimaryPart
			local r = call(CarService.GetRun, player)
			local fresh = okGo
				and rGo == true
				and raceEvent() == "Racing"
				and ch ~= nil
				and ch.Anchored == false
				and type(r) == "table"
				and r.Car == c
				and seatedIn(c)
			if not fresh then
				rapidBad += 1
			end
			local from = ch and hdist(ch.Position, startPos) or math.huge
			rapidFar = math.max(rapidFar, from)
			local closest, over = watchFreshRun(c)
			rapidClosest = math.min(rapidClosest, closest)
			rapidOver += over
		end
		check(checks, "event_rapid_each_start_racing", rapidBad, 0, rapidBad == 0)
		check(
			checks,
			"event_rapid_car_at_track1_start",
			rapidFar == math.huge and -1 or rapidFar,
			AUTO_START_RADIUS,
			rapidFar <= AUTO_START_RADIUS
		)
		check(
			checks,
			"event_rapid_keeps_away_from_walk_spawn",
			rapidClosest == math.huge and -1 or rapidClosest,
			AUTO_SPAWN_KEEP_OUT,
			rapidClosest > AUTO_SPAWN_KEEP_OUT and rapidClosest ~= math.huge
		)
		check(checks, "event_rapid_never_over_spawn_floor", rapidOver, 0, rapidOver == 0)
		check(checks, "event_rapid_one_car", #ourCars(), 1, #ourCars() == 1)
		check(checks, "event_rapid_one_active_run", activeRuns(), 1, activeRuns() == 1)

		-- Stop while teleporting cancels the start: on foot, no car, no run, and none created later
		pcall(CarService.SetAutoRace, player, false)
		local runsBeforeCancel = #runs
		local cancelDone, cancelRet = false, nil
		task.spawn(function()
			local okC2, rC2 = pcall(CarService.SetAutoRace, player, true)
			cancelRet = okC2 and rC2
			cancelDone = true
		end)
		local cancelEv = raceEvent()
		check(
			checks,
			"event_cancel_was_teleporting",
			cancelEv == "Teleporting" and 1 or 0,
			1,
			cancelEv == "Teleporting"
		)
		local okCancel, rCancel = pcall(CarService.SetAutoRace, player, false)
		check(
			checks,
			"event_cancel_stop_returns_false",
			okCancel and rCancel == false and 1 or 0,
			1,
			okCancel and rCancel == false
		)
		RunService.Heartbeat:Wait()
		-- DIAGNOSTIC ONLY (no pass condition): records each part of the on-foot conjunction into metrics
		local function recordOnFootParts(prefix, who, hum, hd, rootPart, runCount, activeCount)
			local seatPart = hum.SeatPart
			metrics[prefix .. "_seatpart"] = seatPart and seatPart.Name or "nil"
			metrics[prefix .. "_seatpart_parent"] = seatPart
					and (seatPart.Parent and seatPart.Parent:GetFullName() or "nil")
				or "no_seatpart"
			metrics[prefix .. "_head_transparency"] = hd.Transparency
			metrics[prefix .. "_car_count"] = #ourCars()
			metrics[prefix .. "_run_count"] = runCount
			metrics[prefix .. "_active_run_count"] = activeCount
			local rootDist = rootPart and rootPart.Parent and (rootPart.Position - walkCF.Position).Magnitude or -1
			metrics[prefix .. "_root_pos_to_walk_spawn"] = rootDist
			metrics[prefix .. "_humanoid_state"] = hum:GetState().Name
			metrics[prefix .. "_humanoid_sit"] = hum.Sit
			metrics[prefix .. "_is_racing"] = call(CarService.IsAutoRacing, who) == true
			metrics[prefix .. "_auto_racing_attr"] = tostring(who:GetAttribute("AutoRacing"))
			metrics[prefix .. "_race_event"] = tostring(who:GetAttribute("RaceEvent"))
			metrics[prefix .. "_getcar_nil"] = call(CarService.GetCar, who) == nil
			metrics[prefix .. "_getrun_nil"] = call(CarService.GetRun, who) == nil
		end
		local function cancelledOnFoot()
			return not isRacing()
				and attr() == false
				and raceEvent() == "Off"
				and call(CarService.GetCar, player) == nil
				and call(CarService.GetRun, player) == nil
				and #ourCars() == 0
				and activeRuns() == 0
				and humanoid.SeatPart == nil
				and head.Transparency == 0
		end
		recordOnFootParts("event_cancel", player, humanoid, head, root, #runs, activeRuns())
		check(checks, "event_cancel_on_foot", cancelledOnFoot() and 1 or 0, 1, cancelledOnFoot())
		local evCancel = raceEvent()
		check(checks, "event_cancel_race_event_off", evCancel == "Off" and 1 or 0, 1, evCancel == "Off")
		frames(1)
		recordOnFootParts("event_cancel_after_1s", player, humanoid, head, root, #runs, activeRuns())
		check(checks, "event_cancel_still_on_foot_after_1s", cancelledOnFoot() and 1 or 0, 1, cancelledOnFoot())
		local newRuns = #runs - runsBeforeCancel
		check(checks, "event_cancel_no_run_ever", newRuns, 0, newRuns == 0)
		check(
			checks,
			"event_cancel_start_returned_false",
			cancelRet == false and 1 or 0,
			1,
			cancelDone and cancelRet == false
		)

		-- Seat failure: a second fake player whose avatar can never be seated (the seat is disabled the moment the
		-- car appears and any SeatWeld is removed every frame). After SEAT_TIMEOUT: no race, on foot, no car, no run.
		local p2 = Instance.new("Folder")
		p2.Name = "CarTestAutoSeatless"
		p2.Parent = Workspace
		seatlessPlayer = p2
		local okSetup2 = pcall(function()
			Money.Setup(p2)
			PlayerData.Setup(p2)
		end)
		check(checks, "event_seatless_setup", okSetup2 and 1 or 0, 1, okSetup2)
		local char2, hum2, _, head2 = newFakeCharacter(CFrame.new(walkCF.Position + Vector3.new(6, 3, 0)))
		local char2b = nil
		local okJoin2 = pcall(CarService.OnCharacter, p2, char2)
		RunService.Heartbeat:Wait()
		local evJoin = p2:GetAttribute("RaceEvent")
		check(checks, "event_join_race_event_off", evJoin == "Off" and 1 or 0, 1, okJoin2 and evJoin == "Off")
		pcall(function()
			hum2:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
		end)
		local function blockSeat(seatCar)
			local seat = seatCar and seatCar:FindFirstChild("DriverSeat")
			if seat then
				seat.Disabled = true
				local weld = seat:FindFirstChild("SeatWeld")
				if weld then
					weld:Destroy()
				end
			end
			hum2.Sit = false
		end
		local blockAdded = Workspace.ChildAdded:Connect(function(m)
			if m:IsA("Model") and m:FindFirstChild("DriverSeat") and not baseline[m] then
				blockSeat(m)
			end
		end)
		local seatlessTeleporting = false
		local blockBeat = RunService.Heartbeat:Connect(function()
			if p2:GetAttribute("RaceEvent") == "Teleporting" then
				seatlessTeleporting = true
			end
			blockSeat(call(CarService.GetCar, p2))
		end)
		local seatDone, seatRet = false, nil
		local seatElapsed = -1 -- DIAGNOSTIC: seconds from the SetAutoRace(true) call to its return
		local t0 = os.clock()
		task.spawn(function()
			local tCall = os.clock()
			local okF, rF = pcall(CarService.SetAutoRace, p2, true)
			seatElapsed = os.clock() - tCall
			seatRet = okF and rF
			seatDone = true
		end)
		while os.clock() < t0 + AUTO_SEAT_TIMEOUT + 0.5 do
			RunService.Heartbeat:Wait()
		end
		blockAdded:Disconnect()
		blockBeat:Disconnect()
		metrics.event_seatless_was_teleporting = seatlessTeleporting
		check(checks, "event_seat_fail_returned", seatDone and 1 or 0, 1, seatDone)
		check(checks, "event_seat_fail_returns_false", seatRet == false and 1 or 0, 1, seatRet == false)
		local p2Racing = call(CarService.IsAutoRacing, p2) == true or p2:GetAttribute("AutoRacing") ~= false
		check(checks, "event_seat_fail_not_racing", p2Racing and 0 or 1, 1, not p2Racing)
		local evFail = p2:GetAttribute("RaceEvent")
		check(checks, "event_seat_fail_race_event_off", evFail == "Off" and 1 or 0, 1, evFail == "Off")
		local p2NoCar = call(CarService.GetCar, p2) == nil and #ourCars() == 0
		check(checks, "event_seat_fail_no_car", #ourCars(), 0, p2NoCar)
		local p2NoRun = call(CarService.GetRun, p2) == nil and #seatlessRuns == 0
		check(checks, "event_seat_fail_no_run", #seatlessRuns, 0, p2NoRun)
		metrics.event_seat_fail_setautorace_elapsed = seatElapsed
		local p2Active = 0
		for _, r in seatlessRuns do
			if r.Connection ~= nil then
				p2Active += 1
			end
		end
		recordOnFootParts(
			"event_seat_fail",
			p2,
			hum2,
			head2,
			char2:FindFirstChild("HumanoidRootPart"),
			#seatlessRuns,
			p2Active
		)
		local p2Foot = hum2.SeatPart == nil and head2.Transparency == 0
		check(checks, "event_seat_fail_on_foot", p2Foot and 1 or 0, 1, p2Foot)

		-- Respawn: the new avatar is on foot, RaceEvent "Off"
		char2b = newFakeCharacter(CFrame.new(walkCF.Position + Vector3.new(-6, 3, 0)))
		local okResp = pcall(CarService.OnCharacter, p2, char2b)
		RunService.Heartbeat:Wait()
		local evResp = p2:GetAttribute("RaceEvent")
		check(checks, "event_respawn_race_event_off", evResp == "Off" and 1 or 0, 1, okResp and evResp == "Off")
		pcall(CarService.SetAutoRace, p2, false)
		for _, r in seatlessRuns do
			pcall(function()
				r:Destroy()
			end)
		end
		char2:Destroy()
		char2b:Destroy()
		p2:Destroy()

		-- 12. Death: the car and its run go away with the avatar, the stat stops, and a dead avatar can not be
		-- given a new car by toggling off and on (CarService's own contract: "no avatar to seat (dead ...)")
		local okR, rR = pcall(CarService.SetAutoRace, player, true)
		RunService.Heartbeat:Wait()
		local preDeathCar = call(CarService.GetCar, player)
		local raceAgain = okR and rR == true and preDeathCar ~= nil and seatedIn(preDeathCar)
		check(checks, "pre_death_racing", raceAgain and 1 or 0, 1, raceAgain)
		humanoid.Health = 0
		frames(0.5)
		local deadGone = call(CarService.GetCar, player) == nil
			and call(CarService.GetRun, player) == nil
			and #ourCars() == 0
			and activeRuns() == 0
			and (preDeathCar == nil or preDeathCar.Parent == nil)
		check(checks, "died_car_removed", deadGone and 1 or 0, 1, deadGone)
		local statDead0 = speedRaw()
		frames(1)
		local statDead1 = speedRaw()
		check(checks, "died_stat_frozen", statDead1, statDead0, statDead1 == statDead0)
		pcall(CarService.SetAutoRace, player, false)
		RunService.Heartbeat:Wait()
		local okDR, rDR = pcall(CarService.SetAutoRace, player, true)
		frames(0.5)
		local deadRefused = okDR
			and rDR == false
			and not isRacing()
			and call(CarService.GetCar, player) == nil
			and #ourCars() == 0
			and activeRuns() == 0
		check(checks, "dead_resume_refused", deadRefused and 1 or 0, 1, deadRefused)
		local statDead2 = speedRaw()
		check(checks, "dead_stat_frozen", statDead2, statDead1, statDead2 == statDead1)
	end

	local ok, err = pcall(body)
	check(checks, "auto_toggle_no_error", ok and 1 or 0, 1, ok)
	if not ok then
		metrics.error = tostring(err)
	end

	RaceService.NewRun = origNewRun
	pcall(CarService.SetAutoRace, player, false)
	for _, r in runs do
		pcall(function()
			r:Destroy()
		end)
	end
	for _, m in ourCars() do
		m:Destroy()
	end
	character:Destroy()
	player:Destroy()
	return result("auto_toggle", checks, metrics)
end

-- Economy: RaceConfig contract (pure functions).
function Scenarios.economy()
	local checks = {}
	local RaceConfig = sharedModule("RaceConfig")
	local apiOk = RaceConfig ~= nil
		and type(RaceConfig.SpeedFor) == "function"
		and type(RaceConfig.GainPerSecond) == "function"
	check(checks, "economy_api_exists", apiOk and 1 or 0, 1, apiOk)
	if not apiOk then
		return result("economy", checks, {})
	end
	local function num(x)
		return type(x) == "number" and x == x
	end
	local consts = {
		BASE_SPEED = 30,
		MAX_SPEED = 75,
		HALF_STAT = 1000,
		GAIN_PER_STUD = 0.05,
		GAIN_SOFT = 2000,
		MAX_STAT = 1e9,
	}
	for name, want in consts do
		check(checks, "const_" .. string.lower(name), RaceConfig[name] or -1, want, RaceConfig[name] == want)
	end
	local removed = RaceConfig.MAX_LEVEL == nil and RaceConfig.SPEED_PER_LEVEL == nil
	check(checks, "level_model_removed", removed and 1 or 0, 1, removed)
	local base, top, half, maxStat =
		RaceConfig.BASE_SPEED, RaceConfig.MAX_SPEED, RaceConfig.HALF_STAT, RaceConfig.MAX_STAT
	if not (num(base) and num(top) and num(half) and num(maxStat)) then
		check(checks, "economy_constants_numbers", 0, 1, false)
		return result("economy", checks, {})
	end
	local function sf(x)
		local ok, v = pcall(RaceConfig.SpeedFor, x)
		return ok and v or nil
	end
	local function gp(s, v)
		local ok, r = pcall(RaceConfig.GainPerSecond, s, v)
		return ok and r or nil
	end

	check(checks, "race_config_below_top_speed", top, CarConfig.TopSpeed, top < CarConfig.TopSpeed)
	check(checks, "speed_for_zero_is_base", sf(0) or -1, base, sf(0) == base)
	local mid = sf(half)
	check(
		checks,
		"speed_for_half_stat_is_midpoint",
		mid or -1,
		(base + top) / 2,
		num(mid) and math.abs(mid - (base + top) / 2) <= 0.01
	)
	local bad = { "nan", -5, "9", true, {} }
	local badOk = sf(nil) == base and sf(0 / 0) == base
	for _, b in bad do
		if b ~= "nan" and sf(b) ~= base then
			badOk = false
		end
	end
	check(checks, "speed_for_bad_input_is_base", badOk and 1 or 0, 1, badOk)
	local samples = { 0, 1, 10, 100, 500, 1000, 2000, 5000, 1e5, 1e6, maxStat }
	local increasing, bounded, prev = true, true, -1
	for _, s in samples do
		local v = sf(s)
		if not num(v) then
			increasing, bounded = false, false
			break
		end
		if v <= prev then
			increasing = false
		end
		if v > top or v >= CarConfig.TopSpeed then
			bounded = false
		end
		prev = v
	end
	check(checks, "speed_for_strictly_increasing", increasing and 1 or 0, 1, increasing)
	check(checks, "speed_for_bounded_by_max", bounded and 1 or 0, 1, bounded)
	local atMax = sf(maxStat)
	check(checks, "speed_for_max_stat_near_max", atMax or -1, top - 0.05, num(atMax) and atMax >= top - 0.05)
	local d1, d2 = (sf(2000) or 0) - (sf(1000) or 0), (sf(1000) or 0) - (sf(0) or 0)
	check(checks, "speed_for_diminishing", d1, d2, d1 > 0 and d1 < d2)

	-- GainPerSecond(stat, speed) = GAIN_PER_STUD * speed / (1 + stat / GAIN_SOFT)
	local soft, per = RaceConfig.GAIN_SOFT, RaceConfig.GAIN_PER_STUD
	local formulaOk = true
	for _, pair in { { 0, 30 }, { 1000, 50 }, { 2000, 75 }, { 20000, 40 } } do
		local g = gp(pair[1], pair[2])
		local want = per * pair[2] / (1 + pair[1] / soft)
		if not num(g) or math.abs(g - want) > 1e-9 * math.max(1, want) then
			formulaOk = false
		end
	end
	check(checks, "gain_formula", formulaOk and 1 or 0, 1, formulaOk)
	local badGain = true
	for _, pair in
		{
			{ "x", 30 },
			{ 0, "x" },
			{ 0 / 0, 30 },
			{ 0, 0 / 0 },
			{ -1, 30 },
			{ 0, -30 },
			{ nil, 30 },
			{ 0, nil },
			{ true, 30 },
			{ 0, {} },
		}
	do
		if gp(pair[1], pair[2]) ~= 0 then
			badGain = false
		end
	end
	check(checks, "gain_bad_input_is_zero", badGain and 1 or 0, 1, badGain)
	local zeroOk = gp(0, 0) == 0 and gp(500, 0) == 0 and gp(1e9, 0) == 0
	check(checks, "gain_zero_speed_is_zero", zeroOk and 1 or 0, 1, zeroOk)
	local propOk = true
	for _, s in { 0, 500, 5000 } do
		local a, b = gp(s, 20), gp(s, 40)
		if not (num(a) and num(b) and a > 0 and math.abs(b - 2 * a) <= 1e-9 * b) then
			propOk = false
		end
	end
	check(checks, "gain_proportional_to_speed", propOk and 1 or 0, 1, propOk)
	local dec, p = true, math.huge
	for _, s in { 0, 100, 1000, 10000, 1e5, 1e7 } do
		local g = gp(s, 50)
		if not (num(g) and g > 0 and g < p) then
			dec = false
		end
		p = num(g) and g or p
	end
	check(checks, "gain_strictly_decreasing_in_stat", dec and 1 or 0, 1, dec)
	local far, near = gp(10 * soft, 50), gp(0, 50)
	check(checks, "gain_diminishes_strongly", far or -1, (near or 0) / 5, num(far) and num(near) and far < near / 5)
	return result("economy", checks, {})
end

-- Discovering a car = owning it (no duplicate counts): an owned car is a StringValue <id> (Value = id) in GachaData.
local function owns(player, id)
	local data = player:FindFirstChild("GachaData")
	local v = data and type(id) == "string" and data:FindFirstChild(id)
	return v ~= nil and v:IsA("StringValue") and v.Value == id
end

local function entriesNamed(player, id)
	local data = player:FindFirstChild("GachaData")
	local n = 0
	if data then
		for _, v in data:GetChildren() do
			if v.Name == id then
				n += 1
			end
		end
	end
	return n
end

local function ownedUnique(player)
	local data = player:FindFirstChild("GachaData")
	return data and #data:GetChildren() or 0
end

local function anyCountAttribute(player)
	local data = player:FindFirstChild("GachaData")
	if data then
		for _, v in data:GetChildren() do
			if v:GetAttribute("Count") ~= nil then
				return true
			end
		end
	end
	return false
end

-- Data: PlayerData saves/loads Money and the float Speed stat through an injected store (no real DataStore is touched).
function Scenarios.data()
	local checks = {}
	local PlayerData = serverModule("PlayerData")
	local RaceConfig = sharedModule("RaceConfig")
	local Money = serverModule("MoneyService")
	local apiOk = PlayerData ~= nil
		and RaceConfig ~= nil
		and Money ~= nil
		and type(PlayerData.SetStore) == "function"
		and type(PlayerData.Setup) == "function"
		and type(PlayerData.Load) == "function"
		and type(PlayerData.Save) == "function"
		and type(PlayerData.SpeedStat) == "function"
		and type(PlayerData.AddSpeed) == "function"
		and type(RaceConfig.MAX_STAT) == "number"
	check(checks, "data_api_exists", apiOk and 1 or 0, 1, apiOk)
	if not apiOk then
		return result("data", checks, {})
	end
	local MAX = RaceConfig.MAX_STAT
	local removedOk = PlayerData.SpeedLevel == nil
	check(checks, "speed_level_removed", removedOk and 1 or 0, 1, removedOk)

	local cleanup = {}
	local function newPlayer(name)
		local p = Instance.new("Folder")
		p.Name = name
		p.Parent = Workspace
		table.insert(cleanup, p)
		return p
	end
	local function stat(p, name)
		local stats = p:FindFirstChild("leaderstats")
		local v = stats and stats:FindFirstChild(name)
		return v
	end
	local function val(p, name)
		local v = stat(p, name)
		return v and v.Value or nil
	end
	local function makeStore(initial)
		local store = { data = initial or {}, sets = 0, gets = 0 }
		function store:GetAsync(key)
			self.gets += 1
			return self.data[key]
		end
		function store:SetAsync(key, value)
			self.sets += 1
			self.data[key] = value
		end
		return store
	end
	local function near(a, b)
		return type(a) == "number" and math.abs(a - b) <= 1e-6
	end

	-- Setup: idempotent leaderstats with Money (IntValue 0) and Speed (NumberValue 0)
	local ps = newPlayer("CarTestDataSetup")
	local okSetup = pcall(PlayerData.Setup, ps)
	pcall(PlayerData.Setup, ps)
	local count = 0
	for _, c in ps:GetChildren() do
		if c.Name == "leaderstats" then
			count += 1
		end
	end
	check(checks, "setup_single_leaderstats", count, 1, okSetup and count == 1)
	local money, speed = stat(ps, "Money"), stat(ps, "Speed")
	local statChildren = ps:FindFirstChild("leaderstats") and #ps.leaderstats:GetChildren() or -1
	check(checks, "setup_no_duplicate_stats", statChildren, 2, statChildren == 2)
	check(
		checks,
		"setup_money_intvalue",
		money and money.ClassName == "IntValue" and 1 or 0,
		1,
		money ~= nil and money.ClassName == "IntValue" and money.Value == 0
	)
	check(
		checks,
		"setup_speed_numbervalue",
		speed and speed.ClassName == "NumberValue" and 1 or 0,
		1,
		speed ~= nil and speed.ClassName == "NumberValue" and speed.Value == 0
	)

	-- defaults
	local store = makeStore()
	PlayerData.SetStore(store)
	local p1 = newPlayer("CarTestDataP1")
	local okLoad = PlayerData.Load(p1, 9001)
	check(checks, "load_ok", okLoad == true and 1 or 0, 1, okLoad == true)
	check(checks, "default_money", val(p1, "Money") or -1, 0, val(p1, "Money") == 0)
	check(checks, "default_speed", val(p1, "Speed") or -1, 0, val(p1, "Speed") == 0)
	local speedStat = stat(p1, "Speed")
	check(
		checks,
		"speed_is_numbervalue",
		speedStat and speedStat.ClassName == "NumberValue" and 1 or 0,
		1,
		speedStat ~= nil and speedStat.ClassName == "NumberValue" and not speedStat:IsA("IntValue")
	)
	local st0 = PlayerData.SpeedStat(p1)
	check(checks, "speed_stat_default", st0 or -1, 0, st0 == 0)
	check(checks, "no_data_failed_flag", p1:GetAttribute("DataFailed") and 1 or 0, 0, not p1:GetAttribute("DataFailed"))

	-- save / load roundtrip with the same userId in a fresh player; fractional stat survives
	stat(p1, "Money").Value = 1234
	stat(p1, "Speed").Value = 12.345
	local saved = PlayerData.Save(p1, 9001)
	check(checks, "save_ok", saved == true and 1 or 0, 1, saved == true)
	local rec = store.data["Player_9001"]
	check(checks, "store_key_player_userid", rec and 1 or 0, 1, type(rec) == "table")
	local keys = 0
	for _ in store.data do
		keys += 1
	end
	check(checks, "store_only_that_key", keys, 1, keys == 1)
	if type(rec) == "table" then
		check(checks, "saved_money", rec.Money or -1, 1234, rec.Money == 1234)
		check(checks, "saved_speed", rec.Speed or -1, 12.345, near(rec.Speed, 12.345))
		check(checks, "saved_version", rec.Version or -1, 3, rec.Version == 3)
	else
		for _, name in { "saved_money", "saved_speed", "saved_version" } do
			check(checks, name, 0, 1, false)
		end
	end
	local p2 = newPlayer("CarTestDataP2")
	PlayerData.Load(p2, 9001)
	check(checks, "roundtrip_money", val(p2, "Money") or -1, 1234, val(p2, "Money") == 1234)
	check(checks, "roundtrip_speed", val(p2, "Speed") or -1, 12.345, near(val(p2, "Speed"), 12.345))
	local rs = PlayerData.SpeedStat(p2)
	check(checks, "roundtrip_speed_stat", rs or -1, 12.345, near(rs, 12.345))
	local p3 = newPlayer("CarTestDataP3")
	PlayerData.Load(p3, 9002) -- a different user does not see it
	check(checks, "other_user_isolated", val(p3, "Money") or -1, 0, val(p3, "Money") == 0 and val(p3, "Speed") == 0)

	-- sanitised save; Speed is rounded to 3 decimals
	local cases = {
		{ money = -50, speed = 0, wantMoney = 0, wantSpeed = 0, name = "negative" },
		{ money = 2e12, speed = 2e12, wantMoney = 1e12, wantSpeed = MAX, name = "huge" },
		{ money = 5, speed = -3, wantMoney = 5, wantSpeed = 0, name = "speed_negative" },
		{ money = 5, speed = math.huge, wantMoney = 5, wantSpeed = MAX, name = "speed_infinite" },
		{ money = 5, speed = 12.34567, wantMoney = 5, wantSpeed = 12.346, name = "speed_rounded" },
	}
	for i, c in cases do
		local p = newPlayer("CarTestDataSan" .. i)
		PlayerData.Load(p, 9100 + i)
		stat(p, "Money").Value = c.money
		stat(p, "Speed").Value = c.speed
		local ok = PlayerData.Save(p, 9100 + i)
		local r = store.data["Player_" .. (9100 + i)]
		local good = ok == true
			and type(r) == "table"
			and r.Money == c.wantMoney
			and near(r.Speed, c.wantSpeed)
			and r.Money == math.floor(r.Money)
			and r.Version == 3
		check(checks, "save_sanitised_" .. c.name, type(r) == "table" and r.Speed or -1, c.wantSpeed, good)
	end

	-- corrupt stored data
	local corrupt = {
		{ name = "strings", value = { Money = "lots", Speed = "fast", Version = 2 }, wantSpeed = 0 },
		{ name = "nan", value = { Money = 0 / 0, Speed = 0 / 0, Version = 2 }, wantSpeed = 0 },
		{ name = "negative", value = { Money = -500, Speed = -4, Version = 2 }, wantSpeed = 0 },
		{ name = "missing_fields", value = { Version = 2 }, wantSpeed = 0 },
		{ name = "empty_table", value = {}, wantSpeed = 0 },
		{ name = "not_a_table_string", value = "garbage", wantSpeed = 0 },
		{ name = "not_a_table_number", value = 12345, wantSpeed = 0 },
		{ name = "huge", value = { Money = 1e30, Speed = 1e30, Version = 2 }, wantSpeed = MAX },
		{ name = "infinite", value = { Money = math.huge, Speed = math.huge, Version = 2 }, wantSpeed = MAX },
	}
	for i, c in corrupt do
		local id = 9200 + i
		PlayerData.SetStore(makeStore({ ["Player_" .. id] = c.value }))
		local p = newPlayer("CarTestDataCorrupt" .. i)
		local okc, loaded = pcall(PlayerData.Load, p, id)
		local m, s = val(p, "Money"), val(p, "Speed")
		local good = okc and m ~= nil and s ~= nil and m >= 0 and m <= 1e12 and near(s, c.wantSpeed)
		if c.name ~= "huge" and c.name ~= "infinite" then
			good = good and m == 0
		end
		check(checks, "corrupt_" .. c.name, s or -1, c.wantSpeed, good and loaded == true)
	end

	-- records written by older versions (Version 1 or no Version at all) still load: money kept, Speed a
	-- valid non-negative stat, and the next save upgrades the record to Version 3
	local legacy = {
		{ name = "v1", value = { Money = 250, Speed = 3, Version = 1 }, wantMoney = 250, wantSpeed = 3 },
		{ name = "no_version", value = { Money = 250 }, wantMoney = 250, wantSpeed = 0 },
	}
	for i, c in legacy do
		local id = 9400 + i
		local legacyStore = makeStore({ ["Player_" .. id] = c.value })
		PlayerData.SetStore(legacyStore)
		local p = newPlayer("CarTestDataLegacy" .. i)
		local okl, loadedl = pcall(PlayerData.Load, p, id)
		local m, s = val(p, "Money"), val(p, "Speed")
		local goodLoad = okl and loadedl == true and m == c.wantMoney and s ~= nil and near(s, c.wantSpeed)
		check(checks, "legacy_" .. c.name .. "_loads", s or -1, c.wantSpeed, goodLoad)
		local oksv = pcall(PlayerData.Save, p, id)
		local legacyRec = legacyStore.data["Player_" .. id]
		check(
			checks,
			"legacy_" .. c.name .. "_upgraded_on_save",
			type(legacyRec) == "table" and legacyRec.Version or -1,
			3,
			oksv and type(legacyRec) == "table" and legacyRec.Version == 3 and legacyRec.Money == c.wantMoney
		)
	end

	-- failing store: get throws
	local failStore = { sets = 0 }
	function failStore:GetAsync()
		error("DataStore unavailable")
	end
	function failStore:SetAsync()
		self.sets += 1
	end
	PlayerData.SetStore(failStore)
	local pf = newPlayer("CarTestDataFail")
	local okf, loadedf = pcall(PlayerData.Load, pf, 9301)
	check(checks, "failing_load_no_throw", okf and 1 or 0, 1, okf)
	check(checks, "failing_load_returns_false", loadedf == false and 1 or 0, 1, okf and loadedf == false)
	check(
		checks,
		"failing_load_flags_player",
		pf:GetAttribute("DataFailed") == true and 1 or 0,
		1,
		pf:GetAttribute("DataFailed") == true
	)
	local stats = pf:FindFirstChild("leaderstats")
	if stats and stats:FindFirstChild("Money") then
		stats.Money.Value = 777
	end
	local oks, savedf = pcall(PlayerData.Save, pf, 9301)
	check(checks, "failed_player_save_no_throw", oks and 1 or 0, 1, oks)
	check(checks, "failed_player_save_returns_false", savedf == false and 1 or 0, 1, oks and savedf == false)
	check(checks, "failed_player_save_writes_nothing", failStore.sets, 0, failStore.sets == 0)

	-- Save before the load finished (player leaves during a slow load, or Load was never run) must not
	-- overwrite the saved record with defaults.
	local guardStore = makeStore({ ["Player_9303"] = { Money = 4321, Speed = 6.5, Version = 2 } })
	PlayerData.SetStore(guardStore)
	local pEarly = newPlayer("CarTestDataEarlySave")
	local okEarly, savedEarly = pcall(PlayerData.Save, pEarly, 9303)
	local recEarly = guardStore.data["Player_9303"]
	check(checks, "save_before_load_no_throw", okEarly and 1 or 0, 1, okEarly)
	check(checks, "save_before_load_returns_false", savedEarly == false and 1 or 0, 1, okEarly and savedEarly == false)
	check(
		checks,
		"save_before_load_keeps_record",
		type(recEarly) == "table" and recEarly.Money or -1,
		4321,
		type(recEarly) == "table" and recEarly.Money == 4321 and recEarly.Speed == 6.5
	)

	-- failing store: set throws
	local setFail = makeStore()
	function setFail:SetAsync()
		error("write throttled")
	end
	PlayerData.SetStore(setFail)
	local pss = newPlayer("CarTestDataSetFail")
	PlayerData.Load(pss, 9302)
	local oks2, saved2 = pcall(PlayerData.Save, pss, 9302)
	check(checks, "set_error_save_no_throw", oks2 and 1 or 0, 1, oks2)
	check(checks, "set_error_save_returns_false", saved2 == false and 1 or 0, 1, oks2 and saved2 == false)

	-- SpeedStat clamps to [0, MAX_STAT]
	PlayerData.SetStore(makeStore())
	local pl = newPlayer("CarTestDataStat")
	PlayerData.Load(pl, 9400)
	local speedValue = stat(pl, "Speed")
	local clampOk = speedValue ~= nil
	if speedValue then
		for _, pair in
			{ { 0, 0 }, { -5, 0 }, { 3.25, 3.25 }, { MAX, MAX }, { MAX + 50, MAX }, { 1e30, MAX }, { math.huge, MAX } }
		do
			speedValue.Value = pair[1]
			local got = PlayerData.SpeedStat(pl)
			if type(got) ~= "number" or math.abs(got - pair[2]) > 1e-6 * math.max(1, pair[2]) then
				clampOk = false
			end
		end
		speedValue.Value = 0 / 0
		local nanStat = PlayerData.SpeedStat(pl)
		if not (type(nanStat) == "number" and nanStat >= 0 and nanStat <= MAX) then
			clampOk = false
		end
	end
	check(checks, "speed_stat_clamped", clampOk and 1 or 0, 1, clampOk)
	local bare = newPlayer("CarTestDataBare")
	local okb, bareStat = pcall(PlayerData.SpeedStat, bare)
	check(checks, "speed_stat_no_stats_is_0", okb and bareStat or -1, 0, okb and bareStat == 0)
	local okab = pcall(PlayerData.AddSpeed, bare, 5)
	check(checks, "add_speed_no_stats_no_throw", okab and 1 or 0, 1, okab)

	-- AddSpeed rules
	if speedValue then
		speedValue.Value = 10
		local good, r1 = pcall(PlayerData.AddSpeed, pl, 0.5)
		check(
			checks,
			"add_speed_returns_new_stat",
			good and r1 or -1,
			10.5,
			good and near(r1, 10.5) and near(speedValue.Value, 10.5)
		)
		local rejects = { 0, -1, 0 / 0, math.huge, 1e6 + 1, "5", true, {}, -math.huge }
		local rejectOk = true
		for _, bad in rejects do
			local okr, rr = pcall(PlayerData.AddSpeed, pl, bad)
			if not okr or rr ~= nil or not near(speedValue.Value, 10.5) then
				rejectOk = false
			end
		end
		local okn, rn = pcall(PlayerData.AddSpeed, pl, nil)
		if not okn or rn ~= nil or not near(speedValue.Value, 10.5) then
			rejectOk = false
		end
		check(checks, "add_speed_rejects_bad_amounts", rejectOk and 1 or 0, 1, rejectOk)
		speedValue.Value = 0
		local okmax, rmax = pcall(PlayerData.AddSpeed, pl, 1e6)
		check(
			checks,
			"add_speed_accepts_upper_bound",
			okmax and rmax or -1,
			1e6,
			okmax and near(rmax, 1e6) and near(speedValue.Value, 1e6)
		)
		speedValue.Value = MAX - 1
		local okc, rc = pcall(PlayerData.AddSpeed, pl, 10)
		check(checks, "add_speed_clamps_to_max", okc and rc or -1, MAX, okc and rc == MAX and speedValue.Value == MAX)
	else
		for _, name in
			{
				"add_speed_returns_new_stat",
				"add_speed_rejects_bad_amounts",
				"add_speed_accepts_upper_bound",
				"add_speed_clamps_to_max",
			}
		do
			check(checks, name, 0, 1, false)
		end
	end

	-- Version 3: the car gacha state (Cars, Equipped, Rolls, StatAlloc) is saved and loaded through GachaService.
	local GachaService = serverModule("GachaService")
	local gachaApiOk = GachaService ~= nil
		and type(GachaService.Setup) == "function"
		and type(GachaService.Grant) == "function"
		and type(GachaService.Equip) == "function"
		and type(GachaService.Allocate) == "function"
		and type(GachaService.Roll) == "function"
		and type(GachaService.Snapshot) == "function"
		and type(GachaService.Apply) == "function"
		and type(GachaService.UniqueCount) == "function"
		and type(GachaService.FreePoints) == "function"
	check(checks, "data_gacha_api_exists", gachaApiOk and 1 or 0, 1, gachaApiOk)
	if gachaApiOk then
		local okG, errG = pcall(function()
			local function sameMap(a, b)
				if type(a) ~= "table" or type(b) ~= "table" then
					return false
				end
				for k, v in a do
					if b[k] ~= v then
						return false
					end
				end
				for k, v in b do
					if a[k] ~= v then
						return false
					end
				end
				return true
			end
			local zeroAlloc = { Speed = 0, Money = 0, Luck = 0, Workshop = 0 }
			-- Snapshot().Cars / saved Cars: an array of owned ids, sorted ascending, no duplicates
			local function isIdArray(t)
				if type(t) ~= "table" then
					return false
				end
				local n = 0
				for _ in t do
					n += 1
				end
				if n ~= #t then
					return false
				end
				for i, id in t do
					if type(id) ~= "string" or (i > 1 and not (t[i - 1] < id)) then
						return false
					end
				end
				return true
			end
			local function hasId(t, id)
				return type(t) == "table" and table.find(t, id) ~= nil
			end

			-- round trip
			local gStore = makeStore()
			PlayerData.SetStore(gStore)
			local g1 = newPlayer("CarTestDataGacha1")
			PlayerData.Load(g1, 9501)
			GachaService.Grant(g1, "wooden_car")
			GachaService.Grant(g1, "go_kart")
			GachaService.Grant(g1, "go_kart")
			GachaService.Grant(g1, "street_racer")
			GachaService.Roll(g1, Random.new(5))
			GachaService.Roll(g1, Random.new(6))
			GachaService.Equip(g1, "go_kart")
			GachaService.Allocate(g1, "Speed")
			local snap1 = GachaService.Snapshot(g1)
			local snapOk = type(snap1) == "table"
				and type(snap1.Cars) == "table"
				and snap1.Equipped == "go_kart"
				and snap1.Rolls == 2
				and type(snap1.StatAlloc) == "table"
				and sameMap(snap1.StatAlloc, { Speed = 1, Money = 0, Luck = 0, Workshop = 0 })
				and isIdArray(snap1.Cars)
				and hasId(snap1.Cars, "go_kart")
				and hasId(snap1.Cars, "wooden_car")
				and hasId(snap1.Cars, "street_racer")
				and not hasId(snap1.Cars, "starter")
			check(checks, "gacha_snapshot_shape", snapOk and 1 or 0, 1, snapOk)
			local savedG = PlayerData.Save(g1, 9501)
			local recG = gStore.data["Player_9501"]
			local recOk = savedG == true
				and type(recG) == "table"
				and recG.Version == 3
				and type(snap1) == "table"
				and isIdArray(recG.Cars)
				and sameMap(recG.Cars, snap1.Cars)
				and recG.Equipped == "go_kart"
				and recG.Rolls == 2
				and sameMap(recG.StatAlloc, snap1.StatAlloc)
			check(checks, "v3_save_has_gacha_fields", type(recG) == "table" and recG.Version or -1, 3, recOk)
			local g2 = newPlayer("CarTestDataGacha2")
			PlayerData.Load(g2, 9501)
			local snap2 = GachaService.Snapshot(g2)
			local rtOk = type(snap1) == "table"
				and type(snap2) == "table"
				and sameMap(snap2.Cars, snap1.Cars)
				and snap2.Equipped == "go_kart"
				and snap2.Rolls == 2
				and sameMap(snap2.StatAlloc, snap1.StatAlloc)
			check(checks, "v3_roundtrip_snapshot", rtOk and 1 or 0, 1, rtOk)
			local attrOk = g2:GetAttribute("EquippedCar") == "go_kart"
				and g2:GetAttribute("Rolls") == 2
				and g2:GetAttribute("Alloc_Speed") == 1
				and g2:GetAttribute("StatPoints") == GachaService.FreePoints(g2)
				and g2:FindFirstChild("GachaData") ~= nil
				and g2.GachaData:FindFirstChild("go_kart") ~= nil
				and g2.GachaData.go_kart:IsA("StringValue")
				and g2.GachaData.go_kart.Value == "go_kart"
				and g2.GachaData.go_kart:GetAttribute("Count") == nil
				and #g2.GachaData:GetChildren() == #snap1.Cars
			check(checks, "v3_roundtrip_attributes", attrOk and 1 or 0, 1, attrOk)

			-- a v2 save (no gacha fields) loads with the starter car, no cars, zero allocation; money and speed kept
			PlayerData.SetStore(makeStore({ ["Player_9502"] = { Money = 50, Speed = 3, Version = 2 } }))
			local g3 = newPlayer("CarTestDataGachaV2")
			local okV2 = PlayerData.Load(g3, 9502)
			local s3 = GachaService.Snapshot(g3)
			local v2Ok = okV2 == true
				and val(g3, "Money") == 50
				and near(val(g3, "Speed"), 3)
				and type(s3) == "table"
				and s3.Equipped == "starter"
				and sameMap(s3.Cars, {})
				and s3.Rolls == 0
				and sameMap(s3.StatAlloc, zeroAlloc)
				and g3:GetAttribute("EquippedCar") == "starter"
				and g3:GetAttribute("StatPoints") == 0
			check(checks, "v2_save_loads_gacha_defaults", v2Ok and 1 or 0, 1, v2Ok)

			-- cleaning on load (via PlayerData) and via Apply directly
			local function loadV3(id, name, record)
				record.Version = 3
				PlayerData.SetStore(makeStore({ ["Player_" .. id] = record }))
				local pv3 = newPlayer(name)
				local okl = PlayerData.Load(pv3, id)
				return pv3, okl, GachaService.Snapshot(pv3)
			end
			-- 3 unique = 1 earned point, 4 allocated: trimmed Workshop first, then Money, Luck -> Speed 1 left
			local pa, okA, sa = loadV3(9503, "CarTestDataGachaOver1", {
				Cars = { "go_kart", "rusty_hatchback", "wooden_car" },
				Equipped = "wooden_car",
				Rolls = 4,
				StatAlloc = { Speed = 1, Money = 1, Luck = 1, Workshop = 1 },
			})
			local overOk = okA == true
				and type(sa) == "table"
				and sameMap(sa.StatAlloc, { Speed = 1, Money = 0, Luck = 0, Workshop = 0 })
				and GachaService.FreePoints(pa) == 0
				and pa:GetAttribute("StatPoints") == 0
				and pa:GetAttribute("Alloc_Workshop") == 0
			check(checks, "over_allocation_trimmed", overOk and 1 or 0, 1, overOk)
			-- 6 unique = 2 earned, 3 allocated: only Workshop goes
			local pb, okB, sb = loadV3(9504, "CarTestDataGachaOver2", {
				Cars = { "go_kart", "hover_car", "rocket_car", "rusty_hatchback", "street_racer", "wooden_car" },
				Equipped = "starter",
				Rolls = 6,
				StatAlloc = { Speed = 0, Money = 1, Luck = 1, Workshop = 1 },
			})
			local over2Ok = okB == true
				and type(sb) == "table"
				and sameMap(sb.StatAlloc, { Speed = 0, Money = 1, Luck = 1, Workshop = 0 })
				and GachaService.FreePoints(pb) == 0
			check(checks, "over_allocation_trim_order", over2Ok and 1 or 0, 1, over2Ok)
			-- Equipped not owned -> starter; owned kept
			local _, _, sc = loadV3(9505, "CarTestDataGachaEq1", {
				Cars = { "wooden_car" },
				Equipped = "rocket_car",
				Rolls = 1,
				StatAlloc = zeroAlloc,
			})
			local _, _, sd = loadV3(9506, "CarTestDataGachaEq2", {
				Cars = { "wooden_car" },
				Equipped = "not_a_real_car",
				Rolls = 1,
				StatAlloc = zeroAlloc,
			})
			local pe, _, se = loadV3(9507, "CarTestDataGachaEq3", {
				Cars = { "wooden_car" },
				Equipped = "wooden_car",
				Rolls = 1,
				StatAlloc = zeroAlloc,
			})
			local eqOk = type(sc) == "table"
				and sc.Equipped == "starter"
				and type(sd) == "table"
				and sd.Equipped == "starter"
			check(checks, "unowned_equipped_reset_to_starter", eqOk and 1 or 0, 1, eqOk)
			check(
				checks,
				"owned_equipped_kept",
				type(se) == "table" and se.Equipped == "wooden_car" and 1 or 0,
				1,
				type(se) == "table" and se.Equipped == "wooden_car" and pe:GetAttribute("EquippedCar") == "wooden_car"
			)
			-- unknown ids are kept (a removed car is not wiped) but do not count
			local pu, _, su = loadV3(9508, "CarTestDataGachaUnknown", {
				Cars = { "retired_car", "wooden_car" },
				Equipped = "starter",
				Rolls = 5,
				StatAlloc = zeroAlloc,
			})
			local unkOk = type(su) == "table"
				and type(su.Cars) == "table"
				and sameMap(su.Cars, { "retired_car", "wooden_car" })
				and GachaService.UniqueCount(pu) == 1
			check(checks, "unknown_ids_preserved", unkOk and 1 or 0, 1, unkOk)
			local okUs = PlayerData.Save(pu, 9508)
			local sus = GachaService.Snapshot(pu)
			check(
				checks,
				"unknown_ids_survive_save",
				okUs == true and type(sus) == "table" and hasId(sus.Cars, "retired_car") and 1 or 0,
				1,
				okUs == true and type(sus) == "table" and hasId(sus.Cars, "retired_car")
			)
			-- legacy map form from earlier v3 saves: number > 0 or true = owned; 0, negative or false = not owned
			local pl3, okL, sl = loadV3(9509, "CarTestDataGachaLegacyMap", {
				Cars = { go_kart = 3, wooden_car = 0, rocket_car = true, hover_car = -1, street_racer = false },
				Equipped = "starter",
				Rolls = 3,
				StatAlloc = zeroAlloc,
			})
			local legacyOk = okL == true
				and type(sl) == "table"
				and isIdArray(sl.Cars)
				and sameMap(sl.Cars, { "go_kart", "rocket_car" })
				and GachaService.UniqueCount(pl3) == 2
				and owns(pl3, "go_kart")
				and owns(pl3, "rocket_car")
				and not owns(pl3, "wooden_car")
				and not owns(pl3, "hover_car")
				and not anyCountAttribute(pl3)
			check(checks, "legacy_map_cars_load", legacyOk and 1 or 0, 1, legacyOk)
			-- array form is cleaned: duplicates, non-strings, ids over 64 chars and "starter" dropped
			local pc, okC, sk = loadV3(9511, "CarTestDataGachaArray", {
				Cars = { "wooden_car", "go_kart", "wooden_car", 5, true, "starter", string.rep("x", 65), "go_kart" },
				Equipped = "starter",
				Rolls = 3,
				StatAlloc = zeroAlloc,
			})
			local arrayOk = okC == true
				and type(sk) == "table"
				and isIdArray(sk.Cars)
				and sameMap(sk.Cars, { "go_kart", "wooden_car" })
				and GachaService.UniqueCount(pc) == 2
				and entriesNamed(pc, "wooden_car") == 1
				and entriesNamed(pc, "starter") == 0
				and ownedUnique(pc) == 2
			check(checks, "array_cars_cleaned", arrayOk and 1 or 0, 1, arrayOk)
			-- Apply directly: junk input gives defaults, never an error
			local applyOk = true
			for i, junk in { "garbage", 12345, true } do
				local pj = newPlayer("CarTestDataGachaJunk" .. i)
				GachaService.Setup(pj)
				local okj = pcall(GachaService.Apply, pj, junk)
				local sj = GachaService.Snapshot(pj)
				if
					not okj
					or type(sj) ~= "table"
					or sj.Equipped ~= "starter"
					or not sameMap(sj.Cars, {})
					or sj.Rolls ~= 0
					or not sameMap(sj.StatAlloc, zeroAlloc)
				then
					applyOk = false
				end
			end
			local pn = newPlayer("CarTestDataGachaNil")
			GachaService.Setup(pn)
			local okn = pcall(GachaService.Apply, pn, nil)
			local sn = GachaService.Snapshot(pn)
			applyOk = applyOk and okn and type(sn) == "table" and sn.Equipped == "starter"
			check(checks, "apply_junk_is_defaults", applyOk and 1 or 0, 1, applyOk)
			-- Apply -> Snapshot keeps unknown ids
			local pk = newPlayer("CarTestDataGachaApply")
			GachaService.Setup(pk)
			GachaService.Apply(pk, {
				Cars = { "old_car_v1", "go_kart" },
				Equipped = "go_kart",
				Rolls = 9,
				StatAlloc = zeroAlloc,
			})
			local sp = GachaService.Snapshot(pk)
			local applyKeepOk = type(sp) == "table"
				and isIdArray(sp.Cars)
				and sameMap(sp.Cars, { "go_kart", "old_car_v1" })
				and sp.Equipped == "go_kart"
				and sp.Rolls == 9
			check(checks, "apply_snapshot_keeps_unknown_ids", applyKeepOk and 1 or 0, 1, applyKeepOk)

			-- still never writes before the load finished: a v3 record is left alone
			local v3Rec = {
				Money = 10,
				Speed = 1,
				Version = 3,
				Cars = { "hover_car" },
				Equipped = "hover_car",
				Rolls = 99,
				StatAlloc = zeroAlloc,
			}
			local guard3 = makeStore({ ["Player_9510"] = v3Rec })
			PlayerData.SetStore(guard3)
			local pEarly3 = newPlayer("CarTestDataGachaEarly")
			GachaService.Setup(pEarly3)
			local okE3, savedE3 = pcall(PlayerData.Save, pEarly3, 9510)
			local r3 = guard3.data["Player_9510"]
			local keptOk = okE3
				and savedE3 == false
				and guard3.sets == 0
				and type(r3) == "table"
				and r3.Rolls == 99
				and r3.Equipped == "hover_car"
				and type(r3.Cars) == "table"
				and r3.Cars[1] == "hover_car"
			check(checks, "v3_save_before_load_keeps_record", keptOk and 1 or 0, 1, keptOk)
		end)
		if not okG then
			check(checks, "data_gacha_no_error", 0, tostring(errG), false)
		end
	end

	for _, inst in cleanup do
		inst:Destroy()
	end
	return result("data", checks, {})
end

-- HUD: pure formatting and smoothing (Shared/HudFormat).
function Scenarios.hud()
	local checks = {}
	local HudFormat = sharedModule("HudFormat")
	local RaceConfig = sharedModule("RaceConfig")
	local apiOk = HudFormat ~= nil
		and RaceConfig ~= nil
		and type(HudFormat.SpeedText) == "function"
		and type(HudFormat.RateText) == "function"
		and type(HudFormat.Approach) == "function"
		and type(RaceConfig.SpeedFor) == "function"
	check(checks, "hud_api_exists", apiOk and 1 or 0, 1, apiOk)
	if not apiOk then
		return result("hud", checks, {})
	end
	local function call(fn, ...)
		local ok, r = pcall(fn, ...)
		return ok and r or nil
	end

	local textCases = {
		{ 1234.9, "1,234" },
		{ 0.4, "0" },
		{ 0, "0" },
		{ 999, "999" },
		{ 1000, "1,000" },
		{ 12.345, "12" },
		{ 1e6, "1,000,000" },
		{ 123456789, "123,456,789" },
		{ 1e9, "1,000,000,000" },
	}
	local textOk = true
	for _, c in textCases do
		if call(HudFormat.SpeedText, c[1]) ~= c[2] then
			textOk = false
		end
	end
	check(checks, "speed_text_format", textOk and 1 or 0, 1, textOk)
	local badOk = call(HudFormat.SpeedText, nil) == "0"
	for _, b in { 0 / 0, -5, "12", true, {}, -math.huge } do
		if call(HudFormat.SpeedText, b) ~= "0" then
			badOk = false
		end
	end
	check(checks, "speed_text_bad_input_is_zero", badOk and 1 or 0, 1, badOk)
	local clampOk = true
	for _, b in { math.huge, 1e30, 1e15, 5e9 } do
		local s = call(HudFormat.SpeedText, b)
		if s ~= "1,000,000,000" then
			clampOk = false
		end
	end
	check(checks, "speed_text_huge_clamped", clampOk and 1 or 0, 1, clampOk)
	local sciOk = true
	for _, v in { 1e6, 1e9, 1e15, 1e30, math.huge, 123456.789 } do
		local s = call(HudFormat.SpeedText, v)
		if type(s) ~= "string" or string.find(s, "[eE%.]") or string.find(s, "inf") then
			sciOk = false
		end
	end
	check(checks, "speed_text_no_scientific", sciOk and 1 or 0, 1, sciOk)

	local rateOk = true
	for _, s in { 0, 250, 1000, 5000, 1e5, 1e9 } do
		local want = string.format("%d studs/s", math.round(RaceConfig.SpeedFor(s)))
		if call(HudFormat.RateText, s) ~= want then
			rateOk = false
		end
	end
	check(checks, "rate_text_matches_speed_for", rateOk and 1 or 0, 1, rateOk)

	local A = HudFormat.Approach
	local function near(a, b)
		return type(a) == "number" and math.abs(a - b) <= 1e-9
	end
	local dtOk = near(call(A, 5, 10, 0), 5) and near(call(A, 5, 10, -1), 5) and near(call(A, 5, 10, 0 / 0), 5)
	dtOk = dtOk and near(call(A, 5, 10, nil), 5) and near(call(A, 5, 10, "x"), 5)
	check(checks, "approach_bad_dt_returns_shown", dtOk and 1 or 0, 1, dtOk)
	local nonNumOk = near(call(A, 5, nil, 0.1), 5) and near(call(A, 5, "x", 0.1), 5) and near(call(A, 5, 0 / 0, 0.1), 5)
	nonNumOk = nonNumOk and near(call(A, nil, 50, 0.1), 50) and near(call(A, "x", 50, 0.1), 50)
	check(checks, "approach_bad_value_safe", nonNumOk and 1 or 0, 1, nonNumOk)
	local snapDown = near(call(A, 100, 50, 0.016), 50) and near(call(A, 100, 0, 0.016), 0)
	check(checks, "approach_snaps_down", snapDown and 1 or 0, 1, snapDown)
	check(checks, "approach_equal_stays", near(call(A, 5, 5, 0.1), 5) and 1 or 0, 1, near(call(A, 5, 5, 0.1), 5))
	local dt = 1 / 60
	local step = call(A, 0, 100, dt)
	local expect = 100 * (1 - math.exp(-8 * dt))
	check(
		checks,
		"approach_exponential_step",
		step or -1,
		expect,
		type(step) == "number" and step >= 0.9 * expect and step <= 1.1 * expect
	)
	local big = call(A, 0, 100, 10)
	check(checks, "approach_no_overshoot", big or -1, 100, type(big) == "number" and big <= 100 and big >= 99.99)
	check(
		checks,
		"approach_snaps_when_close",
		near(call(A, 99.997, 100, 0.0001), 100) and 1 or 0,
		1,
		near(call(A, 99.997, 100, 0.0001), 100)
	)
	local shown, monotone, over = 0, true, false
	local target = 1234
	for _ = 1, 600 do
		local nxt = call(A, shown, target, dt)
		if type(nxt) ~= "number" then
			monotone = false
			break
		end
		if nxt < shown then
			monotone = false
		end
		if nxt > target then
			over = true
		end
		shown = nxt
	end
	check(checks, "approach_monotone_no_overshoot", monotone and not over and 1 or 0, 1, monotone and not over)
	check(checks, "approach_converges", shown, target, near(shown, target))

	-- Auto race toggle button text and the MONEY row (brief: "Stop Auto" / "Auto Race" button; "Money stat is
	-- displayed under speed stat on the left").
	local toggleApiOk = type(HudFormat.AutoButtonText) == "function" and type(HudFormat.MoneyText) == "function"
	check(checks, "hud_toggle_api_exists", toggleApiOk and 1 or 0, 1, toggleApiOk)
	if not toggleApiOk then
		return result("hud", checks, {})
	end
	local B = HudFormat.AutoButtonText
	check(checks, "auto_button_text_racing", call(B, true) == "Stop Auto" and 1 or 0, 1, call(B, true) == "Stop Auto")
	local walkingOk = call(B, false) == "Auto Race" and call(B, nil) == "Auto Race"
	check(checks, "auto_button_text_walking", walkingOk and 1 or 0, 1, walkingOk)
	local moneyCases = {
		{ 0, "$0" },
		{ 5, "$5" },
		{ 999, "$999" },
		{ 1000, "$1,000" },
		{ 1234, "$1,234" },
		{ 99.9, "$99" },
		{ 1234.99, "$1,234" },
		{ 1e6, "$1,000,000" },
		{ 123456789, "$123,456,789" },
		{ 1e12, "$1,000,000,000,000" },
	}
	local moneyOk = true
	for _, c in moneyCases do
		if call(HudFormat.MoneyText, c[1]) ~= c[2] then
			moneyOk = false
		end
	end
	check(checks, "money_text_format", moneyOk and 1 or 0, 1, moneyOk)
	local moneyBadOk = call(HudFormat.MoneyText, nil) == "$0"
	for _, b in { -1, -5000, 0 / 0, "12", true, {}, -math.huge } do
		if call(HudFormat.MoneyText, b) ~= "$0" then
			moneyBadOk = false
		end
	end
	check(checks, "money_text_bad_input_is_zero", moneyBadOk and 1 or 0, 1, moneyBadOk)

	-- Gacha odds text for the index ("1 in N" with thousands separators)
	local oddsApiOk = type(HudFormat.Odds) == "function"
	check(checks, "hud_odds_api_exists", oddsApiOk and 1 or 0, 1, oddsApiOk)
	if oddsApiOk then
		local oddsCases = {
			{ 10, "1 in 10" },
			{ 50, "1 in 50" },
			{ 250, "1 in 250" },
			{ 1000, "1 in 1,000" },
			{ 10000, "1 in 10,000" },
			{ 100000, "1 in 100,000" },
		}
		local oddsOk = true
		for _, c in oddsCases do
			if call(HudFormat.Odds, c[1]) ~= c[2] then
				oddsOk = false
			end
		end
		check(checks, "odds_text_format", oddsOk and 1 or 0, 1, oddsOk)
	end
	return result("hud", checks, {})
end

-- Car gacha + index + stat allocation (plan: car gacha, index and stat allocation). The expected catalog is the
-- design doc's 7 placeholder cars; every number below comes from the brief / API contract, not from an implementation.
local GACHA_SEED = {
	{ Id = "rusty_hatchback", Rarity = "Common", Chance = nil, SpeedMulti = 1.1 },
	{ Id = "wooden_car", Rarity = "Uncommon", Chance = 10, SpeedMulti = 1.25 },
	{ Id = "go_kart", Rarity = "Rare", Chance = 50, SpeedMulti = 2 },
	{ Id = "street_racer", Rarity = "Epic", Chance = 250, SpeedMulti = 6 },
	{ Id = "rocket_car", Rarity = "Legendary", Chance = 1000, SpeedMulti = 25 },
	{ Id = "hover_car", Rarity = "Mythic", Chance = 10000, SpeedMulti = 150 },
	{ Id = "void_racer", Rarity = "Secret", Chance = 100000, SpeedMulti = 1000 },
}
local GACHA_RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local GACHA_STATS = { "Speed", "Money", "Luck", "Workshop" }
local GACHA_PER_POINT = { Speed = 0.1, Money = 0.1, Luck = 0.05, Workshop = 0.2 }
local GACHA_ROLLS = 100000
local GACHA_SEED_LUCK1 = 20261001
local GACHA_SEED_LUCK10 = 777
local GACHA_SIGMAS = 4 -- per-car frequency tolerance: 4 binomial sigma + a small floor (deterministic seeds)
local GACHA_FLOOR = 3
local AUTO_ROLL_WAIT = 10 -- seconds of auto-rolling; at ROLL_INTERVAL = 3 that is 3 (or 4) rolls, +-1 allowed
local INDEX_ORIGIN = Vector3.new(-20000, 0, -20000)
local INDEX_RACE_SECONDS = 6
local INDEX_SETTLE_MIN = 1 -- seconds to wait after building the index tracks before the gain runs start...
local INDEX_SETTLE_FRAMES = 60 -- ...and this many frames in a row shorter than INDEX_SETTLE_MAX_DT
local INDEX_SETTLE_MAX_DT = 0.03
local INDEX_SETTLE_CAP = 10

-- Expected "1 in N" result per car at a given luck: rarest first, a car hits with min(1, luck/N), the first hit
-- wins and the catch-all gets whatever is left.
local function gachaExpected(luck)
	local rollable = {}
	local catchAll
	for _, c in GACHA_SEED do
		if c.Chance then
			table.insert(rollable, c)
		else
			catchAll = c
		end
	end
	table.sort(rollable, function(a, b)
		return a.Chance > b.Chance
	end)
	local expected, remaining = {}, 1
	for _, c in rollable do
		local p = math.min(1, luck / c.Chance)
		expected[c.Id] = remaining * p
		remaining *= 1 - p
	end
	expected[catchAll.Id] = remaining
	return expected
end

local function gachaModules()
	local CarCatalog = sharedModule("CarCatalog")
	local GachaConfig = sharedModule("GachaConfig")
	local GachaService = serverModule("GachaService")
	return CarCatalog, GachaConfig, GachaService
end

local function newTestPlayer(cleanup, name)
	local p = Instance.new("Folder")
	p.Name = name
	p.Parent = Workspace
	table.insert(cleanup, p)
	return p
end

local function nearly(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= 1e-9 * math.max(1, math.abs(b))
end

-- Gacha: catalog, config, seeded roll odds, grant/duplicates, the auto-roll timer.
function Scenarios.gacha()
	local checks = {}
	local CarCatalog, GachaConfig, GachaService = gachaModules()
	local catalogOk = CarCatalog ~= nil
		and type(CarCatalog.Get) == "function"
		and type(CarCatalog.All) == "function"
		and type(CarCatalog.Rollable) == "function"
	local configOk = GachaConfig ~= nil
		and type(GachaConfig.Roll) == "function"
		and type(GachaConfig.EarnedPoints) == "function"
		and type(GachaConfig.Multis) == "function"
	local serviceOk = GachaService ~= nil
		and type(GachaService.Setup) == "function"
		and type(GachaService.Grant) == "function"
		and type(GachaService.Roll) == "function"
		and type(GachaService.Equip) == "function"
		and type(GachaService.Allocate) == "function"
		and type(GachaService.UniqueCount) == "function"
		and type(GachaService.StartAutoRoll) == "function"
		and type(GachaService.Snapshot) == "function"
		and type(GachaService.Apply) == "function"
		and type(GachaService.Start) == "function"
	check(checks, "car_catalog_api_exists", catalogOk and 1 or 0, 1, catalogOk)
	check(checks, "gacha_config_api_exists", configOk and 1 or 0, 1, configOk)
	check(checks, "gacha_service_api_exists", serviceOk and 1 or 0, 1, serviceOk)
	if not (catalogOk and configOk and serviceOk) then
		return result("gacha", checks, {})
	end
	local metrics = {}

	-- Config constants
	check(checks, "roll_interval", GachaConfig.ROLL_INTERVAL or -1, 3, GachaConfig.ROLL_INTERVAL == 3)
	check(
		checks,
		"discoveries_per_point",
		GachaConfig.DISCOVERIES_PER_POINT or -1,
		3,
		GachaConfig.DISCOVERIES_PER_POINT == 3
	)
	local statsOk = type(GachaConfig.STATS) == "table" and #GachaConfig.STATS == #GACHA_STATS
	if statsOk then
		for i, s in GACHA_STATS do
			if GachaConfig.STATS[i] ~= s then
				statsOk = false
			end
		end
	end
	check(checks, "stats_list", statsOk and 1 or 0, 1, statsOk)
	local perOk = type(GachaConfig.PER_POINT) == "table"
	if perOk then
		for s, v in GACHA_PER_POINT do
			if not nearly(GachaConfig.PER_POINT[s], v) then
				perOk = false
			end
		end
	end
	check(checks, "per_point_values", perOk and 1 or 0, 1, perOk)
	local rarityOk = type(GachaConfig.RARITY_ORDER) == "table" and #GachaConfig.RARITY_ORDER == #GACHA_RARITY_ORDER
	local colorsOk = type(GachaConfig.RARITY_COLORS) == "table"
	if rarityOk then
		for i, r in GACHA_RARITY_ORDER do
			if GachaConfig.RARITY_ORDER[i] ~= r then
				rarityOk = false
			end
		end
	end
	for _, r in GACHA_RARITY_ORDER do
		if not (colorsOk and typeof(GachaConfig.RARITY_COLORS[r]) == "Color3") then
			colorsOk = false
		end
	end
	check(checks, "rarity_order", rarityOk and 1 or 0, 1, rarityOk)
	check(checks, "rarity_colors", colorsOk and 1 or 0, 1, colorsOk)

	-- Catalog
	check(checks, "starter_id", CarCatalog.STARTER_ID == "starter" and 1 or 0, 1, CarCatalog.STARTER_ID == "starter")
	local starter = CarCatalog.Get("starter")
	local starterOk = type(starter) == "table"
		and starter.SpeedMulti == 1
		and starter.Chance == nil
		and starter.Rollable == false
	check(checks, "starter_spec", starterOk and 1 or 0, 1, starterOk)
	check(
		checks,
		"get_unknown_nil",
		CarCatalog.Get("no_such_car") == nil and 1 or 0,
		1,
		CarCatalog.Get("no_such_car") == nil
	)
	local okAll, all = pcall(CarCatalog.All)
	local okRoll, rollable = pcall(CarCatalog.Rollable)
	all = okAll and type(all) == "table" and all or {}
	rollable = okRoll and type(rollable) == "table" and rollable or {}
	check(checks, "catalog_seven_cars", #all, #GACHA_SEED, #all == #GACHA_SEED)
	check(checks, "rollable_seven_cars", #rollable, #GACHA_SEED, #rollable == #GACHA_SEED)
	local seen, idsOk, snakeOk, catchAlls, starterInAll = {}, true, true, 0, false
	local rarityValid, multiOk, chanceOk = true, true, true
	local validRarity = {}
	for _, r in GACHA_RARITY_ORDER do
		validRarity[r] = true
	end
	for _, c in all do
		local id = type(c) == "table" and c.Id or nil
		if type(id) ~= "string" or seen[id] then
			idsOk = false
		else
			seen[id] = true
			-- lowercase letter first, then [a-z0-9_], no "__", no trailing "_" (Lua patterns cannot repeat a group)
			if
				not string.match(id, "^[a-z][a-z0-9_]*$")
				or string.find(id, "__", 1, true)
				or string.match(id, "_$")
			then
				snakeOk = false
			end
		end
		if id == "starter" then
			starterInAll = true
		end
		if type(c) == "table" then
			if c.Chance == nil then
				catchAlls += 1
			elseif type(c.Chance) ~= "number" or c.Chance ~= math.floor(c.Chance) or c.Chance < 2 then
				chanceOk = false
			end
			if not validRarity[c.Rarity] then
				rarityValid = false
			end
			if type(c.SpeedMulti) ~= "number" or c.SpeedMulti < 1 then
				multiOk = false
			end
		end
	end
	check(checks, "catalog_ids_unique", idsOk and 1 or 0, 1, idsOk and #all > 0)
	check(checks, "catalog_ids_snake_case", snakeOk and 1 or 0, 1, snakeOk and #all > 0)
	check(checks, "catalog_starter_excluded", starterInAll and 1 or 0, 0, not starterInAll)
	check(checks, "catalog_one_catch_all", catchAlls, 1, catchAlls == 1)
	check(checks, "catalog_chance_integers", chanceOk and 1 or 0, 1, chanceOk)
	check(checks, "catalog_rarity_valid", rarityValid and 1 or 0, 1, rarityValid and #all > 0)
	check(checks, "catalog_speed_multi_at_least_1", multiOk and 1 or 0, 1, multiOk and #all > 0)
	local seedOk = true
	for _, want in GACHA_SEED do
		local got = CarCatalog.Get(want.Id)
		if
			type(got) ~= "table"
			or got.Id ~= want.Id
			or got.Rarity ~= want.Rarity
			or got.Chance ~= want.Chance
			or not nearly(got.SpeedMulti, want.SpeedMulti)
			or type(got.Name) ~= "string"
			or got.Model ~= nil
		then
			seedOk = false
		end
	end
	check(checks, "catalog_matches_design_doc", seedOk and 1 or 0, 1, seedOk)
	local orderOk, orders = #all > 0, {}
	for i, c in all do
		local o = type(c) == "table" and c.Order or nil
		if type(o) ~= "number" or orders[o] or (i > 1 and o <= all[i - 1].Order) then
			orderOk = false
			break
		end
		orders[o] = true
	end
	check(checks, "all_sorted_by_order", orderOk and 1 or 0, 1, orderOk)
	local rarestOk = #rollable > 0
	for i, c in rollable do
		local last = i == #rollable
		if type(c) ~= "table" then
			rarestOk = false
			break
		end
		if last then
			if c.Chance ~= nil then
				rarestOk = false
			end
		elseif c.Chance == nil or (i > 1 and c.Chance >= rollable[i - 1].Chance) then
			rarestOk = false
		end
	end
	check(checks, "rollable_rarest_first", rarestOk and 1 or 0, 1, rarestOk)

	-- Seeded roll odds at luck 1 and luck 10
	local validIds = {}
	for _, c in GACHA_SEED do
		validIds[c.Id] = true
	end
	local function rollMany(seed, luck)
		local counts, invalid = {}, 0
		local ok = pcall(function()
			local rng = Random.new(seed)
			for _ = 1, GACHA_ROLLS do
				local id = GachaConfig.Roll(rng, luck)
				if validIds[id] then
					counts[id] = (counts[id] or 0) + 1
				else
					invalid += 1
				end
			end
		end)
		return ok, counts, invalid
	end
	for _, case in
		{
			{ luck = 1, seed = GACHA_SEED_LUCK1, tag = "luck1" },
			{ luck = 10, seed = GACHA_SEED_LUCK10, tag = "luck10" },
		}
	do
		local ok, counts, invalid = rollMany(case.seed, case.luck)
		check(checks, "roll_no_error_" .. case.tag, ok and 1 or 0, 1, ok)
		check(checks, "roll_always_valid_id_" .. case.tag, invalid, 0, ok and invalid == 0)
		local expected = gachaExpected(case.luck)
		for _, c in GACHA_SEED do
			local mean = GACHA_ROLLS * expected[c.Id]
			local sigma = math.sqrt(GACHA_ROLLS * expected[c.Id] * (1 - expected[c.Id]))
			local tol = GACHA_SIGMAS * sigma + GACHA_FLOOR
			local got = counts[c.Id] or 0
			metrics[case.tag .. "_" .. c.Id] = got
			check(
				checks,
				"roll_odds_" .. case.tag .. "_" .. c.Id,
				got,
				string.format("%.1f +- %.1f", mean, tol),
				ok and math.abs(got - mean) <= tol
			)
		end
		if case.luck == 10 then
			-- 10/10: the Uncommon always hits, so the catch-all is never reached
			local common = counts.rusty_hatchback or 0
			check(checks, "luck10_catch_all_never", common, 0, ok and common == 0)
		end
	end
	-- Bad luck (nil, NaN, below 1) is treated as luck 1: the same seed gives the same sequence
	local badLuckOk = true
	local badLucks = { "nil", 0 / 0, 0, 0.5, -5, "10", true }
	for _, badKey in badLucks do
		local bad = badKey
		if badKey == "nil" then
			bad = nil
		end
		local okb = pcall(function()
			local a, b = Random.new(4242), Random.new(4242)
			for _ = 1, 3000 do
				if GachaConfig.Roll(a, bad) ~= GachaConfig.Roll(b, 1) then
					badLuckOk = false
					break
				end
			end
		end)
		if not okb then
			badLuckOk = false
		end
	end
	check(checks, "roll_bad_luck_is_luck_1", badLuckOk and 1 or 0, 1, badLuckOk)

	-- GachaService on fake players
	local cleanup = {}
	local autoHandle
	local okBody, err = pcall(function()
		-- start the auto-roll first so its wall-clock wait overlaps the rest of the scenario
		local pa = newTestPlayer(cleanup, "CarTestGachaAuto")
		GachaService.Setup(pa)
		local autoStart = os.clock()
		autoHandle = GachaService.StartAutoRoll(pa)
		check(
			checks,
			"auto_roll_handle",
			type(autoHandle) == "table" and type(autoHandle.Stop) == "function" and 1 or 0,
			1,
			type(autoHandle) == "table" and type(autoHandle.Stop) == "function"
		)

		local p = newTestPlayer(cleanup, "CarTestGachaP1")
		GachaService.Setup(p)
		GachaService.Setup(p) -- idempotent
		local folders = 0
		for _, c in p:GetChildren() do
			if c.Name == "GachaData" then
				folders += 1
			end
		end
		check(checks, "setup_single_gacha_data", folders, 1, folders == 1 and p.GachaData:IsA("Folder"))
		local defaultsOk = p:GetAttribute("EquippedCar") == "starter"
			and p:GetAttribute("Rolls") == 0
			and p:GetAttribute("StatPoints") == 0
		for _, s in GACHA_STATS do
			if p:GetAttribute("Alloc_" .. s) ~= 0 then
				defaultsOk = false
			end
		end
		check(checks, "setup_default_attributes", defaultsOk and 1 or 0, 1, defaultsOk)
		check(checks, "setup_no_cars_owned", #p.GachaData:GetChildren(), 0, #p.GachaData:GetChildren() == 0)

		-- Grant: new, duplicate, unknown
		local g1 = GachaService.Grant(p, "wooden_car")
		local v = p.GachaData:FindFirstChild("wooden_car")
		check(checks, "grant_new_returns_true", g1 == true and 1 or 0, 1, g1 == true)
		check(
			checks,
			"grant_new_adds_stringvalue",
			owns(p, "wooden_car") and 1 or 0,
			1,
			v ~= nil and owns(p, "wooden_car") and v:GetAttribute("Count") == nil
		)
		local g2 = GachaService.Grant(p, "wooden_car")
		check(checks, "grant_duplicate_returns_false", g2 == false and 1 or 0, 1, g2 == false)
		local dupSame = owns(p, "wooden_car") and entriesNamed(p, "wooden_car") == 1 and not anyCountAttribute(p)
		check(checks, "grant_duplicate_no_change", entriesNamed(p, "wooden_car"), 1, dupSame)
		local dupNoExtra = #p.GachaData:GetChildren() == 1
		check(checks, "grant_duplicate_no_new_entry", #p.GachaData:GetChildren(), 1, dupNoExtra)
		local rejectOk = true
		for _, bad in { "no_such_car", "starter", "", 5, true, {} } do
			local okg, r = pcall(GachaService.Grant, p, bad)
			if not okg or r ~= nil then
				rejectOk = false
			end
		end
		local okNil, rNil = pcall(GachaService.Grant, p, nil)
		rejectOk = rejectOk and okNil and rNil == nil
		check(checks, "grant_unknown_returns_nil", rejectOk and 1 or 0, 1, rejectOk)
		check(
			checks,
			"grant_unknown_no_change",
			#p.GachaData:GetChildren(),
			1,
			#p.GachaData:GetChildren() == 1 and owns(p, "wooden_car")
		)

		-- Roll through the service: counts Rolls, grants the rolled car
		local q = newTestPlayer(cleanup, "CarTestGachaP2")
		GachaService.Setup(q)
		local id1, new1 = GachaService.Roll(q, Random.new(99))
		check(checks, "service_roll_valid_id", validIds[id1] and 1 or 0, 1, validIds[id1] == true)
		check(checks, "service_roll_first_is_new", new1 == true and 1 or 0, 1, new1 == true)
		check(checks, "service_roll_grants_car", owns(q, id1) and 1 or 0, 1, owns(q, id1))
		check(checks, "service_roll_increments_rolls", q:GetAttribute("Rolls") or -1, 1, q:GetAttribute("Rolls") == 1)
		local rng = Random.new(100)
		local rolledOwned, newMatches = owns(q, id1), true
		for _ = 1, 20 do
			local ownedBefore = {}
			for _, c in GACHA_SEED do
				ownedBefore[c.Id] = owns(q, c.Id)
			end
			local id, isNew = GachaService.Roll(q, rng)
			if not owns(q, id) then
				rolledOwned = false
			end
			-- a duplicate roll returns (id, false); a first discovery (id, true)
			if validIds[id] and isNew ~= not ownedBefore[id] then
				newMatches = false
			end
		end
		check(checks, "service_rolls_counted", q:GetAttribute("Rolls") or -1, 21, q:GetAttribute("Rolls") == 21)
		local uq = ownedUnique(q)
		check(
			checks,
			"service_rolls_all_granted",
			uq,
			"1..min(Rolls, 7)",
			rolledOwned and uq >= 1 and uq <= math.min(21, #GACHA_SEED) and GachaService.UniqueCount(q) == uq
		)
		check(checks, "service_roll_is_new_matches_ownership", newMatches and 1 or 0, 1, newMatches)
		check(checks, "service_roll_no_count_attribute", anyCountAttribute(q) and 1 or 0, 0, not anyCountAttribute(q))
		local okDefault, idD = pcall(GachaService.Roll, q)
		check(
			checks,
			"service_roll_default_rng",
			okDefault and validIds[idD] and 1 or 0,
			1,
			okDefault and validIds[idD] == true
		)

		-- Turbo luck (docs/SPAWN_AND_ROLLS_SPEC.md section 4). BRIEF (owner, 2026-10-01): "A turbo luck bar: every X
		-- auto rolls one roll gets multiplied luck." Every TURBO_EVERY-th roll (Rolls = 10, 20, ...) rolls at
		-- Luck * TURBO_LUCK; Roll returns (id, isNew, turboMulti).
		check(checks, "turbo_every", GachaConfig.TURBO_EVERY or -1, 10, GachaConfig.TURBO_EVERY == 10)
		check(checks, "turbo_luck", GachaConfig.TURBO_LUCK or -1, 5, GachaConfig.TURBO_LUCK == 5)
		local turboApi = type(GachaConfig.IsTurbo) == "function" and type(GachaConfig.TurboProgress) == "function"
		check(checks, "turbo_api_exists", turboApi and 1 or 0, 1, turboApi)
		if turboApi then
			local isTurboBad = 0
			for n, want in
				{
					[0] = false,
					[1] = false,
					[5] = false,
					[9] = false,
					[10] = true,
					[11] = false,
					[19] = false,
					[20] = true,
					[30] = true,
					[100] = true,
					[-10] = false,
				}
			do
				local okT, got = pcall(GachaConfig.IsTurbo, n)
				if not okT or got ~= want then
					isTurboBad += 1
				end
			end
			check(checks, "turbo_is_turbo_values", isTurboBad, 0, isTurboBad == 0)
			local progressBad = 0
			for n, want in { [0] = 0, [1] = 1, [9] = 9, [10] = 0, [13] = 3, [20] = 0, [25] = 5, [99] = 9 } do
				local okT, got = pcall(GachaConfig.TurboProgress, n)
				if not okT or got ~= want then
					progressBad += 1
				end
			end
			check(checks, "turbo_progress_values", progressBad, 0, progressBad == 0)
		end
		-- 25 service rolls from 0: turboMulti is TURBO_LUCK on rolls 10 and 20 only, 1 on every other
		local tp = newTestPlayer(cleanup, "CarTestGachaTurbo")
		GachaService.Setup(tp)
		local multiBad, turboRolls = 0, 0
		for k = 1, 25 do
			local okT, _, _, multi = pcall(GachaService.Roll, tp, Random.new(7000 + k))
			local want = k % 10 == 0 and 5 or 1
			if not okT or multi ~= want then
				multiBad += 1
			end
			if okT and multi == 5 then
				turboRolls += 1
			end
		end
		check(checks, "turbo_multi_every_10th_roll", multiBad, 0, multiBad == 0 and turboRolls == 2)
		check(checks, "turbo_rolls_counted", tp:GetAttribute("Rolls") or -1, 25, tp:GetAttribute("Rolls") == 25)
		-- The turbo roll really uses Luck * 5: with a seed where luck and luck * 5 pick different cars, the service's
		-- 10th roll matches GachaConfig.Roll at luck * 5 and its 11th roll matches it at plain luck
		local tq = newTestPlayer(cleanup, "CarTestGachaTurboLuck")
		GachaService.Setup(tq)
		local luck = GachaService.Luck(tq)
		local seed, idTurbo, idPlain = nil, nil, nil
		for sd = 1, 5000 do
			local a = GachaConfig.Roll(Random.new(sd), luck * 5)
			local b = GachaConfig.Roll(Random.new(sd), luck)
			if a ~= b then
				seed, idTurbo, idPlain = sd, a, b
				break
			end
		end
		check(checks, "turbo_seed_found", seed or -1, 1, seed ~= nil)
		if seed then
			metrics.turboSeed = seed
			tq:SetAttribute("Rolls", 9)
			local okA, idA, _, mA = pcall(GachaService.Roll, tq, Random.new(seed))
			local turboOk = okA and idA == idTurbo and mA == 5 and tq:GetAttribute("Rolls") == 10
			check(checks, "turbo_roll_uses_luck_x5", turboOk and 1 or 0, 1, turboOk)
			local okB, idB, _, mB = pcall(GachaService.Roll, tq, Random.new(seed))
			local plainOk = okB and idB == idPlain and mB == 1 and tq:GetAttribute("Rolls") == 11
			check(checks, "turbo_next_roll_plain_luck", plainOk and 1 or 0, 1, plainOk)
			tq:SetAttribute("Rolls", 19)
			local okC, idC, _, mC = pcall(GachaService.Roll, tq, Random.new(seed))
			local turbo20 = okC and idC == idTurbo and mC == 5 and tq:GetAttribute("Rolls") == 20
			check(checks, "turbo_roll_20th_uses_luck_x5", turbo20 and 1 or 0, 1, turbo20)
		end

		-- Remotes exist (GachaService.Start is called by Main at boot)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local equipR = remotes and remotes:FindFirstChild("EquipCar")
		local allocR = remotes and remotes:FindFirstChild("AllocateStat")
		local remotesOk = equipR ~= nil and equipR:IsA("RemoteEvent") and allocR ~= nil and allocR:IsA("RemoteEvent")
		check(checks, "remotes_exist", remotesOk and 1 or 0, 1, remotesOk)

		-- Auto-roll: about one roll every ROLL_INTERVAL seconds, then Stop stops it
		while os.clock() - autoStart < AUTO_ROLL_WAIT do
			task.wait(0.1)
		end
		local autoRolls = pa:GetAttribute("Rolls") or -1
		metrics.autoRolls = autoRolls
		check(checks, "auto_roll_rate", autoRolls, "3..4 (+-1)", autoRolls >= 2 and autoRolls <= 5)
		local ua = ownedUnique(pa)
		check(
			checks,
			"auto_roll_grants_cars",
			ua,
			"1..min(Rolls, 7)",
			ua >= 1 and ua <= math.min(autoRolls, #GACHA_SEED)
		)
		local okStop = type(autoHandle) == "table" and pcall(autoHandle.Stop, autoHandle)
		autoHandle = nil
		local atStop = pa:GetAttribute("Rolls")
		task.wait((GachaConfig.ROLL_INTERVAL or 3) + 1.5)
		local after = pa:GetAttribute("Rolls")
		check(checks, "auto_roll_stop", (after or 0) - (atStop or 0), 0, okStop and after == atStop)
	end)
	if autoHandle then
		pcall(autoHandle.Stop, autoHandle)
	end
	if not okBody then
		check(checks, "gacha_service_no_error", 0, tostring(err), false)
	end
	for _, inst in cleanup do
		inst:Destroy()
	end
	return result("gacha", checks, metrics)
end

-- Index: discoveries -> stat points, allocation, equip, multipliers, and their effect on race gain and pad pay.
function Scenarios.index()
	local checks = {}
	local CarCatalog, GachaConfig, GachaService = gachaModules()
	local RaceService = serverModule("RaceService")
	local RaceConfig = sharedModule("RaceConfig")
	local Money = serverModule("MoneyService")
	local PlayerData = serverModule("PlayerData")
	local apiOk = CarCatalog ~= nil
		and GachaConfig ~= nil
		and GachaService ~= nil
		and RaceService ~= nil
		and RaceConfig ~= nil
		and Money ~= nil
		and PlayerData ~= nil
		and type(GachaConfig.EarnedPoints) == "function"
		and type(GachaConfig.Multis) == "function"
		and type(GachaService.Setup) == "function"
		and type(GachaService.Grant) == "function"
		and type(GachaService.Equip) == "function"
		and type(GachaService.Allocate) == "function"
		and type(GachaService.UniqueCount) == "function"
		and type(GachaService.EarnedPoints) == "function"
		and type(GachaService.FreePoints) == "function"
		and type(GachaService.SpeedMulti) == "function"
		and type(GachaService.MoneyMulti) == "function"
		and type(GachaService.Luck) == "function"
		and type(RaceService.BuildRoute) == "function"
		and type(RaceService.NewRun) == "function"
	check(checks, "index_api_exists", apiOk and 1 or 0, 1, apiOk)
	if not apiOk then
		return result("index", checks, {})
	end
	local metrics = {}
	local function call(fn, ...)
		local ok, r = pcall(fn, ...)
		if ok then
			return r
		end
		return nil
	end

	-- Pure rules
	local earnedOk = true
	for _, pair in { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 1 }, { 5, 1 }, { 6, 2 }, { 7, 2 }, { 9, 3 }, { 30, 10 } } do
		if call(GachaConfig.EarnedPoints, pair[1]) ~= pair[2] then
			earnedOk = false
		end
	end
	check(checks, "earned_points_every_3_unique", earnedOk and 1 or 0, 1, earnedOk)
	local earnedBadOk = call(GachaConfig.EarnedPoints, nil) == 0
	for _, bad in { 0 / 0, -3, "9", true, {}, -math.huge } do
		if call(GachaConfig.EarnedPoints, bad) ~= 0 then
			earnedBadOk = false
		end
	end
	check(checks, "earned_points_bad_input_zero", earnedBadOk and 1 or 0, 1, earnedBadOk)
	local function multisMatch(m, speed, money, luck, workshop)
		return type(m) == "table"
			and nearly(m.Speed, speed)
			and nearly(m.Money, money)
			and nearly(m.Luck, luck)
			and nearly(m.Workshop, workshop)
	end
	local mm = call(GachaConfig.Multis, { Speed = 2, Money = 3, Luck = 4, Workshop = 5 })
	check(
		checks,
		"multis_formula",
		mm and mm.Speed or -1,
		1.2,
		multisMatch(mm, 1 + 0.1 * 2, 1 + 0.1 * 3, 1 + 0.05 * 4, 1 + 0.2 * 5)
	)
	check(checks, "multis_empty_all_one", 1, 1, multisMatch(call(GachaConfig.Multis, {}), 1, 1, 1, 1))
	local mb = call(GachaConfig.Multis, { Speed = "x", Money = 0 / 0, Luck = true, Workshop = nil })
	check(checks, "multis_bad_entries_zero", 1, 1, multisMatch(mb, 1, 1, 1, 1))

	local cleanup = {}
	local models = {}
	local runs = {}
	local connections = {}
	local okBody, err = pcall(function()
		-- Points from discoveries
		local p = newTestPlayer(cleanup, "CarTestIndexP1")
		GachaService.Setup(p)
		local function pts(pl)
			return GachaService.UniqueCount(pl), GachaService.EarnedPoints(pl), GachaService.FreePoints(pl)
		end
		local u, e, f = pts(p)
		check(checks, "fresh_zero_points", e, 0, u == 0 and e == 0 and f == 0 and p:GetAttribute("StatPoints") == 0)
		check(checks, "allocate_fails_at_zero_free", 0, 0, GachaService.Allocate(p, "Speed") == false)
		check(
			checks,
			"allocate_zero_free_no_change",
			p:GetAttribute("Alloc_Speed") or -1,
			0,
			p:GetAttribute("Alloc_Speed") == 0
		)
		GachaService.Grant(p, "rusty_hatchback")
		GachaService.Grant(p, "wooden_car")
		u, e = pts(p)
		check(checks, "two_unique_zero_points", e, 0, u == 2 and e == 0)
		for _ = 1, 5 do
			GachaService.Grant(p, "wooden_car")
			GachaService.Grant(p, "rusty_hatchback")
		end
		u, e = pts(p)
		check(checks, "duplicates_never_count", u, 2, u == 2 and e == 0 and p:GetAttribute("StatPoints") == 0)
		GachaService.Grant(p, "go_kart")
		u, e, f = pts(p)
		check(checks, "three_unique_one_point", e, 1, u == 3 and e == 1 and f == 1)
		check(
			checks,
			"stat_points_attribute_after_grant",
			p:GetAttribute("StatPoints") or -1,
			1,
			p:GetAttribute("StatPoints") == 1
		)

		-- Allocation validation
		local rejectOk = true
		for _, bad in { "Bogus", "speed", "SPEED", "", "Alloc_Speed", 5, true, {} } do
			local oka, r = pcall(GachaService.Allocate, p, bad)
			if not oka or r == true then
				rejectOk = false
			end
		end
		local okn, rn = pcall(GachaService.Allocate, p, nil)
		rejectOk = rejectOk and okn and rn ~= true
		check(checks, "allocate_rejects_bad_names", rejectOk and 1 or 0, 1, rejectOk)
		check(
			checks,
			"allocate_rejected_keeps_point",
			p:GetAttribute("StatPoints") or -1,
			1,
			p:GetAttribute("StatPoints") == 1
		)
		local a1 = GachaService.Allocate(p, "Speed")
		check(checks, "allocate_speed_succeeds", a1 == true and 1 or 0, 1, a1 == true)
		check(
			checks,
			"allocate_increments_alloc",
			p:GetAttribute("Alloc_Speed") or -1,
			1,
			p:GetAttribute("Alloc_Speed") == 1
		)
		check(
			checks,
			"allocate_decrements_stat_points",
			p:GetAttribute("StatPoints") or -1,
			0,
			p:GetAttribute("StatPoints") == 0 and GachaService.FreePoints(p) == 0
		)
		local a2 = GachaService.Allocate(p, "Speed")
		check(
			checks,
			"allocate_beyond_earned_fails",
			a2 == false and 1 or 0,
			1,
			a2 == false and p:GetAttribute("Alloc_Speed") == 1
		)
		check(
			checks,
			"speed_multi_with_1_point",
			GachaService.SpeedMulti(p),
			1.1,
			nearly(GachaService.SpeedMulti(p), 1 * 1.1)
		)
		check(checks, "money_multi_unchanged", GachaService.MoneyMulti(p), 1, nearly(GachaService.MoneyMulti(p), 1))
		check(checks, "luck_unchanged", GachaService.Luck(p), 1, nearly(GachaService.Luck(p), 1))
		for _, c in GACHA_SEED do
			GachaService.Grant(p, c.Id)
		end
		u, e, f = pts(p)
		check(
			checks,
			"seven_unique_two_points",
			e,
			2,
			u == 7 and e == 2 and f == 1 and p:GetAttribute("StatPoints") == 1
		)
		local aL = GachaService.Allocate(p, "Luck")
		check(
			checks,
			"allocate_luck",
			GachaService.Luck(p),
			1.05,
			aL == true and nearly(GachaService.Luck(p), 1 + 0.05)
		)
		check(checks, "allocate_luck_no_more_points", 0, 0, GachaService.Allocate(p, "Money") == false)

		-- Fresh player: every multiplier exactly 1 (also with no GachaService.Setup at all)
		local fresh = newTestPlayer(cleanup, "CarTestIndexFresh")
		GachaService.Setup(fresh)
		local freshOk = GachaService.SpeedMulti(fresh) == 1
			and GachaService.MoneyMulti(fresh) == 1
			and GachaService.Luck(fresh) == 1
		check(checks, "fresh_multis_one", freshOk and 1 or 0, 1, freshOk)
		local bare = newTestPlayer(cleanup, "CarTestIndexBare")
		local bareOk = call(GachaService.SpeedMulti, bare) == 1
			and call(GachaService.MoneyMulti, bare) == 1
			and call(GachaService.Luck, bare) == 1
		check(checks, "no_setup_multis_one", bareOk and 1 or 0, 1, bareOk)

		-- Equip
		local eq = newTestPlayer(cleanup, "CarTestIndexEquip")
		GachaService.Setup(eq)
		local eqBadOk = GachaService.Equip(eq, "go_kart") == false
			and GachaService.Equip(eq, "no_such_car") == false
			and call(GachaService.Equip, eq, 5) ~= true
			and call(GachaService.Equip, eq, nil) ~= true
		check(
			checks,
			"equip_not_owned_rejected",
			eqBadOk and 1 or 0,
			1,
			eqBadOk and eq:GetAttribute("EquippedCar") == "starter"
		)
		GachaService.Grant(eq, "go_kart")
		local eqOk = GachaService.Equip(eq, "go_kart")
		check(
			checks,
			"equip_owned_accepted",
			eqOk == true and 1 or 0,
			1,
			eqOk == true and eq:GetAttribute("EquippedCar") == "go_kart"
		)
		check(
			checks,
			"speed_multi_is_car_multi",
			GachaService.SpeedMulti(eq),
			2,
			nearly(GachaService.SpeedMulti(eq), 2)
		)
		-- car multi x stat multi: p owns go_kart and has 1 Speed point
		GachaService.Equip(p, "go_kart")
		check(
			checks,
			"speed_multi_car_times_stat",
			GachaService.SpeedMulti(p),
			2.2,
			nearly(GachaService.SpeedMulti(p), 2 * 1.1)
		)
		GachaService.Equip(p, "street_racer")
		check(
			checks,
			"speed_multi_after_reequip",
			GachaService.SpeedMulti(p),
			6.6,
			nearly(GachaService.SpeedMulti(p), 6 * 1.1)
		)
		local backOk = GachaService.Equip(p, "starter")
		check(
			checks,
			"equip_starter_always_allowed",
			GachaService.SpeedMulti(p),
			1.1,
			backOk == true and p:GetAttribute("EquippedCar") == "starter" and nearly(GachaService.SpeedMulti(p), 1.1)
		)

		-- Money: the pad pays floor(Cash * MoneyMulti)
		local spec = TrackRegistry.Chain()[1]
		local entries = {}
		for k = 1, 2 do
			local origin = CFrame.new(INDEX_ORIGIN + Vector3.new((k - 1) * 3000, TrackBuilder.TRACK_LIFT or 0, 0))
			local model, layout = TrackBuilder.Build(spec, origin)
			model.Name = "CarTestIndexTrack" .. k
			model.Parent = Workspace
			table.insert(models, model)
			entries[k] = { Layout = layout, Origin = origin, Model = model, Number = spec.Number }
		end
		local pad = models[1]:FindFirstChild("WinPad", true)
		local cash = TrackBuilder.CashFor(spec.Number)
		local pm = newTestPlayer(cleanup, "CarTestIndexMoney")
		Money.Setup(pm)
		GachaService.Setup(pm)
		for _, c in GACHA_SEED do
			GachaService.Grant(pm, c.Id)
		end
		GachaService.Allocate(pm, "Money")
		GachaService.Allocate(pm, "Money")
		local mMulti = GachaService.MoneyMulti(pm)
		check(checks, "money_multi_two_points", mMulti, 1.2, nearly(mMulti, 1 + 0.1 * 2))
		local paid = Money.Collect(pm, pad, 5000)
		local want = math.floor(cash * mMulti)
		check(
			checks,
			"collect_pays_cash_times_money_multi",
			paid or -1,
			want,
			pad ~= nil and paid == want and want > cash
		)
		check(checks, "collect_multi_balance", pm.leaderstats.Money.Value, want, pm.leaderstats.Money.Value == want)
		local pf = newTestPlayer(cleanup, "CarTestIndexMoneyFresh")
		Money.Setup(pf)
		GachaService.Setup(pf)
		local paidF = Money.Collect(pf, pad, 5000)
		check(checks, "collect_fresh_player_pays_cash", paidF or -1, cash, paidF == cash)

		-- Race gain scales with the equipped car: two identical drives, 1x vs a 2x go_kart.
		-- Measurement fix (not a loosening, every limit unchanged): building the tracks causes long frames, so wait
		-- for the world to settle before the runs start, and integrate on PreSimulation with the same dt the run uses.
		local settleStart, streak = os.clock(), 0
		while os.clock() - settleStart < INDEX_SETTLE_CAP do
			local sdt = RunService.Heartbeat:Wait()
			streak = sdt < INDEX_SETTLE_MAX_DT and streak + 1 or 0
			if os.clock() - settleStart >= INDEX_SETTLE_MIN and streak >= INDEX_SETTLE_FRAMES then
				break
			end
		end
		metrics.settleSeconds = round(os.clock() - settleStart)
		local results = {}
		for k = 1, 2 do
			local route = RaceService.BuildRoute({ entries[k] })
			local car = CarFactory.build(CarConfig)
			car.Name = "CarTestIndexCar" .. k
			car:PivotTo(models[k].Start.CFrame + Vector3.new(0, CarConfig.RestHeight, 0))
			car.Parent = Workspace
			table.insert(models, car)
			local player = newTestPlayer(cleanup, "CarTestIndexRacer" .. k)
			Money.Setup(player)
			PlayerData.Setup(player)
			GachaService.Setup(player)
			if k == 2 then
				GachaService.Grant(player, "go_kart")
				GachaService.Equip(player, "go_kart")
			end
			local run = RaceService.NewRun(car, route, player, nil)
			table.insert(runs, run)
			results[k] = {
				player = player,
				chassis = car.PrimaryPart,
				speedValue = player.leaderstats.Speed,
				integral = 0,
				target = run.TargetSpeed,
			}
		end
		local raceMaxDt = 0
		local integrate = RunService.PreSimulation:Connect(function(dt)
			raceMaxDt = math.max(raceMaxDt, dt)
			for _, r in results do
				local g = RaceConfig.GainPerSecond(r.speedValue.Value, r.chassis.AssemblyLinearVelocity.Magnitude)
				if type(g) == "number" and g == g then
					r.integral += g * dt
				end
			end
		end)
		table.insert(connections, integrate)
		frames(INDEX_RACE_SECONDS)
		integrate:Disconnect()
		for _, run in runs do
			run:Destroy()
		end
		metrics.raceMaxDt = round(raceMaxDt)
		runs = {}
		local ratios = {}
		for k, r in results do
			ratios[k] = r.integral > 0 and r.speedValue.Value / r.integral or 0
		end
		metrics.gain1 = round(results[1].speedValue.Value)
		metrics.gain2 = round(results[2].speedValue.Value)
		metrics.ratio1 = round(ratios[1])
		metrics.ratio2 = round(ratios[2])
		check(checks, "race_gain_baseline_unchanged", ratios[1], "1 +- 15%", ratios[1] >= 0.85 and ratios[1] <= 1.15)
		local scale = ratios[1] > 0 and ratios[2] / ratios[1] or 0
		check(checks, "race_gain_scales_with_car_multi", scale, "2 +- 15%", scale >= 1.7 and scale <= 2.3)
		check(
			checks,
			"race_cruise_unaffected_by_car",
			results[2].target or -1,
			results[1].target or -1,
			type(results[1].target) == "number" and results[1].target == results[2].target
		)
	end)
	for _, conn in connections do
		conn:Disconnect()
	end
	for _, run in runs do
		pcall(run.Destroy, run)
	end
	if not okBody then
		check(checks, "index_no_error", 0, tostring(err), false)
	end
	for _, m in models do
		m:Destroy()
	end
	for _, inst in cleanup do
		inst:Destroy()
	end
	return result("index", checks, metrics)
end

-- Car size: the car is about half of its original 13.2 stud length.
local ORIGINAL_CAR_LENGTH = 13.2
function Scenarios.car_size()
	local checks = {}
	local model = CarFactory.build(CarConfig)
	local chassis = model.PrimaryPart
	local cs = chassis and chassis.Size or Vector3.zero
	check(checks, "chassis_length_max", cs.Z, 7.0, chassis ~= nil and cs.Z <= 7.0)
	check(checks, "chassis_width_max", cs.X, 3.5, chassis ~= nil and cs.X <= 3.5)
	local _, size = model:GetBoundingBox()
	check(checks, "model_length_band", size.Z, 4, size.Z >= 4 and size.Z <= 8)
	check(checks, "model_width_max", size.X, 5, size.X <= 5)
	check(checks, "model_height_max", size.Y, 3.5, size.Y <= 3.5)
	local wr = CarConfig.WheelRadius
	check(checks, "wheel_radius_band", wr, 0.5, type(wr) == "number" and wr >= 0.5 and wr <= 0.9)
	local rh = CarConfig.RestHeight
	check(checks, "rest_height_band", rh, 2, type(rh) == "number" and rh > 0 and rh < 2)
	local ratio = size.Z / ORIGINAL_CAR_LENGTH
	check(checks, "length_ratio_max", ratio, 0.6, ratio <= 0.6)
	model:Destroy()
	return result("car_size", checks, { lengthRatio = round(ratio), length = round(size.Z) })
end

-- NPC racer + multiplayer pass-through (contract: docs/NPC_RACER_SPEC.md).
-- BRIEF (user, 2026-10-01): "One NPC racer per track. For now it is the starter car in a different colour per
-- track: red on Track 1, a different colour on every other track. The model must be swappable per track later.
-- The NPC drives in the LEFT lane; the player keeps the right-hand lane. The NPC race starts automatically every
-- time the player starts a track. The NPC is per player: other players never see it (never in the server
-- Workspace). NPC speeds rise per track: very easy on Track 1, increasing on every later track. If the NPC reaches
-- the finish of the track before the player, the player LOSES. The race still plays out, then the player sees a
-- loser screen and is sent back to the start of Track 1 where the Track 1 race starts again. A track's checkpoint
-- money is paid only when the player WINS that track; money from checkpoints already won is kept. Floating text
-- above each NPC, proximity based, editable, default track01_NPC, track02_NPC, ... Players pass through each other."
local NPC_ORIGIN = Vector3.new(40000, 0, 0)
local MULTI_ORIGIN = Vector3.new(-40000, 0, 0)
local NPC_LOSE_SCREEN = 1 -- s: LoseScreenSeconds used by the test runs
local NPC_SLOW = 15 -- studs/s: an NPC every player beats
local NPC_FAST = 60 -- studs/s: an NPC a stat-0 player (RaceConfig.BASE_SPEED) can not beat
local NPC_RESET_RADIUS = 15 -- studs (horizontal) from Track 1's race start after a reset
local NPC_FINISH_RADIUS = 25 -- studs (horizontal) from the track's finish pose when its Result arrives
local NPC_TIME_SLACK = 1 -- s between the run's own times and the test's clock
local NPC_POSE_TOLERANCE = 2 -- studs (horizontal) PoseAt may be from the lane waypoint
local NPC_SCAN_INTERVAL = 1 -- s between scans of the server Workspace for NPC models

local function colorClose(a, b)
	return typeof(a) == "Color3"
		and typeof(b) == "Color3"
		and math.abs(a.R - b.R) <= 1.5 / 255
		and math.abs(a.G - b.G) <= 1.5 / 255
		and math.abs(a.B - b.B) <= 1.5 / 255
end

local function isFiniteNumber(x)
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

local function num(x)
	return isFiniteNumber(x) and x or -1
end

local function npcModelInWorkspace()
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("IsNpc") ~= nil then
			return true
		end
	end
	return false
end

-- Builds the first two chain tracks at `base` the way Main chains them. Returns entries and the models.
local function buildNpcChain(base, prefix, specs)
	local models, entries = {}, {}
	local origin = CFrame.new(base + Vector3.new(0, TrackBuilder.TRACK_LIFT or 0, 0))
	for i = 1, 2 do
		local model, layout = TrackBuilder.Build(specs[i], origin)
		model.Name = prefix .. i
		model.Parent = Workspace
		table.insert(models, model)
		entries[i] = { Layout = layout, Origin = origin, Model = model, Number = specs[i].Number }
		origin = TrackBuilder.EndCFrame(layout, origin)
	end
	return entries, models
end

-- Recorded events of racer r of a type (and track), optionally only those that arrived after time `after`.
local function npcFind(r, typ, track, after)
	for _, rec in r.Events do
		local ev = rec.Event
		if ev.Type == typ and (track == nil or ev.Track == track) and (after == nil or rec.T >= after) then
			return rec
		end
	end
	return nil
end

local function npcAll(r, typ)
	local out = {}
	for _, rec in r.Events do
		if rec.Event.Type == typ then
			table.insert(out, rec)
		end
	end
	return out
end

-- One player's NPC-mode run: a real car, a fake player (Folder) at stat `stat`, every race event recorded with the
-- test's clock, the car's position, up-vector and balance at arrival.
local function newNpcRacer(api, route, startCF, tag, stat, speeds, carGroup)
	local car = CarFactory.build(CarConfig)
	car.Name = "CarTestNpcCar_" .. tag
	car:PivotTo(startCF)
	if carGroup then
		for _, part in car:GetDescendants() do
			if part:IsA("BasePart") then
				part.CollisionGroup = carGroup -- what RaceService.Attach does for a real player's car
			end
		end
	end
	car.Parent = Workspace
	local player = Instance.new("Folder")
	player.Name = "CarTestNpcPlayer_" .. tag
	player.Parent = Workspace
	local r = {
		Tag = tag,
		Car = car,
		Player = player,
		Chassis = car.PrimaryPart,
		Events = {},
		ok = false,
		stopped = false,
		minUpOwn = 1,
		flips = 0,
		flippedFor = 0,
		wasFlipped = false,
		dev = 0,
		devActive = true,
		idx = 1,
		clock0 = os.clock(),
	}
	local okSetup = pcall(function()
		api.Money.Setup(player)
		api.PlayerData.Setup(player)
		player.leaderstats.Speed.Value = stat
	end)
	if not okSetup then
		r.err = "PlayerData.Setup failed"
		return r
	end
	r.Money = player.leaderstats:FindFirstChild("Money")
	local options = {
		Loop = true,
		Npc = true,
		NpcSpeeds = speeds,
		LoseScreenSeconds = NPC_LOSE_SCREEN,
		OnRaceEvent = function(ev)
			if type(ev) ~= "table" then
				return
			end
			local chassis = car.PrimaryPart
			table.insert(r.Events, {
				Event = ev,
				T = os.clock() - r.clock0,
				Pos = chassis and chassis.Position or Vector3.zero,
				UpY = chassis and chassis.CFrame.UpVector.Y or -1,
				Money = r.Money and r.Money.Value or -1,
				RunUnbanked = r.Run and r.Run.Unbanked or nil, -- the run's bank as the event is emitted
			})
		end,
	}
	local okRun, run = pcall(api.RaceService.NewRun, car, route, player, options)
	if not okRun or type(run) ~= "table" then
		r.err = tostring(run)
		return r
	end
	r.Run = run
	r.ok = true
	return r
end

-- Per-frame measurements for racer r: tilt, flips, route deviation (after the 3 s grace, until the first Result),
-- and the car's pose 0.2 s after the first Reset.
local function stepNpcRacer(r, dt, wps)
	if not r.ok then
		return
	end
	local chassis = r.Chassis
	local run = r.Run
	local now = os.clock() - r.clock0
	local up = chassis.CFrame.UpVector.Y
	if not (run.Physics and run.Physics.LoopAssist) then
		r.minUpOwn = math.min(r.minUpOwn, up)
	end
	if up < PhysicsTargets.lap.MinUpY then
		r.flippedFor += dt
		if not r.wasFlipped and r.flippedFor > 1 then
			r.flips += 1
			r.wasFlipped = true
		end
	else
		r.flippedFor, r.wasFlipped = 0, false
	end
	if r.devActive and npcFind(r, "Result") then
		r.devActive = false
	end
	if r.devActive then
		local pos = chassis.Position
		local n = #wps
		local bestD = math.huge
		for i = r.idx, math.min(r.idx + 25, n) do
			local d = (wps[i] - pos).Magnitude
			if d < bestD then
				bestD, r.idx = d, i
			end
		end
		if now > 3 then
			local dist = nearestOnPolyline(wps, pos, math.max(r.idx - 3, 1), math.min(r.idx + 3, n - 1))
			r.dev = math.max(r.dev, dist)
		end
	end
	local reset = npcFind(r, "Reset")
	if reset and not r.resetPose and now - reset.T >= 0.2 then
		r.resetPose = chassis.CFrame
	end
end

local function endNpcRacer(r)
	local run = r.Run
	if run then
		r.snap = {
			MinUpY = run.MinUpY,
			PaidTotal = run.PaidTotal,
			Payouts = run.Payouts,
			Wins = run.Wins,
			Losses = run.Losses,
			Resets = run.Resets,
			RaceTrack = run.RaceTrack,
			Results = type(run.Results) == "table" and #run.Results or -1,
			FlipRecoveries = run.FlipRecoveries,
			-- banked winnings (SPAWN_AND_ROLLS_SPEC section 3), read before Destroy cashes the bank out
			Unbanked = run.Unbanked,
			BankedTotal = run.BankedTotal,
			UnbankedAttr = r.Player:GetAttribute("Unbanked"),
			BalanceBeforeDestroy = r.Money and r.Money.Value or -1,
		}
		pcall(function()
			run:Destroy()
		end)
		r.snap.PaidTotalAfter = run.PaidTotal
		r.snap.PayoutsAfter = run.Payouts
		r.snap.UnbankedAttrAfter = r.Player:GetAttribute("Unbanked")
	else
		r.snap = {}
	end
	r.balance = r.Money and r.Money.Value or -1
	r.Car:Destroy()
	r.Player:Destroy()
end

-- Tilt / flip checks for one NPC-mode run.
local function checkNpcStability(checks, pre, r)
	local strict = PhysicsTargets.lap.MinUpYStrict
	local rm = isFiniteNumber(r.snap.MinUpY) and r.snap.MinUpY or -1
	local worst = math.min(rm, r.minUpOwn)
	check(checks, pre .. "_never_tilted", worst, strict, type(strict) == "number" and worst >= strict)
	local rec = type(r.snap.FlipRecoveries) == "number" and r.snap.FlipRecoveries or -1
	check(checks, pre .. "_no_flips", r.flips, 0, r.flips == 0 and rec == 0)
end

-- Lost track `lost` (by racer r): nothing paid for it, a Reset to Track 1 after the lose screen, the car back at
-- Track 1's start upright and facing along the path, and a new Track 1 Start.
local function checkNpcLoseReset(checks, pre, r, lost, wps)
	local res = npcFind(r, "Result", lost)
	local reset = res and npcFind(r, "Reset", nil, res.T)
	check(checks, pre .. "_reset_event", reset and 1 or 0, 1, reset ~= nil and reset.Event.Track == 1)
	local delay = (reset and res) and reset.T - res.T or -1
	check(
		checks,
		pre .. "_reset_after_lose_screen",
		delay,
		NPC_LOSE_SCREEN,
		reset ~= nil and delay >= NPC_LOSE_SCREEN - 0.1 and delay <= NPC_LOSE_SCREEN + 1.5
	)
	local pose = r.resetPose
	local d = pose and hdist(pose.Position, wps[1]) or -1
	check(checks, pre .. "_reset_to_track1_start", d, NPC_RESET_RADIUS, pose ~= nil and d <= NPC_RESET_RADIUS)
	local up = pose and pose.UpVector.Y or -1
	check(checks, pre .. "_reset_upright", up, 0.9, up >= 0.9)
	local dir = flatV(wps[2] - wps[1])
	local facing = (pose and dir.Magnitude > 1e-6) and flatV(pose.LookVector):Dot(dir.Unit) or -1
	check(checks, pre .. "_reset_faces_path", facing, 0.9, facing >= 0.9)
	local restart = reset and npcFind(r, "Start", 1, reset.T - 0.05)
	check(checks, pre .. "_restarts_track1", restart and 1 or 0, 1, restart ~= nil)
	local rt = r.snap.RaceTrack
	check(checks, pre .. "_race_track_back_to_1", type(rt) == "number" and rt or -1, 1, rt == 1)
	local resets = r.snap.Resets
	check(checks, pre .. "_resets_counted", type(resets) == "number" and resets or -1, 1, resets == 1)
end

function Scenarios.npc()
	local checks = {}
	local metrics = {}
	local NpcConfig = sharedModule("NpcConfig")
	local NpcRacer = sharedModule("NpcRacer")
	local RaceConfig = sharedModule("RaceConfig")
	local PathDriver = sharedModule("PathDriver")
	local api = {
		RaceService = serverModule("RaceService"),
		Money = serverModule("MoneyService"),
		PlayerData = serverModule("PlayerData"),
	}
	local apiOk = NpcConfig ~= nil
		and NpcRacer ~= nil
		and RaceConfig ~= nil
		and PathDriver ~= nil
		and api.RaceService ~= nil
		and api.Money ~= nil
		and api.PlayerData ~= nil
		and type(NpcConfig.For) == "function"
		and type(NpcConfig.Tracks) == "table"
		and type(NpcRacer.LanePath) == "function"
		and type(NpcRacer.Profile) == "function"
		and type(NpcRacer.PoseAt) == "function"
		and type(NpcRacer.ChainEntries) == "function"
		and type(NpcRacer.BuildModel) == "function"
		and type(api.RaceService.BuildRoute) == "function"
		and type(api.RaceService.NewRun) == "function"
		and type(api.PlayerData.Setup) == "function"
		and type(PathDriver.Chain) == "function"
		and type(TrackBuilder.RacePath) == "function"
		and type(TrackBuilder.CashFor) == "function"
		and type(RaceConfig.BASE_SPEED) == "number"
	check(checks, "npc_api_exists", apiOk and 1 or 0, 1, apiOk)
	local specs = type(TrackRegistry.Chain) == "function" and TrackRegistry.Chain() or {}
	check(checks, "npc_chain_has_two_tracks", #specs, 2, #specs >= 2)
	if not apiOk or #specs < 2 then
		return result("npc", checks, metrics)
	end

	local models = {}
	local okBody, err = pcall(function()
		-- NpcConfig: red on Track 1, a different colour per track, speeds rising, labels, per-track overrides
		local infos, allInfo = {}, true
		for n = 1, 5 do
			local ok, info = pcall(NpcConfig.For, n)
			infos[n] = ok and type(info) == "table" and info or nil
			allInfo = allInfo and infos[n] ~= nil
		end
		check(checks, "npc_config_for_returns_info", allInfo and 1 or 0, 1, allInfo)
		if allInfo then
			local c1 = infos[1].Color
			local isColor = typeof(c1) == "Color3"
			local red = isColor and c1.R * 255 >= 200 and c1.G * 255 <= 80 and c1.B * 255 <= 80
			check(checks, "npc_track1_red", isColor and c1.R * 255 or -1, 200, red)
			local same, notColor = 0, 0
			for i = 1, 5 do
				if typeof(infos[i].Color) ~= "Color3" then
					notColor += 1
				end
				for j = i + 1, 5 do
					if colorClose(infos[i].Color, infos[j].Color) then
						same += 1
					end
				end
			end
			check(checks, "npc_colours_distinct_1_to_5", same + notColor, 0, same == 0 and notColor == 0)
			local asPlayer = 0
			for i = 1, 5 do
				if colorClose(infos[i].Color, CarConfig.Colors.Body) then
					asPlayer += 1
				end
			end
			check(checks, "npc_colours_not_player_body", asPlayer, 0, asPlayer == 0)
			local increasing = true
			for i = 1, 5 do
				local s = infos[i].Speed
				if not isFiniteNumber(s) or s <= 0 or (i > 1 and not (s > infos[i - 1].Speed)) then
					increasing = false
				end
			end
			check(checks, "npc_speed_increasing_1_to_5", increasing and 1 or 0, 1, increasing)
			local s1 = isFiniteNumber(infos[1].Speed) and infos[1].Speed or math.huge
			check(checks, "npc_track1_very_easy", s1, RaceConfig.BASE_SPEED, s1 < RaceConfig.BASE_SPEED)
			check(
				checks,
				"npc_label_track1",
				infos[1].Label == "track01_NPC" and 1 or 0,
				1,
				infos[1].Label == "track01_NPC"
			)
			check(
				checks,
				"npc_label_track2",
				infos[2].Label == "track02_NPC" and 1 or 0,
				1,
				infos[2].Label == "track02_NPC"
			)
			local numbersOk = true
			for i = 1, 5 do
				numbersOk = numbersOk and infos[i].Number == i
			end
			check(checks, "npc_info_number", numbersOk and 1 or 0, 1, numbersOk)
		end
		local ld = NpcConfig.LABEL_DISTANCE
		check(checks, "npc_label_distance_finite", isFiniteNumber(ld) and ld or -1, 0, isFiniteNumber(ld) and ld > 0)

		-- model / label / speed / colour are changeable per track (NpcConfig.Tracks is read live by For)
		local saved = NpcConfig.Tracks[7]
		local okBefore, before = pcall(NpcConfig.For, 7)
		local overrideColor = Color3.fromRGB(10, 200, 30)
		NpcConfig.Tracks[7] = { Label = "X", Speed = 99, Model = "Y", Color = overrideColor }
		local okAfter, after = pcall(NpcConfig.For, 7)
		NpcConfig.Tracks[7] = saved
		local okRestored, restored = pcall(NpcConfig.For, 7)
		local overrideOk = okAfter
			and type(after) == "table"
			and after.Label == "X"
			and after.Speed == 99
			and after.Model == "Y"
			and colorClose(after.Color, overrideColor)
		check(checks, "npc_override_per_track", overrideOk and 1 or 0, 1, overrideOk)
		local defaultOk = okBefore
			and okRestored
			and type(before) == "table"
			and type(restored) == "table"
			and (saved ~= nil or before.Label == "track07_NPC")
			and restored.Label == before.Label
			and restored.Speed == before.Speed
		check(checks, "npc_override_restores_default", defaultOk and 1 or 0, 1, defaultOk)

		-- The test chain (Track 1 and 2) far from every other test origin
		local entries
		entries, models = buildNpcChain(NPC_ORIGIN, "CarTestNpcTrack", specs)
		local layout = entries[1].Layout
		local cw, ccurv = layout.Waypoints, layout.Curvature

		-- TrackBuilder.RacePath(layout, -LANE_OFFSET) is the LEFT lane; the default stays the right lane
		local LANE = TrackBuilder.LANE_OFFSET
		local function laneMean(path)
			if type(path) ~= "table" or type(path.Waypoints) ~= "table" or #path.Waypoints ~= #cw then
				return nil, 0
			end
			local sum, cnt = 0, 0
			for i = 2, #cw - 1 do
				if ccurv[i - 1] == 0 and ccurv[i] == 0 and ccurv[i + 1] == 0 then
					local f = flatV(cw[i + 1] - cw[i - 1])
					if f.Magnitude > 1e-6 then
						sum += flatV(path.Waypoints[i] - cw[i]):Dot(f.Unit:Cross(Vector3.yAxis))
						cnt += 1
					end
				end
			end
			return cnt >= 10 and sum / cnt or nil, cnt
		end
		local okL, left = pcall(TrackBuilder.RacePath, layout, -LANE)
		local okR, right = pcall(TrackBuilder.RacePath, layout)
		local okR2, right2 = pcall(TrackBuilder.RacePath, layout, LANE)
		local lm = okL and laneMean(left) or nil
		local rm = okR and laneMean(right) or nil
		check(checks, "npc_race_path_left_lane", lm and -lm or -99, LANE, lm ~= nil and -lm >= 7 and -lm <= 13)
		check(checks, "player_race_path_still_right", rm or -99, LANE, rm ~= nil and rm >= 7 and rm <= 13)
		local sameDefault = okR and okR2 and type(right2) == "table" and type(right2.Waypoints) == "table"
		local maxDiff = -1
		if sameDefault then
			maxDiff = 0
			for i, p in right.Waypoints do
				maxDiff = math.max(maxDiff, (p - (right2.Waypoints[i] or Vector3.new(1e9, 0, 0))).Magnitude)
			end
		end
		check(checks, "race_path_default_offset_is_lane_offset", maxDiff, 0.001, sameDefault and maxDiff <= 0.001)

		-- NpcRacer.LanePath: world-space left lane of a chain entry
		local entry1 = { Layout = layout, Origin = entries[1].Origin, Number = entries[1].Number }
		local okLane, lane = pcall(NpcRacer.LanePath, entry1)
		local laneOk = okLane
			and type(lane) == "table"
			and type(lane.Waypoints) == "table"
			and type(lane.Curvature) == "table"
			and isFiniteNumber(lane.Length)
			and #lane.Waypoints == #cw
		check(checks, "npc_lane_path_built", laneOk and 1 or 0, 1, laneOk)
		if laneOk then
			local worst = -1
			if okL and type(left) == "table" and type(left.Waypoints) == "table" then
				worst = 0
				for i, p in lane.Waypoints do
					local want = entries[1].Origin:PointToWorldSpace(left.Waypoints[i])
					worst = math.max(worst, (p - want).Magnitude)
				end
			end
			check(checks, "npc_lane_path_is_world_left_lane", worst, 0.05, worst >= 0 and worst <= 0.05)
			local wl = lane.Waypoints
			local cum = { 0 }
			for i = 2, #wl do
				cum[i] = cum[i - 1] + (wl[i] - wl[i - 1]).Magnitude
			end
			local len = cum[#wl]
			check(checks, "npc_lane_length", lane.Length, len, math.abs(lane.Length - len) <= 0.01 * len)

			-- NpcRacer.Profile: holds the speed, slows only for grip, faster NPC = shorter time
			local trySpeeds = { NPC_SLOW, 20, 30, 45, NPC_FAST }
			local totals, profiles, profOk = {}, {}, true
			for k, s in trySpeeds do
				local okP, prof = pcall(NpcRacer.Profile, lane, s)
				if okP and type(prof) == "table" and isFiniteNumber(prof.TotalTime) and type(prof.Times) == "table" then
					totals[k], profiles[s] = prof.TotalTime, prof
				else
					profOk = false
				end
			end
			check(checks, "npc_profile_built", profOk and 1 or 0, 1, profOk)
			if profOk then
				local decreasing, neverFaster = true, true
				for k, s in trySpeeds do
					if k > 1 and not (totals[k] < totals[k - 1]) then
						decreasing = false
					end
					if totals[k] < len / s * 0.999 then
						neverFaster = false
					end
				end
				check(checks, "npc_profile_time_decreasing_in_speed", decreasing and 1 or 0, 1, decreasing)
				check(checks, "npc_profile_never_faster_than_speed", neverFaster and 1 or 0, 1, neverFaster)
				metrics.npcTimeSlow = round(totals[1])
				metrics.npcTimeFast = round(totals[#totals])

				-- on the first (flat) straight, 40..200 studs in, time per stud = 1 / speed
				local i0, i1 = nil, nil
				for i = 1, #wl do
					if not i0 and cum[i] >= 40 then
						i0 = i
					end
					if cum[i] <= 200 then
						i1 = i
					end
				end
				local flatStraight = i0 ~= nil and i1 ~= nil and i1 > i0
				if flatStraight then
					for i = i0, i1 do
						if lane.Curvature[i] ~= 0 or math.abs(wl[i].Y - wl[i0].Y) > 0.01 then
							flatStraight = false
						end
					end
				end
				for _, s in { 30, NPC_FAST } do
					local prof = profiles[s]
					local rate = -1
					if flatStraight and #prof.Times == #wl then
						rate = (prof.Times[i1] - prof.Times[i0]) / (cum[i1] - cum[i0])
					end
					check(
						checks,
						"npc_profile_flat_rate_" .. s,
						rate * s,
						1,
						rate > 0 and math.abs(rate * s - 1) <= 0.05
					)
				end

				-- NpcRacer.PoseAt: lane start at 0, lane end at TotalTime, RestHeight above the road, along the path
				local prof = profiles[30]
				local function pose(t)
					local okPose, cf = pcall(NpcRacer.PoseAt, lane, prof, t)
					return okPose and typeof(cf) == "CFrame" and cf or nil
				end
				local p0, pEnd = pose(0), pose(prof.TotalTime)
				local first, last = wl[1], wl[#wl]
				local d0 = p0 and hdist(p0.Position, first) or -1
				local dEnd = pEnd and hdist(pEnd.Position, last) or -1
				check(checks, "npc_pose_at_lane_start", d0, NPC_POSE_TOLERANCE, p0 ~= nil and d0 <= NPC_POSE_TOLERANCE)
				check(
					checks,
					"npc_pose_at_lane_end",
					dEnd,
					NPC_POSE_TOLERANCE,
					pEnd ~= nil and dEnd <= NPC_POSE_TOLERANCE
				)
				local h0 = p0 and p0.Position.Y - first.Y or -99
				local hEnd = pEnd and pEnd.Position.Y - last.Y or -99
				local herr = math.max(math.abs(h0 - CarConfig.RestHeight), math.abs(hEnd - CarConfig.RestHeight))
				check(checks, "npc_pose_rest_height", herr, 1, herr <= 1)
				local pBefore, pAfter = pose(-5), pose(prof.TotalTime + 100)
				local clamped = pBefore ~= nil
					and pAfter ~= nil
					and p0 ~= nil
					and pEnd ~= nil
					and (pBefore.Position - p0.Position).Magnitude <= 0.1
					and (pAfter.Position - pEnd.Position).Magnitude <= 0.1
				check(checks, "npc_pose_clamped", clamped and 1 or 0, 1, clamped)
				if flatStraight then
					local mid = math.floor((i0 + i1) / 2)
					local pm = #prof.Times == #wl and pose(prof.Times[mid]) or nil
					local dm = pm and hdist(pm.Position, wl[mid]) or -1
					check(
						checks,
						"npc_pose_on_lane_mid",
						dm,
						NPC_POSE_TOLERANCE,
						pm ~= nil and dm <= NPC_POSE_TOLERANCE
					)
					local dir = flatV(wl[mid + 1] - wl[mid - 1]).Unit
					local facing = pm and flatV(pm.LookVector):Dot(dir) or -1
					check(checks, "npc_pose_faces_path", facing, 0.99, facing >= 0.99)
				else
					check(checks, "npc_pose_on_lane_mid", -1, NPC_POSE_TOLERANCE, false)
				end
			end
		end

		-- NpcRacer.ChainEntries: the same origins Main builds (TRACK_LIFT, then EndCFrame of each track)
		local live = TrackRegistry.Chain()
		local okCE, ce = pcall(NpcRacer.ChainEntries)
		local ceOk = okCE and type(ce) == "table" and #ce == #live
		check(checks, "npc_chain_entries_count", okCE and type(ce) == "table" and #ce or -1, #live, ceOk)
		if ceOk then
			local origin = CFrame.new(0, TrackBuilder.TRACK_LIFT, 0)
			local worstPos, worstRot, numbersOk = 0, 0, true
			for i, spec in live do
				local e = ce[i]
				if type(e) ~= "table" or typeof(e.Origin) ~= "CFrame" or type(e.Layout) ~= "table" then
					worstPos = math.huge
				else
					worstPos = math.max(worstPos, (e.Origin.Position - origin.Position).Magnitude)
					worstRot = math.max(worstRot, (e.Origin.LookVector - origin.LookVector).Magnitude)
					numbersOk = numbersOk and e.Number == spec.Number
				end
				origin = TrackBuilder.EndCFrame(TrackBuilder.Layout(spec), origin)
			end
			check(
				checks,
				"npc_chain_entries_origins",
				worstPos == math.huge and -1 or worstPos,
				0.01,
				worstPos <= 0.01 and worstRot <= 0.001
			)
			check(checks, "npc_chain_entries_numbers", numbersOk and 1 or 0, 1, numbersOk)
			local y1 = type(ce[1]) == "table" and typeof(ce[1].Origin) == "CFrame" and ce[1].Origin.Position.Y or -99
			check(
				checks,
				"npc_chain_first_origin_lift",
				y1,
				TrackBuilder.TRACK_LIFT,
				math.abs(y1 - TrackBuilder.TRACK_LIFT) <= 0.01
			)
		end

		-- NpcRacer.BuildModel: ghost starter car in the track's colour with a proximity label, never parented
		if allInfo then
			local okM1, m1 = pcall(NpcRacer.BuildModel, infos[1])
			local okM2, m2 = pcall(NpcRacer.BuildModel, infos[2])
			local builtOk = okM1 and okM2 and typeof(m1) == "Instance" and m1:IsA("Model") and typeof(m2) == "Instance"
			check(checks, "npc_model_built", builtOk and 1 or 0, 1, builtOk)
			if builtOk then
				check(
					checks,
					"npc_model_is_npc",
					m1:GetAttribute("IsNpc") == true and 1 or 0,
					1,
					m1:GetAttribute("IsNpc") == true
				)
				local tn = m1:GetAttribute("TrackNumber")
				check(checks, "npc_model_track_number", type(tn) == "number" and tn or -1, 1, tn == 1)
				check(
					checks,
					"npc_model_name",
					m1.Name == "NPC_track01_NPC" and 1 or 0,
					1,
					m1.Name == "NPC_track01_NPC"
				)
				check(checks, "npc_model_not_parented", m1.Parent == nil and 1 or 0, 1, m1.Parent == nil)
				local function body(m)
					return m.PrimaryPart or m:FindFirstChild("Chassis", true)
				end
				local b1, b2 = body(m1), body(m2)
				local c1ok = b1 ~= nil and b1:IsA("BasePart") and colorClose(b1.Color, infos[1].Color)
				check(checks, "npc_model_colour", c1ok and 1 or 0, 1, c1ok)
				local c2ok = b2 ~= nil
					and b2:IsA("BasePart")
					and colorClose(b2.Color, infos[2].Color)
					and not colorClose(b2.Color, b1 and b1.Color or Color3.new())
				check(checks, "npc_model_colour_per_track", c2ok and 1 or 0, 1, c2ok)
				local parts, bad = 0, 0
				for _, p in m1:GetDescendants() do
					if p:IsA("BasePart") then
						parts += 1
						if not p.Anchored or p.CanCollide or p.CanTouch or p.CanQuery then
							bad += 1
						end
					end
				end
				check(checks, "npc_model_parts_ghost", bad, 0, parts > 0 and bad == 0)
				local bb = m1:FindFirstChild("NpcLabel", true)
				local bbOk = bb ~= nil and bb:IsA("BillboardGui")
				local md = bbOk and bb.MaxDistance or -1
				check(
					checks,
					"npc_label_max_distance",
					md,
					isFiniteNumber(ld) and ld or -1,
					bbOk and isFiniteNumber(ld) and md == ld
				)
				local tl = bbOk and bb:FindFirstChildWhichIsA("TextLabel", true)
				local textOk = tl ~= nil and tl ~= false and tl.Text == "track01_NPC"
				check(checks, "npc_label_text", textOk and 1 or 0, 1, textOk)
			end
			if okM1 and typeof(m1) == "Instance" then
				m1:Destroy()
			end
			if okM2 and typeof(m2) == "Instance" then
				m2:Destroy()
			end
		end

		-- RaceService route with per-track NPC data, PathDriver.Chain start / finish indices
		local okRoute, route = pcall(api.RaceService.BuildRoute, entries)
		local routeOk = okRoute
			and type(route) == "table"
			and type(route.Path) == "table"
			and type(route.Path.WorldWaypoints) == "table"
			and type(route.Tracks) == "table"
			and #route.Tracks == 2
		check(checks, "npc_route_built", routeOk and 1 or 0, 1, routeOk)
		if not routeOk then
			return
		end
		local wps = route.Path.WorldWaypoints
		local tracksOk = true
		for i = 1, 2 do
			local t = route.Tracks[i]
			tracksOk = tracksOk
				and type(t) == "table"
				and t.Number == specs[i].Number
				and type(t.StartIndex) == "number"
				and type(t.FinishIndex) == "number"
				and type(t.PadIndex) == "number"
				and t.StartIndex < t.PadIndex
				and t.PadIndex <= t.FinishIndex
				and type(t.Npc) == "table"
				and type(t.Npc.Config) == "table"
				and type(t.Npc.Path) == "table"
				and type(t.Npc.Profile) == "table"
				and isFiniteNumber(t.Npc.Profile.TotalTime)
		end
		check(checks, "npc_route_tracks", tracksOk and 1 or 0, 1, tracksOk)
		if not tracksOk then
			return
		end
		local joint = TrackBuilder.EndCFrame(entries[1].Layout, entries[1].Origin).Position
		local f1 = route.Tracks[1].FinishIndex
		local dj = hdist(wps[f1], joint)
		check(checks, "npc_route_finish_index_at_joint", dj, LANE + 2, dj <= LANE + 2)
		check(
			checks,
			"npc_route_last_finish_is_end",
			route.Tracks[2].FinishIndex,
			#wps,
			route.Tracks[2].FinishIndex == #wps
		)
		local okChain, chain = pcall(PathDriver.Chain, entries)
		local chainOk = okChain
			and type(chain) == "table"
			and type(chain.StartIndices) == "table"
			and type(chain.FinishIndices) == "table"
			and chain.StartIndices[1] == 1
			and chain.FinishIndices[1] == f1
			and chain.FinishIndices[2] == #wps
			and type(chain.StartIndices[2]) == "number"
			and chain.StartIndices[2] >= f1
			and chain.StartIndices[2] <= f1 + 1
		check(checks, "pathdriver_chain_track_indices", chainOk and 1 or 0, 1, chainOk)

		-- Our own NPC times for the race checks (the run's NpcTime must equal the profile's TotalTime)
		local lane2 = select(2, pcall(NpcRacer.LanePath, { Layout = entries[2].Layout, Origin = entries[2].Origin }))
		local function npcTime(laneN, s)
			local okP, prof = pcall(NpcRacer.Profile, laneN, s)
			return okP and type(prof) == "table" and prof.TotalTime or nil
		end
		local tSlow1 = laneOk and npcTime(lane, NPC_SLOW) or nil
		local tFast1 = laneOk and npcTime(lane, NPC_FAST) or nil
		local tFast2 = npcTime(lane2, NPC_FAST)
		local C1, C2 = TrackBuilder.CashFor(1), TrackBuilder.CashFor(2)
		local startCF = entries[1].Model.Start.CFrame + Vector3.new(0, CarConfig.RestHeight, 0)
		local track1Len, totalLen = 0, 0
		for i = 2, #wps do
			local seg = (wps[i] - wps[i - 1]).Magnitude
			totalLen += seg
			if i <= f1 then
				track1Len += seg
			end
		end

		local function race(tag, stat, speeds, cap, stopWhen)
			local r = newNpcRacer(api, route, startCF, tag, stat, speeds, nil)
			local npcSeen, scanT = npcModelInWorkspace(), 0
			if r.ok then
				r.elapsed = frames(cap, function(_, dt)
					stepNpcRacer(r, dt, wps)
					scanT += dt
					if scanT >= NPC_SCAN_INTERVAL then
						scanT = 0
						npcSeen = npcSeen or npcModelInWorkspace()
					end
					if stopWhen(r, os.clock() - r.clock0) then
						r.stopped = true
						return "stop"
					end
				end)
				npcSeen = npcSeen or npcModelInWorkspace()
			end
			r.npcSeen = npcSeen
			endNpcRacer(r)
			return r
		end
		local function untilRestarted(r, now)
			local reset = npcFind(r, "Reset")
			return reset ~= nil
				and r.resetPose ~= nil
				and npcFind(r, "Start", 1, reset.T - 0.05) ~= nil
				and now - reset.T >= 0.5
		end
		local function timeMatches(res, start)
			return res ~= nil
				and start ~= nil
				and isFiniteNumber(res.Event.PlayerTime)
				and math.abs(res.Event.PlayerTime - (res.T - start.T)) <= NPC_TIME_SLACK
		end
		local function npcTimeMatches(res, want)
			return res ~= nil
				and want ~= nil
				and isFiniteNumber(res.Event.NpcTime)
				and math.abs(res.Event.NpcTime - want) <= 0.01 * want
		end

		-- (a) WIN: fast player (HALF_STAT), slow NPC on both tracks
		local fastSpeed = RaceConfig.SpeedFor(RaceConfig.HALF_STAT)
		local a = race(
			"Win",
			RaceConfig.HALF_STAT,
			{ [1] = NPC_SLOW, [2] = NPC_SLOW },
			totalLen / (0.5 * fastSpeed) + 30,
			function(r, now)
				local res2 = npcFind(r, "Result", 2)
				return res2 ~= nil and (npcFind(r, "Start", 1, res2.T) ~= nil or now - res2.T > 3)
			end
		)
		check(checks, "npc_win_run_started", a.ok and 1 or 0, 1, a.ok)
		if a.ok then
			check(checks, "npc_win_completed_in_time", a.elapsed or -1, 0, a.stopped)
			local starts = npcAll(a, "Start")
			local seqOk = #starts >= 2 and starts[1].Event.Track == 1 and starts[2].Event.Track == 2
			check(checks, "npc_win_start_events_1_then_2", #starts, 2, seqOk)
			local s1 = starts[1] and starts[1].Event or {}
			local fieldsOk = s1.Speed == NPC_SLOW
				and s1.Label == "track01_NPC"
				and typeof(s1.Color) == "Color3"
				and isFiniteNumber(s1.ServerStart)
			check(checks, "npc_start_event_fields", fieldsOk and 1 or 0, 1, fieldsOk)
			local r1, r2 = npcFind(a, "Result", 1), npcFind(a, "Result", 2)
			local win1 = r1 ~= nil
				and r1.Event.Result == "Win"
				and isFiniteNumber(r1.Event.PlayerTime)
				and isFiniteNumber(r1.Event.NpcTime)
				and r1.Event.PlayerTime < r1.Event.NpcTime
			local win2 = r2 ~= nil
				and r2.Event.Result == "Win"
				and isFiniteNumber(r2.Event.PlayerTime)
				and isFiniteNumber(r2.Event.NpcTime)
				and r2.Event.PlayerTime < r2.Event.NpcTime
			check(checks, "npc_win_track1", win1 and 1 or 0, 1, win1)
			check(checks, "npc_win_track2", win2 and 1 or 0, 1, win2)
			check(
				checks,
				"npc_win_npc_time_is_profile",
				num(r1 and r1.Event.NpcTime),
				tSlow1 or -1,
				npcTimeMatches(r1, tSlow1)
			)
			check(
				checks,
				"npc_win_player_time_measured",
				num(r1 and r1.Event.PlayerTime),
				r1 and starts[1] and r1.T - starts[1].T or -1,
				timeMatches(r1, starts[1])
			)
			-- SPAWN_AND_ROLLS_SPEC section 3: a win banks the pad's cash (no payout at the finish); Destroy cashes out
			local bankedEach = r1 ~= nil
				and r2 ~= nil
				and r1.Event.Banked == C1
				and r2.Event.Banked == C2
				and r1.Event.Unbanked == C1
				and r2.Event.Unbanked == C1 + C2
			check(checks, "npc_win_banked_each_track_once", bankedEach and 1 or 0, 1, bankedEach)
			local notPaid = r1 ~= nil
				and r2 ~= nil
				and r1.Money == 0
				and r2.Money == 0
				and a.snap.BalanceBeforeDestroy == 0
				and a.snap.PaidTotal == 0
				and a.snap.Payouts == 0
			check(checks, "npc_win_not_paid_at_finish", num(a.snap.BalanceBeforeDestroy), 0, notPaid)
			local bankOk = a.snap.Unbanked == C1 + C2
				and a.snap.BankedTotal == C1 + C2
				and a.snap.UnbankedAttr == C1 + C2
			check(checks, "npc_win_bank_before_stop", num(a.snap.Unbanked), C1 + C2, bankOk)
			local pt = a.snap.PaidTotalAfter
			local totalOk = pt == C1 + C2
				and a.balance == C1 + C2
				and a.snap.PayoutsAfter == 1
				and a.snap.UnbankedAttrAfter == 0
			check(checks, "npc_win_paid_total", type(pt) == "number" and pt or -1, C1 + C2, totalOk)
			local noLoss = a.snap.Losses == 0 and a.snap.Resets == 0 and #npcAll(a, "Reset") == 0
			check(checks, "npc_win_no_losses_no_resets", noLoss and 1 or 0, 1, noLoss)
			check(checks, "npc_win_wins_counted", num(a.snap.Wins), 2, a.snap.Wins == 2)
			check(checks, "npc_win_results_recorded", num(a.snap.Results), 2, a.snap.Results == 2)
			local looped = r2 ~= nil and npcFind(a, "Start", 1, r2.T) ~= nil
			check(checks, "npc_win_loops_to_track1", looped and 1 or 0, 1, looped)
			checkNpcStability(checks, "npc_win", a)
			check(checks, "npc_win_not_in_server_workspace", a.npcSeen and 1 or 0, 0, not a.npcSeen)
		end

		-- (b) LOSE: stat 0 player against a fast NPC on Track 1: race plays out, nothing paid, back to Track 1
		local b = race(
			"Lose",
			0,
			{ [1] = NPC_FAST, [2] = NPC_FAST },
			track1Len / (0.5 * RaceConfig.BASE_SPEED) + 20,
			untilRestarted
		)
		check(checks, "npc_lose_run_started", b.ok and 1 or 0, 1, b.ok)
		if b.ok then
			check(checks, "npc_lose_completed_in_time", b.elapsed or -1, 0, b.stopped)
			local s1, r1 = npcFind(b, "Start", 1), npcFind(b, "Result", 1)
			local lose = r1 ~= nil and r1.Event.Result == "Lose"
			check(checks, "npc_lose_result_lose", lose and 1 or 0, 1, lose)
			local pT = r1 and r1.Event.PlayerTime
			local nT = r1 and r1.Event.NpcTime
			local slower = isFiniteNumber(pT) and isFiniteNumber(nT) and pT > nT
			check(
				checks,
				"npc_lose_player_slower",
				isFiniteNumber(pT) and pT or -1,
				isFiniteNumber(nT) and nT or -1,
				slower
			)
			check(
				checks,
				"npc_lose_npc_time_is_profile",
				isFiniteNumber(nT) and nT or -1,
				tFast1 or -1,
				npcTimeMatches(r1, tFast1)
			)
			check(
				checks,
				"npc_lose_speed_override_used",
				num(s1 and s1.Event.Speed),
				NPC_FAST,
				s1 ~= nil and s1.Event.Speed == NPC_FAST
			)
			-- the race plays out: the Result only arrives when the player's car reaches Track 1's finish
			local arrival = (r1 and s1) and r1.T - s1.T or -1
			check(
				checks,
				"npc_lose_result_after_npc_finish",
				arrival,
				isFiniteNumber(nT) and nT or -1,
				r1 ~= nil and s1 ~= nil and isFiniteNumber(nT) and arrival >= nT - 0.25
			)
			local dFinish = r1 and hdist(r1.Pos, joint) or -1
			check(
				checks,
				"npc_lose_result_at_finish",
				dFinish,
				NPC_FINISH_RADIUS,
				r1 ~= nil and dFinish <= NPC_FINISH_RADIUS
			)
			check(checks, "npc_lose_player_time_measured", num(pT), arrival, timeMatches(r1, s1))
			local paidNothing = r1 ~= nil
				and r1.Event.Banked == 0
				and r1.Event.Unbanked == 0
				and b.snap.BankedTotal == 0
				and b.snap.Unbanked == 0
				and b.snap.PaidTotalAfter == 0
				and b.balance == 0
				and b.snap.PayoutsAfter == 0
			check(checks, "npc_lose_paid_nothing", b.balance, 0, paidNothing)
			local counts = b.snap.Losses == 1 and b.snap.Wins == 0
			check(checks, "npc_lose_counted", type(b.snap.Losses) == "number" and b.snap.Losses or -1, 1, counts)
			local noTrack2 = npcFind(b, "Start", 2) == nil and npcFind(b, "Result", 2) == nil
			check(checks, "npc_lose_never_starts_track2", noTrack2 and 1 or 0, 1, noTrack2)
			checkNpcLoseReset(checks, "npc_lose", b, 1, wps)
			checkNpcStability(checks, "npc_lose", b)
			check(checks, "npc_lose_not_in_server_workspace", b.npcSeen and 1 or 0, 0, not b.npcSeen)
		end

		-- (c) WIN THEN LOSE: stat 0 player, slow NPC on Track 1, fast NPC on Track 2: Track 1's win is banked, and
		-- the loss on Track 2 clears the bank (SPAWN_AND_ROLLS_SPEC section 3; replaces "Track 1's money is kept")
		local c = race(
			"WinLose",
			0,
			{ [1] = NPC_SLOW, [2] = NPC_FAST },
			totalLen / (0.5 * RaceConfig.BASE_SPEED) + 20,
			untilRestarted
		)
		check(checks, "npc_win_lose_run_started", c.ok and 1 or 0, 1, c.ok)
		if c.ok then
			check(checks, "npc_win_lose_completed_in_time", c.elapsed or -1, 0, c.stopped)
			local r1, r2 = npcFind(c, "Result", 1), npcFind(c, "Result", 2)
			local order = r1 ~= nil and r2 ~= nil and r1.T <= r2.T
			local wl = order and r1.Event.Result == "Win" and r2.Event.Result == "Lose"
			check(checks, "npc_win_lose_results", wl and 1 or 0, 1, wl)
			local s2 = npcFind(c, "Start", 2)
			check(
				checks,
				"npc_win_lose_track2_npc_speed",
				num(s2 and s2.Event.Speed),
				NPC_FAST,
				s2 ~= nil and s2.Event.Speed == NPC_FAST
			)
			check(
				checks,
				"npc_win_lose_npc_time_is_profile",
				num(r2 and r2.Event.NpcTime),
				tFast2 or -1,
				npcTimeMatches(r2, tFast2)
			)
			local pT = r2 and r2.Event.PlayerTime
			local nT = r2 and r2.Event.NpcTime
			local slower = isFiniteNumber(pT) and isFiniteNumber(nT) and pT > nT
			check(
				checks,
				"npc_win_lose_player_slower_track2",
				isFiniteNumber(pT) and pT or -1,
				isFiniteNumber(nT) and nT or -1,
				slower
			)
			local bankedWin = r1 ~= nil and r1.Event.Banked == C1 and r1.Event.Unbanked == C1 and r1.Money == 0
			check(checks, "npc_win_lose_track1_banked", num(r1 and r1.Event.Unbanked), C1, bankedWin)
			local cleared = r2 ~= nil
				and r2.Event.Banked == 0
				and r2.Event.Unbanked == 0
				and r2.RunUnbanked == 0
				and r2.Money == 0
				and c.snap.Unbanked == 0
				and c.snap.UnbankedAttr == 0
			check(checks, "npc_win_lose_loss_clears_bank", num(r2 and r2.Event.Unbanked), 0, cleared)
			local nothing = c.balance == 0 and c.snap.PaidTotalAfter == 0 and c.snap.BankedTotal == C1
			check(checks, "npc_win_lose_pays_nothing_on_stop", c.balance, 0, nothing)
			local counts = c.snap.Wins == 1 and c.snap.Losses == 1
			check(checks, "npc_win_lose_counted", type(c.snap.Wins) == "number" and c.snap.Wins or -1, 1, counts)
			checkNpcLoseReset(checks, "npc_win_lose", c, 2, wps)
			checkNpcStability(checks, "npc_win_lose", c)
			check(checks, "npc_win_lose_not_in_server_workspace", c.npcSeen and 1 or 0, 0, not c.npcSeen)
		end
	end)
	for _, m in models do
		m:Destroy()
	end
	check(checks, "npc_no_error", okBody and 1 or 0, 1, okBody)
	if not okBody then
		metrics.error = tostring(err)
	end
	return result("npc", checks, metrics)
end

-- Multiplayer: two players race at the same time from the SAME spot (cars overlapping). They pass through each
-- other (collision group "Cars" does not collide with itself), both stay on their path upright, and each player's
-- NPC race is their own (one wins Track 1, the other loses and is reset without touching the winner).
function Scenarios.multiplayer()
	local PhysicsService = game:GetService("PhysicsService")
	local checks = {}
	local metrics = {}
	local NpcConfig = sharedModule("NpcConfig")
	local NpcRacer = sharedModule("NpcRacer")
	local RaceConfig = sharedModule("RaceConfig")
	local api = {
		RaceService = serverModule("RaceService"),
		Money = serverModule("MoneyService"),
		PlayerData = serverModule("PlayerData"),
	}
	local apiOk = NpcConfig ~= nil
		and NpcRacer ~= nil
		and RaceConfig ~= nil
		and api.RaceService ~= nil
		and api.Money ~= nil
		and api.PlayerData ~= nil
		and type(NpcConfig.For) == "function"
		and type(api.RaceService.BuildRoute) == "function"
		and type(api.RaceService.NewRun) == "function"
		and type(api.PlayerData.Setup) == "function"
		and type(TrackBuilder.CashFor) == "function"
	check(checks, "mp_api_exists", apiOk and 1 or 0, 1, apiOk)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("NpcRace")
	local remoteOk = remote ~= nil and remote:IsA("RemoteEvent")
	check(checks, "mp_npc_race_remote_exists", remoteOk and 1 or 0, 1, remoteOk)
	local okGroup, collidable = pcall(function()
		return PhysicsService:CollisionGroupsAreCollidable("Cars", "Cars")
	end)
	check(
		checks,
		"mp_cars_group_not_self_collidable",
		okGroup and (collidable and 1 or 0) or -1,
		0,
		okGroup and collidable == false
	)
	local specs = type(TrackRegistry.Chain) == "function" and TrackRegistry.Chain() or {}
	check(checks, "mp_chain_has_two_tracks", #specs, 2, #specs >= 2)
	if not apiOk or #specs < 2 then
		return result("multiplayer", checks, metrics)
	end

	local models = {}
	local okBody, err = pcall(function()
		local entries
		entries, models = buildNpcChain(MULTI_ORIGIN, "CarTestMultiTrack", specs)
		local okRoute, route = pcall(api.RaceService.BuildRoute, entries)
		local routeOk = okRoute
			and type(route) == "table"
			and type(route.Path) == "table"
			and type(route.Path.WorldWaypoints) == "table"
			and type(route.Tracks) == "table"
			and #route.Tracks == 2
			and type(route.Tracks[1]) == "table"
			and type(route.Tracks[1].FinishIndex) == "number"
		check(checks, "mp_route_built", routeOk and 1 or 0, 1, routeOk)
		if not routeOk then
			return
		end
		local wps = route.Path.WorldWaypoints
		local track1Len = 0
		for i = 2, route.Tracks[1].FinishIndex do
			track1Len += (wps[i] - wps[i - 1]).Magnitude
		end
		local startCF = entries[1].Model.Start.CFrame + Vector3.new(0, CarConfig.RestHeight, 0)
		local C1 = TrackBuilder.CashFor(1)

		-- Same start, same stat: A races a slow NPC (wins Track 1), B a fast one (loses Track 1)
		local A = newNpcRacer(api, route, startCF, "A", 0, { [1] = NPC_SLOW, [2] = NPC_SLOW }, "Cars")
		local B = newNpcRacer(api, route, startCF, "B", 0, { [1] = NPC_FAST, [2] = NPC_FAST }, "Cars")
		check(checks, "mp_runs_started", (A.ok and 1 or 0) + (B.ok and 1 or 0), 2, A.ok and B.ok)
		local startGap = (A.Chassis.Position - B.Chassis.Position).Magnitude
		check(checks, "mp_cars_overlap_at_start", startGap, 1, startGap <= 1)
		local npcSeen, scanT = npcModelInWorkspace(), 0
		local notInGroup = -1
		local lastA, beforeA, afterA = nil, nil, nil
		local stopped, elapsed = false, 0
		if A.ok and B.ok then
			elapsed = frames(track1Len / (0.5 * RaceConfig.BASE_SPEED) + 25, function(t, dt)
				stepNpcRacer(A, dt, wps)
				stepNpcRacer(B, dt, wps)
				if notInGroup < 0 and t >= 1 then
					notInGroup = 0
					for _, car in { A.Car, B.Car } do
						for _, p in car:GetDescendants() do
							if p:IsA("BasePart") and p.CollisionGroup ~= "Cars" then
								notInGroup += 1
							end
						end
					end
				end
				scanT += dt
				if scanT >= NPC_SCAN_INTERVAL then
					scanT = 0
					npcSeen = npcSeen or npcModelInWorkspace()
				end
				-- the winner's state just before and 1 s after the loser's reset
				local resetB = npcFind(B, "Reset")
				local now = os.clock() - B.clock0
				if resetB and not beforeA then
					beforeA = lastA or {}
				end
				if resetB and beforeA and not afterA and now - resetB.T >= 1 then
					afterA = {
						RaceTrack = A.Run.RaceTrack,
						Results = type(A.Run.Results) == "table" and #A.Run.Results or -1,
					}
				end
				lastA = {
					RaceTrack = A.Run.RaceTrack,
					Results = type(A.Run.Results) == "table" and #A.Run.Results or -1,
				}
				if afterA and npcFind(A, "Result", 1) and B.resetPose and npcFind(B, "Start", 1, resetB.T - 0.05) then
					stopped = true
					return "stop"
				end
			end)
			npcSeen = npcSeen or npcModelInWorkspace()
		end
		if A.ok then
			endNpcRacer(A)
		else
			A.snap = {}
			A.Car:Destroy()
			A.Player:Destroy()
		end
		if B.ok then
			endNpcRacer(B)
		else
			B.snap = {}
			B.Car:Destroy()
			B.Player:Destroy()
		end
		if not (A.ok and B.ok) then
			return
		end
		metrics.elapsed = round(elapsed)
		check(checks, "mp_completed_in_time", elapsed, 0, stopped)
		check(checks, "mp_cars_in_cars_group", notInGroup, 0, notInGroup == 0)

		local maxDev = PhysicsTargets.race.MaxPathDeviation
		check(checks, "mp_a_sticks_to_path", A.dev, maxDev, A.dev <= maxDev)
		check(checks, "mp_b_sticks_to_path", B.dev, maxDev, B.dev <= maxDev)
		checkNpcStability(checks, "mp_a", A)
		checkNpcStability(checks, "mp_b", B)

		local rA, rB = npcFind(A, "Result", 1), npcFind(B, "Result", 1)
		check(checks, "mp_both_reach_track1_finish", (rA and 1 or 0) + (rB and 1 or 0), 2, rA ~= nil and rB ~= nil)
		check(
			checks,
			"mp_a_wins_track1",
			rA and rA.Event.Result == "Win" and 1 or 0,
			1,
			rA ~= nil and rA.Event.Result == "Win"
		)
		check(
			checks,
			"mp_b_loses_track1",
			rB and rB.Event.Result == "Lose" and 1 or 0,
			1,
			rB ~= nil and rB.Event.Result == "Lose"
		)

		-- each recorder only got its own run's events
		local aOwn = #npcAll(A, "Reset") == 0 and #npcAll(A, "Start") > 0
		for _, rec in A.Events do
			if rec.Event.Result == "Lose" or (rec.Event.Type == "Start" and rec.Event.Speed ~= NPC_SLOW) then
				aOwn = false
			end
		end
		local bOwn = #npcAll(B, "Reset") >= 1 and #npcAll(B, "Start") > 0
		for _, rec in B.Events do
			if rec.Event.Result == "Win" or (rec.Event.Type == "Start" and rec.Event.Speed ~= NPC_FAST) then
				bOwn = false
			end
		end
		check(checks, "mp_events_separate_per_player", (aOwn and 1 or 0) + (bOwn and 1 or 0), 2, aOwn and bOwn)

		-- the loser's reset does not touch the winner (on Track 2 with one Win)
		local unaffected = beforeA ~= nil
			and afterA ~= nil
			and beforeA.RaceTrack == 2
			and afterA.RaceTrack == 2
			and beforeA.Results == 1
			and afterA.Results == 1
		check(checks, "mp_loser_reset_leaves_winner", num(afterA and afterA.RaceTrack), 2, unaffected)
		local resetPose = B.resetPose
		local dB = resetPose and hdist(resetPose.Position, wps[1]) or -1
		check(
			checks,
			"mp_loser_reset_to_track1_start",
			dB,
			NPC_RESET_RADIUS,
			resetPose ~= nil and dB <= NPC_RESET_RADIUS
		)
		-- banked (SPAWN_AND_ROLLS_SPEC section 3): A's Track 1 win is in A's bank only, paid when A's run ends
		local money = A.balance == C1
			and A.snap.BankedTotal == C1
			and A.snap.PaidTotal == 0
			and A.snap.PaidTotalAfter == C1
			and B.balance == 0
			and B.snap.BankedTotal == 0
			and B.snap.PaidTotalAfter == 0
		check(checks, "mp_money_per_player", A.balance, C1, money)
		check(checks, "mp_no_npc_in_server_workspace", npcSeen and 1 or 0, 0, not npcSeen)
	end)
	for _, m in models do
		m:Destroy()
	end
	check(checks, "mp_no_error", okBody and 1 or 0, 1, okBody)
	if not okBody then
		metrics.error = tostring(err)
	end
	return result("multiplayer", checks, metrics)
end

-- Spawn area (contract: docs/SPAWN_AND_ROLLS_SPEC.md, sections 1 and 2).
-- BRIEF (owner, 2026-10-01): "Create a spawn area, relatively large and purple for now, close to Track 1 and
-- connected to its start, so players can walk onto the start platform to start auto racing. It is the spawn point
-- (join and respawn) and where Stop always sends the player, out of the race." Owner's answer: join/respawn = on
-- foot in the spawn area.
-- The geometry is read from the LIVE Workspace (Main builds Workspace.SpawnArea after the chain), in the local
-- space of Track 1's Start part. The player flow uses a fake player (Folder) with fake R6 characters, driven
-- through the two server entry points: CarService.OnCharacter(player, character) (what CharacterAdded runs on join
-- and on every respawn) and CarService.PadTouched(player, hitPart) (what StartPad.Touched runs once it has
-- resolved the player).
local SPAWN_COLOR = Color3.fromRGB(140, 70, 220)
local SPAWN_AREA_MIN = Vector2.new(24, -100) -- local (x, z)
local SPAWN_AREA_MAX = Vector2.new(184, 44)
local SPAWN_PAD_MIN = Vector2.new(-20, 2)
local SPAWN_PAD_MAX = Vector2.new(24, 38)
local SPAWN_TOP_Y = 1
local SPAWN_PAD_TOP = 1.2 -- TOP_Y + 0.2
local SPAWN_START_COOLDOWN = 2
local SPAWN_WALK_ROOT_HEIGHT = 3
local SPAWN_WALK_CLEARANCE = 75 -- CarService WALK_CLEARANCE
local SPAWN_EDGE_HEIGHT = 2
local SPAWN_LOCATION_SIZE = Vector3.new(12, 1, 12)
local SPAWN_GEOM_TOL = 0.5 -- studs: footprints match the spec within this
local SPAWN_TOP_TOL = 0.1 -- studs: tops match the spec within this
local SPAWN_TOUCH_GAP = 1 -- studs: "touches" = horizontal gap at most this
local SPAWN_OVERLAP_TOL = 0.05 -- studs of footprint overlap ignored (edges that only touch)
local SPAWN_SIDE_REACH = 3 -- studs: an Edge part lies along a side when its centre is this close to the side line
local SPAWN_SIDE_COVER = 0.9 -- share of each of the three outer sides the Edge parts must cover
local SPAWN_MIDDLE = 8 -- studs (horizontal) the SpawnLocation may be from the area centre
local SPAWN_AT_SPAWN = 4 -- studs (horizontal) the avatar may be from WalkSpawnCFrame
local SPAWN_FACING = 0.9 -- walk spawn look . direction to the pad centre (flat)
local SPAWN_STAND_MIN, SPAWN_STAND_MAX = 1.5, 5 -- root height above the floor top while standing

-- Horizontal footprint of a part as a convex polygon: its 8 corners projected on XZ and the projected axes.
local function spawnPartPoly(part)
	local cf, s = part.CFrame, part.Size / 2
	local pts = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local w = cf:PointToWorldSpace(Vector3.new(x * s.X, y * s.Y, z * s.Z))
				table.insert(pts, Vector2.new(w.X, w.Z))
			end
		end
	end
	local dirs = {}
	for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
		local d = Vector2.new(v.X, v.Z)
		if d.Magnitude > 1e-3 then
			table.insert(dirs, d.Unit)
		end
	end
	return { Points = pts, Dirs = dirs }
end

-- A local (x, z) rectangle in the space of `base`, as a world footprint polygon.
local function spawnRectPoly(base, minV, maxV)
	local pts = {}
	for _, c in
		{
			Vector3.new(minV.X, 0, minV.Y),
			Vector3.new(maxV.X, 0, minV.Y),
			Vector3.new(maxV.X, 0, maxV.Y),
			Vector3.new(minV.X, 0, maxV.Y),
		}
	do
		local w = base:PointToWorldSpace(c)
		table.insert(pts, Vector2.new(w.X, w.Z))
	end
	local dirs = {}
	for _, v in { base.RightVector, base.LookVector } do
		local d = Vector2.new(v.X, v.Z)
		if d.Magnitude > 1e-3 then
			table.insert(dirs, d.Unit)
		end
	end
	return { Points = pts, Dirs = dirs }
end

-- Separating-axis test of two convex footprints: > 0 is the gap between them, <= 0 means they overlap by -value.
local function spawnPolySeparation(a, b)
	local best = -math.huge
	for _, poly in { a, b } do
		for _, d in poly.Dirs do
			for _, ax in { d, Vector2.new(-d.Y, d.X) } do
				local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
				for _, p in a.Points do
					local v = p:Dot(ax)
					aMin, aMax = math.min(aMin, v), math.max(aMax, v)
				end
				for _, p in b.Points do
					local v = p:Dot(ax)
					bMin, bMax = math.min(bMin, v), math.max(bMax, v)
				end
				best = math.max(best, math.max(bMin - aMax, aMin - bMax))
			end
		end
	end
	return best
end

-- Local (x, z) bounds of a part in the space of `base`, and its world top Y.
local function spawnLocalBounds(base, part)
	local cf, s = part.CFrame, part.Size / 2
	local minX, maxX, minZ, maxZ, top = math.huge, -math.huge, math.huge, -math.huge, -math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local w = cf:PointToWorldSpace(Vector3.new(x * s.X, y * s.Y, z * s.Z))
				local l = base:PointToObjectSpace(w)
				minX, maxX = math.min(minX, l.X), math.max(maxX, l.X)
				minZ, maxZ = math.min(minZ, l.Z), math.max(maxZ, l.Z)
				top = math.max(top, w.Y)
			end
		end
	end
	return Vector2.new(minX, minZ), Vector2.new(maxX, maxZ), top
end

local function spawnV2Err(a, b)
	return math.max(math.abs(a.X - b.X), math.abs(a.Y - b.Y))
end

local function spawnInsideLocal(base, pos, minV, maxV)
	local l = base:PointToObjectSpace(pos)
	return l.X >= minV.X and l.X <= maxV.X and l.Z >= minV.Y and l.Z <= maxV.Y
end

function Scenarios.spawn_area()
	local checks = {}
	local metrics = {}
	local StarterPlayer = game:GetService("StarterPlayer")
	local SpawnArea = sharedModule("SpawnArea")
	local CarService = serverModule("CarService")
	local RaceService = serverModule("RaceService")
	local PlayerData = serverModule("PlayerData")
	local Money = serverModule("MoneyService")

	-- Constants and API (section 1)
	local moduleOk = SpawnArea ~= nil
	check(checks, "spawn_module_exists", moduleOk and 1 or 0, 1, moduleOk)
	local A = SpawnArea or {}
	local function v2is(v, want)
		return typeof(v) == "Vector2" and spawnV2Err(v, want) <= 1e-6
	end
	check(checks, "spawn_color", colorClose(A.COLOR, SPAWN_COLOR) and 1 or 0, 1, colorClose(A.COLOR, SPAWN_COLOR))
	local boundsConst = v2is(A.AREA_MIN, SPAWN_AREA_MIN) and v2is(A.AREA_MAX, SPAWN_AREA_MAX)
	check(checks, "spawn_area_bounds_constants", boundsConst and 1 or 0, 1, boundsConst)
	local padConst = v2is(A.PAD_MIN, SPAWN_PAD_MIN) and v2is(A.PAD_MAX, SPAWN_PAD_MAX)
	check(checks, "spawn_pad_bounds_constants", padConst and 1 or 0, 1, padConst)
	check(checks, "spawn_top_y", num(A.TOP_Y), SPAWN_TOP_Y, A.TOP_Y == SPAWN_TOP_Y)
	check(
		checks,
		"spawn_start_cooldown",
		num(A.START_COOLDOWN),
		SPAWN_START_COOLDOWN,
		A.START_COOLDOWN == SPAWN_START_COOLDOWN
	)
	check(
		checks,
		"spawn_walk_root_height",
		num(A.WALK_ROOT_HEIGHT),
		SPAWN_WALK_ROOT_HEIGHT,
		A.WALK_ROOT_HEIGHT == SPAWN_WALK_ROOT_HEIGHT
	)
	local apiOk = moduleOk
		and type(A.Build) == "function"
		and type(A.WalkCFrame) == "function"
		and type(A.Bounds) == "function"
	check(checks, "spawn_api_exists", apiOk and 1 or 0, 1, apiOk)
	local serviceOk = CarService ~= nil
		and RaceService ~= nil
		and PlayerData ~= nil
		and Money ~= nil
		and type(CarService.OnCharacter) == "function"
		and type(CarService.PadTouched) == "function"
		and type(CarService.SetAutoRace) == "function"
		and type(CarService.IsAutoRacing) == "function"
		and type(CarService.GetCar) == "function"
		and type(CarService.GetRun) == "function"
		and type(CarService.WalkSpawnCFrame) == "function"
		and type(RaceService.NewRun) == "function"
		and type(RaceService.GetRoute) == "function"
	check(checks, "spawn_car_service_hooks_exist", serviceOk and 1 or 0, 1, serviceOk)

	-- The live chain and Track 1's Start part
	local trackFolder = Workspace:FindFirstChild("Track")
	local specs = type(TrackRegistry.Chain) == "function" and TrackRegistry.Chain() or {}
	local track1 = trackFolder and specs[1] and trackFolder:FindFirstChild(specs[1].Name)
	local startPart = track1 and track1:FindFirstChild("Start")
	local chainOk = startPart ~= nil and startPart:IsA("BasePart")
	check(checks, "spawn_live_chain_present", chainOk and 1 or 0, 1, chainOk)

	-- Workspace.SpawnArea and its parts
	local area = Workspace:FindFirstChild("SpawnArea")
	local areaOk = area ~= nil and area:IsA("Model")
	check(checks, "spawn_area_model_exists", areaOk and 1 or 0, 1, areaOk)
	if not (chainOk and areaOk) then
		return result("spawn_area", checks, metrics)
	end
	local base = startPart.CFrame
	local floor = area:FindFirstChild("Floor")
	local spawn = area:FindFirstChild("Spawn")
	local pad = area:FindFirstChild("StartPad")
	local floorOk = floor ~= nil and floor:IsA("BasePart")
	local spawnOk = spawn ~= nil and spawn:IsA("SpawnLocation")
	local padOk = pad ~= nil and pad:IsA("BasePart")
	check(checks, "spawn_floor_exists", floorOk and 1 or 0, 1, floorOk)
	check(checks, "spawn_location_exists", spawnOk and 1 or 0, 1, spawnOk)
	check(checks, "spawn_start_pad_exists", padOk and 1 or 0, 1, padOk)

	-- Floor: anchored, purple SmoothPlastic, covers AREA_MIN..AREA_MAX (160 x 144), top at TOP_Y
	if floorOk then
		local fMin, fMax, fTop = spawnLocalBounds(base, floor)
		local err = math.max(spawnV2Err(fMin, SPAWN_AREA_MIN), spawnV2Err(fMax, SPAWN_AREA_MAX))
		check(checks, "spawn_floor_covers_area", err, SPAWN_GEOM_TOL, err <= SPAWN_GEOM_TOL)
		local size = fMax - fMin
		metrics.floor_size = ("%.1f x %.1f"):format(size.X, size.Y)
		local sizeOk = math.abs(size.X - 160) <= SPAWN_GEOM_TOL and math.abs(size.Y - 144) <= SPAWN_GEOM_TOL
		check(checks, "spawn_floor_160_by_144", size.X, 160, sizeOk)
		check(checks, "spawn_floor_top", fTop, SPAWN_TOP_Y, math.abs(fTop - SPAWN_TOP_Y) <= SPAWN_TOP_TOL)
		check(checks, "spawn_floor_anchored", floor.Anchored and 1 or 0, 1, floor.Anchored)
		local purple = colorClose(floor.Color, SPAWN_COLOR)
		check(checks, "spawn_floor_purple", purple and 1 or 0, 1, purple)
		local smooth = floor.Material == Enum.Material.SmoothPlastic
		check(checks, "spawn_floor_smooth_plastic", smooth and 1 or 0, 1, smooth)
		local collide = floor.CanCollide
		check(checks, "spawn_floor_walkable", collide and 1 or 0, 1, collide)
	end

	-- Edge walls: low (2 studs), anchored, on the three outer sides, none on the side facing the pad / road
	local edges = {}
	for _, d in area:GetChildren() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 4) == "Edge" then
			table.insert(edges, d)
		end
	end
	check(checks, "spawn_edges_exist", #edges, 3, #edges >= 3)
	local edgeBad = 0
	local cover = { xMax = 0, zMin = 0, zMax = 0 }
	local onPadSide = 0
	for _, e in edges do
		local eMin, eMax, eTop = spawnLocalBounds(base, e)
		if not e.Anchored or math.abs(eTop - (SPAWN_TOP_Y + SPAWN_EDGE_HEIGHT)) > 0.5 then
			edgeBad += 1
		end
		local c = (eMin + eMax) / 2
		local function spanZ()
			return math.max(0, math.min(eMax.Y, SPAWN_AREA_MAX.Y) - math.max(eMin.Y, SPAWN_AREA_MIN.Y))
		end
		local function spanX()
			return math.max(0, math.min(eMax.X, SPAWN_AREA_MAX.X) - math.max(eMin.X, SPAWN_AREA_MIN.X))
		end
		if math.abs(c.X - SPAWN_AREA_MAX.X) <= SPAWN_SIDE_REACH then
			cover.xMax += spanZ()
		end
		if math.abs(c.Y - SPAWN_AREA_MIN.Y) <= SPAWN_SIDE_REACH then
			cover.zMin += spanX()
		end
		if math.abs(c.Y - SPAWN_AREA_MAX.Y) <= SPAWN_SIDE_REACH then
			cover.zMax += spanX()
		end
		if math.abs(c.X - SPAWN_AREA_MIN.X) <= SPAWN_SIDE_REACH and spanZ() > SPAWN_SIDE_REACH then
			onPadSide += 1
		end
	end
	check(checks, "spawn_edges_low_and_anchored", edgeBad, 0, #edges > 0 and edgeBad == 0)
	local sideX = SPAWN_AREA_MAX.X - SPAWN_AREA_MIN.X
	local sideZ = SPAWN_AREA_MAX.Y - SPAWN_AREA_MIN.Y
	local worstCover = math.min(cover.xMax / sideZ, cover.zMin / sideX, cover.zMax / sideX)
	check(checks, "spawn_edges_cover_three_outer_sides", worstCover, SPAWN_SIDE_COVER, worstCover >= SPAWN_SIDE_COVER)
	check(checks, "spawn_no_edge_on_pad_side", onPadSide, 0, onPadSide == 0)

	-- SpawnLocation: the game's only one, Neutral, Duration 0, 12 x 1 x 12, purple, in the middle, top at TOP_Y
	local spawnCount = 0
	for _, d in Workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			spawnCount += 1
		end
	end
	check(checks, "spawn_only_spawn_location", spawnCount, 1, spawnCount == 1 and spawnOk)
	if spawnOk then
		check(checks, "spawn_location_neutral", spawn.Neutral and 1 or 0, 1, spawn.Neutral == true)
		check(checks, "spawn_location_duration", spawn.Duration, 0, spawn.Duration == 0)
		local sizeErr = (spawn.Size - SPAWN_LOCATION_SIZE).Magnitude
		check(checks, "spawn_location_size", sizeErr, 0.01, sizeErr <= 0.01)
		local sc = colorClose(spawn.Color, SPAWN_COLOR)
		check(checks, "spawn_location_purple", sc and 1 or 0, 1, sc)
		local _, _, sTop = spawnLocalBounds(base, spawn)
		check(checks, "spawn_location_top", sTop, SPAWN_TOP_Y, math.abs(sTop - SPAWN_TOP_Y) <= SPAWN_TOP_TOL)
		local centre = base:PointToWorldSpace(
			Vector3.new((SPAWN_AREA_MIN.X + SPAWN_AREA_MAX.X) / 2, 0, (SPAWN_AREA_MIN.Y + SPAWN_AREA_MAX.Y) / 2)
		)
		local dMid = hdist(spawn.Position, centre)
		check(checks, "spawn_location_in_middle", dMid, SPAWN_MIDDLE, dMid <= SPAWN_MIDDLE)
	end

	-- StartPad: anchored, bright green Neon, tagged StartPad, touchable, covers PAD_MIN..PAD_MAX, top TOP_Y + 0.2,
	-- with a "RACE" sign; it touches the area and Track 1's Start, and spans the road's centre line
	if padOk then
		local pMin, pMax, pTop = spawnLocalBounds(base, pad)
		local err = math.max(spawnV2Err(pMin, SPAWN_PAD_MIN), spawnV2Err(pMax, SPAWN_PAD_MAX))
		check(checks, "spawn_pad_covers_bounds", err, SPAWN_GEOM_TOL, err <= SPAWN_GEOM_TOL)
		check(checks, "spawn_pad_top", pTop, SPAWN_PAD_TOP, math.abs(pTop - SPAWN_PAD_TOP) <= SPAWN_TOP_TOL)
		check(checks, "spawn_pad_anchored", pad.Anchored and 1 or 0, 1, pad.Anchored)
		local tagged = CollectionService:HasTag(pad, "StartPad")
		check(checks, "spawn_pad_tagged", tagged and 1 or 0, 1, tagged)
		check(checks, "spawn_pad_can_touch", pad.CanTouch and 1 or 0, 1, pad.CanTouch)
		local neon = pad.Material == Enum.Material.Neon
		check(checks, "spawn_pad_neon", neon and 1 or 0, 1, neon)
		local c = pad.Color
		local green = c.G >= 0.6 and c.G - c.R >= 0.2 and c.G - c.B >= 0.2
		check(checks, "spawn_pad_bright_green", c.G * 255, 153, green)
		local sign = false
		for _, d in pad:GetDescendants() do
			if d:IsA("TextLabel") and string.find(string.upper(d.Text), "RACE", 1, true) then
				local gui = d:FindFirstAncestorWhichIsA("LayerCollector")
				if gui and (gui:IsA("SurfaceGui") or gui:IsA("BillboardGui")) then
					sign = true
				end
			end
		end
		check(checks, "spawn_pad_race_sign", sign and 1 or 0, 1, sign)
		local spansCentre = pMin.X <= 0 and pMax.X >= 0
		check(checks, "spawn_pad_spans_road_centre", spansCentre and 1 or 0, 1, spansCentre)
		local padPoly = spawnPartPoly(pad)
		if floorOk then
			local gapArea = spawnPolySeparation(padPoly, spawnPartPoly(floor))
			check(checks, "spawn_pad_touches_area", gapArea, SPAWN_TOUCH_GAP, gapArea <= SPAWN_TOUCH_GAP)
		end
		local gapStart = spawnPolySeparation(padPoly, spawnPartPoly(startPart))
		check(checks, "spawn_pad_touches_track1_start", gapStart, SPAWN_TOUCH_GAP, gapStart <= SPAWN_TOUCH_GAP)
	end

	-- SpawnArea.Bounds(start): world corners of the area and the pad, Y = TOP_Y
	if apiOk then
		local okB, bounds = pcall(A.Bounds, base)
		local function worldBox(minV, maxV)
			local lo, hi = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
			for _, x in { minV.X, maxV.X } do
				for _, z in { minV.Y, maxV.Y } do
					local w = base:PointToWorldSpace(Vector3.new(x, 0, z))
					lo = Vector3.new(math.min(lo.X, w.X), 0, math.min(lo.Z, w.Z))
					hi = Vector3.new(math.max(hi.X, w.X), 0, math.max(hi.Z, w.Z))
				end
			end
			return lo, hi
		end
		local function boxErr(b, minV, maxV)
			if type(b) ~= "table" or typeof(b.Min) ~= "Vector3" or typeof(b.Max) ~= "Vector3" then
				return math.huge
			end
			local lo, hi = worldBox(minV, maxV)
			local bLo = Vector3.new(math.min(b.Min.X, b.Max.X), 0, math.min(b.Min.Z, b.Max.Z))
			local bHi = Vector3.new(math.max(b.Min.X, b.Max.X), 0, math.max(b.Min.Z, b.Max.Z))
			local e =
				math.max(math.abs(bLo.X - lo.X), math.abs(bLo.Z - lo.Z), math.abs(bHi.X - hi.X), math.abs(bHi.Z - hi.Z))
			return math.max(e, math.abs(b.Min.Y - SPAWN_TOP_Y), math.abs(b.Max.Y - SPAWN_TOP_Y))
		end
		local eA = okB and type(bounds) == "table" and boxErr(bounds.Area, SPAWN_AREA_MIN, SPAWN_AREA_MAX) or math.huge
		local eP = okB and type(bounds) == "table" and boxErr(bounds.Pad, SPAWN_PAD_MIN, SPAWN_PAD_MAX) or math.huge
		check(checks, "spawn_bounds_area", eA == math.huge and -1 or eA, 0.01, eA <= 0.01)
		check(checks, "spawn_bounds_pad", eP == math.huge and -1 or eP, 0.01, eP <= 0.01)
	end

	-- Walk spawn: SpawnArea.WalkCFrame(start) == CarService.WalkSpawnCFrame(), at the area centre, root
	-- WALK_ROOT_HEIGHT above TOP_Y, facing the pad, inside the area, >= WALK_CLEARANCE from every race waypoint
	local okW, walkCF = false, nil
	if serviceOk then
		okW, walkCF = pcall(CarService.WalkSpawnCFrame)
	end
	local walkOk = okW and typeof(walkCF) == "CFrame"
	check(checks, "spawn_walk_spawn_is_cframe", walkOk and 1 or 0, 1, walkOk)
	if not walkOk then
		walkCF = base * CFrame.new(104, 3, -28)
	end
	if apiOk and walkOk then
		local okA, areaCF = pcall(A.WalkCFrame, base)
		local same = okA
			and typeof(areaCF) == "CFrame"
			and (areaCF.Position - walkCF.Position).Magnitude <= 0.01
			and areaCF.LookVector:Dot(walkCF.LookVector) >= 0.999
		check(checks, "spawn_walk_spawn_is_area_walk_cframe", same and 1 or 0, 1, same)
	end
	local centreLocal =
		Vector3.new((SPAWN_AREA_MIN.X + SPAWN_AREA_MAX.X) / 2, 0, (SPAWN_AREA_MIN.Y + SPAWN_AREA_MAX.Y) / 2)
	local centreWorld = base:PointToWorldSpace(centreLocal)
	local dCentre = hdist(walkCF.Position, centreWorld)
	check(checks, "spawn_walk_at_area_centre", dCentre, SPAWN_GEOM_TOL, dCentre <= SPAWN_GEOM_TOL)
	local wantY = SPAWN_TOP_Y + SPAWN_WALK_ROOT_HEIGHT
	check(checks, "spawn_walk_root_height", walkCF.Position.Y, wantY, math.abs(walkCF.Position.Y - wantY) <= 0.05)
	local inside = spawnInsideLocal(base, walkCF.Position, SPAWN_AREA_MIN, SPAWN_AREA_MAX)
	check(checks, "spawn_walk_inside_area", inside and 1 or 0, 1, inside)
	local padCentre = base:PointToWorldSpace(
		Vector3.new((SPAWN_PAD_MIN.X + SPAWN_PAD_MAX.X) / 2, 0, (SPAWN_PAD_MIN.Y + SPAWN_PAD_MAX.Y) / 2)
	)
	local toPad = flatV(padCentre - walkCF.Position)
	local look = flatV(walkCF.LookVector)
	local facing = (toPad.Magnitude > 1e-6 and look.Magnitude > 1e-6) and look.Unit:Dot(toPad.Unit) or -1
	check(checks, "spawn_walk_faces_pad", facing, SPAWN_FACING, facing >= SPAWN_FACING)
	local route = serviceOk and RaceService.GetRoute() or nil
	local wps = route and route.Path and route.Path.WorldWaypoints or {}
	local nearest = math.huge
	for _, w in wps do
		nearest = math.min(nearest, hdist(w, walkCF.Position))
	end
	check(checks, "spawn_route_present", #wps, 2, #wps >= 2)
	check(
		checks,
		"spawn_walk_clear_of_race_path",
		nearest == math.huge and -1 or nearest,
		SPAWN_WALK_CLEARANCE,
		#wps >= 2 and nearest >= SPAWN_WALK_CLEARANCE
	)

	-- No part of the area (floor, edges, spawn, pad) overlaps any road / wall / checkpoint part of ANY chained
	-- track horizontally (each track's Ground and its invisible Start marker are not road)
	local trackParts = {}
	for _, d in trackFolder:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Ground" and d.Name ~= "Start" then
			table.insert(trackParts, { Part = d, Poly = spawnPartPoly(d) })
		end
	end
	metrics.track_parts_checked = #trackParts
	local overlaps, worst, worstName = 0, math.huge, ""
	for _, d in area:GetDescendants() do
		if d:IsA("BasePart") then
			local poly = spawnPartPoly(d)
			for _, t in trackParts do
				local sep = spawnPolySeparation(poly, t.Poly)
				if sep < worst then
					worst, worstName = sep, d.Name .. "/" .. t.Part:GetFullName()
				end
				if sep < -SPAWN_OVERLAP_TOL then
					overlaps += 1
				end
			end
		end
	end
	if overlaps > 0 then
		metrics.worst_overlap = worstName
	end
	metrics.closest_track_gap = worst == math.huge and -1 or round(worst)
	check(checks, "spawn_area_no_track_overlap", overlaps, 0, #trackParts > 0 and overlaps == 0)
	-- the spec rectangles themselves stay clear too (the area is not allowed to grow into a road later)
	local rectOverlaps = 0
	for _, rect in
		{ spawnRectPoly(base, SPAWN_AREA_MIN, SPAWN_AREA_MAX), spawnRectPoly(base, SPAWN_PAD_MIN, SPAWN_PAD_MAX) }
	do
		for _, t in trackParts do
			if spawnPolySeparation(rect, t.Poly) < -SPAWN_OVERLAP_TOL then
				rectOverlaps += 1
			end
		end
	end
	check(checks, "spawn_bounds_no_track_overlap", rectOverlaps, 0, rectOverlaps == 0)

	if not serviceOk then
		return result("spawn_area", checks, metrics)
	end

	-- Player flow (section 2) with a fake player
	local function call(fn, ...)
		local ok, r = pcall(fn, ...)
		if ok then
			return r
		end
		return nil
	end
	local function carModels()
		local list = {}
		for _, d in Workspace:GetDescendants() do
			if d:IsA("Model") then
				local seat = d:FindFirstChild("DriverSeat")
				if seat and seat:IsA("VehicleSeat") then
					table.insert(list, d)
				end
			end
		end
		return list
	end
	local baseline = {}
	for _, m in carModels() do
		baseline[m] = true
	end
	local function ourCars()
		local list = {}
		for _, m in carModels() do
			if not baseline[m] then
				table.insert(list, m)
			end
		end
		return list
	end

	local player = Instance.new("Folder")
	player.Name = "CarTestSpawnPlayer"
	player.Parent = Workspace
	local okSetup = pcall(function()
		Money.Setup(player)
		PlayerData.Setup(player)
		player.leaderstats.Speed.Value = 0
	end)
	check(checks, "spawn_fake_player_setup", okSetup and 1 or 0, 1, okSetup)

	local runs = {}
	local origNewRun = RaceService.NewRun
	RaceService.NewRun = function(car, raceRoute, p, options)
		local run = origNewRun(car, raceRoute, p, options)
		if p == player and type(run) == "table" then
			table.insert(runs, run)
		end
		return run
	end
	local function activeRuns()
		local n = 0
		for _, r in runs do
			if r.Connection ~= nil then
				n += 1
			end
		end
		return n
	end

	local chars = {}
	local function newChar(offset)
		local model, humanoid, root, head, face = newFakeCharacter(CFrame.new(walkCF.Position + offset))
		model.Name = "CarTestSpawnCharacter"
		table.insert(chars, model)
		return { Model = model, Humanoid = humanoid, Root = root, Head = head, Face = face }
	end
	local function racing()
		return call(CarService.IsAutoRacing, player) == true
	end
	local walkSpeed = StarterPlayer.CharacterWalkSpeed
	local jumpHeight = StarterPlayer.CharacterJumpHeight

	-- On foot at the walk spawn, visible, able to walk and jump, not racing, no car, no run
	local function checkOnFoot(pre, c)
		local notRacing = not racing() and player:GetAttribute("AutoRacing") == false
		check(checks, pre .. "_not_racing", notRacing and 1 or 0, 1, notRacing)
		local noCar = call(CarService.GetCar, player) == nil
			and call(CarService.GetRun, player) == nil
			and #ourCars() == 0
			and activeRuns() == 0
		check(checks, pre .. "_no_car", #ourCars(), 0, noCar)
		local d = hdist(c.Root.Position, walkCF.Position)
		check(checks, pre .. "_at_walk_spawn", d, SPAWN_AT_SPAWN, d <= SPAWN_AT_SPAWN)
		local inArea = spawnInsideLocal(base, c.Root.Position, SPAWN_AREA_MIN, SPAWN_AREA_MAX)
		check(checks, pre .. "_inside_area", inArea and 1 or 0, 1, inArea)
		local h = c.Root.Position.Y - SPAWN_TOP_Y
		check(
			checks,
			pre .. "_standing_height",
			h,
			SPAWN_WALK_ROOT_HEIGHT,
			h >= SPAWN_STAND_MIN and h <= SPAWN_STAND_MAX
		)
		local visible = c.Head.Transparency == 0 and c.Face.Transparency == 0
		check(checks, pre .. "_visible", visible and 1 or 0, 1, visible)
		local unseated = c.Humanoid.SeatPart == nil and c.Humanoid.Sit == false
		check(checks, pre .. "_unseated", unseated and 1 or 0, 1, unseated)
		local walks = c.Humanoid.WalkSpeed == walkSpeed
			and walkSpeed > 0
			and math.abs(c.Humanoid.JumpHeight - jumpHeight) <= 1e-3
		check(checks, pre .. "_walks_and_jumps", c.Humanoid.WalkSpeed, walkSpeed, walks)
		local ub = player:GetAttribute("Unbanked")
		check(checks, pre .. "_unbanked_zero", type(ub) == "number" and ub or 0, 0, ub == nil or ub == 0)
		-- SPAWN_AND_ROLLS_SPEC section 2: "Start is an event": on foot the event is "Off"
		local ev = player:GetAttribute("RaceEvent")
		check(checks, pre .. "_race_event_off", ev == "Off" and 1 or 0, 1, ev == "Off")
	end
	-- Racing on a fresh car (not `oldCar`), seated in it, one car, one active run
	local function checkRacing(pre, c, oldCar)
		local stateOk = racing() and player:GetAttribute("AutoRacing") == true
		check(checks, pre .. "_racing", stateOk and 1 or 0, 1, stateOk)
		local car = call(CarService.GetCar, player)
		local cars = ourCars()
		local carOk = car ~= nil and car.Parent ~= nil and car ~= oldCar and #cars == 1 and cars[1] == car
		check(checks, pre .. "_one_car", #cars, 1, carOk)
		local auto = car ~= nil and car:GetAttribute("AutoRace") == true
		check(checks, pre .. "_car_auto_race", auto and 1 or 0, 1, auto)
		local seat = car and car:FindFirstChild("DriverSeat")
		local seated = seat ~= nil and c.Humanoid.SeatPart == seat
		check(checks, pre .. "_seated", seated and 1 or 0, 1, seated)
		local run = call(CarService.GetRun, player)
		local runOk = type(run) == "table" and run.Connection ~= nil and run.Car == car and activeRuns() == 1
		check(checks, pre .. "_one_active_run", activeRuns(), 1, runOk)
		-- "Start is an event": racing means seated, released (chassis not anchored) and RaceEvent "Racing"
		local ev = player:GetAttribute("RaceEvent")
		check(checks, pre .. "_race_event_racing", ev == "Racing" and 1 or 0, 1, ev == "Racing")
		local released = car ~= nil and car.PrimaryPart ~= nil and car.PrimaryPart.Anchored == false
		check(checks, pre .. "_chassis_released", released and 1 or 0, 1, released)
		return car, run
	end
	local function touch(part)
		local ok = pcall(CarService.PadTouched, player, part)
		frames(0.6) -- spawnCar seats the avatar within ~0.5 s
		return ok
	end
	local function unchangedRacing(car, run)
		return racing()
			and call(CarService.GetCar, player) == car
			and car ~= nil
			and car.Parent ~= nil
			and call(CarService.GetRun, player) == run
			and #ourCars() == 1
			and activeRuns() == 1
	end
	local function stillOnFoot()
		return not racing()
			and player:GetAttribute("AutoRacing") == false
			and call(CarService.GetCar, player) == nil
			and #ourCars() == 0
			and activeRuns() == 0
	end

	local function body()
		-- 1. Join: on foot at the walk spawn, no car (the character spawned somewhere else first)
		local c1 = newChar(Vector3.new(20, 2, 20))
		local okJoin = pcall(CarService.OnCharacter, player, c1.Model)
		check(checks, "join_no_error", okJoin and 1 or 0, 1, okJoin)
		frames(0.5)
		checkOnFoot("join", c1)
		frames(1)
		check(checks, "join_stays_on_foot", stillOnFoot() and 1 or 0, 1, stillOnFoot())

		-- 2. A pad touch by the living, visible, non-racing avatar starts auto racing
		local okT = touch(c1.Model:FindFirstChild("Left Leg"))
		check(checks, "pad_touch_no_error", okT and 1 or 0, 1, okT)
		local car1, run1 = checkRacing("pad_start", c1, nil)

		-- 3. Touching again while racing (avatar part or the car itself) changes nothing
		touch(c1.Model:FindFirstChild("Right Leg"))
		touch(car1 and car1.PrimaryPart or nil)
		local same = unchangedRacing(car1, run1)
		check(checks, "pad_touch_while_racing_ignored", same and 1 or 0, 1, same)

		-- 4. Stop: avatar at the walk spawn in the area, visible and walking; Unbanked back to 0
		local tStop0 = os.clock()
		local okS, rS = pcall(CarService.SetAutoRace, player, false)
		local tStop1 = os.clock()
		check(checks, "stop_returns_false", okS and rS == false and 1 or 0, 1, okS and rS == false)
		RunService.Heartbeat:Wait()
		checkOnFoot("stop", c1)
		local ubStop = player:GetAttribute("Unbanked")
		check(checks, "stop_unbanked_attribute_zero", num(ubStop), 0, ubStop == 0)

		-- 5. START_COOLDOWN after a stop: a touch right away and one just before the end do nothing...
		touch(c1.Model:FindFirstChild("Left Leg"))
		check(checks, "pad_cooldown_refuses_at_once", stillOnFoot() and 1 or 0, 1, stillOnFoot())
		local lateAt = tStop0 + SPAWN_START_COOLDOWN - 0.5
		while os.clock() < lateAt do
			RunService.Heartbeat:Wait()
		end
		local okLate = pcall(CarService.PadTouched, player, c1.Model:FindFirstChild("Left Leg"))
		RunService.Heartbeat:Wait()
		local refusedLate = okLate and stillOnFoot()
		check(checks, "pad_cooldown_refuses_before_end", refusedLate and 1 or 0, 1, refusedLate)
		frames(0.6)
		check(checks, "pad_cooldown_still_on_foot", stillOnFoot() and 1 or 0, 1, stillOnFoot())
		-- ...and once it is over a touch starts again
		while os.clock() < tStop1 + SPAWN_START_COOLDOWN + 0.25 do
			RunService.Heartbeat:Wait()
		end
		touch(c1.Model:FindFirstChild("Left Leg"))
		local car2 = checkRacing("pad_after_cooldown", c1, car1)

		-- 6. Not the avatar: a loose part, a car part and nil do nothing (after a stop and a full cooldown)
		pcall(CarService.SetAutoRace, player, false)
		local tStop2 = os.clock()
		while os.clock() < tStop2 + SPAWN_START_COOLDOWN + 0.25 do
			RunService.Heartbeat:Wait()
		end
		local loose = Instance.new("Part")
		loose.Name = "CarTestSpawnLoosePart"
		loose.Anchored = true
		loose.CFrame = pad and pad.CFrame + Vector3.new(0, 2, 0) or walkCF
		loose.Parent = Workspace
		local strayCar = CarFactory.build(CarConfig)
		strayCar.Name = "CarTestSpawnStrayCar"
		strayCar:PivotTo(CFrame.new(walkCF.Position + Vector3.new(0, 50, 0)))
		for _, d in strayCar:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		strayCar.Parent = Workspace
		baseline[strayCar] = true
		local okL = pcall(CarService.PadTouched, player, loose)
		local okC = pcall(CarService.PadTouched, player, strayCar.PrimaryPart)
		local okN = pcall(CarService.PadTouched, player, nil)
		frames(0.6)
		loose:Destroy()
		strayCar:Destroy()
		check(checks, "pad_foreign_parts_ignored", stillOnFoot() and 1 or 0, 1, okL and okC and okN and stillOnFoot())
		check(
			checks,
			"pad_old_car_gone",
			car2 ~= nil and car2.Parent == nil and 1 or 0,
			1,
			car2 ~= nil and car2.Parent == nil
		)

		-- 7. A dead avatar's touch does nothing; the respawn is on foot at the walk spawn
		c1.Humanoid.Health = 0
		frames(0.3)
		touch(c1.Model:FindFirstChild("Left Leg"))
		check(checks, "pad_dead_avatar_ignored", stillOnFoot() and 1 or 0, 1, stillOnFoot())
		local c2 = newChar(Vector3.new(-15, 2, 25))
		local okR = pcall(CarService.OnCharacter, player, c2.Model)
		check(checks, "respawn_on_foot_no_error", okR and 1 or 0, 1, okR)
		frames(0.5)
		checkOnFoot("respawn_on_foot", c2)

		-- 8. Death while racing: the car goes with the avatar, and the respawn is on foot, not racing
		touch(c2.Model:FindFirstChild("Left Leg"))
		local car3 = checkRacing("pre_death", c2, car2)
		c2.Humanoid.Health = 0
		frames(0.5)
		local gone = call(CarService.GetCar, player) == nil
			and #ourCars() == 0
			and activeRuns() == 0
			and (car3 == nil or car3.Parent == nil)
		check(checks, "death_car_removed", gone and 1 or 0, 1, gone)
		local c3 = newChar(Vector3.new(25, 2, -15))
		local okR2 = pcall(CarService.OnCharacter, player, c3.Model)
		check(checks, "respawn_after_race_no_error", okR2 and 1 or 0, 1, okR2)
		frames(0.5)
		checkOnFoot("respawn_after_race", c3)
		frames(1)
		check(checks, "respawn_after_race_stays_on_foot", stillOnFoot() and 1 or 0, 1, stillOnFoot())
	end

	local ok, err = pcall(body)
	check(checks, "spawn_area_no_error", ok and 1 or 0, 1, ok)
	if not ok then
		metrics.error = tostring(err)
	end
	RaceService.NewRun = origNewRun
	pcall(CarService.SetAutoRace, player, false)
	for _, r in runs do
		pcall(function()
			r:Destroy()
		end)
	end
	for _, m in ourCars() do
		m:Destroy()
	end
	for _, m in chars do
		m:Destroy()
	end
	player:Destroy()
	return result("spawn_area", checks, metrics)
end

-- Banked winnings (contract: docs/SPAWN_AND_ROLLS_SPEC.md, section 3).
-- BRIEF (owner, 2026-10-01): "Stopping pays the winnings of the checkpoints cleared in this run (banked)." Owner's
-- answer: stop payout = "bank, pay on stop".
-- NPC mode: a win adds MoneyService.Quote(player, pad) to run.Unbanked (mirrored in the player attribute
-- Unbanked) and pays NOTHING at the finish; run:CashOut() pays the bank once and zeroes it; run:Destroy() cashes
-- out. Losses clearing the bank are checked in `npc` (lose and win-then-lose runs); non-NPC runs paying pads
-- directly in `race`.
local BANK_ORIGIN = Vector3.new(0, 0, 40000)
local BANK_ATTR_WAIT = 0.2 -- s after a Result before the mirrored attribute is read

local function call0(fn, ...)
	local ok, v = pcall(fn, ...)
	if ok then
		return v
	end
	return nil
end

function Scenarios.bank()
	local checks = {}
	local metrics = {}
	local RaceConfig = sharedModule("RaceConfig")
	local GachaService = serverModule("GachaService")
	local api = {
		RaceService = serverModule("RaceService"),
		Money = serverModule("MoneyService"),
		PlayerData = serverModule("PlayerData"),
	}
	local apiOk = RaceConfig ~= nil
		and GachaService ~= nil
		and api.RaceService ~= nil
		and api.Money ~= nil
		and api.PlayerData ~= nil
		and type(api.Money.Quote) == "function"
		and type(api.Money.Award) == "function"
		and type(api.Money.Setup) == "function"
		and type(api.RaceService.BuildRoute) == "function"
		and type(api.RaceService.NewRun) == "function"
		and type(GachaService.MoneyMulti) == "function"
		and type(TrackBuilder.CashFor) == "function"
	check(checks, "bank_api_exists", apiOk and 1 or 0, 1, apiOk)
	local specs = type(TrackRegistry.Chain) == "function" and TrackRegistry.Chain() or {}
	check(checks, "bank_chain_has_two_tracks", #specs, 2, #specs >= 2)
	if not apiOk or #specs < 2 then
		return result("bank", checks, metrics)
	end

	local models, cleanup = {}, {}
	local racer = nil
	local okBody, err = pcall(function()
		local entries
		entries, models = buildNpcChain(BANK_ORIGIN, "CarTestBankTrack", specs)
		local pad1 = entries[1].Model:FindFirstChild("WinPad", true)
		local n1, n2 = specs[1].Number, specs[2].Number
		local C1, C2 = TrackBuilder.CashFor(n1), TrackBuilder.CashFor(n2)

		-- MoneyService.Quote: floor(Cash * MoneyMulti), no cooldown, pays nothing
		local pq = newTestPlayer(cleanup, "CarTestBankQuote")
		api.Money.Setup(pq)
		GachaService.Setup(pq)
		local q1 = call0(api.Money.Quote, pq, pad1)
		local q2 = call0(api.Money.Quote, pq, pad1)
		check(checks, "quote_is_pad_cash", num(q1), C1, q1 == C1)
		local noCooldown = q2 == q1 and pq.leaderstats.Money.Value == 0
		check(checks, "quote_no_cooldown_pays_nothing", pq.leaderstats.Money.Value, 0, noCooldown)
		local plain = Instance.new("Part")
		plain.Name = "CarTestBankNotAPad"
		plain:SetAttribute("Cash", 500)
		table.insert(cleanup, plain)
		local qBad = call0(api.Money.Quote, pq, plain)
		check(checks, "quote_untagged_part_zero", num(qBad), 0, qBad == 0)
		local pm = newTestPlayer(cleanup, "CarTestBankQuoteMulti")
		api.Money.Setup(pm)
		GachaService.Setup(pm)
		for _, c in GACHA_SEED do
			GachaService.Grant(pm, c.Id)
		end
		GachaService.Allocate(pm, "Money")
		GachaService.Allocate(pm, "Money")
		local multi = GachaService.MoneyMulti(pm)
		local qm = call0(api.Money.Quote, pm, pad1)
		local wantM = math.floor(C1 * multi)
		check(checks, "quote_uses_money_multi", num(qm), wantM, multi > 1 and qm == wantM)

		-- A winning NPC-mode run (fast player, slow NPCs) on both tracks
		local route = api.RaceService.BuildRoute(entries)
		local wps = route.Path.WorldWaypoints
		local totalLen = 0
		for i = 2, #wps do
			totalLen += (wps[i] - wps[i - 1]).Magnitude
		end
		local startCF = entries[1].Model.Start.CFrame + Vector3.new(0, CarConfig.RestHeight, 0)
		local r =
			newNpcRacer(api, route, startCF, "Bank", RaceConfig.HALF_STAT, { [n1] = NPC_SLOW, [n2] = NPC_SLOW }, nil)
		racer = r
		check(checks, "bank_run_started", r.ok and 1 or 0, 1, r.ok)
		if not r.ok then
			metrics.error = r.err
			return
		end
		local run, player, money = r.Run, r.Player, r.Money
		local function attr()
			return player:GetAttribute("Unbanked")
		end
		check(checks, "bank_starts_empty", num(run.Unbanked), 0, run.Unbanked == 0)
		check(checks, "bank_attribute_starts_zero", num(attr()), 0, attr() == 0)
		local hasCashOut = type(run.CashOut) == "function"
		check(checks, "bank_run_has_cash_out", hasCashOut and 1 or 0, 1, hasCashOut)
		local cap = totalLen / (0.5 * RaceConfig.SpeedFor(RaceConfig.HALF_STAT)) + 30
		local function driveUntil(track, seconds)
			return frames(seconds, function()
				if npcFind(r, "Result", track) then
					return "stop"
				end
			end)
		end

		-- Win Track 1: banked, not paid
		driveUntil(n1, cap)
		local res1 = npcFind(r, "Result", n1)
		local win1 = res1 ~= nil and res1.Event.Result == "Win"
		check(checks, "bank_win_track1", win1 and 1 or 0, 1, win1)
		if not win1 then
			return
		end
		local e1 = res1.Event
		check(checks, "bank_result_banked_field", num(e1.Banked), C1, e1.Banked == C1)
		check(checks, "bank_result_unbanked_field", num(e1.Unbanked), C1, e1.Unbanked == C1)
		check(checks, "bank_result_has_no_paid_field", e1.Paid == nil and 0 or 1, 0, e1.Paid == nil)
		check(checks, "bank_win_not_paid_at_finish", res1.Money, 0, res1.Money == 0)
		frames(BANK_ATTR_WAIT)
		check(checks, "bank_run_unbanked_after_win", num(run.Unbanked), C1, run.Unbanked == C1)
		check(checks, "bank_attribute_after_win", num(attr()), C1, attr() == C1)
		check(checks, "bank_money_unchanged_after_win", money.Value, 0, money.Value == 0)
		check(checks, "bank_banked_total_after_win", num(run.BankedTotal), C1, run.BankedTotal == C1)
		local unpaid = run.Payouts == 0 and run.PaidTotal == 0
		check(checks, "bank_no_payout_before_cash_out", num(run.Payouts), 0, unpaid)

		-- CashOut pays exactly the bank, once, and zeroes it
		if hasCashOut then
			local okC, amount = pcall(run.CashOut, run)
			check(checks, "cash_out_returns_bank", okC and num(amount) or -1, C1, okC and amount == C1)
			check(checks, "cash_out_pays_money", money.Value, C1, money.Value == C1)
			check(checks, "cash_out_zeroes_bank", num(run.Unbanked), 0, run.Unbanked == 0)
			RunService.Heartbeat:Wait()
			check(checks, "cash_out_zeroes_attribute", num(attr()), 0, attr() == 0)
			local counted = run.Payouts == 1 and run.PaidTotal == C1 and run.BankedTotal == C1
			check(checks, "cash_out_counted", num(run.PaidTotal), C1, counted)
			local okC2, again = pcall(run.CashOut, run)
			local once = okC2 and again == 0 and money.Value == C1 and run.Payouts == 1 and run.PaidTotal == C1
			check(checks, "cash_out_twice_pays_once", money.Value, C1, once)
		end

		-- Win Track 2: the bank fills again from 0, money untouched at the finish
		local money2 = money.Value
		driveUntil(n2, cap)
		local res2 = npcFind(r, "Result", n2)
		local win2 = res2 ~= nil and res2.Event.Result == "Win"
		check(checks, "bank_win_track2", win2 and 1 or 0, 1, win2)
		if not win2 then
			return
		end
		local e2 = res2.Event
		check(checks, "bank_track2_banked", num(e2.Banked), C2, e2.Banked == C2)
		check(checks, "bank_track2_unbanked_after_cash_out", num(e2.Unbanked), C2, e2.Unbanked == C2)
		check(checks, "bank_track2_not_paid_at_finish", res2.Money, money2, res2.Money == money2)
		frames(BANK_ATTR_WAIT)
		check(checks, "bank_attribute_after_track2", num(attr()), C2, attr() == C2)
		check(checks, "bank_banked_total_sums_wins", num(run.BankedTotal), C1 + C2, run.BankedTotal == C1 + C2)

		-- Destroy cashes out (Stop, death and leaving all go through it), and only once
		local before = money.Value
		local payoutsBefore = run.Payouts
		local okD = pcall(function()
			run:Destroy()
		end)
		check(checks, "destroy_no_error", okD and 1 or 0, 1, okD)
		check(checks, "destroy_cashes_out", money.Value - before, C2, money.Value - before == C2)
		check(checks, "destroy_zeroes_bank", num(run.Unbanked), 0, run.Unbanked == 0)
		check(checks, "destroy_zeroes_attribute", num(attr()), 0, attr() == 0)
		local counted = run.Payouts == payoutsBefore + 1
		check(checks, "destroy_payout_counted", num(run.Payouts), payoutsBefore + 1, counted)
		local afterOnce = money.Value
		pcall(function()
			run:Destroy()
		end)
		if hasCashOut then
			pcall(run.CashOut, run)
		end
		check(checks, "destroy_twice_pays_once", money.Value, afterOnce, money.Value == afterOnce)
		check(checks, "bank_total_paid", money.Value, C1 + C2, money.Value == C1 + C2)
	end)
	if racer then
		if racer.Run then
			pcall(function()
				racer.Run:Destroy()
			end)
		end
		racer.Car:Destroy()
		racer.Player:Destroy()
	end
	for _, m in models do
		m:Destroy()
	end
	for _, inst in cleanup do
		inst:Destroy()
	end
	check(checks, "bank_no_error", okBody and 1 or 0, 1, okBody)
	if not okBody then
		metrics.error = tostring(err)
	end
	return result("bank", checks, metrics)
end

-- Chat admin commands (contract: docs/ADMIN_COMMANDS_SPEC.md).
-- BRIEF (user, 2026-10-01): "chat admin commands so the owner can set stats while testing instead of using the
-- Studio command bar. Server-only; non-admins can never change anything."
-- Every stand-in is a Folder with a UserId attribute. AllowStudio is forced to false for the admin / non-admin
-- checks (admins are made by listing their UserId in AdminConfig.UserIds) and always restored, as are UserIds and
-- AdminService.RunOf. The "all" target is never used here: it would touch the real players of the play session.
local ADMIN_ORIGIN = Vector3.new(0, 0, -40000)
local ADMIN_UID = 914200001 -- listed in AdminConfig.UserIds for the duration of the test
local ADMIN_STRANGER_UID = 914200002 -- never listed: not an admin
local ADMIN_COMMANDS = { "help", "money", "addmoney", "speed", "addspeed", "give", "equip", "roll", "wipe", "tp" }
local ADMIN_MAX_MONEY = 1e15
local ADMIN_TP_SETTLE = 1 -- s driven on Track 1 before the jump (a race is in progress in NPC mode)
local ADMIN_TP_DRIVE = 4 -- s driven after the jump
local ADMIN_TP_SLACK = 3 -- studs beyond RaceService.START_AHEAD the car may be from the track's start waypoint
local ADMIN_LANE_TOLERANCE = 2 -- studs sideways from the lane path at the jump
local ADMIN_EVENT_WAIT = 1 -- s for the NPC Start event after the jump

local function adminSnap(p)
	local s = {}
	local ls = p:FindFirstChild("leaderstats")
	local money = ls and ls:FindFirstChild("Money")
	local speed = ls and ls:FindFirstChild("Speed")
	s.Money = money and money.Value or "none"
	s.Speed = speed and speed.Value or "none"
	local names = {}
	local data = p:FindFirstChild("GachaData")
	if data then
		for _, c in data:GetChildren() do
			table.insert(names, c.Name)
		end
	end
	table.sort(names)
	s.Cars = (data and "" or "nofolder:") .. table.concat(names, ",")
	for _, a in { "EquippedCar", "Rolls", "StatPoints" } do
		s[a] = tostring(p:GetAttribute(a))
	end
	for name, v in p:GetAttributes() do
		if string.sub(name, 1, 6) == "Alloc_" then
			s[name] = tostring(v)
		end
	end
	return s
end

-- true if both snapshots are identical, else false and the first differing key
local function adminSame(a, b)
	for k, v in a do
		if b[k] ~= v then
			return false, k
		end
	end
	for k, v in b do
		if a[k] ~= v then
			return false, k
		end
	end
	return true, nil
end

function Scenarios.admin()
	local checks = {}
	local metrics = {}
	local AdminService = serverModule("AdminService")
	local AdminConfig = serverModule("AdminConfig")
	local RaceService = serverModule("RaceService")
	local Money = serverModule("MoneyService")
	local PlayerData = serverModule("PlayerData")
	local RaceConfig = sharedModule("RaceConfig")
	local CarCatalog, GachaConfig, GachaService = gachaModules()
	local apiOk = AdminService ~= nil
		and AdminConfig ~= nil
		and type(AdminService.IsAdmin) == "function"
		and type(AdminService.Run) == "function"
		and type(AdminService.Parse) == "function"
		and type(AdminService.ParseNumber) == "function"
		and type(AdminService.Commands) == "table"
		and type(AdminService.Start) == "function"
		and type(AdminService.AllowStudio) == "boolean"
		and type(AdminService.RunOf) == "function"
		and type(AdminConfig.UserIds) == "table"
		and type(AdminConfig.MAX_ROLLS) == "number"
	check(checks, "admin_api_exists", apiOk and 1 or 0, 1, apiOk)
	local depsOk = RaceService ~= nil
		and Money ~= nil
		and PlayerData ~= nil
		and RaceConfig ~= nil
		and CarCatalog ~= nil
		and GachaConfig ~= nil
		and GachaService ~= nil
		and type(RaceService.BuildRoute) == "function"
		and type(RaceService.NewRun) == "function"
		and type(GachaService.Setup) == "function"
		and type(GachaService.Allocate) == "function"
		and type(GachaConfig.EarnedPoints) == "function"
		and type(CarCatalog.Rollable) == "function"
		and type(RaceConfig.MAX_STAT) == "number"
	check(checks, "admin_dependencies_exist", depsOk and 1 or 0, 1, depsOk)
	if not (apiOk and depsOk) then
		return result("admin", checks, metrics)
	end

	-- AdminConfig values from the spec
	check(checks, "admin_max_rolls", AdminConfig.MAX_ROLLS, 100, AdminConfig.MAX_ROLLS == 100)
	local gmr = AdminConfig.GROUP_MIN_RANK
	check(checks, "admin_group_min_rank", type(gmr) == "number" and gmr or -1, 255, gmr == 255)
	local ais = AdminConfig.ALLOW_IN_STUDIO
	check(
		checks,
		"admin_allow_studio_default",
		AdminService.AllowStudio == ais and 1 or 0,
		1,
		type(ais) == "boolean" and AdminService.AllowStudio == ais
	)
	local cmdsOk, missingCmd = true, nil
	for _, name in ADMIN_COMMANDS do
		local c = AdminService.Commands[name]
		if type(c) ~= "table" or type(c.Usage) ~= "string" or c.Usage == "" or type(c.Help) ~= "string" then
			cmdsOk, missingCmd = false, name
		end
	end
	check(checks, "admin_commands_table", cmdsOk and 1 or 0, 1, cmdsOk)
	if missingCmd then
		metrics.missingCommand = missingCmd
	end

	-- Start() wiring (Main calls it in the play session the harness runs in)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local msgRemote = remotes and remotes:WaitForChild("AdminMessage", 5)
	local remoteOk = msgRemote ~= nil and msgRemote:IsA("RemoteEvent")
	check(checks, "admin_message_remote", remoteOk and 1 or 0, 1, remoteOk)
	local TextChatService = game:GetService("TextChatService")
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local folder = TextChatService:FindFirstChild("AdminCommands")
		local chatOk = folder ~= nil
		if chatOk then
			for _, name in ADMIN_COMMANDS do
				local found = false
				for _, c in folder:GetChildren() do
					if
						c:IsA("TextChatCommand")
						and c.PrimaryAlias == "/" .. name
						and c.AutocompleteVisible == false
					then
						found = true
					end
				end
				chatOk = chatOk and found
			end
		end
		check(checks, "admin_text_chat_commands", chatOk and 1 or 0, 1, chatOk)
	end

	-- ParseNumber
	local numCases = {
		{ "1500", 1500 },
		{ "1,500", 1500 },
		{ "1.5k", 1500 },
		{ "1.5K", 1500 },
		{ "2m", 2e6 },
		{ "2M", 2e6 },
		{ "3b", 3e9 },
		{ "3B", 3e9 },
		{ "1t", 1e12 },
		{ "1T", 1e12 },
		{ "1e6", 1e6 },
		{ "0", 0 },
		{ "12.5", 12.5 },
		{ "-5", -5 },
	}
	local numBad = 0
	for _, c in numCases do
		local ok, v = pcall(AdminService.ParseNumber, c[1])
		if not ok or not nearly(v, c[2]) then
			numBad += 1
			metrics["parseNumber_" .. c[1]] = ok and tostring(v) or "error"
		end
	end
	check(checks, "admin_parse_number_formats", numBad, 0, numBad == 0)
	local junk = { "", " ", "abc", "nan", "NaN", "inf", "-inf", "1e999", "k", "1kk", "1.2.3", "1x", "$5", "--5" }
	local junkBad = 0
	for _, s in junk do
		local ok, v = pcall(AdminService.ParseNumber, s)
		if not ok or v ~= nil then
			junkBad += 1
			metrics["parseNumberJunk_" .. s] = ok and tostring(v) or "error"
		end
	end
	local okNil, vNil = pcall(AdminService.ParseNumber, nil)
	if not okNil or vNil ~= nil then
		junkBad += 1
	end
	check(checks, "admin_parse_number_junk_nil", junkBad, 0, junkBad == 0)

	-- Parse
	local okP, pName, pArgs = pcall(AdminService.Parse, "/Money 5 me")
	local parseOk = okP
		and pName == "money"
		and type(pArgs) == "table"
		and #pArgs == 2
		and pArgs[1] == "5"
		and pArgs[2] == "me"
	check(checks, "admin_parse_command", parseOk and 1 or 0, 1, parseOk)
	local okS, sName, sArgs = pcall(AdminService.Parse, "/money   5   me")
	local spacesOk = okS and sName == "money" and type(sArgs) == "table" and #sArgs == 2 and sArgs[2] == "me"
	check(checks, "admin_parse_extra_spaces", spacesOk and 1 or 0, 1, spacesOk)
	local okH, hName, hArgs = pcall(AdminService.Parse, "/help")
	local helpOk = okH and hName == "help" and type(hArgs) == "table" and #hArgs == 0
	check(checks, "admin_parse_no_args", helpOk and 1 or 0, 1, helpOk)
	local notCmd = 0
	for _, text in { "hello", "money 5", "", 5 } do
		local ok, n = pcall(AdminService.Parse, text)
		if not ok or n ~= nil then
			notCmd += 1
		end
	end
	local okPn, nPn = pcall(AdminService.Parse, nil)
	if not okPn or nPn ~= nil then
		notCmd += 1
	end
	check(checks, "admin_parse_non_command_nil", notCmd, 0, notCmd == 0)

	local cleanup = {}
	local runs = {}
	local models = {}
	local savedAllow = AdminService.AllowStudio
	local savedRunOf = AdminService.RunOf
	local addedUid = false
	local errors, badReturns = 0, 0

	-- Calls AdminService.Run; never lets it error out of the test. Returns ok (true only for a boolean true), message.
	local function admin(sender, text)
		local okCall, ok, msg = pcall(AdminService.Run, sender, text)
		if not okCall then
			errors += 1
			metrics["error_" .. tostring(text):sub(1, 40)] = tostring(ok)
			return false, nil
		end
		if type(ok) ~= "boolean" or type(msg) ~= "string" then
			badReturns += 1
		end
		return ok == true, msg
	end

	local okBody, err = pcall(function()
		AdminService.AllowStudio = false
		if table.find(AdminConfig.UserIds, ADMIN_UID) == nil then
			table.insert(AdminConfig.UserIds, ADMIN_UID)
			addedUid = true
		end

		local function standIn(name, uid)
			local p = newTestPlayer(cleanup, name)
			if uid then
				p:SetAttribute("UserId", uid)
			end
			Money.Setup(p)
			PlayerData.Setup(p)
			GachaService.Setup(p)
			return p
		end

		-- IsAdmin
		local function isAdmin(p)
			local ok, v = pcall(AdminService.IsAdmin, p)
			return ok and v == true, ok and type(v) == "boolean"
		end
		local stranger = standIn("CarTestAdminStranger", ADMIN_STRANGER_UID)
		local listed = standIn("CarTestAdminSender", ADMIN_UID)
		local noUid = standIn("CarTestAdminNoUid", nil)
		local sA, sBool = isAdmin(stranger)
		check(checks, "admin_unknown_user_not_admin", sA and 1 or 0, 0, sBool and not sA)
		local nA = isAdmin(noUid)
		check(checks, "admin_no_userid_not_admin_outside_studio_rule", nA and 1 or 0, 0, not nA)
		local lA = isAdmin(listed)
		check(checks, "admin_listed_user_is_admin", lA and 1 or 0, 1, lA)
		local okNilA, nilA = pcall(AdminService.IsAdmin, nil)
		check(checks, "admin_nil_not_admin", (okNilA and nilA == false) and 1 or 0, 1, okNilA and nilA == false)
		local gone = Instance.new("Folder")
		gone.Name = "CarTestAdminGone"
		gone:SetAttribute("UserId", ADMIN_UID)
		gone.Parent = Workspace
		gone:Destroy()
		local gA = isAdmin(gone)
		check(checks, "admin_destroyed_not_admin", gA and 1 or 0, 0, not gA)
		AdminService.AllowStudio = true
		local studioA = isAdmin(stranger)
		local wantStudio = RunService:IsStudio()
		check(checks, "admin_allow_studio_rule", studioA and 1 or 0, wantStudio and 1 or 0, studioA == wantStudio)
		AdminService.AllowStudio = false
		-- removing the UserId removes the rights
		local uidAt = table.find(AdminConfig.UserIds, ADMIN_UID)
		if uidAt and addedUid then
			table.remove(AdminConfig.UserIds, uidAt)
			local unlisted = isAdmin(listed)
			check(checks, "admin_unlisted_user_not_admin", unlisted and 1 or 0, 0, not unlisted)
			table.insert(AdminConfig.UserIds, ADMIN_UID)
		end
		local okDef, defRun = pcall(AdminService.RunOf, listed)
		check(checks, "admin_run_of_stand_in_nil", (okDef and defRun == nil) and 1 or 0, 1, okDef and defRun == nil)

		-- Non-admin: every command fails and nothing changes
		local rollable = CarCatalog.Rollable()
		local ids = {}
		for _, c in rollable do
			table.insert(ids, c.Id)
		end
		table.sort(ids)
		local idA, idB = ids[1], ids[2]
		GachaService.Grant(stranger, idA)
		stranger.leaderstats.Money.Value = 777
		stranger.leaderstats.Speed.Value = 12.5
		local nonAdminCmds = {
			"/help",
			"/money 5",
			"/money 5 me",
			"/addmoney 5",
			"/addmoney -100",
			"/speed 5",
			"/addspeed 5",
			"/give " .. tostring(idB),
			"/give all",
			"/equip " .. tostring(idA),
			"/roll 1",
			"/roll 5",
			"/wipe",
			"/wipe me",
			"/tp 2",
		}
		local before = adminSnap(stranger)
		local acceptedN, changedKey = 0, nil
		for _, text in nonAdminCmds do
			local ok = admin(stranger, text)
			if ok then
				acceptedN += 1
				metrics["nonAdminAccepted_" .. text] = true
			end
			local same, key = adminSame(before, adminSnap(stranger))
			if not same and changedKey == nil then
				changedKey = text .. " -> " .. tostring(key)
			end
		end
		check(checks, "admin_non_admin_all_false", acceptedN, 0, acceptedN == 0)
		check(checks, "admin_non_admin_changes_nothing", changedKey and 1 or 0, 0, changedKey == nil)
		if changedKey then
			metrics.nonAdminChanged = changedKey
		end

		-- Admin: every command
		local p = listed
		local ls = p.leaderstats
		local function rejected(name, text)
			local b = adminSnap(p)
			local ok = admin(p, text)
			local same, key = adminSame(b, adminSnap(p))
			check(checks, name, ok and 1 or 0, 0, not ok and same)
			if not same then
				metrics[name .. "_changed"] = key
			end
		end
		local function accepted(name, text, value, limit, cond)
			local ok = admin(p, text)
			check(checks, name, value(), limit, ok and cond())
		end

		accepted(
			"admin_money_set",
			"/money 1500",
			function()
				return ls.Money.Value
			end,
			1500,
			function()
				return ls.Money.Value == 1500
			end
		)
		accepted(
			"admin_money_suffix",
			"/money 2.5k",
			function()
				return ls.Money.Value
			end,
			2500,
			function()
				return ls.Money.Value == 2500
			end
		)
		accepted(
			"admin_money_commas_me",
			"/money 1,234 me",
			function()
				return ls.Money.Value
			end,
			1234,
			function()
				return ls.Money.Value == 1234
			end
		)
		accepted(
			"admin_money_floor",
			"/money 12.9",
			function()
				return ls.Money.Value
			end,
			12,
			function()
				return ls.Money.Value == 12
			end
		)
		accepted(
			"admin_money_case_insensitive",
			"/MONEY 42",
			function()
				return ls.Money.Value
			end,
			42,
			function()
				return ls.Money.Value == 42
			end
		)
		accepted(
			"admin_money_zero",
			"/money 0",
			function()
				return ls.Money.Value
			end,
			0,
			function()
				return ls.Money.Value == 0
			end
		)
		ls.Money.Value = 321
		rejected("admin_money_negative_false", "/money -5")
		rejected("admin_money_junk_false", "/money abc")
		rejected("admin_money_nan_false", "/money nan")
		rejected("admin_money_missing_false", "/money")
		rejected("admin_money_unknown_target_false", "/money 5 zzqx_nobody_here")
		do
			local ok = admin(p, "/money 1e16")
			local v = ls.Money.Value
			local fine = v <= ADMIN_MAX_MONEY and ((ok and v == ADMIN_MAX_MONEY) or (not ok and v == 321))
			check(checks, "admin_money_cap", v, ADMIN_MAX_MONEY, fine)
		end

		ls.Money.Value = 100
		accepted(
			"admin_addmoney",
			"/addmoney 50",
			function()
				return ls.Money.Value
			end,
			150,
			function()
				return ls.Money.Value == 150
			end
		)
		accepted(
			"admin_addmoney_suffix",
			"/addmoney 1k me",
			function()
				return ls.Money.Value
			end,
			1150,
			function()
				return ls.Money.Value == 1150
			end
		)
		accepted(
			"admin_addmoney_negative_clamped",
			"/addmoney -100000",
			function()
				return ls.Money.Value
			end,
			0,
			function()
				return ls.Money.Value == 0
			end
		)
		ls.Money.Value = 55
		rejected("admin_addmoney_junk_false", "/addmoney 1kk")
		rejected("admin_addmoney_inf_false", "/addmoney inf")

		local MAX_STAT = RaceConfig.MAX_STAT
		accepted(
			"admin_speed_set_3_decimals",
			"/speed 12.3454",
			function()
				return ls.Speed.Value
			end,
			12.345,
			function()
				return math.abs(ls.Speed.Value - 12.345) <= 1e-6
			end
		)
		accepted(
			"admin_speed_clamp_max",
			"/speed 1e12",
			function()
				return ls.Speed.Value
			end,
			MAX_STAT,
			function()
				return ls.Speed.Value == MAX_STAT
			end
		)
		accepted(
			"admin_speed_clamp_zero",
			"/speed -3",
			function()
				return ls.Speed.Value
			end,
			0,
			function()
				return ls.Speed.Value == 0
			end
		)
		accepted(
			"admin_speed_set",
			"/speed 10 me",
			function()
				return ls.Speed.Value
			end,
			10,
			function()
				return ls.Speed.Value == 10
			end
		)
		accepted(
			"admin_addspeed",
			"/addspeed 2.5",
			function()
				return ls.Speed.Value
			end,
			12.5,
			function()
				return math.abs(ls.Speed.Value - 12.5) <= 1e-6
			end
		)
		accepted(
			"admin_addspeed_3_decimals",
			"/addspeed 0.0014",
			function()
				return ls.Speed.Value
			end,
			12.501,
			function()
				local v = ls.Speed.Value
				return math.abs(v * 1000 - math.round(v * 1000)) <= 1e-6 and math.abs(v - 12.501) <= 1e-6
			end
		)
		accepted(
			"admin_addspeed_clamp_max",
			"/addspeed 2e9",
			function()
				return ls.Speed.Value
			end,
			MAX_STAT,
			function()
				return ls.Speed.Value == MAX_STAT
			end
		)
		accepted(
			"admin_addspeed_clamp_zero",
			"/addspeed -5e9",
			function()
				return ls.Speed.Value
			end,
			0,
			function()
				return ls.Speed.Value == 0
			end
		)
		ls.Speed.Value = 7
		rejected("admin_speed_junk_false", "/speed fast")
		rejected("admin_speed_inf_false", "/speed inf")
		rejected("admin_addspeed_missing_false", "/addspeed")
		rejected("admin_speed_unknown_target_false", "/speed 5 zzqx_nobody_here")

		-- give / equip
		local function allocSum()
			local s = 0
			for _, stat in GachaConfig.STATS or {} do
				local v = p:GetAttribute("Alloc_" .. stat)
				s += type(v) == "number" and v or 0
			end
			return s
		end
		local function ownsId(id)
			local data = p:FindFirstChild("GachaData")
			return data ~= nil and data:FindFirstChild(id) ~= nil
		end
		local function ownedCount()
			local data = p:FindFirstChild("GachaData")
			return data and #data:GetChildren() or 0
		end
		local function pointsOk()
			return p:GetAttribute("StatPoints") == GachaConfig.EarnedPoints(ownedCount()) - allocSum()
		end
		rejected("admin_equip_unowned_false", "/equip " .. tostring(idB))
		rejected("admin_equip_unknown_false", "/equip bogus_car_zzqx")
		accepted(
			"admin_give_car",
			"/give " .. tostring(idA),
			function()
				return ownedCount()
			end,
			1,
			function()
				return ownsId(idA) and ownedCount() == 1 and pointsOk()
			end
		)
		rejected("admin_give_starter_false", "/give starter")
		rejected("admin_give_unknown_false", "/give bogus_car_zzqx")
		rejected("admin_give_missing_false", "/give")
		rejected("admin_give_unknown_target_false", "/give " .. tostring(idB) .. " zzqx_nobody_here")
		accepted(
			"admin_equip_owned",
			"/equip " .. tostring(idA),
			function()
				return p:GetAttribute("EquippedCar") == idA and 1 or 0
			end,
			1,
			function()
				return p:GetAttribute("EquippedCar") == idA
			end
		)

		-- roll
		local function rolls()
			local v = p:GetAttribute("Rolls")
			return type(v) == "number" and v or -1
		end
		local r0 = rolls()
		accepted("admin_roll_5", "/roll 5", rolls, r0 + 5, function()
			return rolls() == r0 + 5
		end)
		accepted("admin_roll_default_1", "/roll", rolls, r0 + 6, function()
			return rolls() == r0 + 6
		end)
		rejected("admin_roll_0_false", "/roll 0")
		rejected("admin_roll_above_max_false", "/roll " .. tostring(AdminConfig.MAX_ROLLS + 1))
		rejected("admin_roll_negative_false", "/roll -2")
		rejected("admin_roll_junk_false", "/roll lots")

		-- give all
		accepted("admin_give_all", "/give all", ownedCount, #ids, function()
			for _, id in ids do
				if not ownsId(id) then
					return false
				end
			end
			return ownedCount() == #ids and pointsOk()
		end)
		local allocated = GachaService.Allocate(p, (GachaConfig.STATS or {})[1])
		check(checks, "admin_give_all_points_spendable", allocated and 1 or 0, 1, allocated == true and pointsOk())

		-- wipe
		ls.Money.Value = 999
		ls.Speed.Value = 50
		accepted(
			"admin_wipe",
			"/wipe",
			function()
				return ls.Money.Value + ls.Speed.Value + ownedCount() + allocSum() + math.max(rolls(), 0)
			end,
			0,
			function()
				return ls.Money.Value == 0
					and ls.Speed.Value == 0
					and ownedCount() == 0
					and allocSum() == 0
					and rolls() == 0
					and p:GetAttribute("EquippedCar") == CarCatalog.STARTER_ID
					and p:GetAttribute("StatPoints") == 0
			end
		)
		ls.Money.Value = 5
		rejected("admin_wipe_unknown_target_false", "/wipe zzqx_nobody_here")

		-- help / unknown / not a command
		local okHelp, helpMsg = admin(p, "/help")
		local listsAll = type(helpMsg) == "string"
		if listsAll then
			for _, name in ADMIN_COMMANDS do
				if not string.find(string.lower(helpMsg), "/" .. name, 1, true) then
					listsAll = false
				end
			end
		end
		check(checks, "admin_help_true", okHelp and 1 or 0, 1, okHelp)
		check(checks, "admin_help_lists_commands", listsAll and 1 or 0, 1, listsAll)
		rejected("admin_unknown_command_false", "/fly 100")
		rejected("admin_not_a_command_false", "money 5")

		-- Run never errors and refuses garbage
		local garbage = {
			{ p, nil },
			{ p, 42 },
			{ p, "" },
			{ p, "/" },
			{ p, "/money" },
			{ p, string.rep("a", 10000) },
			{ p, "/" .. string.rep("a", 10000) },
			{ p, "/money 5 " .. string.rep("x", 5000) },
			{ nil, "/money 5" },
			{ gone, "/money 5" },
		}
		local garbageAccepted = 0
		local b = adminSnap(p)
		for _, g in garbage do
			if admin(g[1], g[2]) then
				garbageAccepted += 1
			end
		end
		local sameG = adminSame(b, adminSnap(p))
		check(checks, "admin_garbage_false", garbageAccepted, 0, garbageAccepted == 0 and sameG)

		-- /tp and run:JumpToTrack on a real run of the chain (with and without NPC)
		local specs = type(TrackRegistry.Chain) == "function" and TrackRegistry.Chain() or {}
		check(checks, "admin_chain_has_two_tracks", #specs, 2, #specs >= 2)
		if #specs < 2 then
			return
		end
		local entries
		entries, models = buildNpcChain(ADMIN_ORIGIN, "CarTestAdminTrack", specs)
		local okRoute, route = pcall(RaceService.BuildRoute, entries)
		local routeOk = okRoute
			and type(route) == "table"
			and type(route.Path) == "table"
			and type(route.Path.WorldWaypoints) == "table"
			and type(route.Tracks) == "table"
			and #route.Tracks == 2
			and type(route.Tracks[2].StartIndex) == "number"
		check(checks, "admin_route_built", routeOk and 1 or 0, 1, routeOk)
		if not routeOk then
			return
		end
		local wps = route.Path.WorldWaypoints
		local n = #wps
		local t2 = route.Tracks[2]
		local s2, n1, n2 = t2.StartIndex, route.Tracks[1].Number, t2.Number
		local C2 = TrackBuilder.CashFor(n2)
		local startCF = entries[1].Model.Start.CFrame + Vector3.new(0, CarConfig.RestHeight, 0)
		local strict = PhysicsTargets.lap.MinUpYStrict
		local maxDev = (PhysicsTargets.race or {}).MaxPathDeviation

		local function tpRun(npcMode)
			local pre = npcMode and "admin_tp_npc_" or "admin_tp_"
			local car = CarFactory.build(CarConfig)
			car.Name = "CarTestAdminCar"
			car:PivotTo(startCF)
			car.Parent = Workspace
			table.insert(cleanup, car)
			local racer = standIn("CarTestAdminRacer", ADMIN_UID)
			local outsider = standIn("CarTestAdminOutsider", ADMIN_STRANGER_UID)
			local money = racer.leaderstats.Money
			local events, clock0 = {}, os.clock()
			local options = {
				Npc = npcMode,
				NpcSpeeds = { [n1] = NPC_SLOW, [n2] = NPC_SLOW },
				LoseScreenSeconds = NPC_LOSE_SCREEN,
				OnRaceEvent = function(ev)
					if type(ev) == "table" then
						table.insert(events, { Event = ev, T = os.clock() - clock0 })
					end
				end,
			}
			local okRun, run = pcall(RaceService.NewRun, car, route, racer, options)
			local started = okRun and type(run) == "table"
			check(checks, pre .. "run_started", started and 1 or 0, 1, started)
			if not started then
				metrics[pre .. "error"] = tostring(run)
				return
			end
			table.insert(runs, run)
			local hasJump = type(run.JumpToTrack) == "function"
			check(checks, pre .. "run_has_jump_to_track", hasJump and 1 or 0, 1, hasJump)
			AdminService.RunOf = function(who)
				if who == racer or who == outsider then
					return run
				end
				return nil
			end
			local chassis = car.PrimaryPart
			local driver = run.Driver
			frames(ADMIN_TP_SETTLE)
			if npcMode then
				local s1 = false
				for _, rec in events do
					s1 = s1 or (rec.Event.Type == "Start" and rec.Event.Track == n1)
				end
				check(checks, pre .. "track1_race_in_progress", s1 and 1 or 0, 1, s1)
			end

			-- Bad jumps and refused /tp: all in one frame (no yield), so the car can not have moved
			local pos0, idx0, paid0, ev0, money0 = chassis.Position, driver.Index, run.PaidTotal, #events, money.Value
			local bank0 = run.Unbanked
			local badJumps = 0
			if hasJump then
				for _, bad in { 0, -1, 99, n2 + 0.5, 0 / 0, math.huge, "x" } do
					local okC, res = pcall(run.JumpToTrack, run, bad)
					if not okC or res ~= false then
						badJumps += 1
					end
				end
				local okC, res = pcall(run.JumpToTrack, run, nil)
				if not okC or res ~= false then
					badJumps += 1
				end
			end
			check(checks, pre .. "jump_bad_number_false", badJumps, 0, hasJump and badJumps == 0)
			local tpAccepted = 0
			for _, text in { "/tp 99", "/tp 0", "/tp abc", "/tp", "/tp " .. n2 .. " zzqx_nobody_here" } do
				if admin(racer, text) then
					tpAccepted += 1
				end
			end
			check(checks, pre .. "tp_bad_args_false", tpAccepted, 0, tpAccepted == 0)
			local outsiderOk = admin(outsider, "/tp " .. n2)
			check(checks, pre .. "tp_non_admin_false", outsiderOk and 1 or 0, 0, not outsiderOk)
			local moved = (chassis.Position - pos0).Magnitude
			local unchanged = moved <= 0.01
				and driver.Index == idx0
				and run.PaidTotal == paid0
				and #events == ev0
				and money.Value == money0
			check(checks, pre .. "refused_jumps_move_nothing", moved, 0.01, unchanged)

			-- The jump
			local off0, flips0 = run.OffTrackSeconds or 0, run.FlipRecoveries or 0
			local results0 = type(run.Results) == "table" and #run.Results or 0
			local tJump = os.clock() - clock0
			local okTp = admin(racer, "/tp " .. n2)
			local idxNow = driver.Index
			check(checks, pre .. "command_true", okTp and 1 or 0, 1, okTp)
			check(checks, pre .. "driver_index_at_start", idxNow, s2, idxNow >= s2 and idxNow <= s2 + 3)
			RunService.Heartbeat:Wait()
			local cf = chassis.CFrame
			local d = hdist(cf.Position, wps[s2])
			local near = RaceService.START_AHEAD + ADMIN_TP_SLACK
			check(checks, pre .. "car_at_track_start", d, near, d <= near)
			local dir = flatV(wps[s2 + 1] - wps[s2])
			local lat = dir.Magnitude > 1e-6 and flatV(cf.Position - wps[s2]):Dot(dir.Unit:Cross(Vector3.yAxis)) or 99
			check(
				checks,
				pre .. "car_in_lane",
				math.abs(lat),
				ADMIN_LANE_TOLERANCE,
				math.abs(lat) <= ADMIN_LANE_TOLERANCE
			)
			check(checks, pre .. "car_upright", cf.UpVector.Y, 0.98, cf.UpVector.Y >= 0.98)
			local facing = dir.Magnitude > 1e-6 and flatV(cf.LookVector):Dot(dir.Unit) or -1
			check(checks, pre .. "car_faces_path", facing, 0.9, facing >= 0.9)
			check(checks, pre .. "not_finished", run.Finished == true and 1 or 0, 0, run.Finished ~= true)
			local paidNow = run.PaidTotal == paid0 and money.Value == money0
			check(checks, pre .. "jump_pays_nothing", run.PaidTotal - paid0, 0, paidNow)
			if npcMode then
				-- SPAWN_AND_ROLLS_SPEC section 3: admin /tp does not change the bank
				local bankSame = type(bank0) == "number" and run.Unbanked == bank0
				check(checks, pre .. "jump_bank_unchanged", num(run.Unbanked), num(bank0), bankSame)
			end

			-- Drive on from Track 2's start
			local idx, minUp, dev = s2, 1, 0
			frames(ADMIN_TP_DRIVE, function()
				local pos = chassis.Position
				local bestD = math.huge
				for i = idx, math.min(idx + 25, n) do
					local dd = (wps[i] - pos).Magnitude
					if dd < bestD then
						bestD, idx = dd, i
					end
				end
				if not (run.Physics and run.Physics.LoopAssist) then
					minUp = math.min(minUp, chassis.CFrame.UpVector.Y)
				end
				dev = math.max(dev, (nearestOnPolyline(wps, pos, math.max(idx - 3, 1), math.min(idx + 3, n - 1))))
			end)
			local runMin = type(run.MinUpY) == "number" and run.MinUpY or -1
			local worst = math.min(minUp, runMin)
			check(checks, pre .. "never_tilted", worst, strict, type(strict) == "number" and worst >= strict)
			check(checks, pre .. "sticks_to_path", dev, maxDev or -1, type(maxDev) == "number" and dev <= maxDev)
			local offDelta = (run.OffTrackSeconds or 0) - off0
			check(checks, pre .. "not_off_track", offDelta, 0, offDelta == 0)
			local flipDelta = (run.FlipRecoveries or 0) - flips0
			check(checks, pre .. "no_flip_recoveries", flipDelta, 0, flipDelta == 0)
			local progressed = driver.Index - s2
			check(checks, pre .. "drives_on", progressed, 3, progressed >= 3)
			local passedPad2 = driver.Index >= (t2.PadIndex or math.huge)
			local delta = run.PaidTotal - paid0
			local moneyOk = (delta == 0 or (delta == C2 and passedPad2)) and money.Value - money0 == delta
			check(checks, pre .. "earlier_pads_never_paid", delta, 0, moneyOk)
			if npcMode then
				local resultTrack1, resultAfter, start2 = false, false, false
				for _, rec in events do
					local ev = rec.Event
					if ev.Type == "Result" and ev.Track == n1 then
						resultTrack1 = true
					end
					if ev.Type == "Result" and rec.T >= tJump then
						resultAfter = true
					end
					if
						ev.Type == "Start"
						and ev.Track == n2
						and rec.T >= tJump
						and rec.T <= tJump + ADMIN_EVENT_WAIT
					then
						start2 = true
					end
				end
				local results1 = type(run.Results) == "table" and #run.Results or -1
				check(
					checks,
					pre .. "race_dropped_no_result",
					resultTrack1 and 1 or 0,
					0,
					not resultTrack1 and not resultAfter and results1 == results0
				)
				check(checks, pre .. "start_event_for_target", start2 and 1 or 0, 1, start2)
				check(checks, pre .. "race_track_is_target", num(run.RaceTrack), n2, run.RaceTrack == n2)
			end

			-- /tp with no run
			AdminService.RunOf = function()
				return nil
			end
			local noRun = admin(racer, "/tp " .. n2)
			check(checks, pre .. "no_run_false", noRun and 1 or 0, 0, not noRun)
			AdminService.RunOf = savedRunOf
		end
		tpRun(false)
		tpRun(true)
	end)

	-- restore everything
	AdminService.AllowStudio = savedAllow
	AdminService.RunOf = savedRunOf
	if addedUid then
		local i = table.find(AdminConfig.UserIds, ADMIN_UID)
		if i then
			table.remove(AdminConfig.UserIds, i)
		end
	end
	for _, run in runs do
		pcall(function()
			run:Destroy()
		end)
	end
	for _, inst in cleanup do
		inst:Destroy()
	end
	for _, m in models do
		m:Destroy()
	end

	check(checks, "admin_run_never_errors", errors, 0, errors == 0)
	check(checks, "admin_run_returns_bool_and_message", badReturns, 0, badReturns == 0)
	check(checks, "admin_no_error", okBody and 1 or 0, 1, okBody)
	if not okBody then
		metrics.error = tostring(err)
	end
	return result("admin", checks, metrics)
end

-- Roll animation, server side (docs/ROLL_ANIMATION_CONTRACT.md, sections "Shared/RollAnimConfig" and "Server"; owner
-- decisions in docs/ROLL_ANIMATION_SPEC.md). BRIEF (owner, 2026-10-02): "A roll is emphasized when the car is
-- undiscovered AND its odds are rarer than the player's 5th-rarest discovered car (while the player has discovered
-- fewer than 5 cars, any undiscovered car counts). The rarity name alone never triggers it. Every emphasized roll is
-- announced in global chat." Every number below is copied from the contract, never from an implementation.
local ROLL_ANIM_TIMES = { POP = 0.15, SPIN = 0.8, LAND = 0.15, EXIT = 0.15, SWITCH = 0.3 }
local ROLL_ANIM_HOLD = {
	Common = 0.3,
	Uncommon = 0.3,
	Rare = 0.4,
	Epic = 0.6,
	Legendary = 1.5,
	Mythic = 2.5,
	Secret = 4,
}
local ROLL_ANIM_LAYOUT = {
	REEL_CARS = 6,
	LAND_POP = 1.15,
	COMPACT_WIDTH = 0.12, -- owner decision 6: smaller compact roll
	COMPACT_MIN = 100,
	COMPACT_MAX = 230,
	COMPACT_HEIGHT = 66,
	COMPACT_GAP = 8,
	PANEL_TOP = 138, -- 60 + COMPACT_GAP + COMPACT_HEIGHT + 4
	ENLARGED_FACTOR = 3,
	ENLARGED_WIDTH = 0.6,
}
local ROLL_ANIM_ENLARGED_MAX = Vector2.new(780, 336)
local ROLL_ANIM_REELS = 4000 -- seeded reels for the filler odds (5 fillers each)
local ROLL_ANIM_REEL_SEED = 20261002
local ROLL_ANIM_NEAR_MISS_SEED = 4402
local ROLL_ANIM_SERVICE_SEED = 9917
local ROLL_ANIM_SERVICE_ROLLS = 60
local ROLL_ANIM_TIMING_TOL = 0.05 -- s: a task.wait is never shorter than asked; slack for clock granularity only
local ROLL_ANIM_LATE = 1.5 -- s: how late a timed auto-roll may come under test load

-- Contract: Duration = POP + SPIN + LAND + Hold(rarity) + EXIT, + 2 x SWITCH when emphasized.
local function rollAnimDuration(rarity, emphasized)
	local t = ROLL_ANIM_TIMES
	local d = t.POP + t.SPIN + t.LAND + (ROLL_ANIM_HOLD[rarity] or ROLL_ANIM_HOLD.Common) + t.EXIT
	if emphasized then
		d += 2 * t.SWITCH
	end
	return d
end

-- A Random stand-in returning the given NextNumber values in order (the last one repeats).
local function seqRoller(values)
	local i = 0
	return {
		NextNumber = function(_self)
			i += 1
			return values[math.min(i, #values)]
		end,
	}
end

function Scenarios.roll_anim()
	local checks, metrics = {}, {}
	local CarCatalog, GachaConfig, GachaService = gachaModules()
	local RollAnimConfig = sharedModule("RollAnimConfig")
	local baseOk = CarCatalog ~= nil
		and GachaConfig ~= nil
		and GachaService ~= nil
		and type(GachaConfig.Roll) == "function"
		and type(GachaConfig.ROLL_INTERVAL) == "number"
	check(checks, "roll_anim_gacha_modules", baseOk and 1 or 0, 1, baseOk)
	if not baseOk then
		return result("roll_anim", checks, metrics)
	end
	local interval = GachaConfig.ROLL_INTERVAL
	local validIds, catchAllId = {}, nil
	for _, c in GACHA_SEED do
		validIds[c.Id] = true
		if c.Chance == nil then
			catchAllId = c.Id
		end
	end

	-- RollAnimConfig: constants and pure functions
	local cfgOk = RollAnimConfig ~= nil
		and type(RollAnimConfig.Hold) == "function"
		and type(RollAnimConfig.Duration) == "function"
		and type(RollAnimConfig.ExtraPause) == "function"
		and type(RollAnimConfig.Reel) == "function"
	check(checks, "roll_anim_config_api_exists", cfgOk and 1 or 0, 1, cfgOk)
	if cfgOk then
		local constBad = {}
		for name, want in ROLL_ANIM_TIMES do
			if not nearly(RollAnimConfig[name], want) then
				table.insert(constBad, name)
			end
		end
		for name, want in ROLL_ANIM_LAYOUT do
			if not nearly(RollAnimConfig[name], want) then
				table.insert(constBad, name)
			end
		end
		local enlargedMax = RollAnimConfig.ENLARGED_MAX
		if
			typeof(enlargedMax) ~= "Vector2"
			or not nearly(enlargedMax.X, ROLL_ANIM_ENLARGED_MAX.X)
			or not nearly(enlargedMax.Y, ROLL_ANIM_ENLARGED_MAX.Y)
		then
			table.insert(constBad, "ENLARGED_MAX")
		end
		check(checks, "roll_anim_constants", #constBad, table.concat(constBad, ","), #constBad == 0)
		local holdTableBad = type(RollAnimConfig.HOLD) ~= "table" and 1 or 0
		local holdFnBad = 0
		for rarity, want in ROLL_ANIM_HOLD do
			if holdTableBad == 0 and not nearly(RollAnimConfig.HOLD[rarity], want) then
				holdTableBad += 1
			end
			local ok, got = pcall(RollAnimConfig.Hold, rarity)
			if not ok or not nearly(got, want) then
				holdFnBad += 1
			end
		end
		check(checks, "roll_anim_hold_table", holdTableBad, 0, holdTableBad == 0)
		check(checks, "roll_anim_hold_per_rarity", holdFnBad, 0, holdFnBad == 0)
		local unknownBad = 0
		for _, bad in { "Bogus", "", "common", 5 } do
			local ok, got = pcall(RollAnimConfig.Hold, bad)
			if not ok or not nearly(got, ROLL_ANIM_HOLD.Common) then
				unknownBad += 1
			end
		end
		local okNil, gotNil = pcall(RollAnimConfig.Hold, nil)
		if not okNil or not nearly(gotNil, ROLL_ANIM_HOLD.Common) then
			unknownBad += 1
		end
		check(checks, "roll_anim_hold_unknown_is_common", unknownBad, 0, unknownBad == 0)

		local durBad, pauseBad = 0, 0
		local rarities = table.clone(GACHA_RARITY_ORDER)
		table.insert(rarities, "Bogus")
		for _, rarity in rarities do
			for _, emphasized in { false, true } do
				local want = rollAnimDuration(rarity, emphasized)
				local okD, gotD = pcall(RollAnimConfig.Duration, rarity, emphasized)
				if not okD or type(gotD) ~= "number" or math.abs(gotD - want) > 1e-6 then
					durBad += 1
				end
				local okP, gotP = pcall(RollAnimConfig.ExtraPause, rarity, emphasized)
				if not okP or type(gotP) ~= "number" or math.abs(gotP - math.max(0, want - interval)) > 1e-6 then
					pauseBad += 1
				end
			end
		end
		check(checks, "roll_anim_duration_formula", durBad, 0, durBad == 0)
		check(checks, "roll_anim_extra_pause_formula", pauseBad, 0, pauseBad == 0)
		local okC, commonD = pcall(RollAnimConfig.Duration, "Common", false)
		commonD = okC and type(commonD) == "number" and commonD or math.huge
		check(
			checks,
			"roll_anim_common_fits_interval",
			commonD == math.huge and -1 or commonD,
			interval,
			commonD <= interval
		)
		local okS, secretP = pcall(RollAnimConfig.ExtraPause, "Secret", true)
		local wantS = rollAnimDuration("Secret", true) - interval
		check(
			checks,
			"roll_anim_secret_needs_pause",
			okS and type(secretP) == "number" and secretP or -1,
			wantS,
			okS and type(secretP) == "number" and wantS > 0 and math.abs(secretP - wantS) <= 1e-6
		)

		-- Reel(rng, resultId): REEL_CARS ids, the last is the result, the rest are real luck-1 rolls
		local n = ROLL_ANIM_LAYOUT.REEL_CARS
		local function reel(rng, id)
			local ok, r = pcall(RollAnimConfig.Reel, rng, id)
			if ok and type(r) == "table" then
				return r
			end
			return nil
		end
		local lenBad, lastBad, idBad = 0, 0, 0
		for k, c in GACHA_SEED do
			for s = 1, 20 do
				local r = reel(Random.new(1000 * k + s), c.Id)
				if not r or #r ~= n then
					lenBad += 1
				end
				if not r or r[#r] ~= c.Id then
					lastBad += 1
				end
				if r then
					for _, id in r do
						if not validIds[id] then
							idBad += 1
						end
					end
				end
			end
		end
		check(checks, "reel_length", lenBad, 0, lenBad == 0)
		check(checks, "reel_last_is_result", lastBad, 0, lastBad == 0)
		check(checks, "reel_all_rollable", idBad, 0, idBad == 0)
		local detBad, indepBad = 0, 0
		for s = 1, 200 do
			local a = reel(Random.new(s), "void_racer")
			local b = reel(Random.new(s), "void_racer")
			local c = reel(Random.new(s), catchAllId)
			if not (a and b and #a == #b) then
				detBad += 1
			else
				for i = 1, #a do
					if a[i] ~= b[i] then
						detBad += 1
						break
					end
				end
			end
			-- no planting: the fillers do not depend on what was rolled
			if not (a and c and #a == n and #c == n) then
				indepBad += 1
			else
				for i = 1, n - 1 do
					if a[i] ~= c[i] then
						indepBad += 1
						break
					end
				end
			end
		end
		check(checks, "reel_deterministic_per_seed", detBad, 0, detBad == 0)
		check(checks, "reel_fillers_independent_of_result", indepBad, 0, indepBad == 0)

		-- Filler odds over many seeded reels match the real luck-1 odds
		local counts, fillers, reelErr = {}, 0, 0
		local rng = Random.new(ROLL_ANIM_REEL_SEED)
		for i = 1, ROLL_ANIM_REELS do
			local resultId = GACHA_SEED[(i - 1) % #GACHA_SEED + 1].Id
			local r = reel(rng, resultId)
			if not r or #r ~= n then
				reelErr += 1
			else
				for j = 1, n - 1 do
					counts[r[j]] = (counts[r[j]] or 0) + 1
					fillers += 1
				end
			end
		end
		check(checks, "reel_odds_sample_ok", reelErr, 0, reelErr == 0 and fillers == ROLL_ANIM_REELS * (n - 1))
		local expected = gachaExpected(1)
		for _, c in GACHA_SEED do
			local p = expected[c.Id]
			local mean = fillers * p
			local tol = GACHA_SIGMAS * math.sqrt(fillers * p * (1 - p)) + GACHA_FLOOR
			local got = counts[c.Id] or 0
			metrics["reel_" .. c.Id] = got
			check(
				checks,
				"reel_odds_" .. c.Id,
				got,
				string.format("%.1f +- %.1f", mean, tol),
				fillers > 0 and math.abs(got - mean) <= tol
			)
		end
		-- The slot right before a rare result is no likelier to hold a non-common (or a Rare+) car than the odds say
		local nm = Random.new(ROLL_ANIM_NEAR_MISS_SEED)
		local slots, nonCommon, rarePlus = 0, 0, 0
		for i = 1, ROLL_ANIM_REELS do
			local resultId = i % 2 == 0 and "void_racer" or "hover_car"
			local r = reel(nm, resultId)
			if r and #r == n then
				slots += 1
				local spec = CarCatalog.Get(r[n - 1])
				if spec and spec.Chance ~= nil then
					nonCommon += 1
					if spec.Chance >= 50 then
						rarePlus += 1
					end
				end
			end
		end
		local pNon = 1 - expected[catchAllId]
		local pRare = 0
		for _, c in GACHA_SEED do
			if c.Chance and c.Chance >= 50 then
				pRare += expected[c.Id]
			end
		end
		local meanNon = slots * pNon
		local tolNon = GACHA_SIGMAS * math.sqrt(slots * pNon * (1 - pNon)) + GACHA_FLOOR
		check(
			checks,
			"reel_slot_before_result_odds",
			nonCommon,
			string.format("%.1f +- %.1f", meanNon, tolNon),
			slots == ROLL_ANIM_REELS and math.abs(nonCommon - meanNon) <= tolNon
		)
		local maxRare = slots * pRare + GACHA_SIGMAS * math.sqrt(slots * pRare * (1 - pRare)) + GACHA_FLOOR
		check(
			checks,
			"reel_no_planted_rare_before_result",
			rarePlus,
			string.format("<= %.1f", maxRare),
			slots == ROLL_ANIM_REELS and rarePlus <= maxRare
		)
	end

	-- GachaConfig.IsEmphasized(id, ownedIds): ownedIds is an array of car ids owned BEFORE the roll
	local emphOk = type(GachaConfig.IsEmphasized) == "function"
	check(checks, "emphasized_api_exists", emphOk and 1 or 0, 1, emphOk)
	if emphOk then
		local function emph(id, owned)
			local ok, r = pcall(GachaConfig.IsEmphasized, id, owned)
			if ok then
				return r
			end
			return "error"
		end
		local function expectAll(name, cases)
			local bad = {}
			for _, case in cases do
				if emph(case[1], case[2]) ~= case[3] then
					table.insert(bad, tostring(case[1]))
				end
			end
			check(checks, name, #bad, table.concat(bad, ","), #bad == 0)
		end
		local allIds = {}
		for _, c in GACHA_SEED do
			table.insert(allIds, c.Id)
		end
		local rare5 = { "void_racer", "hover_car", "rocket_car", "street_racer", "go_kart" } -- 5th-rarest = 1 in 50
		local rare5w = { "void_racer", "hover_car", "rocket_car", "street_racer", "wooden_car" } -- 5th = 1 in 10
		local common5 = { "rusty_hatchback", "wooden_car", "go_kart", "street_racer", "rocket_car" } -- 5th = catch-all
		local six = { "void_racer", "hover_car", "rocket_car", "street_racer", "go_kart", "rusty_hatchback" }
		local newCases = {}
		for _, id in allIds do
			table.insert(newCases, { id, {}, true })
		end
		expectAll("emph_nothing_owned_any_new_true", newCases)
		local ownedCases = {}
		for _, id in allIds do
			table.insert(ownedCases, { id, { id }, false })
			table.insert(ownedCases, { id, table.clone(allIds), false })
		end
		expectAll("emph_owned_false", ownedCases)
		expectAll("emph_not_rollable_false", {
			{ "starter", {}, false },
			{ "no_such_car", {}, false },
			{ "", {}, false },
			{ nil, {}, false },
			{ 5, {}, false },
		})
		local four = { "void_racer", "hover_car", "rocket_car", "street_racer" }
		expectAll("emph_under_five_any_new_true", {
			{ "rusty_hatchback", four, true },
			{ "wooden_car", four, true },
			{ "go_kart", four, true },
		})
		expectAll("emph_only_distinct_rollable_owned_count", {
			{ "rusty_hatchback", { "void_racer", "hover_car", "rocket_car", "street_racer", "starter" }, true },
			{ "rusty_hatchback", { "void_racer", "hover_car", "rocket_car", "street_racer", "no_such_car" }, true },
			{ "wooden_car", { "void_racer", "void_racer", "hover_car", "rocket_car", "street_racer" }, true },
		})
		expectAll("emph_five_owned_catch_all_is_least_rare", {
			{ "hover_car", common5, true },
			{ "void_racer", common5, true },
		})
		expectAll("emph_not_rarer_than_fifth_false", {
			{ "wooden_car", rare5, false },
			{ "rusty_hatchback", rare5, false },
			{ "rusty_hatchback", rare5w, false },
		})
		expectAll("emph_rarer_than_fifth_true", {
			{ "go_kart", rare5w, true },
		})
		-- with 6 owned the 5th-rarest decides (1 in 50 here), not the least rare one
		expectAll("emph_uses_fifth_rarest_not_least", {
			{ "wooden_car", six, false },
		})
		local reversed = table.clone(rare5w)
		for i = 1, #reversed // 2 do
			reversed[i], reversed[#reversed + 1 - i] = reversed[#reversed + 1 - i], reversed[i]
		end
		expectAll("emph_owned_order_ignored", {
			{ "go_kart", reversed, true },
			{ "rusty_hatchback", reversed, false },
		})
		-- Rarity names never matter: relabel cars (restored afterwards) so two cars share a rarity name but only
		-- the one with the rarer odds passes, and a "Secret"-named common car never passes.
		local relabel = { rusty_hatchback = "Rare", go_kart = "Common", wooden_car = "Secret" }
		local saved = {}
		local okRel, errRel = pcall(function()
			for id, rarity in relabel do
				local spec = CarCatalog.Get(id)
				saved[id] = spec.Rarity
				spec.Rarity = rarity
			end
			expectAll("emph_rarity_names_ignored", {
				{ "go_kart", rare5w, true }, -- now labelled Common, still passes on odds
				{ "rusty_hatchback", rare5w, false }, -- now labelled Rare like the real go_kart, still fails
				{ "wooden_car", rare5, false }, -- labelled Secret, odds 1 in 10: fails
			})
		end)
		for id, rarity in saved do
			CarCatalog.Get(id).Rarity = rarity
		end
		if not okRel then
			check(checks, "emph_rarity_names_ignored", 0, tostring(errRel), false)
		end
	end

	local cleanup, handles, conns = {}, {}, {}
	local originalAnnounce = GachaService.Announce
	local okBody, err = pcall(function()
		-- Remotes (GachaService.Start is called by Main at boot)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local remotesBad = {}
		for _, name in { "RollResult", "RollAnnounce", "SetAutoRoll" } do
			local r = remotes and remotes:FindFirstChild(name)
			if not (r and r:IsA("RemoteEvent")) then
				table.insert(remotesBad, name)
			end
		end
		check(checks, "roll_anim_remotes_exist", #remotesBad, table.concat(remotesBad, ","), #remotesBad == 0)

		-- GachaService.Roll returns (id, isNew, turboMulti, emphasized); an emphasized roll calls
		-- GachaService.Announce(player, id, rolls) (which fires Remotes.RollAnnounce:FireAllClients). Fake players can
		-- not receive remotes, so the announcement is observed by swapping GachaService.Announce for a spy.
		local announceOk = type(originalAnnounce) == "function"
		check(checks, "announce_api_exists", announceOk and 1 or 0, 1, announceOk)
		local calls = {}
		GachaService.Announce = function(player, id, rolls)
			table.insert(calls, { player = player, id = id, rolls = rolls })
		end
		local secret = seqRoller({ 0 }) -- hits the rarest car first: void_racer
		local r1 = newTestPlayer(cleanup, "CarTestRollAnimP1")
		GachaService.Setup(r1)
		local packed = table.pack(pcall(GachaService.Roll, r1, secret))
		local okR1 = packed[1] == true
		check(checks, "service_roll_returns_four_values", okR1 and packed.n - 1 or -1, 4, okR1 and packed.n == 5)
		local first = okR1 and packed[2] == "void_racer" and packed[3] == true and packed[4] == 1 and packed[5] == true
		check(checks, "service_roll_new_secret_emphasized", first and 1 or 0, 1, first)
		local ann1 = #calls == 1
			and calls[1].player == r1
			and calls[1].id == "void_racer"
			and calls[1].rolls == 1
			and r1:GetAttribute("Rolls") == 1
		check(checks, "announce_on_emphasized_roll", #calls, 1, ann1)
		local okR2, id2, new2, _, emph2 = pcall(GachaService.Roll, r1, secret)
		local second = okR2 and id2 == "void_racer" and new2 == false and emph2 == false
		check(checks, "service_roll_owned_not_emphasized", second and 1 or 0, 1, second)
		check(checks, "announce_not_on_owned_roll", #calls, 1, #calls == 1)

		-- 5 rarer cars owned (5th-rarest 1 in 10): Go-Kart (1 in 50) is emphasized, the catch-all is not
		local r2 = newTestPlayer(cleanup, "CarTestRollAnimP2")
		GachaService.Setup(r2)
		for _, id in { "void_racer", "hover_car", "rocket_car", "street_racer", "wooden_car" } do
			GachaService.Grant(r2, id)
		end
		local before = #calls
		local okK, idK, newK, _, emphK = pcall(GachaService.Roll, r2, seqRoller({ 0.99, 0.99, 0.99, 0.99, 0 }))
		local kart = okK and idK == "go_kart" and newK == true and emphK == true
		check(checks, "service_roll_rarer_than_fifth_emphasized", kart and 1 or 0, 1, kart)
		local annK = #calls == before + 1
			and calls[#calls].player == r2
			and calls[#calls].id == "go_kart"
			and calls[#calls].rolls == r2:GetAttribute("Rolls")
		check(checks, "announce_rarer_than_fifth", #calls - before, 1, annK)
		before = #calls
		local okH, idH, newH, _, emphH = pcall(GachaService.Roll, r2, seqRoller({ 0.99 }))
		local hatch = okH and idH == catchAllId and newH == true and emphH == false
		check(checks, "service_roll_new_but_common_not_emphasized", hatch and 1 or 0, 1, hatch)
		check(checks, "announce_not_on_common_new_roll", #calls - before, 0, #calls == before)

		-- Seeded rolls: the flag always equals IsEmphasized(id, owned before the roll); one announce per flag
		if type(GachaConfig.IsEmphasized) == "function" then
			local r3 = newTestPlayer(cleanup, "CarTestRollAnimP3")
			GachaService.Setup(r3)
			before = #calls
			local rng = Random.new(ROLL_ANIM_SERVICE_SEED)
			local mismatch, flagged, rollErr = 0, 0, 0
			for _ = 1, ROLL_ANIM_SERVICE_ROLLS do
				local ownedBefore = {}
				for _, v in r3.GachaData:GetChildren() do
					table.insert(ownedBefore, v.Name)
				end
				local okS, id, _, _, e = pcall(GachaService.Roll, r3, rng)
				if not okS then
					rollErr += 1
				else
					local okE, want = pcall(GachaConfig.IsEmphasized, id, ownedBefore)
					if not okE or e ~= want or type(e) ~= "boolean" then
						mismatch += 1
					end
					if e == true then
						flagged += 1
					end
				end
			end
			metrics.serviceEmphasized = flagged
			check(checks, "service_roll_no_error", rollErr, 0, rollErr == 0)
			check(checks, "service_roll_emphasized_matches_config", mismatch, 0, rollErr == 0 and mismatch == 0)
			check(
				checks,
				"announce_count_matches_emphasized",
				#calls - before,
				flagged,
				flagged >= 1 and #calls - before == flagged
			)
		end
		GachaService.Announce = originalAnnounce

		-- AUTO toggle: AutoRoll attribute (true on join, not saved, Setup never turns it back on)
		local pt = newTestPlayer(cleanup, "CarTestRollAnimToggle")
		GachaService.Setup(pt)
		check(
			checks,
			"auto_roll_attribute_default_true",
			pt:GetAttribute("AutoRoll") == true and 1 or 0,
			1,
			pt:GetAttribute("AutoRoll") == true
		)
		pt:SetAttribute("AutoRoll", false)
		GachaService.Setup(pt)
		pcall(GachaService.Roll, pt, Random.new(1))
		check(
			checks,
			"setup_keeps_auto_roll_off",
			pt:GetAttribute("AutoRoll") == false and 1 or 0,
			1,
			pt:GetAttribute("AutoRoll") == false
		)
		local okSnap, snap = pcall(GachaService.Snapshot, pt)
		local notSaved = okSnap and type(snap) == "table" and snap.AutoRoll == nil
		check(checks, "auto_roll_not_saved", notSaved and 1 or 0, 1, notSaved)

		-- Remotes.SetAutoRoll handler: GachaService.RequestSetAutoRoll(player, value) is exactly what its
		-- OnServerEvent calls (rate limit like AllocateStat, booleans only). Returns true only if applied.
		local reqOk = type(GachaService.RequestSetAutoRoll) == "function"
		check(checks, "set_auto_roll_handler_exists", reqOk and 1 or 0, 1, reqOk)
		local cooldown = GachaService.REMOTE_COOLDOWN
		local cdOk = type(cooldown) == "number" and cooldown > 0 and cooldown <= 1
		check(checks, "set_auto_roll_cooldown_range", cdOk and cooldown or -1, "(0, 1]", cdOk)
		if reqOk and cdOk then
			local pr = newTestPlayer(cleanup, "CarTestRollAnimRequest")
			GachaService.Setup(pr)
			local function req(v)
				local ok, r = pcall(GachaService.RequestSetAutoRoll, pr, v)
				return ok and r == true
			end
			local a = req(false)
			check(checks, "set_auto_roll_accepts_bool", a and 1 or 0, 1, a and pr:GetAttribute("AutoRoll") == false)
			local b = req(true)
			check(checks, "set_auto_roll_rate_limited", b and 1 or 0, 0, not b and pr:GetAttribute("AutoRoll") == false)
			local nonBool = 0
			for _, bad in { "true", 1, 0, {}, "false" } do
				task.wait(cooldown + 0.05)
				if req(bad) or pr:GetAttribute("AutoRoll") ~= false then
					nonBool += 1
				end
			end
			task.wait(cooldown + 0.05)
			if req(nil) or pr:GetAttribute("AutoRoll") ~= false then
				nonBool += 1
			end
			check(checks, "set_auto_roll_rejects_non_boolean", nonBool, 0, nonBool == 0)
			task.wait(cooldown + 0.05)
			local c = req(true)
			check(checks, "set_auto_roll_back_on", c and 1 or 0, 1, c and pr:GetAttribute("AutoRoll") == true)
		end

		-- Timed auto-roll (both run at once): A rolls a forced Secret through StartAutoRoll(player, roller) and must
		-- wait ROLL_INTERVAL + ExtraPause before the next roll; B starts with AutoRoll = false and must not roll
		-- until it is turned back on.
		local pa = newTestPlayer(cleanup, "CarTestRollAnimPause")
		GachaService.Setup(pa)
		local rollTimes = {}
		table.insert(
			conns,
			pa:GetAttributeChangedSignal("Rolls"):Connect(function()
				table.insert(rollTimes, os.clock())
			end)
		)
		local pb = newTestPlayer(cleanup, "CarTestRollAnimOff")
		GachaService.Setup(pb)
		pb:SetAttribute("AutoRoll", false)
		local t0 = os.clock()
		local okA, hA = pcall(GachaService.StartAutoRoll, pa, seqRoller({ 0 }))
		local okB, hB = pcall(GachaService.StartAutoRoll, pb)
		if okA then
			table.insert(handles, hA)
		end
		if okB then
			table.insert(handles, hB)
		end
		local offUntil = t0 + interval + ROLL_ANIM_LATE
		while os.clock() < offUntil do
			task.wait(0.1)
		end
		local offRolls = pb:GetAttribute("Rolls")
		check(checks, "auto_roll_off_no_rolls", offRolls or -1, 0, okB and offRolls == 0)
		pb:SetAttribute("AutoRoll", true)
		local onAt = os.clock()
		-- measured from the switch: only a roll made AFTER AutoRoll is back on counts as resuming
		local rollsAtOn = pb:GetAttribute("Rolls") or 0
		local wantGap = interval + math.max(0, rollAnimDuration("Secret", true) - interval)
		local deadline = math.max(onAt + interval + ROLL_ANIM_LATE, t0 + interval + wantGap + 2 * ROLL_ANIM_LATE)
		local resumedAt = nil
		while os.clock() < deadline do
			if not resumedAt and (pb:GetAttribute("Rolls") or 0) > rollsAtOn then
				resumedAt = os.clock()
			end
			if resumedAt and #rollTimes >= 2 then
				break
			end
			task.wait(0.05)
		end
		local resumeIn = resumedAt and resumedAt - onAt or -1
		metrics.autoRollResumeSeconds = round(resumeIn)
		check(
			checks,
			"auto_roll_on_resumes",
			resumeIn,
			string.format("<= %.2f", interval + ROLL_ANIM_LATE),
			offRolls == 0 and resumedAt ~= nil and resumeIn <= interval + ROLL_ANIM_LATE
		)
		local riggedOk = okA and owns(pa, "void_racer")
		check(checks, "auto_roll_uses_given_roller", riggedOk and 1 or 0, 1, riggedOk)
		local gap = #rollTimes >= 2 and rollTimes[2] - rollTimes[1] or -1
		metrics.autoRollPauseGap = round(gap)
		check(
			checks,
			"auto_roll_pause_after_long_roll",
			gap,
			string.format(">= %.2f", wantGap),
			riggedOk and #rollTimes >= 2 and gap >= wantGap - ROLL_ANIM_TIMING_TOL
		)
		check(
			checks,
			"auto_roll_pause_not_too_long",
			gap,
			string.format("<= %.2f", wantGap + ROLL_ANIM_LATE),
			riggedOk and #rollTimes >= 2 and gap <= wantGap + ROLL_ANIM_LATE
		)
	end)
	GachaService.Announce = originalAnnounce
	for _, h in handles do
		if type(h) == "table" and type(h.Stop) == "function" then
			pcall(h.Stop, h)
		end
	end
	for _, c in conns do
		c:Disconnect()
	end
	if not okBody then
		check(checks, "roll_anim_service_no_error", 0, tostring(err), false)
	end
	for _, inst in cleanup do
		inst:Destroy()
	end
	return result("roll_anim", checks, metrics)
end

-- Upgrade tree, PHASE 1: the pure rules in Shared/UpgradeTree over the data in Shared/UpgradeConfig
-- (docs/UPGRADE_TREE_SPEC.md, owner-confirmed; prices: docs/UPGRADE_TREE_DESIGN.md "Prices"). No server, no Instances,
-- no UI. Every number below is the owner's: never loosen one. Every UpgradeTree call is pcall-guarded, so a missing
-- or erroring function FAILS its check and never crashes the harness.
local UPGRADE_BRANCH_ORDER = { "money", "luck", "rollspeed", "turbo", "speed", "walkspeed" }
local UPGRADE_BRANCH_TIERS = { money = 5, luck = 5, rollspeed = 5, turbo = 4, speed = 5, walkspeed = 5 }
local UPGRADE_BRANCH_NAMES = {
	money = "Money",
	luck = "Luck",
	rollspeed = "Roll Speed",
	turbo = "Turbo",
	speed = "Speed",
	walkspeed = "Walkspeed",
}
local UPGRADE_BRANCH_WEIGHTS = { money = 1, luck = 1.2, rollspeed = 1.5, turbo = 2, speed = 1, walkspeed = 0.5 }
local UPGRADE_BONUS = {
	money = { 0.10, 0.10, 0.15, 0.15, 0.20 },
	luck = { 0.10, 0.15, 0.20, 0.25, 0.30 },
	rollspeed = { 0.10, 0.10, 0.10, 0.10, 0.10 },
	speed = { 0.10, 0.10, 0.15, 0.15, 0.20 },
}
local UPGRADE_PRICES = {
	money = { 150, 330, 730, 1600, 3500 },
	luck = { 180, 400, 870, 1900, 4200 },
	rollspeed = { 230, 500, 1100, 2400, 5300 },
	speed = { 150, 330, 730, 1600, 3500 },
	walkspeed = { 75, 170, 360, 800, 1800 },
	turbo = { 660, 3200, 15000, 34000 },
}
local UPGRADE_TURBO = {
	{ Multi = 10, Every = 15 },
	{ Multi = 50, Every = 25 },
	{ Multi = 100, Every = 40 },
	{ Multi = 1000, Every = 100 },
}
local UPGRADE_WALKSPEED = { 18, 20, 23, 26, 30 }
local UPGRADE_ROLL_INTERVALS = { 2.727, 2.5, 2.308, 2.143, 2.0 }
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

local function hexDistance(q1, r1, q2, r2)
	local dq, dr = q1 - q2, r1 - r2
	return (math.abs(dq) + math.abs(dr) + math.abs(dq + dr)) / 2
end

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in v do
		t[k] = deepCopy(x)
	end
	return t
end

local function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, x in a do
		if not deepEqual(x, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function idSet(ids)
	local s = {}
	for _, id in ids do
		s[id] = true
	end
	return s
end

local function tierIds(branch, n)
	local ids = {}
	for t = 1, n do
		table.insert(ids, branch .. "_" .. t)
	end
	return ids
end

function Scenarios.upgrades()
	local checks = {}
	local metrics = {}
	local UpgradeTree = sharedModule("UpgradeTree")
	local UpgradeConfig = sharedModule("UpgradeConfig")
	local FN_NAMES = {
		"Tiles",
		"Get",
		"Price",
		"NiceRound",
		"RequiredTrack",
		"CanBuy",
		"BuyableCount",
		"Bonuses",
		"RollInterval",
		"Turbo",
		"WalkSpeed",
	}
	local apiOk = UpgradeTree ~= nil and UpgradeConfig ~= nil and type(UpgradeConfig.Branches) == "table"
	if apiOk then
		for _, fname in FN_NAMES do
			if type(UpgradeTree[fname]) ~= "function" then
				apiOk = false
			end
		end
	end
	check(checks, "upgrades_api_exists", apiOk and 1 or 0, 1, apiOk)
	if not apiOk then
		return result("upgrades", checks, metrics)
	end

	local function flag(name, ok, limit)
		check(checks, name, ok and 1 or 0, limit or 1, ok == true)
	end
	-- pcall wrapper: returns callOk, r1, r2. The first errors are kept in metrics for the report.
	local errorCount = 0
	local function call(fname, ...)
		local res = table.pack(pcall(UpgradeTree[fname], ...))
		if not res[1] then
			errorCount += 1
			if errorCount <= 3 then
				metrics["error_" .. errorCount] = fname .. ": " .. tostring(res[2])
			end
			return false, nil, nil
		end
		return true, res[2], res[3]
	end
	local function near(a, b, tol)
		return type(a) == "number" and a == a and math.abs(a - b) <= (tol or 1e-6)
	end
	local function state(ownedIds, money, best, trackCount)
		return { Owned = idSet(ownedIds), Money = money, BestTrack = best, TrackCount = trackCount }
	end
	local configBefore = deepCopy(UpgradeConfig)

	-- Config guard: the data still holds the owner's numbers (spec sections 1, 2, 4; design "Prices").
	local cfgOk = UpgradeConfig.START_ID == "start"
		and UpgradeConfig.BASE_PRICE == 150
		and UpgradeConfig.PRICE_GROWTH == 2.2
		and UpgradeConfig.GATE_FROM_TIER == 3
		and UpgradeConfig.BASE_ROLL_INTERVAL == 3
		and UpgradeConfig.MIN_ROLL_INTERVAL == 2
		and UpgradeConfig.BASE_WALKSPEED == 16
		and type(UpgradeConfig.BASE_TURBO) == "table"
		and UpgradeConfig.BASE_TURBO.Multi == 5
		and UpgradeConfig.BASE_TURBO.Every == 10
		and #UpgradeConfig.Branches == #UPGRADE_BRANCH_ORDER
	local configTierTotal = 0
	for i, b in UpgradeConfig.Branches do
		local id = b.Id
		local list = b.Bonus or b.Tiers or b.WalkSpeed
		local n = type(list) == "table" and #list or 0
		configTierTotal += n
		local branchOk = id == UPGRADE_BRANCH_ORDER[i]
			and n == UPGRADE_BRANCH_TIERS[id]
			and b.Name == UPGRADE_BRANCH_NAMES[id]
			and b.Weight == UPGRADE_BRANCH_WEIGHTS[id]
			and (UPGRADE_BONUS[id] == nil or deepEqual(b.Bonus, UPGRADE_BONUS[id]))
			and (id ~= "turbo" or (deepEqual(b.Tiers, UPGRADE_TURBO) and deepEqual(b.PriceDepth, { 2, 4, 6, 7 })))
			and b.Parent == (id == "turbo" and "rollspeed_1" or "start")
			and (id ~= "walkspeed" or deepEqual(b.WalkSpeed, UPGRADE_WALKSPEED))
		cfgOk = cfgOk and branchOk
	end
	local specTotal = 0
	for _, n in UPGRADE_BRANCH_TIERS do
		specTotal += n
	end
	cfgOk = cfgOk and configTierTotal == specTotal
	check(checks, "upgrades_config_matches_spec", configTierTotal, specTotal, cfgOk)

	-- The expected tile list, built from the config's layout (Origin + tier * Direction, Parent) and the spec's tiers.
	local expected = {}
	local expectedById = {}
	for _, b in UpgradeConfig.Branches do
		local n = UPGRADE_BRANCH_TIERS[b.Id] or 0
		local parent = b.Parent == "start" and { Depth = 0, Q = 0, R = 0 } or expectedById[b.Parent]
		for t = 1, n do
			local e = {
				Id = b.Id .. "_" .. t,
				Branch = b.Id,
				Tier = t,
				Name = UPGRADE_BRANCH_NAMES[b.Id] .. " " .. ROMAN[t],
				Depth = parent and parent.Depth + t or -1,
				Q = b.Origin[1] + t * b.Direction[1],
				R = b.Origin[2] + t * b.Direction[2],
				Parent = t == 1 and b.Parent or (b.Id .. "_" .. (t - 1)),
			}
			e.PriceDepth = b.PriceDepth and b.PriceDepth[t] or e.Depth
			table.insert(expected, e)
			expectedById[e.Id] = e
		end
	end

	-- Tiles()
	local okTiles, tilesRes = call("Tiles")
	local tiles = (okTiles and type(tilesRes) == "table") and tilesRes or {}
	check(checks, "upgrades_tile_count", #tiles, specTotal, #tiles == specTotal)
	local orderOk, namesOk, fieldsOk, fromConfigOk = #tiles == #expected, #tiles > 0, #tiles > 0, #tiles > 0
	local seenIds, seenHex = {}, {}
	local uniqueOk, notStartOk = #tiles > 0, #tiles > 0
	local byId = {}
	for i, tile in tiles do
		local e = expected[i]
		if type(tile) ~= "table" then
			orderOk, namesOk, fieldsOk, fromConfigOk, uniqueOk = false, false, false, false, false
			continue
		end
		if not e or tile.Id ~= e.Id then
			orderOk = false
		end
		local ee = expectedById[tile.Id]
		if not ee or tile.Name ~= ee.Name then
			namesOk = false
		end
		if
			not ee
			or tile.Branch ~= ee.Branch
			or tile.Tier ~= ee.Tier
			or tile.Depth ~= ee.Depth
			or tile.PriceDepth ~= ee.PriceDepth
			or tile.Parent ~= ee.Parent
		then
			fieldsOk = false
		end
		if not ee or tile.Q ~= ee.Q or tile.R ~= ee.R then
			fromConfigOk = false
		end
		if type(tile.Id) ~= "string" or seenIds[tile.Id] then
			uniqueOk = false
		else
			seenIds[tile.Id] = true
			byId[tile.Id] = tile
		end
		local key = tostring(tile.Q) .. "," .. tostring(tile.R)
		if type(tile.Q) ~= "number" or type(tile.R) ~= "number" or seenHex[key] then
			uniqueOk = false
		end
		seenHex[key] = true
		if tile.Q == 0 and tile.R == 0 then
			notStartOk = false
		end
	end
	flag("upgrades_tile_ids_and_order", orderOk)
	flag("upgrades_tile_names_roman", namesOk)
	flag("upgrades_tile_fields", fieldsOk)
	flag("upgrades_tile_ids_and_hex_unique", uniqueOk)
	flag("upgrades_hex_none_at_start", notStartOk)
	flag("upgrades_hex_positions_from_config", fromConfigOk)

	-- Real tree: tier I touches its Parent (Start, or rollspeed_1 for Turbo), tier n touches tier n-1.
	local tier1Ok, chainOk = #tiles > 0, #tiles > 0
	for _, e in expected do
		local tile = byId[e.Id]
		local parentId = e.Parent
		local pq, pr
		if parentId == "start" then
			pq, pr = 0, 0
		elseif byId[parentId] then
			pq, pr = byId[parentId].Q, byId[parentId].R
		end
		local touches = tile ~= nil
			and type(tile.Q) == "number"
			and type(tile.R) == "number"
			and type(pq) == "number"
			and type(pr) == "number"
			and hexDistance(tile.Q, tile.R, pq, pr) == 1
		if e.Tier == 1 then
			tier1Ok = tier1Ok and touches
		else
			chainOk = chainOk and touches
		end
	end
	flag("upgrades_hex_tier1_touches_parent", tier1Ok)
	flag("upgrades_hex_tiers_chain", chainOk)
	local turbo1 = byId.turbo_1
	local forkOk = turbo1 ~= nil and turbo1.Parent == "rollspeed_1" and turbo1.Depth == 2
	check(checks, "upgrades_turbo_forks_rollspeed_depth_2", turbo1 and tonumber(turbo1.Depth) or 0, 2, forkOk)

	-- Get
	local getOk = true
	for _, e in expected do
		local okc, t = call("Get", e.Id)
		if not okc or type(t) ~= "table" or t.Id ~= e.Id or t.Q ~= e.Q or t.R ~= e.R or t.Name ~= e.Name then
			getOk = false
		end
	end
	flag("upgrades_get", getOk)
	local getNilOk = true
	local badGet = table.pack("nope", "", "money_0", "money_6", "turbo_5", "Money_1", nil, 5, true, {})
	for i = 1, badGet.n do
		local okc, t = call("Get", badGet[i])
		if not okc or t ~= nil then
			getNilOk = false
		end
	end
	flag("upgrades_get_unknown_nil", getNilOk)

	-- NiceRound: two significant figures.
	local niceOk = true
	for _, c in
		{
			{ 726, 730 },
			{ 1597, 1600 },
			{ 150, 150 },
			{ 7730, 7700 },
			{ 34000, 34000 },
			{ 225, 230 },
			{ 165, 170 },
			{ 495, 500 },
		}
	do
		local okc, v = call("NiceRound", c[1])
		if not okc or v ~= c[2] then
			niceOk = false
		end
	end
	flag("upgrades_nice_round", niceOk)

	-- Price: the design table, every tile.
	local priceBad = 0
	for branch, prices in UPGRADE_PRICES do
		for tier, want in prices do
			local okc, p = call("Price", branch .. "_" .. tier)
			if not okc or p ~= want then
				priceBad += 1
			end
		end
	end
	check(checks, "upgrades_price_table", priceBad, 0, priceBad == 0)
	local priceNilOk = true
	local badPrice = table.pack("nope", "money_6", nil, 7, {})
	for i = 1, badPrice.n do
		local okc, p = call("Price", badPrice[i])
		if not okc or p ~= nil then
			priceNilOk = false
		end
	end
	flag("upgrades_price_unknown_nil", priceNilOk)

	-- RequiredTrack: tier >= 3 needs min(tier - 1, trackCount); turbo uses its own tier number.
	local function req(id, tc, want)
		local okc, v = call("RequiredTrack", id, tc)
		return okc and v == want
	end
	local reqLowOk = true
	for _, branch in UPGRADE_BRANCH_ORDER do
		for tier = 1, 2 do
			for _, tc in { 1, 2, 10 } do
				reqLowOk = req(branch .. "_" .. tier, tc, 0) and reqLowOk
			end
		end
	end
	flag("upgrades_required_track_tiers_1_2_ungated", reqLowOk)
	local req3Ok = req("money_3", 1, 1) and req("money_3", 2, 2) and req("luck_3", 10, 2) and req("speed_3", 2, 2)
	flag("upgrades_required_track_tier_3", req3Ok)
	local req45Ok = req("walkspeed_5", 2, 2)
		and req("money_5", 10, 4)
		and req("rollspeed_4", 2, 2)
		and req("rollspeed_4", 10, 3)
		and req("luck_5", 3, 3)
	flag("upgrades_required_track_tiers_4_5", req45Ok)
	local reqTurboOk = req("turbo_1", 10, 0)
		and req("turbo_2", 10, 0)
		and req("turbo_3", 10, 2)
		and req("turbo_3", 1, 1)
		and req("turbo_4", 10, 3)
		and req("turbo_4", 2, 2)
	flag("upgrades_required_track_turbo_own_tier", reqTurboOk)

	-- CanBuy
	local function canBuy(st, id)
		local okc, ok, reason = call("CanBuy", st, id)
		if not okc then
			return "error", "error"
		end
		return ok, reason
	end
	local function isOk(st, id)
		local ok = canBuy(st, id)
		return ok == true
	end
	local function isReason(st, id, want)
		local ok, reason = canBuy(st, id)
		return ok == false and reason == want
	end
	local RICH = 1e9
	local canOk = isOk(state({}, RICH, 0, 2), "money_1")
		and isOk(state({}, RICH, 0, 2), "walkspeed_1")
		and isOk(state({ "luck_1" }, RICH, 0, 2), "luck_2")
		and isOk(state({ "luck_1", "luck_2" }, RICH, 2, 2), "luck_3")
		and isOk(state(tierIds("speed", 4), RICH, 2, 2), "speed_5")
		and isOk(state(tierIds("money", 4), RICH, 4, 10), "money_5")
	flag("upgrades_canbuy_ok", canOk)
	local unknownOk = true
	local badBuy = table.pack("nope", "money_6", "turbo_5", "", nil, 5, true, {})
	for i = 1, badBuy.n do
		unknownOk = isReason(state({}, RICH, 10, 10), badBuy[i], "unknown") and unknownOk
	end
	flag("upgrades_canbuy_unknown", unknownOk)
	local ownedOk = isReason(state({ "money_1" }, RICH, 0, 2), "money_1", "owned")
		and isReason(state(tierIds("luck", 5), RICH, 10, 10), "luck_5", "owned")
	flag("upgrades_canbuy_owned", ownedOk)
	local lockedOk = isReason(state({}, RICH, 0, 2), "money_2", "locked")
		and isReason(state({ "luck_1", "luck_3" }, RICH, 10, 10), "luck_5", "locked")
		and isReason(state({ "speed_1" }, RICH, 10, 10), "speed_3", "locked")
	flag("upgrades_canbuy_locked", lockedOk)
	local gatedOk = isReason(state({ "money_1", "money_2" }, RICH, 0, 2), "money_3", "gated")
		and isReason(state({ "money_1", "money_2" }, RICH, 1, 2), "money_3", "gated")
		and isOk(state({ "money_1", "money_2" }, RICH, 2, 2), "money_3")
		and isReason(state(tierIds("money", 3), RICH, 2, 10), "money_4", "gated")
		and isOk(state(tierIds("money", 3), RICH, 3, 10), "money_4")
		and isOk(state(tierIds("money", 4), RICH, 2, 2), "money_5")
	flag("upgrades_canbuy_gated", gatedOk)
	local boundaryOk = isOk(state({}, 150, 0, 2), "money_1")
		and isReason(state({}, 149, 0, 2), "money_1", "money")
		and isOk(state({}, 75, 0, 2), "walkspeed_1")
		and isReason(state({}, 74, 0, 2), "walkspeed_1", "money")
		and isOk(state({ "luck_1" }, 400, 0, 2), "luck_2")
		and isReason(state({ "luck_1" }, 399, 0, 2), "luck_2", "money")
		and isReason(state({}, 0, 0, 2), "rollspeed_1", "money")
	flag("upgrades_canbuy_money_boundary", boundaryOk)
	-- Order of checks: unknown > owned > locked > gated > money.
	local orderCbOk = isReason(state({ "nope" }, 0, 0, 2), "nope", "unknown")
		and isReason(state({ "money_3" }, 0, 0, 2), "money_3", "owned")
		and isReason(state({}, 0, 0, 2), "money_3", "locked")
		and isReason(state({}, 0, 0, 2), "money_2", "locked")
		and isReason(state({ "money_1", "money_2" }, 0, 0, 2), "money_3", "gated")
	flag("upgrades_canbuy_reason_order", orderCbOk)
	local turboLockOk = isReason(state({}, RICH, 10, 10), "turbo_1", "locked")
		and isReason(state({ "money_1", "luck_1", "speed_1" }, RICH, 10, 10), "turbo_1", "locked")
		and isOk(state({ "rollspeed_1" }, RICH, 0, 2), "turbo_1")
		and isOk(state({ "rollspeed_1" }, 660, 0, 2), "turbo_1")
		and isReason(state({ "rollspeed_1" }, 659, 0, 2), "turbo_1", "money")
		and isReason(state({ "rollspeed_1" }, RICH, 0, 2), "turbo_2", "locked")
	flag("upgrades_canbuy_turbo_needs_rollspeed_1", turboLockOk)

	-- BuyableCount (the UPGRADES badge)
	local function buyable(st, want)
		local okc, n = call("BuyableCount", st)
		return okc and n == want
	end
	flag("upgrades_buyable_count_broke_is_0", buyable(state({}, 0, 0, 2), 0))
	flag("upgrades_buyable_count_rich_is_5", buyable(state({}, RICH, 0, 2), 5))
	flag("upgrades_buyable_count_turbo_unlocks", buyable(state({ "rollspeed_1" }, RICH, 0, 2), 6))
	local partialOk = buyable(state({}, 100, 0, 2), 1) -- walkspeed_1 ($75) only
		and buyable(state({}, 150, 0, 2), 3) -- + money_1, speed_1
		and buyable(state({ "money_1", "money_2" }, RICH, 0, 2), 4) -- money_3 gated
		and buyable(state({ "money_1", "money_2" }, RICH, 2, 2), 5)
	flag("upgrades_buyable_count_money_and_gate", partialOk)

	-- Bonuses: added percentages, pure sum of what is owned.
	local function bonuses(ids)
		local okc, b = call("Bonuses", idSet(ids))
		return okc and type(b) == "table" and b or nil
	end
	local function bonusIs(b, want)
		if not b then
			return false
		end
		for _, key in { "Money", "Luck", "Speed", "RollSpeed" } do
			if not near(b[key], want[key] or 0) then
				return false
			end
		end
		return true
	end
	flag("upgrades_bonuses_empty_zero", bonusIs(bonuses({}), {}) and bonusIs(bonuses({ "start" }), {}))
	flag("upgrades_bonuses_luck_1_2_is_0_25", bonusIs(bonuses({ "luck_1", "luck_2" }), { Luck = 0.25 }))
	local fullOk = bonusIs(bonuses(tierIds("money", 5)), { Money = 0.70 })
		and bonusIs(bonuses(tierIds("luck", 5)), { Luck = 1.00 })
		and bonusIs(bonuses(tierIds("speed", 5)), { Speed = 0.70 })
		and bonusIs(bonuses(tierIds("rollspeed", 5)), { RollSpeed = 0.50 })
	flag("upgrades_bonuses_added_full_branches", fullOk)
	local sumOk = bonusIs(bonuses({ "luck_3" }), { Luck = 0.20 })
		and bonusIs(bonuses({ "money_2", "money_5", "speed_4" }), { Money = 0.30, Speed = 0.15 })
	flag("upgrades_bonuses_pure_sum_of_owned", sumOk)
	local otherOk = bonusIs(bonuses({ "walkspeed_1", "walkspeed_2", "turbo_1", "nope" }), {})
	flag("upgrades_bonuses_ignore_walkspeed_turbo_unknown", otherOk)

	-- RollInterval: 3 / (1 + bonus), never below 2.
	local function interval(ids)
		local okc, v = call("RollInterval", idSet(ids))
		return okc and v or nil
	end
	local base = interval({})
	check(checks, "upgrades_roll_interval_base_3", tonumber(base) or -1, 3, near(base, 3, 0.01))
	local riOk = true
	for k = 1, 5 do
		riOk = near(interval(tierIds("rollspeed", k)), UPGRADE_ROLL_INTERVALS[k], 0.01) and riOk
	end
	riOk = near(interval({ "rollspeed_3" }), 2.727, 0.01) and riOk
	flag("upgrades_roll_interval_tiers", riOk)
	local floorOk = true
	local minSeen = math.huge
	for mask = 0, 31 do
		local ids = {}
		for t = 1, 5 do
			if bit32.btest(mask, bit32.lshift(1, t - 1)) then
				table.insert(ids, "rollspeed_" .. t)
			end
		end
		local v = interval(ids)
		if type(v) ~= "number" or v < 2 - 1e-9 then
			floorOk = false
		end
		if type(v) == "number" then
			minSeen = math.min(minSeen, v)
		end
	end
	check(checks, "upgrades_roll_interval_never_below_2", minSeen == math.huge and -1 or minSeen, ">= 2", floorOk)

	-- Turbo: highest owned tier wins.
	local function turboIs(ids, multi, every)
		local okc, v = call("Turbo", idSet(ids))
		return okc and type(v) == "table" and v.Multi == multi and v.Every == every
	end
	flag("upgrades_turbo_base", turboIs({}, 5, 10))
	local turboTiersOk = true
	for k, want in UPGRADE_TURBO do
		turboTiersOk = turboIs(tierIds("turbo", k), want.Multi, want.Every) and turboTiersOk
	end
	flag("upgrades_turbo_tiers", turboTiersOk)
	local turboHighOk = turboIs({ "turbo_1" }, 10, 15)
		and turboIs({ "turbo_2" }, 50, 25)
		and turboIs({ "turbo_1", "turbo_3" }, 100, 40)
		and turboIs({ "turbo_4" }, 1000, 100)
		and turboIs({ "rollspeed_1", "luck_5" }, 5, 10)
	flag("upgrades_turbo_highest_owned_wins", turboHighOk)

	-- WalkSpeed: highest owned tier wins.
	local function walkIs(ids, want)
		local okc, v = call("WalkSpeed", idSet(ids))
		return okc and v == want
	end
	flag("upgrades_walkspeed_base_16", walkIs({}, 16))
	local walkTiersOk = true
	for k, want in UPGRADE_WALKSPEED do
		walkTiersOk = walkIs(tierIds("walkspeed", k), want) and walkTiersOk
	end
	flag("upgrades_walkspeed_tiers", walkTiersOk)
	flag(
		"upgrades_walkspeed_highest_owned_wins",
		walkIs({ "walkspeed_5" }, 30) and walkIs({ "walkspeed_2", "walkspeed_4" }, 26) and walkIs({ "money_5" }, 16)
	)

	-- Purity: nothing mutates the owned set, the state or the config.
	local owned = idSet({ "rollspeed_1", "rollspeed_2", "luck_1", "turbo_1", "walkspeed_1", "money_3" })
	local st = { Owned = owned, Money = 5000, BestTrack = 1, TrackCount = 2 }
	local ownedBefore, stBefore = deepCopy(owned), deepCopy(st)
	call("Bonuses", owned)
	call("RollInterval", owned)
	call("Turbo", owned)
	call("WalkSpeed", owned)
	call("BuyableCount", st)
	for _, e in expected do
		call("CanBuy", st, e.Id)
	end
	local pureOk = deepEqual(owned, ownedBefore) and deepEqual(st, stBefore) and st.Owned == owned
	flag("upgrades_pure_inputs_unchanged", pureOk)
	flag("upgrades_config_unchanged", deepEqual(UpgradeConfig, configBefore))

	metrics.tiles = #tiles
	metrics.call_errors = errorCount
	return result("upgrades", checks, metrics)
end

-- name: "static_settle" | "accel" | "brake" | "skidpad" | "car_size" | "economy" | "hud" | "auto_toggle" | "spawn_area" | "gacha" | "index" | "npc" | "bank" | "multiplayer" | "admin" | "roll_anim" | "upgrades" | "lap:<Track>" | "track:<Track>"
function Scenarios.Run(name)
	local track = string.match(name, "^lap:(.+)$")
	if track then
		return Scenarios.lap(track)
	end
	local trackTest = string.match(name, "^track:(.+)$")
	if trackTest then
		return Scenarios.track(trackTest)
	end
	local fn = Scenarios[name]
	if type(fn) ~= "function" or name == "Run" or name == "lap" then
		return result(name, { { name = "scenario_exists", value = 0, limit = 1, pass = false } }, {})
	end
	return fn()
end

return Scenarios
