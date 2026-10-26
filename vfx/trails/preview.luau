--!nonstrict
-- Draft preview, round 3 (2026-10-26): all six Market cosmetics as live Trails and ParticleEmitters.
-- Runs in the test Studio (Edit or Client datamodel) through the Studio MCP; never synced, never shipped.
-- Six local-only cars drive loops in a row: Rainbow, Solar, Void trails; Azure, Ember, Galaxy auras.
-- TEX is the rbxasset://textures/vfxpreview/<stamp>/ folder printed by `vfxtex.py preview` (this PC only).
-- Same layers as drafts/props/trail-vfx-redesign/build_scene.py. Chassis space: x right, y up, z back.
local TEX = "__TEX__"
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CarFactory = require(Shared.CarFactory)
local CarConfig = require(Shared.CarConfig)

local old = workspace:FindFirstChild("TrailDraftPreview")
if old then
	old:Destroy()
end
if _G.TrailDraftConn then
	_G.TrailDraftConn:Disconnect()
end
local root = Instance.new("Folder")
root.Name = "TrailDraftPreview"
root.Parent = workspace

local rgb = Color3.fromRGB
local WHITE, BLACK = rgb(255, 255, 255), rgb(0, 0, 0)
local VIOLET, TEAL, DEEP, LILAC = rgb(104, 52, 220), rgb(34, 230, 210), rgb(24, 6, 52), rgb(200, 150, 255)
local PALE, GOLD, ORANGE, RED = rgb(255, 245, 145), rgb(255, 188, 48), rgb(255, 120, 30), rgb(200, 40, 10)
local CYAN, ICE = rgb(80, 190, 255), rgb(180, 245, 255)
local EMBER, FLAMEY = rgb(255, 92, 38), rgb(255, 220, 75)
local GALV, PINK, NAVY = rgb(137, 80, 255), rgb(255, 91, 220), rgb(40, 30, 120)
local FIRE = { { 0, PALE }, { 0.3, GOLD }, { 0.6, ORANGE }, { 0.85, RED }, { 1, rgb(40, 10, 5) } }
local WARM_SMOKE = { { 0, rgb(230, 140, 80) }, { 1, rgb(140, 125, 120) } }
local HUES = {}
for n = 0, 6 do
	table.insert(HUES, { n / 6, Color3.fromHSV(n / 6, 0.65, 1) })
end

local function nseq(v)
	if type(v) == "number" then
		return NumberSequence.new(v)
	end
	local points = {}
	for _, p in v do
		table.insert(points, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(points)
end
local function cseq(v)
	if typeof(v) == "Color3" then
		return ColorSequence.new(v)
	end
	local points = {}
	for _, p in v do
		table.insert(points, ColorSequenceKeypoint.new(p[1], p[2]))
	end
	return ColorSequence.new(points)
end
local function mix(a, b, t)
	return a:Lerp(b, t)
end
-- Hard on/off steps along a trail's length (the shipped Void flicker).
local function dashes(phase, count, fadeFrom)
	local points = {}
	for i = 0, count - 1 do
		local x0, x1 = i / count, (i + 1) / count
		local on = (i + phase) % 2 == 0 or (i + phase) % 3 == 0
		local value = on and math.max(0, (x0 - fadeFrom) / (1 - fadeFrom)) or 1
		table.insert(points, { i == 0 and 0 or x0 + 0.002, value })
		table.insert(points, { x1 - 0.002, value })
	end
	points[#points] = { 1, 1 }
	return points
end
-- A frame at pos whose up vector is `up` (EmissionDirection Top then points along up).
local function frameUp(pos, up)
	up = up.Unit
	local right = up:Cross(Vector3.zAxis)
	if right.Magnitude < 1e-3 then
		right = Vector3.xAxis
	end
	right = right.Unit
	return CFrame.fromMatrix(pos, right, up, right:Cross(up))
end

-- ---------------------------------------------------------------- builders
local Car = {}
Car.__index = Car

function Car.new(label, x)
	local self = setmetatable({ helpers = {}, label = label }, Car)
	local model = CarFactory.build(CarConfig)
	model.Name = label
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		end
	end
	model.Parent = root
	self.model, self.chassis, self.x = model, model.PrimaryPart, x
	self.folder = Instance.new("Folder")
	self.folder.Name = "MarketEffects"
	self.folder.Parent = model
	return self
end

function Car:attachment(name, cf)
	local a = Instance.new("Attachment")
	a.Name, a.CFrame = name, cf
	a.Parent = self.chassis
	return a
end

-- An invisible anchored host part that follows the chassis; update(t) returns its chassis-space CFrame.
function Car:host(name, size, update)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Transparency = name, size, 1
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = self.model
	table.insert(self.helpers, { part = p, update = update })
	return p
end

function Car:ribbon(name, r)
	local y, z = r.y, r.z or 3
	local cx = r.x or 0
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0 = self:attachment(name .. "A", CFrame.new(cx - r.half, y, z))
	t.Attachment1 = self:attachment(name .. "B", CFrame.new(cx + r.half, y, z))
	t.FaceCamera, t.MinLength = false, 0.1
	t.Lifetime = r.life
	t.Texture = TEX .. r.tex
	t.TextureMode = r.tile and Enum.TextureMode.Wrap or Enum.TextureMode.Stretch
	if r.tile then
		t.TextureLength = r.tile
	end
	t.Color, t.Transparency, t.WidthScale = cseq(r.color), nseq(r.transparency), nseq(r.width or 1)
	t.LightEmission, t.Brightness = r.le or 0, r.br or 1
	t.Parent = self.folder
end

function Car:emitter(name, e)
	local at = e.at or Vector3.zero
	local dir = e.dir or Vector3.yAxis
	local parent
	local orbit = e.orbit
	if orbit then
		-- An orbiting host: particles locked to it revolve with it; unlocked ones leave a helix behind.
		local spin, r = math.rad(orbit.spin), orbit.r
		local tilt = orbit.tilt or CFrame.identity
		local ring = orbit.ring -- emit round a ring on a spinning host (vortex) instead of from one point
		local size = ring and Vector3.new(r * 2, 0.2, r * 2) or Vector3.new(0.2, 0.2, 0.2)
		parent = self:host(name .. "Host", size, function(t)
			local a = (orbit.phase or 0) + spin * t
			if ring then
				return CFrame.new(at) * tilt * CFrame.Angles(0, a, 0)
			end
			if orbit.axis == "z" then
				return CFrame.new(at + Vector3.new(math.cos(a) * r, math.sin(a) * r, 0))
			end
			return CFrame.new(at) * tilt * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
		end)
	elseif e.box or e.ring or e.tilt then
		local size = e.ring and Vector3.new(e.ring.X * 2, 0.2, e.ring.Y * 2) or (e.box and e.box * 2 or Vector3.new(0.2, 0.2, 0.2))
		local base = e.tilt and (CFrame.new(at) * e.tilt) or frameUp(at, dir)
		local precess = e.precess and math.rad(e.precess) or 0
		parent = self:host(name .. "Host", Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05)), function(t)
			return precess ~= 0 and (CFrame.Angles(0, precess * t, 0) * base) or base
		end)
	else
		parent = self:attachment(name .. "At", frameUp(at, dir))
	end
	local p = Instance.new("ParticleEmitter")
	p.Name = name
	p.Texture = TEX .. e.tex
	if e.grid then
		p.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		p.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	p.Rate = e.rate
	p.Lifetime = NumberRange.new(e.life[1], e.life[2])
	p.Speed = NumberRange.new(e.speed and e.speed[1] or 0, e.speed and e.speed[2] or 0)
	p.EmissionDirection = Enum.NormalId.Top
	p.SpreadAngle = Vector2.new(e.spread or 0, e.spread or 0)
	p.Drag = e.drag or 0
	p.Acceleration = e.acc or Vector3.zero
	p.Size = nseq(e.size)
	p.Transparency = nseq(e.transparency or { { 0, 0 }, { 1, 1 } })
	p.Color = cseq(e.color)
	p.LightEmission, p.Brightness = e.le or 0, e.br or 1
	p.LightInfluence = (e.le or 0) > 0.5 and 0 or 1
	p.LockedToPart = e.locked == true
	p.ZOffset = e.z or 0
	if e.orient == "parallel" then
		p.Orientation = Enum.ParticleOrientation.VelocityParallel
		p.Rotation = NumberRange.new(-90)
	elseif e.orient == "flat" then
		p.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		p.Speed = NumberRange.new(0.001)
		p.SpreadAngle = Vector2.zero
		p.Rotation = NumberRange.new(0, 360)
		p.RotSpeed = NumberRange.new(e.rotSpeed or 0)
	elseif e.spin == false then
		p.Rotation = NumberRange.new(-10, 10)
	else
		p.Rotation = NumberRange.new(0, 360)
		p.RotSpeed = NumberRange.new(-40, 40)
	end
	if parent:IsA("BasePart") then
		p.Shape = (e.ring or (orbit and orbit.ring)) and Enum.ParticleEmitterShape.Cylinder or Enum.ParticleEmitterShape.Box
		p.ShapeStyle = (e.ring or (orbit and orbit.ring)) and Enum.ParticleEmitterShapeStyle.Surface or Enum.ParticleEmitterShapeStyle.Volume
		if orbit and not orbit.ring then
			p.Shape = Enum.ParticleEmitterShape.Sphere
		end
	end
	p.Parent = parent
end

function Car:update(t, chassisCF)
	for _, h in self.helpers do
		h.part.CFrame = chassisCF * h.update(t)
	end
end

-- ---------------------------------------------------------------- the six cosmetics
local cars = {}
local function add(label, x, build)
	local car = Car.new(label, x)
	build(car)
	table.insert(cars, car)
end
local V = Vector3.new

add("Rainbow Trail", -130, function(c)
	c:ribbon("RainbowShadow", { half = 0.75, y = -0.77, life = 2.1, tex = "RainbowRibbon.png", color = rgb(1, 0, 2),
		transparency = { { 0, 0.45 }, { 1, 1 } }, width = { { 0, 1 }, { 1, 0.45 } } })
	c:ribbon("RainbowRibbon", { half = 0.6, y = -0.75, life = 2.0, tex = "RainbowRibbon.png", color = WHITE, le = 0.25, br = 2.5,
		transparency = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }, width = { { 0, 1 }, { 1, 0.35 } } })
	c:ribbon("RainbowCore", { half = 0.12, y = -0.72, life = 0.7, tex = "CoreStreak.png", color = WHITE, le = 1, br = 3,
		transparency = { { 0, 0 }, { 1, 1 } }, width = { { 0, 1 }, { 1, 0 } } })
	c:emitter("RainbowGlints", { tex = "Glint.png", rate = 45, life = { 0.8, 1.6 }, speed = { 0.5, 2 }, dir = V(0, 1, 0.3), spread = 70, drag = 1.5,
		acc = V(0, 1, 0), size = { { 0, 0 }, { 0.2, 1.1 }, { 1, 0 } }, color = HUES, le = 1, br = 3, at = V(0, -0.5, 3), box = V(0.6, 0.1, 0.3) })
	c:emitter("RainbowDust", { tex = "Dot.png", rate = 80, life = { 1, 2 }, speed = { 0.5, 1.5 }, spread = 180, size = { { 0, 0.3 }, { 1, 0 } },
		color = HUES, le = 1, br = 2, at = V(0, -0.5, 3), box = V(0.6, 0.1, 0.3) })
end)

add("Solar Trail", -78, function(c)
	c:ribbon("SolarGlow", { half = 2.4, y = -0.8, life = 1.6, tex = "SoftBand.png", color = { { 0, ORANGE }, { 1, RED } }, le = 1, br = 2.5,
		transparency = { { 0, 0.1 }, { 1, 1 } }, width = { { 0, 1 }, { 1, 0.6 } } })
	c:ribbon("SolarPlasma", { half = 0.95, y = -0.75, life = 2.0, tex = "Plasma.png", le = 0.3, br = 5,
		color = { { 0, PALE }, { 0.35, GOLD }, { 0.7, ORANGE }, { 1, RED } }, transparency = { { 0, 0 }, { 0.5, 0.15 }, { 1, 1 } },
		width = { { 0, 1 }, { 1, 0.3 } } })
	c:ribbon("SolarCore", { half = 0.25, y = -0.72, life = 0.6, tex = "CoreStreak.png", color = { { 0, WHITE }, { 1, PALE } }, le = 1, br = 5,
		transparency = { { 0, 0 }, { 1, 1 } }, width = { { 0, 1 }, { 1, 0 } } })
	c:emitter("SolarFlames", { tex = "Flame.flipbook.png", grid = 4, rate = 110, life = { 0.5, 0.9 }, speed = { 1, 3 }, spread = 25,
		acc = V(0, 4, 0), size = { { 0, 2 }, { 1, 4 } }, color = FIRE, br = 6, at = V(0, -0.3, 3.2), box = V(0.8, 0.1, 0.5), spin = false })
	for _, side in { -1, 1 } do
		c:emitter("SolarWing" .. side, { tex = "Flame.flipbook.png", grid = 4, rate = 45, life = { 0.4, 0.7 }, speed = { 5, 8 },
			dir = V(side, 0.7, 0.3), spread = 12, drag = 1.5, acc = V(0, 3, 0), size = { { 0, 1.2 }, { 1, 2.6 } }, color = FIRE, br = 6,
			at = V(side * 1.2, -0.3, 2.8), spin = false })
	end
	c:emitter("SolarFlare", { tex = "Glint.png", rate = 8, life = { 0.15, 0.25 }, size = { { 0, 5 }, { 1, 3 } }, color = PALE, le = 1, br = 8,
		locked = true, at = V(0, -0.2, 3.4) })
	c:emitter("SolarRings", { tex = "Ring.png", rate = 3, life = { 0.9, 0.9 }, size = { { 0, 2 }, { 1, 9 } }, transparency = { { 0, 0.1 }, { 1, 1 } },
		color = GOLD, le = 1, br = 3, orient = "flat", at = V(0, -1.25, 3.5) })
	c:emitter("SolarSunSparks", { tex = "Glint.png", rate = 50, life = { 0.8, 1.4 }, size = { { 0, 0.8 }, { 1, 0 } }, color = { { 0, PALE }, { 1, ORANGE } },
		le = 1, br = 4, at = V(0, 0.3, 3.5), orbit = { r = 1.2, spin = 400, axis = "z" } })
	c:emitter("SolarEmbers", { tex = "Spark.png", rate = 90, life = { 0.6, 1.2 }, speed = { 4, 10 }, dir = V(0, 1, 0.5), spread = 60, drag = 1,
		acc = V(0, -6, 0), size = { { 0, 0.6 }, { 1, 0.2 } }, color = { { 0, PALE }, { 1, ORANGE } }, le = 1, br = 4, orient = "parallel",
		at = V(0, -0.3, 3.2), box = V(0.8, 0.1, 0.5) })
	c:emitter("SolarSmoke", { tex = "VoidWisp.flipbook.png", grid = 4, rate = 14, life = { 1.2, 1.8 }, speed = { 1, 2 }, spread = 30,
		acc = V(0, 1.5, 0), size = { { 0, 1.8 }, { 1, 4 } }, transparency = { { 0, 0.55 }, { 1, 1 } }, color = WARM_SMOKE,
		at = V(0, 0.5, 4), box = V(0.9, 0.2, 0.6) })
end)

add("Void Trail", -26, function(c)
	c:ribbon("void_trailCore", { half = 0.5, y = -0.82, z = 3.1, life = 1.4, tex = "VoidWake.png",
		color = { { 0, mix(VIOLET, BLACK, 0.8) }, { 1, mix(VIOLET, BLACK, 0.95) } }, transparency = { { 0, 0.1 }, { 1, 1 } }, width = { { 0, 1 }, { 1, 0.3 } } })
	for _, side in { -1, 1 } do -- thin crackle edges kept (the vehicle_effects test checks void_trailEdgeL/R)
		c:ribbon(side < 0 and "void_trailEdgeL" or "void_trailEdgeR", { half = 0.12, x = side * 0.62, y = -0.8, z = 3.1, life = 0.9,
			tex = "VoidCrackle.png", tile = 3, color = { { 0, TEAL }, { 1, VIOLET } }, le = 1, br = 4, transparency = dashes(side < 0 and 0 or 1, 9, 0.3) })
	end
	c:emitter("void_trailSmoke", { tex = "VoidWisp.flipbook.png", grid = 4, rate = 70, life = { 1.2, 2.0 }, speed = { 0.5, 2 }, spread = 70,
		acc = V(0, 0.8, 0), size = { { 0, 1.4 }, { 1, 3.2 } }, transparency = { { 0, 0.05 }, { 1, 0.8 } },
		color = { { 0, mix(VIOLET, BLACK, 0.55) }, { 0.5, mix(VIOLET, BLACK, 0.85) }, { 1, BLACK } }, at = V(0, -0.5, 3.4), box = V(1.2, 0.2, 0.5) })
	c:emitter("VoidFlames", { tex = "Flame.flipbook.png", grid = 4, rate = 70, life = { 0.6, 1.0 }, speed = { 2, 4 }, spread = 30, acc = V(0, 5, 0),
		size = { { 0, 1.6 }, { 1, 3.2 } }, color = { { 0, LILAC }, { 0.35, VIOLET }, { 0.8, DEEP }, { 1, BLACK } }, le = 0.3, br = 4,
		at = V(0, -0.6, 3.5), box = V(1.0, 0.1, 0.5), spin = false })
	c:emitter("VoidFlamesBlack", { tex = "Flame.flipbook.png", grid = 4, rate = 30, life = { 0.7, 1.1 }, speed = { 2, 4 }, spread = 35,
		acc = V(0, 4, 0), size = { { 0, 1.6 }, { 1, 3 } }, color = BLACK, br = 0, at = V(0, -0.6, 3.5), box = V(1.0, 0.1, 0.5), spin = false, z = -0.5 })
	c:emitter("VoidVortex", { tex = "Glint.png", rate = 90, life = { 1.0, 1.8 }, size = { { 0, 0.7 }, { 1, 0 } },
		color = { { 0, TEAL }, { 0.5, rgb(150, 120, 255) }, { 1, VIOLET } }, le = 1, br = 4, at = V(0, 0.3, 3.5), orbit = { r = 1.7, spin = 300, axis = "z" } })
	c:emitter("VoidOrbs", { tex = "Dot.png", rate = 20, life = { 1.2, 2.0 }, size = { { 0, 0.9 }, { 1, 0.3 } }, color = rgb(3, 0, 8), br = 0,
		at = V(0, 0.3, 3.5), orbit = { r = 1.4, spin = -220, axis = "z", phase = math.pi } })
	c:emitter("VoidShards", { tex = "Shard.png", rate = 35, life = { 1, 1.6 }, speed = { 4, 8 }, dir = V(0, 1, 0.4), spread = 70, drag = 0.5,
		acc = V(0, 1, 0), size = { { 0, 1 }, { 1, 0 } }, color = { { 0, TEAL }, { 1, VIOLET } }, le = 0.5, br = 3, orient = "parallel",
		at = V(0, -0.5, 3.5), box = V(1.2, 0.1, 0.5) })
	c:emitter("VoidDarts", { tex = "Spark.png", rate = 60, life = { 0.3, 0.6 }, speed = { 8, 14 }, dir = V(0, 0.1, 1), spread = 20,
		size = { { 0, 0.5 }, { 1, 0.2 } }, color = TEAL, le = 1, br = 5, orient = "parallel", at = V(0, -0.7, 3.5), box = V(1.4, 0.1, 0.3) })
	c:emitter("VoidBolts", { tex = "Bolt.flipbook.png", grid = 4, rate = 18, life = { 0.25, 0.35 }, size = { { 0, 5 }, { 1, 5.5 } }, color = TEAL,
		le = 1, br = 5, at = V(0, 0, 3.5), box = V(1.6, 0.8, 0.5) })
	c:emitter("void_trailMotes", { tex = "Glint.png", rate = 60, life = { 0.6, 1.3 }, speed = { 1.5, 4 }, spread = 70, drag = 2, acc = V(0, 2, 0),
		size = { { 0, 0.5 }, { 1, 0 } }, color = { { 0, TEAL }, { 1, VIOLET } }, le = 1, br = 3, at = V(0, -0.6, 3.3), box = V(1.3, 0.1, 0.4) })
end)

add("Azure Aura", 26, function(c)
	for i, tilt in { CFrame.Angles(math.rad(70), 0, 0), CFrame.Angles(math.rad(70), math.rad(60), 0), CFrame.Angles(math.rad(70), math.rad(-60), 0) } do
		c:emitter("AzureGyro" .. i, { tex = "Ring.png", rate = 1, life = { 1.1, 1.1 }, size = 7, transparency = 0.15, color = CYAN, le = 1, br = 3,
			orient = "flat", tilt = tilt, precess = 90, locked = true, at = V(0, 0.4, 0) })
		c:emitter("AzureOrb" .. i, { tex = "Glint.png", rate = 6, life = { 0.5, 0.5 }, size = 1.4, color = ICE, le = 1, br = 6, locked = true,
			at = V(0, 0.4, 0), orbit = { r = 3.3, spin = 240, tilt = tilt * CFrame.Angles(math.rad(-90), 0, 0), phase = i * 2 } })
	end
	c:emitter("AzurePillar", { tex = "Bolt.flipbook.png", grid = 4, rate = 10, life = { 0.2, 0.3 }, size = { { 0, 3 }, { 1, 3.5 } }, color = ICE,
		le = 1, br = 6, orient = "flat", tilt = CFrame.Angles(0, 0, math.rad(90)), precess = 200, locked = true, at = V(0, 2.6, 0) })
	c:emitter("AzureRing", { tex = "Ring.png", rate = 2, life = { 1.2, 1.2 }, size = { { 0, 3 }, { 1, 10 } }, transparency = { { 0, 0.1 }, { 1, 1 } },
		color = CYAN, le = 1, br = 3, orient = "flat", locked = true, at = V(0, -1.25, 0) })
	c:emitter("AzureArcs", { tex = "Bolt.flipbook.png", grid = 4, rate = 24, life = { 0.2, 0.3 }, size = { { 0, 3.5 }, { 1, 4.5 } }, color = ICE,
		le = 1, br = 6, locked = true, at = V(0, 0.2, 0), box = V(1.8, 0.8, 3.5) })
	c:emitter("AzureCharge", { tex = "Spark.png", rate = 30, life = { 0.3, 0.6 }, speed = { 6, 10 }, spread = 15, size = { { 0, 0.6 }, { 1, 0.2 } },
		color = { { 0, WHITE }, { 1, CYAN } }, le = 1, br = 5, orient = "parallel", locked = true, at = V(0, -0.8, 0), box = V(1.8, 0.1, 3.3) })
	c:emitter("AzureFrost", { tex = "Dot.png", rate = 40, life = { 0.8, 1.4 }, speed = { 0.5, 1.5 }, spread = 180, size = { { 0, 0.22 }, { 1, 0 } },
		color = ICE, le = 1, br = 2, at = V(0, -0.5, 0), box = V(1.8, 0.4, 3.3) })
end)

add("Ember Aura", 78, function(c)
	c:emitter("EmberTornado", { tex = "Flame.flipbook.png", grid = 4, rate = 120, life = { 0.7, 1.1 }, speed = { 3, 4 }, size = { { 0, 1.6 }, { 1, 2.4 } },
		color = FIRE, br = 6, locked = true, spin = false, at = V(0, -0.8, 0), orbit = { r = 2.7, spin = 260, ring = true } })
	c:emitter("EmberFireball", { tex = "Dot.png", rate = 10, life = { 0.4, 0.4 }, size = 1.3, color = FLAMEY, le = 1, br = 6, locked = true,
		at = V(0, 1.8, 0), orbit = { r = 3.6, spin = -180 } })
	c:emitter("EmberFireballFlame", { tex = "Flame.flipbook.png", grid = 4, rate = 16, life = { 0.5, 0.7 }, speed = { 1, 2 }, size = { { 0, 1.6 }, { 1, 2.2 } },
		color = FIRE, br = 6, spin = false, at = V(0, 1.8, 0), orbit = { r = 3.6, spin = -180 } })
	c:emitter("EmberFireRing", { tex = "Flame.flipbook.png", grid = 4, rate = 60, life = { 0.4, 0.6 }, speed = { 1, 2 }, acc = V(0, 3, 0),
		size = { { 0, 1 }, { 1, 1.6 } }, color = FIRE, br = 6, ring = Vector2.new(3.6, 4.6), at = V(0, -1.0, 0), locked = true, spin = false })
	c:emitter("EmberSparks", { tex = "Spark.png", rate = 60, life = { 0.8, 1.3 }, speed = { 4, 8 }, spread = 70, drag = 0.8, acc = V(0, -4, 0),
		size = { { 0, 0.5 }, { 1, 0.15 } }, color = { { 0, PALE }, { 1, EMBER } }, le = 1, br = 4, orient = "parallel", at = V(0, 1, 0), box = V(2.4, 1, 3.2) })
	c:emitter("EmberSmoke", { tex = "VoidWisp.flipbook.png", grid = 4, rate = 10, life = { 1.2, 1.8 }, speed = { 1, 2 }, spread = 30, acc = V(0, 1.5, 0),
		size = { { 0, 1.6 }, { 1, 3.2 } }, transparency = { { 0, 0.55 }, { 1, 1 } }, color = WARM_SMOKE, at = V(0, 3, 2), box = V(1.6, 0.4, 2) })
end)

add("Galaxy Aura", 130, function(c)
	c:emitter("GalaxySigil", { tex = "RuneRing.png", rate = 0.8, life = { 2.5, 2.5 }, size = { { 0, 8.5 }, { 1, 9.5 } },
		transparency = { { 0, 0.6 }, { 0.2, 0.15 }, { 1, 1 } }, color = PINK, le = 1, br = 2.5, orient = "flat", rotSpeed = 40, locked = true, at = V(0, -1.25, 0) })
	for i, tilt in { CFrame.Angles(math.rad(60), math.rad(25), 0), CFrame.Angles(math.rad(60), math.rad(-35), 0) } do
		c:emitter("GalaxyOrbitRing" .. i, { tex = "RuneRing.png", rate = 1, life = { 1.1, 1.1 }, size = 8, transparency = 0.35, color = i == 1 and PINK or GALV,
			le = 1, br = 2.5, orient = "flat", rotSpeed = i == 1 and 30 or -30, tilt = tilt, precess = i == 1 and 25 or -25, locked = true, at = V(0, 0.8, 0) })
		for j, col in { rgb(255, 200, 120), rgb(120, 220, 255) } do
			c:emitter("GalaxyPlanet" .. i .. j, { tex = "Dot.png", rate = 8, life = { 0.4, 0.4 }, size = 0.9 + 0.4 * j, color = col, le = 1, br = 4,
				locked = true, at = V(0, 0.8, 0), orbit = { r = 3.8, spin = i == 1 and 150 or -150, phase = j * math.pi,
					tilt = tilt * CFrame.Angles(math.rad(-90), 0, 0) } })
		end
	end
	c:emitter("GalaxyVortex", { tex = "Nebula.png", rate = 30, life = { 1, 1.6 }, size = { { 0, 1.2 }, { 1, 0.3 } }, transparency = { { 0, 0.2 }, { 1, 1 } },
		color = { { 0, PINK }, { 1, GALV } }, le = 0.8, br = 3, locked = true, at = V(0, 3.2, 0), orbit = { r = 1.6, spin = 360, ring = true } })
	c:emitter("GalaxyNebula", { tex = "Nebula.png", rate = 18, life = { 1.5, 2.5 }, speed = { 0.3, 1 }, spread = 180, size = { { 0, 3 }, { 1, 5 } },
		transparency = { { 0, 0.2 }, { 1, 1 } }, color = { { 0, GALV }, { 0.5, PINK }, { 1, NAVY } }, le = 0.8, br = 2.5, box = V(1.8, 0.8, 3.3) })
	c:emitter("GalaxyNebulaDark", { tex = "Nebula.png", rate = 5, life = { 1.6, 2.6 }, speed = { 0.3, 1 }, spread = 180, size = { { 0, 3 }, { 1, 4.5 } },
		transparency = { { 0, 0.5 }, { 1, 1 } }, color = rgb(1, 0, 3), br = 0, box = V(1.8, 0.8, 3.3), z = -0.5 })
	c:emitter("GalaxyStars", { tex = "Glint.png", rate = 70, life = { 0.8, 1.5 }, size = { { 0, 0 }, { 0.3, 0.8 }, { 1, 0 } }, color = { { 0, WHITE }, { 1, PINK } },
		le = 1, br = 4, at = V(0, 0.8, 0), box = V(3, 2, 4.5) })
	c:emitter("GalaxyShooting", { tex = "Spark.png", rate = 6, life = { 0.3, 0.5 }, speed = { 15, 25 }, dir = V(1, 0.2, 0), spread = 90,
		size = { { 0, 1.2 }, { 1, 0.4 } }, color = WHITE, le = 1, br = 5, orient = "parallel", locked = true, at = V(0, 0.5, 0), box = V(1, 0.5, 2) })
end)

-- ---------------------------------------------------------------- drive
local params = RaycastParams.new()
params.FilterDescendantsInstances = { root }
params.FilterType = Enum.RaycastFilterType.Exclude
local ORIGIN = _G.TrailDraftOrigin or Vector3.zero -- set by the caller (e.g. in front of the player)
local hit = workspace:Raycast(ORIGIN + Vector3.new(0, 100, 0), Vector3.new(0, -300, 0), params)
local groundY = (hit and hit.Position.Y or 0) + 1.3 -- chassis sits 1.29 above wheel bottoms
local RADIUS, SPEED = 22, 45
local clock = 0
_G.TrailDraftConn = RunService.Heartbeat:Connect(function(dt)
	clock += dt
	local angle = clock * SPEED / RADIUS
	for _, c in cars do
		local centre = Vector3.new(ORIGIN.X + c.x, groundY, ORIGIN.Z)
		local pos = centre + Vector3.new(math.cos(angle) * RADIUS, 0, math.sin(angle) * RADIUS)
		local forward = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local cf = CFrame.lookAt(pos, pos + forward) -- car forward is -Z, as lookAt
		c.model:PivotTo(cf)
		c:update(clock, c.chassis.CFrame)
	end
end)
return ("preview: %d cars, ground %.2f"):format(#cars, groundY)
