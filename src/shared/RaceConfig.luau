--!nonstrict
-- Economy knobs for the auto race. The Speed stat (a continuous number that grows while the car drives)
-- sets the cruise speed, with diminishing returns. Studs per second. Keep MAX_SPEED under
-- CarConfig.TopSpeed so the car can always hold it.

local RaceConfig = {}

RaceConfig.BASE_SPEED = 30 -- cruise speed at Speed stat 0
RaceConfig.MAX_SPEED = 75 -- asymptote: the stat can push the speed towards this, never past it
RaceConfig.HALF_STAT = 1000 -- stat at which the cruise speed is halfway between BASE_SPEED and MAX_SPEED
RaceConfig.GAIN_PER_STUD = 0.05 -- stat gained per stud travelled when the stat is 0
RaceConfig.GAIN_SOFT = 2000 -- gain is divided by (1 + stat / GAIN_SOFT): the higher the stat, the slower it grows
RaceConfig.MAX_STAT = 1e9

local function cleanStat(stat)
	if type(stat) ~= "number" or stat ~= stat or stat < 0 then
		return nil
	end
	return math.min(stat, RaceConfig.MAX_STAT)
end

-- Cruise speed (studs/s) for a Speed stat. Always in [BASE_SPEED, MAX_SPEED).
function RaceConfig.SpeedFor(stat)
	stat = cleanStat(stat) or 0
	return RaceConfig.BASE_SPEED + (RaceConfig.MAX_SPEED - RaceConfig.BASE_SPEED) * stat / (stat + RaceConfig.HALF_STAT)
end

-- Stat gained per second while driving at an ACTUAL speed (studs/s): proportional to the speed, shrinking as
-- the stat grows. Bad inputs gain nothing.
function RaceConfig.GainPerSecond(stat, speed)
	stat = cleanStat(stat)
	if not stat or type(speed) ~= "number" or speed ~= speed or speed < 0 or speed == math.huge then
		return 0
	end
	return RaceConfig.GAIN_PER_STUD * speed / (1 + stat / RaceConfig.GAIN_SOFT)
end

return RaceConfig
