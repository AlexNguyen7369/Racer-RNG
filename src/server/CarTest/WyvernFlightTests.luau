--!nonstrict
-- BRIEF: docs/WYVERN_FLIGHT_SPEC.md (owner, 2026-10-27): "when the dragon is auto racing, there is no flying
-- animation, have a physics test suite for that, also make the dragon bigger (this is an exception case) on the
-- pedestal and when auto racing. there should be dynamic wing flapping and the body should also have dynamic
-- animations." Design doc: "Owner, 2026-10-27 (Ember Wyvern flight)"; skin rules docs/VEHICLE_SKINS_SPEC.md (size
-- budget exception), mesh rules docs/CAR_REDESIGN_SPEC.md section 9. Spec section 5 lists what this scenario checks:
--   1. Catalog: ember_wyvern.SkinScale is a number > 1; no other car sets SkinScale.
--   2. Template: CarModels.ember_wyvern has Rig = "Wyvern" and every section 2 bone as a Bone descendant.
--   3. Size: CarAppearance.Apply scales the skin by SkinScale (bounding box within 2%), base still at tyre contact;
--      CarAppearance.Display uses CAR_SCALE * SkinScale; other cars unchanged; every skin part cosmetic.
--   4. Motion (Shared/WyvernMotion, pure maths): 10 s at 30 Hz, Speed 0/45/300, Turn -1/0/1, Reduced off/on.
--   5. Bounds: wing parts rotated by the Arm (and Root) pose stay within MAX_HALF_SPAN sideways once scaled.
--   6. Physics: Track 1-2 race with ember_wyvern equipped keeps the stability rules and the starter's cruise speed.
-- Pose convention (documented for the implementer): WyvernMotion.Pose(t, state)[bone] is a CFrame whose rotation is
-- a MODEL-SPACE rotation (template pivot axes: +Y up, -Z forward) about that bone's own joint; only Root may carry a
-- translation (heave). Angles (FLAP_DOWN, FLAP_UP) are RADIANS. Head yaw is the Y angle of ToEulerAnglesYXZ;
-- positive Turn = positive yaw rate about +Y (a left turn), so the head yaw has the sign of Turn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent

local ID = "ember_wyvern"
local STARTER = "starter"
local OTHER_PASS_CAR = "singularity" -- control: a pedestal car without SkinScale keeps CAR_SCALE
-- Spec section 2: every bone is required.
local SPEC_BONES = { "Root", "Spine1", "Spine2", "Neck1", "Neck2", "Neck3", "Neck4", "Head", "Jaw" }
for k = 1, 6 do
	table.insert(SPEC_BONES, "Tail" .. k)
end
for _, s in { "L", "R" } do
	for _, b in { "Thigh_", "Shin_", "Arm_", "Fore_", "Hand_" } do
		table.insert(SPEC_BONES, b .. s)
	end
	for k = 1, 4 do
		table.insert(SPEC_BONES, "Finger" .. k .. "_" .. s)
	end
end
local SIZE_TOL = 0.02 -- spec section 5: bounding box within 2%
local BASE_TOL = 0.05 -- studs: the scaled skin's base pivot stays at tyre contact height
-- Spec section 3 limits
local MAX_BONE_DEG = 60
local MIN_SWEEP_DEG = 40
local MAX_HEAD_YAW_DEG = 25
local MAX_TAIL_DEG = 14
local HEAD_YAW_PER_TURN = 0.35 -- rad of head yaw per rad/s of Turn
local GLIDE_FLUTTER_DEG = 4 -- glide: at most 4 deg flutter, so a held glide spans at most 2 x 4 deg
local REDUCED_AMPLITUDE = 0.6 -- Reduced is "half the amplitude": allow up to 0.6 of the normal sweep
local REDUCED_TOL_DEG = 1 -- Reduced: no head turn, no bank (within 1 deg of Turn = 0)
local ANGLE_TOL_DEG = 0.5
local MIN_CHANGE_DEG = 0.1 -- pose must change between frames 0.1 s apart while racing
local MIN_CHANGE_STUDS = 1e-3
-- Spec section 1: inside the road (half width 20) from the right-hand lane (offset 10).
local ROAD_HALF_WIDTH, LANE = 20, 10
-- Sampling (spec section 5: 10 s of poses)
local SECONDS, HZ = 10, 30
local SPEEDS = { 0, 45, 300 }
local TURNS = { -1, 0, 1 }
-- Slowest flap cycle: FLAP_BEATS beats at FLAP_HZ 1.2 (cruise, spec section 3 placeholder) + GLIDE_SECONDS, plus a
-- margin. Every window this long must hold a full burst (>= 40 deg sweep) and a glide.
local SLOWEST_FLAP_HZ = 1.2
local CYCLE_MARGIN = 0.3
local WINDOW_STEP = 0.5 -- seconds between window starts
-- Low-speed flap continuity (regression, user report 2026-10-27): 10 s at 60 Hz from an os.clock-sized t, measured
-- speed jittering +-3 around each base; 100 is above CRUISE_SPEED (control). ANIM_SMOOTH mirrors SMOOTH in
-- Client/WyvernAnimator. Per frame the shoulder may move at most FLAP_STEP_SLACK x (steepest slope x dt), the breath
-- at most FLAP_STEP_SLACK x dt / BREATH_RAMP.
local JITTER_T0, JITTER_FRAMES, JITTER_SPEED, JITTER_SEED = 10000, 600, 3, 2027
local JITTER_BASES = { 5, 20, 40, 100 }
local JITTER_OLD_BASE = 20
local ANIM_SMOOTH = 0.15
local FLAP_STEP_SLACK = 1.5
-- Physics (spec section 5)
local RUN_ORIGIN = Vector3.new(-40000, 0, 40000) -- this scenario's own chain, far from every other scenario origin
local SPEED_TOL = 0.02 -- mean actual speed vs the starter's at the same stat
local SAMPLE_AFTER = 3 -- seconds (or 30 studs) before route samples count, like the race scenario
local SAMPLE_AFTER_STUDS = 30
local MASS_TOL = 1e-3

local Tests = {}

local function rotAngle(cf)
	local _, _, _, r00, _, _, _, r11, _, _, _, r22 = cf:GetComponents()
	return math.acos(math.clamp((r00 + r11 + r22 - 1) / 2, -1, 1))
end
local function relAngle(a, b)
	return rotAngle(a.Rotation:Inverse() * b.Rotation)
end
local function finiteCF(cf)
	for _, v in { cf:GetComponents() } do
		if v ~= v or v == math.huge or v == -math.huge then
			return false
		end
	end
	return true
end
local function sameCF(a, b)
	local ca, cb = { a:GetComponents() }, { b:GetComponents() }
	for i = 1, 12 do
		if math.abs(ca[i] - cb[i]) > 1e-9 then
			return false
		end
	end
	return true
end
-- Largest relative rotation between any two samples in list[i0..i1] (every `step`th sample).
local function spread(list, i0, i1, step)
	local best = 0
	for i = i0, i1, step do
		for j = i + step, i1, step do
			best = math.max(best, relAngle(list[i], list[j]))
		end
	end
	return math.deg(best)
end
local function yawDeg(cf)
	local _, ry = cf:ToEulerAnglesYXZ()
	return math.deg(ry)
end
local function corners(cf, size)
	local h, out = size / 2, {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(out, cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)))
			end
		end
	end
	return out
end
local function baseParts(root)
	local out = {}
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(out, part)
		end
	end
	return out
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

function Tests.wyvern_flight()
	local r, flag = H.report("wyvern_flight")
	local metrics = r.metrics
	local catalog = H.module(Shared, "CarCatalog")
	local appearance = H.module(Shared, "CarAppearance")
	local factory = H.module(Shared, "CarFactory")
	local carConfig = H.module(Shared, "CarConfig")
	local passConfig = H.module(Shared, "PassCarConfig")
	local targets = H.module(Shared, "PhysicsTargets")
	local motion = H.module(Shared, "WyvernMotion")
	local baseOk = catalog ~= nil
		and appearance ~= nil
		and factory ~= nil
		and carConfig ~= nil
		and passConfig ~= nil
		and targets ~= nil
		and type(appearance.Apply) == "function"
		and type(appearance.Display) == "function"
	flag("wyvern_base_api_exists", baseOk)
	local motionOk = motion ~= nil and type(motion.Pose) == "function"
	flag("wyvern_motion_module_exists", motionOk)
	if not baseOk then
		return r
	end
	local cleanup = {}
	local ok, err = pcall(function()
		-- 1. Catalog
		local spec = catalog.Get(ID)
		local skinScale = spec and spec.SkinScale
		local scaleOk = type(skinScale) == "number" and skinScale > 1
		flag("wyvern_skin_scale_set", scaleOk, type(skinScale) == "number" and skinScale or -1, 1)
		local scale = scaleOk and skinScale or 1
		local others = 0
		for _, list in { catalog.All(), catalog.Passes and catalog.Passes() or {} } do
			for _, car in list do
				if car.Id ~= ID and car.SkinScale ~= nil then
					others += 1
				end
			end
		end
		local starterSpec = catalog.Get(STARTER)
		if starterSpec and starterSpec.SkinScale ~= nil then
			others += 1
		end
		flag("wyvern_skin_scale_only_wyvern", others == 0, others, 0)

		-- 2. Template rig
		local templates = ReplicatedStorage:FindFirstChild("CarModels")
		local template = templates and templates:FindFirstChild(ID)
		local templateOk = template ~= nil and template:IsA("Model")
		flag("wyvern_template_exists", templateOk)
		flag("wyvern_template_rig_attr", templateOk and template:GetAttribute("Rig") == "Wyvern")
		local bones = {}
		if templateOk then
			for _, d in template:GetDescendants() do
				if d:IsA("Bone") then
					bones[d.Name] = d
				end
			end
		end
		local missingBones = 0
		for _, name in SPEC_BONES do
			flag("wyvern_bone_" .. name, bones[name] ~= nil)
			missingBones += bones[name] and 0 or 1
		end
		metrics.missing_bones = missingBones

		-- 3. Size: racing skin (Apply) and pedestal (Display)
		if templateOk then
			local tSize = select(2, template:GetBoundingBox())
			local rig = factory.build(carConfig)
			table.insert(cleanup, rig) -- never parent a physics rig into the live world
			local applied = appearance.Apply(rig, ID, carConfig)
			local skin = rig:FindFirstChild("EquippedVisual")
			flag("wyvern_apply_skin", applied == true and skin ~= nil)
			if skin then
				local sSize = select(2, skin:GetBoundingBox())
				for _, axis in { "X", "Y", "Z" } do
					local ratio = tSize[axis] > 1e-6 and sSize[axis] / tSize[axis] or -1
					flag(
						"wyvern_apply_scale_" .. string.lower(axis),
						scaleOk and math.abs(ratio - skinScale) <= SIZE_TOL * skinScale,
						ratio,
						scale
					)
				end
				local want = rig.PrimaryPart.CFrame * CFrame.new(0, -carConfig.RestHeight, 0)
				local off = (skin:GetPivot().Position - want.Position).Magnitude
				flag("wyvern_apply_base_at_contact", off <= BASE_TOL, off, BASE_TOL)
				local loose = 0
				for _, part in baseParts(skin) do
					if part.CanCollide or part.CanTouch or part.CanQuery or not part.Massless then
						loose += 1
					end
				end
				flag("wyvern_apply_cosmetic_flags", #baseParts(skin) > 0 and loose == 0, loose, 0)
			end
			-- Another car's applied skin stays at its template size (SkinScale is the wyvern's exception only).
			local otherRig = factory.build(carConfig)
			table.insert(cleanup, otherRig)
			local otherSpec = catalog.Get(OTHER_PASS_CAR)
			local otherTemplate = otherSpec and templates:FindFirstChild(otherSpec.Model or OTHER_PASS_CAR)
			if otherTemplate and appearance.Apply(otherRig, OTHER_PASS_CAR, carConfig) then
				local a = select(2, otherTemplate:GetBoundingBox())
				local b = select(2, otherRig.EquippedVisual:GetBoundingBox())
				local ratio = a.X > 1e-6 and b.X / a.X or -1
				flag("wyvern_other_skin_unscaled", math.abs(ratio - 1) <= SIZE_TOL, ratio, 1)
			else
				flag("wyvern_other_skin_unscaled", false, "no " .. OTHER_PASS_CAR .. " template")
			end

			local carScale = passConfig.CAR_SCALE
			local shown = appearance.Display(spec, CFrame.new(), carScale)
			if shown then
				table.insert(cleanup, shown)
			end
			-- Pedestal cap (spec section 1, owner 2026-10-27): CAR_SCALE * min(SkinScale, DISPLAY_SKIN_MAX). A missing
			-- DISPLAY_SKIN_MAX fails the checks (no fallback).
			local cap = appearance.DISPLAY_SKIN_MAX
			local capOk = type(cap) == "number" and cap > 0
			flag("wyvern_display_skin_max_exists", capOk, capOk and cap or -1, 1)
			local wantShown = capOk and carScale * math.min(scale, cap) or -1
			local gotShown = shown and shown:GetScale() / template:GetScale() or -1
			flag(
				"wyvern_display_scale",
				scaleOk and capOk and shown ~= nil and math.abs(gotShown - wantShown) <= SIZE_TOL * wantShown,
				gotShown,
				wantShown
			)
			if shown then
				local box = select(2, shown:GetBoundingBox())
				local ratio = tSize.X > 1e-6 and box.X / tSize.X or -1
				flag(
					"wyvern_display_bbox_scale",
					scaleOk and capOk and math.abs(ratio - wantShown) <= SIZE_TOL * wantShown,
					ratio,
					wantShown
				)
				local loose = 0
				for _, part in baseParts(shown) do
					if part.CanCollide or part.CanTouch or part.CanQuery or not part.Anchored then
						loose += 1
					end
				end
				flag("wyvern_display_cosmetic_flags", loose == 0, loose, 0)
			end
			local otherShown = otherSpec and appearance.Display(otherSpec, CFrame.new(), carScale)
			if otherShown then
				table.insert(cleanup, otherShown)
			end
			local otherScale = otherShown and otherTemplate and otherShown:GetScale() / otherTemplate:GetScale() or -1
			flag("wyvern_other_display_unscaled", math.abs(otherScale - carScale) <= 1e-3, otherScale, carScale)
		end

		-- 4. Motion (its own function: an early return skips only the motion checks, never the physics race)
		local function motionChecks()
			local constOk = type(motion.FLAP_BEATS) == "number"
				and motion.FLAP_BEATS >= 1
				and type(motion.GLIDE_SECONDS) == "number"
				and motion.GLIDE_SECONDS > 0
				and type(motion.MAX_HALF_SPAN) == "number"
				and type(motion.BONES) == "table"
			flag("wyvern_motion_constants", constOk)
			-- Radians: a downstroke / upstroke past level is under 60 deg, so a degree value (40, 15) fails.
			local down, up = motion.FLAP_DOWN, motion.FLAP_UP
			flag(
				"wyvern_flap_angles_radians",
				type(down) == "number"
					and type(up) == "number"
					and down > 0
					and up > 0
					and down < math.rad(60)
					and up < math.rad(60),
				type(down) == "number" and down or -1,
				math.rad(60)
			)
			local span = type(motion.MAX_HALF_SPAN) == "number" and motion.MAX_HALF_SPAN or math.huge
			flag("wyvern_half_span_inside_road", span <= ROAD_HALF_WIDTH - LANE, span, ROAD_HALF_WIDTH - LANE)
			local listed = {}
			for _, name in (type(motion.BONES) == "table" and motion.BONES or {}) do
				listed[name] = true
			end
			local unlisted = 0
			for _, name in SPEC_BONES do
				unlisted += listed[name] and 0 or 1
			end
			flag("wyvern_motion_bones_listed", unlisted == 0, unlisted, 0)
			if not constOk then
				return
			end

			local n = SECONDS * HZ
			local dt = 1 / HZ
			local function sample(speed, turn, reduced)
				local frames = {}
				for i = 0, n do
					frames[i + 1] = motion.Pose(i * dt, { Speed = speed, Turn = turn, Reduced = reduced })
				end
				return frames
			end
			local function track(frames, bone)
				local out = {}
				for i, pose in frames do
					out[i] = typeof(pose[bone]) == "CFrame" and pose[bone] or CFrame.new()
				end
				return out
			end
			local function meanYaw(frames, bone)
				local sum = 0
				for _, pose in frames do
					sum += typeof(pose[bone]) == "CFrame" and yawDeg(pose[bone]) or 0
				end
				return sum / #frames
			end
			local states = {}
			for _, reduced in { false, true } do
				for _, speed in SPEEDS do
					for _, turn in TURNS do
						local key = ("s%d_t%d_%s"):format(speed, turn, reduced and "reduced" or "normal")
						states[key] =
							{ Speed = speed, Turn = turn, Reduced = reduced, Frames = sample(speed, turn, reduced) }
					end
				end
			end
			local keys = {}
			for key in states do
				table.insert(keys, key)
			end
			table.sort(keys)

			local glideN = math.max(2, math.floor(motion.GLIDE_SECONDS * 0.5 * HZ + 0.5))
			local cycle = motion.FLAP_BEATS / SLOWEST_FLAP_HZ + motion.GLIDE_SECONDS + CYCLE_MARGIN
			local windowN = math.min(n, math.ceil(cycle * HZ))
			local stepN = math.floor(WINDOW_STEP * HZ)
			local worstBone, worstBoneName, missing, nonFinite, rootMoved = 0, "", 0, 0, 0
			local headYawMax, sweepMin, glideFail, frozen, nondet = 0, math.huge, 0, 0, 0
			for _, key in keys do
				local st = states[key]
				-- Every bone posed, finite, within 60 deg of rest; only Root may translate.
				for _, pose in st.Frames do
					for _, name in SPEC_BONES do
						local cf = pose[name]
						if typeof(cf) ~= "CFrame" then
							missing += 1
						elseif not finiteCF(cf) then
							nonFinite += 1
						else
							local a = math.deg(rotAngle(cf))
							if a > worstBone then
								worstBone, worstBoneName = a, key .. ":" .. name
							end
							if name ~= "Root" and cf.Position.Magnitude > 1e-6 then
								rootMoved += 1
							end
						end
					end
				end
				-- Deterministic: the same inputs give the same pose, also when asked in reverse order.
				for i = n + 1, 1, -7 do
					local again = motion.Pose((i - 1) * dt, { Speed = st.Speed, Turn = st.Turn, Reduced = st.Reduced })
					for _, name in SPEC_BONES do
						local a, b = st.Frames[i][name], again[name]
						if typeof(a) ~= "CFrame" or typeof(b) ~= "CFrame" or not sameCF(a, b) then
							nondet += 1
						end
					end
				end
				if not st.Reduced then
					for _, pose in st.Frames do
						if typeof(pose.Head) == "CFrame" then
							headYawMax = math.max(headYawMax, math.abs(yawDeg(pose.Head)))
						end
					end
					-- Flap then glide in every slowest-cycle window, for both shoulders.
					for _, arm in { "Arm_L", "Arm_R" } do
						local list = track(st.Frames, arm)
						local still = {}
						for i = 1, #list - glideN do
							still[i] = spread(list, i, i + glideN, 1) <= 2 * GLIDE_FLUTTER_DEG
						end
						for w = 1, #list - windowN, stepN do
							sweepMin = math.min(sweepMin, spread(list, w, w + windowN, 2))
							local glided = false
							for i = w, w + windowN - glideN do
								glided = glided or still[i] == true
							end
							glideFail += glided and 0 or 1
						end
					end
				end
				-- The pose changes between frames 0.1 s apart while racing.
				if st.Speed > 0 then
					local gap = math.floor(0.1 * HZ + 0.5)
					for i = 1, n + 1 - gap do
						local a, b = st.Frames[i], st.Frames[i + gap]
						local moved = false
						for _, name in SPEC_BONES do
							local ca, cb = a[name], b[name]
							if typeof(ca) == "CFrame" and typeof(cb) == "CFrame" then
								moved = moved
									or math.deg(relAngle(ca, cb)) > MIN_CHANGE_DEG
									or (ca.Position - cb.Position).Magnitude > MIN_CHANGE_STUDS
							end
						end
						frozen += moved and 0 or 1
					end
				end
				RunService.Heartbeat:Wait() -- spread the pose maths over frames (script timeout)
			end
			metrics.worst_bone = worstBoneName
			flag("wyvern_pose_all_bones", missing == 0, missing, 0)
			flag("wyvern_pose_finite", nonFinite == 0, nonFinite, 0)
			flag("wyvern_pose_deterministic", nondet == 0, nondet, 0)
			flag("wyvern_bone_within_60deg", worstBone <= MAX_BONE_DEG, worstBone, MAX_BONE_DEG)
			flag("wyvern_only_root_translates", rootMoved == 0, rootMoved, 0)
			flag(
				"wyvern_shoulder_sweep_per_burst",
				sweepMin ~= math.huge and sweepMin >= MIN_SWEEP_DEG,
				sweepMin == math.huge and -1 or sweepMin,
				MIN_SWEEP_DEG
			)
			flag("wyvern_glide_every_cycle", glideFail == 0, glideFail, 0)
			flag("wyvern_pose_changes_racing", frozen == 0, frozen, 0)
			flag(
				"wyvern_head_yaw_max_25deg",
				headYawMax <= MAX_HEAD_YAW_DEG + ANGLE_TOL_DEG,
				headYawMax,
				MAX_HEAD_YAW_DEG
			)

			-- Head turns into curves: yaw follows the sign of Turn (vs Turn = 0), about Turn x 0.35 rad.
			local wantYaw = math.min(math.deg(HEAD_YAW_PER_TURN), MAX_HEAD_YAW_DEG)
			for _, speed in SPEEDS do
				local base = meanYaw(states[("s%d_t0_normal"):format(speed)].Frames, "Head")
				local left = meanYaw(states[("s%d_t1_normal"):format(speed)].Frames, "Head") - base
				local right = meanYaw(states[("s%d_t-1_normal"):format(speed)].Frames, "Head") - base
				flag(("wyvern_head_yaw_follows_turn_left_s%d"):format(speed), left >= wantYaw * 0.5, left, wantYaw)
				flag(("wyvern_head_yaw_follows_turn_right_s%d"):format(speed), right <= -wantYaw * 0.5, right, -wantYaw)
			end

			-- Tail: travelling wave whose amplitude grows to the tip, at most 14 deg per bone.
			local cruise = states.s45_t0_normal.Frames
			local tailMax = {}
			for k = 1, 6 do
				local m = 0
				for _, pose in cruise do
					if typeof(pose["Tail" .. k]) == "CFrame" then
						m = math.max(m, math.deg(rotAngle(pose["Tail" .. k])))
					end
				end
				tailMax[k] = m
				flag("wyvern_tail" .. k .. "_max_14deg", m <= MAX_TAIL_DEG + ANGLE_TOL_DEG, m, MAX_TAIL_DEG)
			end
			flag("wyvern_tail_tip_moves_more", tailMax[6] > tailMax[1], tailMax[6], tailMax[1])

			-- Reduced motion: smaller flap, no head turn, no bank.
			local normalSweep = spread(track(cruise, "Arm_L"), 1, n + 1, 2)
			local reducedCruise = states.s45_t0_reduced.Frames
			local reducedSweep = spread(track(reducedCruise, "Arm_L"), 1, n + 1, 2)
			flag(
				"wyvern_reduced_smaller_flap",
				normalSweep > 0 and reducedSweep < normalSweep and reducedSweep <= REDUCED_AMPLITUDE * normalSweep,
				reducedSweep,
				REDUCED_AMPLITUDE * normalSweep
			)
			local reducedTurn = states.s45_t1_reduced.Frames
			local headTurn = math.abs(meanYaw(reducedTurn, "Head") - meanYaw(reducedCruise, "Head"))
			flag("wyvern_reduced_no_head_turn", headTurn <= REDUCED_TOL_DEG, headTurn, REDUCED_TOL_DEG)
			local bank = 0
			for i, pose in reducedTurn do
				local a, b = pose.Root, reducedCruise[i].Root
				if typeof(a) == "CFrame" and typeof(b) == "CFrame" then
					bank = math.max(bank, math.deg(relAngle(a, b)))
				end
			end
			flag("wyvern_reduced_no_bank", bank <= REDUCED_TOL_DEG, bank, REDUCED_TOL_DEG)

			-- Regression (user report 2026-10-27, low_speed_flap_continuity): below CRUISE_SPEED the wings glitched,
			-- because `t % period` with a large t (os.clock) jumps the phase whenever the measured speed jitters.
			-- Replays Client/WyvernAnimator's loop: os.clock-sized t, measured speed smoothed over ANIM_SMOOTH, Cycle
			-- integrated by dt / CycleSeconds(speed) and passed in the state.
			local cycleOk = type(motion.CycleSeconds) == "function" and type(motion.Breath) == "function"
			flag("wyvern_motion_cycle_seconds_exists", cycleOk)
			if cycleOk then
				local animDt = 1 / 60
				-- Steepest shoulder slope (rad/s): the downstroke at the fastest beat, FLAP_DOWN * pi / 0.6 * FLAP_HZ_REST.
				local slope = motion.FLAP_DOWN * math.pi / 0.6 * motion.FLAP_HZ_REST
				local flapStep = math.deg(slope * animDt) * FLAP_STEP_SLACK
				local breathStep = animDt / motion.BREATH_RAMP * FLAP_STEP_SLACK
				local function jitterRun(base, useCycle)
					local rng = Random.new(JITTER_SEED + base)
					local speed, phase, prevArm, prevBreath = base, 0, nil, nil
					local worstArm, worstBreath = 0, 0
					for i = 0, JITTER_FRAMES - 1 do
						local t = JITTER_T0 + i * animDt
						local measured = base + rng:NextNumber(-JITTER_SPEED, JITTER_SPEED)
						speed += (measured - speed) * math.clamp(animDt / ANIM_SMOOTH, 0, 1)
						phase = (phase + animDt / motion.CycleSeconds(speed)) % 1
						local state = { Speed = speed, Turn = 0, Reduced = false, Cycle = useCycle and phase or nil }
						local arm = motion.Pose(t, state).Arm_R
						local strength = motion.Breath(t, state)
						if typeof(arm) == "CFrame" and prevArm then
							worstArm = math.max(worstArm, math.deg(relAngle(prevArm, arm)))
						end
						if type(strength) == "number" and prevBreath then
							worstBreath = math.max(worstBreath, math.abs(strength - prevBreath))
						end
						prevArm, prevBreath = typeof(arm) == "CFrame" and arm or nil, strength
					end
					return worstArm, worstBreath
				end
				for _, base in JITTER_BASES do
					local arm, breath = jitterRun(base, true)
					flag(("wyvern_low_speed_flap_continuity_s%d"):format(base), arm <= flapStep, arm, flapStep)
					flag(
						("wyvern_low_speed_breath_continuity_s%d"):format(base),
						breath <= breathStep,
						breath,
						breathStep
					)
				end
				-- The old phase (absolute t, no Cycle) must break the bound: proves this check catches the bug.
				local oldArm = jitterRun(JITTER_OLD_BASE, false)
				flag(
					("wyvern_low_speed_flap_jumps_without_cycle_s%d"):format(JITTER_OLD_BASE),
					oldArm > flapStep,
					oldArm,
					flapStep
				)
				RunService.Heartbeat:Wait()
			end

			-- 5. Bounds: wing parts posed by their Arm (and the Root) at every sampled pose, scaled by SkinScale.
			if templateOk then
				local pivot = template:GetPivot()
				local function jointOf(bone)
					local okPos, pos = pcall(function()
						return bone.WorldPosition
					end)
					return okPos and pivot:PointToObjectSpace(pos) or nil
				end
				local rootJoint = bones.Root and jointOf(bones.Root)
				local worstX = 0
				for _, side in { "L", "R" } do
					local wing = template:FindFirstChild("Wing_" .. side, true)
					local arm = bones["Arm_" .. side]
					local joint = arm and jointOf(arm)
					local wingOk = wing ~= nil and wing:IsA("BasePart") and joint ~= nil and rootJoint ~= nil
					flag("wyvern_wing_" .. side .. "_rigged", wingOk)
					if wingOk then
						local pts = corners(pivot:ToObjectSpace(wing.CFrame), wing.Size)
						for _, key in keys do
							for _, pose in states[key].Frames do
								local a, root = pose["Arm_" .. side], pose.Root
								if typeof(a) == "CFrame" and typeof(root) == "CFrame" then
									for _, p in pts do
										local q = joint + a.Rotation * (p - joint)
										q = rootJoint + root.Rotation * (q - rootJoint) + root.Position
										worstX = math.max(worstX, math.abs(q.X) * scale)
									end
								end
							end
						end
					end
				end
				for _, part in baseParts(template) do
					if part.Name ~= "Wing_L" and part.Name ~= "Wing_R" then
						for _, p in corners(pivot:ToObjectSpace(part.CFrame), part.Size) do
							worstX = math.max(worstX, math.abs(p.X) * scale)
						end
					end
				end
				flag("wyvern_half_span_at_extremes", worstX <= span, worstX, span)
			end
		end
		if motionOk then
			motionChecks()
		end

		-- 6. Physics: Track 1-2 race with ember_wyvern equipped vs the starter, same stat.
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
		flag("wyvern_race_api_exists", raceApi)
		if not raceApi then
			return
		end
		local chain = TrackRegistry.Chain()
		flag("wyvern_race_two_tracks", #chain >= 2, #chain, 2)
		if #chain < 2 then
			return
		end
		local entries = {}
		local origin = CFrame.new(RUN_ORIGIN + Vector3.new(0, TrackBuilder.TRACK_LIFT or 0, 0))
		for i = 1, 2 do
			local model, layout = TrackBuilder.Build(chain[i], origin)
			model.Name = "CarTestWyvernTrack" .. i
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

		-- One drive with the car the player equips (CarService.Attach applies EquippedCar the same way).
		local function drive(carId, stat)
			local st = { flips = 0, minUp = 1, dev = 0, devN = 0, speedSum = 0, speedN = 0 }
			local car = factory.build(carConfig)
			car.Name = "CarTestWyvernCar"
			appearance.Apply(car, carId, carConfig)
			car:PivotTo(startCF)
			car.Parent = Workspace
			local player = Instance.new("Folder")
			player.Name = "CarTestWyvernPlayer"
			player:SetAttribute("EquippedCar", carId)
			player.Parent = Workspace
			table.insert(cleanup, car)
			table.insert(cleanup, player)
			Money.Setup(player)
			PlayerData.Setup(player)
			player.BaseSpeed.Value = stat -- base Speed (owner 2026-10-21), as the race scenario sets it
			local run = RaceService.NewRun(car, route, player, nil)
			local skin = car:FindFirstChild("EquippedVisual")
			st.skinId = skin and skin:GetAttribute("CarId")
			local chassis = car.PrimaryPart
			st.mass = chassis.AssemblyMass
			st.target = run.TargetSpeed
			local target = type(run.TargetSpeed) == "number" and run.TargetSpeed or 1
			local timeout = totalLen / (0.5 * target) + 40
			local t, idx, dist, flippedFor, wasFlipped = 0, 1, 0, 0, false
			while t < timeout and run.Finished ~= true do
				local dt = RunService.Heartbeat:Wait()
				t += dt
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
		end

		local half = RaceConfig.HALF_STAT
		local starter = drive(STARTER, half)
		local wyvern = drive(ID, half)
		stability("wyvern_race", wyvern)
		local same = type(wyvern.target) == "number"
			and type(starter.target) == "number"
			and math.abs(wyvern.target - starter.target) <= 1e-6
		flag("wyvern_race_cruise_equals_starter", same, wyvern.target or -1, starter.target or -1)
		local ratio = starter.meanSpeed > 0 and wyvern.meanSpeed / starter.meanSpeed or -1
		flag("wyvern_race_speed_equals_starter", math.abs(ratio - 1) <= SPEED_TOL, ratio, 1)
		flag(
			"wyvern_race_mass_equals_starter",
			math.abs(wyvern.mass - starter.mass) <= MASS_TOL,
			wyvern.mass,
			starter.mass
		)
		metrics.wyvern_mean_speed = wyvern.meanSpeed
		metrics.starter_mean_speed = starter.meanSpeed
		-- Stability rules also hold at the maximum stat speed (CLAUDE.md "Stability rules").
		if type(RaceConfig.MAX_STAT) == "number" then
			stability("wyvern_race_max", drive(ID, RaceConfig.MAX_STAT))
		else
			flag("wyvern_race_max_stat_exists", false)
		end
	end)
	for i = #cleanup, 1, -1 do
		pcall(function()
			cleanup[i]:Destroy()
		end)
	end
	flag("wyvern_no_error", ok, ok and 1 or tostring(err))
	return r
end

return Tests
