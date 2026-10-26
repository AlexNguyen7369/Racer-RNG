--!nonstrict
-- Cosmetic skin only: retain the existing chassis, seat, wheels and race run.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CarCatalog = require(script.Parent.CarCatalog)
local CarAppearance = {}

-- Showroom finish per part group (docs/CAR_REDESIGN_SPEC.md section 8, placeholders): Reflectance, Transparency
-- (nil keeps the template's) and Shadow. A group is the part name without its number (Accent2 -> Accent).
CarAppearance.FINISH = {
	Body = { Reflectance = 0.08, Shadow = true },
	Accent = { Reflectance = 0.08, Shadow = true },
	Trim = { Reflectance = 0.08, Shadow = false },
	Metal = { Reflectance = 0.25, Shadow = false },
	Glass = { Reflectance = 0.2, Transparency = 0.25, Shadow = false },
	Light = { Shadow = false },
}

local function finish(part)
	local f = CarAppearance.FINISH[(part.Name:gsub("%d+$", ""))]
	if f then
		part.Reflectance = f.Reflectance or part.Reflectance
		part.Transparency = f.Transparency or part.Transparency
		part.CastShadow = f.Shadow
	end
end

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
				-- Redesigned skins carry their reference colours (docs/CAR_REDESIGN_SPEC.md section 4): no tint.
				if
					spec
					and spec.Tint
					and not template:GetAttribute("Redesign")
					and part.Material ~= Enum.Material.Glass
				then
					part.Color = part.Color:Lerp(spec.Tint, 0.35)
				end
				finish(part)
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
		-- The authored skin hides the physics wheels, so give its four visible wheels
		-- the same animated weld contract as the procedural wheels.  A WeldConstraint
		-- cannot expose a changing spin angle; CarPhysics updates these Welds every step.
		local staticSpringLen = config.SuspensionRest * (1 - config.StaticCompression)
		for _, wheel in config.Wheels do
			local part = skin:FindFirstChild("Wheel_" .. wheel.Name, true)
			if part and part:IsA("BasePart") then
				local skinWeld = part:FindFirstChild("SkinWeld")
				if skinWeld then
					skinWeld:Destroy()
				end
				-- Keep the authored wheel orientation, but snap its centre to the
				-- shared physics mount. Imported bodies use different art scales;
				-- retaining their authored position leaves the tire out of line with
				-- the car's interior hub/wheel design.
				local authoredLocal = chassis.CFrame:ToObjectSpace(part.CFrame)
				local localCf = CFrame.new(wheel.Mount - Vector3.new(0, staticSpringLen, 0)) * authoredLocal.Rotation
				local weld = Instance.new("Weld")
				weld.Name = "SkinWeld"
				weld.Part0 = chassis
				weld.Part1 = part
				weld.C0 = localCf
				weld:SetAttribute("StaticSpringLen", staticSpringLen)
				weld:SetAttribute("AnimatedWheel", true)
				weld.Parent = part
			end
		end
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
			if spec.Tint and not template:GetAttribute("Redesign") and part.Material ~= Enum.Material.Glass then
				part.Color = part.Color:Lerp(spec.Tint, 0.35)
			end
			finish(part)
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
