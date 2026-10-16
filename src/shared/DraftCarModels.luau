--!nonstrict
-- Rough stand-in models for the gamepass cars (docs/GAMEPASS_CARS_SPEC.md section 6, drafts/cars/*/DRAFT.md).
-- Ensure() adds them to ReplicatedStorage.CarModels only when no model of that name exists, so a real mesh with the
-- same name replaces them. Like the imported templates: pivot at the base centre, forward -Z, about 5 studs long.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DraftCarModels = {}

local function part(model, name, size, cframe, colour, material, shape)
	local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	if shape and shape ~= "Wedge" then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A dragon: body, legs, neck, horned head, tail, and Wing_L / Wing_R (pivot on the inner edge, for the flap).
local function wyvern()
	local m = Instance.new("Model")
	local scale, belly, glow = Color3.fromRGB(130, 22, 18), Color3.fromRGB(35, 20, 20), Color3.fromRGB(255, 120, 30)
	part(m, "Body", Vector3.new(1.6, 1.1, 2.6), CFrame.new(0, 1.35, 0), scale)
	part(m, "Belly", Vector3.new(1.3, 0.3, 2.2), CFrame.new(0, 0.8, 0), belly)
	part(m, "Seam", Vector3.new(0.2, 0.15, 2.4), CFrame.new(0, 1.95, 0), glow, Enum.Material.Neon)
	for _, leg in { { -0.6, -0.8 }, { 0.6, -0.8 }, { -0.6, 0.8 }, { 0.6, 0.8 } } do
		part(m, "Leg", Vector3.new(0.4, 0.75, 0.45), CFrame.new(leg[1], 0.38, leg[2]), belly)
	end
	part(m, "Neck", Vector3.new(0.7, 0.7, 1.1), CFrame.new(0, 1.9, -1.55) * CFrame.Angles(math.rad(30), 0, 0), scale)
	part(m, "Head", Vector3.new(0.9, 0.7, 0.9), CFrame.new(0, 2.3, -2.2), scale)
	part(
		m,
		"Snout",
		Vector3.new(0.7, 0.45, 0.6),
		CFrame.new(0, 2.15, -2.9) * CFrame.Angles(0, math.pi, 0),
		scale,
		nil,
		"Wedge"
	)
	for _, x in { -0.25, 0.25 } do
		part(m, "Eye", Vector3.new(0.15, 0.12, 0.1), CFrame.new(x, 2.45, -2.66), glow, Enum.Material.Neon)
		part(
			m,
			"Horn",
			Vector3.new(0.15, 0.6, 0.15),
			CFrame.new(x, 2.85, -1.95) * CFrame.Angles(math.rad(-40), 0, 0),
			belly
		)
	end
	local mouth = part(m, "Mouth", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 2.1, -3.2), glow)
	mouth.Transparency = 1
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 6
	fire.Color = glow
	fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
	fire.Parent = mouth
	part(m, "Tail1", Vector3.new(0.8, 0.6, 1.0), CFrame.new(0, 1.3, 1.7), scale)
	part(m, "Tail2", Vector3.new(0.5, 0.4, 0.9), CFrame.new(0, 1.2, 2.4) * CFrame.Angles(math.rad(-10), 0, 0), scale)
	part(m, "TailFin", Vector3.new(0.1, 0.7, 0.6), CFrame.new(0, 1.3, 2.9), glow, Enum.Material.Neon)
	for _, side in { -1, 1 } do
		-- Raised in a V so the span stays inside the skin size budget (docs/VEHICLE_SKINS_SPEC.md)
		local hinge = CFrame.new(side * 0.75, 1.9, -0.1) * CFrame.Angles(0, 0, side * math.rad(28))
		local wing = part(
			m,
			side < 0 and "Wing_L" or "Wing_R",
			Vector3.new(1.9, 0.12, 1.8),
			hinge * CFrame.new(side * 0.95, 0, 0),
			scale
		)
		wing.PivotOffset = CFrame.new(-side * 0.95, 0, 0) -- the inner edge: Client/BestRollView flaps it from here
	end
	m.WorldPivot = CFrame.new()
	return m
end

-- A black hypercar around a small black hole: the void_racer body in black, a dark core and accretion rings.
local function singularity(templates)
	local source = templates:FindFirstChild("void_racer")
	if not (source and source:IsA("Model")) then
		return nil
	end
	local m = source:Clone()
	m:PivotTo(CFrame.new())
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.Material ~= Enum.Material.Glass then
			p.Color = Color3.fromRGB(12, 12, 18)
		end
	end
	local _, size = m:GetBoundingBox()
	local core = size.Y + 0.9
	local ring, rim = Color3.fromRGB(255, 150, 60), Color3.fromRGB(200, 230, 255)
	part(m, "Core", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, core, 0), Color3.new(0, 0, 0), nil, Enum.PartType.Ball)
	part(
		m,
		"Disc",
		Vector3.new(0.06, 2.6, 2.6),
		CFrame.new(0, core, 0) * CFrame.Angles(math.rad(15), 0, math.rad(90)),
		ring,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Halo",
		Vector3.new(0.04, 1.6, 1.6),
		CFrame.new(0, core, 0) * CFrame.Angles(0, 0, math.rad(20)),
		rim,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	m.WorldPivot = CFrame.new()
	return m
end

local BUILDERS = { ember_wyvern = wyvern, singularity = singularity }

function DraftCarModels.Ensure()
	local templates = ReplicatedStorage:FindFirstChild("CarModels")
	if not templates then
		return
	end
	for name, build in BUILDERS do
		if not templates:FindFirstChild(name) then
			local model = build(templates)
			if model then
				model.Name = name
				model.Parent = templates
			end
		end
	end
end

return DraftCarModels
