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
	},
	night = {
		Name = "NIGHT RACE",
		Luck = 1,
		Money = 2,
		NpcSpeed = 1.25,
		ClockTime = 0,
		Brightness = 1,
		Color = Color3.fromRGB(126, 101, 211),
	},
	gold = {
		Name = "GOLD RUSH",
		Luck = 1,
		Money = 3,
		NpcSpeed = 1,
		ClockTime = 17,
		Brightness = 3,
		Color = Color3.fromRGB(255, 199, 72),
	},
}

return WeatherConfig
