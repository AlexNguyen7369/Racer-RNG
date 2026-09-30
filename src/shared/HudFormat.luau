--!nonstrict
-- Pure helpers for the Speed counter HUD (Client/SpeedHud), kept here so they can be tested.

local RaceConfig = require(script.Parent.RaceConfig)

local HudFormat = {}

local SMOOTH_RATE = 8 -- 1/s: how fast the shown number chases the real stat
local SNAP = 0.005

-- "1,234" (whole number, thousands separators, never scientific). Anything that is not a real stat shows 0.
function HudFormat.SpeedText(stat)
	if type(stat) ~= "number" or stat ~= stat or stat < 0 then
		return "0"
	end
	local text = string.format("%.0f", math.floor(math.min(stat, RaceConfig.MAX_STAT)))
	local replaced
	repeat
		text, replaced = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
	until replaced == 0
	return text
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
