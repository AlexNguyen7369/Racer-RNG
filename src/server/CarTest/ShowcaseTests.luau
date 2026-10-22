--!nonstrict
-- BRIEF: docs/WORKSHOP_SPEC.md "5b. Showcase" (owner, 2026-10-22), docs/SAVE_SPEC.md VERSION 12, design doc
-- owner 2026-10-22 entries: "players show 3 cars of their choice in their workshop; duplicate rolls of those cars
-- raise workshop Speed gain ... duplicates are never sold (kept as copies), the player picks the 3 cars, and the
-- bonus comes from the car's SpeedMulti x its copies."
--   * Copies: a roll / grant of an already-owned rollable car adds 1 to GachaData.<id> attribute Copies, pays $0
--     (Roll's 5th return, scrapMoney, is 0; leaderstats.Money unchanged). GachaConfig.SCRAP_MONEY / ScrapMoney and
--     GachaService.ScrapValue are removed.
--   * SlotBonus = SHOWCASE_SCALE x log10(SpeedMulti) x (1 + COPY_BONUS x min(copies, MAX_COPIES));
--     ShowcaseMulti = 1 + sum SlotBonus. SHOWCASE_SLOTS 3, SCALE 0.25, COPY_BONUS 0.1, MAX_COPIES 50 (placeholders).
--   * SetShowcase(player, ids): array of <= 3 distinct owned rollable ids (never starter / gamepass); anything else
--     returns false and changes nothing. Attributes Showcase ("a,b,c") and ShowcaseMulti. Remotes.SetShowcase is a
--     RemoteFunction.
--   * WorkshopMulti = Workshop points multi x ShowcaseMulti: in WorkshopService.Rate and the offline Speed credit.
--   * Save: Snapshot/Apply carry Copies { [id] = n >= 1 } and Showcase { id, ... }; old saves load 0 / empty;
--     PlayerData VERSION 12. A rebirth keeps both (checked in the rebirth scenario).
--   * World: the owner's Plot_N.Workshop has ShowcasePedestal_1..3 (anchored, non-colliding); k showcased cars with a
--     CarModels template = k pedestals holding a Model "Car"; labels have a finite MaxDistance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent
local H = require(script.Parent.AcceptanceSupport)
local Tests = {}

-- The spec's numbers (docs/WORKSHOP_SPEC.md 5b). Independent oracle: never read from GachaConfig.
local SPEC = { SLOTS = 3, SCALE = 0.25, COPY_BONUS = 0.1, MAX_COPIES = 50, VERSION = 12, OFFLINE_FRACTION = 0.25 }
local UID = 990122000

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and a == a and math.abs(a - b) <= 1e-9 * math.max(1, math.abs(b))
end

local function oracleSlot(multi, copies)
	if type(multi) ~= "number" or multi ~= multi or multi <= 1 or multi == math.huge then
		return 0
	end
	if type(copies) ~= "number" or copies ~= copies or copies < 0 then
		copies = 0
	end
	copies = math.min(math.floor(copies), SPEC.MAX_COPIES)
	return SPEC.SCALE * math.log10(multi) * (1 + SPEC.COPY_BONUS * copies)
end

function Tests.showcase()
	local r, flag = H.report("showcase")
	local catalog = H.module(Shared, "CarCatalog")
	local config = H.module(Shared, "GachaConfig")
	local workshop = H.module(Shared, "Workshop")
	local wconfig = H.module(Shared, "WorkshopConfig")
	local gacha = H.module(Server, "GachaService")
	local data = H.module(Server, "PlayerData")
	local wservice = H.module(Server, "WorkshopService")
	local api = catalog
		and config
		and workshop
		and wconfig
		and gacha
		and data
		and wservice
		and type(config.SlotBonus) == "function"
		and type(config.ShowcaseMulti) == "function"
		and type(gacha.Copies) == "function"
		and type(gacha.SetShowcase) == "function"
		and type(gacha.ShowcaseMulti) == "function"
		and type(gacha.WorkshopMulti) == "function"
		and type(gacha.Snapshot) == "function"
		and type(gacha.Apply) == "function"
		and type(wservice.Rate) == "function"
		and type(wservice.Assign) == "function"
		and type(wservice.Release) == "function"
	flag("showcase_api_exists", api == true)
	if not api then
		return r
	end

	local cleanup, assigned = {}, {}
	local function fake(name)
		UID += 1
		local p = H.player(cleanup, UID)
		p.Name = "CarTestShowcase" .. name
		p:SetAttribute("DisplayName", "SC " .. name)
		data.Setup(p)
		gacha.Setup(p)
		return p, UID
	end
	local function specMulti(id)
		local spec = catalog.Get(id)
		return spec and spec.SpeedMulti or 1
	end
	local function oracleMulti(p, ids)
		local m = 1
		for _, id in ids do
			m += oracleSlot(specMulti(id), gacha.Copies(p, id))
		end
		return m
	end

	local ok, err = pcall(function()
		-- 1. Config: the spec's numbers; scrap removed
		flag(
			"showcase_config_matches_spec",
			config.SHOWCASE_SLOTS == SPEC.SLOTS
				and config.SHOWCASE_SCALE == SPEC.SCALE
				and config.COPY_BONUS == SPEC.COPY_BONUS
				and config.MAX_COPIES == SPEC.MAX_COPIES
		)
		local cap = config.MAX_SAVED_COPIES
		flag(
			"showcase_max_saved_copies_large_integer",
			type(cap) == "number" and cap == math.floor(cap) and cap >= 1e6 and cap < math.huge,
			type(cap) == "number" and cap or -1,
			1e6
		)
		local cd = config.SHOWCASE_COOLDOWN
		flag(
			"showcase_cooldown_seconds",
			type(cd) == "number" and cd > 0 and cd < math.huge,
			type(cd) == "number" and cd or -1,
			">0"
		)
		flag(
			"duplicate_scrap_money_removed",
			config.SCRAP_MONEY == nil and config.ScrapMoney == nil and gacha.ScrapValue == nil
		)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local remote = remotes and remotes:FindFirstChild("SetShowcase")
		flag("showcase_remote_is_remote_function", remote ~= nil and remote:IsA("RemoteFunction"))

		-- 2. Formula: SlotBonus against the oracle, copy cap, bad input, ShowcaseMulti = 1 + sum
		local formulaBad, tried = 0, 0
		for _, spec in catalog.Rollable() do
			for _, copies in { 0, 1, 7, 50, 51, 1000, -3, 0 / 0, "x", nil } do
				tried += 1
				local okS, got = pcall(config.SlotBonus, spec, copies)
				if not okS or not near(got, oracleSlot(spec.SpeedMulti, copies)) then
					formulaBad += 1
				end
			end
		end
		flag("slot_bonus_formula", tried > 0 and formulaBad == 0, formulaBad, 0)
		local kart = catalog.Get("go_kart")
		flag(
			"slot_bonus_copies_capped_at_max",
			kart ~= nil
				and near(config.SlotBonus(kart, 50), config.SlotBonus(kart, 5000))
				and config.SlotBonus(kart, 50) > config.SlotBonus(kart, 49)
		)
		local okNil, nilBonus = pcall(config.SlotBonus, nil, 5)
		flag("slot_bonus_nil_spec_zero", okNil and nilBonus == 0)
		local okFlat, flat = pcall(config.SlotBonus, { SpeedMulti = 1 }, 10)
		flag("slot_bonus_multi_1_zero", okFlat and near(flat, 0))
		flag("showcase_multi_empty_is_1", near(config.ShowcaseMulti({}), 1))
		local street, rocket = catalog.Get("street_racer"), catalog.Get("rocket_car")
		local list = { { Spec = kart, Copies = 3 }, { Spec = street, Copies = 0 }, { Spec = rocket, Copies = 60 } }
		local wantList = 1
			+ oracleSlot(2, 3)
			+ oracleSlot(street and street.SpeedMulti, 0)
			+ oracleSlot(rocket and rocket.SpeedMulti, 60)
		local okL, gotList = pcall(config.ShowcaseMulti, list)
		flag("showcase_multi_one_plus_sum", okL and near(gotList, wantList), okL and gotList or -1, wantList)

		-- 3. Copies: a duplicate grant adds 1 copy and pays nothing
		local p = fake("Copies")
		local money = p.leaderstats.Money
		money.Value = 777
		local earned0 = p:GetAttribute("MoneyEarned") or 0
		flag("copies_new_grant_true", gacha.Grant(p, "go_kart") == true)
		local entry = p.GachaData:FindFirstChild("go_kart")
		flag(
			"copies_fresh_car_zero",
			gacha.Copies(p, "go_kart") == 0 and entry ~= nil and (entry:GetAttribute("Copies") or 0) == 0
		)
		local dupe = gacha.Grant(p, "go_kart")
		flag(
			"copies_duplicate_grant_false_plus_one",
			dupe == false and gacha.Copies(p, "go_kart") == 1 and entry:GetAttribute("Copies") == 1,
			gacha.Copies(p, "go_kart"),
			1
		)
		gacha.Grant(p, "go_kart")
		gacha.Grant(p, "go_kart")
		flag("copies_count_each_duplicate", gacha.Copies(p, "go_kart") == 3, gacha.Copies(p, "go_kart"), 3)
		flag("copies_one_entry_only", #p.GachaData:GetChildren() == 1)
		flag(
			"copies_duplicate_grant_no_money",
			money.Value == 777 and (p:GetAttribute("MoneyEarned") or 0) == earned0,
			money.Value,
			777
		)
		flag(
			"copies_unowned_or_bad_id_zero",
			gacha.Copies(p, "street_racer") == 0 and gacha.Copies(p, "no_such_car") == 0 and gacha.Copies(p, nil) == 0
		)

		-- 4. Rolls: an owner of every rollable car rolls only duplicates: copies +1 each, scrapMoney 0, Money unchanged
		local q = fake("Rolls")
		for _, spec in catalog.Rollable() do
			gacha.Grant(q, spec.Id)
		end
		local function totalCopies()
			local n = 0
			for _, e in q.GachaData:GetChildren() do
				n += gacha.Copies(q, e.Name)
			end
			return n
		end
		q.leaderstats.Money.Value = 4321
		local qEarned = q:GetAttribute("MoneyEarned") or 0
		local before, rollBad, scrapBad = totalCopies(), 0, 0
		local rng = Random.new(2210)
		local ROLLS = 25
		for _ = 1, ROLLS do
			local okR, _, isNew, _, _, scrap = pcall(gacha.Roll, q, rng)
			if not okR or isNew ~= false then
				rollBad += 1
			end
			if scrap ~= 0 then
				scrapBad += 1
			end
		end
		flag("roll_duplicate_not_new", rollBad == 0, rollBad, 0)
		flag("roll_duplicate_scrap_money_zero", scrapBad == 0, scrapBad, 0)
		flag("roll_duplicates_add_copies", totalCopies() == before + ROLLS, totalCopies() - before, ROLLS)
		flag(
			"roll_duplicate_money_unchanged",
			q.leaderstats.Money.Value == 4321 and (q:GetAttribute("MoneyEarned") or 0) == qEarned,
			q.leaderstats.Money.Value,
			4321
		)

		-- 5. SetShowcase: validation; a rejected request changes nothing
		local s = fake("Set")
		for _, id in { "go_kart", "wooden_car", "street_racer", "rocket_car" } do
			gacha.Grant(s, id)
		end
		gacha.Grant(s, "go_kart") -- 1 copy
		gacha.Grant(s, "go_kart") -- 2 copies
		local okBase, reasonBase = gacha.SetShowcase(s, { "go_kart" })
		flag("set_showcase_one_car", okBase == true and s:GetAttribute("Showcase") == "go_kart", reasonBase)
		local pass = nil
		for _, spec in catalog.Passes() do
			if spec.GamepassId then
				pass = spec.Id
				s:SetAttribute("Pass_" .. spec.Id, true) -- even a pass the player owns can not be shown
				break
			end
		end
		local bad = {
			{ "nil_ids", nil },
			{ "string_ids", "go_kart" },
			{ "number_ids", 5 },
			{ "four_cars", { "go_kart", "wooden_car", "street_racer", "rocket_car" } },
			{ "duplicates", { "go_kart", "go_kart" } },
			{ "non_string", { "go_kart", 5 } },
			{ "unowned", { "rusty_hatchback" } },
			{ "unknown", { "no_such_car" } },
			{ "starter", { "starter" } },
			{ "sparse", { [1] = "go_kart", [3] = "wooden_car" } },
			{ "dictionary", { a = "go_kart" } },
			{ "mixed", { "wooden_car", x = "street_racer" } },
			{ "gamepass", { pass or "pass_car_missing" } },
		}
		local rejectBad = {}
		local multiBefore = s:GetAttribute("ShowcaseMulti")
		for _, case in bad do
			local okC, accepted = pcall(gacha.SetShowcase, s, case[2])
			if
				not okC
				or accepted ~= false
				or s:GetAttribute("Showcase") ~= "go_kart"
				or s:GetAttribute("ShowcaseMulti") ~= multiBefore
			then
				table.insert(rejectBad, case[1])
				gacha.SetShowcase(s, { "go_kart" })
			end
		end
		flag("set_showcase_rejects_invalid", #rejectBad == 0, table.concat(rejectBad, ","), "")
		flag("set_showcase_gamepass_fixture", pass ~= nil)
		local three = { "go_kart", "street_racer", "rocket_car" }
		local okThree = gacha.SetShowcase(s, three)
		local wantThree = oracleMulti(s, three)
		flag(
			"set_showcase_three_cars",
			okThree == true and s:GetAttribute("Showcase") == "go_kart,street_racer,rocket_car"
		)
		flag(
			"showcase_multi_formula",
			near(gacha.ShowcaseMulti(s), wantThree) and near(s:GetAttribute("ShowcaseMulti"), wantThree),
			gacha.ShowcaseMulti(s),
			wantThree
		)
		local noCopies = 1
			+ oracleSlot(specMulti("go_kart"), 0)
			+ oracleSlot(specMulti("street_racer"), 0)
			+ oracleSlot(specMulti("rocket_car"), 0)
		flag("showcase_multi_uses_copies", gacha.Copies(s, "go_kart") == 2 and gacha.ShowcaseMulti(s) > noCopies + 1e-9)
		-- a copy rolled while shown raises the multi, and the UI attribute mirrors it
		gacha.Grant(s, "street_racer")
		task.wait()
		local wantMore = oracleMulti(s, three)
		flag(
			"showcase_multi_follows_new_copy",
			wantMore > wantThree
				and near(gacha.ShowcaseMulti(s), wantMore)
				and near(s:GetAttribute("ShowcaseMulti"), wantMore),
			s:GetAttribute("ShowcaseMulti"),
			wantMore
		)
		-- WorkshopMulti = Workshop points multi x ShowcaseMulti
		local points = config.Multis({ Workshop = s:GetAttribute("Alloc_Workshop") }).Workshop
		flag(
			"workshop_multi_includes_showcase",
			near(gacha.WorkshopMulti(s), points * wantMore),
			gacha.WorkshopMulti(s),
			points * wantMore
		)
		local rateShown = wservice.Rate(s)
		local okEmpty = gacha.SetShowcase(s, {})
		flag(
			"set_showcase_empty_clears",
			okEmpty == true
				and s:GetAttribute("Showcase") == ""
				and near(gacha.ShowcaseMulti(s), 1)
				and near(s:GetAttribute("ShowcaseMulti"), 1)
		)
		local rateBare = wservice.Rate(s)
		flag(
			"workshop_rate_includes_showcase",
			type(rateBare) == "number" and rateBare > 0 and near(rateShown / rateBare, wantMore),
			type(rateBare) == "number" and rateBare > 0 and rateShown / rateBare or -1,
			wantMore
		)

		-- 6. Snapshot / Apply cleaning
		gacha.SetShowcase(s, { "rocket_car", "go_kart" })
		local snap = gacha.Snapshot(s)
		flag(
			"snapshot_copies_only_positive",
			type(snap.Copies) == "table" and H.same(snap.Copies, { go_kart = 2, street_racer = 1 })
		)
		flag(
			"snapshot_showcase_in_order",
			type(snap.Showcase) == "table" and H.same(snap.Showcase, { "rocket_car", "go_kart" })
		)
		local a = fake("Apply")
		if pass then
			a:SetAttribute("Pass_" .. pass, true)
		end
		gacha.Apply(a, {
			Cars = { "go_kart", "wooden_car", "street_racer" },
			Copies = { go_kart = 3.9, wooden_car = -2, street_racer = 1e15, rocket_car = 7, starter = 4 },
			Showcase = { "go_kart", "go_kart", "rocket_car", "starter", "no_such_car", 7, pass or "x", "wooden_car" },
		})
		flag(
			"apply_copies_cleaned",
			gacha.Copies(a, "go_kart") == 3
				and gacha.Copies(a, "wooden_car") == 0
				and gacha.Copies(a, "street_racer") == config.MAX_SAVED_COPIES
				and gacha.Copies(a, "rocket_car") == 0
				and a.GachaData:FindFirstChild("rocket_car") == nil
		)
		local snapA = gacha.Snapshot(a)
		flag(
			"apply_snapshot_drops_unowned_copies",
			type(snapA.Copies) == "table"
				and snapA.Copies.rocket_car == nil
				and snapA.Copies.starter == nil
				and snapA.Copies.wooden_car == nil
		)
		local shown = string.split(a:GetAttribute("Showcase") or "", ",")
		local seen, showOk = {}, #shown >= 1 and #shown <= SPEC.SLOTS and shown[1] == "go_kart"
		for _, id in shown do
			showOk = showOk and not seen[id] and (id == "go_kart" or id == "wooden_car")
			seen[id] = true
		end
		flag("apply_showcase_cleaned", showOk, a:GetAttribute("Showcase"), "go_kart[,wooden_car]")
		flag("apply_sets_showcase_multi", near(a:GetAttribute("ShowcaseMulti"), oracleMulti(a, shown)))
		local b = fake("ApplyFour")
		gacha.Apply(b, {
			Cars = { "go_kart", "wooden_car", "street_racer", "rocket_car" },
			Showcase = { "go_kart", "wooden_car", "street_racer", "rocket_car" },
		})
		local four = string.split(b:GetAttribute("Showcase") or "", ",")
		flag("apply_showcase_at_most_3", #four == SPEC.SLOTS, #four, SPEC.SLOTS)
		local junkBad = 0
		for _, junk in
			{
				{ Cars = { "go_kart" }, Copies = "junk", Showcase = "junk" },
				{ Cars = { "go_kart" }, Copies = { go_kart = 0 / 0 }, Showcase = { go_kart = true } },
				{ Cars = { "go_kart" }, Copies = { go_kart = "9" } },
			}
		do
			local j = fake("Junk")
			local okJ = pcall(gacha.Apply, j, junk)
			if
				not okJ
				or gacha.Copies(j, "go_kart") ~= 0
				or (j:GetAttribute("Showcase") or "") ~= ""
				or not near(gacha.ShowcaseMulti(j), 1)
			then
				junkBad += 1
			end
		end
		flag("apply_junk_fields_safe", junkBad == 0, junkBad, 0)
		local old = fake("OldSave")
		gacha.Apply(old, { Cars = { "go_kart", "street_racer" }, Equipped = "go_kart", Rolls = 4 })
		local snapOld = gacha.Snapshot(old)
		flag(
			"apply_old_save_zero_copies_empty_showcase",
			gacha.Copies(old, "go_kart") == 0
				and (old:GetAttribute("Showcase") or "") == ""
				and near(gacha.ShowcaseMulti(old), 1)
				and type(snapOld.Copies) == "table"
				and next(snapOld.Copies) == nil
				and type(snapOld.Showcase) == "table"
				and #snapOld.Showcase == 0
		)

		-- 7. PlayerData VERSION 12: offline credit includes the showcase, save round trip, old save upgraded
		local at = 1800000000
		local function record(showcase)
			return {
				Version = SPEC.VERSION,
				Money = 10,
				Speed = 1000,
				WorkshopLevel = 1,
				OfflineAt = at - 3600,
				Cars = { "go_kart", "street_racer" },
				Copies = { go_kart = 4 },
				Showcase = showcase,
			}
		end
		local uidShown, uidBare, uidOld = UID + 101, UID + 102, UID + 103
		local store = H.store({
			[data.KeyFor(uidShown)] = record({ "go_kart", "street_racer" }),
			[data.KeyFor(uidBare)] = record({}),
			[data.KeyFor(uidOld)] = { Version = 11, Money = 5, Speed = 1, Cars = { "go_kart" } },
		})
		data.SetStore(store)
		data.SetClock(function()
			return at
		end)
		local pShown = H.player(cleanup, uidShown)
		local pBare = H.player(cleanup, uidBare)
		flag("data_load_showcase_save", data.Load(pShown, uidShown) == true and data.Load(pBare, uidBare) == true)
		local wantShow = oracleMulti(pShown, { "go_kart", "street_racer" })
		local gShown, gBare = pShown:GetAttribute("OfflineSpeed"), pBare:GetAttribute("OfflineSpeed")
		flag(
			"offline_gain_includes_showcase",
			type(gShown) == "number" and type(gBare) == "number" and gBare > 0 and near(gShown / gBare, wantShow),
			type(gBare) == "number" and gBare > 0 and gShown / gBare or -1,
			wantShow
		)
		local wantBare = SPEC.OFFLINE_FRACTION
			* wconfig.BASE_RATE
			* gacha.SpeedMulti(pBare)
			* wconfig.Levels[1].Multi
			* config.Multis({}).Workshop
			* 3600
		flag("offline_gain_bare_rate_times_time", near(gBare, wantBare), gBare, wantBare)
		flag(
			"data_load_applies_copies_and_showcase",
			gacha.Copies(pShown, "go_kart") == 4
				and pShown:GetAttribute("Showcase") == "go_kart,street_racer"
				and near(pShown:GetAttribute("ShowcaseMulti"), wantShow)
		)
		gacha.Grant(pShown, "go_kart") -- 5 copies
		flag("data_save_ok", data.Save(pShown, uidShown, true) == true)
		local rec = store.data[data.KeyFor(uidShown)]
		flag(
			"data_saved_version_12",
			type(rec) == "table" and rec.Version == SPEC.VERSION,
			type(rec) == "table" and rec.Version or -1,
			SPEC.VERSION
		)
		flag(
			"data_saved_copies_and_showcase",
			type(rec) == "table"
				and H.same(rec.Copies, { go_kart = 5 })
				and H.same(rec.Showcase, { "go_kart", "street_racer" })
		)
		local back = H.player(cleanup, uidShown)
		flag("data_reload", data.Load(back, uidShown) == true)
		flag(
			"data_round_trip_copies_and_showcase",
			gacha.Copies(back, "go_kart") == 5
				and gacha.Copies(back, "street_racer") == 0
				and back:GetAttribute("Showcase") == "go_kart,street_racer"
				and near(back:GetAttribute("ShowcaseMulti"), oracleMulti(back, { "go_kart", "street_racer" }))
		)
		local pOld = H.player(cleanup, uidOld)
		flag("data_old_save_loads", data.Load(pOld, uidOld) == true)
		flag(
			"data_old_save_zero_copies_empty_showcase",
			gacha.Copies(pOld, "go_kart") == 0
				and (pOld:GetAttribute("Showcase") or "") == ""
				and near(gacha.ShowcaseMulti(pOld), 1)
		)
		data.Save(pOld, uidOld, true)
		local recOld = store.data[data.KeyFor(uidOld)]
		flag(
			"data_old_save_upgraded_to_12",
			type(recOld) == "table"
				and recOld.Version == SPEC.VERSION
				and (recOld.Copies == nil or next(recOld.Copies) == nil)
				and (recOld.Showcase == nil or #recOld.Showcase == 0)
		)
		data.SetStore(nil)
		data.SetClock(nil)

		-- 8. World: pedestals on the owner's plot; showcased cars with a template stand on them
		local w = fake("World")
		for _, id in { "go_kart", "street_racer", "rocket_car" } do
			gacha.Grant(w, id)
		end
		gacha.SetShowcase(w, { "go_kart", "street_racer" }) -- set before the plot exists, as on join
		local index = wservice.Assign(w)
		table.insert(assigned, w)
		local folder = Workspace:FindFirstChild("Workshops")
		local plot = folder and type(index) == "number" and folder:FindFirstChild("Plot_" .. index)
		local model = plot and plot:FindFirstChild("Workshop")
		flag("world_owner_has_workshop", model ~= nil, index, ">0")
		local pedestals, pedOk = {}, model ~= nil
		for i = 1, SPEC.SLOTS do
			local ped = model and model:FindFirstChild("ShowcasePedestal_" .. i, true)
			pedOk = pedOk and ped ~= nil and ped:IsA("BasePart") and ped.Anchored and not ped.CanCollide
			pedestals[i] = ped
		end
		flag("world_three_pedestals_anchored_non_colliding", pedOk)
		local templates = ReplicatedStorage:FindFirstChild("CarModels")
		local function withTemplate(ids)
			local n = 0
			for _, id in ids do
				local spec = catalog.Get(id)
				if templates and spec and spec.Model and templates:FindFirstChild(spec.Model) then
					n += 1
				end
			end
			return n
		end
		local function carsShown()
			local n, labels, labelsOk, anchored = 0, 0, true, true
			for _, ped in pedestals do
				local car = ped and ped:FindFirstChild("Car")
				if car and car:IsA("Model") then
					n += 1
					for _, d in car:GetDescendants() do
						if d:IsA("BasePart") and not d.Anchored then
							anchored = false
						end
					end
				end
				for _, d in (ped and ped:GetDescendants() or {}) do
					if d:IsA("BillboardGui") then
						labels += 1
						labelsOk = labelsOk and d.MaxDistance > 0 and d.MaxDistance < math.huge
					end
				end
			end
			return n, labels, labelsOk, anchored
		end
		local function waitShown(want)
			local deadline = os.clock() + 3
			repeat
				local n = carsShown()
				if n == want then
					break
				end
				task.wait(0.1)
			until os.clock() > deadline
			return carsShown()
		end
		if pedOk then
			local want2 = withTemplate({ "go_kart", "street_racer" })
			local n2, labels2, labelsOk2, anchored2 = waitShown(want2)
			flag("world_showcase_on_assign", n2 == want2, n2, want2)
			flag("world_showcase_labels_finite", labels2 >= n2 and labelsOk2, labels2, n2)
			flag("world_showcase_cars_static", anchored2)
			gacha.SetShowcase(w, { "go_kart", "street_racer", "rocket_car" })
			local want3 = withTemplate({ "go_kart", "street_racer", "rocket_car" })
			local n3 = waitShown(want3)
			flag("world_showcase_follows_set", n3 == want3, n3, want3)
			gacha.SetShowcase(w, {})
			local n0 = waitShown(0)
			flag("world_showcase_cleared", n0 == 0, n0, 0)
		end
	end)
	for _, p in assigned do
		pcall(wservice.Release, p)
	end
	pcall(data.SetStore, nil)
	pcall(data.SetClock, nil)
	for _, object in cleanup do
		object:Destroy()
	end
	flag("showcase_no_error", ok, ok and 1 or tostring(err))
	return r
end

return Tests
