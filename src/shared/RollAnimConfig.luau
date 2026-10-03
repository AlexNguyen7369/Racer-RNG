--!nonstrict
-- Timings and sizes of the roll animation (docs/ROLL_ANIMATION_CONTRACT.md). Pure, so the client (Client/RollToast),
-- the server (GachaService pauses auto-roll while a long animation plays) and the tests share them.

local GachaConfig = require(script.Parent.GachaConfig)

local RollAnimConfig = {}

-- One roll: pop in -> spin -> land -> hold -> exit (seconds)
RollAnimConfig.POP = 0.15
RollAnimConfig.SPIN = 0.8
RollAnimConfig.LAND = 0.15
RollAnimConfig.EXIT = 0.15
RollAnimConfig.SWITCH = 0.3 -- compact <-> enlarged view

RollAnimConfig.HOLD = {
	Common = 0.3,
	Uncommon = 0.3,
	Rare = 0.4,
	Epic = 0.6,
	Legendary = 1.5,
	Mythic = 2.5,
	Secret = 4,
}

RollAnimConfig.REEL_CARS = 6 -- cars that drive through the reel; the last one is the result
RollAnimConfig.LAND_POP = 1.15 -- the card pops to this size on landing, then settles to 1x

-- Compact roll (no card: the bare car and its "1 in N"): top centre, under the Auto Race button
RollAnimConfig.COMPACT_WIDTH = 0.12 -- of the screen width (owner, 2026-10-02)
RollAnimConfig.COMPACT_MIN = 100 -- px
RollAnimConfig.COMPACT_MAX = 230 -- px
RollAnimConfig.COMPACT_HEIGHT = 66 -- px: the car ~70%, "1 in N" ~30%
RollAnimConfig.COMPACT_GAP = 8 -- px from the Auto Race button's bottom edge to the roll
RollAnimConfig.PANEL_TOP = 12 + 48 + RollAnimConfig.COMPACT_GAP + RollAnimConfig.COMPACT_HEIGHT + 4 -- Index panel top
-- Enlarged card: centred, about 3x the old compact card
RollAnimConfig.ENLARGED_FACTOR = 3
RollAnimConfig.ENLARGED_WIDTH = 0.6 -- of the screen width
RollAnimConfig.ENLARGED_MAX = Vector2.new(780, 336) -- px

function RollAnimConfig.Hold(rarity)
	return RollAnimConfig.HOLD[rarity] or RollAnimConfig.HOLD.Common
end

-- Seconds one roll's animation takes; an emphasized roll also opens and closes the enlarged view.
function RollAnimConfig.Duration(rarity, emphasized)
	local t = RollAnimConfig.POP
		+ RollAnimConfig.SPIN
		+ RollAnimConfig.LAND
		+ RollAnimConfig.Hold(rarity)
		+ RollAnimConfig.EXIT
	if emphasized then
		t += 2 * RollAnimConfig.SWITCH
	end
	return t
end

-- How much longer than GachaConfig.ROLL_INTERVAL the server waits before the next roll, so it never covers one
-- still playing.
function RollAnimConfig.ExtraPause(rarity, emphasized)
	return math.max(0, RollAnimConfig.Duration(rarity, emphasized) - GachaConfig.ROLL_INTERVAL)
end

-- The cars that drive through the reel, in order; the last is the result. The others are real rolls at luck 1, so
-- the reel shows the true odds and never plants a rare car as a fake near-miss.
function RollAnimConfig.Reel(rng, resultId)
	local reel = {}
	for i = 1, RollAnimConfig.REEL_CARS - 1 do
		reel[i] = GachaConfig.Roll(rng, 1)
	end
	reel[RollAnimConfig.REEL_CARS] = resultId
	return reel
end

return RollAnimConfig
