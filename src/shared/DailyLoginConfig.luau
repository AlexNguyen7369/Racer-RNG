--!nonstrict
-- UTC-day login rewards. The server owns claim timing.
-- No Money: Money comes only from race cash-outs and duplicate car sales (design doc, "Economy").

local DailyLoginConfig = {}

DailyLoginConfig.Rewards = {
	{ Boost = "Luck" },
	{ Boost = "Money" },
	{ Boost = "Luck" },
	{ Boost = "Money" },
	{ Boost = "Speed" },
	{ Boost = "Luck", BoostCount = 2 },
	{ GuaranteedRare = true },
}

return DailyLoginConfig
