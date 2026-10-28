--!nonstrict
-- Shared Backpack-style chrome; adopts existing controls so fixtures/remotes keep their paths.
local Band = require(script.Parent.PanelBand)
local Frame = {}
Frame.Themes = {
	Daily = { Color3.fromRGB(160, 15, 32), Color3.fromRGB(244, 55, 69) },
	Quests = { Color3.fromRGB(55, 80, 190), Color3.fromRGB(75, 180, 240) },
	Shop = { Color3.fromRGB(121, 65, 200), Color3.fromRGB(212, 110, 230) },
	Market = { Color3.fromRGB(255, 160, 60), Color3.fromRGB(250, 90, 170) },
	Backpack = { Color3.fromRGB(104, 104, 245), Color3.fromRGB(80, 170, 250) },
	Checkpoints = { Color3.fromRGB(150, 80, 240), Color3.fromRGB(90, 120, 250) },
}
local function child(parent, class, name)
	local value = parent:FindFirstChild(name)
	if not value then
		value = Instance.new(class)
		value.Name = name
		value.Parent = parent
	end
	return value
end

function Frame.Attach(panel, options)
	panel:SetAttribute("PanelFrame", true)
	panel.BorderSizePixel = 0
	panel.Active = true
	local rounding = panel:FindFirstChildOfClass("UICorner") or child(panel, "UICorner", "Corner")
	rounding.CornerRadius = UDim.new(0, 16)
	local edge = panel:FindFirstChildOfClass("UIStroke") or child(panel, "UIStroke", "FrameOutline")
	edge.Color = Color3.fromRGB(17, 19, 31)
	edge.Thickness = 3
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local header = child(panel, "Frame", "Header")
	header.Position = UDim2.new()
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.BorderSizePixel = 0
	header.ClipsDescendants = true
	header.ZIndex = 2
	child(header, "UICorner", "Corner").CornerRadius = UDim.new(0, 14)
	local gradient = header:FindFirstChildOfClass("UIGradient") or child(header, "UIGradient", "Gradient")
	local title = options.TitleObject or child(header, "TextLabel", "Title")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Rotation = 0
	title.TextScaled = true
	title.ZIndex = 4
	local sizeLimit = title:FindFirstChildOfClass("UITextSizeConstraint") or child(title, "UITextSizeConstraint", "Max")
	sizeLimit.MaxTextSize = 32
	local icon = options.IconObject or child(header, "ImageLabel", "Icon")
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 3
	local close = options.Close or child(header, "TextButton", "Close")
	close.BackgroundColor3 = Color3.fromRGB(232, 69, 60)
	close.BorderSizePixel = 0
	close.AnchorPoint = Vector2.new(1, 0)
	close.ZIndex = 5
	close.Text = close:FindFirstChild("X") and "" or "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 30
	local function layout()
		local compact = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y <= 500
		local h = compact and 48 or 64
		header.Size = UDim2.new(1, 0, 0, h)
		close.Position = UDim2.new(1, -6, 0, 6)
		close.Size = UDim2.fromOffset(h - 12, h - 12)
		title.Position = UDim2.fromOffset(h + 8, 6)
		title.Size = UDim2.new(1, -2 * h - 20, 0, h - 12)
		icon.Position = UDim2.fromOffset(10, 6)
		icon.Size = UDim2.fromOffset(h - 12, h - 12)
	end
	local controller = {}
	function controller:SetTheme(theme, text, image)
		local colors = Frame.Themes[theme] or Frame.Themes.Backpack
		gradient.Color = ColorSequence.new(colors[1], colors[2])
		if text then
			title.Text = text
		end
		if image then
			icon.Image = image
		end
		panel:SetAttribute("PanelTheme", theme)
	end
	controller:SetTheme(options.Theme, options.Title, options.Icon)
	layout()
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	Band.Fit(panel, options.MaxWidth or 760)
	controller.Header, controller.Close = header, close
	return controller
end

-- Owner 2026-10-20 (HUD_LAYOUT_SPEC section 6): a panel's dim backdrop is a non-interactive Frame so the HUD
-- tiles behind it stay clickable; a click that no GUI handled (empty screen) closes the panel instead.
-- "Handled" is judged from the PlayerGui objects under the pointer (a GuiButton, TextBox or Active GuiObject takes
-- the click), not only from gameProcessedEvent, which can report true for a click on empty screen.
local function shown(object)
	while object do
		if
			(object:IsA("GuiObject") and not object.Visible) or (object:IsA("LayerCollector") and not object.Enabled)
		then
			return false
		end
		object = object.Parent
	end
	return true
end

local function takesClick(playerGui, position)
	for _, hit in playerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
		if (hit:IsA("GuiButton") or hit:IsA("TextBox") or hit.Active) and shown(hit) then
			return true
		end
	end
	return false
end

function Frame.CloseOnOutsideClick(backdrop, close)
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	game:GetService("UserInputService").InputBegan:Connect(function(input)
		local click = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		if click and backdrop.Visible and not takesClick(playerGui, input.Position) then
			close()
		end
	end)
end

return Frame
