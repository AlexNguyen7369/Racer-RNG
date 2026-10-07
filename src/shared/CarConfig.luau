--!nonstrict
-- Single source of truth for the starter car. Distances are studs, times are seconds.
-- Roblox forward is -Z, so "front" wheels have negative Z mounts.
-- Body dimensions come from the Blender model (Blender units * SCALE).

local SCALE = 1.5

local WHEEL_RADIUS = 0.75
local WHEEL_WIDTH = 0.6
local SUSPENSION_REST = 0.8 -- mount -> wheel centre at full droop
local STATIC_COMPRESSION = 0.45 -- fraction of travel used when parked
local MOUNT_Y = -0.1 -- mount height relative to chassis centre
local HALF_TRACK = 1.65
local HALF_WHEELBASE = 2.1

local function wheel(name, x, z, front)
	return {
		Name = name,
		Mount = Vector3.new(x, MOUNT_Y, z),
		Front = front,
		Drive = true, -- all-wheel drive: forgiving for beginners
	}
end

local Config = {
	Name = "StarterCar",
	Scale = SCALE,
	BlenderBodyCenterZ = 0.75,

	-- Chassis / mass
	BodySize = Vector3.new(2 * SCALE, 0.7 * SCALE, 4.4 * SCALE),
	Density = 6,

	-- Wheels + suspension
	WheelRadius = WHEEL_RADIUS,
	WheelWidth = WHEEL_WIDTH,
	SuspensionRest = SUSPENSION_REST,
	StaticCompression = STATIC_COMPRESSION,
	MountY = MOUNT_Y,
	DampingRatio = 2.0,
	Wheels = {
		wheel("FL", -HALF_TRACK, -HALF_WHEELBASE, true),
		wheel("FR", HALF_TRACK, -HALF_WHEELBASE, true),
		wheel("RL", -HALF_TRACK, HALF_WHEELBASE, false),
		wheel("RR", HALF_TRACK, HALF_WHEELBASE, false),
	},
	Wheelbase = HALF_WHEELBASE * 2,

	-- Engine / brakes (accelerations are studs/s^2 at the chassis)
	EngineAccel = 100,
	TopSpeed = 90,
	ReverseTopSpeed = 30,
	BrakeAccel = 120,
	AeroDrag = 0.0004, -- accel = AeroDrag * speed^2
	RollingDrag = 1.0, -- 1/s, only with no throttle and no brake (parked / manual coast); kills creep after landing

	-- Steering
	MaxSteer = math.rad(30),
	SteerFalloffSpeed = 60, -- speed at which steering authority halves-ish
	MinSteerFactor = 0.25,
	SteerRate = 8, -- 1/s smoothing

	-- Tyres
	Mu = 1.2, -- peak friction coefficient
	LateralResponse = 18, -- 1/s, how hard tyres cancel sideways slip
	HandbrakeRearMu = 0.5,
	LateralApplyBlend = 0.8, -- 0 = at contact patch, 1 = at centre-of-mass height (anti-roll)
	LongitudinalApplyBlend = 0.6,
	AirAngularDamping = 1.5,

	-- Derived, used by the factory and the test harness
	RestHeight = WHEEL_RADIUS + SUSPENSION_REST * (1 - STATIC_COMPRESSION) - MOUNT_Y,

	Colors = {
		Body = Color3.fromRGB(137, 207, 240), -- baby blue
		Hood = Color3.fromRGB(179, 230, 250),
		Glass = Color3.fromRGB(41, 107, 217),
		Trim = Color3.fromRGB(66, 87, 128),
		Tire = Color3.fromRGB(41, 43, 56),
		Hub = Color3.fromRGB(242, 245, 252),
		Lamp = Color3.fromRGB(255, 247, 199),
		Tail = Color3.fromRGB(255, 140, 158),
	},
}

return Config
