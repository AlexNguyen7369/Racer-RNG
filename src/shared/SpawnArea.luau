--!nonstrict
-- The spawn area (docs/SPAWN_AND_ROLLS_SPEC.md): a large purple floor beside the start of Track 1 with the game's only
-- SpawnLocation, and the StartPad that joins it to the road. Players join and respawn here on foot, Stop sends them
-- back here, and walking onto the StartPad starts auto racing (Server/CarService).
-- Everything is placed in the local space of Track 1's Start part (forward -Z, right +X). Track 1's finish and
-- Track 2 pass behind the start line, so the area sits to the RIGHT of the start straight and the pad fills the
-- gap right behind the start line.
-- Workshop plots (docs/WORKSHOP_SPEC.md, owner 2026-10-06): the floor was grown outward (+X) and forward (-Z) to hold
-- the 7 plots (Shared/WorkshopConfig) in an L around the HUB, the old 160 x 144 floor, which keeps the spawn.

local CollectionService = game:GetService("CollectionService")

local SpawnArea = {}

SpawnArea.COLOR = Color3.fromRGB(140, 70, 220) -- purple, so the area is easy to tell apart (placeholder look)
SpawnArea.PAD_COLOR = Color3.fromRGB(60, 220, 110)
SpawnArea.AREA_MIN = Vector2.new(24, -188) -- local (x, z) corners of the floor: 228 x 232 studs (hub + plots)
SpawnArea.AREA_MAX = Vector2.new(252, 44)
SpawnArea.HUB_MIN = Vector2.new(24, -100) -- the part of the floor kept free of plots: spawn, StartPad side, upgrade pad
SpawnArea.HUB_MAX = Vector2.new(184, 44)
SpawnArea.PAD_MIN = Vector2.new(-20, 2) -- local (x, z) corners of the start platform: behind the start line,
SpawnArea.PAD_MAX = Vector2.new(24, 38) -- from the road's left wall to the area
SpawnArea.TOP_Y = 1 -- floor top = road top
SpawnArea.START_COOLDOWN = 2 -- seconds after a stop or a pad start before the pad can start that player again
SpawnArea.WALK_ROOT_HEIGHT = 3 -- HumanoidRootPart height above the floor top when standing
SpawnArea.TAG = "StartPad"

local THICKNESS = 1
local EDGE_HEIGHT = 2
local EDGE_WIDTH = 1
local PAD_RAISE = 0.2
local SPAWN_SIZE = 12
local LABEL_DISTANCE = 150
local RACE_CANOPY_HEIGHT = 11

-- Track 1's start, flattened: yaw only, at ground level (the local space every spawn-area and plot position uses)
local function base(startCFrame)
	local look = startCFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, -1)
	local p = Vector3.new(startCFrame.Position.X, 0, startCFrame.Position.Z)
	return CFrame.lookAt(p, p + flat)
end

SpawnArea.Base = base

local function world(startCFrame, x, z, y)
	local p = base(startCFrame):PointToWorldSpace(Vector3.new(x, 0, z))
	return Vector3.new(p.X, y or SpawnArea.TOP_Y, p.Z)
end

local function rect(startCFrame, min, max)
	local a = world(startCFrame, min.X, min.Y)
	local b = world(startCFrame, max.X, max.Y)
	return {
		Min = Vector3.new(math.min(a.X, b.X), SpawnArea.TOP_Y, math.min(a.Z, b.Z)),
		Max = Vector3.new(math.max(a.X, b.X), SpawnArea.TOP_Y, math.max(a.Z, b.Z)),
	}
end

-- World corners (Y = TOP_Y) of the floor and of the start platform.
function SpawnArea.Bounds(startCFrame)
	return {
		Area = rect(startCFrame, SpawnArea.AREA_MIN, SpawnArea.AREA_MAX),
		Pad = rect(startCFrame, SpawnArea.PAD_MIN, SpawnArea.PAD_MAX),
	}
end

local function centre(min, max)
	return (min + max) / 2
end

-- Where an avatar stands in the area: the middle of the hub, facing the start platform.
function SpawnArea.WalkCFrame(startCFrame)
	local c = centre(SpawnArea.HUB_MIN, SpawnArea.HUB_MAX)
	local pad = centre(SpawnArea.PAD_MIN, SpawnArea.PAD_MAX)
	local y = SpawnArea.TOP_Y + SpawnArea.WALK_ROOT_HEIGHT
	local pos = world(startCFrame, c.X, c.Y, y)
	local look = world(startCFrame, pad.X, pad.Y, y)
	return CFrame.lookAt(pos, look)
end

-- A part whose top face is at `top`, covering local min..max.
local function slab(model, name, startCFrame, min, max, top, height, class)
	local part = Instance.new(class or "Part")
	part.Name = name
	part.Anchored = true
	part.Size = Vector3.new(max.X - min.X, height, max.Y - min.Y)
	local c = centre(min, max)
	part.CFrame = base(startCFrame) * CFrame.new(c.X, top - height / 2, c.Y)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

function SpawnArea.Build(startCFrame)
	local model = Instance.new("Model")
	model.Name = "SpawnArea"
	local top = SpawnArea.TOP_Y
	local amin, amax = SpawnArea.AREA_MIN, SpawnArea.AREA_MAX

	local floor = slab(model, "Floor", startCFrame, amin, amax, top, THICKNESS)
	floor.Color = SpawnArea.COLOR
	floor.Material = Enum.Material.SmoothPlastic

	-- Low edges on the three outer sides; the side facing the road and the pad stays open
	local edges = {
		EdgeFar = { Vector2.new(amin.X, amin.Y), Vector2.new(amax.X, amin.Y + EDGE_WIDTH) },
		EdgeNear = { Vector2.new(amin.X, amax.Y - EDGE_WIDTH), Vector2.new(amax.X, amax.Y) },
		EdgeOuter = { Vector2.new(amax.X - EDGE_WIDTH, amin.Y), Vector2.new(amax.X, amax.Y) },
	}
	for name, corners in edges do
		local edge = slab(model, name, startCFrame, corners[1], corners[2], top + EDGE_HEIGHT, EDGE_HEIGHT)
		edge.Color = SpawnArea.COLOR:Lerp(Color3.new(0, 0, 0), 0.35)
		edge.Material = Enum.Material.SmoothPlastic
	end

	local c = centre(SpawnArea.HUB_MIN, SpawnArea.HUB_MAX)
	local half = SPAWN_SIZE / 2
	local spawn = slab(
		model,
		"Spawn",
		startCFrame,
		Vector2.new(c.X - half, c.Y - half),
		Vector2.new(c.X + half, c.Y + half),
		top + 0.05, -- a hair above the floor so the two never z-fight
		1,
		"SpawnLocation"
	)
	spawn.Neutral = true
	spawn.Duration = 0 -- no force field
	spawn.Color = SpawnArea.COLOR
	spawn.Material = Enum.Material.SmoothPlastic
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	local pad = slab(model, "StartPad", startCFrame, SpawnArea.PAD_MIN, SpawnArea.PAD_MAX, top + PAD_RAISE, 1)
	pad.Color = SpawnArea.PAD_COLOR
	pad.Material = Enum.Material.Neon
	CollectionService:AddTag(pad, SpawnArea.TAG)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	billboard.MaxDistance = LABEL_DISTANCE
	billboard.AlwaysOnTop = false
	billboard.Parent = pad
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "RACE ▶"
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Parent = billboard

	-- A small overhang makes the manual race entrance read as a destination instead of
	-- an isolated neon pad. It stays open on every side so the start trigger remains
	-- easy to approach on foot.
	local canopy = Instance.new("Model")
	canopy.Name = "RaceOverhang"
	canopy.Parent = model
	local raceBase = base(startCFrame)
	local function canopyPart(name, size, localPosition, color, material)
		local beam = Instance.new("Part")
		beam.Name = name
		beam.Anchored = true
		beam.Size = size
		beam.CFrame = raceBase * CFrame.new(localPosition.X, localPosition.Y, localPosition.Z)
		beam.Color = color
		beam.Material = material or Enum.Material.Metal
		beam.TopSurface = Enum.SurfaceType.Smooth
		beam.BottomSurface = Enum.SurfaceType.Smooth
		beam.Parent = canopy
		return beam
	end
	local canopyTrim = SpawnArea.PAD_COLOR:Lerp(Color3.new(1, 1, 1), 0.2)
	for _, x in { -20, 20 } do
		canopyPart(
			"Post" .. x,
			Vector3.new(1.2, RACE_CANOPY_HEIGHT, 1.2),
			Vector3.new(x, RACE_CANOPY_HEIGHT / 2, 18),
			canopyTrim
		)
	end
	canopyPart(
		"Roof",
		Vector3.new(42, 1.2, 19),
		Vector3.new(0, RACE_CANOPY_HEIGHT, 18),
		SpawnArea.COLOR:Lerp(Color3.new(1, 1, 1), 0.15)
	)
	canopyPart(
		"RoofTrim",
		Vector3.new(43, 0.35, 0.7),
		Vector3.new(0, RACE_CANOPY_HEIGHT + 0.7, 8.7),
		canopyTrim,
		Enum.Material.Neon
	)
	canopyPart(
		"RoofTrimBack",
		Vector3.new(43, 0.35, 0.7),
		Vector3.new(0, RACE_CANOPY_HEIGHT + 0.7, 27.3),
		canopyTrim,
		Enum.Material.Neon
	)
	local canopySign = Instance.new("BillboardGui")
	canopySign.Name = "RaceSign"
	canopySign.Size = UDim2.fromOffset(250, 60)
	canopySign.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 18)
	canopySign.MaxDistance = LABEL_DISTANCE
	canopySign.AlwaysOnTop = false
	canopySign.Parent = canopyPart(
		"SignMount",
		Vector3.new(18, 0.4, 0.4),
		Vector3.new(0, RACE_CANOPY_HEIGHT - 1.5, 8),
		SpawnArea.PAD_COLOR,
		Enum.Material.Neon
	)
	local signText = Instance.new("TextLabel")
	signText.Name = "Text"
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Text = "RACE"
	signText.Font = Enum.Font.GothamBlack
	signText.TextScaled = true
	signText.TextColor3 = Color3.new(1, 1, 1)
	signText.TextStrokeTransparency = 0.25
	signText.Parent = canopySign

	model.PrimaryPart = floor
	local upgrade =
		slab(model, "UpgradePad", startCFrame, Vector2.new(144, -76), Vector2.new(156, -64), top + 0.15, 0.25)
	upgrade.Color = Color3.fromRGB(75, 235, 140)
	upgrade.Material = Enum.Material.Neon
	CollectionService:AddTag(upgrade, "UpgradePad")
	local upgradeGui = billboard:Clone()
	upgradeGui.Name = "UpgradeSign"
	upgradeGui.Text.Text = "UPGRADES"
	upgradeGui.Parent = upgrade
	return model
end

return SpawnArea
