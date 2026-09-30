--!nonstrict
-- Static checks on a track layout, before anything is built or driven.
-- Returns { Ok = boolean, Issues = { string } }.

local TrackBuilder = require(script.Parent.TrackBuilder)

local TrackValidator = {}

local MIN_RADIUS = 28 -- roughly the car's tightest full-lock circle
local MIN_LENGTH = 300
local CLOSE_TOLERANCE = 3 -- studs
local HEADING_TOLERANCE = math.rad(1)
local WALL_CLEARANCE_PAD = 8 -- road width plus both walls and a little air
local MAX_GRADE_DEG = 25 -- steepest slope the car can climb
local MIN_LOOP_RADIUS = 25 -- the car is 13 studs long
local MIN_END_STRAIGHT = 40 -- first and last segment: straight, so tracks join straight-into-straight
local MIN_END_STRAIGHT_MARGIN = 4 -- the last straight is the checkpoint plus this much wall
local MIN_START_FINISH_WIDTHS = 2 -- start and finish are at least this many road widths apart

function TrackValidator.Validate(spec, layout)
	local issues = {}
	local width = layout.Width

	if #spec.Segments == 0 then
		table.insert(issues, "track has no segments")
	end

	-- Track rules (CLAUDE.md): numbered, point-to-point, straight ends, finish apart from start
	if type(spec.Number) ~= "number" or spec.Number < 1 or spec.Number % 1 ~= 0 then
		table.insert(issues, "track needs an integer Number >= 1")
	end
	if layout.Closed then
		table.insert(issues, "track is a closed loop: the finish must be a different place from the start")
	end
	local first, last = spec.Segments[1], spec.Segments[#spec.Segments]
	if first and (first.Type ~= "Straight" or first.Length < MIN_END_STRAIGHT) then
		table.insert(issues, ("first segment must be a Straight of at least %d studs"):format(MIN_END_STRAIGHT))
	end
	local minLast = TrackBuilder.CHECKPOINT_LENGTH + MIN_END_STRAIGHT_MARGIN
	if last and (last.Type ~= "Straight" or last.Length < minLast) then
		table.insert(
			issues,
			("last segment must be a Straight of at least %d studs (the wide checkpoint area sits on it)"):format(
				minLast
			)
		)
	end
	local startFinishGap = layout.EndPosition.Magnitude
	if not layout.Closed and startFinishGap < MIN_START_FINISH_WIDTHS * width then
		table.insert(
			issues,
			("finish is only %.0f studs from the start (min %.0f)"):format(
				startFinishGap,
				MIN_START_FINISH_WIDTHS * width
			)
		)
	end

	for i, seg in spec.Segments do
		if seg.Type == "Turn" then
			if seg.Radius < MIN_RADIUS then
				table.insert(
					issues,
					("segment %d: radius %.0f is tighter than the car can take (min %d)"):format(
						i,
						seg.Radius,
						MIN_RADIUS
					)
				)
			end
			if seg.Radius < width / 2 + 4 then
				table.insert(
					issues,
					("segment %d: radius %.0f is narrower than half the road width"):format(i, seg.Radius)
				)
			end
		elseif seg.Type == "Straight" and seg.Length < 20 then
			table.insert(issues, ("segment %d: straight of %.0f studs is too short"):format(i, seg.Length))
		elseif seg.Type == "Slope" then
			if seg.Length < 40 then
				table.insert(
					issues,
					("segment %d: slope run of %.0f studs is too short (min 40)"):format(i, seg.Length)
				)
			end
			local grade = math.deg(math.atan(math.abs(seg.Rise) * math.pi / (2 * seg.Length)))
			if grade > MAX_GRADE_DEG then
				table.insert(
					issues,
					("segment %d: slope reaches %.1f degrees, the car can climb %d at most"):format(
						i,
						grade,
						MAX_GRADE_DEG
					)
				)
			end
		elseif seg.Type == "Loop" then
			if seg.Radius < MIN_LOOP_RADIUS then
				table.insert(
					issues,
					("segment %d: loop radius %.0f is too small (min %d)"):format(i, seg.Radius, MIN_LOOP_RADIUS)
				)
			end
			if (seg.Shift or (width + 10)) < width + 6 then
				table.insert(
					issues,
					("segment %d: loop shift %.0f is too small, entry and exit lanes would touch (min width + 6)"):format(
						i,
						seg.Shift or 0
					)
				)
			end
		end
	end

	for i, p in layout.Waypoints do
		if p.Y < -0.01 then
			table.insert(issues, ("waypoint %d is %.1f studs below the ground"):format(i, -p.Y))
			break
		end
	end

	if layout.Length < MIN_LENGTH then
		table.insert(issues, ("track is only %.0f studs long (min %d)"):format(layout.Length, MIN_LENGTH))
	end

	if layout.Closed then
		local gap = (layout.EndPosition - Vector3.zero).Magnitude
		if gap > CLOSE_TOLERANCE then
			table.insert(issues, ("closed track does not meet its start: %.1f studs apart"):format(gap))
		end
		local headingError = math.abs(((layout.EndHeading + math.pi) % (2 * math.pi)) - math.pi)
		if headingError > HEADING_TOLERANCE then
			table.insert(
				issues,
				("closed track ends %.1f degrees off its start heading"):format(math.deg(headingError))
			)
		end
	end

	-- Overlap: any two stretches of road that are close in space but far apart along the track
	local wps = layout.Waypoints
	local cum = { 0 }
	for i = 2, #wps do
		cum[i] = cum[i - 1] + (wps[i] - wps[i - 1]).Magnitude
	end
	local total = cum[#wps]
	local near = width * 2.5
	local overlaps = 0
	for i = 1, #wps do
		for j = i + 1, #wps do
			local arc = cum[j] - cum[i]
			local wrapArc = total - arc
			if arc > near and (not layout.Closed or wrapArc > near) then
				if (wps[i] - wps[j]).Magnitude < width + WALL_CLEARANCE_PAD then
					overlaps += 1
				end
			end
		end
	end
	if overlaps > 0 then
		table.insert(issues, ("track overlaps itself (%d close waypoint pairs)"):format(overlaps))
	end

	return { Ok = #issues == 0, Issues = issues }
end

return TrackValidator
