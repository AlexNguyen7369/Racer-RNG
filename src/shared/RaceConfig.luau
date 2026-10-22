--!nonstrict
-- Economy knobs for the auto race. The Speed stat (a continuous number that grows while the car drives)
-- sets the cruise speed, with diminishing returns that never flatten. Studs per second. The optional
-- car multiplier changes the player's base/cruise speed, while speed gain is
-- handled separately by RebirthConfig.

local RaceConfig = {}

RaceConfig.BASE_SPEED = 10 -- cruise speed at Speed stat 0 (owner 2026-10-21: lowered from 12)
RaceConfig.MAX_SPEED = 80 -- cruise reference at the point where post-100K diminishing returns begin
RaceConfig.HALF_STAT = 100000 -- owner 2026-10-22: first 100K Speed is easier; diminishing returns begin after this threshold
RaceConfig.MAX_CRUISE_CAR_MULTI = 1.5 -- high car/market multipliers cannot exceed this effective cruise contribution
RaceConfig.GAIN_PER_SECOND = 2 -- (owner 2026-10-22, placeholder) friendlier early Speed progression
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

-- High car/market multipliers are damped before entering the cruise curve. This preserves meaningful car
-- differences without letting a rare car multiply movement speed hundreds of times.
function RaceConfig.CruiseStatMulti(speedMulti)
	if type(speedMulti) ~= "number" or speedMulti ~= speedMulti or speedMulti <= 0 or speedMulti == math.huge then
		return 1
	end
	return math.clamp(1 + math.log10(speedMulti), 0.1, RaceConfig.MAX_CRUISE_CAR_MULTI)
end

-- Cruise speed (studs/s) for a Speed stat and optional car/market multi. The first HALF_STAT points are linear
-- and generous; only the effective Speed above that threshold enters the logarithmic diminishing-return tail.
function RaceConfig.SpeedFor(stat, speedMulti)
	stat = cleanStat(stat) or 0
	speedMulti = RaceConfig.CruiseStatMulti(speedMulti)
	local effective = math.min(stat * speedMulti, 1e308)
	local range = RaceConfig.MAX_SPEED - RaceConfig.BASE_SPEED
	if effective <= RaceConfig.HALF_STAT then
		return RaceConfig.BASE_SPEED + range * effective / RaceConfig.HALF_STAT
	end
	local tail = effective - RaceConfig.HALF_STAT
	-- each doubling above HALF_STAT adds half the range (owner 2026-10-22: 196 studs/s at 1M)
	return RaceConfig.MAX_SPEED + range / 2 * math.log(1 + tail / RaceConfig.HALF_STAT) / math.log(2)
end

-- Inverse of SpeedFor: the shown Speed at which the cruise speed reaches `speed` (studs/s). 0 at or
-- below BASE_SPEED; math.huge when the answer is past what a double can hold. Gate signs show it (owner 2026-10-21).
function RaceConfig.StatFor(speed)
	if type(speed) ~= "number" or speed ~= speed or speed <= RaceConfig.BASE_SPEED then
		return 0
	end
	local range = RaceConfig.MAX_SPEED - RaceConfig.BASE_SPEED
	if speed <= RaceConfig.MAX_SPEED then
		return RaceConfig.HALF_STAT * (speed - RaceConfig.BASE_SPEED) / range
	end
	local doublings = (speed - RaceConfig.MAX_SPEED) / (range / 2)
	return RaceConfig.HALF_STAT * (2 ^ doublings)
end

-- Base Speed gained per second while the car drives (speed > 0): a flat GAIN_PER_SECOND, independent of the stat
-- and of how fast the car goes (design doc "Core stat model", owner 2026-10-21). Bad inputs gain nothing.
function RaceConfig.GainPerSecond(stat, speed)
	stat = cleanStat(stat)
	if not stat or type(speed) ~= "number" or speed ~= speed or speed <= 0 or speed == math.huge then
		return 0
	end
	return RaceConfig.GAIN_PER_SECOND
end

return RaceConfig
