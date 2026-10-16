--!nonstrict
-- BRIEF (owner, 2026-10-16; design doc "Monetization" -> Shop, Codes; contract docs/SHOP_PURCHASES_SPEC.md sections
-- 1-4, docs/GAMEPASS_SHOP_SPEC.md section 2 and docs/SAVE_SPEC.md 2a): "Products table with the potion packs, the
-- bundle and display-only Server Luck; ProcessReceipt grants exactly once and only after a successful save; codes give
-- potions once per player and never Money or Speed; PlayerData VERSION 9 saves Receipts and Codes."
-- Written before Server/ShopService, Server/CodeConfig and MonetizationConfig.Products exist: red by design.
-- While it runs the test sets made-up ProductIds on three Products entries, injects test codes into
-- CodeConfig.Codes, replaces the save with ShopService.SetSave and uses the first loaded real player for receipts
-- (ProcessReceipt finds players by UserId). Every one of those is put back at the end, even after an error.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent
local Tests = {}

-- Spec section 1 (Grants are fixed; RobuxPrice values are proposed, so only checked positive whole numbers)
local PACKS = {
	{ Id = "potion_luck_pack", Boost = "LuckIII" },
	{ Id = "potion_money_pack", Boost = "MoneyIII" },
	{ Id = "potion_speed_pack", Boost = "SpeedIII" },
}
local PACK_COUNT = 5
local BUNDLE_ID = "potion_bundle"
local BUNDLE_COUNT = 10 -- of every one of the 9 potions
local BUNDLE_POTIONS = 9
local SERVER_LUCK_IDS = { "server_luck_2x", "server_luck_4x", "server_luck_8x" }
local SECTIONS = { Potions = true, Bundle = true, ServerLuck = true }
local MAX_RECEIPTS = 100
local CODE_COOLDOWN = 2
local MAX_CODE_LENGTH = 32
local DATA_VERSION = 9
local MSG_INVALID = "Invalid code"
local MSG_NOT_LOADED = "Data not loaded"
local MSG_WAIT = "Please wait"
local MSG_ALREADY = "Already redeemed"
local MSG_OK = "Code redeemed!"

-- made-up ids, never real
local FAKE_LUCK_PRODUCT = 990075101
local FAKE_BUNDLE_PRODUCT = 990075102
local FAKE_SERVER_LUCK_PRODUCT = 990075103
local UNKNOWN_PRODUCT = 990075199
local ABSENT_USER = 990075001
local DATA_UID = 990075201
local DATA_UID_OLD = 990075202
local TRIM_EXTRA = 5
local IN_FLIGHT_SAVE_SECONDS = 0.3
local IN_FLIGHT_WAIT_LIMIT = 3

-- test codes injected into CodeConfig.Codes (keys upper case, as the spec requires)
local CODE = "CARTESTCODE"
local CODE_GRANTS = { LuckI = 2, MoneyII = 1 }
local CODE_32 = string.rep("Z", MAX_CODE_LENGTH - 7) .. "CARTEST" -- exactly 32 characters
local CODE_33 = string.rep("Y", MAX_CODE_LENGTH + 1 - 7) .. "CARTEST" -- 33: refused even though configured

local function module(parent, name)
	local source = parent:FindFirstChild(name)
	if not source then
		return nil
	end
	local ok, value = pcall(require, source)
	return ok and type(value) == "table" and value or nil
end

local function report(name)
	local r = { scenario = name, pass = true, checks = {}, metrics = {} }
	local function flag(label, ok, value, limit)
		table.insert(
			r.checks,
			{ name = label, pass = ok == true, value = value or (ok and 1 or 0), limit = limit or 1 }
		)
		r.pass = r.pass and ok == true
	end
	return r, flag
end

local function wholeNumber(v, min)
	return type(v) == "number" and v == v and math.abs(v) ~= math.huge and math.floor(v) == v and v >= min
end

local function countKeys(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function contains(list, value)
	if type(list) ~= "table" then
		return false
	end
	for _, v in list do
		if v == value then
			return true
		end
	end
	return false
end

local function sameArray(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b or countKeys(a) ~= #a then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function sameSet(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	local sa, sb = table.clone(a), table.clone(b)
	table.sort(sa, function(x, y)
		return tostring(x) < tostring(y)
	end)
	table.sort(sb, function(x, y)
		return tostring(x) < tostring(y)
	end)
	return sameArray(sa, sb)
end

function Tests.shop_purchases()
	local r, flag = report("shop_purchases")
	local monetization = module(Shared, "MonetizationConfig")
	local boostConfig = module(Shared, "BoostConfig")
	local shop = module(Server, "ShopService")
	local codeConfig = module(Server, "CodeConfig")
	local playerData = module(Server, "PlayerData")
	local rebirth = module(Server, "RebirthService")

	local apiOk = shop ~= nil
		and type(shop.ProcessReceipt) == "function"
		and type(shop.Redeem) == "function"
		and type(shop.Apply) == "function"
		and type(shop.Snapshot) == "function"
		and type(shop.SetSave) == "function"
	flag("shop_service_api_exists", apiOk)
	flag("shop_max_receipts_100", shop ~= nil and shop.MAX_RECEIPTS == MAX_RECEIPTS, shop and shop.MAX_RECEIPTS)
	flag("shop_code_cooldown_2", shop ~= nil and shop.CODE_COOLDOWN == CODE_COOLDOWN, shop and shop.CODE_COOLDOWN)
	flag(
		"shop_code_config_server_only",
		codeConfig ~= nil
			and type(codeConfig.Codes) == "table"
			and ReplicatedStorage:FindFirstChild("CodeConfig", true) == nil
	)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local redeemRemote = remotes and remotes:FindFirstChild("RedeemCode")
	flag("shop_redeem_remote_exists", redeemRemote ~= nil and redeemRemote:IsA("RemoteFunction"))

	-- Section 1: Products
	local products = monetization and monetization.Products
	flag("shop_products_is_array", type(products) == "table" and #products > 0 and countKeys(products) == #products)
	products = type(products) == "table" and products or {}
	local byId, ids, shapeOk = {}, {}, #products > 0
	for _, p in products do
		local ok = type(p) == "table"
			and type(p.Id) == "string"
			and p.Id ~= ""
			and not ids[p.Id]
			and type(p.Name) == "string"
			and p.Name ~= ""
			and type(p.Description) == "string"
			and SECTIONS[p.Section] == true
			and wholeNumber(p.ProductId, 0)
			and wholeNumber(p.RobuxPrice, 1)
			and (p.Grants == nil or type(p.Grants) == "table")
		shapeOk = shapeOk and ok
		if type(p) == "table" and type(p.Id) == "string" then
			ids[p.Id] = true
			byId[p.Id] = p
		end
	end
	flag("shop_products_entry_shape", shapeOk)
	local function validGrant(id, count, want)
		local item = boostConfig and boostConfig.Items and boostConfig.Items[id]
		-- the tier id itself, never a category alias such as "Luck"
		return item ~= nil and item.Id == id and count == want
	end
	for _, pack in PACKS do
		local p = byId[pack.Id]
		local g = p and p.Grants
		flag("shop_product_exists_" .. pack.Id, p ~= nil)
		flag("shop_product_section_" .. pack.Id, p ~= nil and p.Section == "Potions", p and tostring(p.Section))
		flag(
			"shop_product_grants_" .. pack.Id,
			type(g) == "table" and countKeys(g) == 1 and validGrant(pack.Boost, g[pack.Boost], PACK_COUNT),
			g and tostring(g[pack.Boost]),
			PACK_COUNT
		)
	end
	local bundle = byId[BUNDLE_ID]
	local bg = bundle and bundle.Grants
	flag("shop_product_exists_" .. BUNDLE_ID, bundle ~= nil)
	flag("shop_product_section_" .. BUNDLE_ID, bundle ~= nil and bundle.Section == "Bundle")
	local bundleOk = type(bg) == "table" and countKeys(bg) == BUNDLE_POTIONS and boostConfig ~= nil
	if bundleOk then
		for _, category in boostConfig.Order do
			for _, item in boostConfig.ItemsFor(category) do
				bundleOk = bundleOk and validGrant(item.Id, bg[item.Id], BUNDLE_COUNT)
			end
		end
	end
	flag("shop_product_grants_" .. BUNDLE_ID, bundleOk, bg and countKeys(bg) or 0, BUNDLE_POTIONS)
	for _, id in SERVER_LUCK_IDS do
		local p = byId[id]
		flag(
			"shop_product_server_luck_" .. id,
			p ~= nil and p.Section == "ServerLuck" and p.Grants == nil and p.ProductId == 0
		)
	end
	-- docs/GAMEPASS_SHOP_SPEC.md section 2: every gamepass has a whole RobuxPrice
	local passes = monetization and monetization.Gamepasses
	local passPrices = type(passes) == "table" and #passes > 0
	for _, g in type(passes) == "table" and passes or {} do
		passPrices = passPrices and wholeNumber(g.RobuxPrice, 1)
	end
	flag("shop_gamepasses_robux_price", passPrices)

	if not (apiOk and boostConfig and codeConfig and type(codeConfig.Codes) == "table" and playerData) then
		flag("shop_dependencies_present", false)
		return r
	end

	local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
	local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet
	local allItems = {}
	for _, category in boostConfig.Order do
		for _, item in boostConfig.ItemsFor(category) do
			table.insert(allItems, item.Id)
		end
	end
	local function counts(p)
		local c = {}
		for _, id in allItems do
			c[id] = p:GetAttribute("Boost_" .. id) or 0
		end
		return c
	end
	-- true when every count changed by exactly `delta[id]` (0 for the rest)
	local function changedBy(before, after, delta)
		for _, id in allItems do
			if after[id] - before[id] ~= (delta[id] or 0) then
				return false
			end
		end
		return true
	end
	local function snapshot(p)
		local ok, s = pcall(shop.Snapshot, p)
		return ok and type(s) == "table" and s or {}
	end

	-- everything the test changes, put back in `restore`
	local cleanup = {}
	local savedProductIds = {}
	local injectedCodes = { CODE, CODE_32, CODE_33 }
	local realPlayer, realBoosts, realShop, realLoaded, realFailed = nil, nil, nil, nil, nil
	local function restore()
		pcall(shop.SetSave, nil)
		for p, id in savedProductIds do
			p.ProductId = id
		end
		for _, code in injectedCodes do
			codeConfig.Codes[code] = nil
		end
		if realPlayer then
			realPlayer:SetAttribute("DataLoaded", realLoaded)
			realPlayer:SetAttribute("DataFailed", realFailed)
			for id, n in realBoosts do
				realPlayer:SetAttribute("Boost_" .. id, n)
			end
			pcall(shop.Apply, realPlayer, realShop)
		end
		pcall(playerData.SetStore, nil)
		for _, inst in cleanup do
			inst:Destroy()
		end
	end
	local function newPlayer(name, loaded)
		local p = Instance.new("Folder")
		p.Name = name
		p.Parent = Workspace
		table.insert(cleanup, p)
		pcall(playerData.Setup, p)
		if loaded then
			p:SetAttribute("DataLoaded", true)
		end
		return p
	end

	local ok, err = pcall(function()
		-- Section 2: receipts (needs a real, loaded player: ProcessReceipt looks players up by UserId)
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("DataLoaded") == true and not p:GetAttribute("DataFailed") then
				realPlayer = p
				break
			end
		end
		flag("shop_receipt_test_player_present", realPlayer ~= nil)
		local luck = byId.potion_luck_pack
		local money = byId.potion_money_pack
		local luckServer = byId.server_luck_2x
		if realPlayer and luck and bundle and luckServer and money then
			local rp = realPlayer
			realLoaded, realFailed = rp:GetAttribute("DataLoaded"), rp:GetAttribute("DataFailed")
			realBoosts = counts(rp)
			realShop = snapshot(rp)
			savedProductIds[luck] = luck.ProductId
			savedProductIds[bundle] = bundle.ProductId
			savedProductIds[luckServer] = luckServer.ProductId
			luck.ProductId = FAKE_LUCK_PRODUCT
			bundle.ProductId = FAKE_BUNDLE_PRODUCT
			luckServer.ProductId = FAKE_SERVER_LUCK_PRODUCT
			local saveCalls, saveResult, saveDelay, savePlayer = 0, true, 0, nil
			shop.SetSave(function(p)
				saveCalls += 1
				savePlayer = p
				if saveDelay > 0 then
					task.wait(saveDelay)
				end
				return saveResult
			end)
			local function receipt(productId, purchaseId, userId)
				local okCall, decision = pcall(shop.ProcessReceipt, {
					PlayerId = userId or rp.UserId,
					ProductId = productId,
					PurchaseId = purchaseId,
					CurrencySpent = 1,
					CurrencyType = Enum.CurrencyType.Robux,
					PlaceIdWherePurchased = game.PlaceId,
				})
				return okCall and decision or "error"
			end

			local b0 = counts(rp)
			flag(
				"shop_receipt_unknown_product_not_processed",
				receipt(UNKNOWN_PRODUCT, "cartest_shop_unknown") == NOT_YET and changedBy(b0, counts(rp), {})
			)
			flag(
				"shop_receipt_product_id_zero_not_processed",
				receipt(0, "cartest_shop_zero") == NOT_YET and changedBy(b0, counts(rp), {})
			)
			flag(
				"shop_receipt_no_grants_not_processed",
				receipt(FAKE_SERVER_LUCK_PRODUCT, "cartest_shop_serverluck") == NOT_YET
					and changedBy(b0, counts(rp), {})
			)
			flag(
				"shop_receipt_player_absent_not_processed",
				receipt(FAKE_LUCK_PRODUCT, "cartest_shop_absent", ABSENT_USER) == NOT_YET
					and changedBy(b0, counts(rp), {})
			)
			rp:SetAttribute("DataLoaded", false)
			local dNotLoaded = receipt(FAKE_LUCK_PRODUCT, "cartest_shop_notloaded")
			rp:SetAttribute("DataLoaded", realLoaded)
			flag(
				"shop_receipt_not_loaded_not_processed",
				dNotLoaded == NOT_YET and changedBy(b0, counts(rp), {}),
				tostring(dNotLoaded)
			)
			rp:SetAttribute("DataFailed", true)
			local dFailed = receipt(FAKE_LUCK_PRODUCT, "cartest_shop_datafailed")
			rp:SetAttribute("DataFailed", realFailed)
			flag(
				"shop_receipt_data_failed_not_processed",
				dFailed == NOT_YET and changedBy(b0, counts(rp), {}),
				tostring(dFailed)
			)
			flag("shop_receipt_refused_never_saves", saveCalls == 0, saveCalls, 0)

			-- valid purchase
			local b1 = counts(rp)
			local d1 = receipt(FAKE_LUCK_PRODUCT, "cartest_shop_a")
			local a1 = counts(rp)
			flag("shop_receipt_valid_granted", d1 == GRANTED, tostring(d1))
			flag(
				"shop_receipt_grants_exact_count",
				a1.LuckIII - b1.LuckIII == PACK_COUNT,
				a1.LuckIII - b1.LuckIII,
				PACK_COUNT
			)
			flag("shop_receipt_grants_nothing_else", changedBy(b1, a1, { LuckIII = PACK_COUNT }))
			flag("shop_receipt_saves_once", saveCalls == 1 and savePlayer == rp, saveCalls, 1)
			flag("shop_receipt_records_purchase_id", contains(snapshot(rp).Receipts, "cartest_shop_a"))
			local d1b = receipt(FAKE_LUCK_PRODUCT, "cartest_shop_a")
			flag("shop_receipt_duplicate_granted_once", d1b == GRANTED and changedBy(a1, counts(rp), {}), tostring(d1b))

			-- the bundle
			local b2 = counts(rp)
			local d2 = receipt(FAKE_BUNDLE_PRODUCT, "cartest_shop_b")
			local bundleDelta = {}
			for _, id in allItems do
				bundleDelta[id] = BUNDLE_COUNT
			end
			flag(
				"shop_receipt_bundle_grants_ten_each",
				d2 == GRANTED and changedBy(b2, counts(rp), bundleDelta),
				tostring(d2)
			)

			-- a failed save rolls everything back
			saveResult = false
			local b3 = counts(rp)
			local d3 = receipt(FAKE_LUCK_PRODUCT, "cartest_shop_c")
			flag("shop_receipt_save_failure_not_processed", d3 == NOT_YET, tostring(d3))
			flag("shop_receipt_save_failure_rolls_back_grants", changedBy(b3, counts(rp), {}))
			flag(
				"shop_receipt_save_failure_rolls_back_purchase_id",
				not contains(snapshot(rp).Receipts, "cartest_shop_c")
			)
			saveResult = true
			local d3b = receipt(FAKE_LUCK_PRODUCT, "cartest_shop_c")
			flag(
				"shop_receipt_retry_after_failure_grants",
				d3b == GRANTED and changedBy(b3, counts(rp), { LuckIII = PACK_COUNT }),
				tostring(d3b)
			)

			-- the same PurchaseId while the first is still saving
			saveDelay = IN_FLIGHT_SAVE_SECONDS
			local b4 = counts(rp)
			local first = nil
			task.spawn(function()
				first = receipt(FAKE_LUCK_PRODUCT, "cartest_shop_d")
			end)
			local second = receipt(FAKE_LUCK_PRODUCT, "cartest_shop_d")
			local waited = 0
			while first == nil and waited < IN_FLIGHT_WAIT_LIMIT do
				waited += task.wait()
			end
			saveDelay = 0
			flag("shop_receipt_in_flight_not_processed", second == NOT_YET, tostring(second))
			flag(
				"shop_receipt_in_flight_grants_once",
				first == GRANTED and changedBy(b4, counts(rp), { LuckIII = PACK_COUNT }),
				tostring(first)
			)

			-- only the last MAX_RECEIPTS purchase ids are kept
			local total = MAX_RECEIPTS + TRIM_EXTRA
			local trimOk = true
			for i = 1, total do
				trimOk = trimOk and receipt(FAKE_LUCK_PRODUCT, ("cartest_shop_trim_%03d"):format(i)) == GRANTED
			end
			local kept = snapshot(rp).Receipts
			local n = type(kept) == "table" and #kept or -1
			flag("shop_receipts_trimmed_to_max", trimOk and n == MAX_RECEIPTS, n, MAX_RECEIPTS)
			local newestKept = contains(kept, ("cartest_shop_trim_%03d"):format(total))
				and contains(kept, ("cartest_shop_trim_%03d"):format(TRIM_EXTRA + 1))
			for i = 1, TRIM_EXTRA do
				newestKept = newestKept and not contains(kept, ("cartest_shop_trim_%03d"):format(i))
			end
			flag("shop_receipts_keep_newest", newestKept)

			-- a purchase id loaded from the save is never granted again
			pcall(shop.Apply, rp, { Receipts = { "cartest_shop_saved" }, Codes = {} })
			local b5 = counts(rp)
			local d5 = receipt(FAKE_LUCK_PRODUCT, "cartest_shop_saved")
			flag(
				"shop_receipt_saved_id_not_granted_again",
				d5 == GRANTED and changedBy(b5, counts(rp), {}),
				tostring(d5)
			)
			pcall(shop.SetSave, nil)
		end

		-- Section 3: codes (fake players; a fresh player per case so the cooldown never mixes cases)
		codeConfig.Codes[CODE] = { Grants = CODE_GRANTS }
		codeConfig.Codes[CODE_32] = { Grants = { SpeedI = 1 } }
		codeConfig.Codes[CODE_33] = { Grants = { SpeedI = 1 } }
		local function redeem(p, text)
			local okCall, success, message = pcall(shop.Redeem, p, text)
			return okCall and success, okCall and message or "error"
		end
		local function refused(name, text, want, loaded)
			local p = newPlayer("CarTestShop_" .. name, loaded ~= false)
			local before = counts(p)
			local success, message = redeem(p, text)
			flag(
				"shop_code_" .. name,
				success == false and message == want and changedBy(before, counts(p), {}),
				tostring(message),
				want
			)
		end
		refused("non_string_invalid", 42, MSG_INVALID)
		refused("nil_invalid", nil, MSG_INVALID)
		refused("empty_invalid", "", MSG_INVALID)
		refused("blank_invalid", "   ", MSG_INVALID)
		refused("over_32_invalid", CODE_33, MSG_INVALID)
		refused("unknown_invalid", "NOPE_CARTEST", MSG_INVALID)
		refused("not_loaded", CODE, MSG_NOT_LOADED, false)

		local p32 = newPlayer("CarTestShop_32", true)
		local b32 = counts(p32)
		local ok32, msg32 = redeem(p32, "  " .. CODE_32:lower() .. "  ")
		flag(
			"shop_code_32_chars_accepted",
			ok32 == true and msg32 == MSG_OK and changedBy(b32, counts(p32), { SpeedI = 1 }),
			tostring(msg32)
		)

		local pc = newPlayer("CarTestShop_Main", true)
		local stats = pc:FindFirstChild("leaderstats")
		local moneyValue = stats and stats:FindFirstChild("Money")
		local speedValue = stats and stats:FindFirstChild("Speed")
		if moneyValue then
			moneyValue.Value = 500
		end
		if speedValue then
			speedValue.Value = 7.5
		end
		local bc = counts(pc)
		local okC, msgC = redeem(pc, "  cartestcode \t")
		flag("shop_code_case_trim_insensitive", okC == true and msgC == MSG_OK, tostring(msgC), MSG_OK)
		flag("shop_code_grants_exact", changedBy(bc, counts(pc), CODE_GRANTS))
		flag(
			"shop_code_money_speed_unchanged",
			moneyValue ~= nil and speedValue ~= nil and moneyValue.Value == 500 and speedValue.Value == 7.5
		)
		flag("shop_code_recorded_upper_case", sameArray(snapshot(pc).Codes, { CODE }))
		local bw = counts(pc)
		local okW, msgW = redeem(pc, CODE_32)
		flag(
			"shop_code_cooldown_please_wait",
			okW == false and msgW == MSG_WAIT and changedBy(bw, counts(pc), {}),
			tostring(msgW),
			MSG_WAIT
		)
		task.wait(CODE_COOLDOWN + 0.2)
		local okA, msgA = redeem(pc, CODE)
		flag(
			"shop_code_once_per_player",
			okA == false and msgA == MSG_ALREADY and changedBy(bw, counts(pc), {}),
			tostring(msgA),
			MSG_ALREADY
		)
		local po = newPlayer("CarTestShop_Other", true)
		local okO = redeem(po, CODE)
		flag("shop_code_other_player_can_redeem", okO == true)
		local ps = newPlayer("CarTestShop_Saved", true)
		pcall(shop.Apply, ps, { Receipts = {}, Codes = { CODE } })
		local bs = counts(ps)
		local okS, msgS = redeem(ps, CODE)
		flag(
			"shop_code_saved_code_already_redeemed",
			okS == false and msgS == MSG_ALREADY and changedBy(bs, counts(ps), {}),
			tostring(msgS),
			MSG_ALREADY
		)

		-- Section 4: Snapshot / Apply
		local pa = newPlayer("CarTestShop_Apply", true)
		local function applied(data)
			local okApply = pcall(shop.Apply, pa, data)
			return okApply, snapshot(pa)
		end
		local okNil, sNil = applied(nil)
		flag("shop_apply_nil_safe", okNil and sameArray(sNil.Receipts, {}) and sameArray(sNil.Codes, {}))
		local okMissing, sMissing = applied({})
		flag(
			"shop_apply_missing_is_empty",
			okMissing and sameArray(sMissing.Receipts, {}) and sameArray(sMissing.Codes, {})
		)
		local okBad, sBad = applied({ Receipts = "bad", Codes = 5 })
		flag("shop_apply_bad_types_empty", okBad and sameArray(sBad.Receipts, {}) and sameArray(sBad.Codes, {}))
		local okSkip, sSkip = applied({ Receipts = { "r1", 7, {}, "r2" }, Codes = { "C1", false, "C2" } })
		flag(
			"shop_apply_skips_bad_entries",
			okSkip and sameArray(sSkip.Receipts, { "r1", "r2" }) and sameSet(sSkip.Codes, { "C1", "C2" })
		)
		local pb = newPlayer("CarTestShop_RoundTrip", true)
		pcall(shop.Apply, pb, snapshot(pa))
		local sb = snapshot(pb)
		flag(
			"shop_snapshot_apply_round_trip",
			sameArray(sb.Receipts, { "r1", "r2" }) and sameSet(sb.Codes, { "C1", "C2" })
		)

		-- A rebirth keeps both
		if rebirth and type(rebirth.Rebirth) == "function" then
			local pr = newPlayer("CarTestShop_Rebirth", true)
			pr:SetAttribute("Level", 1000000)
			pr:SetAttribute("RebirthLevel", 0)
			pcall(shop.Apply, pr, { Receipts = { "cartest_rb" }, Codes = { CODE } })
			local okR, didRebirth = pcall(rebirth.Rebirth, pr)
			local sr = snapshot(pr)
			flag(
				"shop_rebirth_keeps_receipts_codes",
				okR
					and didRebirth == true
					and sameArray(sr.Receipts, { "cartest_rb" })
					and sameArray(sr.Codes, { CODE })
			)
		else
			flag("shop_rebirth_keeps_receipts_codes", false)
		end

		-- PlayerData VERSION 9 carries Receipts and Codes (injected fake store, as in the data scenario)
		local store = { data = {} }
		function store:GetAsync(key)
			return self.data[key]
		end
		function store:SetAsync(key, value)
			self.data[key] = value
		end
		function store:UpdateAsync(key, transform)
			local current = self.data[key]
			local value = transform(type(current) == "table" and table.clone(current) or current)
			if value ~= nil then
				self.data[key] = value
			end
			return value
		end
		playerData.SetStore(store)
		local pd = newPlayer("CarTestShop_Data", false)
		local loaded = playerData.Load(pd, DATA_UID) == true
		pcall(shop.Apply, pd, { Receipts = { "cartest_saved_r" }, Codes = {} })
		local okD = redeem(pd, CODE)
		local saved = playerData.Save(pd, DATA_UID) == true
		local rec = store.data[playerData.KeyFor(DATA_UID)]
		rec = type(rec) == "table" and rec or {}
		flag("shop_save_ok", loaded and okD == true and saved)
		flag("shop_save_version_9", rec.Version == DATA_VERSION, rec.Version, DATA_VERSION)
		flag("shop_save_has_receipts", sameArray(rec.Receipts, { "cartest_saved_r" }))
		flag("shop_save_has_codes", sameArray(rec.Codes, { CODE }))
		local pd2 = newPlayer("CarTestShop_Data2", false)
		playerData.Load(pd2, DATA_UID)
		local s2 = snapshot(pd2)
		flag(
			"shop_load_restores_receipts_codes",
			sameArray(s2.Receipts, { "cartest_saved_r" }) and sameArray(s2.Codes, { CODE })
		)
		store.data[playerData.KeyFor(DATA_UID_OLD)] = { Money = 1, Speed = 0, Version = 8 }
		local pd3 = newPlayer("CarTestShop_DataOld", false)
		local loadedOld = playerData.Load(pd3, DATA_UID_OLD) == true
		local s3 = snapshot(pd3)
		flag("shop_load_v8_record_empty", loadedOld and sameArray(s3.Receipts, {}) and sameArray(s3.Codes, {}))
	end)
	restore()
	flag("shop_purchases_no_error", ok, ok and 1 or tostring(err))
	return r
end

return Tests
