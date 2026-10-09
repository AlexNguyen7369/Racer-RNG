--!nonstrict
-- Builds the workshop plots and the workshops on them (docs/WORKSHOP_SPEC.md section 2), procedurally like
-- CarFactory: placeholder look until real models exist. Every part is anchored. A plot CFrame
-- (Workshop.PlotCFrame) sits at the plot centre on the floor top, LookVector = the open front (toward the hub), so in
-- plot space the front edge is at z = -PLOT_SIZE / 2 and the back at +PLOT_SIZE / 2.

local CollectionService = game:GetService("CollectionService")

local WorkshopConfig = require(script.Parent.WorkshopConfig)

local WorkshopBuilder = {}

local PLOT_COLOR = Color3.fromRGB(105, 50, 170) -- a shade darker than the spawn floor
local FLOOR_COLOR = Color3.fromRGB(150, 150, 155)
local WALL_COLOR = Color3.fromRGB(70, 75, 85)
local TRIM_COLOR = Color3.fromRGB(255, 200, 40)
local BENCH_COLOR = Color3.fromRGB(120, 80, 45)
local TYRE_COLOR = Color3.fromRGB(25, 25, 25)
local UPGRADE_COLOR = Color3.fromRGB(70, 190, 255)

local BASE_HEIGHT = 0.2
local BASE_LIFT = 0.05 -- base top above the floor top, so the two never z-fight
local WALL_HEIGHT = 12
local WALL_THICKNESS = 1
local SHELL = 36 -- the workshop's square footprint (walls on three sides, front open)
local SIGN_HEIGHT = 16

local function part(model, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function billboard(parent, name, offset, size)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = WorkshopConfig.SIGN_DISTANCE
	gui.AlwaysOnTop = false
	gui.Parent = parent
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Parent = gui
	return text
end

-- An empty plot: `Plot_<index>` with a `Base` slab and a "EMPTY PLOT" `Sign`. Attribute Owner = 0, tag WorkshopPlot.
function WorkshopBuilder.BuildPlot(index, plotCFrame)
	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	local size = WorkshopConfig.PLOT_SIZE
	local base = part(
		model,
		"Base",
		Vector3.new(size, BASE_HEIGHT, size),
		plotCFrame * CFrame.new(0, BASE_LIFT - BASE_HEIGHT / 2, 0),
		PLOT_COLOR
	)
	local text = billboard(base, "Sign", Vector3.new(0, SIGN_HEIGHT, 0), UDim2.fromOffset(260, 60))
	text.Text = WorkshopConfig.EMPTY_TEXT
	model.PrimaryPart = base
	model:SetAttribute("Index", index)
	model:SetAttribute("Owner", 0)
	CollectionService:AddTag(model, WorkshopConfig.TAG)
	return model
end

-- Sets a plot's sign: the owner's name, or EMPTY_TEXT when `ownerName` is nil.
function WorkshopBuilder.SetSign(plotModel, ownerName)
	local base = plotModel:FindFirstChild("Base")
	local sign = base and base:FindFirstChild("Sign")
	local text = sign and sign:FindFirstChild("Text")
	if text then
		text.Text = ownerName and (ownerName .. "'s Workshop") or WorkshopConfig.EMPTY_TEXT
	end
end

-- The workshop of a level on a plot (level 1 = the starter workshop): a `Workshop` model with a concrete floor,
-- back and side walls (front open toward the hub), roof beams, a workbench, a tyre stack, a neon outline around the
-- gain zone and the `Zone` part itself (invisible, no collision, touch or query) with the `Rate` billboard.
function WorkshopBuilder.BuildWorkshop(level, plotCFrame)
	local model = Instance.new("Model")
	model.Name = "Workshop"
	model:SetAttribute("Level", level)
	local lift = BASE_LIFT
	local half = SHELL / 2
	local function at(x, y, z)
		return plotCFrame * CFrame.new(x, lift + y, z)
	end

	local floor =
		part(model, "Floor", Vector3.new(SHELL, 0.2, SHELL), at(0, 0.1, 0), FLOOR_COLOR, Enum.Material.Concrete)
	local wallY = 0.2 + WALL_HEIGHT / 2
	part(
		model,
		"BackWall",
		Vector3.new(SHELL, WALL_HEIGHT, WALL_THICKNESS),
		at(0, wallY, half - WALL_THICKNESS / 2),
		WALL_COLOR,
		Enum.Material.Metal
	)
	for _, side in { -1, 1 } do
		part(
			model,
			side < 0 and "LeftWall" or "RightWall",
			Vector3.new(WALL_THICKNESS, WALL_HEIGHT, SHELL),
			at(side * (half - WALL_THICKNESS / 2), wallY, 0),
			WALL_COLOR,
			Enum.Material.Metal
		)
	end
	-- Roof frame: beams only, so the camera never clips a roof
	for i, z in { -half + 1, 0, half - 1 } do
		part(
			model,
			"RoofBeam" .. i,
			Vector3.new(SHELL, 1, 1),
			at(0, 0.2 + WALL_HEIGHT + 0.5, z),
			TRIM_COLOR,
			Enum.Material.Metal
		)
	end

	-- Props against the back wall
	part(model, "Workbench", Vector3.new(10, 3, 3), at(-8, 1.7, half - 3), BENCH_COLOR, Enum.Material.Wood)
	for i = 1, 3 do
		local tyre = part(
			model,
			"Tyre" .. i,
			Vector3.new(1.4, 3.6, 3.6),
			at(10, 0.2 + 0.7 + (i - 1) * 1.4, half - 4) * CFrame.Angles(0, 0, math.rad(90)),
			TYRE_COLOR
		)
		tyre.Shape = Enum.PartType.Cylinder
	end

	-- The gain zone and its neon outline on the floor
	local zs = WorkshopConfig.ZONE_SIZE
	local zone = part(model, "Zone", zs, at(0, zs.Y / 2, 0), TRIM_COLOR)
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanTouch = false
	zone.CanQuery = false
	zone.CastShadow = false
	for name, spec in
		{
			LineFront = { Vector3.new(zs.X, 0.1, 0.4), Vector3.new(0, 0, -zs.Z / 2) },
			LineBack = { Vector3.new(zs.X, 0.1, 0.4), Vector3.new(0, 0, zs.Z / 2) },
			LineLeft = { Vector3.new(0.4, 0.1, zs.Z), Vector3.new(-zs.X / 2, 0, 0) },
			LineRight = { Vector3.new(0.4, 0.1, zs.Z), Vector3.new(zs.X / 2, 0, 0) },
		}
	do
		local line = part(model, name, spec[1], at(spec[2].X, 0.25, spec[2].Z), TRIM_COLOR, Enum.Material.Neon)
		line.CanCollide = false
	end
	local rate = billboard(zone, "Rate", Vector3.new(0, 2, 0), UDim2.fromOffset(200, 40))
	rate.Text = ""
	rate.TextColor3 = TRIM_COLOR

	-- The upgrade interaction is implemented separately, but every owned workshop
	-- gets a readable world target now. It sits just beyond the open front, inside
	-- the plot, so it does not block the workshop zone or the hub approach.
	local upgrade =
		part(model, "UpgradePad", Vector3.new(10, 0.25, 6), at(0, 0.125, -half - 3), UPGRADE_COLOR, Enum.Material.Neon)
	CollectionService:AddTag(upgrade, "UpgradePad")
	local upgradeSign = billboard(upgrade, "UpgradeSign", Vector3.new(0, 2.2, 0), UDim2.fromOffset(180, 44))
	upgradeSign.Text = "UPGRADE"
	upgradeSign.TextColor3 = UPGRADE_COLOR

	model.PrimaryPart = floor
	return model
end

return WorkshopBuilder
