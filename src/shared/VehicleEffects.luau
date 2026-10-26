--!nonstrict
-- Authored cosmetic profiles; attachments follow the shared chassis, never the skin.
-- Redesign (owner 2026-10-26): long, layered trails from drawn textures (rainbow_trail, void_trail so far)
-- (vfx/trails/textures.py, ids in vfx/trails/asset_ids.json). The server only adds Attachments, Trails and
-- ParticleEmitters (no parts, no mass); Client/VehicleEffectMotion moves the tagged attachments (orbits,
-- precessing rings, volume emission) locally. Chassis space: x right, y up, z back.
local CollectionService = game:GetService("CollectionService")
local MarketConfig = require(script.Parent.MarketConfig)
local Effects = {}

local TEX = {
	Bolt = "rbxassetid://133065074285094",
	CoreStreak = "rbxassetid://124197020388243",
	Dot = "rbxassetid://85679586220861",
	Flame = "rbxassetid://130692121457990",
	Glint = "rbxassetid://132086922886913",
	Nebula = "rbxassetid://132097236933374",
	Plasma = "rbxassetid://91657974746818",
	RainbowRibbon = "rbxassetid://120579905618548",
	Ring = "rbxassetid://116102440578307",
	RuneRing = "rbxassetid://103491489847112",
	Shard = "rbxassetid://139963030280923",
	SoftBand = "rbxassetid://121066246235320",
	Spark = "rbxassetid://70603759816469",
	VoidCrackle = "rbxassetid://98192347397170",
	VoidWake = "rbxassetid://127408604767217",
	VoidWisp = "rbxassetid://81105083815679",
}
local FLIPBOOKS = { Bolt = true, Flame = true, VoidWisp = true } -- 4 x 4 sheets
Effects.MOTION_TAG = "VehicleFxMotion"

local rgb, V = Color3.fromRGB, Vector3.new
local WHITE, BLACK = rgb(255, 255, 255), rgb(0, 0, 0)
local VIOLET, TEAL, DEEP, LILAC = rgb(104, 52, 220), rgb(34, 230, 210), rgb(24, 6, 52), rgb(200, 150, 255)
local HUES = {}
for n = 0, 6 do
	table.insert(HUES, { n / 6, Color3.fromHSV(n / 6, 0.65, 1) })
end
local function dark(c, t)
	return c:Lerp(BLACK, t)
end
-- Hard on/off steps along a trail's length: reads as broken, flickering neon (max 20 keypoints).
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

-- Each profile: ribbons (Trails) and emitters (ParticleEmitters). Emitter keys mirror ParticleEmitter
-- properties; `at` is the attachment, `box` / `ring` / `orbit` / `precess` are motions the client plays.
local PROFILES = {
	-- Thin (1.2 studs) but ~90 studs long: dark twin, hot core, hue glints and stardust.
	rainbow_trail = {
		ribbons = {
			{
				"Shadow",
				half = 0.75,
				y = -0.77,
				life = 2.1,
				tex = "RainbowRibbon",
				color = rgb(1, 0, 2),
				transparency = { { 0, 0.45 }, { 1, 1 } },
				width = { { 0, 1 }, { 1, 0.45 } },
			},
			{
				"Ribbon",
				half = 0.6,
				y = -0.75,
				life = 2.0,
				tex = "RainbowRibbon",
				color = WHITE,
				le = 0.25,
				br = 2.5,
				transparency = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } },
				width = { { 0, 1 }, { 1, 0.35 } },
			},
			{
				"Core",
				half = 0.12,
				y = -0.72,
				life = 0.7,
				tex = "CoreStreak",
				color = WHITE,
				le = 1,
				br = 3,
				transparency = { { 0, 0 }, { 1, 1 } },
				width = { { 0, 1 }, { 1, 0 } },
			},
		},
		emitters = {
			{
				"Glints",
				tex = "Glint",
				rate = 45,
				life = { 0.8, 1.6 },
				speed = { 0.5, 2 },
				dir = V(0, 1, 0.3),
				spread = 70,
				drag = 1.5,
				acc = V(0, 1, 0),
				size = { { 0, 0 }, { 0.2, 1.1 }, { 1, 0 } },
				color = HUES,
				le = 1,
				br = 3,
				at = V(0, -0.5, 3),
				box = V(0.6, 0.1, 0.3),
			},
			{
				"Dust",
				tex = "Dot",
				rate = 80,
				life = { 1, 2 },
				speed = { 0.5, 1.5 },
				spread = 180,
				size = { { 0, 0.3 }, { 1, 0 } },
				color = HUES,
				le = 1,
				br = 2,
				at = V(0, -0.5, 3),
				box = V(0.6, 0.1, 0.3),
			},
		},
	},
	-- Mostly particles: a churning wisp and flame stream, a vortex of motes, dark orbs, shards, darts and lightning.
	-- Core / EdgeL / EdgeR and the Emitter attachment's Motes + Smoke keep the names the vehicle_effects test checks.
	void_trail = {
		ribbons = {
			{
				"Core",
				half = 0.5,
				y = -0.82,
				z = 3.1,
				life = 1.4,
				tex = "VoidWake",
				color = { { 0, dark(VIOLET, 0.8) }, { 1, dark(VIOLET, 0.95) } },
				transparency = { { 0, 0.1 }, { 1, 1 } },
				width = { { 0, 1 }, { 1, 0.3 } },
			},
			{
				"EdgeL",
				half = 0.12,
				x = -0.62,
				y = -0.8,
				z = 3.1,
				life = 0.9,
				tex = "VoidCrackle",
				tile = 3,
				color = { { 0, TEAL }, { 1, VIOLET } },
				le = 1,
				br = 4,
				transparency = dashes(0, 9, 0.3),
			},
			{
				"EdgeR",
				half = 0.12,
				x = 0.62,
				y = -0.8,
				z = 3.1,
				life = 0.9,
				tex = "VoidCrackle",
				tile = 3,
				color = { { 0, TEAL }, { 1, VIOLET } },
				le = 1,
				br = 4,
				transparency = dashes(1, 9, 0.3),
			},
		},
		emitters = {
			{
				"Smoke",
				host = "Emitter",
				tex = "VoidWisp",
				rate = 70,
				life = { 1.2, 2.0 },
				speed = { 0.5, 2 },
				spread = 70,
				acc = V(0, 0.8, 0),
				size = { { 0, 1.4 }, { 1, 3.2 } },
				transparency = { { 0, 0.05 }, { 1, 0.8 } },
				color = { { 0, dark(VIOLET, 0.55) }, { 0.5, dark(VIOLET, 0.85) }, { 1, BLACK } },
				at = V(0, -0.6, 3.4),
				box = V(1.2, 0.15, 0.5),
			},
			{
				"Motes",
				host = "Emitter",
				tex = "Glint",
				rate = 60,
				life = { 0.6, 1.3 },
				speed = { 1.5, 4 },
				spread = 70,
				drag = 2,
				acc = V(0, 2, 0),
				size = { { 0, 0.5 }, { 1, 0 } },
				color = { { 0, TEAL }, { 1, VIOLET } },
				le = 1,
				br = 3,
			},
			{
				"Flames",
				tex = "Flame",
				rate = 70,
				life = { 0.6, 1.0 },
				speed = { 2, 4 },
				spread = 30,
				acc = V(0, 5, 0),
				size = { { 0, 1.6 }, { 1, 3.2 } },
				color = { { 0, LILAC }, { 0.35, VIOLET }, { 0.8, DEEP }, { 1, BLACK } },
				le = 0.3,
				br = 4,
				at = V(0, -0.6, 3.5),
				box = V(1.0, 0.1, 0.5),
				upright = true,
			},
			{
				"FlamesBlack",
				tex = "Flame",
				rate = 30,
				life = { 0.7, 1.1 },
				speed = { 2, 4 },
				spread = 35,
				acc = V(0, 4, 0),
				size = { { 0, 1.6 }, { 1, 3 } },
				color = BLACK,
				br = 0,
				at = V(0, -0.6, 3.5),
				box = V(1.0, 0.1, 0.5),
				upright = true,
				z = -0.5,
			},
			{
				"Vortex",
				tex = "Glint",
				rate = 90,
				life = { 1.0, 1.8 },
				size = { { 0, 0.7 }, { 1, 0 } },
				color = { { 0, TEAL }, { 0.5, rgb(150, 120, 255) }, { 1, VIOLET } },
				le = 1,
				br = 4,
				at = V(0, 0.3, 3.5),
				orbit = { r = 1.7, spin = 300, axis = "Z" },
			},
			{
				"Orbs",
				tex = "Dot",
				rate = 20,
				life = { 1.2, 2.0 },
				size = { { 0, 0.9 }, { 1, 0.3 } },
				color = rgb(3, 0, 8),
				br = 0,
				at = V(0, 0.3, 3.5),
				orbit = { r = 1.4, spin = -220, axis = "Z", phase = math.pi },
			},
			{
				"Shards",
				tex = "Shard",
				rate = 35,
				life = { 1, 1.6 },
				speed = { 4, 8 },
				dir = V(0, 1, 0.4),
				spread = 70,
				drag = 0.5,
				acc = V(0, 1, 0),
				size = { { 0, 1 }, { 1, 0 } },
				color = { { 0, TEAL }, { 1, VIOLET } },
				le = 0.5,
				br = 3,
				streak = true,
				at = V(0, -0.5, 3.5),
				box = V(1.2, 0.1, 0.5),
			},
			{
				"Darts",
				tex = "Spark",
				rate = 60,
				life = { 0.3, 0.6 },
				speed = { 8, 14 },
				dir = V(0, 0.1, 1),
				spread = 20,
				size = { { 0, 0.5 }, { 1, 0.2 } },
				color = TEAL,
				le = 1,
				br = 5,
				streak = true,
				at = V(0, -0.7, 3.5),
				box = V(1.4, 0.1, 0.3),
			},
			{
				"Bolts",
				tex = "Bolt",
				rate = 18,
				life = { 0.25, 0.35 },
				size = { { 0, 5 }, { 1, 5.5 } },
				color = TEAL,
				le = 1,
				br = 5,
				at = V(0, 0, 3.5),
				box = V(1.6, 0.8, 0.5),
			},
		},
	},
}
Effects.Profiles = PROFILES
-- Legacy look (pre-2026-10-26) for items whose redesign is still in progress: solar_trail and the auras.
local LEGACY = {
	solar_trail = { Lifetime = 0.65, Width = 0.75, Ribbons = 1, Rate = 18 },
	azure_aura = { Radius = 1.7, Height = 0.1, Tilt = 0, Rings = 1, Rate = 12 },
	ember_aura = { Radius = 1.5, Height = -0.2, Tilt = 0.18, Rings = 1, Rate = 24 },
	galaxy_aura = { Radius = 1.75, Height = 0.5, Tilt = 0.48, Rings = 2, Rate = 10 },
}
Effects.Legacy = LEGACY

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
-- A frame at pos whose up vector is `up` (EmissionDirection Top then points along it).
local function frameUp(pos, up)
	up = up.Unit
	local right = up:Cross(Vector3.zAxis)
	if right.Magnitude < 1e-3 then
		right = Vector3.xAxis
	end
	right = right.Unit
	return CFrame.fromMatrix(pos, right, up, right:Cross(up))
end
local function attachment(chassis, name, cf)
	local obj = Instance.new("Attachment")
	obj.Name, obj.CFrame = name, cf
	obj:SetAttribute("MarketEffect", true)
	obj.Parent = chassis
	return obj
end
-- Motion the client plays on this attachment (Client/VehicleEffectMotion); the server leaves it at rest.
local function motion(obj, e)
	local base = obj.CFrame
	if e.orbit then
		local o = e.orbit
		obj:SetAttribute("FxMode", o.axis == "Z" and "orbitZ" or "orbit")
		obj:SetAttribute("FxRadius", o.r)
		obj:SetAttribute("FxSpin", o.spin)
		obj:SetAttribute("FxPhase", o.phase or 0)
		obj:SetAttribute("FxTilt", o.tilt or CFrame.identity)
	elseif e.precess then
		obj:SetAttribute("FxMode", "precess")
		obj:SetAttribute("FxSpin", e.precess)
	elseif e.ring then
		obj:SetAttribute("FxMode", "ring")
		obj:SetAttribute("FxBox", Vector3.new(e.ring.X, 0, e.ring.Y))
	elseif e.box then
		obj:SetAttribute("FxMode", "box")
		obj:SetAttribute("FxBox", e.box)
	else
		return
	end
	obj:SetAttribute("FxBase", base)
	CollectionService:AddTag(obj, Effects.MOTION_TAG)
end
local function ribbon(folder, chassis, item, r)
	local name, x, y, z = item.Id .. r[1], r.x or 0, r.y, r.z or 3
	local obj = Instance.new("Trail")
	obj.Name = name
	obj.Attachment0 = attachment(chassis, name .. "A", CFrame.new(x - r.half, y, z))
	obj.Attachment1 = attachment(chassis, name .. "B", CFrame.new(x + r.half, y, z))
	obj.FaceCamera, obj.MinLength, obj.Lifetime = false, 0.1, r.life
	obj.Texture = TEX[r.tex]
	obj.TextureMode = r.tile and Enum.TextureMode.Wrap or Enum.TextureMode.Stretch
	if r.tile then
		obj.TextureLength = r.tile
	end
	obj.Color, obj.Transparency, obj.WidthScale = cseq(r.color), nseq(r.transparency), nseq(r.width or 1)
	obj.LightEmission, obj.Brightness = r.le or 0, r.br or 1
	obj.Parent = folder
end
local function emitter(chassis, item, e, hosts)
	local parent
	if e.host then -- a shared attachment, set up by the first emitter that names it
		parent = hosts[e.host]
	end
	if not parent then
		local at = e.at or Vector3.zero
		local cf = e.tilt and (CFrame.new(at) * e.tilt) or frameUp(at, e.dir or Vector3.yAxis)
		parent = attachment(chassis, item.Id .. (e.host or e[1] .. "At"), cf)
		motion(parent, e)
		if e.host then
			hosts[e.host] = parent
		end
	end
	local p = Instance.new("ParticleEmitter")
	p.Name = item.Id .. e[1]
	p.Texture = TEX[e.tex]
	if FLIPBOOKS[e.tex] then
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
	if e.streak then -- texture's long axis follows the motion (image top leads at Rotation -90)
		p.Orientation = Enum.ParticleOrientation.VelocityParallel
		p.Rotation = NumberRange.new(-90)
	elseif e.flat then -- a sprite lying across its emission direction: needs a tiny Speed to show
		p.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		p.Speed = NumberRange.new(0.001)
		p.SpreadAngle = Vector2.zero
		p.Rotation = NumberRange.new(0, 360)
		p.RotSpeed = NumberRange.new(e.rotSpeed or 0)
	elseif e.upright then
		p.Rotation = NumberRange.new(-10, 10)
	else
		p.Rotation = NumberRange.new(0, 360)
		p.RotSpeed = NumberRange.new(-40, 40)
	end
	p.Parent = parent
end
local function legacyAttachment(chassis, name, position)
	return attachment(chassis, name, CFrame.new(position))
end
local function particles(parent, item, rate, aura)
	if rate == 0 then
		return
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = item.Id .. "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(item.Accent, item.Color)
	sparks.LightEmission, sparks.Rate = 0.8, rate
	sparks.Lifetime = NumberRange.new(0.4, 1)
	sparks.Speed = aura and NumberRange.new(0.5, 1.5) or NumberRange.new(1, 3)
	sparks.EmissionDirection = aura and Enum.NormalId.Top or Enum.NormalId.Back
	sparks.SpreadAngle = Vector2.new(aura and 80 or 15, aura and 80 or 15)
	sparks.Acceleration = aura and Vector3.new(0, 1, 0) or Vector3.zero
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.13),
		NumberSequenceKeypoint.new(0.4, 0.20),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new(0.15, 1)
	sparks.Rotation, sparks.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-45, 45)
	sparks.Parent = parent
end
local function legacyTrail(folder, chassis, item, profile)
	for i = 1, profile.Ribbons do
		local centre = (i - (profile.Ribbons + 1) / 2) * 0.6
		local a = legacyAttachment(chassis, item.Id .. "Left" .. i, Vector3.new(centre - profile.Width / 2, -0.4, 2.5))
		local b = legacyAttachment(chassis, item.Id .. "Right" .. i, Vector3.new(centre + profile.Width / 2, -0.4, 2.5))
		local band = Instance.new("Trail")
		band.Name = item.Id .. "Ribbon" .. i
		band.Attachment0, band.Attachment1 = a, b
		band.Lifetime, band.MinLength = profile.Lifetime, 0.1
		band.LightEmission, band.FaceCamera = 0.85, true
		band.WidthScale, band.Transparency = NumberSequence.new(1, 0), NumberSequence.new(0.15, 1)
		if item.Id == "rainbow_trail" then
			local points = {}
			for n = 0, 6 do
				table.insert(
					points,
					ColorSequenceKeypoint.new(n / 6, Color3.fromHSV((n / 6 + (i - 1) / 3) % 1, 0.7, 1))
				)
			end
			band.Color = ColorSequence.new(points)
		else
			band.Color = ColorSequence.new(item.Accent, item.Color)
		end
		band.Parent = folder
	end
	particles(legacyAttachment(chassis, item.Id .. "Emitter", Vector3.new(0, -0.3, 2.5)), item, profile.Rate, false)
end
local function legacyRing(folder, chassis, item, radius, height, tilt, ordinal)
	local nodes = {}
	for i = 0, 15 do
		local angle = i * math.pi / 8
		local pos =
			Vector3.new(math.cos(angle) * radius, height + math.sin(angle) * tilt, math.sin(angle) * radius * 1.25)
		table.insert(nodes, legacyAttachment(chassis, item.Id .. "Orbit" .. ordinal .. "_" .. i, pos))
	end
	for i, a in nodes do
		local beam = Instance.new("Beam")
		beam.Name = item.Id .. "Arc" .. ordinal .. "_" .. i
		beam.Attachment0, beam.Attachment1 = a, nodes[i % #nodes + 1]
		beam.Width0, beam.Width1 = 0.065, 0.065
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(i % 2 == 0 and item.Color or item.Accent)
		beam.Transparency = NumberSequence.new(0.2)
		beam.LightEmission = 1
		beam.Parent = folder
		if item.Id == "azure_aura" and i % 4 == 1 then
			local top = legacyAttachment(chassis, item.Id .. "Charge" .. i, a.Position + Vector3.new(0.15, 1.4, -0.1))
			local bolt = beam:Clone()
			bolt.Name = "AzureCharge" .. i
			bolt.Attachment1 = top
			bolt.Width0, bolt.Width1 = 0.12, 0.025
			bolt.Parent = folder
		end
	end
end
function Effects.Apply(car, player)
	local chassis = car and car.PrimaryPart
	if not chassis then
		return
	end
	for _, child in chassis:GetChildren() do
		if child:IsA("Attachment") and child:GetAttribute("MarketEffect") then
			child:Destroy()
		end
	end
	local old = car:FindFirstChild("MarketEffects")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "MarketEffects"
	folder.Parent = car
	for _, kind in { "Aura", "Trail" } do
		local item = MarketConfig.Get(kind, player and player:GetAttribute("Equipped" .. kind))
		local profile = item and PROFILES[item.Id]
		local legacy = item and not profile and LEGACY[item.Id]
		if legacy then
			folder:SetAttribute(kind, item.Id)
			if kind == "Trail" then
				legacyTrail(folder, chassis, item, legacy)
			else
				for n = 1, legacy.Rings do
					legacyRing(
						folder,
						chassis,
						item,
						legacy.Radius,
						legacy.Height,
						legacy.Tilt * (n % 2 == 0 and -1 or 1),
						n
					)
				end
				particles(
					legacyAttachment(chassis, item.Id .. "Emitter", Vector3.new(0, 0.6, 0)),
					item,
					legacy.Rate,
					true
				)
			end
		elseif profile then
			folder:SetAttribute(kind, item.Id)
			for _, r in profile.ribbons or {} do
				ribbon(folder, chassis, item, r)
			end
			local hosts = {}
			for _, e in profile.emitters or {} do
				emitter(chassis, item, e, hosts)
			end
		end
	end
end
return Effects
