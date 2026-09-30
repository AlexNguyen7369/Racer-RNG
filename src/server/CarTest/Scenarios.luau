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
		pcall(function()
			run:Destroy()
		end)
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
local AUTO_BASEPLATE_TOP = 0 -- Main builds the chain TRACK_LIFT above a baseplate whose top is Y = 0
local AUTO_START_RADIUS = 25 -- studs: a resumed car spawns at the Track 1 start
local AUTO_WALK_SPEED = 16 -- StarterPlayer defaults
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

-- A minimal R6 avatar: HumanoidRootPart (invisible), Torso, Head with a face decal, two legs, Motor6D joints.
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
	local origNewRun = RaceService.NewRun
	RaceService.NewRun = function(car, route, p, options)
		local run = origNewRun(car, route, p, options)
		if p == player and type(run) == "table" then
			table.insert(runs, run)
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
			before[d] = { Transparency = d.Transparency, CanCollide = d.CanCollide, Massless = d.Massless }
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
		local runOk = type(run) == "table" and run.Connection ~= nil and run.Car == car and run ~= oldRun
		check(checks, pre .. "_run_active", runOk and 1 or 0, 1, runOk)
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
		frames(3)
		local stat1 = speedRaw()
		check(checks, "drive_stat_grew", stat1, stat0, stat1 > stat0)

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

		local visOk, collideOk, massOk = true, true, true
		for part, b in before do
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
		local unseated = humanoid.Sit == false and humanoid.SeatPart == nil
		check(checks, "stop_unseated", unseated and 1 or 0, 1, unseated)
		check(checks, "stop_walk_speed", humanoid.WalkSpeed, AUTO_WALK_SPEED, humanoid.WalkSpeed == AUTO_WALK_SPEED)
		local jh = humanoid.JumpHeight
		check(checks, "stop_jump_height", jh, AUTO_JUMP_HEIGHT, math.abs(jh - AUTO_JUMP_HEIGHT) <= 1e-3)
		local viewer = humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.Viewer
		check(checks, "stop_name_display_viewer", viewer and 1 or 0, 1, viewer)
		local atSpawn = hdist(root.Position, walkCF.Position)
		check(checks, "stop_at_walk_spawn", atSpawn, AUTO_SPAWN_MATCH, atSpawn <= AUTO_SPAWN_MATCH)

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
		local onBase = hit ~= nil
			and not hit.Instance:IsDescendantOf(trackFolder)
			and math.abs(hit.Position.Y - AUTO_BASEPLATE_TOP) <= 1
		check(checks, "walk_spawn_on_baseplate", hit and hit.Position.Y or -999, AUTO_BASEPLATE_TOP, onBase)
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
		local ground = hit and hit.Position.Y or AUTO_BASEPLATE_TOP
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
		check(checks, "saved_version", rec.Version or -1, 2, rec.Version == 2)
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
			and r.Version == 2
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
	-- valid non-negative stat, and the next save upgrades the record to Version 2
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
			2,
			oksv and type(legacyRec) == "table" and legacyRec.Version == 2 and legacyRec.Money == c.wantMoney
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
	return result("hud", checks, {})
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

-- name: "static_settle" | "accel" | "brake" | "skidpad" | "car_size" | "economy" | "hud" | "auto_toggle" | "lap:<Track>" | "track:<Track>"
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
