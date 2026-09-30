--!nonstrict
-- Rectangle circuit with an S-bend on each long side. The two S-bends shift the road in
-- opposite world directions, so the loop still closes.
return {
	Name = "Circuit",
	Description = "Four corners plus two S-bends. Tests turn-in and direction changes.",
	Width = 36,
	Closed = true,
	Segments = {
		{ Type = "Straight", Length = 120 },
		{ Type = "Turn", Angle = 45, Radius = 60 },
		{ Type = "Turn", Angle = -45, Radius = 60 },
		{ Type = "Straight", Length = 60 },
		{ Type = "Turn", Angle = 90, Radius = 70 },
		{ Type = "Straight", Length = 140 },
		{ Type = "Turn", Angle = 90, Radius = 70 },
		{ Type = "Straight", Length = 120 },
		{ Type = "Turn", Angle = 45, Radius = 60 },
		{ Type = "Turn", Angle = -45, Radius = 60 },
		{ Type = "Straight", Length = 60 },
		{ Type = "Turn", Angle = 90, Radius = 70 },
		{ Type = "Straight", Length = 140 },
		{ Type = "Turn", Angle = 90, Radius = 70 },
	},
}
