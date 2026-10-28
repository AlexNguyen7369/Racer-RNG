--!nonstrict
-- BRIEF: docs/CAR_EXPANSION_SPEC.md + PANEL_ART_GIFTING_SPEC.md (owner, 2026-10-20):
-- exactly 100 NEW identities, 18/24/22/17/11/8, 20 per family, one existing catch-all,
-- cosmetic shared-body skins, all ids discoverable/saveable, and seeded rolls never nil.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent
local H = require(script.Parent.AcceptanceSupport)
local Tests = {}
-- { count, Chance band low, Chance band high, SpeedMulti base, SpeedMulti step }. Chance bands: odds rev. (owner
-- 2026-10-27, design doc "odds rev.", CAR_EXPANSION_SPEC "Distribution"; was 12+2i, 60+7i, 300+30i, 1200+250i,
-- 15000+3500i, 150000+150000i): log-spaced in the old order, 2 significant figures. Secret stays under int64.
-- Fields 6 and 7: the OLD Chance formula (old base + old step * i), only to rebuild the doc's "old order".
local BANDS = {
	Uncommon = { 18, 10, 200, 1.30, 0.05, 12, 2 },
	Rare = { 24, 500, 25e3, 2.25, 0.15, 60, 7 },
	Epic = { 22, 5e4, 2.5e6, 5.5, 0.5, 300, 30 },
	Legendary = { 17, 1e7, 1e9, 20, 5, 1200, 250 },
	Mythic = { 11, 5e9, 1e15, 150, 25, 15000, 3500 },
	Secret = { 8, 1e16, 5e18, 1200, 200, 150000, 150000 },
}
-- Chance of the seed and event cars before the odds rev. (their files at the 2026-10-27 baseline): the old order
local OLD_CHANCE = {
	wooden_car = 10,
	go_kart = 50,
	street_racer = 250,
	rain_runner = 500,
	rocket_car = 1000,
	midnight_kart = 2500,
	golden_racer = 5000,
	hover_car = 10000,
	void_racer = 100000,
}
local RARITY_TIERS = { "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local function sig2(x)
	local e = math.floor(math.log10(x)) - 1
	return math.round(x / 10 ^ e) * 10 ^ e
end
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
		local prevChance, oldChance = {}, {}
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
			local got = catalog.Get(id)
			-- the catalog's Chance sits in its rarity's band with 2 significant figures, and the manifest order keeps
			-- the old order: each car is rarer than the previous expansion car of the same rarity
			local chance = got and got.Chance
			flag(
				"expansion_rarity_band_" .. id,
				band ~= nil
					and type(chance) == "number"
					and chance >= band[2]
					and chance <= band[3]
					and chance == sig2(chance)
					and (prevChance[spec.Rarity] == nil or chance > prevChance[spec.Rarity])
					and math.abs(spec.SpeedMulti - (band[4] + band[5] * i)) < 1e-9,
				chance,
				band and band[2] .. ".." .. band[3]
			)
			prevChance[spec.Rarity] = type(chance) == "number" and chance or prevChance[spec.Rarity]
			oldChance[id] = band and band[6] + band[7] * i
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
		-- Odds rev.: every rollable car (seeds and event cars too) in its rarity's band; every car of a rarity is
		-- rarer than every car of the rarity below (Uncommon < Rare < ... < Secret)
		local lo, hi, outOfBand = {}, {}, {}
		for _, spec in catalog.All() do
			if spec.Chance ~= nil then
				local band = BANDS[spec.Rarity]
				if not band or spec.Chance < band[2] or spec.Chance > band[3] then
					table.insert(outOfBand, spec.Id)
				end
				lo[spec.Rarity] = math.min(lo[spec.Rarity] or math.huge, spec.Chance)
				hi[spec.Rarity] = math.max(hi[spec.Rarity] or 0, spec.Chance)
			end
		end
		flag("expansion_all_chances_in_band", #outOfBand == 0, table.concat(outOfBand, ","), "none")
		local tiersOk = true
		for t = 2, #RARITY_TIERS do
			local below, above = RARITY_TIERS[t - 1], RARITY_TIERS[t]
			tiersOk = tiersOk and hi[below] ~= nil and lo[above] ~= nil and hi[below] < lo[above]
		end
		flag("expansion_rarity_tiers_strictly_ordered", tiersOk)
		-- Odds rev. spacing (design doc "odds rev.", 2026-10-27): within each rarity the rollable cars, in their OLD
		-- order, span the band evenly on a log scale: the k-th of m is sig2(low * (high / low) ^ ((k - 1) / (m - 1))).
		-- Only the 2-significant-figure rounding is tolerated (a 1e-9 nudge covers a rounding tie in double maths).
		local byRarity = {}
		for _, spec in catalog.All() do
			if spec.Chance ~= nil and BANDS[spec.Rarity] then
				byRarity[spec.Rarity] = byRarity[spec.Rarity] or {}
				table.insert(byRarity[spec.Rarity], spec)
			end
		end
		for _, rarity in RARITY_TIERS do
			local list, band = byRarity[rarity] or {}, BANDS[rarity]
			local unknown = {}
			for _, spec in list do
				local old = OLD_CHANCE[spec.Id] or oldChance[spec.Id]
				if old == nil then
					table.insert(unknown, spec.Id)
				end
			end
			flag("odds_rev_old_order_known_" .. string.lower(rarity), #unknown == 0, table.concat(unknown, ","), "none")
			if #unknown == 0 and #list >= 2 then
				table.sort(list, function(a, b)
					return (OLD_CHANCE[a.Id] or oldChance[a.Id]) < (OLD_CHANCE[b.Id] or oldChance[b.Id])
				end)
				local bad, m = {}, #list
				for k, spec in list do
					local ideal = band[2] * (band[3] / band[2]) ^ ((k - 1) / (m - 1))
					local c = spec.Chance
					if c ~= sig2(ideal) and c ~= sig2(ideal * (1 + 1e-9)) and c ~= sig2(ideal * (1 - 1e-9)) then
						table.insert(bad, string.format("%s=%g(want %g)", spec.Id, c, sig2(ideal)))
					end
				end
				flag(
					"odds_rev_even_log_spacing_" .. string.lower(rarity),
					#bad == 0,
					#bad == 0 and m or table.concat(bad, ","),
					m
				)
			end
		end
		for id in expected do
			flag("expansion_index_contains_" .. id, seen[id] == true)
		end
		-- Independent ordered manifest/seed oracle for one forced hit at every expansion entry (catalog chances).
		for _, wantedSpec in manifest.Cars do
			local wanted = catalog.Get(wantedSpec.Id) or wantedSpec
			local calls, targetDraw = 0, 1
			for _, candidateSpec in manifest.Cars do
				local candidate = catalog.Get(candidateSpec.Id) or candidateSpec
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
