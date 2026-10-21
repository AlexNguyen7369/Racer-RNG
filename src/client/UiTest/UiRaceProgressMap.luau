--!nonstrict
-- Focused client test, independent of the full UI/physics harness.
-- In an existing Play CLIENT:
-- local c = game.Players.LocalPlayer.PlayerScripts.Client
-- local r = require(c.UiTest.UiRaceProgressMap).Run()
-- print(game.HttpService:JSONEncode(r))
-- Uses a fresh Hud.Build and BindableEvent remote in an isolated, unparented
-- container. Never touches the live HUD, a real remote, player stats or saves.
local Tests = {}

function Tests.Run()
	local result = { scenario = "ui_race_progress_map", pass = true, checks = {}, metrics = {} }
	local function flag(name, ok, value)
		table.insert(result.checks, { name = name, pass = ok == true, value = value or (ok and 1 or 0), limit = 1 })
		result.pass = result.pass and ok == true
	end
	local function near(a, b)
		return math.abs(a - b) < 1e-4
	end
	local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local player = game:GetService("Players").LocalPlayer
	assert(player, "Run UiRaceProgressMap on the Play client")
	local client = script.Parent.Parent
	local map = require(shared.RaceProgressMap)
	local builder = require(shared.TrackBuilder)
	local npc = require(shared.NpcRacer)
	local config = require(shared.NpcConfig)
	local carConfig = require(shared.CarConfig)
	local registry = require(shared.TrackRegistry)
	local controllerModule = require(client.RaceProgressMap)
	local hudModule = require(client.RollToast.Ui.RacerHud)
	local root = Instance.new("Folder")
	root.Name = "RaceProgressMapTestOnly"
	local remoteEvent = Instance.new("BindableEvent")
	remoteEvent.Parent = root
	local showcase = Instance.new("ScreenGui")
	showcase.Name, showcase.Enabled, showcase.Parent = "RollShowcase", false, root
	local hud, controller
	local ok, err = xpcall(function()
		hud = hudModule.Build(root)
		-- Allow the generated HUD's deferred responsive fit to settle before resize checks.
		task.wait(0.12)
		controller = controllerModule.Attach(hud, player, { OnClientEvent = remoteEvent.Event })
		local canvas, card = hud.RaceMapCanvas, hud.RaceMap
		flag("hidden_until_start", not card.Visible)
		flag(
			"transparent_route_shell",
			card.BackgroundTransparency == 1
				and card:FindFirstChild("Shadow") == nil
				and card:FindFirstChildOfClass("UIStroke") == nil
		)
		flag(
			"controller_api",
			type(controller.Handle) == "function"
				and type(controller.Update) == "function"
				and type(controller.Destroy) == "function"
		)
		local entries, specs = npc.ChainEntries(), registry.Chain()
		local first, second = entries[1], entries[2]
		assert(first and second, "Client map tests require two tracks")
		local function route(entry, lane)
			local path = builder.RacePath(entry.Layout, lane)
			for i, point in path.Waypoints do
				path.Waypoints[i] = entry.Origin:PointToWorldSpace(point)
			end
			return map.Build(path)
		end
		local center, playerRoute = route(first, 0), route(first, builder.LANE_OFFSET)
		local up = Vector3.new(0, carConfig.RestHeight, 0)
		local function event(entry, best)
			return {
				Type = "Start",
				Track = entry.Number,
				Speed = config.For(entry.Number).Speed,
				ServerStart = workspace:GetServerTimeNow(),
				BestTime = best,
			}
		end
		local function childrenNamed(name)
			local count = 0
			for _, child in canvas:GetChildren() do
				if child.Name == name then
					count += 1
				end
			end
			return count
		end
		local function youCentered(label)
			flag(label, canvas.YouDot.Position == UDim2.fromScale(0.5, 0.5))
		end
		local start = event(first)
		controller.Handle(start)
		controller.Update(0, map.Point(playerRoute, 0) + up)
		flag("start_shows_card", card.Visible)
		flag(
			"current_track_title",
			hud.RaceMapTitle.Text == string.format("TRACK %d · %s", first.Number, string.upper(specs[1].Name))
		)
		flag("missing_pb_placeholder", hud.RaceMapPB.Text == "PB --")
		flag("initial_time_and_status", hud.RaceMapTime.Text == "TIME 00:00.00" and hud.RaceMapStatus.Text == "EVEN")
		flag("single_current_track_route", childrenNamed("RouteSegment") == #center.Points - 1)
		flag(
			"markers_once",
			childrenNamed("YouDot") == 1 and childrenNamed("NpcDot") == 1 and childrenNamed("Finish") == 1
		)
		local you, rival = canvas.YouDot, canvas.NpcDot
		flag("markers_labeled", you.Label.Text == "YOU" and rival.Label.Text == "NPC")
		flag(
			"avatar_or_colored_fallback",
			you:IsA("ImageLabel") and (you.Image ~= "" or you.BackgroundTransparency < 1)
		)
		youCentered("you_centered_at_start")
		flag("route_clipped_to_viewport", canvas.ClipsDescendants)
		local firstSegment = canvas:FindFirstChild("RouteSegment")
		local north = Vector3.new(0, 0, -1)
		local startPosition = map.Point(playerRoute, 0) + up
		controller.Update(0, startPosition, north)
		local initialRotation, initialNpc = firstSegment.Rotation, rival.Position
		controller.Update(0, startPosition, -north)
		local rotationChange = math.abs((firstSegment.Rotation - initialRotation + 180) % 360 - 180)
		flag("opposite_heading_rotates_route", near(rotationChange, 180))
		flag("opposite_heading_rotates_npc", rival.Position ~= initialNpc)
		youCentered("you_centered_after_heading_change")
		controller.Update(0, startPosition, north)
		local routeBeforeMovement = firstSegment.Position
		-- Advance along the right-hand lane in small increments. Chassis positions
		-- include ride height, while route projection must use the road's height.
		for i = 1, 10 do
			controller.Update(0, map.Point(playerRoute, i / 100) + up)
		end
		youCentered("you_centered_while_advancing")
		flag("update_redraws_route_while_moving", firstSegment.Position ~= routeBeforeMovement)
		flag("ahead_status", hud.RaceMapStatus.Text == "AHEAD")
		controller.Update(0, map.Point(playerRoute, 0.02) + up)
		youCentered("you_centered_when_position_moves_backwards")
		controller.Update(61.239, nil)
		flag("deterministic_time_centiseconds", hud.RaceMapTime.Text == "TIME 01:01.23")
		flag("npc_dot_moves", rival.Position ~= you.Position)
		local nonInteractive = not card.Active and not card.Selectable
		for _, child in card:GetDescendants() do
			if child:IsA("GuiObject") then
				nonInteractive = nonInteractive and not child.Active and not child.Selectable
			end
		end
		flag("presentation_only_card", nonInteractive)
		controller.Update(61.239, startPosition + Vector3.new(10000, 0, 10000), north)
		local edge = rival.Position
		flag(
			"far_npc_clamps_to_view_edge",
			edge.X.Scale >= 0.07 - 1e-5
				and edge.X.Scale <= 0.93 + 1e-5
				and edge.Y.Scale >= 0.07 - 1e-5
				and edge.Y.Scale <= 0.93 + 1e-5
				and (
					near(edge.X.Scale, 0.07)
					or near(edge.X.Scale, 0.93)
					or near(edge.Y.Scale, 0.07)
					or near(edge.Y.Scale, 0.93)
				)
		)
		youCentered("you_centered_with_far_npc")
		for _ = 1, 3 do
			controller.Handle(event(first, 65.43))
		end
		flag(
			"restart_no_marker_accumulation",
			childrenNamed("YouDot") == 1 and childrenNamed("NpcDot") == 1 and childrenNamed("Finish") == 1
		)
		flag("restart_no_route_accumulation", childrenNamed("RouteSegment") == #center.Points - 1)
		flag("pb_exact_format", hud.RaceMapPB.Text == "PB 01:05.43")
		flag("restart_resets_time", hud.RaceMapTime.Text == "TIME 00:00.00")
		controller.Update(0, map.Point(playerRoute, 0) + up)
		youCentered("restart_recenters_you")
		local npcPath = npc.LanePath(first)
		local profile = npc.Profile(npcPath, start.Speed)
		controller.Update(profile.TotalTime / 2, map.Point(playerRoute, 0) + up)
		flag("behind_status", hud.RaceMapStatus.Text == "BEHIND")
		youCentered("you_centered_while_npc_advances")

		-- A resized tactical view keeps the player centered and one route alive.
		canvas.Size = UDim2.fromOffset(190, 60)
		task.wait()
		controller.Update(profile.TotalTime / 2, nil)
		youCentered("resize_keeps_you_centered")
		flag(
			"resize_keeps_single_route",
			childrenNamed("RouteSegment") == #center.Points - 1 and childrenNamed("Finish") == 1
		)
		showcase.Enabled = true
		controller.Update(12.34, nil)
		flag("showcase_hides_map", not card.Visible)
		showcase.Enabled = false
		controller.Update(15.67, nil)
		flag("showcase_close_restores_active_map", card.Visible and hud.RaceMapTime.Text == "TIME 00:15.67")
		hud.Gui.Enabled = false
		controller.Update(16, nil)
		flag("disabled_hud_hides_map", not card.Visible)
		hud.Gui.Enabled = true
		controller.Update(17, nil)
		flag("reenabled_hud_restores_map", card.Visible)

		controller.Handle(event(second, 120.01))
		flag(
			"track_transition_replaces_title_and_pb",
			hud.RaceMapTitle.Text == string.format("TRACK %d · %s", second.Number, string.upper(specs[2].Name))
				and hud.RaceMapPB.Text == "PB 02:00.01"
		)
		local secondCenter = route(second, 0)
		flag(
			"track_transition_replaces_geometry",
			childrenNamed("RouteSegment") == #secondCenter.Points - 1 and childrenNamed("YouDot") == 1
		)
		for _, kind in { "Result", "Reset", "Stop" } do
			controller.Handle(event(first))
			controller.Handle({ Type = kind, Track = first.Number, Result = "Win" })
			flag(string.lower(kind) .. "_hides_and_cleans", not card.Visible and #canvas:GetChildren() == 0)
			controller.Update(99, map.Point(playerRoute, 0.2) + up)
			flag(string.lower(kind) .. "_stays_hidden", not card.Visible)
		end
		controller.Handle({ Type = "Start", Track = 999, ServerStart = start.ServerStart, Speed = 1 })
		controller.Handle("malformed")
		controller.Handle({ Type = "DuelStart", Track = first.Number })
		flag("invalid_or_duel_events_cannot_show_map", not card.Visible and #canvas:GetChildren() == 0)

		-- Hills retain centered YOU while world-space route geometry moves.
		local testedHill = false
		for _, entry in entries do
			local candidate = route(entry, builder.LANE_OFFSET)
			local hasHill = false
			for _, point in candidate.Points do
				if math.abs(point.Y - candidate.Points[1].Y) > 5 then
					hasHill = true
					break
				end
			end
			if hasHill then
				testedHill = true
				center = route(entry, 0)
				controller.Handle(event(entry))
				for i = 0, 100 do
					controller.Update(0, map.Point(candidate, i / 100) + up)
					youCentered("hill_you_centered_" .. i)
				end
				break
			end
		end
		flag("hill_fixture_exercised", testedHill)
		local liveStart = event(first)
		liveStart.ServerStart = workspace:GetServerTimeNow() - 65
		remoteEvent:Fire(liveStart)
		-- A task.wait can resume before the first render callback processes Start.
		local renderDeadline = os.clock() + 1
		repeat
			task.wait()
		until hud.RaceMapTime.Text ~= "TIME 00:00.00" or os.clock() >= renderDeadline
		flag(
			"injected_remote_start_connected",
			card.Visible
				and hud.RaceMapTitle.Text
					== string.format("TRACK %d · %s", first.Number, string.upper(specs[1].Name))
		)
		local minutes, seconds, centiseconds = hud.RaceMapTime.Text:match("^TIME (%d+):(%d%d)%.(%d%d)$")
		local liveElapsed = minutes and tonumber(minutes) * 60 + tonumber(seconds) + tonumber(centiseconds) / 100
		-- Allow render scheduling/server-clock drift around the 65-second offset.
		flag(
			"render_connection_uses_server_clock",
			liveElapsed ~= nil and liveElapsed >= 64 and liveElapsed < 70,
			liveElapsed
		)
		remoteEvent:Fire({ Type = "Stop" })
		task.wait()
		flag("injected_remote_stop_connected", not card.Visible and #canvas:GetChildren() == 0)
		controller.Handle(event(first))
		controller.Destroy()
		flag("destroy_hides_and_cleans", not card.Visible and #canvas:GetChildren() == 0)
		local text = hud.RaceMapTime.Text
		remoteEvent:Fire(event(second))
		task.wait()
		controller.Handle(event(first))
		controller.Update(200, Vector3.zero)
		flag(
			"destroy_disconnects_remote_and_render",
			not card.Visible and #canvas:GetChildren() == 0 and hud.RaceMapTime.Text == text
		)
		local destroyAgain = pcall(controller.Destroy)
		flag("destroy_idempotent", destroyAgain)
	end, debug.traceback)
	if not ok then
		flag("client_test_completed", false, tostring(err))
	end
	if controller then
		controller.Destroy()
	end
	root:Destroy()
	return result
end

return Tests
