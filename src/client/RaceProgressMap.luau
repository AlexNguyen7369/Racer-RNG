--!nonstrict
-- Attached after RacerHud.Bind so a stale StarterGui can never strand this view.
-- Look: docs/RACE_PROGRESS_MAP_SPEC.md "Look (owner 2026-10-27)"; theme and motion: docs/HUD_LAYOUT_SPEC.md 8 and 10.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcRacer = require(Shared.NpcRacer)
local NpcConfig = require(Shared.NpcConfig)
local CarConfig = require(Shared.CarConfig)
local TrackBuilder = require(Shared.TrackBuilder)
local TrackRegistry = require(Shared.TrackRegistry)
local RouteMath = require(Shared.RaceProgressMap)
local UiTheme = require(Shared.UiTheme)
local UiMotion = require(script.Parent.UiMotion)

local Controller = {}
local tracks = {}
local entries
local headshot
local UP = Vector3.new(0, CarConfig.RestHeight, 0)
local FLAT = Vector3.new(1, 0, 1)
local VIEW_SPAN = 260
local VIEW_MARGIN = 0.15 -- route kept this far (view fraction) outside the canvas; the edge fade hides it
local REBUILD_PX = 1.5
local REBUILD_COS = math.cos(math.rad(1.5))
local DRIVEN = Color3.fromRGB(164, 107, 255)
local AHEAD = Color3.fromRGB(61, 224, 255)
local FADE_IN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Palette = UiTheme.Palette

-- "track01_NPC" -> "T1 NPC"; any other label is cut to 10 characters.
local function shortName(label)
	local name = string.upper(tostring(label)):gsub("^TRACK0*(%d+)_", "T%1 ")
	return #name > 10 and name:sub(1, 9) .. "." or name
end

local function trackFor(number)
	if tracks[number] then
		return tracks[number]
	end
	if not entries then
		entries = NpcRacer.ChainEntries()
	end
	for _, entry in entries do
		if entry.Number == number then
			local function lane(offset)
				local path = TrackBuilder.RacePath(entry.Layout, offset)
				for i, point in path.Waypoints do
					path.Waypoints[i] = entry.Origin:PointToWorldSpace(point)
				end
				return RouteMath.Build(path)
			end
			local spec
			for _, candidate in TrackRegistry.Chain() do
				if candidate.Number == number then
					spec = candidate
				end
			end
			local npcPath = NpcRacer.LanePath(entry)
			tracks[number] = {
				Route = lane(0),
				PlayerRoute = lane(TrackBuilder.LANE_OFFSET),
				NpcRoute = RouteMath.Build(npcPath),
				NpcPath = npcPath,
				NpcName = shortName(NpcConfig.For(number).Label),
				Title = string.format("TRACK %d · %s", number, string.upper(spec and spec.Name or "RACE")),
			}
			return tracks[number]
		end
	end
	return nil
end

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	if object:IsA("GuiObject") then
		object.Active, object.Selectable = false, false
	end
	object.Parent = parent
	return object
end

-- Theme text: FredokaOne with the dark outline (HUD_LAYOUT_SPEC section 8).
local function text(name, parent, props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = UiTheme.Font
	props.TextColor3 = props.TextColor3 or Palette.White
	local label = make("TextLabel", name, parent, props)
	UiTheme.Stroke(label, 1.5)
	return label
end

-- Transparent at both ends of the gradient axis, so clipped road fades out at the canvas edge.
local function edgeFade(group, rotation)
	make("UIGradient", "EdgeFade", group, {
		Rotation = rotation,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.12, 0),
			NumberSequenceKeypoint.new(0.88, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
end

function Controller.Attach(hud, player, remote)
	player = player or Players.LocalPlayer
	remote = remote or ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NpcRace")
	local gui = hud.Gui.Parent
	-- RaceMap is a transparent spacer root. Keeping the root as the controller's
	-- visibility target also works with saved HUDs generated before this change.
	local card = hud.RaceMap
	local canvas = hud.RaceMapCanvas
	local status = hud.RaceMapStatus
	local state, view = nil, nil
	local connections = {}
	local destroyed = false
	local self = {}
	card.Active, card.Selectable = false, false
	canvas.ClipsDescendants = true
	-- Keep the metadata compact and edge-aligned like a kart-racing tactical HUD;
	-- the route itself remains the visual focus and stays completely transparent.
	hud.RaceMapTitle.TextXAlignment = Enum.TextXAlignment.Left
	status.TextXAlignment = Enum.TextXAlignment.Right
	hud.RaceMapTime.TextXAlignment = Enum.TextXAlignment.Left
	hud.RaceMapPB.TextXAlignment = Enum.TextXAlignment.Right
	-- The pill is a sibling under the status text (Sibling ZIndex: a child would cover the text). No card fill.
	local pill = card:FindFirstChild("StatusPill")
		or make("Frame", "StatusPill", card, {
			AnchorPoint = Vector2.new(1, 0.5),
			BorderSizePixel = 0,
			BackgroundColor3 = Palette.Muted,
			ZIndex = math.max(status.ZIndex - 1, 1),
		})
	if not pill:FindFirstChildOfClass("UICorner") then
		make("UICorner", "Pill", pill, { CornerRadius = UDim.new(1, 0) })
	end
	local fadeTargets = { { pill, "BackgroundTransparency", 0.15 } }
	for _, label in { hud.RaceMapTitle, status, hud.RaceMapTime, hud.RaceMapPB } do
		label.Font = UiTheme.Font
		local stroke = label:FindFirstChildOfClass("UIStroke") or UiTheme.Stroke(label, 1.5)
		table.insert(fadeTargets, { label, "TextTransparency", 0 })
		table.insert(fadeTargets, { stroke, "Transparency", 0 })
	end
	for _, object in card:GetDescendants() do
		if object:IsA("GuiObject") then
			object.Active, object.Selectable = false, false
		end
	end

	local function clear()
		for _, object in canvas:GetChildren() do
			object:Destroy()
		end
		view = nil
	end

	local function marker(name, caption, color)
		local size = name == "YouDot" and 22 or 18
		local dot = make("ImageLabel", name, canvas, {
			Size = UDim2.fromOffset(size, size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Image = "",
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 6,
		})
		make("UICorner", "Circle", dot, { CornerRadius = UDim.new(1, 0) })
		make("UIStroke", "Halo", dot, { Color = Palette.White, Transparency = 0.1, Thickness = 3 })
		make("UIStroke", "Ring", dot, { Color = color, Thickness = 2 })
		local label = text("Label", dot, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, size + 3),
			Size = UDim2.fromOffset(64, 14),
			Text = caption,
			TextSize = 11,
			ZIndex = 7,
		})
		return dot, label
	end

	local function canvasSize()
		local size = canvas.AbsoluteSize
		return Vector2.new(math.max(size.X, 1), math.max(size.Y, 1))
	end

	local function point(position, center, heading)
		return RouteMath.ViewPoint(position, center, heading, canvasSize(), VIEW_SPAN)
	end

	local function placeAt(object, position)
		local p = point(position, state.ViewPosition, state.Heading)
		object.Position = UDim2.fromScale(p.X, p.Y)
	end

	-- Rebuilds the three Path2D lines for the current view: only the stretch whose segments touch the view (plus
	-- margin), split exactly at the player's progress into driven (violet) and ahead (cyan).
	local function rebuildRoute()
		local route = state.Track.Route
		local center, heading = state.ViewPosition, state.Heading
		local views = table.create(#route.Points)
		for i, routePoint in route.Points do
			views[i] = point(routePoint, center, heading)
		end
		local lo, hi
		for i = 1, #views - 1 do
			local a, b = views[i], views[i + 1]
			-- Bounding-box overlap is conservative: a long straight crossing the view is never dropped.
			if
				math.max(a.X, b.X) >= -VIEW_MARGIN
				and math.min(a.X, b.X) <= 1 + VIEW_MARGIN
				and math.max(a.Y, b.Y) >= -VIEW_MARGIN
				and math.min(a.Y, b.Y) <= 1 + VIEW_MARGIN
			then
				lo = lo or i
				hi = i + 1
			end
		end
		local all, driven, ahead = {}, {}, {}
		if lo then
			local target = state.You * route.Total
			-- Path2D holds at most 100 control points: thin the visible run (99 + the split point per line).
			local step = math.ceil((hi - lo + 1) / 99)
			for i = lo, hi, step do
				local control = Path2DControlPoint.new(UDim2.fromScale(views[i].X, views[i].Y))
				table.insert(all, control)
				table.insert(route.Lengths[i] <= target and driven or ahead, control)
			end
			local split = point(RouteMath.Point(route, state.You), center, heading)
			local splitPoint = Path2DControlPoint.new(UDim2.fromScale(split.X, split.Y))
			table.insert(driven, splitPoint)
			table.insert(ahead, 1, splitPoint)
		end
		view.Outline:SetControlPoints(all)
		view.Driven:SetControlPoints(driven)
		view.Ahead:SetControlPoints(ahead)
		view.Center, view.Heading, view.Size = center, heading, canvasSize()
	end

	-- Lines only when the view moved or turned enough to matter; START / finish markers every call.
	local function drawGeometry(force)
		if not state or not view then
			return
		end
		local size = canvasSize()
		if
			force
			or not view.Center
			or (state.ViewPosition - view.Center).Magnitude * size.Y / VIEW_SPAN > REBUILD_PX
			or view.Heading:Dot(state.Heading) < REBUILD_COS
			or view.Size ~= size
		then
			rebuildRoute()
		end
		placeAt(view.Finish, RouteMath.Point(state.Track.Route, 1))
		placeAt(view.Start, RouteMath.Point(state.Track.Route, 0))
	end

	local function visible()
		local showcase = gui and gui:FindFirstChild("RollShowcase")
		return state ~= nil and hud.Gui.Enabled and not (showcase and showcase.Enabled)
	end

	local function setStatus(value)
		if status.Text == value then
			return
		end
		status.Text = value
		status.TextColor3 = Palette.White
		pill.BackgroundColor3 = value:sub(1, 5) == "AHEAD" and Palette.Ahead
			or (value:sub(1, 6) == "BEHIND" and Palette.Behind or Palette.Muted)
		-- Measured in offset units (not TextBounds) so it is right before the first render and under any UIScale.
		local width = TextService:GetTextSize(value, status.TextSize, status.Font, Vector2.new(1e4, 100)).X
		local height = status.Size.Y.Offset
		pill.Size = UDim2.fromOffset(width + 14, height + 2)
		pill.Position = status.Position + UDim2.fromOffset(status.Size.X.Offset + 7, height / 2)
	end

	-- Fade in on track start (instant while motion is reduced); there is no exit fade.
	local function fadeIn()
		local reduced = UiMotion.Reduced()
		for _, target in fadeTargets do
			local object, property, goal = target[1], target[2], target[3]
			if not reduced then
				object[property] = 1
			end
			UiMotion.Create(object, FADE_IN, { [property] = goal }):Play()
		end
		if not reduced then
			view.Fade.GroupTransparency = 1
			UiMotion.Create(view.Fade, FADE_IN, { GroupTransparency = 0 }):Play()
		end
	end

	function self.Handle(event)
		if destroyed or type(event) ~= "table" then
			return
		end
		if event.Type ~= "Start" then
			if event.Type == "Result" or event.Type == "Reset" or event.Type == "Stop" then
				-- Hidden and emptied at once: no exit animation may delay this hide (HUD_LAYOUT_SPEC section 10).
				state = nil
				card.Visible = false
				clear()
			end
			return
		end
		local track = trackFor(event.Track)
		if not track or type(event.ServerStart) ~= "number" or type(event.Speed) ~= "number" or event.Speed <= 0 then
			return
		end
		clear()
		local heading = (RouteMath.Point(track.PlayerRoute, 0.01) - RouteMath.Point(track.PlayerRoute, 0)) * FLAT
		state = {
			Track = track,
			Profile = NpcRacer.Profile(track.NpcPath, event.Speed),
			ServerStart = event.ServerStart,
			You = 0,
			Npc = 0,
			Elapsed = 0,
			ViewPosition = RouteMath.Point(track.PlayerRoute, 0),
			Heading = heading.Magnitude > 1e-6 and heading.Unit or Vector3.new(0, 0, -1),
		}
		-- Two nested CanvasGroups: the outer fades the left/right edges, the inner top/bottom.
		local fade = make("CanvasGroup", "RouteFade", canvas, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 1,
		})
		edgeFade(fade, 0)
		local fadeY = make("CanvasGroup", "RouteFadeY", fade, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		})
		edgeFade(fadeY, 90)
		local function line(name, color, thickness, z)
			return make("Path2D", name, fadeY, { Color3 = color, Thickness = thickness, ZIndex = z })
		end
		view = {
			Fade = fade,
			Outline = line("RouteOutline", UiTheme.Outline, 12, 1),
			Driven = line("RouteDriven", DRIVEN, 6, 2),
			Ahead = line("RouteAhead", AHEAD, 6, 2),
		}
		local you = marker("YouDot", "YOU", Palette.Ahead)
		-- The map is heading-up, so the chevron always points up.
		text("Heading", you, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, -2),
			Size = UDim2.fromOffset(14, 12),
			Text = "▲",
			TextSize = 12,
			ZIndex = 7,
		})
		local npcDot, npcLabel = marker("NpcDot", track.NpcName, Palette.Behind)
		text("Arrow", npcDot, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Text = "◆",
			TextSize = 10,
			ZIndex = 7,
		})
		view.You, view.Npc, view.NpcLabel = you, npcDot, npcLabel
		view.Start = text("Start", canvas, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(52, 20),
			BackgroundTransparency = 0.1,
			BackgroundColor3 = Palette.PanelDeep,
			Text = "START",
			TextSize = 12,
			ZIndex = 4,
		})
		make("UICorner", "Pill", view.Start, { CornerRadius = UDim.new(1, 0) })
		-- Checkered flag tile: 3x3 alternating squares with a dark outline.
		local finish = make("Frame", "Finish", canvas, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Palette.White,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 4,
		})
		UiTheme.Stroke(finish, 2, UiTheme.Outline, true)
		for row = 0, 2 do
			for column = 0, 2 do
				if (row + column) % 2 == 0 then
					make("Frame", "Square", finish, {
						Position = UDim2.fromScale(column / 3, row / 3),
						Size = UDim2.fromScale(1 / 3, 1 / 3),
						BackgroundColor3 = UiTheme.Outline,
						BorderSizePixel = 0,
						ZIndex = 4,
					})
				end
			end
		end
		view.Finish = finish
		you.Image = headshot or ""
		hud.RaceMapTitle.Text = track.Title
		hud.RaceMapPB.Text = type(event.BestTime) == "number" and "PB " .. RouteMath.FormatTime(event.BestTime)
			or "PB --"
		hud.RaceMapTime.Text = "TIME 00:00.00"
		status.Text = ""
		setStatus("EVEN")
		drawGeometry(true)
		card.Visible = visible()
		fadeIn()
	end

	function self.Update(elapsed, position, heading)
		if destroyed or not state then
			return
		end
		local dt = math.max(0, elapsed - state.Elapsed)
		local track = state.Track
		if typeof(position) == "Vector3" then
			local previous = state.Position or RouteMath.Point(track.PlayerRoute, 0) + UP
			state.You = RouteMath.Progress(
				track.PlayerRoute,
				position - UP,
				state.You,
				(position - previous).Magnitude * 2 + 32
			)
			state.Position = position
			state.ViewPosition = position - UP
			if typeof(heading) == "Vector3" and (heading * FLAT).Magnitude > 1e-6 then
				state.Heading = (heading * FLAT).Unit
			end
		end
		local npcPosition = NpcRacer.PoseAt(track.NpcPath, state.Profile, elapsed).Position - UP
		state.Npc = RouteMath.Progress(track.NpcRoute, npcPosition, state.Npc, state.Profile.Speed * dt * 1.1 + 32)
		state.Elapsed = elapsed
		view.You.Position = UDim2.fromScale(0.5, 0.5)
		local npcPoint = point(RouteMath.Point(track.Route, state.Npc), state.ViewPosition, state.Heading)
		local clamped = RouteMath.ClampViewPoint(npcPoint, 0.07)
		view.Npc.Position = UDim2.new(clamped.X, 0, clamped.Y, 3)
		view.NpcLabel.Position = UDim2.new(0.5, 0, 0, clamped.Y > 0.8 and -15 or 21)
		drawGeometry(false)
		local word = RouteMath.Status(state.You, state.Npc)
		if word == "EVEN" then
			setStatus(word)
		else
			-- Gap at the player's progress: the NPC's timeline there against the player's clock (presentation only).
			local npcTime = RouteMath.TimeAt(track.NpcRoute, state.Profile.Times, state.You)
			setStatus(string.format("%s %.1fs", word, math.abs(elapsed - npcTime)))
		end
		hud.RaceMapTime.Text = "TIME " .. RouteMath.FormatTime(elapsed)
		card.Visible = visible()
	end

	local function fit()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local right = camera.ViewportSize.Y <= 500 and 10 or 20
		local y = camera.ViewportSize.Y <= 500 and 64 or 68
		-- The map has a fixed authored anchor. It must not push the persistent HUD
		-- (especially the Backpack/Items entry) when a race starts.
		card.Position = UDim2.new(1, -right, 0, y)
	end
	function self.Destroy()
		destroyed, state = true, nil
		for _, connection in connections do
			connection:Disconnect()
		end
		clear()
		card.Visible = false
	end
	card.Visible = false
	table.insert(connections, remote.OnClientEvent:Connect(self.Handle))
	table.insert(
		connections,
		canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			drawGeometry(true)
		end)
	)
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			fit()
			if state then
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local seat = humanoid and humanoid.SeatPart
				local car = seat and seat:FindFirstAncestorOfClass("Model")
				local position = car and car:GetAttribute("AutoRace") and car:GetPivot().Position or nil
				local heading = car and car:GetPivot().LookVector or nil
				self.Update(math.max(0, workspace:GetServerTimeNow() - state.ServerStart), position, heading)
			end
		end)
	)
	-- Thumbnail lookup may yield; never suspend event handling or a newer track's draw.
	task.spawn(function()
		if not headshot then
			local ok, image = pcall(
				Players.GetUserThumbnailAsync,
				Players,
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size48x48
			)
			if ok and type(image) == "string" then
				headshot = image
			end
		end
		if not destroyed and view then
			view.You.Image = headshot or ""
		end
	end)
	return self
end

return Controller
