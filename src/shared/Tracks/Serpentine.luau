--!nonstrict
-- Point-to-point sprint: a zig-zag of 90 degree corners. Not a loop.
return {
	Name = "Serpentine",
	Description = "Sprint with alternating left/right 90s.",
	Width = 36,
	Closed = false,
	Segments = {
		{ Type = "Straight", Length = 150 },
		{ Type = "Turn", Angle = 90, Radius = 60 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = -90, Radius = 60 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = -90, Radius = 60 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = 90, Radius = 60 },
		{ Type = "Straight", Length = 150 },
	},
}
