--!nonstrict
-- Shows each auto-roll result for a moment (Remotes.RollResult, fired by the server's GachaService):
-- the car's name in its rarity colour, with "NEW!" the first time it enters the index. It never shows while
-- the index or stats panel is open (it would cover their buttons; the index shows the new car anyway).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared.CarCatalog)
local GachaConfig = require(Shared.GachaConfig)
local rollRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RollResult")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))

local SHOW_SECONDS = 1.6

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "RollToast"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -24) -- bottom centre
toast.Size = UDim2.fromOffset(320, 44)
toast.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.Font = Enum.Font.GothamBlack
toast.TextSize = 20
toast.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = toast
local stroke = Instance.new("UIStroke")
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Thickness = 2
stroke.Transparency = 1
stroke.Parent = toast

local shownAt = 0

local function hide()
	shownAt = 0
	toast.BackgroundTransparency, toast.TextTransparency, stroke.Transparency = 1, 1, 1
end
PanelSwitch.Changed:Connect(function()
	if PanelSwitch.AnyOpen() then
		hide()
	end
end)

rollRemote.OnClientEvent:Connect(function(id, isNew)
	local spec = CarCatalog.Get(id)
	if not spec or PanelSwitch.AnyOpen() then
		return
	end
	local color = GachaConfig.RARITY_COLORS[spec.Rarity] or Color3.new(1, 1, 1)
	toast.Text = (isNew and "NEW! " or "") .. spec.Name .. "  ·  " .. spec.Rarity
	toast.TextColor3 = spec.Rarity == "Secret" and Color3.new(1, 1, 1) or color
	stroke.Color = color
	toast.BackgroundTransparency, toast.TextTransparency, stroke.Transparency = 0.15, 0, 0
	local stamp = os.clock()
	shownAt = stamp
	task.delay(SHOW_SECONDS, function()
		if shownAt == stamp then
			local info = TweenInfo.new(0.3)
			TweenService:Create(toast, info, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		end
	end)
end)
