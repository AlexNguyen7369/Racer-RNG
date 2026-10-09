--!nonstrict
-- UTC-day login rewards. The server owns claim timing.

local DailyLoginConfig = {}

DailyLoginConfig.Rewards = {
	{ Money = 500 },
	{ Money = 1000 },
	{ Money = 2500, Boost = "Luck" },
	{ Money = 5000, Boost = "Money" },
	{ Money = 10000, Boost = "Speed" },
	{ Money = 25000, Boost = "Luck", BoostCount = 2 },
	{ Money = 50000, GuaranteedRare = true },
}

return DailyLoginConfig
