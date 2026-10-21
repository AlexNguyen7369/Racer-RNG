--!nonstrict
-- Ordered 3D distance drives progress; X/Z is used only to present the route.
local RaceProgressMap = {}

function RaceProgressMap.Build(path)
	local route = { Points = {}, Lengths = {}, Total = 0 }
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, point in ipairs(path and path.Waypoints or {}) do
		if typeof(point) == "Vector3" then
			local previous = route.Points[#route.Points]
			if previous then
				route.Total += (point - previous).Magnitude
			end
			table.insert(route.Points, point)
			table.insert(route.Lengths, route.Total)
			minX, minZ = math.min(minX, point.X), math.min(minZ, point.Z)
			maxX, maxZ = math.max(maxX, point.X), math.max(maxZ, point.Z)
		end
	end
	if #route.Points == 0 then
		minX, minZ, maxX, maxZ = 0, 0, 0, 0
	end
	route.MinX, route.MinZ = minX, minZ
	route.Width, route.Height = maxX - minX, maxZ - minZ
	return route
end

-- The forward distance window disambiguates a loop's repeated 3D point.
function RaceProgressMap.Progress(route, position, previous, maxAdvanceStuds)
	if not route or #route.Points < 2 or route.Total < 1e-9 or typeof(position) ~= "Vector3" then
		return 0
	end
	local lower = previous and math.clamp(previous, 0, 1) * route.Total or 0
	local upper = previous and math.min(route.Total, lower + (maxAdvanceStuds or math.max(32, route.Total * 0.04)))
		or route.Total
	local bestDistance, best = math.huge, lower
	for i = 1, #route.Points - 1 do
		local start, finish = route.Lengths[i], route.Lengths[i + 1]
		local span = finish - start
		if span > 1e-9 and finish >= lower and start <= upper then
			local a, b = route.Points[i], route.Points[i + 1]
			local delta = b - a
			local alpha = math.clamp(
				delta:Dot(position - a) / delta:Dot(delta),
				math.max(0, (lower - start) / span),
				math.min(1, (upper - start) / span)
			)
			local distance = (position - a:Lerp(b, alpha)).Magnitude
			if distance < bestDistance then
				bestDistance, best = distance, start + span * alpha
			end
		end
	end
	return math.clamp(best / route.Total, 0, 1)
end

function RaceProgressMap.Point(route, progress)
	progress = math.clamp(progress or 0, 0, 1)
	if #route.Points == 0 then
		return Vector3.zero
	end
	if #route.Points == 1 or route.Total <= 1e-9 then
		return route.Points[1]
	end
	local target = route.Total * progress
	for i = 2, #route.Points do
		if route.Lengths[i] >= target then
			local span = route.Lengths[i] - route.Lengths[i - 1]
			return route.Points[i - 1]:Lerp(
				route.Points[i],
				span > 1e-9 and (target - route.Lengths[i - 1]) / span or 0
			)
		end
	end
	return route.Points[#route.Points]
end

-- Uniform scale preserves shape; padding keeps the dots inside the card.
function RaceProgressMap.Normalized(route, point, size)
	size = size or Vector2.new(236, 84)
	local width, height = math.max(size.X, 1), math.max(size.Y, 1)
	local padding = math.min(14, width / 4, height / 4)
	local scale = math.min(
		(width - padding * 2) / math.max(route.Width, 1e-9),
		(height - padding * 2) / math.max(route.Height, 1e-9)
	)
	return Vector2.new(
		0.5 + (point.X - route.MinX - route.Width / 2) * scale / width,
		0.5 + (point.Z - route.MinZ - route.Height / 2) * scale / height
	)
end

-- Projects world space into a heading-up tactical view. `verticalSpan` is the
-- amount of world space shown from the centre to the top/bottom of the map;
-- horizontal span follows the canvas aspect ratio so the route is not warped.
function RaceProgressMap.ViewPoint(point, center, forward, size, verticalSpan)
	size = size or Vector2.new(340, 196)
	verticalSpan = math.max(tonumber(verticalSpan) or 260, 1)
	if typeof(forward) ~= "Vector3" then
		forward = Vector3.new(0, 0, -1)
	end
	local heading = Vector3.new(forward.X, 0, forward.Z)
	if heading.Magnitude < 1e-6 then
		heading = Vector3.new(0, 0, -1)
	else
		heading = heading.Unit
	end
	local right = Vector3.new(-heading.Z, 0, heading.X)
	local relative = point - center
	local aspect = math.max(size.X, 1) / math.max(size.Y, 1)
	return Vector2.new(0.5 + relative:Dot(right) / (verticalSpan * aspect), 0.5 - relative:Dot(heading) / verticalSpan)
end

-- Keeps an off-screen racer visible as an edge marker without allowing the
-- marker to sit under the route labels or disappear at a corner.
function RaceProgressMap.ClampViewPoint(point, padding)
	padding = math.clamp(tonumber(padding) or 0.07, 0, 0.45)
	local centre = Vector2.new(0.5, 0.5)
	local delta = point - centre
	local maxX, maxY = 0.5 - padding, 0.5 - padding
	if math.abs(delta.X) <= maxX and math.abs(delta.Y) <= maxY then
		return point, false
	end
	if delta.Magnitude < 1e-9 then
		return centre, true
	end
	local scale = math.min(maxX / math.abs(delta.X), maxY / math.abs(delta.Y))
	return centre + delta * scale, true
end

function RaceProgressMap.Status(you, npc)
	local difference = you - npc
	return math.abs(difference) < 0.01 and "EVEN" or (difference > 0 and "AHEAD" or "BEHIND")
end

function RaceProgressMap.FormatTime(seconds)
	local centiseconds = math.floor(math.max(0, seconds or 0) * 100 + 1e-6)
	return string.format("%02d:%02d.%02d", centiseconds // 6000, (centiseconds // 100) % 60, centiseconds % 100)
end

return RaceProgressMap
