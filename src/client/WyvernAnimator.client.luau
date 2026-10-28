--!nonstrict
-- Plays the Ember Wyvern flight (docs/WYVERN_FLIGHT_SPEC.md section 4) on every rigged skin in this client's world:
-- the equipped ride of any player, NPC skins of that model and the pedestal / Best Roll cars. Each RenderStepped it
-- poses the bones from Shared/WyvernMotion; Speed and Turn come from how far the model moved and turned since the
-- last frame, so it works the same for driven, railed and anchored (pedestal) models. The frame is the part that
-- holds the Root bone (Body): it has the template's axes and moves with the skin, unlike the pivot of a skin Model
-- without a PrimaryPart. Local only: nothing replicates.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WyvernMotion = require(Shared:WaitForChild("WyvernMotion"))
local WyvernBreath = require(Shared:WaitForChild("WyvernBreath"))
local UiMotion = require(script.Parent.UiMotion)

local DRAW_DISTANCE = 300 -- studs from the camera; farther rigs keep their last pose
local SMOOTH = 0.15 -- seconds: smoothing of the measured speed and turn rate

local rigs = {} -- model -> { bones = { name -> { bone, rest } }, pivot, speed, turn, offset }
local pending = {} -- rigged models whose bones have not all replicated yet

-- Starts posing a model once every bone is there (its rest pose is read with all Transforms at identity).
local function track(model)
	if rigs[model] then
		return
	end
	local found = {}
	for _, bone in model:GetDescendants() do
		if bone:IsA("Bone") then
			found[bone.Name] = bone
		end
	end
	for _, name in WyvernMotion.BONES do
		if not found[name] then
			pending[model] = true
			return
		end
	end
	pending[model] = nil
	local holder = found.Root.Parent
	local pivot = holder.CFrame
	for _, bone in found do
		bone.Transform = CFrame.identity
	end
	local entry = {
		bones = {},
		speed = 0,
		turn = 0,
		cycle = (#model:GetFullName() % 17) / 17,
		offset = (#model:GetFullName() % 17) * 0.37,
		pivot = pivot,
		holder = holder,
	}
	for name, bone in found do
		entry.bones[name] = { bone = bone, rest = pivot:ToObjectSpace(bone.WorldCFrame).Rotation }
	end
	-- Blue fire breath on the Head bone, built at the rest pose (docs/WYVERN_BREATH_SPEC.md).
	entry.breath = WyvernBreath.Build(model)
	rigs[model] = entry
end

local function consider(inst)
	if inst:IsA("Model") and inst:GetAttribute("Rig") == "Wyvern" then
		track(inst)
	end
end
Workspace.DescendantAdded:Connect(consider)
for _, inst in Workspace:GetDescendants() do
	consider(inst)
end

RunService.RenderStepped:Connect(function(dt)
	local camera = Workspace.CurrentCamera
	local reduced = UiMotion.Reduced()
	local t = os.clock()
	for model in pending do
		if model.Parent then
			track(model)
		else
			pending[model] = nil
		end
	end
	for model, entry in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local pivot = entry.holder.CFrame
		if camera and (pivot.Position - camera.CFrame.Position).Magnitude > DRAW_DISTANCE then
			entry.pivot = pivot
			if entry.breath then
				WyvernBreath.SetStrength(entry.breath, 0)
			end
			continue
		end
		-- Measured motion (studs/s, rad/s of yaw; positive turn = turning left).
		local step = math.max(dt, 1 / 240)
		local moved = (pivot.Position - entry.pivot.Position).Magnitude / step
		local look, last = pivot.LookVector, entry.pivot.LookVector
		local yaw = math.atan2(last.X * look.Z - last.Z * look.X, last.X * look.X + last.Z * look.Z)
		local k = math.clamp(dt / SMOOTH, 0, 1)
		entry.speed += (moved - entry.speed) * k
		entry.turn += (-yaw / step - entry.turn) * k
		entry.pivot = pivot
		local scale = model:GetScale()
		local speed = entry.speed / scale
		-- Integrated flap phase: the beat slows smoothly with speed instead of jumping (WyvernMotion.CycleSeconds).
		entry.cycle = (entry.cycle + dt / WyvernMotion.CycleSeconds(speed)) % 1
		local state = { Speed = speed, Turn = entry.turn, Reduced = reduced, Cycle = entry.cycle }
		local pose = WyvernMotion.Pose(t + entry.offset, state)
		if entry.breath then
			WyvernBreath.SetStrength(entry.breath, WyvernMotion.Breath(t + entry.offset, state))
		end
		for name, cf in pose do
			local b = entry.bones[name]
			if b then -- model-space rotation about the joint (and heave) -> the bone's local Transform
				local r = b.rest
				b.bone.Transform = CFrame.new(r:Inverse() * (cf.Position * scale)) * (r:Inverse() * cf.Rotation * r)
			end
		end
	end
end)
