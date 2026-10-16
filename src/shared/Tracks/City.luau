--!nonstrict
-- Track 6: a long neon city route with broad, readable turns.
return {
	Name = "City",
	Description = "A neon city run through towers, signs, and four broad street-corner turns.",
	Number = 6,
	Biome = "City",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromRGB(45, 48, 68),
		Support = Color3.fromRGB(28, 30, 48),
		Wall = Color3.fromRGB(70, 220, 255),
		Ground = Color3.fromRGB(28, 35, 52),
		Line = Color3.fromRGB(255, 80, 190),
		Checkpoint = Color3.fromRGB(50, 60, 92),
		WinPad = Color3.fromRGB(255, 218, 42),
		Checkered = true,
		CheckerDark = Color3.fromRGB(20, 22, 35),
	},
	Segments = {
		{ Type = "Straight", Length = 180 },
		{ Type = "Turn", Angle = 90, Radius = 72 },
		{ Type = "Straight", Length = 220 },
		{ Type = "Turn", Angle = -90, Radius = 72 },
		{ Type = "Straight", Length = 220 },
		{ Type = "Turn", Angle = -90, Radius = 72 },
		{ Type = "Straight", Length = 220 },
		{ Type = "Turn", Angle = 90, Radius = 72 },
		{ Type = "Straight", Length = 220 },
		{ Type = "Straight", Length = 140 },
	},
}
