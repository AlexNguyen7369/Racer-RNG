--!nonstrict
-- Ember Wyvern blue fire breath (docs/WYVERN_BREATH_SPEC.md): five particle layers on one Attachment under the Head
-- bone, so the fire follows the head as the rig moves. Client only (Client/WyvernAnimator builds and drives it); the
-- server never calls Build. Uploaded VFX textures only (Shared/VehicleEffects.TEXTURES). Numbers are placeholders.
local VehicleEffects = require(script.Parent.VehicleEffects)

local WyvernBreath = {}

local rgb = Color3.fromRGB
local HOT, CYAN, BLUE, DEEP, SOOT =
	rgb(230, 255, 255), rgb(60, 220, 255), rgb(20, 130, 230), rgb(10, 40, 140), rgb(4, 6, 16)
WyvernBreath.PALETTE = { HOT, CYAN, BLUE, DEEP, SOOT }
-- Mouth relative to the Head bone at rest, facing along the jaw (measured from the template at scale 1: mouth
-- drafts/cars/ember_wyvern/redesign/parts.json, direction (0, -0.12, -1)). Bone-local, so it follows the head and
-- scales with the model.
WyvernBreath.HEAD_OFFSET = CFrame.new(0, 0.7889, 0.1074, -1, 0, 0, 0, 0.4414, -0.8973, 0, -0.8973, -0.4414)

local function seq(points)
	local out = {}
	for _, p in points do
		table.insert(
			out,
			(typeof(p[2]) == "Color3" and ColorSequenceKeypoint or NumberSequenceKeypoint).new(p[1], p[2])
		)
	end
	return typeof(points[1][2]) == "Color3" and ColorSequence.new(out) or NumberSequence.new(out)
end

-- Layer = { name, texture, rate (full strength), life, speed, spread, size (studs at scale 1), colour, transparency,
-- lightEmission, brightness, extras }
local LAYERS = {
	{
		"BreathCore",
		"Flame",
		60,
		{ 0.14, 0.22 },
		{ 10, 14 },
		5,
		{ { 0, 0.35 }, { 1, 1.4 } },
		{ { 0, HOT }, { 0.25, CYAN }, { 1, BLUE } },
		{ { 0, 0 }, { 1, 1 } },
		1,
		4,
		{ LockedToPart = true },
	},
	{
		"BreathBody",
		"Flame",
		60,
		{ 0.3, 0.45 },
		{ 8, 12 },
		12,
		{ { 0, 0.6 }, { 1, 2.4 } },
		{ { 0, CYAN }, { 0.35, BLUE }, { 0.7, DEEP }, { 1, SOOT } },
		{ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } },
		0.6,
		3,
		{ Drag = 2, Acceleration = Vector3.new(0, 3, 0), VelocityInheritance = 1 },
	},
	{
		"BreathSmoke",
		"VoidWisp",
		10,
		{ 0.8, 1.2 },
		{ 4, 7 },
		20,
		{ { 0, 1 }, { 1, 2.8 } },
		{ { 0, DEEP }, { 0.4, SOOT }, { 1, SOOT } },
		{ { 0, 0.45 }, { 1, 1 } },
		0,
		1,
		{ Drag = 2, Acceleration = Vector3.new(0, 3, 0), VelocityInheritance = 1 },
	},
	{
		"BreathSparks",
		"Spark",
		40,
		{ 0.5, 1 },
		{ 12, 26 },
		26,
		{ { 0, 0.45 }, { 1, 0.15 } },
		{ { 0, CYAN }, { 1, BLUE } },
		{ { 0, 0 }, { 1, 1 } },
		1,
		4,
		{ Drag = 1, Acceleration = Vector3.new(0, -6, 0), VelocityInheritance = 1, Streak = true },
	},
	{
		"MouthGlow",
		"Glint",
		12,
		{ 0.12, 0.2 },
		{ 0, 0 },
		0,
		{ { 0, 1.4 }, { 1, 0.9 } },
		{ { 0, CYAN }, { 1, CYAN } },
		{ { 0, 0 }, { 1, 1 } },
		1,
		5,
		{ LockedToPart = true },
	},
}
WyvernBreath.LAYERS = LAYERS

-- Builds the breath on a rigged model (attribute Rig = "Wyvern"); returns the Attachment (nil without a Head bone).
function WyvernBreath.Build(model)
	local head = model:FindFirstChild("Head", true)
	if not (head and head:IsA("Bone")) then
		return nil
	end
	local old = head:FindFirstChild("Breath")
	if old then
		old:Destroy()
	end
	local scale = model:GetScale()
	local att = Instance.new("Attachment")
	att.Name = "Breath"
	att.CFrame = CFrame.new(WyvernBreath.HEAD_OFFSET.Position * scale) * WyvernBreath.HEAD_OFFSET.Rotation
	local textures = VehicleEffects.TEXTURES
	for _, l in LAYERS do
		local name, tex, rate, life, speed, spread, size, colour, transparency, le, br, extra =
			l[1], l[2], l[3], l[4], l[5], l[6], l[7], l[8], l[9], l[10], l[11], l[12]
		local p = Instance.new("ParticleEmitter")
		p.Name = name
		p.Texture = textures[tex]
		if VehicleEffects.FLIPBOOKS[tex] then
			p.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			p.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
		p.EmissionDirection = Enum.NormalId.Front
		p.Rate = 0
		p:SetAttribute("FullRate", rate)
		p.Lifetime = NumberRange.new(life[1], life[2])
		p.Speed = NumberRange.new(speed[1] * scale, speed[2] * scale)
		p.SpreadAngle = Vector2.new(spread, spread)
		local scaled = {}
		for _, k in size do
			table.insert(scaled, { k[1], k[2] * scale })
		end
		p.Size = seq(scaled)
		p.Color = seq(colour)
		p.Transparency = seq(transparency)
		p.LightEmission, p.Brightness = le, br
		p.LightInfluence = le > 0.5 and 0 or 1
		p.LockedToPart = extra.LockedToPart == true
		p.Drag = extra.Drag or 0
		p.Acceleration = (extra.Acceleration or Vector3.zero) * scale
		p.VelocityInheritance = extra.VelocityInheritance or 0
		if extra.Streak then
			p.Orientation = Enum.ParticleOrientation.VelocityParallel
			p.Rotation = NumberRange.new(-90)
		else
			p.Rotation = NumberRange.new(0, 360)
			p.RotSpeed = NumberRange.new(-40, 40)
		end
		p.Parent = att
	end
	att.Parent = head
	return att
end

-- Breath strength 0..1 (WyvernMotion.Breath) -> each layer's rate.
function WyvernBreath.SetStrength(att, strength)
	for _, p in att:GetChildren() do
		if p:IsA("ParticleEmitter") then
			p.Rate = (p:GetAttribute("FullRate") or 0) * math.clamp(strength, 0, 1)
		end
	end
end

return WyvernBreath
