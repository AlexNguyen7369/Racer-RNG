--!nonstrict
-- Bag and seven-day daily reward presentation. Server remotes own all grants.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local boosts = require(ReplicatedStorage.Shared.BoostConfig)
local dailyConfig = require(ReplicatedStorage.Shared.DailyLoginConfig)

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

local bagButton = button("BagButton", screen, UDim2.new(1, -16, 0, 64), UDim2.fromOffset(112, 36), "BAG")
bagButton.AnchorPoint = Vector2.new(1, 0)
local dailyButton =
	button("DailyRewardButton", screen, UDim2.new(1, -16, 0, 106), UDim2.fromOffset(176, 36), "DAILY REWARDS")
dailyButton.AnchorPoint = Vector2.new(1, 0)

local backdrop = make("Frame", "ModalBackdrop", screen, {
	Position = UDim2.fromScale(0, 0),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	Visible = false,
})
local modal = make("Frame", "Modal", backdrop, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.86, 0.76),
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
	Text = "BAG",
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
	Position = UDim2.new(1, -300, 0, 146),
	Size = UDim2.fromOffset(284, 42),
	BackgroundTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "",
})

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

local function remainingToday()
	return 86400 - (os.time() % 86400)
end

local function formatTime(seconds)
	return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function showBag()
	backdrop.Visible = true
	title.Text = "BAG • CONSUMABLES"
	clearContent()
	for _, category in ipairs(boosts.Order) do
		make("TextLabel", category .. "Heading", content, {
			Size = UDim2.new(1, -8, 0, 26),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(140, 210, 255),
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = category .. " POTIONS",
		})
		for _, item in ipairs(boosts.ItemsFor(category)) do
			local count = player:GetAttribute("Boost_" .. item.Id) or 0
			local untilAt = player:GetAttribute("BoostUntil_" .. item.Id) or 0
			if count > 0 or untilAt > os.time() then
				local row = make("Frame", item.Id, content, {
					Size = UDim2.new(1, -8, 0, 58),
					BackgroundColor3 = Color3.fromRGB(42, 54, 84),
				})
				rounded(row, 8)
				make("TextLabel", "Label", row, {
					Position = UDim2.fromOffset(10, 5),
					Size = UDim2.new(1, -150, 1, -10),
					BackgroundTransparency = 1,
					TextColor3 = Color3.new(1, 1, 1),
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = item.Name
						.. "  •  x"
						.. tostring(count)
						.. "\n"
						.. tostring(item.Multiplier)
						.. "x for 60 seconds",
				})
				local readyToUse = count > 0 and untilAt <= os.time()
				local action = button(
					"Use",
					row,
					UDim2.new(1, -126, 0.5, -18),
					UDim2.fromOffset(116, 36),
					untilAt > os.time() and ("ACTIVE " .. formatTime(untilAt - os.time())) or "USE"
				)
				action.Active = readyToUse
				action.AutoButtonColor = action.Active
				action.BackgroundColor3 = action.Active and Color3.fromRGB(74, 172, 105) or Color3.fromRGB(70, 75, 95)
				action.Activated:Connect(function()
					if not action.Active then
						return
					end
					local ok, used, message = pcall(function()
						return ReplicatedStorage.Remotes:WaitForChild("UseBoost"):InvokeServer(item.Id)
					end)
					status.Text = ok and (used and (item.Name .. " active for 60 seconds") or tostring(message))
						or "Connection error"
					showBag()
				end)
			end
		end
	end
end

local function showDaily()
	backdrop.Visible = true
	title.Text = "DAILY REWARDS • 7 DAYS"
	clearContent()
	local streak = math.clamp(player:GetAttribute("DailyStreak") or 0, 0, 7)
	local last = player:GetAttribute("DailyLast") or -1
	local claimedToday = last == math.floor(os.time() / 86400)
	for day, reward in ipairs(dailyConfig.Rewards) do
		local details = "+$" .. tostring(reward.Money)
		if reward.Boost then
			details ..= "  •  " .. reward.Boost .. " Potion I"
		end
		if reward.GuaranteedRare then
			details ..= "  •  Guaranteed rare car"
		end
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
			status.Text = "Claimed Day " .. tostring(reward.Day) .. " • +$" .. tostring(reward.Money)
			showDaily()
		else
			status.Text = ok and tostring(reward) or "Connection error"
		end
	end)
end

bagButton.Activated:Connect(showBag)
dailyButton.Activated:Connect(showDaily)
close.Activated:Connect(function()
	backdrop.Visible = false
end)

local function refreshButtons()
	local last = player:GetAttribute("DailyLast") or -1
	local today = math.floor(os.time() / 86400)
	if last == today then
		dailyButton.Text = "NEXT DAILY  " .. formatTime(remainingToday())
	else
		dailyButton.Text = "DAILY REWARDS  •  CLAIM"
	end
	if backdrop.Visible and title.Text:find("BAG", 1, true) then
		showBag()
	end
end

refreshButtons()
task.spawn(function()
	while screen.Parent do
		task.wait(1)
		local last = player:GetAttribute("DailyLast") or -1
		local ready = last ~= math.floor(os.time() / 86400)
		if ready and not backdrop.Visible then
			showDaily()
		end
		refreshButtons()
	end
end)
