--!nonstrict
-- GENERATED from ui/specs/RacerIndex.ui.json. DO NOT EDIT: change the spec and run ui/tooling/gen_atlas.py.
-- spec-hash: 80e4155a1165
-- Build(playerGui) creates the ScreenGui and returns refs: refs[<node id>] for every node (buttons: the Face
-- TextButton, connect .Activated to it), refs.Gui for the ScreenGui.

local function new(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local Ui = {}

Ui.SpecHash = "80e4155a1165"

function Ui.Build(playerGui)
	local refs = {}
	local scales = {} -- { UIScale, desktop zoom, phone zoom }
	local layouts = {} -- { instance, desktop props, phone props }
	local gui = new("ScreenGui", {
		Name = "RacerIndex",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	gui:SetAttribute("SpecHash", "80e4155a1165")
	refs.Gui = gui
	local v1 = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.55, 0.52),
		Size = UDim2.fromOffset(780, 524),
		Visible = true,
		BackgroundTransparency = 1,
	}, gui)
	local v1s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(18, 26, 65),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v1)
	corner(v1s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(18, 26, 65),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v1s)
	local v1f = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, v1)
	corner(v1f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(59, 68, 93), Color3.fromRGB(28, 38, 62)) },
		v1f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v1f
	)
	local v1l = new("Frame", {
		Name = "Lift",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v1f)
	corner(v1l, 3)
	refs["Panel"] = v1f
	table.insert(scales, { new("UIScale", {}, v1), 1, 1 })
	table.insert(layouts, {
		v1,
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.55, 0.52),
			Size = UDim2.fromOffset(780, 524),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.62, 0.56),
			Size = UDim2.fromOffset(500, 280),
			Visible = true,
		},
	})
	local v2 = new("Frame", {
		Name = "Header",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(756, 64),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	local v2s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(18, 81, 123),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v2)
	corner(v2s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(18, 81, 123),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v2s)
	local v2f = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, v2)
	corner(v2f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(57, 221, 255), Color3.fromRGB(26, 190, 224)) },
		v2f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v2f
	)
	local v2l = new("Frame", {
		Name = "Lift",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v2f)
	corner(v2l, 3)
	refs["Header"] = v2f
	table.insert(layouts, {
		v2,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(756, 64),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(484, 48),
			Visible = true,
		},
	})
	local v3 = new("Frame", {
		Name = "CarsTab",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.fromOffset(190, 48),
		Visible = true,
		BackgroundTransparency = 1,
	}, v2f)
	local v3s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(18, 81, 123),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v3)
	corner(v3s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(18, 81, 123),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v3s)
	local v3f = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Text = "",
		AutoButtonColor = false,
	}, v3)
	corner(v3f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(57, 221, 255), Color3.fromRGB(26, 190, 224)) },
		v3f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v3f
	)
	local v3l = new("Frame", {
		Name = "Lift",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v3f)
	corner(v3l, 3)
	refs["CarsTab"] = v3f
	table.insert(layouts, {
		v3,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(18, 8),
			Size = UDim2.fromOffset(190, 48),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.fromOffset(140, 48),
			Visible = true,
		},
	})
	local v4 = new("TextLabel", {
		Name = "CarsTabLabel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "CARS",
		TextSize = 25,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v3f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v4
	)
	refs["CarsTabLabel"] = v4
	table.insert(layouts, {
		v4,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextSize = 25,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextSize = 22,
			Visible = true,
		},
	})
	local v5 = new("Frame", {
		Name = "ConsumablesTab",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(228, 8),
		Size = UDim2.fromOffset(270, 48),
		Visible = true,
		BackgroundTransparency = 1,
	}, v2f)
	local v5s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(18, 26, 65),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v5)
	corner(v5s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(18, 26, 65),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v5s)
	local v5f = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Text = "",
		AutoButtonColor = false,
	}, v5)
	corner(v5f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(59, 68, 93), Color3.fromRGB(28, 38, 62)) },
		v5f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v5f
	)
	local v5l = new("Frame", {
		Name = "Lift",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v5f)
	corner(v5l, 3)
	refs["ConsumablesTab"] = v5f
	table.insert(layouts, {
		v5,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(228, 8),
			Size = UDim2.fromOffset(270, 48),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(168, 0),
			Size = UDim2.fromOffset(214, 48),
			Visible = true,
		},
	})
	local v6 = new("TextLabel", {
		Name = "ConsumablesTabLabel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "CONSUMABLES",
		TextSize = 23,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v5f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v6
	)
	refs["ConsumablesTabLabel"] = v6
	table.insert(layouts, {
		v6,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextSize = 23,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextSize = 20,
			Visible = true,
		},
	})
	local v7 = new("Frame", {
		Name = "Close",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(692, 6),
		Size = UDim2.fromOffset(52, 52),
		Visible = true,
		BackgroundTransparency = 1,
	}, v2f)
	local v7s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(88, 37, 73),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v7)
	corner(v7s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(88, 37, 73),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v7s)
	local v7f = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Text = "",
		AutoButtonColor = false,
	}, v7)
	corner(v7f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 98, 113), Color3.fromRGB(224, 68, 83)) },
		v7f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v7f
	)
	local v7l = new("Frame", {
		Name = "Lift",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v7f)
	corner(v7l, 3)
	refs["Close"] = v7f
	table.insert(layouts, {
		v7,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(692, 6),
			Size = UDim2.fromOffset(52, 52),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(428, 0),
			Size = UDim2.fromOffset(48, 48),
			Visible = true,
		},
	})
	local v8 = new("TextLabel", {
		Name = "CloseLabel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "X",
		TextSize = 26,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v7f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v8
	)
	refs["CloseLabel"] = v8
	table.insert(layouts, {
		v8,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextSize = 26,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextSize = 24,
			Visible = true,
		},
	})
	local v9 = new("TextLabel", {
		Name = "IndexProgress",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 92),
		Size = UDim2.fromOffset(748, 26),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "3 / 7 DISCOVERED",
		TextSize = 21,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v1f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v9
	)
	refs["IndexProgress"] = v9
	table.insert(layouts, {
		v9,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(16, 92),
			Size = UDim2.fromOffset(748, 26),
			TextSize = 21,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(12, 72),
			Size = UDim2.fromOffset(476, 22),
			TextSize = 18,
			Visible = true,
		},
	})
	local v10 = new("Frame", {
		Name = "GridHost",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 134),
		Size = UDim2.fromOffset(748, 374),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	refs["GridHost"] = v10
	table.insert(layouts, {
		v10,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(16, 134),
			Size = UDim2.fromOffset(748, 374),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(12, 100),
			Size = UDim2.fromOffset(476, 168),
			Visible = true,
		},
	})
	local v11 = new("Frame", {
		Name = "ConsumablesHost",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 134),
		Size = UDim2.fromOffset(748, 374),
		Visible = false,
		BackgroundTransparency = 1,
	}, v1f)
	refs["ConsumablesHost"] = v11
	table.insert(layouts, {
		v11,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(16, 134),
			Size = UDim2.fromOffset(748, 374),
			Visible = false,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(12, 100),
			Size = UDim2.fromOffset(476, 168),
			Visible = false,
		},
	})
	local function fit()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local height = camera.ViewportSize.Y
		local phone = height <= 500
		local k = if phone then math.clamp(height / 390, 0.85, 1.15) else math.clamp(height / 720, 0.6, 1.4)
		for _, scale in ipairs(scales) do
			scale[1].Scale = k * (if phone then scale[3] else scale[2])
		end
		for _, row in ipairs(layouts) do
			for key, value in pairs(if phone then row[3] else row[2]) do
				row[1][key] = value
			end
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	return refs
end

function Ui.Bind(playerGui)
	local saved = playerGui:WaitForChild("RacerIndex")
	assert(
		saved:IsA("ScreenGui") and saved:GetAttribute("SpecHash") == "80e4155a1165",
		"Saved UI is stale; regenerate and bake it in Edit mode"
	)
	local function new(className, props, parent)
		local inst = parent:FindFirstChild(props.Name or className)
		assert(inst and inst:IsA(className), "Saved UI is missing " .. (props.Name or className))
		return inst
	end
	local function corner(parent, _radius)
		assert(parent:FindFirstChildOfClass("UICorner"), "Saved UI corner is missing")
	end
	local refs = {}
	local scales = {} -- { UIScale, desktop zoom, phone zoom }
	local layouts = {} -- { instance, desktop props, phone props }
	local gui = new("ScreenGui", {
		Name = "RacerIndex",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	gui:SetAttribute("SpecHash", "80e4155a1165")
	refs.Gui = gui
	local v1 = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.55, 0.52),
		Size = UDim2.fromOffset(780, 524),
		Visible = true,
		BackgroundTransparency = 1,
	}, gui)
	local v1s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(18, 26, 65),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v1)
	corner(v1s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(18, 26, 65),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v1s)
	local v1f = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, v1)
	corner(v1f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(59, 68, 93), Color3.fromRGB(28, 38, 62)) },
		v1f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v1f
	)
	local v1l = new("Frame", {
		Name = "Lift",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v1f)
	corner(v1l, 3)
	refs["Panel"] = v1f
	table.insert(scales, { new("UIScale", {}, v1), 1, 1 })
	table.insert(layouts, {
		v1,
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.55, 0.52),
			Size = UDim2.fromOffset(780, 524),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.62, 0.56),
			Size = UDim2.fromOffset(500, 280),
			Visible = true,
		},
	})
	local v2 = new("Frame", {
		Name = "Header",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(756, 64),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	local v2s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(18, 81, 123),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v2)
	corner(v2s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(18, 81, 123),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v2s)
	local v2f = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, v2)
	corner(v2f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(57, 221, 255), Color3.fromRGB(26, 190, 224)) },
		v2f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v2f
	)
	local v2l = new("Frame", {
		Name = "Lift",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v2f)
	corner(v2l, 3)
	refs["Header"] = v2f
	table.insert(layouts, {
		v2,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(756, 64),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(484, 48),
			Visible = true,
		},
	})
	local v3 = new("Frame", {
		Name = "CarsTab",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.fromOffset(190, 48),
		Visible = true,
		BackgroundTransparency = 1,
	}, v2f)
	local v3s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(18, 81, 123),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v3)
	corner(v3s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(18, 81, 123),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v3s)
	local v3f = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Text = "",
		AutoButtonColor = false,
	}, v3)
	corner(v3f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(57, 221, 255), Color3.fromRGB(26, 190, 224)) },
		v3f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v3f
	)
	local v3l = new("Frame", {
		Name = "Lift",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v3f)
	corner(v3l, 3)
	refs["CarsTab"] = v3f
	table.insert(layouts, {
		v3,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(18, 8),
			Size = UDim2.fromOffset(190, 48),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.fromOffset(140, 48),
			Visible = true,
		},
	})
	local v4 = new("TextLabel", {
		Name = "CarsTabLabel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "CARS",
		TextSize = 25,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v3f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v4
	)
	refs["CarsTabLabel"] = v4
	table.insert(layouts, {
		v4,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextSize = 25,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextSize = 22,
			Visible = true,
		},
	})
	local v5 = new("Frame", {
		Name = "ConsumablesTab",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(228, 8),
		Size = UDim2.fromOffset(270, 48),
		Visible = true,
		BackgroundTransparency = 1,
	}, v2f)
	local v5s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(18, 26, 65),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v5)
	corner(v5s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(18, 26, 65),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v5s)
	local v5f = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Text = "",
		AutoButtonColor = false,
	}, v5)
	corner(v5f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(59, 68, 93), Color3.fromRGB(28, 38, 62)) },
		v5f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v5f
	)
	local v5l = new("Frame", {
		Name = "Lift",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v5f)
	corner(v5l, 3)
	refs["ConsumablesTab"] = v5f
	table.insert(layouts, {
		v5,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(228, 8),
			Size = UDim2.fromOffset(270, 48),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(168, 0),
			Size = UDim2.fromOffset(214, 48),
			Visible = true,
		},
	})
	local v6 = new("TextLabel", {
		Name = "ConsumablesTabLabel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "CONSUMABLES",
		TextSize = 23,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v5f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v6
	)
	refs["ConsumablesTabLabel"] = v6
	table.insert(layouts, {
		v6,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextSize = 23,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextSize = 20,
			Visible = true,
		},
	})
	local v7 = new("Frame", {
		Name = "Close",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(692, 6),
		Size = UDim2.fromOffset(52, 52),
		Visible = true,
		BackgroundTransparency = 1,
	}, v2f)
	local v7s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(88, 37, 73),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v7)
	corner(v7s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(88, 37, 73),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v7s)
	local v7f = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Text = "",
		AutoButtonColor = false,
	}, v7)
	corner(v7f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 98, 113), Color3.fromRGB(224, 68, 83)) },
		v7f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v7f
	)
	local v7l = new("Frame", {
		Name = "Lift",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v7f)
	corner(v7l, 3)
	refs["Close"] = v7f
	table.insert(layouts, {
		v7,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(692, 6),
			Size = UDim2.fromOffset(52, 52),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(428, 0),
			Size = UDim2.fromOffset(48, 48),
			Visible = true,
		},
	})
	local v8 = new("TextLabel", {
		Name = "CloseLabel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "X",
		TextSize = 26,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v7f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v8
	)
	refs["CloseLabel"] = v8
	table.insert(layouts, {
		v8,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextSize = 26,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextSize = 24,
			Visible = true,
		},
	})
	local v9 = new("TextLabel", {
		Name = "IndexProgress",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 92),
		Size = UDim2.fromOffset(748, 26),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "3 / 7 DISCOVERED",
		TextSize = 21,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v1f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v9
	)
	refs["IndexProgress"] = v9
	table.insert(layouts, {
		v9,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(16, 92),
			Size = UDim2.fromOffset(748, 26),
			TextSize = 21,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(12, 72),
			Size = UDim2.fromOffset(476, 22),
			TextSize = 18,
			Visible = true,
		},
	})
	local v10 = new("Frame", {
		Name = "GridHost",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 134),
		Size = UDim2.fromOffset(748, 374),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	refs["GridHost"] = v10
	table.insert(layouts, {
		v10,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(16, 134),
			Size = UDim2.fromOffset(748, 374),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(12, 100),
			Size = UDim2.fromOffset(476, 168),
			Visible = true,
		},
	})
	local v11 = new("Frame", {
		Name = "ConsumablesHost",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 134),
		Size = UDim2.fromOffset(748, 374),
		Visible = false,
		BackgroundTransparency = 1,
	}, v1f)
	refs["ConsumablesHost"] = v11
	table.insert(layouts, {
		v11,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(16, 134),
			Size = UDim2.fromOffset(748, 374),
			Visible = false,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(12, 100),
			Size = UDim2.fromOffset(476, 168),
			Visible = false,
		},
	})
	local function fit()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local height = camera.ViewportSize.Y
		local phone = height <= 500
		local k = if phone then math.clamp(height / 390, 0.85, 1.15) else math.clamp(height / 720, 0.6, 1.4)
		for _, scale in ipairs(scales) do
			scale[1].Scale = k * (if phone then scale[3] else scale[2])
		end
		for _, row in ipairs(layouts) do
			for key, value in pairs(if phone then row[3] else row[2]) do
				row[1][key] = value
			end
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	return refs
end

return Ui
