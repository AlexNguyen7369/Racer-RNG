--!nonstrict
if script.Parent:FindFirstChild("RollToast") then
	return
end
if script.Parent:FindFirstChild("RollToast") then
	return
end

-- The car index: an INDEX button on the right opens a grid of every catalog car (Shared/CarCatalog) in
-- index order. Undiscovered cars are dark "?" tiles that show only their rarity and odds; discovered cars
-- show a transparent "?" placeholder (no models yet) with name and multi, and can be equipped.
-- Everything shown comes from the server (player.GachaData, player attributes); Equip only asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared.CarCatalog)
local GachaConfig = require(Shared.GachaConfig)
local HudFormat = require(Shared.HudFormat)
local RollAnimConfig = require(Shared.RollAnimConfig)
local equipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EquipCar")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local data = player:WaitForChild("GachaData")

local PANEL_BG = Color3.fromRGB(20, 28, 48)
local TOP_CLEAR = RollAnimConfig.PANEL_TOP -- below the Auto Race button and the compact roll under it
local BOTTOM_CLEAR = 74 -- and ends above the bottom strip (Client/RollUi TURBO LUCK bar and its pop text)
local TILE_BG = Color3.fromRGB(34, 44, 70)
local LOCKED_BG = Color3.fromRGB(12, 14, 22)
local WHITE = Color3.fromRGB(255, 255, 255)

local gui = Instance.new("ScreenGui")
gui.Name = "IndexUi"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function round(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
end

local function text(parent, name, str, size, font, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -8, 0, size + 2)
	l.Text = str
	l.TextSize = size
	l.Font = font
	l.TextColor3 = color
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local open = Instance.new("TextButton")
open.Name = "OpenIndex"
open.AnchorPoint = Vector2.new(1, 0.5)
open.Position = UDim2.new(1, -16, 0.5, -32)
open.Size = UDim2.fromOffset(110, 48)
open.BackgroundColor3 = Color3.fromRGB(70, 140, 255)
open.Font = Enum.Font.GothamBlack
open.TextSize = 20
open.TextColor3 = WHITE
open.Text = "INDEX"
open.Parent = gui
round(open, 12)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, TOP_CLEAR)
panel.Size = UDim2.new(0.6, 0, 1, -TOP_CLEAR - BOTTOM_CLEAR)
panel.BackgroundColor3 = PANEL_BG
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = gui
round(panel, 16)
local limit = Instance.new("UISizeConstraint")
limit.MinSize = Vector2.new(320, 110) -- still ends above the bottom strip on a phone
limit.MaxSize = Vector2.new(760, 560)
limit.Parent = panel

local header = text(panel, "Header", "INDEX", 22, Enum.Font.GothamBlack, WHITE)
header.Position = UDim2.fromOffset(16, 12)
header.TextXAlignment = Enum.TextXAlignment.Left
local progress = text(panel, "Progress", "", 14, Enum.Font.Gotham, Color3.fromRGB(200, 210, 230))
progress.Position = UDim2.fromOffset(16, 40)
progress.Size = UDim2.new(1, -72, 0, 16) -- clear of the Close button
progress.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton")
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 12)
close.Size = UDim2.fromOffset(36, 36)
close.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
close.Font = Enum.Font.GothamBlack
close.TextSize = 18
close.TextColor3 = WHITE
close.Text = "X"
close.Parent = panel
round(close, 10)

local grid = Instance.new("ScrollingFrame")
grid.Name = "Grid"
grid.Position = UDim2.fromOffset(12, 68)
grid.Size = UDim2.new(1, -24, 1, -80)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 6
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.CanvasSize = UDim2.new()
grid.Parent = panel
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.fromOffset(132, 176)
layout.CellPadding = UDim2.fromOffset(10, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

local tiles = {} -- car Id -> { Frame, Icon, Name, Info, Equip }

for _, spec in CarCatalog.All() do
	local tile = Instance.new("Frame")
	tile.Name = spec.Id
	tile.LayoutOrder = spec.Order
	tile.BackgroundColor3 = TILE_BG
	tile.Parent = grid
	round(tile, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = GachaConfig.RARITY_COLORS[spec.Rarity] or WHITE
	stroke.Parent = tile

	-- Placeholder art: a big "?" (no car models yet; spec.Model will replace it)
	local icon = text(tile, "Icon", "?", 64, Enum.Font.GothamBlack, WHITE)
	icon.Size = UDim2.new(1, 0, 0, 80)
	icon.Position = UDim2.fromOffset(0, 4)
	local name = text(tile, "CarName", "", 14, Enum.Font.GothamBold, WHITE)
	name.Position = UDim2.fromOffset(4, 86)
	local info = text(tile, "Info", "", 12, Enum.Font.Gotham, Color3.fromRGB(200, 210, 230))
	info.Position = UDim2.fromOffset(4, 104)
	info.Size = UDim2.new(1, -8, 0, 28)
	info.TextWrapped = true

	local equip = Instance.new("TextButton")
	equip.Name = "Equip"
	equip.AnchorPoint = Vector2.new(0.5, 1)
	equip.Position = UDim2.new(0.5, 0, 1, -6)
	equip.Size = UDim2.new(1, -16, 0, 28)
	equip.Font = Enum.Font.GothamBold
	equip.TextSize = 14
	equip.TextColor3 = WHITE
	equip.Parent = tile
	round(equip, 8)
	equip.Activated:Connect(function()
		if equip.Active then
			equipRemote:FireServer(spec.Id)
		end
	end)

	tiles[spec.Id] = { Frame = tile, Icon = icon, Name = name, Info = info, Equip = equip, Spec = spec }
end

local function refresh()
	local equipped = player:GetAttribute("EquippedCar")
	local unique = 0
	for id, t in tiles do
		local found = data:FindFirstChild(id) ~= nil -- discovering a car = owning it
		local spec = t.Spec
		local odds = spec.Chance and HudFormat.Odds(spec.Chance) or "Common drop"
		if found then
			unique += 1
			t.Frame.BackgroundColor3 = TILE_BG
			t.Icon.TextTransparency = 0.7 -- transparent placeholder until the car has a model
			t.Name.Text = spec.Name
			t.Info.Text = string.format("%s · x%s Speed\n%s", spec.Rarity, tostring(spec.SpeedMulti), odds)
			t.Equip.Visible = true
			local isOn = equipped == id
			t.Equip.Text = isOn and "Equipped" or "Equip"
			t.Equip.Active = not isOn
			t.Equip.AutoButtonColor = not isOn -- a disabled button does not highlight
			t.Equip.BackgroundColor3 = isOn and Color3.fromRGB(90, 90, 110) or Color3.fromRGB(60, 180, 90)
		else
			t.Frame.BackgroundColor3 = LOCKED_BG
			t.Icon.TextTransparency = 0
			t.Name.Text = "???"
			t.Info.Text = spec.Rarity .. "\n" .. odds
			t.Equip.Visible = false
		end
	end
	local per = GachaConfig.DISCOVERIES_PER_POINT
	progress.Text = string.format(
		"Discovered %d / %d  ·  next stat point in %d  ·  equipped: %s",
		unique,
		#CarCatalog.All(),
		per - unique % per,
		(CarCatalog.Get(equipped) or CarCatalog.Get(CarCatalog.STARTER_ID)).Name
	)
end

data.ChildAdded:Connect(refresh)
data.ChildRemoved:Connect(refresh)
player:GetAttributeChangedSignal("EquippedCar"):Connect(refresh)

PanelSwitch.Register("Index", panel)
open.Activated:Connect(function()
	if PanelSwitch.Toggle("Index") then
		refresh()
	end
end)
close.Activated:Connect(function()
	PanelSwitch.Close("Index")
end)
refresh()
