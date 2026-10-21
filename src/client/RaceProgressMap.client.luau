--!nonstrict
-- Client-only presentation for the private NPC race progress card.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcRacer = require(Shared.NpcRacer)
local RouteMath = require(Shared.RaceProgressMap)
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NpcRace")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local hud = gui:WaitForChild("RacerHud")
local map = hud:WaitForChild("RaceMap")
local face = map:FindFirstChild("Face") or map
local canvas = face:WaitForChild("RaceMapCanvas")
local canvasFace = canvas:FindFirstChild("Face") or canvas
local title = face:WaitForChild("RaceMapTitle")
local status = face:WaitForChild("RaceMapStatus")
local timeLabel = face:WaitForChild("RaceMapTime")
local pbLabel = face:WaitForChild("RaceMapPB")

local lanes = {}
for _, entry in NpcRacer.ChainEntries() do
	lanes[entry.Number] = NpcRacer.LanePath(entry)
end

local state = nil
local routeLines = {}
local youDot, npcDot
local function clearChildren()
	for _, child in canvasFace:GetChildren() do
		if child ~= youDot and child ~= npcDot then
			child:Destroy()
		end
	end
	routeLines = {}
end

local function dot(name, color, image)
	local item = Instance.new("ImageLabel")
	item.Name, item.Size, item.AnchorPoint = name, UDim2.fromOffset(18, 18), Vector2.new(0.5, 0.5)
	item.BackgroundColor3, item.BackgroundTransparency, item.Image = color, 0, image or ""
	item.ImageColor3, item.ZIndex = Color3.new(1, 1, 1), 8
	item.Parent = canvasFace
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(1, 0), item
	local caption = Instance.new("TextLabel")
	caption.Name, caption.Size, caption.Position = "Label", UDim2.fromOffset(34, 14), UDim2.fromOffset(-8, 15)
	caption.BackgroundTransparency, caption.Text, caption.TextSize = 1, name == "YouDot" and "YOU" or "NPC", 10
	caption.Font, caption.TextColor3, caption.TextStrokeTransparency = Enum.Font.GothamBold, Color3.new(1, 1, 1), 0
	caption.ZIndex, caption.Parent = 9, item
	return item
end

local function formatTime(seconds)
	seconds = math.max(0, seconds or 0)
	local minutes = math.floor(seconds / 60)
	return string.format("%02d:%05.2f", minutes, seconds - minutes * 60)
end

local function drawRoute(route)
	clearChildren()
	local previous
	for _, point in ipairs(route.Points) do
		local p = RouteMath.Normalized(route, point)
		local current = Vector2.new(p.X, p.Y)
		if previous then
			local delta = current - previous
			local line = Instance.new("Frame")
			line.AnchorPoint, line.Position = Vector2.new(0, 0.5), UDim2.fromScale(previous.X, previous.Y)
			line.Size = UDim2.fromOffset(delta.Magnitude * canvasFace.AbsoluteSize.X, 3)
			line.Rotation, line.BackgroundColor3, line.BorderSizePixel =
				math.deg(math.atan2(delta.Y, delta.X)), Color3.fromRGB(92, 181, 255), 0
			line.ZIndex, line.Parent = 3, canvasFace
			table.insert(routeLines, { Line = line, A = previous, B = current })
		end
		previous = current
	end
	youDot = dot("YouDot", Color3.fromRGB(60, 255, 120))
	npcDot = dot("NpcDot", Color3.fromRGB(255, 90, 100))
	local finish = Instance.new("Frame")
	finish.Name, finish.Size, finish.AnchorPoint = "Finish", UDim2.fromOffset(4, 28), Vector2.new(0.5, 0.5)
	local finishPoint = RouteMath.Normalized(route, route.Points[#route.Points])
	finish.Position, finish.BackgroundColor3, finish.ZIndex =
		UDim2.fromScale(finishPoint.X, finishPoint.Y), Color3.fromRGB(255, 232, 30), 4
	finish.Parent = canvasFace
	local ok, headshot = pcall(
		Players.GetUserThumbnailAsync,
		Players,
		player.UserId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size48x48
	)
	if ok and type(headshot) == "string" then
		youDot.Image = headshot
	end
end

local function setDot(item, route, progress)
	local p = RouteMath.Normalized(route, RouteMath.Point(route, progress))
	item.Position = UDim2.fromScale(p.X, p.Y)
end

local function hide()
	state = nil
	map.Visible = false
end

local function start(event)
	local path = lanes[event.Track]
	if not path then
		hide()
		return
	end
	local profile = NpcRacer.Profile(path, event.Speed)
	state = {
		Track = event.Track,
		Path = path,
		Route = RouteMath.Build(path),
		Profile = profile,
		ServerStart = event.ServerStart,
		Best = event.BestTime,
	}
	drawRoute(state.Route)
	title.Text = string.upper((event.Label or ("TRACK " .. tostring(event.Track))))
	pbLabel.Text = event.BestTime and "PB " .. formatTime(event.BestTime) or "PB --"
	map.Visible = true
end

remote.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" then
		return
	end
	if event.Type == "Start" then
		start(event)
	elseif event.Type == "Result" or event.Type == "Reset" or event.Type == "Stop" then
		hide()
	end
end)

local showcase = gui:WaitForChild("RollShowcase", 10)
if showcase then
	showcase:GetPropertyChangedSignal("Enabled"):Connect(function()
		if showcase.Enabled then
			hide()
		end
	end)
end

RunService.RenderStepped:Connect(function()
	if not state or not map.Visible then
		return
	end
	local elapsed = math.max(0, Workspace:GetServerTimeNow() - state.ServerStart)
	local npcProgress = math.clamp(elapsed / math.max(state.Profile.TotalTime, 1e-6), 0, 1)
	local car
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat then
		car = seat:FindFirstAncestorWhichIsA("Model")
	end
	local youProgress = car and RouteMath.Progress(state.Route, car:GetPivot().Position) or 0
	setDot(youDot, state.Route, youProgress)
	setDot(npcDot, state.Route, npcProgress)
	local difference = youProgress - npcProgress
	status.Text = math.abs(difference) < 0.01 and "EVEN" or (difference > 0 and "AHEAD" or "BEHIND")
	timeLabel.Text = "TIME " .. formatTime(elapsed)
	for _, segment in ipairs(routeLines) do
		local delta = segment.B - segment.A
		segment.Line.Size = UDim2.fromOffset(delta.Magnitude * canvasFace.AbsoluteSize.X, 3)
	end
end)

hide()
