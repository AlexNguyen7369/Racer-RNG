--!nonstrict
-- Planned gamepass catalogue. Purchase ownership remains with Roblox/PassCarService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("MonetizationConfig"))
local catalog = require(shared:WaitForChild("CarCatalog"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local root = make("ScreenGui", "ShopUi", gui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 7,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local backdrop = make("TextButton", "Backdrop", root, {
	Size = UDim2.fromScale(1, 1),
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.fromRGB(8, 10, 22),
	BackgroundTransparency = 0.35,
	Visible = false,
})
PanelSwitch.Register("Shop", backdrop)
local panel = make("Frame", "Panel", backdrop, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 110),
	Size = UDim2.fromScale(0.78, 0.68),
	BackgroundColor3 = Color3.fromRGB(29, 32, 53),
	Active = true,
})
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
make("TextLabel", "Title", panel, {
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(1, -76, 0, 34),
	Text = "SHOP • GAMEPASSES",
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local close = make("TextButton", "Close", panel, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 8),
	Size = UDim2.fromOffset(38, 30),
	Text = "×",
	Font = Enum.Font.GothamBold,
	TextSize = 24,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = Color3.fromRGB(210, 70, 90),
})
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 7)
local list = make("ScrollingFrame", "Items", panel, {
	Position = UDim2.fromOffset(14, 54),
	Size = UDim2.new(1, -28, 1, -68),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
})
local _layout = make("UIGridLayout", "Layout", list, {
	CellSize = UDim2.new(0.48, 0, 0, 96),
	CellPadding = UDim2.fromOffset(10, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

local entries = {}
for _, item in config.Gamepasses do
	table.insert(entries, item)
end
for _, car in catalog.Passes() do
	table.insert(entries, {
		Id = car.Id,
		Name = car.Name,
		GamepassId = car.GamepassId,
		Description = string.format("%s car • x%s Speed", car.Rarity, tostring(car.SpeedMulti)),
	})
end
for order, item in entries do
	local card = make("Frame", item.Id, list, {
		BackgroundColor3 = Color3.fromRGB(49, 55, 78),
		LayoutOrder = order,
	})
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
	make("TextLabel", "Name", card, {
		Position = UDim2.fromOffset(12, 9),
		Size = UDim2.new(1, -126, 0, 24),
		Text = item.Name,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	make("TextLabel", "Description", card, {
		Position = UDim2.fromOffset(12, 35),
		Size = UDim2.new(1, -126, 0, 46),
		Text = item.Description,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(193, 205, 225),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local buy = make("TextButton", "Buy", card, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(98, 34),
		Text = item.GamepassId > 0 and "BUY" or "COMING SOON",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = item.GamepassId > 0 and Color3.fromRGB(70, 175, 105) or Color3.fromRGB(80, 88, 112),
		Active = item.GamepassId > 0,
	})
	Instance.new("UICorner", buy).CornerRadius = UDim.new(0, 7)
	buy.Activated:Connect(function()
		if item.GamepassId > 0 then
			MarketplaceService:PromptGamePassPurchase(player, item.GamepassId)
		end
	end)
end

-- The HudChrome Shop tile opens it (PanelSwitch.Toggle("Shop")).
close.Activated:Connect(function()
	PanelSwitch.Close("Shop")
end)
backdrop.Activated:Connect(function()
	PanelSwitch.Close("Shop")
end)

-- Opens in the shared band between the HUD entries (docs/HUD_LAYOUT_SPEC.md section 6).
require(script.Parent:WaitForChild("PanelBand")).Fit(panel, 900)
