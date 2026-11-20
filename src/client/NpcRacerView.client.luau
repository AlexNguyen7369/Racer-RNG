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
local CarCatalog = require(Shared.CarCatalog)
local HudFormat = require(Shared.HudFormat)
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
	current = { Model = model, Path = path, Profile = profile, ServerStart = event.ServerStart, ModelId = info.Model }
end

-- Loser screen. A lost race ends when the NPC's time is up (Vic2CS proposal 2026-11-20, design doc "Playtest
-- follow-ups"): the Result Lose arrives then, and the server resets the car LoseScreen seconds later (Reset + Start),
-- which hides the screen. It names the NPC's car and the track the player goes back to, and a progress guide: the
-- Speed the lost track needs, about how long that takes at the player's race gain, and a rebirth hint. Every number
-- comes from the server's event; this only formats it.
local gui = Instance.new("ScreenGui")
gui.Name = "LoserScreen"
gui.DisplayOrder = 20 -- the overlay draws above every other game GUI, including DuelUi
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = playerGui
local shade = Instance.new("Frame")
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(20, 10, 15)
shade.BackgroundTransparency = 0.35
shade.Parent = gui

local function label(name, y, height, font, color, text)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.fromScale(0.8, height)
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Text = text or ""
	l.Parent = shade
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = name == "Title" and 96 or 34
	cap.Parent = l
	return l
end
local title = label("Title", 0.36, 0.14, Enum.Font.GothamBlack, Color3.fromRGB(255, 80, 80), "YOU LOST!")
title.TextStrokeTransparency = 0
local detail = label("Detail", 0.5, 0.06, Enum.Font.GothamBold, Color3.new(1, 1, 1))
local guide = label("Guide", 0.58, 0.05, Enum.Font.GothamBold, Color3.fromRGB(255, 220, 60))
local rebirth = label("Rebirth", 0.65, 0.05, Enum.Font.GothamBold, Color3.fromRGB(190, 140, 255))

local function finite(x)
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- "about 45 s", "about 12 min", "about 3.5 h", "about 4 days" (placeholder wording)
local function aboutTime(seconds)
	if seconds < 60 then
		return ("about %d s"):format(math.max(1, math.ceil(seconds)))
	elseif seconds < 3600 then
		return ("about %d min"):format(math.ceil(seconds / 60))
	elseif seconds < 86400 then
		local hours = string.gsub(string.format("%.1f", seconds / 3600), "%.0$", "")
		return ("about %s h"):format(hours)
	end
	return ("about %s days"):format(HudFormat.Short(math.ceil(seconds / 86400)))
end

-- x5, x7.5
local function multiText(multi)
	return multi == math.floor(multi) and HudFormat.Short(multi) or string.format("%.1f", multi)
end

-- The NPC's car by its catalog name ("the Rain Runner"), else "the NPC"
local function npcName(event)
	local id = type(event.NpcModel) == "string" and event.NpcModel
		or current and current.Model:GetAttribute("TrackNumber") == event.Track and current.ModelId
		or nil
	local spec = id and CarCatalog.Get(id)
	return spec and type(spec.Name) == "string" and "the " .. spec.Name or "the NPC"
end

local function guideText(event)
	if not (finite(event.NeedSpeed) and finite(event.Speed)) then
		return ""
	end
	local track = event.Track or 0
	local need = HudFormat.SpeedText(event.NeedSpeed)
	if event.Speed >= event.NeedSpeed then
		return ("Track %d needs %s Speed. You have it: try a NITRO boost!"):format(track, need)
	end
	if not finite(event.GainRate) or event.GainRate <= 0 then
		return ("Track %d needs %s Speed."):format(track, need)
	end
	local seconds = (event.NeedSpeed - event.Speed) / event.GainRate
	return ("Track %d needs %s Speed: %s of racing"):format(track, need, aboutTime(seconds))
end

local loseToken = 0
local function hideLoser()
	loseToken += 1
	gui.Enabled = false
end

local function showLoser(event)
	loseToken += 1
	local token = loseToken
	local back = type(event.BackTo) == "number" and ("Back to Track %d!"):format(event.BackTo) or "Back to the start!"
	detail.Text = ("Lost Track %d to %s. %s"):format(event.Track or 0, npcName(event), back)
	guide.Text = guideText(event)
	local canRebirth = event.CanRebirth == true and finite(event.RebirthMulti) and event.RebirthMulti > 1
	rebirth.Text = canRebirth and ("Rebirth now for x%s Speed gain"):format(multiText(event.RebirthMulti)) or ""
	gui.Enabled = true
	-- The server's Reset (or a Start / Stop) hides it; this is only a fallback if that never arrives.
	local seconds = finite(event.LoseScreen) and event.LoseScreen or NpcConfig.LOSE_SCREEN_SECONDS
	task.delay(seconds + 2, function()
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
		hideLoser() -- the next race starts after the loser screen (or an admin jump replaced it)
		startNpc(event)
	elseif event.Type == "Result" and event.Result == "Lose" then
		showLoser(event) -- the NPC stays at its finish (PoseAt clamps) until the Reset
	elseif event.Type == "Reset" or event.Type == "Stop" then
		clearNpc()
		hideLoser()
	end
end)

RunService.RenderStepped:Connect(function()
	if current and current.Model.Parent then
		local t = Workspace:GetServerTimeNow() - current.ServerStart
		current.Model:PivotTo(NpcRacer.PoseAt(current.Path, current.Profile, t))
	end
end)
