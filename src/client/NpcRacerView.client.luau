--!nonstrict
-- Draws this player's NPC racer and the loser screen. The server decides the race (Server/RaceService) and sends
-- the events to this player only; the NPC car is created here, in this client's Workspace, so no other player
-- ever sees it. Its position is pure maths (Shared/NpcRacer), driven by the server clock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcConfig = require(Shared.NpcConfig)
local NpcRacer = require(Shared.NpcRacer)
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NpcRace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Lanes per track number, built once from the same chain the server builds
local lanes = {}
for _, entry in NpcRacer.ChainEntries() do
	lanes[entry.Number] = NpcRacer.LanePath(entry)
end

local current = nil -- { Model, Path, Profile, ServerStart }

local function clearNpc()
	if current then
		current.Model:Destroy()
		current = nil
	end
end

local function startNpc(event)
	clearNpc()
	local path = lanes[event.Track]
	if not path then
		return
	end
	local info = NpcConfig.For(event.Track)
	info.Color = typeof(event.Color) == "Color3" and event.Color or info.Color
	info.Label = type(event.Label) == "string" and event.Label or info.Label
	info.Model = type(event.Model) == "string" and event.Model or info.Model
	local profile = NpcRacer.Profile(path, type(event.Speed) == "number" and event.Speed or info.Speed)
	local model = NpcRacer.BuildModel(info)
	model:PivotTo(NpcRacer.PoseAt(path, profile, 0))
	model.Parent = Workspace -- client-side only: never replicated
	current = { Model = model, Path = path, Profile = profile, ServerStart = event.ServerStart }
end

-- Loser screen
local gui = Instance.new("ScreenGui")
gui.Name = "LoserScreen"
gui.DisplayOrder = 10 -- the overlay draws above every other game GUI
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = playerGui
local shade = Instance.new("Frame")
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(20, 10, 15)
shade.BackgroundTransparency = 0.35
shade.Parent = gui
local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.42)
title.Size = UDim2.fromScale(0.8, 0.14)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 80, 80)
title.TextStrokeTransparency = 0
title.Text = "YOU LOST!"
title.Parent = shade
local detail = Instance.new("TextLabel")
detail.Name = "Detail"
detail.AnchorPoint = Vector2.new(0.5, 0.5)
detail.Position = UDim2.fromScale(0.5, 0.56)
detail.Size = UDim2.fromScale(0.7, 0.06)
detail.BackgroundTransparency = 1
detail.Font = Enum.Font.GothamBold
detail.TextScaled = true
detail.TextColor3 = Color3.new(1, 1, 1)
detail.TextStrokeTransparency = 0.3
detail.Parent = shade

local loseToken = 0
local function showLoser(event)
	loseToken += 1
	local token = loseToken
	local who = current
			and current.Model:GetAttribute("TrackNumber") == event.Track
			and NpcConfig.For(event.Track).Label
		or "The NPC"
	detail.Text = ("You lost at checkpoint %d to %s. Back to the start!"):format(event.Track or 0, who)
	gui.Enabled = true
	task.delay(NpcConfig.LOSE_SCREEN_SECONDS, function()
		if loseToken == token then
			gui.Enabled = false
		end
	end)
end

remote.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" then
		return
	end
	if event.Type == "Start" then
		startNpc(event)
	elseif event.Type == "Result" and event.Result == "Lose" then
		showLoser(event)
	elseif event.Type == "Reset" or event.Type == "Stop" then
		clearNpc()
		if event.Type == "Stop" then
			gui.Enabled = false
		end
	end
end)

RunService.RenderStepped:Connect(function()
	if current and current.Model.Parent then
		local t = Workspace:GetServerTimeNow() - current.ServerStart
		current.Model:PivotTo(NpcRacer.PoseAt(current.Path, current.Profile, t))
	end
end)
