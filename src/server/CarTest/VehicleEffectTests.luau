--!nonstrict
-- BRIEF: Void Trail rework (src/shared/VehicleEffects.luau). docs/PANEL_ART_GIFTING_SPEC.md: "Effects attach to the
-- chassis, have no collision, and never change mass or controls. Equip, respawn and skin replacement preserve the
-- server-owned EquippedAura/EquippedTrail attributes". docs/GAME_DESIGN_REQUIREMENTS.md (~line 737): distinct
-- cosmetic in-world profiles applied to the shared chassis without changing physics or equip authority.
-- Runs on a fake player's real auto-racing car (CarService.Attach -> RaceService run), like auto_toggle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")

local TRAIL_ID = "void_trail"
local TRAILS = { "void_trailCore", "void_trailEdgeL", "void_trailEdgeR" }
local EMITTERS = { "void_trailMotes", "void_trailSmoke" }
local EMITTER_ATTACHMENT = "void_trailEmitter"
local DRIVE_SECONDS = 3
local MIN_DRIVE_DISTANCE = 20 -- studs the chassis must cover in DRIVE_SECONDS
local MIN_RIBBON_WIDTH = 0.05 -- studs between a trail's two attachments
local MASS_TOLERANCE = 1e-6
local TRACK_TOLERANCE = 1e-3 -- studs: attachment world position vs chassis-space position
local SEAT_TIMEOUT = 10 -- seconds to wait for a run after a (re)start
local SKIN_ID = "apex_arrow" -- any catalog car: the skin replacement path (CarAppearance.Apply)
local EFFECT_CLASSES = { Attachment = true, Trail = true, Beam = true, ParticleEmitter = true, Folder = true }

local Tests = {}

-- helpers = { newFakeCharacter, clearSpawnOfRealPlayers } (locals of Scenarios.luau, passed in)
function Tests.make(helpers)
	return function()
		local r, flag = H.report("vehicle_effects")
		local metrics = r.metrics
		local CarService = H.module(Server, "CarService")
		local MarketService = H.module(Server, "MarketService")
		local PlayerData = H.module(Server, "PlayerData")
		local Money = H.module(Server, "MoneyService")
		local VehicleEffects = H.module(Shared, "VehicleEffects")
		local CarAppearance = H.module(Shared, "CarAppearance")
		local CarConfig = H.module(Shared, "CarConfig")
		local Targets = H.module(Shared, "PhysicsTargets")
		local strict = Targets and Targets.lap and Targets.lap.MinUpYStrict
		local apiOk = CarService ~= nil
			and MarketService ~= nil
			and PlayerData ~= nil
			and Money ~= nil
			and VehicleEffects ~= nil
			and CarAppearance ~= nil
			and CarConfig ~= nil
			and type(strict) == "number"
			and type(CarService.Attach) == "function"
			and type(CarService.SetAutoRace) == "function"
			and type(CarService.GetCar) == "function"
			and type(CarService.GetRun) == "function"
			and type(MarketService.Equip) == "function"
			and type(VehicleEffects.Apply) == "function"
			and type(VehicleEffects.Profiles) == "table"
			and VehicleEffects.Profiles[TRAIL_ID] ~= nil
		flag("effects_api_exists", apiOk)
		if not apiOk then
			return r
		end

		local player = Instance.new("Folder")
		player.Name = "CarTestEffectsPlayer"
		player.Parent = Workspace
		local origTrail, origAura = player:GetAttribute("EquippedTrail"), player:GetAttribute("EquippedAura")
		local okWalk, walkCF = pcall(CarService.WalkSpawnCFrame)
		walkCF = okWalk and typeof(walkCF) == "CFrame" and walkCF or CFrame.new(0, 3, 0)
		local releaseSpawn = helpers.clearSpawnOfRealPlayers(walkCF.Position)
		local character = helpers.newFakeCharacter(CFrame.new(walkCF.Position + Vector3.new(0, 3, 0)))

		local function waitRun()
			local deadline = os.clock() + SEAT_TIMEOUT
			while os.clock() < deadline do
				local car, run = CarService.GetCar(player), CarService.GetRun(player)
				if car and car.PrimaryPart and type(run) == "table" and run.Connection ~= nil then
					return car, run
				end
				RunService.Heartbeat:Wait()
			end
			return CarService.GetCar(player), CarService.GetRun(player)
		end
		local function snapshot(car)
			local set, parts = {}, 0
			for _, d in car:GetDescendants() do
				set[d] = true
				if d:IsA("BasePart") then
					parts += 1
				end
			end
			return set, parts
		end
		local function partMass(car)
			local total = 0
			for _, d in car:GetDescendants() do
				if d:IsA("BasePart") then
					total += d:GetMass()
				end
			end
			return total
		end
		-- Checks 1 and 2: folder, three ribbons and two emitters, all on the chassis. Returns the attachments.
		local function checkProfile(pre, car)
			local chassis = car.PrimaryPart
			local folder = car:FindFirstChild("MarketEffects")
			flag(pre .. "_folder_exists", folder ~= nil and folder:IsA("Folder"))
			flag(pre .. "_folder_trail_attr", folder ~= nil and folder:GetAttribute("Trail") == TRAIL_ID)
			local atts = {}
			for _, name in TRAILS do
				local t = folder and folder:FindFirstChild(name)
				local isTrail = t ~= nil and t:IsA("Trail")
				flag(pre .. "_" .. name .. "_exists", isTrail)
				if isTrail then
					local a0, a1 = t.Attachment0, t.Attachment1
					local onChassis = a0 ~= nil and a1 ~= nil and a0.Parent == chassis and a1.Parent == chassis
					flag(pre .. "_" .. name .. "_on_chassis", onChassis)
					local width = onChassis and (a0.WorldPosition - a1.WorldPosition).Magnitude or 0
					flag(pre .. "_" .. name .. "_width", width > MIN_RIBBON_WIDTH, width, MIN_RIBBON_WIDTH)
					flag(pre .. "_" .. name .. "_flat", t.FaceCamera == false)
					flag(pre .. "_" .. name .. "_enabled", t.Enabled == true)
					local tagged = onChassis
						and a0:GetAttribute("MarketEffect") == true
						and a1:GetAttribute("MarketEffect") == true
					flag(pre .. "_" .. name .. "_attachments_tagged", tagged)
					if onChassis then
						table.insert(atts, a0)
						table.insert(atts, a1)
					end
				end
			end
			local source = chassis:FindFirstChild(EMITTER_ATTACHMENT)
			local sourceOk = source ~= nil and source:IsA("Attachment") and source:GetAttribute("MarketEffect") == true
			flag(pre .. "_emitter_attachment_on_chassis", sourceOk)
			for _, name in EMITTERS do
				local e = source and source:FindFirstChild(name)
				local ok = e ~= nil and e:IsA("ParticleEmitter") and e.Enabled == true and e.Rate > 0
				flag(pre .. "_" .. name .. "_emitting", ok, e and e:IsA("ParticleEmitter") and e.Rate or 0, 0)
			end
			if sourceOk then
				table.insert(atts, source)
			end
			return atts
		end
		local function effectLeft(car)
			local n = 0
			for _, d in car:GetDescendants() do
				if d:GetAttribute("MarketEffect") == true or string.sub(d.Name, 1, #TRAIL_ID) == TRAIL_ID then
					n += 1
				end
			end
			return n
		end

		local function body()
			local okSetup = pcall(function()
				Money.Setup(player)
				PlayerData.Setup(player)
			end)
			flag("effects_fake_player_setup", okSetup)
			player:SetAttribute("EquippedAura", nil)
			player:SetAttribute("EquippedTrail", nil)
			flag("effects_attach_no_error", (pcall(CarService.Attach, player, character)))
			local car, run = waitRun()
			local carOk = car ~= nil and car.PrimaryPart ~= nil and type(run) == "table" and run.Car == car
			flag("effects_racing_car", carOk)
			if not carOk then
				return
			end
			local chassis = car.PrimaryPart

			-- Equip the way the Market does (server-side, ownership checked), then the CarService listener body
			-- (VehicleEffects.Apply on the live car; the listener itself is wired only for real Players)
			local before, partsBefore = snapshot(car)
			local massBefore, assemblyBefore = partMass(car), chassis.AssemblyMass
			player:SetAttribute("OwnTrail_" .. TRAIL_ID, true)
			local okEquip, equipped = pcall(MarketService.Equip, player, "Trail", TRAIL_ID)
			flag(
				"effects_market_equip",
				okEquip and equipped == true and player:GetAttribute("EquippedTrail") == TRAIL_ID
			)
			flag("effects_apply_no_error", (pcall(VehicleEffects.Apply, car, player)))
			local atts = checkProfile("equip", car)

			-- 3. Only effect instances added, no BasePart, mass unchanged, the same run still drives the car
			local _, partsAfter = snapshot(car)
			flag("equip_no_basepart_added", partsAfter == partsBefore, partsAfter - partsBefore, 0)
			local bad = 0
			for _, d in car:GetDescendants() do
				if not before[d] and not EFFECT_CLASSES[d.ClassName] then
					bad += 1
					metrics["equip_unexpected_" .. bad] = d.ClassName .. ":" .. d.Name
				end
			end
			flag("equip_only_effect_instances", bad == 0, bad, 0)
			local dMass = math.abs(partMass(car) - massBefore)
			local dAssembly = math.abs(chassis.AssemblyMass - assemblyBefore)
			flag("equip_part_mass_unchanged", dMass <= MASS_TOLERANCE, dMass, MASS_TOLERANCE)
			flag("equip_assembly_mass_unchanged", dAssembly <= MASS_TOLERANCE, dAssembly, MASS_TOLERANCE)
			local sameRun = CarService.GetRun(player) == run
				and run.Connection ~= nil
				and CarService.GetCar(player) == car
			flag("equip_controls_unchanged", sameRun and car:GetAttribute("AutoRace") == true)

			-- 4 + 5. The car drives on: the chassis travels, every effect attachment rides on it, no tilt
			local start = chassis.Position
			local attStart = {}
			for i, a in atts do
				attStart[i] = a.WorldPosition
			end
			local minUpY, maxTrackErr, detached = 1, 0, 0
			local t = 0
			while t < DRIVE_SECONDS do
				t += RunService.Heartbeat:Wait()
				if not chassis.Parent then
					break
				end
				minUpY = math.min(minUpY, chassis.CFrame.UpVector.Y)
				for _, a in atts do
					if a.Parent ~= chassis then
						detached += 1
					else
						local want = chassis.CFrame:PointToWorldSpace(a.Position)
						maxTrackErr = math.max(maxTrackErr, (a.WorldPosition - want).Magnitude)
					end
				end
			end
			local moved = (chassis.Position - start).Magnitude
			flag("drive_chassis_moved", moved > MIN_DRIVE_DISTANCE, moved, MIN_DRIVE_DISTANCE)
			local minAttMoved = math.huge
			for i, a in atts do
				minAttMoved = math.min(minAttMoved, (a.WorldPosition - attStart[i]).Magnitude)
			end
			minAttMoved = #atts > 0 and minAttMoved or 0
			flag("drive_trail_laid", minAttMoved > MIN_DRIVE_DISTANCE, minAttMoved, MIN_DRIVE_DISTANCE)
			flag("drive_attachments_stay_on_chassis", detached == 0, detached, 0)
			flag("drive_attachments_track_chassis", maxTrackErr <= TRACK_TOLERANCE, maxTrackErr, TRACK_TOLERANCE)
			flag("drive_min_up_y", minUpY >= strict, minUpY, strict)
			checkProfile("drive", car)

			-- 6a. Skin replacement (the EquippedCar listener body: CarAppearance.Apply then VehicleEffects.Apply)
			local okSkin = pcall(function()
				CarAppearance.Apply(car, SKIN_ID, CarConfig)
				VehicleEffects.Apply(car, player)
			end)
			flag("skin_apply_no_error", okSkin)
			flag("skin_equipped_trail_kept", player:GetAttribute("EquippedTrail") == TRAIL_ID)
			checkProfile("skin", car)

			-- 6b. Respawn: Stop then Start builds a new car through CarService.spawnCar
			flag("respawn_stop_no_error", (pcall(CarService.SetAutoRace, player, false)))
			RunService.Heartbeat:Wait()
			flag("respawn_start_no_error", (pcall(CarService.SetAutoRace, player, true)))
			local car2 = waitRun()
			local car2Ok = car2 ~= nil and car2 ~= car and car2.PrimaryPart ~= nil
			flag("respawn_new_car", car2Ok)
			flag("respawn_equipped_trail_kept", player:GetAttribute("EquippedTrail") == TRAIL_ID)
			if not car2Ok then
				return
			end
			checkProfile("respawn", car2)

			-- 7. Unequip: attribute nil (listener body) clears the folder and every MarketEffect attachment
			player:SetAttribute("EquippedTrail", nil)
			flag("unequip_apply_no_error", (pcall(VehicleEffects.Apply, car2, player)))
			local folder = car2:FindFirstChild("MarketEffects")
			local emptyOk = folder == nil or (#folder:GetChildren() == 0 and folder:GetAttribute("Trail") == nil)
			flag("unequip_folder_empty", emptyOk, folder and #folder:GetChildren() or 0, 0)
			local left = effectLeft(car2)
			flag("unequip_no_effect_left", left == 0, left, 0)
		end

		local ok, err = pcall(body)
		flag("effects_no_error", ok)
		if not ok then
			metrics.error = tostring(err)
		end
		pcall(CarService.SetAutoRace, player, false)
		player:SetAttribute("EquippedTrail", origTrail)
		player:SetAttribute("EquippedAura", origAura)
		local leftover = CarService.GetCar(player)
		if leftover then
			leftover:Destroy()
		end
		character:Destroy()
		player:Destroy()
		releaseSpawn()
		return r
	end
end

return Tests
