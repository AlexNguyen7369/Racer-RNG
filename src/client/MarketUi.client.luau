--!nonstrict
-- Market (docs/HUD_LAYOUT_SPEC.md, Market pill): the Backpack look with side tabs, a tile grid and a detail pane.
-- Buying and equipping go to the server (MarketPurchase / MarketEquip); the client only shows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Market = require(shared:WaitForChild("MarketConfig"))
local Format = require(shared:WaitForChild("HudFormat"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local Ui = script.Parent:WaitForChild("RollToast"):WaitForChild("Ui")
local Icons = require(Ui.HudIcons)
local PotionIcons = require(Ui.PotionIcons)
local MarketArt = require(script.Parent:WaitForChild("MarketArt"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local OUTLINE = UiTheme.Outline
local PALETTE = UiTheme.Palette
local BODY = Color3.fromRGB(32, 27, 36)
local TILE_BLUE = Color3.fromRGB(47, 107, 255)
local TILE_GREEN = Color3.fromRGB(60, 220, 90)
local TILE_GOLD = Color3.fromRGB(255, 214, 90)
local KINDS = { { "Trail", "Trails" }, { "Aura", "Auras" }, { "Potion", "Potions" } }

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
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	local label = make("TextLabel", name, parent, props)
	make("UIStroke", "Outline", label, { Color = OUTLINE, Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Round })
	return label
end
local function cascade(tiles)
	UiMotion.Cascade(tiles, "Stroke")
end

local root = make(
	"ScreenGui",
	"MarketUi",
	gui,
	{ ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }
)
local backdrop = make("Frame", "Backdrop", root, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(8, 10, 22),
	BackgroundTransparency = 1, -- the world dim is HudChrome/PanelDim, below the HUD
	Visible = false,
})
PanelSwitch.Register("Market", backdrop)
local panel = make("Frame", "Panel", backdrop, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 124),
	Size = UDim2.fromOffset(820, 440),
	BackgroundColor3 = BODY,
	Active = true,
})
corner(panel, 16)
stroke(panel, OUTLINE, 4)

-- Header: gradient band, icon, title and the square red X (same as the Backpack).
local header = make("Frame", "Header", panel, {
	Size = UDim2.new(1, 0, 0, 64),
	BackgroundColor3 = Color3.new(1, 1, 1),
	ClipsDescendants = true,
})
corner(header, 16)
make("UIGradient", "Gradient", header, {
	Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(250, 90, 170)),
})
make("ImageLabel", "Icon", header, {
	Position = UDim2.fromOffset(14, 6),
	Size = UDim2.fromOffset(52, 52),
	BackgroundTransparency = 1,
	Image = Icons.Market.Image,
	ScaleType = Enum.ScaleType.Fit,
})
caption("Title", header, {
	Position = UDim2.fromOffset(78, 0),
	Size = UDim2.new(1, -160, 1, 0),
	Text = "Market",
	TextSize = 36,
	TextXAlignment = Enum.TextXAlignment.Left,
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

-- Potions retain their bottle artwork; cosmetics share the authored vector renderer.
local function swatch(parent, item, kind, pos, size)
	if kind == "Potion" then
		return make("ImageLabel", "Art", parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = size,
			BackgroundTransparency = 1,
			Image = PotionIcons[item.Category] or "",
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		})
	end
	return MarketArt.Draw(parent, item, pos, size)
end

local tabs = {}
for order, entry in KINDS do
	local kind, label = entry[1], entry[2]
	local b = make("TextButton", kind .. "Tab", rail, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = true,
	})
	corner(b, 12)
	UiTheme.Gradient(b, Color3.fromRGB(58, 68, 80), Color3.fromRGB(34, 40, 48))
	local edge = stroke(b, OUTLINE, 4)
	swatch(b, Market.Items[kind][1], kind, UDim2.fromOffset(48, 38), UDim2.fromOffset(56, 56))
	caption("Label", b, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 24),
		Text = label,
		TextSize = 20,
	})
	-- Per-tab scale: a UIScale on the rail would shrink the rail with the tabs and never make them fit.
	tabs[kind] = { Button = b, Edge = edge, Scale = make("UIScale", "Scale", b, {}) }
end

-- Tile grid.
local grid = make("ScrollingFrame", "Grid", panel, {
	Position = UDim2.fromOffset(120, 76),
	Size = UDim2.new(0.58, -132, 1, -88),
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

-- Detail pane (like the Items reference): rarity line, name, big preview, price, description, action.
local detail = make("Frame", "Detail", panel, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 76),
	Size = UDim2.new(0.42, -12, 1, -88),
	BackgroundColor3 = Color3.new(1, 1, 1),
})
corner(detail, 12)
stroke(detail, OUTLINE, 3)
make("UIGradient", "Gradient", detail, {
	Color = ColorSequence.new(Color3.fromRGB(70, 40, 110), Color3.fromRGB(150, 60, 170)),
	Rotation = 90,
})
local rarity = caption("Rarity", detail, {
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 0, 20),
	Text = "",
	TextSize = 16,
	TextColor3 = Color3.fromRGB(205, 150, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local nameLabel = caption("Name", detail, {
	Position = UDim2.fromOffset(12, 26),
	Size = UDim2.new(1, -24, 0, 30),
	Text = "",
	TextSize = 26,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local viewport = make("ViewportFrame", "Preview", detail, {
	Position = UDim2.fromOffset(12, 60),
	Size = UDim2.new(1, -24, 1, -190),
	BackgroundColor3 = Color3.fromRGB(12, 15, 30),
	BackgroundTransparency = 0.5,
	Ambient = Color3.fromRGB(130, 140, 190),
	LightColor = Color3.new(1, 1, 1),
})
corner(viewport, 10)
local priceRow = make("Frame", "Price", detail, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -100),
	Size = UDim2.new(1, -24, 0, 26),
	BackgroundColor3 = Color3.fromRGB(20, 20, 30),
	BackgroundTransparency = 0.3,
})
corner(priceRow, 6)
local priceText = caption("Value", priceRow, {
	Position = UDim2.fromOffset(10, 0),
	Size = UDim2.new(1, -20, 1, 0),
	Text = "",
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local description = make("TextLabel", "Description", detail, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -54),
	Size = UDim2.new(1, -24, 0, 42),
	BackgroundTransparency = 1,
	Text = "",
	Font = UiTheme.Font,
	TextSize = 13,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(225, 225, 240),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
})
local action = make("TextButton", "Action", detail, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.new(1, -24, 0, 38),
	Text = "",
	BackgroundColor3 = TILE_GREEN,
	AutoButtonColor = true,
})
corner(action, 8)
stroke(action, OUTLINE, 3)
UiTheme.Gradient(action, Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 185)) -- depth on whatever colour it shows
local actionLabel = caption("Label", action, { Size = UDim2.fromScale(1, 1), Text = "BUY", TextSize = 22 })
local status = caption("Status", panel, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 120, 1, -4),
	Size = UDim2.new(0.58, -132, 0, 20),
	Text = "",
	TextSize = 15,
	TextColor3 = TILE_GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})
local statusHome = status.Position
-- A purchase / equip answer slides in from the bottom edge.
local function notify(text, color)
	status.Text = text
	status.TextColor3 = color
	status.Position = statusHome
	UiMotion.SlideIn(status, Vector2.new(0, 14))
end

local function preview(item, kind)
	viewport:ClearAllChildren()
	corner(viewport, 10)
	local world = make("WorldModel", "World", viewport, {})
	local camera = make("Camera", "Camera", viewport, {})
	camera.CFrame = CFrame.lookAt(Vector3.new(4.5, 3.2, 5.5), Vector3.new(0, 1.3, 0.8))
	viewport.CurrentCamera = camera
	if kind == "Potion" then
		local bottle = make("Part", "Bottle", world, {
			Anchored = true,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			Position = Vector3.new(0, 1.6, 0),
			Color = item.Color,
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
		make("Part", "Cork", world, {
			Anchored = true,
			Size = Vector3.new(0.9, 0.9, 0.9),
			Position = bottle.Position + Vector3.new(0, 1.8, 0),
			Color = Color3.fromRGB(140, 90, 50),
		})
		return
	end
	make("Part", "Body", world, {
		Anchored = true,
		Size = Vector3.new(4.8, 0.8, 2.5),
		Position = Vector3.new(0, 1.2, 0),
		Color = Color3.fromRGB(77, 151, 205),
		Material = Enum.Material.SmoothPlastic,
	})
	if kind == "Aura" then
		make("Part", "Orb", world, {
			Anchored = true,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4.8, 2.6, 3.4),
			Position = Vector3.new(0, 1.8, 0),
			Color = item.Color,
			Material = Enum.Material.Neon,
			Transparency = 0.42,
		})
		make("Part", "Ring", world, {
			Anchored = true,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 5.2, 5.2),
			CFrame = CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = item.Accent or item.Color,
			Material = Enum.Material.Neon,
		})
	else
		for index = 1, 4 do
			make("Part", "Spark" .. index, world, {
				Anchored = true,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.35, 0.35, 0.35),
				Position = Vector3.new(0, 0.75, index * 1.15),
				Color = index % 2 == 0 and (item.Accent or item.Color) or item.Color,
				Material = Enum.Material.Neon,
			})
		end
	end
end

local selectedKind = "Trail"
local selected = nil -- item id
local busy = false
local entering = false -- the next render is the panel opening: cascade its tiles
local render

local function owned(kind, id)
	if kind == "Potion" then
		return (player:GetAttribute("Boost_" .. id) or 0) > 0
	end
	return player:GetAttribute("Own" .. kind .. "_" .. id) == true
end

local function showDetail(item)
	local kind = selectedKind
	local equipped = kind ~= "Potion" and player:GetAttribute("Equipped" .. kind) == item.Id
	local isOwned = owned(kind, item.Id)
	rarity.Text = kind == "Potion" and (item.Category .. " Potion")
		or kind == "Aura" and string.format("Aura  •  %s speed", Format.Multi(item.SpeedMulti))
		or "Trail  •  cosmetic"
	nameLabel.Text = item.Name
	priceText.Text = kind == "Potion"
			and string.format(
				"%s   •   Owned x%s",
				Format.MoneyText(item.Price),
				Format.Short(player:GetAttribute("Boost_" .. item.Id) or 0)
			)
		or (isOwned and "Owned" or Format.MoneyText(item.Price))
	description.Text = item.Description
	actionLabel.Text = kind == "Potion" and "BUY" or (equipped and "EQUIPPED" or isOwned and "EQUIP" or "BUY")
	action.BackgroundColor3 = equipped and Color3.fromRGB(55, 110, 180) or TILE_GREEN
	preview(item, kind)
end

action.Activated:Connect(function()
	local item = selected and Market.Get(selectedKind, selected)
	if not item or busy then
		return
	end
	local kind = selectedKind
	if kind ~= "Potion" and player:GetAttribute("Equipped" .. kind) == item.Id then
		return
	end
	busy = true
	local remote = (kind ~= "Potion" and owned(kind, item.Id)) and "MarketEquip" or "MarketPurchase"
	local ok, done, message = pcall(function()
		return remotes:WaitForChild(remote):InvokeServer(kind, item.Id)
	end)
	busy = false
	notify(
		ok and tostring(message or (done and "Done" or "Try again")) or "Connection error",
		(ok and done) and TILE_GREEN or Color3.fromRGB(255, 100, 120)
	)
	render()
end)

function render()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for kind, refs in tabs do
		refs.Edge.Color = kind == selectedKind and Color3.new(1, 1, 1) or OUTLINE
	end
	local items = Market.Items[selectedKind]
	if not (selected and Market.Get(selectedKind, selected)) then
		selected = items[1] and items[1].Id
	end
	local equippedId = player:GetAttribute("Equipped" .. selectedKind)
	local shownTiles = {}
	for order, item in items do
		local b = make("TextButton", selectedKind .. "_" .. item.Id, grid, {
			LayoutOrder = order,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Text = "",
			AutoButtonColor = true,
		})
		table.insert(shownTiles, b)
		corner(b, 12)
		UiTheme.Gradient(b, PALETTE.Row, PALETTE.PanelDeep)
		stroke(b, item.Id == selected and Color3.new(1, 1, 1) or item.Id == equippedId and TILE_GREEN or TILE_BLUE, 4)
		swatch(b, item, selectedKind, UDim2.new(0.5, 0, 0.5, -8), UDim2.fromOffset(60, 60))
		local badge = owned(selectedKind, item.Id)
				and (selectedKind == "Potion" and ("x" .. Format.Short(player:GetAttribute("Boost_" .. item.Id) or 0)) or "Owned")
			or Format.MoneyText(item.Price)
		caption("Badge", b, {
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.new(1, -12, 0, 20),
			Text = badge,
			TextSize = 15,
			TextScaled = true,
			TextColor3 = TILE_GOLD,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
		})
		caption("Name", b, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -8, 0, 20),
			Text = item.Name,
			TextSize = 15,
			TextScaled = true,
			ZIndex = 5,
		})
		b.Activated:Connect(function()
			selected = item.Id
			render()
		end)
	end
	local item = selected and Market.Get(selectedKind, selected)
	if item then
		showDetail(item)
	end
	if entering then
		entering = false
		cascade(shownTiles)
	end
end

for kind, refs in tabs do
	refs.Button.Activated:Connect(function()
		selectedKind = kind
		selected = nil
		status.Text = ""
		render()
	end)
end

local function open()
	PanelSwitch.Toggle("Market") -- showing it renders (Visible handler below)
end
local function closeMarket()
	PanelSwitch.Close("Market")
end
-- The top-right Market pill (HudChrome) opens it.
PanelSwitch.SetAction("Market", open)
close.Activated:Connect(closeMarket)
require(script.Parent:WaitForChild("PanelFrame")).CloseOnOutsideClick(backdrop, closeMarket)
remotes:WaitForChild("MarketOpen").OnClientEvent:Connect(open)
player.AttributeChanged:Connect(function(attr)
	if backdrop.Visible and (attr:sub(1, 6) == "Boost_" or attr:sub(1, 3) == "Own" or attr:sub(1, 8) == "Equipped") then
		render()
	end
end)

-- Opens in the shared band between the HUD entries (docs/HUD_LAYOUT_SPEC.md section 6); short panels shrink the tabs.
require(script.Parent:WaitForChild("PanelFrame")).Attach(panel, {
	Theme = "Market",
	Title = "Market",
	Icon = Icons.Market.Image,
	TitleObject = header.Title,
	Close = close,
	MaxWidth = 900,
})
local function fitTabs()
	local ancestor = rail.AbsoluteSize.X / 96 -- PanelBand scale; the rail is 96 design px wide
	if ancestor <= 0 then
		return
	end
	local count = 0
	for _ in tabs do
		count += 1
	end
	local scale = math.clamp((rail.AbsoluteSize.Y / ancestor - (count - 1) * 10) / (count * 96), 0.4, 1)
	for _, refs in tabs do
		refs.Scale.Scale = scale
	end
end
rail:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTabs)
fitTabs()
-- However the panel is shown, its grid is filled.
backdrop:GetPropertyChangedSignal("Visible"):Connect(function()
	if backdrop.Visible then
		entering = true
		render()
	end
end)
UiTheme.Apply(root)
