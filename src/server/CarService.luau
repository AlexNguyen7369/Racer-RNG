--!nonstrict
-- Replaces each player's avatar with their car. The Humanoid character still exists (Roblox needs it
-- for camera, respawn and input) but it is hidden and seated in the car's VehicleSeat, so the car
-- is the only thing anyone sees.
-- The "Stop Auto" / "Auto Race" button (Client/AutoRaceButton) fires Remotes.SetAutoRace: stopping removes the
-- car and puts the visible avatar on foot beside Track 1 (WalkSpawnCFrame); resuming spawns a fresh car at the
-- start. The player attribute AutoRacing is the state the button shows. The Speed stat lives in leaderstats,
-- so it is kept across both.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local CarFactory = require(Shared.CarFactory)
local PlayerData = require(script.Parent.PlayerData)
local RaceService = require(script.Parent.RaceService)
local TrackBuilder = require(Shared.TrackBuilder)

local CarService = {}

CarService.TOGGLE_COOLDOWN = 0.75 -- seconds between toggle requests from one player (remote only)

local WALK_CLEARANCE = 75 -- studs (horizontal) the walk spawn keeps from every race path waypoint
local WALK_ROOT_HEIGHT = 3 -- HumanoidRootPart height above the baseplate top when standing

local cars = {} -- player -> car model
local runs = {} -- player -> RaceService run
local characters = {} -- player -> character the car belongs to
local racing = {} -- player -> true / false (nil = never attached)
local generation = {} -- player -> number, bumped by every state change so stale attaches give up
local hidden = {} -- character -> { Parts = { [part] = props }, Added = connection }
local watched = setmetatable({}, { __mode = "k" }) -- character -> true once its death is handled
local lastToggle = {} -- player -> os.clock() of the last accepted remote request
local walkSpawn = nil

local function userIdOf(player)
	local ok, id = pcall(function()
		return player.UserId
	end)
	return ok and id or nil
end

local function hidePart(state, d)
	if d:IsA("BasePart") then
		if not state.Parts[d] then
			state.Parts[d] = { Transparency = d.Transparency, CanCollide = d.CanCollide, Massless = d.Massless }
		end
		d.Transparency = 1
		d.CanCollide = false
		d.Massless = true
	elseif d:IsA("Decal") then
		if not state.Parts[d] then
			state.Parts[d] = { Transparency = d.Transparency }
		end
		d.Transparency = 1
	end
end

local function hideCharacter(character)
	local state = hidden[character]
	if not state then
		state = { Parts = {} }
		hidden[character] = state
		-- Accessories that load after the character spawns are hidden too
		state.Added = character.DescendantAdded:Connect(function(d)
			hidePart(state, d)
		end)
	end
	for _, d in character:GetDescendants() do
		hidePart(state, d)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
	end
end

local function showCharacter(character)
	local state = hidden[character]
	if state then
		hidden[character] = nil
		state.Added:Disconnect()
		for d, props in state.Parts do
			if d.Parent then
				for k, v in props do
					d[k] = v
				end
			end
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
		humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
		humanoid.JumpPower = StarterPlayer.CharacterJumpPower
	end
end

local function spawnCFrame(index)
	local track = Workspace:FindFirstChild("Track")
	local start = track and track:FindFirstChild("Start", true) -- first track in the chain
	local base = start and start.CFrame or CFrame.new(0, 0, 0)
	local row = math.floor((index - 1) / 2)
	local col = (index - 1) % 2 == 0 and -1 or 1
	return base * CFrame.new(TrackBuilder.LANE_OFFSET + col * 4, CarConfig.RestHeight + 1, row * 9)
end

-- Where an avatar stands when auto race stops: on the baseplate beside the start of Track 1, clear of every road
-- (the nearest race path waypoint is at least WALK_CLEARANCE away).
function CarService.WalkSpawnCFrame()
	if walkSpawn then
		return walkSpawn
	end
	local track = Workspace:FindFirstChild("Track")
	local start = track and track:FindFirstChild("Start", true)
	local base = start and start.CFrame or CFrame.new(0, 0, 0)
	local route = RaceService.GetRoute()
	local wps = route and route.Path.WorldWaypoints or {}

	local function clearance(p)
		local best = math.huge
		for _, w in wps do
			best = math.min(best, Vector2.new(w.X - p.X, w.Z - p.Z).Magnitude)
		end
		return best
	end

	-- Behind the start line first (the chain runs away from it), then to either side
	local best, bestClear = nil, -1
	for _, offset in
		{
			Vector3.new(0, 0, 90),
			Vector3.new(-90, 0, 40),
			Vector3.new(90, 0, 40),
			Vector3.new(0, 0, 120),
			Vector3.new(-110, 0, 0),
			Vector3.new(110, 0, 0),
		}
	do
		local p = base:PointToWorldSpace(offset)
		local c = clearance(p)
		if c >= WALK_CLEARANCE then
			best = p
			break
		elseif c > bestClear then
			best, bestClear = p, c
		end
	end
	local pos = Vector3.new(best.X, WALK_ROOT_HEIGHT, best.Z)
	local look = Vector3.new(base.Position.X, pos.Y, base.Position.Z) -- facing the start
	walkSpawn = (look - pos).Magnitude > 1e-3 and CFrame.lookAt(pos, look) or CFrame.new(pos)
	return walkSpawn
end

local function removeCar(player)
	local run = runs[player]
	runs[player] = nil
	if run then
		run:Destroy() -- commits the Speed gained since the last commit
	end
	local car = cars[player]
	cars[player] = nil
	if car then
		car:Destroy()
	end
end

-- Spawns the car, hides the character and seats it. Gives up (leaving cleanup to whoever bumped the generation)
-- as soon as a newer request arrives.
local function spawnCar(player, character, gen)
	removeCar(player)
	local humanoid = character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")
	if generation[player] ~= gen then
		return
	end
	hideCharacter(character)

	local index = 1
	for i, p in Players:GetPlayers() do
		if p == player then
			index = i
		end
	end

	local car = CarFactory.build(CarConfig)
	car:PivotTo(spawnCFrame(index))
	car.Parent = Workspace
	cars[player] = car
	car:SetAttribute("Owner", userIdOf(player))

	local seat = car:FindFirstChild("DriverSeat")
	local chassis = car.PrimaryPart
	local run = RaceService.Attach(player, car)
	runs[player] = run
	if not run then
		chassis:SetNetworkOwner(player) -- no race route: manual driving, the client steps the physics
	end

	for _ = 1, 5 do
		character:PivotTo(seat.CFrame * CFrame.new(0, 2, 0))
		seat:Sit(humanoid)
		task.wait(0.1)
		if generation[player] ~= gen then
			return
		end
		if humanoid.SeatPart == seat then
			break
		end
	end
end

-- Puts the avatar back on its feet at the walk spawn, visible and able to walk.
local function standUp(player)
	local character = characters[player]
	removeCar(player)
	if not character or not character.Parent then
		return
	end
	showCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
	end
	character:PivotTo(CarService.WalkSpawnCFrame())
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.AssemblyLinearVelocity = Vector3.zero
			d.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function isAlive(character)
	local humanoid = character and character.Parent and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Makes `character` the player's current avatar, dropping what was kept for the previous one.
local function adopt(player, character)
	local old = characters[player]
	if old and old ~= character and hidden[old] then
		hidden[old].Added:Disconnect()
		hidden[old] = nil
	end
	characters[player] = character
	-- The car goes when the avatar dies, however it got the car (joined racing, or resumed after walking)
	if not watched[character] then
		watched[character] = true
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Once(function()
			if characters[player] == character then
				removeCar(player)
			end
		end)
	end
end

local function setState(player, enabled)
	racing[player] = enabled
	generation[player] = (generation[player] or 0) + 1
	player:SetAttribute("AutoRacing", enabled)
	return generation[player]
end

-- Gives `character` a car and starts auto racing it.
function CarService.Attach(player, character)
	adopt(player, character)
	local gen = setState(player, true)
	spawnCar(player, character, gen)
end

function CarService.IsAutoRacing(player)
	return racing[player] == true
end

function CarService.GetCar(player)
	return cars[player]
end

function CarService.GetRun(player)
	return runs[player]
end

-- Turns auto race on (fresh car at the start) or off (avatar on foot beside the track). Returns the state.
-- Anything but a boolean is ignored. The last request wins, even while an earlier one is still seating.
function CarService.SetAutoRace(player, enabled)
	if type(enabled) ~= "boolean" or enabled == CarService.IsAutoRacing(player) then
		return CarService.IsAutoRacing(player)
	end
	local character = characters[player]
	if enabled and not isAlive(character) then
		return CarService.IsAutoRacing(player) -- no avatar to seat (dead or not spawned yet)
	end
	local gen = setState(player, enabled)
	if enabled then
		spawnCar(player, character, gen)
	else
		standUp(player)
	end
	return CarService.IsAutoRacing(player)
end

local function forget(player)
	removeCar(player)
	local character = characters[player]
	if character and hidden[character] then
		hidden[character].Added:Disconnect()
		hidden[character] = nil
	end
	characters[player] = nil
	racing[player] = nil
	generation[player] = nil
	lastToggle[player] = nil
end

function CarService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local remote = remotes:FindFirstChild("SetAutoRace")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "SetAutoRace"
		remote.Parent = remotes
	end
	remote.OnServerEvent:Connect(function(player, enabled)
		if type(enabled) ~= "boolean" then
			return
		end
		local now = os.clock()
		if lastToggle[player] and now - lastToggle[player] < CarService.TOGGLE_COOLDOWN then
			return
		end
		lastToggle[player] = now
		CarService.SetAutoRace(player, enabled)
	end)

	local function onCharacter(player, character)
		if racing[player] == false then
			-- Respawned while on foot: stay on foot, beside the track
			adopt(player, character)
			character:WaitForChild("HumanoidRootPart")
			character:PivotTo(CarService.WalkSpawnCFrame())
		else
			CarService.Attach(player, character)
		end
	end
	local function onPlayer(player)
		player.CameraMinZoomDistance = 10
		player.CameraMaxZoomDistance = 40
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	PlayerData.OnLeaving(forget) -- before the leave save, so the run's last Speed gain is saved
	Players.PlayerRemoving:Connect(forget)
end

return CarService
