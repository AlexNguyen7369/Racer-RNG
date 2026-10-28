--!nonstrict
-- Spins and bobs Singularity's black hole (docs/CAR_REDESIGN_SPEC.md section 11) on this client only: the Orb welds of
-- equipped skins (C0 = rest * Offset) and the anchored Orb parts of static display copies (CFrame = rest * Offset;
-- the turning spawn-area pedestals are done by Client/BestRollView).
-- The server never changes them, so nothing replicates.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local OrbMotion = require(Shared:WaitForChild("OrbMotion"))
local UiMotion = require(script.Parent.UiMotion)

local ORB_DISTANCE = 200 -- studs from the camera; farther orbs keep their last pose

local welds = {} -- Weld -> rest C0
local anchored = {} -- BasePart -> rest CFrame

local function consider(inst)
	if inst:IsA("Weld") and inst:GetAttribute("AnimatedOrb") then
		welds[inst] = inst.C0
	elseif
		inst:IsA("BasePart")
		and inst:GetAttribute("Orb")
		and inst.Anchored
		-- the spawn-area showcase pedestals turn their cars every frame and move the orb themselves (BestRollView)
		and not (inst:FindFirstAncestor("BestRoll") or inst:FindFirstAncestor("PassCars"))
	then
		anchored[inst] = inst.CFrame
	end
end
Workspace.DescendantAdded:Connect(consider)
Workspace.DescendantRemoving:Connect(function(inst)
	welds[inst] = nil
	anchored[inst] = nil
end)
for _, inst in Workspace:GetDescendants() do
	consider(inst)
end

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local offset = OrbMotion.Offset(os.clock(), UiMotion.Reduced())
	for weld, rest in welds do
		local part = weld.Part1
		if part and (part.Position - eye).Magnitude < ORB_DISTANCE then
			weld.C0 = rest * offset
		end
	end
	for part, rest in anchored do
		if (rest.Position - eye).Magnitude < ORB_DISTANCE then
			part.CFrame = rest * offset
		end
	end
end)
