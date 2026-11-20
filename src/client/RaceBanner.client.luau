--!nonstrict
-- Win moment (proposed by Vic2CS 2026-11-20, design doc "Playtest follow-ups", needs owner agreement; display only):
-- when the server says this player won a track (Remotes.NpcRace Result "Win"), a short banner pops in below the Race
-- button: "TRACK 3 CLEARED", the amount the server paid ("+$450", the event's Paid) and "NEW BEST" with the time when
-- the run beat an existing personal best (NewBest and a PreviousBest). About 2 s, a small shine and a burst of
-- sparks; with reduced motion (Client/UiMotion) it simply appears and disappears. It never takes input.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudFormat = require(Shared.HudFormat)
local RouteMath = require(Shared.RaceProgressMap)
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NpcRace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SHOW_SECONDS = 2 -- placeholder: whole banner, pop-in to gone
local POP_SECONDS = 0.25
local FADE_SECONDS = 0.35
local TOP = 140 -- px from the top: below the Race button (y 72..124) and the compact roll beside it
local PHONE_TOP = 112
local SPARKS = 10

local gui = Instance.new("ScreenGui")
gui.Name = "RaceBanner"
gui.DisplayOrder = 9 -- above the HUD and panels, below DuelUi (12) and the LoserScreen (20)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Banner"
root.AnchorPoint = Vector2.new(0.5, 0)
root.Position = UDim2.new(0.5, 0, 0, TOP)
root.Size = UDim2.fromOffset(340, 104)
root.BackgroundTransparency = 1
root.Active = false
root.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = root

local function label(name, y, height, font, color, size)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, y)
	l.Size = UDim2.new(1, 0, 0, height)
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = Color3.fromRGB(18, 22, 43)
	l.Active = false
	l.ZIndex = 3
	l.Text = ""
	l.Parent = root
	return l
end
local title = label("Title", 0, 44, Enum.Font.FredokaOne, Color3.fromRGB(120, 255, 170), 40)
local paid = label("Paid", 44, 32, Enum.Font.FredokaOne, Color3.fromRGB(255, 225, 90), 30)
local best = label("NewBest", 76, 26, Enum.Font.GothamBlack, Color3.fromRGB(110, 220, 255), 20)

-- The shine: a bright band sweeping across the title text
local shine = Instance.new("UIGradient")
shine.Color = ColorSequence.new(Color3.new(1, 1, 1))
shine.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.6),
	NumberSequenceKeypoint.new(0.45, 0.6),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.55, 0.6),
	NumberSequenceKeypoint.new(1, 0.6),
})
shine.Rotation = 20
shine.Offset = Vector2.new(-1, 0)
shine.Parent = title

local labels = { title, paid, best }
local token = 0

local function setFade(alpha)
	for _, l in labels do
		l.TextTransparency = alpha
		l.TextStrokeTransparency = alpha
	end
end

-- A small burst of sparks from the title's centre (skipped with reduced motion)
local function sparks()
	for i = 1, SPARKS do
		local s = Instance.new("TextLabel")
		s.Name = "Spark"
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.new(0.5, 0, 0, 22)
		s.Size = UDim2.fromOffset(18, 18)
		s.BackgroundTransparency = 1
		s.Text = "✦"
		s.Font = Enum.Font.GothamBold
		s.TextSize = 16
		s.TextColor3 = i % 2 == 0 and Color3.fromRGB(255, 225, 90) or Color3.fromRGB(120, 255, 170)
		s.Active = false
		s.ZIndex = 2
		s.Parent = root
		local angle = (i / SPARKS) * math.pi * 2 + 0.3
		local reach = 120 + (i % 3) * 25
		local goal = UDim2.new(0.5, math.cos(angle) * reach, 0, 22 + math.sin(angle) * reach * 0.45)
		UiMotion.Create(s, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = goal,
			TextTransparency = 1,
			Rotation = 90,
		}):Play()
		task.delay(0.75, function()
			s:Destroy()
		end)
	end
end

local function show(event)
	token += 1
	local mine = token
	for _, child in root:GetChildren() do
		if child.Name == "Spark" then
			child:Destroy()
		end
	end
	title.Text = ("TRACK %d CLEARED"):format(event.Track or 0)
	local amount = type(event.Paid) == "number" and event.Paid or 0
	paid.Text = amount > 0 and "+" .. HudFormat.MoneyText(amount) or ""
	local beat = event.NewBest == true and type(event.PreviousBest) == "number" and type(event.PlayerTime) == "number"
	best.Text = beat and "NEW BEST " .. RouteMath.FormatTime(event.PlayerTime) or ""
	local camera = Workspace.CurrentCamera
	local phone = camera and camera.ViewportSize.Y <= 500
	root.Position = UDim2.new(0.5, 0, 0, phone and PHONE_TOP or TOP)
	local size = phone and 0.75 or 1
	gui.Enabled = true
	local reduced = UiMotion.Reduced()
	setFade(0)
	if reduced then
		scale.Scale = size
	else
		scale.Scale = size * 0.55
		UiMotion.Create(scale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = size,
		}):Play()
		shine.Offset = Vector2.new(-1, 0)
		UiMotion.Create(shine, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0.15), {
			Offset = Vector2.new(1, 0),
		}):Play()
		sparks()
	end
	task.delay(SHOW_SECONDS - FADE_SECONDS, function()
		if token ~= mine then
			return
		end
		if reduced then
			gui.Enabled = false
			return
		end
		for _, l in labels do
			UiMotion.Create(l, TweenInfo.new(FADE_SECONDS), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		task.delay(FADE_SECONDS, function()
			if token == mine then
				gui.Enabled = false
			end
		end)
	end)
end

remote.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" then
		return
	end
	if event.Type == "Result" and event.Result == "Win" then
		show(event)
	elseif event.Type == "Stop" then
		token += 1
		gui.Enabled = false
	end
end)
