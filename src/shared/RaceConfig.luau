--!nonstrict
-- Economy knobs for the auto race. The Speed stat (a continuous number that grows while the car drives)
-- sets the cruise speed, with diminishing returns that never flatten. Studs per second. The optional
-- car multiplier changes the player's base/cruise speed, while speed gain is
-- handled separately by RebirthConfig.

local RaceConfig = {}

RaceConfig.BASE_SPEED = 12 -- cruise speed at Speed stat 0 (owner 2026-10-20: much slower, was 30)
RaceConfig.MAX_SPEED = 22 -- owner 2026-10-21: buffed from 18 (+5 studs/s per Speed doubling); reference speed at HALF_STAT, higher stats continue increasing beyond it
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

-- Cruise speed (studs/s) for a Speed stat and optional Speed multi. The curve runs on the shown Speed
-- (stat x multi, the full multi with no damping; owner 2026-10-21), so the same shown Speed always gives the same
-- cruise speed. MAX_SPEED is the midpoint reference, not a hard cap: diminishing returns, never flat.
function RaceConfig.SpeedFor(stat, speedMulti)
	stat = cleanStat(stat) or 0
	if type(speedMulti) ~= "number" or speedMulti ~= speedMulti or speedMulti <= 0 or speedMulti == math.huge then
		speedMulti = 1
	end
	return RaceConfig.BASE_SPEED
		+ (RaceConfig.MAX_SPEED - RaceConfig.BASE_SPEED)
			* math.log(1 + math.min(stat * speedMulti, 1e308) / RaceConfig.HALF_STAT)
			/ (2 * math.log(2))
end

-- Inverse of SpeedFor: the shown Speed at which the cruise speed reaches `speed` (studs/s). 0 at or
-- below BASE_SPEED; math.huge when the answer is past what a double can hold. Gate signs show it (owner 2026-10-21).
function RaceConfig.StatFor(speed)
	if type(speed) ~= "number" or speed ~= speed or speed <= RaceConfig.BASE_SPEED then
		return 0
	end
	local doublings = 2 * (speed - RaceConfig.BASE_SPEED) / (RaceConfig.MAX_SPEED - RaceConfig.BASE_SPEED)
	return RaceConfig.HALF_STAT * (2 ^ doublings - 1)
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
