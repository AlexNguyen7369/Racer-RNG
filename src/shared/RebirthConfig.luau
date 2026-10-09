--!nonstrict
-- Rebirth progression knobs. Rebirth itself is not enabled yet, but keeping the
-- formula here lets racing use the same server-owned level once it is added.

local RebirthConfig = {}

RebirthConfig.DEFAULT_LEVEL = 0
RebirthConfig.MAX_LEVEL = 100
RebirthConfig.GAIN_PER_LEVEL = 0.10 -- +10% passive racing Speed gain per rebirth

function RebirthConfig.CleanLevel(level)
	if type(level) ~= "number" or level ~= level then
		return RebirthConfig.DEFAULT_LEVEL
	end
	return math.floor(math.clamp(level, RebirthConfig.DEFAULT_LEVEL, RebirthConfig.MAX_LEVEL))
end

function RebirthConfig.SpeedGainMulti(level)
	level = RebirthConfig.CleanLevel(level)
	return 1 + level * RebirthConfig.GAIN_PER_LEVEL
end

return RebirthConfig
