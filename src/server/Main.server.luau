--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BiomeDressing = require(Shared.BiomeDressing)
-- Populate all cosmetic templates before any car, index, showcase or pedestal can request one.
require(Shared.DraftCarModels).Ensure()
local TrackBuilder = require(Shared.TrackBuilder)
local TrackRegistry = require(Shared.TrackRegistry)
local SpawnArea = require(Shared.SpawnArea)
local VfxArea = require(Shared.VfxArea)
local AdminService = require(script.Parent.AdminService)
local CarService = require(script.Parent.CarService)
local GachaService = require(script.Parent.GachaService)
local MoneyService = require(script.Parent.MoneyService)
local PlayerData = require(script.Parent.PlayerData)
local RaceService = require(script.Parent.RaceService)
local UpgradeService = require(script.Parent.UpgradeService)
local WorkshopService = require(script.Parent.WorkshopService)
local WeatherService = require(script.Parent.WeatherService)
local MarketService = require(script.Parent.MarketService)
local RebirthService = require(script.Parent.RebirthService)
local BoostService = require(script.Parent.BoostService)
local DailyLoginService = require(script.Parent.DailyLoginService)
local LevelService = require(script.Parent.LevelService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local DuelService = require(script.Parent.DuelService)
local CheckpointService = require(script.Parent.CheckpointService)
local PassCarService = require(script.Parent.PassCarService)
local QuestService = require(script.Parent.QuestService)
local ShopService = require(script.Parent.ShopService)

-- Tracks are chained in Number order: each one starts where the previous one's finish checkpoint is.
local chain = TrackRegistry.Chain()
assert(#chain > 0, "no numbered tracks found")

local folder = Instance.new("Folder")
folder.Name = "Track"
folder.Parent = Workspace

local entries = {}
local origin = CFrame.new(0, TrackBuilder.TRACK_LIFT, 0)
for _, spec in chain do
	local model, layout = TrackBuilder.Build(spec, origin)
	model.Name = spec.Name
	model.Parent = folder
	table.insert(entries, { Layout = layout, Origin = origin, Model = model, Number = spec.Number })
	origin = TrackBuilder.EndCFrame(layout, origin)
end

-- The spawn area beside Track 1's start: players join, respawn and stop here, and walk onto its StartPad to race
local track1Start = entries[1].Model:FindFirstChild("Start", true).CFrame
local spawnArea = SpawnArea.Build(track1Start)
spawnArea.Parent = Workspace
local trackModels = {}
for _, entry in entries do
	table.insert(trackModels, entry.Model)
end
BiomeDressing.Prune(trackModels, { spawnArea }) -- scenery keeps clear of every road and the spawn area
require(Shared.TrackPreviews).Bake(trackModels) -- checkpoint card previews (docs/CHECKPOINT_SPEC.md section 4)
VfxArea.Build().Parent = Workspace -- the admin-only VFX showcase floor (/tp vfxarea)

-- The lighting baseline goes in before WeatherService snapshots it (docs/RENDERING_SPEC.md)
require(Shared.LightingConfig).Apply()
-- The player's car auto-races the whole chain at the speed from their saved stats
RaceService.Start(RaceService.BuildRoute(entries))
WeatherService.Start()
PlayerData.Start()
UpgradeService.SetTrackCount(#chain) -- the tree's tier gate (docs/UPGRADE_TREE_DESIGN.md)
UpgradeService.Start() -- the money upgrade tree: Remotes.BuyUpgrade and the UPGRADES badge
GachaService.Start() -- free auto-rolls (after each save loads), the car index and stat points
MoneyService.Start()
CarService.Start()
WorkshopService.Start(track1Start) -- 7 workshop plots in the spawn area, one per player, idle Speed in the zone
MarketService.Start() -- the spawn-area aura and trail market (physical prompt + client button)
RebirthService.Start()
BoostService.Start()
DailyLoginService.Start()
LevelService.Start()
PassCarService.Start() -- gamepass cars on the two small pedestals (docs/GAMEPASS_CARS_SPEC.md)
LeaderboardService.Start() -- global boards on the spawn-area signs (docs/LEADERBOARD_SPEC.md)
DuelService.Start() -- player vs player duels, no stake (docs/DUEL_SPEC.md)
CheckpointService.Start() -- pick the starting track at the hub's Checkpoints NPC (docs/CHECKPOINT_SPEC.md)
QuestService.Start() -- UTC daily and weekly quest tracking (docs/QUESTS_SPEC.md)
ShopService.Start() -- Robux potion receipts and redeem codes (docs/SHOP_PURCHASES_SPEC.md)
AdminService.Start() -- chat admin commands (docs/ADMIN_COMMANDS_SPEC.md)
