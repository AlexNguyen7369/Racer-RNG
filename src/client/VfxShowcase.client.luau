--!nonstrict
-- VFX showcase (docs/ADMIN_COMMANDS_SPEC.md "VFX showcase area"): while the local avatar is near Shared/VfxArea,
-- one local car per Market trail / aura drives its own loop wearing that effect. Client-only; nothing replicates.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local CarFactory = require(Shared.CarFactory)
local VehicleEffects = require(Shared.VehicleEffects)
local VfxArea = require(Shared.VfxArea)

local TRAIL_RADIUS, AURA_RADIUS, SPEED = 16, 9, 45 -- studs, studs, studs/s (the cruise speed at Speed 0)
local CHASSIS_HEIGHT = 1.29 -- chassis centre above the wheel bottoms

local player = Players.LocalPlayer
local showcase, cars, clock = nil, {}, 0

local function build()
	showcase = Instance.new("Folder")
	showcase.Name = "VfxShowcase"
	for i, item in VfxArea.Items do
		local kind, id = item[1], item[2]
		local car = CarFactory.build(CarConfig)
		car.Name = id
		for _, d in car:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
			end
		end
		VehicleEffects.ApplyProfile(car, kind, id)
		car.Parent = showcase
		table.insert(
			cars,
			{ model = car, centre = VfxArea.LaneCentre(i), radius = kind == "Aura" and AURA_RADIUS or TRAIL_RADIUS }
		)
	end
	showcase.Parent = Workspace
end

local function clear()
	if showcase then
		showcase:Destroy()
	end
	showcase, cars = nil, {}
end

RunService.Heartbeat:Connect(function(dt)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local near = root ~= nil and (root.Position - VfxArea.CENTER).Magnitude <= VfxArea.SHOW_RADIUS
	if near and not showcase then
		build()
	elseif not near and showcase then
		clear()
	end
	if not showcase then
		return
	end
	clock += dt
	for _, c in cars do
		local a = clock * SPEED / c.radius
		local pos = c.centre + Vector3.new(math.cos(a) * c.radius, CHASSIS_HEIGHT, math.sin(a) * c.radius)
		c.model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))) -- car forward is -Z
	end
end)
