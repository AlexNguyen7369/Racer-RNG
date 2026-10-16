--!nonstrict
-- Backpack (docs/HUD_LAYOUT_SPEC.md section 3): Misc (potions), Trails and Auras tabs with item tiles. Cars live
-- only in the Index. Clicking a potion asks the server to use one and clicking a trail or aura asks it to equip
-- it; the server decides both.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Market = require(shared.MarketConfig)
local Boosts = require(shared.BoostConfig)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local Ui = script.Parent:WaitForChild("RollToast"):WaitForChild("Ui")
local Icons = require(Ui.HudIcons)
local PotionIcons = require(Ui.PotionIcons)

local OUTLINE = Color3.fromRGB(17, 19, 31)
local BODY = Color3.fromRGB(32, 27, 36)
local TILE_BLUE = Color3.fromRGB(47, 107, 255)
local TILE_GREEN = Color3.fromRGB(60, 220, 90)

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function corner(parent, radius)
	make("UICorner", "Corner", parent, { CornerRadius = UDim.new(0, radius) })
end
local function stroke(parent, color, thickness)
	return make("UIStroke", "Stroke", parent, {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end
local function caption(name, parent, props)
	props.BackgroundTransparency = 1
	props.Font = Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	local label = make("TextLabel", name, parent, props)
	make("UIStroke", "Outline", label, { Color = OUTLINE, Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Round })
	return label
end
local function count(n)
	return n >= 1000 and string.format("x%.1fk", n / 1000) or ("x" .. n)
end

local root = make("ScreenGui", "RacerBackpack", gui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(720, 420),
	BackgroundColor3 = BODY,
	Visible = false,
	Active = true,
})
corner(panel, 16)
stroke(panel, OUTLINE, 4)
PanelSwitch.Register("Backpack", panel)

-- Header: blue checkered band, icon, title and the square red X.
local header = make("Frame", "Header", panel, {
	Size = UDim2.new(1, 0, 0, 64),
	BackgroundColor3 = Color3.new(1, 1, 1),
	ClipsDescendants = true,
})
corner(header, 16)
make("UIGradient", "Gradient", header, {
	Color = ColorSequence.new(Color3.fromRGB(104, 104, 245), Color3.fromRGB(80, 170, 250)),
})
caption("Title", header, {
	Position = UDim2.fromOffset(78, 0),
	Size = UDim2.new(1, -160, 1, 0),
	Text = "Backpack",
	TextSize = 36,
	TextXAlignment = Enum.TextXAlignment.Left,
})
make("ImageLabel", "Icon", header, {
	Position = UDim2.fromOffset(14, 6),
	Size = UDim2.fromOffset(52, 52),
	BackgroundTransparency = 1,
	Image = Icons.Items.Image,
	ScaleType = Enum.ScaleType.Fit,
})
local close = make("TextButton", "Close", header, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(72, 64),
	BackgroundColor3 = Color3.fromRGB(232, 69, 60),
	Text = "",
	AutoButtonColor = true,
})
caption("X", close, { Size = UDim2.fromScale(1, 1), Text = "X", TextSize = 40 })

-- Side tabs.
local rail = make("Frame", "Tabs", panel, {
	Position = UDim2.fromOffset(12, 76),
	Size = UDim2.new(0, 96, 1, -88),
	BackgroundTransparency = 1,
})
make("UIListLayout", "Layout", rail, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
local railScale = make("UIScale", "Scale", rail, {})
local tabs = {}
local function tab(name, order, art)
	local b = make("TextButton", name .. "Tab", rail, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = Color3.fromRGB(44, 52, 60),
		Text = "",
		AutoButtonColor = true,
	})
	corner(b, 12)
	local edge = stroke(b, OUTLINE, 4)
	art(b)
	caption("Label", b, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 24),
		Text = name,
		TextSize = 20,
	})
	tabs[name] = { Button = b, Edge = edge }
	return b
end
-- Trails and auras have no icon art yet: a trail is a colour streak, an aura a glowing orb.
local function swatch(parent, item, kind, pos, size)
	local art = make("Frame", "Art", parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = size,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Rotation = kind == "Trail" and -20 or 0,
		ZIndex = 3,
	})
	make("UICorner", "Corner", art, { CornerRadius = UDim.new(1, 0) })
	make("UIGradient", "Gradient", art, { Color = ColorSequence.new(item.Color, item.Accent or item.Color) })
	stroke(art, OUTLINE, 3)
	return art
end
tab("Misc", 1, function(b)
	make("ImageLabel", "Art", b, {
		Position = UDim2.fromOffset(18, 6),
		Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1,
		Image = PotionIcons.Luck,
		ScaleType = Enum.ScaleType.Fit,
	})
end)
tab("Trails", 2, function(b)
	swatch(b, Market.Items.Trail[1], "Trail", UDim2.fromOffset(48, 36), UDim2.fromOffset(66, 22))
end)
tab("Auras", 3, function(b)
	swatch(b, Market.Items.Aura[1], "Aura", UDim2.fromOffset(48, 36), UDim2.fromOffset(48, 48))
end)

local grid = make("ScrollingFrame", "Items", panel, {
	Position = UDim2.fromOffset(120, 76),
	Size = UDim2.new(1, -132, 1, -88),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIPadding", "Padding", grid, {
	PaddingTop = UDim.new(0, 4),
	PaddingLeft = UDim.new(0, 4),
	PaddingRight = UDim.new(0, 10),
})
make("UIGridLayout", "Layout", grid, {
	CellSize = UDim2.fromOffset(104, 104),
	CellPadding = UDim2.fromOffset(12, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local empty = caption("Empty", panel, {
	Position = UDim2.fromOffset(120, 140),
	Size = UDim2.new(1, -132, 0, 40),
	Text = "",
	TextSize = 22,
	Visible = false,
})
local hint = caption("Hint", panel, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 120, 1, -6),
	Size = UDim2.new(1, -132, 0, 22),
	Text = "",
	TextSize = 16,
	TextColor3 = Color3.fromRGB(255, 214, 90),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})

local current = "Misc"
local busy = false
local function tile(id, order, highlighted)
	local b = make("TextButton", id, grid, {
		LayoutOrder = order,
		BackgroundColor3 = Color3.fromRGB(14, 24, 52),
		Text = "",
		AutoButtonColor = true,
	})
	corner(b, 12)
	stroke(b, highlighted and TILE_GREEN or TILE_BLUE, 4)
	return b
end

local render
local function equip(kind, item)
	if busy then
		return
	end
	busy = true
	local ok, done, message = pcall(function()
		return remotes:WaitForChild("MarketEquip"):InvokeServer(kind, item.Id)
	end)
	busy = false
	hint.Text = ok and (done and ("Equipped " .. item.Name) or tostring(message)) or "Connection error"
	render()
end
local function use(item)
	if busy then
		return
	end
	busy = true
	local ok, used, message = pcall(function()
		return remotes:WaitForChild("UseBoost"):InvokeServer(item.Id)
	end)
	busy = false
	hint.Text = ok and (used and (item.Name .. " activated") or tostring(message)) or "Connection error"
	render()
end

function render()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for name, refs in tabs do
		refs.Edge.Color = name == current and Color3.new(1, 1, 1) or OUTLINE
	end
	local shown = 0
	if current ~= "Misc" then
		local kind = current == "Trails" and "Trail" or "Aura"
		local equipped = player:GetAttribute("Equipped" .. kind)
		for order, item in Market.Items[kind] do
			if player:GetAttribute("Own" .. kind .. "_" .. item.Id) == true then
				shown += 1
				local b = tile(item.Id, order, item.Id == equipped)
				swatch(
					b,
					item,
					kind,
					UDim2.new(0.5, 0, 0.5, -10),
					kind == "Trail" and UDim2.fromOffset(78, 26) or UDim2.fromOffset(56, 56)
				)
				caption("Name", b, {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -4),
					Size = UDim2.new(1, -8, 0, 22),
					Text = item.Name,
					TextSize = 15,
					TextScaled = true,
					ZIndex = 5,
				})
				b.MouseEnter:Connect(function()
					hint.Text = item.Description or item.Name
				end)
				b.Activated:Connect(function()
					if item.Id ~= player:GetAttribute("Equipped" .. kind) then
						equip(kind, item)
					end
				end)
			end
		end
		empty.Text = "None owned yet. Buy them in the Market!"
	else
		local order = 0
		for _, category in Boosts.Order do
			for _, item in Boosts.ItemsFor(category) do
				local n = player:GetAttribute("Boost_" .. item.Id) or 0
				order += 1
				if n > 0 then
					shown += 1
					local b = tile(item.Id, order, false)
					make("ImageLabel", "Art", b, {
						Position = UDim2.fromOffset(10, 6),
						Size = UDim2.new(1, -20, 1, -20),
						BackgroundTransparency = 1,
						Image = PotionIcons[category] or "",
						ScaleType = Enum.ScaleType.Fit,
					})
					caption("Tier", b, {
						Position = UDim2.fromOffset(8, 4),
						Size = UDim2.fromOffset(40, 24),
						Text = item.Roman,
						TextSize = 20,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 5,
					})
					caption("Count", b, {
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, -6, 1, -2),
						Size = UDim2.new(1, -12, 0, 30),
						Text = count(n),
						TextSize = 26,
						TextXAlignment = Enum.TextXAlignment.Right,
						ZIndex = 5,
					})
					b.MouseEnter:Connect(function()
						hint.Text = string.format(
							"%s: x%.2f %s for %ds. Click to use.",
							item.Name,
							item.Multiplier,
							category,
							item.Duration
						)
					end)
					b.Activated:Connect(function()
						use(item)
					end)
				end
			end
		end
		empty.Text = "No potions. Win races and claim daily rewards!"
	end
	empty.Visible = shown == 0
end

for name, refs in tabs do
	refs.Button.Activated:Connect(function()
		current = name
		hint.Text = ""
		render()
	end)
end
close.Activated:Connect(function()
	PanelSwitch.Close("Backpack")
end)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		hint.Text = ""
		render()
	end
end)
player.AttributeChanged:Connect(function(attr)
	if panel.Visible and (attr:sub(1, 6) == "Boost_" or attr:sub(1, 3) == "Own" or attr:sub(1, 8) == "Equipped") then
		render()
	end
end)
-- Same band as the other panels; short panels (phones) shrink the three tabs to fit.
require(script.Parent:WaitForChild("PanelBand")).Fit(panel, 760)
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	railScale.Scale = math.clamp((panel.AbsoluteSize.Y - 88) / (3 * 96 + 20), 0.4, 1)
end)
