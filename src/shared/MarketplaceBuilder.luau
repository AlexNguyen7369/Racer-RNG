--!nonstrict
-- Modular Blender marketplace; smooth box boundaries keep detailed displays from snagging players.
local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MeshAssets = require(script.Parent.MarketplaceMeshAssets)

local template = ReplicatedStorage:WaitForChild("SpawnMarketplace"):Clone()
for _, mesh in template:GetDescendants() do
	if mesh:IsA("MeshPart") then
		local assetId = MeshAssets[mesh.Name]
		assert(assetId, "Missing marketplace mesh asset: " .. mesh.Name)
		if mesh.MeshId ~= assetId or mesh.MeshSize.Magnitude == 0 then
			local texture = mesh.TextureID
			local loaded = AssetService:CreateMeshPartAsync(Content.fromUri(assetId), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
			})
			mesh:ApplyMesh(loaded)
			mesh.TextureID = texture
			loaded:Destroy()
		end
		assert(mesh.MeshId == assetId and mesh.MeshSize.Magnitude > 0, "Marketplace mesh failed to load: " .. mesh.Name)
	end
end

local MarketplaceBuilder = {}
MarketplaceBuilder.CENTER = Vector2.new(50, -70)
MarketplaceBuilder.ROTATION = 90 -- additional half-turn from the owner's previous -90 orientation
MarketplaceBuilder.SIZE = Vector3.new(48, 0.2, 44)
MarketplaceBuilder.VENDORS = {
	{ Name = "Aura", Kind = "Aura", Counter = Vector3.new(-17, 0, -3), Width = 9, Npc = Vector3.new(-17, 0, -7) },
	{ Name = "Workshop", Kind = "Upgrades", Counter = Vector3.new(0, 0, -11), Width = 18, Npc = Vector3.new(0, 0, -15) },
	{ Name = "Parts", Kind = "Trail", Counter = Vector3.new(17, 0, -3), Width = 9, Npc = Vector3.new(17, 0, -7) },
}

local function box(parent, name, size, cf, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide = collide
	p.CanTouch = false
	p.CanQuery = collide
	p.CastShadow = false
	p.Parent = parent
	return p
end

function MarketplaceBuilder.Build(placement)
	local model = Instance.new("Model")
	model.Name = "Marketplace"
	model:SetAttribute("EntranceWidth", 24)
	model:SetAttribute("CourtyardWidth", 24)
	local vendors = Instance.new("Folder")
	vendors.Name = "Vendors"
	vendors.Parent = model
	local areas = {}
	for _, spec in MarketplaceBuilder.VENDORS do
		local vendor = Instance.new("Model")
		vendor.Name = spec.Name
		vendor:SetAttribute("VendorKind", spec.Kind)
		vendor:SetAttribute("Modular", true)
		vendor.Parent = vendors
		areas[spec.Name] = vendor
	end
	local courtyard = Instance.new("Model")
	courtyard.Name = "Courtyard"
	courtyard.Parent = model
	areas.Courtyard = courtyard
	local visual = template:Clone()
	for _, mesh in visual:GetChildren() do
		if mesh:IsA("BasePart") then
			mesh.CFrame = placement * mesh.CFrame
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanTouch = false
			mesh.CanQuery = false
			mesh.CastShadow = false
			if mesh:IsA("MeshPart") then
				mesh.DoubleSided = true
			end
			mesh.Parent = areas[mesh.Name:match("^(%w+)_")]
		end
	end
	visual:Destroy()
	local boundaries = Instance.new("Folder")
	boundaries.Name = "CollisionBoundaries"
	boundaries.Parent = model
	local function boundary(name, size, pos)
		return box(boundaries, name, size, placement * CFrame.new(pos), true)
	end
	local floor = boundary("WalkSurface", MarketplaceBuilder.SIZE, Vector3.new(0, 0.1, 0))
	model.PrimaryPart = floor
	boundary("RearWall", Vector3.new(46, 10, 0.8), Vector3.new(0, 5.2, -20))
	for _, x in { -23, 23 } do
		boundary("SideDisplay_" .. x, Vector3.new(3.2, 3, 12), Vector3.new(x, 1.7, 15))
	end
	for _, spec in MarketplaceBuilder.VENDORS do
		local vendor = areas[spec.Name]
		local c = spec.Counter
		boundary(spec.Name .. "Counter", Vector3.new(spec.Width + 0.5, 4.2, 3), c + Vector3.new(0, 2.1, 0))
		local points = Instance.new("Folder")
		points.Name = "InteractionPoints"
		points.Parent = vendor
		local anchor = box(points, "PromptAnchor", Vector3.new(1, 1, 1), placement * CFrame.new(c + Vector3.new(0, 4.5, 1.7)), false)
		CollectionService:AddTag(anchor, "MarketPad")
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "OpenMarket"
		prompt.ActionText = "Browse Market"
		prompt.ObjectText = spec.Name == "Parts" and "Trails & Parts" or spec.Name .. " Vendor"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		for name, position in {
			NPC = spec.Npc + Vector3.new(0, 3.2, 0),
			ShopButton = c + Vector3.new(2, 4.6, 1.6),
			ItemDisplay = c + Vector3.new(0, 4.8, 0),
		} do
			local point = Instance.new("Attachment")
			point.Name = name
			point.Position = position - (c + Vector3.new(0, 4.5, 1.7))
			point.Parent = anchor
		end
		vendor.PrimaryPart = anchor
	end
	boundary("AuraFrontDisplay", Vector3.new(5.2, 3.6, 3.2), Vector3.new(-19, 1.8, 5))
	boundary("PartsFrontDisplay", Vector3.new(6, 4.5, 8), Vector3.new(18.5, 2.25, 4.5))
	boundary("TyreStack", Vector3.new(3.2, 4.1, 3.2), Vector3.new(-8, 2.05, -7.5))
	for _, x in { -22, -12, 12, 22 } do
		for _, z in { -16, -2 } do
			boundary("Post_" .. x .. "_" .. z, Vector3.new(1.5, 11.2, 1.5), Vector3.new(x, 5.8, z))
		end
	end
	for _, x in { -10, 10 } do
		boundary("WorkshopPost_" .. x, Vector3.new(1.5, 13, 1.5), Vector3.new(x, 6.7, -10))
	end
	local lights = Instance.new("Folder")
	lights.Name = "Lighting"
	lights.Parent = model
	for index, pos in { Vector3.new(-17, 8, -4), Vector3.new(0, 10, -10), Vector3.new(17, 8, -4), Vector3.new(-21, 4, 18), Vector3.new(21, 4, 18) } do
		local mount = box(lights, "LanternMount_" .. index, Vector3.new(0.2, 0.2, 0.2), placement * CFrame.new(pos), false)
		local light = Instance.new("PointLight")
		light.Name = "WarmLantern"
		light.Color = Color3.fromRGB(255, 201, 117)
		light.Brightness = 1.4
		light.Range = 14
		light.Shadows = false
		light.Parent = mount
	end
	return model
end

return MarketplaceBuilder
