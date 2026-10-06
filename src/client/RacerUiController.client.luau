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
local Ui = script.Parent:WaitForChild("Ui")
local Components = require(Ui.RacerComponents)
local PanelSwitch = require(script.Parent.PanelSwitch)
local hud = require(Ui.RacerHud).Bind(playerGui)
local index = require(Ui.RacerIndex).Bind(playerGui)
local stats = require(Ui.RacerStats).Bind(playerGui)
local settings = require(Ui.RacerSettings).Bind(playerGui)
local tiles = Components.BindIndex(index, catalog)
local rows = Components.BindStats(stats, config)
local GREEN = Color3.fromRGB(60, 255, 60)
local RED = Color3.fromRGB(255, 77, 94)
local GRAY = Color3.fromRGB(104, 111, 135)

hud.Gui.DisplayOrder = 1
for name, refs in pairs({ Index = index, Stats = stats, Settings = settings }) do
    refs.Gui.DisplayOrder = 2
    refs.Panel.Parent.Visible = false
    refs.Gui.Enabled = true
    PanelSwitch.Register(name, refs.Panel.Parent)
    refs.Close.Activated:Connect(function() PanelSwitch.Close(name) end)
end

local function label(button, value)
    for _, child in ipairs(button:GetChildren()) do
        if child:IsA("TextLabel") then child.Text = value end
    end
end

hud.Index.Activated:Connect(function() PanelSwitch.Toggle("Index") end)
hud.Stats.Activated:Connect(function() PanelSwitch.Toggle("Stats") end)
hud.Settings.Activated:Connect(function() PanelSwitch.Toggle("Settings") end)
UserInputService.InputBegan:Connect(function(input, consumed)
    if not consumed and input.KeyCode == Enum.KeyCode.Escape then
        for _, name in ipairs({ "Index", "Stats", "Settings" }) do PanelSwitch.Close(name) end
    end
end)

local originalSoon = hud.RebirthSoon.Text
local rebirthStamp = 0
hud.Rebirth.Activated:Connect(function()
    rebirthStamp += 1
    local stamp = rebirthStamp
    hud.RebirthSoon.Text = "COMING SOON!"
    task.delay(1.5, function() if rebirthStamp == stamp then hud.RebirthSoon.Text = originalSoon end end)
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
        tile.Info.Text = owned and string.format("%s · x%s", tile.Spec.Rarity, tostring(tile.Spec.SpeedMulti)) or tile.Spec.Rarity
        tile.Equip.Visible = owned
        local on = id == equipped
        tile.Equip.Active = owned and not on
        tile.Equip.Selectable = owned and not on
        Components.Tint(tile.Equip, on and GRAY or GREEN)
        tile.Equip.Label.Text = on and "EQUIPPED" or "EQUIP"
        if owned then count += 1 end
    end
    index.IndexProgress.Text = string.format("%d / %d DISCOVERED · NEXT POINT IN %d", count, #catalog.All(), config.DISCOVERIES_PER_POINT - count % config.DISCOVERIES_PER_POINT)
end
for id, tile in pairs(tiles) do
    tile.Equip.Activated:Connect(function()
        if tile.Equip.Active and data:FindFirstChild(id) then remotes.EquipCar:FireServer(id) end
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
    for _, stat in ipairs(config.STATS) do allocations[stat] = player:GetAttribute("Alloc_" .. stat) or 0 end
    local multis = config.Multis(allocations)
    for stat, row in pairs(rows) do
        local available = free > 0 and stat ~= "Workshop"
        row.Value.Text = stat == "Workshop" and "x1.00 · COMING SOON" or string.format("x%.2f  >  x%.2f", multis[stat], multis[stat] + config.PER_POINT[stat])
        row.Plus.Active = available
        row.Plus.Selectable = available
        Components.Tint(row.Plus, available and GREEN or GRAY)
    end
    label(hud.Stats, "STATS")
    local badge = hud.Stats:FindFirstChild("PointsBadge")
    if badge then badge.Visible = free > 0; badge.Label.Text = tostring(free) end
end
for stat, row in pairs(rows) do
    row.Plus.Activated:Connect(function()
        if row.Plus.Active and stat ~= "Workshop" then remotes.AllocateStat:FireServer(stat) end
    end)
    player:GetAttributeChangedSignal("Alloc_" .. stat):Connect(refreshStats)
end
player:GetAttributeChangedSignal("StatPoints"):Connect(refreshStats)
refreshStats()

local pendingRace = false
local function refreshRace()
    local racing = player:GetAttribute("AutoRacing") == true
    label(hud.Race, racing and "STOP AUTO" or "AUTO RACE")
    Components.Tint(hud.Race, pendingRace and GRAY or (racing and RED or GREEN))
    hud.Race.Active = not pendingRace
end
hud.Race.Activated:Connect(function()
    if pendingRace then return end
    pendingRace = true; refreshRace()
    remotes.SetAutoRace:FireServer(player:GetAttribute("AutoRacing") ~= true)
    task.delay(1, function() pendingRace = false; refreshRace() end)
end)
player:GetAttributeChangedSignal("AutoRacing"):Connect(refreshRace)
refreshRace()

local function refreshAuto()
    local on = player:GetAttribute("AutoRoll") ~= false
    label(hud.AutoRoll, on and "AUTO ON" or "AUTO OFF")
    Components.Tint(hud.AutoRoll, on and GREEN or GRAY)
    label(settings.AutoToggle, on and "ON" or "OFF")
    Components.Tint(settings.AutoToggle, on and GREEN or GRAY)
end
local function toggleAuto() remotes.SetAutoRoll:FireServer(player:GetAttribute("AutoRoll") == false) end
hud.AutoRoll.Activated:Connect(toggleAuto)
settings.AutoToggle.Activated:Connect(toggleAuto)
player:GetAttributeChangedSignal("AutoRoll"):Connect(refreshAuto)
refreshAuto()
task.spawn(function()
    local toast = playerGui:WaitForChild("RollToast")
    local openRollView = toast:WaitForChild("OpenRollView")
    hud.RollView.Activated:Connect(function() openRollView:Fire() end)
    local showcase = playerGui:WaitForChild("RollShowcase")
    local function refreshShowcase() hud.Gui.Enabled = not showcase.Enabled end
    showcase:GetPropertyChangedSignal("Enabled"):Connect(refreshShowcase)
    refreshShowcase()
end)

local turboTween
local function refreshTurbo()
    local progress = config.TurboProgress(player:GetAttribute("Rolls") or 0)
    hud.TurboLabel.Text = string.format("TURBO LUCK %d/%d", progress, config.TURBO_EVERY)
    if turboTween then turboTween:Cancel() end
    turboTween = TweenService:Create(hud.TurboFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(progress / config.TURBO_EVERY, 1) })
    turboTween:Play()
end
player:GetAttributeChangedSignal("Rolls"):Connect(refreshTurbo)
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
        if value >= unit[1] then return (isMoney and "$" or "") .. string.format("%.1f%s", value / unit[1], unit[2]) end
    end
    return isMoney and format.MoneyText(value) or format.SpeedText(value)
end
RunService.Heartbeat:Connect(function(dt)
    shownSpeed = format.Approach(shownSpeed, speed.Value, dt)
    shownMoney = format.Approach(shownMoney, money.Value, dt)
    shownBank = format.Approach(shownBank, player:GetAttribute("Unbanked") or 0, dt)
    hud.SpeedValue.Text = readable(shownSpeed, false) .. " SPEED"
    hud.SpeedRate.Text = format.RateText(shownSpeed)
    hud.MoneyValue.Text = readable(shownMoney, true)
    hud.Unbanked.Text = "UNBANKED " .. readable(shownBank, true)
end)

-- Session-local audio preference: preserve authored volumes and mute new sounds too.
local muted = false
local volumes = setmetatable({}, { __mode = "k" })
local function applySound(sound)
    if sound:IsA("Sound") then
        if volumes[sound] == nil then volumes[sound] = sound.Volume end
        sound.Volume = muted and 0 or volumes[sound]
    end
end
settings.SoundToggle.Activated:Connect(function()
    muted = not muted
    for _, descendant in ipairs(game:GetDescendants()) do applySound(descendant) end
    label(settings.SoundToggle, muted and "OFF" or "ON")
    Components.Tint(settings.SoundToggle, muted and GRAY or GREEN)
end)
game.DescendantAdded:Connect(function(descendant) if muted then applySound(descendant) end end)
settings.EffectsToggle.Activated:Connect(function()
    local reduced = player:GetAttribute("ReduceEffects") ~= true
    player:SetAttribute("ReduceEffects", reduced)
    label(settings.EffectsToggle, reduced and "ON" or "OFF")
    Components.Tint(settings.EffectsToggle, reduced and GREEN or GRAY)
end)
label(settings.EffectsToggle, player:GetAttribute("ReduceEffects") == true and "ON" or "OFF")
Components.Tint(settings.EffectsToggle, player:GetAttribute("ReduceEffects") == true and GREEN or GRAY)

-- Non-interactive numeric labels must not overflow as saves grow.
for _, object in ipairs({ hud.SpeedValue, hud.SpeedRate, hud.MoneyValue, hud.Unbanked, index.IndexProgress, stats.Points }) do
    object.TextScaled = true
    local limit = Instance.new("UITextSizeConstraint")
    limit.MinTextSize = 14; limit.MaxTextSize = object.TextSize
    limit.Parent = object
end

for _, root in ipairs({ hud.Gui, settings.Gui }) do
    for _, object in ipairs(root:GetDescendants()) do
        if object:IsA("TextLabel") and object.Parent:IsA("TextButton") then
            object.TextScaled = true
            local limit = Instance.new("UITextSizeConstraint")
            limit.MinTextSize = 14; limit.MaxTextSize = object.TextSize
            limit.Parent = object
        end
    end
end
hud.Turbo.ClipsDescendants = true
hud.TurboFill.ZIndex = 2
hud.TurboLabel.ZIndex = 5

playerGui:SetAttribute("RacerUiReady", true)

