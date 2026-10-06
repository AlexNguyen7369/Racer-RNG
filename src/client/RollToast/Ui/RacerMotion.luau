--!nonstrict
-- Local visual feedback only; never changes gameplay or layout spacing.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Motion = {}

function Motion.Attach(root)
	local connected = setmetatable({}, { __mode = "k" })
	local function attach(object)
		if object.Name == "Backdrop" or object.Name == "Toast" then
			return
		end
		if not object:IsA("TextButton") and not (object:IsA("Frame") and object:GetAttribute("CarId")) then
			return
		end
		if connected[object] then
			return
		end
		connected[object] = true
		local scale = Instance.new("UIScale")
		scale.Name = "HoverScale"
		scale.Parent = object
		local hovering = false
		local activeTween
		local function animate(value)
			if activeTween then
				activeTween:Cancel()
			end
			activeTween = TweenService:Create(
				scale,
				TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = value }
			)
			activeTween:Play()
		end
		object.MouseEnter:Connect(function()
			if not UserInputService.MouseEnabled then
				return
			end
			hovering = true
			animate(1.035)
		end)
		object.MouseLeave:Connect(function()
			hovering = false
			animate(1)
		end)
		object:GetPropertyChangedSignal("Visible"):Connect(function()
			if not object.Visible then
				hovering = false
				animate(1)
			end
		end)
		if object:IsA("TextButton") then
			object.MouseButton1Down:Connect(function()
				animate(0.97)
			end)
			object.MouseButton1Up:Connect(function()
				animate(hovering and 1.035 or 1)
			end)
		end
	end
	for _, object in ipairs(root:GetDescendants()) do
		attach(object)
	end
	root.DescendantAdded:Connect(attach)
end

return Motion
