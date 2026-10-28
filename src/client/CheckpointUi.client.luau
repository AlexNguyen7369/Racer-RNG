--!nonstrict
-- Checkpoints panel (docs/CHECKPOINT_SPEC.md section 3): opened by the hub NPC's OpenCheckpoints prompt. One card
-- per track; Track 1 and beaten tracks can be picked, the others are dimmed with a lock. The server decides
-- (Remotes.SetCheckpoint); the cards only show the player attributes Checkpoint and BestTrack.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local CheckpointConfig = require(shared.CheckpointConfig)
local TrackRegistry = require(shared.TrackRegistry)
local TrackBuilder = require(shared.TrackBuilder)
local HudFormat = require(shared.HudFormat)
local UiTheme = require(shared.UiTheme)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RunService = game:GetService("RunService")
local BiomeDressing = require(shared.BiomeDressing)
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local BiomePreview = require(script.Parent:WaitForChild("BiomePreview"))

local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))

-- Same vocabulary as the Backpack and Market (HUD_LAYOUT_SPEC section 3): dark body, navy tiles, blue glow
-- border, green border on the selected tile, Fredoka outlined text.
local OUTLINE = UiTheme.Outline
local BODY = Color3.fromRGB(32, 27, 36)
local CARD = Color3.fromRGB(14, 24, 52)
local TILE_BLUE = Color3.fromRGB(47, 107, 255)
local SELECTED = Color3.fromRGB(60, 220, 90)

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function corner(parent, radius)
	make("UICorner", "Corner", parent, { CornerRadius = UDim.new(0, radius) })
end
local function caption(name, parent, props)
	props.BackgroundTransparency = 1
	props.Font = Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextScaled = props.TextScaled ~= false
	local label = make("TextLabel", name, parent, props)
	make("UIStroke", "Outline", label, { Color = OUTLINE, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round })
	return label
end

local root = make("ScreenGui", "CheckpointUi", gui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(720, 420),
	BackgroundColor3 = BODY,
	Visible = false,
	Active = true,
})
corner(panel, 16)
make("UIStroke", "Stroke", panel, { Color = OUTLINE, Thickness = 4 })
PanelSwitch.Register("Checkpoints", panel)

local close = PanelFrame.Attach(panel, { Theme = "Checkpoints", Title = "Checkpoints", MaxWidth = 760 }).Close
-- No HudIcons art for checkpoints: a finish flag glyph fills the header's icon slot.
caption("Flag", panel.Header.Icon, { Size = UDim2.fromScale(1, 1), Text = "🏁", ZIndex = 4 })
local HINT = "Click a track to see it; START HERE makes your auto race start there."
local hint = caption("Hint", panel, {
	Position = UDim2.fromOffset(16, 70),
	Size = UDim2.new(1, -32, 0, 24),
	Text = HINT,
	TextColor3 = Color3.fromRGB(210, 200, 230),
})

-- Section 4 (owner 2026-10-27): the card grid on the left, the detail pane of the shown track on the right.
local list = make("ScrollingFrame", "Cards", panel, {
	Position = UDim2.fromOffset(16, 102),
	Size = UDim2.new(0.58, -24, 1, -114),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
})
make("UIPadding", "Pad", list, { PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) })
local grid = make("UIGridLayout", "Grid", list, {
	CellSize = UDim2.new(1 / 3, -8, 0, 132),
	CellPadding = UDim2.fromOffset(10, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
})
list:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	local columns = list.AbsoluteSize.X < 330 and 2 or 3
	grid.CellSize = UDim2.new(1 / columns, -8, 0, columns == 2 and 120 or 132)
end)

local DETAIL_HOME = UDim2.new(1, -16, 0, 102)
local detail = make("Frame", "Detail", panel, {
	AnchorPoint = Vector2.new(1, 0),
	Position = DETAIL_HOME,
	Size = UDim2.new(0.42, -8, 1, -114),
})
UiTheme.Plate(detail, TILE_BLUE)
detail.BackgroundTransparency = 0
local detailPreview = make("ViewportFrame", "Preview", detail, {
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.new(1, -20, 0.38, 0),
	BorderSizePixel = 0,
})
corner(detailPreview, UiTheme.Radius.S)
local function row(name, y, h, color)
	return caption(name, detail, {
		Position = UDim2.new(0, 12, y, 0),
		Size = UDim2.new(1, -24, h, 0),
		Text = "",
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end
local title = row("Title", 0.41, 0.08)
local biomeLabel = row("Biome", 0.49, 0.06, Color3.fromRGB(170, 190, 255))
local recSpeed = row("RecSpeed", 0.57, 0.07, UiTheme.Palette.Speed)
local yourSpeed = row("YourSpeed", 0.645, 0.06)
local status = caption("Status", detail, {
	Position = UDim2.new(0, 12, 0.715, 0),
	Size = UDim2.fromScale(0.62, 0.065),
	Text = "",
})
status.BackgroundTransparency = 0 -- caption() makes labels transparent; this one is a chip
corner(status, 999)
make("UIPadding", "Pad", status, { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
local cash = row("Cash", 0.79, 0.06, Color3.fromRGB(120, 255, 140))
local start = make("TextButton", "Start", detail, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.new(1, -24, 0.11, 0),
	Text = "START HERE",
	Font = UiTheme.Font,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = SELECTED,
	AutoButtonColor = true,
})
corner(start, UiTheme.Radius.S)
UiTheme.Stroke(start, 2)
make("UIPadding", "Pad", start, { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) })

local chain = TrackRegistry.Chain()
local cards = {}
local shown -- track number in the detail pane
local turnDetail
local showTrack

for _, spec in chain do
	local n = spec.Number
	local card = make("TextButton", "Track_" .. n, list, {
		LayoutOrder = n,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = true,
	})
	corner(card, UiTheme.Radius.M)
	-- Subtle navy gradient (Backpack tiles); the white background lets the gradient set the colour.
	UiTheme.Gradient(card, UiTheme.Palette.Row, CARD)
	local edge = make("UIStroke", "Stroke", card, {
		Color = TILE_BLUE,
		Thickness = 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	local preview = make("ViewportFrame", "Preview", card, {
		Position = UDim2.fromScale(0.06, 0.05),
		Size = UDim2.fromScale(0.88, 0.56),
		BorderSizePixel = 0,
	})
	corner(preview, UiTheme.Radius.S)
	caption(
		"Number",
		card,
		{ Position = UDim2.fromScale(0.05, 0.63), Size = UDim2.fromScale(0.9, 0.19), Text = "TRACK " .. n }
	)
	caption("Biome", card, {
		Position = UDim2.fromScale(0.05, 0.81),
		Size = UDim2.fromScale(0.9, 0.14),
		Text = BiomeDressing.Title(spec.Biome or ""),
		TextColor3 = Color3.fromRGB(170, 190, 255),
	})
	local lock = make("Frame", "Lock", card, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		ZIndex = 3,
	})
	corner(lock, UiTheme.Radius.M)
	caption(
		"Icon",
		lock,
		{ Position = UDim2.fromScale(0.3, 0.1), Size = UDim2.fromScale(0.4, 0.4), Text = "🔒", ZIndex = 4 }
	)
	caption("Need", lock, {
		Position = UDim2.fromScale(0.05, 0.5),
		Size = UDim2.fromScale(0.9, 0.15),
		Text = "Beat Track " .. n,
		ZIndex = 4,
	})
	card.Activated:Connect(function()
		showTrack(n)
	end)
	cards[n] = { Card = card, Edge = edge, Lock = lock, Preview = preview, Spec = spec }
end

-- Previews are built on the first open, once the server's TrackPreviews bake has replicated.
local function buildPreviews()
	for _, refs in cards do
		if not refs.Turn then
			refs.Turn = BiomePreview.FromTrack(refs.Preview, refs.Spec.Name, refs.Spec.Biome)
		end
	end
end

local function speedStat()
	local stats = player:FindFirstChild("leaderstats")
	local speed = stats and stats:FindFirstChild("Speed")
	return speed and speed.Value or 0
end

local function render()
	local best = player:GetAttribute("BestTrack")
	local current = CheckpointConfig.Effective(player:GetAttribute("Checkpoint"), best, #chain)
	for n, refs in cards do
		local open = CheckpointConfig.IsOpen(n, best, #chain)
		refs.Lock.Visible = not open
		refs.Card.AutoButtonColor = n ~= shown
		refs.Edge.Color = n == current and SELECTED or (n == shown and Color3.new(1, 1, 1) or TILE_BLUE)
	end
	local refs = shown and cards[shown]
	if not refs then
		return
	end
	local open = CheckpointConfig.IsOpen(shown, best, #chain)
	local rec, speed = BiomeDressing.RecSpeed(shown), speedStat()
	title.Text = string.format("TRACK %d · %s", shown, string.upper(refs.Spec.Name or ""))
	biomeLabel.Text = BiomeDressing.Title(refs.Spec.Biome or "")
	recSpeed.Text = "REC. SPEED " .. HudFormat.SpeedText(rec)
	yourSpeed.Text = "YOUR SPEED " .. HudFormat.SpeedText(speed)
	local ready = speed >= rec
	status.Text = ready and "READY" or ("NEED " .. HudFormat.SpeedText(rec - speed) .. " MORE")
	status.BackgroundColor3 = ready and UiTheme.Palette.MoneyDeep or UiTheme.Palette.DangerDeep
	cash.Text = "PAYOUT " .. HudFormat.MoneyText(TrackBuilder.CashFor(shown))
	local selected = shown == current
	start.Text = selected and "SELECTED" or (open and "START HERE" or "LOCKED")
	start.Active = open and not selected
	start.AutoButtonColor = start.Active
	start.BackgroundColor3 = start.Active and SELECTED or UiTheme.Palette.Muted
end

function showTrack(n)
	local changed = shown ~= n
	shown = n
	if changed then
		turnDetail = BiomePreview.FromTrack(detailPreview, cards[n].Spec.Name, cards[n].Spec.Biome)
		detail.Position = DETAIL_HOME -- a click mid-slide must not move the pane's home
		UiMotion.SlideIn(detail, Vector2.new(16, 0), 0.2)
	end
	render()
end

start.Activated:Connect(function()
	if not start.Active or not shown then
		return
	end
	local ok, reason = remotes:WaitForChild("SetCheckpoint"):InvokeServer(shown)
	if not ok then
		hint.Text = tostring(reason or "Try again")
	end
end)

-- The shown track's previews turn slowly while the panel is open (not while motion is reduced).
local angle = math.rad(35)
RunService.RenderStepped:Connect(function(dt)
	if not panel.Visible or UiMotion.Reduced() or not shown then
		return
	end
	angle += dt * 0.35
	turnDetail(angle)
	if cards[shown].Turn then
		cards[shown].Turn(angle)
	end
end)

close.Activated:Connect(function()
	PanelSwitch.Close("Checkpoints")
end)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		buildPreviews()
		showTrack(
			CheckpointConfig.Effective(player:GetAttribute("Checkpoint"), player:GetAttribute("BestTrack"), #chain)
		)
	end
end)
task.spawn(function()
	player:WaitForChild("leaderstats"):WaitForChild("Speed").Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)
end)
player.AttributeChanged:Connect(function(attr)
	if attr == "Checkpoint" or attr == "BestTrack" then
		hint.Text = HINT
		render()
	end
end)

-- The hub NPC's prompt (built by Shared/SpawnArea on the server) toggles the panel.
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt.Name == "OpenCheckpoints" then
		PanelSwitch.Toggle("Checkpoints")
	end
end)
UiTheme.Apply(root)
render()
