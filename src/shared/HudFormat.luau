--!nonstrict
-- Pure helpers for the HUD (Client/SpeedHud, Client/AutoRaceButton), kept here so they can be tested.

local RaceConfig = require(script.Parent.RaceConfig)

local HudFormat = {}

local SMOOTH_RATE = 8 -- 1/s: how fast the shown number chases the real stat
local SNAP = 0.005

-- Whole number with thousands separators, never scientific: 1234.9 -> "1,234".
local function commas(n)
	local text = string.format("%.0f", math.floor(n))
	local replaced
	repeat
		text, replaced = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
	until replaced == 0
	return text
end

HudFormat.SUFFIX_FROM = 1e3 -- placeholder: from 1k Money switches to suffixes (owner 2026-10-27)
HudFormat.SPEED_SUFFIX_FROM = 1e6 -- placeholder: Speed keeps full digits to 1m so each second's gain shows (owner 2026-10-27)

-- Full digits below SPEED_SUFFIX_FROM ("123,456"); from there on "1.23m", "2.5qt" (HudFormat.Short).
-- Anything that is not a real stat shows 0.
function HudFormat.SpeedText(stat)
	if type(stat) ~= "number" or stat ~= stat or stat < 0 or stat == math.huge then
		return "0"
	end
	return stat >= HudFormat.SPEED_SUFFIX_FROM and HudFormat.Short(stat) or commas(stat)
end

-- A Speed gain: one decimal below 10 so a quarter second's small gain still shows ("0.5", "2"), else SpeedText.
function HudFormat.GainText(gain)
	if type(gain) == "number" and gain == gain and gain > 0 and gain < 10 then
		return (string.format("%.1f", gain):gsub("%.0$", ""))
	end
	return HudFormat.SpeedText(gain)
end

local SUFFIXES = { "k", "m", "b", "t", "qd", "qt", "sx", "sp", "oc", "no", "dc" }

-- Short number with lowercase suffixes, "10.2m", "4.5qd" (owner 2026-10-27); past the last suffix "1.2e45", "inf" when infinite.
function HudFormat.Short(n)
	if type(n) ~= "number" or n ~= n or n < 0 then
		return "0"
	elseif n == math.huge then
		return "inf"
	elseif n < 1000 then
		return tostring(math.floor(n))
	end
	local tier = math.floor(math.log10(n) / 3)
	if tier > #SUFFIXES then
		return string.format("%.1fe%d", n / 10 ^ math.floor(math.log10(n)), math.floor(math.log10(n)))
	end
	local text = string.format("%.3g", n / 10 ^ (tier * 3))
	if tonumber(text) >= 1000 then -- 999.96k rounds to 1000k
		return tier < #SUFFIXES and "1" .. SUFFIXES[tier + 1] or string.format("1.0e%d", tier * 3 + 3)
	end
	return text .. SUFFIXES[tier]
end

-- "$999", "$1.2m" for the Money row (same suffixes as Speed). Anything that is not a real, finite, non-negative amount shows $0.
function HudFormat.MoneyText(money)
	if type(money) ~= "number" or money ~= money or money < 0 or money == math.huge then
		return "$0"
	end
	return "$" .. (money >= HudFormat.SUFFIX_FROM and HudFormat.Short(money) or commas(money))
end

-- Multiplier text, the one style for every screen (docs/HUD_LAYOUT_SPEC.md section 8): "x1.5", "x2", "x1.25".
function HudFormat.Multi(n)
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return "x1"
	elseif n >= 1000 then
		return "x" .. HudFormat.Short(n) -- "x1k", "x100b"
	end
	local text = string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
	return "x" .. text
end

-- Gacha odds, "1 in 1,000". Anything that is not a real chance shows "1 in ?".
-- `luck` (optional) is the roll's luck from the server: the odds shown are chance / luck, never below 1 in 1.
-- A missing or invalid luck counts as 1 (docs/WEATHER_EVENTS_SPEC.md, "Displayed odds").
function HudFormat.Odds(chance, luck)
	if type(chance) ~= "number" or chance ~= chance or chance < 1 or chance == math.huge then
		return "1 in ?"
	end
	if type(luck) == "number" and luck == luck and luck > 1 and luck ~= math.huge then
		chance = math.max(1, math.floor(chance / luck + 0.5))
	end
	return "1 in " .. (chance >= HudFormat.SUFFIX_FROM and HudFormat.Short(chance) or commas(chance)) -- "1 in 2.5qd"
end

-- The toggle button's label: it names what pressing it does.
function HudFormat.AutoButtonText(isRacing)
	return isRacing == true and "Stop Auto" or "Auto Race"
end

-- The cruise speed the stat currently gives, e.g. "42 studs/s". The optional multi is the equipped
-- car/aura cruise multi; it never changes the Speed stat or its gain rate.
function HudFormat.RateText(stat, speedMulti)
	return string.format("%d studs/s", math.floor(RaceConfig.SpeedFor(stat, speedMulti) + 0.5))
end

-- Moves the number on screen towards the real stat: smooth, never overshoots, never counts down while the
-- stat is rising. If the stat drops the number snaps to it.
function HudFormat.Approach(shown, target, dt)
	if type(target) ~= "number" or target ~= target then
		return (type(shown) == "number" and shown == shown) and shown or 0
	end
	if type(shown) ~= "number" or shown ~= shown then
		return target
	end
	if type(dt) ~= "number" or dt ~= dt or dt <= 0 then
		return shown
	end
	if target < shown then
		return target
	end
	local diff = target - shown
	if diff <= SNAP then
		return target
	end
	return math.min(target, shown + diff * (1 - math.exp(-SMOOTH_RATE * dt)))
end

return HudFormat
