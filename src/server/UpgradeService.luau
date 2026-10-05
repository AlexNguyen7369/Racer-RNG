--!nonstrict
-- Upgrade tree, server side (docs/UPGRADE_TREE_DESIGN.md). The server owns all of it; clients only see:
--   player.Upgrades: one StringValue per owned tile id
--   player attributes: BestTrack, TurboCount, TurboEvery, TurboMulti, UpgradesBuyable (the badge)
-- Remotes.BuyUpgrade(tileId) -> ok, reason. The client never sends a price.
--
-- SKELETON (2026-10-05): API only, not required by Main yet. Implemented in upgrade tree phase 2, after
-- test-writer's checks for it are red.

local UpgradeService = {}

UpgradeService.REMOTE_COOLDOWN = 0.15 -- seconds between accepted BuyUpgrade requests per player

local function todo(name)
	error("UpgradeService." .. name .. " is not implemented yet (upgrade tree phase 2)", 2)
end

-- Creates player.Upgrades and the attributes (idempotent).
function UpgradeService.Setup(_player)
	todo("Setup")
end

-- Set { [tileId] = true } of the player's tiles (Start included).
function UpgradeService.Owned(_player)
	todo("Owned")
end

-- Validated purchase: takes the price from leaderstats.Money exactly once and grants the tile. ok, reason.
function UpgradeService.Buy(_player, _tileId)
	todo("Buy")
end

-- Effects, read by GachaService (Bonuses, RollInterval, Turbo) and CarService (WalkSpeed).
function UpgradeService.Bonuses(_player)
	todo("Bonuses")
end

function UpgradeService.RollInterval(_player)
	todo("RollInterval")
end

function UpgradeService.Turbo(_player)
	todo("Turbo")
end

function UpgradeService.WalkSpeed(_player)
	todo("WalkSpeed")
end

-- Raises BestTrack to trackNumber if higher (called by RaceService on a won / finished track).
function UpgradeService.ReachTrack(_player, _trackNumber)
	todo("ReachTrack")
end

-- Save format (PlayerData VERSION 4): { Upgrades = { id, ... } (sorted), BestTrack = n, TurboCount = n }.
function UpgradeService.Snapshot(_player)
	todo("Snapshot")
end

-- Loads a snapshot (unknown ids kept, version-3 saves: TurboCount from Rolls % 10).
function UpgradeService.Apply(_player, _saved)
	todo("Apply")
end

-- Creates Remotes.BuyUpgrade and keeps UpgradesBuyable current.
function UpgradeService.Start()
	todo("Start")
end

return UpgradeService
