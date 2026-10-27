--!nonstrict
-- Drive-by themes, one per track Biome (docs/BIOME_DRESSING_SPEC.md). Data only; BiomeDressing builds it.
-- Every number here is a placeholder that can be tuned.
--
-- A prop: { Name, Size, Parts, Tag?, Glow? }
--   Size   bounding box (studs) the uploaded mesh is scaled to (Shared/BiomeMeshAssets "<Biome>_<Name>")
--   Parts  fallback blocks used while the prop has no mesh: { Size, Pos, Color, Material, Shape? },
--          Pos is the part centre relative to the prop's base centre (Y up, -Z along the road)
--   Tag    "BiomeSpin" or "BiomeBob", animated on the client by Client/BiomeAmbience
--   Glow   Color3 of a local PointLight (landmarks and gate only)
-- Layers: Rhythm { Every, Offset, Props }, Landmarks { Offset, Every, Props }, Horizon { Offset, Props },
-- Gate { Color, Material, Glow?, Index? (waypoint, default BiomeDressing GATE_INDEX) }, Ground { Color, Material }. Offset is studs from the road edge.
-- Scatter { Every, Near, Far, Props, Patches } (owner 2026-10-26): Props are prop tables or the Name of a rhythm or
--   landmark prop (same table, so the same mesh); Patches are flat slabs { Name, Size (X, Z), Color, Material }.
-- Particles: one ParticleEmitter setting per biome, put on every landmark (Rate is capped by BiomeDressing).

local M = Enum.Material
local rgb = Color3.fromRGB
local v = Vector3.new

local function part(size, pos, color, material, shape)
	return { Size = size, Pos = pos, Color = color, Material = material, Shape = shape }
end

-- Common shapes, so each theme only picks colours and proportions.
local function block(name, size, color, material, extra)
	local parts = { part(size, v(0, size.Y / 2, 0), color, material) }
	for _, p in extra or {} do
		table.insert(parts, p)
	end
	return { Name = name, Size = size, Parts = parts }
end

local function tree(name, height, trunk, leaves, leafMaterial)
	return {
		Name = name,
		Size = v(height * 0.6, height, height * 0.6),
		Parts = {
			part(v(height * 0.12, height * 0.4, height * 0.12), v(0, height * 0.2, 0), trunk, M.Wood),
			part(v(height * 0.6, height * 0.7, height * 0.6), v(0, height * 0.62, 0), leaves, leafMaterial or M.Grass),
		},
	}
end

local function pole(name, height, color, lamp)
	return {
		Name = name,
		Size = v(3, height, 3),
		Parts = {
			part(v(1, height, 1), v(0, height / 2, 0), color, M.Metal),
			part(v(3, 1, 3), v(0, height, 0), lamp, M.Neon),
		},
	}
end

-- Detailed City tower (owner 2026-10-27): podium + lobby, setback tiers with glass window bands, corner and centre
-- fins, a neon crown ring per tier and rooftop gear. o = { Body, Trim, Glass, Neon, Tiers?, Floor?, MaxBands?, Roof? }
local function skyscraper(name, w, h, d, o)
	local parts = {}
	local function add(size, pos, color, material, shape)
		table.insert(parts, part(size, pos, color, material, shape))
	end
	local podium = math.max(4, h * 0.08)
	add(v(w + 4, podium, d + 4), v(0, podium / 2, 0), o.Trim, M.Concrete)
	add(v(w * 0.6, podium * 0.7, 0.4), v(0, podium * 0.35, -(d + 4) / 2 - 0.2), o.Glass, M.Glass) -- lobby
	local tiers = o.Tiers or 2
	local y, tw, td = podium, w, d
	for t = 1, tiers do
		local th = (h - podium) * (tiers == 1 and 1 or t == 1 and 0.62 or 0.38)
		add(v(tw, th, td), v(0, y + th / 2, 0), o.Body, M.Concrete)
		local bands = math.max(1, math.min(o.MaxBands or 10, math.floor(th / (o.Floor or 6))))
		local step = th / bands
		for b = 1, bands do
			add(v(tw + 0.3, step * 0.55, td + 0.3), v(0, y + step * (b - 0.5), 0), o.Glass, M.Glass)
		end
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				add(v(1.2, th, 1.2), v(sx * tw / 2, y + th / 2, sz * td / 2), o.Trim, M.Concrete)
			end
		end
		add(v(0.8, th, td + 0.6), v(0, y + th / 2, 0), o.Trim, M.Concrete) -- centre fins, front and back
		add(v(tw + 0.6, th, 0.8), v(0, y + th / 2, 0), o.Trim, M.Concrete) -- centre fins, sides
		y += th
		add(v(tw + 0.6, 1, td + 0.6), v(0, y, 0), o.Neon, M.Neon) -- crown ring
		if t < tiers then
			tw, td = tw * 0.7, td * 0.7
		end
	end
	add(v(tw * 0.25, 2.5, td * 0.25), v(-tw * 0.2, y + 1.75, td * 0.15), o.Trim, M.Metal) -- AC units
	add(v(tw * 0.2, 2, td * 0.3), v(tw * 0.15, y + 1.5, td * 0.2), o.Trim, M.Metal)
	local top = y + 0.5
	if o.Roof == "tank" then
		add(v(tw * 0.22, tw * 0.25, tw * 0.22), v(tw * 0.2, top + tw * 0.125 + 2, -td * 0.2), o.Body, M.WoodPlanks)
		add(v(tw * 0.24, 2, tw * 0.24), v(tw * 0.2, top + 1, -td * 0.2), o.Trim, M.Metal)
		top += tw * 0.25 + 2
	elseif o.Roof == "spire" then
		for i, k in { 0.35, 0.2, 0.08 } do
			add(v(tw * k, 4, td * k), v(0, top + 4 * i - 2, 0), o.Trim, M.Metal)
		end
		top += 12
	end
	local mast = h * 0.12
	add(v(0.6, mast, 0.6), v(tw * 0.3, y + mast / 2, td * 0.3), rgb(160, 160, 170), M.Metal) -- antenna
	add(v(1.4, 1.4, 1.4), v(tw * 0.3, y + mast, td * 0.3), o.Neon, M.Neon, Enum.PartType.Ball)
	return { Name = name, Size = v(w + 4, math.max(top, y + mast + 0.7), d + 4), Parts = parts, Glow = o.Neon }
end

local function peak(name, size, rock, cap, capMaterial)
	return {
		Name = name,
		Size = size,
		Parts = {
			part(v(size.X, size.Y * 0.7, size.Z), v(0, size.Y * 0.35, 0), rock, M.Rock),
			part(v(size.X * 0.55, size.Y * 0.3, size.Z * 0.55), v(0, size.Y * 0.85, 0), cap, capMaterial or M.Snow),
		},
	}
end

local function gate(color, material, glow, index)
	return { Color = color, Material = material, Glow = glow, Index = index }
end

local function ball(name, d, color, material, tag)
	return {
		Name = name,
		Size = v(d, d, d),
		Tag = tag,
		Parts = { part(v(d, d, d), v(0, d / 2, 0), color, material, Enum.PartType.Ball) },
	}
end

local function patch(name, x, z, color, material)
	return { Name = name, Size = v(x, 0.2, z), Color = color, Material = material }
end

-- Built-in particle textures only (spec Layers 8)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

return {
	Speedway = {
		Ground = { Color = rgb(74, 112, 72), Material = M.Grass },
		Rhythm = {
			Every = 4,
			Offset = 10,
			Props = {
				block("TyreStack", v(4, 4, 4), rgb(25, 25, 28), M.Rubber, {
					part(v(4.2, 1, 4.2), v(0, 2, 0), rgb(235, 235, 235), M.SmoothPlastic),
				}),
				pole("Flag", 12, rgb(220, 220, 225), rgb(230, 40, 40)),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 20,
			Props = {
				block("Grandstand", v(60, 18, 16), rgb(200, 205, 215), M.Concrete, {
					part(v(60, 2, 18), v(0, 19, 0), rgb(210, 40, 45), M.SmoothPlastic),
					part(v(56, 6, 8), v(0, 8, -6), rgb(40, 90, 200), M.SmoothPlastic),
				}),
				block("PitGarage", v(36, 12, 18), rgb(235, 235, 240), M.SmoothPlastic, {
					part(v(36.2, 3, 18.2), v(0, 10, 0), rgb(210, 40, 45), M.SmoothPlastic),
				}),
				block("TimingTower", v(10, 34, 10), rgb(30, 32, 40), M.Metal, {
					part(v(10.4, 8, 10.4), v(0, 28, 0), rgb(255, 210, 40), M.Neon),
				}),
			},
		},
		Horizon = {
			Offset = 300,
			Props = { pole("StadiumLight", 70, rgb(140, 145, 155), rgb(255, 250, 220)) },
		},
		Gate = gate(rgb(210, 40, 45), M.SmoothPlastic, rgb(255, 240, 200), 18), -- past the spawn-area floor
		Scatter = {
			Every = 2,
			Near = 30,
			Far = 170,
			Props = {
				"TyreStack",
				block("Bush", v(8, 5, 8), rgb(62, 122, 56), M.Grass),
				block("Banner", v(14, 8, 1), rgb(30, 32, 40), M.Metal, {
					part(v(14.2, 4, 1.2), v(0, 6, 0), rgb(230, 40, 40), M.SmoothPlastic),
				}),
				tree("Poplar", 26, rgb(90, 64, 44), rgb(52, 112, 52)),
				"Flag",
			},
			Patches = {
				patch("MownStripe", 44, 12, rgb(96, 142, 86), M.Grass),
				patch("Dirt", 24, 14, rgb(122, 94, 64), M.Ground),
				patch("Flowers", 16, 12, rgb(236, 204, 72), M.Grass),
			},
		},
		Particles = { -- confetti over the stands
			Texture = SPARKLE,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, rgb(255, 70, 70)),
				ColorSequenceKeypoint.new(0.5, rgb(255, 220, 60)),
				ColorSequenceKeypoint.new(1, rgb(70, 140, 255)),
			}),
			Size = 0.6,
			Lifetime = 3,
			Rate = 6,
			Speed = 8,
			Spread = 50,
			Acceleration = v(0, -4, 0),
			LightEmission = 0.3,
		},
	},

	Forest = {
		Ground = { Color = rgb(64, 110, 58), Material = M.Grass },
		Rhythm = {
			Every = 3,
			Offset = 10,
			Props = {
				tree("Pine", 22, rgb(92, 64, 44), rgb(34, 92, 50)),
				block("Rock", v(6, 4, 5), rgb(120, 120, 115), M.Slate),
				tree("Birch", 18, rgb(220, 220, 210), rgb(110, 160, 70)),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 22,
			Props = {
				block("LogCabin", v(24, 12, 18), rgb(122, 80, 48), M.WoodPlanks, {
					part(v(26, 4, 20), v(0, 14, 0), rgb(80, 50, 35), M.Wood),
				}),
				block("Lookout", v(10, 36, 10), rgb(110, 75, 45), M.Wood, {
					part(v(14, 4, 14), v(0, 36, 0), rgb(80, 50, 35), M.WoodPlanks),
				}),
				tree("GiantPine", 48, rgb(92, 64, 44), rgb(28, 80, 44)),
			},
		},
		Horizon = {
			Offset = 280,
			Props = { peak("TreeHill", v(160, 70, 120), rgb(50, 96, 52), rgb(34, 80, 46), M.Grass) },
		},
		Gate = gate(rgb(110, 75, 45), M.Wood, nil, 9), -- past the race-start pavilion
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 160,
			Props = {
				"Pine",
				"Birch",
				block("Bush", v(7, 5, 7), rgb(48, 104, 50), M.Grass),
				"Pine",
				block("Log", v(10, 2.5, 2.5), rgb(104, 72, 46), M.Wood),
				{
					Name = "Mushroom",
					Size = v(4, 5, 4),
					Parts = {
						part(v(1.4, 3, 1.4), v(0, 1.5, 0), rgb(240, 232, 214), M.SmoothPlastic),
						part(v(4, 2, 4), v(0, 3.8, 0), rgb(210, 50, 45), M.SmoothPlastic),
					},
				},
				"Rock",
			},
			Patches = {
				patch("Moss", 26, 18, rgb(44, 92, 46), M.Grass),
				patch("Bluebells", 16, 12, rgb(120, 110, 220), M.Grass),
				patch("Dirt", 20, 14, rgb(104, 78, 52), M.Ground),
			},
		},
		Particles = { -- fireflies
			Texture = SPARKLE,
			Color = rgb(210, 255, 120),
			Size = 0.5,
			Lifetime = 5,
			Rate = 6,
			Speed = 1.2,
			Acceleration = v(0, 0.3, 0),
			LightEmission = 1,
		},
	},

	Docks = {
		Ground = { Color = rgb(96, 98, 104), Material = M.Concrete },
		Rhythm = {
			Every = 2, -- one short straight: denser rhythm
			Offset = 10,
			Props = {
				pole("Lamp", 16, rgb(60, 62, 70), rgb(255, 200, 90)),
				block("Cone", v(2, 3, 2), rgb(255, 120, 20), M.SmoothPlastic),
				block("Container", v(8, 8, 20), rgb(40, 110, 170), M.CorrodedMetal),
			},
		},
		Landmarks = {
			Offset = 45,
			Every = 18,
			Props = {
				block("Crane", v(8, 50, 8), rgb(240, 180, 30), M.Metal, {
					part(v(8, 4, 50), v(0, 50, -18), rgb(240, 180, 30), M.Metal),
				}),
				block("Warehouse", v(50, 20, 30), rgb(140, 140, 150), M.CorrodedMetal, {
					part(v(50.2, 2, 30.2), v(0, 14, 0), rgb(200, 60, 40), M.SmoothPlastic),
				}),
				block("ContainerStack", v(20, 16, 20), rgb(190, 60, 50), M.CorrodedMetal, {
					part(v(20, 8, 20), v(0, 12, 0), rgb(50, 140, 90), M.CorrodedMetal),
				}),
			},
		},
		Horizon = {
			Offset = 300,
			Props = {
				block("Smokestack", v(14, 90, 14), rgb(120, 70, 60), M.Brick, {
					part(v(14.4, 6, 14.4), v(0, 80, 0), rgb(230, 230, 230), M.SmoothPlastic),
				}),
			},
		},
		Gate = gate(rgb(240, 180, 30), M.Metal),
		Scatter = {
			Every = 1, -- one short straight: dense
			Near = 25,
			Far = 150,
			Props = {
				"Container",
				block("Crate", v(4, 4, 4), rgb(150, 110, 62), M.WoodPlanks),
				block("Pallet", v(6, 1, 6), rgb(170, 130, 80), M.WoodPlanks, {
					part(v(4, 3, 4), v(0, 2.5, 0), rgb(70, 90, 120), M.Fabric),
				}),
				block("Bollard", v(2, 3, 2), rgb(240, 180, 30), M.Metal),
				"ContainerStack",
			},
			Patches = {
				patch("Oil", 14, 10, rgb(28, 28, 34), M.SmoothPlastic),
				patch("LoadingBay", 30, 4, rgb(232, 192, 44), M.Concrete),
				patch("Puddle", 18, 12, rgb(70, 92, 112), M.Glass),
			},
		},
		Particles = { -- steam
			Texture = SMOKE,
			Color = rgb(220, 224, 230),
			Size = 4,
			Lifetime = 5,
			Rate = 3,
			Speed = 4,
			Spread = 15,
			Transparency = 0.6,
		},
	},

	Suburb = {
		Ground = { Color = rgb(88, 140, 70), Material = M.Grass },
		Rhythm = {
			Every = 4,
			Offset = 10,
			Props = {
				block("Hedge", v(10, 4, 4), rgb(50, 110, 50), M.Grass),
				pole("StreetLamp", 14, rgb(50, 50, 55), rgb(255, 230, 160)),
				tree("Oak", 18, rgb(100, 70, 45), rgb(70, 140, 60)),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 14,
			Props = {
				block("House", v(22, 12, 18), rgb(235, 220, 190), M.SmoothPlastic, {
					part(v(24, 6, 20), v(0, 15, 0), rgb(160, 60, 50), M.Slate),
				}),
				block("HouseBlue", v(22, 12, 18), rgb(150, 190, 220), M.SmoothPlastic, {
					part(v(24, 6, 20), v(0, 15, 0), rgb(70, 70, 80), M.Slate),
				}),
				block("GasStation", v(30, 10, 20), rgb(240, 240, 240), M.SmoothPlastic, {
					part(v(30.4, 2, 20.4), v(0, 9, 0), rgb(220, 40, 40), M.Neon),
				}),
			},
		},
		Horizon = {
			Offset = 260,
			Props = { block("Rooftops", v(120, 24, 40), rgb(170, 90, 70), M.Slate) },
		},
		Gate = gate(rgb(240, 240, 240), M.SmoothPlastic),
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 160,
			Props = {
				"Oak",
				tree("Cherry", 16, rgb(96, 64, 46), rgb(246, 170, 200)),
				block("Mailbox", v(2, 4, 2), rgb(60, 60, 70), M.Metal, {
					part(v(2, 1.6, 3), v(0, 4, 0), rgb(40, 90, 200), M.SmoothPlastic),
				}),
				block("PicketFence", v(12, 3, 1), rgb(245, 245, 240), M.WoodPlanks),
				"Hedge",
				block("Playhouse", v(8, 6, 8), rgb(250, 210, 90), M.SmoothPlastic, {
					part(v(9, 3, 9), v(0, 7.5, 0), rgb(220, 70, 60), M.SmoothPlastic),
				}),
			},
			Patches = {
				patch("FlowerBed", 14, 6, rgb(240, 120, 170), M.Grass),
				patch("Path", 30, 5, rgb(200, 196, 186), M.Concrete),
				patch("Lawn", 32, 22, rgb(110, 166, 84), M.Grass),
			},
		},
		Particles = { -- drifting petals
			Texture = SPARKLE,
			Color = rgb(255, 180, 210),
			Size = 0.5,
			Lifetime = 5,
			Rate = 5,
			Speed = 2,
			Acceleration = v(1.5, -0.6, 0),
		},
	},

	PirateCoast = {
		Ground = { Color = rgb(230, 205, 150), Material = M.Sand },
		Rhythm = {
			Every = 4,
			Offset = 10,
			Props = {
				tree("Palm", 22, rgb(140, 100, 60), rgb(60, 150, 70), M.Grass),
				block("Barrel", v(4, 5, 4), rgb(130, 85, 45), M.Wood),
			},
		},
		Landmarks = {
			Offset = 45,
			Every = 18,
			Props = {
				{
					Name = "Ship",
					Size = v(16, 34, 44),
					Tag = "BiomeBob",
					Parts = {
						part(v(16, 8, 44), v(0, 4, 0), rgb(110, 70, 40), M.WoodPlanks),
						part(v(1.5, 30, 1.5), v(0, 19, 0), rgb(90, 60, 35), M.Wood),
						part(v(14, 14, 0.5), v(0, 22, 0), rgb(240, 235, 220), M.Fabric),
					},
				},
				block("Lighthouse", v(10, 40, 10), rgb(240, 240, 240), M.SmoothPlastic, {
					part(v(10.4, 6, 10.4), v(0, 16, 0), rgb(210, 40, 40), M.SmoothPlastic),
					part(v(8, 4, 8), v(0, 42, 0), rgb(255, 230, 120), M.Neon),
				}),
				block("Fort", v(36, 14, 24), rgb(160, 150, 130), M.Cobblestone),
			},
		},
		Horizon = {
			Offset = 320,
			Props = { peak("Island", v(140, 40, 100), rgb(80, 140, 70), rgb(60, 150, 70), M.Grass) },
		},
		Gate = gate(rgb(110, 70, 40), M.WoodPlanks),
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 170,
			Props = {
				"Palm",
				block("Boulder", v(8, 5, 6), rgb(130, 120, 110), M.Slate),
				block("Chest", v(4, 3, 3), rgb(120, 76, 40), M.WoodPlanks, {
					part(v(4.2, 0.6, 3.2), v(0, 2.2, 0), rgb(230, 190, 60), M.Metal),
				}),
				"Barrel",
				"Palm",
				block("Anchor", v(6, 8, 2), rgb(70, 72, 80), M.CorrodedMetal, {
					part(v(6, 1.5, 2), v(0, 1, 0), rgb(70, 72, 80), M.CorrodedMetal),
				}),
			},
			Patches = {
				patch("TidePool", 22, 16, rgb(60, 176, 206), M.Glass),
				patch("WetSand", 28, 18, rgb(196, 168, 118), M.Sand),
				patch("Seaweed", 12, 10, rgb(60, 120, 70), M.Grass),
			},
		},
		Particles = { -- sea spray
			Texture = SPARKLE,
			Color = rgb(235, 250, 255),
			Size = 0.7,
			Lifetime = 2,
			Rate = 6,
			Speed = 6,
			Spread = 40,
			Acceleration = v(0, -6, 0),
			LightEmission = 0.4,
		},
	},

	City = {
		Ground = { Color = rgb(40, 44, 58), Material = M.Concrete },
		Rhythm = {
			Every = 4,
			Offset = 10,
			Props = {
				pole("Streetlight", 16, rgb(40, 40, 50), rgb(255, 80, 190)),
				block("Hydrant", v(2, 3, 2), rgb(220, 40, 40), M.Metal),
				block("Sign", v(6, 10, 1), rgb(30, 30, 40), M.Metal, {
					part(v(6.2, 3, 1.2), v(0, 8, 0), rgb(80, 220, 255), M.Neon),
				}),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 10,
			Props = {
				skyscraper("Skyscraper", 24, 60, 30, {
					Body = rgb(70, 78, 104),
					Trim = rgb(150, 156, 172),
					Glass = rgb(60, 140, 200),
					Neon = rgb(80, 220, 255),
					Roof = "tank",
				}),
				skyscraper("SkyscraperPink", 22, 80, 22, {
					Body = rgb(64, 50, 92),
					Trim = rgb(170, 160, 190),
					Glass = rgb(120, 90, 180),
					Neon = rgb(255, 80, 190),
					Roof = "spire",
				}),
			},
		},
		Horizon = {
			Offset = 300,
			Props = {
				skyscraper("Skyline", 60, 140, 40, {
					Body = rgb(40, 46, 76),
					Trim = rgb(90, 96, 120),
					Glass = rgb(50, 110, 170),
					Neon = rgb(80, 220, 255),
					MaxBands = 8,
					Roof = "spire",
				}),
			},
		},
		Gate = gate(rgb(30, 30, 40), M.Metal, rgb(255, 80, 190)),
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 160,
			Props = {
				"Sign",
				block("Billboard", v(30, 24, 2), rgb(30, 30, 40), M.Metal, {
					part(v(30.2, 12, 2.2), v(0, 18, 0), rgb(255, 210, 60), M.Neon),
				}),
				block("Bench", v(6, 2.5, 2), rgb(90, 60, 40), M.WoodPlanks),
				block("Kiosk", v(6, 8, 6), rgb(40, 44, 60), M.Metal, {
					part(v(6.4, 1, 6.4), v(0, 8, 0), rgb(80, 220, 255), M.Neon),
				}),
				block("Planter", v(6, 3, 6), rgb(150, 150, 160), M.Concrete, {
					part(v(5, 2, 5), v(0, 3.5, 0), rgb(60, 130, 70), M.Grass),
				}),
				"Hydrant",
				skyscraper("Block", 18, 36, 18, {
					Body = rgb(84, 90, 116),
					Trim = rgb(140, 146, 160),
					Glass = rgb(70, 150, 210),
					Neon = rgb(255, 80, 190),
					Tiers = 1,
					MaxBands = 5,
				}),
			},
			Patches = {
				patch("Crosswalk", 22, 6, rgb(235, 235, 240), M.Concrete),
				patch("NeonPuddle", 14, 10, rgb(80, 220, 255), M.Glass),
				patch("Asphalt", 30, 20, rgb(30, 32, 40), M.Asphalt),
			},
		},
		Particles = { -- neon sparkle
			Texture = SPARKLE,
			Color = ColorSequence.new(rgb(255, 80, 190), rgb(80, 220, 255)),
			Size = 0.6,
			Lifetime = 3,
			Rate = 5,
			Speed = 2,
			LightEmission = 1,
		},
	},

	Desert = {
		Ground = { Color = rgb(224, 177, 92), Material = M.Sand },
		Rhythm = {
			Every = 4,
			Offset = 12,
			Props = {
				block("Cactus", v(3, 12, 3), rgb(70, 130, 60), M.Grass, {
					part(v(5, 1.5, 1.5), v(0, 7, 0), rgb(70, 130, 60), M.Grass),
				}),
				block("Rock", v(7, 4, 6), rgb(170, 110, 60), M.Sandstone),
			},
		},
		Landmarks = {
			Offset = 45,
			Every = 18,
			Props = {
				block("Mesa", v(44, 24, 34), rgb(156, 91, 48), M.Sandstone, {
					part(v(46, 2, 36), v(0, 14, 0), rgb(190, 120, 70), M.Sandstone),
				}),
				{
					Name = "Windmill",
					Size = v(20, 34, 20),
					Tag = "BiomeSpin",
					Parts = {
						part(v(2, 30, 2), v(0, 15, 0), rgb(120, 120, 125), M.Metal),
						part(v(20, 2, 1), v(0, 30, -1.5), rgb(200, 200, 200), M.Metal),
						part(v(2, 20, 1), v(0, 30, -1.5), rgb(200, 200, 200), M.Metal),
					},
				},
				block("GasStation", v(28, 10, 18), rgb(230, 220, 200), M.WoodPlanks, {
					part(v(28.4, 2, 18.4), v(0, 9, 0), rgb(220, 60, 40), M.SmoothPlastic),
				}),
			},
		},
		Horizon = {
			Offset = 300,
			Props = { block("CanyonWall", v(200, 60, 40), rgb(170, 95, 55), M.Sandstone) },
		},
		Gate = gate(rgb(156, 91, 48), M.Sandstone),
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 170,
			Props = {
				"Cactus",
				ball("Tumbleweed", 4, rgb(150, 112, 64), M.Wood, "BiomeSpin"),
				block("Boulder", v(10, 7, 9), rgb(184, 120, 70), M.Sandstone),
				block("DeadTree", v(1.5, 12, 1.5), rgb(110, 80, 56), M.Wood, {
					part(v(6, 1, 1), v(1.5, 9, 0), rgb(110, 80, 56), M.Wood),
				}),
				"Rock",
			},
			Patches = {
				patch("CrackedEarth", 26, 20, rgb(204, 150, 92), M.Ground),
				patch("DryGrass", 16, 12, rgb(182, 164, 92), M.Grass),
				patch("RedSand", 30, 18, rgb(206, 126, 76), M.Sand),
			},
		},
		Particles = { -- dust devils
			Texture = SMOKE,
			Color = rgb(226, 190, 140),
			Size = 5,
			Lifetime = 5,
			Rate = 3,
			Speed = 3,
			Acceleration = v(3, 0.5, 0),
			Transparency = 0.7,
		},
	},

	Snow = {
		Ground = { Color = rgb(235, 248, 255), Material = M.Snow },
		Rhythm = {
			Every = 3,
			Offset = 10,
			Props = {
				tree("SnowPine", 22, rgb(92, 64, 44), rgb(35, 100, 84)),
				block("Snowman", v(5, 9, 5), rgb(250, 250, 255), M.Snow, {
					part(v(3.5, 3.5, 3.5), v(0, 8, 0), rgb(250, 250, 255), M.Snow, Enum.PartType.Ball),
				}),
				block("Fence", v(10, 3, 1), rgb(120, 80, 50), M.Wood),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 18,
			Props = {
				block("Cabin", v(22, 12, 18), rgb(110, 70, 45), M.WoodPlanks, {
					part(v(24, 4, 20), v(0, 14, 0), rgb(245, 250, 255), M.Snow),
				}),
				block("IceCliff", v(40, 30, 24), rgb(170, 220, 245), M.Ice),
				block("SkiLift", v(6, 40, 6), rgb(70, 70, 80), M.Metal, {
					part(v(20, 2, 2), v(0, 40, 0), rgb(220, 40, 40), M.Metal),
				}),
			},
		},
		Horizon = {
			Offset = 320,
			Props = { peak("Peak", v(180, 120, 140), rgb(110, 120, 135), rgb(245, 250, 255)) },
		},
		Gate = gate(rgb(110, 70, 45), M.WoodPlanks, rgb(160, 210, 255)),
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 160,
			Props = {
				"SnowPine",
				block("SnowDrift", v(10, 3, 6), rgb(244, 250, 255), M.Snow),
				block("IceShard", v(4, 10, 4), rgb(170, 220, 245), M.Ice),
				"SnowPine",
				block("SnowRock", v(7, 4, 6), rgb(120, 126, 140), M.Slate, {
					part(v(6, 1, 5), v(0, 4.3, 0), rgb(245, 250, 255), M.Snow),
				}),
			},
			Patches = {
				patch("FrozenPond", 26, 18, rgb(178, 222, 248), M.Ice),
				patch("BlueSnow", 30, 20, rgb(214, 232, 250), M.Snow),
				patch("Tracks", 24, 4, rgb(200, 214, 228), M.Snow),
			},
		},
		Particles = { -- snowfall
			Texture = SPARKLE,
			Color = rgb(255, 255, 255),
			Size = 0.6,
			Lifetime = 6,
			Rate = 8,
			Speed = 2,
			Acceleration = v(0.5, -3, 0),
			LightEmission = 0.2,
		},
	},

	Volcano = {
		Ground = { Color = rgb(42, 38, 48), Material = M.Basalt },
		Rhythm = {
			Every = 4,
			Offset = 12,
			Props = {
				block("BasaltSpike", v(5, 14, 5), rgb(42, 38, 48), M.Basalt),
				block("GlowCrack", v(10, 0.6, 3), rgb(255, 72, 18), M.Neon),
			},
		},
		Landmarks = {
			Offset = 45,
			Every = 16,
			Props = {
				block("LavaFall", v(20, 30, 10), rgb(42, 38, 48), M.Basalt, {
					part(v(8, 30, 1), v(0, 15, -5.2), rgb(255, 90, 20), M.Neon),
				}),
				block("Crater", v(40, 10, 40), rgb(55, 45, 50), M.Basalt, {
					part(v(30, 0.6, 30), v(0, 10, 0), rgb(255, 72, 18), M.Neon),
				}),
				block("ObsidianShard", v(10, 26, 10), rgb(20, 18, 28), M.Glass),
			},
		},
		Horizon = {
			Offset = 320,
			Props = { peak("Volcano", v(200, 130, 200), rgb(50, 42, 48), rgb(255, 80, 20), M.Neon) },
		},
		Gate = gate(rgb(42, 38, 48), M.Basalt, rgb(255, 110, 40)),
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 160,
			Props = {
				"BasaltSpike",
				block("Boulder", v(9, 6, 8), rgb(52, 46, 56), M.Basalt, {
					part(v(9.2, 0.4, 2), v(0, 3, 0), rgb(255, 90, 20), M.Neon),
				}),
				block("SteamVent", v(5, 2, 5), rgb(60, 52, 58), M.Basalt, {
					part(v(2, 0.4, 2), v(0, 2.1, 0), rgb(255, 140, 40), M.Neon),
				}),
				block("Obsidian", v(4, 8, 4), rgb(20, 18, 28), M.Glass),
			},
			Patches = {
				patch("LavaPool", 20, 14, rgb(255, 92, 22), M.Neon),
				patch("Ash", 28, 20, rgb(72, 66, 72), M.Slate),
				patch("Cooling", 16, 10, rgb(150, 40, 20), M.CrackedLava),
			},
		},
		Particles = { -- rising embers
			Texture = SPARKLE,
			Color = ColorSequence.new(rgb(255, 210, 80), rgb(255, 60, 20)),
			Size = 0.5,
			Lifetime = 3,
			Rate = 8,
			Speed = 6,
			Spread = 30,
			Acceleration = v(0, 3, 0),
			LightEmission = 1,
		},
	},

	Space = {
		Ground = { Color = rgb(10, 14, 35), Material = M.Slate },
		Rhythm = {
			Every = 4,
			Offset = 10,
			Props = {
				pole("Pylon", 20, rgb(80, 95, 130), rgb(80, 240, 255)),
				block("LightStrip", v(12, 0.6, 2), rgb(180, 120, 255), M.Neon),
			},
		},
		Landmarks = {
			Offset = 45,
			Every = 18,
			Props = {
				block("Dome", v(30, 16, 30), rgb(120, 140, 180), M.Glass, {
					part(v(32, 2, 32), v(0, 1, 0), rgb(80, 95, 130), M.Metal),
				}),
				{
					Name = "Dish",
					Size = v(20, 30, 20),
					Tag = "BiomeSpin",
					Parts = {
						part(v(3, 20, 3), v(0, 10, 0), rgb(80, 95, 130), M.Metal),
						part(v(20, 2, 20), v(0, 22, 0), rgb(200, 210, 230), M.Metal),
					},
				},
				block("Rover", v(12, 6, 16), rgb(200, 200, 210), M.Metal, {
					part(v(4, 2, 4), v(0, 7, 0), rgb(80, 240, 255), M.Neon),
				}),
			},
		},
		Horizon = {
			Offset = 360,
			Props = {
				{
					Name = "Planet",
					Size = v(120, 120, 120),
					Parts = {
						part(v(120, 120, 120), v(0, 120, 0), rgb(150, 90, 200), M.SmoothPlastic, Enum.PartType.Ball),
					},
				},
			},
		},
		Gate = gate(rgb(80, 95, 130), M.Metal, rgb(80, 240, 255)),
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 170,
			Props = {
				block("Crystal", v(4, 9, 4), rgb(190, 110, 255), M.Neon),
				block("MoonRock", v(8, 4, 7), rgb(110, 116, 140), M.Slate),
				block("Antenna", v(1, 14, 1), rgb(160, 170, 200), M.Metal, {
					part(v(2, 2, 2), v(0, 14, 0), rgb(255, 60, 90), M.Neon),
				}),
				"Pylon",
				ball("Orb", 5, rgb(80, 240, 255), M.ForceField, "BiomeBob"),
			},
			Patches = {
				patch("Crater", 26, 26, rgb(20, 24, 52), M.Slate),
				patch("GlowPad", 12, 12, rgb(80, 240, 255), M.Neon),
				patch("Stardust", 30, 18, rgb(120, 100, 180), M.Sand),
			},
		},
		Particles = { -- star twinkle
			Texture = SPARKLE,
			Color = ColorSequence.new(rgb(120, 240, 255), rgb(200, 140, 255)),
			Size = 0.7,
			Lifetime = 3,
			Rate = 6,
			Speed = 0.6,
			LightEmission = 1,
		},
	},
}
