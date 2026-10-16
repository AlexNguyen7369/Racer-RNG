--!nonstrict
-- Gamepass car pedestals (docs/GAMEPASS_CARS_SPEC.md section 5): left and right of the Best Roll Ever pedestal,
-- across the spawn's line of sight. Height and spin come from LeaderboardConfig.BEST_ROLL.
local PassCarConfig = {}

PassCarConfig.RADIUS = 6
PassCarConfig.CAR_SCALE = 1.5
PassCarConfig.TEXT_DISTANCE = 150 -- studs: MaxDistance of the name above the car
PassCarConfig.PROMPT_DISTANCE = 12 -- studs from the pedestal centre

-- Local (X, Z) of each pedestal centre in the spawn area
PassCarConfig.Pedestals = {
	{ CarId = "ember_wyvern", X = 162, Z = -48 },
	{ CarId = "singularity", X = 129, Z = -84 },
}

return PassCarConfig
