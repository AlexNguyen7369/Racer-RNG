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

-- Quest list/detail treatment from images/UI_QuestReference.png. The game has
-- Daily and Weekly quest data only, so the reference's other categories and
-- search controls are intentionally omitted.
local questTabs = make("Frame", "QuestTabs", modal, {
	Position = UDim2.fromOffset(14, 52),
	Size = UDim2.new(1, -28, 0, 38),
	BackgroundTransparency = 1,
	Visible = false,
})
local questTabLayout = Instance.new("UIListLayout")
questTabLayout.FillDirection = Enum.FillDirection.Horizontal
questTabLayout.Padding = UDim.new(0, 8)
questTabLayout.Parent = questTabs
local dailyQuestTab = button("Daily", questTabs, UDim2.new(), UDim2.new(0.5, -4, 1, 0), "DAILY")
local weeklyQuestTab = button("Weekly", questTabs, UDim2.new(), UDim2.new(0.5, -4, 1, 0), "WEEKLY")

local questDetail = make("Frame", "QuestDetail", modal, {
	Position = UDim2.new(0.55, 0, 0, 100),
	Size = UDim2.new(0.45, -14, 1, -114),
	BackgroundColor3 = Color3.fromRGB(18, 27, 47),
	BorderSizePixel = 0,
	Visible = false,
})
rounded(questDetail, 10)
local questDetailEdge = Instance.new("UIStroke")
questDetailEdge.Color = Color3.fromRGB(25, 201, 235)
questDetailEdge.Thickness = 2
questDetailEdge.Parent = questDetail
local function detailText(name, position, size, textSize, color)
	return make("TextLabel", name, questDetail, {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = color,
		Font = Enum.Font.GothamBold,
		TextSize = textSize,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end
local questType =
	detailText("Type", UDim2.fromOffset(14, 12), UDim2.new(1, -28, 0, 20), 13, Color3.fromRGB(25, 201, 235))
local questName =
	detailText("Name", UDim2.fromOffset(14, 35), UDim2.new(1, -28, 0, 54), 22, Color3.fromRGB(255, 190, 42))
local questGoal =
	detailText("Goal", UDim2.fromOffset(14, 94), UDim2.new(1, -28, 0, 42), 14, Color3.fromRGB(230, 234, 241))
local progressTrack = make("Frame", "ProgressTrack", questDetail, {
	Position = UDim2.fromOffset(14, 144),
	Size = UDim2.new(1, -28, 0, 24),
	BackgroundColor3 = Color3.fromRGB(8, 12, 22),
	BorderSizePixel = 0,
})
rounded(progressTrack, 8)
local progressFill = make("Frame", "Fill", progressTrack, {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(25, 201, 235),
	BorderSizePixel = 0,
})
rounded(progressFill, 8)
local progressText = make("TextLabel", "Progress", progressTrack, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "0 / 0",
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 13,
})
local questReward =
	detailText("Reward", UDim2.fromOffset(14, 184), UDim2.new(1, -28, 0, 48), 15, Color3.fromRGB(255, 214, 90))

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

local view = nil -- "Daily" or "Quests": which content the shared modal shows
local questCategory = "Daily"
local questRows = {}

local function layoutView()
	local camera = workspace.CurrentCamera
	local phone = camera and camera.ViewportSize.Y <= 500
	local quests = view == "Quests"
	questTabs.Visible = quests
	questDetail.Visible = quests and not phone
	if quests then
		content.Position = UDim2.fromOffset(14, 100)
		content.Size = phone and UDim2.new(1, -28, 1, -114) or UDim2.new(0.53, -18, 1, -114)
	else
		content.Position = UDim2.fromOffset(14, 52)
		content.Size = UDim2.new(1, -28, 1, -66)
	end
end

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutView)
end

local function refreshChrome()
	local camera = workspace.CurrentCamera
	local compact = camera and camera.ViewportSize.Y <= 500
	status.Visible = not compact and not PanelSwitch.AnyOpen()
end

PanelSwitch.OnChange(refreshChrome)
backdrop:GetPropertyChangedSignal("Visible"):Connect(refreshChrome)

local function clearContent()
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local fresh = Instance.new("UIListLayout")
	fresh.Padding = UDim.new(0, 8)
	fresh.Parent = content
end

local function showDaily()
	view = "Daily"
	if not backdrop.Visible then
		PanelSwitch.Toggle("Daily")
	end
	backdrop.Visible = true
	refreshChrome()
	layoutView()
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

local function selectQuest(quest, current, weekly)
	for id, refs in questRows do
		refs.Edge.Color = id == quest.Id and Color3.new(1, 1, 1) or Color3.fromRGB(25, 201, 235)
	end
	questType.Text = weekly and "WEEKLY QUEST" or "DAILY QUEST"
	questName.Text = quest.Name
	questGoal.Text = quest.Name
	progressFill.Size = UDim2.fromScale(math.clamp(current / math.max(1, quest.Target), 0, 1), 1)
	progressText.Text = string.format(
		"%d / %d  (%d%%)",
		current,
		quest.Target,
		math.floor(current / math.max(1, quest.Target) * 100 + 0.5)
	)
	questReward.Text = string.format("REWARD  •  %dx %s", quest.RewardCount or 1, quest.Reward)
end

local function showQuests()
	view = "Quests"
	if not backdrop.Visible then
		PanelSwitch.Toggle("Daily")
	end
	backdrop.Visible = true
	refreshChrome()
	layoutView()
	title.Text = "QUESTS"
	clearContent()
	questRows = {}
	dailyQuestTab.BackgroundColor3 = questCategory == "Daily" and Color3.fromRGB(205, 151, 19)
		or Color3.fromRGB(42, 54, 84)
	weeklyQuestTab.BackgroundColor3 = questCategory == "Weekly" and Color3.fromRGB(205, 151, 19)
		or Color3.fromRGB(42, 54, 84)
	local weekly = questCategory == "Weekly"
	local quests = weekly and questConfig.Weekly or questConfig.Daily
	local progress = decode(weekly and "QuestWeeklyProgress" or "QuestDailyProgress")
	local claimed = decode(weekly and "QuestWeeklyClaimed" or "QuestDailyClaimed")
	local selectedQuest, selectedCurrent = nil, 0
	for _, quest in quests do
		local current = math.min(quest.Target, progress[quest.Id] or 0)
		local done = claimed[quest.Id] == 1
		local row = button(quest.Id, content, UDim2.new(), UDim2.new(1, -8, 0, 72), "")
		row.AutoButtonColor = false
		rounded(row, 7)
		local rowEdge = Instance.new("UIStroke")
		rowEdge.Name = "Selection"
		rowEdge.Color = Color3.fromRGB(25, 201, 235)
		rowEdge.Thickness = 2
		rowEdge.Parent = row
		make("TextLabel", "Text", row, {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -124, 0, 24),
			BackgroundTransparency = 1,
			Text = quest.Name,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(255, 190, 42),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		make("TextLabel", "Progress", row, {
			Position = UDim2.fromOffset(12, 38),
			Size = UDim2.new(1, -124, 0, 20),
			BackgroundTransparency = 1,
			Text = string.format("%d / %d  •  %s", current, quest.Target, quest.Reward),
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(193, 205, 225),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local claim = button(
			"Claim",
			row,
			UDim2.new(1, -106, 0.5, -18),
			UDim2.fromOffset(96, 32),
			done and "CLAIMED" or current >= quest.Target and "CLAIM" or "LOCKED"
		)
		claim.Active = not done and current >= quest.Target
		claim.AutoButtonColor = claim.Active
		claim.BackgroundColor3 = claim.Active and Color3.fromRGB(70, 175, 105) or Color3.fromRGB(80, 88, 112)
		questRows[quest.Id] = { Button = row, Edge = rowEdge }
		if not selectedQuest then
			selectedQuest, selectedCurrent = quest, current
		end
		row.Activated:Connect(function()
			selectQuest(quest, current, weekly)
		end)
		claim.Activated:Connect(function()
			if not claim.Active then
				return
			end
			local ok, success, message = pcall(function()
				return ReplicatedStorage.Remotes.QuestClaim:InvokeServer(weekly, quest.Id)
			end)
			status.Text = ok and (success and ("Claimed " .. tostring(message)) or tostring(message))
				or "Connection error"
			showQuests()
		end)
	end
	if selectedQuest then
		selectQuest(selectedQuest, selectedCurrent, weekly)
	end
end

dailyQuestTab.Activated:Connect(function()
	questCategory = "Daily"
	showQuests()
end)
weeklyQuestTab.Activated:Connect(function()
	questCategory = "Weekly"
	showQuests()
end)

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
