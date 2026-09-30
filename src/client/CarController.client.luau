--!nonstrict
-- Drives the car the local player is seated in. The server hands us network ownership of the chassis,
-- so we run the same CarPhysics the test harness uses. VehicleSeat gives us throttle/steer for
-- keyboard, gamepad and mobile; Space is the handbrake and R flips the car upright.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local CarPhysics = require(Shared.CarPhysics)

local player = Players.LocalPlayer

local handbrake = false
ContextActionService:BindActionAtPriority("CarHandbrake", function(_, state)
	handbrake = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
	return Enum.ContextActionResult.Sink -- stops Space from making the avatar jump out of the seat
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space)

local current -- { Model, Physics }
local flippedFor = 0

local function release()
	current = nil
	flippedFor = 0
end

RunService.PreSimulation:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat") and seat.Parent:GetAttribute("IsCar")) then
		release()
		return
	end

	local model = seat.Parent
	if model:GetAttribute("AutoRace") then
		release() -- the server drives this car along the track (RaceService)
		return
	end
	if not current or current.Model ~= model then
		current = { Model = model, Physics = CarPhysics.new(model, CarConfig) }
	end
	local physics = current.Physics

	physics:Step({
		Throttle = seat.ThrottleFloat,
		Steer = seat.SteerFloat,
		Brake = 0,
		Handbrake = handbrake,
	}, dt)

	-- Flip recovery: R, or automatically after 2 s upside down
	local up = physics.Chassis.CFrame.UpVector
	flippedFor = up.Y < 0.2 and flippedFor + dt or 0
	if flippedFor > 2 or UserInputService:IsKeyDown(Enum.KeyCode.R) then
		flippedFor = 0
		local cf = physics.Chassis.CFrame
		local _, yaw = cf:ToEulerAnglesYXZ()
		physics:Reset(CFrame.new(cf.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, yaw, 0))
	end
end)
