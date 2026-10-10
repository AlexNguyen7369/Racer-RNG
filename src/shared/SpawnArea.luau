--!nonstrict
-- The spawn area (docs/SPAWN_AND_ROLLS_SPEC.md): a large purple floor beside the start of Track 1 with the game's only
-- SpawnLocation, and the StartPad pavilion within the hub. Players join and respawn here on foot, Stop sends them
-- back here, and walking onto the StartPad starts auto racing (Server/CarService).
-- Everything is placed in the local space of Track 1's Start part (forward -Z, right +X). Track 1's finish and
-- Track 2 pass behind the start line, so the area sits to the RIGHT of the start straight.
-- Workshop plots (docs/WORKSHOP_SPEC.md, owner 2026-10-06): the floor was grown outward (+X) and forward (-Z) to hold
-- the 7 plots (Shared/WorkshopConfig) in an L around the HUB, the old 160 x 144 floor, which keeps the spawn.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RaceStartMeshAssets = require(script.Parent.RaceStartMeshAssets)
local MarketplaceBuilder = require(script.Parent.MarketplaceBuilder)

-- Match WorkshopBuilder's native-mesh safeguard before Main builds the area.
local raceTemplate = ReplicatedStorage:WaitForChild("RaceStartPavilion"):Clone()
for _, mesh in raceTemplate:GetDescendants() do
	if mesh:IsA("MeshPart") then
		local assetId = RaceStartMeshAssets[mesh.Name]
		assert(assetId, "Missing race start mesh asset: " .. mesh.Name)
		if mesh.MeshId ~= assetId or mesh.MeshSize.Magnitude == 0 then
			local texture = mesh.TextureID
			local loaded = AssetService:CreateMeshPartAsync(Content.fromUri(assetId), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
			})
			mesh:ApplyMesh(loaded)
			mesh.TextureID = texture
			loaded:Destroy()
		end
		assert(mesh.MeshId == assetId and mesh.MeshSize.Magnitude > 0, "Race start mesh failed to load: " .. mesh.Name)
	end
end

local SpawnArea = {}

SpawnArea.COLOR = Color3.fromRGB(140, 70, 220) -- purple, so the area is easy to tell apart (placeholder look)
SpawnArea.PAD_COLOR = Color3.fromRGB(60, 220, 110)
SpawnArea.AREA_MIN = Vector2.new(24, -188) -- local (x, z) corners of the floor: 228 x 232 studs (hub + plots)
SpawnArea.AREA_MAX = Vector2.new(252, 44)
SpawnArea.HUB_MIN = Vector2.new(24, -100) -- the part of the floor kept free of plots: spawn, StartPad side, upgrade pad
SpawnArea.HUB_MAX = Vector2.new(184, 44)
SpawnArea.PAD_MIN = Vector2.new(-20, 2) -- authored pavilion coordinates; placement is controlled by PadBase
SpawnArea.PAD_MAX = Vector2.new(24, 38)
SpawnArea.PAD_CENTER = Vector2.new(34.3031235, 28.4993916) -- owner's on-foot position in the hub
SpawnArea.PAD_FRONT = Vector2.new(1, 0) -- square to the hub: sign faces +X, right entrance faces -Z
SpawnArea.TOP_Y = 1 -- floor top = road top
SpawnArea.START_COOLDOWN = 2 -- seconds after a stop or a pad start before the pad can start that player again
SpawnArea.WALK_ROOT_HEIGHT = 3 -- HumanoidRootPart height above the floor top when standing
SpawnArea.TAG = "StartPad"
SpawnArea.MARKET_TAG = "MarketPad"

local THICKNESS = 1
local EDGE_HEIGHT = 2
local EDGE_WIDTH = 1
local PAD_RAISE = 0.2
local SPAWN_SIZE = 12
local LABEL_DISTANCE = 150

-- Track 1's start, flattened: yaw only, at ground level (the local space every spawn-area and plot position uses)
local function base(startCFrame)
	local look = startCFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, -1)
	local p = Vector3.new(startCFrame.Position.X, 0, startCFrame.Position.Z)
	return CFrame.lookAt(p, p + flat)
end

SpawnArea.Base = base

-- Move the entire entrance (pad, meshes, boundaries, lights) together independently of the road.
function SpawnArea.PadBase(startCFrame)
	local c = SpawnArea.PAD_CENTER
	local front = SpawnArea.PAD_FRONT.Unit
	local position = Vector3.new(c.X, 0, c.Y)
	local facing = CFrame.lookAt(position, position - Vector3.new(front.X, 0, front.Y))
	local authoredCentre = (SpawnArea.PAD_MIN + SpawnArea.PAD_MAX) / 2
	return base(startCFrame) * facing * CFrame.new(-authoredCentre.X, 0, -authoredCentre.Y)
end

local function world(startCFrame, x, z, y)
	local p = base(startCFrame):PointToWorldSpace(Vector3.new(x, 0, z))
	return Vector3.new(p.X, y or SpawnArea.TOP_Y, p.Z)
end

local function rect(startCFrame, min, max)
	local lowX, highX, lowZ, highZ = math.huge, -math.huge, math.huge, -math.huge
	for _, x in { min.X, max.X } do
		for _, z in { min.Y, max.Y } do
			local p = world(startCFrame, x, z)
			lowX, highX = math.min(lowX, p.X), math.max(highX, p.X)
			lowZ, highZ = math.min(lowZ, p.Z), math.max(highZ, p.Z)
		end
	end
	return { Min = Vector3.new(lowX, SpawnArea.TOP_Y, lowZ), Max = Vector3.new(highX, SpawnArea.TOP_Y, highZ) }
end

-- World corners (Y = TOP_Y) of the floor and of the start platform.
function SpawnArea.Bounds(startCFrame)
	return {
		Area = rect(startCFrame, SpawnArea.AREA_MIN, SpawnArea.AREA_MAX),
		Pad = rect(SpawnArea.PadBase(startCFrame), SpawnArea.PAD_MIN, SpawnArea.PAD_MAX),
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
	local look = world(SpawnArea.PadBase(startCFrame), pad.X, pad.Y, y)
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
	-- Open only the low curb section crossed by the relocated platform.
	local padBounds = SpawnArea.Bounds(CFrame.new()).Pad
	if padBounds.Min.Z < amax.Y and padBounds.Max.Z > amax.Y - EDGE_WIDTH then
		local gapMin = math.max(amin.X, padBounds.Min.X - EDGE_WIDTH * 2)
		local gapMax = math.min(amax.X, padBounds.Max.X + EDGE_WIDTH * 2)
		if gapMax > gapMin then
			edges.EdgeNear = nil
			if gapMin > amin.X then
				edges.EdgeNearBefore = { Vector2.new(amin.X, amax.Y - EDGE_WIDTH), Vector2.new(gapMin, amax.Y) }
			end
			if gapMax < amax.X then
				edges.EdgeNear = { Vector2.new(gapMax, amax.Y - EDGE_WIDTH), Vector2.new(amax.X, amax.Y) }
			end
		end
	end
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

	local padFrame = SpawnArea.PadBase(startCFrame)
	local pad = slab(model, "StartPad", padFrame, SpawnArea.PAD_MIN, SpawnArea.PAD_MAX, top + PAD_RAISE, 1)
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

	-- Blender meshes are decorative; the original pad remains the touch trigger.
	local canopy = raceTemplate:Clone()
	canopy.Name = "RaceOverhang"
	local placement = padFrame * CFrame.new(0, top + PAD_RAISE, 0)
	for _, mesh in canopy:GetDescendants() do
		if mesh:IsA("BasePart") then
			mesh.CFrame = placement * mesh.CFrame
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanTouch = false
			mesh.CanQuery = false
			mesh.CastShadow = false
			if mesh:IsA("MeshPart") then
				mesh.DoubleSided = true
			end
		end
	end
	canopy.Parent = model

	-- Box boundaries cover rail gaps and column detail without snagging avatars.
	-- The hub entrance stays open from z=10..30; both 18.5-stud lanes stay clear.
	local boundaries = Instance.new("Folder")
	boundaries.Name = "RaceBoundaries"
	boundaries.Parent = model
	local function boundary(name, min, max, height)
		local collider = slab(boundaries, name, padFrame, min, max, top + PAD_RAISE + height, height)
		collider.Transparency = 1
		collider.CanTouch = false
		collider.CastShadow = false
	end
	boundary("LeftRail", Vector2.new(-21.85, 2), Vector2.new(-20.15, 38), 3.35)
	boundary("HubRailForward", Vector2.new(22.15, 2), Vector2.new(23.85, 10), 3.35)
	boundary("HubRailRear", Vector2.new(22.15, 30), Vector2.new(23.85, 38), 3.35)
	for _, x in { -20.5, 20.5 } do
		for _, z in { 7, 33 } do
			boundary(
				"Column_" .. x .. "_" .. z,
				Vector2.new(x - 1.65, z - 1.65),
				Vector2.new(x + 1.65, z + 1.65),
				12.75
			)
		end
	end

	-- Local, shadow-free lights leave the global Lighting/weather system intact.
	local padCentre = centre(SpawnArea.PAD_MIN, SpawnArea.PAD_MAX)
	for _, x in { -12, 0, 12 } do
		local mount = Instance.new("Attachment")
		mount.Name = "CanopyLight_" .. x
		mount.Position = Vector3.new(x - padCentre.X, 11.5 + pad.Size.Y / 2, 0)
		mount.Parent = pad
		local light = Instance.new("PointLight")
		light.Name = "RaceGlow"
		light.Color = Color3.fromRGB(80, 240, 255)
		light.Brightness = 1.2
		light.Range = 20
		light.Shadows = false
		light.Parent = mount
	end

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

	local market = slab(model, "MarketPad", startCFrame, Vector2.new(42, -76), Vector2.new(58, -64), top + 0.15, 0.25)
	market.Color = Color3.fromRGB(255, 190, 65)
	market.Material = Enum.Material.Neon
	CollectionService:AddTag(market, SpawnArea.MARKET_TAG)
	local marketSign = billboard:Clone()
	marketSign.Name = "MarketSign"
	marketSign.Text.Text = "MARKET"
	marketSign.Parent = market
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenMarket"
	prompt.ActionText = "Open Market"
	prompt.ObjectText = "Aura & Trail Market"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = market
	-- Keep the original market tag and interaction while the modular stalls frame it.
	market.Transparency = 1
	market.CanCollide = false
	market.CanTouch = false
	marketSign.Enabled = false
	prompt.Enabled = false -- the three vendor anchors open the same existing browser
	local marketCenter = MarketplaceBuilder.CENTER
	local marketplace = MarketplaceBuilder.Build(
		base(startCFrame)
			* CFrame.new(marketCenter.X, top, marketCenter.Y)
			* CFrame.Angles(0, math.rad(MarketplaceBuilder.ROTATION), 0)
	)
	marketplace.Parent = model
	-- Dimensional lettering replaces the pad label; cloned hub labels stay enabled.
	billboard.Enabled = false
	return model
end

return SpawnArea
