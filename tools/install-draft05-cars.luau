-- Install the actual FBX-imported MeshParts; no procedural replacement geometry.
local storage = game:GetService("ReplicatedStorage")
local server = game:GetService("ServerStorage")
local ids = { "rusty_hatchback", "wooden_car", "go_kart", "street_racer", "rocket_car", "hover_car", "void_racer" }
local counts = { 7, 7, 4, 7, 5, 6, 6 }
local palette = {
	orange = "FBA052", wood = "B98650", woodlight = "E9BE79", red = "F34F5C", white = "FAF0DD",
	purple = "AD79EB", pink = "F795C8", cyan = "79E5F0", black = "252B36", glass = "40596D",
	gray = "99A5B1", yellow = "FFE5A2", rust = "AA7750",
}
local prepared = Instance.new("Folder")
prepared.Name = "CarModelsDraft05Prepared"
prepared.Parent = server
local report = {}
for i, id in ipairs(ids) do
	local batch = workspace:FindFirstChild(i <= 4 and "cars_A" or "cars_B")
	assert(batch, "FBX batch missing")
	local imported = assert(batch:FindFirstChild("D05_" .. id), "Imported car missing: " .. id)
	local model = imported:Clone()
	model.Name = id
	model.Parent = prepared
	-- FBX's empty-node pivot preserves the Blender origin. Scale uniformly around it.
	model:ScaleTo(0.01)
	model:PivotTo(CFrame.new())
	local meshes = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("MeshPart") then
			meshes += 1
			assert(part.MeshId ~= "", "Missing uploaded mesh")
			local key = part.Name:match("_([^_]+)$")
			local hex = assert(palette[key], "Unknown Blender material group: " .. part.Name)
			part.Color = Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
			part.Material = Enum.Material.SmoothPlastic
			part.Reflectance = 0
			part.Transparency = 0
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			part.RenderFidelity = Enum.RenderFidelity.Precise
			-- Match Blender's two-sided surfaces (window cards and circular lamp caps).
			part.DoubleSided = true
			part.Name = id .. "_" .. key
		elseif part:IsA("Light") then
			error("Unexpected active light in FBX")
		end
	end
	assert(meshes == counts[i], "Incomplete import: " .. id)
	local _, size = model:GetBoundingBox()
	assert(size.X > 3 and size.X < 6 and size.Z > 4 and size.Z < 7, "Incorrect import scale")
	model:SetAttribute("MeshRevision", 5)
	table.insert(report, { id = id, meshParts = meshes, size = tostring(size) })
end
local backup = Instance.new("Folder")
backup.Name = "Draft05InstallationBackup_" .. tostring(os.time())
backup.Parent = server
storage.CarModels.Parent = backup
prepared.Name = "CarModels"
prepared.Parent = storage
local raw = Instance.new("Folder")
raw.Name = "Draft05RawImports"
raw.Parent = backup
workspace.cars_A.Parent = raw
workspace.cars_B.Parent = raw
return game:GetService("HttpService"):JSONEncode({ cars = report, backup = backup:GetFullName() })
