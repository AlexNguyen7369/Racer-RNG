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

local function tower(name, w, h, d, color, material, stripe)
	return block(name, v(w, h, d), color, material, {
		part(v(w + 0.2, 2, d + 0.2), v(0, h * 0.7, 0), stripe, M.Neon),
		part(v(w + 0.2, 2, d + 0.2), v(0, h * 0.4, 0), stripe, M.Neon),
	})
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
				tower("Tower", 24, 60, 30, rgb(35, 42, 70), M.Concrete, rgb(80, 220, 255)),
				tower("TowerPink", 22, 80, 22, rgb(45, 35, 70), M.Glass, rgb(255, 80, 190)),
				block("Billboard", v(30, 24, 2), rgb(30, 30, 40), M.Metal, {
					part(v(30.2, 12, 2.2), v(0, 18, 0), rgb(255, 210, 60), M.Neon),
				}),
			},
		},
		Horizon = {
			Offset = 300,
			Props = { tower("Skyline", 60, 140, 40, rgb(25, 30, 55), M.Concrete, rgb(80, 220, 255)) },
		},
		Gate = gate(rgb(30, 30, 40), M.Metal, rgb(255, 80, 190)),
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
	},
}
