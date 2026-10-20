--!nonstrict
-- Deterministic, non-colliding drive-by scenery for every track (docs/BIOME_DRESSING_SPEC.md).
-- Build(model, layout, spec, origin) dresses one track from Shared/BiomeThemes[spec.Biome].
-- Prune(trackModels, extra) runs after the whole chain is built and removes props too close to any road.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local Themes = require(script.Parent.BiomeThemes)
local MeshAssets = require(script.Parent.BiomeMeshAssets)

local BiomeDressing = {}
BiomeDressing.CLEARANCE = 8 -- studs every prop keeps from any road, wall, checkpoint, pad or spawn-area part
BiomeDressing.BUDGET = 400 -- BaseParts per track Environment
BiomeDressing.GATE_HEIGHT = 28 -- studs from the road to the gate beam

local GROUND_Y = -1 -- TrackBuilder GROUND_TOP: props stand on the grass
local WALL = 2 -- studs of wall outside the road edge
local GATE_INDEX = 4 -- waypoint of the start gate (past the previous track's checkpoint)
local HORIZON_EVERY = 30 -- waypoints between horizon pieces on long runs without corners
local GRID = 64 -- studs per broad-phase cell in Prune

local templates = {}
local function meshTemplate(key)
	if templates[key] == nil then
		templates[key] = false
		local asset = MeshAssets[key]
		if asset then
			local id = type(asset) == "table" and asset.Mesh or asset
			local ok, loaded = pcall(function()
				return AssetService:CreateMeshPartAsync(Content.fromUri(id), {
					CollisionFidelity = Enum.CollisionFidelity.Box,
				})
			end)
			if ok then
				if type(asset) == "table" and asset.Texture then
					loaded.TextureID = asset.Texture
				end
				templates[key] = loaded
			else
				warn("BiomeDressing: mesh failed to load, using fallback: " .. key)
			end
		end
	end
	return templates[key] or nil
end

-- The prop's real size: an uploaded mesh keeps its proportions and is scaled to the prop's height.
local function footprint(biome, def)
	local template = meshTemplate(biome .. "_" .. def.Name)
	return template and template.Size * (def.Size.Y / template.Size.Y) or def.Size
end

local function visual(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- One prop as a Model whose base centre is `base` and whose -Z faces the road.
local function place(folder, biome, def, base, name, glow)
	local model = Instance.new("Model")
	model.Name = name
	local template = meshTemplate(biome .. "_" .. def.Name)
	if template then
		local mesh = template:Clone()
		mesh.Name = def.Name
		mesh.Size = footprint(biome, def)
		mesh.CFrame = base * CFrame.new(0, mesh.Size.Y / 2, 0)
		visual(mesh)
		mesh.Parent = model
	else
		for i, p in def.Parts do
			local part = Instance.new("Part")
			part.Name = def.Name .. i
			part.Size = p.Size
			part.CFrame = base * CFrame.new(p.Pos)
			part.Color = p.Color
			part.Material = p.Material or Enum.Material.SmoothPlastic
			if p.Shape then
				part.Shape = p.Shape
			end
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			visual(part)
			part.Parent = model
		end
	end
	for _, part in model:GetChildren() do
		part.CastShadow = def.Size.Magnitude > 30 -- small props cast no shadow
	end
	if glow and def.Glow then
		local light = Instance.new("PointLight")
		light.Color = def.Glow
		light.Range = 24
		light.Shadows = false
		light.Parent = model:GetChildren()[1]
	end
	if def.Tag then
		CollectionService:AddTag(model, def.Tag)
	end
	model.Parent = folder
	return #model:GetChildren()
end

local function flat(vector)
	local f = Vector3.new(vector.X, 0, vector.Z)
	return f.Magnitude > 1e-4 and f.Unit or Vector3.new(0, 0, -1)
end

-- World base CFrame `distance` studs to one side (-1 left, 1 right) of waypoint i, on the ground, facing the road.
local function beside(layout, origin, i, side, distance)
	local wps = layout.Waypoints
	local tangent = flat(wps[math.min(#wps, i + 1)] - wps[math.max(1, i - 1)])
	local right = Vector3.new(-tangent.Z, 0, tangent.X)
	local point = origin:PointToWorldSpace(wps[i] + right * side * distance)
	local toRoad = flat(origin:VectorToWorldSpace(-right * side))
	local base = Vector3.new(point.X, GROUND_Y, point.Z)
	return CFrame.lookAt(base, base + toRoad)
end

-- Corners (runs of curvature) with their middle waypoint and outside side, and the tops of climbs.
local function features(layout)
	local wps, curv = layout.Waypoints, layout.Curvature
	local corners, crests = {}, {}
	local i = 2
	while i < #wps do
		if (curv[i] or 0) > 0 then
			local s = i
			while i < #wps and (curv[i + 1] or 0) > 0 do
				i += 1
			end
			local t1 = flat(wps[s] - wps[s - 1])
			local t2 = flat(wps[math.min(#wps, i + 1)] - wps[i])
			local cross = t1.Z * t2.X - t1.X * t2.Z -- > 0 for a left turn, whose outside is the right
			table.insert(corners, { Index = (s + i) // 2, Side = cross > 0 and 1 or -1 })
		end
		i += 1
	end
	local rise = 0
	for j = 2, #wps - 1 do
		local dy = wps[j].Y - wps[j - 1].Y
		rise = dy > 0.05 and rise + dy or 0
		if rise >= 8 and wps[j + 1].Y - wps[j].Y <= 0.05 then
			table.insert(crests, j)
		end
	end
	return corners, crests
end

local function near(list, index, gap)
	for _, other in list do
		if math.abs(other - index) < gap then
			return true
		end
	end
	return false
end

-- Arch over the road at the track start: posts outside the clearance, beam GATE_HEIGHT above the road.
local function gate(folder, layout, origin, theme)
	local wps = layout.Waypoints
	local at = theme.Gate.Index or GATE_INDEX
	if #wps <= at + 1 then
		return 0
	end
	local road = origin:PointToWorldSpace(wps[at])
	local tangent = flat(origin:VectorToWorldSpace(wps[at + 1] - wps[at - 1]))
	local look = CFrame.lookAt(road, road + tangent)
	local lateral = layout.Width / 2 + BiomeDressing.CLEARANCE + 6
	local postHeight = road.Y + BiomeDressing.GATE_HEIGHT - GROUND_Y
	local model = Instance.new("Model")
	model.Name = "Gate"
	local function piece(name, size, cf, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = cf
		part.Color = color
		part.Material = material
		visual(part)
		part.Parent = model
		return part
	end
	for _, side in { -1, 1 } do
		local foot = (look * CFrame.new(side * lateral, 0, 0)).Position
		piece(
			"GatePost" .. (side < 0 and "L" or "R"),
			Vector3.new(4, postHeight, 4),
			CFrame.new(foot.X, GROUND_Y + postHeight / 2, foot.Z) * look.Rotation,
			theme.Gate.Color,
			theme.Gate.Material
		)
	end
	local beam = piece(
		"GateBeam",
		Vector3.new(lateral * 2 + 4, 3, 4),
		look * CFrame.new(0, BiomeDressing.GATE_HEIGHT, 0),
		theme.Gate.Color,
		theme.Gate.Material
	)
	piece(
		"GateSign",
		Vector3.new(lateral * 2 - 8, 1.5, 0.5),
		look * CFrame.new(0, BiomeDressing.GATE_HEIGHT, -2.3),
		theme.Gate.Glow or theme.Gate.Color,
		Enum.Material.Neon
	)
	if theme.Gate.Glow then
		local light = Instance.new("PointLight")
		light.Color = theme.Gate.Glow
		light.Range = 30
		light.Shadows = false
		light.Parent = beam
	end
	model.Parent = folder
	return #model:GetChildren()
end

function BiomeDressing.Build(model, layout, spec, origin)
	local biome = spec.Biome
	local theme = type(biome) == "string" and Themes[biome]
	if not theme then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Environment"
	folder.Parent = model
	model:SetAttribute("Biome", biome)
	local ground = model:FindFirstChild("Ground")
	if ground then
		ground.Color = theme.Ground.Color
		ground.Material = theme.Ground.Material
	end

	local wps = layout.Waypoints
	local edge = layout.Width / 2 + WALL
	local count = gate(folder, layout, origin, theme)
	local function add(layer, n, i, side, glow, name)
		local def = layer.Props[n % #layer.Props + 1]
		local base = beside(layout, origin, i, side, edge + layer.Offset + footprint(biome, def).Z / 2)
		count += place(folder, biome, def, base, name, glow)
	end
	local function alternate(n)
		return n % 2 == 0 and 1 or -1
	end

	-- Landmarks and horizon first, so the rhythm layer is what the budget trims.
	local corners, crests = features(layout)
	local spots, n = {}, 0
	for _, c in corners do
		add(theme.Landmarks, n, c.Index, c.Side, true, "Landmark_" .. c.Index)
		add(theme.Horizon, n, c.Index, c.Side, false, "Horizon_" .. c.Index)
		table.insert(spots, c.Index)
		n += 1
	end
	for _, i in crests do
		if not near(spots, i, 6) then
			add(theme.Landmarks, n, i, alternate(n), true, "Landmark_" .. i)
			table.insert(spots, i)
			n += 1
		end
	end
	local every = theme.Landmarks.Every
	for i = every, #wps - every, every do
		if not near(spots, i, every // 2) then
			add(theme.Landmarks, n, i, alternate(n), true, "Landmark_" .. i)
			table.insert(spots, i)
			n += 1
		end
	end
	for i = HORIZON_EVERY, #wps, HORIZON_EVERY do
		if not near(spots, i, HORIZON_EVERY // 2) then
			local h = i // HORIZON_EVERY
			add(theme.Horizon, h, i, alternate(h), false, "Horizon_" .. i)
		end
	end

	local rhythm, k = theme.Rhythm, 0
	for i = 2, #wps - 1, rhythm.Every do
		for _, side in { -1, 1 } do
			if count + 4 > BiomeDressing.BUDGET then
				return
			end
			add(rhythm, k, i, side, false, "Rhythm_" .. i .. (side < 0 and "L" or "R"))
			k += 1
		end
	end
end

-- shortcut: axis-aligned boxes only, so a few props beside diagonal road pieces are pruned that an
-- exact oriented-box test would keep; switch to oriented boxes if too much scenery goes missing.
local function bounds(cf, size)
	local r, u, b = cf.RightVector * size.X / 2, cf.UpVector * size.Y / 2, cf.LookVector * size.Z / 2
	local e = Vector3.new(
		math.abs(r.X) + math.abs(u.X) + math.abs(b.X),
		math.abs(r.Y) + math.abs(u.Y) + math.abs(b.Y),
		math.abs(r.Z) + math.abs(u.Z) + math.abs(b.Z)
	)
	return cf.Position - e, cf.Position + e
end

local function blockers(trackModels, extra)
	local list = {}
	local function addAll(root)
		if root:IsA("BasePart") then
			table.insert(list, root)
		end
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
	end
	for _, model in trackModels do
		for _, name in { "Road", "Walls", "Checkpoint" } do
			local child = model:FindFirstChild(name)
			if child then
				addAll(child)
			end
		end
		local pad = model:FindFirstChild("WinPad", true)
		if pad then
			addAll(pad)
		end
	end
	for _, inst in extra or {} do
		addAll(inst)
	end
	return list
end

-- Removes every Environment prop whose box, grown by CLEARANCE, touches a blocker. Returns how many.
function BiomeDressing.Prune(trackModels, extra)
	local grid = {}
	local function cells(lo, hi, fn)
		for cx = math.floor(lo.X / GRID), math.floor(hi.X / GRID) do
			for cz = math.floor(lo.Z / GRID), math.floor(hi.Z / GRID) do
				fn(cx .. "," .. cz)
			end
		end
	end
	for _, part in blockers(trackModels, extra) do
		local lo, hi = bounds(part.CFrame, part.Size)
		local box = { lo, hi }
		cells(lo, hi, function(key)
			grid[key] = grid[key] or {}
			table.insert(grid[key], box)
		end)
	end
	local grow = Vector3.one * BiomeDressing.CLEARANCE
	local removed = 0
	for _, model in trackModels do
		local folder = model:FindFirstChild("Environment")
		for _, prop in folder and folder:GetChildren() or {} do
			local hit = false
			-- Each part on its own: a gate's posts and beam are clear even though their joint box spans the road.
			for _, part in prop:IsA("BasePart") and { prop } or prop:GetDescendants() do
				if part:IsA("BasePart") and not hit then
					local lo, hi = bounds(part.CFrame, part.Size)
					lo, hi = lo - grow, hi + grow
					cells(lo, hi, function(key)
						for _, box in grid[key] or {} do
							hit = hit
								or (
									lo.X < box[2].X
									and hi.X > box[1].X
									and lo.Y < box[2].Y
									and hi.Y > box[1].Y
									and lo.Z < box[2].Z
									and hi.Z > box[1].Z
								)
						end
					end)
				end
			end
			if hit then
				prop:Destroy()
				removed += 1
			end
		end
	end
	return removed
end

return BiomeDressing
