--!nonstrict
-- Replaces each player's avatar with their car. The Humanoid character still exists (Roblox needs it
-- for camera, respawn and input) but it is hidden and seated in the car's VehicleSeat, so the car
-- is the only thing anyone sees.
-- Players join and respawn ON FOOT in the spawn area (Shared/SpawnArea, docs/SPAWN_AND_ROLLS_SPEC.md). The
-- "Auto Race" button (Client/AutoRaceButton, Remotes.SetAutoRace) or walking onto the StartPad spawns a fresh car at
-- the start; "Stop Auto" ends the run, removes the car and puts the visible avatar back in
-- the spawn area (WalkSpawnCFrame). The player attribute AutoRacing is the state the button shows. The Speed stat
-- lives in leaderstats, so it is kept across both.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local CarFactory = require(Shared.CarFactory)
local CarAppearance = require(Shared.CarAppearance)
local CarCatalog = require(Shared.CarCatalog)
local MountConfig = require(Shared.MountConfig)
local SpawnArea = require(Shared.SpawnArea)
local PlayerData = require(script.Parent.PlayerData)
local RaceService = require(script.Parent.RaceService)
local UpgradeService = require(script.Parent.UpgradeService)
local TrackBuilder = require(Shared.TrackBuilder)
local VehicleEffects = require(Shared.VehicleEffects)

local CarService = {}

CarService.TOGGLE_COOLDOWN = 0.75 -- seconds between toggle requests from one player (remote only)
CarService.SPRINT_MULTI = 1.5 -- on-foot WalkSpeed multiplier while Shift is held (docs/SPRINT_SPEC.md, placeholder)

local HIDDEN_GROUP = "HiddenAvatar" -- the hidden avatar while it rides: collides with nothing
local UNSEAT_TIMEOUT = 1 -- most seconds Stop waits for the Humanoid to leave the seat
local SEAT_TIMEOUT = 3 -- most seconds a start waits for the avatar to be seated before it gives up (no race)
local SEAT_SLACK = 6 -- studs the seated avatar's root may be from the seat to count as teleported in
local PLACE_HOLD = 2 -- seconds the server keeps putting a real player's avatar back at the walk spawn after a teleport
local PLACE_SLACK = 8 -- studs (horizontal) the avatar may be from the walk spawn before it is put back

local cars = {} -- player -> car model
local runs = {} -- player -> RaceService run
local characters = {} -- player -> character the car belongs to
local racing = {} -- player -> true / false (nil = never attached)
local generation = {} -- player -> number, bumped by every state change so stale attaches give up
local hidden = {} -- character -> { Parts = { [part] = props }, Added = connection }
local watched = setmetatable({}, { __mode = "k" }) -- character -> true once its death is handled
local lastToggle = {} -- player -> os.clock() of the last accepted remote request
local lastPadStart = {} -- player -> os.clock() of the last stop or StartPad start (StartPad cooldown)
local sprinting = {} -- player -> true while they hold Shift
local mounts = {} -- player -> { Car, Humanoid, HipHeight, SpeedMulti } while they ride (docs/MOUNT_SPEC.md)
local lastMountToggle = {} -- player -> os.clock() of the last accepted ride toggle

local DUEL_SLOT_GAP = 8 -- studs between the two held duel cars (the road is 40 wide)

local function userIdOf(player)
	local ok, id = pcall(function()
		return player.UserId
	end)
	return ok and id or nil
end

local function hidePart(state, d)
	if d:IsA("BasePart") then
		if not state.Parts[d] then
			state.Parts[d] = {
				Transparency = d.Transparency,
				CanCollide = d.CanCollide,
				Massless = d.Massless,
				CollisionGroup = d.CollisionGroup,
			}
		end
		d.Transparency = 1
		d.CanCollide = false
		d.Massless = true
		-- A seated Humanoid turns its torso collision back on: its own group, collidable with nothing, keeps the
		-- hidden avatar from ever touching a car or the track
		d.CollisionGroup = HIDDEN_GROUP
	elseif d:IsA("Decal") then
		if not state.Parts[d] then
			state.Parts[d] = { Transparency = d.Transparency }
		end
		d.Transparency = 1
	end
end

local hiddenGroupReady = false
local function ensureHiddenGroup()
	if hiddenGroupReady then
		return
	end
	hiddenGroupReady = true
	pcall(function()
		PhysicsService:RegisterCollisionGroup(HIDDEN_GROUP)
	end)
	for _, other in PhysicsService:GetRegisteredCollisionGroups() do
		pcall(function()
			PhysicsService:CollisionGroupSetCollidable(HIDDEN_GROUP, other.name, false)
		end)
	end
end

local function hideCharacter(character)
	ensureHiddenGroup()
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

-- On-foot WalkSpeed: the player's Walkspeed upgrade tier (UpgradeService), raised while sprinting and while riding;
-- the StarterPlayer default for fakes.
local function walkSpeedOf(player)
	if typeof(player) == "Instance" then
		local speed = UpgradeService.WalkSpeed(player)
		if sprinting[player] then
			speed *= CarService.SPRINT_MULTI
		end
		local mount = mounts[player]
		return mount and math.min(speed * mount.SpeedMulti, MountConfig.MAX_SPEED) or speed
	end
	return StarterPlayer.CharacterWalkSpeed
end

local function showCharacter(character, player)
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
		humanoid.WalkSpeed = walkSpeedOf(player)
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

-- Where an avatar stands on foot (join, respawn, after Stop): the middle of the spawn area beside Track 1.
function CarService.WalkSpawnCFrame()
	local track = Workspace:FindFirstChild("Track")
	local start = track and track:FindFirstChild("Start", true) -- first track in the chain
	return SpawnArea.WalkCFrame(start and start.CFrame or CFrame.new(0, 0, 0))
end

-- Puts the avatar at the walk spawn. A real player's client owns its character's physics and, right after it leaves
-- the car, can send back its old position (beside where the car was) and undo a single server teleport: for
-- PLACE_HOLD seconds the avatar is put back whenever it is far from the spot (unless a newer request arrived).
local function placeAtWalkSpawn(player, character, gen, target)
	target = target or CarService.WalkSpawnCFrame()
	character:PivotTo(target)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.AssemblyLinearVelocity = Vector3.zero
			d.AssemblyAngularVelocity = Vector3.zero
		end
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return -- fake players (tests) have no client to undo the teleport
	end
	task.spawn(function()
		local deadline = os.clock() + PLACE_HOLD
		while os.clock() < deadline and generation[player] == gen and character.Parent do
			RunService.Heartbeat:Wait()
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local off = root.Position - target.Position
				if Vector2.new(off.X, off.Z).Magnitude > PLACE_SLACK then
					character:PivotTo(target)
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
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

local function setState(player, enabled)
	racing[player] = enabled
	generation[player] = (generation[player] or 0) + 1
	player:SetAttribute("AutoRacing", enabled)
	if not enabled then
		player:SetAttribute("RaceEvent", "Off")
	end
	return generation[player]
end

local standUp -- forward declaration (defined below)

-- Really seated: Humanoid.SeatPart alone can stay set after the weld is gone, so the seat must also name this
-- Humanoid as its Occupant and a live SeatWeld must join the seat to the character, with the root next to the seat.
local function seatedIn(humanoid, character, seat)
	local root = character:FindFirstChild("HumanoidRootPart")
	local weld = seat:FindFirstChild("SeatWeld")
	return humanoid.SeatPart == seat
		and seat.Occupant == humanoid
		and weld ~= nil
		and weld:IsA("Weld")
		and weld.Part1 ~= nil
		and weld.Part1:IsDescendantOf(character)
		and root ~= nil
		and (root.Position - seat.Position).Magnitude <= SEAT_SLACK
end

-- Takes the Humanoid out of its seat now: Sit = false alone can leave a stale SeatPart (even to a destroyed seat),
-- leaving the seated state clears it.
local function unseat(humanoid)
	humanoid.Sit = false
	if humanoid.SeatPart then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

-- Takes the player off their ridden car (docs/MOUNT_SPEC.md). WalkSpeed is left for the caller to refresh.
local function dismount(player)
	local mount = mounts[player]
	if not mount then
		return
	end
	mounts[player] = nil
	mount.Car:Destroy()
	if mount.Humanoid.Parent then
		mount.Humanoid.HipHeight = mount.HipHeight
	end
	player:SetAttribute("Mounted", false)
end

-- The race is an event in three steps, so nothing drives before the player is really in the car:
--   1. the car is built at the start line and held there (chassis anchored: nothing can drag it, not even a client
--      that still reports its avatar where it stood a moment ago);
--   2. the avatar is teleported into the seat until the server sees it seated, next to the seat;
--   3. only then the car is released and RaceService starts the race (driver, NPC race, Speed gain).
-- The player attribute RaceEvent shows the step: "Teleporting" during 1-2, "Racing" from 3, "Off" on foot.
-- If the avatar can not be seated within SEAT_TIMEOUT the race never starts and the player is put back on foot.
-- Gives up (leaving cleanup to whoever bumped the generation) as soon as a newer request arrives.
-- Duel mode (duel = { Track, Slot, OnSeated }, docs/DUEL_SPEC.md): the car waits at the picked track's start and
-- stays held after step 2; OnSeated() is called and CarService.ReleaseDuel starts the race. Slot 2 waits
-- DUEL_SLOT_GAP studs to the left: two cars held on one spot let each seat take the other player's avatar.
local function spawnCar(player, character, gen, duel)
	removeCar(player)
	dismount(player)
	local humanoid = character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")
	if generation[player] ~= gen then
		return
	end
	player:SetAttribute("RaceEvent", "Teleporting")
	hideCharacter(character)

	local index = 1
	for i, p in Players:GetPlayers() do
		if p == player then
			index = i
		end
	end

	-- 1. The car waits at the start line, held in place
	local start = spawnCFrame(index)
	if duel then
		start = RaceService.TrackStartCFrame(duel.Track) * CFrame.new(-DUEL_SLOT_GAP * ((duel.Slot or 1) - 1), 0, 0)
	elseif RaceService.StartTrackFor(player) > 1 then
		start = RaceService.TrackStartCFrame(RaceService.StartTrackFor(player)) or start -- checkpoint (CHECKPOINT_SPEC)
	end
	local car = CarFactory.build(CarConfig)
	if duel then
		RaceService.SetCarGroup(car) -- the release puts both cars on the same lane
		-- Held through the countdown with its driver seated: without this the client's CarController takes the car
		-- for a manual one until the release (its R key would lift the car on that client only)
		car:SetAttribute("AutoRace", true)
	end
	CarAppearance.Apply(car, player:GetAttribute("EquippedCar"), CarConfig)
	VehicleEffects.Apply(car, player)
	car:PivotTo(start)
	local chassis = car.PrimaryPart
	chassis.Anchored = true
	car.Parent = Workspace
	cars[player] = car
	car:SetAttribute("Owner", userIdOf(player))
	local seat = car:FindFirstChild("DriverSeat")

	-- 2. Teleport the avatar into the seat until the server sees it there
	local deadline = os.clock() + SEAT_TIMEOUT
	while not seatedIn(humanoid, character, seat) do
		if generation[player] ~= gen or cars[player] ~= car then
			return
		end
		if os.clock() > deadline or humanoid.Health <= 0 then
			-- Never seated: no race; back on foot in the spawn area
			setState(player, false)
			standUp(player, generation[player])
			return
		end
		character:PivotTo(seat.CFrame * CFrame.new(0, 2, 0))
		-- Teleport first, sit a frame later: a Stop right after the start cancels before any Sit. Sit is only asked
		-- of a Humanoid that is in no seat and of a seat that can take it: repeated Sit calls that never weld can
		-- leave Humanoid.SeatPart stuck, which nothing clears.
		RunService.Heartbeat:Wait()
		if generation[player] ~= gen or cars[player] ~= car then
			return
		end
		if humanoid.SeatPart == nil and not seat.Disabled then
			seat:Sit(humanoid)
		end
		task.wait(0.1)
	end
	if generation[player] ~= gen or cars[player] ~= car then
		return
	end

	if duel then
		car:PivotTo(start)
		duel.OnSeated()
		return
	end

	-- 3. Release the car at the start line and start the race
	car:PivotTo(start)
	chassis.Anchored = false
	local run = RaceService.Attach(player, car)
	runs[player] = run
	if not run then
		chassis:SetNetworkOwner(player) -- no race route: manual driving, the client steps the physics
	end
	player:SetAttribute("RaceEvent", "Racing")
end

-- Puts the avatar back on its feet at the walk spawn, visible and able to walk.
function standUp(player, gen)
	local character = characters[player]
	-- Unseat before the car goes: removing the SeatWeld clears SeatPart now, not a physics step later
	local car = cars[player]
	local seat = car and car:FindFirstChild("DriverSeat")
	local weld = seat and seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	local humanoid0 = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid0 then
		unseat(humanoid0)
	end
	removeCar(player)
	if not character or not character.Parent then
		return
	end
	showCharacter(character, player)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		unseat(humanoid)
	end
	placeAtWalkSpawn(player, character, gen)
	-- The Humanoid clears SeatPart on its own step, which can lag a few frames under load: Stop returns only once
	-- the avatar is really on foot (unless a newer request arrived meanwhile)
	if humanoid then
		local deadline = os.clock() + UNSEAT_TIMEOUT
		while humanoid.SeatPart and os.clock() < deadline and generation[player] == gen do
			RunService.Heartbeat:Wait()
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
				dismount(player)
			end
		end)
	end
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

-- The avatar CarService knows for this player (Attach / OnCharacter), else a real player's Character.
function CarService.GetCharacter(player)
	local character = characters[player]
	if character and character.Parent then
		return character
	end
	if typeof(player) == "Instance" and player:IsA("Player") then
		return player.Character
	end
	return nil
end

function CarService.GetRun(player)
	return runs[player]
end

-- Turns auto race on (fresh car at the start) or off (avatar on foot beside the track). Returns the state.
-- Anything but a boolean is ignored. The last request wins, even while an earlier one is still seating.
-- `duel` (server only, DuelService): see spawnCar.
function CarService.SetAutoRace(player, enabled, duel)
	if type(enabled) ~= "boolean" or enabled == CarService.IsAutoRacing(player) then
		return CarService.IsAutoRacing(player)
	end
	local character = characters[player]
	if enabled and not isAlive(character) then
		return CarService.IsAutoRacing(player) -- no avatar to seat (dead or not spawned yet)
	end
	local gen = setState(player, enabled)
	lastPadStart[player] = os.clock() -- the StartPad waits START_COOLDOWN after any start or stop
	if enabled then
		spawnCar(player, character, gen, duel)
	else
		standUp(player, gen) -- removing the car destroys its run; NPC wins were already paid at each finish
	end
	return CarService.IsAutoRacing(player)
end

-- Puts the avatar on foot at cf (admin /tp vfxarea and /tp home, ADMIN_COMMANDS_SPEC): stops auto racing first,
-- then holds it there like the walk spawn. False when there is no live avatar.
function CarService.Teleport(player, cf)
	local character = CarService.GetCharacter(player)
	if not isAlive(character) then
		return false
	end
	if CarService.IsAutoRacing(player) then
		CarService.SetAutoRace(player, false)
	end
	local gen = setState(player, false) -- a new generation ends the walk-spawn hold of that Stop
	lastPadStart[player] = os.clock()
	placeAtWalkSpawn(player, character, gen, cf)
	return true
end

-- Releases a held duel car and starts its duel run (duel = { Track, OnFinish }). Returns the run, or nil.
function CarService.ReleaseDuel(player, duel)
	local car = cars[player]
	local route = RaceService.GetRoute()
	if not (car and car.PrimaryPart and route and racing[player] == true) or runs[player] then
		return nil
	end
	car.PrimaryPart.Anchored = false
	local run = RaceService.NewRun(car, route, player, { Duel = duel })
	runs[player] = run
	player:SetAttribute("RaceEvent", "Racing")
	return run
end

-- A part touched the StartPad: if it belongs to `player`'s living, visible avatar that is on foot, auto racing
-- starts (unless the player stopped or started less than SpawnArea.START_COOLDOWN ago). Returns true if it started.
function CarService.PadTouched(player, hit)
	if player == nil or racing[player] == true or typeof(hit) ~= "Instance" then
		return false
	end
	local character = characters[player]
	if not isAlive(character) or hidden[character] or not hit:IsDescendantOf(character) then
		return false
	end
	local last = lastPadStart[player]
	if last and os.clock() - last < SpawnArea.START_COOLDOWN then
		return false
	end
	return CarService.SetAutoRace(player, true)
end

-- A new avatar (join or respawn) is always on foot in the spawn area: any car left is removed (its run cashes out).
function CarService.OnCharacter(player, character)
	adopt(player, character)
	local gen = setState(player, false)
	removeCar(player)
	dismount(player)
	if player:GetAttribute("Unbanked") == nil then
		player:SetAttribute("Unbanked", 0) -- the HUD's UNBANKED row reads it from the start
	end
	character:WaitForChild("HumanoidRootPart")
	if generation[player] ~= gen then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = walkSpeedOf(player)
	end
	placeAtWalkSpawn(player, character, gen)
end

local function forget(player)
	removeCar(player)
	dismount(player)
	local character = characters[player]
	if character and hidden[character] then
		hidden[character].Added:Disconnect()
		hidden[character] = nil
	end
	characters[player] = nil
	racing[player] = nil
	generation[player] = nil
	lastToggle[player] = nil
	lastPadStart[player] = nil
	sprinting[player] = nil
	lastMountToggle[player] = nil
end

-- Re-applies WalkSpeed to an avatar on foot (a hidden, riding avatar keeps WalkSpeed 0).
local function refreshWalkSpeed(player)
	local character = characters[player]
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and not hidden[character] then
		humanoid.WalkSpeed = walkSpeedOf(player)
	end
end

-- Puts the avatar on top of its equipped car: a cosmetic welded under the root that moves with normal walking.
-- HipHeight lifts the avatar to the car's roof. Returns true when the player is riding.
local function mountCar(player)
	local character = characters[player]
	if racing[player] == true or not isAlive(character) or hidden[character] then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local id = player:GetAttribute("EquippedCar")
	local car = CarFactory.build(CarConfig)
	car.Name = "MountedCar"
	car:SetAttribute("IsCar", nil)
	car.DriverSeat:Destroy() -- nothing may sit the avatar down: it keeps walking
	CarAppearance.Apply(car, id, CarConfig)
	VehicleEffects.Apply(car, player)

	local chassis = car.PrimaryPart
	chassis.CanCollide = false
	chassis.CanTouch = false
	chassis.CanQuery = false
	chassis.Massless = true
	chassis.RootPriority = -127

	-- The car is still at the origin here, with its chassis RestHeight above the ground
	local boxCFrame, boxSize = (car:FindFirstChild("EquippedVisual") or car):GetBoundingBox()
	local seatHeight = math.min(boxCFrame.Y + boxSize.Y / 2 + CarConfig.RestHeight, MountConfig.MAX_SEAT_HEIGHT)
	local hipHeight = humanoid.HipHeight
	humanoid.HipHeight = seatHeight

	-- Move the whole car first: its welds fix their offsets when it enters the Workspace
	local offset = CFrame.new(0, CarConfig.RestHeight - seatHeight - root.Size.Y / 2, 0)
	car:PivotTo(root.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Name = "MountWeld"
	weld.Part0 = root
	weld.Part1 = chassis
	weld.C0 = offset
	weld.Parent = chassis
	CollectionService:AddTag(car, MountConfig.TAG)
	car.Parent = Workspace

	local spec = CarCatalog.Get(id)
	mounts[player] = {
		Car = car,
		Humanoid = humanoid,
		HipHeight = hipHeight,
		SpeedMulti = MountConfig.SpeedMulti(spec and spec.SpeedMulti),
	}
	player:SetAttribute("Mounted", true)
	return true
end

-- Rides or gets off the equipped car. Returns whether the player is riding.
function CarService.SetMounted(player, enabled)
	if enabled and not mounts[player] then
		mountCar(player)
	elseif not enabled then
		dismount(player)
	end
	refreshWalkSpeed(player)
	return mounts[player] ~= nil
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

	-- No cooldown: a dropped release would leave the player stuck sprinting, and the server sets the speed either way.
	local sprintRemote = remotes:FindFirstChild("SetSprint")
	if not sprintRemote then
		sprintRemote = Instance.new("RemoteEvent")
		sprintRemote.Name = "SetSprint"
		sprintRemote.Parent = remotes
	end
	sprintRemote.OnServerEvent:Connect(function(player, enabled)
		if type(enabled) ~= "boolean" then
			return
		end
		sprinting[player] = enabled or nil
		refreshWalkSpeed(player)
	end)

	local mountRemote = remotes:FindFirstChild("ToggleMount")
	if not mountRemote then
		mountRemote = Instance.new("RemoteEvent")
		mountRemote.Name = "ToggleMount"
		mountRemote.Parent = remotes
	end
	mountRemote.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastMountToggle[player] and now - lastMountToggle[player] < MountConfig.TOGGLE_COOLDOWN then
			return
		end
		lastMountToggle[player] = now
		CarService.SetMounted(player, mounts[player] == nil)
	end)

	-- A rider's raised avatar does not touch the race pad, so riders are checked by position (docs/MOUNT_SPEC.md).
	task.spawn(function()
		while true do
			task.wait(MountConfig.PAD_CHECK)
			for player, mount in mounts do
				local root = mount.Humanoid.RootPart
				for _, pad in CollectionService:GetTagged(SpawnArea.TAG) do
					local offset = root and pad.CFrame:PointToObjectSpace(root.Position)
					if offset and math.abs(offset.X) <= pad.Size.X / 2 and math.abs(offset.Z) <= pad.Size.Z / 2 then
						task.spawn(CarService.PadTouched, player, root)
						break
					end
				end
			end
		end
	end)

	local function onCharacter(player, character)
		CarService.OnCharacter(player, character)
	end

	local function watchPad(pad)
		pad.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local player = model and Players:GetPlayerFromCharacter(model)
			if player then
				CarService.PadTouched(player, hit)
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal(SpawnArea.TAG):Connect(watchPad)
	for _, pad in CollectionService:GetTagged(SpawnArea.TAG) do
		watchPad(pad)
	end
	local function onPlayer(player)
		player:GetAttributeChangedSignal("EquippedCar"):Connect(function()
			local car = cars[player]
			if car and car.Parent then
				CarAppearance.Apply(car, player:GetAttribute("EquippedCar"), CarConfig)
				VehicleEffects.Apply(car, player)
			end
			if mounts[player] then -- swap the ridden car and its speed
				dismount(player)
				CarService.SetMounted(player, true)
			end
		end)
		for _, attribute in { "EquippedAura", "EquippedTrail" } do
			player:GetAttributeChangedSignal(attribute):Connect(function()
				local car = cars[player] or (mounts[player] and mounts[player].Car)
				if car and car.Parent then
					VehicleEffects.Apply(car, player)
				end
			end)
		end
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
	-- A Walkspeed purchase applies at once to an avatar on foot.
	UpgradeService.OnChanged(refreshWalkSpeed)
	PlayerData.OnLeaving(forget) -- before the leave save, so the run's last Speed gain is saved
	Players.PlayerRemoving:Connect(forget)
end

return CarService
