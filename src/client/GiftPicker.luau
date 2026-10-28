--!nonstrict
-- Recipient selection and confirmation; server validates and opens the purchase prompt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local Palette = UiTheme.Palette
local TILE_BLUE = Color3.fromRGB(47, 107, 255)
local SELECTED = Color3.fromRGB(60, 220, 90)
local Picker = {}
local function make(class, name, parent, props)
	local obj = Instance.new(class)
	obj.Name = name
	for key, value in props do
		obj[key] = value
	end
	obj.Parent = parent
	return obj
end
local function label(name, parent, props)
	props.BackgroundTransparency = 1
	props.Font = UiTheme.Font
	props.TextColor3 = Palette.White
	props.TextSize = 16
	props.TextWrapped = true
	local object = make("TextLabel", name, parent, props)
	UiTheme.Stroke(object, 1.5)
	return object
end
-- Navy tile with a coloured glow edge and outlined white text (Backpack look, docs/HUD_LAYOUT_SPEC.md section 8).
local function skin(button, glow)
	UiTheme.Corner(button, "S")
	UiTheme.Stroke(button, 1.5)
	local edge = button:FindFirstChild("Edge") or make("UIStroke", "Edge", button, {})
	edge.Color = glow
	edge.Thickness = 2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return button
end
function Picker.Create(panel, items, backdrop)
	local root = make("Frame", "GiftPicker", panel, {
		Position = UDim2.fromOffset(12, 76),
		Size = UDim2.new(1, -24, 1, -88),
		Visible = false,
		Active = true,
	})
	UiTheme.Plate(root, TILE_BLUE).BackgroundTransparency = 0
	local summary =
		label("Summary", root, { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 0, 40), Text = "" })
	local recipients = make("ScrollingFrame", "Recipients", root, {
		Position = UDim2.fromOffset(8, 44),
		Size = UDim2.new(1, -16, 1, -116),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
	})
	make("UIListLayout", "Layout", recipients, { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })
	local status = label(
		"Status",
		root,
		{ Position = UDim2.new(0, 8, 1, -70), Size = UDim2.new(1, -16, 0, 24), Text = "Choose a player" }
	)
	local cancel = make("TextButton", "Cancel", root, {
		Position = UDim2.new(0, 8, 1, -40),
		Size = UDim2.new(0.35, -12, 0, 34),
		Text = "Back",
		Font = UiTheme.Font,
		TextSize = 16,
		BackgroundColor3 = Palette.Muted,
		TextColor3 = Palette.White,
	})
	skin(cancel, Palette.Row)
	local confirm = make("TextButton", "Confirm", root, {
		Position = UDim2.new(0.35, 4, 1, -40),
		Size = UDim2.new(0.65, -12, 0, 34),
		Text = "Confirm gift",
		Font = UiTheme.Font,
		TextSize = 16,
		BackgroundColor3 = Palette.MoneyDeep,
		TextColor3 = Palette.White,
		Active = false,
		AutoButtonColor = false,
	})
	skin(confirm, Palette.Money)
	local product, selected, submitting, generation, price = nil, nil, false, 0, nil
	local function update()
		confirm.Active = selected ~= nil and not submitting
		confirm.AutoButtonColor = confirm.Active
		confirm.BackgroundTransparency = confirm.Active and 0 or 0.55
		if product then
			summary.Text = product.Name
				.. (price and (" • " .. tostring(price) .. " R$") or " • Price shown by Roblox")
		end
	end
	local function render()
		for _, child in recipients:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local candidates = Players:GetPlayers()
		table.sort(candidates, function(a, b)
			return a.Name < b.Name
		end)
		local count = 0
		for _, recipient in candidates do
			if recipient ~= Players.LocalPlayer then
				count += 1
				local button = make("TextButton", tostring(recipient.UserId), recipients, {
					Size = UDim2.new(1, -8, 0, 36),
					LayoutOrder = count,
					BackgroundColor3 = Palette.Row,
					Text = recipient.DisplayName .. " (@" .. recipient.Name .. ")",
					TextSize = 15,
					Font = UiTheme.Font,
					TextColor3 = Palette.White,
				})
				skin(button, selected == recipient and SELECTED or TILE_BLUE)
				button.Activated:Connect(function()
					if submitting then
						return
					end
					selected = recipient
					status.Text = "Send to @" .. recipient.Name .. "?"
					render()
				end)
			end
		end
		if count == 0 then
			status.Text = "No other players in this server"
		end
		update()
	end
	local function close()
		generation += 1
		root.Visible = false
		items.Visible = true
		selected, product = nil, nil
	end
	cancel.Activated:Connect(function()
		if not submitting then
			close()
		end
	end)
	confirm.Activated:Connect(function()
		if not confirm.Active or not product or not selected then
			return
		end
		submitting = true
		update()
		local token = generation
		local remote = ReplicatedStorage.Remotes:FindFirstChild("PrepareGift")
		local ok, accepted, message = pcall(function()
			return remote:InvokeServer(product.Id, selected.UserId)
		end)
		submitting = false
		if token ~= generation then
			return
		end
		status.Text = ok and tostring(message) or "Gift request failed; try again"
		if accepted then
			selected = nil
		end
		update()
	end)
	Players.PlayerAdded:Connect(function()
		if root.Visible then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function(leaving)
		if selected == leaving then
			selected = nil
			status.Text = "Recipient left; choose another player"
		end
		task.defer(function()
			if root.Visible then
				render()
			end
		end)
	end)
	UiTheme.Apply(root)
	backdrop:GetPropertyChangedSignal("Visible"):Connect(function()
		if not backdrop.Visible then
			close()
		end
	end)
	return function(item)
		generation += 1
		product, selected, price = item, nil, nil
		items.Visible = false
		root.Visible = true
		status.Text = "Choose a player"
		render()
		local token = generation
		task.spawn(function()
			local ok, info =
				pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.GiftProductId, Enum.InfoType.Product)
			if token == generation and ok and type(info) == "table" then
				price = info.PriceInRobux
				update()
			end
		end)
	end
end
return Picker
