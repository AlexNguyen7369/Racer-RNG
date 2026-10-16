--!nonstrict
-- Progression display: all purchases and earnings are owned by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Tree = require(shared.UpgradeTree)
local Tracks = require(shared.TrackRegistry)
local Workshop = require(shared.Workshop)
local Format = require(shared.HudFormat)
local Weather = require(shared.WeatherConfig)
local Boosts = require(shared.BoostConfig)
local Switch = require(script.Parent.PanelSwitch)
local Band = require(script.Parent.PanelBand)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local BLUE = Color3.fromRGB(61, 151, 219)
local GREEN = Color3.fromRGB(89, 225, 138)
local RED = Color3.fromRGB(238, 87, 107)
local DARK = Color3.fromRGB(29, 32, 53)

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
local function panel(name, title)
	local root = screen("Racer" .. name, 2)
	local p = make("Frame", "Panel", root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 254),
		Size = UDim2.new(0.82, 0, 1, -344),
		BackgroundColor3 = DARK,
		Visible = false,
	})
	make("UICorner", "Corner", p, { CornerRadius = UDim.new(0, 14) })
	text("Title", p, UDim2.fromOffset(12, 4), UDim2.new(1, -74, 0, 34), title)
	local close = button("Close", p, UDim2.new(1, -48, 0, 6), UDim2.fromOffset(38, 30), "×")
	close.BackgroundColor3 = RED
	Switch.Register(name, p)
	-- Opens in the shared band between the HUD entries (docs/HUD_LAYOUT_SPEC.md section 6).
	Band.Fit(p, 700)
	close.Activated:Connect(function()
		Switch.Close(name)
	end)
	panels[name] = p
	return p
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
local treePanel, canvas, feedback, tiles = treeView.Panel, treeView.Canvas, treeView.Feedback, treeView.Tiles
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
			TweenService:Create(b, TweenInfo.new(0.15), { Rotation = 0 }):Play()
		end
		TweenService:Create(label, TweenInfo.new(0.15), { TextSize = 15 }):Play()
		task.delay(0.2, function()
			label.TextSize = 13
		end)
	end)
end
local workshopPanel = panel("Workshop", "WORKSHOP UPGRADE")
local workshopTitle = workshopPanel:FindFirstChild("Title")
if workshopTitle then
	workshopTitle.Font = Enum.Font.Gotham
	workshopTitle.TextSize = 14
end
local levelLabel = text("Level", workshopPanel, UDim2.new(0, 12, 0.22, 0), UDim2.new(1, -24, 0, 36), "")
local priceLabel = text("Price", workshopPanel, UDim2.new(0, 12, 0.42, 0), UDim2.new(1, -24, 0, 36), "")
local workshopRate = text("Rate", workshopPanel, UDim2.new(0, 12, 0.58, 0), UDim2.new(1, -24, 0, 26), "")
local workshopResult = text("Result", workshopPanel, UDim2.new(0, 12, 0.72, 0), UDim2.new(1, -24, 0, 24), "")
for _, label in { levelLabel, priceLabel, workshopRate, workshopResult } do
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(218, 224, 235)
end
local buyWorkshop =
	button("Buy", workshopPanel, UDim2.new(0.5, -90, 1, -48), UDim2.fromOffset(180, 36), "BUY NEXT LEVEL")
buyWorkshop.Font = Enum.Font.Gotham
buyWorkshop.TextSize = 12
local welcome = panel("Welcome", "WELCOME BACK")
local earnings = text("Earnings", welcome, UDim2.new(0, 12, 0.3, 0), UDim2.new(1, -24, 0, 40), "")
local away = text("Away", welcome, UDim2.new(0, 12, 0.55, 0), UDim2.new(1, -24, 0, 40), "")

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
	levelLabel.Text = "Level " .. level .. " • x" .. Workshop.LevelMulti(level) .. " Speed gain"
	priceLabel.Text = nextLevel
			and ("Level " .. (level + 1) .. " • x" .. nextLevel.Multi .. " • " .. Format.MoneyText(nextLevel.Price))
		or "MAX LEVEL"
	setActive(buyWorkshop, nextLevel ~= nil and balance >= nextLevel.Price)
	buyWorkshop.Selectable = buyWorkshop.Active
	buyWorkshop.BackgroundColor3 = buyWorkshop.Active and GREEN or DARK
	local inWorkshop = player:GetAttribute("InWorkshop") == true
	workshopRate.Text = string.format(
		"Current gain  +%.1f Speed/s%s",
		player:GetAttribute("WorkshopRate") or 0,
		inWorkshop and "  •  ACTIVE" or ""
	)
	workshopRate.TextColor3 = inWorkshop and GREEN or Color3.fromRGB(160, 174, 195)
end
buyWorkshop.Activated:Connect(function()
	if not buyWorkshop.Active then
		return
	end
	setActive(buyWorkshop, false)
	local ok, bought, reason = pcall(function()
		return remotes:WaitForChild("WorkshopUpgrade"):InvokeServer()
	end)
	workshopResult.Text = ok and tostring(reason or (bought and "Upgraded" or "Try again"))
		or "Connection error; try again"
	refresh()
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
	earnings.Text = string.format("+%s Speed earned while away", Format.SpeedText(credit))
	away.Text = string.format(
		"Away %dh %dm %ds • 25%% gain • 8h maximum",
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
UserInputService.InputBegan:Connect(function(input, consumed)
	if not consumed and input.KeyCode == Enum.KeyCode.Escape then
		for name in panels do
			Switch.Close(name)
		end
	end
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
	hud.Enabled = not (showcase and showcase.Enabled) and not treePanel.Visible
	refreshPotions(workspace:GetServerTimeNow())
end)
refresh()
refreshWelcome()
