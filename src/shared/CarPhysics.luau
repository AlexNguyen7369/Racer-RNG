--!nonstrict
-- Raycast-suspension vehicle model. One implementation shared by the player's client
-- (CarController) and the server-side test harness (CarTest), so what we test is what ships.
--
-- Input: { Throttle = -1..1, Steer = -1..1 (+1 = right), Brake = 0..1, Handbrake = boolean }
-- Call :Step(input, dt) once per PreSimulation on whichever machine owns the chassis.

local CarPhysics = {}
CarPhysics.__index = CarPhysics

local function sign(x)
	return x >= 0 and 1 or -1
end

function CarPhysics.new(model, config)
	local chassis = model.PrimaryPart
	assert(chassis, "car model needs a PrimaryPart")

	local wheels = {}
	for _, w in config.Wheels do
		table.insert(wheels, {
			Cfg = w,
			Part = model:FindFirstChild("Wheel_" .. w.Name),
			Weld = chassis:FindFirstChild("WheelWeld_" .. w.Name),
			Spin = 0,
			SpringLen = config.SuspensionRest,
			Grounded = false,
		})
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true
	params.IgnoreWater = true
	-- Other cars are in the same non-colliding group, so with this the wheel rays see the road, not them
	pcall(function()
		params.CollisionGroup = "Cars"
	end)
	local parkedAttachment = Instance.new("Attachment")
	parkedAttachment.Name = "ParkedStabilizerAttachment"
	parkedAttachment.Parent = chassis
	local parkedStabilizer = Instance.new("LinearVelocity")
	parkedStabilizer.Name = "ParkedStabilizer"
	parkedStabilizer.Attachment0 = parkedAttachment
	parkedStabilizer.RelativeTo = Enum.ActuatorRelativeTo.World
	parkedStabilizer.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	parkedStabilizer.VectorVelocity = Vector3.zero
	parkedStabilizer.ForceLimitsEnabled = false
	parkedStabilizer.Enabled = false
	parkedStabilizer.Parent = chassis
	return setmetatable({
		Model = model,
		Chassis = chassis,
		Config = config,
		Wheels = wheels,
		RayParams = params,
		SteerAngle = 0,
		-- read-only telemetry, refreshed every Step
		GroundedCount = 0,
		ForwardSpeed = 0,
		LateralSpeed = 0,
		Speed = 0,
		ParkedTime = 0,
		Parked = false,
		ParkedStabilizer = parkedStabilizer,
	}, CarPhysics)
end

function CarPhysics:Step(input, dt)
	dt = math.min(dt, 1 / 30)
	local cfg = self.Config
	local chassis = self.Chassis
	local cf = chassis.CFrame
	local up = cf.UpVector
	local look = cf.LookVector
	local mass = chassis.AssemblyMass
	local gravity = workspace.Gravity
	local wheels = self.Wheels
	local n = #wheels
	local cornerMass = mass / n
	local rest, radius = cfg.SuspensionRest, cfg.WheelRadius
	local k = cornerMass * gravity / (cfg.StaticCompression * rest)
	-- Keep drop settling critically damped even when the server delivers a hitch-sized
	-- step. The implicit solve remains stable, while the extra margin prevents parked
	-- chassis velocity from reappearing after suspension contact.
	local c = 2.5 * cfg.DampingRatio * math.sqrt(k * cornerMass)
	local vel = chassis.AssemblyLinearVelocity
	local fwdSpeed = vel:Dot(look)
	local com = chassis.AssemblyCenterOfMass

	-- Steering: less authority at speed, smoothed. Steer +1 = right, wheel angle +ve = left.
	local speedFactor = 1 / (1 + (math.abs(fwdSpeed) / cfg.SteerFalloffSpeed) ^ 2)
	local steerTarget = -input.Steer * cfg.MaxSteer * math.max(speedFactor, cfg.MinSteerFactor)
	self.SteerAngle += (steerTarget - self.SteerAngle) * math.min(1, dt * cfg.SteerRate)

	-- Pedals: reverse throttle while rolling forwards becomes braking until nearly stopped.
	-- Forward throttle while rolling backwards (e.g. down a slope) always drives: braking there
	-- would pin the car at ~1 stud/s and stop it ever climbing.
	local throttle, brake = input.Throttle, input.Brake
	if throttle < 0 and fwdSpeed > 1 then
		brake = math.max(brake, math.abs(throttle))
		throttle = 0
	end
	if input.Handbrake then
		throttle = 0
	end

	local driveCount = 0
	for _, w in wheels do
		if w.Cfg.Drive then
			driveCount += 1
		end
	end

	local grounded = 0
	local lateralSpeedSum = 0
	local loopAssist = false

	-- Pass 1: suspension rays. Spring load (with a bump stop near full compression) per grounded wheel.
	local down = -up
	for _, w in wheels do
		local hit = workspace:Raycast(cf:PointToWorldSpace(w.Cfg.Mount), down * (rest + radius), self.RayParams)
		w.Hit = hit
		if hit then
			if hit.Instance:GetAttribute("LoopAssist") then
				loopAssist = true
			end
			local springLen = math.clamp(hit.Distance - radius, 0, rest)
			local compression = rest - springLen
			w.SpringLen = springLen
			w.SpringLoad = k * compression
			w.Stiffness = k
			if compression > rest * 0.9 then
				w.SpringLoad += k * 8 * (compression - rest * 0.9)
				w.Stiffness = k * 9
			end
		end
	end

	-- Pass 2: implicit (backward Euler) spring/damper solve over heave, pitch and roll.
	-- An explicit per-corner damper assumes each wheel carries mass/4, but the chassis' roll inertia is
	-- about 3x smaller than that, so the explicit roll mode sits on the edge of stability at 60 Hz and
	-- blows up at lower frame rates (the car chatters, rolls and flips). Solving for the post-step
	-- velocity makes the suspension stable at any dt; statics are unchanged (gravity is in the solve).
	-- Generalised velocity q = (heave along up, pitch rate about local X, roll rate about local Z).
	local size = chassis.Size
	local Ix = mass * (size.Y * size.Y + size.Z * size.Z) / 12
	local Iz = mass * (size.X * size.X + size.Y * size.Y) / 12
	local comLocal = cf:PointToObjectSpace(com)
	local angVel = chassis.AssemblyAngularVelocity
	local q1, q2, q3 = vel:Dot(up), angVel:Dot(cf.XVector), angVel:Dot(cf.ZVector)
	-- A = M + dt * sum(c' G G^T), rhs = M q + dt * sum(G F) + gravity impulse (per unit of q)
	local a11, a12, a13, a22, a23, a33 = mass, 0, 0, Ix, 0, Iz
	local gravityUp = loopAssist and 0 or -gravity * up.Y * dt * mass
	local r1, r2, r3 = mass * q1 + gravityUp, Ix * q2, Iz * q3
	for _, w in wheels do
		if w.Hit then
			local r = w.Cfg.Mount - comLocal
			local g1, g2, g3 = 1, -r.Z, r.X -- mount velocity along up = G . q; up-force f gives wrench f * G
			w.G1, w.G2, w.G3 = g1, g2, g3
			w.DampEff = c + dt * w.Stiffness
			local cd = dt * w.DampEff
			a11 += cd * g1 * g1
			a12 += cd * g1 * g2
			a13 += cd * g1 * g3
			a22 += cd * g2 * g2
			a23 += cd * g2 * g3
			a33 += cd * g3 * g3
			r1 += dt * w.SpringLoad * g1
			r2 += dt * w.SpringLoad * g2
			r3 += dt * w.SpringLoad * g3
		end
	end
	-- Symmetric 3x3 solve (Cramer's rule)
	local det = a11 * (a22 * a33 - a23 * a23) - a12 * (a12 * a33 - a23 * a13) + a13 * (a12 * a23 - a22 * a13)
	local p1, p2, p3 = q1, q2, q3
	if math.abs(det) > 1e-9 then
		p1 = (r1 * (a22 * a33 - a23 * a23) - a12 * (r2 * a33 - a23 * r3) + a13 * (r2 * a23 - a22 * r3)) / det
		p2 = (a11 * (r2 * a33 - a23 * r3) - r1 * (a12 * a33 - a23 * a13) + a13 * (a12 * r3 - r2 * a13)) / det
		p3 = (a11 * (a22 * r3 - r2 * a23) - a12 * (a12 * r3 - r2 * a13) + r1 * (a12 * a23 - a22 * a13)) / det
	end

	for _, w in wheels do
		local mount = w.Cfg.Mount
		local origin = cf:PointToWorldSpace(mount)
		local hit = w.Hit

		if hit then
			grounded += 1
			w.Grounded = true

			-- Suspension force from the post-step compression rate (never pulls the car down)
			local compRate = -(w.G1 * p1 + w.G2 * p2 + w.G3 * p3)
			local springForce = math.max(w.SpringLoad + w.DampEff * compRate, 0)

			-- Ground-plane wheel basis (front wheels are steered)
			local normal = hit.Normal
			local steer = w.Cfg.Front and self.SteerAngle or 0
			local wheelLook = (cf * CFrame.Angles(0, steer, 0)).LookVector
			local fwd = (wheelLook - normal * wheelLook:Dot(normal)).Unit
			local right = fwd:Cross(normal)

			local contact = hit.Position
			local cv = chassis:GetVelocityAtPosition(contact)
			local vLong, vLat = cv:Dot(fwd), cv:Dot(right)
			lateralSpeedSum += vLat

			-- Longitudinal: drive (with torque taper), brakes, coasting drag
			local fLong = 0
			if w.Cfg.Drive and throttle ~= 0 then
				-- Auto-race supplies a stat-derived target that may exceed the
				-- vehicle's legacy baseline TopSpeed. Keep the baseline for all
				-- other inputs and preserve the separate reverse limit.
				local top = throttle > 0 and (input.TargetSpeed or cfg.TopSpeed) or cfg.ReverseTopSpeed
				local taper = math.clamp(1 - math.abs(fwdSpeed) / top, 0, 1)
				fLong += throttle * cfg.EngineAccel * mass / driveCount * taper
			end
			if brake > 0 then
				local wanted = brake * cfg.BrakeAccel * cornerMass
				local stopAll = math.abs(vLong) * cornerMass / dt
				fLong -= sign(vLong) * math.min(wanted, stopAll)
			elseif throttle == 0 then
				fLong -= vLong * cfg.RollingDrag * cornerMass
			end

			-- Lateral: cancel sideways slip, limited by the friction budget
			local mu = cfg.Mu
			if input.Handbrake and not w.Cfg.Front then
				mu *= cfg.HandbrakeRearMu
			end
			local maxF = mu * springForce
			local latLimit = math.min(maxF, math.abs(vLat) * cornerMass / dt)
			local fLat = math.clamp(-vLat * cornerMass * cfg.LateralResponse, -latLimit, latLimit)

			-- Friction circle
			local mag = math.sqrt(fLong * fLong + fLat * fLat)
			if mag > maxF and mag > 0 then
				local scale = maxF / mag
				fLong *= scale
				fLat *= scale
			end

			-- Apply. Friction is applied partway up towards the centre of mass to resist roll/pitch.
			local h = up:Dot(com - contact)
			chassis:ApplyImpulseAtPosition(up * springForce * dt, origin)
			chassis:ApplyImpulseAtPosition(fwd * fLong * dt, contact + up * h * cfg.LongitudinalApplyBlend)
			chassis:ApplyImpulseAtPosition(right * fLat * dt, contact + up * h * cfg.LateralApplyBlend)

			w.Spin -= vLong / radius * dt
		else
			w.Grounded = false
			w.SpringLen = rest
			w.Spin -= fwdSpeed / radius * dt
		end

		if w.Weld then
			w.Weld.C0 = CFrame.new(mount - Vector3.new(0, w.SpringLen, 0))
				* CFrame.Angles(0, w.Cfg.Front and self.SteerAngle or 0, 0)
				* CFrame.Angles(w.Spin, 0, 0)
		end
	end

	-- Aero drag, and damped rotation while airborne
	local speed = vel.Magnitude
	if speed > 0.1 then
		chassis:ApplyImpulse(-vel.Unit * cfg.AeroDrag * speed * speed * mass * dt)
	end
	-- Vertical loops: no real car can climb 80 studs of circle at 90 studs/s, so while any wheel is on a
	-- LoopAssist road the car is weightless. Inertia still presses it into the road (centripetal force),
	-- so it sticks to the inside of the loop and exits at roughly the speed it entered.
	if loopAssist then
		chassis:ApplyImpulse(Vector3.new(0, gravity * mass * dt, 0))
	end
	self.LoopAssist = loopAssist
	if grounded == 0 and not loopAssist then
		chassis.AssemblyAngularVelocity *= math.max(0, 1 - cfg.AirAngularDamping * dt)
	end

	self.GroundedCount = grounded
	self.ForwardSpeed = fwdSpeed
	self.LateralSpeed = grounded > 0 and lateralSpeedSum / grounded or 0
	self.Speed = speed
	local idle = input.Throttle == 0 and input.Brake == 0 and not input.Handbrake
	local horizontalSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	if not idle or grounded ~= n then
		self.ParkedTime = 0
		self.Parked = false
	elseif not self.Parked then
		-- Ground contact is enough to begin settling; waiting for a low vertical
		-- velocity lets suspension rebounds keep resetting the parked state.
		if horizontalSpeed < 0.5 then
			self.ParkedTime += dt
		else
			self.ParkedTime = 0
		end
		self.Parked = self.ParkedTime >= 0.25
	else
		self.ParkedTime += dt
	end
	self.ParkedStabilizer.Enabled = self.Parked
	if self.Parked then
		chassis.AssemblyLinearVelocity = Vector3.zero
		chassis.AssemblyAngularVelocity = Vector3.zero
	end
end

-- Put the car upright at a CFrame (used for respawn / flip recovery).
function CarPhysics:Reset(cframe)
	self.Chassis.AssemblyLinearVelocity = Vector3.zero
	self.Chassis.AssemblyAngularVelocity = Vector3.zero
	self.Model:PivotTo(cframe)
	self.SteerAngle = 0
end

return CarPhysics
