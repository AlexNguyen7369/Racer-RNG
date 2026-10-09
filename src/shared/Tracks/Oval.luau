--!nonstrict
-- Beginner track: two long straights joined by wide, gentle hairpins.
return {
	Name = "Oval",
	Description = "Easy point-to-point oval: long straights and wide left turns test top speed and steady cornering. Ends on a short level straight with a wide checkpoint area that leads to the next track.",
	Number = 1,
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromRGB(110, 116, 132),
		Support = Color3.fromRGB(70, 74, 88),
		Wall = Color3.fromRGB(188, 42, 48),
		Ground = Color3.fromRGB(74, 112, 72),
		Line = Color3.fromRGB(245, 245, 245),
		Checkpoint = Color3.fromRGB(128, 34, 40),
		WinPad = Color3.fromRGB(255, 218, 42),
		Checkered = true,
		CheckerDark = Color3.fromRGB(28, 30, 38),
	},
	Segments = {
		{ Type = "Straight", Length = 240 },
		{ Type = "Turn", Angle = 180, Radius = 90 },
		{ Type = "Straight", Length = 240 },
		{ Type = "Turn", Angle = 90, Radius = 90 },
		{ Type = "Straight", Length = 80 },
	},
}
