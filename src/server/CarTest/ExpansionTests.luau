--!nonstrict
-- BRIEF: docs/CAR_EXPANSION_SPEC.md + PANEL_ART_GIFTING_SPEC.md (owner, 2026-10-20):
-- exactly 100 NEW identities, 18/24/22/17/11/8, 20 per family, one existing catch-all,
-- cosmetic shared-body skins, all ids discoverable/saveable, and seeded rolls never nil.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent
local H = require(script.Parent.AcceptanceSupport)
local Tests = {}
local BANDS = {
	Uncommon = { 18, 12, 2, 1.30, 0.05 },
	Rare = { 24, 60, 7, 2.25, 0.15 },
	Epic = { 22, 300, 30, 5.5, 0.5 },
	Legendary = { 17, 1200, 250, 20, 5 },
	Mythic = { 11, 15000, 3500, 150, 25 },
	Secret = { 8, 150000, 150000, 1200, 200 },
}
local FAMILIES = { "city_utility", "offroad_rally", "track_hyper", "futuristic_hover", "fantasy_novelty" }
local SEEDS = { "rusty_hatchback", "wooden_car", "go_kart", "street_racer", "rocket_car", "hover_car", "void_racer" }
local EVENTS = { rain_runner = "rain", midnight_kart = "night", golden_racer = "gold" }

function Tests.car_expansion()
	local r, flag = H.report("car_expansion")
	local manifest = H.module(Shared, "CarExpansionManifest")
	local catalog = H.module(Shared, "CarCatalog")
	local config = H.module(Shared, "GachaConfig")
	local appearance = H.module(Shared, "CarAppearance")
	local factory = H.module(Shared, "CarFactory")
	local bodyConfig = H.module(Shared, "CarConfig")
	local gacha = H.module(Server, "GachaService")
	local data = H.module(Server, "PlayerData")
	local api = manifest
		and type(manifest.Cars) == "table"
		and catalog
		and config
		and appearance
		and factory
		and bodyConfig
		and gacha
		and data
	flag("expansion_api_exists", api ~= nil and api ~= false)
	if not api then
		return r
	end
	local cleanup = {}
	local ok, err = pcall(function()
		flag("expansion_exactly_100_new_entries", #manifest.Cars == 100, #manifest.Cars, 100)
		local ids, orders, chances, rarityCounts, families, expected = {}, {}, {}, {}, {}, {}
		for _, id in SEEDS do
			expected[id] = true
		end
		for id in EVENTS do
			expected[id] = true
		end
		local templates = ReplicatedStorage:FindFirstChild("CarModels")
		local rig = factory.build(bodyConfig)
		table.insert(cleanup, rig) -- never parent a physics rig into the live world
		local chassis = rig.PrimaryPart
		local seat = rig:FindFirstChildWhichIsA("VehicleSeat", true)
		local bodySize, bodyPose, bodyProperties = chassis.Size, chassis.CFrame, chassis.CustomPhysicalProperties
		local physicsParts = {}
		for _, part in rig:GetDescendants() do
			if part:IsA("BasePart") then
				physicsParts[part] = { Size = part.Size, CanCollide = part.CanCollide, Massless = part.Massless }
			end
		end
		-- The skin fits the shared car's physical footprint: body length and outer tyre edges.
		local maxWidth = bodyConfig.BodySize.X
		for _, wheel in bodyConfig.Wheels do
			maxWidth = math.max(maxWidth, 2 * math.abs(wheel.Mount.X) + bodyConfig.WheelWidth)
		end
		local previousSkin
		for _, spec in manifest.Cars do
			local id = spec.Id
			flag(
				"expansion_unique_new_id_" .. id,
				not ids[id]
					and not expected[id]
					and string.match(id, "^[a-z][a-z0-9_]*$") ~= nil
					and not string.find(id, "__", 1, true)
					and not string.match(id, "_$")
			)
			flag("expansion_unique_order_" .. id, type(spec.Order) == "number" and not orders[spec.Order])
			flag("expansion_unique_chance_" .. id, type(spec.Chance) == "number" and not chances[spec.Chance])
			ids[id], expected[id], orders[spec.Order], chances[spec.Chance] = true, true, true, true
			families[spec.Family] = (families[spec.Family] or 0) + 1
			rarityCounts[spec.Rarity] = (rarityCounts[spec.Rarity] or 0) + 1
			local band = BANDS[spec.Rarity]
			local i = rarityCounts[spec.Rarity]
			flag(
				"expansion_rarity_band_" .. id,
				band ~= nil
					and spec.Chance == band[2] + band[3] * i
					and math.abs(spec.SpeedMulti - (band[4] + band[5] * i)) < 1e-9
			)
			local got = catalog.Get(id)
			local source = Shared.Cars:FindFirstChild(id)
			flag("expansion_permanent_module_" .. id, source ~= nil and source:IsA("ModuleScript"))
			local raw = source and require(source)
			for _, field in { "Id", "Chance", "Rarity", "SpeedMulti", "Order", "Model" } do
				flag(
					"expansion_contract_" .. id .. "_" .. string.lower(field),
					got ~= nil and raw ~= nil and got[field] == spec[field] and raw[field] == spec[field]
				)
			end
			flag(
				"expansion_base_rollable_" .. id,
				got ~= nil
					and got.Rollable == true
					and got.Event == nil
					and got.GamepassId == nil
					and spec.Model == id
					and spec.Chance ~= nil
			)
			local template = templates and templates:FindFirstChild(id)
			flag("expansion_model_exists_" .. id, template ~= nil and template:IsA("Model"))
			if template and template:IsA("Model") then
				local cf, size = template:GetBoundingBox()
				local offset = template:GetPivot():PointToObjectSpace(cf.Position)
				flag(
					"expansion_model_bounds_" .. id,
					size.X > 0
						and size.Y > 0
						and size.Z > 0
						and size.X + 2 * math.abs(offset.X) <= maxWidth + 1e-4
						and size.Z + 2 * math.abs(offset.Z) <= bodyConfig.BodySize.Z + 1e-4
						and offset.Y - size.Y / 2 >= -1e-4
				)
				local anchored, parts = true, 0
				for _, part in template:GetDescendants() do
					if part:IsA("BasePart") then
						parts += 1
						anchored = anchored and part.Anchored
					end
				end
				flag("expansion_template_anchored_" .. id, parts > 0 and anchored)
				local applied = appearance.Apply(rig, id, bodyConfig)
				local skin = rig:FindFirstChild("EquippedVisual")
				flag(
					"expansion_skin_attached_" .. id,
					applied == true and skin ~= nil and skin:GetAttribute("CarId") == id and skin ~= template
				)
				local safe = skin ~= nil
				if skin then
					for _, part in skin:GetDescendants() do
						if part:IsA("BasePart") then
							local weld = part:FindFirstChild("SkinWeld")
							local animatedWheel = part.Name == "Wheel_FL"
								or part.Name == "Wheel_FR"
								or part.Name == "Wheel_RL"
								or part.Name == "Wheel_RR"
							safe = safe
								and not part.CanCollide
								and not part.CanTouch
								and not part.CanQuery
								and part.Massless
								and not part.Anchored
								and part.CollisionGroup == chassis.CollisionGroup
								and weld ~= nil
								and ((not animatedWheel and weld:IsA("WeldConstraint")) or (animatedWheel and weld:IsA(
									"Weld"
								)))
								and weld.Part0 == chassis
								and weld.Part1 == part
						end
					end
				end
				flag("expansion_skin_cosmetic_only_" .. id, safe)
				local intact = rig.PrimaryPart == chassis
					and chassis.Size == bodySize
					and chassis.CFrame == bodyPose
					and chassis.CustomPhysicalProperties == bodyProperties
					and seat.Parent ~= nil
				for part, state in physicsParts do
					intact = intact
						and part.Parent ~= nil
						and part.Size == state.Size
						and part.CanCollide == state.CanCollide
						and part.Massless == state.Massless
				end
				flag("expansion_shared_body_preserved_" .. id, intact)
				flag("expansion_swap_removes_previous_" .. id, previousSkin == nil or previousSkin.Parent == nil)
				previousSkin = skin
			end
		end
		for rarity, band in BANDS do
			flag(
				"expansion_count_" .. string.lower(rarity),
				rarityCounts[rarity] == band[1],
				rarityCounts[rarity] or 0,
				band[1]
			)
		end
		for _, family in FAMILIES do
			flag("expansion_family_" .. family, families[family] == 20, families[family] or 0, 20)
		end
		local seen, catchAll = {}, 0
		for _, spec in catalog.All() do
			flag(
				"expansion_index_expected_" .. spec.Id,
				expected[spec.Id] == true and not seen[spec.Id] and spec.GamepassId == nil
			)
			seen[spec.Id] = true
			if spec.Chance == nil then
				catchAll += 1
				flag("expansion_existing_catch_all", spec.Id == "rusty_hatchback" and spec.Event == nil)
			end
		end
		flag("expansion_single_catch_all", catchAll == 1, catchAll, 1)
		for id in expected do
			flag("expansion_index_contains_" .. id, seen[id] == true)
		end
		-- Independent ordered manifest/seed oracle for one forced hit at every expansion entry.
		for _, wanted in manifest.Cars do
			local calls, targetDraw = 0, 1
			for _, candidate in manifest.Cars do
				if candidate.Chance > wanted.Chance then
					targetDraw += 1
				end
			end
			for _, id in SEEDS do
				local chance = catalog.Get(id).Chance
				if chance and chance > wanted.Chance then
					targetDraw += 1
				end
			end
			local roller = {
				NextNumber = function()
					calls += 1
					return calls == targetDraw and 0 or 0.999999
				end,
			}
			flag("expansion_reachable_roll_" .. wanted.Id, config.Roll(roller, 1) == wanted.Id)
		end
		for _, weather in { "none", "clear", "rain", "night", "gold", "aurora" } do
			for _, luck in { 1, 10, 1000, 1e12 } do
				local a, b = Random.new(20261020), Random.new(20261020)
				local valid, deterministic = true, true
				for _ = 1, 512 do
					local id = config.Roll(a, luck, weather)
					valid = valid
						and id ~= nil
						and expected[id] == true
						and (EVENTS[id] == nil or EVENTS[id] == weather)
					deterministic = deterministic and id == config.Roll(b, luck, weather)
				end
				flag("expansion_seeded_valid_" .. weather .. "_" .. tostring(luck), valid)
				flag("expansion_seeded_repeatable_" .. weather .. "_" .. tostring(luck), deterministic)
			end
		end
		local store = H.store()
		data.SetStore(store)
		local uid = 990078001
		local player = H.player(cleanup, uid)
		flag("expansion_profile_load", data.Load(player, uid) == true)
		for _, spec in manifest.Cars do
			flag("expansion_discovery_" .. spec.Id, gacha.Grant(player, spec.Id) == true)
			flag("expansion_duplicate_not_discovery_" .. spec.Id, gacha.Grant(player, spec.Id) == false)
			flag("expansion_equip_" .. spec.Id, gacha.Equip(player, spec.Id) == true)
		end
		flag("expansion_100_discoveries", gacha.UniqueCount(player) == 100, gacha.UniqueCount(player), 100)
		flag("expansion_discovery_points", gacha.EarnedPoints(player) == 33, gacha.EarnedPoints(player), 33)
		flag("expansion_save", data.Save(player, uid, true) == true)
		local record = store.data[data.KeyFor(uid)]
		flag("expansion_saved_v11", record.Version == 12, record.Version, 12) -- name kept; current VERSION is 12
		local restored = H.player(cleanup, uid)
		flag("expansion_reload", data.Load(restored, uid) == true)
		for _, spec in manifest.Cars do
			local owned = restored:FindFirstChild("GachaData")
			flag("expansion_saved_identity_" .. spec.Id, owned ~= nil and owned:FindFirstChild(spec.Id) ~= nil)
		end
		flag("expansion_equipped_round_trip", restored:GetAttribute("EquippedCar") == manifest.Cars[#manifest.Cars].Id)
		flag("expansion_reload_points", gacha.UniqueCount(restored) == 100 and gacha.EarnedPoints(restored) == 33)
	end)
	data.SetStore(nil)
	for _, object in cleanup do
		object:Destroy()
	end
	flag("expansion_no_error", ok, ok and 1 or tostring(err))
	return r
end

return Tests
