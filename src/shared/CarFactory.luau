--!nonstrict
-- Builds the blocky baby-blue starter car procedurally, so there is no asset dependency.
-- Layout numbers are the Blender model's coordinates (x forward, y left, z up).

local CarFactory = {}

function CarFactory.build(config)
	local S = config.Scale
	local baseZ = config.BlenderBodyCenterZ
	local colors = config.Colors

	local model = Instance.new("Model")
	model.Name = config.Name
	model:SetAttribute("IsCar", true)

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = config.BodySize
	chassis.Color = colors.Body
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.CustomPhysicalProperties = PhysicalProperties.new(config.Density, 0, 0, 1, 1)
	chassis.CFrame = CFrame.new()
	chassis.Parent = model
	model.PrimaryPart = chassis

	local function attach(name, size, localCFrame, color, shape)
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = chassis.CFrame * localCFrame
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chassis
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	-- Blender (x fwd, y left, z up) -> chassis-local (x right, y up, z back)
	local function blk(name, sizeB, centerB, color)
		local size = Vector3.new(sizeB.Y * S, sizeB.Z * S, sizeB.X * S)
		local pos = Vector3.new(centerB.Y * S, (centerB.Z - baseZ) * S, -centerB.X * S)
		return attach(name, size, CFrame.new(pos), color)
	end

	-- Body panels
	blk("Hood", Vector3.new(1.3, 1.7, 0.16), Vector3.new(1.5, 0, 1.12), colors.Hood)
	blk("Cabin", Vector3.new(2.7, 1.85, 0.9), Vector3.new(-0.75, 0, 1.55), colors.Body)

	-- Windows
	blk("Windshield", Vector3.new(0.05, 1.5, 0.6), Vector3.new(0.62, 0, 1.6), colors.Glass)
	blk("RearWindow", Vector3.new(0.05, 1.5, 0.5), Vector3.new(-2.11, 0, 1.62), colors.Glass)

	for _, s in { 1, -1 } do
		local tag = s == 1 and "L" or "R"
		local y = s * 0.93
		blk("Win_" .. tag .. "1", Vector3.new(0.75, 0.05, 0.5), Vector3.new(-1.65, y, 1.62), colors.Glass)
		blk("Win_" .. tag .. "2", Vector3.new(0.75, 0.05, 0.5), Vector3.new(-0.8, y, 1.62), colors.Glass)
		blk("Win_" .. tag .. "3", Vector3.new(0.6, 0.05, 0.5), Vector3.new(0.05, y, 1.62), colors.Glass)
		blk("Trim_" .. tag, Vector3.new(3.4, 0.05, 0.12), Vector3.new(-0.3, s * 1.0, 0.72), colors.Trim)
		blk("Mirror_" .. tag, Vector3.new(0.18, 0.22, 0.16), Vector3.new(0.55, s * 1.03, 1.5), colors.Body)
		blk("Rail_" .. tag, Vector3.new(2.4, 0.08, 0.08), Vector3.new(-0.75, s * 0.6, 2.06), colors.Trim)
		blk("Head_" .. tag, Vector3.new(0.08, 0.42, 0.3), Vector3.new(2.2, s * 0.68, 0.95), colors.Lamp)
		blk("Tail_" .. tag, Vector3.new(0.08, 0.34, 0.3), Vector3.new(-2.2, s * 0.68, 0.95), colors.Tail)
	end
	blk("RoofBar1", Vector3.new(0.08, 1.3, 0.08), Vector3.new(-1.6, 0, 2.06), colors.Trim)
	blk("RoofBar2", Vector3.new(0.08, 1.3, 0.08), Vector3.new(-0.1, 0, 2.06), colors.Trim)
	blk("BumperF", Vector3.new(0.3, 2.0, 0.28), Vector3.new(2.2, 0, 0.55), colors.Trim)
	blk("BumperR", Vector3.new(0.3, 2.0, 0.28), Vector3.new(-2.2, 0, 0.55), colors.Trim)

	-- Driver seat (invisible, the player's avatar sits here hidden)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 0.6, 2) * (S / 3)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanQuery = false
	seat.Massless = true
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.CFrame = chassis.CFrame * CFrame.new(0, config.BodySize.Y / 2 + 0.3 * S / 3, 1.5 * S / 3)
	seat.Parent = model
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = chassis
	seatWeld.Part1 = seat
	seatWeld.Parent = seat

	-- Wheels: moved every frame by CarPhysics through Weld.C0
	for _, w in config.Wheels do
		local restCFrame =
			CFrame.new(w.Mount - Vector3.new(0, config.SuspensionRest * (1 - config.StaticCompression), 0))
		local diameter = config.WheelRadius * 2
		local wheel = attach(
			"Wheel_" .. w.Name,
			Vector3.new(config.WheelWidth, diameter, diameter),
			restCFrame,
			colors.Tire,
			Enum.PartType.Cylinder
		)
		wheel:FindFirstChildOfClass("WeldConstraint"):Destroy()

		local weld = Instance.new("Weld")
		weld.Name = "WheelWeld_" .. w.Name
		weld.Part0 = chassis
		weld.Part1 = wheel
		weld.C0 = restCFrame
		weld.Parent = chassis

		local side = w.Mount.X >= 0 and 1 or -1
		local hub = Instance.new("Part")
		hub.Name = "Hub_" .. w.Name
		hub.Shape = Enum.PartType.Cylinder
		hub.Size = Vector3.new(0.15 * S / 3, config.WheelRadius * 1.1, config.WheelRadius * 1.1)
		hub.Color = colors.Hub
		hub.Material = Enum.Material.SmoothPlastic
		hub.CanCollide = false
		hub.CanQuery = false
		hub.CanTouch = false
		hub.Massless = true
		hub.CFrame = wheel.CFrame * CFrame.new(side * (config.WheelWidth / 2 + 0.02 * S / 3), 0, 0)
		hub.Parent = model
		local hubWeld = Instance.new("WeldConstraint")
		hubWeld.Part0 = wheel
		hubWeld.Part1 = hub
		hubWeld.Parent = hub
	end

	return model
end

return CarFactory
