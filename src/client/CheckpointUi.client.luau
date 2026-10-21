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
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))

local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))

-- Same vocabulary as the Backpack and Market (HUD_LAYOUT_SPEC section 3): dark body, navy tiles, blue glow
-- border, green border on the selected tile, Fredoka outlined text.
local OUTLINE = Color3.fromRGB(17, 19, 31)
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
local hint = caption("Hint", panel, {
	Position = UDim2.fromOffset(16, 70),
	Size = UDim2.new(1, -32, 0, 24),
	Text = "Pick the track your auto race starts on. Beat a track to unlock it.",
	TextColor3 = Color3.fromRGB(210, 200, 230),
})

local list = make("ScrollingFrame", "Cards", panel, {
	Position = UDim2.fromOffset(16, 102),
	Size = UDim2.new(1, -32, 1, -114),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
})
make("UIGridLayout", "Grid", list, {
	CellSize = UDim2.fromOffset(150, 150),
	CellPadding = UDim2.fromOffset(12, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
})

local chain = TrackRegistry.Chain()
local cards = {}
for _, spec in chain do
	local n = spec.Number
	local card = make("TextButton", "Track_" .. n, list, {
		LayoutOrder = n,
		BackgroundColor3 = CARD,
		Text = "",
		AutoButtonColor = true,
	})
	corner(card, 12)
	local edge = make("UIStroke", "Stroke", card, {
		Color = TILE_BLUE,
		Thickness = 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	caption(
		"Number",
		card,
		{ Position = UDim2.fromScale(0.05, 0.06), Size = UDim2.fromScale(0.9, 0.3), Text = "TRACK " .. n }
	)
	caption(
		"TrackName",
		card,
		{ Position = UDim2.fromScale(0.05, 0.38), Size = UDim2.fromScale(0.9, 0.18), Text = spec.Name }
	)
	caption("Cash", card, {
		Position = UDim2.fromScale(0.05, 0.57),
		Size = UDim2.fromScale(0.9, 0.15),
		Text = HudFormat.MoneyText(TrackBuilder.CashFor(n)),
		TextColor3 = Color3.fromRGB(120, 255, 140),
	})
	local state =
		caption("State", card, { Position = UDim2.fromScale(0.1, 0.76), Size = UDim2.fromScale(0.8, 0.18), Text = "" })
	local lock = make("Frame", "Lock", card, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		ZIndex = 3,
	})
	corner(lock, 12)
	caption(
		"Icon",
		lock,
		{ Position = UDim2.fromScale(0.3, 0.12), Size = UDim2.fromScale(0.4, 0.45), Text = "🔒", ZIndex = 4 }
	)
	caption("Need", lock, {
		Position = UDim2.fromScale(0.05, 0.62),
		Size = UDim2.fromScale(0.9, 0.18),
		Text = "Beat Track " .. n,
		ZIndex = 4,
	})
	card.Activated:Connect(function()
		if lock.Visible or player:GetAttribute("Checkpoint") == n then
			return
		end
		local ok, reason = remotes:WaitForChild("SetCheckpoint"):InvokeServer(n)
		if not ok then
			hint.Text = tostring(reason or "Try again")
		end
	end)
	cards[n] = { Card = card, Edge = edge, State = state, Lock = lock }
end

local function render()
	local best = player:GetAttribute("BestTrack")
	local current = CheckpointConfig.Effective(player:GetAttribute("Checkpoint"), best, #chain)
	for n, refs in cards do
		local open = CheckpointConfig.IsOpen(n, best, #chain)
		local selected = n == current
		refs.Lock.Visible = not open
		refs.State.Visible = open
		refs.Card.AutoButtonColor = open and not selected
		refs.Edge.Color = selected and SELECTED or TILE_BLUE
		refs.State.Text = selected and "SELECTED" or "SELECT"
		refs.State.TextColor3 = selected and SELECTED or Color3.new(1, 1, 1)
	end
end

close.Activated:Connect(function()
	PanelSwitch.Close("Checkpoints")
end)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		render()
	end
end)
player.AttributeChanged:Connect(function(attr)
	if attr == "Checkpoint" or attr == "BestTrack" then
		hint.Text = "Pick the track your auto race starts on. Beat a track to unlock it."
		render()
	end
end)

-- The hub NPC's prompt (built by Shared/SpawnArea on the server) toggles the panel.
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt.Name == "OpenCheckpoints" then
		PanelSwitch.Toggle("Checkpoints")
	end
end)
render()
