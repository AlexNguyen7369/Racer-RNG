--!nonstrict
-- Builds workshop plots with a Blender-authored garage and unchanged gameplay targets.
-- Every part is anchored. A plot CFrame
-- (Workshop.PlotCFrame) sits at the plot centre on the floor top, LookVector = the open front (toward the hub), so in
-- plot space the front edge is at z = -PLOT_SIZE / 2 and the back at +PLOT_SIZE / 2.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorkshopConfig = require(script.Parent.WorkshopConfig)
local WorkshopMeshAssets = require(script.Parent.WorkshopMeshAssets)

-- Prepare once during module loading, before assignment or a purchase can run.
-- Rojo hot updates can leave existing MeshParts with empty MeshContent. A mesh
-- id/size in XML alone does not guarantee the native geometry exists in Studio.
local garageTemplate = ReplicatedStorage:WaitForChild("RacingGarage"):Clone()
for _, mesh in garageTemplate:GetDescendants() do
	if mesh:IsA("MeshPart") then
		local assetId = WorkshopMeshAssets[mesh.Name]
		assert(assetId, "Missing workshop mesh asset: " .. mesh.Name)
		if mesh.MeshId ~= assetId or mesh.MeshSize.Magnitude == 0 then
			local texture = mesh.TextureID
			local loaded = AssetService:CreateMeshPartAsync(Content.fromUri(assetId), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
			})
			mesh:ApplyMesh(loaded)
			mesh.TextureID = texture
			loaded:Destroy()
		end
		assert(mesh.MeshId == assetId and mesh.MeshSize.Magnitude > 0, "Workshop mesh failed to load: " .. mesh.Name)
	end
end

local WorkshopBuilder = {}

local PLOT_COLOR = Color3.fromRGB(105, 50, 170) -- a shade darker than the spawn floor
local FLOOR_COLOR = Color3.fromRGB(150, 150, 155)
local TRIM_COLOR = Color3.fromRGB(255, 200, 40)
local UPGRADE_COLOR = Color3.fromRGB(70, 190, 255)

local BASE_HEIGHT = 0.2
local BASE_LIFT = 0.05 -- base top above the floor top, so the two never z-fight
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
-- Blender garage (front open toward the hub), perimeter racing props, a neon outline around the
-- gain zone and the `Zone` part itself (invisible, no collision, touch or query).
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
	-- The imported template faces +Z; turn it toward plot-local -Z.
	-- Mesh groups are decorative only. The original Floor remains the walk surface.
	local visual = garageTemplate:Clone()
	visual.Name = "Visual"
	local placement = at(0, 0.2, 0) * CFrame.Angles(0, math.pi, 0)
	for _, mesh in visual:GetDescendants() do
		if mesh:IsA("BasePart") then
			mesh.CFrame = placement * mesh.CFrame
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanTouch = false
			mesh.CanQuery = false
			if mesh:IsA("MeshPart") then
				mesh.DoubleSided = true
			end
		end
	end
	visual.Parent = model
	-- Preserve the original three wall collision boundaries beneath the mesh shell.
	local walls = {
		BackWall = { Vector3.new(SHELL, 12, 1), Vector3.new(0, 6.2, half - 0.5) },
		LeftWall = { Vector3.new(1, 12, SHELL), Vector3.new(-half + 0.5, 6.2, 0) },
		RightWall = { Vector3.new(1, 12, SHELL), Vector3.new(half - 0.5, 6.2, 0) },
	}
	for name, spec in walls do
		local wall = part(model, name, spec[1], at(spec[2].X, spec[2].Y, spec[2].Z), FLOOR_COLOR)
		wall.Transparency = 1
	end
	-- Three local, shadow-free lights; no changes to global Lighting/weather.
	for _, x in { -10, 0, 10 } do
		local mount = Instance.new("Attachment")
		mount.Name = "TaskLight"
		mount.Position = Vector3.new(x, 10.3, 14)
		mount.Parent = floor
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 202, 126)
		light.Brightness = 1.4
		light.Range = 18
		light.Shadows = false
		light.Parent = mount
	end

	-- Caged entrance lantern makes the garage mouth readable from the hub.
	local lantern = Instance.new("Attachment")
	lantern.Name = "EntranceLantern"
	lantern.Position = Vector3.new(0, 10.7, -16.8)
	lantern.Parent = floor
	local entranceLight = Instance.new("PointLight")
	entranceLight.Color = Color3.fromRGB(255, 183, 76)
	entranceLight.Brightness = 1.6
	entranceLight.Range = 15
	entranceLight.Shadows = false
	entranceLight.Parent = lantern

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
