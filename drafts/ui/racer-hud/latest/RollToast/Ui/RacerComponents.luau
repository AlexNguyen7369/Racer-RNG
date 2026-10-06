--!nonstrict
-- Saved, data-driven gallery and stat rows. Bake in Edit, Bind in Play.
local Components = {}
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(12, 16, 30)
local DARK = Color3.fromRGB(32, 43, 71)
local GREEN = Color3.fromRGB(60, 255, 60)
local GRAY = Color3.fromRGB(104, 111, 135)
local ATLAS = "rbxassetid://121915283083474"
local ICONS = { cash = 0, speed = 1, luck = 2, workshop = 3, rusty_hatchback = 4, wooden_car = 5,
    go_kart = 6, street_racer = 7, rocket_car = 8, hover_car = 9, void_racer = 10, rebirth = 11 }

local function make(class, props, parent)
    local instance = Instance.new(class)
    for key, value in pairs(props) do instance[key] = value end
    instance.Parent = parent
    return instance
end

local function round(parent)
    make("UICorner", { CornerRadius = UDim.new(0, 10) }, parent)
end

local function edge(parent, color)
    return make("UIStroke", { Color = color or BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

function Components.Tint(button, color)
    local gradient = button:FindFirstChildOfClass("UIGradient")
    button.BackgroundColor3 = WHITE
    if not gradient then gradient = make("UIGradient", { Rotation = 90 }, button) end
    gradient.Color = ColorSequence.new(color:Lerp(WHITE, 0.12), color:Lerp(BLACK, 0.12))
end

local function face(class, name, pos, size, color, parent)
    local props = { Name = name, Position = pos, Size = size, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3 }
    if class == "TextButton" then props.Text = ""; props.AutoButtonColor = false end
    local object = make(class, props, parent)
    round(object); edge(object)
    Components.Tint(object, color)
    local lift = make("Frame", { Name = "Lift", Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 0, 6),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 3 }, object)
    round(lift)
    return object
end

local function label(parent, name, value, pos, size, textSize, color)
    local result = make("TextLabel", { Name = name, Text = value, BackgroundTransparency = 1, Position = pos, Size = size,
        Font = Enum.Font.FredokaOne, TextSize = textSize, TextColor3 = color or WHITE, ZIndex = 5,
        TextTruncate = Enum.TextTruncate.AtEnd }, parent)
    make("UIStroke", { Color = BLACK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, result)
    return result
end

local function picture(parent, name, icon, pos, size)
    local i = ICONS[icon] or 4
    return make("ImageLabel", { Name = name, Image = ATLAS, BackgroundTransparency = 1,
        ImageRectOffset = Vector2.new(i % 4 * 256, math.floor(i / 4) * 256), ImageRectSize = Vector2.new(256, 256),
        Position = pos, Size = size, ScaleType = Enum.ScaleType.Fit, ZIndex = 4 }, parent)
end

function Components.CarArt(parent, name, icon, pos, size)
    return picture(parent, name, icon, pos, size)
end

local function scroll(host, name)
    local grid = make("ScrollingFrame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = Color3.fromRGB(30, 216, 255),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true, ZIndex = 3 }, host)
    make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) }, grid)
    return grid
end

function Components.BakeIndex(refs, catalog, config)
    local grid = scroll(refs.GridHost, "Gallery")
    make("UIGridLayout", { CellSize = UDim2.fromOffset(170, 208), CellPadding = UDim2.fromOffset(12, 12),
        SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, grid)
    for _, spec in ipairs(catalog.All()) do
        local color = config.RARITY_COLORS[spec.Rarity] or WHITE
        if spec.Rarity == "Secret" then color = Color3.fromRGB(198, 101, 255) end
        local tile = face("Frame", spec.Id, UDim2.new(), UDim2.fromOffset(170, 208), DARK, grid)
        tile.LayoutOrder = spec.Order
        tile:FindFirstChildOfClass("UIStroke").Color = color
        label(tile, "CarName", "???", UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 20), 17)
        local art = picture(tile, "Art", spec.Id, UDim2.fromOffset(8, 28), UDim2.new(1, -16, 0, 88))
        art.ImageColor3 = Color3.new(0, 0, 0)
        label(tile, "Locked", "?", UDim2.new(0.5, -15, 0, 55), UDim2.fromOffset(30, 30), 26)
        label(tile, "Info", spec.Rarity, UDim2.fromOffset(4, 122), UDim2.new(1, -8, 0, 20), 16, color)
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
        tiles[spec.Id] = { Frame = tile, Art = tile.Art, Name = tile.CarName, Info = tile.Info,
            Locked = tile.Locked, Equip = tile.Equip, Spec = spec }
    end
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
    list.ScrollBarImageColor3 = Color3.fromRGB(172, 99, 238)
    make("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }, list)
    local names = { Speed = "SPEED MULTIPLIER", Money = "MONEY MULTIPLIER", Luck = "LUCK MULTIPLIER", Workshop = "WORKSHOP MULTIPLIER" }
    local arts = { Speed = "speed", Money = "cash", Luck = "luck", Workshop = "workshop" }
    for i, stat in ipairs(config.STATS) do
        local row = face("Frame", stat, UDim2.new(), UDim2.new(1, -14, 0, 68), Color3.fromRGB(41, 55, 83), list)
        row.LayoutOrder = i
        picture(row, "Art", arts[stat], UDim2.fromOffset(4, 2), UDim2.fromOffset(64, 64))
        label(row, "StatName", names[stat], UDim2.fromOffset(76, 5), UDim2.new(1, -152, 0, 24), 21)
        label(row, "Value", stat == "Workshop" and "COMING SOON" or "x1.00", UDim2.fromOffset(76, 37), UDim2.new(1, -152, 0, 23), 19, GREEN)
        local plus = face("TextButton", "Plus", UDim2.new(1, -62, 0, 10), UDim2.fromOffset(48, 48), stat == "Workshop" and GRAY or GREEN, row)
        label(plus, "Label", "+", UDim2.new(), UDim2.fromScale(1, 1), 30)
    end
end

function Components.BakeHud(refs)
    local badge = face("Frame", "PointsBadge", UDim2.new(1, -16, 0, -10), UDim2.fromOffset(26, 26), Color3.fromRGB(255, 77, 94), refs.Stats)
    label(badge, "Label", "1", UDim2.new(), UDim2.fromScale(1, 1), 17)
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
            row.Value.TextSize = phone and 16 or 19
        end
    end
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
    fit()
    return rows
end

return Components