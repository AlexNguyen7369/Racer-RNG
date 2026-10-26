--!nonstrict
-- Authored cosmetic profiles; attachments follow the shared chassis, never the skin.
-- Redesign (owner 2026-10-26): long, layered trails and calm auras (Ember in a Dragon Ball Z style) from drawn textures
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
	KiFlame = "rbxassetid://118315939715440",
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
local FLIPBOOKS = { Bolt = true, Flame = true, VoidWisp = true, KiFlame = true } -- 4 x 4 sheets
local LOOPING = { KiFlame = 24 } -- flipbooks that loop (frames per second) from a random frame, to flicker
Effects.MOTION_TAG = "VehicleFxMotion"

local rgb, V = Color3.fromRGB, Vector3.new
local WHITE, BLACK = rgb(255, 255, 255), rgb(0, 0, 0)
local VIOLET, TEAL, DEEP, LILAC = rgb(104, 52, 220), rgb(34, 230, 210), rgb(24, 6, 52), rgb(200, 150, 255)
local PALE, GOLD, ORANGE, RED = rgb(255, 245, 145), rgb(255, 188, 48), rgb(255, 120, 30), rgb(200, 40, 10)
local CYAN, ICE = rgb(80, 190, 255), rgb(180, 245, 255)
local EMBER, FLAMEY = rgb(255, 92, 38), rgb(255, 220, 75)
local GALV, PINK, NAVY = rgb(137, 80, 255), rgb(255, 91, 220), rgb(40, 30, 120)
local WHITEGOLD, GOLDEN, AMBER, BOLT = rgb(255, 248, 200), rgb(255, 214, 64), rgb(255, 160, 20), rgb(150, 220, 255)
local FIRE = { { 0, PALE }, { 0.3, GOLD }, { 0.6, ORANGE }, { 0.85, RED }, { 1, rgb(40, 10, 5) } }
local WARM_SMOKE = { { 0, rgb(230, 140, 80) }, { 1, rgb(140, 125, 120) } }
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
	-- A comet: heat glow, plasma, white-hot core, fast-rising flames with flame wings, an exhaust flare,
	-- spat embers and warm smoke.
	solar_trail = {
		ribbons = {
			{
				"Glow",
				half = 2.4,
				y = -0.8,
				life = 1.6,
				tex = "SoftBand",
				color = { { 0, ORANGE }, { 1, RED } },
				le = 1,
				br = 2.5,
				transparency = { { 0, 0.1 }, { 1, 1 } },
				width = { { 0, 1 }, { 1, 0.6 } },
			},
			{
				"Plasma",
				half = 0.95,
				y = -0.75,
				life = 2.0,
				tex = "Plasma",
				le = 0.3,
				br = 5,
				color = { { 0, PALE }, { 0.35, GOLD }, { 0.7, ORANGE }, { 1, RED } },
				transparency = { { 0, 0 }, { 0.5, 0.15 }, { 1, 1 } },
				width = { { 0, 1 }, { 1, 0.3 } },
			},
			{
				"Core",
				half = 0.25,
				y = -0.72,
				life = 0.6,
				tex = "CoreStreak",
				color = { { 0, WHITE }, { 1, PALE } },
				le = 1,
				br = 5,
				transparency = { { 0, 0 }, { 1, 1 } },
				width = { { 0, 1 }, { 1, 0 } },
			},
		},
		emitters = {
			{
				"Flames",
				tex = "Flame",
				rate = 90,
				life = { 0.4, 0.7 },
				speed = { 3, 5 },
				spread = 20,
				acc = V(0, 6, 0),
				size = { { 0, 1.8 }, { 1, 3.4 } },
				color = FIRE,
				br = 6,
				at = V(0, -0.3, 3.2),
				box = V(0.8, 0.1, 0.5),
				upright = true,
			},
			{
				"WingL",
				tex = "Flame",
				rate = 30,
				life = { 0.4, 0.6 },
				speed = { 5, 8 },
				dir = V(-1, 0.8, 0.3),
				spread = 12,
				drag = 1.5,
				acc = V(0, 4, 0),
				size = { { 0, 1.2 }, { 1, 2.4 } },
				color = FIRE,
				br = 6,
				at = V(-1.2, -0.3, 2.8),
				upright = true,
			},
			{
				"WingR",
				tex = "Flame",
				rate = 30,
				life = { 0.4, 0.6 },
				speed = { 5, 8 },
				dir = V(1, 0.8, 0.3),
				spread = 12,
				drag = 1.5,
				acc = V(0, 4, 0),
				size = { { 0, 1.2 }, { 1, 2.4 } },
				color = FIRE,
				br = 6,
				at = V(1.2, -0.3, 2.8),
				upright = true,
			},
			{
				"Flare",
				tex = "Glint",
				rate = 8,
				life = { 0.15, 0.25 },
				size = { { 0, 4 }, { 1, 2.5 } },
				color = PALE,
				le = 1,
				br = 6,
				locked = true,
				at = V(0, -0.2, 3.4),
			},
			{
				"Embers",
				tex = "Spark",
				rate = 70,
				life = { 0.6, 1.2 },
				speed = { 4, 10 },
				dir = V(0, 1, 0.5),
				spread = 60,
				drag = 1,
				acc = V(0, -6, 0),
				size = { { 0, 0.6 }, { 1, 0.2 } },
				color = { { 0, PALE }, { 1, ORANGE } },
				le = 1,
				br = 4,
				streak = true,
				at = V(0, -0.3, 3.2),
				box = V(0.8, 0.1, 0.5),
			},
			{
				"Smoke",
				tex = "VoidWisp",
				rate = 12,
				life = { 1.2, 1.8 },
				speed = { 1, 2 },
				spread = 30,
				acc = V(0, 1.5, 0),
				size = { { 0, 1.8 }, { 1, 4 } },
				transparency = { { 0, 0.55 }, { 1, 1 } },
				color = WARM_SMOKE,
				at = V(0, 0.5, 4),
				box = V(0.9, 0.2, 0.6),
			},
		},
	},
	-- Calm charge: a soft ground glow that pulses, a few arcs crawling on the body, charge streaks and frost motes.
	azure_aura = {
		emitters = {
			{
				"Glow",
				tex = "Dot",
				rate = 3,
				life = { 0.8, 0.8 },
				size = 8,
				transparency = { { 0, 0.8 }, { 0.5, 0.65 }, { 1, 1 } },
				color = CYAN,
				le = 1,
				br = 1.5,
				flat = true,
				locked = true,
				at = V(0, -1.24, 0),
			},
			{
				"Pulse",
				tex = "Ring",
				rate = 1,
				life = { 1.2, 1.2 },
				size = { { 0, 3 }, { 1, 8 } },
				transparency = { { 0, 0.35 }, { 1, 1 } },
				color = CYAN,
				le = 1,
				br = 2,
				flat = true,
				locked = true,
				at = V(0, -1.25, 0),
			},
			{
				"Arcs",
				tex = "Bolt",
				rate = 8,
				life = { 0.2, 0.3 },
				size = { { 0, 2.5 }, { 1, 3.5 } },
				color = ICE,
				le = 1,
				br = 5,
				locked = true,
				at = V(0, 0.2, 0),
				box = V(1.6, 0.6, 3.2),
			},
			{
				"Charge",
				tex = "Spark",
				rate = 15,
				life = { 0.3, 0.5 },
				speed = { 6, 9 },
				spread = 10,
				size = { { 0, 0.5 }, { 1, 0.2 } },
				color = { { 0, WHITE }, { 1, CYAN } },
				le = 1,
				br = 4,
				streak = true,
				locked = true,
				at = V(0, -0.8, 0),
				ring = Vector2.new(1.7, 3.4),
			},
			{
				"Frost",
				tex = "Dot",
				rate = 20,
				life = { 0.8, 1.4 },
				speed = { 0.5, 1.5 },
				spread = 180,
				size = { { 0, 0.2 }, { 1, 0 } },
				color = ICE,
				le = 1,
				br = 2,
				at = V(0, -0.5, 0),
				box = V(1.8, 0.4, 3.3),
			},
		},
	},
	-- A Dragon Ball Z style ki aura: short-lived flame tongues hug the body and shoot upward, a white-hot inner
	-- sheath inside an orange one, fast streaks rising, a ground glow that pulses, a few embers.
	ember_aura = {
		emitters = {
			{
				"SheathOuter",
				tex = "Flame",
				rate = 90,
				life = { 0.3, 0.5 },
				speed = { 5, 8 },
				spread = 10,
				acc = V(0, 8, 0),
				size = { { 0, 1.4 }, { 0.6, 2.3 }, { 1, 1.2 } },
				color = { { 0, FLAMEY }, { 0.35, ORANGE }, { 0.75, RED }, { 1, rgb(60, 10, 5) } },
				le = 0.4,
				br = 5,
				locked = true,
				upright = true,
				at = V(0, -0.9, 0),
				ring = Vector2.new(1.9, 3.6),
			},
			{
				"SheathInner",
				tex = "Flame",
				rate = 70,
				life = { 0.25, 0.4 },
				speed = { 4, 7 },
				spread = 8,
				acc = V(0, 6, 0),
				size = { { 0, 1 }, { 1, 1.6 } },
				color = { { 0, WHITE }, { 0.5, PALE }, { 1, FLAMEY } },
				le = 1,
				br = 3,
				locked = true,
				upright = true,
				at = V(0, -0.7, 0),
				ring = Vector2.new(1.5, 3.1),
				z = 0.5,
			},
			{
				"Streaks",
				tex = "Spark",
				rate = 40,
				life = { 0.25, 0.4 },
				speed = { 14, 20 },
				spread = 5,
				size = { { 0, 0.5 }, { 1, 0.2 } },
				color = { { 0, PALE }, { 1, ORANGE } },
				le = 1,
				br = 5,
				streak = true,
				locked = true,
				at = V(0, -0.5, 0),
				ring = Vector2.new(1.7, 3.4),
			},
			{
				"Glow",
				tex = "Dot",
				rate = 4,
				life = { 0.5, 0.7 },
				size = 8,
				transparency = { { 0, 0.75 }, { 0.5, 0.6 }, { 1, 1 } },
				color = ORANGE,
				le = 1,
				br = 1.5,
				flat = true,
				locked = true,
				at = V(0, -1.24, 0),
			},
			{
				"Pulse",
				tex = "Ring",
				rate = 1.2,
				life = { 0.6, 0.6 },
				size = { { 0, 3 }, { 1, 8 } },
				transparency = { { 0, 0.3 }, { 1, 1 } },
				color = ORANGE,
				le = 1,
				br = 2,
				flat = true,
				locked = true,
				at = V(0, -1.25, 0),
			},
			{
				"Embers",
				tex = "Dot",
				rate = 20,
				life = { 0.8, 1.4 },
				speed = { 2, 4 },
				spread = 30,
				acc = V(0, 2, 0),
				size = { { 0, 0.25 }, { 1, 0 } },
				color = { { 0, FLAMEY }, { 1, EMBER } },
				le = 1,
				br = 3,
				at = V(0, 0, 0),
				box = V(1.6, 0.4, 3.2),
			},
		},
	},
	-- Quiet cosmos: a slow rune sigil on the ground, nebula wisps drifting off the car with a dark twin,
	-- twinkling stars and the odd shooting star.
	galaxy_aura = {
		emitters = {
			{
				"Sigil",
				tex = "RuneRing",
				rate = 0.6,
				life = { 2.5, 2.5 },
				size = { { 0, 8 }, { 1, 8.6 } },
				transparency = { { 0, 0.7 }, { 0.25, 0.3 }, { 1, 1 } },
				color = PINK,
				le = 1,
				br = 2,
				flat = true,
				rotSpeed = 20,
				locked = true,
				at = V(0, -1.25, 0),
			},
			{
				"Nebula",
				tex = "Nebula",
				rate = 8,
				life = { 1.5, 2.5 },
				speed = { 0.3, 1 },
				spread = 180,
				size = { { 0, 2.5 }, { 1, 4 } },
				transparency = { { 0, 0.35 }, { 1, 1 } },
				color = { { 0, GALV }, { 0.5, PINK }, { 1, NAVY } },
				le = 0.8,
				br = 2,
				at = V(0, 0, 0),
				box = V(1.8, 0.8, 3.3),
			},
			{
				"NebulaDark",
				tex = "Nebula",
				rate = 3,
				life = { 1.6, 2.6 },
				speed = { 0.3, 1 },
				spread = 180,
				size = { { 0, 2.5 }, { 1, 3.8 } },
				transparency = { { 0, 0.55 }, { 1, 1 } },
				color = rgb(1, 0, 3),
				br = 0,
				at = V(0, 0, 0),
				box = V(1.8, 0.8, 3.3),
				z = -0.5,
			},
			{
				"Stars",
				tex = "Glint",
				rate = 30,
				life = { 0.8, 1.5 },
				size = { { 0, 0 }, { 0.3, 0.7 }, { 1, 0 } },
				color = { { 0, WHITE }, { 1, PINK } },
				le = 1,
				br = 4,
				at = V(0, 0.6, 0),
				box = V(2.4, 1.4, 3.8),
			},
			{
				"Shooting",
				tex = "Spark",
				rate = 2,
				life = { 0.3, 0.5 },
				speed = { 15, 25 },
				dir = V(1, 0.2, 0),
				spread = 90,
				size = { { 0, 1.1 }, { 1, 0.4 } },
				color = WHITE,
				le = 1,
				br = 5,
				streak = true,
				locked = true,
				at = V(0, 0.5, 0),
				box = V(1, 0.5, 2),
			},
		},
	},
	-- Draft (owner 2026-10-26, design doc "Draft aura"): a golden Super Saiyan style ki aura after Dragon Ball Z.
	-- Not sold: shown only in the VFX showcase area through ApplyProfile. Spiky looping ki flames hug the body
	-- and shoot up (a crown over the roof), blue-white lightning crackles, a shockwave rolls out along the
	-- ground, dust is blown out and small rocks float up.
	ascended_aura = {
		emitters = {
			{
				"SheathOuter",
				tex = "KiFlame",
				rate = 70,
				life = { 0.3, 0.5 },
				speed = { 6, 9 },
				spread = 6,
				acc = V(0, 10, 0),
				size = { { 0, 2.2 }, { 0.5, 3.2 }, { 1, 2 } },
				color = { { 0, WHITEGOLD }, { 0.4, GOLDEN }, { 1, AMBER } },
				le = 0.5,
				br = 6,
				locked = true,
				upright = true,
				at = V(0, -1.0, 0),
				ring = Vector2.new(1.9, 3.7),
			},
			{
				"SheathInner",
				tex = "KiFlame",
				rate = 50,
				life = { 0.25, 0.4 },
				speed = { 4, 7 },
				spread = 6,
				acc = V(0, 8, 0),
				size = { { 0, 1.4 }, { 1, 2.2 } },
				color = { { 0, WHITE }, { 1, WHITEGOLD } },
				le = 1,
				br = 4,
				locked = true,
				upright = true,
				at = V(0, -0.8, 0),
				ring = Vector2.new(1.4, 3.0),
				z = 0.5,
			},
			{
				"Crown",
				tex = "KiFlame",
				rate = 20,
				life = { 0.3, 0.5 },
				speed = { 8, 12 },
				spread = 5,
				acc = V(0, 8, 0),
				size = { { 0, 2.5 }, { 1, 3.5 } },
				color = { { 0, WHITEGOLD }, { 1, GOLDEN } },
				le = 0.7,
				br = 5,
				locked = true,
				upright = true,
				at = V(0, 1.2, 0),
				box = V(1.2, 0.1, 2.4),
			},
			{
				"Streaks",
				tex = "Spark",
				rate = 50,
				life = { 0.2, 0.35 },
				speed = { 18, 26 },
				spread = 4,
				size = { { 0, 0.6 }, { 1, 0.25 } },
				color = { { 0, WHITE }, { 1, GOLDEN } },
				le = 1,
				br = 5,
				streak = true,
				locked = true,
				at = V(0, -0.8, 0),
				ring = Vector2.new(1.8, 3.5),
			},
			{
				"Lightning",
				tex = "Bolt",
				rate = 12,
				life = { 0.12, 0.2 },
				size = { { 0, 3.5 }, { 1, 5 } },
				color = BOLT,
				le = 1,
				br = 7,
				locked = true,
				at = V(0, 0.6, 0),
				box = V(2, 1.2, 3.6),
			},
			{
				"Glow",
				tex = "Dot",
				rate = 4,
				life = { 0.6, 0.8 },
				size = 10,
				transparency = { { 0, 0.7 }, { 0.5, 0.55 }, { 1, 1 } },
				color = GOLDEN,
				le = 1,
				br = 1.5,
				flat = true,
				locked = true,
				at = V(0, -1.24, 0),
			},
			{
				"Shockwave",
				tex = "Ring",
				rate = 0.8,
				life = { 0.7, 0.7 },
				size = { { 0, 4 }, { 1, 14 } },
				transparency = { { 0, 0.2 }, { 1, 1 } },
				color = GOLDEN,
				le = 1,
				br = 3,
				flat = true,
				locked = true,
				at = V(0, -1.25, 0),
			},
			{
				"Debris",
				tex = "Shard",
				rate = 8,
				life = { 1.2, 2 },
				speed = { 1.5, 3 },
				spread = 20,
				size = { { 0, 0.5 }, { 1, 0.3 } },
				transparency = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } },
				color = rgb(90, 85, 80),
				locked = true,
				at = V(0, -1.1, 0),
				ring = Vector2.new(3.5, 5),
			},
			{
				"Dust",
				tex = "VoidWisp",
				rate = 8,
				life = { 0.8, 1.2 },
				speed = { 2, 4 },
				spread = 60,
				size = { { 0, 1.5 }, { 1, 3.5 } },
				transparency = { { 0, 0.5 }, { 1, 1 } },
				color = rgb(170, 160, 150),
				at = V(0, -1.1, 0),
				ring = Vector2.new(3, 4.5),
			},
			{
				"Sparkles",
				tex = "Glint",
				rate = 25,
				life = { 0.5, 1 },
				size = { { 0, 0 }, { 0.3, 0.7 }, { 1, 0 } },
				color = WHITEGOLD,
				le = 1,
				br = 4,
				locked = true,
				at = V(0, 0.8, 0),
				box = V(2.2, 1.6, 3.8),
			},
		},
	},
}
Effects.Profiles = PROFILES

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
		p.FlipbookMode = LOOPING[e.tex] and Enum.ParticleFlipbookMode.Loop or Enum.ParticleFlipbookMode.OneShot
		if LOOPING[e.tex] then
			p.FlipbookFramerate = NumberRange.new(LOOPING[e.tex])
			p.FlipbookStartRandom = true
		end
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
-- Removes every effect from the car and returns a fresh MarketEffects folder (nil without a chassis).
local function reset(car)
	local chassis = car and car.PrimaryPart
	if not chassis then
		return nil
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
	return folder
end
local function build(folder, chassis, kind, id)
	local profile = PROFILES[id]
	if not profile then
		return
	end
	local item = { Id = id } -- instance names are <id><layer>
	folder:SetAttribute(kind, id)
	for _, r in profile.ribbons or {} do
		ribbon(folder, chassis, item, r)
	end
	local hosts = {}
	for _, e in profile.emitters or {} do
		emitter(chassis, item, e, hosts)
	end
end
function Effects.Apply(car, player)
	local folder = reset(car)
	if not folder then
		return
	end
	for _, kind in { "Aura", "Trail" } do
		local item = MarketConfig.Get(kind, player and player:GetAttribute("Equipped" .. kind))
		if item then
			build(folder, car.PrimaryPart, kind, item.Id)
		end
	end
end
-- One profile by id, Market item or not (the VFX showcase shows drafts such as ascended_aura this way).
function Effects.ApplyProfile(car, kind, id)
	local folder = reset(car)
	if folder then
		build(folder, car.PrimaryPart, kind, id)
	end
end
return Effects
