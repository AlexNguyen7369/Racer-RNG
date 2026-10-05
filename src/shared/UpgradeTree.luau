--!nonstrict
-- Upgrade tree rules: pure functions over a set of owned tile ids (no Instances), so the server (truth), the
-- client (display only) and the tests share them. Numbers: Shared/UpgradeConfig. Design: docs/UPGRADE_TREE_DESIGN.md.
--
-- `owned` is a set { [tileId] = true }. "start" is always treated as owned.
-- A tile: { Id, Branch, Tier, Name ("Luck III"), Depth, PriceDepth, Q, R, Parent }.

local UpgradeConfig = require(script.Parent.UpgradeConfig)

local UpgradeTree = {}

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
local BONUS_KEYS = { "Money", "Luck", "Speed", "RollSpeed" }

-- Built once from the config: the ordered tile list and an id -> tile map. Callers always get copies.
local tiles, byId, branchById = {}, {}, {}
for _, branch in UpgradeConfig.Branches do
	branchById[branch.Id] = branch
	local count = #(branch.Bonus or branch.Tiers or branch.WalkSpeed)
	local parentDepth = branch.Parent == UpgradeConfig.START_ID and 0 or byId[branch.Parent].Depth
	for tier = 1, count do
		local tile = {
			Id = branch.Id .. "_" .. tier,
			Branch = branch.Id,
			Tier = tier,
			Name = branch.Name .. " " .. ROMAN[tier],
			Depth = parentDepth + tier,
			Q = branch.Origin[1] + tier * branch.Direction[1],
			R = branch.Origin[2] + tier * branch.Direction[2],
			Parent = tier == 1 and branch.Parent or (branch.Id .. "_" .. (tier - 1)),
		}
		tile.PriceDepth = branch.PriceDepth and branch.PriceDepth[tier] or tile.Depth
		table.insert(tiles, tile)
		byId[tile.Id] = tile
	end
end

local function copy(tile)
	return table.clone(tile)
end

local function isOwned(owned, id)
	return id == UpgradeConfig.START_ID or (type(owned) == "table" and owned[id] == true)
end

-- Highest owned tier of a branch (0 = none).
local function highestTier(owned, branchId)
	local best = 0
	if type(owned) ~= "table" then
		return best
	end
	for id, has in owned do
		local tile = has == true and byId[id]
		if tile and tile.Branch == branchId and tile.Tier > best then
			best = tile.Tier
		end
	end
	return best
end

-- Every tile in a stable order (branch order, then tier), Start excluded.
function UpgradeTree.Tiles()
	local list = table.create(#tiles)
	for i, tile in tiles do
		list[i] = copy(tile)
	end
	return list
end

-- The tile with this id, or nil.
function UpgradeTree.Get(tileId)
	local tile = type(tileId) == "string" and byId[tileId]
	return tile and copy(tile) or nil
end

-- Two significant figures, halves rounded up (726 -> 730, 1597 -> 1600, 225 -> 230).
function UpgradeTree.NiceRound(x)
	if type(x) ~= "number" or x ~= x or x <= 0 or x == math.huge then
		return 0
	end
	local unit = 10 ^ (math.floor(math.log10(x)) - 1)
	return math.floor(x / unit + 0.5) * unit
end

-- Price in Money: NiceRound(BASE_PRICE * PRICE_GROWTH ^ (PriceDepth - 1) * Weight). nil for an unknown id.
function UpgradeTree.Price(tileId)
	local tile = type(tileId) == "string" and byId[tileId]
	if not tile then
		return nil
	end
	local weight = branchById[tile.Branch].Weight
	return UpgradeTree.NiceRound(UpgradeConfig.BASE_PRICE * UpgradeConfig.PRICE_GROWTH ^ (tile.PriceDepth - 1) * weight)
end

-- The BestTrack a tile needs (0 = no gate): tier >= GATE_FROM_TIER needs min(tier - 1, trackCount).
function UpgradeTree.RequiredTrack(tileId, trackCount)
	local tile = type(tileId) == "string" and byId[tileId]
	if not tile or tile.Tier < UpgradeConfig.GATE_FROM_TIER then
		return 0
	end
	trackCount = type(trackCount) == "number" and math.max(0, math.floor(trackCount)) or 0
	return math.min(tile.Tier - 1, trackCount)
end

-- ok, reason. Reasons: "unknown", "owned", "locked" (previous tile not owned), "gated" (BestTrack too low),
-- "money" (not enough). `state` = { Owned = set, Money = n, BestTrack = n, TrackCount = n }.
function UpgradeTree.CanBuy(state, tileId)
	local tile = type(tileId) == "string" and byId[tileId]
	if not tile then
		return false, "unknown"
	end
	state = type(state) == "table" and state or {}
	if isOwned(state.Owned, tile.Id) then
		return false, "owned"
	end
	if not isOwned(state.Owned, tile.Parent) then
		return false, "locked"
	end
	local best = type(state.BestTrack) == "number" and state.BestTrack or 0
	if best < UpgradeTree.RequiredTrack(tile.Id, state.TrackCount) then
		return false, "gated"
	end
	local money = type(state.Money) == "number" and state.Money or 0
	if money < UpgradeTree.Price(tile.Id) then
		return false, "money"
	end
	return true, nil
end

-- How many tiles CanBuy says yes to right now (the UPGRADES badge).
function UpgradeTree.BuyableCount(state)
	local n = 0
	for _, tile in tiles do
		if UpgradeTree.CanBuy(state, tile.Id) then
			n += 1
		end
	end
	return n
end

-- Added bonuses from owned tiles: { Money = 0.25, Luck = 0, Speed = 0.1, RollSpeed = 0.2 }.
function UpgradeTree.Bonuses(owned)
	local sums = {}
	for _, key in BONUS_KEYS do
		sums[key] = 0
	end
	if type(owned) ~= "table" then
		return sums
	end
	for id, has in owned do
		local tile = has == true and byId[id]
		local branch = tile and branchById[tile.Branch]
		if branch and branch.Bonus and sums[branch.Effect] ~= nil then
			sums[branch.Effect] += branch.Bonus[tile.Tier]
		end
	end
	return sums
end

-- Seconds between auto-rolls: BASE_ROLL_INTERVAL / (1 + RollSpeed bonus), never below MIN_ROLL_INTERVAL.
function UpgradeTree.RollInterval(owned)
	local bonus = UpgradeTree.Bonuses(owned).RollSpeed
	return math.max(UpgradeConfig.MIN_ROLL_INTERVAL, UpgradeConfig.BASE_ROLL_INTERVAL / (1 + bonus))
end

-- { Multi, Every } of the highest owned Turbo tier (BASE_TURBO when none).
function UpgradeTree.Turbo(owned)
	local tier = highestTier(owned, "turbo")
	local pick = tier > 0 and branchById.turbo.Tiers[tier] or UpgradeConfig.BASE_TURBO
	return { Multi = pick.Multi, Every = pick.Every }
end

-- On-foot WalkSpeed of the highest owned Walkspeed tier (BASE_WALKSPEED when none).
function UpgradeTree.WalkSpeed(owned)
	local tier = highestTier(owned, "walkspeed")
	return tier > 0 and branchById.walkspeed.WalkSpeed[tier] or UpgradeConfig.BASE_WALKSPEED
end

UpgradeTree.Config = UpgradeConfig

return UpgradeTree
