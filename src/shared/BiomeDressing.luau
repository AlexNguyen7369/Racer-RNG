--!nonstrict
-- Deterministic, non-colliding drive-by scenery for every track (docs/BIOME_DRESSING_SPEC.md).
-- Build(model, layout, spec, origin) dresses one track from Shared/BiomeThemes[spec.Biome].
-- Prune(trackModels, extra) runs after the whole chain is built and removes props too close to any road.

local CollectionService = game:GetService("CollectionService")
local Themes = require(script.Parent.BiomeThemes)
local HudFormat = require(script.Parent.HudFormat)
local UiTheme = require(script.Parent.UiTheme)
local NpcConfig = require(script.Parent.NpcConfig)
local RaceConfig = require(script.Parent.RaceConfig)

local BiomeDressing = {}
BiomeDressing.CLEARANCE = 8 -- studs every prop keeps from any road, wall, checkpoint, pad or spawn-area part
BiomeDressing.BUDGET = 1200 -- BaseParts per track Environment (owner 2026-10-27)
-- Size factor per layer (owner 2026-10-27, placeholders); Rhythm and the gate keep their theme sizes
BiomeDressing.SCALE = { Landmarks = 1.75, Horizon = 2, Scatter = 1.5 }
BiomeDressing.GATE_HEIGHT = 28 -- studs from the road to the gate beam
BiomeDressing.PARTICLE_MAX_RATE = 8 -- particles per second per landmark emitter

local GROUND_Y = -1 -- TrackBuilder GROUND_TOP: props stand on the grass
local GROUND_STEP = 0.02 -- studs each later track's ground sits below the previous one
local WALL = 2 -- studs of wall outside the road edge
local GATE_INDEX = 4 -- waypoint of the start gate (past the previous track's checkpoint)
local HORIZON_EVERY = 30 -- waypoints between horizon pieces on long runs without corners
local HORIZON_FIT = { 1, 0.75, 0.5, 1 / 3 } -- fractions of the horizon Offset tried until the piece fits on the ground
local PATCH_THICKNESS = 0.2 -- studs: ground patches are flat slabs
local SCATTER_PASSES = 4 -- scatter spots are visited in interleaved passes so a full budget still covers the whole track
local GRID = 64 -- studs per broad-phase cell in Prune

local MeshData = script.Parent:WaitForChild("BiomeMeshData")
local dataCache = {}
-- Baked CC0 mesh of a prop (Shared/BiomeMeshData/<Biome>), or nil when the prop only has fallback parts.
function BiomeDressing.MeshFor(biome, name)
	if dataCache[biome] == nil then
		local module = MeshData:FindFirstChild(biome)
		dataCache[biome] = module and require(module) or false
	end
	return dataCache[biome] and dataCache[biome][name] or nil
end

-- The prop's real size: a baked mesh keeps its proportions and is scaled to the prop's height.
local function footprint(biome, def)
	local mesh = BiomeDressing.MeshFor(biome, def.Name)
	return mesh and mesh.Size * (def.Size.Y / mesh.Size.Y) or def.Size
end

local scaledCache = setmetatable({}, { __mode = "k" })
-- A prop grown by k: part sizes and offsets alike, same Name (so the same baked mesh, scaled to the new height).
local function scaled(def, k)
	if not k or k == 1 then
		return def
	end
	local byK = scaledCache[def] or {}
	scaledCache[def] = byK
	if not byK[k] then
		local copy = table.clone(def)
		copy.Size = def.Size * k
		copy.Parts = {}
		for i, p in def.Parts do
			local q = table.clone(p)
			q.Size = p.Size * k
			q.Pos = p.Pos * k
			copy.Parts[i] = q
		end
		byK[k] = copy
	end
	return byK[k]
end

local function visual(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- Theme particle settings -> a ParticleEmitter (spec Layers 8: one per landmark, capped Rate).
local function emitter(parent, cfg)
	local e = Instance.new("ParticleEmitter")
	e.Name = "BiomeParticles"
	e.Texture = cfg.Texture
	e.Color = typeof(cfg.Color) == "ColorSequence" and cfg.Color or ColorSequence.new(cfg.Color)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.15, cfg.Size),
		NumberSequenceKeypoint.new(1, cfg.Size * 0.6),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, cfg.Transparency or 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(cfg.Lifetime * 0.7, cfg.Lifetime)
	e.Rate = math.min(cfg.Rate, BiomeDressing.PARTICLE_MAX_RATE)
	e.Speed = NumberRange.new(cfg.Speed * 0.5, cfg.Speed)
	e.SpreadAngle = Vector2.new(cfg.Spread or 180, cfg.Spread or 180)
	e.Acceleration = cfg.Acceleration or Vector3.zero
	e.EmissionDirection = cfg.Direction or Enum.NormalId.Top
	e.LightEmission = cfg.LightEmission or 0
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = parent
end

-- One prop as a Model whose base centre is `base` and whose -Z faces the road.
local function place(folder, biome, def, base, name, glow, particles)
	local model = Instance.new("Model")
	model.Name = name
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
	if BiomeDressing.MeshFor(biome, def.Name) then
		-- Invisible box at the mesh's real size: Prune checks it, and Client/BiomeMeshes puts the mesh there
		-- and hides the fallback parts (EditableMesh content does not replicate, so each client builds it).
		local size = footprint(biome, def)
		local bounds = Instance.new("Part")
		bounds.Name = "MeshBounds"
		bounds.Size = size
		bounds.CFrame = base * CFrame.new(0, size.Y / 2, 0)
		bounds.Transparency = 1
		visual(bounds)
		bounds.Parent = model
		model:SetAttribute("Mesh", biome .. "_" .. def.Name)
		CollectionService:AddTag(model, "BiomeMesh")
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
	if particles then
		emitter(model:GetChildren()[1], particles)
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
local SIGN_HEIGHT = 8 -- studs the gate sign hangs below the beam

-- "PirateCoast" -> "PIRATE COAST"
local function biomeTitle(biome)
	return string.upper((string.gsub(biome, "(%l)(%u)", "%1 %2")))
end
BiomeDressing.Title = biomeTitle

-- The recommended Speed for track n: the stat whose cruise speed matches its NPC (gate sign, checkpoint panel).
function BiomeDressing.RecSpeed(n)
	return RaceConfig.StatFor(NpcConfig.For(n or 1).Speed)
end

-- Text on the sign's face toward the oncoming car: the biome and the recommended Speed (owner 2026-10-21).
local function signText(sign, spec)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "GateSignGui"
	gui.Face = Enum.NormalId.Back -- +Z: the car drives toward -Z (look direction)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = sign
	local function line(name, text, y, height, color)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.05, y)
		label.Size = UDim2.fromScale(0.9, height)
		label.Font = UiTheme.Font
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		UiTheme.Stroke(label, 2)
		label.Parent = gui
	end
	local rec = BiomeDressing.RecSpeed(spec.Number)
	-- SpeedText shows a non-finite number as 0; Short shows "inf"
	local recText = rec == math.huge and HudFormat.Short(rec) or HudFormat.SpeedText(rec)
	line("Biome", biomeTitle(spec.Biome), 0.06, 0.52, Color3.new(1, 1, 1))
	line("RecSpeed", "REC. SPEED " .. recText, 0.6, 0.34, Color3.fromRGB(255, 220, 60))
end

local function gate(folder, layout, origin, theme, spec)
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
	local sign = piece(
		"GateSign",
		Vector3.new(math.min(lateral * 2 - 8, 48), SIGN_HEIGHT, 0.5),
		look * CFrame.new(0, BiomeDressing.GATE_HEIGHT - 1.5 - SIGN_HEIGHT / 2, 2.3),
		Color3.fromRGB(20, 22, 30),
		Enum.Material.SmoothPlastic
	)
	signText(sign, spec)
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

-- 0..1 from a waypoint, a side and a salt: variety without randomness, so two builds are identical.
local function hash(i, side, salt)
	local x = math.sin(i * 12.9898 + side * 78.233 + salt * 37.719) * 43758.5453
	return x - math.floor(x)
end

-- Scatter layer (spec Layers 7): props and flat ground patches between Near and Far studs from the road edge,
-- built last into whatever budget is left. Returns the new part count.
local function scatter(folder, layout, origin, theme, biome, ground, edge, count, onGround, budget)
	local s, wps = theme.Scatter, layout.Waypoints
	local named = {}
	for _, layer in { theme.Rhythm, theme.Landmarks } do
		for _, def in layer.Props do
			named[def.Name] = def
		end
	end
	local groundTop = ground and ground.Position.Y + ground.Size.Y / 2 or GROUND_Y
	local stride = s.Every * SCATTER_PASSES
	for pass = 0, SCATTER_PASSES - 1 do
		for i = 2 + pass * s.Every, #wps - 1, stride do
			for _, side in { -1, 1 } do
				local tag = i .. (side < 0 and "L" or "R")
				local def = s.Props[math.floor(hash(i, side, 1) * 1000) % #s.Props + 1]
				def = scaled(named[def] or def, BiomeDressing.SCALE.Scatter)
				local size = footprint(biome, def)
				local reach = Vector2.new(size.X, size.Z).Magnitude / 2
				local distance = edge + s.Near + (s.Far - s.Near) * hash(i, side, 2) + reach
				local base = beside(layout, origin, i, side, distance)
					* CFrame.Angles(0, hash(i, side, 3) * 2 * math.pi, 0)
				-- The patch (one part) goes first, so a tight budget still covers the ground.
				if (i // s.Every) % 2 == 0 and count + 1 <= budget then
					local p = s.Patches[math.floor(hash(i, side, 4) * 1000) % #s.Patches + 1]
					local patchReach = Vector2.new(p.Size.X, p.Size.Z).Magnitude / 2
					local at = edge + s.Near + (s.Far - s.Near) * hash(i, side, 5) + patchReach
					local cf = beside(layout, origin, i, side, at) * CFrame.Angles(0, hash(i, side, 6) * math.pi, 0)
					if onGround(cf, patchReach) then
						local slab = Instance.new("Part")
						slab.Name = p.Name .. "1"
						slab.Size = Vector3.new(p.Size.X, PATCH_THICKNESS, p.Size.Z)
						slab.CFrame = cf - Vector3.new(0, cf.Position.Y - groundTop - PATCH_THICKNESS / 2, 0)
						slab.Color = p.Color
						slab.Material = p.Material
						slab.TopSurface = Enum.SurfaceType.Smooth
						slab.BottomSurface = Enum.SurfaceType.Smooth
						slab.CastShadow = false
						visual(slab)
						local patch = Instance.new("Model")
						patch.Name = "Patch_" .. tag
						slab.Parent = patch
						patch.Parent = folder
						count += 1
					end
				end
				if count + #def.Parts + 1 <= budget and onGround(base, reach) then
					count += place(folder, biome, def, base, "Scatter_" .. tag, false)
				end
			end
		end
	end
	return count
end

-- Footprints (XZ) of two ground-standing boxes overlap: 2D separating axis test.
local function footprintsOverlap(a, b)
	local axes = { a.CFrame.RightVector, a.CFrame.LookVector, b.CFrame.RightVector, b.CFrame.LookVector }
	local d = b.CFrame.Position - a.CFrame.Position
	for _, axis in axes do
		axis = flat(axis)
		local function radius(box)
			return math.abs(flat(box.CFrame.RightVector):Dot(axis)) * box.Half.X
				+ math.abs(flat(box.CFrame.LookVector):Dot(axis)) * box.Half.Y
		end
		if math.abs(Vector3.new(d.X, 0, d.Z):Dot(axis)) >= radius(a) + radius(b) then
			return false
		end
	end
	return true
end

-- Blocks layer (spec Layers 9): street-wall rows of low-rise buildings, a slot every `Spacing` studs along the road
-- on each side, `Rows` deep. A building overlapping one already placed (inside corners) is skipped.
local function blocks(folder, layout, origin, theme, biome, edge, count, onGround, budget)
	local b, wps = theme.Blocks, layout.Waypoints
	local placed = {}
	for _, m in folder:GetChildren() do -- landmarks and horizon pieces keep their ground
		if m:IsA("Model") and (string.match(m.Name, "^Landmark_") or string.match(m.Name, "^Horizon_")) then
			local cf, size = m:GetBoundingBox()
			table.insert(placed, { CFrame = cf, Half = Vector2.new(size.X / 2, size.Z / 2) })
		end
	end
	local travelled, nextSlot, slot = 0, 0, 0
	for i = 2, #wps - 1 do
		travelled += (Vector3.new(wps[i].X, 0, wps[i].Z) - Vector3.new(wps[i - 1].X, 0, wps[i - 1].Z)).Magnitude
		if travelled >= nextSlot then
			slot += 1
			nextSlot += b.Spacing
			for _, side in { -1, 1 } do
				for row = 1, b.Rows do
					local def = b.Props[math.floor(hash(slot, side, row + 10) * 1000) % #b.Props + 1]
					local distance = edge + b.Near + (row - 1) * b.RowDepth + def.Size.Z / 2
					local base = beside(layout, origin, i, side, distance)
					local box = { CFrame = base, Half = Vector2.new(def.Size.X / 2, def.Size.Z / 2) }
					local clear = count + #def.Parts <= budget
						and onGround(base, Vector2.new(def.Size.X, def.Size.Z).Magnitude / 2)
					for _, other in placed do
						if not clear then
							break
						end
						clear = not footprintsOverlap(box, other)
					end
					if clear then
						table.insert(placed, box)
						count += place(
							folder,
							biome,
							def,
							base,
							"Block_" .. slot .. (side < 0 and "L" or "R") .. row,
							false
						)
					end
				end
			end
		end
	end
	return count
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
		-- Neighbouring tracks' grounds overlap; a per-track step keeps their different colours from z-fighting.
		ground.Position -= Vector3.new(0, GROUND_STEP * (spec.Number or 0), 0)
	end

	local wps = layout.Waypoints
	local edge = layout.Width / 2 + WALL
	local budget = theme.Budget or BiomeDressing.BUDGET
	local count = gate(folder, layout, origin, theme, spec)
	-- A prop whose footprint leaves this track's ground would hang over the void (or the Baseplate below it).
	-- `reach` is the prop's half-width on the ground (its half-diagonal when it is turned).
	local function onGround(base, reach)
		if not ground then
			return true
		end
		local l = ground.CFrame:PointToObjectSpace(base.Position)
		return math.abs(l.X) + reach <= ground.Size.X / 2 and math.abs(l.Z) + reach <= ground.Size.Z / 2
	end
	local function add(layer, n, i, side, glow, name, fits)
		local k = layer == theme.Landmarks and BiomeDressing.SCALE.Landmarks
			or layer == theme.Horizon and BiomeDressing.SCALE.Horizon
		local raw = layer.Props[n % #layer.Props + 1]
		-- A horizon piece that fits nowhere at its scale shrinks toward x1 (spec Rules, Scale)
		local steps = { k }
		if fits and k then
			for s = k - 0.25, 1, -0.25 do
				table.insert(steps, s)
			end
		end
		for _, s in steps do
			local def = scaled(raw, s)
			local size = footprint(biome, def)
			for _, f in fits or { 1 } do
				local offset = fits and math.max(layer.Offset * f, theme.Landmarks.Offset) or layer.Offset
				local base = beside(layout, origin, i, side, edge + offset + size.Z / 2)
				if onGround(base, math.max(size.X, size.Z) / 2) then
					count += place(folder, biome, def, base, name, glow, glow and theme.Particles)
					return
				end
			end
		end
	end
	local function alternate(n)
		return n % 2 == 0 and 1 or -1
	end

	-- Landmarks and horizon first, so the rhythm layer is what the budget trims.
	local corners, crests = features(layout)
	local spots, n = {}, 0
	for _, c in corners do
		add(theme.Landmarks, n, c.Index, c.Side, true, "Landmark_" .. c.Index)
		add(theme.Horizon, n, c.Index, c.Side, false, "Horizon_" .. c.Index, HORIZON_FIT)
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
	local first = math.min(every, #wps // 2) -- a short straight track still gets one
	for i = first, #wps - first, every do
		if not near(spots, i, every // 2) then
			add(theme.Landmarks, n, i, alternate(n), true, "Landmark_" .. i)
			table.insert(spots, i)
			n += 1
		end
	end
	local horizonEvery = math.min(HORIZON_EVERY, #wps // 2)
	for i = horizonEvery, #wps, horizonEvery do
		if not near(spots, i, horizonEvery // 2) then
			local h = i // horizonEvery
			add(theme.Horizon, h, i, alternate(h), false, "Horizon_" .. i, HORIZON_FIT)
		end
	end

	local rhythm, k = theme.Rhythm, 0
	for i = 2, #wps - 1, rhythm.Every do
		for _, side in { -1, 1 } do
			if count + 4 > budget then
				return
			end
			add(rhythm, k, i, side, false, "Rhythm_" .. i .. (side < 0 and "L" or "R"))
			k += 1
		end
	end
	if theme.Blocks then
		count = blocks(folder, layout, origin, theme, biome, edge, count, onGround, budget)
	end
	if theme.Scatter then
		count = scatter(folder, layout, origin, theme, biome, ground, edge, count, onGround, budget)
	end
end

-- World axis-aligned box of an oriented box: the broad phase only.
local function bounds(cf, size)
	local r, u, b = cf.RightVector * size.X / 2, cf.UpVector * size.Y / 2, cf.LookVector * size.Z / 2
	local e = Vector3.new(
		math.abs(r.X) + math.abs(u.X) + math.abs(b.X),
		math.abs(r.Y) + math.abs(u.Y) + math.abs(b.Y),
		math.abs(r.Z) + math.abs(u.Z) + math.abs(b.Z)
	)
	return cf.Position - e, cf.Position + e
end

-- Oriented box overlap (separating axis test), the same test as the `environment` scenario. Touching is no overlap.
local function overlaps(cfA, halfA, cfB, halfB)
	local a = { cfA.RightVector, cfA.UpVector, cfA.LookVector }
	local b = { cfB.RightVector, cfB.UpVector, cfB.LookVector }
	local ha, hb = { halfA.X, halfA.Y, halfA.Z }, { halfB.X, halfB.Y, halfB.Z }
	local t = cfB.Position - cfA.Position
	local function separated(axis)
		if axis.Magnitude < 1e-6 then
			return false
		end
		axis = axis.Unit
		local ra, rb = 0, 0
		for k = 1, 3 do
			ra += math.abs(a[k]:Dot(axis)) * ha[k]
			rb += math.abs(b[k]:Dot(axis)) * hb[k]
		end
		return math.abs(t:Dot(axis)) >= ra + rb
	end
	for k = 1, 3 do
		if separated(a[k]) or separated(b[k]) then
			return false
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if separated(a[i]:Cross(b[j])) then
				return false
			end
		end
	end
	return true
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
		local box = { lo, hi, part.CFrame, part.Size / 2 }
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
					local half = part.Size / 2 + grow -- grown in the part's own axes
					local lo, hi = bounds(part.CFrame, half * 2)
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
									and overlaps(part.CFrame, half, box[3], box[4])
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
