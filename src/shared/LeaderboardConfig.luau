--!nonstrict
-- Global leaderboards (docs/LEADERBOARD_SPEC.md): the boards, their signs and their OrderedDataStores.
local LeaderboardConfig = {}

LeaderboardConfig.TOP_N = 10
LeaderboardConfig.REFRESH = 60 -- seconds between reads
LeaderboardConfig.WRITE_INTERVAL = 300 -- seconds between writes of the players in the server
LeaderboardConfig.NO_DATA = "No data yet"

-- In sign order. A store name is permanent: a new one starts an empty board.
LeaderboardConfig.Boards = {
	{ Id = "Speed", Title = "TOP SPEED", Store = "LB_Speed_v1" },
	{ Id = "MoneyEarned", Title = "MONEY EARNED", Store = "LB_MoneyEarned_v1" },
	{ Id = "Rolls", Title = "MOST ROLLS", Store = "LB_Rolls_v1" },
	{ Id = "RarestCar", Title = "RAREST CAR", Store = "LB_RarestCar_v1" },
}

-- Signs: local (x, z) of each board's centre in the spawn area (along the hub's near edge, facing the spawn).
LeaderboardConfig.SIGN_SIZE = Vector3.new(16, 12, 1)
LeaderboardConfig.SIGN_Z = 40
LeaderboardConfig.SIGN_X = { 152, 128, 104, 80 } -- read left to right from the spawn

-- Best Roll Ever pedestal (docs/LEADERBOARD_SPEC.md 3a): local (X, Z) of its centre, where the
-- spawn-area upgrade pad stood (owner, 2026-10-13).
LeaderboardConfig.BEST_ROLL = {
	X = 150,
	Z = -70,
	RADIUS = 12,
	HEIGHT = 2,
	CAR_SCALE = 3.5, -- the car stands at this scale, so it reads from across the hub
	SPIN = 45, -- degrees per second (client only)
	TEXT_DISTANCE = 150, -- studs: MaxDistance of the stats above the car
}

return LeaderboardConfig
