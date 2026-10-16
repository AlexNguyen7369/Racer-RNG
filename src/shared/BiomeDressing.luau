--!nonstrict
-- Deterministic, non-colliding procedural scenery for numbered biome tracks.

local BiomeDressing = {}

local function prop(parent, name, size, cf, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

local function sample(layout, origin, index, side, distance)
	local point = layout.Waypoints[index]
	local before = layout.Waypoints[math.max(1, index - 1)]
	local after = layout.Waypoints[math.min(#layout.Waypoints, index + 1)]
	local tangent = Vector3.new(after.X - before.X, 0, after.Z - before.Z)
	if tangent.Magnitude < 1e-4 then
		tangent = Vector3.new(0, 0, -1)
	end
	tangent = tangent.Unit
	local right = Vector3.new(-tangent.Z, 0, tangent.X)
	local localPoint = point + right * side * distance
	local worldPoint = origin:PointToWorldSpace(localPoint)
	local worldTangent = origin:VectorToWorldSpace(tangent)
	return worldPoint, CFrame.lookAt(worldPoint, worldPoint + worldTangent)
end

local function indices(layout)
	local step = math.max(1, math.floor(#layout.Waypoints / 10))
	local out = {}
	for i = 2, #layout.Waypoints - 1, step do
		table.insert(out, i)
	end
	return out
end

local function city(folder, layout, origin)
	local colors = {
		Building = Color3.fromRGB(35, 42, 70),
		Window = Color3.fromRGB(80, 220, 255),
		Light = Color3.fromRGB(255, 80, 190),
	}
	for n, i in ipairs(indices(layout)) do
		for _, side in { -1, 1 } do
			local _, cf = sample(layout, origin, i, side, layout.Width / 2 + 42)
			local height = 24 + (n % 4) * 12
			prop(
				folder,
				"Tower_" .. n .. "_" .. side,
				Vector3.new(22, height, 30),
				cf * CFrame.new(0, height / 2, 0),
				colors.Building,
				Enum.Material.Concrete
			)
			prop(
				folder,
				"Window_" .. n .. "_" .. side,
				Vector3.new(22.2, 2, 2),
				cf * CFrame.new(0, height * 0.65, -15.2),
				colors.Window,
				Enum.Material.Neon
			)
		end
		local _, sign = sample(layout, origin, i, n % 2 == 0 and 1 or -1, layout.Width / 2 + 24)
		prop(
			folder,
			"Streetlight_" .. n,
			Vector3.new(1, 16, 1),
			sign * CFrame.new(0, 8, 0),
			colors.Light,
			Enum.Material.Neon
		)
	end
end

local function desert(folder, layout, origin)
	local rock = Color3.fromRGB(156, 91, 48)
	local sand = Color3.fromRGB(224, 177, 92)
	for n, i in ipairs(indices(layout)) do
		for _, side in { -1, 1 } do
			local point, cf = sample(layout, origin, i, side, layout.Width / 2 + 38 + (n % 3) * 10)
			local h = 10 + (n % 4) * 5
			prop(
				folder,
				"Mesa_" .. n .. "_" .. side,
				Vector3.new(28 + n % 3 * 8, h, 24),
				cf * CFrame.new(0, h / 2, 0),
				rock,
				Enum.Material.Sandstone
			)
			prop(
				folder,
				"Dune_" .. n .. "_" .. side,
				Vector3.new(38, 3, 20),
				CFrame.new(point + Vector3.new(0, 1.5, 0)),
				sand,
				Enum.Material.Sand
			)
		end
	end
end

local function snow(folder, layout, origin)
	local snowColor = Color3.fromRGB(235, 248, 255)
	local pine = Color3.fromRGB(35, 100, 84)
	for n, i in ipairs(indices(layout)) do
		for _, side in { -1, 1 } do
			local point, cf = sample(layout, origin, i, side, layout.Width / 2 + 38)
			local h = 18 + (n % 3) * 5
			prop(
				folder,
				"Snowbank_" .. n .. "_" .. side,
				Vector3.new(30, 5, 22),
				CFrame.new(point + Vector3.new(0, 2.5, 0)),
				snowColor,
				Enum.Material.Snow
			)
			prop(
				folder,
				"Pine_" .. n .. "_" .. side,
				Vector3.new(10, h, 10),
				cf * CFrame.new(0, h / 2, 14),
				pine,
				Enum.Material.Wood,
				Enum.PartType.Cylinder
			)
		end
	end
end

local function volcano(folder, layout, origin)
	local basalt = Color3.fromRGB(42, 38, 48)
	local lava = Color3.fromRGB(255, 72, 18)
	for n, i in ipairs(indices(layout)) do
		for _, side in { -1, 1 } do
			local _, cf = sample(layout, origin, i, side, layout.Width / 2 + 40)
			local h = 14 + (n % 4) * 4
			prop(
				folder,
				"Basalt_" .. n .. "_" .. side,
				Vector3.new(24, h, 24),
				cf * CFrame.new(0, h / 2, 0),
				basalt,
				Enum.Material.Basalt
			)
			prop(
				folder,
				"Lava_" .. n .. "_" .. side,
				Vector3.new(26, 0.5, 8),
				cf * CFrame.new(0, 0.3, 16),
				lava,
				Enum.Material.Neon
			)
		end
	end
end

local function space(folder, layout, origin)
	local metal = Color3.fromRGB(80, 95, 130)
	local cyan = Color3.fromRGB(80, 240, 255)
	for n, i in ipairs(indices(layout)) do
		for _, side in { -1, 1 } do
			local _, cf = sample(layout, origin, i, side, layout.Width / 2 + 42)
			local h = 22 + (n % 3) * 8
			prop(
				folder,
				"OrbitalPylon_" .. n .. "_" .. side,
				Vector3.new(8, h, 8),
				cf * CFrame.new(0, h / 2, 0),
				metal,
				Enum.Material.Metal
			)
			prop(
				folder,
				"OrbitalLight_" .. n .. "_" .. side,
				Vector3.new(10, 1, 2),
				cf * CFrame.new(0, h * 0.72, -5),
				cyan,
				Enum.Material.Neon
			)
		end
	end
end

function BiomeDressing.Build(model, layout, spec, origin)
	local biome = spec.Biome
	if type(biome) ~= "string" then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Environment"
	folder.Parent = model
	model:SetAttribute("Biome", biome)
	if biome == "City" then
		city(folder, layout, origin)
	elseif biome == "Desert" then
		desert(folder, layout, origin)
	elseif biome == "Snow" then
		snow(folder, layout, origin)
	elseif biome == "Volcano" then
		volcano(folder, layout, origin)
	elseif biome == "Space" then
		space(folder, layout, origin)
	end
end

return BiomeDressing
