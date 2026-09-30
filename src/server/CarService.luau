--!nonstrict
-- Replaces each player's avatar with their car. The Humanoid character still exists (Roblox needs it
-- for camera, respawn and input) but it is hidden and seated in the car's VehicleSeat, so the car
-- is the only thing anyone sees.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local CarFactory = require(Shared.CarFactory)
local RaceService = require(script.Parent.RaceService)
local TrackBuilder = require(Shared.TrackBuilder)

local CarService = {}

local cars = {} -- player -> car model

local function hideCharacter(character)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanCollide = false
			d.Massless = true
		elseif d:IsA("Decal") then
			d.Transparency = 1
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
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

local function removeCar(player)
	local car = cars[player]
	if car then
		car:Destroy()
		cars[player] = nil
	end
end

function CarService.Attach(player, character)
	removeCar(player)
	local humanoid = character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")
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
	car:SetAttribute("Owner", player.UserId)

	local seat = car:FindFirstChild("DriverSeat")
	local chassis = car.PrimaryPart
	if not RaceService.Attach(player, car) then
		chassis:SetNetworkOwner(player) -- no race route: manual driving, the client steps the physics
	end

	for _ = 1, 5 do
		character:PivotTo(seat.CFrame * CFrame.new(0, 2, 0))
		seat:Sit(humanoid)
		task.wait(0.1)
		if humanoid.SeatPart == seat then
			break
		end
	end

	humanoid.Died:Once(function()
		removeCar(player)
	end)
end

function CarService.Start()
	local function onPlayer(player)
		player.CameraMinZoomDistance = 10
		player.CameraMaxZoomDistance = 40
		player.CharacterAdded:Connect(function(character)
			CarService.Attach(player, character)
		end)
		if player.Character then
			task.spawn(CarService.Attach, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(removeCar)
end

return CarService
