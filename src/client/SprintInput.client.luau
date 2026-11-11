--!nonstrict
-- Hold Shift to sprint on foot (docs/SPRINT_SPEC.md). Sends only the intent; Server/CarService decides the speed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetSprint")

local function isShift(keyCode)
	return keyCode == Enum.KeyCode.LeftShift or keyCode == Enum.KeyCode.RightShift
end

local sprinting = false
local function setSprinting(enabled)
	if sprinting ~= enabled then
		sprinting = enabled
		remote:FireServer(enabled)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and isShift(input.KeyCode) then
		setSprinting(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if
		isShift(input.KeyCode)
		and not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		and not UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	then
		setSprinting(false)
	end
end)

UserInputService.WindowFocusReleased:Connect(function()
	setSprinting(false)
end)
