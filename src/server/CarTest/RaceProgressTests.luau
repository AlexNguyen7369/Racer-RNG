--!nonstrict
-- docs/RACE_PROGRESS_MAP_SPEC.md: ordered 3D progress, aspect-preserving display,
-- private win-only PBs. docs/SAVE_SPEC.md: VERSION 11, atomic injected-store saves.
-- Geometry/Records also run offline: lune run tools/tests/race_progress_map.luau.
-- Server cases use only fake Folder players, an isolated PlayerData module/store,
-- and synthetic routes. Each forced finish consumes one simulation frame.
local Tests = {}

local function report(name)
	local result = { scenario = name, pass = true, checks = {}, metrics = {} }
	local function flag(label, ok, value)
		table.insert(result.checks, { name = label, pass = ok == true, value = value or (ok and 1 or 0), limit = 1 })
		result.pass = result.pass and ok == true
	end
	return result, flag
end

local function near(a, b, tolerance)
	return type(a) == "number" and math.abs(a - b) <= (tolerance or 1e-6)
end

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function same(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not same(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function Tests.Geometry(map)
	local result, flag = report("race_progress_geometry")
	for _, name in { "Build", "Progress", "Point", "Normalized", "ViewPoint", "ClampViewPoint", "Status", "FormatTime" } do
		flag("api_" .. name, type(map[name]) == "function")
	end
	local function route(points)
		return map.Build({ Waypoints = points })
	end
	local a, b, c = Vector3.new(0, 0, 0), Vector3.new(30, 40, 0), Vector3.new(30, 40, 150)
	local hill = route({ a, b, c }) -- 50 uphill studs + 150 level studs.
	flag("length_uses_3d", near(hill.Total, 200))
	flag("hill_projection", near(map.Progress(hill, Vector3.new(15, 20, 0)), 0.125))
	flag("level_projection_after_hill", near(map.Progress(hill, Vector3.new(30, 40, 75)), 0.625))
	flag("projection_start_clamp", near(map.Progress(hill, Vector3.new(-30, -40, 0)), 0))
	flag("projection_finish_clamp", near(map.Progress(hill, Vector3.new(30, 40, 200)), 1))
	flag("point_uses_distance_not_waypoint_count", (map.Point(hill, 0.25) - b).Magnitude < 1e-5)
	flag("point_hill_interpolation", (map.Point(hill, 0.125) - Vector3.new(15, 20, 0)).Magnitude < 1e-5)
	flag("point_start_clamp", map.Point(hill, -1) == a)
	flag("point_finish_clamp", map.Point(hill, 2) == c)
	for _, progress in { 0, 0.05, 0.125, 0.25, 0.5, 0.9, 1 } do
		flag("point_projection_roundtrip_" .. progress, near(map.Progress(hill, map.Point(hill, progress)), progress))
	end

	local bridge = route({
		Vector3.new(-100, 0, 0),
		Vector3.new(100, 0, 0),
		Vector3.new(100, 50, 0),
		Vector3.new(-100, 50, 0),
	})
	flag("overlap_lower_deck", near(map.Progress(bridge, Vector3.new(0, 0, 0)), 100 / 450))
	flag("overlap_upper_deck", near(map.Progress(bridge, Vector3.new(0, 50, 0)), 350 / 450))
	flag("vertical_projection", near(map.Progress(bridge, Vector3.new(100, 25, 0)), 225 / 450))
	local cross = route({
		Vector3.new(-100, 0, -100),
		Vector3.new(100, 0, 100),
		Vector3.new(-100, 0, 100),
		Vector3.new(100, 0, -100),
	})
	local diagonal = math.sqrt(200 * 200 * 2)
	local firstCross = diagonal / 2 / cross.Total
	local lastCross = (diagonal + 200 + diagonal / 2) / cross.Total
	flag(
		"true_3d_crossing_early_branch",
		near(map.Progress(cross, Vector3.zero, firstCross - 10 / cross.Total, 25), firstCross)
	)
	flag(
		"true_3d_crossing_late_branch",
		near(map.Progress(cross, Vector3.zero, lastCross - 10 / cross.Total, 25), lastCross)
	)
	local early = map.Progress(cross, Vector3.new(1, 0, -1), firstCross - 5 / cross.Total, 25)
	flag("closer_future_branch_cannot_skip_loop", early < firstCross + 20 / cross.Total)
	local straight = route({ Vector3.zero, Vector3.new(1000, 0, 0) })
	flag("previous_progress_is_monotonic", near(map.Progress(straight, Vector3.new(50, 0, 0), 0.4, 50), 0.4))
	flag("explicit_continuity_window", near(map.Progress(straight, Vector3.new(900, 0, 0), 0.4, 50), 0.45))
	local defaultWindow = map.Progress(straight, Vector3.new(900, 0, 0), 0.4)
	flag("default_continuity_window", defaultWindow >= 0.4 and defaultWindow < 0.9)
	flag("zero_window_does_not_advance", near(map.Progress(straight, Vector3.new(900, 0, 0), 0.4, 0), 0.4))
	local previous = 0
	for index, x in { 20, 40, 15, 60, 10, 80, 100 } do
		local current = map.Progress(straight, Vector3.new(x, 0, 0), previous, 30)
		flag("jitter_monotonic_" .. index, current >= previous and current <= previous + 0.030001)
		previous = current
	end

	local rectangle = route({ Vector3.new(-100, 8, -50), Vector3.new(100, 80, 50) })
	for index, size in { Vector2.new(100, 100), Vector2.new(400, 200), Vector2.new(190, 128), Vector2.new(20, 10) } do
		local low = map.Normalized(rectangle, rectangle.Points[1], size)
		local high = map.Normalized(rectangle, rectangle.Points[2], size)
		local pixelWidth, pixelHeight = (high.X - low.X) * size.X, (high.Y - low.Y) * size.Y
		local padding = math.min(14, size.X / 4, size.Y / 4)
		flag("aspect_" .. index, near(pixelWidth / pixelHeight, 2))
		flag("centered_" .. index, near(low.X + high.X, 1) and near(low.Y + high.Y, 1))
		flag("padding_" .. index, low.X * size.X >= padding - 1e-5 and low.Y * size.Y >= padding - 1e-5)
		flag("fills_available_axis_" .. index, near(low.X * size.X, padding) or near(low.Y * size.Y, padding))
	end
	local squareLow = map.Normalized(rectangle, rectangle.Points[1], Vector2.new(100, 100))
	flag("known_square_normalization", near(squareLow.X, 0.14) and near(squareLow.Y, 0.32))
	local defaultLow = map.Normalized(rectangle, rectangle.Points[1])
	flag("default_236_by_84_padding14", near(defaultLow.X, 62 / 236) and near(defaultLow.Y, 14 / 84))
	local translated =
		route({ rectangle.Points[1] + Vector3.new(900, 100, -700), rectangle.Points[2] + Vector3.new(900, 100, -700) })
	flag(
		"normalization_translation_invariant",
		(map.Normalized(translated, translated.Points[1]) - defaultLow).Magnitude < 1e-6
	)
	local horizontal = route({ Vector3.zero, Vector3.new(100, 0, 0) })
	local vertical = route({ Vector3.zero, Vector3.new(0, 100, 0) })
	flag("horizontal_centered_z", near(map.Normalized(horizontal, Vector3.zero).Y, 0.5))
	flag("vertical_3d_progress", near(map.Progress(vertical, Vector3.new(0, 25, 0)), 0.25))
	flag(
		"vertical_topdown_collapses_to_center",
		(map.Normalized(vertical, Vector3.new(0, 75, 0)) - Vector2.new(0.5, 0.5)).Magnitude < 1e-6
	)
	for index, points in { {}, { b }, { b, b, b }, { a, a, b, b, c } } do
		local degenerate = route(points)
		local progress = map.Progress(degenerate, b)
		local point = map.Point(degenerate, 0.5)
		local normalized = map.Normalized(degenerate, point)
		flag(
			"degenerate_finite_" .. index,
			finite(progress) and finite(point.X) and finite(normalized.X) and finite(normalized.Y)
		)
		if index < 4 then
			flag("degenerate_zero_progress_" .. index, progress == 0)
			flag("degenerate_point_" .. index, point == (points[1] or Vector3.zero))
		else
			flag("repeated_waypoints_keep_distance", near(degenerate.Total, 200))
		end
	end
	-- Heading-up viewport: equal world distances retain equal pixel lengths.
	local origin, north = Vector3.zero, Vector3.new(0, 0, -1)
	local viewSize = Vector2.new(400, 200)
	for index, case in
		{
			{ origin, north, Vector2.new(0.5, 0.5) },
			{ Vector3.new(0, 0, -50), north, Vector2.new(0.5, 0.25) },
			{ Vector3.new(0, 0, 50), north, Vector2.new(0.5, 0.75) },
			{ Vector3.new(50, 0, 0), north, Vector2.new(0.625, 0.5) },
			{ Vector3.new(-50, 0, 0), north, Vector2.new(0.375, 0.5) },
			{ Vector3.new(50, 0, 0), Vector3.xAxis, Vector2.new(0.5, 0.25) },
			{ Vector3.new(0, 0, -50), Vector3.xAxis, Vector2.new(0.375, 0.5) },
		}
	do
		local point = map.ViewPoint(case[1], origin, case[2], viewSize, 200)
		flag("view_cardinal_heading_" .. index, (point - case[3]).Magnitude < 1e-6)
	end
	local shift = Vector3.new(1200, 80, -900)
	local baseline = map.ViewPoint(Vector3.new(50, 0, -50), origin, north, viewSize, 200)
	flag(
		"view_translation_invariant",
		(map.ViewPoint(Vector3.new(50, 0, -50) + shift, shift, north, viewSize, 200) - baseline).Magnitude < 1e-6
	)
	flag(
		"view_ignores_height",
		(map.ViewPoint(Vector3.new(50, 900, -50), origin, north, viewSize, 200) - baseline).Magnitude < 1e-6
	)
	flag(
		"view_normalizes_flat_heading",
		(map.ViewPoint(Vector3.new(50, 0, -50), origin, Vector3.new(0, 90, -20), viewSize, 200) - baseline).Magnitude
			< 1e-6
	)
	for index, heading in { Vector3.zero, Vector3.yAxis } do
		flag(
			"view_degenerate_heading_" .. index,
			(map.ViewPoint(Vector3.new(50, 0, -50), origin, heading, viewSize, 200) - baseline).Magnitude < 1e-6
		)
	end
	for index, size in { Vector2.new(100, 100), viewSize, Vector2.new(190, 128) } do
		local right = map.ViewPoint(Vector3.new(50, 0, 0), origin, north, size, 200)
		local ahead = map.ViewPoint(Vector3.new(0, 0, -50), origin, north, size, 200)
		flag("view_preserves_pixel_aspect_" .. index, near((right.X - 0.5) * size.X, (0.5 - ahead.Y) * size.Y, 1e-4))
		local zoomed = map.ViewPoint(Vector3.new(0, 0, -50), origin, north, size, 400)
		flag("view_zoom_span_" .. index, near(0.5 - zoomed.Y, (0.5 - ahead.Y) / 2))
	end
	local offscreen = map.ViewPoint(Vector3.new(10000, 0, -10000), origin, north, viewSize, 200)
	flag("view_leaves_far_geometry_unclamped", offscreen.X > 1 and offscreen.Y < 0)
	local tiny = map.ViewPoint(origin, origin, north, Vector2.zero, 0)
	flag("view_degenerate_size_finite", finite(tiny.X) and finite(tiny.Y))
	for index, point in { Vector2.new(0.5, 0.5), Vector2.new(0.25, 0.75), Vector2.new(0.125, 0.875) } do
		local clamped, clipped = map.ClampViewPoint(point, 0.125)
		flag("view_inside_not_clamped_" .. index, clamped == point and clipped == false)
	end
	for index, case in
		{
			{ Vector2.new(2, 0.5), Vector2.new(0.875, 0.5) },
			{ Vector2.new(-1, 0.5), Vector2.new(0.125, 0.5) },
			{ Vector2.new(0.5, 2), Vector2.new(0.5, 0.875) },
			{ Vector2.new(0.5, -1), Vector2.new(0.5, 0.125) },
			{ Vector2.new(2, 1), Vector2.new(0.875, 0.625) },
			{ Vector2.new(-1, 0), Vector2.new(0.125, 0.375) },
		}
	do
		local clamped, clipped = map.ClampViewPoint(case[1], 0.125)
		flag("view_edge_clamp_" .. index, clipped == true and (clamped - case[2]).Magnitude < 1e-6)
		local again, clippedAgain = map.ClampViewPoint(clamped, 0.125)
		flag("view_clamp_idempotent_" .. index, (again - clamped).Magnitude < 1e-6 and clippedAgain == false)
	end
	for index, point in { Vector2.new(4, -2), Vector2.new(-2, -1), Vector2.new(-1, 3), Vector2.new(3, 4) } do
		local clamped, clipped = map.ClampViewPoint(point)
		local delta, edge = point - Vector2.new(0.5, 0.5), clamped - Vector2.new(0.5, 0.5)
		flag(
			"view_edge_default_margin_" .. index,
			clipped
				and clamped.X >= 0.07 - 1e-6
				and clamped.X <= 0.93 + 1e-6
				and clamped.Y >= 0.07 - 1e-6
				and clamped.Y <= 0.93 + 1e-6
				and (near(math.abs(edge.X), 0.43) or near(math.abs(edge.Y), 0.43))
		)
		flag(
			"view_edge_preserves_direction_" .. index,
			near(delta.X * edge.Y - delta.Y * edge.X, 0) and delta:Dot(edge) > 0
		)
	end
	for index, case in
		{
			{ 0.5, 0.5, "EVEN" },
			{ 0.509, 0.5, "EVEN" },
			{ 0.491, 0.5, "EVEN" },
			{ 0.01, 0, "AHEAD" },
			{ 0, 0.01, "BEHIND" },
			{ 0.8, 0.2, "AHEAD" },
			{ 0.2, 0.8, "BEHIND" },
		}
	do
		flag("status_1_percent_" .. index, map.Status(case[1], case[2]) == case[3])
	end
	for index, case in
		{
			{ 0, "00:00.00" },
			{ -4, "00:00.00" },
			{ 0.009, "00:00.00" },
			{ 0.01, "00:00.01" },
			{ 1.999, "00:01.99" },
			{ 59.999, "00:59.99" },
			{ 60, "01:00.00" },
			{ 61.23, "01:01.23" },
			{ 5999.99, "99:59.99" },
			{ 6000, "100:00.00" },
		}
	do
		flag("time_exact_centiseconds_" .. index, map.FormatTime(case[1]) == case[2], map.FormatTime(case[1]))
	end
	return result
end

function Tests.Records(times, trackNumbers)
	local result, flag = report("race_progress_records")
	local player, other = {}, {}
	local first, second = trackNumbers[1], trackNumbers[2]
	assert(first and second, "PB isolation tests require two numbered tracks")
	flag("setup_empty", next(times.Snapshot(player)) == nil)
	local best, changed = times.Record(player, first, 90)
	flag("first_positive_time_records", best == 90 and changed == true)
	times.Setup(player)
	flag("setup_idempotent", times.Best(player, first) == 90)
	for _, seconds in { 95, 90 } do
		best, changed = times.Record(player, first, seconds)
		flag("slower_or_equal_" .. seconds, best == 90 and changed == false)
	end
	best, changed = times.Record(player, tostring(first), 80.125)
	flag(
		"faster_time_and_canonical_string_key",
		best == 80.125 and changed == true and times.Best(player, first) == 80.125
	)
	flag("other_player_empty", times.Best(other, first) == nil)
	times.Record(other, first, 21)
	times.Record(player, second, 33)
	flag("per_player_isolation", times.Best(player, first) == 80.125 and times.Best(other, first) == 21)
	flag("per_track_isolation", times.Best(player, second) == 33 and times.Best(player, first) == 80.125)
	local snapshot = times.Snapshot(player)
	flag("snapshot_canonical_string_keys", snapshot[tostring(first)] == 80.125 and snapshot[first] == nil)
	snapshot[tostring(first)], snapshot[tostring(second)] = 1, nil
	flag("snapshot_mutation_cannot_change_pb", times.Best(player, first) == 80.125 and times.Best(player, second) == 33)
	local before = times.Snapshot(player)
	for index, value in { 0, -1, math.huge, -math.huge, 0 / 0, "12", false, {} } do
		best, changed = times.Record(player, first, value)
		flag("invalid_time_" .. index, changed == false and best == 80.125 and same(times.Snapshot(player), before))
	end
	best, changed = times.Record(player, first, nil)
	flag("nil_time_rejected", best == 80.125 and changed == false)
	for index, track in
		{ 0, -1, 1.5, #trackNumbers + 1, math.huge, 0 / 0, "01", "1.0", "1e0", "+1", " 1", "1 ", "no-track", true, {} }
	do
		best, changed = times.Record(player, track, 1)
		flag(
			"invalid_track_" .. index,
			best == nil
				and changed == false
				and times.Best(player, track) == nil
				and same(times.Snapshot(player), before)
		)
	end
	best, changed = times.Record(player, nil, 1)
	flag("nil_track_rejected", best == nil and changed == false and same(times.Snapshot(player), before))
	local source = {
		RaceBestTimes = {
			[tostring(first)] = 18.25,
			[tostring(second)] = 22,
			[first] = 2,
			["01"] = 1,
			["1.0"] = 1,
			["1e0"] = 1,
			["+1"] = 1,
			["0"] = 1,
			["-1"] = 1,
			["1.5"] = 1,
			[" 1"] = 1,
			["1 "] = 1,
			[tostring(#trackNumbers + 1)] = 1,
		},
	}
	times.Apply(player, source)
	flag(
		"apply_canonical_existing_tracks_only",
		same(times.Snapshot(player), { [tostring(first)] = 18.25, [tostring(second)] = 22 })
	)
	source.RaceBestTimes[tostring(first)] = 0.5
	flag("apply_does_not_alias_save_table", times.Best(player, first) == 18.25)
	local detached = times.Snapshot(player)
	times.Record(player, first, 17)
	flag("snapshot_does_not_change_after_new_record", detached[tostring(first)] == 18.25)
	for _, track in trackNumbers do
		times.Apply(player, { RaceBestTimes = { [tostring(track)] = 12.5 } })
		flag("every_registry_track_accepted_" .. track, times.Best(player, track) == 12.5)
	end
	for index, value in { 0, -5, math.huge, -math.huge, 0 / 0, "10", false, {} } do
		times.Apply(player, { RaceBestTimes = { [tostring(first)] = value } })
		flag("apply_invalid_value_" .. index, next(times.Snapshot(player)) == nil)
	end
	for index, data in { {}, { RaceBestTimes = false }, { RaceBestTimes = "invalid" }, { RaceBestTimes = 5 } } do
		times.Record(player, first, 3)
		times.Apply(player, data)
		flag("malformed_or_missing_table_resets_" .. index, next(times.Snapshot(player)) == nil)
	end
	times.Record(player, first, 3)
	times.Apply(player, nil)
	flag("nil_save_resets", next(times.Snapshot(player)) == nil)
	flag("apply_did_not_change_other_player", times.Best(other, first) == 21)
	return result
end

local function merge(result, section)
	for _, check in section.checks do
		table.insert(result.checks, check)
	end
	result.pass = result.pass and section.pass
end

function Tests.race_progress_map()
	local result, flag = report("race_progress_map")
	local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local server = script.Parent.Parent
	local times = require(server.RaceTimeService)
	local support = require(script.Parent.AcceptanceSupport)
	local cleanup, runs = {}, {}
	local function section(name, fn)
		local ok, err = xpcall(fn, debug.traceback)
		if not ok then
			flag(name .. "_completed", false, tostring(err))
		end
	end
	section("geometry", function()
		merge(result, Tests.Geometry(require(shared.RaceProgressMap)))
	end)
	section("records", function()
		local numbers = {}
		for _, track in require(shared.TrackRegistry).Chain() do
			table.insert(numbers, track.Number)
		end
		merge(result, Tests.Records(times, numbers))
	end)
	section("persistence", function()
		-- Clone only PlayerData so SetStore never redirects the live player's autosaves.
		local module = server.PlayerData:Clone()
		module.Name, module.Parent = "CarTestRaceProgressData", server
		table.insert(cleanup, module)
		local data = require(module)
		local oldId, id = 990088001, 990088002
		local fake = support.store({
			[data.KeyFor(oldId)] = { Version = 10, Money = 123, Speed = 456 },
			[data.KeyFor(id)] = {
				Version = 11,
				RaceBestTimes = { ["1"] = 80.25, ["2"] = 90, ["01"] = 1, ["999"] = 1, ["3"] = -1 },
			},
		})
		fake.retry = true -- exercises retried UpdateAsync transforms as well.
		data.SetStore(fake)
		data.SetClock(function()
			return 1800000000
		end)
		data.SetSessionId("race-progress-test")
		local old = support.player(cleanup, oldId)
		flag("v10_loads", data.Load(old, oldId))
		flag("v10_pb_defaults_empty", next(times.Snapshot(old)) == nil)
		flag("v10_existing_stats_preserved", old.leaderstats.Money.Value == 123 and data.SpeedStat(old) == 456)
		flag("v10_upgrades_on_save", data.Save(old, oldId, true))
		local upgraded = fake.data[data.KeyFor(oldId)]
		flag(
			"v10_saved_as_version11_empty_pb",
			upgraded.Version == 12 and type(upgraded.RaceBestTimes) == "table" and next(upgraded.RaceBestTimes) == nil
		)
		local player = support.player(cleanup, id)
		flag("v11_loads", data.Load(player, id))
		flag("v11_load_sanitizes_pb", same(times.Snapshot(player), { ["1"] = 80.25, ["2"] = 90 }))
		times.Record(player, 1, 75.125)
		flag("v11_atomic_save", data.Save(player, id, true))
		local saved = fake.data[data.KeyFor(id)]
		flag(
			"v11_payload_and_release",
			saved.Version == 12 and saved.Lock == nil and same(saved.RaceBestTimes, { ["1"] = 75.125, ["2"] = 90 })
		)
		local rejoined = support.player(cleanup, id)
		flag("v11_rejoin_loads", data.Load(rejoined, id))
		flag("v11_roundtrip_keeps_per_track_pb", same(times.Snapshot(rejoined), saved.RaceBestTimes))
		local snapshot = times.Snapshot(rejoined)
		snapshot["1"] = 1
		flag(
			"v11_snapshot_cannot_mutate_store",
			fake.data[data.KeyFor(id)].RaceBestTimes["1"] == 75.125 and times.Best(rejoined, 1) == 75.125
		)
		flag(
			"pb_not_published_as_attribute",
			rejoined:GetAttribute("RaceBestTimes") == nil and rejoined:GetAttribute("BestTime") == nil
		)
		flag("store_really_used_updateasync", fake.updates >= 5 and fake.writes >= 5)
	end)
	section("race_events", function()
		local runService = game:GetService("RunService")
		local raceService = require(server.RaceService)
		local carFactory, carConfig = require(shared.CarFactory), require(shared.CarConfig)
		local npc, npcConfig = require(shared.NpcRacer), require(shared.NpcConfig)
		local points = {}
		for i = 0, 4 do
			table.insert(points, Vector3.new(0, 2000, -i * 20))
		end
		local route = {
			Path = { WorldWaypoints = points, Curvature = { 0, 0, 0, 0, 0 }, Width = 40, Closed = false },
			Pads = {},
			Tracks = {},
		}
		for number = 1, 2 do
			local start = (number - 1) * 2 + 1
			local path = {
				Waypoints = { points[start], points[start + 1], points[start + 2] },
				Curvature = { 0, 0, 0 },
				Length = 40,
			}
			table.insert(route.Tracks, {
				Number = number,
				StartIndex = start,
				FinishIndex = start + 2,
				Npc = { Config = npcConfig.For(number), Path = path, Profile = npc.Profile(path, 1) },
			})
		end
		local caseId = 0
		local function fixture(options, records)
			caseId += 1
			local player = support.player(cleanup, 990088100 + caseId)
			times.Apply(player, { RaceBestTimes = records or {} })
			local car = carFactory.build(carConfig)
			car.Name, car.Parent = "RaceProgressTestCar", player
			local events, run = {}, nil
			options = options or { Npc = true }
			options.OnRaceEvent = function(event)
				table.insert(events, event)
				if event.Type == "Result" and run then
					-- The callback fires in PreSimulation: prevent a second physics frame.
					run.Connection:Disconnect()
					run.RailConnection:Disconnect()
				end
			end
			run = raceService.NewRun(car, route, player, options)
			table.insert(runs, run)
			return run, player, events
		end
		local function finish(run, track)
			run.Driver.Index = route.Tracks[track].FinishIndex
			runService.PreSimulation:Wait()
			runService.PostSimulation:Wait()
		end
		local before = workspace:GetServerTimeNow()
		local win, player, events = fixture(
			{ Npc = true, NpcSpeeds = { [1] = 0.001, [2] = 0.001 } },
			{ ["1"] = 120, ["2"] = 40 }
		)
		local start = events[1]
		flag("start_payload_owner_pb", start.Type == "Start" and start.Track == 1 and start.BestTime == 120)
		local info = npcConfig.For(1)
		flag(
			"start_payload_npc_metadata",
			finite(start.Speed)
				and start.Speed > 0
				and start.Color == info.Color
				and start.Label == info.Label
				and start.Model == info.Model
		)
		flag("start_does_not_publish_all_pbs", start.RaceBestTimes == nil)
		flag(
			"start_server_clock",
			finite(start.ServerStart)
				and start.ServerStart >= before
				and start.ServerStart <= workspace:GetServerTimeNow()
		)
		finish(win, 1)
		local won = win.Results[1]
		flag("win_authoritative_result", won ~= nil and won.Result == "Win" and won.Track == 1)
		flag("win_positive_finite_time", won ~= nil and finite(won.PlayerTime) and won.PlayerTime > 0)
		flag("win_beats_npc_time", won ~= nil and finite(won.NpcTime) and won.PlayerTime < won.NpcTime)
		flag("one_frame_one_result", #win.Results == 1 and win.Wins == 1)
		flag(
			"win_records_pb_and_payload",
			won ~= nil
				and won.NewBest == true
				and won.BestTime == won.PlayerTime
				and times.Best(player, 1) == won.PlayerTime
		)
		flag("win_keeps_other_track_pb", times.Best(player, 2) == 40)
		local nextStart = events[3]
		flag(
			"next_track_start_uses_its_pb",
			nextStart ~= nil and nextStart.Type == "Start" and nextStart.Track == 2 and nextStart.BestTime == 40
		)
		local pb = times.Snapshot(player)
		win:Destroy()
		flag("stop_after_win_keeps_pb", same(times.Snapshot(player), pb) and events[#events].Type == "Stop")

		local slower, slowPlayer = fixture({ Npc = true, NpcSpeeds = { [1] = 0.001 } }, { ["1"] = 1e-8 })
		finish(slower, 1)
		local slowerResult = slower.Results[1]
		flag(
			"slower_win_keeps_existing_pb",
			slowerResult ~= nil
				and slowerResult.Result == "Win"
				and slowerResult.NewBest == false
				and slowerResult.BestTime == 1e-8
				and times.Best(slowPlayer, 1) == 1e-8
		)
		slower:Destroy()
		for index, records in { {}, { ["1"] = 25, ["2"] = 50 } } do
			local loss, loser, lostEvents = fixture({ Npc = true, NpcSpeeds = { [1] = 1e12 } }, records)
			finish(loss, 1)
			local lost = loss.Results[1]
			flag(
				"loss_authoritative_time_" .. index,
				lost ~= nil and finite(lost.NpcTime) and lost.PlayerTime >= lost.NpcTime
			)
			flag(
				"loss_no_pb_" .. index,
				lost ~= nil
					and lost.Result == "Lose"
					and lost.NewBest == false
					and lost.BestTime == records["1"]
					and same(times.Snapshot(loser), records)
			)
			flag(
				"reset_no_pb_" .. index,
				loss.Resets == 1
					and same(times.Snapshot(loser), records)
					and lostEvents[3].Type == "Reset"
					and lostEvents[4].Type == "Start"
					and lostEvents[4].BestTime == records["1"]
			)
			loss:Destroy()
		end
		local stopped, walker, stopEvents = fixture()
		flag("start_missing_pb_is_nil", stopEvents[1].Type == "Start" and stopEvents[1].BestTime == nil)
		stopped:Destroy()
		flag("incomplete_stop_no_pb", #stopped.Results == 0 and next(times.Snapshot(walker)) == nil)
		local jumped, admin = fixture(nil, { ["1"] = 25 })
		flag("jump_resets_incomplete_race", jumped:JumpToTrack(2) == true)
		flag("jump_no_pb", #jumped.Results == 0 and same(times.Snapshot(admin), { ["1"] = 25 }))
		jumped:Destroy()
		local ordinary, solo = fixture({ Npc = false })
		finish(ordinary, 2)
		flag("non_npc_finish_no_pb", ordinary.Finished and #ordinary.Results == 0 and next(times.Snapshot(solo)) == nil)
		ordinary:Destroy()
		local duelFinishes, duel = 0, nil
		local duelist
		duel, duelist = fixture({
			Duel = {
				Track = 1,
				OnFinish = function()
					duelFinishes += 1
					duel.Connection:Disconnect()
					duel.RailConnection:Disconnect()
				end,
			},
		})
		finish(duel, 1)
		flag(
			"duel_finish_no_pb",
			duel.Finished and duelFinishes == 1 and #duel.Results == 0 and next(times.Snapshot(duelist)) == nil
		)
		duel:Destroy()
	end)
	for _, run in runs do
		pcall(function()
			run:Destroy()
		end)
	end
	for _, instance in cleanup do
		instance:Destroy()
	end
	return result
end

return Tests
