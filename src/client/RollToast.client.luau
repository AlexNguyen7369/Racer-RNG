--!nonstrict
-- Each auto-roll result (Remotes.RollResult, fired by the server's GachaService) pops up as a toast above the TURBO
-- LUCK bar: the car's name in its rarity colour, "NEW!" the first time it enters the index. Clicking the toast
-- enlarges it into the roll showcase (docs/SPAWN_AND_ROLLS_SPEC.md): a dimmed, blurred screen with one big card
-- that shows every roll as it happens (the car, "?" until it has a model, its odds, name, rarity and speed multi).
-- Clicking anywhere off the card closes it. The toast never shows while a panel or the showcase is open.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared.CarCatalog)
local GachaConfig = require(Shared.GachaConfig)
local HudFormat = require(Shared.HudFormat)
local rollRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RollResult")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))

local SHOW_SECONDS = 1.6
local FADE_SECONDS = 0.3
local TOAST_BOTTOM = 62 -- px from the screen bottom: above Client/RollUi's TURBO LUCK bar and its pop text
local SHOWCASE_ORDER = 5 -- above the HUD, below the loser screen (10)
local BLUR_SIZE = 14
local WHITE = Color3.new(1, 1, 1)
local CARD_BG = Color3.fromRGB(20, 28, 48)
local TURBO_COLOR = Color3.fromRGB(255, 170, 40)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function round(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
end

local function rarityColor(spec)
	return GachaConfig.RARITY_COLORS[spec.Rarity] or WHITE
end

local function oddsText(spec)
	return spec.Chance and HudFormat.Odds(spec.Chance) or "Common"
end

-- Toast ---------------------------------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "RollToast"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local toast = Instance.new("TextButton")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -TOAST_BOTTOM)
toast.Size = UDim2.fromOffset(320, 44)
toast.BackgroundColor3 = CARD_BG
toast.BackgroundTransparency = 0.15
toast.AutoButtonColor = true
toast.Font = Enum.Font.GothamBlack
toast.TextSize = 20
toast.Visible = false
toast.Parent = gui
round(toast, 12)
local stroke = Instance.new("UIStroke")
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Thickness = 2
stroke.Parent = toast

-- Showcase ------------------------------------------------------------------------------------------------------

local showcase = Instance.new("ScreenGui")
showcase.Name = "RollShowcase"
showcase.ResetOnSpawn = false
showcase.IgnoreGuiInset = true
showcase.DisplayOrder = SHOWCASE_ORDER
showcase.Enabled = false
showcase.Parent = playerGui

-- Anywhere off the card: close
local backdrop = Instance.new("TextButton")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(8, 10, 20)
backdrop.BackgroundTransparency = 0.35
backdrop.AutoButtonColor = false
backdrop.Text = ""
backdrop.Parent = showcase

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -48) -- clear of the TURBO LUCK bar under the backdrop
hint.Size = UDim2.fromOffset(320, 20)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamBold
hint.TextSize = 14
hint.TextColor3 = Color3.fromRGB(200, 210, 230)
hint.Text = "Tap anywhere to close"
hint.Parent = backdrop

-- The card (Active: clicks on it do not reach the backdrop)
local card = Instance.new("Frame")
card.Name = "Card"
card.Active = true
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(0, 300, 0.8, 0)
card.BackgroundColor3 = CARD_BG
card.BackgroundTransparency = 0.1
card.ZIndex = 2
card.Parent = showcase
round(card, 18)
local cardLimit = Instance.new("UISizeConstraint")
cardLimit.MaxSize = Vector2.new(300, 400)
cardLimit.Parent = card
local cardStroke = Instance.new("UIStroke")
cardStroke.Thickness = 3
cardStroke.Parent = card

-- A label placed by fractions of the card's height, so the card fits a phone in landscape too
local function line(name, top, height, font, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, 12, top, 0)
	l.Size = UDim2.new(1, -24, height, 0)
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.ZIndex = 3
	l.Parent = card
	return l
end

local viewport = Instance.new("ViewportFrame")
viewport.Name = "Viewport"
viewport.Position = UDim2.new(0, 12, 0.03, 0)
viewport.Size = UDim2.new(1, -24, 0.46, 0)
viewport.BackgroundColor3 = Color3.fromRGB(30, 38, 62)
viewport.ZIndex = 3
viewport.Parent = card
round(viewport, 12)
local placeholder = Instance.new("TextLabel")
placeholder.Name = "Placeholder"
placeholder.AnchorPoint = Vector2.new(0.5, 0.5)
placeholder.Position = UDim2.fromScale(0.5, 0.5)
placeholder.Size = UDim2.fromScale(1, 0.76)
placeholder.BackgroundTransparency = 1
placeholder.Font = Enum.Font.GothamBlack
placeholder.TextScaled = true
placeholder.Text = "?"
placeholder.TextColor3 = WHITE
placeholder.TextTransparency = 0.2
placeholder.ZIndex = 4
placeholder.Parent = viewport

local odds = line("Odds", 0.51, 0.1, Enum.Font.GothamBlack, WHITE)
local carName = line("CarName", 0.62, 0.1, Enum.Font.GothamBlack, WHITE)
local rarity = line("Rarity", 0.73, 0.07, Enum.Font.GothamBold, WHITE)
local speedMulti = line("SpeedMulti", 0.8, 0.07, Enum.Font.GothamBold, Color3.fromRGB(200, 210, 230))

local function badge(name, str, color, x)
	local b = Instance.new("TextLabel")
	b.Name = name
	b.AnchorPoint = Vector2.new(x, 0)
	b.Position = UDim2.new(x, x == 0 and 12 or -12, 0.89, 0)
	b.Size = UDim2.fromScale(0.4, 0.07)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = WHITE
	b.Text = str
	b.Visible = false
	b.ZIndex = 3
	b.Parent = card
	round(b, 6)
	return b
end
local newBadge = badge("NewBadge", "NEW!", Color3.fromRGB(60, 180, 90), 0)
local turboBadge = badge("TurboBadge", "TURBO", TURBO_COLOR, 1)

local blur = Lighting:FindFirstChild("RollShowcaseBlur")
if not blur then
	blur = Instance.new("BlurEffect")
	blur.Name = "RollShowcaseBlur"
	blur.Size = BLUR_SIZE
	blur.Parent = Lighting
end
blur.Enabled = false

local shownModel = nil

-- The car's model in the viewport when it has one (ReplicatedStorage.CarModels[spec.Model]), else the "?"
local function showArt(spec)
	if shownModel then
		shownModel:Destroy()
		shownModel = nil
	end
	local models = ReplicatedStorage:FindFirstChild("CarModels")
	local source = type(spec.Model) == "string" and models and models:FindFirstChild(spec.Model)
	if source and source:IsA("Model") then
		shownModel = source:Clone()
		shownModel.Parent = viewport
		local camera = viewport.CurrentCamera or Instance.new("Camera")
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local cf, size = shownModel:GetBoundingBox()
		local dist = size.Magnitude * 0.9
		camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.7, dist * 0.45, dist * 0.7), cf.Position)
		placeholder.Visible = false
	else
		placeholder.Visible = true
	end
end

local latest = nil -- { Spec, IsNew, Turbo } of the last roll

local function fillCard()
	if not latest then
		return
	end
	local spec = latest.Spec
	local color = rarityColor(spec)
	cardStroke.Color = color
	odds.Text = oddsText(spec)
	odds.TextColor3 = spec.Rarity == "Secret" and WHITE or color
	carName.Text = spec.Name
	rarity.Text = spec.Rarity
	rarity.TextColor3 = spec.Rarity == "Secret" and WHITE or color
	rarity.TextStrokeColor3 = spec.Rarity == "Secret" and color or Color3.new(0, 0, 0)
	speedMulti.Text = "Speed x" .. tostring(spec.SpeedMulti or 1)
	newBadge.Visible = latest.IsNew == true
	turboBadge.Visible = latest.Turbo > 1
	turboBadge.Text = "TURBO x" .. tostring(latest.Turbo)
	showArt(spec)
end

-- Toast and showcase state ----------------------------------------------------------------------------------------

local shownAt = 0

local function hideToast()
	shownAt = 0
	toast.Visible = false
end

local function openShowcase()
	if not latest then
		return
	end
	hideToast()
	PanelSwitch.Close("Index")
	PanelSwitch.Close("Stats")
	fillCard()
	showcase.Enabled = true
	blur.Enabled = true
end

local function closeShowcase()
	showcase.Enabled = false
	blur.Enabled = false
end

PanelSwitch.Changed:Connect(function()
	if PanelSwitch.AnyOpen() then
		hideToast()
	end
end)

toast.Activated:Connect(openShowcase)
-- A click on the card does not close: an Active frame does not stop the backdrop button under it from firing, so
-- the backdrop ignores presses inside the card (the showcase ignores the GUI inset, so both use screen pixels)
local function overCard()
	local p = UserInputService:GetMouseLocation()
	local a, size = card.AbsolutePosition, card.AbsoluteSize
	return p.X >= a.X and p.X <= a.X + size.X and p.Y >= a.Y and p.Y <= a.Y + size.Y
end
backdrop.Activated:Connect(function()
	if not overCard() then
		closeShowcase()
	end
end)

rollRemote.OnClientEvent:Connect(function(id, isNew, turboMulti)
	local spec = CarCatalog.Get(id)
	if not spec then
		return
	end
	latest = {
		Spec = spec,
		IsNew = isNew == true,
		Turbo = (type(turboMulti) == "number" and turboMulti > 1) and turboMulti or 1,
	}
	if showcase.Enabled then
		fillCard() -- live: the open showcase always shows the current roll
		return
	end
	if PanelSwitch.AnyOpen() then
		return
	end
	local color = rarityColor(spec)
	toast.Text = (isNew and "NEW! " or "") .. spec.Name .. "  ·  " .. spec.Rarity
	toast.TextColor3 = spec.Rarity == "Secret" and WHITE or color
	stroke.Color = color
	toast.BackgroundTransparency, toast.TextTransparency, stroke.Transparency = 0.15, 0, 0
	toast.Visible = true
	local stamp = os.clock()
	shownAt = stamp
	task.delay(SHOW_SECONDS, function()
		if shownAt ~= stamp then
			return
		end
		local info = TweenInfo.new(FADE_SECONDS)
		TweenService:Create(toast, info, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		task.delay(FADE_SECONDS, function()
			if shownAt == stamp then
				hideToast() -- faded out: no invisible hitbox left behind
			end
		end)
	end)
end)
