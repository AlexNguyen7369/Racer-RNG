--!nonstrict
-- Market browser: category folders on the left and a projected visual preview for every item.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Market = require(shared:WaitForChild("MarketConfig"))
local Format = require(shared:WaitForChild("HudFormat"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local root = make(
	"ScreenGui",
	"MarketUi",
	gui,
	{ ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 8, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }
)
local openButton = make("TextButton", "MarketButton", root, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0.32, 0),
	Size = UDim2.fromOffset(124, 44),
	Text = "MARKET",
	Font = Enum.Font.GothamBlack,
	TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 170, 45),
})
make("UICorner", "Corner", openButton, { CornerRadius = UDim.new(0, 9) })
local backdrop = make("TextButton", "Backdrop", root, {
	Size = UDim2.fromScale(1, 1),
	Text = "",
	BackgroundColor3 = Color3.fromRGB(8, 10, 22),
	BackgroundTransparency = 0.35,
	Visible = false,
	AutoButtonColor = false,
})
local panel = make("Frame", "Panel", backdrop, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.84, 0.72),
	BackgroundColor3 = Color3.fromRGB(29, 32, 53),
	Active = true,
})
make("UICorner", "Corner", panel, { CornerRadius = UDim.new(0, 16) })
make("TextLabel", "Title", panel, {
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(1, -76, 0, 34),
	Text = "MARKET",
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local close = make("TextButton", "Close", panel, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 8),
	Size = UDim2.fromOffset(38, 30),
	Text = "×",
	Font = Enum.Font.GothamBold,
	TextSize = 24,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = Color3.fromRGB(210, 70, 90),
})
make("UICorner", "Corner", close, { CornerRadius = UDim.new(0, 7) })
local status = make("TextLabel", "Status", panel, {
	Position = UDim2.fromOffset(18, 47),
	Size = UDim2.new(1, -36, 0, 22),
	Text = "Choose a folder to browse projected effects.",
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(190, 205, 225),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local folders = make("Frame", "Folders", panel, {
	Position = UDim2.fromOffset(14, 78),
	Size = UDim2.new(0, 132, 1, -92),
	BackgroundColor3 = Color3.fromRGB(21, 24, 42),
})
make("UICorner", "Corner", folders, { CornerRadius = UDim.new(0, 10) })
make("TextLabel", "FolderTitle", folders, {
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.new(1, -24, 0, 38),
	Text = "FUEL TYPE",
	Font = Enum.Font.GothamBlack,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(255, 196, 75),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local list = make("ScrollingFrame", "Items", panel, {
	Position = UDim2.fromOffset(158, 78),
	Size = UDim2.new(1, -172, 1, -92),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	BorderSizePixel = 0,
})
local layout = make("UIListLayout", "Layout", list, { Padding = UDim.new(0, 9) })
local selectedKind = "Trail"
local refresh

local function owned(kind, id)
	return player:GetAttribute("Own" .. kind .. "_" .. id) == true
end

local function folderButton(kind, label, y)
	local button = make("TextButton", kind .. "Folder", folders, {
		Position = UDim2.fromOffset(8, y),
		Size = UDim2.new(1, -16, 0, 46),
		Text = label,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(42, 47, 72),
		AutoButtonColor = true,
	})
	make("UICorner", "Corner", button, { CornerRadius = UDim.new(0, 8) })
	button.Activated:Connect(function()
		selectedKind = kind
		for _, child in folders:GetChildren() do
			if child:IsA("TextButton") then
				child.BackgroundColor3 = child.Name == kind .. "Folder" and Color3.fromRGB(82, 108, 180)
					or Color3.fromRGB(42, 47, 72)
			end
		end
		status.Text = kind == "Trail" and "Trails leave a visible wake behind your car."
			or "Auras surround your car with light and sparks."
		refresh()
	end)
	return button
end
folderButton("Trail", "TRAILS", 55)
folderButton("Aura", "AURA", 108)

local function preview(parent, item, kind)
	local viewport = make("ViewportFrame", "Preview", parent, {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(86, 68),
		BackgroundColor3 = Color3.fromRGB(12, 15, 30),
		BackgroundTransparency = 0.15,
		Ambient = Color3.fromRGB(130, 140, 190),
		LightColor = Color3.new(1, 1, 1),
	})
	make("UICorner", "Corner", viewport, { CornerRadius = UDim.new(0, 8) })
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(0, 2.2, 8) * CFrame.Angles(math.rad(-8), 0, 0)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local body = Instance.new("Part")
	body.Anchored = true
	body.Size = Vector3.new(4.8, 0.8, 2.5)
	body.Position = Vector3.new(0, 1.2, 0)
	body.Color = Color3.fromRGB(77, 151, 205)
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = world
	if kind == "Aura" then
		local orb = Instance.new("Part")
		orb.Anchored = true
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(4.8, 2.6, 3.4)
		orb.Position = Vector3.new(0, 1.8, 0)
		orb.Color = item.Color
		orb.Material = Enum.Material.Neon
		orb.Transparency = 0.42
		orb.Parent = world
		local ring = Instance.new("Part")
		ring.Anchored = true
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.12, 5.2, 5.2)
		ring.CFrame = CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90))
		ring.Color = item.Accent or item.Color
		ring.Material = Enum.Material.Neon
		ring.Parent = world
	else
		for index = 1, 4 do
			local spark = Instance.new("Part")
			spark.Anchored = true
			spark.Shape = Enum.PartType.Ball
			spark.Size = Vector3.new(0.35, 0.35, 0.35)
			spark.Position = Vector3.new(0, 0.75, index * 1.15)
			spark.Color = index % 2 == 0 and (item.Accent or item.Color) or item.Color
			spark.Material = Enum.Material.Neon
			spark.Parent = world
		end
	end
end

refresh = function()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, item in Market.Items[selectedKind] do
		local card = make(
			"Frame",
			selectedKind .. item.Id,
			list,
			{ Size = UDim2.new(1, -8, 0, 124), BackgroundColor3 = Color3.fromRGB(49, 55, 78) }
		)
		make("UICorner", "Corner", card, { CornerRadius = UDim.new(0, 10) })
		preview(card, item, selectedKind)
		make("TextLabel", "Info", card, {
			Position = UDim2.fromOffset(106, 10),
			Size = UDim2.new(1, -116, 0, 28),
			Text = item.Name,
			Font = Enum.Font.GothamBlack,
			TextSize = 16,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		make("TextLabel", "Description", card, {
			Position = UDim2.fromOffset(106, 40),
			Size = UDim2.new(1, -116, 0, 42),
			Text = item.Description
				.. "\n"
				.. Format.MoneyText(item.Price)
				.. "  •  x"
				.. item.SpeedMulti
				.. " speed",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(193, 205, 225),
			BackgroundTransparency = 1,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local button = make("TextButton", "Action", card, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -10),
			Size = UDim2.fromOffset(100, 32),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = Color3.fromRGB(70, 175, 105),
		})
		make("UICorner", "Corner", button, { CornerRadius = UDim.new(0, 7) })
		local isOwned = owned(selectedKind, item.Id)
		local equipped = player:GetAttribute("Equipped" .. selectedKind) == item.Id
		button.Text = equipped and "EQUIPPED" or isOwned and "EQUIP" or "BUY"
		button.BackgroundColor3 = equipped and Color3.fromRGB(55, 110, 180) or Color3.fromRGB(70, 175, 105)
		button.Activated:Connect(function()
			button.Active = false
			local ok, message
			if isOwned then
				ok, message = remotes.MarketEquip:InvokeServer(selectedKind, item.Id)
			else
				ok, message = remotes.MarketPurchase:InvokeServer(selectedKind, item.Id)
			end
			status.Text = tostring(message or (ok and "Done" or "Try again"))
			status.TextColor3 = ok and Color3.fromRGB(100, 235, 140) or Color3.fromRGB(255, 100, 120)
			task.wait(0.15)
			refresh()
		end)
	end
	list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
end

local function open()
	refresh()
	backdrop.Visible = true
end
local function closeMarket()
	backdrop.Visible = false
end
openButton.Activated:Connect(open)
close.Activated:Connect(closeMarket)
backdrop.Activated:Connect(closeMarket)
remotes:WaitForChild("MarketOpen").OnClientEvent:Connect(open)
player:GetAttributeChangedSignal("EquippedAura"):Connect(refresh)
player:GetAttributeChangedSignal("EquippedTrail"):Connect(refresh)
