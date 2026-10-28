--!nonstrict
-- BRIEF: docs/WYVERN_BREATH_SPEC.md (owner, 2026-10-27): "add the blue fire breath effects to the dragon". Design doc
-- "Owner, 2026-10-27 (Ember Wyvern breath)". Spec section 3 lists what this scenario checks:
--   1. WyvernMotion.Breath exists, is deterministic, stays in 0..1, is 0 through every flap burst and reaches 1 in
--      every glide at Speed 0 / 45 / 300; Reduced never passes 0.4.
--   2. WyvernBreath.Build on a template clone: Attachment "Breath" under the Head bone with the five named emitters,
--      uploaded VehicleEffects textures only, palette colours only; SetStrength(att, 0) -> every rate 0, 1 -> each
--      layer's full rate (> 0). Section 2 details: BreathCore LockedToPart, BreathSmoke LightEmission 0, world-space
--      layers inherit velocity, sizes scale with the model scale.
--   3. On the server no Breath attachment exists in any skin after a race (client only).
--   4. The wyvern_flight limits still hold with the jaw following the breath.
-- Phases are read from the pose, not from the implementation: a flap burst is where the shoulder (Arm_L) sweeps, a
-- glide is where it is held (within 2 x the 4 deg glide flutter, docs/WYVERN_FLIGHT_SPEC.md section 3).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent

local ID = "ember_wyvern"
local EMITTERS = { "BreathCore", "BreathBody", "BreathSmoke", "BreathSparks", "MouthGlow" }
-- Spec section 2 palette (RGB 0..255): HOT, CYAN, BLUE, DEEP, SOOT
local PALETTE = { { 230, 255, 255 }, { 60, 220, 255 }, { 20, 130, 230 }, { 10, 40, 140 }, { 4, 6, 16 } }
local COLOUR_TOL = 1.5 / 255
local REDUCED_MAX = 0.4
local FULL = 0.999 -- "reaches 1"
local SECONDS, HZ = 10, 30
local SPEEDS = { 0, 45, 300 }
local TURNS = { -1, 0, 1 }
-- Slowest flap cycle (as wyvern_flight): FLAP_BEATS at FLAP_HZ 1.2 + GLIDE_SECONDS + margin. Every window this long
-- holds one burst and one glide.
local SLOWEST_FLAP_HZ = 1.2
local CYCLE_MARGIN = 0.3
local WINDOW_STEP = 0.5
-- While breathing the shoulder is held: spread within the glide flutter (2 x 4 deg) plus 2 deg settling margin.
local HELD_SPREAD_DEG = 2 * 4 + 2
local MAX_BONE_DEG = 60 -- docs/WYVERN_FLIGHT_SPEC.md section 3
local JAW_OPEN_DEG = 1 -- mean jaw angle at full breath exceeds the mean at no breath by at least this
local SIZE_SCALE = 2 -- test model scale for "sizes and speeds scale with the model's scale"
local SCALE_TOL = 0.02
local RUN_ORIGIN = Vector3.new(40000, 0, -40000) -- this scenario's own chain, far from every other scenario origin
local DRIVE_SECONDS = 5

local Tests = {}

local function rotAngle(cf)
	local _, _, _, r00, _, _, _, r11, _, _, _, r22 = cf:GetComponents()
	return math.acos(math.clamp((r00 + r11 + r22 - 1) / 2, -1, 1))
end
local function spread(list, i0, i1)
	local best = 0
	for i = i0, i1 do
		for j = i + 1, i1 do
			best = math.max(best, rotAngle(list[i].Rotation:Inverse() * list[j].Rotation))
		end
	end
	return math.deg(best)
end
local function inPalette(c)
	for _, p in PALETTE do
		if
			math.abs(c.R - p[1] / 255) <= COLOUR_TOL
			and math.abs(c.G - p[2] / 255) <= COLOUR_TOL
			and math.abs(c.B - p[3] / 255) <= COLOUR_TOL
		then
			return true
		end
	end
	return false
end
local function breathNames(root)
	local found = {}
	for _, d in root:GetDescendants() do
		if d.Name == "Breath" and d:IsA("Attachment") then
			table.insert(found, d:GetFullName())
		end
	end
	return found
end

function Tests.wyvern_breath()
	local r, flag = H.report("wyvern_breath")
	local metrics = r.metrics
	local motion = H.module(Shared, "WyvernMotion")
	local breath = H.module(Shared, "WyvernBreath")
	local effects = H.module(Shared, "VehicleEffects")
	local motionOk = motion ~= nil
		and type(motion.Breath) == "function"
		and type(motion.Pose) == "function"
		and type(motion.BREATH_RAMP) == "number"
		and type(motion.FLAP_BEATS) == "number"
		and type(motion.GLIDE_SECONDS) == "number"
	flag("breath_motion_api_exists", motionOk)
	local buildOk = breath ~= nil
		and type(breath.Build) == "function"
		and type(breath.SetStrength) == "function"
		and effects ~= nil
		and type(effects.TEXTURES) == "table"
	flag("breath_build_api_exists", buildOk)
	local cleanup = {}
	local ok, err = pcall(function()
		-- 1. Breath strength
		local function strengthChecks()
			local ramp, glide = motion.BREATH_RAMP, motion.GLIDE_SECONDS
			flag("breath_ramp_fits_glide", ramp > 0 and 2 * ramp < glide, ramp, glide / 2)
			local n, dt = SECONDS * HZ, 1 / HZ
			local cycle = motion.FLAP_BEATS / SLOWEST_FLAP_HZ + glide + CYCLE_MARGIN
			local windowN = math.min(n, math.ceil(cycle * HZ))
			local stepN = math.floor(WINDOW_STEP * HZ)
			local badRange, nondet, reducedMax = 0, 0, 0
			local flapping, missedFull, missedOff, longRun = 0, 0, 0, 0
			local jawFullSum, jawFullN, jawOffSum, jawOffN, jawMax = 0, 0, 0, 0, 0
			for _, reduced in { false, true } do
				for _, speed in SPEEDS do
					for _, turn in TURNS do
						local function state()
							return { Speed = speed, Turn = turn, Reduced = reduced }
						end
						local values, arms = {}, {}
						for i = 0, n do
							local v = motion.Breath(i * dt, state())
							local pose = motion.Pose(i * dt, state())
							values[i + 1] = v
							arms[i + 1] = typeof(pose.Arm_L) == "CFrame" and pose.Arm_L or CFrame.new()
							if type(v) ~= "number" or v ~= v or v < 0 or v > 1 then
								badRange += 1
								values[i + 1] = 0
								v = 0
							end
							local jaw = typeof(pose.Jaw) == "CFrame" and math.deg(rotAngle(pose.Jaw)) or math.huge
							jawMax = math.max(jawMax, jaw)
							if not reduced and jaw ~= math.huge then
								if v >= FULL then
									jawFullSum += jaw
									jawFullN += 1
								elseif v == 0 then
									jawOffSum += jaw
									jawOffN += 1
								end
							end
							if reduced then
								reducedMax = math.max(reducedMax, v)
							end
						end
						-- Deterministic: same inputs, same value, also asked in reverse order.
						for i = n + 1, 1, -5 do
							if motion.Breath((i - 1) * dt, state()) ~= values[i] then
								nondet += 1
							end
						end
						if not reduced then
							-- Every breathing run is a held shoulder (a glide), never longer than one glide.
							local i = 1
							while i <= n + 1 do
								if values[i] > 0 then
									local j = i
									while j < n + 1 and values[j + 1] > 0 do
										j += 1
									end
									if spread(arms, i, j) > HELD_SPREAD_DEG then
										flapping += 1
									end
									if (j - i) * dt > glide + dt then
										longRun += 1
									end
									i = j + 1
								else
									i += 1
								end
							end
							-- Every slowest-cycle window reaches 1 (a glide) and has 0 (a burst).
							for w = 1, n + 1 - windowN, stepN do
								local full, off = false, false
								for k = w, w + windowN do
									full = full or values[k] >= FULL
									off = off or values[k] == 0
								end
								missedFull += full and 0 or 1
								missedOff += off and 0 or 1
							end
						end
						RunService.Heartbeat:Wait() -- spread the maths over frames (script timeout)
					end
				end
			end
			flag("breath_in_range", badRange == 0, badRange, 0)
			flag("breath_deterministic", nondet == 0, nondet, 0)
			flag("breath_zero_in_flap_bursts", flapping == 0, flapping, 0)
			flag("breath_run_within_glide", longRun == 0, longRun, 0)
			flag("breath_full_every_glide", missedFull == 0, missedFull, 0)
			flag("breath_off_every_cycle", missedOff == 0, missedOff, 0)
			flag("breath_reduced_max", reducedMax <= REDUCED_MAX, reducedMax, REDUCED_MAX)
			-- 4. Flight limits with the jaw following the breath
			flag("breath_jaw_within_60deg", jawMax <= MAX_BONE_DEG, jawMax, MAX_BONE_DEG)
			local jawFull = jawFullN > 0 and jawFullSum / jawFullN or 0
			local jawOff = jawOffN > 0 and jawOffSum / jawOffN or 0
			metrics.jaw_full_deg, metrics.jaw_off_deg = jawFull, jawOff
			flag(
				"breath_jaw_opens_with_breath",
				jawFullN > 0 and jawOffN > 0 and jawFull - jawOff >= JAW_OPEN_DEG,
				jawFull - jawOff,
				JAW_OPEN_DEG
			)
		end
		if motionOk then
			strengthChecks()
		end

		-- 2. Build on a template clone (never parented: the server must not show it)
		local templates = ReplicatedStorage:FindFirstChild("CarModels")
		local template = templates and templates:FindFirstChild(ID)
		local templateOk = template ~= nil and template:IsA("Model")
		flag("breath_template_exists", templateOk)
		flag("breath_template_has_no_breath", templateOk and #breathNames(template) == 0)
		local function buildChecks()
			local clone = template:Clone()
			table.insert(cleanup, clone)
			local att = breath.Build(clone)
			local head = clone:FindFirstChild("Head", true)
			local attOk = typeof(att) == "Instance" and att:IsA("Attachment") and att.Name == "Breath"
			flag("breath_attachment_built", attOk)
			flag("breath_attachment_under_head", attOk and head ~= nil and head:IsA("Bone") and att.Parent == head)
			if not attOk then
				return
			end
			local uploaded = {}
			for _, id in effects.TEXTURES do
				uploaded[id] = true
			end
			local emitterCount = 0
			for _, d in att:GetDescendants() do
				emitterCount += d:IsA("ParticleEmitter") and 1 or 0
			end
			flag("breath_five_emitters", emitterCount == #EMITTERS, emitterCount, #EMITTERS)
			local emitters = {}
			for _, name in EMITTERS do
				local e = att:FindFirstChild(name)
				local isEmitter = e ~= nil and e:IsA("ParticleEmitter")
				flag("breath_emitter_" .. name, isEmitter)
				if isEmitter then
					emitters[name] = e
					flag("breath_texture_uploaded_" .. name, e.Texture ~= "" and uploaded[e.Texture] == true)
					local colours = true
					for _, k in e.Color.Keypoints do
						colours = colours and inPalette(k.Value)
					end
					flag("breath_palette_" .. name, colours)
				end
			end
			local core, smoke = emitters.BreathCore, emitters.BreathSmoke
			flag("breath_core_locked_to_part", core ~= nil and core.LockedToPart == true)
			flag(
				"breath_smoke_no_light",
				smoke ~= nil and smoke.LightEmission == 0,
				smoke and smoke.LightEmission or -1,
				0
			)
			local unInherited = 0
			for _, e in emitters do
				if not e.LockedToPart and e.VelocityInheritance <= 0 then
					unInherited += 1
				end
			end
			flag("breath_world_layers_inherit_velocity", unInherited == 0, unInherited, 0)
			-- Rates: 0 -> every rate 0; 1 -> each layer's full rate (> 0); 0.5 -> half of it.
			breath.SetStrength(att, 1)
			local fullOk, rates = true, {}
			for _, name in EMITTERS do
				local e = emitters[name]
				local fullRate = e and e:GetAttribute("FullRate")
				rates[name] = e and e.Rate or 0
				fullOk = fullOk and type(fullRate) == "number" and fullRate > 0 and math.abs(e.Rate - fullRate) <= 1e-6
			end
			flag("breath_strength_one_full_rate", fullOk)
			breath.SetStrength(att, 0.5)
			local halfOk = true
			for _, name in EMITTERS do
				local e = emitters[name]
				halfOk = halfOk and e ~= nil and math.abs(e.Rate - 0.5 * rates[name]) <= 1e-6
			end
			flag("breath_strength_scales_rate", halfOk)
			breath.SetStrength(att, 0)
			local lit = 0
			for _, d in att:GetDescendants() do
				if d:IsA("ParticleEmitter") and d.Rate ~= 0 then
					lit += 1
				end
			end
			flag("breath_strength_zero_no_rate", lit == 0, lit, 0)
			-- Sizes and speeds scale with the model's scale.
			local big = template:Clone()
			table.insert(cleanup, big)
			big:ScaleTo(big:GetScale() * SIZE_SCALE)
			local bigAtt = breath.Build(big)
			local bigCore = bigAtt and bigAtt:FindFirstChild("BreathCore")
			if core and bigCore and bigCore:IsA("ParticleEmitter") then
				local a, b = core.Size.Keypoints, bigCore.Size.Keypoints
				local sizeRatio = a[#a].Value > 0 and b[#b].Value / a[#a].Value or -1
				local speedRatio = core.Speed.Max > 0 and bigCore.Speed.Max / core.Speed.Max or -1
				flag(
					"breath_size_scales_with_model",
					math.abs(sizeRatio - SIZE_SCALE) <= SCALE_TOL * SIZE_SCALE,
					sizeRatio,
					SIZE_SCALE
				)
				flag(
					"breath_speed_scales_with_model",
					math.abs(speedRatio - SIZE_SCALE) <= SCALE_TOL * SIZE_SCALE,
					speedRatio,
					SIZE_SCALE
				)
			else
				flag("breath_size_scales_with_model", false)
			end
		end
		if buildOk and templateOk then
			buildChecks()
		end

		-- 3. Server: no Breath in any skin after a race (the client builds it; nothing replicates).
		local TrackRegistry = H.module(Shared, "TrackRegistry")
		local TrackBuilder = H.module(Shared, "TrackBuilder")
		local RaceConfig = H.module(Shared, "RaceConfig")
		local CarFactory = H.module(Shared, "CarFactory")
		local CarConfig = H.module(Shared, "CarConfig")
		local CarAppearance = H.module(Shared, "CarAppearance")
		local RaceService = H.module(Server, "RaceService")
		local PlayerData = H.module(Server, "PlayerData")
		local Money = H.module(Server, "MoneyService")
		local raceApi = TrackRegistry
			and TrackBuilder
			and RaceConfig
			and CarFactory
			and CarConfig
			and CarAppearance
			and RaceService
			and PlayerData
			and Money
			and type(RaceService.NewRun) == "function"
		flag("breath_race_api_exists", raceApi ~= nil and raceApi ~= false)
		if not raceApi then
			return
		end
		local chain = TrackRegistry.Chain()
		flag("breath_race_two_tracks", #chain >= 2, #chain, 2)
		if #chain < 2 then
			return
		end
		local entries = {}
		local origin = CFrame.new(RUN_ORIGIN + Vector3.new(0, TrackBuilder.TRACK_LIFT or 0, 0))
		for i = 1, 2 do
			local model, layout = TrackBuilder.Build(chain[i], origin)
			model.Name = "CarTestBreathTrack" .. i
			model.Parent = Workspace
			table.insert(cleanup, model)
			entries[i] = { Layout = layout, Origin = origin, Model = model, Number = chain[i].Number }
			origin = TrackBuilder.EndCFrame(layout, origin)
		end
		local route = RaceService.BuildRoute(entries)
		local car = CarFactory.build(CarConfig)
		car.Name = "CarTestBreathCar"
		CarAppearance.Apply(car, ID, CarConfig)
		car:PivotTo(entries[1].Model.Start.CFrame + Vector3.new(0, CarConfig.RestHeight, 0))
		car.Parent = Workspace
		local player = Instance.new("Folder")
		player.Name = "CarTestBreathPlayer"
		player:SetAttribute("EquippedCar", ID)
		player.Parent = Workspace
		table.insert(cleanup, car)
		table.insert(cleanup, player)
		Money.Setup(player)
		PlayerData.Setup(player)
		player.BaseSpeed.Value = RaceConfig.HALF_STAT
		local run = RaceService.NewRun(car, route, player, nil)
		local t = 0
		while t < DRIVE_SECONDS and run.Finished ~= true do
			t += RunService.Heartbeat:Wait()
		end
		local skin = car:FindFirstChild("EquippedVisual")
		flag("breath_race_skin_equipped", skin ~= nil and skin:GetAttribute("CarId") == ID)
		local inSkin = skin and #breathNames(skin) or 0
		flag("breath_none_in_race_skin", inSkin == 0, inSkin, 0)
		pcall(function()
			run:Destroy()
		end)
		-- Every skin in the server Workspace (players' cars, pedestals, Best Roll): no Breath attachment.
		local found = breathNames(Workspace)
		metrics.server_breath = table.concat(found, ", ")
		flag("breath_none_on_server", #found == 0, #found, 0)
	end)
	for i = #cleanup, 1, -1 do
		pcall(function()
			cleanup[i]:Destroy()
		end)
	end
	flag("breath_no_error", ok, ok and 1 or tostring(err))
	return r
end

return Tests
