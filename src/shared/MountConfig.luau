--!nonstrict
-- Numbers for riding the equipped car on foot (docs/MOUNT_SPEC.md). All placeholders.

local MountConfig = {}

MountConfig.TAG = "MountedCar"
MountConfig.TOGGLE_COOLDOWN = 0.4 -- seconds between ride toggles from one player
MountConfig.PAD_CHECK = 0.2 -- seconds between checks for a rider on the race pad
MountConfig.SPEED_SCALE = 0.5 -- extra speed per power of ten of the car's SpeedMulti
MountConfig.MAX_MULTI = 3
MountConfig.MAX_SPEED = 100 -- studs/s, after Walkspeed upgrades and sprint
MountConfig.MAX_SEAT_HEIGHT = 6 -- studs: how high a tall ride can lift the avatar

-- Car SpeedMulti runs from about 1 to the thousands, so ride speed follows its logarithm.
function MountConfig.SpeedMulti(carSpeedMulti)
	local multi = math.max(carSpeedMulti or 1, 1)
	return math.min(1 + MountConfig.SPEED_SCALE * math.log10(multi), MountConfig.MAX_MULTI)
end

return MountConfig
