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
local RouteMath = require(Shared.RaceProgressMap)
local TrackRegistry = require(Shared.TrackRegistry)
local UiTheme = require(Shared.UiTheme)
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
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

-- Loser screen (docs/NPC_RACER_SPEC.md "Loser screen", docs/HUD_LAYOUT_SPEC.md sections 8 and 10): built once,
-- only its texts change per loss. Non-interactive; the shade is the first GuiObject child and covers the screen.
local Palette = UiTheme.Palette
local CARD_W, CARD_H, OVERHANG = 460, 330, 14
local ROW_STAGGER = 0.06

local trackNames = {}
for _, spec in TrackRegistry.Chain() do
	trackNames[spec.Number] = spec.Name
end

local gui = Instance.new("ScreenGui")
gui.Name = "LoserScreen"
gui.DisplayOrder = 20 -- the overlay draws above every other game GUI, including DuelUi
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = playerGui
local shade = Instance.new("Frame")
shade.Name = "Shade"
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(40, 6, 16)
shade.BackgroundTransparency = 0.3
shade.BorderSizePixel = 0
shade.Parent = gui

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.new(0.5, 0, 0.5, OVERHANG // 2)
card.Size = UDim2.fromOffset(CARD_W, CARD_H)
UiTheme.Plate(card, Palette.Danger)
card.Parent = shade
-- Layout scale (not MotionScale): the card keeps 16 px margins down to a 600 x 390 phone viewport.
local fit = Instance.new("UIScale")
fit.Name = "FitScale"
fit.Parent = card
local function refit()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		fit.Scale = math.min(1, (size.X - 32) / CARD_W, (size.Y - 32) / (CARD_H + OVERHANG))
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
refit()

local function label(name, parent, y, height, textSize, color)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, y)
	text.Size = UDim2.new(1, -40, 0, height)
	text.BackgroundTransparency = 1
	text.Font = UiTheme.Font
	text.TextSize = textSize
	text.TextColor3 = color or Palette.White
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Text = ""
	UiTheme.Stroke(text, 2)
	text.Parent = parent
	return text
end

local ribbon = Instance.new("Frame")
ribbon.Name = "BannerRibbon"
ribbon.AnchorPoint = Vector2.new(0.5, 0)
ribbon.Position = UDim2.new(0.5, 0, 0, -OVERHANG)
ribbon.Size = UDim2.fromOffset(CARD_W - 60, 64)
ribbon.BackgroundColor3 = Palette.White
ribbon.BorderSizePixel = 0
UiTheme.Corner(ribbon, "M")
UiTheme.Gradient(ribbon, Palette.Danger, Palette.DangerDeep)
UiTheme.Stroke(ribbon, 3, nil, true)
ribbon.Parent = card
local banner = label("Banner", ribbon, 0, 64, 44)
banner.Size = UDim2.fromScale(1, 1)
banner.Text = "YOU LOST"
UiTheme.Stroke(banner, 3)

local rows = {
	label("NpcName", card, 62, 30, 26),
	label("TrackTitle", card, 94, 22, 18, Palette.Unbanked),
	label("YourTime", card, 128, 30, 26, Palette.Behind),
	label("NpcTime", card, 160, 30, 26),
	label("Gap", card, 194, 34, 32, Palette.Danger),
	label("Pb", card, 234, 24, 20, Palette.Speed),
	label("BackTo", card, 264, 24, 20),
}
local npcName, trackTitle, yourTime, npcTime, gap, pb, backTo = table.unpack(rows)

local countdown = Instance.new("Frame")
countdown.Name = "Countdown"
countdown.AnchorPoint = Vector2.new(0.5, 0)
countdown.Position = UDim2.new(0.5, 0, 0, 298)
countdown.Size = UDim2.new(1, -60, 0, 12)
countdown.BackgroundColor3 = Palette.PanelDeep
countdown.BorderSizePixel = 0
UiTheme.Corner(countdown, "S")
UiTheme.Stroke(countdown, 2, nil, true)
countdown.Parent = card
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = Palette.White
fill.BorderSizePixel = 0
UiTheme.Corner(fill, "S")
UiTheme.Gradient(fill, Palette.Danger, Palette.DangerDeep)
fill.Parent = countdown

local homes = { [ribbon] = ribbon.Position }
for _, row in rows do
	homes[row] = row.Position
end

local runStart = nil -- the run's start track: the Reset's Track, else the run's first Start
local lastBest = {} -- track -> best time from the Start event
local function backToText(s)
	s = math.max(1, math.floor(tonumber(s) or 1))
	return s == 1 and "Back to the start" or ("Back to checkpoint %d"):format(s)
end

local function npcLabel(track)
	local info = NpcConfig.For(track)
	local o = NpcConfig.Tracks[info.Number]
	local car = o and o.Model and CarCatalog.Get(o.Model)
	local carName = car and car.Name or (o and o.Model)
	return carName and ("%s · %s"):format(info.Label, carName) or info.Label
end

local loseToken = 0
local shownAt = 0
local drain = nil
local function hideLoser()
	loseToken += 1
	gui.Enabled = false
end

local function showLoser(event)
	loseToken += 1
	local token = loseToken
	local track = tonumber(event.Track) or 1
	local mine, theirs = tonumber(event.PlayerTime), tonumber(event.NpcTime)
	local best = tonumber(event.BestTime) or lastBest[track]
	npcName.Text = npcLabel(track)
	trackTitle.Text = ("TRACK %d · %s"):format(track, string.upper(trackNames[track] or "RACE"))
	yourTime.Text = "YOUR TIME " .. (mine and RouteMath.FormatTime(mine) or "--")
	npcTime.Text = "NPC TIME " .. (theirs and RouteMath.FormatTime(theirs) or "--")
	gap.Text = (mine and theirs) and ("+%.2fs"):format(math.max(0, mine - theirs)) or ""
	pb.Text = best and "PB " .. RouteMath.FormatTime(best) or "PB --"
	backTo.Text = backToText(runStart or player:GetAttribute("Checkpoint"))

	for gui_, home in homes do
		gui_.Position = home
	end
	if drain then
		drain:Cancel()
	end
	fill.Size = UDim2.fromScale(1, 1)
	shownAt = os.clock()
	gui.Enabled = true
	refit()

	UiMotion.SlideIn(ribbon, Vector2.new(0, -80), 0.25)
	task.delay(0.25, function()
		if loseToken == token then
			UiMotion.Shake(ribbon, 10, 0.3)
		end
	end)
	local reduced = UiMotion.Reduced()
	for i, row in rows do
		row.Visible = reduced
		if not reduced then
			task.delay(0.12 + (i - 1) * ROW_STAGGER, function()
				if loseToken == token then
					row.Visible = true
					UiMotion.SlideIn(row, Vector2.new(0, 18), 0.22)
				end
			end)
		end
	end
	drain = UiMotion.Create(
		fill,
		TweenInfo.new(NpcConfig.LOSE_SCREEN_SECONDS, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(0, 1) }
	)
	drain:Play()

	task.delay(NpcConfig.LOSE_SCREEN_SECONDS, function()
		if loseToken == token then
			gui.Enabled = false
		end
	end)
end

-- Start / Reset never cut the recap short; once its time is up they hide it at once.
local function hideIfDone()
	if gui.Enabled and os.clock() - shownAt >= NpcConfig.LOSE_SCREEN_SECONDS then
		hideLoser()
	end
end

remote.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" then
		return
	end
	if event.Type == "Start" then
		startNpc(event)
		if runStart == nil then
			runStart = event.Track
		end
		if type(event.Track) == "number" then
			lastBest[event.Track] = tonumber(event.BestTime)
		end
		-- A loss is followed immediately by Reset + Start. Keep the presentation
		-- overlay alive for its configured duration while the new NPC is rebuilt.
		hideIfDone()
	elseif event.Type == "Result" and event.Result == "Lose" then
		showLoser(event)
	elseif event.Type == "Reset" then
		clearNpc()
		-- Reset is authoritative and immediate, but must not cancel the loser
		-- presentation: RaceService sends it in the same frame as Result/Lose.
		if type(event.Track) == "number" then
			runStart = event.Track
			if gui.Enabled then
				backTo.Text = backToText(runStart)
			end
		end
		hideIfDone()
	elseif event.Type == "Stop" then
		clearNpc()
		runStart = nil
		hideLoser()
	end
end)

RunService.RenderStepped:Connect(function()
	if current and current.Model.Parent then
		local t = Workspace:GetServerTimeNow() - current.ServerStart
		current.Model:PivotTo(NpcRacer.PoseAt(current.Path, current.Profile, t))
	end
end)
