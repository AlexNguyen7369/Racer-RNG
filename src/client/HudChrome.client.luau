--!nonstrict
-- HUD entry points (docs/HUD_LAYOUT_SPEC.md): the left 2 x 3 icon grid and the top-right Daily / Quests / Market
-- pills with the round Settings button. Each entry only opens a panel; the panels' scripts own everything else.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local client = script.Parent
local PanelSwitch = require(client:WaitForChild("PanelSwitch"))
local Icons = require(client:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))

local OUTLINE = Color3.fromRGB(17, 19, 31)
local RED = Color3.fromRGB(232, 60, 76)
local TILE = 72
local LABEL = 22

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function outlined(label, thickness)
	make(
		"UIStroke",
		"Outline",
		label,
		{ Color = OUTLINE, Thickness = thickness, LineJoinMode = Enum.LineJoinMode.Round }
	)
	return label
end

local function icon(name, parent, props)
	local art = Icons[name]
	props.Image = art.Image
	props.BackgroundTransparency = 1
	props.ScaleType = Enum.ScaleType.Fit
	if art.Offset then
		props.ImageRectOffset, props.ImageRectSize = art.Offset, art.Size
	end
	return make("ImageLabel", "Icon", parent, props)
end

local function badge(parent)
	local b = make("TextLabel", "Badge", parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = RED,
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Visible = false,
		ZIndex = 4,
	})
	make("UICorner", "Corner", b, { CornerRadius = UDim.new(1, 0) })
	make(
		"UIStroke",
		"Ring",
		b,
		{ Color = Color3.new(1, 1, 1), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
	)
	return b
end

local root = make("ScreenGui", "HudChrome", gui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 1,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
-- Owner 2026-10-20 (HUD_LAYOUT_SPEC section 6): an open panel dims only the world. The dim layer sits below
-- every HUD ScreenGui (DisplayOrder 0), so the HUD entries stay bright and clickable over it.
local worldDim = make("ScreenGui", "PanelDim", gui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 0,
	Enabled = false,
})
make("Frame", "Dim", worldDim, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(8, 10, 18),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	Active = false,
	Selectable = false,
})

local function setHudDimmed(dimmed)
	worldDim.Enabled = dimmed
end

-- Icon tiles -----------------------------------------------------------------------------------------------------
local PANEL =
	{ Shop = "Shop", Items = "Backpack", Index = "Index", Upgrade = "Upgrades", Stats = "Stats", Rebirth = "Rebirth" }
local CELL = Vector2.new(TILE + 12, TILE + LABEL)
local scales = {}
-- A transparent holder with a vertical list of tiles; its UIScale shrinks it on phones.
local function holder(name, count, props)
	props.Size = UDim2.fromOffset(CELL.X, count * CELL.Y + (count - 1) * 8)
	props.BackgroundTransparency = 1
	local frame = make("Frame", name, root, props)
	table.insert(scales, make("UIScale", "Scale", frame, {}))
	make("UIListLayout", "Layout", frame, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	return frame
end
local grid = holder("Grid", 3, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, -24) })
local shopColumn =
	holder("ShopColumn", 1, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, -24) })
-- Items and Upgrade flank the LEVEL / TURBO LUCK bars at the bottom centre; placed every refresh.
-- The anchor sits on the icon's centre (not the icon + label), so the icon lines up with the gap.
local ICON_MID = TILE / 2 / (TILE + LABEL)
local itemsSlot = holder("ItemsSlot", 1, { AnchorPoint = Vector2.new(1, ICON_MID) })
local upgradeSlot = holder("UpgradeSlot", 1, { AnchorPoint = Vector2.new(0, ICON_MID) })
local BOTTOM_SCALE = 0.75 -- the bottom pair is smaller than the edge tiles (owner, 2026-10-15)
local SLOTS = {
	{ "Index", grid },
	{ "Stats", grid },
	{ "Rebirth", grid },
	{ "Shop", shopColumn },
	{ "Items", itemsSlot },
	{ "Upgrade", upgradeSlot },
}
local tiles = {}
for order, slot in SLOTS do
	local name = slot[1]
	local tile = make("ImageButton", name, slot[2], {
		LayoutOrder = order,
		Size = UDim2.fromOffset(CELL.X, CELL.Y),
		BackgroundTransparency = 1,
		Image = "",
		AutoButtonColor = false,
	})
	tile:SetAttribute("Panel", PANEL[name])
	icon(name, tile, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(TILE, TILE),
	})
	outlined(
		make("TextLabel", "Label", tile, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.new(1, 8, 0, LABEL + 4),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			TextSize = 19,
			TextColor3 = Color3.new(1, 1, 1),
			Text = name,
			ZIndex = 3,
		}),
		2.5
	)
	tile.Activated:Connect(function()
		PanelSwitch.Action(PANEL[name])
	end)
	tiles[name] = { Button = tile, Badge = badge(tile) }
end

-- Top-right pills (Roblox top-bar style) -------------------------------------------------------------------------
local bar = make("Frame", "TopRight", root, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 7),
	Size = UDim2.fromOffset(0, 44),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
})
local barScale = make("UIScale", "Scale", bar, {})
make("UIListLayout", "Layout", bar, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
})
local function pill(name, order, caption)
	local b = make("TextButton", name, bar, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(caption and 0 or 44, 44),
		AutomaticSize = caption and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
		BackgroundColor3 = Color3.fromRGB(18, 18, 21),
		BackgroundTransparency = 0.3,
		Text = "",
		AutoButtonColor = true,
	})
	make("UICorner", "Corner", b, { CornerRadius = UDim.new(1, 0) })
	icon(name, b, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = caption and UDim2.new(0, 12, 0.5, 0) or UDim2.new(0.5, -13, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
	})
	local text
	if caption then
		make("UIPadding", "Padding", b, { PaddingRight = UDim.new(0, 16) })
		text = make("TextLabel", "Caption", b, {
			Position = UDim2.fromOffset(46, 0),
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 19,
			TextColor3 = Color3.new(1, 1, 1),
			Text = caption,
		})
	end
	b.Activated:Connect(function()
		PanelSwitch.Action(name)
	end)
	return b, text
end
local daily, dailyText = pill("Daily", 1, "Daily")
local dailyBadge = badge(daily)
dailyBadge.Text = "!"
-- On the calendar's corner, clear of the caption.
dailyBadge.Position = UDim2.fromOffset(38, 9)
dailyBadge.Size = UDim2.fromOffset(18, 18)
dailyBadge.TextSize = 13
pill("Quests", 2, "Quests")
pill("Market", 3, "Market")
pill("Settings", 4)

-- Live state -----------------------------------------------------------------------------------------------------
local function setBadge(b, count)
	b.Visible = count > 0
	b.Text = tostring(count)
end

local function refresh()
	setBadge(tiles.Upgrade.Badge, player:GetAttribute("UpgradesBuyable") or 0)
	setBadge(tiles.Stats.Badge, player:GetAttribute("StatPoints") or 0)
	-- Same UTC day key the daily reward panel and DailyLoginService use.
	local now = os.time()
	local claimed = (player:GetAttribute("DailyLast") or -1) == math.floor(now / 86400)
	dailyBadge.Visible = not claimed
	if claimed then
		local left = 86400 - now % 86400
		dailyText.Text = string.format("%d:%02d:%02d", left // 3600, left // 60 % 60, left % 60)
	else
		dailyText.Text = "Daily"
	end
	local camera = workspace.CurrentCamera
	local phone = camera and camera.ViewportSize.Y <= 500
	for _, scale in scales do
		local bottomPair = scale.Parent == itemsSlot or scale.Parent == upgradeSlot
		scale.Scale = (phone and 0.68 or 1) * (bottomPair and BOTTOM_SCALE or 1)
	end
	barScale.Scale = phone and 0.8 or 1
	grid.Position = phone and UDim2.new(0, 8, 0.5, -20) or UDim2.new(0, 14, 0.5, -24)
	shopColumn.Position = phone and UDim2.new(1, -8, 0.5, -20) or UDim2.new(1, -14, 0.5, -24)
	-- Bottom pair: right beside the LEVEL / TURBO LUCK bars, each icon centred on the gap between the bars. That
	-- is below the Speed readout, so the wider Speed group never touches them. An open panel fills the band above
	-- the bars, so the pair hides while any panel is open (the panel's X and Escape close it).
	local hud = gui:FindFirstChild("RacerHud")
	local level = hud and hud:FindFirstChild("Level")
	local turbo = hud and hud:FindFirstChild("Turbo")
	itemsSlot.Visible = level ~= nil and turbo ~= nil
	upgradeSlot.Visible = itemsSlot.Visible
	if itemsSlot.Visible then
		-- AbsolutePosition starts below the top bar; these ScreenGuis ignore the inset, so add it back.
		local inset = GuiService:GetGuiInset().Y
		local left = math.min(level.AbsolutePosition.X, turbo.AbsolutePosition.X)
		local right =
			math.max(level.AbsolutePosition.X + level.AbsoluteSize.X, turbo.AbsolutePosition.X + turbo.AbsoluteSize.X)
		local gap = (level.AbsolutePosition.Y + level.AbsoluteSize.Y + turbo.AbsolutePosition.Y) / 2 + inset
		itemsSlot.Position = UDim2.fromOffset(left - 10, gap)
		upgradeSlot.Position = UDim2.fromOffset(right + 10, gap)
	end
	-- The roll showcase takes the whole screen; every HUD entry hides with the rest of the HUD.
	local showcase = gui:FindFirstChild("RollShowcase")
	root.Enabled = not (showcase and showcase.Enabled)
	setHudDimmed(PanelSwitch.AnyOpen())
end

for _, attr in { "UpgradesBuyable", "StatPoints", "DailyLast" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
PanelSwitch.OnChange(refresh)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.25 then
		elapsed = 0
		refresh()
	end
end)
refresh()
