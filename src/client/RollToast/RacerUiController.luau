--!nonstrict
-- Bind saved UI; all economy, ownership and allocation decisions stay on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local catalog = require(Shared.CarCatalog)
local config = require(Shared.GachaConfig)
local format = require(Shared.HudFormat)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Ui = script.Parent:WaitForChild("Ui")
local Components = require(Ui.RacerComponents)
require(Ui.RacerMotion).Attach(playerGui)
local client = script.Parent:IsA("LocalScript") and script.Parent.Parent or script.Parent
local PanelSwitch = require(client.PanelSwitch)
local hud = require(Ui.RacerHud).Bind(playerGui)
-- The saved HUD asset predates the session-local free-points badge. Bake the
-- small badge at runtime so the live HUD and UiSpec share the same contract.
Components.BakeHud(hud)
-- Uploaded HUD art shares an atlas; keep the individual icon crops when binding.
hud.MoneyIcon.ImageRectOffset = Vector2.new(0, 0)
hud.MoneyIcon.ImageRectSize = Vector2.new(256, 256)
hud.SpeedIcon.ImageRectOffset = Vector2.new(256, 0)
hud.SpeedIcon.ImageRectSize = Vector2.new(256, 256)
hud.MoneyValue.TextXAlignment = Enum.TextXAlignment.Left
hud.Unbanked.TextXAlignment = Enum.TextXAlignment.Left
hud.SpeedValue.TextXAlignment = Enum.TextXAlignment.Left
local index = require(Ui.RacerIndex).Bind(playerGui)
local stats = require(Ui.RacerStats).Bind(playerGui)
local settings = require(Ui.RacerSettings).Bind(playerGui)
local rebirth = require(Ui.RacerRebirth).Bind(playerGui)
-- Catalog additions extend the saved gallery without waiting forever for an old seven-car bake.
local gallery = index.GridHost:FindFirstChild("Gallery")
for _, spec in catalog.All() do
	if not gallery or not gallery:FindFirstChild(spec.Id) then
		if gallery then
			gallery:Destroy()
		end
		Components.BakeIndex(index, catalog, config)
		break
	end
end
local tiles = Components.BindIndex(index, catalog)
local rows = Components.BindStats(stats, config)
local GREEN = Color3.fromRGB(60, 255, 60)
local RED = Color3.fromRGB(255, 77, 94)
local GRAY = Color3.fromRGB(104, 111, 135)

-- Roll entry is the compact animation at the top centre of the screen. The old
-- bottom roll controls and Settings auto-roll row are intentionally hidden.
hud.RollControls.Visible = false
-- Generated responsive fits reapply authored visibility on viewport changes.
-- Keep the retired entry points hidden throughout those fits.
hud.RollControls:GetPropertyChangedSignal("Visible"):Connect(function()
	if hud.RollControls.Visible then
		hud.RollControls.Visible = false
	end
end)
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
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("TextLabel") then
			child.Text = value
		end
	end
end

-- The former Settings auto-roll row is now the local top-down camera toggle.
local function refreshTopDown()
	local on = player:GetAttribute("TopDownView") == true
	label(settings.AutoName, "TOP-DOWN VIEW")
	label(settings.AutoToggle, on and "ON" or "OFF")
	Components.Tint(settings.AutoToggle, on and GREEN or GRAY)
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
local savedCameraType, savedCameraSubject, savedFieldOfView

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

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	local car = player:GetAttribute("TopDownView") == true and autoRaceCar() or nil
	if car and camera then
		if not topDownWasActive then
			topDownWasActive = true
			savedCameraType = camera.CameraType
			savedCameraSubject = camera.CameraSubject
			savedFieldOfView = camera.FieldOfView
		end
		local target = car:GetPivot().Position + Vector3.new(0, 2, 0)
		local desired = CFrame.lookAt(target + Vector3.new(0, topDownHeight, 0), target)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 55
		camera.CFrame = camera.CFrame:Lerp(desired, 0.16)
	elseif topDownWasActive and camera then
		topDownWasActive = false
		camera.CameraType = savedCameraType or Enum.CameraType.Custom
		camera.CameraSubject = savedCameraSubject
		if savedFieldOfView then
			camera.FieldOfView = savedFieldOfView
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

local data = player:WaitForChild("GachaData")
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
			"%d pts  x%.2f  >  x%.2f",
			allocations[stat],
			multis[stat],
			multis[stat] + config.PER_POINT[stat]
		)
		row.Plus.Active = available
		row.Plus.Selectable = available
		Components.Tint(row.Plus, available and GREEN or GRAY)
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
	label(hud.Race, format.AutoButtonText(racing))
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

task.spawn(function()
	playerGui:WaitForChild("RollToast")
	local showcase = playerGui:WaitForChild("RollShowcase")
	local function refreshShowcase()
		hud.Gui.Enabled = not showcase.Enabled
	end
	showcase:GetPropertyChangedSignal("Enabled"):Connect(refreshShowcase)
	refreshShowcase()
end)

local turboTween
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
	hud.TurboLabel.Text = string.format("TURBO LUCK %d/%d", progress, every)
	if turboTween then
		turboTween:Cancel()
	end
	local size = UDim2.fromScale(progress / every, 1)
	turboTween = TweenService:Create(hud.TurboFill, TweenInfo.new(0.2), { Size = size })
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
		hud.TurboLabel.Text = "TURBO x" .. tostring(turbo) .. "!"
		task.delay(1.2, refreshTurbo)
	end
end)

local leaderstats = player:WaitForChild("leaderstats")
local speed = leaderstats:WaitForChild("Speed")
local money = leaderstats:WaitForChild("Money")
local shownSpeed, shownMoney, shownBank = speed.Value, money.Value, player:GetAttribute("Unbanked") or 0
local function readable(value, isMoney)
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, unit in ipairs(units) do
		if value >= unit[1] then
			return (isMoney and "$" or "") .. string.format("%.1f%s", value / unit[1], unit[2])
		end
	end
	return isMoney and format.MoneyText(value) or format.SpeedText(value)
end
-- The Racer panels open in the band between the Race button and the TURBO LUCK bar, centred, clear of the
-- INDEX / STATS / REBIRTH column on the left (and the same margin on the right). The generated fit sizes them;
-- here their UIScale shrinks below the generated k only when the band is too small (owner decision 2026-10-08;
-- the compact roll hides while a panel is open). All these ScreenGuis ignore the top-bar inset.
local PANEL_GAP = 8
local function fitPanels()
	local camera = workspace.CurrentCamera
	if not camera or camera.ViewportSize.X <= 1 then
		return
	end
	local viewport = camera.ViewportSize
	local inset = GuiService:GetGuiInset().Y
	local race = hud.Gui:FindFirstChild("Race")
	local raceFace = race and race:FindFirstChild("Face")
	local turbo = hud.Gui:FindFirstChild("Turbo")
	local navigation = hud.Gui:FindFirstChild("Navigation")
	if not (raceFace and turbo and navigation) then
		return
	end
	local top = raceFace.AbsolutePosition.Y + raceFace.AbsoluteSize.Y + inset + PANEL_GAP
	local bottom = turbo.AbsolutePosition.Y + inset - PANEL_GAP
	-- The column's right edge includes what sticks out of it (the STATS free-points badge).
	local columnRight = navigation.AbsolutePosition.X + navigation.AbsoluteSize.X
	for _, child in navigation:GetDescendants() do
		if child:IsA("GuiObject") and child.Visible then
			columnRight = math.max(columnRight, child.AbsolutePosition.X + child.AbsoluteSize.X)
		end
	end
	local side = columnRight + PANEL_GAP
	local width, height = viewport.X - 2 * side, bottom - top
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
			frame.Position = UDim2.new(0.5, 0, 0, top + height / 2)
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

RunService.Heartbeat:Connect(function(dt)
	fitPanels()
	shownSpeed = format.Approach(shownSpeed, speed.Value, dt)
	shownMoney = format.Approach(shownMoney, money.Value, dt)
	-- Unbanked is a live round result, so never leave the sublabel behind the
	-- authoritative value while the money/speed readouts are animating.
	shownBank = player:GetAttribute("Unbanked") or 0
	hud.SpeedValue.Text = readable(shownSpeed, false) .. " SPEED"
	hud.MoneyValue.Text = readable(shownMoney, true)
	hud.Unbanked.Text = "UNBANKED " .. readable(shownBank, true)
	-- Align to the visible icon + left-aligned text, not the label's unused width.
	local icon = hud.SpeedIcon
	local right = hud.SpeedValue.AbsolutePosition.X + hud.SpeedValue.TextBounds.X
	if hud.SpeedValue.TextBounds.X > 0 then
		local group = icon.Parent
		local visibleWidth = right - icon.AbsolutePosition.X
		local groupPosition = group.Position
		group.Position =
			UDim2.new(0.5, (group.AbsoluteSize.X - visibleWidth) / 2, groupPosition.Y.Scale, groupPosition.Y.Offset)
		clearSpeedOfToast(group)
		local wrapper = hud.Turbo.Parent
		local position = wrapper.Position
		wrapper.Position = UDim2.new(0.5, 0, position.Y.Scale, position.Y.Offset)
	end
end)
player:GetAttributeChangedSignal("Unbanked"):Connect(function()
	shownBank = player:GetAttribute("Unbanked") or 0
end)

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
	label(settings.SoundToggle, muted and "OFF" or "ON")
	Components.Tint(settings.SoundToggle, muted and GRAY or GREEN)
end)
game.DescendantAdded:Connect(function(descendant)
	if muted then
		applySound(descendant)
	end
end)
settings.EffectsToggle.Activated:Connect(function()
	local reduced = player:GetAttribute("ReduceEffects") ~= true
	player:SetAttribute("ReduceEffects", reduced)
	label(settings.EffectsToggle, reduced and "ON" or "OFF")
	Components.Tint(settings.EffectsToggle, reduced and GREEN or GRAY)
end)
label(settings.EffectsToggle, player:GetAttribute("ReduceEffects") == true and "ON" or "OFF")
Components.Tint(settings.EffectsToggle, player:GetAttribute("ReduceEffects") == true and GREEN or GRAY)

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
