--!nonstrict
-- Progression display: all purchases and earnings are owned by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Tree = require(shared.UpgradeTree)
local Tracks = require(shared.TrackRegistry)
local Workshop = require(shared.Workshop)
local Format = require(shared.HudFormat)
local Weather = require(shared.WeatherConfig)
local Switch = require(script.Parent.PanelSwitch)
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
	close.Activated:Connect(function()
		Switch.Close(name)
	end)
	panels[name] = p
	return p
end
local hud = screen("RacerProgression", 1)
local upgrades = button("UpgradeButton", hud, UDim2.new(1, -16, 0.22, 0), UDim2.fromOffset(110, 40), "UPGRADES")
upgrades.AnchorPoint = Vector2.new(1, 0)
local badge = text("Badge", upgrades, UDim2.new(1, -26, 0, 0), UDim2.fromOffset(26, 22), "0")
badge.BackgroundTransparency = 0
badge.BackgroundColor3 = RED
make("UICorner", "Corner", badge, { CornerRadius = UDim.new(1, 0) })
local rate = text("WorkshopRate", hud, UDim2.new(0.5, -150, 0.8, 0), UDim2.fromOffset(300, 24), "+0.0 Speed/s")
local weather = text("WeatherBanner", hud, UDim2.fromOffset(16, 12), UDim2.fromOffset(220, 42), "")
weather.TextXAlignment = Enum.TextXAlignment.Left
local treePanel = panel("Upgrades", "MONEY UPGRADE TREE")
local canvas = make("ScrollingFrame", "Canvas", treePanel, {
	Position = UDim2.fromOffset(8, 44),
	Size = UDim2.new(1, -16, 1, -82),
	CanvasSize = UDim2.fromOffset(1600, 1400),
	CanvasPosition = Vector2.new(500, 500),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	ClipsDescendants = true,
	ScrollingEnabled = true,
})
local feedback = text(
	"Result",
	treePanel,
	UDim2.new(0, 8, 1, -34),
	UDim2.new(1, -16, 0, 28),
	"Drag to explore • select an available upgrade"
)
local tiles = {}
local pendingBuys = {}
local purchaseSound =
	make("Sound", "PurchaseSound", hud, { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3 })
local start = text("Start", canvas, UDim2.fromOffset(750, 650), UDim2.fromOffset(100, 88), "START")
start.BackgroundTransparency = 0
start.BackgroundColor3 = BLUE
for _, tile in Tree.Tiles() do
	local position = Vector2.new(750 + 112 * (tile.Q + tile.R / 2), 650 + 108 * tile.R)
	local b = button(tile.Id, canvas, UDim2.fromOffset(position.X, position.Y), UDim2.fromOffset(100, 88), "")
	b.BackgroundTransparency = 1
	for i, rotation in { 0, -60, 60 } do
		make("Frame", "Hex" .. i, b, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(50, 86),
			Rotation = rotation,
			BackgroundColor3 = DARK,
			BorderSizePixel = 0,
			ZIndex = 2,
		})
	end
	local label = text("Text", b, UDim2.fromOffset(4, 4), UDim2.new(1, -8, 1, -8), tile.Name)
	label.ZIndex = 3
	label.TextSize = 13
	tiles[tile.Id] = { Button = b, Label = label, Tile = tile }
	b.MouseEnter:Connect(function()
		for _, branch in Tree.Config.Branches do
			if branch.Id == tile.Branch then
				local value = branch.Bonus
						and ("+" .. math.floor(branch.Bonus[tile.Tier] * 100 + 0.5) .. "% " .. branch.Effect)
					or branch.WalkSpeed and (tostring(branch.WalkSpeed[tile.Tier]) .. " WalkSpeed")
					or branch.Tiers
						and ("Turbo x" .. branch.Tiers[tile.Tier].Multi .. " every " .. branch.Tiers[tile.Tier].Every .. " rolls")
				feedback.Text = tile.Name .. ": " .. tostring(value)
				feedback.TextColor3 = Color3.new(1, 1, 1)
			end
		end
	end)
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
local levelLabel = text("Level", workshopPanel, UDim2.new(0, 12, 0.22, 0), UDim2.new(1, -24, 0, 36), "")
local priceLabel = text("Price", workshopPanel, UDim2.new(0, 12, 0.42, 0), UDim2.new(1, -24, 0, 36), "")
local workshopResult = text("Result", workshopPanel, UDim2.new(0, 12, 0.62, 0), UDim2.new(1, -24, 0, 28), "")
local buyWorkshop =
	button("Buy", workshopPanel, UDim2.new(0.5, -90, 1, -48), UDim2.fromOffset(180, 36), "BUY NEXT LEVEL")
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
		local description = reason == "owned" and "OWNED"
			or reason == "locked" and "?"
			or reason == "gated" and ("Reach Track " .. Tree.RequiredTrack(id, state.TrackCount))
			or Format.MoneyText(Tree.Price(id))
		refs.Label.Text = reason == "locked" and "?" or (refs.Tile.Name .. "\n" .. description)
		refs.Label.TextColor3 = reason == "owned" and BLUE or canBuy and GREEN or RED
		for _, child in refs.Button:GetChildren() do
			if child:IsA("Frame") then
				child.BackgroundColor3 = owned[id] and Color3.fromRGB(28, 70, 109) or Color3.fromRGB(49, 55, 78)
			end
		end
	end
	local count = player:GetAttribute("UpgradesBuyable") or 0
	badge.Text, badge.Visible = tostring(count), count > 0
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
	rate.Text = string.format(
		"%s +%.1f Speed/s",
		inWorkshop and "IN WORKSHOP" or "WORKSHOP",
		player:GetAttribute("WorkshopRate") or 0
	)
	rate.TextColor3 = inWorkshop and GREEN or Color3.fromRGB(160, 174, 195)
end
upgrades.Activated:Connect(function()
	Switch.Toggle("Upgrades")
end)
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
	local moneyCredit = player:GetAttribute("OfflineMoney") or 0
	local seconds = math.floor(player:GetAttribute("OfflineSeconds") or 0)
	if credit <= 0 and moneyCredit <= 0 then
		Switch.Close("Welcome")
		lastCredit = nil
	end
	earnings.Text = string.format(
		"+%s Speed  •  +%s Money earned while away",
		Format.SpeedText(credit),
		Format.MoneyText(moneyCredit)
	)
	away.Text = string.format(
		"Away %dh %dm %ds • 25%% gain • 8h maximum",
		math.floor(seconds / 3600),
		math.floor(seconds / 60) % 60,
		seconds % 60
	)
	local rewardKey = tostring(credit) .. ":" .. tostring(moneyCredit)
	if (credit > 0 or moneyCredit > 0) and rewardKey ~= lastCredit then
		lastCredit = rewardKey
		if not welcome.Visible then
			Switch.Toggle("Welcome")
		end
	end
end
for _, attr in { "BestTrack", "UpgradesBuyable", "WorkshopLevel", "InWorkshop", "WorkshopRate" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
for _, attr in { "OfflineSpeed", "OfflineMoney", "OfflineSeconds" } do
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
local onWorldPad = false
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.25 then
		return
	end
	elapsed = 0
	local spec = Weather.Events[ReplicatedStorage:GetAttribute("WeatherEvent") or ""]
	local remaining =
		math.max(0, math.ceil((ReplicatedStorage:GetAttribute("WeatherEndsAt") or 0) - workspace:GetServerTimeNow()))
	weather.Text = spec
			and string.format("%s • %ds\nLuck x%s • Money x%s", spec.Name, remaining, spec.Luck, spec.Money)
		or ""
	weather.TextColor3 = spec and spec.Color or BLUE
	weather.Visible = spec ~= nil
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local inside = false
	for _, pad in CollectionService:GetTagged("UpgradePad") do
		if
			root
			and pad:IsA("BasePart")
			and pad:IsDescendantOf(workspace)
			and not pad:FindFirstAncestor("Workshops")
		then
			local p = pad.CFrame:PointToObjectSpace(root.Position)
			inside = math.abs(p.X) <= pad.Size.X / 2 and math.abs(p.Z) <= pad.Size.Z / 2 and math.abs(p.Y) <= 8
			if inside then
				break
			end
		end
	end
	if inside and not onWorldPad and not treePanel.Visible then
		Switch.Toggle("Upgrades")
	end
	if not inside and onWorldPad then
		Switch.Close("Upgrades")
	end
	onWorldPad = inside
	local showcase = gui:FindFirstChild("RollShowcase")
	hud.Enabled = not (showcase and showcase.Enabled)
	-- An open panel owns the screen: the UPGRADES entry would sit over another panel's header and the
	-- workshop line over the panel body.
	local otherOpen = Switch.AnyOpen() and not treePanel.Visible
	upgrades.Visible = not otherOpen
	rate.Visible = not Switch.AnyOpen()
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.X > 1 then
		local viewport = camera.ViewportSize
		-- These ScreenGuis ignore the top-bar inset, so an AbsolutePosition + inset is an offset in them.
		local inset = GuiService:GetGuiInset().Y
		local racerHud = gui:FindFirstChild("RacerHud")
		local turbo = racerHud and racerHud:FindFirstChild("Turbo")
		local toastGui = gui:FindFirstChild("RollToast")
		local toast = toastGui and toastGui:FindFirstChild("Toast")
		local toastBottom = toast and toast.AbsolutePosition.Y + inset + toast.AbsoluteSize.Y or 246
		local bottom = turbo and turbo.AbsolutePosition.Y + inset - 8 or viewport.Y - 90
		-- Tall viewports put the right-hand upgrade entry beside the panels. Keep its column free, and keep clear of
		-- the INDEX / STATS / REBIRTH column (badge included) on the left, mirrored on the right.
		local navigation = racerHud and racerHud:FindFirstChild("Navigation")
		local columnRight = 0
		if navigation then
			columnRight = navigation.AbsolutePosition.X + navigation.AbsoluteSize.X
			for _, child in navigation:GetDescendants() do
				if child:IsA("GuiObject") and child.Visible then
					columnRight = math.max(columnRight, child.AbsolutePosition.X + child.AbsoluteSize.X)
				end
			end
		end
		local width = viewport.Y > 700 and math.min(700, viewport.X - 284) or math.min(700, viewport.X * 0.82)
		width = math.max(100, math.min(width, viewport.X - 2 * (columnRight + 8)))
		for _, p in panels do
			if viewport.Y <= 500 then
				-- Short landscape screens use the space to the right of the compact roll.
				local right = toast and toast.AbsolutePosition.X + toast.AbsoluteSize.X + 12 or viewport.X / 2 + 127
				local sideWidth = math.max(100, math.min(300, viewport.X - right - 16))
				local top = upgrades.AbsolutePosition.Y + inset + upgrades.AbsoluteSize.Y + 8
				p.AnchorPoint = Vector2.new(1, 0)
				p.Position = UDim2.new(1, -16, 0, top)
				p.Size = UDim2.fromOffset(sideWidth, math.max(112, bottom - top))
			else
				p.AnchorPoint = Vector2.new(0.5, 0)
				p.Position = UDim2.new(0.5, 0, 0, toastBottom + 8)
				p.Size = UDim2.fromOffset(width, math.max(112, bottom - toastBottom - 8))
			end
		end
		rate.Size = UDim2.fromOffset(math.min(300, viewport.X - 24), 24)
		rate.TextSize = 16
		rate.TextXAlignment = Enum.TextXAlignment.Center
		local speed = racerHud and racerHud:FindFirstChild("Speed")
		local rateTop = speed and speed.AbsolutePosition.Y + inset - 28 or viewport.Y * 0.7 - 28
		rate.Position = UDim2.new(0.5, -rate.Size.X.Offset / 2, 0, rateTop)
		-- Short screens: above Speed would be inside the compact roll, so sit right of the Speed group instead.
		if speed and toast and rateTop < toast.AbsolutePosition.Y + inset + toast.AbsoluteSize.Y + 4 then
			local left = speed.AbsolutePosition.X + speed.AbsoluteSize.X + 8
			local sideWidth = math.max(60, viewport.X - left - 12)
			rate.Size = UDim2.fromOffset(sideWidth, 24)
			rate.TextSize = 12
			rate.TextXAlignment = Enum.TextXAlignment.Left
			local centreY = speed.AbsolutePosition.Y + inset + speed.AbsoluteSize.Y / 2
			rate.Position = UDim2.fromOffset(left, centreY - 12)
		end
		weather.Size = UDim2.fromOffset(math.min(220, viewport.X * 0.28), 42)
		weather.TextSize = viewport.X < 600 and 12 or 16
	end
end)
refresh()
refreshWelcome()
