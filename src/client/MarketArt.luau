--!nonstrict
-- Scale-independent authored vector art; no network upload is needed to display icons.
local Recipes = require(game:GetService("ReplicatedStorage").Shared.MarketArtConfig)
local Art = {}
function Art.Draw(parent, item, position, size)
	local root = Instance.new("Frame")
	root.Name = "Art"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position, root.Size = position, size
	root.BackgroundTransparency = 1
	root.ZIndex = 3
	root:SetAttribute("Icon", item.Icon)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = root
	for order, segment in Recipes[item.Id] or {} do
		local shape = Instance.new("Frame")
		shape.Name = "Shape" .. order
		shape.AnchorPoint = Vector2.new(0.5, 0.5)
		shape.Position = UDim2.fromScale(segment[1] / 100, segment[2] / 100)
		shape.Size = UDim2.fromScale(segment[3] / 100, segment[4] / 100)
		shape.Rotation = segment[5]
		shape.BackgroundColor3 = Color3.fromHex(segment[7])
		shape.BorderSizePixel = 0
		shape.ZIndex = 3
		if segment[6] > 0 then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(segment[6], 0)
			corner.Parent = shape
		end
		shape.Parent = root
	end
	root.Parent = parent
	return root
end
return Art
