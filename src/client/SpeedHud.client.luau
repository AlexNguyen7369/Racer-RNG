--!nonstrict
-- Stats panel on the left of the screen. It shows the Speed stat (leaderstats.Speed, grown by the server
-- while the car drives) with Money (leaderstats.Money) under it and the run's banked winnings (player attribute
-- Unbanked, paid into Money when auto racing stops) under that; all count smoothly as they change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HudFormat = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudFormat"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 16, 0.5, 0) -- left edge, vertically centred
panel.Size = UDim2.fromOffset(150, 184)
panel.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
panel.BackgroundTransparency = 0.25
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local function label(name, text, size, position, color, font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -16, 0, size)
	l.Position = position
	l.Text = text
	l.TextColor3 = color
	l.Font = font
	l.TextSize = size
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = panel
	return l
end

label("Title", "SPEED", 14, UDim2.fromOffset(12, 8), Color3.fromRGB(137, 207, 240), Enum.Font.GothamBold)
local value = label("Value", "0", 36, UDim2.fromOffset(12, 24), Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
local rate =
	label("Rate", HudFormat.RateText(0), 14, UDim2.fromOffset(12, 68), Color3.fromRGB(200, 210, 230), Enum.Font.Gotham)

label("MoneyTitle", "MONEY", 14, UDim2.fromOffset(12, 92), Color3.fromRGB(255, 214, 64), Enum.Font.GothamBold)
local moneyValue =
	label("MoneyValue", "$0", 26, UDim2.fromOffset(12, 108), Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)

label("UnbankedTitle", "UNBANKED", 14, UDim2.fromOffset(12, 138), Color3.fromRGB(255, 170, 40), Enum.Font.GothamBold)
local unbankedValue =
	label("UnbankedValue", "$0", 22, UDim2.fromOffset(12, 154), Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)

local stats = player:WaitForChild("leaderstats")
local speedStat = stats:WaitForChild("Speed")
local moneyStat = stats:WaitForChild("Money")

local shown = speedStat.Value
local shownMoney = moneyStat.Value
local function unbanked()
	local v = player:GetAttribute("Unbanked")
	return type(v) == "number" and v or 0
end
local shownUnbanked = unbanked()
-- Heartbeat, not RenderStepped: the numbers stay current even on frames that do not render
RunService.Heartbeat:Connect(function(dt)
	shown = HudFormat.Approach(shown, speedStat.Value, dt)
	value.Text = HudFormat.SpeedText(shown)
	rate.Text = HudFormat.RateText(shown)
	shownMoney = HudFormat.Approach(shownMoney, moneyStat.Value, dt)
	moneyValue.Text = HudFormat.MoneyText(shownMoney)
	shownUnbanked = HudFormat.Approach(shownUnbanked, unbanked(), dt)
	unbankedValue.Text = HudFormat.MoneyText(shownUnbanked)
end)
