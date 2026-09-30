--!nonstrict
-- Beginner track: an oval with a smooth hill on each long straight.
return {
	Name = "Hill",
	Description = "Point-to-point hill run: a hill on each straight joined by a wide right hairpin, ending on a short level straight with a wide checkpoint area that leads to the next track. Tests climbing, cresting and descending at speed without stalling or leaving the road.",
	Width = 40,
	Closed = false,
	Number = 2,
	Segments = {
		{ Type = "Straight", Length = 100 },
		{ Type = "Slope", Length = 160, Rise = 30 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Slope", Length = 160, Rise = -30 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = -180, Radius = 80 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Slope", Length = 160, Rise = 30 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Slope", Length = 160, Rise = -30 },
		{ Type = "Straight", Length = 100 },
	},
}
