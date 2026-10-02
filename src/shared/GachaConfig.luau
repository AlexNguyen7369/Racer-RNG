--!nonstrict
-- Gacha, index and stat-point rules (placeholder numbers from the design doc). Pure functions, so the
-- server and the tests share them. The server decides every roll; clients only display.

local CarCatalog = require(script.Parent.CarCatalog)

local GachaConfig = {}

GachaConfig.ROLL_INTERVAL = 3 -- seconds between free auto-rolls
GachaConfig.DISCOVERIES_PER_POINT = 3 -- every 3 unique cars in the index grant 1 stat point

-- Turbo luck: every TURBO_EVERY-th roll (Rolls = 10, 20, ...) rolls with TURBO_LUCK times the player's luck.
-- Derived from the saved roll count, so nothing extra is saved.
GachaConfig.TURBO_EVERY = 10
GachaConfig.TURBO_LUCK = 5

GachaConfig.STATS = { "Speed", "Money", "Luck", "Workshop" }
GachaConfig.PER_POINT = { -- each point adds this to its multi (additive, easier to tune)
	Speed = 0.1, -- all Speed gain
	Money = 0.1, -- race payouts
	Luck = 0.05, -- car roll odds
	Workshop = 0.2, -- workshop gain (no workshop yet)
}

GachaConfig.RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
GachaConfig.RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(90, 200, 90),
	Rare = Color3.fromRGB(70, 140, 255),
	Epic = Color3.fromRGB(170, 80, 230),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 70, 110),
	Secret = Color3.fromRGB(20, 20, 20),
}

local function count(n)
	if type(n) ~= "number" or n ~= n or n < 0 or n == math.huge then
		return 0
	end
	return math.floor(n)
end

-- One roll: checks cars rarest first, each hits with min(1, luck / N), the first hit wins, else the catch-all.
function GachaConfig.Roll(rng, luck)
	if type(luck) ~= "number" or luck ~= luck or luck < 1 then
		luck = 1
	end
	local catchAll = nil
	for _, spec in CarCatalog.Rollable() do
		if spec.Chance == nil then
			catchAll = spec
		elseif rng:NextNumber() < math.min(1, luck / spec.Chance) then
			return spec.Id
		end
	end
	return catchAll.Id
end

-- True if roll number `rollNumber` (1 = the first roll ever) is a turbo roll.
function GachaConfig.IsTurbo(rollNumber)
	return count(rollNumber) > 0 and count(rollNumber) % GachaConfig.TURBO_EVERY == 0
end

-- Rolls done towards the next turbo roll, 0 .. TURBO_EVERY - 1 (the bar's fill).
function GachaConfig.TurboProgress(rolls)
	return count(rolls) % GachaConfig.TURBO_EVERY
end

-- Stat points earned from the index: floor(unique / DISCOVERIES_PER_POINT).
function GachaConfig.EarnedPoints(uniqueCount)
	return math.floor(count(uniqueCount) / GachaConfig.DISCOVERIES_PER_POINT)
end

-- Multis from allocated points: { Speed, Money, Luck, Workshop }, each 1 + points * PER_POINT.
function GachaConfig.Multis(alloc)
	alloc = type(alloc) == "table" and alloc or {}
	local multis = {}
	for _, stat in GachaConfig.STATS do
		multis[stat] = 1 + count(alloc[stat]) * GachaConfig.PER_POINT[stat]
	end
	return multis
end

return GachaConfig
