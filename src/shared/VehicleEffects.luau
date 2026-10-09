--!strict
-- Visuals are attached to the physics chassis, so they remain visible on every client's car.
local MarketConfig = require(script.Parent.MarketConfig)

local VehicleEffects = {}

local function effectFolder(car)
	local chassis = car.PrimaryPart
	if chassis then
		for _, child in chassis:GetChildren() do
			if child:IsA("Attachment") and child:GetAttribute("MarketEffect") then
				child:Destroy()
			end
		end
	end
	local old = car:FindFirstChild("MarketEffects")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "MarketEffects"
	folder.Parent = car
	return folder
end

local function weld(part, chassis)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = chassis
	joint.Part1 = part
	joint.Parent = part
end

local function addAura(folder, chassis, item)
	local orb = Instance.new("Part")
	orb.Name = "AuraGlow"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(5.5, 2.8, 7)
	orb.CFrame = chassis.CFrame * CFrame.new(0, 0.8, 0)
	orb.Transparency = 0.78
	orb.Color = item.Color
	orb.Material = Enum.Material.Neon
	weld(orb, chassis)
	orb.Parent = folder

	local light = Instance.new("PointLight")
	light.Name = "AuraLight"
	light.Color = item.Color
	light.Brightness = 2.5
	light.Range = 16
	light.Parent = orb

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AuraParticles"
	emitter.Color = ColorSequence.new(item.Color)
	emitter.LightEmission = 0.8
	emitter.Rate = 34
	emitter.Lifetime = NumberRange.new(0.7, 1.35)
	emitter.Speed = NumberRange.new(1, 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = orb

	local ring = Instance.new("Part")
	ring.Name = "AuraRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.16, 6.4, 6.4)
	ring.CFrame = chassis.CFrame * CFrame.new(0, -0.7, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.3
	ring.Color = item.Accent or item.Color
	ring.Material = Enum.Material.Neon
	weld(ring, chassis)
	ring.Parent = folder

	local orbit = Instance.new("ParticleEmitter")
	orbit.Name = "AuraOrbit"
	orbit.Color = ColorSequence.new(item.Accent or item.Color, item.Color)
	orbit.LightEmission = 1
	orbit.Rate = 12
	orbit.Lifetime = NumberRange.new(0.9, 1.5)
	orbit.Speed = NumberRange.new(0, 0.4)
	orbit.SpreadAngle = Vector2.new(360, 360)
	orbit.Shape = Enum.ParticleEmitterShape.Sphere
	orbit.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	orbit.Size = NumberSequence.new(0.16)
	orbit.Parent = ring
end

local function addTrail(folder, chassis, item)
	local front = Instance.new("Attachment")
	front.Name = "TrailFront"
	front.Position = Vector3.new(0, -0.25, -2.1)
	front.Parent = chassis
	front:SetAttribute("MarketEffect", true)
	local back = Instance.new("Attachment")
	back.Name = "TrailBack"
	back.Position = Vector3.new(0, -0.25, 2.1)
	back.Parent = chassis
	back:SetAttribute("MarketEffect", true)
	local trail = Instance.new("Trail")
	trail.Name = item.Id .. "Trail"
	trail.Attachment0 = front
	trail.Attachment1 = back
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, item.Color),
		ColorSequenceKeypoint.new(0.45, item.Accent or item.Color),
		ColorSequenceKeypoint.new(1, item.Color:Lerp(Color3.new(1, 1, 1), 0.2)),
	})
	trail.Lifetime = item.Id == "void_trail" and 1.1 or 0.9
	trail.MinLength = 0.1
	trail.LightEmission = 0.8
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Parent = folder

	local spark = Instance.new("ParticleEmitter")
	spark.Name = "TrailSparks"
	spark.Color = ColorSequence.new(item.Color, item.Accent or item.Color)
	spark.LightEmission = 1
	spark.Rate = item.Id == "solar_trail" and 28 or 16
	spark.Lifetime = NumberRange.new(0.35, 0.8)
	spark.Speed = NumberRange.new(2, 5)
	spark.SpreadAngle = Vector2.new(15, 15)
	spark.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	spark.Parent = back
end

function VehicleEffects.Apply(car, player)
	local chassis = car and car.PrimaryPart
	if not chassis then
		return
	end
	local folder = effectFolder(car)
	local aura = MarketConfig.Get("Aura", player and player:GetAttribute("EquippedAura"))
	local trail = MarketConfig.Get("Trail", player and player:GetAttribute("EquippedTrail"))
	if aura then
		addAura(folder, chassis, aura)
	end
	if trail then
		addTrail(folder, chassis, trail)
	end
end

return VehicleEffects
