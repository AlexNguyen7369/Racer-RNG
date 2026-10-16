--!nonstrict
-- Track 8: a frozen pass with rolling slopes and a mountain hairpin.
return {
	Name = "Snow",
	Description = "A frozen mountain pass between snowbanks, pines, and blue ice cliffs.",
	Number = 8,
	Biome = "Snow",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromRGB(116, 145, 170),
		Support = Color3.fromRGB(75, 105, 132),
		Wall = Color3.fromRGB(195, 235, 255),
		Ground = Color3.fromRGB(190, 220, 235),
		Line = Color3.fromRGB(255, 255, 255),
		Checkpoint = Color3.fromRGB(110, 164, 198),
		WinPad = Color3.fromRGB(255, 218, 42),
	},
	Segments = {
		{ Type = "Straight", Length = 180 },
		{ Type = "Turn", Angle = 90, Radius = 78 },
		{ Type = "Straight", Length = 160 },
		{ Type = "Slope", Length = 220, Rise = 28 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = -180, Radius = 86 },
		{ Type = "Straight", Length = 160 },
		{ Type = "Slope", Length = 220, Rise = -28 },
		{ Type = "Turn", Angle = 90, Radius = 78 },
		{ Type = "Straight", Length = 180 },
		{ Type = "Straight", Length = 140 },
	},
}
