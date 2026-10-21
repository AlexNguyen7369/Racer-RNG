--!nonstrict
-- Saved, data-driven gallery and stat rows. Bake in Edit, Bind in Play.
local Components = {}
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(12, 16, 30)
local DARK = Color3.fromRGB(32, 43, 71)
local GREEN = Color3.fromRGB(60, 255, 60)
local ATLAS = "rbxassetid://121915283083474"
local ICONS = {
	cash = 0,
	speed = 1,
	luck = 2,
	workshop = 3,
	rusty_hatchback = 4,
	wooden_car = 5,
	go_kart = 6,
	street_racer = 7,
	rocket_car = 8,
	hover_car = 9,
	void_racer = 10,
	rain_runner = 7,
	midnight_kart = 6,
	golden_racer = 8,
	rebirth = 11,
}

local function make(class, props, parent)
	local instance = Instance.new(class)
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function round(parent)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, parent)
end

local function edge(parent, color)
	return make(
		"UIStroke",
		{ Color = color or BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		parent
	)
end

function Components.Tint(button, color)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	button.BackgroundColor3 = WHITE
	if not gradient then
		gradient = make("UIGradient", { Rotation = 90 }, button)
	end
	gradient.Color = ColorSequence.new(color:Lerp(WHITE, 0.12), color:Lerp(BLACK, 0.12))
end

local function face(class, name, pos, size, color, parent)
	local props =
		{ Name = name, Position = pos, Size = size, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3 }
	if class == "TextButton" then
		props.Text = ""
		props.AutoButtonColor = false
	end
	local object = make(class, props, parent)
	round(object)
	edge(object)
	Components.Tint(object, color)
	local lift = make("Frame", {
		Name = "Lift",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, object)
	round(lift)
	return object
end

local function label(parent, name, value, pos, size, textSize, color)
	local result = make("TextLabel", {
		Name = name,
		Text = value,
		BackgroundTransparency = 1,
		Position = pos,
		Size = size,
		Font = Enum.Font.FredokaOne,
		TextSize = textSize,
		TextColor3 = color or WHITE,
		ZIndex = 5,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
	make("UIStroke", { Color = BLACK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, result)
	return result
end

local function picture(parent, name, icon, pos, size)
	local i = ICONS[icon] or 4
	return make("ImageLabel", {
		Name = name,
		Image = ATLAS,
		BackgroundTransparency = 1,
		ImageRectOffset = Vector2.new(i % 4 * 256, math.floor(i / 4) * 256),
		ImageRectSize = Vector2.new(256, 256),
		Position = pos,
		Size = size,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 4,
	}, parent)
end

function Components.CarArt(parent, name, icon, pos, size)
	return picture(parent, name, icon, pos, size)
end

-- The car's own model, front three-quarter view (docs/CAR_EXPANSION_SPEC.md "Car icons"). Idempotent; false
-- while the template has not replicated yet. Cars face -Z.
function Components.FillCarModel(view, spec, name)
	name = name or "Car"
	if view:FindFirstChild(name) then
		return true
	end
	local CarAppearance = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").CarAppearance)
	local car = CarAppearance.Display(spec, CFrame.new(), 1)
	if not car then
		return false
	end
	car.Name = name
	car.Parent = view
	local box, extents = car:GetBoundingBox()
	local camera = view.CurrentCamera or make("Camera", { Name = "Camera", FieldOfView = 30 }, view)
	view.CurrentCamera = camera
	-- Bounding-sphere fit is loose for long, low cars; 0.7 fills the tile without clipping.
	local distance = 0.7 * extents.Magnitude / 2 / math.sin(math.rad(15))
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(-0.75, 0.55, -1).Unit * distance, box.Position)
	return true
end

function Components.CarModelArt(parent, name, spec, pos, size)
	local view = make("ViewportFrame", {
		Name = name,
		BackgroundTransparency = 1,
		Position = pos,
		Size = size,
		Ambient = Color3.fromRGB(175, 175, 185),
		LightColor = WHITE,
		LightDirection = Vector3.new(-1, -2, -1),
		ZIndex = 4,
	}, parent)
	Components.FillCarModel(view, spec)
	return view
end

local function scroll(host, name)
	local grid = make("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Color3.fromRGB(30, 216, 255),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		ZIndex = 3,
	}, host)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 10),
	}, grid)
	return grid
end

function Components.BakeIndex(refs, catalog, config)
	local grid = scroll(refs.GridHost, "Gallery")
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(170, 208),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, grid)
	for _, spec in ipairs(catalog.All()) do
		local color = config.RARITY_COLORS[spec.Rarity] or WHITE
		local tile = face("Frame", spec.Id, UDim2.new(), UDim2.fromOffset(170, 208), DARK, grid)
		tile.LayoutOrder = spec.Order
		tile:FindFirstChildOfClass("UIStroke").Color = color
		label(tile, "CarName", "???", UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 20), 17)
		local art = Components.CarModelArt(tile, "Art", spec, UDim2.fromOffset(8, 28), UDim2.new(1, -16, 0, 88))
		art.ImageColor3 = Color3.new(0, 0, 0)
		label(tile, "Locked", "?", UDim2.new(0.5, -15, 0, 55), UDim2.fromOffset(30, 30), 26)
		local info = label(tile, "Info", spec.Rarity, UDim2.fromOffset(4, 122), UDim2.new(1, -8, 0, 20), 16, color)
		if spec.Rarity == "Secret" then
			info:FindFirstChildOfClass("UIStroke").Color = WHITE
		end
		local equip = face("TextButton", "Equip", UDim2.fromOffset(8, 154), UDim2.new(1, -16, 0, 44), GREEN, tile)
		label(equip, "Label", "EQUIP", UDim2.new(), UDim2.fromScale(1, 1), 17)
		equip.Visible = false
		tile:SetAttribute("CarId", spec.Id)
	end
end

function Components.BindIndex(refs, catalog)
	local grid = refs.GridHost:WaitForChild("Gallery")
	local tiles = {}
	for _, spec in ipairs(catalog.All()) do
		local tile = grid:WaitForChild(spec.Id)
		tiles[spec.Id] = {
			Frame = tile,
			Art = tile.Art,
			Name = tile.CarName,
			Info = tile.Info,
			Locked = tile.Locked,
			Equip = tile.Equip,
			Spec = spec,
		}
	end
	-- Tiles baked before a model replicated (or as old atlas images) get the model once it exists.
	local function fillModels()
		for _, tile in tiles do
			if tile.Art:IsA("ViewportFrame") then
				Components.FillCarModel(tile.Art, tile.Spec)
			end
		end
	end
	local models = game:GetService("ReplicatedStorage"):WaitForChild("CarModels")
	models.ChildAdded:Connect(fillModels)
	fillModels()
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	local function fit()
		local phone = workspace.CurrentCamera.ViewportSize.Y <= 500
		local columns = phone and 3 or 4
		-- UIScale is inherited from the generated host; its Size is in design pixels.
		local width = refs.GridHost.Size.X.Offset - 14
		layout.CellSize = UDim2.fromOffset(math.floor((width - (columns - 1) * 12) / columns), 208)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	refs.GridHost:GetPropertyChangedSignal("Size"):Connect(fit)
	fit()
	return tiles
end

function Components.BakeStats(refs, config)
	local list = scroll(refs.StatsHost, "Rows")
	list:SetAttribute("DesignVersion", 2)
	list.ScrollBarImageColor3 = Color3.fromRGB(172, 99, 238)
	local padding = list:FindFirstChildOfClass("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	make("UIListLayout", {
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, list)
	local names = {
		Speed = "SPEED MULTIPLIER",
		Money = "MONEY MULTIPLIER",
		Luck = "LUCK MULTIPLIER",
		Workshop = "WORKSHOP MULTIPLIER",
	}
	local arts = { Speed = "speed", Money = "cash", Luck = "luck", Workshop = "workshop" }
	local colours = {
		Speed = Color3.fromRGB(24, 202, 239),
		Money = Color3.fromRGB(255, 194, 18),
		Luck = Color3.fromRGB(88, 225, 80),
		Workshop = Color3.fromRGB(198, 62, 229),
	}
	for i, stat in ipairs(config.STATS) do
		local colour = colours[stat]
		local row = face("Frame", stat, UDim2.new(), UDim2.new(1, -16, 0, 82), Color3.fromRGB(235, 238, 244), list)
		row.LayoutOrder = i
		row:SetAttribute("AccentColor", colour)
		row:FindFirstChildOfClass("UIStroke").Color = colour
		row:FindFirstChildOfClass("UIGradient"):Destroy()
		row.BackgroundColor3 = Color3.fromRGB(242, 244, 247)
		picture(row, "Art", arts[stat], UDim2.fromOffset(6, 7), UDim2.fromOffset(66, 66))
		local statName = label(row, "StatName", names[stat], UDim2.fromOffset(80, 5), UDim2.new(1, -238, 0, 25), 21)
		statName.TextColor3 = Color3.fromRGB(43, 45, 54)
		statName.TextXAlignment = Enum.TextXAlignment.Left
		statName:FindFirstChildOfClass("UIStroke").Transparency = 1
		local description = label(
			row,
			"Description",
			string.format("+%d%% %s per point", math.floor(config.PER_POINT[stat] * 100 + 0.5), stat),
			UDim2.fromOffset(80, 31),
			UDim2.new(1, -238, 0, 20),
			15,
			Color3.fromRGB(111, 114, 123)
		)
		description.TextXAlignment = Enum.TextXAlignment.Left
		description:FindFirstChildOfClass("UIStroke").Transparency = 1
		local accent = make("Frame", {
			Name = "Accent",
			Position = UDim2.fromOffset(80, 58),
			Size = UDim2.new(1, -244, 0, 11),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, row)
		round(accent)
		local value = label(
			row,
			"Value",
			"0 pts  x1.00  >  x1.00",
			UDim2.new(1, -230, 0, 27),
			UDim2.fromOffset(150, 24),
			15,
			colour
		)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value:FindFirstChildOfClass("UIStroke").Color = WHITE
		local plus = face("TextButton", "Plus", UDim2.new(1, -72, 0, 10), UDim2.fromOffset(60, 60), colour, row)
		label(plus, "Label", "+", UDim2.new(), UDim2.fromScale(1, 1), 34)
	end
end

function Components.BakeHud(refs)
	round(refs.TurboFill)
	-- StarterGui contains a baked HUD from before the Level/XP meter was added.
	-- Add the meter at runtime as well, so an asset/Rojo resync is not required
	-- for the progression HUD to appear in an existing place.
	if not refs.LevelFill or not refs.LevelLabel then
		local level = face("Frame", "Level", UDim2.new(0.5, 0, 1, -60), UDim2.fromOffset(250, 32), DARK, refs.Gui)
		level.AnchorPoint = Vector2.new(0.5, 1)
		level.BackgroundTransparency = 0
		local fill = make("Frame", {
			Name = "LevelFill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Color3.fromRGB(30, 216, 255),
			BorderSizePixel = 0,
			ZIndex = 4,
		}, level)
		round(fill)
		local text = label(level, "LevelLabel", "LEVEL 1  0/100 XP", UDim2.new(), UDim2.fromScale(1, 1), 18)
		text.TextXAlignment = Enum.TextXAlignment.Center
		refs.Level = level
		refs.LevelFill = fill
		refs.LevelLabel = text
	end
	local badge = make("TextLabel", {
		Name = "PointsBadge",
		Position = UDim2.new(1, -16, 0, -10),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(255, 77, 94),
		BorderSizePixel = 0,
		Text = "1",
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 5,
	}, refs.Stats)
	round(badge)
	edge(badge)
	badge.Visible = false
end

function Components.BindStats(refs, config)
	local list = refs.StatsHost:WaitForChild("Rows")
	local rows = {}
	for _, stat in ipairs(config.STATS) do
		local row = list:WaitForChild(stat)
		rows[stat] = { Frame = row, Value = row.Value, Plus = row.Plus }
	end
	local function fit()
		local phone = workspace.CurrentCamera.ViewportSize.Y <= 500
		for _, row in pairs(rows) do
			row.Frame.StatName.TextSize = phone and 17 or 21
			row.Value.TextSize = phone and 13 or 15
			local description = row.Frame:FindFirstChild("Description")
			if description then
				description.TextSize = phone and 12 or 15
			end
		end
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	return rows
end

return Components
