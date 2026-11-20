--!nonstrict
-- Timed nitro boost while auto racing (proposed by Vic2CS, 2026-11-19; design doc "Timed nitro boost",
-- docs/NITRO_SPEC.md). A needle sweeps across a bar; pressing while it is in the green zone gives a boost, in the gold
-- centre a bigger one. The zones sit at a new random target on every bar. Pure maths shared by Server/NitroService (which decides) and Client/NitroInput (which draws).
-- Every number is a placeholder.

local NitroConfig = {}

NitroConfig.PERIOD = 1.6 -- seconds for the needle to sweep left -> right -> left once
NitroConfig.GOOD_ZONE = 0.3 -- needle within this of the centre (bar half-width = 1) is a Good press
NitroConfig.PERFECT_ZONE = 0.08 -- ...within this, Perfect
NitroConfig.GOOD_MULTI = 1.4 -- cruise speed x this while a Good boost lasts
NitroConfig.PERFECT_MULTI = 1.7
NitroConfig.DURATION = 2 -- seconds a boost lasts
NitroConfig.RECHARGE = 6 -- seconds after a boost ends before the bar is ready again
NitroConfig.MISS_COOLDOWN = 2 -- seconds the bar is locked after a press outside the green zone
NitroConfig.START_DELAY = 2 -- seconds after auto racing starts before the bar is first ready
NitroConfig.LATENCY_WINDOW = 0.35 -- s: the server accepts the client's press time this far in the past (ping)
-- The target (centre of the green and gold zones) is a new random spot for every bar (Vic2CS 2026-11-19): the server
-- picks it when auto racing starts and right after grading each press; the client shows it once that bar is ready. It stays far enough from the edges for the whole green zone to fit on the bar, and at least
-- TARGET_MIN_MOVE away from the previous target so every new bar looks different.
NitroConfig.TARGET_RANGE = 1 - NitroConfig.GOOD_ZONE
NitroConfig.TARGET_MIN_MOVE = 0.3

-- Needle position at server time `t` for a bar that became ready at `readyAt`: -1 (left edge) .. 1 (right edge).
-- It starts at the left edge and moves at a constant rate (a triangle wave).
function NitroConfig.NeedleAt(t, readyAt)
	local phase = ((t - readyAt) % NitroConfig.PERIOD) / NitroConfig.PERIOD
	return 1 - 4 * math.abs(phase - 0.5)
end

-- A new target in [-TARGET_RANGE, TARGET_RANGE], at least TARGET_MIN_MOVE from `previous` (when given).
-- `rng` is a Random (the server's); the result is always a valid target.
function NitroConfig.NewTarget(rng, previous)
	local range = NitroConfig.TARGET_RANGE
	local target = 0
	for _ = 1, 8 do
		target = rng:NextNumber(-range, range)
		if type(previous) ~= "number" or math.abs(target - previous) >= NitroConfig.TARGET_MIN_MOVE then
			return target
		end
	end
	-- Unlucky draws: jump the minimum distance away, toward the side with more room
	if type(previous) == "number" then
		target = previous >= 0 and previous - NitroConfig.TARGET_MIN_MOVE or previous + NitroConfig.TARGET_MIN_MOVE
	end
	return math.clamp(target, -range, range)
end

-- "Perfect", "Good" or "Miss" for a needle position, measured from `target` (the zones' centre; 0 when nil).
function NitroConfig.Grade(position, target)
	if type(target) ~= "number" or target ~= target then
		target = 0
	end
	local off = math.abs(position - target)
	if off <= NitroConfig.PERFECT_ZONE then
		return "Perfect"
	elseif off <= NitroConfig.GOOD_ZONE then
		return "Good"
	end
	return "Miss"
end

-- Cruise speed multiplier for a grade (1 for a miss).
function NitroConfig.MultiFor(grade)
	if grade == "Perfect" then
		return NitroConfig.PERFECT_MULTI
	elseif grade == "Good" then
		return NitroConfig.GOOD_MULTI
	end
	return 1
end

return NitroConfig
