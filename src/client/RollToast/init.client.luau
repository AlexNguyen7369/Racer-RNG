--!nonstrict
-- The roll animation (docs/ROLL_ANIMATION_CONTRACT.md, design doc "Roll animation"). Every auto-roll result
-- (Remotes.RollResult, decided by the server's GachaService) plays as: pop in -> spin (cars drive through a reel,
-- slowing like a slot reel; fillers are real rolls, never fake near-misses) -> land (the result brakes into the
-- centre, the card pops, smoke) -> hold (longer for rarer cars, with rarity effects) -> exit (the card shrinks and
-- "+ Car" flies to the INDEX button).
--   Compact view (default): RollToast/Toast at top centre directly under the Auto Race button: NO card, only the bare
--   car and its "1 in N" under it (owner, 2026-10-02). Shown only while a roll plays (or while auto-roll is off),
--   hidden only while the enlarged view is open: panels and HUD clicks never touch it.
--   Enlarged view: the full card (name, rarity, Speed multi, odds, NEW / TURBO badges, rarity effects) in the
--   RollShowcase overlay (dimmed + blurred), a big centre card, the AUTO toggle and "Tap anywhere
--   to close". Clicking the compact card opens it; clicking anywhere off the card closes it. An emphasized roll
--   (server flag) opens it by itself and drops back to compact after the roll.
-- Both cards always show the same roll; tests read the Phase / RollId / RollSerial attributes on each card, the
-- View attribute on the RollToast ScreenGui and ReelIds on each Reel.

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared.CarCatalog)
local GachaConfig = require(Shared.GachaConfig)
local HudFormat = require(Shared.HudFormat)
local RollAnimConfig = require(Shared.RollAnimConfig)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local rollRemote = remotes:WaitForChild("RollResult")
local autoRollRemote = remotes:WaitForChild("SetAutoRoll")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))

local A = RollAnimConfig
local SHOWCASE_ORDER = 5 -- above the HUD, below the loser screen (10)
local BLUR_SIZE = 14
local AUTO_BUTTON_SIZE = Vector2.new(180, 44)
local AUTO_BUTTON_BOTTOM = 38 -- keeps the toggle below the card on small phones
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CARD_BG = Color3.fromRGB(20, 28, 48)
local GOLD = Color3.fromRGB(255, 200, 60)
local TURBO_BLUE = Color3.fromRGB(60, 170, 255)
local ITALIC = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Ui = script:WaitForChild("Ui")
task.spawn(function() require(script:WaitForChild("RacerUiController")) end)
local Components = require(Ui.RacerComponents)
local rollRefs = require(Ui.RollShowcase).Bind(playerGui)
rollRefs.Gui.Enabled = false
rollRefs.PreviewCar.Visible = false

local function autoRaceBottom()
	local hud = playerGui:FindFirstChild("RacerHud")
	local outer = hud and hud:FindFirstChild("Race")
	local button = outer and outer:FindFirstChild("Face")
	local inset = GuiService:GetGuiInset()
	return button and (button.AbsolutePosition.Y + button.AbsoluteSize.Y) or 60
end
local rng = Random.new()

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function round(inst, radius)
	return make("UICorner", { CornerRadius = radius }, inst)
end

local function rarityColor(spec)
	return GachaConfig.RARITY_COLORS[spec.Rarity] or WHITE
end

-- Readable text colour for a rarity (Secret is near-black: white text, the colour goes to the outline)
local function textColor(spec)
	return spec.Rarity == "Secret" and WHITE or rarityColor(spec)
end

local function rarityRank(spec)
	return table.find(GachaConfig.RARITY_ORDER, spec.Rarity) or 1
end

local function reduceEffects()
	return player:GetAttribute("ReduceEffects") == true
end

-- Card body ------------------------------------------------------------------------------------------------------
-- Everything inside a card, laid out in fractions of the card so the same body works compact and enlarged.

local function label(name, pos, size, parent, font)
	return make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Position = pos,
		Size = size,
		FontFace = font or BOLD,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "",
		ZIndex = 6,
	}, parent)
end

local ART_POS = rollRefs.PreviewCar.Position
local ART_SIZE = rollRefs.PreviewCar.Size

-- Transparent edge masks work over any world background, without colored covers.
local edgeMasks = setmetatable({}, { __mode = "k" })
local function attachReelFade(object, reel)
    local gradient = make("UIGradient", { Name = "ReelEdgeFade" }, object)
    edgeMasks[object] = { Reel = reel, Gradient = gradient }
end

local function edgeOpacity(x)
    return math.clamp(math.min(x / 0.18, (1 - x) / 0.18), 0, 1)
end

local function updateReelFade(object, binding)
    local width = binding.Reel.AbsoluteSize.X
    local objectWidth = object.AbsoluteSize.X
    if width <= 0 or objectWidth <= 0 then return end
    local left = (object.AbsolutePosition.X - binding.Reel.AbsolutePosition.X) / width
    local span = objectWidth / width
    local samples = { 0, 1 }
    for _, edge in ipairs({ 0, 0.18, 0.82, 1 }) do
        local u = (edge - left) / span
        if u > 0.0001 and u < 0.9999 then table.insert(samples, u) end
    end
    table.sort(samples)
    local keys = {}
    for _, u in ipairs(samples) do
        table.insert(keys, NumberSequenceKeypoint.new(u, 1 - edgeOpacity(left + u * span)))
    end
    binding.Gradient.Transparency = NumberSequence.new(keys)
end

local function buildBody(parent, z)
	local body = rollRefs.CardBody
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.BackgroundTransparency = 0.1
	local stroke = body:FindFirstChildOfClass("UIStroke")

	-- Rarity-coloured badge behind the car, its gradient slowly turning
	local glow = make("Frame", {
		Name = "Glow",
		Position = ART_POS,
		Size = ART_SIZE,
		BackgroundColor3 = WHITE,
		ZIndex = z + 1,
	}, body)
	round(glow, UDim.new(0.3, 0))
	local glowGradient = make("UIGradient", { Name = "Spin" }, glow)

	local ring = make("Frame", {
		Name = "Ring",
		Position = ART_POS,
		Size = ART_SIZE,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z + 2,
	}, body)
	round(ring, UDim.new(0.3, 0))
	local ringStroke = make("UIStroke", { Thickness = 4, Color = WHITE }, ring)

	local burst = make("Frame", {
		Name = "Burst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.24, 0.5),
		Size = UDim2.fromScale(0.5, 0.9),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z,
	}, body)
	round(burst, UDim.new(0.5, 0))
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, burst)

	-- The reel the cars drive through
	local reel = make("Frame", {
		Name = "Reel",
		Position = ART_POS,
		Size = ART_SIZE,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = z + 3,
	}, body)
	local streaks = make("Frame", {
		Name = "Streaks",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z + 3,
	}, reel)
	for i, y in { 0.2, 0.42, 0.68, 0.85 } do
		make("Frame", {
			Name = "Streak" .. i,
			Position = UDim2.fromScale(-1, y),
			Size = UDim2.fromScale(0.6, 0.025),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ZIndex = z + 3,
		}, streaks)
	end
	local smoke = make("Frame", {
		Name = "Smoke",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z + 5,
	}, reel)
	for i, x in { 0.3, 0.5, 0.7 } do
		local puff = make("Frame", {
			Name = "Puff" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.8),
			Size = UDim2.fromScale(0.1, 0.1),
			BackgroundColor3 = Color3.fromRGB(220, 220, 225),
			BackgroundTransparency = 0.3,
			ZIndex = z + 5,
		}, smoke)
		round(puff, UDim.new(0.5, 0))
	end

	-- The landed car: its model when it has one, else "?"
	local viewport = make("Frame", {
		Name = "Viewport",
		Position = ART_POS,
		Size = ART_SIZE,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z + 4,
	}, body)
	local placeholder = label("Placeholder", UDim2.fromScale(0.62, 0.02), UDim2.fromScale(0.36, 0.36), viewport, ITALIC)
	placeholder.Text = "?"
	placeholder.ZIndex = z + 6
	placeholder.TextStrokeTransparency = 0.3

	local flare = make("Frame", {
		Name = "Flare",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.3, 0.5),
		Size = UDim2.fromScale(0.35, 0.18),
		BackgroundColor3 = Color3.fromRGB(255, 250, 220),
		BackgroundTransparency = 0.2,
		Visible = false,
		ZIndex = z + 7,
	}, body)
	round(flare, UDim.new(0.5, 0))

	-- Text column
	local odds = rollRefs.ResultOdds
	local carName = rollRefs.ResultName
	local speedMulti = rollRefs.ResultSpeed
	local rarity = rollRefs.ResultRarity
	for _, text in ipairs({ odds, carName, speedMulti, rarity }) do text.TextScaled = true end

	local function badge(name, text, color, x)
		local b = label(name, UDim2.fromScale(x, 0.065), UDim2.fromScale(0.15, 0.1), body)
		b.BackgroundTransparency = 0
		b.BackgroundColor3 = color
		b.Text = text
		b.Visible = false
		round(b, UDim.new(0, 4))
		return b
	end
	local newBadge = badge("NewBadge", "NEW!", Color3.fromRGB(60, 255, 60), 0.66)
	local turboBadge = badge("TurboBadge", "TURBO", TURBO_BLUE, 0.83)

	local flames = make("Frame", {
		Name = "TurboFlames",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z + 8,
	}, body)
	round(flames, UDim.new(0, 14))
	local flameStroke = make("UIStroke", { Thickness = 5, Color = WHITE }, flames)
	local flameGradient = make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 90, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 230, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 90, 255)),
		}),
	}, flameStroke)

	local autoOff = label("AutoOff", UDim2.fromScale(0.03, 0.78), UDim2.fromScale(0.42, 0.16), body)
	autoOff.Text = "AUTO OFF"
	autoOff.TextStrokeTransparency = 0
	autoOff.Visible = false

	return {
		Body = body,
		Edge = stroke,
		Glow = glow,
		GlowGradient = glowGradient,
		Ring = ring,
		RingStroke = ringStroke,
		Burst = burst,
		Reel = reel,
		Streaks = streaks,
		Smoke = smoke,
		Viewport = viewport,
		Placeholder = placeholder,
		Flare = flare,
		Odds = odds,
		CarName = carName,
		SpeedMulti = speedMulti,
		Rarity = rarity,
		NewBadge = newBadge,
		TurboBadge = turboBadge,
		Flames = flames,
		FlameGradient = flameGradient,
		AutoOff = autoOff,
		Model = nil,
		Z = z,
		Full = true,
	}
end

-- The compact roll: no card, only the bare car (reel, landed model) with its "1 in N" under it
local function buildBare(parent, z)
	local body = make("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	local artSize = UDim2.new(1, 0, 0, A.COMPACT_HEIGHT * 0.7)
	local reel = make("Frame", {
		Name = "Reel",
		Size = artSize,
		Position = UDim2.fromOffset(0, 24),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = z + 3,
	}, body)
	local streaks = make("Frame", {
		Name = "Streaks",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z + 3,
	}, reel)
	for i, y in { 0.25, 0.5, 0.75 } do
		make("Frame", {
			Name = "Streak" .. i,
			Position = UDim2.fromScale(-1, y),
			Size = UDim2.fromScale(0.4, 0.03),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ZIndex = z + 3,
		}, streaks)
	end
	local smoke = make("Frame", {
		Name = "Smoke",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z + 5,
	}, reel)
	for i, x in { 0.38, 0.5, 0.62 } do
		local puff = make("Frame", {
			Name = "Puff" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.85),
			Size = UDim2.fromScale(0.06, 0.1),
			BackgroundColor3 = Color3.fromRGB(220, 220, 225),
			BackgroundTransparency = 0.3,
			ZIndex = z + 5,
		}, smoke)
		round(puff, UDim.new(0.5, 0))
	end
	local viewport = make("Frame", {
		Name = "Viewport",
		Size = artSize,
		Position = UDim2.fromOffset(0, 24),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z + 4,
	}, body)
	local placeholder = label("Placeholder", UDim2.fromScale(0.72, 0), UDim2.fromScale(0.2, 0.4), viewport, ITALIC)
	placeholder.Text = "?"
	placeholder.ZIndex = z + 6
	placeholder.TextStrokeTransparency = 0.3
	local odds = label("Odds", UDim2.fromOffset(0, 24 + A.COMPACT_HEIGHT * 0.7), UDim2.new(1, 0, 0, A.COMPACT_HEIGHT * 0.3), body, ITALIC)
	odds.TextStrokeTransparency = 0.2
	local autoOff = label("AutoOff", UDim2.new(), UDim2.new(1, 0, 0, 20), body)
	autoOff.Text = "AUTO OFF"
	autoOff.Font = Enum.Font.FredokaOne
	autoOff.TextScaled = false
	autoOff.TextSize = 16
	autoOff.TextStrokeTransparency = 1
	make("UIStroke", { Color = BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, autoOff)
	autoOff.Visible = false
	return {
		Body = body,
		Reel = reel,
		Streaks = streaks,
		Smoke = smoke,
		Viewport = viewport,
		Placeholder = placeholder,
		Odds = odds,
		AutoOff = autoOff,
		Model = nil,
		Z = z,
		Full = false,
	}
end

-- A 2D car icon in the rarity colour (the spin uses icons; the result uses the ViewportFrame)
local function carTile(spec, parent, z)
    local tile = Components.CarArt(parent, "Tile_" .. spec.Id, spec.Id, UDim2.fromScale(-0.6, 0.55), UDim2.fromScale(0.96, 0.96))
    tile.AnchorPoint = Vector2.new(0.5, 0.5)
    tile.ZIndex = z
    if parent.Name == "Reel" then attachReelFade(tile, parent) end
    return tile
end

-- Compact card --------------------------------------------------------------------------------------------------

local gui = make("ScreenGui", { Name = "RollToast", ResetOnSpawn = false }, playerGui)
gui:SetAttribute("View", "Compact")

local toast = make("TextButton", {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, autoRaceBottom() + A.COMPACT_GAP),
	Size = UDim2.new(A.COMPACT_WIDTH, 0, 0, A.COMPACT_HEIGHT + 24),
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
}, gui)
make("UISizeConstraint", {
	MinSize = Vector2.new(A.COMPACT_MIN, A.COMPACT_HEIGHT + 24),
	MaxSize = Vector2.new(A.COMPACT_MAX, A.COMPACT_HEIGHT + 24),
}, toast)
local compact = buildBare(toast, 2)

local flyIcon = make("Frame", {
	Name = "FlyIcon",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(52, 30),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 20,
}, gui)

-- Enlarged view -------------------------------------------------------------------------------------------------

local showcase = rollRefs.Gui
showcase.DisplayOrder = SHOWCASE_ORDER
showcase.Enabled = false

-- Anywhere off the card: close
local backdrop = make("TextButton", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(8, 10, 20),
	BackgroundTransparency = 0.35,
	AutoButtonColor = false,
	Text = "",
}, showcase)
make("TextLabel", {
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(320, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(200, 210, 230),
	Text = "Tap anywhere to close",
}, backdrop)

-- The card (Active: clicks on it do not close). About 3x the compact card, above the AUTO button on a phone too.
local card = rollRefs.Card
card.Active = true
card.ZIndex = 2
local CARD_POS = card.Position
local CARD_SIZE = card.Size
local enlarged = buildBody(card, 3)

local autoButton = make("TextButton", {
	Name = "AutoButton",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -AUTO_BUTTON_BOTTOM),
	Size = UDim2.fromOffset(AUTO_BUTTON_SIZE.X, AUTO_BUTTON_SIZE.Y),
	FontFace = BOLD,
	TextSize = 22,
	TextColor3 = WHITE,
	AutoButtonColor = true,
	ZIndex = 4,
}, showcase)
round(autoButton, UDim.new(0, 12))
make("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = CARD_BG }, autoButton)

local takeover = make("Frame", {
	Name = "Takeover",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(5, 5, 8),
	BackgroundTransparency = 0.15,
	Visible = false,
	ZIndex = 10,
}, showcase)
local takeoverStroke = make("UIStroke", { Thickness = 10, Color = WHITE }, takeover)
local rainbow = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 255, 120)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 140, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 60, 255)),
	}),
}, takeoverStroke)
local takeoverText = make("TextLabel", {
	Name = "Title",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromScale(0.8, 0.2),
	BackgroundTransparency = 1,
	FontFace = ITALIC,
	TextScaled = true,
	TextColor3 = WHITE,
	ZIndex = 11,
}, takeover)
make("TextLabel", {
	Name = "Skip",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.62),
	Size = UDim2.fromOffset(320, 24),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(200, 210, 230),
	Text = "Tap to skip",
	ZIndex = 11,
}, takeover)

local blur = Lighting:FindFirstChild("RollShowcaseBlur")
if not blur then
	blur = make("BlurEffect", { Name = "RollShowcaseBlur", Size = BLUR_SIZE }, Lighting)
end
blur.Enabled = false

local bodies = { compact, enlarged }
local cards = { toast, card }

-- State ---------------------------------------------------------------------------------------------------------

local latest = nil -- { Spec, IsNew, Turbo, Emphasized } of the roll playing or last played
local serial = 0 -- RollResults received
local phase = "Idle"
local tweens = {} -- running tweens of the current roll (cancelled when a new roll starts)
local autoOpened = false -- the enlarged view was opened by an emphasized roll, not by the player
local switchStamp = 0

for _, b in ipairs(bodies) do
    for _, streak in ipairs(b.Streaks:GetChildren()) do
        attachReelFade(streak, b.Reel)
    end
end
RunService.RenderStepped:Connect(function()
    if phase ~= "Spin" and phase ~= "Land" then return end
    for object, binding in pairs(edgeMasks) do
        if object.Parent then updateReelFade(object, binding) end
    end
end)

local function setAttr(name, value)
	for _, c in cards do
		c:SetAttribute(name, value)
	end
end
setAttr("Phase", "Idle")
setAttr("RollSerial", 0)

local function tween(inst, seconds, props, style, direction)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	table.insert(tweens, t)
	t:Play()
	return t
end

local function cancelTweens()
	for _, t in tweens do
		t:Cancel()
	end
	table.clear(tweens)
end

local function autoRollOn()
	return player:GetAttribute("AutoRoll") ~= false
end

local function isEnlarged()
	return gui:GetAttribute("View") == "Enlarged"
end

-- The compact roll shows while a roll plays in the compact view, or while auto-roll is off (it is then the way
-- into the enlarged view and its AUTO button); hidden only while the enlarged view is open. Panels and HUD clicks
-- never touch it (owner, 2026-10-02): the panels start below it instead.
local function refreshToast()
	local playing = phase ~= "Idle"
	local show = (playing or not autoRollOn()) and not isEnlarged()
	toast.Visible = show
	compact.AutoOff.Visible = not autoRollOn()
	if show and not playing then
		compact.Body.Size = UDim2.fromScale(1, 1)
		if not latest then
			compact.Odds.Text = "?"
			compact.Viewport.Visible = true
		end
	end
end

local function setPhase(name)
	phase = name
	setAttr("Phase", name)
	refreshToast()
end

-- Card contents -------------------------------------------------------------------------------------------------

local function showModel(b, spec)
    if b.Model then b.Model:Destroy() end
    local art = carTile(spec, b.Viewport, b.Z + 4)
    art.Position = UDim2.fromScale(0.5, 0.5)
    art.Size = UDim2.fromScale(1, 1)
    b.Model = art
    b.Placeholder.Visible = false
    return true
end

-- The card before the spin: rarity unknown, plain frame, turbo flames + badge on a turbo roll
local function resetBody(b, roll)
	for _, child in b.Reel:GetChildren() do
		if child.Name:sub(1, 5) == "Tile_" then
			child:Destroy()
		end
	end
	b.Viewport.Visible = false
	b.Smoke.Visible = false
	b.Streaks.Visible = true
	b.Odds.Text = "?"
	b.Odds.TextColor3 = WHITE
	b.AutoOff.Visible = false
	if b.Full then
		b.Edge.Color = WHITE
		b.Glow.BackgroundColor3 = Color3.fromRGB(60, 70, 95)
		b.GlowGradient.Color = ColorSequence.new(WHITE)
		b.Ring.Visible = false
		b.Burst.Visible = false
		b.Flare.Visible = false
		b.CarName.Text = ""
		b.CarName.TextColor3 = Color3.fromRGB(170, 180, 200)
		b.SpeedMulti.Text = ""
		b.Rarity.Text = ""
		b.NewBadge.Visible = false
		local turbo = roll.Turbo > 1
		b.TurboBadge.Visible = turbo
		b.TurboBadge.Text = "TURBO x" .. tostring(roll.Turbo)
		b.Flames.Visible = turbo
	end
	b.Body.Position = UDim2.fromScale(0.5, 0.5)
end

-- The landed result's text, colours and art
local function fillResult(b, roll)
	-- Replace the spinning sprites with the usual landed car icon.
	for _, child in ipairs(b.Reel:GetChildren()) do
		if child.Name:sub(1, 5) == "Tile_" then child.Visible = false end
	end
	local spec = roll.Spec
	local color = rarityColor(spec)
	b.Odds.Text = spec.Chance and HudFormat.Odds(spec.Chance) or "Common"
	b.Odds.TextColor3 = rarityRank(spec) >= 5 and GOLD or textColor(spec)
	b.Viewport.Visible = true
	if b.Full then
		b.Edge.Color = color
		Components.Tint(rollRefs.RollHeader, color)
		b.Glow.BackgroundColor3 = color:Lerp(CARD_BG, 0.8)
		b.GlowGradient.Color = ColorSequence.new(CARD_BG:Lerp(color, 0.15), CARD_BG)
		b.CarName.Text = spec.Name
		b.CarName.TextColor3 = WHITE
		b.SpeedMulti.Text = "x" .. tostring(spec.SpeedMulti or 1) .. " SPEED MULTIPLIER"
		b.Rarity.Text = spec.Rarity
		b.Rarity.TextColor3 = textColor(spec)
		b.Rarity.TextStrokeColor3 = spec.Rarity == "Secret" and color or BLACK
		b.Rarity.TextStrokeTransparency = spec.Rarity == "Secret" and 0 or 0.4
		b.NewBadge.Visible = roll.IsNew
	end
	showModel(b, spec)
end

-- Views ---------------------------------------------------------------------------------------------------------

local function openEnlarged(auto)
	if isEnlarged() then
		return
	end
	autoOpened = auto == true
	PanelSwitch.Close("Index")
	PanelSwitch.Close("Stats")
	PanelSwitch.Close("Settings")
	PanelSwitch.Close("Rebirth")
	gui:SetAttribute("View", "Enlarged")
	backdrop.Visible = true
	autoButton.Visible = true
	showcase.Enabled = true
	blur.Enabled = true
	refreshToast()
	-- Grow from where the compact card is to the centre, with a slight overshoot
	local stamp = os.clock()
	switchStamp = stamp
	local inset = GuiService:GetGuiInset()
	local from = toast.AbsolutePosition + inset + toast.AbsoluteSize / 2
	card.Position = UDim2.fromOffset(from.X, from.Y)
	card.Size = UDim2.fromOffset(toast.AbsoluteSize.X, toast.AbsoluteSize.Y)
	local info = TweenInfo.new(A.SWITCH, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(card, info, { Position = CARD_POS, Size = CARD_SIZE }):Play()
end

local function closeEnlarged()
	if not isEnlarged() then
		return
	end
	autoOpened = false
	takeover.Visible = false
	local stamp = os.clock()
	switchStamp = stamp
	gui:SetAttribute("View", "Compact")
	blur.Enabled = false
	-- The reverse: shrink back towards the compact card's place, then hide
	local inset = GuiService:GetGuiInset()
	local to = Vector2.new(
		card.AbsolutePosition.X + card.AbsoluteSize.X / 2,
		autoRaceBottom() + A.COMPACT_GAP + A.COMPACT_HEIGHT / 2 + inset.Y
	)
	local info = TweenInfo.new(A.SWITCH, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	TweenService:Create(card, info, {
		Position = UDim2.fromOffset(to.X, to.Y),
		Size = UDim2.fromOffset(card.AbsoluteSize.X / A.ENLARGED_FACTOR, A.COMPACT_HEIGHT),
	}):Play()
	backdrop.Visible = false
	autoButton.Visible = false
	task.delay(A.SWITCH, function()
		if switchStamp == stamp then
			showcase.Enabled = false
			backdrop.Visible = true
			autoButton.Visible = true
			card.Position = CARD_POS
			card.Size = CARD_SIZE
			refreshToast()
		end
	end)
	refreshToast()
end

-- The roll sequence -----------------------------------------------------------------------------------------------

-- Splits the spin between the filler cars, each slower than the last (slot-reel slow-down)
local function spinTimes(count)
	local weights, sum = {}, 0
	for i = 1, count do
		weights[i] = 1.2 ^ (i - 1)
		sum += weights[i]
	end
	for i = 1, count do
		weights[i] = weights[i] / sum * A.SPIN
	end
	return weights
end

local function shake(b, mySerial)
	if reduceEffects() then
		return
	end
	task.spawn(function()
		-- Short enough to settle inside LAND: the card is still at Hold
		for i = 1, 4 do
			if serial ~= mySerial then
				return
			end
			local m = (5 - i) / 4
			b.Body.Position = UDim2.new(0.5, rng:NextInteger(-4, 4) * m, 0.5, rng:NextInteger(-3, 3) * m)
			task.wait(0.03)
		end
		b.Body.Position = UDim2.fromScale(0.5, 0.5)
	end)
end

-- Landing extras by rarity (design doc "Effects by rarity")
local function landEffects(b, roll, mySerial)
	local spec = roll.Spec
	local rank = rarityRank(spec)
	local color = rarityColor(spec)
	local flashes = not reduceEffects()
	b.Smoke.Visible = true
	for _, puff in b.Smoke:GetChildren() do
		puff.Size = UDim2.fromScale(0.1, 0.1)
		puff.BackgroundTransparency = 0.3
		tween(puff, 0.45, { Size = UDim2.fromScale(0.32, 0.32), BackgroundTransparency = 1 })
	end
	if rank >= 3 then -- Rare: brighter streaks
		b.Streaks.Visible = true
		for _, s in b.Streaks:GetChildren() do
			s.BackgroundTransparency = 0
			s.Position = UDim2.fromScale(-0.6, s.Position.Y.Scale)
			tween(s, 0.35, { Position = UDim2.fromScale(1.1, s.Position.Y.Scale), BackgroundTransparency = 0.6 })
		end
	end
	if not b.Full then
		return -- the compact roll has no card: smoke and streaks only
	end
	if rank >= 4 then -- Epic: pulsing ring
		b.Ring.Visible = true
		b.RingStroke.Color = color
		b.RingStroke.Transparency = 0
		local pulse = TweenService:Create(
			b.RingStroke,
			TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.8 }
		)
		table.insert(tweens, pulse)
		pulse:Play()
	end
	if rank >= 5 and flashes then -- Legendary: radial gold burst and a light shake
		b.Burst.Visible = true
		b.Burst.Size = UDim2.fromScale(0.3, 0.5)
		b.Burst.BackgroundTransparency = 0.1
		tween(b.Burst, 0.6, { Size = UDim2.fromScale(1.4, 2.2), BackgroundTransparency = 1 })
	end
	if rank >= 5 then
		shake(b, mySerial)
	end
	if rank >= 6 and flashes then -- Mythic: a headlight flare across the card
		b.Flare.Visible = true
		b.Flare.Position = UDim2.fromScale(-0.3, 0.5)
		tween(b.Flare, 0.5, { Position = UDim2.fromScale(1.3, 0.5) }, Enum.EasingStyle.Sine)
	end
	if spec.Rarity == "Secret" and isEnlarged() and b == enlarged then -- Secret: full-screen takeover
		takeoverText.Text = "SECRET\n" .. spec.Name
		takeover.Visible = true
	end
end

local function flyToIndex(spec)
	local indexGui = playerGui:FindFirstChild("RacerHud")
	local navigation = indexGui and indexGui:FindFirstChild("Navigation")
	local wrapper = navigation and navigation:FindFirstChild("Index")
	local target = wrapper and wrapper:FindFirstChild("Face")
	if not target or not target.Visible then
		return
	end
	local inset = GuiService:GetGuiInset()
	local from = isEnlarged() and (card.AbsolutePosition - inset + card.AbsoluteSize / 2)
		or (toast.AbsolutePosition + toast.AbsoluteSize / 2)
	local to = target.AbsolutePosition + target.AbsoluteSize / 2
	flyIcon:ClearAllChildren()
	local icon = carTile(spec, flyIcon, 21)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(1, 1)
	flyIcon.Position = UDim2.fromOffset(from.X, from.Y)
	flyIcon.Visible = true
	-- Lands inside Exit and rests on the button until Phase "Idle" hides it (contract: flies to OpenIndex, then
	-- Idle), easing out so the player sees it arrive instead of vanishing on the way.
	tween(
		flyIcon,
		A.EXIT * 0.7,
		{ Position = UDim2.fromOffset(to.X, to.Y) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
end

local function play(roll)
	serial += 1
	local mySerial = serial
	cancelTweens()
	flyIcon.Visible = false
	takeover.Visible = false
	latest = roll
	local spec = roll.Spec
	setAttr("RollSerial", mySerial)
	setAttr("RollId", spec.Id)

	local function alive()
		return serial == mySerial
	end
	local function after(seconds)
		task.wait(seconds)
		return alive()
	end

	local reelIds = A.Reel(rng, spec.Id)
	for _, b in bodies do
		resetBody(b, roll)
		b.Reel:SetAttribute("ReelIds", table.concat(reelIds, ","))
	end
	if roll.Emphasized and not isEnlarged() then
		openEnlarged(true)
	end

	-- Pop in: the card grows from nothing and fades in
	setPhase("PopIn")
	for _, b in bodies do
		b.Body.Size = UDim2.fromScale(0, 0)
		local goal = { Size = UDim2.fromScale(1, 1) }
		if b.Full then
			b.Body.BackgroundTransparency = 1
			goal.BackgroundTransparency = 0.1
		end
		tween(b.Body, A.POP, goal, Enum.EasingStyle.Back)
	end
	if not after(A.POP) then
		return
	end

	-- Spin: the filler cars drive through left to right, each slower than the last; streaks rush past
	setPhase("Spin")
	local times = spinTimes(#reelIds - 1)
	local tiles = {}
	for _, b in bodies do
		tiles[b] = {}
		for i, id in reelIds do
			tiles[b][i] = carTile(CarCatalog.Get(id) or spec, b.Reel, b.Z + 4)
		end
		for _, s in b.Streaks:GetChildren() do
			s.BackgroundTransparency = 0.4
			s.Position = UDim2.fromScale(-0.6, s.Position.Y.Scale)
			local loop = TweenService:Create(
				s,
				TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
				{ Position = UDim2.fromScale(1.1, s.Position.Y.Scale) }
			)
			table.insert(tweens, loop)
			loop:Play()
		end
	end
	for i = 1, #reelIds - 1 do
		local passing = CarCatalog.Get(reelIds[i])
		for _, b in bodies do
			if b.Full then
				b.CarName.Text = passing and passing.Name or ""
			end
			tween(tiles[b][i], times[i], { Position = UDim2.fromScale(1.6, 0.55) }, Enum.EasingStyle.Linear)
		end
		if not after(times[i]) then
			return
		end
	end

	-- Land: the result brakes into the centre with a small skid, the card pops to LAND_POP and settles
	setPhase("Land")
	for _, b in bodies do
		b.Streaks.Visible = false
		local tile = tiles[b][#reelIds]
		tween(tile, A.LAND, { Position = UDim2.fromScale(0.5, 0.55) }, Enum.EasingStyle.Quart)
		fillResult(b, roll)
		b.Body.Size = UDim2.fromScale(A.LAND_POP, A.LAND_POP)
		tween(b.Body, A.LAND, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
		landEffects(b, roll, mySerial)
	end
	if not after(A.LAND) then
		return
	end

	-- Hold: the result stays, longer for rarer cars
	setPhase("Hold")
	if not after(A.Hold(spec.Rarity)) then
		return
	end
	takeover.Visible = false

	-- Exit: the compact roll shrinks away, a small car icon flies to the INDEX button (the Garage, once it exists)
	setPhase("Exit")
	flyToIndex(spec)
	if not isEnlarged() then
		tween(
			compact.Body,
			A.EXIT,
			{ Size = UDim2.fromScale(0, 0), BackgroundTransparency = 1 },
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		)
	end
	if not after(A.EXIT) then
		return
	end
	flyIcon.Visible = false
	setPhase("Idle")
	if roll.Emphasized and autoOpened then
		closeEnlarged()
	end
end

-- Inputs --------------------------------------------------------------------------------------------------------

local function refreshAutoButton()
	local on = autoRollOn()
	autoButton.Text = on and "AUTO: ON" or "AUTO: OFF"
	autoButton.BackgroundColor3 = on and Color3.fromRGB(60, 255, 60) or Color3.fromRGB(104, 111, 135)
	refreshToast()
end
player:GetAttributeChangedSignal("AutoRoll"):Connect(refreshAutoButton)
refreshAutoButton()

autoButton.Activated:Connect(function()
	autoRollRemote:FireServer(not autoRollOn())
end)

toast.Activated:Connect(function()
	openEnlarged(false)
end)

-- A click on the card or the AUTO button does not close: an Active frame does not stop the backdrop button under it
-- from firing, so the backdrop ignores presses inside them (the showcase ignores the GUI inset: both use screen
-- pixels)
local function over(gobj)
	local p = UserInputService:GetMouseLocation()
	local a, size = gobj.AbsolutePosition, gobj.AbsoluteSize
	return p.X >= a.X and p.X <= a.X + size.X and p.Y >= a.Y and p.Y <= a.Y + size.Y
end
backdrop.Activated:Connect(function()
	if takeover.Visible then
		takeover.Visible = false -- tap to skip the Secret takeover
		return
	end
	if not over(card) and not over(autoButton) then
		closeEnlarged()
	end
end)

-- The glows slowly turn; the turbo flames and the Secret rainbow flicker
RunService.RenderStepped:Connect(function(dt)
	enlarged.GlowGradient.Rotation = (enlarged.GlowGradient.Rotation + dt * 60) % 360
	if enlarged.Flames.Visible then
		enlarged.FlameGradient.Offset = Vector2.new(math.sin(os.clock() * 9) * 0.3, 0)
	end
	if takeover.Visible then
		rainbow.Rotation = (rainbow.Rotation + dt * 120) % 360
	end
end)

rollRemote.OnClientEvent:Connect(function(id, isNew, turboMulti, emphasized)
	local spec = CarCatalog.Get(id)
	if not spec then
		return
	end
	task.spawn(play, {
		Spec = spec,
		IsNew = isNew == true,
		Turbo = (type(turboMulti) == "number" and turboMulti > 1) and turboMulti or 1,
		Emphasized = emphasized == true,
	})
end)

-- Shared entry point for the bottom-right ROLLS button; it opens the existing view, not a free roll.
local openRollView = make("BindableEvent", { Name = "OpenRollView" }, gui)
openRollView.Event:Connect(function() openEnlarged(false) end)
local function fitCompact()
	toast.Position = UDim2.new(0.5, 0, 0, autoRaceBottom() + A.COMPACT_GAP)
end
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitCompact) end
local hud = playerGui:WaitForChild("RacerHud")
local race = hud:WaitForChild("Race"):WaitForChild("Face")
race:GetPropertyChangedSignal("AbsolutePosition"):Connect(fitCompact)
race:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCompact)
fitCompact()
-- Match the saved responsive card and the same large artwork on each device.
local function fitRollArt()
    CARD_POS = card.Position
    CARD_SIZE = card.Size
    for _, object in ipairs({ enlarged.Glow, enlarged.Ring, enlarged.Reel, enlarged.Viewport }) do
        object.Position = rollRefs.PreviewCar.Position
        object.Size = rollRefs.PreviewCar.Size
    end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.defer(fitRollArt) end)
fitRollArt()
autoButton.Font = Enum.Font.FredokaOne
autoButton:FindFirstChildOfClass("UIStroke").Thickness = 3
fillResult(enlarged, { Spec = CarCatalog.Get("rusty_hatchback"), IsNew = false, Turbo = 1 })
fillResult(compact, { Spec = CarCatalog.Get("rusty_hatchback"), IsNew = false, Turbo = 1 })
