--!nonstrict
-- Track 7: a long canyon route with safe climbs and sweeping bends.
return {
	Name = "Desert",
	Description = "A sun-baked canyon road climbing over mesas and sweeping through a wide hairpin.",
	Number = 7,
	Biome = "Desert",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromRGB(112, 82, 66),
		Support = Color3.fromRGB(90, 55, 40),
		Wall = Color3.fromRGB(218, 157, 82),
		Ground = Color3.fromRGB(210, 157, 78),
		Line = Color3.fromRGB(255, 238, 172),
		Checkpoint = Color3.fromRGB(164, 108, 56),
		WinPad = Color3.fromRGB(255, 218, 42),
	},
	Segments = {
		{ Type = "Straight", Length = 180 },
		{ Type = "Slope", Length = 220, Rise = 35 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = 90, Radius = 75 },
		{ Type = "Straight", Length = 180 },
		{ Type = "Turn", Angle = -180, Radius = 92 },
		{ Type = "Straight", Length = 180 },
		{ Type = "Slope", Length = 220, Rise = -35 },
		{ Type = "Straight", Length = 180 },
		{ Type = "Straight", Length = 140 },
	},
}
