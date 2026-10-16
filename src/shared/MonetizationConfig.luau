--!nonstrict
-- The Creator Dashboard supplies the real ids. Zero keeps an entry visible in the Shop while it is not published.
local MonetizationConfig = {}

MonetizationConfig.Gamepasses = {
	{ Id = "vip", Name = "VIP", GamepassId = 0, Description = "VIP title, perks, and priority treatment." },
	{ Id = "auto_roll_2x", Name = "2x Auto-Roll", GamepassId = 0, Description = "Roll twice as fast." },
	{ Id = "extra_roll_1", Name = "Extra Roll I", GamepassId = 0, Description = "+1 simultaneous auto-roll (2 total)." },
	{ Id = "extra_roll_2", Name = "Extra Roll II", GamepassId = 0, Description = "+1 more simultaneous auto-roll (3 total)." },
	{ Id = "speed_doubler_1", Name = "Speed Doubler I", GamepassId = 0, Description = "Doubles Speed gain." },
	{ Id = "speed_doubler_2", Name = "Speed Doubler II", GamepassId = 0, Description = "Doubles the Speed Doubler effect again." },
	{ Id = "speed_doubler_3", Name = "Speed Doubler III", GamepassId = 0, Description = "Third tier of the Speed Doubler chain." },
	{ Id = "speed_doubler_4", Name = "Speed Doubler IV", GamepassId = 0, Description = "Fourth tier of the Speed Doubler chain." },
	{ Id = "speed_doubler_5", Name = "Speed Doubler V", GamepassId = 0, Description = "Final planned Speed Doubler tier." },
	{ Id = "money_2x", Name = "2x Money", GamepassId = 0, Description = "Doubles race payouts." },
	{ Id = "luck_1", Name = "+1 Luck", GamepassId = 0, Description = "Adds one permanent base Luck." },
	{ Id = "luck_2", Name = "+2 Luck", GamepassId = 0, Description = "Adds two permanent base Luck." },
	{ Id = "workshop_gold", Name = "Gold Workshop", GamepassId = 0, Description = "Permanent Gold workshop tier." },
	{ Id = "workshop_diamond", Name = "Diamond Workshop", GamepassId = 0, Description = "Permanent Diamond workshop tier." },
	{ Id = "workshop_void", Name = "Void Workshop", GamepassId = 0, Description = "Permanent Void workshop tier." },
}

return MonetizationConfig
