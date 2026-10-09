--!nonstrict
-- Mechanical Workshop numbers (docs/WORKSHOP_SPEC.md, drafted 2026-10-06). Data only: the rules that read it live in
-- Shared/Workshop. Plot rects are local (x, z) of Track 1's flattened Start, like Shared/SpawnArea.

local WorkshopConfig = {}

WorkshopConfig.PLOT_COUNT = 7 -- one plot per player; the server's Max Players must be 7 (Game Settings, by hand)
WorkshopConfig.PLOT_SIZE = 48 -- studs, square

-- Assignment order: a joining player gets the lowest free index. `Front` = the local direction the open side faces
-- (toward the hub), as a unit (x, z).
WorkshopConfig.Plots = {
	{ Min = Vector2.new(200, -12), Max = Vector2.new(248, 36), Front = Vector2.new(-1, 0) },
	{ Min = Vector2.new(200, -68), Max = Vector2.new(248, -20), Front = Vector2.new(-1, 0) },
	{ Min = Vector2.new(200, -124), Max = Vector2.new(248, -76), Front = Vector2.new(-1, 0) },
	{ Min = Vector2.new(200, -180), Max = Vector2.new(248, -132), Front = Vector2.new(-1, 0) },
	{ Min = Vector2.new(144, -180), Max = Vector2.new(192, -132), Front = Vector2.new(0, 1) },
	{ Min = Vector2.new(88, -180), Max = Vector2.new(136, -132), Front = Vector2.new(0, 1) },
	{ Min = Vector2.new(32, -180), Max = Vector2.new(80, -132), Front = Vector2.new(0, 1) },
}

-- The gain zone, centred in the plot: (x, height, z) studs. Standing anywhere in it (root above the floor and below
-- the height) earns Speed.
WorkshopConfig.ZONE_SIZE = Vector3.new(32, 12, 32)

WorkshopConfig.TICK = 0.5 -- seconds between server zone checks
WorkshopConfig.BASE_RATE = 1 -- Speed per second at level 1, stat 0, no multis (placeholder, design doc "B")

-- Configurable progression defaults: each level doubles W; next prices grow fivefold from $500.
WorkshopConfig.Levels = {
	{ Multi = 1, Price = 0 }, -- the starter workshop
}
for level = 2, 10 do
	WorkshopConfig.Levels[level] = { Multi = 2 ^ (level - 1), Price = 500 * 5 ^ (level - 2) }
end
WorkshopConfig.MAX_LEVEL = #WorkshopConfig.Levels
WorkshopConfig.OFFLINE_FRACTION = 0.25
WorkshopConfig.OFFLINE_CAP = 8 * 60 * 60
WorkshopConfig.UPGRADE_DISTANCE = 12
WorkshopConfig.REMOTE_COOLDOWN = 0.5

WorkshopConfig.SIGN_DISTANCE = 120 -- MaxDistance of the plot signs
WorkshopConfig.EMPTY_TEXT = "EMPTY PLOT"
WorkshopConfig.TAG = "WorkshopPlot"

return WorkshopConfig
