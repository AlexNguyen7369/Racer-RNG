--!nonstrict
-- The HUD speedometer (docs/HUD_LAYOUT_SPEC.md section 9), drawn into the generated `SpeedDial` spacer. The needle
-- and arc show the car's real speed in studs/s; presentation only, the Speed stat beside it stays the number.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaceConfig = require(Shared.RaceConfig)
local UiTheme = require(Shared.UiTheme)

local SpeedDial = {}

local START_DEG, SWEEP_DEG = 135, 270 -- clockwise from +X (screen y points down): bottom left round to bottom right
local RADIUS = 0.4 -- arc radius, share of the dial's size
local ARC_POINTS = 28
local NEEDLE_RATE = 10 -- 1/s: how fast the needle chases the speed
local REDRAW_STEP = 0.005 -- redraw the arc fill only when it moved this much

local LOW, MID, HIGH = Color3.fromRGB(80, 230, 255), UiTheme.Palette.Speed, UiTheme.Palette.SpeedDeep

-- Full scale in studs/s for this stat (section 9; placeholder): a little above the current cruise speed.
function SpeedDial.Scale(stat)
	return math.max(RaceConfig.SpeedFor(stat) * 1.25, RaceConfig.BASE_SPEED * 2)
end

local function point(fraction)
	local a = math.rad(START_DEG + SWEEP_DEG * fraction)
	return Path2DControlPoint.new(UDim2.fromScale(0.5 + RADIUS * math.cos(a), 0.5 + RADIUS * math.sin(a)))
end

local function arc(fraction)
	local points = {}
	local count = math.max(2, math.ceil(ARC_POINTS * fraction))
	for i = 0, count - 1 do
		table.insert(points, point(fraction * i / (count - 1)))
	end
	return points
end

local function path(parent, name, color, thickness, z)
	local line = Instance.new("Path2D")
	line.Name = name
	line.Color3 = color
	line.Thickness = thickness
	line.ZIndex = z
	line.Parent = parent
	return line
end

local function colorAt(fraction)
	return fraction < 0.5 and LOW:Lerp(MID, fraction * 2) or MID:Lerp(HIGH, (fraction - 0.5) * 2)
end

-- Builds the dial into `frame` (the SpeedDial spacer). Returns an object with Update(dt, speed, stat).
function SpeedDial.Attach(frame)
	frame:ClearAllChildren()
	frame.Active = false

	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(0.96, 0.96)
	disc.BackgroundColor3 = Color3.new(1, 1, 1)
	disc.BackgroundTransparency = 0.1
	disc.ZIndex = 1
	disc.Parent = frame
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = disc
	UiTheme.Gradient(disc, UiTheme.Palette.Panel, UiTheme.Palette.PanelDeep)
	local rim = UiTheme.Stroke(disc, 3, UiTheme.Outline, true)

	local track = path(frame, "Track", Color3.fromRGB(58, 70, 104), 7, 2)
	track:SetControlPoints(arc(1))
	local fill = path(frame, "Fill", LOW, 7, 2)
	fill.Visible = false

	for i = 0, 8 do
		local f = i / 8
		local a = math.rad(START_DEG + SWEEP_DEG * f)
		local tick = Instance.new("Frame")
		tick.Name = "Tick"
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(0.5 + 0.29 * math.cos(a), 0.5 + 0.29 * math.sin(a))
		tick.Size = UDim2.fromOffset(i % 2 == 0 and 7 or 4, 2)
		tick.Rotation = START_DEG + SWEEP_DEG * f
		tick.BackgroundColor3 = Color3.new(1, 1, 1)
		tick.BackgroundTransparency = i % 2 == 0 and 0.15 or 0.5
		tick.BorderSizePixel = 0
		tick.ZIndex = 2
		tick.Parent = frame
	end

	-- A full-size frame turned about the dial's centre; its bar points along +X at Rotation 0.
	local needle = Instance.new("Frame")
	needle.Name = "Needle"
	needle.Size = UDim2.fromScale(1, 1)
	needle.BackgroundTransparency = 1
	needle.Rotation = START_DEG
	needle.ZIndex = 2
	needle:SetAttribute("DialValue", 0)
	needle.Parent = frame
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.Size = UDim2.new(0.42, 0, 0, 4)
	bar.BackgroundColor3 = UiTheme.Palette.Danger
	bar.BorderSizePixel = 0
	bar.ZIndex = 2
	bar.Parent = needle
	UiTheme.Corner(bar, 2)
	UiTheme.Stroke(bar, 1, UiTheme.Outline, true)

	local readout = Instance.new("TextLabel")
	readout.Name = "DialSpeed"
	readout.AnchorPoint = Vector2.new(0.5, 0.5)
	readout.Position = UDim2.fromScale(0.5, 0.8)
	readout.Size = UDim2.fromScale(0.6, 0.2)
	readout.BackgroundTransparency = 1
	readout.Font = UiTheme.Font
	readout.TextScaled = true
	readout.TextColor3 = Color3.new(1, 1, 1)
	readout.Text = "0"
	readout.ZIndex = 4
	readout.Parent = frame
	UiTheme.Stroke(readout, 1.5)

	local shown, drawn = 0, -1
	local dial = { Frame = frame, Needle = needle, Rim = rim }

	-- `speed` is the car's real speed (0 on foot), `stat` the Speed stat for the scale.
	function dial.Update(dt, speed, stat)
		speed = (type(speed) == "number" and speed == speed and speed > 0) and speed or 0
		shown += (speed - shown) * (1 - math.exp(-NEEDLE_RATE * math.max(dt, 0)))
		if speed == 0 and shown < 0.05 then
			shown = 0
		end
		local fraction = math.clamp(shown / SpeedDial.Scale(stat), 0, 1)
		needle.Rotation = START_DEG + SWEEP_DEG * fraction
		needle:SetAttribute("DialValue", speed)
		-- On foot / without a car the number reads 0 at once (HUD spec section 9); only the needle glides back.
		readout.Text = speed > 0 and tostring(math.floor(shown + 0.5)) or "0"
		track.Color3 = speed > 0 and Color3.fromRGB(58, 70, 104) or Color3.fromRGB(44, 50, 70)
		if math.abs(fraction - drawn) >= REDRAW_STEP then
			drawn = fraction
			fill.Visible = fraction > 0.01
			if fill.Visible then
				fill:SetControlPoints(arc(fraction))
				fill.Color3 = colorAt(fraction)
			end
		end
	end

	return dial
end

return SpeedDial
