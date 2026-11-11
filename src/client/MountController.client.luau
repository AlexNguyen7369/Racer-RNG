--!nonstrict
-- Press C to ride the equipped car (docs/MOUNT_SPEC.md). Sends only the intent; Server/CarService does the rest.
-- Also plays the seated pose on this player's avatar and spins the wheels of every ridden car in this client's world.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local MountConfig = require(Shared:WaitForChild("MountConfig"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ToggleMount")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.C then
		remote:FireServer()
	end
end)

-- Seated pose, using the avatar's own sit animation. It replicates to other players through the Animator.
local sitTrack

local function stopPose()
	if sitTrack then
		sitTrack:Stop()
		sitTrack:Destroy()
		sitTrack = nil
	end
end

local function updatePose()
	stopPose()
	if player:GetAttribute("Mounted") ~= true then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animate = character and character:FindFirstChild("Animate")
	local sit = animate and animate:FindFirstChild("sit")
	local animation = sit and sit:FindFirstChildOfClass("Animation")
	if animator and animation then
		sitTrack = animator:LoadAnimation(animation)
		sitTrack.Priority = Enum.AnimationPriority.Action
		sitTrack.Looped = true
		sitTrack:Play()
	end
end

player:GetAttributeChangedSignal("Mounted"):Connect(updatePose)

-- Wheels: the same weld contract CarPhysics drives during a race (spin about the axle on top of the rest pose).
local rides = {} -- model -> { Chassis, Wheels = { [weld] = { Rest, Spin } } }

local function watch(model)
	local wheels = {}
	local function consider(d)
		if d:IsA("Weld") and (d:GetAttribute("AnimatedWheel") or string.sub(d.Name, 1, 10) == "WheelWeld_") then
			wheels[d] = { Rest = d.C0, Spin = 0 }
		end
	end
	for _, d in model:GetDescendants() do
		consider(d)
	end
	rides[model] = { Wheels = wheels, Added = model.DescendantAdded:Connect(consider) }
end

local function unwatch(model)
	local ride = rides[model]
	if ride then
		ride.Added:Disconnect()
		rides[model] = nil
	end
end

CollectionService:GetInstanceAddedSignal(MountConfig.TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(MountConfig.TAG):Connect(unwatch)
for _, model in CollectionService:GetTagged(MountConfig.TAG) do
	watch(model)
end

RunService.RenderStepped:Connect(function(dt)
	for model, ride in rides do
		local chassis = model.PrimaryPart
		if chassis then
			local forwardSpeed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
			for weld, wheel in ride.Wheels do
				wheel.Spin -= forwardSpeed / CarConfig.WheelRadius * dt
				weld.C0 = wheel.Rest * CFrame.Angles(wheel.Spin, 0, 0)
			end
		end
	end
end)
