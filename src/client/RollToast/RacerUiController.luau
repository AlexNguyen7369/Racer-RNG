--!nonstrict
-- Bind saved UI; all economy, ownership and allocation decisions stay on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local catalog = require(Shared.CarCatalog)
local config = require(Shared.GachaConfig)
local format = require(Shared.HudFormat)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- There is only one supported HUD. Remove baked copies from older Studio
-- places before binding the current generated UI, including copies cloned on
-- a later respawn from an old StarterGui.
local legacyNames = { "AutoRaceButton", "SpeedHud", "StatsUi", "RollUi", "IndexUi", "RacerHudConcept" }
local function removeLegacy(child)
	if table.find(legacyNames, child.Name) then
		child:Destroy()
	end
end
for _, name in legacyNames do
	local legacy = playerGui:FindFirstChild(name)
	if legacy then
		legacy:Destroy()
	end
end
playerGui.ChildAdded:Connect(removeLegacy)
local Ui = script.Parent:WaitForChild("Ui")
local Components = require(Ui.RacerComponents)
local HudButtonStyle = require(Ui.HudButtonStyle)
require(Ui.RacerMotion).Attach(playerGui)
local client = script.Parent:IsA("LocalScript") and script.Parent.Parent or script.Parent
local PanelSwitch = require(client.PanelSwitch)
local UiMotion = require(client.UiMotion)
local PanelBand = require(client.PanelBand)
local hud = require(Ui.RacerHud).Bind(playerGui)
require(client.RaceProgressMap).Attach(hud)
-- The saved HUD asset predates the session-local free-points badge. Bake the
-- small badge at runtime so the live HUD and UiSpec share the same contract.
Components.BakeHud(hud)
-- The discovery panel is intentionally cars-only; holdables live in the separate Bag control.
if hud.IndexLabel then
	hud.IndexLabel.Text = "INDEX"
end
-- Uploaded HUD art shares an atlas; keep the individual icon crops when binding.
hud.MoneyIcon.ImageRectOffset = Vector2.new(0, 0)
hud.MoneyIcon.ImageRectSize = Vector2.new(256, 256)
hud.SpeedIcon.ImageRectOffset = Vector2.new(256, 0)
hud.SpeedIcon.ImageRectSize = Vector2.new(256, 256)
hud.MoneyValue.TextXAlignment = Enum.TextXAlignment.Left
hud.Unbanked.TextXAlignment = Enum.TextXAlignment.Left
hud.SpeedValue.TextXAlignment = Enum.TextXAlignment.Left
-- Read-out look (docs/HUD_LAYOUT_SPEC.md section 9): Money plate, gradient numbers, the speedometer.
local UiTheme = require(Shared.UiTheme)
local palette = UiTheme.Palette
UiTheme.Plate(hud.MoneyPlate, palette.MoneyDeep)
UiTheme.Gradient(hud.MoneyValue, Color3.fromRGB(190, 255, 170), palette.MoneyDeep)
UiTheme.Gradient(hud.Unbanked, Color3.fromRGB(255, 240, 150), palette.UnbankedDeep)
UiTheme.Gradient(hud.SpeedValue, Color3.fromRGB(255, 250, 170), palette.SpeedDeep)
hud.MoneyValue.TextColor3 = Color3.new(1, 1, 1)
hud.Unbanked.TextColor3 = Color3.new(1, 1, 1)
hud.SpeedValue.TextColor3 = Color3.new(1, 1, 1)
local speedDial = require(Ui.SpeedDial).Attach(hud.SpeedDial)
local index = require(Ui.RacerIndex).Bind(playerGui)
local stats = require(Ui.RacerStats).Bind(playerGui)
local settings = require(Ui.RacerSettings).Bind(playerGui)
local rebirth = require(Ui.RacerRebirth).Bind(playerGui)
local rebirthConfig = require(Shared.RebirthConfig)
-- FredokaOne and token radii on the code-built parts inside the generated screens too (HUD_LAYOUT_SPEC section 8).
for _, refs in { hud, index, stats, settings, rebirth } do
	UiTheme.Apply(refs.Gui)
end
-- Catalog additions extend the saved gallery without waiting forever for an old seven-car bake.
local gallery = index.GridHost:FindFirstChild("Gallery")
for _, spec in catalog.All() do
	local baked = gallery and gallery:FindFirstChild(spec.Id)
	if not (baked and baked:FindFirstChild("Art") and baked.Art:IsA("ViewportFrame")) then
		if gallery then
			gallery:Destroy()
		end
		Components.BakeIndex(index, catalog, config)
		break
	end
end
local statsRows = stats.StatsHost:FindFirstChild("Rows")
local rebuildStats = statsRows == nil or statsRows:GetAttribute("DesignVersion") ~= 2
if statsRows then
	for _, stat in config.STATS do
		if not statsRows:FindFirstChild(stat) then
			rebuildStats = true
			break
		end
	end
end
if rebuildStats then
	if statsRows then
		statsRows:Destroy()
	end
	Components.BakeStats(stats, config)
end
local tiles = Components.BindIndex(index, catalog)
local rows = Components.BindStats(stats, config)
local data = player:WaitForChild("GachaData")
local leaderstats = player:WaitForChild("leaderstats")
local speed = leaderstats:WaitForChild("Speed") -- base Speed, set by the server; car multis affect cruise only
local money = leaderstats:WaitForChild("Money")
local GREEN = Color3.fromRGB(60, 255, 60)
local RED = Color3.fromRGB(255, 77, 94)
local GRAY = Color3.fromRGB(104, 111, 135)
local sessionStartedAt = os.time()

local function formatDuration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local hours = seconds // 3600
	local minutes = (seconds // 60) % 60
	local remainder = seconds % 60
	return hours > 0 and string.format("%dh %02dm", hours, minutes) or string.format("%dm %02ds", minutes, remainder)
end

local function bestRolledCar()
	local best
	for _, spec in catalog.All() do
		if data and data:FindFirstChild(spec.Id) and (not best or (spec.Chance or 0) > (best.Chance or 0)) then
			best = spec
		end
	end
	return best
end

-- Roll entry is the compact animation at the top centre of the screen. The old
-- bottom roll controls and Settings auto-roll row are intentionally hidden.
-- Generated responsive fits reapply authored visibility on viewport changes.
-- Keep the retired entry points hidden throughout those fits. INDEX / STATS / REBIRTH and the Settings gear
-- moved to the HudChrome icon grid and top-right pills (docs/HUD_LAYOUT_SPEC.md).
for _, retired in { hud.RollControls, hud.Gui:FindFirstChild("Navigation"), hud.Gui:FindFirstChild("Settings") } do
	retired.Visible = false
	retired:GetPropertyChangedSignal("Visible"):Connect(function()
		if retired.Visible then
			retired.Visible = false
		end
	end)
end
settings.AutoRow.Visible = true

hud.Gui.DisplayOrder = 1
local racerPanels = { Index = index, Stats = stats, Settings = settings, Rebirth = rebirth }
for name, refs in pairs(racerPanels) do
	refs.Gui.DisplayOrder = 2
	refs.Panel.Parent.Visible = false
	refs.Gui.Enabled = true
	PanelSwitch.Register(name, refs.Panel.Parent)
	refs.Close.Activated:Connect(function()
		PanelSwitch.Close(name)
	end)
end

local function label(button, value)
	HudButtonStyle.SetCaption(button, value)
end

-- Settings look (docs/HUD_LAYOUT_SPEC.md section 4): grey header with the gear, and every toggle an ON / OFF
-- pill on a dark track (green ON on the right, red OFF on the left). The whole track stays the hitbox.
local OFF_RED = Color3.fromRGB(232, 69, 60)
local function switch(toggle, on)
	local knob = toggle:FindFirstChild("Knob")
	if not knob then
		knob = Instance.new("Frame")
		knob.Name = "Knob"
		knob.Size = UDim2.fromScale(0.6, 1)
		knob.BorderSizePixel = 0
		knob.ZIndex = 3
		Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 10)
		local edge = Instance.new("UIStroke")
		edge.Thickness, edge.Color = 3, Color3.fromRGB(18, 22, 43)
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = knob
		knob.Parent = toggle
		local caption = toggle:FindFirstChild(toggle.Parent.Name .. "Label")
		if caption then
			caption.Parent = knob
			caption.ZIndex = 4
		end
		local lift = toggle:FindFirstChild("Lift")
		if lift then
			lift.Visible = false
		end
		Components.Tint(toggle, Color3.fromRGB(16, 16, 20))
	end
	knob.Position = on and UDim2.fromScale(0.4, 0) or UDim2.fromScale(0, 0)
	Components.Tint(knob, on and GREEN or OFF_RED)
	local caption = knob:FindFirstChildWhichIsA("TextLabel")
	if caption then
		caption.Text = on and "ON" or "OFF"
	end
	toggle:SetAttribute("On", on)
end
Components.Tint(settings.Header, Color3.fromRGB(176, 178, 186))
settings.Title.Text = "Settings"
settings.Title.TextXAlignment = Enum.TextXAlignment.Left
local function fitSettingsTitle()
	-- Reserve the right side of the generated header for both category tabs and
	-- the close button at desktop and phone sizes.
	settings.Title.Size = UDim2.new(1, -286, 1, 0)
end
fitSettingsTitle()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		task.defer(fitSettingsTitle)
	end)
end
local titlePad = Instance.new("UIPadding")
titlePad.PaddingLeft = UDim.new(0, 58)
titlePad.Parent = settings.Title
local gear = Instance.new("ImageLabel")
gear.Name = "Gear"
gear.AnchorPoint = Vector2.new(0, 0.5)
gear.Position = UDim2.new(0, -54, 0.5, 0)
gear.Size = UDim2.fromOffset(46, 46)
gear.BackgroundTransparency = 1
gear.Image = require(Ui.HudIcons).Settings.Image
gear.ScaleType = Enum.ScaleType.Fit
gear.Parent = settings.Title

-- Settings owns the read-only Player Profile category from the reference. The
-- separate Stats panel remains exclusively for spending rebirth/index points.
local categoryTabs = Instance.new("Frame")
categoryTabs.Name = "CategoryTabs"
categoryTabs.AnchorPoint = Vector2.new(1, 0)
categoryTabs.Position = UDim2.new(1, -64, 0, 8)
categoryTabs.Size = UDim2.fromOffset(210, 48)
categoryTabs.BackgroundTransparency = 1
categoryTabs.ZIndex = 6
categoryTabs.Parent = settings.Header
local categoryLayout = Instance.new("UIListLayout")
categoryLayout.FillDirection = Enum.FillDirection.Horizontal
categoryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
categoryLayout.VerticalAlignment = Enum.VerticalAlignment.Center
categoryLayout.Padding = UDim.new(0, 6)
categoryLayout.Parent = categoryTabs

local function categoryButton(name, text, width)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(width, 38)
	button.BackgroundColor3 = Color3.fromRGB(34, 39, 57)
	button.AutoButtonColor = false
	button.Font = Enum.Font.FredokaOne
	button.Text = text
	button.TextSize = text == "PLAYER PROFILE" and 12 or 14
	button.TextColor3 = Color3.new(1, 1, 1)
	button.ZIndex = 7
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
	local edge = Instance.new("UIStroke")
	edge.Name = "Outline"
	edge.Color = Color3.fromRGB(18, 22, 43)
	edge.Thickness = 2
	edge.Parent = button
	button.Parent = categoryTabs
	return button
end

local settingsTab = categoryButton("SettingsTab", "SETTINGS", 84)
local profileTab = categoryButton("ProfileTab", "PLAYER PROFILE", 120)
local profileHost = Instance.new("ScrollingFrame")
profileHost.Name = "PlayerProfile"
profileHost.Position = UDim2.fromOffset(16, 96)
profileHost.Size = UDim2.new(1, -32, 1, -112)
profileHost.BackgroundTransparency = 1
profileHost.BorderSizePixel = 0
profileHost.ScrollBarThickness = 5
profileHost.ScrollBarImageColor3 = Color3.fromRGB(172, 99, 238)
profileHost.CanvasSize = UDim2.new()
profileHost.AutomaticCanvasSize = Enum.AutomaticSize.Y
profileHost.ScrollingDirection = Enum.ScrollingDirection.Y
profileHost.ClipsDescendants = true
profileHost.Visible = false
profileHost.ZIndex = 3
profileHost.Parent = settings.Panel
local profilePadding = Instance.new("UIPadding")
profilePadding.PaddingBottom = UDim.new(0, 8)
profilePadding.PaddingLeft = UDim.new(0, 4)
profilePadding.PaddingRight = UDim.new(0, 10)
profilePadding.Parent = profileHost
local profileLayout = Instance.new("UIListLayout")
profileLayout.Padding = UDim.new(0, 8)
profileLayout.SortOrder = Enum.SortOrder.LayoutOrder
profileLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
profileLayout.Parent = profileHost

local profileRows = {
	{ "TotalRolls", "TOTAL ROLLS", "0" },
	{ "BestRoll", "BEST CAR ROLLED", "1 in ?" },
	{ "CarsDiscovered", "CARS DISCOVERED", "0" },
	{ "Level", "LEVEL", "1" },
	{ "Speed", "SPEED", "0" },
	{ "Luck", "LUCK STAT", "x1.00" },
	{ "SessionTime", "TIME THIS SESSION", "0m 00s" },
}
local profileValues = {}
for order, spec in profileRows do
	local row = Instance.new("Frame")
	row.Name = spec[1]
	row.Size = UDim2.new(1, -8, 0, 48)
	row.BackgroundColor3 = Color3.fromRGB(235, 238, 244)
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.ZIndex = 3
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
	local rowEdge = Instance.new("UIStroke")
	rowEdge.Color = Color3.fromRGB(35, 39, 49)
	rowEdge.Thickness = 3
	rowEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rowEdge.Parent = row
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.Position = UDim2.fromOffset(16, 0)
	name.Size = UDim2.fromScale(0.58, 1)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.Text = spec[2]
	name.TextColor3 = Color3.fromRGB(35, 39, 49)
	name.TextSize = 18
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.ZIndex = 4
	name.Parent = row
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Position = UDim2.fromScale(0.58, 0)
	value.Size = UDim2.new(0.38, -12, 1, 0)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.FredokaOne
	value.Text = spec[3]
	value.TextColor3 = Color3.fromRGB(35, 39, 49)
	value.TextSize = 18
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.ZIndex = 4
	value.Parent = row
	row.Parent = profileHost
	profileValues[spec[1]] = value
end

local settingsCategory = "Settings"
local function setSettingsCategory(category)
	settingsCategory = category == "Profile" and "Profile" or "Settings"
	local showSettings = settingsCategory == "Settings"
	settings.SoundRow.Parent.Visible = showSettings
	settings.EffectsRow.Parent.Visible = showSettings
	settings.AutoRow.Parent.Visible = showSettings
	profileHost.Visible = not showSettings
	settingsTab.BackgroundColor3 = showSettings and Color3.fromRGB(172, 99, 238) or Color3.fromRGB(34, 39, 57)
	profileTab.BackgroundColor3 = showSettings and Color3.fromRGB(34, 39, 57) or Color3.fromRGB(172, 99, 238)
	settings.Gui:SetAttribute("Category", settingsCategory)
end
settingsTab.Activated:Connect(function()
	setSettingsCategory("Settings")
end)
profileTab.Activated:Connect(function()
	setSettingsCategory("Profile")
end)
settings.Panel.Parent:GetPropertyChangedSignal("Visible"):Connect(function()
	if settings.Panel.Parent.Visible then
		setSettingsCategory("Settings")
	end
end)
setSettingsCategory("Settings")

local function refreshProfile()
	local allocations = {}
	for _, stat in config.STATS do
		allocations[stat] = player:GetAttribute("Alloc_" .. stat) or 0
	end
	local multis = config.Multis(allocations)
	local best = bestRolledCar()
	profileValues.TotalRolls.Text = format.SpeedText(player:GetAttribute("Rolls") or 0)
	profileValues.BestRoll.Text = format.Odds(best and best.Chance)
	profileValues.CarsDiscovered.Text = format.SpeedText(#data:GetChildren())
	profileValues.Level.Text = format.SpeedText(player:GetAttribute("Level") or 1)
	profileValues.Speed.Text = format.SpeedText(speed.Value)
	profileValues.Luck.Text = format.Multi(multis.Luck) .. string.format(" · %d pts", allocations.Luck)
	profileValues.SessionTime.Text = formatDuration(os.time() - sessionStartedAt)
end
for _, attr in { "Rolls", "Level", "Alloc_Luck" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshProfile)
end
data.ChildAdded:Connect(refreshProfile)
data.ChildRemoved:Connect(refreshProfile)
speed.Changed:Connect(refreshProfile)
refreshProfile()
task.spawn(function()
	while player.Parent do
		task.wait(1)
		refreshProfile()
	end
end)

-- Rebirth panel (docs/REBIRTH_SPEC.md): the generated layout shows the reset warning, the next rebirth's rewards
-- and the level requirement; the server decides the rebirth, this only displays its numbers and replies.
local function multiplierText(value)
	return format.Multi(value)
end
rebirth.PointRewardCaption.Text = string.format(
	rebirthConfig.POINTS_PER_REBIRTH == 1 and "+%d Stat Point" or "+%d Stat Points",
	rebirthConfig.POINTS_PER_REBIRTH
)
local rebirthBusy, rebirthReply = false, nil
local function refreshRebirth()
	local level = player:GetAttribute("RebirthLevel") or 0
	local nextMultiplier = rebirthConfig.NextMultiplier(level)
	rebirth.LuckRewardCaption.Text = multiplierText(nextMultiplier) .. " Luck"
	rebirth.SpeedRewardCaption.Text = multiplierText(nextMultiplier) .. " Speed Gain"
	local required = rebirthConfig.Requirements(level).Level
	local playerLevel = player:GetAttribute("Level") or 1
	local maxed = level >= rebirthConfig.MAX_LEVEL
	local eligible = not maxed and playerLevel >= required
	rebirth.BarText.Text = maxed and "MAX REBIRTH" or string.format("%d / %d Level", playerLevel, required)
	rebirth.Fill.Size = UDim2.fromScale(maxed and 1 or math.clamp(playerLevel / required, 0, 1), 1)
	local active = eligible and not rebirthBusy
	rebirth.RebirthButton.Active = active
	label(rebirth.RebirthButton, rebirthReply or (maxed and "MAX" or "REBIRTH"))
	Components.Tint(rebirth.RebirthButton, active and GREEN or GRAY)
end
rebirth.RebirthButton.Activated:Connect(function()
	if not rebirth.RebirthButton.Active or rebirthBusy then
		return
	end
	rebirthBusy = true
	refreshRebirth()
	local ok, success, message = pcall(function()
		return remotes:WaitForChild("Rebirth"):InvokeServer()
	end)
	rebirthReply = ok and (success and "REBIRTH COMPLETE" or tostring(message)) or "Connection error"
	rebirthBusy = false
	refreshRebirth()
	local shown = rebirthReply
	task.delay(2.5, function()
		if rebirthReply == shown then
			rebirthReply = nil
			refreshRebirth()
		end
	end)
end)
player:GetAttributeChangedSignal("RebirthLevel"):Connect(refreshRebirth)
player:GetAttributeChangedSignal("Level"):Connect(refreshRebirth)
refreshRebirth()

-- The former Settings auto-roll row is now the local top-down camera toggle.
local function refreshTopDown()
	local on = player:GetAttribute("TopDownView") == true
	label(settings.AutoName, "TOP-DOWN VIEW")
	switch(settings.AutoToggle, on)
end
settings.AutoToggle.Activated:Connect(function()
	player:SetAttribute("TopDownView", player:GetAttribute("TopDownView") ~= true)
	refreshTopDown()
end)
refreshTopDown()

-- Optional bird's-eye camera for auto racing. Mouse-wheel zoom changes the
-- camera height, keeping the car visible from above instead of using a chase
-- camera. The normal Roblox camera is restored when auto racing ends.
local topDownHeight = 48
local TOP_DOWN_MIN = 22
local TOP_DOWN_MAX = 110
local topDownWasActive = false
local savedCameraSubject, savedFieldOfView

local function restoreTopDownCamera(camera)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local wasScripted = topDownWasActive or camera.CameraType == Enum.CameraType.Scriptable
	topDownWasActive = false
	if wasScripted then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid or savedCameraSubject
	end
	if wasScripted and savedFieldOfView then
		camera.FieldOfView = savedFieldOfView
	end
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel and player:GetAttribute("TopDownView") == true then
		topDownHeight = math.clamp(topDownHeight - input.Position.Z * 6, TOP_DOWN_MIN, TOP_DOWN_MAX)
	end
end)

local function autoRaceCar()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = seat and seat.Parent
	if model and model:IsA("Model") and model:GetAttribute("IsCar") and model:GetAttribute("AutoRace") then
		return model
	end
	return nil
end

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	local autoRacing = player:GetAttribute("AutoRacing") == true
	local car = autoRacing and player:GetAttribute("TopDownView") == true and autoRaceCar() or nil
	if car and camera then
		if not topDownWasActive then
			topDownWasActive = true
			savedCameraSubject = camera.CameraSubject
			savedFieldOfView = camera.FieldOfView
		end
		local target = car:GetPivot().Position + Vector3.new(0, 2, 0)
		local desired = CFrame.lookAt(target + Vector3.new(0, topDownHeight, 0), target)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 55
		camera.CFrame = camera.CFrame:Lerp(desired, 1 - 0.84 ^ (dt * 60)) -- same feel as 0.16 per frame at 60 fps, at any fps
	elseif camera and (topDownWasActive or not autoRacing) then
		restoreTopDownCamera(camera)
	end
end)

player:GetAttributeChangedSignal("AutoRacing"):Connect(function()
	if player:GetAttribute("AutoRacing") ~= true then
		local camera = workspace.CurrentCamera
		if camera then
			restoreTopDownCamera(camera)
		end
	end
end)

hud.Index.Activated:Connect(function()
	PanelSwitch.Toggle("Index")
end)
hud.Stats.Activated:Connect(function()
	PanelSwitch.Toggle("Stats")
end)
hud.Settings.Activated:Connect(function()
	PanelSwitch.Toggle("Settings")
end)
hud.Rebirth.Activated:Connect(function()
	PanelSwitch.Toggle("Rebirth")
end)
UserInputService.InputBegan:Connect(function(input, consumed)
	if not consumed and input.KeyCode == Enum.KeyCode.Escape then
		for _, name in ipairs({ "Index", "Stats", "Settings", "Rebirth" }) do
			PanelSwitch.Close(name)
		end
	end
end)

local function refreshIndex()
	local equipped = player:GetAttribute("EquippedCar")
	local count = 0
	for id, tile in pairs(tiles) do
		local owned = data:FindFirstChild(id) ~= nil
		tile.Frame:SetAttribute("Owned", owned)
		tile.Name.Text = owned and tile.Spec.Name or "???"
		tile.Art.ImageColor3 = owned and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		tile.Locked.Visible = not owned
		tile.Info.Text = owned and string.format("%s · x%s", tile.Spec.Rarity, tostring(tile.Spec.SpeedMulti))
			or tile.Spec.Rarity
		tile.Equip.Visible = owned
		local on = id == equipped
		tile.Equip.Active = owned and not on
		tile.Equip.Selectable = owned and not on
		Components.Tint(tile.Equip, on and GRAY or GREEN)
		tile.Equip.Label.Text = on and "EQUIPPED" or "EQUIP"
		if owned then
			count += 1
		end
	end
	index.IndexProgress.Text = string.format(
		"%d / %d DISCOVERED · NEXT POINT IN %d",
		count,
		#catalog.All(),
		config.DISCOVERIES_PER_POINT - count % config.DISCOVERIES_PER_POINT
	)
end
for id, tile in pairs(tiles) do
	tile.Equip.Activated:Connect(function()
		if tile.Equip.Active and data:FindFirstChild(id) then
			remotes.EquipCar:FireServer(id)
		end
	end)
end
data.ChildAdded:Connect(refreshIndex)
data.ChildRemoved:Connect(refreshIndex)
player:GetAttributeChangedSignal("EquippedCar"):Connect(refreshIndex)
refreshIndex()
require(Ui.InventoryTabs).Attach(index, player, refreshIndex)

local function refreshStats()
	local free = player:GetAttribute("StatPoints") or 0
	stats.Points.Text = string.format("%d FREE POINT%s", free, free == 1 and "" or "S")
	local allocations = {}
	for _, stat in ipairs(config.STATS) do
		allocations[stat] = player:GetAttribute("Alloc_" .. stat) or 0
	end
	local multis = config.Multis(allocations)
	for stat, row in pairs(rows) do
		local available = free > 0
		row.Value.Text = string.format(
			"%d pts  %s  >  %s",
			allocations[stat],
			format.Multi(multis[stat]),
			format.Multi(multis[stat] + config.PER_POINT[stat])
		)
		row.Plus.Active = available
		row.Plus.Selectable = available
		Components.Tint(row.Plus, available and (row.Frame:GetAttribute("AccentColor") or GREEN) or GRAY)
	end
	label(hud.Stats, "STATS")
	local badge = hud.Stats:FindFirstChild("PointsBadge")
	if badge then
		badge.Visible = free > 0
		badge.Text = tostring(free)
	end
end
for stat, row in pairs(rows) do
	row.Plus.Activated:Connect(function()
		if row.Plus.Active then
			remotes.AllocateStat:FireServer(stat)
		end
	end)
	player:GetAttributeChangedSignal("Alloc_" .. stat):Connect(refreshStats)
end
player:GetAttributeChangedSignal("StatPoints"):Connect(refreshStats)
refreshStats()

local pendingRace = false
local function refreshRace()
	local racing = player:GetAttribute("AutoRacing") == true
	label(hud.Race, string.upper(format.AutoButtonText(racing)))
	Components.Tint(hud.Race, pendingRace and GRAY or (racing and RED or GREEN))
	hud.Race.Active = not pendingRace
end
hud.Race.Activated:Connect(function()
	if pendingRace then
		return
	end
	pendingRace = true
	refreshRace()
	remotes.SetAutoRace:FireServer(player:GetAttribute("AutoRacing") ~= true)
	task.delay(1, function()
		pendingRace = false
		refreshRace()
	end)
end)
player:GetAttributeChangedSignal("AutoRacing"):Connect(refreshRace)
refreshRace()
-- The Race button breathes (a soft glow behind it) while the player is on foot (section 10).
local raceGlow = Instance.new("Frame")
raceGlow.Name = "BreathGlow"
raceGlow.AnchorPoint = Vector2.new(0.5, 0.5)
raceGlow.Position = UDim2.fromScale(0.5, 0.5)
raceGlow.Size = UDim2.new(1, 10, 1, 10)
raceGlow.BackgroundColor3 = Color3.fromRGB(120, 255, 150)
raceGlow.BackgroundTransparency = 1
raceGlow.ZIndex = 0
raceGlow.Parent = hud.Race.Parent
UiTheme.Corner(raceGlow, "M")
local stopBreath
local function refreshBreath()
	local onFoot = player:GetAttribute("AutoRacing") ~= true
	if onFoot and not stopBreath then
		raceGlow.BackgroundTransparency = 0.85
		stopBreath = UiMotion.Pulse(raceGlow, { BackgroundTransparency = 0.45 }, 1.1)
	elseif not onFoot and stopBreath then
		stopBreath()
		stopBreath = nil
		raceGlow.BackgroundTransparency = 1
	end
end
player:GetAttributeChangedSignal("AutoRacing"):Connect(refreshBreath)
player:GetAttributeChangedSignal("ReduceEffects"):Connect(function()
	if stopBreath then
		stopBreath()
		stopBreath = nil
	end
	refreshBreath()
end)
refreshBreath()

task.spawn(function()
	playerGui:WaitForChild("RollToast")
	local showcase = playerGui:WaitForChild("RollShowcase")
	local function refreshShowcase()
		hud.Gui.Enabled = not showcase.Enabled
	end
	showcase:GetPropertyChangedSignal("Enabled"):Connect(refreshShowcase)
	PanelSwitch.OnChange(refreshShowcase)
	refreshShowcase()
end)

local turboTween
local turboPopUntil = 0
-- Rolls done towards the next turbo roll and how many it takes: the server's TurboCount / TurboEvery (upgrade tree),
-- or the every-10th-roll rule from Rolls before those attributes arrive.
local function turboState()
	local count, every = player:GetAttribute("TurboCount"), player:GetAttribute("TurboEvery")
	if type(count) == "number" and type(every) == "number" and every >= 1 then
		return math.clamp(count, 0, every - 1), every
	end
	return config.TurboProgress(player:GetAttribute("Rolls") or 0), config.TURBO_EVERY
end
local function refreshTurbo()
	local progress, every = turboState()
	if os.clock() >= turboPopUntil then
		hud.TurboLabel.Text = string.format("TURBO LUCK %d/%d", progress, every)
	end
	if turboTween then
		turboTween:Cancel()
	end
	local size = UDim2.fromScale(progress / every, 1)
	turboTween = UiMotion.Create(hud.TurboFill, TweenInfo.new(0.2), { Size = size })
	local tweenRef = turboTween
	tweenRef:Play()
	-- Keep the authoritative endpoint exact for HUD checks and for a turbo reset;
	-- the tween still provides the visible transition between updates.
	task.delay(0.25, function()
		if turboTween == tweenRef then
			hud.TurboFill.Size = size
		end
	end)
end
player:GetAttributeChangedSignal("Rolls"):Connect(refreshTurbo)
player:GetAttributeChangedSignal("TurboCount"):Connect(refreshTurbo)
player:GetAttributeChangedSignal("TurboEvery"):Connect(refreshTurbo)
refreshTurbo()
remotes.RollResult.OnClientEvent:Connect(function(_, _, turbo)
	if type(turbo) == "number" and turbo > 1 then
		turboPopUntil = os.clock() + 1.2
		hud.TurboLabel.Text = "TURBO x" .. tostring(turbo) .. "!"
		UiMotion.Pop(hud.TurboLabel, 0.25)
		UiMotion.Shine(hud.TurboFill)
		task.delay(1.2, function()
			if os.clock() >= turboPopUntil then
				turboPopUntil = 0
				refreshTurbo()
			end
		end)
	end
end)

local levelTween
local function refreshLevel()
	local level = math.max(1, math.floor(tonumber(player:GetAttribute("Level")) or 1))
	local xp = math.max(0, tonumber(player:GetAttribute("XP")) or 0)
	local nextXp = math.max(1, tonumber(player:GetAttribute("XPToNext")) or 100)
	local progress = math.clamp(xp / nextXp, 0, 1)
	hud.LevelLabel.Text = string.format("LEVEL %d  %d/%d XP", level, math.floor(xp), math.floor(nextXp))
	if levelTween then
		levelTween:Cancel()
	end
	local size = UDim2.fromScale(progress, 1)
	levelTween = UiMotion.Create(hud.LevelFill, TweenInfo.new(0.2), { Size = size })
	levelTween:Play()
	local tweenRef = levelTween
	task.delay(0.25, function()
		if levelTween == tweenRef then
			hud.LevelFill.Size = size
		end
	end)
end
for _, attr in { "Level", "XP", "XPToNext" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshLevel)
end
refreshLevel()

local shownSpeed, shownMoney, shownBank = speed.Value, money.Value, player:GetAttribute("Unbanked") or 0
local lastSpeedPop, speedTier = 0, nil
local stopBankPulse
local function readable(value, isMoney)
	return isMoney and format.MoneyText(value) or format.SpeedText(value)
end
-- The Racer panels open in the band between the Race button and the TURBO LUCK bar, centred, clear of the
-- HudChrome icon grid on the left (and the same margin on the right). The generated fit sizes them;
-- here their UIScale shrinks below the generated k only when the band is too small (owner decision 2026-10-08;
-- the compact roll hides while a panel is open). All these ScreenGuis ignore the top-bar inset.
local function fitPanels()
	local camera = workspace.CurrentCamera
	if not camera or camera.ViewportSize.X <= 1 then
		return
	end
	local viewport = camera.ViewportSize
	-- docs/HUD_LAYOUT_SPEC.md section 6: below Race, above TURBO LUCK and Money, between the icon grid and Shop.
	local side, top, right, bottom = PanelBand.Rect()
	if not side then
		return
	end
	local width, height = right - side, bottom - top
	local k = if viewport.Y <= 500
		then math.clamp(viewport.Y / 390, 0.85, 1.15)
		else math.clamp(viewport.Y / 720, 0.6, 1.4)
	for _, refs in pairs(racerPanels) do
		local frame = refs.Panel.Parent
		local scale = frame:FindFirstChildOfClass("UIScale")
		local base = frame.Size
		if scale and base.X.Offset > 0 and base.Y.Offset > 0 then
			scale.Scale = math.max(0.3, math.min(k, width / base.X.Offset, height / base.Y.Offset))
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Position = UDim2.fromOffset((side + right) / 2, top + height / 2)
		end
	end
end

-- On short screens the centred Speed group would reach up into the compact roll (Race bottom + COMPACT_GAP +
-- its height): move it down into the gap above the TURBO bar, never closer than SPEED_TURBO_GAP to the bar.
local SPEED_TOAST_GAP, SPEED_TURBO_GAP = 4, 2
local speedShift, speedSetOffset = 0, nil
local function clearSpeedOfToast(group)
	local position = group.Position
	if speedSetOffset == nil or position.Y.Offset ~= speedSetOffset then
		speedShift = 0 -- the generated fit put the group back at its authored place
	end
	local baseOffset = position.Y.Offset - speedShift
	local toastGui = playerGui:FindFirstChild("RollToast")
	local toast = toastGui and toastGui:FindFirstChild("Toast")
	local turbo = hud.Gui:FindFirstChild("Turbo")
	local shift = 0
	if toast and turbo then
		local groupTop = group.AbsolutePosition.Y - speedShift
		local need = toast.AbsolutePosition.Y + toast.AbsoluteSize.Y + SPEED_TOAST_GAP - groupTop
		local room = turbo.AbsolutePosition.Y - SPEED_TURBO_GAP - (groupTop + group.AbsoluteSize.Y)
		shift = math.max(0, math.min(need, room))
	end
	speedShift = shift
	speedSetOffset = baseOffset + shift
	group.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, speedSetOffset)
end

-- Owner 2026-10-29 (docs/HUD_LAYOUT_SPEC.md section 9): on phones the whole Speed readout (dial, SpeedValue and
-- its +Speed float, which rises from SpeedValue) sits at the BOTTOM RIGHT of the safe area: its visible right edge
-- SPEED_EDGE px in, above whatever sits under its width (weather icon, potion buttons, touch jump button, the
-- Upgrade tile and the LEVEL / TURBO bars), below the race map and the Shop tile with room for the rising float
-- (the map's place is reserved even while it is hidden, so the readout does not jump when a race starts). It keeps
-- the generated phone scale and shrinks only as far as needed to fit there.
local PHONE_MAX_HEIGHT, SPEED_EDGE, SPEED_GAP, SPEED_MIN_SCALE = 500, 8, 6, 0.5 -- min: 50% of the phone size (HUD_LAYOUT_SPEC 9, owner 2026-10-29)
local FLOAT_HEIGHT, FLOAT_RISE = 30, 46 -- shortcut: copies of UiMotion.Float's label size and rise; keep in step
local function absRect(o, needVisible)
	if not (o and o:IsA("GuiObject")) or (needVisible and not o.Visible) then
		return nil
	end
	local p, sz = o.AbsolutePosition, o.AbsoluteSize
	return { p.X, p.Y, p.X + sz.X, p.Y + sz.Y }
end
local function placeSpeedBottomRight(group, visibleWidth, viewportHeight)
	local origin, area = hud.Gui.AbsolutePosition, hud.Gui.AbsoluteSize
	local rightEdge = origin.X + area.X - SPEED_EDGE
	local below = {}
	local progression = playerGui:FindFirstChild("RacerProgression")
	if progression then
		table.insert(below, absRect(progression:FindFirstChild("WeatherIcon"), true))
		local potions = progression:FindFirstChild("PotionStatus")
		if potions and potions.Visible then
			for _, bottle in potions:GetChildren() do
				table.insert(below, absRect(bottle, true))
			end
		end
	end
	local touch = playerGui:FindFirstChild("TouchGui")
	local touchFrame = touch and touch.Enabled and touch:FindFirstChild("TouchControlFrame")
	table.insert(below, absRect(touchFrame and touchFrame:FindFirstChild("JumpButton"), true))
	local chrome = playerGui:FindFirstChild("HudChrome")
	for _, name in { "ItemsSlot", "UpgradeSlot" } do
		table.insert(below, absRect(chrome and chrome:FindFirstChild(name), true))
	end
	for _, name in { "Level", "Turbo" } do
		table.insert(below, absRect(hud.Gui:FindFirstChild(name), true))
	end
	local ceiling = origin.Y
	local above = {
		absRect(hud.Gui:FindFirstChild("RaceMap"), false),
		absRect(chrome and chrome:FindFirstChild("ShopColumn"), true),
	}
	for _, r in above do
		ceiling = math.max(ceiling, r[4] + SPEED_GAP)
	end
	local scale = group:FindFirstChildOfClass("UIScale")
	local old = scale and scale.Scale or 1
	local base = group.Size.Y.Offset
	-- Room for the +Speed float above the group: UiMotion.Float's 30 px label, bottom on SpeedValue's top, rises 46 px.
	local floatAbove = math.max(0, FLOAT_HEIGHT + FLOAT_RISE - hud.SpeedValue.Position.Y.Offset)
	-- Bottom limit: the highest top of everything under the readout's visible span at scale k.
	local function floorAt(k)
		local left = rightEdge - visibleWidth * k / old
		local floor = origin.Y + area.Y - SPEED_EDGE
		for _, r in below do
			if r[3] + SPEED_GAP > left and r[1] < rightEdge then
				floor = math.min(floor, r[2] - SPEED_GAP)
			end
		end
		return floor
	end
	-- Same phone k as the generated fit (RacerHud.luau); the readout never grows past it. A smaller scale only
	-- narrows the span (fewer things beneath it), so "fits" is monotonic: binary-search the largest scale that fits.
	local function fits(k)
		return floorAt(k) - ceiling >= (base + floatAbove) * k
	end
	local k = math.clamp(viewportHeight / 390, 0.85, 1.15)
	if scale and base > 0 then
		if not fits(k) then
			local lo, hi = SPEED_MIN_SCALE * k, k
			for _ = 1, 12 do
				local mid = (lo + hi) / 2
				if fits(mid) then
					lo = mid
				else
					hi = mid
				end
			end
			k = lo
		end
		scale.Scale = k
	else
		k = old
	end
	local floor = floorAt(k)
	local width, height = group.Size.X.Offset * k, base * k
	local centre = Vector2.new(
		rightEdge - visibleWidth * k / old + width * group.AnchorPoint.X,
		floor - height * (1 - group.AnchorPoint.Y)
	) - origin
	group.Position = UDim2.fromOffset(math.floor(centre.X + 0.5), math.floor(centre.Y + 0.5))
	speedShift, speedSetOffset = 0, nil -- back on a desktop / tablet fit, clearSpeedOfToast starts from scratch
end

-- The numbers count up towards the server's values (HudFormat.Approach) and pop when they grow (section 9, 10).
local function refreshReadouts(dt)
	shownSpeed = format.Approach(shownSpeed, speed.Value, dt)
	shownMoney = format.Approach(shownMoney, money.Value, dt)
	shownBank = format.Approach(shownBank, player:GetAttribute("Unbanked") or 0, dt)
	hud.SpeedValue.Text = readable(shownSpeed, false) .. " SPEED"
	hud.MoneyValue.Text = readable(shownMoney, true)
	hud.Unbanked.Text = "UNBANKED " .. readable(shownBank, true)
end
local lastMoney = money.Value
money.Changed:Connect(function(value)
	if value > lastMoney then
		UiMotion.Pop(hud.MoneyValue)
		UiMotion.Float(
			hud.MoneyValue.Parent,
			"+" .. format.MoneyText(value - lastMoney),
			palette.Money,
			UDim2.fromOffset(hud.MoneyValue.Position.X.Offset, hud.MoneyValue.Position.Y.Offset)
		)
	end
	lastMoney = value
end)
-- Speed gain floats like the +$ payout: the gain of each quarter second, summed (HUD_LAYOUT_SPEC section 10).
local SPEED_FLOAT_EVERY = 0.25
local lastSpeed, speedGain = speed.Value, 0
-- The summed differences of large stats carry float error (12345 arrives as 12344.9999...), which GainText's
-- whole-number floor would show one short: snap a sum within that error to the whole gain it really is.
local function shownGain(gain)
	local whole = math.floor(gain + 0.5)
	return if math.abs(gain - whole) <= math.max(1e-6, math.abs(lastSpeed) * 1e-12) then whole else gain
end
speed.Changed:Connect(function(value)
	if value > lastSpeed then
		speedGain += value - lastSpeed
	end
	lastSpeed = value
end)
task.spawn(function()
	while true do
		task.wait(SPEED_FLOAT_EVERY)
		if speedGain > 0 then
			UiMotion.Float(
				hud.SpeedValue.Parent,
				"+" .. format.GainText(shownGain(speedGain)),
				palette.Speed,
				UDim2.fromOffset(hud.SpeedValue.Position.X.Offset, hud.SpeedValue.Position.Y.Offset)
			)
			speedGain = 0
		end
	end
end)
speed.Changed:Connect(function(value)
	-- Speed grows all the time while racing: pop at most every 1.5 s, glow the dial on a new suffix tier.
	local tier = value >= format.SPEED_SUFFIX_FROM and math.floor(math.log10(value) / 3) or 0
	if speedTier and tier > speedTier then
		UiMotion.Pop(hud.SpeedDial, 0.18)
		UiMotion.Shine(hud.MoneyPlate)
	elseif os.clock() - lastSpeedPop > 1.5 then
		lastSpeedPop = os.clock()
		UiMotion.Pop(hud.SpeedValue, 0.06)
	end
	speedTier = tier
end)
local function refreshBank()
	local banked = (player:GetAttribute("Unbanked") or 0) > 0
	if banked and not stopBankPulse then
		UiMotion.Pop(hud.Unbanked)
		stopBankPulse = UiMotion.Pulse(hud.Unbanked, { TextTransparency = 0.35 }, 0.7)
	elseif not banked and stopBankPulse then
		stopBankPulse()
		stopBankPulse = nil
	end
end
player:GetAttributeChangedSignal("Unbanked"):Connect(refreshBank)
refreshBank()
task.spawn(function()
	while true do
		task.wait(6)
		if hud.Gui.Enabled then
			UiMotion.Shine(hud.MoneyPlate)
		end
	end
end)

local function carSpeed()
	local car = autoRaceCar()
	local chassis = car and car.PrimaryPart
	return chassis and chassis.AssemblyLinearVelocity.Magnitude or 0
end

RunService.Heartbeat:Connect(function(dt)
	fitPanels()
	refreshReadouts(dt)
	speedDial.Update(dt, carSpeed(), speed.Value)
	-- Align to the visible dial + left-aligned text, not the label's unused width.
	local icon = hud.SpeedDial
	local right = hud.SpeedValue.AbsolutePosition.X + hud.SpeedValue.TextBounds.X
	if hud.SpeedValue.TextBounds.X > 0 then
		local group = icon.Parent
		local visibleWidth = right - icon.AbsolutePosition.X
		local camera = workspace.CurrentCamera
		-- Phones: placeSpeedBottomRight is event-driven (below), never per frame (section 10 "Budget").
		if not (camera and camera.ViewportSize.Y <= PHONE_MAX_HEIGHT) then
			local groupPosition = group.Position
			group.Position =
				UDim2.new(0.5, (group.AbsoluteSize.X - visibleWidth) / 2, groupPosition.Y.Scale, groupPosition.Y.Offset)
			clearSpeedOfToast(group)
		end
		local wrapper = hud.Turbo.Parent
		local position = wrapper.Position
		wrapper.Position = UDim2.new(0.5, 0, position.Y.Scale, position.Y.Offset)
	end
end)
-- Phone Speed layout runs only when something it measures changes: the viewport, the Speed text, the generated fit
-- resetting the group, or a move / resize / show / hide of anything it clears. Many signals in one frame queue one
-- deferred layout; its own writes settle on the next pass (same values, so no further events).
local phoneSpeedQueued = false
local function layoutPhoneSpeed()
	phoneSpeedQueued = false
	local camera = workspace.CurrentCamera
	local icon, value = hud.SpeedDial, hud.SpeedValue
	if camera and camera.ViewportSize.Y <= PHONE_MAX_HEIGHT and value.TextBounds.X > 0 then
		local visibleWidth = value.AbsolutePosition.X + value.TextBounds.X - icon.AbsolutePosition.X
		placeSpeedBottomRight(icon.Parent, visibleWidth, camera.ViewportSize.Y)
	end
end
local function queuePhoneSpeed()
	if not phoneSpeedQueued then
		phoneSpeedQueued = true
		task.defer(layoutPhoneSpeed)
	end
end
local watched = setmetatable({}, { __mode = "k" })
local function watch(object, properties)
	if watched[object] then
		return
	end
	watched[object] = true
	for _, property in properties do
		object:GetPropertyChangedSignal(property):Connect(queuePhoneSpeed)
	end
	queuePhoneSpeed()
end
local CLEARED = {
	WeatherIcon = true,
	PotionStatus = true,
	JumpButton = true,
	ItemsSlot = true,
	UpgradeSlot = true,
	ShopColumn = true,
	Level = true,
	Turbo = true,
	RaceMap = true,
}
local GEOMETRY = { "AbsolutePosition", "AbsoluteSize", "Visible" }
local function watchCleared(object)
	local potionButton = object.Parent and object.Parent.Name == "PotionStatus"
	if object:IsA("GuiObject") and (CLEARED[object.Name] or potionButton) then
		watch(object, GEOMETRY)
	elseif object:IsA("ScreenGui") and object.Name == "TouchGui" then
		watch(object, { "Enabled" })
	end
end
for _, object in playerGui:GetDescendants() do
	watchCleared(object)
end
playerGui.DescendantAdded:Connect(watchCleared)
local speedGroup = hud.SpeedDial.Parent
watch(hud.SpeedValue, { "TextBounds" })
watch(speedGroup, { "Position" }) -- the generated fit puts the authored place back
local speedScale = speedGroup:FindFirstChildOfClass("UIScale")
if speedScale then
	watch(speedScale, { "Scale" })
end
watch(hud.Gui, { "AbsoluteSize" })
if workspace.CurrentCamera then
	watch(workspace.CurrentCamera, { "ViewportSize" })
end

-- Session-local audio preference: preserve authored volumes and mute new sounds too.
local muted = false
local volumes = setmetatable({}, { __mode = "k" })
local function applySound(sound)
	if sound:IsA("Sound") then
		if volumes[sound] == nil then
			volumes[sound] = sound.Volume
		end
		sound.Volume = muted and 0 or volumes[sound]
	end
end
settings.SoundToggle.Activated:Connect(function()
	muted = not muted
	for _, descendant in ipairs(game:GetDescendants()) do
		applySound(descendant)
	end
	switch(settings.SoundToggle, not muted)
end)
game.DescendantAdded:Connect(function(descendant)
	if muted then
		applySound(descendant)
	end
end)
settings.EffectsToggle.Activated:Connect(function()
	local reduced = player:GetAttribute("ReduceEffects") ~= true
	player:SetAttribute("ReduceEffects", reduced)
	switch(settings.EffectsToggle, reduced)
end)
switch(settings.EffectsToggle, player:GetAttribute("ReduceEffects") == true)
switch(settings.SoundToggle, true)

-- Non-interactive numeric labels must not overflow as saves grow.
for _, object in ipairs({ hud.SpeedValue, hud.MoneyValue, hud.Unbanked, index.IndexProgress, stats.Points }) do
	object.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 14
	limit.MaxTextSize = object.TextSize
	limit.Parent = object
end

for _, root in ipairs({ hud.Gui, settings.Gui }) do
	for _, object in ipairs(root:GetDescendants()) do
		if object:IsA("TextLabel") and object.Parent:IsA("TextButton") then
			object.TextScaled = true
			local limit = Instance.new("UITextSizeConstraint")
			limit.MinTextSize = 14
			limit.MaxTextSize = object.TextSize
			limit.Parent = object
		end
	end
end
hud.Turbo.ClipsDescendants = true
hud.TurboFill.ZIndex = 2
hud.TurboLabel.ZIndex = 5

playerGui:SetAttribute("RacerUiReady", true)

return true
