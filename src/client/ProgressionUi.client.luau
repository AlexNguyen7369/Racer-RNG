--!nonstrict
-- Progression display: all purchases and earnings are owned by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
-- Speed amounts and gain rates show the saved base Speed. Equipped cars affect cruise movement only.
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Tree = require(shared.UpgradeTree)
local Tracks = require(shared.TrackRegistry)
local Workshop = require(shared.Workshop)
local Format = require(shared.HudFormat)
local Weather = require(shared.WeatherConfig)
local Boosts = require(shared.BoostConfig)
local CarCatalog = require(shared.CarCatalog)
local GachaConfig = require(shared.GachaConfig)
local Switch = require(script.Parent.PanelSwitch)
local UiMotion = require(script.Parent.UiMotion)
local PanelFrame = require(script.Parent.PanelFrame)
local HudIcons = require(script.Parent.RollToast.Ui.HudIcons)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local BLUE = Color3.fromRGB(61, 151, 219)
local GREEN = Color3.fromRGB(89, 225, 138)
local RED = Color3.fromRGB(238, 87, 107)
local DARK = Color3.fromRGB(29, 32, 53)
-- Backpack / Market vocabulary for the Workshop and Welcome panels (HUD_LAYOUT_SPEC sections 3 and 6).
local OUTLINE = Color3.fromRGB(17, 19, 31)
local BODY = Color3.fromRGB(32, 27, 36)
local TILE = Color3.fromRGB(14, 24, 52)
local TILE_BLUE = Color3.fromRGB(47, 107, 255)
local GOLD = Color3.fromRGB(255, 214, 90)
local GREY = Color3.fromRGB(44, 52, 60)
local SOFT = Color3.fromRGB(210, 220, 240)
-- Header gradients for the two panels built here (PanelFrame falls back to the Backpack blue for unknown themes).
PanelFrame.Themes.Workshop = PanelFrame.Themes.Workshop or { Color3.fromRGB(30, 150, 80), Color3.fromRGB(130, 215, 70) }
PanelFrame.Themes.Welcome = PanelFrame.Themes.Welcome or { Color3.fromRGB(235, 125, 30), Color3.fromRGB(255, 200, 60) }
-- Panel content starts under the PanelFrame header (64 px; 48 on phones) and stops BOTTOM px above the frame edge.
local TOP, BOTTOM = 72, 10

local function make(class, name, parent, properties)
	local instance = Instance.new(class)
	instance.Name = name
	for key, value in properties do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end
local function screen(name, order)
	return make("ScreenGui", name, gui, {
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = order,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
end
local function text(name, parent, position, size, value)
	return make("TextLabel", name, parent, {
		Position = position,
		Size = size,
		Text = value,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
	})
end
local function button(name, parent, position, size, value)
	local b = make("TextButton", name, parent, {
		Position = position,
		Size = size,
		Text = value,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = BLUE,
		AutoButtonColor = true,
	})
	make("UICorner", "Corner", b, { CornerRadius = UDim.new(0, 8) })
	return b
end
-- A disabled button gets no hover / press highlight.
local function setActive(b, active)
	b.Active = active
	b.AutoButtonColor = active
end
local panels = {}
-- A PanelSwitch panel with the shared PanelFrame chrome: gradient header with icon and title, square red X, rounded
-- outlined body; PanelFrame keeps it in the PanelBand band (docs/HUD_LAYOUT_SPEC.md section 6). Title and Close stay
-- direct children of Panel (UiSpec paths Panel/Close).
local function panel(name, title, icon)
	local root = screen("Racer" .. name, 2)
	local p = make("Frame", "Panel", root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(700, 420),
		BackgroundColor3 = BODY,
		Visible = false,
	})
	local titleLabel = text("Title", p, UDim2.new(), UDim2.fromOffset(200, 40), title)
	local close = button("Close", p, UDim2.new(), UDim2.fromOffset(40, 40), "X")
	Switch.Register(name, p)
	PanelFrame.Attach(p, {
		Theme = name,
		Title = title,
		Icon = icon,
		TitleObject = titleLabel,
		Close = close,
		MaxWidth = 700,
	})
	close.Activated:Connect(function()
		Switch.Close(name)
	end)
	panels[name] = p
	return p
end
-- Fredoka outlined text (Backpack / Market look), scaled down to fit its box, at most maxText px.
local function caption(name, parent, props, maxText)
	props.BackgroundTransparency = 1
	props.Font = Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextScaled = true
	props.TextWrapped = true
	props.Text = props.Text or ""
	props.ZIndex = props.ZIndex or 2
	local label = make("TextLabel", name, parent, props)
	make("UIStroke", "Outline", label, { Color = OUTLINE, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round })
	make("UITextSizeConstraint", "Max", label, { MaxTextSize = maxText or 20 })
	return label
end
-- A chunky Fredoka button with a dark border (Market Buy / Daily Claim look).
local function bigButton(name, parent, value, color, maxText)
	local b = make("TextButton", name, parent, {
		Text = value,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = OUTLINE,
		TextStrokeTransparency = 0,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		ZIndex = 2,
	})
	make("UICorner", "Corner", b, { CornerRadius = UDim.new(0, 10) })
	make("UIStroke", "Edge", b, { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	make("UITextSizeConstraint", "Max", b, { MaxTextSize = maxText or 24 })
	make("UIPadding", "Padding", b, { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
	return b
end
-- Places `object` in a column under the header. Pure UDim maths (no runtime fit), so it holds at every viewport:
-- with R = panel height - TOP - BOTTOM, its middle sits at TOP + offset + share * R and its height is
-- min(cap, base + grow * R). The numbers below keep the rows apart from R = 100 (phone band) up.
local function place(object, x, width, offset, share, base, grow, cap)
	object.AnchorPoint = Vector2.new(x.Scale == 0.5 and 0.5 or 0, 0.5)
	object.Position = UDim2.new(x, UDim.new(share, TOP + offset - share * (TOP + BOTTOM)))
	object.Size = UDim2.new(width, UDim.new(grow, base - grow * (TOP + BOTTOM)))
	make("UISizeConstraint", "Cap", object, { MaxSize = Vector2.new(math.huge, cap) })
end
local hud = screen("RacerProgression", 1)
-- Weather icon, bottom right (docs/WEATHER_EVENTS_SPEC.md, "Weather icon"): hover or tap shows the card.
local weather = button("WeatherIcon", hud, UDim2.new(1, -8, 1, -8), UDim2.fromOffset(44, 44), "")
weather.AnchorPoint = Vector2.new(1, 1)
weather.BackgroundColor3 = DARK
weather.TextSize = 24
local weatherCard = make("Frame", "Card", weather, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, 0, 0, -6),
	Size = UDim2.fromOffset(200, 74),
	BackgroundColor3 = DARK,
	Visible = false,
})
make("UICorner", "Corner", weatherCard, { CornerRadius = UDim.new(0, 8) })
local weatherTitle = text("Title", weatherCard, UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 22), "")
local weatherStats = text("Stats", weatherCard, UDim2.fromOffset(8, 26), UDim2.new(1, -16, 0, 22), "")
local weatherTime = text("Time", weatherCard, UDim2.fromOffset(8, 48), UDim2.new(1, -16, 0, 20), "")
weatherStats.TextSize = 13
weatherTime.TextSize = 13
local weatherPinned, weatherHover = false, false
local function showWeatherCard()
	weatherCard.Visible = weatherPinned or weatherHover
end
weather.Activated:Connect(function()
	-- A tap decides alone, so a second tap hides the card while the pointer still rests on the icon.
	weatherPinned = not weatherPinned
	weatherHover = false
	showWeatherCard()
end)
weather.MouseEnter:Connect(function()
	weatherHover = true
	showWeatherCard()
end)
weather.MouseLeave:Connect(function()
	weatherHover = false
	showWeatherCard()
end)

-- Active consumables share the weather status strip. The server owns the expiry attributes; this row only
-- displays the strongest active tier in each category and counts down against the server clock.
local potionStatus = make("Frame", "PotionStatus", hud, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -60, 1, -8),
	Size = UDim2.fromOffset(0, 74),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
})
local _potionLayout = make("UIListLayout", "Layout", potionStatus, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding = UDim.new(0, 10),
})

local potionButtons = {}
local PotionIcons = require(script.Parent.RollToast.Ui.PotionIcons)
-- "9m 33s" under each bottle (docs/HUD_LAYOUT_SPEC.md section 5).
local function potionTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%dh %dm", seconds // 3600, seconds // 60 % 60)
	elseif seconds >= 60 then
		return string.format("%dm %ds", seconds // 60, seconds % 60)
	end
	return string.format("%ds", seconds)
end
for _, category in Boosts.Order do
	local icon = make("ImageButton", category .. "Potion", potionStatus, {
		Size = UDim2.fromOffset(64, 74),
		BackgroundTransparency = 1,
		Image = "",
		AutoButtonColor = false,
		Visible = false,
	})
	make("ImageLabel", "Bottle", icon, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		BackgroundTransparency = 1,
		Image = PotionIcons[category] or "",
		ScaleType = Enum.ScaleType.Fit,
	})
	local timer = text("Timer", icon, UDim2.fromScale(0.5, 1), UDim2.fromOffset(84, 20), "")
	timer.AnchorPoint = Vector2.new(0.5, 1)
	timer.Font = Enum.Font.FredokaOne
	timer.TextSize = 17
	timer.TextWrapped = false
	timer.ZIndex = 2
	make("UIStroke", "Outline", timer, { Color = Color3.fromRGB(17, 19, 31), Thickness = 2 })
	local card = make("Frame", "Card", icon, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -6),
		Size = UDim2.fromOffset(190, 72),
		BackgroundColor3 = DARK,
		Visible = false,
		ZIndex = 20,
	})
	make("UICorner", "Corner", card, { CornerRadius = UDim.new(0, 8) })
	local name = text("Name", card, UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 22), "")
	name.TextSize = 14
	local effect = text("Effect", card, UDim2.fromOffset(8, 26), UDim2.new(1, -16, 0, 20), "")
	effect.TextSize = 12
	local time = text("Time", card, UDim2.fromOffset(8, 47), UDim2.new(1, -16, 0, 18), "")
	time.TextSize = 12
	local hover = false
	local function show()
		card.Visible = hover
	end
	icon.MouseEnter:Connect(function()
		hover = true
		show()
	end)
	icon.MouseLeave:Connect(function()
		hover = false
		show()
	end)
	potionButtons[category] = { Button = icon, Timer = timer, Card = card, Name = name, Effect = effect, Time = time }
end

local function strongestPotion(category, now)
	local best
	for _, item in Boosts.ItemsFor(category) do
		local untilAt = player:GetAttribute("BoostUntil_" .. item.Id)
		if type(untilAt) == "number" and untilAt > now and (not best or item.Multiplier > best.Multiplier) then
			best = { Item = item, Until = untilAt }
		end
	end
	return best
end

local function refreshPotions(now)
	local activeCount = 0
	for _, category in Boosts.Order do
		local slot = potionButtons[category]
		local activePotion = strongestPotion(category, now)
		if activePotion then
			activeCount += 1
			slot.Button.Visible = true
			slot.Button:SetAttribute("PotionId", activePotion.Item.Id)
			slot.Button:SetAttribute("PotionUntil", activePotion.Until)
			slot.Timer.Text = potionTime(activePotion.Until - now)
			slot.Name.Text = activePotion.Item.Name
			slot.Effect.Text = string.format("x%.2f %s", activePotion.Item.Multiplier, activePotion.Item.Category)
			slot.Time.Text = potionTime(activePotion.Until - now) .. " remaining"
		else
			slot.Button.Visible = false
			slot.Button:SetAttribute("PotionId", nil)
			slot.Button:SetAttribute("PotionUntil", nil)
			slot.Card.Visible = false
		end
	end
	potionStatus.Visible = activeCount > 0 and hud.Enabled
end
local treeView = require(script.Parent.RollToast.Ui.UpgradeTreeView).Create(gui, Tree, Format)
local treePanel, feedback, tiles = treeView.Panel, treeView.Feedback, treeView.Tiles
Switch.Register("Upgrades", treePanel)
panels.Upgrades = treePanel
for _, close in { treeView.Refs.Close, treeView.Refs.Exit } do
	close.Activated:Connect(function()
		Switch.Close("Upgrades")
	end)
end
local pendingBuys = {}
local purchaseSound =
	make("Sound", "PurchaseSound", hud, { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3 })
for _, tile in Tree.Tiles() do
	local entry = tiles[tile.Id]
	if not entry then
		continue
	end
	local b, label = entry.Button, entry.Label
	b.Activated:Connect(function()
		if not b.Active or pendingBuys[tile.Id] then
			return
		end
		pendingBuys[tile.Id] = true
		setActive(b, false)
		local ok, bought, reason = pcall(function()
			return remotes:WaitForChild("BuyUpgrade"):InvokeServer(tile.Id)
		end)
		feedback.Text = ok and (bought and ("Bought " .. tile.Name) or tostring(reason))
			or "Connection error; try again"
		feedback.TextColor3 = ok and bought and GREEN or RED
		pendingBuys[tile.Id] = nil
		if ok and bought then
			purchaseSound:Play()
		else
			b.Rotation = -3
			UiMotion.Create(b, TweenInfo.new(0.15), { Rotation = 0 }):Play()
		end
		UiMotion.Create(label, TweenInfo.new(0.15), { TextSize = 15 }):Play()
		task.delay(0.2, function()
			label.TextSize = 13
		end)
	end)
end
local workshopPanel = panel("Workshop", "WORKSHOP UPGRADE", HudIcons.Upgrade.Image)
-- Left part (<= 42% of the width, UiSpec.WorkshopShowcase.LeftShare): a navy card with the level, the live gain, the
-- next level's price, the BUY button and the purchase feedback.
local LEFT = UDim.new(0.42, -24)
local levelCard = make("Frame", "LevelCard", workshopPanel, {
	Position = UDim2.fromOffset(8, TOP - 4),
	Size = UDim2.new(0.42, -16, 1, -(TOP - 4) - BOTTOM + 4),
	BackgroundColor3 = TILE,
	ZIndex = 1,
})
make("UICorner", "Corner", levelCard, { CornerRadius = UDim.new(0, 12) })
local levelCardEdge = make(
	"UIStroke",
	"Edge",
	levelCard,
	{ Color = TILE_BLUE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
)
local levelLabel = caption("Level", workshopPanel, { TextColor3 = GOLD }, 36)
place(levelLabel, UDim.new(0, 12), LEFT, 5.7, 0.0327, 10, 0.06, 40)
local workshopRate = caption("Rate", workshopPanel, { TextColor3 = SOFT }, 18)
place(workshopRate, UDim.new(0, 12), LEFT, 19.2, 0.1077, 7.8, 0.0325, 24)
local priceLabel = caption("Price", workshopPanel, {}, 20)
place(priceLabel, UDim.new(0, 12), LEFT, 31.5, 0.1846, 8, 0.04, 28)
local buyWorkshop = bigButton("Buy", workshopPanel, "UPGRADE", GREEN, 24)
place(buyWorkshop, UDim.new(0, 12), LEFT, 43.2, 0.2885, 10, 0.08, 50)
local workshopResult = caption("Result", workshopPanel, {}, 28)
place(workshopResult, UDim.new(0, 12), LEFT, 52, 0.4, 8.5, 0.055, 36)
local function say(message, color)
	workshopResult.Text = message
	workshopResult.TextColor3 = color or Color3.new(1, 1, 1)
end
-- Showcase (docs/WORKSHOP_SPEC.md "Showcase"): the right part of the Workshop panel. The server validates every pick.
local showcaseFrame = make("Frame", "Showcase", workshopPanel, {
	Position = UDim2.new(0.44, 0, 0, TOP - 4),
	Size = UDim2.new(0.56, -12, 1, -(TOP - 4) - BOTTOM),
	BackgroundTransparency = 1,
})
local showcaseMulti = caption("Multi", showcaseFrame, {
	Size = UDim2.new(0.5, -4, 0, 30),
	TextXAlignment = Enum.TextXAlignment.Left,
}, 18)
-- BEST 3: a plain shortcut while cars are shown; while every slot is EMPTY it is the panel's call to action.
local best3 = bigButton("Best3", showcaseFrame, "BEST 3", BLUE, 18)
best3.Position = UDim2.new(0.5, 4, 0, 0)
best3.Size = UDim2.new(0.5, -4, 0, 30)
local best3Edge = best3:FindFirstChild("Edge")
local best3Pulse = nil
local function pulseBest3(on)
	if on and not best3Pulse then
		best3Edge.Color = GOLD
		best3Pulse = UiMotion.Create(
			best3Edge,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Thickness = 5 }
		)
		best3Pulse:Play()
	elseif not on and best3Pulse then
		best3Pulse:Cancel()
		best3Pulse = nil
		best3Edge.Color = OUTLINE
		best3Edge.Thickness = 3
	end
end
local slots = {}
for i = 1, GachaConfig.SHOWCASE_SLOTS do
	local slot = make("Frame", "Slot" .. i, showcaseFrame, {
		Position = UDim2.new((i - 1) / GachaConfig.SHOWCASE_SLOTS, 2, 0, 36),
		Size = UDim2.new(1 / GachaConfig.SHOWCASE_SLOTS, -4, 0, 36),
		BackgroundColor3 = TILE,
	})
	make("UICorner", "Corner", slot, { CornerRadius = UDim.new(0, 8) })
	local edge = make(
		"UIStroke",
		"Edge",
		slot,
		{ Color = TILE_BLUE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
	)
	local name = caption("Name", slot, {
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.new(1, -34, 0.55, -2),
		Text = "EMPTY",
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 15)
	local info = caption("Info", slot, {
		Position = UDim2.new(0, 6, 0.55, 0),
		Size = UDim2.new(1, -34, 0.45, -2),
		TextColor3 = SOFT,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 12)
	local clear = button("Clear", slot, UDim2.new(1, -26, 0.5, -11), UDim2.fromOffset(22, 22), "×")
	clear.BackgroundColor3 = RED
	slots[i] = { Name = name, Info = info, Clear = clear, Edge = edge }
end
local showcaseList = make("ScrollingFrame", "List", showcaseFrame, {
	Position = UDim2.fromOffset(0, 78),
	Size = UDim2.new(1, 0, 1, -78),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
})
make("UIListLayout", "Layout", showcaseList, { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })

local function shownIds()
	local ids = {}
	for id in string.gmatch(player:GetAttribute("Showcase") or "", "[^,]+") do
		table.insert(ids, id)
	end
	return ids
end
-- Owned rollable cars, highest slot bonus first: { Spec, Copies, Bonus }.
local function showcaseCandidates()
	local list = {}
	local data = player:FindFirstChild("GachaData")
	for _, entry in data and data:GetChildren() or {} do
		local spec = CarCatalog.Get(entry.Name)
		if spec and spec.Rollable and not spec.GamepassId then
			local copies = entry:GetAttribute("Copies") or 0
			table.insert(list, { Spec = spec, Copies = copies, Bonus = GachaConfig.SlotBonus(spec, copies) })
		end
	end
	table.sort(list, function(a, b)
		if a.Bonus ~= b.Bonus then
			return a.Bonus > b.Bonus
		end
		return a.Spec.Id < b.Spec.Id
	end)
	return list
end
local showcaseBusy = false
local function sendShowcase(ids)
	if showcaseBusy then
		return
	end
	showcaseBusy = true
	local ok, applied, reason = pcall(function()
		return remotes:WaitForChild("SetShowcase"):InvokeServer(ids)
	end)
	if ok and applied then
		say("SHOWCASE UPDATED!", GREEN)
	else
		say(ok and tostring(reason or "Try again") or "Connection error; try again", RED)
	end
	showcaseBusy = false
end
local function refreshShowcase()
	local ids = shownIds()
	local candidates = showcaseCandidates()
	local copiesOf = {}
	for _, c in candidates do
		copiesOf[c.Spec.Id] = c.Copies
	end
	showcaseMulti.Text = string.format("SHOWCASE  x%.2f Speed gain", player:GetAttribute("ShowcaseMulti") or 1)
	-- Every slot EMPTY while the player owns showable cars: BEST 3 becomes the call to action and the slots say so.
	local prompt = #ids == 0 and #candidates > 0
	best3.Text = prompt and "SHOWCASE YOUR BEST 3" or "BEST 3"
	best3.BackgroundColor3 = prompt and GREEN or BLUE
	pulseBest3(prompt)
	for i, slot in slots do
		local spec = ids[i] and CarCatalog.Get(ids[i])
		slot.Name.Text = spec and spec.Name or "EMPTY"
		slot.Info.Text = spec and string.format("x%d copies", copiesOf[spec.Id] or 0)
			or (prompt and "+Speed gain" or "")
		slot.Clear.Visible = spec ~= nil
		slot.Edge.Color = spec and GREEN or (prompt and GOLD or TILE_BLUE)
	end
	for _, row in showcaseList:GetChildren() do
		if row:IsA("Frame") then
			row:Destroy()
		end
	end
	local full = #ids >= GachaConfig.SHOWCASE_SLOTS
	for order, c in candidates do
		local row = make("Frame", "Car_" .. c.Spec.Id, showcaseList, {
			Size = UDim2.new(1, -6, 0, 26),
			BackgroundTransparency = 1,
			LayoutOrder = order,
		})
		caption("Name", row, {
			Size = UDim2.new(0.55, -4, 1, 0),
			Text = c.Spec.Name,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, 15)
		caption("Info", row, {
			Position = UDim2.fromScale(0.55, 0),
			Size = UDim2.new(0.45, -70, 1, 0),
			Text = string.format("x%d  +%.2f", c.Copies, c.Bonus),
			TextColor3 = SOFT,
		}, 13)
		local shown = table.find(ids, c.Spec.Id) ~= nil
		local show = button("Show", row, UDim2.new(1, -64, 0, 1), UDim2.fromOffset(62, 24), shown and "SHOWN" or "SHOW")
		show.Font = Enum.Font.FredokaOne
		show.TextSize = 14
		show.BackgroundColor3 = shown and GREEN or BLUE
		setActive(show, shown or not full)
		show.Activated:Connect(function()
			if not show.Active then
				return
			end
			local nextIds = shownIds()
			local at = table.find(nextIds, c.Spec.Id)
			if at then
				table.remove(nextIds, at)
			elseif #nextIds < GachaConfig.SHOWCASE_SLOTS then
				table.insert(nextIds, c.Spec.Id)
			end
			sendShowcase(nextIds)
		end)
	end
end
for i, slot in slots do
	slot.Clear.Activated:Connect(function()
		local ids = shownIds()
		if ids[i] then
			table.remove(ids, i)
			sendShowcase(ids)
		end
	end)
end
best3.Activated:Connect(function()
	local ids = {}
	for _, c in showcaseCandidates() do
		if #ids >= GachaConfig.SHOWCASE_SLOTS then
			break
		end
		table.insert(ids, c.Spec.Id)
	end
	sendShowcase(ids)
end)
local function refreshShowcaseIfOpen()
	if workshopPanel.Visible then
		refreshShowcase()
	end
end
for _, attr in { "Showcase", "ShowcaseMulti" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshShowcaseIfOpen)
end
workshopPanel:GetPropertyChangedSignal("Visible"):Connect(refreshShowcaseIfOpen)
task.spawn(function()
	local data = player:WaitForChild("GachaData")
	local function watch(entry)
		entry:GetAttributeChangedSignal("Copies"):Connect(refreshShowcaseIfOpen)
	end
	for _, entry in data:GetChildren() do
		watch(entry)
	end
	data.ChildAdded:Connect(function(entry)
		watch(entry)
		refreshShowcaseIfOpen()
	end)
	data.ChildRemoved:Connect(refreshShowcaseIfOpen)
end)

workshopPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not workshopPanel.Visible then
		pulseBest3(false)
	end
end)

-- Welcome back (offline Speed, docs/WORKSHOP_SPEC.md phase 2): sized to its content, not the whole band. PanelFrame
-- still centres it in the band; the size constraint caps it at WELCOME_SIZE. The Speed was already credited by
-- PlayerData on load, so COLLECT only closes the panel.
local WELCOME_SIZE = Vector2.new(460, 250)
local welcome = panel("Welcome", "WELCOME BACK", HudIcons.Items.Image)
make("UISizeConstraint", "ContentSize", welcome, { MaxSize = WELCOME_SIZE })
local FULL = UDim.new(1, -24)
local earnings = caption("Earnings", welcome, { TextColor3 = GOLD }, 34)
place(earnings, UDim.new(0, 12), FULL, 0, 0.2, 0, 0.3, 44)
local away = caption("Away", welcome, { TextColor3 = SOFT }, 17)
place(away, UDim.new(0, 12), FULL, 0, 0.5, 0, 0.26, 40)
local collect = bigButton("Collect", welcome, "COLLECT", GREEN, 26)
place(collect, UDim.new(0.5, 0), UDim.new(0.6, 0), 0, 0.82, 0, 0.3, 46)
collect.Activated:Connect(function()
	Switch.Close("Welcome")
end)

-- Purchase feedback: a big gold "LEVEL N!" that pops, the level number flashing and the card's border glowing.
local resultMax = workshopResult:FindFirstChild("Max")
local levelMax = levelLabel:FindFirstChild("Max")
local celebration = 0
local function celebrateLevel(level)
	celebration += 1
	local mine = celebration
	purchaseSound:Play()
	say("LEVEL " .. level .. "!", GOLD)
	resultMax.MaxTextSize = 44
	UiMotion.Create(
		resultMax,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ MaxTextSize = 28 }
	)
		:Play()
	levelMax.MaxTextSize = 52
	levelLabel.TextColor3 = Color3.new(1, 1, 1)
	UiMotion.Create(levelMax, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { MaxTextSize = 36 })
		:Play()
	UiMotion.Create(levelLabel, TweenInfo.new(0.8), { TextColor3 = GOLD }):Play()
	levelCardEdge.Color = GOLD
	levelCardEdge.Thickness = 5
	UiMotion.Create(levelCardEdge, TweenInfo.new(1.2), { Color = TILE_BLUE, Thickness = 3 }):Play()
	task.delay(4, function()
		if celebration == mine and workshopResult.Text == "LEVEL " .. level .. "!" then
			say("")
		end
	end)
end

local function refresh()
	local money = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Money")
	local balance = money and money.Value or 0
	local owned = {}
	local folder = player:FindFirstChild("Upgrades")
	if folder then
		for _, v in folder:GetChildren() do
			owned[v.Name] = true
		end
	end
	local state = {
		Owned = owned,
		Money = balance,
		BestTrack = player:GetAttribute("BestTrack") or 0,
		TrackCount = #Tracks.Chain(),
	}
	for id, refs in tiles do
		local canBuy, reason = Tree.CanBuy(state, id)
		setActive(refs.Button, canBuy and not pendingBuys[id])
		refs.Button.Selectable = canBuy
		treeView.Paint(refs, owned[id] == true, canBuy, reason, state.TrackCount)
	end
	treeView.Balance(balance)
	local level = Workshop.CleanLevel(player:GetAttribute("WorkshopLevel"))
	local nextLevel = Workshop.Config.Levels[level + 1]
	levelLabel.Text = "LEVEL " .. level
	priceLabel.Text = nextLevel
			and string.format(
				"NEXT: LEVEL %d  •  x%s gain  •  %s",
				level + 1,
				tostring(nextLevel.Multi),
				Format.MoneyText(nextLevel.Price)
			)
		or "MAX LEVEL"
	local affordable = nextLevel ~= nil and balance >= nextLevel.Price
	setActive(buyWorkshop, affordable)
	buyWorkshop.Selectable = buyWorkshop.Active
	buyWorkshop.BackgroundColor3 = buyWorkshop.Active and GREEN or GREY
	buyWorkshop.Text = not nextLevel and "MAX LEVEL"
		or (affordable and ("UPGRADE TO LEVEL " .. (level + 1)) or ("NEED " .. Format.MoneyText(nextLevel.Price)))
	local inWorkshop = player:GetAttribute("InWorkshop") == true
	local rate = player:GetAttribute("WorkshopRate") or 0
	workshopRate.Text = string.format(
		"x%s gain  •  +%s Speed/s%s",
		tostring(Workshop.LevelMulti(level)),
		rate >= 1000 and Format.SpeedText(rate) or string.format("%.1f", rate),
		inWorkshop and "  •  ACTIVE" or ""
	)
	workshopRate.TextColor3 = inWorkshop and GREEN or SOFT
end
buyWorkshop.Activated:Connect(function()
	if not buyWorkshop.Active then
		return
	end
	setActive(buyWorkshop, false)
	local ok, bought, reason = pcall(function()
		return remotes:WaitForChild("WorkshopUpgrade"):InvokeServer()
	end)
	refresh()
	if ok and bought then
		celebrateLevel(Workshop.CleanLevel(player:GetAttribute("WorkshopLevel")))
	else
		say(ok and tostring(reason or "Try again") or "Connection error; try again", RED)
		buyWorkshop.Rotation = -3
		UiMotion.Create(buyWorkshop, TweenInfo.new(0.15), { Rotation = 0 }):Play()
	end
end)
remotes:WaitForChild("WorkshopOpen").OnClientEvent:Connect(function()
	refresh()
	if not workshopPanel.Visible then
		Switch.Toggle("Workshop")
	end
end)
local lastCredit = nil
local function refreshWelcome()
	local credit = player:GetAttribute("OfflineSpeed") or 0
	local seconds = math.floor(player:GetAttribute("OfflineSeconds") or 0)
	if credit <= 0 then
		Switch.Close("Welcome")
		lastCredit = nil
	end
	earnings.Text = string.format("+%s Speed", Format.SpeedText(credit))
	away.Text = string.format(
		"Earned while you were away %dh %dm %ds  •  25%% of workshop gain, 8h max",
		math.floor(seconds / 3600),
		math.floor(seconds / 60) % 60,
		seconds % 60
	)
	local rewardKey = tostring(credit)
	if credit > 0 and rewardKey ~= lastCredit then
		lastCredit = rewardKey
		if not welcome.Visible then
			Switch.Toggle("Welcome")
		end
	end
end
for _, attr in { "BestTrack", "UpgradesBuyable", "WorkshopLevel", "InWorkshop", "WorkshopRate" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
for _, attr in { "OfflineSpeed", "OfflineSeconds" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshWelcome)
end
task.spawn(function()
	local money = player:WaitForChild("leaderstats"):WaitForChild("Money")
	money.Changed:Connect(refresh)
	local folder = player:WaitForChild("Upgrades")
	folder.ChildAdded:Connect(refresh)
	folder.ChildRemoved:Connect(refresh)
	refresh()
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.25 then
		return
	end
	elapsed = 0
	local weatherId = ReplicatedStorage:GetAttribute("WeatherEvent") or ""
	local active = Weather.Events[weatherId]
	local spec = active or Weather.Events.clear
	local remaining =
		math.max(0, math.ceil((ReplicatedStorage:GetAttribute("WeatherEndsAt") or 0) - workspace:GetServerTimeNow()))
	weather.Text = spec.Icon
	weatherTitle.Text = spec.Name
	weatherTitle.TextColor3 = spec.Color or Color3.new(1, 1, 1)
	weatherStats.Text = Weather.Describe(weatherId)
	weatherTime.Text = active and string.format("%ds left", remaining) or ""
	local showcase = gui:FindFirstChild("RollShowcase")
	hud.Enabled = not (showcase and showcase.Enabled)
	refreshPotions(workspace:GetServerTimeNow())
end)
refresh()
refreshWelcome()
