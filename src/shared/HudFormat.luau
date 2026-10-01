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

-- "1,234" (whole number, thousands separators, never scientific). Anything that is not a real stat shows 0.
function HudFormat.SpeedText(stat)
	if type(stat) ~= "number" or stat ~= stat or stat < 0 then
		return "0"
	end
	return commas(math.min(stat, RaceConfig.MAX_STAT))
end

-- "$1,234" for the Money row. Anything that is not a real, finite, non-negative amount shows $0.
function HudFormat.MoneyText(money)
	if type(money) ~= "number" or money ~= money or money < 0 or money == math.huge then
		return "$0"
	end
	return "$" .. commas(money)
end

-- Gacha odds, "1 in 1,000". Anything that is not a real chance shows "1 in ?".
function HudFormat.Odds(chance)
	if type(chance) ~= "number" or chance ~= chance or chance < 1 or chance == math.huge then
		return "1 in ?"
	end
	return "1 in " .. commas(chance)
end

-- The toggle button's label: it names what pressing it does.
function HudFormat.AutoButtonText(isRacing)
	return isRacing == true and "Stop Auto" or "Auto Race"
end

-- The cruise speed the stat currently gives, e.g. "42 studs/s".
function HudFormat.RateText(stat)
	return string.format("%d studs/s", math.floor(RaceConfig.SpeedFor(stat) + 0.5))
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
