--!nonstrict
-- Attached after RacerHud.Bind so a stale StarterGui can never strand this view.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcRacer = require(Shared.NpcRacer)
local CarConfig = require(Shared.CarConfig)
local TrackBuilder = require(Shared.TrackBuilder)
local TrackRegistry = require(Shared.TrackRegistry)
local RouteMath = require(Shared.RaceProgressMap)

local Controller = {}
local tracks = {}
local entries
local headshot
local UP = Vector3.new(0, CarConfig.RestHeight, 0)
local VIEW_SPAN = 260

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
	object.Parent = parent
	return object
end

function Controller.Attach(hud, player, remote)
	player = player or Players.LocalPlayer
	remote = remote or ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NpcRace")
	local gui = hud.Gui.Parent
	-- RaceMap is a transparent spacer root. Keeping the root as the controller's
	-- visibility target also works with saved HUDs generated before this change.
	local card = hud.RaceMap
	local canvas = hud.RaceMapCanvas
	local state, routeFrames, dots, finish = nil, {}, {}, nil
	local connections = {}
	local destroyed = false
	local self = {}
	card.Active, card.Selectable = false, false
	canvas.ClipsDescendants = true
	for _, object in card:GetDescendants() do
		if object:IsA("GuiObject") then
			object.Active, object.Selectable = false, false
		end
	end

	local function clear()
		for _, object in canvas:GetChildren() do
			object:Destroy()
		end
		routeFrames, dots, finish = {}, {}, nil
	end

	local function marker(name, caption, color)
		local dot = make("ImageLabel", name, canvas, {
			Size = UDim2.fromOffset(16, 16),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Image = "",
			ZIndex = 6,
		})
		make("UICorner", "Circle", dot, { CornerRadius = UDim.new(1, 0) })
		make("UIStroke", "Ring", dot, { Color = color, Thickness = 2 })
		make("TextLabel", "Label", dot, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, caption == "YOU" and -13 or 17),
			Size = UDim2.fromOffset(30, 11),
			BackgroundTransparency = 1,
			Text = caption,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0,
			ZIndex = 7,
		})
		return dot
	end

	local function canvasSize()
		local size = canvas.AbsoluteSize
		return Vector2.new(math.max(size.X, 1), math.max(size.Y, 1))
	end

	local function point(position, center, heading)
		return RouteMath.ViewPoint(position, center, heading, canvasSize(), VIEW_SPAN)
	end

	local function drawGeometry()
		if not state then
			return
		end
		local center = state.ViewPosition
		local heading = state.Heading
		local size = canvasSize()
		for i, segment in routeFrames do
			local a = point(state.Track.Route.Points[i], center, heading)
			local b = point(state.Track.Route.Points[i + 1], center, heading)
			local delta = Vector2.new((b.X - a.X) * size.X, (b.Y - a.Y) * size.Y)
			segment.Position = UDim2.fromScale((a.X + b.X) / 2, (a.Y + b.Y) / 2)
			segment.Size = UDim2.fromOffset(math.max(delta.Magnitude, 1), 3)
			segment.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		end
		local endPoint = point(RouteMath.Point(state.Track.Route, 1), center, heading)
		finish.Position = UDim2.fromScale(endPoint.X, endPoint.Y)
	end

	local function visible()
		local showcase = gui and gui:FindFirstChild("RollShowcase")
		return state ~= nil and hud.Gui.Enabled and not (showcase and showcase.Enabled)
	end

	function self.Handle(event)
		if destroyed or type(event) ~= "table" then
			return
		end
		if event.Type ~= "Start" then
			if event.Type == "Result" or event.Type == "Reset" or event.Type == "Stop" then
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
		state = {
			Track = track,
			Profile = NpcRacer.Profile(track.NpcPath, event.Speed),
			ServerStart = event.ServerStart,
			You = 0,
			Npc = 0,
			Elapsed = 0,
			ViewPosition = RouteMath.Point(track.PlayerRoute, 0),
			Heading = RouteMath.Point(track.PlayerRoute, 0.01) - RouteMath.Point(track.PlayerRoute, 0),
		}
		for _ = 1, #track.Route.Points - 1 do
			table.insert(
				routeFrames,
				make("Frame", "RouteSegment", canvas, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.fromRGB(100, 183, 235),
					BorderSizePixel = 0,
					ZIndex = 2,
				})
			)
		end
		dots.You = marker("YouDot", "YOU", Color3.fromRGB(64, 255, 144))
		dots.Npc = marker("NpcDot", "NPC", Color3.fromRGB(255, 102, 117))
		finish = make("TextLabel", "Finish", canvas, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(16, 14),
			Text = "▥",
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 231, 105),
			TextSize = 16,
			Font = Enum.Font.GothamBold,
			ZIndex = 4,
		})
		dots.You.Image = headshot or ""
		hud.RaceMapTitle.Text = track.Title
		hud.RaceMapPB.Text = type(event.BestTime) == "number" and "PB " .. RouteMath.FormatTime(event.BestTime)
			or "PB --"
		hud.RaceMapTime.Text, hud.RaceMapStatus.Text = "TIME 00:00.00", "EVEN"
		drawGeometry()
		card.Visible = visible()
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
			if typeof(heading) == "Vector3" and Vector3.new(heading.X, 0, heading.Z).Magnitude > 1e-6 then
				state.Heading = Vector3.new(heading.X, 0, heading.Z).Unit
			end
		end
		local npcPosition = NpcRacer.PoseAt(track.NpcPath, state.Profile, elapsed).Position - UP
		state.Npc = RouteMath.Progress(track.NpcRoute, npcPosition, state.Npc, state.Profile.Speed * dt * 1.1 + 32)
		state.Elapsed = elapsed
		dots.You.Position = UDim2.fromScale(0.5, 0.5)
		local npcPoint = point(RouteMath.Point(track.Route, state.Npc), state.ViewPosition, state.Heading)
		local clamped = RouteMath.ClampViewPoint(npcPoint, 0.07)
		dots.Npc.Position = UDim2.new(clamped.X, 0, clamped.Y, 3)
		local npcLabel = dots.Npc:FindFirstChild("Label")
		if npcLabel then
			npcLabel.Position = UDim2.new(0.5, 0, 0, clamped.Y > 0.8 and -13 or 17)
		end
		drawGeometry()
		hud.RaceMapStatus.Text = RouteMath.Status(state.You, state.Npc)
		hud.RaceMapStatus.TextColor3 = state.You - state.Npc >= 0.01 and Color3.fromRGB(100, 255, 160)
			or (state.Npc - state.You >= 0.01 and Color3.fromRGB(255, 142, 145) or Color3.new(1, 1, 1))
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
	table.insert(connections, canvas:GetPropertyChangedSignal("Size"):Connect(drawGeometry))
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
		if not destroyed and dots.You then
			dots.You.Image = headshot or ""
		end
	end)
	return self
end

return Controller
