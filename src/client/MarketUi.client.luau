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

local OUTLINE = Color3.fromRGB(17, 19, 31)
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

local root = make(
	"ScreenGui",
	"MarketUi",
	gui,
	{ ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }
)
local backdrop = make("TextButton", "Backdrop", root, {
	Size = UDim2.fromScale(1, 1),
	Text = "",
	BackgroundColor3 = Color3.fromRGB(8, 10, 22),
	BackgroundTransparency = 0.35,
	Visible = false,
	AutoButtonColor = false,
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
local railScale = make("UIScale", "Scale", rail, {})

-- Trails and auras have no icon art: a trail is a colour streak, an aura a glowing orb.
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
	local art = make("Frame", "Art", parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = kind == "Trail" and UDim2.new(size.X, UDim.new(size.Y.Scale * 0.35, size.Y.Offset * 0.35)) or size,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Rotation = kind == "Trail" and -20 or 0,
		ZIndex = 3,
	})
	corner(art, 999)
	make("UIGradient", "Gradient", art, { Color = ColorSequence.new(item.Color, item.Accent or item.Color) })
	stroke(art, OUTLINE, 3)
	return art
end

local tabs = {}
for order, entry in KINDS do
	local kind, label = entry[1], entry[2]
	local b = make("TextButton", kind .. "Tab", rail, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = Color3.fromRGB(44, 52, 60),
		Text = "",
		AutoButtonColor = true,
	})
	corner(b, 12)
	local edge = stroke(b, OUTLINE, 4)
	swatch(b, Market.Items[kind][1], kind, UDim2.fromOffset(48, 38), UDim2.fromOffset(56, 56))
	caption("Label", b, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 24),
		Text = label,
		TextSize = 20,
	})
	tabs[kind] = { Button = b, Edge = edge }
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
	Font = Enum.Font.GothamBold,
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
		or kind == "Aura" and string.format("Aura  •  x%s speed", tostring(item.SpeedMulti))
		or "Trail  •  cosmetic"
	nameLabel.Text = item.Name
	priceText.Text = kind == "Potion"
			and string.format(
				"%s   •   Owned x%d",
				Format.MoneyText(item.Price),
				player:GetAttribute("Boost_" .. item.Id) or 0
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
	status.Text = ok and tostring(message or (done and "Done" or "Try again")) or "Connection error"
	status.TextColor3 = (ok and done) and TILE_GREEN or Color3.fromRGB(255, 100, 120)
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
	for order, item in items do
		local b = make("TextButton", selectedKind .. "_" .. item.Id, grid, {
			LayoutOrder = order,
			BackgroundColor3 = Color3.fromRGB(14, 24, 52),
			Text = "",
			AutoButtonColor = true,
		})
		corner(b, 12)
		stroke(b, item.Id == selected and Color3.new(1, 1, 1) or item.Id == equippedId and TILE_GREEN or TILE_BLUE, 4)
		swatch(b, item, selectedKind, UDim2.new(0.5, 0, 0.5, -8), UDim2.fromOffset(60, 60))
		local badge = owned(selectedKind, item.Id)
				and (selectedKind == "Potion" and ("x" .. (player:GetAttribute("Boost_" .. item.Id) or 0)) or "Owned")
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
	PanelSwitch.Toggle("Market")
	render()
end
local function closeMarket()
	PanelSwitch.Close("Market")
end
-- The top-right Market pill (HudChrome) opens it.
PanelSwitch.SetAction("Market", open)
close.Activated:Connect(closeMarket)
backdrop.Activated:Connect(closeMarket)
remotes:WaitForChild("MarketOpen").OnClientEvent:Connect(open)
player.AttributeChanged:Connect(function(attr)
	if backdrop.Visible and (attr:sub(1, 6) == "Boost_" or attr:sub(1, 3) == "Own" or attr:sub(1, 8) == "Equipped") then
		render()
	end
end)

-- Opens in the shared band between the HUD entries (docs/HUD_LAYOUT_SPEC.md section 6); short panels shrink the tabs.
require(script.Parent:WaitForChild("PanelBand")).Fit(panel, 900)
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	railScale.Scale = math.clamp((panel.AbsoluteSize.Y - 88) / (3 * 96 + 20), 0.4, 1)
end)
