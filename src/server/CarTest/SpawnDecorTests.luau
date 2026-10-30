--!nonstrict
-- BRIEF (owner, 2026-10-30; docs/SPAWN_AND_ROLLS_SPEC.md section 1b, design doc "Owner spawn-area redesign,
-- 2026-10-30"): "I want an open track theme, make the ground pixar themed. The floor can become concrete. Yes up to
-- your design disgression. Portal spot is correct. 40 stud tower is ok. Continue implementation".
-- Spec 1b.4-1b.9 and 1b.3: every theme piece lives under Workspace.SpawnArea.Decor (built by Shared/SpawnDecor);
-- anchored, CanTouch = false, flat paint never collides or queries; nothing in a plot, the placed pad, the market,
-- a pedestal / stand, the pit lane (when taller than 0.1), the walk spawn's 10 studs (when taller than 0.1), the
-- portal spot, or outside the floor; a 40-stud timing tower at local (176, -92); at most 4 lights, no shadows,
-- Lighting untouched; at most 300 new parts in the whole redesign (Decor + the SpawnArea Edge* kerb blocks; owner
-- 2026-10-30, was 250 in Decor only) and 20,000 triangles in Decor; small parts cast no shadow; the build is deterministic;
-- the CheckpointNpc ring and the pavilion RoofPurple mesh are no longer purple.
-- Layout reference: drafts/environments/spawn-area-redesign/DRAFT.md sections 3 and 6.
-- Contract assumed by this test: `SpawnDecor.Build(startCFrame) -> Instance` named "Decor" (the caller parents it),
-- the tower is a descendant named "TimingTower" (Model or BasePart).
-- Written before Shared/SpawnDecor exists: red by design.

local AssetService = game:GetService("AssetService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tests = {}

local MAX_PARTS = 300 -- 1b.9: Decor + Edge* kerb blocks (owner 2026-10-30)
local MAX_TRIANGLES = 20000 -- 1b.9
local MAX_LIGHTS = 4 -- 1b.8
local PAINT_HEIGHT = 0.1 -- 1b.4: flat paint is 0.1 high
local HEIGHT_TOL = 1e-3
local SHADOW_SIZE = 30 -- 1b.9 / RENDERING_SPEC.md section 3: Size.Magnitude <= 30 casts no shadow
local WALK_CLEAR = 10 -- 1b.4: studs around the walk spawn with nothing taller than 0.1
local TRACK_CLEAR = 4 -- studs every decor part keeps from any track road or wall (DRAFT.md section 3)
local PAD_HALF = Vector2.new(18, 22) -- SPAWN_AND_ROLLS_SPEC.md section 1: placed footprint PAD_CENTER +/- (18, 22)
local PIT_X = { 184, 200 } -- 1b.5: the pit-lane strips in front of the plots
local PIT_Z = { -132, -116 }
local PORTAL = { X = 96, Z = -88, HalfX = 12, HalfZ = 6 } -- 1b.7: fixed spot, 24 x 12 footprint facing +Z
local TOWER = { X = 176, Z = -92, Height = 40 } -- 1b.6
local TOWER_TOL = 0.5 -- studs
local GEOM_TOL = 0.05 -- studs of footprint overlap ignored (parts that only touch)
local CFRAME_TOL = 1e-4

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

local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) ~= math.huge
end

local function isPurple(c) -- any clearly saturated violet hue (the old purples sit at hue 0.74-0.78)
	if typeof(c) ~= "Color3" then
		return false
	end
	local h, s = c:ToHSV()
	return h >= 0.7 and h <= 0.9 and s >= 0.25
end

local function corners(part)
	local cf, s = part.CFrame, part.Size / 2
	local list = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(list, cf:PointToWorldSpace(Vector3.new(x * s.X, y * s.Y, z * s.Z)))
			end
		end
	end
	return list
end

local function worldHeight(part)
	local lo, hi = math.huge, -math.huge
	for _, w in corners(part) do
		lo, hi = math.min(lo, w.Y), math.max(hi, w.Y)
	end
	return hi - lo
end

-- Horizontal footprint of a part: its 8 corners on XZ and the projected axes (as in the spawn_area scenario).
local function partPoly(part)
	local pts, dirs = {}, {}
	for _, w in corners(part) do
		table.insert(pts, Vector2.new(w.X, w.Z))
	end
	for _, v in { part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector } do
		local d = Vector2.new(v.X, v.Z)
		if d.Magnitude > 1e-3 then
			table.insert(dirs, d.Unit)
		end
	end
	return { Points = pts, Dirs = dirs }
end

local function rectPoly(base, minV, maxV)
	local pts = {}
	for _, x in { minV.X, maxV.X } do
		for _, z in { minV.Y, maxV.Y } do
			local w = base:PointToWorldSpace(Vector3.new(x, 0, z))
			table.insert(pts, Vector2.new(w.X, w.Z))
		end
	end
	local r = base.RightVector
	return { Points = pts, Dirs = { Vector2.new(r.X, r.Z).Unit } }
end

local SIDES = 32
local function circlePoly(base, x, z, radius) -- never smaller than the circle
	local pts, dirs = {}, {}
	local outer = radius / math.cos(math.pi / SIDES)
	for k = 0, SIDES - 1 do
		local a = 2 * math.pi * k / SIDES
		local w = base:PointToWorldSpace(Vector3.new(x + outer * math.cos(a), 0, z + outer * math.sin(a)))
		table.insert(pts, Vector2.new(w.X, w.Z))
		local n = base:VectorToWorldSpace(Vector3.new(math.cos(a + math.pi / SIDES), 0, math.sin(a + math.pi / SIDES)))
		table.insert(dirs, Vector2.new(n.X, n.Z).Unit)
	end
	return { Points = pts, Dirs = dirs }
end

-- Separating-axis test of two convex footprints: > 0 is the gap, <= 0 means they overlap by -value.
local function separation(a, b)
	local best = -math.huge
	for _, poly in { a, b } do
		for _, d in poly.Dirs do
			for _, ax in { d, Vector2.new(-d.Y, d.X) } do
				local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
				for _, p in a.Points do
					local v = p:Dot(ax)
					aMin, aMax = math.min(aMin, v), math.max(aMax, v)
				end
				for _, p in b.Points do
					local v = p:Dot(ax)
					bMin, bMax = math.min(bMin, v), math.max(bMax, v)
				end
				best = math.max(best, math.max(bMin - aMax, aMin - bMax))
			end
		end
	end
	return best
end

local function partsOf(root)
	local list = {}
	if root and root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, d in root and root:GetDescendants() or {} do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- Path of every BasePart under root with its CFrame, in GetDescendants order.
local function layout(root)
	local list = {}
	for _, p in partsOf(root) do
		local names, node = {}, p
		while node and node ~= root do
			table.insert(names, 1, node.Name)
			node = node.Parent
		end
		table.insert(list, { Path = table.concat(names, "/"), CFrame = p.CFrame })
	end
	return list
end

local function sameLayout(a, b)
	if #a == 0 or #a ~= #b then
		return false
	end
	for i, e in a do
		local f = b[i]
		if e.Path ~= f.Path then
			return false
		end
		local ca, cb = { e.CFrame:GetComponents() }, { f.CFrame:GetComponents() }
		for k = 1, 12 do
			if math.abs(ca[k] - cb[k]) > CFRAME_TOL then
				return false
			end
		end
	end
	return true
end

local LIGHTING_PROPS = {
	"Ambient",
	"Brightness",
	"ClockTime",
	"ColorShift_Bottom",
	"ColorShift_Top",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ExposureCompensation",
	"FogColor",
	"FogEnd",
	"FogStart",
	"GeographicLatitude",
	"GlobalShadows",
	"OutdoorAmbient",
}
local function lightingSnapshot()
	local parts = {}
	for _, key in LIGHTING_PROPS do
		table.insert(parts, key .. "=" .. tostring(Lighting[key]))
	end
	local kids = {}
	for _, d in Lighting:GetDescendants() do
		table.insert(kids, d.ClassName .. ":" .. d.Name)
	end
	table.sort(kids)
	return table.concat(parts, ";") .. "|" .. table.concat(kids, ";")
end

-- Triangles of every MeshPart, read with EditableMesh once per MeshId; nil when that is not possible here.
local function triangleTotal(parts)
	local perMesh, total = {}, 0
	for _, p in parts do
		if p:IsA("MeshPart") and p.MeshId ~= "" then
			local n = perMesh[p.MeshId]
			if n == nil then
				local ok, mesh = pcall(function()
					return AssetService:CreateEditableMeshAsync(Content.fromUri(p.MeshId))
				end)
				if not ok or not mesh then
					return nil
				end
				local okFaces, faces = pcall(function()
					return mesh:GetFaces()
				end)
				mesh:Destroy()
				if not okFaces then
					return nil
				end
				n = #faces
				perMesh[p.MeshId] = n
			end
			total += n
		end
	end
	return total
end

function Tests.spawn_decor()
	local r, flag = report("spawn_decor")
	local spawnArea = module(Shared, "SpawnArea")
	local decorModule = module(Shared, "SpawnDecor")
	local workshopConfig = module(Shared, "WorkshopConfig")
	local lbConfig = module(Shared, "LeaderboardConfig")
	local passConfig = module(Shared, "PassCarConfig")
	local registry = module(Shared, "TrackRegistry")

	flag("spawn_decor_module_exists", decorModule ~= nil and type(decorModule.Build) == "function")

	-- The live world
	local area = Workspace:FindFirstChild("SpawnArea")
	local trackFolder = Workspace:FindFirstChild("Track")
	local chain = registry and type(registry.Chain) == "function" and registry.Chain() or {}
	local track1 = trackFolder and chain[1] and trackFolder:FindFirstChild(chain[1].Name)
	local startPart = track1 and track1:FindFirstChild("Start")
	local A = spawnArea or {}
	local worldOk = area ~= nil
		and startPart ~= nil
		and startPart:IsA("BasePart")
		and typeof(A.AREA_MIN) == "Vector2"
		and typeof(A.AREA_MAX) == "Vector2"
		and typeof(A.PAD_CENTER) == "Vector2"
		and type(A.WalkCFrame) == "function"
	flag("spawn_decor_world_present", worldOk)

	-- 1b.3: leftover purple retinted (checked even before Decor exists)
	local npc = area and area:FindFirstChild("CheckpointNpc", true)
	local ring = npc and npc:FindFirstChild("Ring", true)
	local ringOk = ring ~= nil and ring:IsA("BasePart") and not isPurple(ring.Color)
	flag("spawn_decor_checkpoint_ring_not_purple", ringOk)
	local roof = area and area:FindFirstChild("RoofPurple", true)
	local roofOk = roof ~= nil and roof:IsA("BasePart") and not isPurple(roof.Color)
	flag("spawn_decor_pavilion_roof_not_purple", roofOk)

	local decor = area and area:FindFirstChild("Decor")
	flag("spawn_decor_folder_exists", decor ~= nil)
	if not (decor and worldOk) then
		return r
	end
	local base = startPart.CFrame
	local parts = partsOf(decor)
	r.metrics.decor_parts = #parts

	-- 1b.9: budget. The redesign's only new parts outside Decor are the red / white Edge* kerb blocks (direct children).
	local kerbs = 0
	for _, child in area:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 4) == "Edge" then
			kerbs += 1
		end
	end
	local redesignParts = #parts + kerbs
	r.metrics.kerb_parts = kerbs
	r.metrics.redesign_parts = redesignParts
	flag("spawn_decor_has_parts", #parts > 0, #parts, 1)
	flag(
		"spawn_decor_part_budget",
		#parts > 0 and redesignParts <= MAX_PARTS,
		("%d (decor %d + kerbs %d)"):format(redesignParts, #parts, kerbs),
		MAX_PARTS
	)
	local tris = triangleTotal(parts)
	if tris == nil then
		-- the harness has no skip state: an unmeasurable budget is a failure, never a silent pass
		r.metrics.triangles = "not measurable (EditableMesh unavailable)"
		flag("spawn_decor_triangle_budget", false, "skipped: EditableMesh unavailable", MAX_TRIANGLES)
	else
		r.metrics.triangles = tris
		flag("spawn_decor_triangle_budget", tris <= MAX_TRIANGLES, tris, MAX_TRIANGLES)
	end

	-- 1b.4 / 1b.9: part flags
	local loose, touchable, paintSolid, visibleCollider, smallShadow = 0, 0, 0, 0, 0
	local tall = {}
	for _, p in parts do
		if not p.Anchored then
			loose += 1
		end
		if p.CanTouch then
			touchable += 1
		end
		local h = worldHeight(p)
		if h <= PAINT_HEIGHT + HEIGHT_TOL then
			if p.CanCollide or p.CanQuery then
				paintSolid += 1
			end
		else
			table.insert(tall, p)
		end
		if p.CanCollide and p.Transparency < 1 then
			visibleCollider += 1
		end
		if p.Size.Magnitude <= SHADOW_SIZE and p.CastShadow then
			smallShadow += 1
		end
	end
	flag("spawn_decor_all_anchored", loose == 0, loose, 0)
	flag("spawn_decor_no_can_touch", touchable == 0, touchable, 0)
	flag("spawn_decor_paint_non_colliding", paintSolid == 0, paintSolid, 0)
	flag("spawn_decor_colliders_invisible", visibleCollider == 0, visibleCollider, 0)
	flag("spawn_decor_small_parts_no_shadow", smallShadow == 0, smallShadow, 0)

	-- 1b.4 / 1b.5 / 1b.7: keep-out zones
	local function overlapCount(list, polys)
		local n = 0
		for _, p in list do
			local fp = partPoly(p)
			for _, poly in polys do
				if separation(fp, poly) < -GEOM_TOL then
					n += 1
					break
				end
			end
		end
		return n
	end
	local plots = {}
	for _, plot in workshopConfig and workshopConfig.Plots or {} do
		table.insert(plots, rectPoly(base, plot.Min, plot.Max))
	end
	local marketplace = area:FindFirstChild("Marketplace")
	local market = marketplace and marketplace:IsA("Model") and marketplace.PrimaryPart
	local stands = {}
	local B = lbConfig and lbConfig.BEST_ROLL
	if type(B) == "table" and finite(B.X) and finite(B.Z) and finite(B.RADIUS) then
		table.insert(stands, circlePoly(base, B.X, B.Z, B.RADIUS))
	end
	local P = passConfig or {}
	for _, e in type(P.Pedestals) == "table" and P.Pedestals or {} do
		if finite(e.X) and finite(e.Z) and finite(P.RADIUS) then
			table.insert(stands, circlePoly(base, e.X, e.Z, P.RADIUS))
		end
	end
	local walk = base:PointToObjectSpace(A.WalkCFrame(base).Position)
	local zones = {
		{ Label = "plots", Parts = parts, Polys = plots, Need = 7 },
		{
			Label = "pad",
			Parts = parts,
			Polys = { rectPoly(base, A.PAD_CENTER - PAD_HALF, A.PAD_CENTER + PAD_HALF) },
			Need = 1,
		},
		{ Label = "marketplace", Parts = parts, Polys = market and { partPoly(market) } or {}, Need = 1 },
		{ Label = "stands", Parts = parts, Polys = stands, Need = 3 }, -- Best Roll + the two pass-car pedestals
		{
			Label = "pit_lane",
			Parts = tall,
			Polys = {
				rectPoly(base, Vector2.new(PIT_X[1], A.AREA_MIN.Y), Vector2.new(PIT_X[2], A.AREA_MAX.Y)),
				rectPoly(base, Vector2.new(A.AREA_MIN.X, PIT_Z[1]), Vector2.new(PIT_X[2], PIT_Z[2])),
			},
			Need = 2,
		},
		{ Label = "walk_spawn", Parts = tall, Polys = { circlePoly(base, walk.X, walk.Z, WALK_CLEAR) }, Need = 1 },
		{
			Label = "portal_spot",
			Parts = parts,
			Polys = {
				rectPoly(
					base,
					Vector2.new(PORTAL.X - PORTAL.HalfX, PORTAL.Z - PORTAL.HalfZ),
					Vector2.new(PORTAL.X + PORTAL.HalfX, PORTAL.Z + PORTAL.HalfZ)
				),
			},
			Need = 1,
		},
	}
	for _, zone in zones do
		local n = overlapCount(zone.Parts, zone.Polys)
		local known = #zone.Polys >= zone.Need -- a missing zone fails, never passes by default
		flag("spawn_decor_clear_of_" .. zone.Label, known and n == 0, known and n or -1, 0)
	end

	-- 1b.4: inside AREA_MIN..AREA_MAX at any height
	local outside = 0
	for _, p in parts do
		for _, w in corners(p) do
			local l = base:PointToObjectSpace(w)
			if
				l.X < A.AREA_MIN.X - GEOM_TOL
				or l.X > A.AREA_MAX.X + GEOM_TOL
				or l.Z < A.AREA_MIN.Y - GEOM_TOL
				or l.Z > A.AREA_MAX.Y + GEOM_TOL
			then
				outside += 1
				break
			end
		end
	end
	flag("spawn_decor_inside_area", outside == 0, outside, 0)

	-- at least TRACK_CLEAR from every road or wall part of the chain
	local trackParts = {}
	for _, folder in trackFolder and trackFolder:GetDescendants() or {} do
		if folder.Name == "Road" or folder.Name == "Walls" then
			for _, p in partsOf(folder) do
				table.insert(trackParts, p)
			end
		end
	end
	local nearTrack, minGap = 0, math.huge
	for _, p in parts do
		local fp = partPoly(p)
		local reach = p.Size.Magnitude / 2 + TRACK_CLEAR
		for _, t in trackParts do
			local d = Vector2.new(p.Position.X - t.Position.X, p.Position.Z - t.Position.Z).Magnitude
			if d <= reach + t.Size.Magnitude / 2 then
				local gap = separation(fp, partPoly(t))
				minGap = math.min(minGap, gap)
				if gap < TRACK_CLEAR then
					nearTrack += 1
					break
				end
			end
		end
	end
	r.metrics.track_min_gap = minGap == math.huge and -1 or math.round(minGap * 1000) / 1000
	flag("spawn_decor_track_parts_found", #trackParts > 0, #trackParts, 1)
	flag("spawn_decor_clear_of_track", #trackParts > 0 and nearTrack == 0, nearTrack, 0)

	-- 1b.6: timing tower
	local tower = decor:FindFirstChild("TimingTower", true)
	flag("spawn_decor_tower_exists", tower ~= nil and (tower:IsA("Model") or tower:IsA("BasePart")))
	if tower and (tower:IsA("Model") or tower:IsA("BasePart")) then
		local cf, size
		if tower:IsA("Model") then
			cf, size = tower:GetBoundingBox()
		else
			cf, size = tower.CFrame, tower.Size
		end
		local l = base:PointToObjectSpace(cf.Position)
		local h = size.Y
		r.metrics.tower_height = math.round(h * 1000) / 1000
		flag("spawn_decor_tower_height", math.abs(h - TOWER.Height) <= TOWER_TOL, h, TOWER.Height)
		local off = Vector2.new(l.X - TOWER.X, l.Z - TOWER.Z).Magnitude
		flag("spawn_decor_tower_position", off <= TOWER_TOL, off, TOWER_TOL)
	end

	-- 1b.8: lights
	local lights, shadowed = 0, 0
	for _, d in decor:GetDescendants() do
		if d:IsA("Light") then
			lights += 1
			if d.Shadows then
				shadowed += 1
			end
		end
	end
	flag("spawn_decor_light_count", lights <= MAX_LIGHTS, lights, MAX_LIGHTS)
	flag("spawn_decor_lights_no_shadows", shadowed == 0, shadowed, 0)

	-- 1b.8 + determinism: two fresh builds leave Lighting as it was and match each other and the live Decor
	if decorModule and type(decorModule.Build) == "function" then
		local before = lightingSnapshot()
		local okA, a = pcall(decorModule.Build, base)
		local okB, b = pcall(decorModule.Build, base)
		flag("spawn_decor_build_runs", okA and okB and typeof(a) == "Instance" and typeof(b) == "Instance")
		flag("spawn_decor_lighting_unchanged", lightingSnapshot() == before)
		if okA and okB and typeof(a) == "Instance" and typeof(b) == "Instance" then
			local la, lb = layout(a), layout(b)
			flag("spawn_decor_deterministic", sameLayout(la, lb), #la, #lb)
			flag("spawn_decor_matches_live", sameLayout(la, layout(decor)), #la, #parts)
		end
		for _, built in { okA and a, okB and b } do
			if typeof(built) == "Instance" and built ~= decor then
				built:Destroy()
			end
		end
	end

	return r
end

return Tests
