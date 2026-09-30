--!nonstrict
-- Beginner track: two long straights joined by wide, gentle hairpins.
return {
	Name = "Oval",
	Description = "Easy point-to-point oval: long straights and wide left turns test top speed and steady cornering. Ends on a short level straight with a wide checkpoint area that leads to the next track.",
	Number = 1,
	Width = 40,
	Closed = false,
	Segments = {
		{ Type = "Straight", Length = 240 },
		{ Type = "Turn", Angle = 180, Radius = 90 },
		{ Type = "Straight", Length = 240 },
		{ Type = "Turn", Angle = 90, Radius = 90 },
		{ Type = "Straight", Length = 80 },
	},
}
