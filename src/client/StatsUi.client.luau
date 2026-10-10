--!nonstrict
if script.Parent:FindFirstChild("RollToast") then
	return
end
if script.Parent:FindFirstChild("RollToast") then
	return
end

-- Stat points: a STATS button on the right opens a panel with the free points (player attribute StatPoints,
-- earned from the index, see GachaConfig) and one row per stat with a "+" that asks the server to spend a
-- point (Remotes.AllocateStat). The server decides; the rows always show its attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GachaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GachaConfig"))
local allocRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AllocateStat")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WHITE = Color3.fromRGB(255, 255, 255)
local TOP_CLEAR = 68 -- the panel starts below the Auto Race button (top centre, 12 + 48 px)
local ROW_STEP = 44
local PANEL_HEIGHT = 60 + ROW_STEP * #GachaConfig.STATS
local LABELS = {
	Speed = "Base Speed Multi",
	Money = "Base Money Multi",
	Luck = "Luck Multi",
	Workshop = "Workshop Multi",
}
local DISABLED = { Workshop = "Workshop coming soon" } -- no workshop yet

local gui = Instance.new("ScreenGui")
gui.Name = "StatsUi"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function round(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
end

local function label(parent, name, str, size, font, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = str
	l.TextSize = size
	l.Font = font
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local open = Instance.new("TextButton")
open.Name = "OpenStats"
open.AnchorPoint = Vector2.new(1, 0.5)
open.Position = UDim2.new(1, -16, 0.5, 32)
open.Size = UDim2.fromOffset(110, 48)
open.BackgroundColor3 = Color3.fromRGB(170, 80, 230)
open.Font = Enum.Font.GothamBlack
open.TextSize = 20
open.TextColor3 = WHITE
open.Text = "STATS"
open.Parent = gui
round(open, 12)
local badge = label(open, "Badge", "", 14, Enum.Font.GothamBlack, WHITE)
badge.AnchorPoint = Vector2.new(0.5, 0.5)
badge.Position = UDim2.fromScale(1, 0)
badge.Size = UDim2.fromOffset(26, 26)
badge.TextXAlignment = Enum.TextXAlignment.Center
badge.BackgroundTransparency = 0
badge.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
round(badge, 13)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -140, 0, TOP_CLEAR)
-- Narrower on small screens so its left edge stays right of the compact roll at the top centre (it ends at 0.56 x
-- the screen width): the two never overlap (docs/ROLL_ANIMATION_CONTRACT.md)
panel.Size = UDim2.new(0.44, -150, 0, PANEL_HEIGHT)
local panelLimit = Instance.new("UISizeConstraint")
panelLimit.MaxSize = Vector2.new(300, PANEL_HEIGHT)
panelLimit.Parent = panel
panel.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = gui
round(panel, 14)

local points = label(panel, "Points", "", 18, Enum.Font.GothamBlack, WHITE)
points.Position = UDim2.fromOffset(14, 10)
points.Size = UDim2.new(1, -28, 0, 22)
local hint = label(panel, "Hint", "", 12, Enum.Font.Gotham, Color3.fromRGB(200, 210, 230))
hint.Position = UDim2.fromOffset(14, 32)
hint.Size = UDim2.new(1, -28, 0, 16)
hint.Text = string.format("+1 point per %d new cars in the index", GachaConfig.DISCOVERIES_PER_POINT)

local rows = {}
for i, stat in GachaConfig.STATS do
	local row = Instance.new("Frame")
	row.Name = stat
	row.Position = UDim2.fromOffset(10, 56 + (i - 1) * ROW_STEP)
	row.Size = UDim2.new(1, -20, 0, ROW_STEP - 4)
	row.BackgroundColor3 = Color3.fromRGB(34, 44, 70)
	row.Parent = panel
	round(row, 10)
	local name = label(row, "StatName", LABELS[stat], 14, Enum.Font.GothamBold, WHITE)
	name.Position = UDim2.fromOffset(10, 2)
	name.Size = UDim2.new(1, -70, 0, 18)
	local value = label(row, "Value", "", 12, Enum.Font.Gotham, Color3.fromRGB(200, 210, 230))
	value.Position = UDim2.fromOffset(10, 21)
	value.Size = UDim2.new(1, -70, 0, 16)
	local plus = Instance.new("TextButton")
	plus.Name = "Plus"
	plus.AnchorPoint = Vector2.new(1, 0.5)
	plus.Position = UDim2.new(1, -8, 0.5, 0)
	plus.Size = UDim2.fromOffset(44, 32)
	plus.Font = Enum.Font.GothamBlack
	plus.TextSize = 22
	plus.TextColor3 = WHITE
	plus.Text = "+"
	plus.Parent = row
	round(plus, 8)
	plus.Activated:Connect(function()
		if plus.Active then
			allocRemote:FireServer(stat)
		end
	end)
	rows[stat] = { Value = value, Plus = plus }
end

local function refresh()
	local free = player:GetAttribute("StatPoints") or 0
	points.Text = string.format("Stat points: %d", free)
	badge.Text = tostring(free)
	badge.Visible = free > 0
	local alloc = {}
	for _, stat in GachaConfig.STATS do
		alloc[stat] = player:GetAttribute("Alloc_" .. stat) or 0
	end
	local multis = GachaConfig.Multis(alloc)
	for _, stat in GachaConfig.STATS do
		local r = rows[stat]
		local disabled = DISABLED[stat]
		r.Value.Text = disabled
			or string.format(
				"%d pts · x%.2f (+%.2f per point)",
				alloc[stat],
				multis[stat],
				GachaConfig.PER_POINT[stat]
			)
		local can = free > 0 and not disabled
		r.Plus.Active = can
		r.Plus.AutoButtonColor = can
		r.Plus.BackgroundColor3 = can and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(90, 90, 110)
	end
end

player:GetAttributeChangedSignal("StatPoints"):Connect(refresh)
for _, stat in GachaConfig.STATS do
	player:GetAttributeChangedSignal("Alloc_" .. stat):Connect(refresh)
end
PanelSwitch.Register("Stats", panel)
open.Activated:Connect(function()
	PanelSwitch.Toggle("Stats")
end)
refresh()
