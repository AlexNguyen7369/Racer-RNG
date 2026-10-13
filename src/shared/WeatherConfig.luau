--!nonstrict
-- Server-wide events. Economy effects are read on the server; clients display the replicated event.
local WeatherConfig = {}

-- A weather starts every INTERVAL (start to start) and lasts DURATION (docs/WEATHER_EVENTS_SPEC.md, "Schedule").
WeatherConfig.INTERVAL = 15 * 60
WeatherConfig.DURATION = 3 * 60
-- Picked with equal chance; the owner plans weighted chances later.
WeatherConfig.Order = { "clear", "rain", "night", "gold", "aurora" }
-- Icons are text glyphs until image icons exist.
WeatherConfig.Events = {
	-- A real pick with no effect: no Sky, ClockTime, Brightness or Color, so the baseline stays.
	clear = { Name = "CLEAR", Icon = "☀", Luck = 1, Money = 1, NpcSpeed = 1 },
	rain = {
		Name = "RAIN",
		Icon = "🌧",
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
		Icon = "🌙",
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
		Icon = "💰",
		Luck = 1,
		Money = 3,
		NpcSpeed = 1,
		ClockTime = 17.6,
		Brightness = 3,
		Color = Color3.fromRGB(255, 190, 60),
		Sky = { -- deep gold haze over the whole sky; broad, thin golden clouds (must not read as the clear sky)
			Atmosphere = { Color = Color3.fromRGB(255, 170, 60), Density = 0.45, Haze = 2.6 },
			Clouds = { Cover = 0.6, Density = 0.3, Color = Color3.fromRGB(255, 195, 90) },
			StarCount = 0,
		},
	},
	aurora = {
		Name = "AURORA",
		Icon = "🌌",
		Luck = 1.5,
		Money = 1.5,
		NpcSpeed = 1,
		ClockTime = 19.3,
		Brightness = 1,
		Color = Color3.fromRGB(90, 230, 170),
		Sky = { -- bright teal-green glow at dusk; violet clouds, stars (must not read as the black night sky)
			Atmosphere = { Color = Color3.fromRGB(40, 255, 170), Density = 0.42, Haze = 2.4 },
			Clouds = { Cover = 0.55, Density = 0.3, Color = Color3.fromRGB(170, 110, 255) },
			StarCount = 3000,
		},
	},
}

-- What a weather changes, for the HUD card: every multiplier that is not 1, else "NO BONUS".
function WeatherConfig.Describe(id)
	local spec = WeatherConfig.Events[id]
	local parts = {}
	for _, stat in { { "Luck", "LUCK x" }, { "Money", "MONEY x" }, { "NpcSpeed", "NPC SPEED x" } } do
		if spec and spec[stat[1]] ~= 1 then
			table.insert(parts, stat[2] .. tostring(spec[stat[1]]))
		end
	end
	return #parts > 0 and table.concat(parts, " • ") or "NO BONUS"
end

return WeatherConfig
