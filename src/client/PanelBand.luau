--!nonstrict
-- The band every hand-built panel opens in (docs/HUD_LAYOUT_SPEC.md section 6): below the Race button, above the
-- TURBO LUCK bar, and between the left icon grid and the right Shop column, so a panel never covers a HUD entry.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui")

local Band = {}
local GAP = 8

-- left, top, right, bottom in IgnoreGuiInset screen offsets, or nil before the HUD exists.
function Band.Rect()
	local camera = workspace.CurrentCamera
	local hud = gui:FindFirstChild("RacerHud")
	local chrome = gui:FindFirstChild("HudChrome")
	local race = hud and hud:FindFirstChild("Race")
	local turbo = hud and hud:FindFirstChild("Turbo")
	local grid = chrome and chrome:FindFirstChild("Grid")
	local shop = chrome and chrome:FindFirstChild("ShopColumn")
	if not (camera and race and turbo and grid and shop) then
		return nil
	end
	-- AbsolutePosition starts below the top bar; the HUD ScreenGuis ignore the inset, so add it back.
	local inset = GuiService:GetGuiInset().Y
	local viewport = camera.ViewportSize
	-- The grid's right edge includes what sticks out of it (the Stats badge).
	local gridRight = grid.AbsolutePosition.X + grid.AbsoluteSize.X
	for _, child in grid:GetDescendants() do
		if child:IsA("GuiObject") and child.Visible then
			gridRight = math.max(gridRight, child.AbsolutePosition.X + child.AbsoluteSize.X)
		end
	end
	-- Both edges use the wider margin so the panel stays centred.
	local margin = math.max(gridRight, viewport.X - shop.AbsolutePosition.X) + GAP
	local right = viewport.X - margin
	local raceMap = hud:FindFirstChild("RaceMap")
	if raceMap and raceMap.Visible and hud.Enabled then
		right = math.min(right, raceMap.AbsolutePosition.X - GAP)
	end
	-- The bottom stops above the TURBO LUCK bar and above the Money readout in the bottom-left corner.
	local bottom = turbo.AbsolutePosition.Y
	local money = hud:FindFirstChild("Money")
	if
		money
		and money:IsA("GuiObject")
		and money.Visible
		and money.AbsolutePosition.X + money.AbsoluteSize.X > margin
	then
		bottom = math.min(bottom, money.AbsolutePosition.Y)
	end
	return margin, race.AbsolutePosition.Y + race.AbsoluteSize.Y + inset + GAP, right, bottom + inset - GAP
end

local function shown(object)
	while object and object:IsA("GuiObject") do
		if not object.Visible then
			return false
		end
		object = object.Parent
	end
	return true
end

-- Keeps `panel` centred in the band while it is shown, at most maxWidth wide.
function Band.Fit(panel, maxWidth)
	RunService.Heartbeat:Connect(function()
		if not shown(panel) then
			return
		end
		local left, top, right, bottom = Band.Rect()
		if not left then
			return
		end
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromOffset((left + right) / 2, (top + bottom) / 2)
		panel.Size = UDim2.fromOffset(math.max(240, math.min(maxWidth, right - left)), math.max(160, bottom - top))
	end)
end

return Band
