--!nonstrict
-- Plays the motion of trail / aura attachments made by Shared/VehicleEffects (tag VehicleFxMotion):
-- orbits round the car or the wake, precessing rings, and volume emission (a point that jumps round a box
-- or ellipse every frame, since attachments emit from a point). Local only: the server never moves them.
-- Reduced motion (Roblox setting or REDUCED EFFECTS) leaves them at rest.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local VehicleEffects = require(Shared.VehicleEffects)
local UiMotion = require(script.Parent.UiMotion)

local tracked = {}
local function add(obj)
	if obj:IsA("Attachment") then
		tracked[obj] = true
	end
end
CollectionService:GetInstanceAddedSignal(VehicleEffects.MOTION_TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(VehicleEffects.MOTION_TAG):Connect(function(obj)
	tracked[obj] = nil
end)
for _, obj in CollectionService:GetTagged(VehicleEffects.MOTION_TAG) do
	add(obj)
end

local random = Random.new()
local clock = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	local reduced = UiMotion.Reduced()
	for obj in tracked do
		local base = obj:GetAttribute("FxBase")
		if not obj.Parent or typeof(base) ~= "CFrame" then
			continue
		end
		if reduced then
			obj.CFrame = base
			continue
		end
		local mode = obj:GetAttribute("FxMode")
		if mode == "orbit" or mode == "orbitZ" then
			local a = (obj:GetAttribute("FxPhase") or 0) + math.rad(obj:GetAttribute("FxSpin") or 0) * clock
			local r = obj:GetAttribute("FxRadius") or 0
			local offset
			if mode == "orbitZ" then -- round the wake, which runs along z behind the car
				offset = Vector3.new(math.cos(a) * r, math.sin(a) * r, 0)
			else
				local t = obj:GetAttribute("FxTilt")
				offset = (typeof(t) == "CFrame" and t or CFrame.identity):VectorToWorldSpace(
					Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				)
			end
			obj.CFrame = base.Rotation + base.Position + offset
		elseif mode == "precess" then
			local spin = CFrame.Angles(0, math.rad(obj:GetAttribute("FxSpin") or 0) * clock, 0)
			obj.CFrame = CFrame.new(base.Position) * spin * base.Rotation -- turn in place round the car's up axis
		elseif mode == "box" then
			local b = obj:GetAttribute("FxBox") or Vector3.zero
			obj.CFrame = base
				+ Vector3.new(random:NextNumber(-b.X, b.X), random:NextNumber(-b.Y, b.Y), random:NextNumber(-b.Z, b.Z))
		elseif mode == "ring" then
			local b = obj:GetAttribute("FxBox") or Vector3.zero
			local a = random:NextNumber(0, 2 * math.pi)
			obj.CFrame = base + Vector3.new(math.cos(a) * b.X, 0, math.sin(a) * b.Z)
		end
	end
end)
