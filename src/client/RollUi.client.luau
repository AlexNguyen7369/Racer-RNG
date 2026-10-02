--!nonstrict
-- The TURBO LUCK bar at the bottom centre (docs/SPAWN_AND_ROLLS_SPEC.md): it fills one step per auto roll and every
-- GachaConfig.TURBO_EVERY-th roll gets TURBO_LUCK times the luck; on that roll it flashes and pops "TURBO x5!",
-- then starts empty again. The server decides every roll (Remotes.RollResult); this only displays. The roll toast
-- above it and the roll showcase live in Client/RollToast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GachaConfig = require(Shared.GachaConfig)
local rollRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RollResult")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BOTTOM = 10 -- px from the screen's bottom edge to the bar
local BAR_SIZE = Vector2.new(240, 16)
local POP_SECONDS = 1.2
local WHITE = Color3.fromRGB(255, 255, 255)
local TURBO_COLOR = Color3.fromRGB(255, 170, 40)

local gui = Instance.new("ScreenGui")
gui.Name = "RollUi"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function round(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
end

local function text(parent, name, str, size)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = str
	l.TextSize = size
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = WHITE
	l.Parent = parent
	return l
end

local bar = Instance.new("Frame")
bar.Name = "TurboBar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -BOTTOM)
bar.Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y)
bar.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
bar.BackgroundTransparency = 0.2
bar.Parent = gui
round(bar, 8)
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = TURBO_COLOR
fill.BorderSizePixel = 0
fill.Parent = bar
round(fill, 8)
local label = text(bar, "Label", "", 11)
label.TextStrokeTransparency = 0.5
label.ZIndex = 2
local pop = text(bar, "TurboPop", "", 22)
pop.AnchorPoint = Vector2.new(0.5, 1)
pop.Position = UDim2.new(0.5, 0, 0, -4)
pop.Size = UDim2.fromOffset(BAR_SIZE.X, 26)
pop.TextColor3 = TURBO_COLOR
pop.TextStrokeTransparency = 0.2
pop.Visible = false
pop.ZIndex = 3

local popStamp = 0

local function refresh(animate)
	local progress = GachaConfig.TurboProgress(player:GetAttribute("Rolls") or 0)
	label.Text = string.format("TURBO LUCK %d/%d", progress, GachaConfig.TURBO_EVERY)
	local size = UDim2.fromScale(progress / GachaConfig.TURBO_EVERY, 1)
	if animate then
		TweenService:Create(fill, TweenInfo.new(0.25), { Size = size }):Play()
	else
		fill.Size = size
	end
end

-- The turbo roll: the bar flashes full, "TURBO x5!" pops above it, then the bar empties for the next round
local function turboPop(multi)
	local stamp = os.clock()
	popStamp = stamp
	pop.Text = "TURBO x" .. tostring(multi) .. "!"
	pop.TextTransparency = 0
	pop.Size = UDim2.fromOffset(BAR_SIZE.X * 0.6, 16)
	pop.Visible = true
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(BAR_SIZE.X, 26),
	}):Play()
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = WHITE
	TweenService:Create(fill, TweenInfo.new(0.4), { BackgroundColor3 = TURBO_COLOR }):Play()
	task.delay(0.4, function()
		if popStamp == stamp then
			refresh(true)
		end
	end)
	task.delay(POP_SECONDS, function()
		if popStamp == stamp then
			TweenService:Create(pop, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			task.delay(0.3, function()
				if popStamp == stamp then
					pop.Visible = false
				end
			end)
		end
	end)
end

rollRemote.OnClientEvent:Connect(function(_, _, turboMulti)
	if type(turboMulti) == "number" and turboMulti > 1 then
		turboPop(turboMulti)
	end
end)

player:GetAttributeChangedSignal("Rolls"):Connect(function()
	if not pop.Visible then
		refresh(true)
	else
		label.Text = string.format(
			"TURBO LUCK %d/%d",
			GachaConfig.TurboProgress(player:GetAttribute("Rolls") or 0),
			GachaConfig.TURBO_EVERY
		)
	end
end)
refresh(false)
