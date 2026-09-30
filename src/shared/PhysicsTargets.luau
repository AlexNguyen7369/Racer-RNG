--!nonstrict
-- Pass/fail limits used by the server-side CarTest harness.
-- The physics-tuner changes CarConfig to meet these; only change a target on purpose
-- (it is a game-feel decision, not a bug fix).

return {
	static_settle = {
		MaxSettleSpeed = 0.5, -- studs/s after 3 s
		MinCompression = 0.15, -- fraction of suspension travel, every wheel
		MaxCompression = 0.65,
		MaxTiltDeg = 3,
	},
	accel = {
		MaxTimeTo40 = 2.5, -- seconds from standstill to 40 studs/s
		MinTopSpeedFrac = 0.85, -- of CarConfig.TopSpeed within 12 s
		MaxDrift = 3, -- studs sideways while accelerating straight
	},
	brake = {
		FromSpeed = 60,
		MaxStopDistance = 45, -- studs
		MaxDrift = 3,
	},
	skidpad = {
		Speed = 40,
		MaxRadius = 70, -- studs, at full steer
		MinUpY = 0.85, -- chassis must stay upright (1 = level)
	},
	lap = {
		MaxOffTrackSeconds = 3,
		MaxFlips = 0,
		MinUpY = 0.3,
		MinUpYStrict = 0.9, -- user: the car must not flip or tilt by any means (hills are ~16 deg = 0.96)
	},
	race = {
		MaxPathDeviation = 5, -- studs from the route, start (after 3 s) to the last checkpoint
		MinUpY = 0.9,
		MaxFlips = 0,
		FlipRecoverySeconds = 3, -- a flipped car must be back on its wheels on the path within this
	},
}
