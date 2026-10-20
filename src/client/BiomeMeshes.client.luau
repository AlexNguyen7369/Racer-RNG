--!nonstrict
-- Puts the baked CC0 meshes on biome props near the camera (docs/BIOME_DRESSING_SPEC.md "Assets"). The server
-- tags each prop that has one "BiomeMesh" with attribute Mesh = "<Biome>_<Prop>" and an invisible MeshBounds box.
-- EditableMesh content does not replicate and the client has a strict EditableMesh memory budget, so this builds
-- a mesh only while a prop using it is within LOAD_DISTANCE (nearest first), destroys it when none is, and
-- shows the fallback parts everywhere else (and whenever the budget is full).

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BiomeDressing = require(Shared.BiomeDressing)
local BiomeMeshAssets = require(Shared.BiomeMeshAssets)
local BiomeMeshCodec = require(Shared.BiomeMeshCodec)

local LOAD_DISTANCE = 450 -- studs from the camera
local REFRESH = 1 -- seconds between range checks

local built = {} -- key -> { Mesh = EditableMesh, Part = MeshPart }

local function build(key)
	local biome, name = string.match(key, "^([^_]+)_(.+)$")
	local data = biome and BiomeDressing.MeshFor(biome, name)
	local mesh = data and BiomeMeshCodec.Build(data.Data)
	if not mesh then
		return nil -- no data, or the mesh budget is full: keep the fallback
	end
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
		})
	end)
	if not ok then
		mesh:Destroy()
		return nil
	end
	local texture = BiomeMeshAssets[key]
	if texture then
		part.TextureContent = Content.fromUri(texture)
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return { Mesh = mesh, Part = part }
end

local function setFallback(model, visible)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "MeshBounds" and child.Name ~= "BiomeMesh" then
			child.LocalTransparencyModifier = visible and 0 or 1
		end
	end
end

local function show(model, entry)
	local bounds = model:FindFirstChild("MeshBounds")
	if not bounds or model:FindFirstChild("BiomeMesh") then
		return
	end
	local part = entry.Part:Clone()
	part.Name = "BiomeMesh"
	part.Size = bounds.Size
	part.CFrame = bounds.CFrame
	part.CastShadow = bounds.Size.Magnitude > 30
	setFallback(model, false)
	part.Parent = model
end

local function hide(model)
	local part = model:FindFirstChild("BiomeMesh")
	if part then
		part:Destroy()
		setFallback(model, true)
	end
end

while true do
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	if eye then
		local nearest, inRange = {}, {}
		for _, model in CollectionService:GetTagged("BiomeMesh") do
			local bounds = model:FindFirstChild("MeshBounds")
			local key = model:GetAttribute("Mesh")
			if bounds and key then
				local d = (bounds.Position - eye).Magnitude
				if d < LOAD_DISTANCE then
					inRange[model] = key
					nearest[key] = math.min(nearest[key] or math.huge, d)
				else
					hide(model)
				end
			end
		end
		for key, entry in built do
			if not nearest[key] then
				for _, model in CollectionService:GetTagged("BiomeMesh") do
					if model:GetAttribute("Mesh") == key then
						hide(model)
					end
				end
				entry.Mesh:Destroy() -- frees its share of the budget at once
				entry.Part:Destroy()
				built[key] = nil
			end
		end
		local wanted = {}
		for key in nearest do
			if not built[key] then
				table.insert(wanted, key)
			end
		end
		table.sort(wanted, function(a, b)
			return nearest[a] < nearest[b]
		end)
		for _, key in wanted do
			local entry = build(key)
			if not entry then
				break -- budget full: farther meshes wait for one to be released
			end
			built[key] = entry
		end
		for model, key in inRange do
			if built[key] then
				show(model, built[key])
			end
		end
	end
	task.wait(REFRESH)
end
