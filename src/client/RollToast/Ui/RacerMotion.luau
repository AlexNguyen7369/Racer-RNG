--!nonstrict
-- Local visual feedback only; never changes gameplay or layout spacing.
local UiMotion = require(script.Parent.Parent.Parent:WaitForChild("UiMotion"))
local UserInputService = game:GetService("UserInputService")
local Motion = {}

function Motion.Attach(root)
	local connected = setmetatable({}, { __mode = "k" })
	local pressSound = root:FindFirstChild("HudPressSound")
	if not pressSound then
		pressSound = Instance.new("Sound")
		pressSound.Name = "HudPressSound"
		-- Roblox's bundled slider tick becomes a soft, short bubble-pop when
		-- pitched up. Keeping it as rbxasset avoids an external audio upload.
		pressSound.SoundId = "rbxasset://sounds/volume_slider.ogg"
		pressSound.PlaybackSpeed = 1.35
		pressSound.Volume = 0.22
		pressSound.Parent = root
	end
	local function attach(object)
		if object.Name == "Backdrop" or object.Name == "Toast" then
			return
		end
		if
			not object:IsA("GuiButton")
			and not (object:IsA("Frame") and (object:GetAttribute("CarId") or object:GetAttribute("RacerHover")))
		then
			return
		end
		if connected[object] then
			return
		end
		connected[object] = true
		local scale = Instance.new("UIScale")
		scale.Name = "HoverScale"
		scale.Parent = object
		local hoverStroke = object:FindFirstChild("RacerHoverHighlight")
		if not hoverStroke then
			hoverStroke = Instance.new("UIStroke")
			hoverStroke.Name = "RacerHoverHighlight"
			hoverStroke.Color = Color3.new(1, 1, 1)
			hoverStroke.Thickness = 3
			hoverStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			hoverStroke.Transparency = 1
			hoverStroke.Parent = object
		end
		local hovering = false
		local activeTween
		local function animate(value)
			if activeTween then
				activeTween:Cancel()
			end
			activeTween = UiMotion.Create(
				scale,
				TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = value }
			)
			activeTween:Play()
		end
		local function highlight(value)
			UiMotion.Create(
				hoverStroke,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = value }
			)
				:Play()
		end
		object.MouseEnter:Connect(function()
			if not UserInputService.MouseEnabled then
				return
			end
			hovering = true
			animate(1.035)
			highlight(0)
		end)
		object.MouseLeave:Connect(function()
			hovering = false
			animate(1)
			highlight(1)
		end)
		object:GetPropertyChangedSignal("Visible"):Connect(function()
			if not object.Visible then
				hovering = false
				animate(1)
				highlight(1)
			end
		end)
		if object:IsA("GuiButton") then
			object.MouseButton1Down:Connect(function()
				animate(0.97)
			end)
			object.MouseButton1Up:Connect(function()
				animate(hovering and 1.035 or 1)
			end)
			object.Activated:Connect(function()
				-- Restarting one short local sound keeps rapid clicks responsive without
				-- creating a Sound instance per button press.
				pressSound:Stop()
				pressSound:Play()
				animate(0.94)
				task.delay(0.08, function()
					if object.Parent and object.Visible then
						animate(hovering and 1.035 or 1)
					end
				end)
			end)
		end
	end
	for _, object in ipairs(root:GetDescendants()) do
		attach(object)
	end
	root.DescendantAdded:Connect(attach)
end

return Motion
