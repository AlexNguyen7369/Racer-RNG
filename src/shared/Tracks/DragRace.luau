--!nonstrict
-- Short straight sprint: Track 3 continues from Track 2's checkpoint.
return {
	Name = "DragRace",
	Description = "Short straight drag race with a bold sunset palette, built as the next leg after Hill.",
	Number = 3,
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromRGB(72, 48, 88),
		Support = Color3.fromRGB(45, 30, 62),
		Wall = Color3.fromRGB(255, 119, 58),
		Ground = Color3.fromRGB(112, 67, 74),
		Line = Color3.fromRGB(255, 235, 174),
		Checkpoint = Color3.fromRGB(94, 49, 76),
		WinPad = Color3.fromRGB(255, 194, 54),
	},
	Segments = {
		-- Keep the sprint visually short while satisfying the shared point-to-point
		-- minimum and leaving a real finish gap from the start.
		{ Type = "Straight", Length = 320 },
	},
}
