--!nonstrict
-- Shop (docs/GAMEPASS_SHOP_SPEC.md): Featured gamepass cars, Gamepasses, Potions + bundle, Server Luck, Codes.
-- Display and purchase prompts only; Roblox owns prices and ownership, Server/ShopService grants products and codes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("MonetizationConfig"))
local catalog = require(shared:WaitForChild("CarCatalog"))
local Gacha = require(shared:WaitForChild("GachaConfig"))
local Boosts = require(shared:WaitForChild("BoostConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local Ui = script.Parent:WaitForChild("RollToast"):WaitForChild("Ui")
local Icons = require(Ui.HudIcons)
local PotionIcons = require(Ui.PotionIcons)
local ShopPresentation = require(script.Parent:WaitForChild("ShopPresentation"))

local OUTLINE = Color3.fromRGB(24, 22, 34)
local PANEL = Color3.fromRGB(236, 236, 242)
local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"

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
local function stroke(parent, thickness)
	make("UIStroke", "Stroke", parent, {
		Color = OUTLINE,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end
-- Chunky white text with a dark outline, like the references.
local function caption(name, parent, props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextScaled = true
	local label = make("TextLabel", name, parent, props)
	make("UIStroke", "Outline", label, { Color = OUTLINE, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round })
	make("UITextSizeConstraint", "Max", label, { MaxTextSize = props.TextSize or 24 })
	return label
end
local function gradient(parent, a, b)
	make("UIGradient", "Gradient", parent, { Color = ColorSequence.new(a, b), Rotation = 90 })
end
local function lighter(color, t)
	return color:Lerp(Color3.new(1, 1, 1), t)
end
local function commas(n)
	local s = tostring(math.floor(n))
	repeat
		local count
		s, count = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return s
end
local function section(name, order, title, subtitle)
	local frame = make("Frame", name, nil, {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	make("UIListLayout", "Layout", frame, {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	if title then
		caption("Title", frame, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 40), Text = title, TextSize = 36 })
	end
	if subtitle then
		make("TextLabel", "Subtitle", frame, {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = subtitle,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(120, 120, 135),
		})
	end
	return frame
end

local root = make("ScreenGui", "ShopUi", gui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 7,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local backdrop = make("Frame", "Backdrop", root, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(8, 10, 22),
	BackgroundTransparency = 1, -- the world dim is HudChrome/PanelDim, below the HUD
	Visible = false,
})
PanelSwitch.Register("Shop", backdrop)
local panel = make("Frame", "Panel", backdrop, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 110),
	Size = UDim2.fromScale(0.78, 0.68),
	BackgroundColor3 = PANEL,
	Active = true,
})
corner(panel, 16)
stroke(panel, 4)
make("UIGradient", "Gradient", panel, {
	Color = ColorSequence.new(Color3.fromRGB(246, 246, 250), Color3.fromRGB(226, 226, 234)),
	Rotation = 90,
})
local title = caption("Title", panel, {
	Position = UDim2.fromOffset(-6, -26),
	Size = UDim2.fromOffset(150, 56),
	Rotation = -4,
	Text = "Shop",
	TextSize = 52,
	ZIndex = 3,
})
title.Outline.Thickness = 4
local close = make("TextButton", "Close", panel, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 10, 0, -12),
	Size = UDim2.fromOffset(46, 46),
	Text = "",
	BackgroundColor3 = Color3.fromRGB(232, 69, 60),
	AutoButtonColor = true,
	ZIndex = 3,
})
corner(close, 10)
stroke(close, 3)
caption("X", close, { Size = UDim2.fromScale(1, 1), Text = "X", TextSize = 30, ZIndex = 3 })

local list = make("ScrollingFrame", "Items", panel, {
	Position = UDim2.fromOffset(12, 76),
	Size = UDim2.new(1, -24, 1, -88),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Color3.fromRGB(140, 140, 160),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIListLayout", "Layout", list, { Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder })
make("UIPadding", "Padding", list, {
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 12),
	PaddingLeft = UDim.new(0, 4),
	PaddingRight = UDim.new(0, 12),
})

-- A colour card with the dark outline and a light-to-colour gradient.
local function card(name, parent, color, props)
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	local frame = make("Frame", name, parent, props)
	corner(frame, 14)
	stroke(frame, 3)
	gradient(frame, lighter(color, 0.55), color)
	return frame
end

-- The green price button. kind = "pass" | "product"; id 0 shows "Coming soon" and never prompts.
local function buyButton(parent, kind, id, robuxPrice, props)
	props.Text = ""
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	props.AutoButtonColor = true
	local button = make("TextButton", "Buy", parent, props)
	corner(button, 10)
	stroke(button, 3)
	gradient(button, Color3.fromRGB(226, 255, 120), Color3.fromRGB(98, 214, 60))
	make("ImageLabel", "Robux", button, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.1, id > 0 and 0.5 or 0.38),
		Size = UDim2.fromScale(0.22, 0.6),
		BackgroundTransparency = 1,
		Image = ROBUX_ICON,
		ImageColor3 = OUTLINE,
		ScaleType = Enum.ScaleType.Fit,
	})
	local price = caption("Price", button, {
		Position = UDim2.fromScale(0.32, id > 0 and 0.12 or 0.04),
		Size = UDim2.fromScale(0.62, id > 0 and 0.76 or 0.62),
		Text = commas(robuxPrice),
		TextSize = 28,
	})
	if id <= 0 then
		caption("Soon", button, {
			Position = UDim2.fromScale(0.05, 0.64),
			Size = UDim2.fromScale(0.9, 0.3),
			Text = "Coming soon",
			TextSize = 12,
		})
		return button
	end
	task.spawn(function()
		local infoType = kind == "pass" and Enum.InfoType.GamePass or Enum.InfoType.Product
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			price.Text = commas(info.PriceInRobux)
		end
	end)
	button.Activated:Connect(function()
		if button:GetAttribute("Owned") then
			return -- an owned gamepass car's button equips it instead (Featured below)
		end
		if kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	return button
end

-- 1. Featured: the gamepass cars, each in a ViewportFrame.
local function carPreview(parent, spec)
	ShopPresentation.Preview(parent, spec, backdrop)
end
local featured = section("Featured", 1, nil, nil)
featured.Parent = list
local featuredRow = make("Frame", "Row", featured, {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 230),
	BackgroundTransparency = 1,
})
make("UIGridLayout", "Layout", featuredRow, {
	CellSize = UDim2.new(0.5, -8, 1, 0),
	CellPadding = UDim2.fromOffset(16, 0),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
for order, car in catalog.Passes() do
	local color = Gacha.RARITY_COLORS[car.Rarity] or Color3.fromRGB(255, 150, 60)
	local box = card(car.Id, featuredRow, color, { LayoutOrder = order })
	caption("Name", box, {
		Position = UDim2.fromScale(0.04, 0.03),
		Size = UDim2.fromScale(0.92, 0.13),
		Text = car.Name,
		TextSize = 32,
	})
	caption("Stats", box, {
		Position = UDim2.fromScale(0.04, 0.15),
		Size = UDim2.fromScale(0.92, 0.09),
		Text = string.format("×%s SPEED", commas(car.SpeedMulti)),
		TextColor3 = lighter(color, 0.6),
		TextSize = 20,
	})
	task.spawn(carPreview, box, car)
	local buy = buyButton(box, "pass", car.GamepassId or 0, car.RobuxPrice or 0, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(122, 48),
	})
	-- Featured cards advertise the pass price. Equipping remains in Backpack/pedestals.
 if buy:FindFirstChild("Soon") then buy.Soon:Destroy() end
 buy.Robux.Position=UDim2.fromScale(.08,.5)
 buy.Price.Position=UDim2.fromScale(.32,.12)
 buy.Price.Size=UDim2.fromScale(.62,.76)
 local function owned()
  local hasPass=player:GetAttribute("Pass_"..car.Id)==true
  buy:SetAttribute("Owned",hasPass)
  buy.Active=not hasPass and (car.GamepassId or 0)>0
  buy.AutoButtonColor=buy.Active
 end
 owned()
 player:GetAttributeChangedSignal("Pass_"..car.Id):Connect(owned)
end

-- 2. Gamepasses grid.
local passes = section("Gamepasses", 2, "Gamepasses", nil)
passes.Parent = list
local grid = make("Frame", "Grid", passes, {
	LayoutOrder = 2,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
})
make("UIGridLayout", "Layout", grid, {
	CellSize = UDim2.new(1 / 3, -11, 0, 180),
	CellPadding = UDim2.fromOffset(16, 16),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
for order, item in config.Gamepasses do
	local box = card(item.Id, grid, item.Color or Color3.fromRGB(110, 205, 255), { LayoutOrder = order })
	caption("Name", box, {
		Position = UDim2.fromScale(0.05, 0.04),
		Size = UDim2.fromScale(0.9, 0.17),
		Text = item.Name,
		TextSize = 28,
	})
	caption("Description", box, {
		Position = UDim2.fromScale(0.05, 0.21),
		Size = UDim2.fromScale(0.9, 0.11),
		Text = item.Description,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
	})
	local icon = Icons[item.Icon] or Icons.Shop
	make("ImageLabel", "Icon", box, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.34),
		Size = UDim2.fromScale(0.5, 0.36),
		BackgroundTransparency = 1,
		Image = icon.Image,
		ImageRectOffset = icon.Offset or Vector2.zero,
		ImageRectSize = icon.Size or Vector2.zero,
		ScaleType = Enum.ScaleType.Fit,
	})
	buyButton(box, "pass", item.GamepassId, item.RobuxPrice, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromScale(0.62, 0.22),
	})
end

-- 3. Potions: packs and the bundle (developer products).
local first = Boosts.Get("LuckI")
local potions =
	section("Potions", 3, "Potions", string.format("(POTIONS LAST %d SECONDS EACH)", first and first.Duration or 60))
potions.Parent = list
local packRow = make("Frame", "Packs", potions, {
	LayoutOrder = 2,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
})
make("UIGridLayout", "Layout", packRow, {
	CellSize = UDim2.new(1 / 3, -11, 0, 170),
	CellPadding = UDim2.fromOffset(16, 16),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local POTION_COLORS = {
	Luck = Color3.fromRGB(110, 230, 160),
	Money = Color3.fromRGB(255, 200, 70),
	Speed = Color3.fromRGB(110, 205, 255),
}
local function grantCategory(grants)
	for id in grants do
		local boost = Boosts.Get(id)
		return boost and boost.Category or "Luck"
	end
	return "Luck"
end
for order, product in config.Products do
	if product.Section == "Potions" then
		local category = grantCategory(product.Grants)
		local box = card(product.Id, packRow, POTION_COLORS[category], { LayoutOrder = order })
		caption("Name", box, {
			Position = UDim2.fromScale(0.05, 0.04),
			Size = UDim2.fromScale(0.9, 0.16),
			Text = product.Name,
			TextSize = 24,
		})
		caption("Description", box, {
			Position = UDim2.fromScale(0.05, 0.2),
			Size = UDim2.fromScale(0.9, 0.1),
			Text = product.Description,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
		})
		make("ImageLabel", "Icon", box, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.32),
			Size = UDim2.fromScale(0.5, 0.38),
			BackgroundTransparency = 1,
			Image = PotionIcons[category],
			ScaleType = Enum.ScaleType.Fit,
		})
		buyButton(box, "product", product.ProductId, product.RobuxPrice, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.fromScale(0.62, 0.23),
		})
	end
end
for _, product in config.Products do
	if product.Section == "Bundle" then
		local banner = card("Bundle", potions, Color3.fromRGB(255, 170, 220), {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 170),
		})
		banner.Gradient.Rotation = 0
		banner.Gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 235, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 225, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(245, 160, 230)),
		})
		local name = caption("Name", banner, {
			Position = UDim2.fromScale(0.03, 0.05),
			Size = UDim2.fromScale(0.5, 0.22),
			Text = product.Name,
			TextColor3 = Color3.fromRGB(240, 120, 255),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 34,
		})
		name.Outline.Thickness = 3
		caption("Description", banner, {
			Position = UDim2.fromScale(0.03, 0.27),
			Size = UDim2.fromScale(0.5, 0.12),
			Text = product.Description,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 18,
		})
		local bottles = make("Frame", "Contents", banner, {
			Position = UDim2.fromScale(0.03, 0.42),
			Size = UDim2.fromScale(0.55, 0.54),
			BackgroundTransparency = 1,
		})
		make("UIListLayout", "Layout", bottles, {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0.04, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		local total, perCategory = 0, {}
		for id, count in product.Grants do
			local boost = Boosts.Get(id)
			total += count
			if boost then
				perCategory[boost.Category] = (perCategory[boost.Category] or 0) + count
			end
		end
		for order, category in Boosts.Order do
			local bottle = make("ImageLabel", category, bottles, {
				LayoutOrder = order,
				Size = UDim2.fromScale(0.25, 1),
				BackgroundTransparency = 1,
				Image = PotionIcons[category],
				ScaleType = Enum.ScaleType.Fit,
			})
			caption("Count", bottle, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromScale(0.9, 0.34),
				Text = "x" .. (perCategory[category] or 0),
				TextSize = 22,
			})
		end
		caption("Total", banner, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0.3, 0),
			Size = UDim2.fromScale(0.3, 0.14),
			Text = string.format("x%d Potions!", total),
			TextSize = 22,
		})
		buyButton(banner, "product", product.ProductId, product.RobuxPrice, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -12),
			Size = UDim2.fromScale(0.3, 0.38),
		})
	end
end

-- 4. DOUBLE Server Luck banner (display only until the Server Luck feature exists).
local luck = section("ServerLuck", 4, nil, nil)
luck.Parent = list
local luckBanner = card("Banner", luck, Color3.fromRGB(150, 230, 90), {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 150),
})
local luckTitle = caption("Title", luckBanner, {
	Position = UDim2.fromScale(0.03, 0.06),
	Size = UDim2.fromScale(0.94, 0.24),
	Text = "DOUBLE Server Luck!",
	TextColor3 = Color3.fromRGB(80, 220, 90),
	TextSize = 38,
})
luckTitle.Outline.Thickness = 3
local tiers = make("Frame", "Tiers", luckBanner, {
	Position = UDim2.fromScale(0.03, 0.38),
	Size = UDim2.fromScale(0.94, 0.54),
	BackgroundTransparency = 1,
})
make("UIGridLayout", "Layout", tiers, {
	CellSize = UDim2.new(1 / 3, -8, 1, 0),
	CellPadding = UDim2.fromOffset(12, 0),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
for order, product in config.Products do
	if product.Section == "ServerLuck" then
		local tier = make("Frame", product.Id, tiers, { LayoutOrder = order, BackgroundTransparency = 1 })
		caption("Name", tier, { Size = UDim2.fromScale(1, 0.34), Text = product.Name, TextSize = 20 })
		buyButton(tier, "product", product.ProductId, product.RobuxPrice, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0.8, 0.62),
		})
	end
end

-- 5. Codes.
local codes = section("Codes", 5, "Codes", nil)
codes.Parent = list
local codeBox = card("Box", codes, Color3.fromRGB(130, 180, 255), {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 170),
})
local hint = caption("Hint", codeBox, {
	Position = UDim2.fromScale(0.04, 0.06),
	Size = UDim2.fromScale(0.92, 0.18),
	Text = "Follow the socials on the game page for codes!",
	TextColor3 = Color3.fromRGB(110, 200, 255),
	TextSize = 28,
})
hint.Outline.Color = Color3.fromRGB(30, 60, 140)
local input = make("TextBox", "Input", codeBox, {})
input.AnchorPoint = Vector2.new(0.5, 0)
input.Position = UDim2.fromScale(0.5, 0.3)
input.Size = UDim2.fromScale(0.5, 0.24)
input.BackgroundColor3 = Color3.fromRGB(80, 92, 112)
input.PlaceholderText = "Enter code here.."
input.PlaceholderColor3 = Color3.fromRGB(40, 46, 60)
input.Text = ""
input.ClearTextOnFocus = false
input.Font = Enum.Font.GothamBlack
input.TextScaled = true
input.TextColor3 = Color3.new(1, 1, 1)
corner(input, 10)
stroke(input, 3)
make("UIPadding", "Padding", input, { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) })
local redeem = make("TextButton", "Redeem", codeBox, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.6),
	Size = UDim2.fromScale(0.26, 0.2),
	Text = "",
	BackgroundColor3 = Color3.new(1, 1, 1),
	AutoButtonColor = true,
})
corner(redeem, 10)
stroke(redeem, 3)
gradient(redeem, Color3.fromRGB(140, 230, 255), Color3.fromRGB(70, 170, 245))
caption("Label", redeem, { Size = UDim2.fromScale(1, 1), Text = "Redeem", TextSize = 26 })
local status = make("TextLabel", "Status", codeBox, {
	Position = UDim2.fromScale(0.04, 0.83),
	Size = UDim2.fromScale(0.92, 0.13),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(30, 60, 140),
})
redeem.Activated:Connect(function()
	redeem.Active = false
	local ok, message = remotes:WaitForChild("RedeemCode"):InvokeServer(input.Text)
	status.Text = tostring(message or (ok and "Code redeemed!" or "Try again"))
	status.TextColor3 = ok and Color3.fromRGB(30, 140, 60) or Color3.fromRGB(200, 40, 60)
	if ok then
		input.Text = ""
	end
	redeem.Active = true
end)

-- 6. Thanks.
make("TextLabel", "Thanks", list, {
	LayoutOrder = 6,
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Text = "♥  Thanks for your support!  ♥",
	Font = Enum.Font.GothamBlack,
	TextSize = 18,
	TextColor3 = OUTLINE,
})

-- The HudChrome Shop tile opens it (PanelSwitch.Toggle("Shop")).
local openGift = require(script.Parent:WaitForChild("GiftPicker")).Create(panel, list, backdrop)
local function giftButton(box, product, reason)
	local enabled = product and (product.GiftProductId or 0) > 0 and (product.ProductId or 0) > 0
	local buy = box:FindFirstChild("Buy")
	if not buy then
		return
	end
	local bundle = box.Name == "Bundle"
	buy.AnchorPoint = Vector2.new(0, 1)
	buy.Position = bundle and UDim2.new(0.62, 0, 1, -42) or UDim2.new(0.04, 0, 1, -28)
	buy.Size = bundle and UDim2.fromScale(0.34, 0.25) or UDim2.fromScale(0.51, 0.2)
	local gift = make("TextButton", "Gift", box, {
		AnchorPoint = Vector2.new(1, 1),
		Position = bundle and UDim2.new(1, -8, 1, -6) or UDim2.new(0.96, 0, 1, -28),
		Size = bundle and UDim2.new(0.34, -8, 0, 30) or UDim2.fromScale(0.37, 0.2),
		Text = "Gift",
		Font = Enum.Font.FredokaOne,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(130, 75, 190),
		BackgroundTransparency = enabled and 0 or 0.45,
		Active = enabled == true,
		AutoButtonColor = enabled == true,
	})
	corner(gift, 8)
	if not enabled then
		local note = make("TextLabel", "GiftReason", box, {
			AnchorPoint = Vector2.new(0, 1),
			Position = bundle and UDim2.new(0, 6, 1, -2) or UDim2.new(0, 4, 1, -4),
			Size = bundle and UDim2.new(0.6, -12, 0, 18) or UDim2.new(1, -8, 0, 18),
			Text = reason or "Gift unavailable • coming soon",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = OUTLINE,
			TextScaled = true,
		})
		make("UITextSizeConstraint", "Max", note, { MaxTextSize = 11 })
	end
	gift.Activated:Connect(function()
		if enabled then
			openGift(product)
		end
	end)
end
for _, pass in config.Gamepasses do
	giftButton(grid[pass.Id], nil, "Account-bound • no gifting")
end
for _, product in config.Products do
	if product.Section == "Potions" then
		giftButton(packRow[product.Id], product)
	elseif product.Section == "Bundle" then
		giftButton(potions.Bundle, product)
	elseif product.Section == "ServerLuck" then
		giftButton(tiers[product.Id], nil, "Server-wide • no gifting")
	end
end
close.Activated:Connect(function()
	PanelSwitch.Close("Shop")
end)
require(script.Parent:WaitForChild("PanelFrame")).CloseOnOutsideClick(backdrop, function()
	PanelSwitch.Close("Shop")
end)

-- Opens in the shared band between the HUD entries (docs/HUD_LAYOUT_SPEC.md section 6).
require(script.Parent:WaitForChild("PanelFrame")).Attach(panel, {
	Theme = "Shop",
	Title = "Shop",
	Icon = Icons.Shop.Image,
	TitleObject = title,
	Close = close,
	MaxWidth = 900,
})
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	local columns = panel.AbsoluteSize.X < 560 and 2 or 3
	grid.Layout.CellSize = UDim2.new(1 / columns, -11, 0, 196)
	packRow.Layout.CellSize = UDim2.new(1 / columns, -11, 0, 196)
end)
-- Shop-only visual layer; purchases, ownership and gifting remain in this script.
ShopPresentation.Apply(panel, list, featuredRow, root)
