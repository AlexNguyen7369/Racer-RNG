--!nonstrict
-- Paddock theme of the spawn area (docs/SPAWN_AND_ROLLS_SPEC.md section 1b, owner 2026-10-30; layout:
-- drafts/environments/spawn-area-redesign/DRAFT.md section 3). A pure layout table plus a builder, like
-- MarketplaceBuilder. Everything is in the local (x, z) space of Track 1's flattened Start, like Shared/SpawnArea.
-- Flat paint is 0.1 high (top at TOP_Y + 0.05) and never collides or queries; tall pieces are visual only and
-- collide through one invisible box each. Nothing touches Lighting; at most 4 lights, none with shadows.
-- TimingTower and TyreStack use the Blender meshes in ReplicatedStorage.SpawnPaddockProps when they are there,
-- else rounded parts of the same name and size.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpawnDecor = {}

SpawnDecor.TOP_Y = 1 -- SpawnArea.TOP_Y (not required: SpawnArea requires this module)
SpawnDecor.PAINT_HEIGHT = 0.1
SpawnDecor.SPAWN_CENTER = Vector2.new(104, -28) -- hub centre, where Spawn and the walk spawn are
SpawnDecor.COLORS = { -- section 1b.2 placeholders
	Walkway = Color3.fromRGB(245, 232, 200),
	Lane = Color3.fromRGB(78, 82, 96),
	Line = Color3.fromRGB(245, 245, 240),
	Red = Color3.fromRGB(235, 70, 60),
	White = Color3.fromRGB(245, 245, 240),
	Teal = Color3.fromRGB(40, 200, 190),
	Amber = Color3.fromRGB(255, 190, 65),
	Tyre = Color3.fromRGB(44, 46, 56),
	Board = Color3.fromRGB(52, 56, 72),
	Metal = Color3.fromRGB(220, 224, 232),
}
SpawnDecor.WALKWAY_WIDTH = 12
-- From the spawn centre towards To; the first Skip studs stay bare so walkways never overlap the grid box or each other
SpawnDecor.WALKWAYS = {
	{ Name = "WalkToPad", To = Vector2.new(44, -2), Skip = 15 }, -- ends short of the pavilion's hub entrance
	{ Name = "WalkToMarket", To = Vector2.new(78, -54), Skip = 22 }, -- ends short of the market (x <= 72)
	{ Name = "WalkToPortal", To = Vector2.new(97, -78), Skip = 16 }, -- ends short of the portal spot (z >= -82)
}
SpawnDecor.GRID = { Size = 20, Line = 1 } -- spawn grid box outline around SPAWN_CENTER
-- Pit lane paint (section 1b.5: nothing taller than 0.1 in x 184..200 or z -132..-116). Plot 4 faces the 8-stud
-- gap beside plot 5, so its lane is narrower.
SpawnDecor.LANES = {
	{ Name = "PitLaneEast", Min = Vector2.new(184, -131), Max = Vector2.new(199, 36), Boxes = { 1, 2, 3 } },
	{ Name = "PitLaneSouth", Min = Vector2.new(32, -131), Max = Vector2.new(184, -116), Boxes = { 5, 6, 7 } },
	{ Name = "PitLaneCorner", Min = Vector2.new(192, -180), Max = Vector2.new(199, -131), Boxes = { 4 } },
}
SpawnDecor.LINES = {
	{ Name = "PitLineEast", Min = Vector2.new(199, -180), Max = Vector2.new(200, 36) },
	{ Name = "PitLineSouth", Min = Vector2.new(32, -132), Max = Vector2.new(192, -131) },
}
SpawnDecor.KERBS = { -- red / white blocks along the hub side of the lane
	{ Name = "KerbEast", Min = Vector2.new(182, -114), Max = Vector2.new(184, 36) },
	{ Name = "KerbSouth", Min = Vector2.new(32, -116), Max = Vector2.new(184, -114) },
}
SpawnDecor.KERB_BLOCK = 4
SpawnDecor.PIT_BOXES = { -- the painted box in front of plot 1..7 (white outline, plot number)
	{ Min = Vector2.new(186.5, -4), Max = Vector2.new(196.5, 28) },
	{ Min = Vector2.new(186.5, -60), Max = Vector2.new(196.5, -28) },
	{ Min = Vector2.new(186.5, -116), Max = Vector2.new(196.5, -84) },
	{ Min = Vector2.new(193, -172), Max = Vector2.new(198, -140) },
	{ Min = Vector2.new(152, -128.5), Max = Vector2.new(184, -118.5) },
	{ Min = Vector2.new(96, -128.5), Max = Vector2.new(128, -118.5) },
	{ Min = Vector2.new(40, -128.5), Max = Vector2.new(72, -118.5) },
}
SpawnDecor.TOWER = { Center = Vector2.new(176, -92), Size = Vector3.new(6, 40, 6) } -- section 1b.6
SpawnDecor.MASTS = { Vector2.new(249, 41), Vector2.new(249, -185), Vector2.new(28, -185) }
SpawnDecor.MAST_SIZE = Vector3.new(2, 30, 2)
SpawnDecor.MAST_AIM = Vector2.new(140, -72) -- the lamps lean towards the middle of the area
SpawnDecor.TYRE_SIZE = Vector3.new(3, 3, 3)
SpawnDecor.TYRE_X = 249.5 -- behind plots 1-4: x 248..251, between the plots' back (248) and the edge wall (251)
SpawnDecor.TYRE_Z = {} -- 12 stacks, 18 studs apart
for i = 0, 11 do
	table.insert(SpawnDecor.TYRE_Z, -171 + 18 * i)
end

-- Blender props (assets/studio/SpawnPaddockProps.rbxmx), loaded once like MarketplaceBuilder's meshes
local props = {}
local folder = ReplicatedStorage:FindFirstChild("SpawnPaddockProps")
for _, name in { "TimingTower", "TyreStack" } do
	local mesh = folder and folder:FindFirstChild(name)
	if mesh and mesh:IsA("MeshPart") and mesh.MeshId ~= "" then
		if mesh.MeshSize.Magnitude == 0 then -- Rojo leaves MeshParts unloaded: apply the uploaded mesh
			pcall(function()
				local loaded = AssetService:CreateMeshPartAsync(Content.fromUri(mesh.MeshId), {
					CollisionFidelity = Enum.CollisionFidelity.Box,
				})
				local texture = mesh.TextureID
				mesh:ApplyMesh(loaded)
				mesh.TextureID = texture
				loaded:Destroy()
			end)
		end
		if mesh.MeshSize.Magnitude > 0 then
			props[name] = mesh
		end
	end
end

-- Track 1's start, flattened: yaw only, at ground level (same as SpawnArea.Base)
local function base(startCFrame)
	local look = startCFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, -1)
	local p = Vector3.new(startCFrame.Position.X, 0, startCFrame.Position.Z)
	return CFrame.lookAt(p, p + flat)
end

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = size.Magnitude > 30 -- RENDERING_SPEC.md section 3
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function collider(parent, size, cf)
	local p = part(parent, "Collider", size, cf, Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CanCollide = true
	p.CanQuery = true
	p.CastShadow = false
	return p
end

-- Upright cylinder (the part's X axis is its length) spanning y0..y1 in `frame`
local function disc(parent, name, frame, y0, y1, diameter, color, material)
	local cf = frame * CFrame.new(0, (y0 + y1) / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	return part(parent, name, Vector3.new(y1 - y0, diameter, diameter), cf, color, material, Enum.PartType.Cylinder)
end

-- Visual mesh scaled to the spec size, or nil when the prop is not in ReplicatedStorage
local function mesh(parent, name, size, cf)
	local template = props[name]
	if not template then
		return nil
	end
	local m = template:Clone()
	m.Name = "Mesh"
	m.Size = size
	m.CFrame = cf
	m.Anchored = true
	m.CanCollide = false
	m.CanTouch = false
	m.CanQuery = false
	m.CastShadow = size.Magnitude > 30
	m.Parent = parent
	return m
end

function SpawnDecor.Build(startCFrame)
	local b = base(startCFrame)
	local top = SpawnDecor.TOP_Y
	local C = SpawnDecor.COLORS
	local decor = Instance.new("Model")
	decor.Name = "Decor"

	local paintY = top + 0.05 - SpawnDecor.PAINT_HEIGHT / 2
	local function paint(parent, name, min, max, color)
		local c = (min + max) / 2
		local size = Vector3.new(max.X - min.X, SpawnDecor.PAINT_HEIGHT, max.Y - min.Y)
		return part(parent, name, size, b * CFrame.new(c.X, paintY, c.Y), color)
	end
	local function group(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = decor
		return f
	end

	-- Spawn grid box and walkways
	local walk = group("Walkways")
	local s, g = SpawnDecor.SPAWN_CENTER, SpawnDecor.GRID
	local h, w = g.Size / 2, g.Line
	paint(walk, "GridNorth", s + Vector2.new(-h, h - w), s + Vector2.new(h, h), C.White)
	paint(walk, "GridSouth", s + Vector2.new(-h, -h), s + Vector2.new(h, -h + w), C.White)
	paint(walk, "GridWest", s + Vector2.new(-h, -h + w), s + Vector2.new(-h + w, h - w), C.White)
	paint(walk, "GridEast", s + Vector2.new(h - w, -h + w), s + Vector2.new(h, h - w), C.White)
	for _, spec in SpawnDecor.WALKWAYS do
		local dir = (spec.To - s).Unit
		local from = s + dir * spec.Skip
		local length = (spec.To - from).Magnitude
		local mid = (from + spec.To) / 2
		local cf = CFrame.lookAt(
			b:PointToWorldSpace(Vector3.new(mid.X, paintY, mid.Y)),
			b:PointToWorldSpace(Vector3.new(spec.To.X, paintY, spec.To.Y))
		)
		part(walk, spec.Name, Vector3.new(SpawnDecor.WALKWAY_WIDTH, SpawnDecor.PAINT_HEIGHT, length), cf, C.Walkway)
	end

	-- Pit lane: asphalt around each pit box (never stacked, so no z-fighting), white lines, kerbs
	local pit = group("PitLane")
	for _, lane in SpawnDecor.LANES do
		local holes = {}
		for _, n in lane.Boxes do
			table.insert(holes, SpawnDecor.PIT_BOXES[n])
		end
		-- Sweep the lane in x slabs cut at every box edge; in each slab, asphalt fills the z gaps between boxes
		local cuts = { lane.Min.X, lane.Max.X }
		for _, r in holes do
			table.insert(cuts, r.Min.X)
			table.insert(cuts, r.Max.X)
		end
		table.sort(cuts)
		local piece = 0
		for i = 1, #cuts - 1 do
			local x0, x1 = cuts[i], cuts[i + 1]
			if x1 - x0 > 1e-6 then
				local inSlab = {}
				for _, r in holes do
					if r.Min.X < x1 - 1e-6 and r.Max.X > x0 + 1e-6 then
						table.insert(inSlab, r)
					end
				end
				table.sort(inSlab, function(p, q)
					return p.Min.Y < q.Min.Y
				end)
				local z = lane.Min.Y
				for k = 1, #inSlab + 1 do
					local z1 = inSlab[k] and inSlab[k].Min.Y or lane.Max.Y
					if z1 - z > 1e-6 then
						piece += 1
						paint(pit, lane.Name .. "_" .. piece, Vector2.new(x0, z), Vector2.new(x1, z1), C.Lane)
					end
					z = inSlab[k] and inSlab[k].Max.Y or z
				end
			end
		end
	end
	for n, r in ipairs(SpawnDecor.PIT_BOXES) do
		local box = Instance.new("Folder")
		box.Name = "PitBox_" .. n
		box.Parent = pit
		local min, max, lw = r.Min, r.Max, 1
		paint(box, "LineA", min, Vector2.new(max.X, min.Y + lw), C.Line)
		paint(box, "LineB", Vector2.new(min.X, max.Y - lw), max, C.Line)
		paint(box, "LineC", Vector2.new(min.X, min.Y + lw), Vector2.new(min.X + lw, max.Y - lw), C.Line)
		paint(box, "LineD", Vector2.new(max.X - lw, min.Y + lw), Vector2.new(max.X, max.Y - lw), C.Line)
		local inner = paint(box, "Inner", min + Vector2.new(lw, lw), max - Vector2.new(lw, lw), C.Lane)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Number"
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 10
		gui.MaxDistance = 150
		gui.Parent = inner
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = tostring(n)
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = C.Amber
		label.Parent = gui
	end
	for _, line in SpawnDecor.LINES do
		paint(pit, line.Name, line.Min, line.Max, C.Line)
	end
	for _, kerb in SpawnDecor.KERBS do
		local along = kerb.Max.X - kerb.Min.X >= kerb.Max.Y - kerb.Min.Y and "X" or "Y"
		local from, to = kerb.Min[along], kerb.Max[along]
		local k = 0
		for a = from, to - 1e-6, SpawnDecor.KERB_BLOCK do
			local a1 = math.min(a + SpawnDecor.KERB_BLOCK, to)
			local min = along == "X" and Vector2.new(a, kerb.Min.Y) or Vector2.new(kerb.Min.X, a)
			local max = along == "X" and Vector2.new(a1, kerb.Max.Y) or Vector2.new(kerb.Max.X, a1)
			k += 1
			paint(pit, kerb.Name .. "_" .. k, min, max, k % 2 == 1 and C.Red or C.White)
		end
	end

	-- Timing tower (section 1b.6): a Model whose bounding box is TOWER.Size at TOWER.Center
	local t = SpawnDecor.TOWER
	local tower = Instance.new("Model")
	tower.Name = "TimingTower"
	local foot = b * CFrame.new(t.Center.X, top, t.Center.Y)
	local hull = collider(tower, t.Size, foot * CFrame.new(0, t.Size.Y / 2, 0))
	tower.PrimaryPart = hull
	if not mesh(tower, "TimingTower", t.Size, hull.CFrame) then
		-- shortcut: rounded-part stand-in for the Blender tower; drop it once SpawnPaddockProps always loads
		local d = t.Size.X
		disc(tower, "Plinth", foot, 0, 2, d, C.Red)
		part(
			tower,
			"Shaft",
			Vector3.new(d - 1.4, 30, d - 1.4),
			foot * CFrame.new(0, 17, 0),
			C.White,
			Enum.Material.Metal
		)
		part(tower, "Board", Vector3.new(d - 0.4, 6, d - 0.4), foot * CFrame.new(0, 30, 0), C.Board)
		disc(tower, "Band", foot, 33, 34.5, d, C.Teal, Enum.Material.Neon)
		part(
			tower,
			"Dome",
			Vector3.new(d, d, d),
			foot * CFrame.new(0, t.Size.Y - d / 2, 0),
			C.Amber,
			nil,
			Enum.PartType.Ball
		)
	end
	tower.Parent = decor

	-- Floodlight masts: one shadow-free SpotLight each, leaning towards the middle of the area
	local masts = group("Floodlights")
	for i, at in SpawnDecor.MASTS do
		local m = Instance.new("Model")
		m.Name = "Mast_" .. i
		local size = SpawnDecor.MAST_SIZE
		local mfoot = b * CFrame.new(at.X, top, at.Y)
		m.PrimaryPart = collider(m, size, mfoot * CFrame.new(0, size.Y / 2, 0))
		disc(m, "Foot", mfoot, 0, 1, size.X, C.Red)
		disc(m, "Pole", mfoot, 1, size.Y - size.X, size.X * 0.6, C.Metal, Enum.Material.Metal)
		local headCf = mfoot * CFrame.new(0, size.Y - size.X / 2, 0)
		local head = part(m, "Lamp", Vector3.one * size.X, headCf, C.Amber, Enum.Material.Neon, Enum.PartType.Ball)
		-- the lamp stays axis-aligned (its box never leaves the 2 x 2 footprint); only the light's attachment aims
		local aim = b:PointToWorldSpace(Vector3.new(SpawnDecor.MAST_AIM.X, top, SpawnDecor.MAST_AIM.Y))
		local mount = Instance.new("Attachment")
		mount.Name = "Aim"
		mount.Parent = head
		mount.WorldCFrame = CFrame.lookAt(headCf.Position, aim)
		local light = Instance.new("SpotLight")
		light.Name = "Floodlight"
		light.Face = Enum.NormalId.Front
		light.Angle = 70
		light.Range = 60
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 236, 200)
		light.Shadows = false
		light.Parent = mount
		m.Parent = masts
	end

	-- Tyre stacks behind plots 1-4
	local tyres = group("TyreStacks")
	for i, z in SpawnDecor.TYRE_Z do
		local stack = Instance.new("Model")
		stack.Name = "TyreStack_" .. i
		local size = SpawnDecor.TYRE_SIZE
		local tfoot = b * CFrame.new(SpawnDecor.TYRE_X, top, z)
		stack.PrimaryPart = collider(stack, size, tfoot * CFrame.new(0, size.Y / 2, 0))
		if not mesh(stack, "TyreStack", size, stack.PrimaryPart.CFrame) then
			-- shortcut: three rounded cylinders stand in for the Blender tyre mesh until SpawnPaddockProps loads
			local band = ({ C.Red, C.White, C.Teal })[(i - 1) % 3 + 1]
			for k = 1, 3 do
				disc(
					stack,
					"Tyre_" .. k,
					tfoot,
					(k - 1) * size.Y / 3,
					k * size.Y / 3,
					size.X,
					k == 3 and band or C.Tyre
				)
			end
		end
		stack.Parent = tyres
	end

	return decor
end

return SpawnDecor
