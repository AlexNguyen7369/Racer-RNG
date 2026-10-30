--!nonstrict
-- Track 10: the capstone orbital route with a high-radius hairpin and long approaches.
return {
	Name = "Space",
	Description = "An orbital frontier run across luminous platforms, pylons, and a luminous hairpin.",
	Number = 10,
	Biome = "Space",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromRGB(42, 55, 88),
		Support = Color3.fromRGB(24, 30, 60),
		Wall = Color3.fromRGB(84, 245, 255),
		Ground = Color3.fromRGB(10, 14, 35),
		Line = Color3.fromRGB(180, 120, 255),
		Checkpoint = Color3.fromRGB(48, 72, 130),
		WinPad = Color3.fromRGB(255, 218, 42),
	},
	Segments = {
		{ Type = "Straight", Length = 220 },
		{ Type = "Turn", Angle = 90, Radius = 82 },
		{ Type = "Straight", Length = 180 },
		{ Type = "Slope", Length = 250, Rise = 60 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = 180, Radius = 128 },
		{ Type = "Straight", Length = 180 },
		{ Type = "Turn", Angle = -90, Radius = 82 },
		{ Type = "Straight", Length = 220 },
		{ Type = "Straight", Length = 140 },
	},
}
