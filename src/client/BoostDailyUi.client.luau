--!nonstrict
-- Bag and seven-day daily reward presentation. Server remotes own all grants.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local dailyConfig = require(ReplicatedStorage.Shared.DailyLoginConfig)
local questConfig = require(ReplicatedStorage.Shared.QuestConfig)
local HttpService = game:GetService("HttpService")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))

local screen = Instance.new("ScreenGui")
screen.Name = "DailyBoosts"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 6
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = gui

local function make(class, name, parent, props)
	local instance = Instance.new(class)
	instance.Name = name
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function rounded(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function button(name, parent, position, size, text)
	local instance = make("TextButton", name, parent, {
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(42, 54, 84),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Text = text,
		AutoButtonColor = true,
	})
	rounded(instance, 8)
	return instance
end

local backdrop = make("Frame", "ModalBackdrop", screen, {
	Position = UDim2.fromScale(0, 0),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	Visible = false,
})
PanelSwitch.Register("Daily", backdrop)
local modal = make("Frame", "Modal", backdrop, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 146),
	Size = UDim2.fromScale(0.58, 0.48),
	BackgroundColor3 = Color3.fromRGB(29, 32, 53),
})
rounded(modal, 14)
local title = make("TextLabel", "Title", modal, {
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(1, -76, 0, 34),
	BackgroundTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 21,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "DAILY REWARDS",
})
local close = button("Close", modal, UDim2.new(1, -50, 0, 8), UDim2.fromOffset(36, 30), "×")
close.BackgroundColor3 = Color3.fromRGB(210, 75, 90)
local content = make("ScrollingFrame", "Content", modal, {
	Position = UDim2.fromOffset(14, 52),
	Size = UDim2.new(1, -28, 1, -66),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
})
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = content

local status = make("TextLabel", "Status", screen, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 1, -130),
	Size = UDim2.fromOffset(160, 42),
	BackgroundTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "",
})

local function refreshChrome()
	local camera = workspace.CurrentCamera
	local compact = camera and camera.ViewportSize.Y <= 500
	status.Visible = not compact and not PanelSwitch.AnyOpen()
end

PanelSwitch.OnChange(refreshChrome)
backdrop:GetPropertyChangedSignal("Visible"):Connect(refreshChrome)

local function clearContent()
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local fresh = Instance.new("UIListLayout")
	fresh.Padding = UDim.new(0, 8)
	fresh.Parent = content
end

local view = nil -- "Daily" or "Quests": which content the shared modal shows
local function showDaily()
	view = "Daily"
	if not backdrop.Visible then
		PanelSwitch.Toggle("Daily")
	end
	backdrop.Visible = true
	refreshChrome()
	title.Text = "DAILY REWARDS • 7 DAYS"
	clearContent()
	local streak = math.clamp(player:GetAttribute("DailyStreak") or 0, 0, 7)
	local last = player:GetAttribute("DailyLast") or -1
	local claimedToday = last == math.floor(os.time() / 86400)
	for day, reward in ipairs(dailyConfig.Rewards) do
		local details = reward.GuaranteedRare and "Guaranteed rare car"
			or ("%d x %s Potion I"):format(reward.BoostCount or 1, reward.Boost)
		local row = make("TextLabel", "Day" .. day, content, {
			Size = UDim2.new(1, -8, 0, 38),
			BackgroundColor3 = day <= streak and Color3.fromRGB(48, 110, 78) or Color3.fromRGB(42, 54, 84),
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "  DAY " .. day .. (day <= streak and "  ✓  " or "     ") .. details,
		})
		rounded(row, 8)
	end
	local claim = button(
		"Claim",
		content,
		UDim2.fromOffset(0, 0),
		UDim2.new(1, -8, 0, 42),
		claimedToday and "CLAIMED TODAY" or "CLAIM DAY " .. tostring(math.min(streak + 1, 7))
	)
	claim.LayoutOrder = 20
	claim.Active = not claimedToday
	claim.AutoButtonColor = claim.Active
	claim.Activated:Connect(function()
		if not claim.Active then
			return
		end
		local ok, success, reward = pcall(function()
			return ReplicatedStorage.Remotes:WaitForChild("DailyClaim"):InvokeServer()
		end)
		if ok and success then
			status.Text = "Claimed Day " .. tostring(reward.Day)
			showDaily()
		else
			status.Text = ok and tostring(reward) or "Connection error"
		end
	end)
end

local function decode(name)
	local raw = player:GetAttribute(name)
	if type(raw) ~= "string" then
		return {}
	end
	local ok, value = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return ok and type(value) == "table" and value or {}
end

local function showQuests()
	view = "Quests"
	if not backdrop.Visible then
		PanelSwitch.Toggle("Daily")
	end
	backdrop.Visible = true
	refreshChrome()
	title.Text = "QUESTS"
	clearContent()
	local function renderGroup(label, quests, progress, claimed, weekly)
		make("TextLabel", label, content, {
			Size = UDim2.new(1, -8, 0, 30), BackgroundTransparency = 1, Text = label,
			TextColor3 = Color3.fromRGB(255, 196, 75), Font = Enum.Font.GothamBlack, TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		for _, quest in quests do
			local current = math.min(quest.Target, progress[quest.Id] or 0)
			local done = claimed[quest.Id] == 1
			local row = make("Frame", quest.Id, content, { Size = UDim2.new(1, -8, 0, 52), BackgroundColor3 = Color3.fromRGB(42, 54, 84) })
			rounded(row, 7)
			make("TextLabel", "Text", row, { Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -122, 0, 22), BackgroundTransparency = 1, Text = quest.Name, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left })
			make("TextLabel", "Progress", row, { Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -122, 0, 18), BackgroundTransparency = 1, Text = string.format("%d / %d  •  %s", current, quest.Target, quest.Reward), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(193, 205, 225), TextXAlignment = Enum.TextXAlignment.Left })
			local claim = button("Claim", row, UDim2.new(1, -106, 0.5, -16), UDim2.fromOffset(96, 32), done and "CLAIMED" or current >= quest.Target and "CLAIM" or "LOCKED")
			claim.Active = not done and current >= quest.Target
			claim.AutoButtonColor = claim.Active
			claim.BackgroundColor3 = claim.Active and Color3.fromRGB(70, 175, 105) or Color3.fromRGB(80, 88, 112)
			claim.Activated:Connect(function()
				if not claim.Active then return end
				local ok, success, message = pcall(function()
					return ReplicatedStorage.Remotes.QuestClaim:InvokeServer(weekly, quest.Id)
				end)
				status.Text = ok and (success and ("Claimed " .. tostring(message)) or tostring(message)) or "Connection error"
				showQuests()
			end)
		end
	end
	renderGroup("DAILY", questConfig.Daily, decode("QuestDailyProgress"), decode("QuestDailyClaimed"), false)
	renderGroup("WEEKLY", questConfig.Weekly, decode("QuestWeeklyProgress"), decode("QuestWeeklyClaimed"), true)
end

-- The top-right Daily and Quests pills (HudChrome) share this modal; a second click on the same pill closes it.
local function action(name, show)
	return function()
		if backdrop.Visible and view == name then
			PanelSwitch.Close("Daily")
			return
		end
		show()
	end
end
PanelSwitch.SetAction("Daily", action("Daily", showDaily))
PanelSwitch.SetAction("Quests", action("Quests", showQuests))
close.Activated:Connect(function()
	PanelSwitch.Close("Daily")
	backdrop.Visible = false
	refreshChrome()
end)

refreshChrome()
task.spawn(function()
	while screen.Parent do
		refreshChrome()
		task.wait(0.05)
	end
end)

local autoShownDay = nil
task.spawn(function()
	while screen.Parent do
		task.wait(1)
		local last = player:GetAttribute("DailyLast") or -1
		local today = math.floor(os.time() / 86400)
		-- Auto-open once per UTC day: after the player closes it, only the button reopens it.
		if last ~= today and autoShownDay ~= today and not backdrop.Visible then
			autoShownDay = today
			showDaily()
		end
	end
end)

-- Opens in the shared band between the HUD entries (docs/HUD_LAYOUT_SPEC.md section 6).
require(script.Parent:WaitForChild("PanelBand")).Fit(modal, 760)
