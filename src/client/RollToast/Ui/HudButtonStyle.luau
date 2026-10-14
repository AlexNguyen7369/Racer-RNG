--!nonstrict
-- Shared presentation for the handcrafted HUD entries; existing handlers remain on each button.
local Style = {}
local Components = require(script.Parent.RacerComponents)
local OUTLINE = Color3.fromRGB(12, 16, 30)
Style.Colors = {
	Upgrades = Color3.fromRGB(30, 216, 255),
	Bag = Color3.fromRGB(172, 99, 238),
	Daily = Color3.fromRGB(60, 255, 60),
	Market = Color3.fromRGB(255, 180, 45),
}
local function stroke(parent, name, mode, thickness)
	local edge = parent:FindFirstChild(name) or Instance.new("UIStroke")
	edge.Name, edge.ApplyStrokeMode = name, mode
	edge.Color, edge.Thickness = OUTLINE, thickness
	edge.Parent = parent
end

function Style.SetCaption(button, value)
	-- Generated Face buttons are blank hitboxes. Update only their named caption,
	-- never every TextLabel (which would also overwrite badges).
	local caption = button:FindFirstChild("HudCaption") or button:FindFirstChild(button.Parent.Name .. "Label")
	if caption and caption:IsA("TextLabel") then
		button.Text = ""
		button:SetAttribute("RacerCaption", value)
		if not caption:GetAttribute("RacerCaptionBound") then
			caption:SetAttribute("RacerCaptionBound", true)
			caption:GetPropertyChangedSignal("Text"):Connect(function()
				local current = button:GetAttribute("RacerCaption")
				if current and caption.Text ~= current then caption.Text = current end
			end)
		end
		caption.Text = value
	elseif button:IsA("TextLabel") or button:IsA("TextButton") then
		button.Text = value
	end
end

function Style.Utility(button, slot, color)
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled, button.TextWrapped = true, true
	button.TextTruncate = Enum.TextTruncate.None
	button.ZIndex = 3
	button:SetAttribute("RacerHover", true)
	local corner = button:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, 10), button
	stroke(button, "RacerBorder", Enum.ApplyStrokeMode.Border, 3)
	Components.Tint(button, color)
	local shadow = Instance.new("Frame")
	shadow.Name, shadow.BorderSizePixel = button.Name .. "Shadow", 0
	shadow.BackgroundColor3 = color:Lerp(OUTLINE, .6):Lerp(Color3.fromRGB(27,42,143), .3)
	shadow.BackgroundTransparency, shadow.ZIndex = .4, 2
	shadow.Parent = button.Parent
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius, shadowCorner.Parent = UDim.new(0,10), shadow
	local function syncShadow()
		shadow.AnchorPoint, shadow.Size, shadow.Visible = button.AnchorPoint, button.Size, button.Visible
		local p = button.Position
		shadow.Position = UDim2.new(p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset+4)
	end
	for _,property in {"AnchorPoint","Position","Size","Visible"} do
		button:GetPropertyChangedSignal(property):Connect(syncShadow)
	end
	local padding = button:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	padding.Parent = button
	local textSize = button:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	local caption = Instance.new("TextLabel")
	caption.Name, caption.BackgroundTransparency = "HudCaption", 1
	caption.Size = UDim2.fromScale(1, 1)
	caption.Font, caption.TextColor3 = Enum.Font.FredokaOne, Color3.new(1, 1, 1)
	caption.TextScaled, caption.TextWrapped, caption.ZIndex = true, true, 5
	caption.Text, caption.Parent = button.Text, button
	textSize.MinTextSize, textSize.MaxTextSize, textSize.Parent = 14, 23, caption
	stroke(caption, "RacerTextOutline", Enum.ApplyStrokeMode.Contextual, 3)
	button.Text = ""
	button:GetPropertyChangedSignal("Text"):Connect(function()
		if button.Text ~= "" then
			caption.Text = button.Text
			button.Text = ""
		end
	end)
	local lift = Instance.new("Frame")
	lift.Name, lift.BackgroundColor3 = "RacerLift", Color3.new(1, 1, 1)
	lift.BackgroundTransparency, lift.BorderSizePixel = 0.7, 0
	lift.Position, lift.Size = UDim2.fromOffset(4, 2), UDim2.new(1, -8, 0, 5)
	lift.ZIndex, lift.Parent = 4, button
	local liftCorner = Instance.new("UICorner")
	liftCorner.CornerRadius, liftCorner.Parent = UDim.new(0, 8), lift
	-- RacerMotion already attaches hover feedback to PlayerGui buttons.
	local function fit()
		local camera = workspace.CurrentCamera
		if not camera or camera.ViewportSize.X <= 1 then return end
		local viewport = camera.ViewportSize
		local phone = viewport.Y <= 500
		local k = phone and math.clamp(viewport.Y / 390, 0.85, 1.15) or math.clamp(viewport.Y / 720, 0.6, 1.4)
		local width, height, gap = (phone and 118 or 160) * k, 48 * k, 22 * k
		local top = (phone and 0.44 or 0.45) * viewport.Y - (phone and 184 or 206) * k / 2
		button.AnchorPoint = Vector2.new(1, 0)
		button.Size = UDim2.fromOffset(width, height)
		button.Position = UDim2.new(1, -(phone and 12 or 22), 0, top + (slot - 1) * (height + gap))
	end
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	fit()
	syncShadow()
end

return Style
