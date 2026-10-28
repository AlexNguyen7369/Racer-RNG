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
local LeaderboardConfig = require(script.Parent.LeaderboardConfig)
local PassCarConfig = require(script.Parent.PassCarConfig)
local CarCatalog = require(script.Parent.CarCatalog)
local CheckpointConfig = require(script.Parent.CheckpointConfig)
local UiTheme = require(script.Parent.UiTheme)
local Players = game:GetService("Players")

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
SpawnArea.HUB_MIN = Vector2.new(24, -100) -- the part of the floor kept free of plots: spawn, StartPad side, Best Roll pedestal
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

local THICKNESS = 3 -- reaches the Baseplate top (y = -2) so the floor never shows a gap underneath
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
	text.Font = UiTheme.Font
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	UiTheme.Stroke(text, 2)
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

	-- Global leaderboard signs (docs/LEADERBOARD_SPEC.md): along the hub's near edge, facing the spawn. The server
	-- (LeaderboardService) writes the rows.
	local boards = Instance.new("Model")
	boards.Name = "Leaderboards"
	local size = LeaderboardConfig.SIGN_SIZE
	for i, board in LeaderboardConfig.Boards do
		local sign = Instance.new("Part")
		sign.Name = "Board_" .. board.Id
		sign.Anchored = true
		sign.Size = size
		sign.CFrame = base(startCFrame)
			* CFrame.new(LeaderboardConfig.SIGN_X[i], top + size.Y / 2, LeaderboardConfig.SIGN_Z)
		sign.Color = Color3.fromRGB(28, 22, 48)
		sign.Material = Enum.Material.SmoothPlastic
		sign.TopSurface = Enum.SurfaceType.Smooth
		sign.BottomSurface = Enum.SurfaceType.Smooth
		sign.Parent = boards
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Board"
		gui.Face = Enum.NormalId.Front -- the part's front (-Z) looks at the hub centre
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Parent = sign
		local function line(name, order, height, colour, font)
			local label = Instance.new("TextLabel")
			label.Name = name
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, -24, height, 0)
			label.Position = UDim2.new(0, 12, order, 0)
			label.Font = font
			label.TextScaled = true
			label.TextColor3 = colour
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = ""
			UiTheme.Stroke(label, 2)
			label.Parent = gui
			return label
		end
		local title = line("Title", 0.02, 0.14, Color3.fromRGB(255, 214, 90), UiTheme.Font)
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.Text = board.Title
		for row = 1, LeaderboardConfig.TOP_N do
			line("Row" .. row, 0.18 + (row - 1) * 0.08, 0.07, Color3.new(1, 1, 1), UiTheme.Font)
		end
	end
	boards.Parent = model

	-- Showcase row: the Best Roll Ever pedestal (docs/LEADERBOARD_SPEC.md 3a) between the two gamepass car
	-- pedestals (docs/GAMEPASS_CARS_SPEC.md 5). The servers fill the labels and put a car on each CarMount;
	-- Client/BestRollView turns them.
	local cfg = LeaderboardConfig.BEST_ROLL
	local blue, cream = Color3.fromRGB(40, 70, 190), Color3.fromRGB(255, 240, 170)
	-- A round platform: returns its Pedestal part (with CarMount on top) and a Stats billboard above it
	local function pedestal(parent, x, z, radius, statsSize, statsHeight, textDistance)
		-- name, bottom and top as fractions of HEIGHT, radius inset (the stripe sits in a groove)
		for _, layer in
			{ { "Pedestal", 0, 0.4, 0, blue }, { "Stripe", 0.4, 0.6, 0.2, cream }, { "Top", 0.6, 1, 0, blue } }
		do
			local disc = Instance.new("Part")
			disc.Name = layer[1]
			disc.Shape = Enum.PartType.Cylinder -- the axis is the part's X: turned upright below
			disc.Anchored = true
			local diameter = (radius - layer[4]) * 2
			disc.Size = Vector3.new((layer[3] - layer[2]) * cfg.HEIGHT, diameter, diameter)
			disc.CFrame = base(startCFrame)
				* CFrame.new(x, top + (layer[2] + layer[3]) / 2 * cfg.HEIGHT, z)
				* CFrame.Angles(0, 0, math.rad(90))
			disc.Color = layer[5]
			disc.Material = Enum.Material.SmoothPlastic
			disc.TopSurface = Enum.SurfaceType.Smooth
			disc.BottomSurface = Enum.SurfaceType.Smooth
			disc.Parent = parent
		end
		local part = parent.Pedestal
		local mount = Instance.new("Attachment")
		mount.Name = "CarMount"
		mount.Parent = part
		mount.WorldCFrame = base(startCFrame) * CFrame.new(x, top + cfg.HEIGHT, z)
		local stats = Instance.new("BillboardGui")
		stats.Name = "Stats"
		stats.Size = statsSize -- studs: the text keeps its size in the world
		stats.Adornee = mount -- upright, unlike the turned cylinder: the offset below points straight up
		stats.StudsOffsetWorldSpace = Vector3.new(0, statsHeight, 0)
		stats.MaxDistance = textDistance
		stats.LightInfluence = 0
		stats.Parent = part
		return part, stats
	end
	local function stat(stats, name, y, height, colour, value)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, height)
		label.Font = UiTheme.Font
		label.TextScaled = true
		label.TextColor3 = colour
		UiTheme.Stroke(label, 2)
		label.Text = value
		label.Parent = stats
	end

	local best = Instance.new("Model")
	best.Name = "BestRoll"
	local _, bestStats = pedestal(best, cfg.X, cfg.Z, cfg.RADIUS, UDim2.fromScale(36, 11), 15, cfg.TEXT_DISTANCE)
	stat(bestStats, "Title", 0, 0.4, Color3.new(1, 1, 1), "BEST ROLL EVER")
	stat(bestStats, "Odds", 0.4, 0.22, Color3.fromRGB(255, 214, 90), LeaderboardConfig.NO_DATA)
	stat(bestStats, "Car", 0.62, 0.2, Color3.new(1, 1, 1), "")
	stat(bestStats, "Player", 0.82, 0.18, Color3.fromRGB(200, 220, 255), "")
	best.Parent = model

	local passCars = Instance.new("Model")
	passCars.Name = "PassCars"
	for _, entry in PassCarConfig.Pedestals do
		local spec = CarCatalog.Get(entry.CarId)
		local stand = Instance.new("Model")
		stand.Name = "Pass_" .. entry.CarId
		local part, stats = pedestal(
			stand,
			entry.X,
			entry.Z,
			PassCarConfig.RADIUS,
			UDim2.fromScale(14, 4),
			8,
			PassCarConfig.TEXT_DISTANCE
		)
		stat(stats, "Title", 0, 0.6, Color3.new(1, 1, 1), spec and spec.Name or entry.CarId)
		stat(stats, "Tag", 0.6, 0.4, Color3.fromRGB(120, 255, 170), "GAMEPASS")
		local buy = Instance.new("ProximityPrompt")
		buy.Name = "Buy"
		buy.ObjectText = spec and spec.Name or entry.CarId
		buy.ActionText = (spec and (spec.GamepassId or 0) > 0) and "Unlock" or "Coming soon"
		buy.KeyboardKeyCode = Enum.KeyCode.E
		buy.HoldDuration = 0
		buy.MaxActivationDistance = PassCarConfig.PROMPT_DISTANCE
		buy.RequiresLineOfSight = false
		buy.Parent = part
		stand.Parent = passCars
	end
	passCars.Parent = model

	-- Checkpoints NPC (docs/CHECKPOINT_SPEC.md): a rig on a purple ring; its prompt opens Client/CheckpointUi.
	local npc = Instance.new("Model")
	npc.Name = "CheckpointNpc"
	local spot = CheckpointConfig.NPC_POS
	local here = world(startCFrame, spot.X, spot.Y, top)
	local face = world(startCFrame, CheckpointConfig.NPC_FACE.X, CheckpointConfig.NPC_FACE.Y, top)
	local stand = CFrame.lookAt(here, face)
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 9, 9)
	ring.CFrame = stand * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(190, 90, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.Parent = npc
	-- Only the server can build a rig from a description; anywhere else the ring and prompt still work.
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if ok and rig then
		rig.Name = "Rig"
		for _, part in rig:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		local humanoid = rig:FindFirstChildOfClass("Humanoid")
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		rig:PivotTo(stand * CFrame.new(0, 0.3 + humanoid.HipHeight + rig.PrimaryPart.Size.Y / 2, 0))
		rig.Parent = npc
	end
	local anchor = Instance.new("Part")
	anchor.Name = "PromptAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = stand * CFrame.new(0, 3, 0)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.Parent = npc
	local open = Instance.new("ProximityPrompt")
	open.Name = "OpenCheckpoints"
	open.ActionText = "Checkpoints"
	open.ObjectText = "Choose your start"
	open.KeyboardKeyCode = Enum.KeyCode.E
	open.HoldDuration = 0
	open.MaxActivationDistance = CheckpointConfig.PROMPT_DISTANCE
	open.RequiresLineOfSight = false
	open.Parent = anchor
	local title = Instance.new("BillboardGui")
	title.Name = "Title"
	title.Size = UDim2.fromScale(10, 2.4)
	title.StudsOffset = Vector3.new(0, 4.2, 0)
	title.MaxDistance = CheckpointConfig.TEXT_DISTANCE
	title.Parent = anchor
	for i, line in
		{
			{ "Name", "Checkpoints", Color3.new(1, 1, 1) },
			{ "Sub", "Choose your start", Color3.fromRGB(200, 140, 255) },
		}
	do
		local label = Instance.new("TextLabel")
		label.Name = line[1]
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, (i - 1) * 0.58)
		label.Size = UDim2.fromScale(1, i == 1 and 0.58 or 0.42)
		label.Font = UiTheme.Font
		label.TextScaled = true
		label.Text = line[2]
		label.TextColor3 = line[3]
		UiTheme.Stroke(label, 2)
		label.Parent = title
	end
	npc.PrimaryPart = anchor
	npc.Parent = model
	return model
end

return SpawnArea
