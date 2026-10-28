--!nonstrict
-- BRIEF (owner, 2026-10-20; design doc "Racing" > "Track environments", contract docs/BIOME_DRESSING_SPEC.md):
-- "every track has its own visual theme ... drive-by scenery". Spec "Acceptance (harness scenario `environment`)":
-- "For every chain track: an `Environment` folder exists and the `Biome` attribute is set; every BasePart in it is
-- anchored and has `CanCollide`, `CanTouch` and `CanQuery` false; after `Prune` no prop is within `CLEARANCE` of any
-- road, wall, checkpoint, pad or spawn-area part; the part count is within the budget; two builds give the same prop
-- names and CFrames; and `Lighting` is unchanged."
-- Also from the spec: the Biome table (track number -> Biome), `Shared/BiomeThemes[biome]`, a `Gate` at each track
-- start, local lights with `Shadows = false`, and no Atmosphere / Sky / Clouds from dressing.
-- Written before BiomeThemes, BiomeDressing.Prune/CLEARANCE/BUDGET and the Biome of tracks 1-5 exist: red by design.
-- Everything is built unparented (never in Workspace) and destroyed at the end.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackBuilder = require(Shared.TrackBuilder)
local TrackRegistry = require(Shared.TrackRegistry)
local RaceConfig = require(Shared.RaceConfig)
local NpcConfig = require(Shared.NpcConfig)
local HudFormat = require(Shared.HudFormat)

local Tests = {}

-- Spec "Themes": track number -> Biome
local BIOMES = { "Speedway", "Forest", "Docks", "Suburb", "PirateCoast", "City", "Desert", "Snow", "Volcano", "Space" }
local CHAIN_ORIGIN = Vector3.new(-20000, 0, 20000) -- far from the play area and the other scenario origins
local GEOM_TOL = 0.05 -- studs of overlap ignored (boxes that only touch)
local CFRAME_TOL = 1e-3
local CELL = 64 -- broad-phase grid cell, studs
local LIGHT_TOL = 1e-3
local SIZE_TOL = 1e-3
local GROUND_TOP = -1 -- TrackBuilder GROUND_TOP (world Y of the grass top)
local GROUND_STEP = 0.02 -- contract: track N's ground top sits 0.02 * N below GROUND_TOP (no z-fighting)
local MAX_TRIANGLES = 20000
local MAX_VERTICES = 60000
-- Visual pass (owner 2026-10-26, spec Layers 7-8 and Acceptance "Added 2026-10-26")
local PARTICLE_MAX_RATE = 8 -- spec placeholder PARTICLE_MAX_RATE
local MIN_SCATTER = 10
local MIN_PATCHES = 5
local PATCH_THICKNESS = 0.2
local PATCH_GROUND_TOL = 0.05
-- Scale and detail (owner 2026-10-27, design doc Track environments; spec Rules "Budget", "Scale", "City skyscrapers")
local BUDGET = 1200 -- spec placeholder: BaseParts per track Environment
local WANT_SCALE = { Landmarks = 1.75, Horizon = 2, Scatter = 1.5 } -- spec placeholders; Rhythm and gate unscaled
local LAYER_OF_PREFIX = { Landmark_ = "Landmarks", Horizon_ = "Horizon", Scatter_ = "Scatter" }
local CITY = 6
local CITY_TOWER_PROPS = { Skyscraper = true, SkyscraperPink = true, Block = true, Skyline = true }
local CITY_TOWER_MIN_PARTS = 25
local CITY_TOWER_MIN_HEIGHT = 100 -- studs, model bounding box of the tallest City landmark
-- Populated city (owner 2026-10-27, design doc Track environments; spec Layers 9 Blocks, Rules "Theme budget")
local CITY_BUDGET = 2600 -- spec placeholder: City theme Budget
local CITY_MIN_BLOCKS = 60
local BLOCK_SHRINK = 0.5 -- studs each footprint is shrunk by before the overlap test
local BLOCK_PROBE_STEP = 24 -- studs between coverage probes along straight road
local BLOCK_MIN_COVERAGE = 0.7

local function module(parent, name)
	local source = parent:FindFirstChild(name)
	if not source then
		return nil
	end
	local ok, value = pcall(require, source)
	return ok and type(value) == "table" and value or nil
end

local function report(name)
	local r = { scenario = name, pass = true, checks = {}, metrics = {} }
	local function flag(label, ok, value, limit)
		table.insert(
			r.checks,
			{ name = label, pass = ok == true, value = value or (ok and 1 or 0), limit = limit or 1 }
		)
		r.pass = r.pass and ok == true
	end
	return r, flag
end

local function baseParts(root)
	local out = {}
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
	end
	return out
end

-- Oriented box overlap (separating axis test). Touching or a gap = no overlap.
local function boxesOverlap(cfA, halfA, cfB, halfB)
	local a = { cfA.RightVector, cfA.UpVector, cfA.LookVector }
	local b = { cfB.RightVector, cfB.UpVector, cfB.LookVector }
	local ha = { halfA.X, halfA.Y, halfA.Z }
	local hb = { halfB.X, halfB.Y, halfB.Z }
	local t = cfB.Position - cfA.Position
	local function separated(axis)
		if axis.Magnitude < 1e-6 then
			return false
		end
		axis = axis.Unit
		local ra = math.abs(a[1]:Dot(axis)) * ha[1]
			+ math.abs(a[2]:Dot(axis)) * ha[2]
			+ math.abs(a[3]:Dot(axis)) * ha[3]
		local rb = math.abs(b[1]:Dot(axis)) * hb[1]
			+ math.abs(b[2]:Dot(axis)) * hb[2]
			+ math.abs(b[3]:Dot(axis)) * hb[3]
		return math.abs(t:Dot(axis)) >= ra + rb
	end
	for i = 1, 3 do
		if separated(a[i]) or separated(b[i]) then
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

-- World axis-aligned half extents of an oriented box
local function aabbHalf(cf, half)
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return Vector3.new(
		math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z,
		math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z,
		math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
	)
end

-- XZ footprint of a part's oriented box, shrunk by `shrink` on every side
local function footprint(part, shrink)
	local function flat(v)
		local f = Vector2.new(v.X, v.Z)
		return f.Magnitude > 1e-6 and f.Unit or Vector2.new(1, 0)
	end
	return {
		C = Vector2.new(part.Position.X, part.Position.Z),
		A = { flat(part.CFrame.RightVector), flat(part.CFrame.LookVector) },
		H = { math.max(0, part.Size.X / 2 - shrink), math.max(0, part.Size.Z / 2 - shrink) },
	}
end

-- 2D separating axis test; touching = no overlap
local function footprintsOverlap(a, b)
	local d = b.C - a.C
	for _, axis in { a.A[1], a.A[2], b.A[1], b.A[2] } do
		local ra = math.abs(a.A[1]:Dot(axis)) * a.H[1] + math.abs(a.A[2]:Dot(axis)) * a.H[2]
		local rb = math.abs(b.A[1]:Dot(axis)) * b.H[1] + math.abs(b.A[2]:Dot(axis)) * b.H[2]
		if math.abs(d:Dot(axis)) >= ra + rb then
			return false
		end
	end
	return true
end

local function footprintHas(f, point)
	local d = point - f.C
	return math.abs(d:Dot(f.A[1])) <= f.H[1] and math.abs(d:Dot(f.A[2])) <= f.H[2]
end

-- Obstacles: every road, wall, checkpoint (incl. WinPad) part of every track, plus the spawn area
local function obstacleGrid(trackModels, extra)
	local grid, list = {}, {}
	local function add(part)
		local half = part.Size / 2
		local ext = aabbHalf(part.CFrame, half)
		local p = part.Position
		local o = { CFrame = part.CFrame, Half = half, Min = p - ext, Max = p + ext, Name = part:GetFullName() }
		table.insert(list, o)
		for x = math.floor(o.Min.X / CELL), math.floor(o.Max.X / CELL) do
			for z = math.floor(o.Min.Z / CELL), math.floor(o.Max.Z / CELL) do
				local key = x .. "," .. z
				grid[key] = grid[key] or {}
				table.insert(grid[key], o)
			end
		end
	end
	for _, model in trackModels do
		for _, name in { "Road", "Walls", "Checkpoint" } do
			for _, part in baseParts(model:FindFirstChild(name)) do
				add(part)
			end
		end
		local pad = model:FindFirstChild("WinPad", true)
		if pad and pad:IsA("BasePart") and not pad:IsDescendantOf(model:FindFirstChild("Checkpoint") or pad) then
			add(pad)
		end
	end
	if extra then
		for _, part in baseParts(extra) do
			add(part)
		end
	end
	return grid, #list
end

-- First obstacle a prop box (grown by `grow` on every side) overlaps, or nil
local function firstHit(grid, part, grow)
	local half = part.Size / 2 + Vector3.one * grow
	local ext = aabbHalf(part.CFrame, half)
	local p = part.Position
	local mn, mx = p - ext, p + ext
	local seen = {}
	for x = math.floor(mn.X / CELL), math.floor(mx.X / CELL) do
		for z = math.floor(mn.Z / CELL), math.floor(mx.Z / CELL) do
			for _, o in grid[x .. "," .. z] or {} do
				if
					not seen[o]
					and mn.X < o.Max.X
					and mx.X > o.Min.X
					and mn.Y < o.Max.Y
					and mx.Y > o.Min.Y
					and mn.Z < o.Max.Z
					and mx.Z > o.Min.Z
				then
					seen[o] = true
					if boxesOverlap(part.CFrame, half, o.CFrame, o.Half) then
						return o
					end
				end
				seen[o] = true
			end
		end
	end
	return nil
end

local function buildChain(specs)
	local tracks = {}
	local origin = CFrame.new(CHAIN_ORIGIN + Vector3.new(0, TrackBuilder.TRACK_LIFT or 0, 0))
	for _, spec in specs do
		local model, layout = TrackBuilder.Build(spec, origin)
		table.insert(tracks, { Spec = spec, Model = model, Layout = layout, Origin = origin })
		origin = TrackBuilder.EndCFrame(layout, origin)
	end
	return tracks
end

-- Sorted (name, CFrame) list of an Environment folder, for the determinism check
local function signature(env)
	local out = {}
	for _, part in baseParts(env) do
		local p = part.Position
		table.insert(
			out,
			{ Key = ("%s|%.1f|%.1f|%.1f"):format(part.Name, p.X, p.Y, p.Z), Name = part.Name, CFrame = part.CFrame }
		)
	end
	table.sort(out, function(x, y)
		return x.Key < y.Key
	end)
	return out
end

local function sameSignature(a, b)
	if #a ~= #b then
		return false, math.abs(#a - #b)
	end
	local worst = 0
	for i = 1, #a do
		if a[i].Name ~= b[i].Name then
			return false, -1
		end
		local ca, cb = { a[i].CFrame:GetComponents() }, { b[i].CFrame:GetComponents() }
		for k = 1, 12 do
			worst = math.max(worst, math.abs(ca[k] - cb[k]))
		end
	end
	return worst <= CFRAME_TOL, worst
end

local function lightingSnapshot()
	local function count(parent, class)
		local n = 0
		for _, c in parent:GetChildren() do
			if c:IsA(class) then
				n += 1
			end
		end
		return n
	end
	return {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Ambient = Lighting.Ambient,
		Atmosphere = count(Lighting, "Atmosphere"),
		Sky = count(Lighting, "Sky"),
		Clouds = count(Workspace.Terrain, "Clouds"),
	}
end

local function colorDiff(a, b)
	return math.max(math.abs(a.R - b.R), math.abs(a.G - b.G), math.abs(a.B - b.B))
end

-- Every prop definition of a theme ({ Name, Size, Parts }), keyed by Name (first one wins)
local function themeProps(theme)
	local out, seen = {}, {}
	local function walk(t)
		if type(t) ~= "table" or seen[t] then
			return
		end
		seen[t] = true
		if type(t.Name) == "string" and typeof(t.Size) == "Vector3" and type(t.Parts) == "table" then
			out[t.Name] = out[t.Name] or t
		end
		for _, v in t do
			walk(v)
		end
	end
	walk(theme)
	return out
end

-- Baked mesh entry rules: { Size = Vector3, Data = base64 } decoding to u16 vc, u16 ic, vc*10 bytes, ic u16 indices
local function meshEntryProblem(codec, entry)
	if type(entry) ~= "table" or typeof(entry.Size) ~= "Vector3" or type(entry.Data) ~= "string" then
		return "shape"
	end
	if entry.Size.X <= 0 or entry.Size.Y <= 0 or entry.Size.Z <= 0 then
		return "size"
	end
	local ok, blob = pcall(codec.Decode, entry.Data)
	if not ok or type(blob) ~= "buffer" or buffer.len(blob) < 4 then
		return "decode"
	end
	local vc, ic = buffer.readu16(blob, 0), buffer.readu16(blob, 2)
	if buffer.len(blob) ~= 4 + vc * 10 + ic * 2 then
		return "length"
	end
	if ic % 3 ~= 0 or ic // 3 > MAX_TRIANGLES or vc > MAX_VERTICES then
		return "counts"
	end
	local base = 4 + vc * 10
	for k = 0, ic - 1 do
		if buffer.readu16(blob, base + k * 2) >= vc then
			return "index"
		end
	end
	return nil
end

-- The theme prop a built prop Model comes from: its Mesh attribute, else its first fallback part's name
-- without the trailing number (parts are named <Prop><i>)
local function propNameOf(model, biome)
	local mesh = model:GetAttribute("Mesh")
	if type(mesh) == "string" and string.sub(mesh, 1, #biome + 1) == biome .. "_" then
		return string.sub(mesh, #biome + 2)
	end
	for _, c in model:GetChildren() do
		if c:IsA("BasePart") and c.Name ~= "MeshBounds" then
			return (string.gsub(c.Name, "%d+$", ""))
		end
	end
	return nil
end

function Tests.environment()
	local r, flag = report("environment")
	local Dressing = module(Shared, "BiomeDressing")
	local Themes = module(Shared, "BiomeThemes")
	local SpawnArea = module(Shared, "SpawnArea")
	flag("dressing_module", Dressing ~= nil)
	flag("themes_module", Themes ~= nil)
	local clearance = Dressing and Dressing.CLEARANCE
	local budget = Dressing and Dressing.BUDGET
	flag("clearance_value", clearance == 8, type(clearance) == "number" and clearance or -1, 8)
	flag("budget_value", budget == BUDGET, type(budget) == "number" and budget or -1, BUDGET)
	-- Scale rule (owner 2026-10-27): SCALE = { Landmarks = 1.75, Horizon = 2, Scatter = 1.5 }
	local scale = Dressing and type(Dressing.SCALE) == "table" and Dressing.SCALE or nil
	flag("scale_table", scale ~= nil)
	for layer, want in WANT_SCALE do
		local got = scale and scale[layer]
		flag(
			("scale_%s"):format(string.lower(layer)),
			type(got) == "number" and math.abs(got - want) <= SIZE_TOL,
			type(got) == "number" and got or -1,
			want
		)
	end
	flag("prune_api", Dressing ~= nil and type(Dressing.Prune) == "function")

	local specs = TrackRegistry.Chain()
	flag("chain_length", #specs == #BIOMES, #specs, #BIOMES)
	for _, spec in specs do
		local want = BIOMES[spec.Number]
		flag(("biome_spec_%d"):format(spec.Number), spec.Biome == want and want ~= nil)
		flag(
			("biome_theme_%d"):format(spec.Number),
			Themes ~= nil and type(spec.Biome) == "string" and Themes[spec.Biome] ~= nil
		)
	end

	local before = lightingSnapshot()
	local okA, chainA = pcall(buildChain, specs)
	local okB, chainB = pcall(buildChain, specs)
	flag("chain_builds", okA and okB, nil, nil)
	if not (okA and okB) then
		r.error = tostring(okA and chainB or chainA)
		return r
	end

	-- Determinism: two fresh builds (before Prune) give the same prop names and CFrames
	for i, t in chainA do
		local same, worst = sameSignature(
			signature(t.Model:FindFirstChild("Environment")),
			signature(chainB[i].Model:FindFirstChild("Environment"))
		)
		flag(("deterministic_%d"):format(t.Spec.Number), same, worst, CFRAME_TOL)
	end
	-- Baked meshes (Shared/BiomeMeshData, BiomeMeshCodec, BiomeMeshAssets)
	local meshFolder = Shared:FindFirstChild("BiomeMeshData")
	local Codec = module(Shared, "BiomeMeshCodec")
	local Assets = module(Shared, "BiomeMeshAssets")
	local meshForOk = Dressing ~= nil and type(Dressing.MeshFor) == "function"
	flag("mesh_data_folder", meshFolder ~= nil and meshFolder:IsA("Folder"))
	flag("mesh_codec", Codec ~= nil and type(Codec.Decode) == "function")
	flag("mesh_assets_module", Assets ~= nil)
	flag("mesh_for_api", meshForOk)
	local meshEntries, meshProblems = 0, {}
	for _, biome in BIOMES do
		local data = meshFolder and module(meshFolder, biome)
		local bad, badIds, badLookup, first = 0, 0, 0, nil
		for name, entry in data or {} do
			meshEntries += 1
			local problem = "codec" -- no codec: every entry fails
			if Codec and type(Codec.Decode) == "function" then
				problem = meshEntryProblem(Codec, entry) -- nil when the entry is valid
			end
			if problem then
				bad += 1
				first = first or (name .. ":" .. problem)
			end
			local id = Assets and Assets[biome .. "_" .. name]
			if type(id) ~= "string" or not string.match(id, "^rbxassetid://%d+$") then
				badIds += 1
				first = first or (name .. ":asset_id")
			end
			if not meshForOk or Dressing.MeshFor(biome, name) ~= entry then
				badLookup += 1
				first = first or (name .. ":mesh_for")
			end
		end
		flag(("mesh_data_valid_%s"):format(biome), bad == 0, bad, 0)
		flag(("mesh_asset_ids_%s"):format(biome), badIds == 0, badIds, 0)
		flag(("mesh_for_matches_%s"):format(biome), badLookup == 0, badLookup, 0)
		if first then
			meshProblems[biome] = first
		end
	end
	r.metrics.mesh_entries = meshEntries
	r.metrics.mesh_problems = meshProblems

	-- Built props (fresh build, before Prune): a prop with baked data is a tagged BiomeMesh model with an
	-- invisible MeshBounds at the prop's SCALED height (def.Size.Y * SCALE[layer], layer from the name prefix of the
	-- prop's top-level Environment child; Rhythm_ and the gate x1; missing SCALE = red) and the mesh's proportions;
	-- a prop without data has neither
	local meshCounts = {}
	local function layerScale(env, m)
		local top = m
		while top.Parent and top.Parent ~= env do
			top = top.Parent
		end
		for prefix, layer in LAYER_OF_PREFIX do
			if string.sub(top.Name, 1, #prefix) == prefix then
				local v = scale and scale[layer]
				return type(v) == "number" and v or nil, layer
			end
		end
		return 1, nil
	end
	for _, t in chainB do
		local n, biome = t.Spec.Number, BIOMES[t.Spec.Number]
		local env = t.Model:FindFirstChild("Environment")
		local defs = themeProps(Themes and biome and Themes[biome])
		local meshBad, plainBad, meshed, firstBad = 0, 0, 0, nil
		for _, m in (env and env:GetDescendants() or {}) do
			if m:IsA("Model") then
				local propName = biome and propNameOf(m, biome)
				local def = propName and defs[propName]
				local data = def and meshForOk and Dressing.MeshFor(biome, propName)
				local bounds = m:FindFirstChild("MeshBounds")
				local tagged = CollectionService:HasTag(m, "BiomeMesh")
				if data then
					meshed += 1
					local ok = tagged and m:GetAttribute("Mesh") == biome .. "_" .. propName
					ok = ok and bounds ~= nil and bounds:IsA("Part") and bounds.Transparency == 1
					ok = ok
						and bounds.Anchored
						and not bounds.CanCollide
						and not bounds.CanTouch
						and not bounds.CanQuery
					if ok then
						-- Spec Rules "Scale" (owner 2026-10-27): a horizon piece that fits at no HORIZON_FIT offset
						-- shrinks by 0.25 steps from SCALE.Horizon toward x1; every other layer is exact
						local k, layer = layerScale(env, m)
						local fits = false
						if k ~= nil then
							local s = k
							repeat
								fits = fits or math.abs(bounds.Size.Y - def.Size.Y * s) <= SIZE_TOL
								s -= 0.25
							until layer ~= "Horizon" or s < 1 - SIZE_TOL
						end
						ok = fits
						local ratio = bounds.Size / data.Size
						local lo = math.min(ratio.X, ratio.Y, ratio.Z)
						local hi = math.max(ratio.X, ratio.Y, ratio.Z)
						ok = ok and hi - lo <= SIZE_TOL
					end
					if not ok then
						meshBad += 1
						firstBad = firstBad or m.Name
					end
				elseif bounds ~= nil or tagged then
					plainBad += 1
					firstBad = firstBad or m.Name
				end
			end
		end
		flag(("mesh_props_%d"):format(n), env ~= nil and meshBad == 0, meshBad, 0)
		flag(("meshless_props_plain_%d"):format(n), env ~= nil and plainBad == 0, plainBad, 0)
		meshCounts[tostring(n)] = { meshed = meshed, first_bad = firstBad }

		-- City skyscrapers (owner 2026-10-27, spec Rules "City skyscrapers"): landmark, scatter-block and skyline
		-- towers have no baked mesh; every City landmark is a detailed tower (>= 25 parts, Glass window bands, a
		-- Neon crown) and the tallest is at least 100 studs high (fresh build, before Prune)
		if n == CITY then
			local meshedTowers, towersFirst = 0, nil
			local landmarks, thin, noGlass, noNeon, tallest, landmarkFirst = 0, 0, 0, 0, 0, nil
			for _, c in (env and env:GetChildren() or {}) do
				local isLayer = false
				for prefix in LAYER_OF_PREFIX do
					isLayer = isLayer or string.sub(c.Name, 1, #prefix) == prefix
				end
				if c:IsA("Model") and isLayer then
					local propName = propNameOf(c, biome)
					local isLandmark = string.sub(c.Name, 1, 9) == "Landmark_"
					local isSkyline = string.sub(c.Name, 1, 8) == "Horizon_"
					if isLandmark or isSkyline or CITY_TOWER_PROPS[propName] then
						for _, d in c:GetDescendants() do
							local meshAttr = d:GetAttribute("Mesh")
							local towerMesh = type(meshAttr) == "string"
								and CITY_TOWER_PROPS[string.sub(meshAttr, #biome + 2)]
							if d.Name == "MeshBounds" or CollectionService:HasTag(d, "BiomeMesh") or towerMesh then
								meshedTowers += 1
								towersFirst = towersFirst or c.Name
								break
							end
						end
						local meshAttr = c:GetAttribute("Mesh")
						if
							c:FindFirstChild("MeshBounds") ~= nil
							or CollectionService:HasTag(c, "BiomeMesh")
							or (type(meshAttr) == "string" and CITY_TOWER_PROPS[string.sub(meshAttr, #biome + 2)])
						then
							meshedTowers += 1
							towersFirst = towersFirst or c.Name
						end
					end
					if isLandmark then
						landmarks += 1
						local parts = baseParts(c)
						local glass, neon = false, false
						for _, part in parts do
							glass = glass or part.Material == Enum.Material.Glass
							neon = neon or part.Material == Enum.Material.Neon
						end
						if #parts < CITY_TOWER_MIN_PARTS then
							thin += 1
							landmarkFirst = landmarkFirst or ("%s parts=%d"):format(c.Name, #parts)
						end
						if not glass then
							noGlass += 1
							landmarkFirst = landmarkFirst or (c.Name .. " no_glass")
						end
						if not neon then
							noNeon += 1
							landmarkFirst = landmarkFirst or (c.Name .. " no_neon")
						end
						if #parts > 0 then
							local _, size = c:GetBoundingBox()
							tallest = math.max(tallest, size.Y)
						end
					end
				end
			end
			flag("city_towers_no_mesh", env ~= nil and meshedTowers == 0, meshedTowers, 0)
			flag("city_landmarks_present", landmarks >= 1, landmarks, 1)
			flag("city_landmarks_detailed", landmarks >= 1 and thin == 0, thin, 0)
			flag("city_landmarks_glass_bands", landmarks >= 1 and noGlass == 0, noGlass, 0)
			flag("city_landmarks_neon_crown", landmarks >= 1 and noNeon == 0, noNeon, 0)
			flag(
				"city_landmark_height",
				tallest >= CITY_TOWER_MIN_HEIGHT,
				math.round(tallest * 100) / 100,
				CITY_TOWER_MIN_HEIGHT
			)
			r.metrics.city = { landmarks = landmarks, tallest = tallest, first_bad = towersFirst or landmarkFirst }
		end

		-- Ground top: TrackBuilder's GROUND_TOP lowered 0.02 per track number
		local ground = t.Model:FindFirstChild("Ground")
		local top = ground and ground:IsA("BasePart") and ground.Position.Y + ground.Size.Y / 2 or math.huge
		local want = GROUND_TOP - GROUND_STEP * n
		flag(
			("ground_top_%d"):format(n),
			math.abs(top - want) <= SIZE_TOL,
			top == math.huge and -1 or math.round(top * 1000) / 1000,
			want
		)
	end
	r.metrics.mesh_props = meshCounts
	for _, t in chainB do
		t.Model:Destroy()
	end

	local spawnModel
	if SpawnArea and type(SpawnArea.Build) == "function" then
		local start = chainA[1].Model:FindFirstChild("Start", true)
		local okS, m = pcall(SpawnArea.Build, start and start.CFrame or chainA[1].Origin)
		spawnModel = okS and m or nil
	end
	flag("spawn_area_builds", spawnModel ~= nil)

	-- Probes: one prop sitting on Track 1's road must be pruned, one high above it must survive
	local models, prePrune = {}, {}
	for _, t in chainA do
		table.insert(models, t.Model)
		prePrune[t.Spec.Number] = #baseParts(t.Model:FindFirstChild("Environment"))
	end
	local env1 = chainA[1].Model:FindFirstChild("Environment")
	local nearProbe, farProbe
	if env1 then
		local road = chainA[1].Model:FindFirstChild("Road")
		local roadPart = road and baseParts(road)[1]
		local base = roadPart and roadPart.CFrame or chainA[1].Origin
		nearProbe = Instance.new("Part")
		nearProbe.Name = "CarTestNearProbe"
		nearProbe.Size = Vector3.new(2, 2, 2)
		nearProbe.CFrame = base * CFrame.new(0, 4, 0)
		nearProbe.Anchored, nearProbe.CanCollide, nearProbe.CanTouch, nearProbe.CanQuery = true, false, false, false
		nearProbe.Parent = env1
		farProbe = nearProbe:Clone()
		farProbe.Name = "CarTestFarProbe"
		farProbe.CFrame = base * CFrame.new(0, 400, 0)
		farProbe.Parent = env1
	end

	local pruneOk = false
	if Dressing and type(Dressing.Prune) == "function" then
		local okP, err = pcall(Dressing.Prune, models, spawnModel and { spawnModel } or nil)
		pruneOk = okP
		if not okP then
			r.error = tostring(err)
		end
	end
	flag("prune_runs", pruneOk)
	flag("prune_removes_road_probe", pruneOk and nearProbe ~= nil and nearProbe.Parent == nil)
	flag("prune_keeps_far_probe", pruneOk and farProbe ~= nil and farProbe.Parent == env1)
	if farProbe then
		farProbe:Destroy()
	end

	local grid, obstacles = obstacleGrid(models, spawnModel)
	r.metrics.obstacles = obstacles
	local grow = (type(clearance) == "number" and clearance or 8) - GEOM_TOL
	local counts, worstHits, visualCounts = {}, {}, {}
	for _, t in chainA do
		local n = t.Spec.Number
		local model = t.Model
		local env = model:FindFirstChild("Environment")
		flag(("environment_folder_%d"):format(n), env ~= nil and env:IsA("Folder"))
		flag(("biome_attribute_%d"):format(n), model:GetAttribute("Biome") == BIOMES[n] and BIOMES[n] ~= nil)
		local parts = baseParts(env)
		counts[tostring(n)] = { built = prePrune[n] or 0, kept = #parts }
		flag(("environment_nonempty_%d"):format(n), #parts > 0, #parts, 1)
		-- Spec Rules "Theme budget" (owner 2026-10-27): a theme Budget replaces BUDGET for its track. Only the City's
		-- value (2600) is in the doc, so every other track stays capped at BUDGET and the City at CITY_BUDGET.
		local theme = Themes and BIOMES[n] and Themes[BIOMES[n]]
		local cap = n == CITY and CITY_BUDGET or BUDGET
		local limit = theme and type(theme.Budget) == "number" and theme.Budget
			or (type(budget) == "number" and budget or BUDGET)
		limit = math.min(limit, cap)
		flag(("environment_budget_%d"):format(n), #parts <= limit, #parts, limit)
		if n == CITY then
			local got = theme and theme.Budget
			flag("city_budget_value", got == CITY_BUDGET, type(got) == "number" and got or -1, CITY_BUDGET)
		end

		-- Gate (spec Layers 4): a Gate* part on the FIRST STRAIGHT, after Prune: its horizontal distance from Start along
		-- the start direction is within 0..spec.Segments[1].Length
		local start = model:FindFirstChild("Start", true)
		local startCF = start and start.CFrame or t.Origin
		local ahead = startCF.LookVector * Vector3.new(1, 0, 1)
		ahead = ahead.Magnitude > 1e-6 and ahead.Unit or Vector3.new(0, 0, -1)
		local first = type(t.Spec.Segments) == "table" and t.Spec.Segments[1]
		local firstLength = first and type(first.Length) == "number" and first.Length or 0
		local gateAlong = nil
		for _, part in parts do
			if string.sub(part.Name, 1, 4) == "Gate" then
				local along = ((part.Position - startCF.Position) * Vector3.new(1, 0, 1)):Dot(ahead)
				if along >= 0 and along <= firstLength and (gateAlong == nil or along < gateAlong) then
					gateAlong = along
				end
			end
		end
		flag(
			("gate_at_start_%d"):format(n),
			gateAlong ~= nil,
			gateAlong == nil and -1 or math.round(gateAlong * 100) / 100,
			firstLength
		)

		-- Gate sign (owner 2026-10-21, design doc Track environments "gate signs"; spec Layers 4 "Sign"): Part GateSign
		-- in Environment/Gate, SurfaceGui GateSignGui on the face toward the oncoming car, TextLabel Biome (upper-case
		-- biome, words split) and TextLabel RecSpeed = "REC. SPEED " .. the shown Speed whose cruise speed is the
		-- track's NPC speed (RaceConfig.StatFor), formatted like the HUD Speed (Short when infinite).
		local gateModel = env and env:FindFirstChild("Gate")
		local sign = gateModel and gateModel:FindFirstChild("GateSign")
		local gui = sign and sign:IsA("BasePart") and sign:FindFirstChild("GateSignGui")
		gui = gui and gui:IsA("SurfaceGui") and gui or nil
		flag(("gate_sign_gui_%d"):format(n), gui ~= nil)
		local biomeLabel = gui and gui:FindFirstChild("Biome")
		local recLabel = gui and gui:FindFirstChild("RecSpeed")
		biomeLabel = biomeLabel and biomeLabel:IsA("TextLabel") and biomeLabel or nil
		recLabel = recLabel and recLabel:IsA("TextLabel") and recLabel or nil
		local wantBiome = BIOMES[n] and string.upper((string.gsub(BIOMES[n], "(%l)(%u)", "%1 %2"))) or "?"
		flag(("gate_sign_biome_%d"):format(n), biomeLabel ~= nil and biomeLabel.Text == wantBiome)
		local npcSpeed = NpcConfig.For(n).Speed
		local rec = RaceConfig.StatFor(npcSpeed)
		local recText = rec == math.huge and HudFormat.Short(rec) or HudFormat.SpeedText(rec)
		flag(("gate_sign_rec_speed_%d"):format(n), recLabel ~= nil and recLabel.Text == "REC. SPEED " .. recText)
		-- The recommended shown Speed really cruises at the NPC's speed (finite cases)
		local cruise = rec < math.huge and RaceConfig.SpeedFor(rec) or npcSpeed
		flag(
			("gate_sign_rec_matches_npc_%d"):format(n),
			rec > 0 and math.abs(cruise - npcSpeed) <= 1e-6 * npcSpeed,
			cruise,
			npcSpeed
		)
		-- Owner 2026-10-21 ("lower track requirements"): every track's recommended Speed is a real (finite) number,
		-- and Track 1 does not need ~10M Speed: below 10,000
		flag(("gate_sign_rec_finite_%d"):format(n), rec > 0 and rec < math.huge, rec < math.huge and rec or -1, 1)
		if n == 1 then
			flag("gate_sign_rec_track1_below_10k", rec > 0 and rec < 10000, rec, 10000)
		end
		-- Faces the oncoming car: the GUI face normal points back along the drive direction
		local facing = -1
		if gui then
			local normal = sign.CFrame:VectorToWorldSpace(Vector3.FromNormalId(gui.Face))
			facing = -(normal * Vector3.new(1, 0, 1)):Dot(ahead)
		end
		flag(("gate_sign_faces_car_%d"):format(n), facing >= 0.9, math.round(facing * 100) / 100, 0.9)

		local flagsBad, hits, firstBad = 0, 0, nil
		for _, part in parts do
			if not part.Anchored or part.CanCollide or part.CanTouch or part.CanQuery then
				flagsBad += 1
			end
			local o = firstHit(grid, part, grow)
			if o then
				hits += 1
				firstBad = firstBad or (part.Name .. " -> " .. o.Name)
			end
		end
		flag(("props_visual_only_%d"):format(n), env ~= nil and flagsBad == 0, flagsBad, 0)
		flag(("props_clear_of_road_%d"):format(n), env ~= nil and hits == 0, hits, 0)
		if firstBad then
			worstHits[tostring(n)] = firstBad
		end

		local badLights, skyLike = 0, 0
		for _, d in (env and env:GetDescendants() or {}) do
			if d:IsA("Light") and d.Shadows then
				badLights += 1
			end
		end
		for _, d in model:GetDescendants() do
			if d:IsA("Atmosphere") or d:IsA("Sky") or d:IsA("Clouds") then
				skyLike += 1
			end
		end
		flag(("lights_no_shadows_%d"):format(n), badLights == 0, badLights, 0)
		flag(("no_sky_or_atmosphere_%d"):format(n), skyLike == 0, skyLike, 0)

		-- Visual pass (owner 2026-10-26): after Prune each track keeps landmarks, horizon, scatter and flat patches
		local prefixCount = { Landmark_ = 0, Horizon_ = 0, Scatter_ = 0, Patch_ = 0 }
		local patchBad, patchFirst = 0, nil
		local ground = model:FindFirstChild("Ground")
		local groundTop = ground and ground:IsA("BasePart") and ground.Position.Y + ground.Size.Y / 2 or nil
		for _, c in (env and env:GetChildren() or {}) do
			for prefix, k in prefixCount do
				if string.sub(c.Name, 1, #prefix) == prefix then
					prefixCount[prefix] = k + 1
				end
			end
			if string.sub(c.Name, 1, 6) == "Patch_" then
				local patchParts = baseParts(c)
				if c:IsA("BasePart") then
					table.insert(patchParts, c)
				end
				for _, part in patchParts do
					local bottom = part.Position.Y - part.Size.Y / 2
					local ok = part.Size.Y <= PATCH_THICKNESS + SIZE_TOL
						and groundTop ~= nil
						and math.abs(bottom - groundTop) <= PATCH_GROUND_TOL
					if not ok then
						patchBad += 1
						patchFirst = patchFirst or ("%s y=%.3f h=%.3f"):format(part:GetFullName(), bottom, part.Size.Y)
					end
				end
			end
		end
		flag(("landmark_present_%d"):format(n), prefixCount.Landmark_ >= 1, prefixCount.Landmark_, 1)
		flag(("horizon_present_%d"):format(n), prefixCount.Horizon_ >= 1, prefixCount.Horizon_, 1)
		flag(("scatter_present_%d"):format(n), prefixCount.Scatter_ >= MIN_SCATTER, prefixCount.Scatter_, MIN_SCATTER)
		flag(("patches_present_%d"):format(n), prefixCount.Patch_ >= MIN_PATCHES, prefixCount.Patch_, MIN_PATCHES)
		flag(("patches_flat_on_ground_%d"):format(n), env ~= nil and patchBad == 0, patchBad, 0)

		-- Particles (spec Layer 8): only BiomeParticles, inside a Landmark_* model, Rate <= 8, one per landmark
		local emitters, particlesBad, particlesFirst, perLandmark = 0, 0, nil, {}
		for _, d in (env and env:GetDescendants() or {}) do
			if d:IsA("ParticleEmitter") then
				local top = d
				while top.Parent and top.Parent ~= env do
					top = top.Parent
				end
				local inLandmark = top ~= d and top:IsA("Model") and string.sub(top.Name, 1, 9) == "Landmark_"
				if d.Name == "BiomeParticles" then
					emitters += 1
				end
				if inLandmark then
					perLandmark[top] = (perLandmark[top] or 0) + 1
				end
				local ok = d.Name == "BiomeParticles"
					and inLandmark
					and d.Rate <= PARTICLE_MAX_RATE
					and perLandmark[top] <= 1
				if not ok then
					particlesBad += 1
					particlesFirst = particlesFirst or ("%s rate=%g"):format(d:GetFullName(), d.Rate)
				end
			end
		end
		flag(("particles_rules_%d"):format(n), env ~= nil and particlesBad == 0, particlesBad, 0)
		flag(("particles_present_%d"):format(n), emitters >= 1, emitters, 1)
		visualCounts[tostring(n)] = {
			landmarks = prefixCount.Landmark_,
			horizon = prefixCount.Horizon_,
			scatter = prefixCount.Scatter_,
			patches = prefixCount.Patch_,
			particles = emitters,
			first_patch_bad = patchFirst,
			first_particle_bad = particlesFirst,
		}

		-- Populated city (owner 2026-10-27, spec Layers 9 Blocks), after Prune: Block_<slot><L|R><row> models line
		-- both sides two rows deep, their footprints (oriented XZ box of each model's largest part, shrunk by
		-- BLOCK_SHRINK) never overlap, and probes every BLOCK_PROBE_STEP studs along the straight road, offset
		-- Width/2 + Near + RowDepth/2 to each side (middle of row 1), mostly fall inside a Block_ footprint.
		if n == CITY then
			local blocks, rows, sides = {}, {}, {}
			for _, c in (env and env:GetChildren() or {}) do
				local _, side, row = string.match(c.Name, "^Block_(%d+)([LR])(%d+)$")
				local largest
				for _, part in baseParts(c) do
					if largest == nil or part.Size.X * part.Size.Z > largest.Size.X * largest.Size.Z then
						largest = part
					end
				end
				if side and c:IsA("Model") and largest then
					table.insert(blocks, { Name = c.Name, Part = largest })
					rows[tonumber(row)] = true
					sides[side] = true
				end
			end
			flag("city_blocks_count", #blocks >= CITY_MIN_BLOCKS, #blocks, CITY_MIN_BLOCKS)
			flag("city_blocks_both_rows", rows[1] == true and rows[2] == true)
			flag("city_blocks_both_sides", sides.L == true and sides.R == true)

			local overlaps, overlapFirst = 0, nil
			local shrunk, full = {}, {}
			for i, b in blocks do
				shrunk[i] = footprint(b.Part, BLOCK_SHRINK)
				full[i] = footprint(b.Part, 0)
			end
			for i = 1, #blocks do
				for j = i + 1, #blocks do
					if footprintsOverlap(shrunk[i], shrunk[j]) then
						overlaps += 1
						overlapFirst = overlapFirst or (blocks[i].Name .. " x " .. blocks[j].Name)
					end
				end
			end
			flag("city_blocks_no_overlap", #blocks > 0 and overlaps == 0, overlaps, 0)

			local cfg = theme and type(theme.Blocks) == "table" and theme.Blocks or nil
			local probes, covered = 0, 0
			if cfg and type(cfg.Near) == "number" and type(cfg.RowDepth) == "number" then
				local offset = t.Layout.Width / 2 + cfg.Near + cfg.RowDepth / 2
				local wps, curv = t.Layout.Waypoints, t.Layout.Curvature
				local along, nextProbe = 0, 0
				for i = 2, #wps do
					if curv[i] == 0 then
						local a, b = t.Origin * wps[i - 1], t.Origin * wps[i]
						local d = Vector2.new(b.X - a.X, b.Z - a.Z)
						local len = d.Magnitude
						if len > 1e-6 then
							local dir = d.Unit
							local right = Vector2.new(-dir.Y, dir.X)
							while nextProbe <= along + len do
								local p = Vector2.new(a.X, a.Z) + dir * (nextProbe - along)
								for _, s in { -1, 1 } do
									local q = p + right * s * offset
									probes += 1
									for _, f in full do
										if footprintHas(f, q) then
											covered += 1
											break
										end
									end
								end
								nextProbe += BLOCK_PROBE_STEP
							end
							along += len
						end
					end
				end
			end
			local coverage = probes > 0 and covered / probes or 0
			flag(
				"city_blocks_gap",
				probes > 0 and coverage >= BLOCK_MIN_COVERAGE,
				math.round(coverage * 1000) / 1000,
				BLOCK_MIN_COVERAGE
			)
			r.metrics.city_blocks = {
				count = #blocks,
				overlaps = overlaps,
				first_overlap = overlapFirst,
				probes = probes,
				covered = covered,
			}
		end
	end
	r.metrics.parts = counts
	r.metrics.first_overlap = worstHits
	r.metrics.visual = visualCounts

	local after = lightingSnapshot()
	local lightOk = math.abs(after.ClockTime - before.ClockTime) <= LIGHT_TOL
		and math.abs(after.Brightness - before.Brightness) <= LIGHT_TOL
		and colorDiff(after.OutdoorAmbient, before.OutdoorAmbient) <= LIGHT_TOL
		and colorDiff(after.Ambient, before.Ambient) <= LIGHT_TOL
	flag("lighting_unchanged", lightOk)
	flag(
		"no_new_sky_atmosphere_clouds",
		after.Atmosphere == before.Atmosphere and after.Sky == before.Sky and after.Clouds == before.Clouds
	)

	for _, t in chainA do
		t.Model:Destroy()
	end
	if spawnModel then
		spawnModel:Destroy()
	end
	return r
end

return Tests
