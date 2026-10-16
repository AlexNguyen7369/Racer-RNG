--!nonstrict
-- Cosmetic skin only: retain the existing chassis, seat, wheels and race run.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CarCatalog = require(script.Parent.CarCatalog)
local CarAppearance = {}

function CarAppearance.Apply(car, id, config)
	local chassis = car.PrimaryPart
	assert(chassis, "Car appearance requires the existing chassis")
	local templates = ReplicatedStorage:FindFirstChild("CarModels")
	local spec = type(id) == "string" and CarCatalog.Get(id)
	local visualId = spec and id ~= CarCatalog.STARTER_ID and (spec.Model or id) or "rusty_hatchback"
	local template = templates and templates:FindFirstChild(visualId)
	local skin
	if template and template:IsA("Model") then
		skin = template:Clone()
		skin.Name = "EquippedVisual"
		skin:SetAttribute("CarId", id)
		-- Imported templates have a base-centered pivot; place that base at tyre contact height.
		skin:PivotTo(chassis.CFrame * CFrame.new(0, -config.RestHeight, 0))
		for _, part in ipairs(skin:GetDescendants()) do
			if part:IsA("BasePart") then
				if spec and spec.Tint and part.Material ~= Enum.Material.Glass then
					part.Color = part.Color:Lerp(spec.Tint, 0.35)
				end
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
				part.RootPriority = -127
				part.CollisionGroup = chassis.CollisionGroup
				local weld = Instance.new("WeldConstraint")
				weld.Name = "SkinWeld"
				weld.Part0 = chassis
				weld.Part1 = part
				weld.Parent = part
				part.Anchored = false
			end
		end
	end
	local old = car:FindFirstChild("EquippedVisual")
	if old then
		old:Destroy()
	end
	for _, part in ipairs(car:GetChildren()) do
		if part:IsA("BasePart") then
			local original = part:GetAttribute("StarterTransparency")
			if original == nil then
				original = part.Transparency
				part:SetAttribute("StarterTransparency", original)
			end
			part.Transparency = skin and 1 or original
		end
	end
	if skin then
		skin.Parent = car
	end
	car:SetAttribute("EquippedCar", spec and id or CarCatalog.STARTER_ID)
	car:SetAttribute("VisualCarId", skin and visualId or CarCatalog.STARTER_ID)
	return skin ~= nil
end

-- A static display copy of a car's skin (the spawn-area pedestals): named "Car", standing on `cframe` at `scale`,
-- every part anchored and non-colliding. nil when the car has no model in CarModels.
function CarAppearance.Display(spec, cframe, scale)
	local templates = ReplicatedStorage:FindFirstChild("CarModels")
	local template = spec and templates and templates:FindFirstChild(spec.Model or spec.Id)
	if not (template and template:IsA("Model")) then
		return nil
	end
	local car = template:Clone()
	car.Name = "Car"
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			if spec.Tint and part.Material ~= Enum.Material.Glass then
				part.Color = part.Color:Lerp(spec.Tint, 0.35)
			end
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	car:ScaleTo(car:GetScale() * scale) -- imported templates do not sit at scale 1
	car:PivotTo(cframe) -- templates have a base-centred pivot
	return car
end

return CarAppearance
