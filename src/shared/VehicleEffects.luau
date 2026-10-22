--!nonstrict
-- Authored cosmetic profiles; attachments follow the shared chassis, never the skin.
local MarketConfig = require(script.Parent.MarketConfig)
local Effects = {}
local PROFILES = {
	rainbow_trail = { Lifetime = 0.9, Width = 1.7, Ribbons = 3, Rate = 0 },
	solar_trail = { Lifetime = 0.65, Width = 0.75, Ribbons = 1, Rate = 18 },
	void_trail = { Style = "Void", Lifetime = 1.2, HalfWidth = 1.3, Rate = 40 },
	azure_aura = { Radius = 1.7, Height = 0.1, Tilt = 0, Rings = 1, Rate = 12 },
	ember_aura = { Radius = 1.5, Height = -0.2, Tilt = 0.18, Rings = 1, Rate = 24 },
	galaxy_aura = { Radius = 1.75, Height = 0.5, Tilt = 0.48, Rings = 2, Rate = 10 },
}
Effects.Profiles = PROFILES
local function attachment(chassis, name, position)
	local obj = Instance.new("Attachment")
	obj.Name, obj.Position = name, position
	obj:SetAttribute("MarketEffect", true)
	obj.Parent = chassis
	return obj
end
local function particles(parent, item, rate, aura)
	if rate == 0 then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = item.Id .. "Sparks"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(item.Accent, item.Color)
	emitter.LightEmission, emitter.Rate = 0.8, rate
	emitter.Lifetime = NumberRange.new(0.4, 1)
	emitter.Speed = aura and NumberRange.new(0.5, 1.5) or NumberRange.new(1, 3)
	emitter.EmissionDirection = aura and Enum.NormalId.Top or Enum.NormalId.Back
	emitter.SpreadAngle = Vector2.new(aura and 80 or 15, aura and 80 or 15)
	emitter.Acceleration = aura and Vector3.new(0, 1, 0) or Vector3.zero
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.13),
		NumberSequenceKeypoint.new(0.4, 0.20),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.15, 1)
	emitter.Rotation, emitter.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-45, 45)
	emitter.Parent = parent
end
-- Hard-edged on/off steps along a trail's length: reads as broken, flickering neon (max 20 keypoints).
local function dashes(phase, count, fadeFrom)
	local points = {}
	for i = 0, count - 1 do
		local x0, x1 = i / count, (i + 1) / count
		local on = (i + phase) % 2 == 0 or (i + phase) % 3 == 0
		local value = on and math.max(0, (x0 - fadeFrom) / (1 - fadeFrom)) or 1
		table.insert(points, NumberSequenceKeypoint.new(i == 0 and 0 or x0 + 0.002, value))
		table.insert(points, NumberSequenceKeypoint.new(x1 - 0.002, value))
	end
	points[#points] = NumberSequenceKeypoint.new(1, 1)
	return NumberSequence.new(points)
end
-- Void Trail: a dark ground-flat wake between the rear wheels, flickering neon edges, void smoke and motes.
-- Tuned from Studio captures (2026-10-20); y sits just above the wheel bottoms of the shared chassis.
local function voidTrail(folder, chassis, item, profile)
	-- Keep the wake above the road when the suspension compresses or the rail makes
	-- a small vertical correction.  It is still below the chassis, but has margin
	-- above the wheel contact plane instead of being allowed to clip through it.
	local y, z, half = -0.82, 3.1, profile.HalfWidth
	local function ribbon(name, x0, x1, props)
		local a = attachment(chassis, item.Id .. name .. "A", Vector3.new(x0, y, z))
		local b = attachment(chassis, item.Id .. name .. "B", Vector3.new(x1, y, z))
		local obj = Instance.new("Trail")
		obj.Name = item.Id .. name
		obj.Attachment0, obj.Attachment1 = a, b
		obj.FaceCamera, obj.MinLength, obj.Lifetime = false, 0.1, profile.Lifetime
		for key, value in props do
			obj[key] = value
		end
		obj.Parent = folder
	end
	local black = Color3.new(0, 0, 0)
	ribbon("Core", -half, half, {
		LightEmission = 0,
		Color = ColorSequence.new(item.Color:Lerp(black, 0.6), item.Color:Lerp(black, 0.92)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.6, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		WidthScale = NumberSequence.new(1, 0.4),
	})
	for side, phase in { [-1] = 0, [1] = 1 } do
		ribbon(side < 0 and "EdgeL" or "EdgeR", side * half - 0.1, side * half + 0.1, {
			LightEmission = 1,
			Brightness = 2,
			Color = ColorSequence.new(item.Accent, item.Color),
			Transparency = dashes(phase, 9, 0.3),
		})
	end
	local source = attachment(chassis, item.Id .. "Emitter", Vector3.new(0, y + 0.1, z))
	local motes = Instance.new("ParticleEmitter")
	motes.Name = item.Id .. "Motes"
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = ColorSequence.new(item.Accent, item.Color)
	motes.LightEmission, motes.Rate, motes.Drag, motes.ZOffset = 1, profile.Rate, 2, 0.5
	motes.Lifetime, motes.Speed = NumberRange.new(0.5, 1.1), NumberRange.new(1.5, 4)
	motes.EmissionDirection, motes.SpreadAngle = Enum.NormalId.Top, Vector2.new(70, 70)
	motes.Acceleration = Vector3.new(0, 2, 0)
	motes.Size = NumberSequence.new(0.45, 0)
	motes.Transparency = NumberSequence.new(0, 1)
	motes.Parent = source
	local smoke = motes:Clone()
	smoke.Name = item.Id .. "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(item.Color:Lerp(black, 0.5), item.Color:Lerp(black, 0.9))
	smoke.LightEmission, smoke.Rate, smoke.ZOffset = 0, profile.Rate / 2, 0
	smoke.Acceleration = Vector3.new(0, 0.6, 0)
	smoke.Size = NumberSequence.new(1, 2.5)
	smoke.Transparency = NumberSequence.new(0.35, 1)
	smoke.Parent = source
end
local function trail(folder, chassis, item, profile)
	if profile.Style == "Void" then
		return voidTrail(folder, chassis, item, profile)
	end
	for i = 1, profile.Ribbons do
		local centre = (i - (profile.Ribbons + 1) / 2) * 0.6
		local a = attachment(chassis, item.Id .. "Left" .. i, Vector3.new(centre - profile.Width / 2, -0.4, 2.5))
		local b = attachment(chassis, item.Id .. "Right" .. i, Vector3.new(centre + profile.Width / 2, -0.4, 2.5))
		local ribbon = Instance.new("Trail")
		ribbon.Name = item.Id .. "Ribbon" .. i
		ribbon.Attachment0, ribbon.Attachment1 = a, b
		ribbon.Lifetime, ribbon.MinLength = profile.Lifetime, 0.1
		ribbon.LightEmission, ribbon.FaceCamera = 0.85, true
		ribbon.WidthScale, ribbon.Transparency = NumberSequence.new(1, 0), NumberSequence.new(0.15, 1)
		if item.Id == "rainbow_trail" then
			local points = {}
			for n = 0, 6 do
				table.insert(
					points,
					ColorSequenceKeypoint.new(n / 6, Color3.fromHSV((n / 6 + (i - 1) / 3) % 1, 0.7, 1))
				)
			end
			ribbon.Color = ColorSequence.new(points)
		else
			ribbon.Color = ColorSequence.new(item.Accent, item.Color)
		end
		ribbon.Parent = folder
	end
	particles(attachment(chassis, item.Id .. "Emitter", Vector3.new(0, -0.3, 2.5)), item, profile.Rate, false)
end
local function ring(folder, chassis, item, radius, height, tilt, ordinal)
	local nodes = {}
	for i = 0, 15 do
		local angle = i * math.pi / 8
		local pos =
			Vector3.new(math.cos(angle) * radius, height + math.sin(angle) * tilt, math.sin(angle) * radius * 1.25)
		table.insert(nodes, attachment(chassis, item.Id .. "Orbit" .. ordinal .. "_" .. i, pos))
	end
	for i, a in nodes do
		local beam = Instance.new("Beam")
		beam.Name = item.Id .. "Arc" .. ordinal .. "_" .. i
		beam.Attachment0, beam.Attachment1 = a, nodes[i % #nodes + 1]
		beam.Width0, beam.Width1 = 0.065, 0.065
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(i % 2 == 0 and item.Color or item.Accent)
		beam.Transparency = NumberSequence.new(0.2)
		beam.LightEmission = 1
		beam.Parent = folder
		if item.Id == "azure_aura" and i % 4 == 1 then
			local top = attachment(chassis, item.Id .. "Charge" .. i, a.Position + Vector3.new(0.15, 1.4, -0.1))
			local bolt = beam:Clone()
			bolt.Name = "AzureCharge" .. i
			bolt.Attachment1 = top
			bolt.Width0, bolt.Width1 = 0.12, 0.025
			bolt.Parent = folder
		end
	end
end
function Effects.Apply(car, player)
	local chassis = car and car.PrimaryPart
	if not chassis then
		return
	end
	for _, child in chassis:GetChildren() do
		if child:IsA("Attachment") and child:GetAttribute("MarketEffect") then
			child:Destroy()
		end
	end
	local old = car:FindFirstChild("MarketEffects")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "MarketEffects"
	folder.Parent = car
	for _, kind in { "Aura", "Trail" } do
		local item = MarketConfig.Get(kind, player and player:GetAttribute("Equipped" .. kind))
		local profile = item and PROFILES[item.Id]
		if profile then
			folder:SetAttribute(kind, item.Id)
			if kind == "Trail" then
				trail(folder, chassis, item, profile)
			else
				for n = 1, profile.Rings do
					ring(
						folder,
						chassis,
						item,
						profile.Radius,
						profile.Height,
						profile.Tilt * (n % 2 == 0 and -1 or 1),
						n
					)
				end
				particles(attachment(chassis, item.Id .. "Emitter", Vector3.new(0, 0.6, 0)), item, profile.Rate, true)
			end
		end
	end
end
return Effects
