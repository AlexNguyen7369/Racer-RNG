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

-- Duplicate rolls become direct Money rewards. Rarer cars are worth more.
GachaConfig.SCRAP_MONEY = {
	Common = 100,
	Uncommon = 250,
	Rare = 750,
	Epic = 2500,
	Legendary = 10000,
	Mythic = 50000,
	Secret = 250000,
}

function GachaConfig.ScrapMoney(spec)
	return math.max(0, math.floor(GachaConfig.SCRAP_MONEY[spec and spec.Rarity] or 0))
end

local function count(n)
	if type(n) ~= "number" or n ~= n or n < 0 or n == math.huge then
		return 0
	end
	return math.floor(n)
end

-- One roll: checks cars rarest first, each hits with min(1, luck / N), the first hit wins, else the catch-all.
function GachaConfig.Roll(rng, luck, event)
	if type(luck) ~= "number" or luck ~= luck or luck < 1 then
		luck = 1
	end
	local catchAll = nil
	for _, spec in CarCatalog.Rollable() do
		if spec.Event and spec.Event ~= event then
			continue
		elseif spec.Chance == nil then
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

-- An emphasized roll plays in the enlarged view and is announced to the server (owner, 2026-10-02): the car is
-- undiscovered (not in `ownedIds`, the player's cars before this roll) and rarer than the player's 5th-rarest
-- discovered car; with fewer than 5 discovered, any undiscovered car. Rarer = larger Chance (the catch-all has none).
-- Rarity names never matter.
GachaConfig.EMPHASIS_RANK = 5

function GachaConfig.IsEmphasized(id, ownedIds)
	local spec = CarCatalog.Get(id)
	if not spec or not spec.Rollable then
		return false
	end
	local chances = {}
	local seen = {}
	for _, owned in (type(ownedIds) == "table" and ownedIds or {}) do
		if owned == id then
			return false
		end
		local ownedSpec = CarCatalog.Get(owned)
		if ownedSpec and ownedSpec.Rollable and not seen[owned] then
			seen[owned] = true
			table.insert(chances, ownedSpec.Chance or 0)
		end
	end
	if #chances < GachaConfig.EMPHASIS_RANK then
		return true
	end
	table.sort(chances, function(a, b)
		return a > b
	end)
	return (spec.Chance or 0) > chances[GachaConfig.EMPHASIS_RANK]
end

-- Stat points earned from the index: floor(unique / DISCOVERIES_PER_POINT).
function GachaConfig.EarnedPoints(uniqueCount)
	return math.floor(count(uniqueCount) / GachaConfig.DISCOVERIES_PER_POINT)
end

-- Multis from allocated points: { Speed, Money, Luck, Workshop }, each 1 + points * PER_POINT. `bonuses` (optional,
-- the upgrade tree's UpgradeTree.Bonuses) is ADDED on top: 1 + points * PER_POINT + bonuses[stat].
function GachaConfig.Multis(alloc, bonuses)
	alloc = type(alloc) == "table" and alloc or {}
	bonuses = type(bonuses) == "table" and bonuses or {}
	local multis = {}
	for _, stat in GachaConfig.STATS do
		local extra = bonuses[stat]
		if type(extra) ~= "number" or extra ~= extra or extra < 0 or extra == math.huge then
			extra = 0
		end
		multis[stat] = 1 + count(alloc[stat]) * GachaConfig.PER_POINT[stat] + extra
	end
	return multis
end

return GachaConfig
