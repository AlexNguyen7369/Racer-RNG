--!nonstrict
-- Reduced motion for UI (docs/HUD_LAYOUT_SPEC.md section 7): Roblox's Reduced Motion setting or the in-game
-- REDUCED EFFECTS toggle. UI tweens go through Create so they land at once while motion is reduced.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UiMotion = {}

local INSTANT = TweenInfo.new(0)

function UiMotion.Reduced()
	local player = Players.LocalPlayer
	return GuiService.ReducedMotionEnabled or (player ~= nil and player:GetAttribute("ReduceEffects") == true)
end

-- TweenService:Create with the same arguments; a reduced tween takes 0 s and never repeats.
function UiMotion.Create(instance, info, goal)
	return TweenService:Create(instance, UiMotion.Reduced() and INSTANT or info, goal)
end

-- Motion presets (section 10): Pop, SlideIn, Shine, Pulse, Shake, Float; each lands at once while reduced.

-- The UIScale the presets animate. A layout UIScale (any other name) is never touched: nil then.
local function motionScale(gui)
	local scale = gui:FindFirstChildOfClass("UIScale")
	if scale and scale.Name ~= "MotionScale" then
		return nil
	end
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "MotionScale"
		scale.Parent = gui
	end
	return scale
end

-- Grows the gui by `amount` (default 12%) and settles back, about 0.18 s.
function UiMotion.Pop(gui, amount)
	local scale = motionScale(gui)
	if not scale then
		return
	end
	if UiMotion.Reduced() then
		scale.Scale = 1
		return
	end
	local up = TweenService:Create(
		scale,
		TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 1 + (amount or 0.12) }
	)
	up.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			TweenService
				:Create(scale, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1 })
				:Play()
		end
	end)
	up:Play()
end

-- Moves the gui from `offset` (Vector2, px) to where it is now, fading a CanvasGroup in; Back easing.
function UiMotion.SlideIn(gui, offset, duration)
	local target = gui.Position
	duration = duration or 0.25
	if UiMotion.Reduced() then
		if gui:IsA("CanvasGroup") then
			gui.GroupTransparency = 0
		end
		return
	end
	gui.Position = target + UDim2.fromOffset(offset.X, offset.Y)
	TweenService:Create(gui, TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = target,
	}):Play()
	if gui:IsA("CanvasGroup") then
		gui.GroupTransparency = 1
		TweenService:Create(gui, TweenInfo.new(duration * 0.8), { GroupTransparency = 0 }):Play()
	end
end

-- Sweeps one light band across the gui (a plate or a bar fill). The overlay is reused per gui.
function UiMotion.Shine(gui, duration)
	if UiMotion.Reduced() then
		return
	end
	local overlay = gui:FindFirstChild("MotionShine")
	if not overlay then
		overlay = Instance.new("Frame")
		overlay.Name = "MotionShine"
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BackgroundColor3 = Color3.new(1, 1, 1)
		overlay.BorderSizePixel = 0
		overlay.Active = false
		overlay.ZIndex = gui.ZIndex
		local corner = gui:FindFirstChildOfClass("UICorner")
		if corner then
			corner:Clone().Parent = overlay
		end
		local band = Instance.new("UIGradient")
		band.Rotation = 20
		band.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		band.Parent = overlay
		overlay.Parent = gui
	end
	local band = overlay:FindFirstChildOfClass("UIGradient")
	band.Offset = Vector2.new(-1, 0)
	TweenService:Create(
		band,
		TweenInfo.new(duration or 0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Offset = Vector2.new(1, 0) }
	):Play()
end

-- Loops `instance` between its current properties and `goal` (reversing), one way in `period` seconds.
-- Returns a stop function that puts the starting values back. While reduced nothing loops.
function UiMotion.Pulse(instance, goal, period)
	local start = {}
	for property in goal do
		start[property] = instance[property]
	end
	if UiMotion.Reduced() then
		return function() end
	end
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(period or 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		goal
	)
	tween:Play()
	return function()
		tween:Cancel()
		for property, value in start do
			instance[property] = value
		end
	end
end

-- Shakes the gui sideways by up to `px` for `duration` seconds, then puts it back.
function UiMotion.Shake(gui, px, duration)
	if UiMotion.Reduced() then
		return
	end
	local home = gui.Position
	local steps = 6
	task.spawn(function()
		for i = 1, steps do
			local dx = (i % 2 == 0 and -1 or 1) * (px or 8) * (1 - (i - 1) / steps)
			gui.Position = home + UDim2.fromOffset(dx, 0)
			task.wait((duration or 0.3) / steps)
		end
		gui.Position = home
	end)
end

-- Lights up the first 12 `items` one after another (background and their `edgeName` stroke fade in to the values
-- they had): for tiles a grid or list layout positions, where a slide would not show.
local CASCADE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
function UiMotion.Cascade(items, edgeName)
	if UiMotion.Reduced() then
		return
	end
	for i = 1, math.min(#items, 12) do
		local item = items[i]
		local edge = edgeName and item:FindFirstChild(edgeName)
		local fill, line = item.BackgroundTransparency, edge and edge.Transparency
		item.BackgroundTransparency = 1
		if edge then
			edge.Transparency = 1
		end
		task.delay((i - 1) * 0.03, function()
			TweenService:Create(item, CASCADE, { BackgroundTransparency = fill }):Play()
			if edge then
				TweenService:Create(edge, CASCADE, { Transparency = line }):Play()
			end
		end)
	end
end

-- A short text ("+$1.2m") that rises from `position` inside `parent`, fades out and is removed.
function UiMotion.Float(parent, text, color, position)
	if UiMotion.Reduced() then
		return
	end
	local label = Instance.new("TextLabel")
	label.Name = "MotionFloat"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = position
	label.Size = UDim2.fromOffset(200, 30)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 26
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
	label.Text = text
	label.ZIndex = 20
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(18, 22, 43)
	stroke.Thickness = 2.5
	stroke.Parent = label
	label.Parent = parent
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Position = position - UDim2.fromOffset(0, 46), TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	task.delay(1.15, function()
		label:Destroy()
	end)
end

return UiMotion
