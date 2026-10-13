--!nonstrict
-- Server-wide events. Economy effects are read on the server; clients display the replicated event.
local WeatherConfig = {}

WeatherConfig.MIN_INTERVAL = 10 * 60
WeatherConfig.MAX_INTERVAL = 20 * 60
WeatherConfig.DURATION = 3 * 60
WeatherConfig.Order = { "rain", "night", "gold" }
WeatherConfig.Events = {
	rain = {
		Name = "RAIN",
		Luck = 2,
		Money = 1,
		NpcSpeed = 1,
		ClockTime = 14,
		Brightness = 1,
		Color = Color3.fromRGB(88, 157, 210),
		Sky = { -- grey-blue, dense, hazy; heavy dark cover
			Atmosphere = { Color = Color3.fromRGB(120, 140, 160), Density = 0.5, Haze = 3 },
			Clouds = { Cover = 0.9, Density = 0.8, Color = Color3.fromRGB(90, 95, 105) },
			StarCount = 0,
		},
	},
	night = {
		Name = "NIGHT RACE",
		Luck = 1,
		Money = 2,
		NpcSpeed = 1.25,
		ClockTime = 0,
		Brightness = 1,
		Color = Color3.fromRGB(126, 101, 211),
		Sky = { -- dark violet, thin; light cover, many stars
			Atmosphere = { Color = Color3.fromRGB(60, 40, 110), Density = 0.2, Haze = 0 },
			Clouds = { Cover = 0.3, Density = 0.4, Color = Color3.fromRGB(70, 60, 110) },
			StarCount = 5000,
		},
	},
	gold = {
		Name = "GOLD RUSH",
		Luck = 1,
		Money = 3,
		NpcSpeed = 1,
		ClockTime = 17,
		Brightness = 3,
		Color = Color3.fromRGB(255, 199, 72),
		Sky = { -- warm gold, light haze; thin golden clouds
			Atmosphere = { Color = Color3.fromRGB(255, 200, 110), Density = 0.3, Haze = 1 },
			Clouds = { Cover = 0.4, Density = 0.2, Color = Color3.fromRGB(255, 215, 130) },
			StarCount = 0,
		},
	},
}

return WeatherConfig
