--!nonstrict
-- The "Stop Auto" / "Auto Race" button at the top centre of the screen. It only asks: the server
-- (CarService.SetAutoRace) decides, and the label always follows the server's player attribute AutoRacing,
-- so the button can never show a state the game is not in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudFormat = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudFormat"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetAutoRace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local STOP_COLOR = Color3.fromRGB(220, 70, 70)
local RACE_COLOR = Color3.fromRGB(60, 180, 90)
local PENDING_SECONDS = 1 -- the button stays greyed out this long after a press (server cooldown is shorter)

local gui = Instance.new("ScreenGui")
gui.Name = "AutoRaceButton"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "Toggle"
button.AnchorPoint = Vector2.new(0.5, 0)
button.Position = UDim2.new(0.5, 0, 0, 12) -- top centre
button.Size = UDim2.fromOffset(180, 48)
button.Font = Enum.Font.GothamBlack
button.TextSize = 22
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.AutoButtonColor = true
button.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = button
local stroke = Instance.new("UIStroke")
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Color = Color3.fromRGB(20, 28, 48)
stroke.Thickness = 2
stroke.Parent = button

local pending = false

local function refresh()
	local racing = player:GetAttribute("AutoRacing") == true
	button.Text = HudFormat.AutoButtonText(racing)
	button.BackgroundColor3 = racing and STOP_COLOR or RACE_COLOR
	button.BackgroundTransparency = pending and 0.5 or 0
	button.Active = not pending
end

button.Activated:Connect(function()
	if pending then
		return
	end
	pending = true
	refresh()
	remote:FireServer(player:GetAttribute("AutoRacing") ~= true)
	task.delay(PENDING_SECONDS, function()
		pending = false
		refresh()
	end)
end)

player:GetAttributeChangedSignal("AutoRacing"):Connect(refresh)
refresh()
