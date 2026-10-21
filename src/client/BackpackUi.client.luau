--!nonstrict
-- Backpack (docs/HUD_LAYOUT_SPEC.md section 3): Misc (potions), Trails, Auras and Cars tabs with item tiles.
-- Clicking a potion asks the server to use one; clicking a trail, aura or car asks it to equip it; the server
-- decides all of them. Cars are listed least rare first (owner, 2026-10-20).
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
local MarketArt = require(script.Parent:WaitForChild("MarketArt"))
local CarCatalog = require(shared.CarCatalog)
local GachaConfig = require(shared.GachaConfig)
local Components = require(Ui.RacerComponents)

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
	-- Per-tab scale: a UIScale on the rail would shrink the rail with the tabs and never make them fit.
	tabs[name] = { Button = b, Edge = edge, Scale = make("UIScale", "Scale", b, {}) }
	return b
end
-- Same original art as Market tiles, tabs and detail previews.
local function swatch(parent, item, kind, pos, size)
	return MarketArt.Draw(parent, item, pos, kind == "Trail" and UDim2.new(size.X, size.X) or size)
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
tab("Cars", 4, function(b)
	local spec = CarCatalog.All()[1]
	local art = Components.CarModelArt(b, "Art", spec, UDim2.fromOffset(8, 2), UDim2.fromOffset(80, 66))
	ReplicatedStorage:WaitForChild("CarModels").ChildAdded:Connect(function()
		Components.FillCarModel(art, spec)
	end)
end)

-- Owned cars, least rare first, then catalog order.
local rarityRank = {}
for i, rarity in GachaConfig.RARITY_ORDER do
	rarityRank[rarity] = i
end
local function ownedCars()
	local data = player:FindFirstChild("GachaData")
	local list = {}
	for _, spec in CarCatalog.All() do
		if data and data:FindFirstChild(spec.Id) then
			table.insert(list, spec)
		end
	end
	for _, spec in CarCatalog.Passes() do -- gamepass cars are owned through Roblox (Pass_<id>), not GachaData
		if player:GetAttribute("Pass_" .. spec.Id) == true then
			table.insert(list, spec)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = rarityRank[a.Rarity] or 99, rarityRank[b.Rarity] or 99
		if ra ~= rb then
			return ra < rb
		end
		return (a.Order or 0) < (b.Order or 0)
	end)
	return list
end

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
	if current == "Cars" then
		local equipped = player:GetAttribute("EquippedCar")
		for order, spec in ownedCars() do
			shown += 1
			local b = tile(spec.Id, order, spec.Id == equipped)
			Components.CarModelArt(b, "Art", spec, UDim2.fromOffset(6, 4), UDim2.new(1, -12, 1, -46))
			caption("Name", b, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -20),
				Size = UDim2.new(1, -8, 0, 20),
				Text = spec.Name,
				TextSize = 15,
				TextScaled = true,
				ZIndex = 5,
			})
			caption("Multi", b, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -2),
				Size = UDim2.new(1, -8, 0, 18),
				Text = "x" .. tostring(spec.SpeedMulti),
				TextSize = 14,
				TextColor3 = GachaConfig.RARITY_COLORS[spec.Rarity] or Color3.new(1, 1, 1),
				ZIndex = 5,
			})
			b.MouseEnter:Connect(function()
				hint.Text = string.format(
					"%s (%s) x%s speed. Click to equip.",
					spec.Name,
					spec.Rarity,
					tostring(spec.SpeedMulti)
				)
			end)
			b.Activated:Connect(function()
				if spec.Id ~= player:GetAttribute("EquippedCar") then
					remotes.EquipCar:FireServer(spec.Id)
					hint.Text = "Equipping " .. spec.Name
				end
			end)
		end
		empty.Text = "No cars yet. Keep rolling!"
	elseif current ~= "Misc" then
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
	local watched = attr:sub(1, 6) == "Boost_" or attr:sub(1, 3) == "Own" or attr:sub(1, 8) == "Equipped"
	if panel.Visible and (watched or attr:sub(1, 5) == "Pass_") then
		render()
	end
end)
task.spawn(function()
	local data = player:WaitForChild("GachaData")
	local function changed()
		if panel.Visible and current == "Cars" then
			render()
		end
	end
	data.ChildAdded:Connect(changed)
	data.ChildRemoved:Connect(changed)
end)
-- Same band as the other panels; short panels (phones) shrink the four tabs to fit.
require(script.Parent:WaitForChild("PanelFrame")).Attach(panel, {
	Theme = "Backpack",
	Title = "Backpack",
	Icon = Icons.Items.Image,
	TitleObject = header.Title,
	Close = close,
	MaxWidth = 760,
})
local function fitTabs()
	local ancestor = rail.AbsoluteSize.X / 96 -- PanelBand scale; the rail is 96 design px wide
	if ancestor <= 0 then
		return
	end
	local scale = math.clamp((rail.AbsoluteSize.Y / ancestor - 3 * 10) / (4 * 96), 0.4, 1)
	for _, refs in tabs do
		refs.Scale.Scale = scale
	end
end
rail:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTabs)
fitTabs()
