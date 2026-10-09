--!nonstrict
-- Technical point-to-point circuit with repeated gentle S-bends. It always makes
-- forward progress, so the numbered route cannot fold back across its neighbours.
return {
	Name = "Circuit",
	Description = "Eight gentle direction changes on a point-to-point route. Tests turn-in without folding back across the chain.",
	Number = 4,
	Width = 36,
	Closed = false,
	Segments = {
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = 45, Radius = 60 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = -45, Radius = 60 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = 45, Radius = 60 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = -45, Radius = 60 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = 45, Radius = 60 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = -45, Radius = 60 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = 45, Radius = 60 },
		{ Type = "Straight", Length = 100 },
		{ Type = "Turn", Angle = -45, Radius = 60 },
		{ Type = "Straight", Length = 100 },
	},
}
