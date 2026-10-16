--!nonstrict
-- Track 9: an advanced volcanic route with a technical hairpin.
return {
	Name = "Volcano",
	Description = "A basalt and lava run over steep ridges, technical bends, and a long crater approach.",
	Number = 9,
	Biome = "Volcano",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromRGB(58, 52, 62),
		Support = Color3.fromRGB(35, 32, 42),
		Wall = Color3.fromRGB(255, 92, 30),
		Ground = Color3.fromRGB(55, 38, 40),
		Line = Color3.fromRGB(255, 196, 70),
		Checkpoint = Color3.fromRGB(108, 50, 44),
		WinPad = Color3.fromRGB(255, 218, 42),
	},
	Segments = {
		{ Type = "Straight", Length = 180 },
		{ Type = "Slope", Length = 220, Rise = 40 },
		{ Type = "Turn", Angle = 120, Radius = 72 },
		{ Type = "Straight", Length = 150 },
		{ Type = "Straight", Length = 552 },
		{ Type = "Turn", Angle = -120, Radius = 72 },
		{ Type = "Slope", Length = 220, Rise = -40 },
		{ Type = "Straight", Length = 180 },
		{ Type = "Straight", Length = 64 },
	},
}
