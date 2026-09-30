--!nonstrict
-- Pure-pursuit driver that follows a list of waypoints with the real car physics. Two users:
--   * the test harness (CarTest/Bot is this module), which drives a track's centreline to prove it is drivable;
--   * RaceService, which auto-races a player's car along the chain of tracks (PathDriver.Chain) at the
--     cruise speed from the player's saved Speed stat (options.TargetSpeed).
-- The driver holds TargetSpeed on straights and slopes and only slows down where corner grip requires it.

local TrackBuilder = require(script.Parent.TrackBuilder)

local PathDriver = {}
PathDriver.__index = PathDriver

local LOOKAHEAD_MIN = 14
local LOOKAHEAD_TIME = 0.3
local SEARCH_WINDOW = 25
local BRAKE_PREVIEW = 70
local SPEED_MARGIN = 0.92
local BOT_GRIP_FRACTION = 0.55 -- bot only uses this share of the tyre budget in corners

-- path: { WorldWaypoints, Curvature, Closed, Width }. options: { TargetSpeed?, NoFinalSlow? }
function PathDriver.new(layout, config, options)
	options = options or {}
	return setmetatable({
		TargetSpeed = options.TargetSpeed,
		NoFinalSlow = options.NoFinalSlow == true,
		Waypoints = layout.WorldWaypoints,
		Curvature = layout.Curvature,
		Closed = layout.Closed,
		Width = layout.Width,
		Config = config,
		Index = 1,
		Wraps = 0,
		Done = false,
		OffTrackSeconds = 0,
		DistanceToCenter = 0,
	}, PathDriver)
end

-- Distances are 3D so that hills and loops (where the road overlaps itself in plan view) track correctly.
local function flat(v)
	return v
end

function PathDriver:Control(chassis, dt)
	local wps, n, cfg = self.Waypoints, #self.Waypoints, self.Config
	local cf = chassis.CFrame
	local pos = chassis.Position
	local vel = chassis.AssemblyLinearVelocity
	local speed = vel.Magnitude
	local fwdSpeed = vel:Dot(cf.LookVector)

	-- Progress: nearest waypoint in a forward window
	local bestI, bestD = self.Index, math.huge
	for off = 0, SEARCH_WINDOW do
		local i = self.Index + off
		if i > n then
			if self.Closed then
				i -= n
			else
				break
			end
		end
		local d = (flat(wps[i]) - flat(pos)).Magnitude
		if d < bestD then
			bestD, bestI = d, i
		end
	end
	if self.Closed and bestI < self.Index - n / 2 then
		self.Wraps += 1
	end
	self.Index = bestI
	self.DistanceToCenter = bestD
	if bestD > self.Width / 2 then
		self.OffTrackSeconds += dt
	end
	if (self.Closed and self.Wraps >= 1) or (not self.Closed and self.Index >= n - 1) then
		self.Done = true
	end

	-- Steering: pure pursuit towards a point ahead on the centreline
	local lookahead = LOOKAHEAD_MIN + speed * LOOKAHEAD_TIME
	local acc, j, prev = 0, self.Index, wps[self.Index]
	while acc < lookahead do
		local nj = j + 1
		if nj > n then
			if self.Closed then
				nj = 1
			else
				break
			end
		end
		acc += (wps[nj] - prev).Magnitude
		prev, j = wps[nj], nj
	end
	local target = cf:PointToObjectSpace(wps[j])
	local alpha = math.atan2(target.X, -target.Z) -- +ve = target is to the right
	local ld = math.max(target.Magnitude, 1)
	local wheelAngle = math.atan(2 * cfg.Wheelbase * math.sin(alpha) / ld)
	local speedFactor = 1 / (1 + (math.abs(fwdSpeed) / cfg.SteerFalloffSpeed) ^ 2)
	local maxWheel = cfg.MaxSteer * math.max(speedFactor, cfg.MinSteerFactor)
	local steer = math.clamp(wheelAngle / maxWheel, -1, 1)

	-- Speed: slow for the tightest corner in the next BRAKE_PREVIEW studs
	local latAccel = cfg.Mu * workspace.Gravity * BOT_GRIP_FRACTION
	local targetSpeed = math.min(cfg.TopSpeed * SPEED_MARGIN, self.TargetSpeed or math.huge)
	local ahead, k, p = 0, self.Index, wps[self.Index]
	while ahead < BRAKE_PREVIEW do
		local curv = self.Curvature[k]
		if curv > 0 then
			targetSpeed = math.min(targetSpeed, math.sqrt(latAccel / curv))
		end
		local nk = k + 1
		if nk > n then
			if self.Closed then
				nk = 1
			else
				break
			end
		end
		ahead += (wps[nk] - p).Magnitude
		p, k = wps[nk], nk
	end
	if not self.Closed and not self.NoFinalSlow and self.Index > n - 8 then
		targetSpeed = math.min(targetSpeed, 30)
	end

	local err = targetSpeed - fwdSpeed
	local throttle, brake = 0, 0
	if err > 0 then
		throttle = math.clamp(err * 0.25, 0, 1)
	else
		brake = math.clamp(-err * 0.15, 0, 1)
	end

	return { Throttle = throttle, Steer = steer, Brake = brake, Handbrake = false }
end

-- Joins the tracks of the chain into one path. entries = { { Layout, Origin, Model?, Number? }, ... } in
-- Number order. Each track contributes its RacePath (centre line plus the swing over the winnings pad).
-- The first point of every later track is the previous track's finish, so it is dropped.
-- path.PadIndices[i] is the waypoint index of entry i's pad.
function PathDriver.Chain(entries)
	local waypoints, curvature, padIndices = {}, {}, {}
	for i, entry in entries do
		local race = TrackBuilder.RacePath(entry.Layout)
		local first = i == 1 and 1 or 2
		for k = first, #race.Waypoints do
			table.insert(waypoints, entry.Origin:PointToWorldSpace(race.Waypoints[k]))
			table.insert(curvature, race.Curvature[k])
		end
		padIndices[i] = #waypoints - (#race.Waypoints - race.PadIndex)
	end
	return {
		WorldWaypoints = waypoints,
		Curvature = curvature,
		Closed = false,
		Width = entries[1] and entries[1].Layout.Width or 40,
		PadIndices = padIndices,
	}
end

return PathDriver
