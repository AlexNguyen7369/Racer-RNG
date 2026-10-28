--!nonstrict
-- A small live 3D preview of a track's biome in a ViewportFrame (docs/CHECKPOINT_SPEC.md section 4): its ground, a
-- strip of road under its gate colours and 2-3 of its own props from Shared/BiomeThemes. Presentation only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Themes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BiomeThemes"))

local BiomePreview = {}

local MAX_PROP_HEIGHT = 16 -- studs: tall landmarks (skyscrapers) are shrunk to fit the shot
local FOCUS = Vector3.new(0, 5, 0)
local ORBIT_RADIUS, ORBIT_HEIGHT = 46, 24
local TRACK_LEAD, TRACK_ORBIT, TRACK_HEIGHT = 25, 70, 38 -- studs: real-track shot (placeholders)

-- Sky behind each biome (placeholders); anything unknown gets the day sky.
local SKY = {
	Speedway = Color3.fromRGB(120, 190, 255),
	Forest = Color3.fromRGB(140, 200, 235),
	Docks = Color3.fromRGB(150, 185, 215),
	Suburb = Color3.fromRGB(135, 205, 255),
	PirateCoast = Color3.fromRGB(110, 205, 240),
	City = Color3.fromRGB(70, 60, 120),
	Desert = Color3.fromRGB(250, 205, 140),
	Snow = Color3.fromRGB(200, 225, 245),
	Volcano = Color3.fromRGB(90, 35, 40),
	Space = Color3.fromRGB(14, 12, 40),
}

local function block(parent, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- One theme prop at `base` (its base centre), shrunk so it is at most MAX_PROP_HEIGHT tall.
local function prop(parent, def, base)
	local k = math.min(1, MAX_PROP_HEIGHT / math.max(def.Size.Y, 1))
	for _, p in def.Parts do
		local part = block(parent, p.Size * k, base * CFrame.new(p.Pos * k), p.Color, p.Material)
		if p.Shape then
			part.Shape = p.Shape
		end
	end
end

local function first(layer, i)
	local props = layer and layer.Props
	return props and props[((i - 1) % #props) + 1] or nil
end

-- Builds the preview of `biome` into `viewport` (replacing anything there). Returns a function that turns the
-- camera to `angle` radians around the scene.
function BiomePreview.Build(viewport, biome)
	viewport:ClearAllChildren()
	local theme = Themes[biome] or {}
	viewport.BackgroundColor3 = SKY[biome] or SKY.Speedway
	viewport.Ambient = Color3.fromRGB(170, 170, 180)
	viewport.LightColor = Color3.fromRGB(255, 248, 235)
	viewport.LightDirection = Vector3.new(-1, -2, -0.6)

	local scene = Instance.new("Model")
	scene.Name = "Scene"
	local ground = theme.Ground or { Color = Color3.fromRGB(74, 112, 72), Material = Enum.Material.Grass }
	block(scene, Vector3.new(64, 1, 64), CFrame.new(0, -0.5, 0), ground.Color, ground.Material)
	block(scene, Vector3.new(14, 0.2, 64), CFrame.new(0, 0.1, 0), Color3.fromRGB(70, 74, 84), Enum.Material.Asphalt)
	for z = -28, 28, 8 do
		block(scene, Vector3.new(0.6, 0.22, 3), CFrame.new(0, 0.12, z), Color3.fromRGB(235, 235, 235))
	end

	local gate = theme.Gate
	if gate then
		block(scene, Vector3.new(1.6, 14, 1.6), CFrame.new(-8.5, 7, 6), gate.Color, gate.Material)
		block(scene, Vector3.new(1.6, 14, 1.6), CFrame.new(8.5, 7, 6), gate.Color, gate.Material)
		block(scene, Vector3.new(18.6, 2.2, 1.8), CFrame.new(0, 14, 6), gate.Color, gate.Material)
		if gate.Glow then
			block(scene, Vector3.new(16, 0.4, 2), CFrame.new(0, 12.8, 6), gate.Glow, Enum.Material.Neon)
		end
	end
	local landmark = first(theme.Landmarks, 1)
	if landmark then
		prop(scene, landmark, CFrame.new(-19, 0, -12) * CFrame.Angles(0, math.rad(90), 0))
	end
	for i, z in { -18, 2, 20 } do
		local def = first(theme.Rhythm, i)
		if def then
			prop(scene, def, CFrame.new(12, 0, z) * CFrame.Angles(0, math.rad(-90), 0))
		end
	end
	scene.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local function turn(angle)
		local eye = FOCUS + Vector3.new(math.sin(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.cos(angle) * ORBIT_RADIUS)
		camera.CFrame = CFrame.lookAt(eye, FOCUS)
	end
	turn(math.rad(35))
	return turn
end

-- The real scenery around track `name`'s start gate, baked by the server (Shared/TrackPreviews), in `viewport`;
-- falls back to Build from the theme data while the bake has not arrived. Returns the same turn function.
function BiomePreview.FromTrack(viewport, name, biome)
	local folder = ReplicatedStorage:FindFirstChild("TrackPreviews")
	local source = folder and folder:FindFirstChild(name)
	local focus = source and source:GetAttribute("Focus")
	if not focus then
		return BiomePreview.Build(viewport, biome)
	end
	viewport:ClearAllChildren()
	viewport.BackgroundColor3 = SKY[biome] or SKY.Speedway
	viewport.Ambient = Color3.fromRGB(170, 170, 180)
	viewport.LightColor = Color3.fromRGB(255, 248, 235)
	viewport.LightDirection = Vector3.new(-1, -2, -0.6)
	source:Clone().Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 50
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	-- Orbit a point just past the gate, looking down the road the car takes.
	local centre = (focus * CFrame.new(0, 0, -TRACK_LEAD)).Position
	local function turn(angle)
		local offset =
			focus:VectorToWorldSpace(Vector3.new(math.sin(angle) * TRACK_ORBIT, 0, math.cos(angle) * TRACK_ORBIT))
		camera.CFrame = CFrame.lookAt(centre + offset + Vector3.new(0, TRACK_HEIGHT, 0), centre)
	end
	turn(math.rad(35))
	return turn
end

return BiomePreview
