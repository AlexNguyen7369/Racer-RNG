--!nonstrict
-- Economy knobs for the auto race. The Speed stat (a continuous number that grows while the car drives)
-- sets the cruise speed, with diminishing returns that never flatten. Studs per second. The optional
-- car multiplier changes the player's base/cruise speed, while speed gain is
-- handled separately by RebirthConfig.

local RaceConfig = {}

RaceConfig.BASE_SPEED = 12 -- cruise speed at Speed stat 0 (owner 2026-10-20: much slower, was 30)
RaceConfig.MAX_SPEED = 22 -- (owner 2026-10-20: harsher, was 28, before that 75) reference cruise speed at HALF_STAT; higher stats continue increasing beyond it
RaceConfig.HALF_STAT = 5000 -- (owner 2026-10-20: was 1000) stat at which the cruise speed is halfway between BASE_SPEED and MAX_SPEED
RaceConfig.GAIN_PER_STUD = 0.01 -- (owner 2026-10-20: 5x slower, was 0.05) stat gained per stud travelled, at every stat
RaceConfig.MAX_STAT = 1e9 -- stability-test reference stat only, NOT a cap: the Speed stat has no cap (owner 2026-10-20)

local function cleanStat(stat)
	if type(stat) ~= "number" or stat ~= stat or stat < 0 or stat == math.huge then
		return nil
	end
	return stat
end

-- A Speed stat as saved and shown: any finite number >= 0 (no cap), rounded to 3 decimals; nil for anything else
-- (infinity can not be saved in a DataStore).
function RaceConfig.CleanStat(stat)
	stat = cleanStat(stat)
	if stat == nil or stat >= 1e12 then
		return stat -- above 1e12 a double has no 3 decimals left to round, and * 1000 could overflow
	end
	return math.floor(stat * 1000 + 0.5) / 1000
end

-- Cruise speed (studs/s) for a Speed stat and optional car multiplier. MAX_SPEED
-- is the midpoint reference, not a hard cap: higher stats keep adding speed with
-- diminishing returns so progression cannot get stuck at the car's old ceiling.
-- A multiplier above 1 is intentionally dampened with a power curve. The exponent is anchored so every
-- 1.1x multiplier produces exactly 1.01x cruise speed; large catalog values therefore stay useful without
-- turning into hundreds of times more speed. The displayed multiplier remains unchanged.
local MULTI_SPEED_EXPONENT = math.log(1.01) / math.log(1.1)
function RaceConfig.SpeedFor(stat, carSpeedMulti)
	stat = cleanStat(stat) or 0
	if type(carSpeedMulti) ~= "number" or carSpeedMulti ~= carSpeedMulti or carSpeedMulti <= 0 then
		carSpeedMulti = 1
	elseif carSpeedMulti > 1 then
		carSpeedMulti = carSpeedMulti ^ MULTI_SPEED_EXPONENT
	end
	local cruise = RaceConfig.BASE_SPEED
		+ (RaceConfig.MAX_SPEED - RaceConfig.BASE_SPEED)
			* math.log(1 + stat / RaceConfig.HALF_STAT)
			/ (2 * math.log(2))
	return cruise * carSpeedMulti
end

-- Stat gained per second while driving at an ACTUAL speed (studs/s): proportional to the speed only. The stat
-- never reduces it, so a higher stat (a faster car) gains faster (design doc "Core stat model", owner 2026-10-13).
-- Bad inputs gain nothing.
function RaceConfig.GainPerSecond(stat, speed)
	stat = cleanStat(stat)
	if not stat or type(speed) ~= "number" or speed ~= speed or speed < 0 or speed == math.huge then
		return 0
	end
	return RaceConfig.GAIN_PER_STUD * speed
end

return RaceConfig
