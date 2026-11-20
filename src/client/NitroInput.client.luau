--!nonstrict
-- Timed nitro bar while auto racing (docs/NITRO_SPEC.md, proposal). Draws the needle from the server's
-- NitroReadyAt and sends only the press time; Server/NitroService grades it and starts the boost.
-- Press: Space, a left click on the world (not on a button), tapping the bar, or gamepad X / R1.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local NitroConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NitroConfig"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Nitro")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BAR_W, BAR_H = 340, 34
local GAP_ABOVE_SPEED = 10 -- px between the bar's label and the HUD Speed readout
local FALLBACK_Y = 0.7 -- bar bottom (scale) when the HUD Speed readout is not found
local FOV_KICK = 8 -- degrees added to the camera's field of view while boosting
local GAP_BELOW_ROLL = 6 -- px kept free under the compact roll (RollToast.Toast) on short screens
local MIN_SCALE = 0.55 -- the bar shrinks (UIScale) down to this to fit between the compact roll and Speed

local COLOR_BG = Color3.fromRGB(20, 22, 32)
local COLOR_GOOD = Color3.fromRGB(60, 210, 90)
local COLOR_PERFECT = Color3.fromRGB(255, 200, 40)
local COLOR_NEEDLE = Color3.fromRGB(255, 255, 255)
local COLOR_CHARGE = Color3.fromRGB(80, 140, 255)
local COLOR_MARK = Color3.fromRGB(255, 70, 200) -- where the last press landed

local function make(className, props, parent)
	local obj = Instance.new(className)
	for k, v in props do
		obj[k] = v
	end
	obj.Parent = parent
	return obj
end

local gui = make("ScreenGui", {
	Name = "NitroBar",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 5,
	Enabled = false,
}, playerGui)

local root = make("Frame", {
	Name = "Root",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, FALLBACK_Y),
	Size = UDim2.fromOffset(BAR_W, BAR_H + 30),
	BackgroundTransparency = 1,
}, gui)

local rootScale = make("UIScale", { Name = "FitScale", Scale = 1 }, root)

local label = make("TextLabel", {
	Name = "Label",
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 20,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.4,
	Text = "",
}, root)

-- The bar is a button so phones can tap it (and a mouse can click it)
local bar = make("TextButton", {
	Name = "Bar",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, BAR_H),
	BackgroundColor3 = COLOR_BG,
	BackgroundTransparency = 0.15,
	AutoButtonColor = false,
	Text = "",
}, root)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, bar)
make("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.6, Thickness = 2 }, bar)

local good = make("Frame", {
	Name = "Good",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(NitroConfig.GOOD_ZONE, 0, 1, -8),
	BackgroundColor3 = COLOR_GOOD,
	BorderSizePixel = 0,
}, bar)
make("UICorner", { CornerRadius = UDim.new(0, 4) }, good)
local perfect = make("Frame", {
	Name = "Perfect",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(NitroConfig.PERFECT_ZONE, 0, 1, -8),
	BackgroundColor3 = COLOR_PERFECT,
	BorderSizePixel = 0,
}, bar)
make("UICorner", { CornerRadius = UDim.new(0, 3) }, perfect)
local charge = make("Frame", {
	Name = "Charge",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = COLOR_CHARGE,
	BackgroundTransparency = 0.55, -- see-through, so the zones and the press marker stay readable while charging
	BorderSizePixel = 0,
	ZIndex = 2,
}, bar)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, charge)
-- Where the last press landed: shown from the press until the next bar is ready
local mark = make("Frame", {
	Name = "PressMark",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 6, 1, 14),
	BackgroundColor3 = COLOR_MARK,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 4,
}, bar)
make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5 }, mark)
local needle = make("Frame", {
	Name = "Needle",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.new(0, 4, 1, 6),
	BackgroundColor3 = COLOR_NEEDLE,
	BorderSizePixel = 0,
	ZIndex = 3,
}, bar)

local function now()
	return workspace:GetServerTimeNow()
end

local function racing()
	return player:GetAttribute("AutoRacing") == true and type(player:GetAttribute("NitroReadyAt")) == "number"
end

-- When the current charge started: the server moves NitroReadyAt on every start, boost and miss
local chargeFrom = now()
player:GetAttributeChangedSignal("NitroReadyAt"):Connect(function()
	chargeFrom = math.max(now(), player:GetAttribute("NitroUntil") or 0)
end)

-- Grade text from the server, shown for a moment after each press
local flashText, flashUntil, flashColor = "", 0, Color3.new(1, 1, 1)
local function flash(text, color, seconds)
	flashText, flashColor, flashUntil = text, color, os.clock() + seconds
end

-- -1..1 bar position -> scale along the bar
local function toScale(position)
	return (math.clamp(position, -1, 1) + 1) / 2
end

-- The zones are drawn at the target of the bar on screen. The server picks the next bar's target the moment a press
-- is graded, so the old zones stay put (beside the press marker) until the next bar is ready.
local shownTarget = nil
local function placeZones(target)
	shownTarget = target
	good.Position = UDim2.fromScale(toScale(target), 0.5)
	perfect.Position = UDim2.fromScale(toScale(target), 0.5)
end
placeZones(0)

local function showMark(position)
	mark.Position = UDim2.fromScale(toScale(position), 0.5)
	mark.Visible = true
end

local function press()
	if not racing() or not gui.Enabled then -- hidden under a panel or the roll showcase: no blind presses
		return
	end
	local readyAt = player:GetAttribute("NitroReadyAt")
	local t = now()
	if t < readyAt or t < (player:GetAttribute("NitroUntil") or 0) then
		return -- not ready: nothing is sent
	end
	showMark(NitroConfig.NeedleAt(t, readyAt)) -- at once; the server's graded position replaces it
	remote:FireServer(t)
end

-- Space / gamepad X / R1 through ContextActionService, one step above Client/CarController's "CarHandbrake" (which
-- sinks Space in the seat so the avatar does not jump out). A key bound there arrives in UserInputService with
-- gameProcessed = true, so it must not be read there. Pass lets the handbrake still see it; ContextActionService
-- never fires while a text box (chat) has focus.
ContextActionService:BindActionAtPriority("NitroPress", function(_, state)
	if state == Enum.UserInputState.Begin then
		press()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Space, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonR1)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return -- a click / tap on another button
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		press() -- a left click on the world
	end
end)
bar.Activated:Connect(press) -- a click or tap on the bar itself is "processed", so it comes here instead

player:GetAttributeChangedSignal("NitroPresses"):Connect(function()
	local pressPos = player:GetAttribute("NitroPressPos")
	if type(pressPos) == "number" then
		showMark(pressPos) -- the position the server graded
	end
	local grade = player:GetAttribute("NitroGrade")
	if grade == "Perfect" then
		flash(("PERFECT! x%.1f"):format(player:GetAttribute("NitroMulti") or 1), COLOR_PERFECT, NitroConfig.DURATION)
	elseif grade == "Good" then
		flash(("NITRO x%.1f"):format(player:GetAttribute("NitroMulti") or 1), COLOR_GOOD, NitroConfig.DURATION)
	else
		flash("MISS", Color3.fromRGB(255, 90, 90), 1)
	end
end)

-- Sit just above the HUD's Speed readout (RacerHud), so the bar never covers it
local speedReadout = nil
local function findSpeedReadout()
	local hud = playerGui:FindFirstChild("RacerHud")
	if not hud then
		return nil
	end
	for _, d in hud:GetDescendants() do
		if d:IsA("GuiObject") and d.Name == "Speed" and d.Visible then
			return d
		end
	end
	return nil
end

local baseFov, kicked = nil, false
local function setFovKick(on)
	local camera = workspace.CurrentCamera
	if not camera or on == kicked then
		return
	end
	if on then
		baseFov = camera.FieldOfView
	end
	kicked = on
	TweenService:Create(camera, TweenInfo.new(on and 0.15 or 0.4), {
		FieldOfView = on and baseFov + FOV_KICK or (baseFov or 70),
	}):Play()
end

-- Like the rest of the HUD, the bar hides while a panel (PanelSwitch) or the roll showcase covers the screen
local function covered()
	if PanelSwitch.AnyOpen() then
		return true
	end
	local showcase = playerGui:FindFirstChild("RollShowcase")
	return showcase ~= nil and showcase:IsA("ScreenGui") and showcase.Enabled
end

RunService.RenderStepped:Connect(function()
	local show = racing()
	local t = now()
	local untilTime = player:GetAttribute("NitroUntil") or 0
	local boosting = show and t < untilTime
	setFovKick(boosting) -- a boost still feels like one under a panel
	gui.Enabled = show and not covered()
	if not gui.Enabled then
		return
	end
	if not (speedReadout and speedReadout.Parent) then
		speedReadout = findSpeedReadout()
	end
	if speedReadout then
		-- AbsolutePosition is measured from below the top bar for every gui (IgnoreGuiInset or not), and this gui
		-- ignores the inset, so a readout's screen Y (this gui's offset space) is AbsolutePosition.Y + inset
		local inset = GuiService:GetGuiInset().Y
		local height = root.Size.Y.Offset
		local speedTop = speedReadout.AbsolutePosition.Y + inset
		local speedBottom = speedTop + speedReadout.AbsoluteSize.Y

		-- Above Speed (desktop): between the compact roll and the readout
		local aboveBottom = speedTop - GAP_ABOVE_SPEED
		local aboveScale = 1
		local rollGui = playerGui:FindFirstChild("RollToast")
		local toast = rollGui and rollGui:FindFirstChild("Toast", true)
		if toast and toast:IsA("GuiObject") then
			local rollBottom = toast.AbsolutePosition.Y + inset + toast.AbsoluteSize.Y + GAP_BELOW_ROLL
			aboveScale = math.min(1, (aboveBottom - rollBottom) / height)
		end
		-- Below Speed (phones, where Speed sits right under the compact roll): down to the LEVEL bar
		local belowTop = speedBottom + GAP_ABOVE_SPEED
		local hud = speedReadout:FindFirstAncestorWhichIsA("ScreenGui")
		local level = hud and hud:FindFirstChild("Level", true)
		local belowLimit = (level and level:IsA("GuiObject") and level.Visible)
				and level.AbsolutePosition.Y + inset - GAP_ABOVE_SPEED
			or gui.AbsoluteSize.Y
		local belowScale = math.min(1, (belowLimit - belowTop) / height)

		if aboveScale >= 1 or aboveScale >= belowScale then
			root.AnchorPoint = Vector2.new(0.5, 1)
			root.Position = UDim2.fromOffset(gui.AbsoluteSize.X / 2, aboveBottom)
			rootScale.Scale = math.clamp(aboveScale, MIN_SCALE, 1)
		else
			root.AnchorPoint = Vector2.new(0.5, 0)
			root.Position = UDim2.fromOffset(gui.AbsoluteSize.X / 2, belowTop)
			rootScale.Scale = math.clamp(belowScale, MIN_SCALE, 1)
		end
	end

	local readyAt = player:GetAttribute("NitroReadyAt")
	local ready = not boosting and t >= readyAt

	-- A new bar: the zones jump to the server's new target and the old press marker goes. Before the first press
	-- (nothing to compare with) the zones simply follow the target.
	local target = player:GetAttribute("NitroTarget")
	target = type(target) == "number" and target or 0
	if (ready or not mark.Visible) and target ~= shownTarget then
		placeZones(target)
	end
	if ready and mark.Visible and os.clock() >= flashUntil then
		mark.Visible = false
	end

	if boosting then
		local left = (untilTime - t) / NitroConfig.DURATION
		charge.Visible, needle.Visible = true, false
		charge.BackgroundColor3 = flashColor
		charge.Size = UDim2.fromScale(math.clamp(left, 0, 1), 1)
	elseif t < readyAt then
		-- Charging (after a boost) or locked (after a miss): the fill grows until the bar is ready
		local total = math.max(readyAt - chargeFrom, 0.001)
		charge.Visible, needle.Visible = true, false
		charge.BackgroundColor3 = COLOR_CHARGE
		charge.Size = UDim2.fromScale(math.clamp(1 - (readyAt - t) / total, 0, 1), 1)
	else
		charge.Visible, needle.Visible = false, true
		needle.Position = UDim2.fromScale((NitroConfig.NeedleAt(t, readyAt) + 1) / 2, 0.5)
	end

	if os.clock() < flashUntil then
		label.Text, label.TextColor3 = flashText, flashColor
	elseif boosting then
		label.Text, label.TextColor3 = "NITRO!", flashColor
	elseif t < readyAt then
		label.Text, label.TextColor3 = "NITRO CHARGING", Color3.fromRGB(200, 210, 255)
	else
		local hint = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and "TAP" or "SPACE"
		label.Text, label.TextColor3 = "NITRO READY: " .. hint, Color3.new(1, 1, 1)
	end
end)
