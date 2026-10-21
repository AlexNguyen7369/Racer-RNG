--!nonstrict
-- Ordered path projection used by the race map. Presentation uses X/Z, progress uses 3D distance.
local RaceProgressMap = {}

function RaceProgressMap.Build(path)
	local points = path and path.Waypoints or {}
	local route = {
		Points = {},
		Lengths = {},
		Total = 0,
		MinX = math.huge,
		MaxX = -math.huge,
		MinZ = math.huge,
		MaxZ = -math.huge,
	}
	for i, point in ipairs(points) do
		if typeof(point) == "Vector3" then
			route.Points[i] = point
			route.Lengths[i] = route.Total
			route.MinX, route.MaxX = math.min(route.MinX, point.X), math.max(route.MaxX, point.X)
			route.MinZ, route.MaxZ = math.min(route.MinZ, point.Z), math.max(route.MaxZ, point.Z)
			if i > 1 then
				route.Total += (point - points[i - 1]).Magnitude
				route.Lengths[i] = route.Total
			end
		end
	end
	if route.MinX == math.huge then
		route.MinX, route.MaxX, route.MinZ, route.MaxZ = 0, 1, 0, 1
	end
	route.Width = math.max(route.MaxX - route.MinX, 1)
	route.Height = math.max(route.MaxZ - route.MinZ, 1)
	return route
end

function RaceProgressMap.Progress(route, position)
	if not route or #route.Points < 2 or typeof(position) ~= "Vector3" then
		return 0
	end
	local bestDistance, best = math.huge, 0
	for i = 1, #route.Points - 1 do
		local a, b = route.Points[i], route.Points[i + 1]
		local delta = b - a
		local alpha = delta:Dot(position - a) / math.max(delta:Dot(delta), 1e-9)
		alpha = math.clamp(alpha, 0, 1)
		local projected = a:Lerp(b, alpha)
		local distance = (position - projected).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			best = (route.Lengths[i] + (b - a).Magnitude * alpha) / math.max(route.Total, 1e-9)
		end
	end
	return math.clamp(best, 0, 1)
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

function RaceProgressMap.Normalized(route, point)
	return Vector2.new((point.X - route.MinX) / route.Width, (point.Z - route.MinZ) / route.Height)
end

return RaceProgressMap
