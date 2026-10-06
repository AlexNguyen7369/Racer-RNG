--!nonstrict
-- Auto race. The server drives every player's car with the real CarPhysics, steered by PathDriver along
-- the chain of tracks. While it drives, the player's Speed stat grows with the car's ACTUAL speed (with
-- diminishing returns, see RaceConfig) and the cruise speed follows the stat. When the car passes a
-- winnings pad the pad pays the player (MoneyService.Collect); the car never has to touch the pad. After
-- the last finish the car is put back at the start of Track 1 and keeps racing.
--
-- NPC races (options.Npc, on for players): every track is a race against that track's NPC (Shared/NpcConfig,
-- Shared/NpcRacer). The NPC's time for the track is known when the player starts it; if the player's car reaches
-- the finish later than that, the player lost: the race plays out, the client shows the loser screen, and after
-- LOSE_SCREEN_SECONDS the car goes back to the start of Track 1.
-- Banked winnings (docs/SPAWN_AND_ROLLS_SPEC.md): winning a track adds its pad's value (MoneyService.Quote) to the
-- run's bank (run.Unbanked, mirrored in the player attribute Unbanked) instead of paying; a loss empties the bank;
-- run:CashOut() (also done by run:Destroy, so Stop, death and leaving) pays it into leaderstats.Money.
-- Race events go to the owning player only (Remotes.NpcRace:FireClient), whose client draws the NPC.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local CarPhysics = require(Shared.CarPhysics)
local PathDriver = require(Shared.PathDriver)
local RaceConfig = require(Shared.RaceConfig)
local NpcConfig = require(Shared.NpcConfig)
local NpcRacer = require(Shared.NpcRacer)
local MoneyService = require(script.Parent.MoneyService)
local PlayerData = require(script.Parent.PlayerData)
local GachaService = require(script.Parent.GachaService)
local UpgradeService = require(script.Parent.UpgradeService)

local RaceService = {}

RaceService.COMMIT_INTERVAL = 0.25 -- seconds between writes of the gained Speed stat (replication is not per frame)
RaceService.FLIP_UP_Y = 0.5 -- body up-vector Y below this counts as flipped...
RaceService.FLIP_SECONDS = 0.4 -- ...after this long, and the car is put back upright on the path
RaceService.START_AHEAD = 5 -- studs along the path from the road's first edge: all four wheels start on the road
local DEVIATION_GRACE = 3 -- seconds after the start before path deviation is measured (the car starts on the centre line)

local CAR_GROUP = "Cars"

local route = nil
local npcRemote = nil -- Remotes.NpcRace, created by Start

-- entries = { { Layout, Origin, Model, Number }, ... } in Number order (the chain Main builds).
function RaceService.BuildRoute(entries)
	local path = PathDriver.Chain(entries)
	local pads, tracks = {}, {}
	for i, entry in entries do
		local pad = entry.Model and entry.Model:FindFirstChild("WinPad", true)
		table.insert(pads, { Pad = pad, Index = path.PadIndices[i], Number = entry.Number or i })
		local config = NpcConfig.For(entry.Number or i)
		local lane = NpcRacer.LanePath(entry)
		table.insert(tracks, {
			Number = entry.Number or i,
			StartIndex = path.StartIndices[i],
			FinishIndex = path.FinishIndices[i],
			PadIndex = path.PadIndices[i],
			Pad = pad,
			Npc = { Config = config, Path = lane, Profile = NpcRacer.Profile(lane, config.Speed) },
		})
	end
	return { Path = path, Pads = pads, Tracks = tracks }
end

function RaceService.SetRoute(newRoute)
	route = newRoute
end

function RaceService.GetRoute()
	return route
end

local function isPlayer(player)
	return typeof(player) == "Instance" and player:IsA("Player")
end

-- The upgrade tree's gate: the best track the player has won (NPC mode) or finished (no NPC). Fakes are Instances too.
local function reachTrack(player, number)
	if typeof(player) == "Instance" then
		UpgradeService.ReachTrack(player, number)
	end
end

local function setCarGroup(car)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = CAR_GROUP
		end
	end
end

-- Starts driving `car` along `raceRoute` for `player`. Returns a run object; call run:Destroy() to stop.
-- options: { Loop = true } puts the car back at the start of the route after the last finish.
--          { Npc = true } races every track against its NPC. Test hooks: NpcSpeeds = { [number] = speed },
--          LoseScreenSeconds, OnRaceEvent(event).
function RaceService.NewRun(car, raceRoute, player, options)
	options = options or {}
	local chassis = car.PrimaryPart
	pcall(function()
		chassis:SetNetworkOwner(nil) -- the server owns the car
	end)
	car:SetAttribute("AutoRace", true)

	PlayerData.Setup(player)
	local stat = PlayerData.SpeedStat(player)
	local physics = CarPhysics.new(car, CarConfig)
	local driver = PathDriver.new(raceRoute.Path, CarConfig, {
		TargetSpeed = RaceConfig.SpeedFor(stat),
		NoFinalSlow = options.Loop,
	})
	local run = {
		Car = car,
		TargetSpeed = driver.TargetSpeed,
		Finished = false,
		Payouts = 0,
		PaidTotal = 0,
		Unbanked = 0, -- NPC mode: won, not yet paid (paid by CashOut)
		BankedTotal = 0, -- NPC mode: everything wins added to the bank
		Gained = 0,
		MinUpY = 1,
		MaxPathDeviation = 0,
		FlipRecoveries = 0,
		OffTrackSeconds = 0,
		Laps = 0,
		Driver = driver,
		Physics = physics,
		RaceTrack = nil, -- number of the track being raced against its NPC
		Results = {}, -- every Result event
		Wins = 0,
		Losses = 0,
		Resets = 0,
	}
	local npcMode = options.Npc == true and type(raceRoute.Tracks) == "table" and #raceRoute.Tracks > 0
	local loseSeconds = options.LoseScreenSeconds or NpcConfig.LOSE_SCREEN_SECONDS
	local race = nil -- { Index, Number, Started, NpcTime }
	local held = false -- the car waits at the finish while the loser screen shows
	local lossGen = 0 -- bumped by JumpToTrack so a pending lose-screen reset never fires after a jump
	local alive = true
	local paid = {} -- pad entry -> already paid this pass
	local pending, sinceCommit = 0, 0
	local flippedFor, runTime = 0, 0

	-- Where every run starts and where the car goes after the last finish or a lost race: the start of Track 1,
	-- in the lane, START_AHEAD studs onto the road (the first waypoint is the road's very edge), facing down it
	local wps = raceRoute.Path.WorldWaypoints
	local firstDir = (wps[2] - wps[1]).Unit
	local startPos = wps[1] + firstDir * RaceService.START_AHEAD + Vector3.new(0, CarConfig.RestHeight + 0.5, 0)
	local startCF = CFrame.lookAt(startPos, startPos + Vector3.new(firstDir.X, 0, firstDir.Z))
	physics:Reset(startCF)

	local function setUnbanked(amount)
		run.Unbanked = amount
		if typeof(player) == "Instance" then
			player:SetAttribute("Unbanked", amount)
		end
	end
	if npcMode then
		setUnbanked(0)
	end

	local function emit(event)
		if options.OnRaceEvent then
			local ok, err = pcall(options.OnRaceEvent, event)
			if not ok then
				warn("OnRaceEvent: " .. tostring(err))
			end
		end
		if npcRemote and isPlayer(player) then
			npcRemote:FireClient(player, event) -- the owner only: nobody else sees this NPC
		end
	end

	local function startRace(i)
		local track = raceRoute.Tracks[i]
		local cfg = track.Npc.Config
		local speed = options.NpcSpeeds and options.NpcSpeeds[track.Number] or cfg.Speed
		local profile = track.Npc.Profile
		if speed ~= profile.Speed then
			profile = NpcRacer.Profile(track.Npc.Path, speed)
		end
		race = { Index = i, Number = track.Number, Started = runTime, NpcTime = profile.TotalTime }
		run.RaceTrack = track.Number
		emit({
			Type = "Start",
			Track = track.Number,
			ServerStart = workspace:GetServerTimeNow(),
			Speed = speed,
			Color = cfg.Color,
			Label = cfg.Label,
			Model = cfg.Model,
		})
	end

	local function backToStart()
		driver.Index, driver.Done = 1, false
		paid = {}
		physics:Reset(startCF)
	end

	-- The player's car reached the finish of the track it is racing on: decide, pay a win, move on.
	local function finishRace()
		local track = raceRoute.Tracks[race.Index]
		local playerTime = runTime - race.Started
		local win = playerTime < race.NpcTime
		local amount = 0
		if win then
			amount = track.Pad and MoneyService.Quote(player, track.Pad) or 0
			run.BankedTotal += amount
			setUnbanked(run.Unbanked + amount)
			reachTrack(player, track.Number)
		else
			setUnbanked(0) -- a lost race loses what was not banked yet
		end
		local event = {
			Type = "Result",
			Track = track.Number,
			Result = win and "Win" or "Lose",
			PlayerTime = playerTime,
			NpcTime = race.NpcTime,
			Banked = amount,
			Unbanked = run.Unbanked,
		}
		table.insert(run.Results, event)
		emit(event)
		local index = race.Index
		race = nil
		if win then
			run.Wins += 1
			if index < #raceRoute.Tracks then
				startRace(index + 1)
			elseif options.Loop then
				run.Laps += 1
				backToStart()
				startRace(1)
			else
				run.Laps += 1
				run.Finished = true
			end
		else
			run.Losses += 1
			held = true
			local gen = lossGen
			task.delay(loseSeconds, function()
				if not alive or not car.Parent or gen ~= lossGen then
					return
				end
				backToStart()
				held = false
				run.Resets += 1
				emit({ Type = "Reset", Track = raceRoute.Tracks[1].Number })
				startRace(1)
			end)
		end
	end

	local function payPads()
		for _, entry in raceRoute.Pads do
			if entry.Pad and not paid[entry] and driver.Index >= entry.Index then
				paid[entry] = true
				reachTrack(player, entry.Number)
				local amount = MoneyService.Collect(player, entry.Pad)
				if amount > 0 then
					run.Payouts += 1
					run.PaidTotal += amount
				end
			end
		end
	end

	-- Distance from the car to the route: the nearer of the two segments around the driver's waypoint
	local function pathDeviation()
		local pos = chassis.Position
		local best = math.huge
		for k = math.max(driver.Index - 1, 1), math.min(driver.Index, #wps - 1) do
			local a, b = wps[k], wps[k + 1]
			local ab = b - a
			local t = math.clamp((pos - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
			best = math.min(best, (pos - (a + ab * t)).Magnitude)
		end
		return best
	end

	-- A flipped car is put back upright on the path, facing along it
	local function recoverIfFlipped(dt)
		local up = chassis.CFrame.UpVector.Y
		-- Stability is measured from the start to the last checkpoint: not while the car rolls out past the end
		if not physics.LoopAssist and not run.Finished then
			run.MinUpY = math.min(run.MinUpY, up)
		end
		if up < RaceService.FLIP_UP_Y and not physics.LoopAssist then
			flippedFor += dt
		else
			flippedFor = 0
		end
		if flippedFor >= RaceService.FLIP_SECONDS then
			flippedFor = 0
			local i = math.clamp(driver.Index, 1, #wps - 1)
			local pos = wps[i] + Vector3.new(0, CarConfig.RestHeight + 0.5, 0)
			local ahead = wps[i + 1]
			physics:Reset(CFrame.lookAt(pos, Vector3.new(ahead.X, pos.Y, ahead.Z)))
			run.FlipRecoveries += 1
		end
	end

	local function commitStat()
		if pending > 0 then
			local added = pending
			pending = 0
			local newStat = PlayerData.AddSpeed(player, added)
			if newStat then
				run.Gained += added
			end
		end
		stat = PlayerData.SpeedStat(player) -- the source of truth (also picks up a load finishing)
		run.TargetSpeed = RaceConfig.SpeedFor(stat)
		driver.TargetSpeed = run.TargetSpeed
	end

	if npcMode then
		startRace(1)
	end

	-- Admin /tp: puts the car at the start of track `number` (START_AHEAD in, in the lane, upright, facing along the
	-- path). Pads of earlier tracks count as paid for this pass, so a jump never pays; in NPC mode the race in
	-- progress is dropped (no Result) and that track's race starts. Returns false (nothing changes) for a bad number.
	function run:JumpToTrack(number)
		if not alive or type(number) ~= "number" or type(raceRoute.Tracks) ~= "table" then
			return false
		end
		local index = nil
		for i, track in raceRoute.Tracks do
			if track.Number == number then
				index = i
				break
			end
		end
		if not index then
			return false
		end
		local s = math.clamp(raceRoute.Tracks[index].StartIndex, 1, #wps - 1)
		local dir = (wps[s + 1] - wps[s]).Unit
		local pos = wps[s] + dir * RaceService.START_AHEAD + Vector3.new(0, CarConfig.RestHeight + 0.5, 0)
		physics:Reset(CFrame.lookAt(pos, pos + Vector3.new(dir.X, 0, dir.Z)))
		driver.Index, driver.Done = s, false
		paid = {}
		for _, entry in raceRoute.Pads do
			if entry.Index < s then
				paid[entry] = true
			end
		end
		lossGen += 1
		held = false
		flippedFor = 0
		run.Finished = false
		if npcMode then
			race = nil
			startRace(index)
		end
		return true
	end

	run.Connection = RunService.PreSimulation:Connect(function(dt)
		if not car.Parent then
			run:Destroy()
			return
		end
		local control = driver:Control(chassis, dt)
		if held then
			control = { Throttle = 0, Steer = control.Steer, Brake = 1, Handbrake = false }
		end
		physics:Step(control, dt)
		run.OffTrackSeconds = driver.OffTrackSeconds
		runTime += dt
		if npcMode then
			if race then
				local track = raceRoute.Tracks[race.Index]
				local last = race.Index == #raceRoute.Tracks
				if driver.Index >= track.FinishIndex or (last and driver.Done) then
					finishRace()
				end
			end
		else
			payPads()
		end
		recoverIfFlipped(dt)
		if runTime > DEVIATION_GRACE and not run.Finished then -- past the last finish there is no path to follow
			run.MaxPathDeviation = math.max(run.MaxPathDeviation, pathDeviation())
		end

		-- Passive gain: proportional to the ACTUAL speed, smaller the higher the stat, times the equipped
		-- car's and the stat points' Speed multi (GachaService). The cruise speed does not use the multi.
		pending += RaceConfig.GainPerSecond(stat, chassis.AssemblyLinearVelocity.Magnitude) * GachaService.SpeedMulti(
			player
		) * dt
		sinceCommit += dt
		if sinceCommit >= RaceService.COMMIT_INTERVAL then
			sinceCommit = 0
			commitStat()
		end

		if not npcMode and driver.Done and not run.Finished then
			run.Finished = true
			run.Laps += 1
			if options.Loop then
				driver.Index, driver.Done = 1, false
				paid = {}
				physics:Reset(startCF)
				run.Finished = false
			end
		end
	end)

	-- Pays the bank into leaderstats.Money and empties it. Returns the amount paid (0 if none).
	function run:CashOut()
		local amount = run.Unbanked
		if amount <= 0 then
			return 0
		end
		setUnbanked(0)
		if MoneyService.Award(player, amount) == nil then
			return 0
		end
		run.Payouts += 1
		run.PaidTotal += amount
		return amount
	end

	-- Stops the run. The Speed gained since the last commit is committed first, so stopping never loses stat, and
	-- the bank is paid out, so stopping (or dying, or leaving) never loses won money.
	function run:Destroy()
		if alive then
			alive = false
			self:CashOut()
			if npcMode then
				emit({ Type = "Stop" })
			end
		end
		if self.Connection then
			self.Connection:Disconnect()
			self.Connection = nil
			commitStat()
		end
	end
	return run
end

RaceService.SetCarGroup = setCarGroup

-- Called by CarService once the player's car exists. Returns the run, or nil if there is no route
-- (then the car is driven manually).
function RaceService.Attach(player, car)
	if not route then
		return nil
	end
	setCarGroup(car)
	return RaceService.NewRun(car, route, player, { Loop = true, Npc = true })
end

function RaceService.Start(newRoute)
	route = newRoute
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	npcRemote = remotes:FindFirstChild("NpcRace")
	if not npcRemote then
		npcRemote = Instance.new("RemoteEvent")
		npcRemote.Name = "NpcRace"
		npcRemote.Parent = remotes
	end
	pcall(function()
		PhysicsService:RegisterCollisionGroup(CAR_GROUP)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(CAR_GROUP, CAR_GROUP, false) -- overlapping spawns can not shove each other
	end)
end

return RaceService
