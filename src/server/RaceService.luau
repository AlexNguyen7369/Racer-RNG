--!nonstrict
-- Auto race. The server drives every player's car with the real CarPhysics, steered by PathDriver along
-- the chain of tracks. While it drives, the player's Speed stat grows with the car's ACTUAL speed (with
-- diminishing returns, see RaceConfig) and the cruise speed follows the stat. When the car passes a
-- winnings pad the pad pays the player (MoneyService.Collect); the car never has to touch the pad. After
-- the last finish the car is put back at the start of Track 1 and keeps racing.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local CarPhysics = require(Shared.CarPhysics)
local PathDriver = require(Shared.PathDriver)
local RaceConfig = require(Shared.RaceConfig)
local MoneyService = require(script.Parent.MoneyService)
local PlayerData = require(script.Parent.PlayerData)

local RaceService = {}

RaceService.COMMIT_INTERVAL = 0.25 -- seconds between writes of the gained Speed stat (replication is not per frame)
RaceService.FLIP_UP_Y = 0.5 -- body up-vector Y below this counts as flipped...
RaceService.FLIP_SECONDS = 0.4 -- ...after this long, and the car is put back upright on the path
local DEVIATION_GRACE = 3 -- seconds after the start before path deviation is measured (the car starts on the centre line)

local CAR_GROUP = "Cars"

local route = nil

-- entries = { { Layout, Origin, Model, Number }, ... } in Number order (the chain Main builds).
function RaceService.BuildRoute(entries)
	local path = PathDriver.Chain(entries)
	local pads = {}
	for i, entry in entries do
		local pad = entry.Model and entry.Model:FindFirstChild("WinPad", true)
		table.insert(pads, { Pad = pad, Index = path.PadIndices[i] })
	end
	return { Path = path, Pads = pads }
end

function RaceService.SetRoute(newRoute)
	route = newRoute
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
		Gained = 0,
		MinUpY = 1,
		MaxPathDeviation = 0,
		FlipRecoveries = 0,
		OffTrackSeconds = 0,
		Laps = 0,
		Driver = driver,
		Physics = physics,
	}
	local paid = {} -- pad entry -> already paid this pass
	local pending, sinceCommit = 0, 0
	local flippedFor, runTime = 0, 0

	-- Where the car goes after the last finish: the start of Track 1, facing down the first stretch
	local wps = raceRoute.Path.WorldWaypoints
	local startPos = wps[1] + Vector3.new(0, CarConfig.RestHeight + 0.5, 0)
	local startCF = CFrame.lookAt(startPos, Vector3.new(wps[2].X, startPos.Y, wps[2].Z))

	local function payPads()
		for _, entry in raceRoute.Pads do
			if entry.Pad and not paid[entry] and driver.Index >= entry.Index then
				paid[entry] = true
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
		if not physics.LoopAssist then
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

	run.Connection = RunService.PreSimulation:Connect(function(dt)
		if not car.Parent then
			run:Destroy()
			return
		end
		physics:Step(driver:Control(chassis, dt), dt)
		run.OffTrackSeconds = driver.OffTrackSeconds
		payPads()
		recoverIfFlipped(dt)
		runTime += dt
		if runTime > DEVIATION_GRACE then
			run.MaxPathDeviation = math.max(run.MaxPathDeviation, pathDeviation())
		end

		-- Passive gain: proportional to the ACTUAL speed, smaller the higher the stat
		pending += RaceConfig.GainPerSecond(stat, chassis.AssemblyLinearVelocity.Magnitude) * dt
		sinceCommit += dt
		if sinceCommit >= RaceService.COMMIT_INTERVAL then
			sinceCommit = 0
			commitStat()
		end

		if driver.Done and not run.Finished then
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

	function run:Destroy()
		if self.Connection then
			self.Connection:Disconnect()
			self.Connection = nil
		end
	end
	return run
end

-- Called by CarService once the player's car exists. Returns the run, or nil if there is no route
-- (then the car is driven manually).
function RaceService.Attach(player, car)
	if not route then
		return nil
	end
	setCarGroup(car)
	return RaceService.NewRun(car, route, player, { Loop = true })
end

function RaceService.Start(newRoute)
	route = newRoute
	pcall(function()
		PhysicsService:RegisterCollisionGroup(CAR_GROUP)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(CAR_GROUP, CAR_GROUP, false) -- overlapping spawns can not shove each other
	end)
end

return RaceService
