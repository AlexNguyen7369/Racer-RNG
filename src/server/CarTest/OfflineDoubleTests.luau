--!nonstrict
-- BRIEF (owner, 2026-10-28; design doc "Monetization" -> "Offline reward double", contract docs/OFFLINE_DOUBLE_SPEC.md
-- sections 1-4): "A 19 R$ developer product doubles this session's offline Speed reward once, through ShopService
-- receipts (SetOfflineReward, the shared grant/save/undo helper); WINDOW_SECONDS 300 placeholder."
-- Calls ShopService.ProcessReceipt with fake receipts, as shop_purchases does: it sets a made-up ProductId on
-- MonetizationConfig.OfflineDouble, replaces the save with ShopService.SetSave, shortens WINDOW_SECONDS for the
-- window case and uses the first loaded real player (ProcessReceipt finds players by UserId). Everything is put back
-- at the end, even after an error.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent
local Tests = {}

local PRODUCT_KEY = "offline_double"
local WINDOW_SECONDS = 300 -- placeholder in the spec, but the test guards the current value
local FAKE_PRODUCT = 990075301 -- made up, never real
local ABSENT_USER = 990075002
local AMOUNT = 1234.5
local LATE_AMOUNT = 321
local SHORT_WINDOW = 0.5
local WINDOW_WAIT = 1.2
local EPS = 1e-6

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

local function contains(list, value)
	return type(list) == "table" and table.find(list, value) ~= nil
end

local function near(a, b)
	return math.abs(a - b) <= EPS * math.max(1, math.abs(b))
end

function Tests.offline_double()
	local r, flag = report("offline_double")
	local monetization = module(Shared, "MonetizationConfig")
	local boostConfig = module(Shared, "BoostConfig")
	local shop = module(Server, "ShopService")
	local playerData = module(Server, "PlayerData")
	local cfg = monetization and monetization.OfflineDouble

	-- Section 1: the product
	flag("offline_double_config_exists", type(cfg) == "table")
	cfg = type(cfg) == "table" and cfg or {}
	flag("offline_double_id", cfg.Id == PRODUCT_KEY, tostring(cfg.Id), PRODUCT_KEY)
	flag("offline_double_product_id_whole", wholeNumber(cfg.ProductId, 0), cfg.ProductId)
	flag("offline_double_robux_price_whole", wholeNumber(cfg.RobuxPrice, 1), cfg.RobuxPrice)
	flag("offline_double_window_300", cfg.WINDOW_SECONDS == WINDOW_SECONDS, cfg.WINDOW_SECONDS, WINDOW_SECONDS)
	local listed = false
	for _, p in monetization and type(monetization.Products) == "table" and monetization.Products or {} do
		listed = listed or (type(p) == "table" and p.Id == PRODUCT_KEY)
	end
	flag("offline_double_not_a_shop_product", not listed)

	local apiOk = shop ~= nil
		and type(shop.ProcessReceipt) == "function"
		and type(shop.SetOfflineReward) == "function"
		and type(shop.SetSave) == "function"
		and type(shop.Snapshot) == "function"
		and type(shop.Apply) == "function"
	flag("offline_double_api_exists", apiOk)
	if not (apiOk and boostConfig and playerData and monetization and monetization.OfflineDouble) then
		flag("offline_double_dependencies_present", false)
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

	local rp = nil
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("DataLoaded") == true and not p:GetAttribute("DataFailed") then
			rp = p
			break
		end
	end
	flag("offline_double_test_player_present", rp ~= nil)
	if not rp then
		return r
	end

	local realProductId, realWindow = cfg.ProductId, cfg.WINDOW_SECONDS
	local realLoaded, realFailed = rp:GetAttribute("DataLoaded"), rp:GetAttribute("DataFailed")
	local realOpen, realDoubled = rp:GetAttribute("OfflineDoubleOpen"), rp:GetAttribute("OfflineDoubled")
	local realOfflineSpeed = rp:GetAttribute("OfflineSpeed")
	local realShop = shop.Snapshot(rp)
	local speed = playerData.Setup(rp)
	local netAdded = 0 -- Speed this test added and kept; removed again in restore (racing may add Speed meanwhile)

	local function restore()
		pcall(shop.SetSave, nil)
		cfg.ProductId = realProductId
		cfg.WINDOW_SECONDS = realWindow
		rp:SetAttribute("DataLoaded", realLoaded)
		rp:SetAttribute("DataFailed", realFailed)
		pcall(shop.Apply, rp, realShop)
		-- an open, undoubled reward comes back; otherwise none (its window or double is already spent)
		pcall(shop.SetOfflineReward, rp, realOpen == true and realOfflineSpeed or 0)
		rp:SetAttribute("OfflineDoubleOpen", realOpen)
		rp:SetAttribute("OfflineDoubled", realDoubled)
		if speed then
			speed.Value = math.max(0, speed.Value - netAdded)
		end
	end

	local ok, err = pcall(function()
		local stats = rp:FindFirstChild("leaderstats")
		local money = stats and stats:FindFirstChild("Money")
		flag("offline_double_speed_and_money_values", speed ~= nil and money ~= nil)
		cfg.ProductId = FAKE_PRODUCT
		local saveCalls, saveResult = 0, true
		shop.SetSave(function(p)
			saveCalls += 1
			return p == rp and saveResult
		end)
		local function receipt(purchaseId, userId)
			local okCall, decision = pcall(shop.ProcessReceipt, {
				PlayerId = userId or rp.UserId,
				ProductId = FAKE_PRODUCT,
				PurchaseId = purchaseId,
				CurrencySpent = 19,
				CurrencyType = Enum.CurrencyType.Robux,
				PlaceIdWherePurchased = game.PlaceId,
			})
			return okCall and decision or "error"
		end
		-- every Money / potion / Speed value, read with no yield around a receipt
		local function state()
			local s = { Money = money and money.Value or 0, Speed = speed and speed.Value or 0 }
			for _, id in allItems do
				s[id] = rp:GetAttribute("Boost_" .. id) or 0
			end
			return s
		end
		local function unchanged(a, b, speedDelta)
			if a.Money ~= b.Money or not near(b.Speed - a.Speed, speedDelta or 0) then
				return false
			end
			for _, id in allItems do
				if a[id] ~= b[id] then
					return false
				end
			end
			return true
		end
		-- runs one receipt with no yield in between, so nothing else can change Speed meanwhile
		local function run(purchaseId, userId)
			local before = state()
			local d = receipt(purchaseId, userId)
			local after = state()
			return d, before, after
		end

		-- Section 2: no reward (gain 0, negative, NaN) -> window closed, receipt refused
		for label, gain in { zero = 0, negative = -5, nan = 0 / 0, inf = math.huge } do
			shop.SetOfflineReward(rp, gain)
			flag("offline_double_no_reward_closed_" .. label, rp:GetAttribute("OfflineDoubleOpen") == false)
		end
		local dNone, b0, a0 = run("cartest_od_none")
		flag(
			"offline_double_no_reward_not_processed",
			dNone == NOT_YET and unchanged(b0, a0) and not contains(shop.Snapshot(rp).Receipts, "cartest_od_none"),
			tostring(dNone)
		)

		-- a reward opens the window
		shop.SetOfflineReward(rp, AMOUNT)
		flag("offline_double_reward_opens_window", rp:GetAttribute("OfflineDoubleOpen") == true)
		flag("offline_double_reward_not_doubled_yet", rp:GetAttribute("OfflineDoubled") == nil)

		-- Section 3.1: player absent, save not loaded, save failed
		local dAbsent, bA, aA = run("cartest_od_absent", ABSENT_USER)
		flag("offline_double_player_absent_not_processed", dAbsent == NOT_YET and unchanged(bA, aA), tostring(dAbsent))
		rp:SetAttribute("DataLoaded", false)
		local dNotLoaded, bL, aL = run("cartest_od_notloaded")
		rp:SetAttribute("DataLoaded", realLoaded)
		flag(
			"offline_double_not_loaded_not_processed",
			dNotLoaded == NOT_YET and unchanged(bL, aL),
			tostring(dNotLoaded)
		)
		rp:SetAttribute("DataFailed", true)
		local dFailed, bF, aF = run("cartest_od_datafailed")
		rp:SetAttribute("DataFailed", realFailed)
		flag("offline_double_data_failed_not_processed", dFailed == NOT_YET and unchanged(bF, aF), tostring(dFailed))
		flag("offline_double_refused_never_saves", saveCalls == 0, saveCalls, 0)

		-- Section 3.5: a failed save undoes the grant
		saveResult = false
		local dSaveFail, bS, aS = run("cartest_od_savefail")
		saveResult = true
		flag("offline_double_save_failure_not_processed", dSaveFail == NOT_YET, tostring(dSaveFail))
		flag("offline_double_save_failure_undoes_speed", unchanged(bS, aS), aS.Speed - bS.Speed, 0)
		flag(
			"offline_double_save_failure_drops_purchase_id",
			not contains(shop.Snapshot(rp).Receipts, "cartest_od_savefail")
		)
		flag("offline_double_save_failure_clears_doubled", rp:GetAttribute("OfflineDoubled") == nil)
		flag("offline_double_save_failure_window_still_open", rp:GetAttribute("OfflineDoubleOpen") == true)

		-- Section 3.5: the grant, exactly once
		saveCalls = 0
		local d1, b1, a1 = run("cartest_od_a")
		netAdded += a1.Speed - b1.Speed
		flag("offline_double_granted", d1 == GRANTED, tostring(d1))
		flag("offline_double_adds_offline_amount", near(a1.Speed - b1.Speed, AMOUNT), a1.Speed - b1.Speed, AMOUNT)
		flag("offline_double_money_potions_unchanged", unchanged(b1, a1, AMOUNT))
		flag("offline_double_saves_once", saveCalls == 1, saveCalls, 1)
		flag("offline_double_records_purchase_id", contains(shop.Snapshot(rp).Receipts, "cartest_od_a"))
		flag("offline_double_closes_window", rp:GetAttribute("OfflineDoubleOpen") == false)
		flag(
			"offline_double_sets_doubled_attribute",
			rp:GetAttribute("OfflineDoubled") == AMOUNT,
			rp:GetAttribute("OfflineDoubled"),
			AMOUNT
		)

		-- Section 3.3: the same PurchaseId again -> granted, nothing added
		local d2, b2, a2 = run("cartest_od_a")
		flag("offline_double_duplicate_granted_once", d2 == GRANTED and unchanged(b2, a2), tostring(d2))

		-- Section 3.4: a second purchase for the same reward -> NotProcessedYet, nothing added
		saveCalls = 0
		local d3, b3, a3 = run("cartest_od_b")
		flag(
			"offline_double_second_purchase_not_processed",
			d3 == NOT_YET and unchanged(b3, a3) and not contains(shop.Snapshot(rp).Receipts, "cartest_od_b"),
			tostring(d3)
		)
		flag("offline_double_second_purchase_no_save", saveCalls == 0, saveCalls, 0)

		-- Section 4: the window closes after WINDOW_SECONDS (shortened here), a late receipt still grants
		cfg.WINDOW_SECONDS = SHORT_WINDOW
		shop.SetOfflineReward(rp, LATE_AMOUNT)
		cfg.WINDOW_SECONDS = realWindow
		flag("offline_double_late_window_opens", rp:GetAttribute("OfflineDoubleOpen") == true)
		task.wait(WINDOW_WAIT)
		flag("offline_double_window_closes", rp:GetAttribute("OfflineDoubleOpen") == false)
		local d4, b4, a4 = run("cartest_od_late")
		netAdded += a4.Speed - b4.Speed
		flag("offline_double_late_receipt_granted", d4 == GRANTED, tostring(d4))
		flag(
			"offline_double_late_receipt_adds_amount",
			unchanged(b4, a4, LATE_AMOUNT),
			a4.Speed - b4.Speed,
			LATE_AMOUNT
		)
		flag("offline_double_late_window_stays_closed", rp:GetAttribute("OfflineDoubleOpen") == false)
	end)
	restore()
	flag("offline_double_no_error", ok, ok and 1 or tostring(err))
	return r
end

return Tests
