--!nonstrict
-- Presentation only: authoritative prices, locks and purchases stay in ProgressionUi/UpgradeTree.
local View = {}
local Components = require(script.Parent.RacerComponents)
local UserInputService = game:GetService("UserInputService")
local WORLD, MIN_ZOOM, MAX_ZOOM, ZOOM_STEP = 1800, 0.15, 1.6, 0.16
-- The click box is one row step tall so neighbouring tiles never overlap; the hex art is sized from the width.
local NODE_WIDTH, NODE_HEIGHT, STEP_X, STEP_Y = 100, 106, 122, 106
local CYAN, DARK, WHITE = Color3.fromRGB(30, 216, 255), Color3.fromRGB(27, 33, 46), Color3.new(1, 1, 1)
local ICONS =
	{ money = "cash", luck = "luck", speed = "speed", rollspeed = "go_kart", turbo = "rocket_car", walkspeed = "speed" }
local function make(class, name, props, parent)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function label(parent, name, text, pos, size, textSize)
	local object = make("TextLabel", name, {
		BackgroundTransparency = 1,
		Position = pos,
		Size = size,
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextSize = textSize,
		TextColor3 = WHITE,
		TextWrapped = true,
		ZIndex = 7,
	}, parent)
	make(
		"UIStroke",
		"GlyphOutline",
		{ Color = Color3.fromRGB(12, 16, 30), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		object
	)
	return object
end
local function hex(parent, name, width, color, z, yOffset)
	local pieces = {}
	for i, rotation in { 0, 60, -60 } do
		pieces[i] = make("Frame", name .. i, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, yOffset or 0),
			Size = UDim2.fromOffset(width, width / math.sqrt(3)),
			Rotation = rotation,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
		}, parent)
	end
	return pieces
end
local function paint(pieces, color)
	for _, piece in pieces do
		piece.BackgroundColor3 = color
	end
end

function View.Create(gui, Tree, Format)
	local chromeModule = script.Parent.Parent.Parent:WaitForChild("Ui"):WaitForChild("RacerUpgrades")
	local chrome = require(chromeModule)
	-- Roblox clones StarterGui asynchronously. Wait for the authored shell rather
	-- than building a second GUI before that clone arrives.
	local refs = chrome.Bind(gui)
	local screen = refs.Gui
	screen.DisplayOrder = 8
	local panel = make("Frame", "Panel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(7, 15, 24),
		BackgroundTransparency = 0.04, -- opaque surface: HUD read-outs must not show through; below the 0.05 cap since float32 0.05 > 0.05 (UiSpec.PanelCoversReadouts)
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 0,
		Active = true,
	}, screen)
	-- The canvas starts right of ZoomTools (x 22 + 120 wide, ui/specs/RacerUpgrades.ui.json), so a panned node is
	-- clipped there instead of sliding under the + / - / EXIT buttons.
	local canvas = make("ScrollingFrame", "Canvas", {
		Position = UDim2.fromOffset(150, 0),
		Size = UDim2.new(1, -150, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ClipsDescendants = true,
		ScrollingEnabled = false,
		CanvasSize = UDim2.fromOffset(WORLD, WORLD),
		ZIndex = 1,
	}, panel)
	local world = make(
		"Frame",
		"TreeWorld",
		{ Size = UDim2.fromOffset(WORLD, WORLD), BackgroundTransparency = 1, ZIndex = 2 },
		canvas
	)
	local scale = make("UIScale", "TreeZoom", { Scale = 0.8 }, world)
	local feedback = make("TextLabel", "Result", { BackgroundTransparency = 1, Visible = false, Text = "" }, panel)
	local tiles = {}
	local view = { Panel = panel, Canvas = canvas, Tiles = tiles, Feedback = feedback, Refs = refs }
	local selected
	local function description(tile)
		for _, branch in Tree.Config.Branches do
			if branch.Id == tile.Branch then
				if branch.Bonus then
					return "+" .. math.floor(branch.Bonus[tile.Tier] * 100 + 0.5) .. "% " .. branch.Effect
				end
				if branch.WalkSpeed then
					return branch.WalkSpeed[tile.Tier] .. " WalkSpeed"
				end
				if branch.Tiers then
					local tier = branch.Tiers[tile.Tier]
					return "Turbo x" .. tier.Multi .. " / " .. tier.Every .. " rolls"
				end
			end
		end
		return ""
	end
	local function inspect(entry)
		selected = entry
		refs.DetailTitle.Text = entry.Tile.Name
		refs.DetailBonus.Text = description(entry.Tile)
		refs.DetailStatus.Text = entry.Status or "Select a tile"
	end
	local function node(id, name, q, r, icon)
		local button = make("TextButton", id, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(WORLD / 2 + STEP_X * (q + r / 2), WORLD / 2 + STEP_Y * r),
			Size = UDim2.fromOffset(NODE_WIDTH, NODE_HEIGHT),
			Text = "",
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			ZIndex = 3,
		}, world)
		hex(button, "Shadow", NODE_WIDTH + 5, Color3.fromRGB(10, 19, 38), 3, 5)
		local outline = hex(button, "HexEdge", NODE_WIDTH + 3, WHITE, 4)
		local fills = hex(button, "HexFace", NODE_WIDTH - 3, CYAN, 5)
		local art = Components.CarArt(button, "Art", icon, UDim2.new(0.5, -32, 0.5, -36), UDim2.fromOffset(64, 64))
		art.ZIndex = 6
		local title = label(button, "Text", name, UDim2.fromOffset(2, 12), UDim2.new(1, -4, 0, 46), 19)
		local price = label(button, "Price", "", UDim2.new(0, 2, 1, -36), UDim2.new(1, -4, 0, 28), 16)
		return { Button = button, Label = title, Price = price, Art = art, Fills = fills, Outline = outline }
	end
	local start = node("Start", "START", 0, 0, "speed")
	start.Price.Text = "UPGRADES"
	for _, tile in Tree.Tiles() do
		local entry = node(tile.Id, tile.Name, tile.Q, tile.R, ICONS[tile.Branch])
		entry.Tile = tile
		tiles[tile.Id] = entry
		entry.Button.MouseEnter:Connect(function()
			inspect(entry)
		end)
		entry.Button.Activated:Connect(function()
			inspect(entry)
		end)
	end
	function view.Paint(entry, owned, canBuy, reason, trackCount)
		local locked = reason == "locked"
		entry.Label.Text = locked and "?" or entry.Tile.Name
		entry.Label.TextSize = locked and 42 or 19
		-- A locked "?" fills the whole node (centred as before), so the drawn content spans the hitbox.
		entry.Label.Position = locked and UDim2.new() or UDim2.fromOffset(2, 12)
		entry.Label.Size = locked and UDim2.fromScale(1, 1) or UDim2.new(1, -4, 0, 46)
		entry.Art.Visible = not locked
		local gate = reason == "gated" and ("Reach Track " .. Tree.RequiredTrack(entry.Tile.Id, trackCount)) or nil
		entry.Price.Text = locked and "" or owned and "OWNED" or gate or Format.MoneyText(Tree.Price(entry.Tile.Id))
		entry.Price.TextColor3 = owned and Color3.fromRGB(60, 255, 60)
			or canBuy and Color3.fromRGB(60, 255, 60)
			or Color3.fromRGB(255, 105, 105)
		paint(entry.Fills, owned and CYAN or DARK)
		paint(entry.Outline, owned and WHITE or canBuy and CYAN or Color3.fromRGB(82, 90, 100))
		entry.Status = owned and "OWNED"
			or locked and "Previous upgrade required"
			or gate
			or canBuy and ("BUY • " .. Format.MoneyText(Tree.Price(entry.Tile.Id)))
			or "Not enough Money"
		if selected == entry then
			inspect(entry)
		end
	end
	function view.Balance(value)
		refs.Balance.Text = Format.MoneyText(value)
	end
	feedback:GetPropertyChangedSignal("Text"):Connect(function()
		refs.DetailStatus.Text = feedback.Text
	end)
	local function clampPan(position)
		return Vector2.new(
			math.clamp(position.X, 0, math.max(0, WORLD * scale.Scale - canvas.AbsoluteSize.X)),
			math.clamp(position.Y, 0, math.max(0, WORLD * scale.Scale - canvas.AbsoluteSize.Y))
		)
	end
	local function zoom(value, anchor)
		local old = scale.Scale
		value = math.clamp(value, MIN_ZOOM, MAX_ZOOM)
		anchor = anchor or canvas.AbsoluteSize / 2
		local worldPoint = (canvas.CanvasPosition + anchor) / old
		scale.Scale = value
		canvas.CanvasSize = UDim2.fromOffset(WORLD * value, WORLD * value)
		canvas.CanvasPosition = clampPan(worldPoint * value - anchor)
		screen:SetAttribute("TreeZoom", value)
	end
	refs.ZoomIn.Activated:Connect(function()
		zoom(scale.Scale + ZOOM_STEP)
	end)
	refs.ZoomOut.Activated:Connect(function()
		zoom(scale.Scale - ZOOM_STEP)
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not panel.Visible or input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		local origin = canvas.AbsolutePosition + game:GetService("GuiService"):GetGuiInset()
		local point = mouse - origin
		if point.X >= 0 and point.Y >= 0 and point.X <= canvas.AbsoluteSize.X and point.Y <= canvas.AbsoluteSize.Y then
			zoom(scale.Scale + input.Position.Z * ZOOM_STEP, point)
		end
	end)
	local dragStart, panStart
	canvas.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			panStart = canvas.CanvasPosition
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragStart
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			canvas.CanvasPosition = clampPan(panStart - (Vector2.new(input.Position.X, input.Position.Y) - dragStart))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragStart = nil
		end
	end)
	local blur = Instance.new("BlurEffect")
	blur.Name, blur.Size, blur.Enabled, blur.Parent = "UpgradeTreeBlur", 12, false, game:GetService("Lighting")
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		screen.Enabled = panel.Visible
		blur.Enabled = panel.Visible
		if panel.Visible then
			zoom(scale.Scale)
			canvas.CanvasPosition = clampPan(Vector2.new(WORLD / 2, WORLD / 2) * scale.Scale - canvas.AbsoluteSize / 2)
		end
	end)
	screen.Enabled = false
	zoom(0.8)
	return view
end

return View
