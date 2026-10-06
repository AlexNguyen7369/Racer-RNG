--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackBuilder = require(Shared.TrackBuilder)
local TrackRegistry = require(Shared.TrackRegistry)
local SpawnArea = require(Shared.SpawnArea)
local AdminService = require(script.Parent.AdminService)
local CarService = require(script.Parent.CarService)
local GachaService = require(script.Parent.GachaService)
local MoneyService = require(script.Parent.MoneyService)
local PlayerData = require(script.Parent.PlayerData)
local RaceService = require(script.Parent.RaceService)
local UpgradeService = require(script.Parent.UpgradeService)
local WorkshopService = require(script.Parent.WorkshopService)

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

-- The player's car auto-races the whole chain at the speed from their saved stats
RaceService.Start(RaceService.BuildRoute(entries))
PlayerData.Start()
UpgradeService.SetTrackCount(#chain) -- the tree's tier gate (docs/UPGRADE_TREE_DESIGN.md)
UpgradeService.Start() -- the money upgrade tree: Remotes.BuyUpgrade and the UPGRADES badge
GachaService.Start() -- free auto-rolls (after each save loads), the car index and stat points
MoneyService.Start()
CarService.Start()
WorkshopService.Start(track1Start) -- 7 workshop plots in the spawn area, one per player, idle Speed in the zone
AdminService.Start() -- chat admin commands (docs/ADMIN_COMMANDS_SPEC.md)
