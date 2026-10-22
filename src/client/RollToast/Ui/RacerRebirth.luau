--!nonstrict
-- GENERATED from ui/specs/RacerRebirth.ui.json. DO NOT EDIT: change the spec and run ui/tooling/gen_atlas.py.
-- spec-hash: e3e844a47fa5
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

Ui.SpecHash = "e3e844a47fa5"

function Ui.Build(playerGui)
	local refs = {}
	local scales = {} -- { UIScale, desktop zoom, phone zoom }
	local layouts = {} -- { instance, desktop props, phone props }
	local gui = new("ScreenGui", {
		Name = "RacerRebirth",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	gui:SetAttribute("SpecHash", "e3e844a47fa5")
	refs.Gui = gui
	local v1 = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.55, 0, 0.52, 0),
		Size = UDim2.new(0, 600, 0, 414),
		Visible = true,
		BackgroundTransparency = 1,
	}, gui)
	local v1s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
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
		Position = UDim2.new(0, 4, 0, 2),
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
			Position = UDim2.new(0.55, 0, 0.52, 0),
			Size = UDim2.new(0, 600, 0, 414),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.62, 0, 0.56, 0),
			Size = UDim2.new(0, 500, 0, 276),
			Visible = true,
		},
	})
	local v2 = new("Frame", {
		Name = "Header",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.new(0, 576, 0, 64),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	local v2s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(82, 42, 90),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v2)
	corner(v2s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(82, 42, 90),
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
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(235, 107, 207), Color3.fromRGB(204, 77, 176)) },
		v2f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v2f
	)
	local v2l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
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
			Position = UDim2.new(0, 12, 0, 12),
			Size = UDim2.new(0, 576, 0, 64),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 8),
			Size = UDim2.new(0, 484, 0, 48),
			Visible = true,
		},
	})
	local v3 = new("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0, 470, 0, 64),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "REBIRTH",
		TextSize = 34,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v2f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v3
	)
	refs["Title"] = v3
	table.insert(layouts, {
		v3,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 12, 0, 0),
			Size = UDim2.new(0, 470, 0, 64),
			TextSize = 34,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 0),
			Size = UDim2.new(0, 382, 0, 48),
			TextSize = 25,
			Visible = true,
		},
	})
	local v4 = new("Frame", {
		Name = "Close",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 512, 0, 6),
		Size = UDim2.new(0, 52, 0, 52),
		Visible = true,
		BackgroundTransparency = 1,
	}, v2f)
	local v4s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(88, 37, 73),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v4)
	corner(v4s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(88, 37, 73),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v4s)
	local v4f = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Text = "",
		AutoButtonColor = false,
	}, v4)
	corner(v4f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 98, 113), Color3.fromRGB(224, 68, 83)) },
		v4f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v4f
	)
	local v4l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v4f)
	corner(v4l, 3)
	refs["Close"] = v4f
	table.insert(layouts, {
		v4,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 512, 0, 6),
			Size = UDim2.new(0, 52, 0, 52),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 428, 0, 0),
			Size = UDim2.new(0, 48, 0, 48),
			Visible = true,
		},
	})
	local v5 = new("TextLabel", {
		Name = "CloseLabel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "X",
		TextSize = 26,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v4f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v5
	)
	refs["CloseLabel"] = v5
	table.insert(layouts, {
		v5,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			TextSize = 26,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			TextSize = 24,
			Visible = true,
		},
	})
	local v6 = new("Frame", {
		Name = "Warning",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 84),
		Size = UDim2.new(0, 576, 0, 82),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	refs["Warning"] = v6
	table.insert(layouts, {
		v6,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 12, 0, 84),
			Size = UDim2.new(0, 576, 0, 82),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 58),
			Size = UDim2.new(0, 484, 0, 50),
			Visible = true,
		},
	})
	local v7 = new("TextLabel", {
		Name = "WarningTitle",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 576, 0, 30),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "WARNING",
		TextSize = 28,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 77, 94),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v6)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v7
	)
	refs["WarningTitle"] = v7
	table.insert(layouts, {
		v7,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 576, 0, 30),
			TextSize = 28,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 484, 0, 20),
			TextSize = 18,
			Visible = true,
		},
	})
	local v8 = new("TextLabel", {
		Name = "WarningText",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(0, 576, 0, 48),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "Rebirth resets your Money and Speed\n(Robux purchases stay)",
		TextSize = 19,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v6)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v8
	)
	refs["WarningText"] = v8
	table.insert(layouts, {
		v8,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 32),
			Size = UDim2.new(0, 576, 0, 48),
			TextSize = 19,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 20),
			Size = UDim2.new(0, 484, 0, 30),
			TextSize = 12,
			Visible = true,
		},
	})
	local v9 = new("Frame", {
		Name = "Rewards",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 170),
		Size = UDim2.new(0, 576, 0, 148),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	refs["Rewards"] = v9
	table.insert(layouts, {
		v9,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 12, 0, 170),
			Size = UDim2.new(0, 576, 0, 148),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 110),
			Size = UDim2.new(0, 484, 0, 100),
			Visible = true,
		},
	})
	local v10 = new("TextLabel", {
		Name = "RewardsTitle",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 576, 0, 30),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "REWARDS UNLOCKED",
		TextSize = 26,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 232, 30),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v9)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v10
	)
	refs["RewardsTitle"] = v10
	table.insert(layouts, {
		v10,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 576, 0, 30),
			TextSize = 26,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 484, 0, 20),
			TextSize = 16,
			Visible = true,
		},
	})
	local v11 = new("Frame", {
		Name = "LuckReward",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 34),
		Size = UDim2.new(0, 176, 0, 112),
		Visible = true,
		BackgroundTransparency = 1,
	}, v9)
	local v11s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(21, 30, 69),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v11)
	corner(v11s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(21, 30, 69),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v11s)
	local v11f = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, v11)
	corner(v11f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(67, 79, 104), Color3.fromRGB(36, 48, 73)) },
		v11f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v11f
	)
	local v11l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v11f)
	corner(v11l, 3)
	refs["LuckReward"] = v11f
	table.insert(layouts, {
		v11,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 12, 0, 34),
			Size = UDim2.new(0, 176, 0, 112),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 22),
			Size = UDim2.new(0, 150, 0, 76),
			Visible = true,
		},
	})
	local v12 = new("ImageLabel", {
		Name = "LuckRewardIcon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 62, 0, 62),
		Visible = true,
		BackgroundTransparency = 1,
		Image = "rbxassetid://121915283083474",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, v11f)
	v12.ImageRectOffset = Vector2.new(512, 0)
	v12.ImageRectSize = Vector2.new(256, 256)
	refs["LuckRewardIcon"] = v12
	table.insert(layouts, {
		v12,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.new(0, 62, 0, 62),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.new(0, 40, 0, 40),
			Visible = true,
		},
	})
	local v13 = new("TextLabel", {
		Name = "LuckRewardCaption",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 6, 0, 76),
		Size = UDim2.new(0, 164, 0, 28),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "x5.00 Luck",
		TextSize = 18,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v11f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v13
	)
	refs["LuckRewardCaption"] = v13
	table.insert(layouts, {
		v13,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 6, 0, 76),
			Size = UDim2.new(0, 164, 0, 28),
			TextSize = 18,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 4, 0, 48),
			Size = UDim2.new(0, 142, 0, 22),
			TextSize = 14,
			Visible = true,
		},
	})
	local v14 = new("Frame", {
		Name = "SpeedReward",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 200, 0, 34),
		Size = UDim2.new(0, 176, 0, 112),
		Visible = true,
		BackgroundTransparency = 1,
	}, v9)
	local v14s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(21, 30, 69),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v14)
	corner(v14s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(21, 30, 69),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v14s)
	local v14f = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, v14)
	corner(v14f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(67, 79, 104), Color3.fromRGB(36, 48, 73)) },
		v14f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v14f
	)
	local v14l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v14f)
	corner(v14l, 3)
	refs["SpeedReward"] = v14f
	table.insert(layouts, {
		v14,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 200, 0, 34),
			Size = UDim2.new(0, 176, 0, 112),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 167, 0, 22),
			Size = UDim2.new(0, 150, 0, 76),
			Visible = true,
		},
	})
	local v15 = new("ImageLabel", {
		Name = "SpeedRewardIcon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 62, 0, 62),
		Visible = true,
		BackgroundTransparency = 1,
		Image = "rbxassetid://121915283083474",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, v14f)
	v15.ImageRectOffset = Vector2.new(256, 0)
	v15.ImageRectSize = Vector2.new(256, 256)
	refs["SpeedRewardIcon"] = v15
	table.insert(layouts, {
		v15,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.new(0, 62, 0, 62),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.new(0, 40, 0, 40),
			Visible = true,
		},
	})
	local v16 = new("TextLabel", {
		Name = "SpeedRewardCaption",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 6, 0, 76),
		Size = UDim2.new(0, 164, 0, 28),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "x5.00 Speed Gain",
		TextSize = 18,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v14f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v16
	)
	refs["SpeedRewardCaption"] = v16
	table.insert(layouts, {
		v16,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 6, 0, 76),
			Size = UDim2.new(0, 164, 0, 28),
			TextSize = 18,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 4, 0, 48),
			Size = UDim2.new(0, 142, 0, 22),
			TextSize = 14,
			Visible = true,
		},
	})
	local v17 = new("Frame", {
		Name = "PointReward",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 388, 0, 34),
		Size = UDim2.new(0, 176, 0, 112),
		Visible = true,
		BackgroundTransparency = 1,
	}, v9)
	local v17s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(21, 30, 69),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v17)
	corner(v17s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(21, 30, 69),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v17s)
	local v17f = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, v17)
	corner(v17f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(67, 79, 104), Color3.fromRGB(36, 48, 73)) },
		v17f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v17f
	)
	local v17l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v17f)
	corner(v17l, 3)
	refs["PointReward"] = v17f
	table.insert(layouts, {
		v17,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 388, 0, 34),
			Size = UDim2.new(0, 176, 0, 112),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 326, 0, 22),
			Size = UDim2.new(0, 150, 0, 76),
			Visible = true,
		},
	})
	local v18 = new("ImageLabel", {
		Name = "PointRewardIcon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 62, 0, 62),
		Visible = true,
		BackgroundTransparency = 1,
		Image = "rbxassetid://121915283083474",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, v17f)
	v18.ImageRectOffset = Vector2.new(768, 512)
	v18.ImageRectSize = Vector2.new(256, 256)
	refs["PointRewardIcon"] = v18
	table.insert(layouts, {
		v18,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.new(0, 62, 0, 62),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.new(0, 40, 0, 40),
			Visible = true,
		},
	})
	local v19 = new("TextLabel", {
		Name = "PointRewardCaption",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 6, 0, 76),
		Size = UDim2.new(0, 164, 0, 28),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "+1 Stat Point",
		TextSize = 18,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v17f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v19
	)
	refs["PointRewardCaption"] = v19
	table.insert(layouts, {
		v19,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 6, 0, 76),
			Size = UDim2.new(0, 164, 0, 28),
			TextSize = 18,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 4, 0, 48),
			Size = UDim2.new(0, 142, 0, 22),
			TextSize = 14,
			Visible = true,
		},
	})
	local v20 = new("Frame", {
		Name = "Requirements",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 324),
		Size = UDim2.new(0, 376, 0, 80),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	refs["Requirements"] = v20
	table.insert(layouts, {
		v20,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 12, 0, 324),
			Size = UDim2.new(0, 376, 0, 80),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 212),
			Size = UDim2.new(0, 304, 0, 58),
			Visible = true,
		},
	})
	local v21 = new("TextLabel", {
		Name = "RequirementsTitle",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 376, 0, 28),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "REQUIREMENTS",
		TextSize = 24,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(172, 99, 238),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v20)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v21
	)
	refs["RequirementsTitle"] = v21
	table.insert(layouts, {
		v21,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 376, 0, 28),
			TextSize = 24,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 304, 0, 18),
			TextSize = 15,
			Visible = true,
		},
	})
	local v22 = new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 8, 0, 36),
		Size = UDim2.new(0, 360, 0, 40),
		Visible = true,
		BackgroundTransparency = 1,
	}, v20)
	local v22s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(21, 30, 69),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v22)
	corner(v22s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(21, 30, 69),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v22s)
	local v22f = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, v22)
	corner(v22f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(67, 79, 104), Color3.fromRGB(36, 48, 73)) },
		v22f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v22f
	)
	local v22l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v22f)
	corner(v22l, 3)
	refs["Bar"] = v22f
	table.insert(layouts, {
		v22,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 36),
			Size = UDim2.new(0, 360, 0, 40),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 22),
			Size = UDim2.new(0, 300, 0, 34),
			Visible = true,
		},
	})
	local v23 = new("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 0, 1, 0),
		Visible = true,
		BackgroundColor3 = Color3.fromRGB(61, 220, 99),
		BorderSizePixel = 0,
	}, v22f)
	refs["Fill"] = v23
	local v24 = new("TextLabel", {
		Name = "BarText",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 360, 0, 40),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "0 / 10 Level",
		TextSize = 20,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v22f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v24
	)
	refs["BarText"] = v24
	table.insert(layouts, {
		v24,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 360, 0, 40),
			TextSize = 20,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 300, 0, 34),
			TextSize = 16,
			Visible = true,
		},
	})
	local v25 = new("Frame", {
		Name = "RebirthButton",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 400, 0, 356),
		Size = UDim2.new(0, 176, 0, 48),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	local v25s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(27, 82, 74),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v25)
	corner(v25s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(27, 82, 74),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v25s)
	local v25f = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Text = "",
		AutoButtonColor = false,
	}, v25)
	corner(v25f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(84, 224, 118), Color3.fromRGB(54, 194, 87)) },
		v25f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v25f
	)
	local v25l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v25f)
	corner(v25l, 3)
	refs["RebirthButton"] = v25f
	table.insert(layouts, {
		v25,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 400, 0, 356),
			Size = UDim2.new(0, 176, 0, 48),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 320, 0, 232),
			Size = UDim2.new(0, 172, 0, 38),
			Visible = true,
		},
	})
	local v26 = new("TextLabel", {
		Name = "RebirthButtonLabel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "REBIRTH",
		TextSize = 24,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v25f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v26
	)
	refs["RebirthButtonLabel"] = v26
	table.insert(layouts, {
		v26,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			TextSize = 24,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			TextSize = 20,
			Visible = true,
		},
	})
	local function fit()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local height = camera.ViewportSize.Y
		-- Studio can briefly report a placeholder 1x1 camera while PlayerGui is already laid out.
		-- Use the live GUI height so the first fit does not clamp desktop UI to minimum scale.
		if height <= 1 and gui.AbsoluteSize.Y > 1 then
			height = gui.AbsoluteSize.Y
		end
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
	task.defer(fit)
	task.delay(0.1, fit)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	return refs
end

function Ui.Bind(playerGui)
	local saved = playerGui:WaitForChild("RacerRebirth")
	if not saved:IsA("ScreenGui") then
		saved:Destroy()
		return Ui.Build(playerGui)
	end
	if saved:GetAttribute("SpecHash") ~= Ui.SpecHash then
		saved:Destroy()
		return Ui.Build(playerGui)
	end
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
		Name = "RacerRebirth",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	gui:SetAttribute("SpecHash", "e3e844a47fa5")
	refs.Gui = gui
	local v1 = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.55, 0, 0.52, 0),
		Size = UDim2.new(0, 600, 0, 414),
		Visible = true,
		BackgroundTransparency = 1,
	}, gui)
	local v1s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
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
		Position = UDim2.new(0, 4, 0, 2),
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
			Position = UDim2.new(0.55, 0, 0.52, 0),
			Size = UDim2.new(0, 600, 0, 414),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.62, 0, 0.56, 0),
			Size = UDim2.new(0, 500, 0, 276),
			Visible = true,
		},
	})
	local v2 = new("Frame", {
		Name = "Header",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.new(0, 576, 0, 64),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	local v2s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(82, 42, 90),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v2)
	corner(v2s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(82, 42, 90),
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
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(235, 107, 207), Color3.fromRGB(204, 77, 176)) },
		v2f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v2f
	)
	local v2l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
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
			Position = UDim2.new(0, 12, 0, 12),
			Size = UDim2.new(0, 576, 0, 64),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 8),
			Size = UDim2.new(0, 484, 0, 48),
			Visible = true,
		},
	})
	local v3 = new("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0, 470, 0, 64),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "REBIRTH",
		TextSize = 34,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v2f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v3
	)
	refs["Title"] = v3
	table.insert(layouts, {
		v3,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 12, 0, 0),
			Size = UDim2.new(0, 470, 0, 64),
			TextSize = 34,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 0),
			Size = UDim2.new(0, 382, 0, 48),
			TextSize = 25,
			Visible = true,
		},
	})
	local v4 = new("Frame", {
		Name = "Close",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 512, 0, 6),
		Size = UDim2.new(0, 52, 0, 52),
		Visible = true,
		BackgroundTransparency = 1,
	}, v2f)
	local v4s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(88, 37, 73),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v4)
	corner(v4s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(88, 37, 73),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v4s)
	local v4f = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Text = "",
		AutoButtonColor = false,
	}, v4)
	corner(v4f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 98, 113), Color3.fromRGB(224, 68, 83)) },
		v4f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v4f
	)
	local v4l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v4f)
	corner(v4l, 3)
	refs["Close"] = v4f
	table.insert(layouts, {
		v4,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 512, 0, 6),
			Size = UDim2.new(0, 52, 0, 52),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 428, 0, 0),
			Size = UDim2.new(0, 48, 0, 48),
			Visible = true,
		},
	})
	local v5 = new("TextLabel", {
		Name = "CloseLabel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "X",
		TextSize = 26,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v4f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v5
	)
	refs["CloseLabel"] = v5
	table.insert(layouts, {
		v5,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			TextSize = 26,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			TextSize = 24,
			Visible = true,
		},
	})
	local v6 = new("Frame", {
		Name = "Warning",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 84),
		Size = UDim2.new(0, 576, 0, 82),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	refs["Warning"] = v6
	table.insert(layouts, {
		v6,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 12, 0, 84),
			Size = UDim2.new(0, 576, 0, 82),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 58),
			Size = UDim2.new(0, 484, 0, 50),
			Visible = true,
		},
	})
	local v7 = new("TextLabel", {
		Name = "WarningTitle",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 576, 0, 30),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "WARNING",
		TextSize = 28,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 77, 94),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v6)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v7
	)
	refs["WarningTitle"] = v7
	table.insert(layouts, {
		v7,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 576, 0, 30),
			TextSize = 28,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 484, 0, 20),
			TextSize = 18,
			Visible = true,
		},
	})
	local v8 = new("TextLabel", {
		Name = "WarningText",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(0, 576, 0, 48),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "Rebirth resets your Money and Speed\n(Robux purchases stay)",
		TextSize = 19,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v6)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v8
	)
	refs["WarningText"] = v8
	table.insert(layouts, {
		v8,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 32),
			Size = UDim2.new(0, 576, 0, 48),
			TextSize = 19,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 20),
			Size = UDim2.new(0, 484, 0, 30),
			TextSize = 12,
			Visible = true,
		},
	})
	local v9 = new("Frame", {
		Name = "Rewards",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 170),
		Size = UDim2.new(0, 576, 0, 148),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	refs["Rewards"] = v9
	table.insert(layouts, {
		v9,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 12, 0, 170),
			Size = UDim2.new(0, 576, 0, 148),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 110),
			Size = UDim2.new(0, 484, 0, 100),
			Visible = true,
		},
	})
	local v10 = new("TextLabel", {
		Name = "RewardsTitle",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 576, 0, 30),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "REWARDS UNLOCKED",
		TextSize = 26,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 232, 30),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v9)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v10
	)
	refs["RewardsTitle"] = v10
	table.insert(layouts, {
		v10,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 576, 0, 30),
			TextSize = 26,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 484, 0, 20),
			TextSize = 16,
			Visible = true,
		},
	})
	local v11 = new("Frame", {
		Name = "LuckReward",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 34),
		Size = UDim2.new(0, 176, 0, 112),
		Visible = true,
		BackgroundTransparency = 1,
	}, v9)
	local v11s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(21, 30, 69),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v11)
	corner(v11s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(21, 30, 69),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v11s)
	local v11f = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, v11)
	corner(v11f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(67, 79, 104), Color3.fromRGB(36, 48, 73)) },
		v11f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v11f
	)
	local v11l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v11f)
	corner(v11l, 3)
	refs["LuckReward"] = v11f
	table.insert(layouts, {
		v11,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 12, 0, 34),
			Size = UDim2.new(0, 176, 0, 112),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 22),
			Size = UDim2.new(0, 150, 0, 76),
			Visible = true,
		},
	})
	local v12 = new("ImageLabel", {
		Name = "LuckRewardIcon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 62, 0, 62),
		Visible = true,
		BackgroundTransparency = 1,
		Image = "rbxassetid://121915283083474",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, v11f)
	v12.ImageRectOffset = Vector2.new(512, 0)
	v12.ImageRectSize = Vector2.new(256, 256)
	refs["LuckRewardIcon"] = v12
	table.insert(layouts, {
		v12,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.new(0, 62, 0, 62),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.new(0, 40, 0, 40),
			Visible = true,
		},
	})
	local v13 = new("TextLabel", {
		Name = "LuckRewardCaption",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 6, 0, 76),
		Size = UDim2.new(0, 164, 0, 28),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "x5.00 Luck",
		TextSize = 18,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v11f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v13
	)
	refs["LuckRewardCaption"] = v13
	table.insert(layouts, {
		v13,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 6, 0, 76),
			Size = UDim2.new(0, 164, 0, 28),
			TextSize = 18,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 4, 0, 48),
			Size = UDim2.new(0, 142, 0, 22),
			TextSize = 14,
			Visible = true,
		},
	})
	local v14 = new("Frame", {
		Name = "SpeedReward",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 200, 0, 34),
		Size = UDim2.new(0, 176, 0, 112),
		Visible = true,
		BackgroundTransparency = 1,
	}, v9)
	local v14s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(21, 30, 69),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v14)
	corner(v14s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(21, 30, 69),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v14s)
	local v14f = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, v14)
	corner(v14f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(67, 79, 104), Color3.fromRGB(36, 48, 73)) },
		v14f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v14f
	)
	local v14l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v14f)
	corner(v14l, 3)
	refs["SpeedReward"] = v14f
	table.insert(layouts, {
		v14,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 200, 0, 34),
			Size = UDim2.new(0, 176, 0, 112),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 167, 0, 22),
			Size = UDim2.new(0, 150, 0, 76),
			Visible = true,
		},
	})
	local v15 = new("ImageLabel", {
		Name = "SpeedRewardIcon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 62, 0, 62),
		Visible = true,
		BackgroundTransparency = 1,
		Image = "rbxassetid://121915283083474",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, v14f)
	v15.ImageRectOffset = Vector2.new(256, 0)
	v15.ImageRectSize = Vector2.new(256, 256)
	refs["SpeedRewardIcon"] = v15
	table.insert(layouts, {
		v15,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.new(0, 62, 0, 62),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.new(0, 40, 0, 40),
			Visible = true,
		},
	})
	local v16 = new("TextLabel", {
		Name = "SpeedRewardCaption",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 6, 0, 76),
		Size = UDim2.new(0, 164, 0, 28),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "x5.00 Speed Gain",
		TextSize = 18,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v14f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v16
	)
	refs["SpeedRewardCaption"] = v16
	table.insert(layouts, {
		v16,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 6, 0, 76),
			Size = UDim2.new(0, 164, 0, 28),
			TextSize = 18,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 4, 0, 48),
			Size = UDim2.new(0, 142, 0, 22),
			TextSize = 14,
			Visible = true,
		},
	})
	local v17 = new("Frame", {
		Name = "PointReward",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 388, 0, 34),
		Size = UDim2.new(0, 176, 0, 112),
		Visible = true,
		BackgroundTransparency = 1,
	}, v9)
	local v17s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(21, 30, 69),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v17)
	corner(v17s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(21, 30, 69),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v17s)
	local v17f = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, v17)
	corner(v17f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(67, 79, 104), Color3.fromRGB(36, 48, 73)) },
		v17f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v17f
	)
	local v17l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v17f)
	corner(v17l, 3)
	refs["PointReward"] = v17f
	table.insert(layouts, {
		v17,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 388, 0, 34),
			Size = UDim2.new(0, 176, 0, 112),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 326, 0, 22),
			Size = UDim2.new(0, 150, 0, 76),
			Visible = true,
		},
	})
	local v18 = new("ImageLabel", {
		Name = "PointRewardIcon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 62, 0, 62),
		Visible = true,
		BackgroundTransparency = 1,
		Image = "rbxassetid://121915283083474",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, v17f)
	v18.ImageRectOffset = Vector2.new(768, 512)
	v18.ImageRectSize = Vector2.new(256, 256)
	refs["PointRewardIcon"] = v18
	table.insert(layouts, {
		v18,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.new(0, 62, 0, 62),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.new(0, 40, 0, 40),
			Visible = true,
		},
	})
	local v19 = new("TextLabel", {
		Name = "PointRewardCaption",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 6, 0, 76),
		Size = UDim2.new(0, 164, 0, 28),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "+1 Stat Point",
		TextSize = 18,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v17f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v19
	)
	refs["PointRewardCaption"] = v19
	table.insert(layouts, {
		v19,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 6, 0, 76),
			Size = UDim2.new(0, 164, 0, 28),
			TextSize = 18,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 4, 0, 48),
			Size = UDim2.new(0, 142, 0, 22),
			TextSize = 14,
			Visible = true,
		},
	})
	local v20 = new("Frame", {
		Name = "Requirements",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 324),
		Size = UDim2.new(0, 376, 0, 80),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	refs["Requirements"] = v20
	table.insert(layouts, {
		v20,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 12, 0, 324),
			Size = UDim2.new(0, 376, 0, 80),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 212),
			Size = UDim2.new(0, 304, 0, 58),
			Visible = true,
		},
	})
	local v21 = new("TextLabel", {
		Name = "RequirementsTitle",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 376, 0, 28),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "REQUIREMENTS",
		TextSize = 24,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(172, 99, 238),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v20)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v21
	)
	refs["RequirementsTitle"] = v21
	table.insert(layouts, {
		v21,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 376, 0, 28),
			TextSize = 24,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 304, 0, 18),
			TextSize = 15,
			Visible = true,
		},
	})
	local v22 = new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 8, 0, 36),
		Size = UDim2.new(0, 360, 0, 40),
		Visible = true,
		BackgroundTransparency = 1,
	}, v20)
	local v22s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(21, 30, 69),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v22)
	corner(v22s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(21, 30, 69),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v22s)
	local v22f = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, v22)
	corner(v22f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(67, 79, 104), Color3.fromRGB(36, 48, 73)) },
		v22f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v22f
	)
	local v22l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v22f)
	corner(v22l, 3)
	refs["Bar"] = v22f
	table.insert(layouts, {
		v22,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 8, 0, 36),
			Size = UDim2.new(0, 360, 0, 40),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 22),
			Size = UDim2.new(0, 300, 0, 34),
			Visible = true,
		},
	})
	local v23 = new("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 0, 1, 0),
		Visible = true,
		BackgroundColor3 = Color3.fromRGB(61, 220, 99),
		BorderSizePixel = 0,
	}, v22f)
	refs["Fill"] = v23
	local v24 = new("TextLabel", {
		Name = "BarText",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 360, 0, 40),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "0 / 10 Level",
		TextSize = 20,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v22f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v24
	)
	refs["BarText"] = v24
	table.insert(layouts, {
		v24,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 360, 0, 40),
			TextSize = 20,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 300, 0, 34),
			TextSize = 16,
			Visible = true,
		},
	})
	local v25 = new("Frame", {
		Name = "RebirthButton",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 400, 0, 356),
		Size = UDim2.new(0, 176, 0, 48),
		Visible = true,
		BackgroundTransparency = 1,
	}, v1f)
	local v25s = new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(27, 82, 74),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, v25)
	corner(v25s, 10)
	new("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(27, 82, 74),
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, v25s)
	local v25f = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Text = "",
		AutoButtonColor = false,
	}, v25)
	corner(v25f, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(84, 224, 118), Color3.fromRGB(54, 194, 87)) },
		v25f
	)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		v25f
	)
	local v25l = new("Frame", {
		Name = "Lift",
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, v25f)
	corner(v25l, 3)
	refs["RebirthButton"] = v25f
	table.insert(layouts, {
		v25,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 400, 0, 356),
			Size = UDim2.new(0, 176, 0, 48),
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 320, 0, 232),
			Size = UDim2.new(0, 172, 0, 38),
			Visible = true,
		},
	})
	local v26 = new("TextLabel", {
		Name = "RebirthButtonLabel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Visible = true,
		BackgroundTransparency = 1,
		Text = "REBIRTH",
		TextSize = 24,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, v25f)
	new(
		"UIStroke",
		{ Thickness = 3, Color = Color3.fromRGB(18, 22, 43), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		v26
	)
	refs["RebirthButtonLabel"] = v26
	table.insert(layouts, {
		v26,
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			TextSize = 24,
			Visible = true,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			TextSize = 20,
			Visible = true,
		},
	})
	local function fit()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local height = camera.ViewportSize.Y
		-- Studio can briefly report a placeholder 1x1 camera while PlayerGui is already laid out.
		-- Use the live GUI height so the first fit does not clamp desktop UI to minimum scale.
		if height <= 1 and gui.AbsoluteSize.Y > 1 then
			height = gui.AbsoluteSize.Y
		end
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
	task.defer(fit)
	task.delay(0.1, fit)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	return refs
end

return Ui
