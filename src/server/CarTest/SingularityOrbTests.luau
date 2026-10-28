--!nonstrict
-- BRIEF: docs/CAR_REDESIGN_SPEC.md section 11 (owner, 2026-10-27), design doc "Owner, 2026-10-27 (Singularity orb":
-- "Singularity's black hole is smaller and floats above the engine deck (no stand). It spins and bobs up and down,
-- with a bright neon glow around its black core. The motion plays on each client only; it never changes physics,
-- speed or payouts." Also CAR_REDESIGN_SPEC sections 2 (bounds, Neon rule) and 7, and docs/VEHICLE_SKINS_SPEC.md
-- "Optional animated parts" (parts with Orb = true spin and bob on the client). This scenario checks:
--   1. Template: CarModels.singularity has exactly three Orb = true MeshParts, Metal2 (Metal), Light3 and Light4
--      (Neon), all centred on one point; the core is smaller than ring and halo; core holds PointLight OrbGlow
--      (Shadows false).
--   2. Motion (Shared/OrbMotion.Offset(t, reduced), pure maths): a finite, deterministic CFrame; translation only
--      vertical and within +-BOB_HEIGHT; rotation only about the vertical axis at SPIN_SPEED; bob periodic at
--      BOB_RATE (rad/s); reduced = no bob and a third of the spin.
--   3. Bounds: every orb part at rest * Offset(t) (normal and reduced, several periods) stays within section 2.
--   4. Apply: each orb part is joined by a Weld "SkinWeld" (AnimatedOrb = true, Part0 chassis, C0 = rest offset);
--      every other non-wheel skin part keeps a WeldConstraint; Display copies keep the three Orb parts anchored.
--   5. Physics: a Track 1-2 race with singularity equipped keeps the stability rules and the starter's speed and mass,
--      and the server never changes the orb welds (C0 unchanged after a few seconds and at the finish).
-- Not tested (docs leave them open or placeholders): the orb's exact size (0.26 / 0.46), the light's colour /
-- Brightness 3 / Range 10, the spin direction, whether BOB_HEIGHT is amplitude or peak-to-peak, ORB_DISTANCE, and
-- "floats above the engine deck, no spindle".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent

local ID = "singularity"
local STARTER = "starter"
local CONTROL = "rusty_hatchback" -- a car without an orb: Apply adds no AnimatedOrb weld
local ORB_PARTS = { Metal2 = Enum.Material.Metal, Light3 = Enum.Material.Neon, Light4 = Enum.Material.Neon }
local CORE = "Metal2"
local CENTRE_TOL = 0.02 -- studs: "all three are centred on the orb centre"
local CF_TOL = 1e-3 -- studs / rotation components: weld C0 vs rest offset
-- Section 2 bounds, same numbers and tolerance as RedesignTests (car_redesign).
local MAX_X, MAX_Z, MIN_Y, TOLERANCE = 1.95, 3.3, -0.01, 0.02
-- Motion sampling
local DT = 0.05
local PERIODS = 3 -- sample this many of the slowest (bob or spin) periods
local RATE_TOL = 0.02 -- spin rate within 2% of SPIN_SPEED (or SPIN_SPEED / 3 reduced)
local MOTION_EPS = 1e-6
local PERIODIC_TOL = 1e-4
local BOB_REACH = 0.5 -- the bob reaches at least half BOB_HEIGHT (holds whether it is amplitude or peak-to-peak)
local REDUCED_SPIN = 1 / 3
-- Physics (copied from wyvern_flight)
local RUN_ORIGIN = Vector3.new(-44000, 0, 44000) -- this scenario's own chain, far from every other scenario origin
local SPEED_TOL = 0.02
local SAMPLE_AFTER = 3
local SAMPLE_AFTER_STUDS = 30
local MASS_TOL = 1e-3
local WELD_CHECK_AFTER = 3 -- seconds of RaceService driving before the first orb weld comparison

local Tests = {}

local function finiteCF(cf)
	for _, v in { cf:GetComponents() } do
		if v ~= v or v == math.huge or v == -math.huge then
			return false
		end
	end
	return true
end
local function cfDiff(a, b)
	local ca, cb, worst = { a:GetComponents() }, { b:GetComponents() }, 0
	for i = 1, 12 do
		worst = math.max(worst, math.abs(ca[i] - cb[i]))
	end
	return worst
end
local function wrap(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end
local function yaw(cf)
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end
local function nearestOnPolyline(pts, p, lo, hi)
	local best, bestI = math.huge, lo
	for i = math.max(lo, 1), math.min(hi, #pts - 1) do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local len2 = ab:Dot(ab)
		if len2 > 1e-6 then
			local d = (p - (a + ab * math.clamp((p - a):Dot(ab) / len2, 0, 1))).Magnitude
			if d < best then
				best, bestI = d, i
			end
		end
	end
	return best, bestI
end
local function orbParts(root)
	local out = {}
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Orb") == true then
			table.insert(out, part)
		end
	end
	return out
end
-- Extent of a box at `cf` (pivot space): max |x|, max |z|, min y over its corners.
local function boxExtent(cf, size)
	local h = size / 2
	local maxX, maxZ, minY = 0, 0, math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
				maxX = math.max(maxX, math.abs(p.X))
				maxZ = math.max(maxZ, math.abs(p.Z))
				minY = math.min(minY, p.Y)
			end
		end
	end
	return maxX, maxZ, minY
end

function Tests.singularity_orb()
	local r, flag = H.report("singularity_orb")
	local metrics = r.metrics
	local catalog = H.module(Shared, "CarCatalog")
	local appearance = H.module(Shared, "CarAppearance")
	local factory = H.module(Shared, "CarFactory")
	local carConfig = H.module(Shared, "CarConfig")
	local targets = H.module(Shared, "PhysicsTargets")
	local motion = H.module(Shared, "OrbMotion")
	local baseOk = catalog ~= nil
		and appearance ~= nil
		and factory ~= nil
		and carConfig ~= nil
		and targets ~= nil
		and type(appearance.Apply) == "function"
		and type(appearance.Display) == "function"
	flag("orb_base_api_exists", baseOk)
	local motionOk = motion ~= nil
		and type(motion.Offset) == "function"
		and type(motion.SPIN_SPEED) == "number"
		and motion.SPIN_SPEED > 0
		and type(motion.BOB_HEIGHT) == "number"
		and motion.BOB_HEIGHT > 0
		and type(motion.BOB_RATE) == "number"
		and motion.BOB_RATE > 0
	flag("orb_motion_module_exists", motionOk)
	local client = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	client = client and client:FindFirstChild("Client")
	flag("orb_animator_exists", client ~= nil and client:FindFirstChild("OrbAnimator", true) ~= nil)
	if not baseOk then
		return r
	end
	local cleanup = {}
	local ok, err = pcall(function()
		-- 1. Template
		local spec = catalog.Get(ID)
		local templates = ReplicatedStorage:FindFirstChild("CarModels")
		local template = spec and templates and templates:FindFirstChild(spec.Model or ID)
		local templateOk = template ~= nil and template:IsA("Model")
		flag("orb_template_exists", templateOk)
		if not templateOk then
			return
		end
		local orbs = orbParts(template)
		local byName = {}
		for _, part in orbs do
			byName[part.Name] = part
		end
		flag("orb_part_count", #orbs == 3, #orbs, 3)
		for name, material in ORB_PARTS do
			local part = byName[name]
			flag("orb_part_" .. name, part ~= nil and part:IsA("MeshPart"))
			flag(
				"orb_material_" .. name,
				part ~= nil and part.Material == material,
				part and part.Material.Name or "missing",
				material.Name
			)
		end
		local core = byName[CORE]
		local worstCentre = 0
		if core then
			for _, part in orbs do
				worstCentre = math.max(worstCentre, (part.Position - core.Position).Magnitude)
			end
		end
		flag("orb_parts_concentric", core ~= nil and #orbs == 3 and worstCentre <= CENTRE_TOL, worstCentre, CENTRE_TOL)
		local function maxDim(p)
			return p and math.max(p.Size.X, p.Size.Y, p.Size.Z) or 0
		end
		-- Section 2/11: the core sits inside the ring; the halo is a thicker shell around the core.
		flag(
			"orb_core_inside_ring",
			core ~= nil and byName.Light3 ~= nil and maxDim(core) < maxDim(byName.Light3),
			maxDim(core),
			maxDim(byName.Light3)
		)
		flag(
			"orb_core_inside_halo",
			core ~= nil and byName.Light4 ~= nil and maxDim(core) < maxDim(byName.Light4),
			maxDim(core),
			maxDim(byName.Light4)
		)
		local glow = core and core:FindFirstChild("OrbGlow")
		local glowOk = glow ~= nil and glow:IsA("PointLight")
		flag("orb_glow_light", glowOk)
		flag("orb_glow_no_shadows", glowOk and glow.Shadows == false)
		flag("orb_glow_lit", glowOk and glow.Brightness > 0 and glow.Range > 0, glowOk and glow.Brightness or -1, 0)
		metrics.orb_core_size = maxDim(core)
		metrics.orb_ring_size = maxDim(byName.Light3)
		metrics.orb_halo_size = maxDim(byName.Light4)

		-- 2. Motion and 3. bounds (own function: an early return skips only these, never the race)
		local function motionChecks()
			local slowest = math.max(2 * math.pi / motion.BOB_RATE, 2 * math.pi / (motion.SPIN_SPEED * REDUCED_SPIN))
			local steps = math.ceil(PERIODS * slowest / DT)
			local finite, determ = true, true
			local maxSide, maxBob, worstTilt = 0, { [false] = 0, [true] = 0 }, 1
			local worstRate = { [false] = 0, [true] = 0 }
			local signs = { [false] = {}, [true] = {} }
			local periodic = 0
			local bobPeriod = 2 * math.pi / motion.BOB_RATE
			local samples = { [false] = {}, [true] = {} }
			for _, reduced in { false, true } do
				local want = motion.SPIN_SPEED * (reduced and REDUCED_SPIN or 1)
				local prev
				for i = 0, steps do
					local t = i * DT
					local cf = motion.Offset(t, reduced)
					if typeof(cf) ~= "CFrame" then
						flag("orb_offset_is_cframe", false, typeof(cf), "CFrame")
						return
					end
					local again = motion.Offset(t, reduced)
					determ = determ and typeof(again) == "CFrame" and cfDiff(cf, again) == 0
					finite = finite and finiteCF(cf)
					samples[reduced][i] = cf
					maxSide = math.max(maxSide, math.abs(cf.Position.X), math.abs(cf.Position.Z))
					maxBob[reduced] = math.max(maxBob[reduced], math.abs(cf.Position.Y))
					worstTilt = math.min(worstTilt, cf.UpVector.Y)
					if prev then
						local d = wrap(yaw(cf) - yaw(prev))
						worstRate[reduced] = math.max(worstRate[reduced], math.abs(math.abs(d) / DT - want) / want)
						signs[reduced][d >= 0 and 1 or -1] = true
					end
					prev = cf
					if not reduced and t + bobPeriod <= steps * DT then
						local later = motion.Offset(t + bobPeriod, false)
						if typeof(later) == "CFrame" then
							periodic = math.max(periodic, math.abs(later.Position.Y - cf.Position.Y))
						end
					end
				end
			end
			flag("orb_offset_is_cframe", true)
			flag("orb_offset_finite", finite)
			flag("orb_offset_deterministic", determ)
			flag("orb_offset_vertical_only", maxSide <= MOTION_EPS, maxSide, MOTION_EPS)
			flag("orb_rotation_about_vertical", worstTilt >= 1 - MOTION_EPS, worstTilt, 1 - MOTION_EPS)
			local bh = motion.BOB_HEIGHT
			flag("orb_bob_within_height", maxBob[false] <= bh + MOTION_EPS, maxBob[false], bh)
			flag("orb_bob_moves", maxBob[false] >= BOB_REACH * bh, maxBob[false], BOB_REACH * bh)
			flag("orb_bob_rate", periodic <= PERIODIC_TOL, periodic, PERIODIC_TOL)
			flag("orb_spin_rate", worstRate[false] <= RATE_TOL, worstRate[false], RATE_TOL)
			flag("orb_spin_one_direction", not (signs[false][1] and signs[false][-1]))
			flag("orb_reduced_no_bob", maxBob[true] <= MOTION_EPS, maxBob[true], MOTION_EPS)
			flag("orb_reduced_spin_third", worstRate[true] <= RATE_TOL, worstRate[true], RATE_TOL)
			flag("orb_reduced_spin_one_direction", not (signs[true][1] and signs[true][-1]))
			metrics.orb_max_bob = maxBob[false]

			-- 3. Bounds at every sampled offset: C0 = rest * Offset(t), rest in the template's pivot space.
			if #orbs == 0 then
				return
			end
			local pivot = template:GetPivot()
			local wx, wz, wy = 0, 0, math.huge
			for _, part in orbs do
				local rest = pivot:ToObjectSpace(part.CFrame)
				for _, reduced in { false, true } do
					for i = 0, steps do
						local x, z, y = boxExtent(rest * samples[reduced][i], part.Size)
						wx, wz, wy = math.max(wx, x), math.max(wz, z), math.min(wy, y)
					end
				end
			end
			flag("orb_bounds_x", wx <= MAX_X + TOLERANCE, wx, MAX_X)
			flag("orb_bounds_z", wz <= MAX_Z + TOLERANCE, wz, MAX_Z)
			flag("orb_bounds_floor", wy >= MIN_Y - TOLERANCE, wy, MIN_Y)
		end
		if motionOk then
			motionChecks()
		end

		-- 4. Apply: orb parts get an animated Weld, the rest keep WeldConstraints.
		local wheelNames = {}
		for _, wheel in carConfig.Wheels do
			wheelNames["Wheel_" .. wheel.Name] = true
		end
		local rig = factory.build(carConfig)
		table.insert(cleanup, rig) -- never parent a physics rig into the live world
		local applied = appearance.Apply(rig, ID, carConfig)
		local skin = rig:FindFirstChild("EquippedVisual")
		flag("orb_apply_skin", applied == true and skin ~= nil)
		if skin then
			local chassis = rig.PrimaryPart
			local tPivot = template:GetPivot()
			local base = CFrame.new(0, -carConfig.RestHeight, 0)
			local skinOrbs = orbParts(skin)
			flag("orb_apply_part_count", #skinOrbs == 3, #skinOrbs, 3)
			for _, part in skinOrbs do
				local welds = {}
				for _, child in part:GetChildren() do
					if child:IsA("JointInstance") or child:IsA("WeldConstraint") then
						table.insert(welds, child)
					end
				end
				local weld = part:FindFirstChild("SkinWeld")
				local isWeld = #welds == 1 and weld ~= nil and weld.ClassName == "Weld"
				flag("orb_weld_is_weld_" .. part.Name, isWeld, weld and weld.ClassName or "missing", "Weld")
				flag("orb_weld_attr_" .. part.Name, isWeld and weld:GetAttribute("AnimatedOrb") == true)
				flag("orb_weld_part0_chassis_" .. part.Name, isWeld and weld.Part0 == chassis and weld.Part1 == part)
				local src = template:FindFirstChild(part.Name, true)
				local rest = src and base * tPivot:ToObjectSpace(src.CFrame)
				local d = isWeld and rest and cfDiff(weld.C0, rest) or math.huge
				flag("orb_weld_c0_rest_" .. part.Name, d <= CF_TOL, d, CF_TOL)
				local d1 = isWeld and cfDiff(weld.C1, CFrame.identity) or math.huge
				flag("orb_weld_c1_identity_" .. part.Name, d1 <= CF_TOL, d1, CF_TOL)
			end
			local badStatic = 0
			for _, part in skin:GetDescendants() do
				if part:IsA("BasePart") and part:GetAttribute("Orb") ~= true and not wheelNames[part.Name] then
					local weld = part:FindFirstChild("SkinWeld")
					if not (weld and weld:IsA("WeldConstraint")) then
						badStatic += 1
					end
				end
			end
			flag("orb_other_parts_weld_constraint", badStatic == 0, badStatic, 0)
		end
		-- A car without an orb gets no AnimatedOrb weld.
		local otherRig = factory.build(carConfig)
		table.insert(cleanup, otherRig)
		local strayOrbWelds = 0
		if appearance.Apply(otherRig, CONTROL, carConfig) then
			for _, d in otherRig:GetDescendants() do
				if d:GetAttribute("AnimatedOrb") ~= nil then
					strayOrbWelds += 1
				end
			end
		end
		flag("orb_control_car_no_orb_weld", strayOrbWelds == 0, strayOrbWelds, 0)
		-- Pedestal / display copies keep the three Orb parts, anchored (OrbAnimator moves them on the client).
		local display = appearance.Display(spec, CFrame.new(RUN_ORIGIN - Vector3.new(0, 500, 0)), 1)
		if display then
			table.insert(cleanup, display)
		end
		local dOrbs = display and orbParts(display) or {}
		local unanchored = 0
		for _, part in dOrbs do
			unanchored += part.Anchored and 0 or 1
		end
		flag("orb_display_parts_anchored", #dOrbs == 3 and unanchored == 0, #dOrbs, 3)

		-- 5. Physics: Track 1-2 race with singularity equipped vs the starter, same stat.
		local TrackRegistry = H.module(Shared, "TrackRegistry")
		local TrackBuilder = H.module(Shared, "TrackBuilder")
		local RaceConfig = H.module(Shared, "RaceConfig")
		local RaceService = H.module(Server, "RaceService")
		local PlayerData = H.module(Server, "PlayerData")
		local Money = H.module(Server, "MoneyService")
		local raceApi = TrackRegistry ~= nil
			and TrackBuilder ~= nil
			and RaceConfig ~= nil
			and RaceService ~= nil
			and PlayerData ~= nil
			and Money ~= nil
			and type(RaceService.NewRun) == "function"
			and type(RaceService.BuildRoute) == "function"
			and targets.lap ~= nil
			and type(targets.lap.MinUpYStrict) == "number"
			and targets.race ~= nil
			and type(targets.race.MaxPathDeviation) == "number"
		flag("orb_race_api_exists", raceApi)
		if not raceApi then
			return
		end
		local chain = TrackRegistry.Chain()
		flag("orb_race_two_tracks", #chain >= 2, #chain, 2)
		if #chain < 2 then
			return
		end
		local entries = {}
		local origin = CFrame.new(RUN_ORIGIN + Vector3.new(0, TrackBuilder.TRACK_LIFT or 0, 0))
		for i = 1, 2 do
			local model, layout = TrackBuilder.Build(chain[i], origin)
			model.Name = "CarTestOrbTrack" .. i
			model.Parent = Workspace
			table.insert(cleanup, model)
			entries[i] = { Layout = layout, Origin = origin, Model = model, Number = chain[i].Number }
			origin = TrackBuilder.EndCFrame(layout, origin)
		end
		local route = RaceService.BuildRoute(entries)
		local wps = route.Path.WorldWaypoints
		local totalLen = 0
		for i = 2, #wps do
			totalLen += (wps[i] - wps[i - 1]).Magnitude
		end
		local startCF = entries[1].Model.Start.CFrame + Vector3.new(0, carConfig.RestHeight, 0)
		local strict, maxDev, flipUp = targets.lap.MinUpYStrict, targets.race.MaxPathDeviation, targets.lap.MinUpY

		local function orbWelds(car)
			local out = {}
			local vis = car:FindFirstChild("EquippedVisual")
			for _, part in vis and orbParts(vis) or {} do
				local weld = part:FindFirstChild("SkinWeld")
				if weld and weld:IsA("Weld") then
					out[part.Name] = { Weld = weld, C0 = weld.C0, Part0 = weld.Part0 }
				end
			end
			return out
		end
		-- Worst C0 change of the orb welds since `first` (math.huge when a weld vanished or was re-parented).
		local function weldDrift(car, first)
			local now, worst, n = orbWelds(car), 0, 0
			for name, w in first do
				n += 1
				local cur = now[name]
				if not (cur and cur.Weld == w.Weld and cur.Part0 == w.Part0) then
					return math.huge
				end
				worst = math.max(worst, cfDiff(cur.C0, w.C0))
			end
			return n == 3 and worst or math.huge
		end

		local function drive(carId, stat)
			local st = { flips = 0, minUp = 1, dev = 0, devN = 0, speedSum = 0, speedN = 0 }
			local car = factory.build(carConfig)
			car.Name = "CarTestOrbCar"
			appearance.Apply(car, carId, carConfig)
			car:PivotTo(startCF)
			car.Parent = Workspace
			local player = Instance.new("Folder")
			player.Name = "CarTestOrbPlayer"
			player:SetAttribute("EquippedCar", carId)
			player.Parent = Workspace
			table.insert(cleanup, car)
			table.insert(cleanup, player)
			Money.Setup(player)
			PlayerData.Setup(player)
			player.BaseSpeed.Value = stat -- base Speed (owner 2026-10-21), as the race scenario sets it
			local run = RaceService.NewRun(car, route, player, nil)
			local raceSkin = car:FindFirstChild("EquippedVisual")
			st.skinId = raceSkin and raceSkin:GetAttribute("CarId")
			local firstWelds = orbWelds(car)
			local chassis = car.PrimaryPart
			st.mass = chassis.AssemblyMass
			st.target = run.TargetSpeed
			local target = type(run.TargetSpeed) == "number" and run.TargetSpeed or 1
			local timeout = totalLen / (0.5 * target) + 40
			local t, idx, dist, flippedFor, wasFlipped = 0, 1, 0, 0, false
			while t < timeout and run.Finished ~= true do
				local dt = RunService.Heartbeat:Wait()
				t += dt
				if st.earlyDrift == nil and t >= WELD_CHECK_AFTER then
					st.earlyDrift = weldDrift(car, firstWelds)
				end
				local pos = chassis.Position
				local speed = chassis.AssemblyLinearVelocity.Magnitude
				dist += speed * dt
				local d, seg = nearestOnPolyline(wps, pos, math.max(idx - 3, 1), math.min(idx + 25, #wps - 1))
				idx = seg
				local upY = chassis.CFrame.UpVector.Y
				if not (run.Physics and run.Physics.LoopAssist) then
					st.minUp = math.min(st.minUp, upY)
				end
				if t > SAMPLE_AFTER or dist >= SAMPLE_AFTER_STUDS then
					st.dev = math.max(st.dev, d)
					st.devN += 1
					st.speedSum += speed
					st.speedN += 1
				end
				if upY < flipUp then
					flippedFor += dt
					if not wasFlipped and flippedFor > 1 then
						st.flips += 1
						wasFlipped = true
					end
				else
					flippedFor, wasFlipped = 0, false
				end
			end
			st.endDrift = weldDrift(car, firstWelds)
			st.finished = run.Finished == true
			st.runMinUp = run.MinUpY
			st.runDev = run.MaxPathDeviation
			st.recoveries = run.FlipRecoveries
			st.offTrack = run.OffTrackSeconds
			st.meanSpeed = st.speedN > 0 and st.speedSum / st.speedN or 0
			pcall(function()
				run:Destroy()
			end)
			return st
		end
		local function stability(pre, st)
			flag(pre .. "_skin_equipped", st.skinId == ID, tostring(st.skinId), ID)
			flag(pre .. "_finished", st.finished)
			flag(pre .. "_flips", st.flips == 0, st.flips, 0)
			local rec = type(st.recoveries) == "number" and st.recoveries or -1
			flag(pre .. "_no_flip_recoveries", rec == 0, rec, 0)
			local off = type(st.offTrack) == "number" and st.offTrack or math.huge
			flag(pre .. "_off_track", off == 0, off, 0)
			flag(pre .. "_body_never_tilted", st.minUp >= strict, st.minUp, strict)
			local rm = type(st.runMinUp) == "number" and st.runMinUp or -1
			flag(pre .. "_never_tilted", rm >= strict, rm, strict)
			flag(pre .. "_path_deviation", st.devN > 0 and st.dev <= maxDev, st.dev, maxDev)
			local rd = type(st.runDev) == "number" and st.runDev or math.huge
			flag(pre .. "_run_path_deviation", rd <= maxDev, rd, maxDev)
			-- "the server never changes it" (section 11): same Weld, Part0 and C0 after a few seconds and at the end.
			local early = st.earlyDrift or math.huge
			flag(pre .. "_orb_weld_unchanged_early", early <= 1e-9, early, 0)
			flag(pre .. "_orb_weld_unchanged_end", st.endDrift <= 1e-9, st.endDrift, 0)
		end

		local half = RaceConfig.HALF_STAT
		local starter = drive(STARTER, half)
		local orb = drive(ID, half)
		stability("orb_race", orb)
		local same = type(orb.target) == "number"
			and type(starter.target) == "number"
			and math.abs(orb.target - starter.target) <= 1e-6
		flag("orb_race_cruise_equals_starter", same, orb.target or -1, starter.target or -1)
		local ratio = starter.meanSpeed > 0 and orb.meanSpeed / starter.meanSpeed or -1
		flag("orb_race_speed_equals_starter", math.abs(ratio - 1) <= SPEED_TOL, ratio, 1)
		flag("orb_race_mass_equals_starter", math.abs(orb.mass - starter.mass) <= MASS_TOL, orb.mass, starter.mass)
		metrics.orb_mean_speed = orb.meanSpeed
		metrics.starter_mean_speed = starter.meanSpeed
		-- Stability rules also hold at the maximum stat speed (CLAUDE.md "Stability rules").
		if type(RaceConfig.MAX_STAT) == "number" then
			stability("orb_race_max", drive(ID, RaceConfig.MAX_STAT))
		else
			flag("orb_race_max_stat_exists", false)
		end
	end)
	for i = #cleanup, 1, -1 do
		pcall(function()
			cleanup[i]:Destroy()
		end)
	end
	flag("orb_no_error", ok, ok and 1 or tostring(err))
	return r
end

return Tests
