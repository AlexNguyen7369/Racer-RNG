--!nonstrict
-- Upgrade tree numbers (docs/UPGRADE_TREE_SPEC.md, confirmed by the owner 2026-10-02; how it is built:
-- docs/UPGRADE_TREE_DESIGN.md). Data only: the rules that read it live in Shared/UpgradeTree.
-- Tile ids ("<branch>_<tier>", e.g. "luck_3") are permanent save keys: never rename or reuse one.

local UpgradeConfig = {}

UpgradeConfig.START_ID = "start" -- owned by everyone, never saved

-- price = NiceRound(BASE_PRICE * PRICE_GROWTH ^ (PriceDepth - 1) * Weight), NiceRound = 2 significant figures, halves up
UpgradeConfig.BASE_PRICE = 150
UpgradeConfig.PRICE_GROWTH = 2.2

-- Tiers at or above GATE_FROM_TIER need BestTrack >= min(tier - 1, number of tracks in the game).
UpgradeConfig.GATE_FROM_TIER = 3

UpgradeConfig.BASE_ROLL_INTERVAL = 3 -- seconds (GachaConfig.ROLL_INTERVAL today)
UpgradeConfig.MIN_ROLL_INTERVAL = 2 -- the fastest roll speed ever: interval = BASE / (1 + bonus), never below this

UpgradeConfig.BASE_WALKSPEED = 16
UpgradeConfig.BASE_TURBO = { Multi = 5, Every = 10 } -- no Turbo tier owned

-- Hex grid: axial (q, r), Start at (0, 0). A branch's tier I sits at Origin + Direction, tier n at
-- Origin + n * Direction. `Parent` is the tile tier I needs (Start, or a fork off another branch).
-- `Bonus` per tier is ADDED (0.10 = +10 %); Walkspeed and Turbo use their own tables instead.
UpgradeConfig.Branches = {
	{
		Id = "money",
		Name = "Money",
		Effect = "Money", -- added to the Money multi (track winnings)
		Weight = 1,
		Parent = "start",
		Origin = { 0, 0 },
		Direction = { -1, 0 },
		Bonus = { 0.10, 0.10, 0.15, 0.15, 0.20 },
	},
	{
		Id = "luck",
		Name = "Luck",
		Effect = "Luck", -- added to the Luck multi (every roll)
		Weight = 1.2,
		Parent = "start",
		Origin = { 0, 0 },
		Direction = { 0, -1 },
		Bonus = { 0.10, 0.15, 0.20, 0.25, 0.30 },
	},
	{
		Id = "rollspeed",
		Name = "Roll Speed",
		Effect = "RollSpeed", -- interval = BASE_ROLL_INTERVAL / (1 + total bonus)
		Weight = 1.5,
		Parent = "start",
		Origin = { 0, 0 },
		Direction = { 1, -1 },
		Bonus = { 0.10, 0.10, 0.10, 0.10, 0.10 },
	},
	{
		Id = "turbo",
		Name = "Turbo",
		Effect = "Turbo", -- sets the turbo roll's luck multi and how many rolls it takes
		Weight = 2,
		Parent = "rollspeed_1", -- forks off Roll Speed I, so Turbo I is depth 2 (spec: never the first purchase)
		Origin = { 1, -1 },
		Direction = { 1, 0 },
		PriceDepth = { 2, 4, 6, 7 }, -- spec price table: Turbo III at depth 6, IV at depth 7
		Tiers = {
			{ Multi = 10, Every = 15 },
			{ Multi = 50, Every = 25 },
			{ Multi = 100, Every = 40 },
			{ Multi = 1000, Every = 100 },
		},
	},
	{
		Id = "speed",
		Name = "Speed",
		Effect = "Speed", -- added to the Speed-stat GAIN multi; never cruise speed or car physics
		Weight = 1,
		Parent = "start",
		Origin = { 0, 0 },
		Direction = { 0, 1 },
		Bonus = { 0.10, 0.10, 0.15, 0.15, 0.20 },
	},
	{
		Id = "walkspeed",
		Name = "Walkspeed",
		Effect = "WalkSpeed", -- on-foot Humanoid.WalkSpeed (absolute values per tier)
		Weight = 0.5,
		Parent = "start",
		Origin = { 0, 0 },
		Direction = { -1, 1 },
		WalkSpeed = { 18, 20, 23, 26, 30 },
	},
	-- Direction { 1, 0 } from Start is free for a future branch.
}

return UpgradeConfig
