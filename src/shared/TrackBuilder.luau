--!nonstrict
-- Turns a track spec (see src/shared/Tracks/*.luau) into geometry.
--
-- Layout(spec)  pure maths: pieces, centreline waypoints, curvature, end pose. No instances.
-- Build(spec, origin)  Layout + Parts (road, walls, start line, checkpoint + win pad, grass) under a Model.
-- EndCFrame(layout, origin)  world pose of the finish; the next track is built from it.
--
-- Segment types:
--   { Type = "Straight", Length }                  flat run at the current height
--   { Type = "Turn", Angle, Radius }               flat corner; Angle > 0 left, < 0 right
--   { Type = "Slope", Length, Rise }               smooth (cosine) climb or drop: Length is the horizontal
--                                                  run, Rise the height change (negative = descend). Both ends
--                                                  are level, so a hill is a +Rise slope followed by a -Rise one.
--   { Type = "Loop", Radius, Shift?, Direction? }  vertical loop-the-loop. The road climbs a circle of Radius,
--                                                  goes upside down and comes back down, drifting sideways by
--                                                  Shift (default width + 10) toward Direction ("Left" default,
--                                                  or "Right") so the two lanes miss each other. Loop pieces are
--                                                  tagged LoopAssist, which CarPhysics uses to cancel gravity.
--
-- Heading convention: 0 = facing -Z (Roblox forward), positive = turning left. Height is Y.

local CollectionService = game:GetService("CollectionService")

local TrackBuilder = {}

TrackBuilder.TRACK_LIFT = 1 -- studs the chain sits above the baseplate so road never blends into it
TrackBuilder.CASH_PER_TRACK = 100 -- $ the winnings pad pays per track number (track 3 pays 3x)
TrackBuilder.WIN_TEXT_DISTANCE = 60 -- studs: the $ text only shows when the player is this close
TrackBuilder.LANE_OFFSET = 10 -- studs to the RIGHT of the road centre the car drives (a right-hand lane)
TrackBuilder.CHECKPOINT_LENGTH = 60 -- studs of the last straight that make up the checkpoint area
TrackBuilder.CHECKPOINT_APRON = 30 -- studs of apron on each side of the road at the checkpoint
TrackBuilder.PAD_LEFT_OFFSET = 24 -- studs the winnings pad sits to the left of the road centre line

local DEFAULT_WIDTH = 36
local TURN_STEP_DEG = 6
local LOOP_STEP_DEG = 5
local SLOPE_STEP = 8
local WAYPOINT_SPACING = 12
local ROAD_THICKNESS = 2
local WALL_HEIGHT = 5
local WALL_THICKNESS = 2
local WALL_GAP = 0.5 -- clear space between the last wall and the checkpoint apron
local GROUND_TOP = -1
local SUPPORT_CLEARANCE = 0.05 -- keep a horizontal support just below the lowest sloped road underside

local COLORS = {
	Road = Color3.fromRGB(120, 130, 150),
	Support = Color3.fromRGB(78, 87, 112),
	Wall = Color3.fromRGB(232, 240, 250),
	Ground = Color3.fromRGB(150, 220, 160),
	Line = Color3.fromRGB(255, 255, 255),
	Checkpoint = Color3.fromRGB(170, 180, 205),
	WinPad = Color3.fromRGB(255, 220, 40), -- yellow; easy to swap later
}

local function colorsFor(spec)
	local colors = table.clone(COLORS)
	for name, color in (spec.Palette or {}) do
		colors[name] = color
	end
	return colors
end

local CHECKPOINT_LENGTH = TrackBuilder.CHECKPOINT_LENGTH
local CHECKPOINT_APRON = TrackBuilder.CHECKPOINT_APRON
local PAD_LEFT_OFFSET = TrackBuilder.PAD_LEFT_OFFSET
local PAD_SIZE = 10
local PAD_BEHIND_FINISH = CHECKPOINT_LENGTH / 2 -- pad centre, studs back from the finish pose (the swing peaks here)
local FINISH_LINE_BEHIND = 6
local AREA_TOP = 0.05 -- checkpoint area top above the road top: no z-fighting, no bump the suspension can feel

local function fwdVec(h)
	return Vector3.new(-math.sin(h), 0, -math.cos(h))
end

local function leftVec(h)
	return Vector3.new(-math.cos(h), 0, math.sin(h))
end

local function flatPiece(center, heading, length)
	return {
		Center = center,
		Heading = heading,
		Length = length,
		CFrame = CFrame.new(center) * CFrame.Angles(0, heading, 0),
		Support = true,
	}
end

-- Money the winnings pad pays: the track number scales the quantity.
function TrackBuilder.CashFor(number)
	return (number or 1) * TrackBuilder.CASH_PER_TRACK
end

-- World CFrame of a layout's finish (facing along the last straight). The next track is built with
-- this as its origin, so its Start sits exactly on this finish.
function TrackBuilder.EndCFrame(layout, origin)
	origin = origin or CFrame.new()
	return origin * CFrame.new(layout.EndPosition) * CFrame.Angles(0, layout.EndHeading, 0)
end

-- The line the auto-racing car follows: the road centre line shifted LANE_OFFSET studs to the RIGHT, so the car
-- drives in a right-hand lane, not dead centre. The winnings pad sits beside the road on the left apron, so the
-- path never goes near it; PadIndex is the waypoint abeam of the pad and the car collects when it passes it.
-- Curvature is adjusted for the shifted radius (right lane: outside of a left bend, inside of a right bend).
-- offset (optional, signed, default LANE_OFFSET): studs to the right; the NPC racer passes -LANE_OFFSET (left lane).
-- Returns local-space { Waypoints, Curvature, PadIndex }.
function TrackBuilder.RacePath(layout, offset)
	offset = offset or TrackBuilder.LANE_OFFSET
	local wps, curv = layout.Waypoints, layout.Curvature
	local n = #wps
	local waypoints, curvature = table.create(n), table.create(n)
	local lastRight = Vector3.new(1, 0, 0)
	for i = 1, n do
		local t = wps[math.min(i + 1, n)] - wps[math.max(i - 1, 1)] -- central difference
		local flat = Vector3.new(t.X, 0, t.Z)
		local right = lastRight
		if flat.Magnitude > 1e-6 then
			flat = flat.Unit
			right = Vector3.new(-flat.Z, 0, flat.X)
			lastRight = right
		end
		waypoints[i] = wps[i] + right * offset

		local kappa = curv[i]
		if kappa > 1e-6 and i > 1 and i < n then
			local before = Vector3.new(wps[i].X - wps[i - 1].X, 0, wps[i].Z - wps[i - 1].Z)
			local after = Vector3.new(wps[i + 1].X - wps[i].X, 0, wps[i + 1].Z - wps[i].Z)
			local turn = before:Cross(after).Y -- > 0: left turn
			local radius = 1 / kappa
			if turn > 1e-6 then
				radius = math.max(radius + offset, 1)
			elseif turn < -1e-6 then
				radius = math.max(radius - offset, 1)
			end
			kappa = 1 / radius
		end
		curvature[i] = kappa
	end

	local endPos = layout.EndPosition
	local abeam = endPos - fwdVec(layout.EndHeading) * PAD_BEHIND_FINISH
	local padIndex, best = n, math.huge
	for i = n, 1, -1 do
		local d = (wps[i] - abeam).Magnitude
		if d < best then
			best, padIndex = d, i
		end
		if (endPos - wps[i]).Magnitude > CHECKPOINT_LENGTH + 40 then
			break
		end
	end
	return { Waypoints = waypoints, Curvature = curvature, PadIndex = padIndex }
end

function TrackBuilder.Layout(spec)
	local width = spec.Width or DEFAULT_WIDTH
	local pos = Vector3.zero
	local heading = 0
	local pieces = {}
	local waypoints = { Vector3.zero }
	local curvature = { 0 }
	local length = 0
	local maxGrade = 0
	local loopCount = 0

	for _, seg in spec.Segments do
		if seg.Type == "Straight" then
			local len = seg.Length
			local dir = fwdVec(heading)
			table.insert(pieces, flatPiece(pos + dir * len / 2, heading, len))
			local n = math.max(1, math.ceil(len / WAYPOINT_SPACING))
			for i = 1, n do
				table.insert(waypoints, pos + dir * len * i / n)
				table.insert(curvature, 0)
			end
			pos += dir * len
			length += len
		elseif seg.Type == "Turn" then
			local theta = math.rad(seg.Angle)
			local radius = seg.Radius
			local s = theta >= 0 and 1 or -1
			local center = pos + leftVec(heading) * radius * s
			local n = math.max(1, math.ceil(math.abs(seg.Angle) / TURN_STEP_DEG))
			local dTheta = theta / n
			local prev = pos
			for i = 1, n do
				local p = center - leftVec(heading + dTheta * i) * radius * s
				local chord = 2 * (radius + width / 2) * math.sin(math.abs(dTheta) / 2) + 0.2
				table.insert(pieces, flatPiece((prev + p) / 2, heading + dTheta * (i - 0.5), chord))
				table.insert(waypoints, p)
				table.insert(curvature, 1 / radius)
				prev = p
			end
			pos = prev
			heading += theta
			length += math.abs(theta) * radius
		elseif seg.Type == "Slope" then
			local run, rise = seg.Length, seg.Rise
			local dir = fwdVec(heading)
			local n = math.max(2, math.ceil(run / SLOPE_STEP))
			local prev = pos
			for i = 1, n do
				local t = i / n
				local p = pos + dir * run * t + Vector3.new(0, rise * (1 - math.cos(math.pi * t)) / 2, 0)
				local d = p - prev
				local pitch = math.atan2(d.Y, Vector3.new(d.X, 0, d.Z).Magnitude)
				local center = (prev + p) / 2
				table.insert(pieces, {
					Center = center,
					Heading = heading,
					Length = d.Magnitude + 0.2,
					CFrame = CFrame.new(center) * CFrame.Angles(0, heading, 0) * CFrame.Angles(pitch, 0, 0),
					Support = true,
				})
				table.insert(waypoints, p)
				table.insert(curvature, 0)
				prev = p
			end
			maxGrade = math.max(maxGrade, math.atan(math.abs(rise) * math.pi / (2 * run)))
			pos = prev
			length += math.sqrt(run * run + rise * rise)
		elseif seg.Type == "Loop" then
			local radius = seg.Radius
			local shift = seg.Shift or (width + 10)
			local s = seg.Direction == "Right" and -1 or 1
			local f, l, up = fwdVec(heading), leftVec(heading), Vector3.yAxis
			local function pointAt(phi)
				return pos
					+ f * (radius * math.sin(phi))
					+ up * (radius * (1 - math.cos(phi)))
					+ l * (s * shift * (phi - math.sin(phi)) / (2 * math.pi))
			end
			local n = math.ceil(360 / LOOP_STEP_DEG)
			local prev = pos
			for i = 1, n do
				local phi = 2 * math.pi * i / n
				local mid = 2 * math.pi * (i - 0.5) / n
				local p = pointAt(phi)
				-- Frame at the piece's middle: tangent from the derivative, surface normal towards the loop centre
				local tangent = (
					f * (radius * math.cos(mid))
					+ up * (radius * math.sin(mid))
					+ l * (s * shift * (1 - math.cos(mid)) / (2 * math.pi))
				).Unit
				local toCentre = f * -math.sin(mid) + up * math.cos(mid)
				local normal = (toCentre - tangent * toCentre:Dot(tangent)).Unit
				local right = tangent:Cross(normal)
				local center = (prev + p) / 2
				table.insert(pieces, {
					Center = center,
					Heading = heading,
					Length = (p - prev).Magnitude + 0.2,
					CFrame = CFrame.fromMatrix(center, right, normal, -tangent),
					Support = false,
					Loop = true,
				})
				table.insert(waypoints, p)
				table.insert(curvature, 1 / radius)
				prev = p
			end
			pos = prev
			length += 2 * math.pi * radius
			loopCount += 1
		else
			error("Unknown segment type: " .. tostring(seg.Type))
		end
	end

	local peak = 0
	for _, p in waypoints do
		peak = math.max(peak, p.Y)
	end

	return {
		Width = width,
		Closed = spec.Closed == true,
		Pieces = pieces,
		Waypoints = waypoints,
		Curvature = curvature,
		Length = length,
		EndPosition = pos,
		EndHeading = heading,
		Peak = peak, -- highest waypoint, studs
		MaxGradeDeg = math.deg(maxGrade), -- steepest Slope segment
		LoopCount = loopCount,
	}
end

local function newPart(model, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function checkeredLine(parent, name, cframe, width, depth, colors)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	local cells = 8
	local cellWidth = width / cells
	for i = 1, cells do
		local color = i % 2 == 0 and (colors.CheckerDark or Color3.fromRGB(28, 30, 38)) or colors.Line
		newPart(
			folder,
			"Cell" .. i,
			Vector3.new(cellWidth, 0.12, depth),
			cframe * CFrame.new(-width / 2 + cellWidth * (i - 0.5), 0.08, 0),
			color,
			Enum.Material.SmoothPlastic
		).CanCollide =
			false
	end
	return folder
end

function TrackBuilder.Build(spec, origin)
	origin = origin or CFrame.new()
	local layout = TrackBuilder.Layout(spec)
	local width = layout.Width
	local colors = colorsFor(spec)

	local model = Instance.new("Model")
	model.Name = spec.Name

	local roads = Instance.new("Folder")
	roads.Name = "Road"
	roads.Parent = model
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = model
	local supports = Instance.new("Folder")
	supports.Name = "Supports"
	supports.Parent = model

	for i, piece in layout.Pieces do
		local pieceCF = origin * piece.CFrame
		local road = newPart(
			roads,
			"Road" .. i,
			Vector3.new(width, ROAD_THICKNESS, piece.Length),
			pieceCF * CFrame.new(0, -ROAD_THICKNESS / 2, 0),
			colors.Road
		)
		local wallOffset = width / 2 + WALL_THICKNESS / 2
		local pieceWalls = {}
		-- The checkpoint apron is wider than the road, so the finish straight's walls stop where it starts
		local wallLength, wallZ = piece.Length, 0
		if i == #layout.Pieces and piece.Length > CHECKPOINT_LENGTH + WALL_GAP then
			wallLength = piece.Length - CHECKPOINT_LENGTH - WALL_GAP
			wallZ = (CHECKPOINT_LENGTH + WALL_GAP) / 2 -- piece space: +Z is back, away from the finish
		end
		for _, side in { -1, 1 } do
			table.insert(
				pieceWalls,
				newPart(
					walls,
					"Wall" .. i .. (side < 0 and "L" or "R"),
					Vector3.new(WALL_THICKNESS, WALL_HEIGHT, wallLength),
					pieceCF * CFrame.new(side * wallOffset, WALL_HEIGHT / 2 - ROAD_THICKNESS, wallZ),
					colors.Wall
				)
			)
		end
		if piece.Loop then
			-- CarPhysics cancels gravity while a wheel touches a LoopAssist part
			road:SetAttribute("LoopAssist", true)
			for _, w in pieceWalls do
				w:SetAttribute("LoopAssist", true)
			end
		end

		-- Hills: fill from the ground up to the middle of the road slab, so the road is not on stilts
		local slabY = (origin * piece.CFrame).Position.Y
			- ROAD_THICKNESS / 2
			- math.abs(pieceCF.LookVector.Y) * piece.Length / 2
			- SUPPORT_CLEARANCE
		if piece.Support and slabY > GROUND_TOP + 1 then
			local flatLook = Vector3.new(pieceCF.LookVector.X, 0, pieceCF.LookVector.Z)
			local footprint = CFrame.lookAt(Vector3.zero, flatLook)
			local height = slabY - GROUND_TOP
			newPart(
				supports,
				"Support" .. i,
				Vector3.new(width - 1, height, piece.Length * math.max(flatLook.Magnitude, 0.5)),
				CFrame.new(pieceCF.Position.X, GROUND_TOP + height / 2, pieceCF.Position.Z) * footprint.Rotation,
				colors.Support
			)
		end
	end

	-- Start / finish line
	newPart(
		model,
		"StartLine",
		Vector3.new(width, 0.2, 3),
		origin * CFrame.new(0, 0.1, -6),
		colors.Line,
		Enum.Material.Neon
	).CanCollide =
		false -- decor: the car drives over it
	if colors.Checkered then
		checkeredLine(model, "StartCheckered", origin * CFrame.new(0, 0.1, -6), width, 3, colors)
	end

	-- Checkpoint area at the finish: it connects to the next track's start
	local checkpoint = Instance.new("Model")
	checkpoint.Name = "Checkpoint"
	checkpoint.Parent = model
	local endCF = origin * CFrame.new(layout.EndPosition) * CFrame.Angles(0, layout.EndHeading, 0)
	local function decor(part)
		part.CanCollide = false
		part.CanQuery = false
		return part
	end
	-- Wider than the road: an apron each side. It is a real slab (cars drive on it), flush with the road top.
	newPart(
		checkpoint,
		"CheckpointArea",
		Vector3.new(width + 2 * CHECKPOINT_APRON, ROAD_THICKNESS, CHECKPOINT_LENGTH),
		endCF * CFrame.new(0, AREA_TOP - ROAD_THICKNESS / 2, CHECKPOINT_LENGTH / 2),
		colors.Checkpoint
	)
	decor(
		newPart(
			checkpoint,
			"FinishLine",
			Vector3.new(width, 0.3, 3),
			endCF * CFrame.new(0, AREA_TOP + 0.15, FINISH_LINE_BEHIND),
			colors.Line,
			Enum.Material.Neon
		)
	)
	if colors.Checkered then
		checkeredLine(
			checkpoint,
			"FinishCheckered",
			endCF * CFrame.new(0, AREA_TOP + 0.15, FINISH_LINE_BEHIND),
			width,
			3,
			colors
		)
	end
	local winPad = decor(newPart(
		checkpoint,
		"WinPad",
		Vector3.new(PAD_SIZE, 0.4, PAD_SIZE),
		endCF * CFrame.new(-PAD_LEFT_OFFSET, AREA_TOP + 0.2, PAD_BEHIND_FINISH), -- LEFT of the road centre
		colors.WinPad,
		Enum.Material.Neon
	))
	winPad.CanTouch = true -- RaceService pays the driver when the auto-racing car reaches it
	local cash = TrackBuilder.CashFor(spec.Number)
	winPad:SetAttribute("Cash", cash)
	CollectionService:AddTag(winPad, "WinPad")
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WinText"
	billboard.Adornee = winPad
	billboard.Size = UDim2.fromOffset(120, 50)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.MaxDistance = TrackBuilder.WIN_TEXT_DISTANCE -- proximity based
	billboard.LightInfluence = 0
	billboard.Parent = winPad
	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "$" .. cash
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = colors.WinPad
	label.TextStrokeTransparency = 0
	label.Parent = billboard

	-- Grass under everything so falling off the road is survivable
	local minP, maxP = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
	for _, p in layout.Waypoints do
		minP = Vector3.new(math.min(minP.X, p.X), 0, math.min(minP.Z, p.Z))
		maxP = Vector3.new(math.max(maxP.X, p.X), 0, math.max(maxP.Z, p.Z))
	end
	local pad = width * 3 + 200
	local size = maxP - minP
	local ground = newPart(
		model,
		"Ground",
		Vector3.new(size.X + pad * 2, 1, size.Z + pad * 2),
		origin * CFrame.new((minP + maxP) / 2),
		colors.Ground,
		Enum.Material.Grass
	)
	ground.Position = Vector3.new(ground.Position.X, GROUND_TOP - 0.5, ground.Position.Z)

	-- Invisible spawn marker: facing along the first straight, a little above the road
	local start = newPart(model, "Start", Vector3.new(4, 1, 4), origin * CFrame.new(0, 0.5, 0), colors.Line)
	start.Transparency = 1
	start.CanCollide = false
	start.CanQuery = false
	start.CanTouch = false

	-- World-space waypoints for bots
	local world = table.create(#layout.Waypoints)
	for i, p in layout.Waypoints do
		world[i] = origin:PointToWorldSpace(p)
	end
	layout.WorldWaypoints = world

	model:SetAttribute("TrackName", spec.Name)
	model:SetAttribute("Number", spec.Number)
	model:SetAttribute("Length", layout.Length)
	return model, layout
end

return TrackBuilder
