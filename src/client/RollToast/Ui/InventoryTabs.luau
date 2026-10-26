--!nonstrict
-- Cars retain the existing discovery/equip flow; consumable use stays server-authoritative.
local Tabs = {}
local Components = require(script.Parent.RacerComponents)
local WHITE = Color3.new(1, 1, 1)
local GREEN, DARK = Color3.fromRGB(60, 255, 60), Color3.fromRGB(32, 43, 71)
local ICON = require(script.Parent.PotionIcons)
local function make(class, name, props, parent)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function outline(object, mode, thickness)
	make(
		"UIStroke",
		"Outline",
		{ Color = Color3.fromRGB(12, 16, 30), Thickness = thickness or 2.5, ApplyStrokeMode = mode },
		object
	)
end
local function text(parent, name, value, pos, size, fontSize)
	local object = make("TextLabel", name, {
		Text = value,
		Position = pos,
		Size = size,
		Font = Enum.Font.FredokaOne,
		TextSize = fontSize,
		TextColor3 = WHITE,
		BackgroundTransparency = 1,
		TextWrapped = true,
		ZIndex = 5,
	}, parent)
	outline(object, Enum.ApplyStrokeMode.Contextual)
	return object
end
function Tabs.Attach(refs, player, refreshCars)
	local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local config = require(shared:WaitForChild("BoostConfig"))
	local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("UseBoost")
	local list = make("ScrollingFrame", "Consumables", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Color3.fromRGB(30, 216, 255),
	}, refs.ConsumablesHost)
	-- Holdables are opened from the standalone Bag HUD button; Index is car discovery only.
	refs.ConsumablesTab.Visible = false
	refs.ConsumablesHost.Visible = false
	make("UIListLayout", "Layout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	make("UIPadding", "Padding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 12),
	}, list)
	local empty = text(
		list,
		"Empty",
		"No consumables yet. Win races or visit the Market.",
		UDim2.new(),
		UDim2.new(1, 0, 0, 70),
		21
	)
	local rows = {}
	local tab = "Cars"
	local statusUntil = 0
	local summary = "CONSUMABLES"
	local function refresh()
		local total = 0
		for _, entry in rows do
			local count = player:GetAttribute("Boost_" .. entry.Item.Id) or 0
			local remaining = math.max(0, (player:GetAttribute("BoostUntil_" .. entry.Item.Id) or 0) - os.time())
			entry.Row.Visible = count > 0 or remaining > 0
			entry.Count.Text = "x" .. count
			entry.Info.Text = entry.Item.Multiplier
				.. "x "
				.. entry.Item.Category
				.. " • "
				.. entry.Item.Duration
				.. " seconds"
			entry.Use.Active = count > 0 and remaining <= 0 and not entry.Busy
			entry.Use.Selectable = entry.Use.Active
			entry.Caption.Text = remaining > 0 and ("ACTIVE " .. math.ceil(remaining) .. "s")
				or entry.Busy and "..."
				or "USE"
			Components.Tint(entry.Use, entry.Use.Active and GREEN or Color3.fromRGB(104, 111, 135))
			total += count
		end
		empty.Visible = total == 0
		summary = "CONSUMABLES • " .. total .. " OWNED"
		if tab == "Consumables" and os.clock() >= statusUntil then
			refs.IndexProgress.Text = summary
		end
	end
	local order = 0
	for _, category in config.Order do
		for _, item in config.ItemsFor(category) do
			order += 1
			local row = make("Frame", item.Id, {
				Size = UDim2.new(1, 0, 0, 92),
				BackgroundColor3 = DARK,
				BorderSizePixel = 0,
				LayoutOrder = order,
				Visible = false,
			}, list)
			make("UICorner", "Corner", { CornerRadius = UDim.new(0, 10) }, row)
			outline(row, Enum.ApplyStrokeMode.Border)
			local art = make("ImageLabel", "Icon", {
				Image = ICON[category],
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Position = UDim2.fromOffset(10, 8),
				Size = UDim2.fromOffset(64, 68),
			}, row)
			art.ZIndex = 4
			local name = text(row, "Name", item.Name, UDim2.fromOffset(84, 12), UDim2.new(1, -224, 0, 28), 21)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local info = text(row, "Info", "", UDim2.fromOffset(84, 44), UDim2.new(1, -224, 0, 36), 16)
			info.TextXAlignment = Enum.TextXAlignment.Left
			local count = text(row, "Count", "", UDim2.fromOffset(12, 67), UDim2.fromOffset(60, 22), 17)
			count.TextColor3 = Color3.fromRGB(255, 232, 30)
			local action = make("TextButton", "Use", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(116, 50),
				Text = "",
				BackgroundColor3 = GREEN,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				ZIndex = 4,
			}, row)
			make("UICorner", "Corner", { CornerRadius = UDim.new(0, 10) }, action)
			outline(action, Enum.ApplyStrokeMode.Border, 3)
			local caption = text(action, "Caption", "USE", UDim2.fromOffset(4, 4), UDim2.new(1, -8, 1, -8), 20)
			caption.TextScaled = true
			local entry =
				{ Row = row, Item = item, Count = count, Info = info, Use = action, Caption = caption, Busy = false }
			table.insert(rows, entry)
			action.Activated:Connect(function()
				if not action.Active or entry.Busy then
					return
				end
				entry.Busy = true
				refresh()
				local ok, used, message = pcall(function()
					return remote:InvokeServer(item.Id)
				end)
				entry.Busy = false
				statusUntil = os.clock() + 3
				refs.IndexProgress.Text = ok and (used and (item.Name .. " ACTIVATED") or tostring(message))
					or "Connection error"
				refresh()
			end)
			player:GetAttributeChangedSignal("Boost_" .. item.Id):Connect(refresh)
			player:GetAttributeChangedSignal("BoostUntil_" .. item.Id):Connect(refresh)
		end
	end
	local function selectTab(value)
		tab = value
		refs.Gui:SetAttribute("InventoryTab", tab)
		refs.GridHost.Visible = tab == "Cars"
		refs.ConsumablesHost.Visible = tab == "Consumables"
		Components.Tint(refs.CarsTab, tab == "Cars" and Color3.fromRGB(30, 216, 255) or DARK)
		Components.Tint(refs.ConsumablesTab, tab == "Consumables" and Color3.fromRGB(30, 216, 255) or DARK)
		if tab == "Cars" then
			refreshCars()
		else
			refresh()
		end
	end
	refs.CarsTab.Activated:Connect(function()
		selectTab("Cars")
	end)
	refs.ConsumablesTab.Activated:Connect(function()
		selectTab("Consumables")
	end)
	refs.IndexProgress:GetPropertyChangedSignal("Text"):Connect(function()
		if tab == "Consumables" and os.clock() >= statusUntil and refs.IndexProgress.Text ~= summary then
			refs.IndexProgress.Text = summary
		end
	end)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		task.defer(function()
			selectTab(tab)
		end)
	end)
	selectTab("Cars")
	task.spawn(function()
		while refs.Gui.Parent do
			task.wait(1)
			if tab == "Consumables" then
				refresh()
			end
		end
	end)
end
return Tabs
