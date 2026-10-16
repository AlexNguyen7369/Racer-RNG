--!nonstrict
-- Bind saved UI; all economy, ownership and allocation decisions stay on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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
local PanelBand = require(client.PanelBand)
local hud = require(Ui.RacerHud).Bind(playerGui)
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
local index = require(Ui.RacerIndex).Bind(playerGui)
local stats = require(Ui.RacerStats).Bind(playerGui)
local settings = require(Ui.RacerSettings).Bind(playerGui)
local rebirth = require(Ui.RacerRebirth).Bind(playerGui)
local rebirthConfig = require(Shared.RebirthConfig)
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

-- Rebirth panel (docs/REBIRTH_SPEC.md): the generated layout shows the reset warning, the next rebirth's rewards
-- and the level requirement; the server decides the rebirth, this only displays its numbers and replies.
local function percent(fraction)
	return math.floor(fraction * 100 + 0.5)
end
rebirth.LuckRewardCaption.Text = string.format("+%d%% Luck", percent(rebirthConfig.LUCK_GAIN_PER_LEVEL))
rebirth.SpeedRewardCaption.Text = string.format("+%d%% Speed Gain", percent(rebirthConfig.GAIN_PER_LEVEL))
rebirth.PointRewardCaption.Text = string.format(
	rebirthConfig.POINTS_PER_REBIRTH == 1 and "+%d Stat Point" or "+%d Stat Points",
	rebirthConfig.POINTS_PER_REBIRTH
)
local rebirthBusy, rebirthReply = false, nil
local function refreshRebirth()
	local level = player:GetAttribute("RebirthLevel") or 0
	local required = rebirthConfig.Requirements(level).Level
	local playerLevel = player:GetAttribute("Level") or 1
	local eligible = playerLevel >= required
	rebirth.BarText.Text = string.format("%d / %d Level", playerLevel, required)
	rebirth.Fill.Size = UDim2.fromScale(math.clamp(playerLevel / required, 0, 1), 1)
	local active = eligible and not rebirthBusy and level < rebirthConfig.MAX_LEVEL
	rebirth.RebirthButton.Active = active
	label(rebirth.RebirthButton, rebirthReply or "REBIRTH")
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

task.spawn(function()
	playerGui:WaitForChild("RollToast")
	local showcase = playerGui:WaitForChild("RollShowcase")
	local function refreshShowcase()
		local upgrades = playerGui:FindFirstChild("RacerUpgrades")
		local treeOpen = upgrades and upgrades:FindFirstChild("Panel") and upgrades.Panel.Visible
		hud.Gui.Enabled = not showcase.Enabled and not treeOpen
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
		turboPopUntil = os.clock() + 1.2
		hud.TurboLabel.Text = "TURBO x" .. tostring(turbo) .. "!"
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
	levelTween = TweenService:Create(hud.LevelFill, TweenInfo.new(0.2), { Size = size })
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

local leaderstats = player:WaitForChild("leaderstats")
local speed = leaderstats:WaitForChild("Speed")
local money = leaderstats:WaitForChild("Money")
local shownSpeed, shownMoney, shownBank = speed.Value, money.Value, player:GetAttribute("Unbanked") or 0
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

local function refreshReadouts()
	shownSpeed = speed.Value
	shownMoney = money.Value
	shownBank = player:GetAttribute("Unbanked") or 0
	hud.SpeedValue.Text = readable(shownSpeed, false) .. " SPEED"
	hud.MoneyValue.Text = readable(shownMoney, true)
	hud.Unbanked.Text = "UNBANKED " .. readable(shownBank, true)
end
speed.Changed:Connect(refreshReadouts)
money.Changed:Connect(refreshReadouts)
player:GetAttributeChangedSignal("Unbanked"):Connect(refreshReadouts)

RunService.Heartbeat:Connect(function(_dt)
	fitPanels()
	refreshReadouts()
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
