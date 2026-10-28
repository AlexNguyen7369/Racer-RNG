--!nonstrict
-- Ember Wyvern flight pose (docs/WYVERN_FLIGHT_SPEC.md section 3): pure maths, so the same time and state give the
-- same pose everywhere. Pose(t, state) returns { [boneName] = CFrame }: a rotation in MODEL space (x right, y up,
-- -z forward) about that bone's own joint; Root may also carry a model-space translation (the heave). The client
-- (Client/WyvernAnimator) turns each into the bone's Transform. Angles are radians. Numbers are placeholders.
local WyvernMotion = {}

WyvernMotion.FLAP_BEATS = 3
WyvernMotion.GLIDE_SECONDS = 1.2
WyvernMotion.FLAP_HZ_REST = 1.8
WyvernMotion.FLAP_HZ_CRUISE = 1.2
WyvernMotion.CRUISE_SPEED = 45 -- studs/s: at and above this the slower beat is used
WyvernMotion.FLAP_DOWN = math.rad(34) -- was 40: 40 + the 12 deg bank put the wing tip 9.31 studs out (MAX_HALF_SPAN 9)
WyvernMotion.FLAP_UP = math.rad(15)
WyvernMotion.FLUTTER = math.rad(3)
WyvernMotion.HEAVE = 0.3 -- studs at SkinScale 1 (placeholder; owner 2026-10-27 asked for a livelier body)
WyvernMotion.HEAD_TURN = 0.35 -- head yaw per rad/s of turn
WyvernMotion.HEAD_MAX = math.rad(25)
WyvernMotion.BANK = 0.25 -- body roll per rad/s of turn
WyvernMotion.BANK_MAX = math.rad(8) -- was 12 (same reason)
WyvernMotion.TAIL_MAX = math.rad(14)
WyvernMotion.BREATH_RAMP = 0.15 -- s: the breath swells in and dies away at the ends of each glide
WyvernMotion.MAX_HALF_SPAN = 9 -- studs sideways from the chassis centre (spec section 1, placeholder)
WyvernMotion.BONES = {
	"Root",
	"Spine1",
	"Spine2",
	"Neck1",
	"Neck2",
	"Neck3",
	"Neck4",
	"Head",
	"Jaw",
	"Tail1",
	"Tail2",
	"Tail3",
	"Tail4",
	"Tail5",
	"Tail6",
	"Thigh_L",
	"Shin_L",
	"Thigh_R",
	"Shin_R",
	"Arm_L",
	"Fore_L",
	"Hand_L",
	"Finger1_L",
	"Finger2_L",
	"Finger3_L",
	"Finger4_L",
	"Arm_R",
	"Fore_R",
	"Hand_R",
	"Finger1_R",
	"Finger2_R",
	"Finger3_R",
	"Finger4_R",
}

local TAU = math.pi * 2
local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local function clamp(v, lo, hi)
	return math.max(lo, math.min(hi, v))
end

-- Wing elevation over one beat (phase 0..1), 0 = the rest V: down and back to rest by 0.6, then up and back.
local function beat(phase, down, up)
	if phase < 0.6 then
		return -down * math.sin(math.pi * phase / 0.6)
	end
	return up * math.sin(math.pi * (phase - 0.6) / 0.4)
end

-- Elevation of the shoulder at time t, plus the beat phase (nil in the glide) for the lagged forearm and fingers.
local function flapHz(speed)
	local M = WyvernMotion
	return M.FLAP_HZ_REST + (M.FLAP_HZ_CRUISE - M.FLAP_HZ_REST) * clamp((speed or 0) / M.CRUISE_SPEED, 0, 1)
end

-- Seconds of one flap burst plus its glide at this speed.
function WyvernMotion.CycleSeconds(speed)
	return WyvernMotion.FLAP_BEATS / flapHz(speed) + WyvernMotion.GLIDE_SECONDS
end

-- Time into the current burst + glide. With `cycle` (the fraction of cycles done, integrated by the caller over
-- dt / CycleSeconds) a changing speed only changes how fast the phase runs; `t % period` alone jumps the phase
-- whenever the speed changes below CRUISE_SPEED, because t (os.clock) is large.
local function cycleTime(t, speed, cycle)
	local period = WyvernMotion.CycleSeconds(speed)
	if cycle then
		return (cycle % 1) * period, period
	end
	return t % period, period
end

function WyvernMotion.Wing(t, speed, reduced, cycle)
	local M = WyvernMotion
	if reduced then -- one slow flap every 2 s at half the amplitude
		local u = t % 2
		if u < 1 then
			return beat(u, M.FLAP_DOWN * 0.5, M.FLAP_UP * 0.5), u
		end
		return 0, nil
	end
	local beatT = 1 / flapHz(speed)
	local burst = M.FLAP_BEATS * beatT
	local u = cycleTime(t, speed, cycle)
	if u < burst then
		local phase = (u / beatT) % 1
		return beat(phase, M.FLAP_DOWN, M.FLAP_UP), phase
	end
	-- Glide: wings held spread, a slow flutter that starts and ends at rest.
	local g = (u - burst) / M.GLIDE_SECONDS
	return M.FLUTTER * math.sin(TAU * g) * math.sin(math.pi * g), nil
end

-- Breath strength 0..1 (docs/WYVERN_BREATH_SPEC.md section 1): 0 through every flap burst, 1 in the glide, ramped
-- over BREATH_RAMP at both ends. Reduced motion: the slow flap's rest second, at most 0.4.
function WyvernMotion.Breath(t, state)
	local M = WyvernMotion
	state = state or {}
	local u, start, length, peak
	if state.Reduced then
		u, start, length, peak = t % 2, 1, 1, 0.4
	else
		local burst = M.FLAP_BEATS / flapHz(state.Speed)
		u, start, length, peak = cycleTime(t, state.Speed, state.Cycle), burst, M.GLIDE_SECONDS, 1
	end
	local g = u - start
	if g < 0 then
		return 0
	end
	return peak * clamp(math.min(g, length - g) / M.BREATH_RAMP, 0, 1)
end

function WyvernMotion.Pose(t, state)
	local M = WyvernMotion
	state = state or {}
	local speed, turn, reduced = state.Speed or 0, state.Turn or 0, state.Reduced == true
	local pose = {}
	local e, phase = M.Wing(t, speed, reduced, state.Cycle)
	for side, s in { L = -1, R = 1 } do
		-- Shoulder about the body axis (+Z rotation lifts the right wing, so the left wing uses -s).
		pose["Arm_" .. side] = CFrame.fromAxisAngle(Z, s * e)
		local lag = phase and beat((phase - 0.08) % 1, M.FLAP_DOWN, M.FLAP_UP) or e
		local lag2 = phase and beat((phase - 0.16) % 1, M.FLAP_DOWN, M.FLAP_UP) or e
		pose["Fore_" .. side] = CFrame.fromAxisAngle(Z, s * lag * 0.45)
		pose["Hand_" .. side] = CFrame.fromAxisAngle(Z, s * lag2 * 0.25)
		-- Fingers fold back on the upstroke and spread on the downstroke.
		local fold = math.max(0, lag2) / M.FLAP_UP * math.rad(10)
		for k = 1, 4 do
			pose["Finger" .. k .. "_" .. side] = CFrame.fromAxisAngle(Y, -s * fold * (k / 4))
		end
	end
	-- Body (owner 2026-10-27: "make the dragon body also dynamically animated"): every part of it answers the wing
	-- beat, the speed and the curves. stroke = how far into the downstroke (0..1), lift = the upstroke (0..1).
	local stroke = math.max(0, -e) / M.FLAP_DOWN
	local lift = math.max(0, e) / M.FLAP_UP
	local fast = clamp(speed / M.CRUISE_SPEED, 0, 1) -- streamlines the pose at speed
	local sway = reduced and 0.4 or 1
	local bank = reduced and 0 or clamp(turn * M.BANK, -M.BANK_MAX, M.BANK_MAX)
	local curve = reduced and 0 or clamp(turn * 0.12, -math.rad(8), math.rad(8)) -- spine bends into the turn
	-- Torso: rises on the downstroke and sinks on the upstroke, rolls a little with each beat, banks into curves.
	local heave = (stroke - 0.35 * lift) * M.HEAVE
	local roll = math.rad(3) * sway * math.sin(TAU * 0.5 * t)
	pose.Root = CFrame.new(0, heave, 0) * CFrame.fromAxisAngle(Z, bank + roll)
	-- Chest pitches up as the wings drive down; the spine sways side to side and curves into the turn.
	local spineYaw = math.rad(4) * sway * math.sin(TAU * 0.45 * t)
	pose.Spine1 = CFrame.fromAxisAngle(Y, spineYaw + curve * 0.5)
		* CFrame.fromAxisAngle(X, math.rad(4) * (stroke - lift))
	pose.Spine2 = CFrame.fromAxisAngle(Y, spineYaw * 0.6 + curve * 0.5)
		* CFrame.fromAxisAngle(X, math.rad(7) * (stroke - 0.6 * lift))
		* CFrame.fromAxisAngle(Z, -bank * 0.3)
	-- Neck: a travelling S that lags the chest, dipping against each downstroke and stretching out at speed; the
	-- head counters the pitch so it stays level, and turns into curves.
	local neckPitch = 0
	for k = 1, 4 do
		local pitch = math.rad(6) * sway * math.sin(TAU * 0.55 * t - k * 0.8)
			- math.rad(5) * stroke * (k <= 2 and 1 or -0.5)
			- math.rad(3) * fast
		neckPitch += pitch
		pose["Neck" .. k] = CFrame.fromAxisAngle(
			Y,
			math.rad(7) * sway * math.sin(TAU * 0.4 * t - k * 0.7) + curve * 0.4
		) * CFrame.fromAxisAngle(X, pitch)
	end
	local yaw = reduced and 0 or clamp(turn * M.HEAD_TURN, -M.HEAD_MAX, M.HEAD_MAX)
	pose.Head = CFrame.fromAxisAngle(Y, yaw) * CFrame.fromAxisAngle(X, -neckPitch * 0.8)
	-- Jaw: opens with the fire breath, and snaps open now and then (every 4 s), wider at speed.
	local snap = math.rad(10 + 6 * fast) * math.max(0, math.sin(TAU * t / 4)) ^ 6
	pose.Jaw = CFrame.fromAxisAngle(X, -math.max(snap, math.rad(18) * M.Breath(t, state)))
	-- Tail: a strong travelling wave down its whole length, lifting on each downstroke, swinging out of curves.
	-- Each bone stays within TAIL_MAX (yaw and pitch together).
	local tailPitchMax = math.rad(3)
	local tailYawMax = math.sqrt(M.TAIL_MAX ^ 2 - tailPitchMax ^ 2)
	for k = 1, 6 do
		local amp = tailYawMax * (0.45 + 0.55 * k / 6) * sway
		local swing = amp * math.sin(TAU * 0.8 * t - k * 0.75)
			- clamp(turn * 0.05 * k, -amp, amp) * (reduced and 0 or 1)
		local pitch = tailPitchMax * clamp(0.6 * math.sin(TAU * 0.8 * t - k * 0.5) + 0.6 * stroke - 0.3 * lift, -1, 1)
		pose["Tail" .. k] = CFrame.fromAxisAngle(Y, clamp(swing, -tailYawMax, tailYawMax))
			* CFrame.fromAxisAngle(X, pitch)
	end
	-- Legs: kick back on each downstroke and tuck tighter at speed.
	for _, side in { "L", "R" } do
		pose["Thigh_" .. side] = CFrame.fromAxisAngle(
			X,
			math.rad(12) * stroke * sway - math.rad(6) * fast + math.rad(4) * math.sin(TAU * 0.4 * t)
		)
		pose["Shin_" .. side] =
			CFrame.fromAxisAngle(X, math.rad(10) * stroke * sway + math.rad(4) * math.sin(TAU * 0.4 * t - 0.8))
	end
	return pose
end

return WyvernMotion
