--!nonstrict
-- The NPC racer is a numbers game: it does not use physics. It drives the LEFT lane of a track (centre line
-- shifted LANE_OFFSET to the left) at its NpcConfig speed, slowing only where corner grip requires it (the same
-- limit PathDriver uses), so its time for a track is known the moment the race starts. The server decides the
-- race from that time (Server/RaceService); the owning client only draws the car (Client/NpcRacerView), so other
-- players never see it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarConfig = require(script.Parent.CarConfig)
local CarFactory = require(script.Parent.CarFactory)
local NpcConfig = require(script.Parent.NpcConfig)
local TrackBuilder = require(script.Parent.TrackBuilder)
local TrackRegistry = require(script.Parent.TrackRegistry)

local NpcRacer = {}

local GRIP_FRACTION = 0.55 -- PathDriver's BOT_GRIP_FRACTION: the share of the tyre budget used in corners
local HOOD_TINT = 0.3 -- the hood is the body colour lightened this much towards white

-- The chain of tracks as Main builds it, without instances: { { Layout, Origin, Number }, ... } in Number order.
function NpcRacer.ChainEntries()
	local entries = {}
	local origin = CFrame.new(0, TrackBuilder.TRACK_LIFT, 0)
	for _, spec in TrackRegistry.Chain() do
		local layout = TrackBuilder.Layout(spec)
		table.insert(entries, { Layout = layout, Origin = origin, Number = spec.Number })
		origin = TrackBuilder.EndCFrame(layout, origin)
	end
	return entries
end

-- The NPC's lane on one chain entry { Layout, Origin }, in world space: { Waypoints, Curvature, Length }.
function NpcRacer.LanePath(entry)
	local lane = TrackBuilder.RacePath(entry.Layout, -TrackBuilder.LANE_OFFSET)
	local waypoints = table.create(#lane.Waypoints)
	local length = 0
	for i, p in lane.Waypoints do
		waypoints[i] = entry.Origin:PointToWorldSpace(p)
		if i > 1 then
			length += (waypoints[i] - waypoints[i - 1]).Magnitude
		end
	end
	return { Waypoints = waypoints, Curvature = lane.Curvature, Length = length }
end

-- When the NPC passes each waypoint at cruise `speed`: { Times, TotalTime, Length }.
function NpcRacer.Profile(path, speed)
	local wps, curv = path.Waypoints, path.Curvature
	local latAccel = CarConfig.Mu * workspace.Gravity * GRIP_FRACTION
	local function limit(i)
		local k = curv[i] or 0
		return k > 0 and math.min(speed, math.sqrt(latAccel / k)) or speed
	end
	local times = table.create(#wps)
	times[1] = 0
	local t = 0
	for i = 2, #wps do
		local v = math.max(math.min(limit(i - 1), limit(i)), 1e-3)
		t += (wps[i] - wps[i - 1]).Magnitude / v
		times[i] = t
	end
	return { Times = times, TotalTime = t, Length = path.Length, Speed = speed }
end

-- Where the NPC is `t` seconds after the start: a CFrame on the lane at the car's ride height, facing along it.
function NpcRacer.PoseAt(path, profile, t)
	local wps, times = path.Waypoints, profile.Times
	local n = #wps
	t = math.clamp(t, 0, profile.TotalTime)
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if times[mid] <= t then
			lo = mid
		else
			hi = mid
		end
	end
	local a, b = wps[lo], wps[hi]
	local span = times[hi] - times[lo]
	local alpha = span > 1e-6 and math.clamp((t - times[lo]) / span, 0, 1) or 0
	local up = Vector3.new(0, CarConfig.RestHeight, 0)
	local pos = a:Lerp(b, alpha) + up
	local dir = b - a
	if dir.Magnitude < 1e-6 then
		return CFrame.new(pos)
	end
	return CFrame.lookAt(pos, pos + dir.Unit)
end

local function setupParts(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
end

-- The NPC car for `info` (NpcConfig.For(n)): the starter car in info.Color, or a clone of
-- ReplicatedStorage.NpcModels[info.Model]. Not parented: the owning client puts it in its own Workspace.
function NpcRacer.BuildModel(info)
	local model
	local folder = info.Model and ReplicatedStorage:FindFirstChild("NpcModels")
	local custom = folder and folder:FindFirstChild(info.Model)
	if custom and custom:IsA("Model") then
		model = custom:Clone()
		if not model.PrimaryPart then
			model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
		end
	else
		local config = table.clone(CarConfig)
		config.Colors = table.clone(CarConfig.Colors)
		config.Colors.Body = info.Color
		config.Colors.Hood = info.Color:Lerp(Color3.new(1, 1, 1), HOOD_TINT)
		model = CarFactory.build(config)
		local seat = model:FindFirstChild("DriverSeat")
		if seat then
			seat:Destroy() -- nobody sits in an NPC
		end
	end
	model.Name = "NPC_" .. info.Label
	model:SetAttribute("IsNpc", true)
	model:SetAttribute("TrackNumber", info.Number)
	setupParts(model)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NpcLabel"
	billboard.Adornee = model.PrimaryPart
	billboard.Size = UDim2.fromOffset(160, 36)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.MaxDistance = NpcConfig.LABEL_DISTANCE -- proximity based
	billboard.LightInfluence = 0
	billboard.Parent = model
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = info.Label
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
	return model
end

return NpcRacer
