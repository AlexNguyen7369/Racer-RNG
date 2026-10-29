--!nonstrict
-- BRIEF: Workshop phase 2: exact 25% offline rate, eight-hour cap,
-- no Speed cap, guarded next-level purchase, OfflineAt persistence and one-time credit.
-- Owner, 2026-10-13 (design doc "Core stat model", WORKSHOP_SPEC section 4): no diminishing term. Offline Speed =
-- Workshop.Rate x OFFLINE_FRACTION x min(seconds, OFFLINE_CAP); the stat itself never reduces it and, owner
-- 2026-10-20, the Speed stat has no cap (MAX_STAT is only a test reference stat, it clamps nothing). (Was: the integral of rate / (1 + stat / GAIN_SOFT).)
-- Weather: rain luck 2, night NPC speed 1.25/money 2, gold money 3, expiry,
-- actual rolls/payouts and Event-only catalog eligibility. No owner prices assumed.
-- Weather, owner 2026-10-13 (design doc "Weather events", WEATHER_EVENTS_SPEC "Schedule"): a weather every
-- 15 minutes start to start for 3 minutes, five weathers picked with equal chance (clear, rain, night, gold,
-- aurora), clear changes nothing, aurora luck 1.5 / money 1.5, WeatherConfig.Describe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent
local Tests = {}

local function module(parent, name)
	local source = parent:FindFirstChild(name)
	if not source then
		return nil
	end
	local ok, value = pcall(require, source)
	return ok and value or nil
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

local function near(a, b, tolerance)
	return type(a) == "number" and a == a and math.abs(a - b) <= (tolerance or 1e-6)
end

-- Independent oracle (owner, 2026-10-13): 25% of the workshop rate x the time capped at eight hours. The stat does
-- not reduce it and nothing clamps it to a max stat (owner 2026-10-20: no Speed cap). This deliberately never calls Workshop.Rate/OfflineGain.
local function integrated(_stat, speedMulti, levelMulti, workshopMulti, seconds, config)
	local a = 0.25 * config.BASE_RATE * speedMulti * levelMulti * workshopMulti
	local t = math.clamp(seconds, 0, 8 * 60 * 60)
	return a * t
end

function Tests.workshop_offline()
	local r, flag = report("workshop_offline")
	local workshop = module(Shared, "Workshop")
	local config = module(Shared, "WorkshopConfig")
	local race = module(Shared, "RaceConfig")
	local api = workshop and config and race and type(workshop.OfflineGain) == "function"
	flag("offline_gain_api_exists", api == true)
	if not api then
		return r
	end
	local function exact(label, stat, sm, level, wm, seconds)
		local want = integrated(stat, sm, config.Levels[level].Multi, wm, seconds, config)
		local ok, got = pcall(workshop.OfflineGain, stat, sm, level, wm, seconds)
		-- relative tolerance: uncapped gains can reach 1e12+, where 1e-6 absolute is below double precision
		flag(
			label,
			ok and near(got, want, math.max(1e-6, math.abs(want) * 1e-9)),
			type(got) == "number" and got or -1,
			want
		)
		return got, want
	end
	exact("offline_exact_quarter_rate_from_zero", 0, 1, 1, 1, 3600)
	exact("offline_exact_existing_stat_not_reduced", 2000, 3, 1, 2, 7200)
	exact("offline_eight_hour_cap", 1234, 2, 1, 3, 8 * 3600)
	exact("offline_beyond_eight_hours_same_gain", 1234, 2, 1, 3, 48 * 3600)
	exact("offline_zero_seconds", 100, 2, 1, 3, 0)
	exact("offline_negative_seconds", 100, 2, 1, 3, -1)
	exact("offline_zero_speed_multi", 100, 0, 1, 3, 3600)
	exact("offline_zero_workshop_multi", 100, 2, 1, 0, 3600)
	-- Owner 2026-10-20: no Speed cap. At and above the old 1e9 reference the full gain is still paid.
	exact("offline_at_max_stat_full_gain", race.MAX_STAT, 2, 1, 3, 8 * 3600)
	exact("offline_crossing_max_stat_not_clamped", race.MAX_STAT - 0.25, 1e8, 1, 2, 8 * 3600)
	exact("offline_above_1e12_full_gain", 1e12, 2, 1, 3, 8 * 3600)
	exact("offline_above_1e15_full_gain", 1e15, 2, 1, 3, 3600)
	do
		local ok, got = pcall(workshop.OfflineGain, race.MAX_STAT - 0.25, 1e8, 1, 2, 8 * 3600)
		flag("offline_gain_can_pass_max_stat", ok and type(got) == "number" and got > 0.25, ok and got or -1, 0.25)
		for _, bad in { { "inf", math.huge }, { "nan", 0 / 0 }, { "negative", -1 } } do
			local okBad, gotBad = pcall(workshop.OfflineGain, bad[2], 2, 1, 3, 3600)
			flag("offline_bad_stat_no_gain_" .. bad[1], okBad and gotBad == 0, okBad and gotBad or -1, 0)
		end
	end
	-- Owner, 2026-10-13: the rate x the capped time IS the rule (was: an integral that paid less).
	local got = exact("offline_is_rate_times_capped_time", 0, 10, 1, 5, 8 * 3600)
	local linear = 0.25 * config.BASE_RATE * 10 * 5 * 8 * 3600
	flag("offline_no_diminishing_from_zero", near(got, linear), type(got) == "number" and got or -1, linear)
	-- The public contract: OfflineGain = Rate x OFFLINE_FRACTION x clamp(seconds, 0, OFFLINE_CAP).
	local contract = type(workshop.Rate) == "function"
		and type(config.OFFLINE_FRACTION) == "number"
		and type(config.OFFLINE_CAP) == "number"
	for _, case in { { 0, 3600 }, { 2000, 3600 }, { 1e6, 7200 }, { 1e6, 48 * 3600 }, { 5e8, 100 } } do
		local stat, seconds = case[1], case[2]
		local okWant, wantGain = pcall(function()
			return workshop.Rate(stat, 2, 1, 3) * config.OFFLINE_FRACTION * math.clamp(seconds, 0, config.OFFLINE_CAP)
		end)
		local okGot, gotGain = pcall(workshop.OfflineGain, stat, 2, 1, 3, seconds)
		contract = contract and okWant and okGot and near(gotGain, wantGain) and wantGain > 0
	end
	flag("offline_equals_rate_times_fraction_times_time", contract)
	local same = true
	local atZero = workshop.OfflineGain(0, 2, 1, 3, 3600)
	for _, stat in { 2000, 1e6, 5e8, 1e9, 1e12, 1e15 } do
		same = same and atZero > 0 and workshop.OfflineGain(stat, 2, 1, 3, 3600) == atZero
	end
	flag("offline_same_gain_at_any_stat", same, type(atZero) == "number" and atZero or -1, 0.25 * 2 * 3 * 3600)
	local first = workshop.OfflineGain(500, 2, 1, 3, 1800)
	local second = workshop.OfflineGain(500 + first, 2, 1, 3, 1800)
	local whole = workshop.OfflineGain(500, 2, 1, 3, 3600)
	flag("offline_gain_composes", near(first + second, whole))
	for level, entry in config.Levels do
		exact("offline_configured_level_" .. level, 500, 2, level, 3, 3600)
		flag("offline_level_multi_valid_" .. level, type(entry.Multi) == "number" and entry.Multi > 0)
	end
	for i, args in
		{
			{ -1, 1, 1, 1, 10 },
			{ 0 / 0, 1, 1, 1, 10 },
			{ 0, math.huge, 1, 1, 10 },
			{ 0, -1, 1, 1, 10 },
			{ 0, 1, 1, -1, 10 },
			{ 0, 1, 1, 1, 0 / 0 },
			{ 0, 1, 1, 1, math.huge },
			{ 0, 1, 1, 1, "bad" },
		}
	do
		local ok, gain = pcall(workshop.OfflineGain, table.unpack(args))
		flag("offline_invalid_input_" .. i, ok and gain == 0)
	end
	return r
end

local function fake(name, data, gacha)
	local p = Instance.new("Folder")
	p.Name = "CarTestPhase2" .. name
	p:SetAttribute("UserId", -74001)
	p.Parent = Workspace
	data.Setup(p)
	gacha.Setup(p)
	return p
end

function Tests.workshop_phase2()
	local r, flag = report("workshop_phase2")
	local service = module(Server, "WorkshopService")
	local data = module(Server, "PlayerData")
	local gacha = module(Server, "GachaService")
	local carService = module(Server, "CarService")
	local workshop = module(Shared, "Workshop")
	local config = module(Shared, "WorkshopConfig")
	local race = module(Shared, "RaceConfig")
	local api = service and data and gacha and carService and config and race
	flag("workshop_phase2_dependencies", api ~= nil)
	if not api then
		return r
	end
	flag("workshop_buy_upgrade_api_exists", type(service.BuyUpgrade) == "function")
	flag("offline_clock_api_exists", type(data.SetClock) == "function")
	local players = {}
	local function player(name)
		local p = fake(name, data, gacha)
		table.insert(players, p)
		return p
	end
	local oldLevels, oldMax = config.Levels, config.MAX_LEVEL
	local oldCharacter = carService.GetCharacter
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.Parent = character
	character.Parent = Workspace
	local buyer
	local ownedPlot, originalOwner
	local ok, err = pcall(function()
		if type(service.BuyUpgrade) == "function" then
			-- Synthetic uneven prices catch charging current tier, double debits and stale quotes.
			-- They are test fixtures, never a requirement on owner-approved prices.
			config.Levels = { { Multi = 1, Price = 0 }, { Multi = 3, Price = 137 }, { Multi = 7, Price = 419 } }
			config.MAX_LEVEL = #config.Levels
			buyer = player("Buyer")
			buyer:SetAttribute("DataLoaded", true)
			buyer:SetAttribute("WorkshopLevel", 1)
			local index = service.Assign(buyer)
			local folder = Workspace:FindFirstChild("Workshops")
			local plot = folder and folder:FindFirstChild("Plot_" .. tostring(index))
			local pad = plot and plot:FindFirstChild("UpgradePad", true)
			flag("upgrade_fixture_has_owned_plot_and_pad", index > 0 and pad ~= nil)
			if pad then
				root.CFrame = pad.CFrame + Vector3.new(0, 3, 0)
				carService.GetCharacter = function(p)
					return p == buyer and character or oldCharacter(p)
				end
				local money = buyer.leaderstats.Money
				money.Value = 10000
				local function rejection(label, change, restore)
					local balance, level = money.Value, buyer:GetAttribute("WorkshopLevel")
					change()
					local accepted = service.BuyUpgrade(buyer)
					flag(
						label,
						not accepted and money.Value == balance and buyer:GetAttribute("WorkshopLevel") == level
					)
					restore()
				end
				rejection("upgrade_reject_unloaded", function()
					buyer:SetAttribute("DataLoaded", false)
				end, function()
					buyer:SetAttribute("DataLoaded", true)
				end)
				rejection("upgrade_reject_failed_load", function()
					buyer:SetAttribute("DataFailed", true)
				end, function()
					buyer:SetAttribute("DataFailed", nil)
				end)
				rejection("upgrade_reject_dead", function()
					humanoid.Health = 0
				end, function()
					humanoid.Health = humanoid.MaxHealth
				end)
				local close = root.CFrame
				rejection("upgrade_reject_far", function()
					root.CFrame = close + Vector3.new(1000, 0, 0)
				end, function()
					root.CFrame = close
				end)
				local owner = plot:GetAttribute("Owner")
				ownedPlot, originalOwner = plot, owner
				rejection("upgrade_reject_forged_owner", function()
					plot:SetAttribute("Owner", owner - 1)
				end, function()
					plot:SetAttribute("Owner", owner)
				end)
				money.Value = config.Levels[2].Price - 1
				rejection("upgrade_reject_insufficient", function() end, function() end)
				money.Value = config.Levels[2].Price
				local accepted = service.BuyUpgrade(buyer)
				flag(
					"upgrade_exact_balance_buys_next_level_once",
					accepted == true and money.Value == 0 and buyer:GetAttribute("WorkshopLevel") == 2
				)
				money.Value = config.Levels[3].Price
				accepted = service.BuyUpgrade(buyer)
				flag(
					"upgrade_next_price_changes_with_level",
					accepted == true and money.Value == 0 and buyer:GetAttribute("WorkshopLevel") == 3
				)
				money.Value = 10000
				rejection("upgrade_reject_max_level", function() end, function() end)
				service.Release(buyer)
				buyer:SetAttribute("WorkshopLevel", 1)
				rejection("upgrade_reject_without_owned_plot", function() end, function() end)
			end
		end
		config.Levels, config.MAX_LEVEL = oldLevels, oldMax
		local at = os.time()
		local clock = at
		if type(data.SetClock) == "function" then
			data.SetClock(function()
				return clock
			end)
		end
		local initial = { Speed = 2500, Money = 41, WorkshopLevel = 1, OfflineAt = at - 3600 }
		local saved
		local store = { claims = 0 }
		function store:GetAsync(_key)
			return initial
		end
		function store:SetAsync(_key, payload)
			saved = payload
			initial = payload
		end
		-- docs/SAVE_SPEC.md section 1 (VERSION 8): Load and Save are one UpdateAsync each. It returns the new value
		-- and writes nothing (returning nil, like the real DataStore) when the transform returns nil.
		function store:UpdateAsync(_key, transform)
			self.claims += 1
			local updated = transform(table.clone(initial))
			if updated == nil then
				return nil
			end
			saved = updated
			initial = updated
			return updated
		end
		data.SetStore(store)
		local p = player("OfflineLoad")
		gacha.Apply(p, initial)
		local offlineGain =
			integrated(initial.Speed, gacha.SpeedMulti(p), config.Levels[1].Multi, gacha.WorkshopMulti(p), 3600, config)
		local want = initial.Speed + offlineGain
		-- Owner, 2026-10-12 (docs/SAVE_SPEC.md section 3): offline earnings are Speed ONLY. Money after the load is
		-- the saved Money exactly (was: + 10% of the Speed credit).
		local wantMoney = 41
		flag("offline_load_succeeds", data.Load(p, 74002, at) == true)
		flag("offline_load_credits_rate_times_time", near(p.BaseSpeed.Value, want, 0.002), p.BaseSpeed.Value, want)
		flag(
			"offline_claim_persisted_before_any_save",
			store.claims == 1
				and near(initial.Speed, want, 0.002)
				and initial.OfflineAt == at
				and initial.WorkshopLevel == 1
		)
		flag(
			"offline_load_credits_no_money",
			p.leaderstats.Money.Value == wantMoney,
			p.leaderstats.Money.Value,
			wantMoney
		)
		flag(
			"offline_claim_leaves_saved_money",
			initial.Money == wantMoney,
			type(initial.Money) == "number" and initial.Money or -1,
			wantMoney
		)
		flag("offline_money_attribute_not_set", p:GetAttribute("OfflineMoney") == nil)
		flag(
			"offline_money_api_removed",
			workshop ~= nil and workshop.OfflineMoney == nil and config.OFFLINE_MONEY_FRACTION == nil
		)
		flag(
			"offline_welcome_attributes",
			near(p:GetAttribute("OfflineSpeed"), want - 2500, 0.002) and p:GetAttribute("OfflineSeconds") == 3600
		)
		local reconnect = player("ReconnectBeforeSave")
		data.Load(reconnect, 74002)
		flag(
			"offline_no_replay_on_reconnect_without_save",
			near(reconnect.BaseSpeed.Value, want, 0.002) and reconnect:GetAttribute("OfflineSpeed") == 0
		)
		-- GetAsync can race another session's claim: the callback must use the
		-- latest persisted record, not a gain computed from the stale read.
		local claimed = table.clone(initial)
		local stale = table.clone(initial)
		stale.Speed, stale.OfflineAt = 2500, at - 3600
		local racedStore = {}
		function racedStore:GetAsync(_key)
			return stale
		end
		function racedStore:UpdateAsync(_key, transform)
			local updated = transform(table.clone(claimed))
			if updated ~= nil then
				claimed = updated
			end
			return updated
		end
		data.SetStore(racedStore)
		local raced = player("ConcurrentClaim")
		local raceLoaded = data.Load(raced, 74002)
		flag(
			"offline_stale_read_cannot_replay_claim",
			raceLoaded == true
					and near(raced.BaseSpeed.Value, want, 0.002)
					and raced:GetAttribute("OfflineSpeed") == 0
					and raced.leaderstats.Money.Value == wantMoney
				or raceLoaded == false
					and raced:GetAttribute("DataFailed") == true
					and raced:GetAttribute("DataLoaded") ~= true
					and raced.BaseSpeed.Value <= 2500
		)
		data.SetStore(store)
		-- Include a subsequent live gain: reloading must neither replay offline credit nor reset live progress.
		data.AddSpeed(p, 7)
		local once = p.BaseSpeed.Value
		clock = at + 60
		local claimsBefore = store.claims
		data.Load(p, 74002)
		flag("offline_repeated_load_preserves_once_credit_and_live_gain", near(p.BaseSpeed.Value, once, 0.002))
		flag("offline_repeated_load_no_store_claim", store.claims == claimsBefore)
		flag("offline_save_succeeds", data.Save(p, 74002) == true)
		flag(
			"offline_at_saved_unix_timestamp",
			saved ~= nil and type(saved.OfflineAt) == "number" and saved.OfflineAt == clock and saved.Version == 12
		)
		local afterSave = player("ReconnectAfterSave")
		data.Load(afterSave, 74002)
		flag(
			"offline_save_does_not_replay_previous_absence",
			near(afterSave.BaseSpeed.Value, once, 0.002)
				and afterSave:GetAttribute("OfflineSpeed") == 0
				and afterSave.leaderstats.Money.Value == wantMoney
		)
		clock = at
		for _, case in { { "Legacy", nil }, { "Future", at + 3600 }, { "Malformed", "bad" } } do
			initial = { Speed = 99, WorkshopLevel = 1, OfflineAt = case[2] }
			local legacy = player(case[1])
			data.Load(legacy, 74003, at)
			flag("offline_no_credit_" .. string.lower(case[1]), legacy.BaseSpeed.Value == 99)
		end
		for _, mode in { "missing_atomic_api", "failed_atomic_claim" } do
			initial = { Speed = 99, Money = 41, WorkshopLevel = 1, OfflineAt = at - 3600 }
			local badStore = {}
			function badStore:GetAsync(_key)
				return initial
			end
			function badStore:SetAsync(_key, _payload)
				error("must not save after failed claim")
			end
			if mode == "failed_atomic_claim" then
				function badStore:UpdateAsync(_key, _transform)
					error("injected atomic failure")
				end
			end
			data.SetStore(badStore)
			local failedClaim = player(mode)
			local loaded = data.Load(failedClaim, 74005)
			flag(
				"offline_reject_" .. mode,
				loaded == false
					and failedClaim:GetAttribute("DataFailed") == true
					and failedClaim:GetAttribute("DataLoaded") ~= true
					and failedClaim.BaseSpeed.Value <= 99
					and data.Save(failedClaim, 74005) == false
					and initial.OfflineAt == at - 3600
			)
		end
		data.SetStore(store)
		function store:GetAsync(_key)
			error("injected load failure")
		end
		function store:UpdateAsync(_key, _transform) -- VERSION 8: the load is this call
			error("injected load failure")
		end
		local failed = player("Failed")
		flag(
			"offline_failed_load_no_credit_or_save",
			data.Load(failed, 74004, at) == false and failed.BaseSpeed.Value == 0 and data.Save(failed, 74004) == false
		)
	end)
	config.Levels, config.MAX_LEVEL = oldLevels, oldMax
	carService.GetCharacter = oldCharacter
	-- Undo a forged Owner left by a failure mid-rejection, but ONLY while the buyer still holds the plot: once the
	-- scenario released it the service already wrote Owner 0 and the EMPTY sign, and writing the old owner back
	-- would leak the plot to the fake player (a later `workshop` run then sees one owned plot too many).
	if ownedPlot and ownedPlot.Parent and buyer and service.PlotOf(buyer) > 0 then
		ownedPlot:SetAttribute("Owner", originalOwner)
	end
	data.SetStore(nil)
	if type(data.SetClock) == "function" then
		data.SetClock(nil)
	end
	-- Every plot this scenario assigned goes back through the service's real release path (frees owners/plotOf,
	-- removes the workshop, Owner 0, EMPTY sign), whether or not the body failed.
	for _, p in players do
		pcall(service.Release, p)
		p:Destroy()
	end
	character:Destroy()
	flag("workshop_phase2_no_runtime_error", ok, nil, ok and 1 or tostring(err))
	-- Isolation: after the scenario only real players own plots; every other plot is EMPTY with no workshop.
	local realIds = {}
	for _, plr in game:GetService("Players"):GetPlayers() do
		realIds[plr.UserId] = true
	end
	local folder = Workspace:FindFirstChild("Workshops")
	local leaked = 0
	for i = 1, config.PLOT_COUNT do
		local plot = folder and folder:FindFirstChild("Plot_" .. i)
		if plot then
			local owner = plot:GetAttribute("Owner")
			local base = plot:FindFirstChild("Base")
			local sign = base and base:FindFirstChild("Sign")
			local text = sign and sign:FindFirstChild("Text")
			local empty = owner == nil or owner == 0
			if empty then
				if plot:FindFirstChild("Workshop") ~= nil or (text and text.Text ~= config.EMPTY_TEXT) then
					leaked += 1
				end
			elseif not realIds[owner] then
				leaked += 1
			end
		end
	end
	local fakeHolds = 0
	for _, p in players do
		if service.PlotOf(p) > 0 then
			fakeHolds += 1
		end
	end
	flag("workshop_phase2_releases_every_plot", folder ~= nil and leaked == 0 and fakeHolds == 0, leaked + fakeHolds, 0)
	return r
end

function Tests.weather()
	local r, flag = report("weather")
	local weather = module(Server, "WeatherService")
	local config = module(Shared, "WeatherConfig")
	local data = module(Server, "PlayerData")
	local gacha = module(Server, "GachaService")
	local money = module(Server, "MoneyService")
	local catalog = module(Shared, "CarCatalog")
	local gachaConfig = module(Shared, "GachaConfig")
	local api = weather
		and config
		and data
		and gacha
		and money
		and catalog
		and gachaConfig
		and type(weather.Current) == "function"
		and type(weather.SetEvent) == "function"
		and type(weather.Tick) == "function"
		and type(weather.Multipliers) == "function"
	flag("weather_api_exists", api == true)
	if not api then
		return r
	end
	local p = fake("Weather", data, gacha)
	local pad = Instance.new("Part")
	local resources = {}
	local extraPlayers = {}
	pad:SetAttribute("Cash", 113)
	game:GetService("CollectionService"):AddTag(pad, "WinPad")
	local ok, err = pcall(function()
		local at = Workspace:GetServerTimeNow()
		weather.SetEvent("", at)
		local baseLuck, baseMoney = gacha.Luck(p), gacha.MoneyMulti(p)
		-- Spec table (owner, 2026-10-13): Luck, Money, NPC speed. "clear" is a real pick that changes nothing.
		local expected = {
			clear = { 1, 1, 1 },
			rain = { 2, 1, 1 },
			night = { 1, 2, 1.25 },
			gold = { 1, 3, 1 },
			aurora = { 1.5, 1.5, 1 },
		}
		-- "" is the state between weathers; "clear" is now a weather id, so "" is labelled "none".
		local function label(id)
			return id == "" and "none" or id
		end
		for _, id in { "clear", "rain", "night", "gold", "aurora" } do
			local values = expected[id]
			flag("weather_set_" .. id, weather.SetEvent(id, at) == true)
			local current, expiry = weather.Current()
			flag("weather_current_" .. id, current == id and near(expiry, at + config.DURATION))
			flag(
				"weather_replicated_" .. id,
				ReplicatedStorage:GetAttribute("WeatherEvent") == id
					and near(ReplicatedStorage:GetAttribute("WeatherEndsAt"), expiry)
			)
			local mult = weather.Multipliers()
			flag(
				"weather_exact_multipliers_" .. id,
				mult.Luck == values[1] and mult.Money == values[2] and mult.NpcSpeed == values[3]
			)
			flag("weather_reaches_gacha_luck_" .. id, near(gacha.Luck(p), baseLuck * values[1]))
			flag("weather_reaches_money_multi_" .. id, near(gacha.MoneyMulti(p), baseMoney * values[2]))
			local quote = math.floor(113 * baseMoney * values[2])
			flag("weather_reaches_banked_quote_" .. id, money.Quote(p, pad) == quote)
			local balance = p.leaderstats.Money.Value
			flag(
				"weather_reaches_paid_collect_" .. id,
				money.Collect(p, pad, at) == quote and p.leaderstats.Money.Value == balance + quote
			)
			flag(
				"weather_collect_still_once_" .. id,
				money.Collect(p, pad, at) == 0 and p.leaderstats.Money.Value == balance + quote
			)
			weather.Tick(expiry - 0.001)
			flag("weather_active_until_expiry_" .. id, weather.Current() == id)
			weather.Tick(expiry)
			local clear, ends = weather.Current()
			mult = weather.Multipliers()
			flag(
				"weather_expires_exactly_" .. id,
				clear == "" and ends == 0 and mult.Luck == 1 and mult.Money == 1 and mult.NpcSpeed == 1
			)
			flag(
				"weather_expiry_restores_consumers_" .. id,
				near(gacha.Luck(p), baseLuck)
					and near(gacha.MoneyMulti(p), baseMoney)
					and money.Quote(p, pad) == math.floor(113 * baseMoney)
			)
			at += config.DURATION + 10
		end
		weather.SetEvent("rain", at)
		local id, ends = weather.Current()
		flag("weather_invalid_event_rejected", weather.SetEvent("invalid", at) == false and weather.Current() == id)
		flag("weather_invalid_time_rejected", weather.SetEvent("night", 0 / 0) == false)
		local unchanged, unchangedEnds = weather.Current()
		flag("weather_invalid_request_preserves_expiry", unchanged == id and unchangedEnds == ends)
		local races = module(Server, "RaceService")
		local factory = module(Shared, "CarFactory")
		local carConfig = module(Shared, "CarConfig")
		local route = races and races.GetRoute()
		flag("weather_npc_live_route_available", route ~= nil and factory ~= nil and carConfig ~= nil)
		if route and factory and carConfig then
			for _, event in { "", "night", "clear", "aurora" } do
				weather.SetEvent(event, at)
				local car = factory.build(carConfig)
				car.Parent = Workspace
				table.insert(resources, car)
				local start
				local run = races.NewRun(car, route, p, {
					Npc = true,
					OnRaceEvent = function(ev)
						if ev.Type == "Start" then
							start = ev
						end
					end,
				})
				table.insert(resources, run)
				local wantSpeed = route.Tracks[1].Npc.Config.Speed * (event == "" and 1 or expected[event][3])
				flag("weather_reaches_npc_track_start_" .. label(event), start ~= nil and near(start.Speed, wantSpeed))
				run:Destroy()
				resources[#resources] = nil
				car:Destroy()
				resources[#resources] = nil
			end
		end
		-- A deterministic first rare-car threshold demonstrates that Roll consumes the doubled luck.
		local target
		for _, spec in catalog.Rollable() do
			if not spec.Event and spec.Chance and spec.Chance > 2 * baseLuck then
				target = spec
				break
			end
		end
		flag("weather_roll_discriminating_catalog_fixture", target ~= nil)
		if target then
			-- Events filtered before RNG sampling may shift indices: supply by active eligible order.
			local function sample(event)
				local eligible = {}
				for _, spec in catalog.Rollable() do
					if spec.Chance and (not spec.Event or spec.Event == event) then
						table.insert(eligible, spec)
					end
				end
				local index = 0
				return {
					NextNumber = function()
						index += 1
						return eligible[index] == target and 1.5 * baseLuck / target.Chance or 0.999999
					end,
				}
			end
			weather.SetEvent("", at)
			p:SetAttribute("TurboCount", 0)
			local dry = gacha.Roll(p, sample(""))
			weather.SetEvent("rain", at)
			p:SetAttribute("TurboCount", 0)
			local wet = gacha.Roll(p, sample("rain"))
			flag("weather_rain_changes_actual_roll_threshold", dry ~= target.Id and wet == target.Id)
		end
		-- BRIEF (owner, 2026-10-13; design doc "Weather events": "Luck from an event is free, but the displayed
		-- odds must still update while it is active"; WEATHER_EVENTS_SPEC "Displayed odds"): Roll returns the
		-- roll's luck as its 6th value, GachaService.Luck(player) at that moment, WITHOUT the turbo multi.
		do
			local function rollLuck(event, turboCount)
				weather.SetEvent(event, at)
				p:SetAttribute("TurboCount", turboCount)
				local want = gacha.Luck(p)
				local _, _, turboMulti, _, _, luck = gacha.Roll(p, {
					NextNumber = function()
						return 0.999999
					end,
				})
				return luck, want, turboMulti
			end
			local clearLuck, clearWant = rollLuck("", 0)
			flag(
				"weather_roll_luck_none",
				type(clearLuck) == "number" and clearLuck == clearWant and near(clearLuck, baseLuck),
				type(clearLuck) == "number" and clearLuck or -1,
				baseLuck
			)
			-- x2 is exact in floating point, so "exactly 2x" is an equality, not a tolerance.
			-- x1.5 (aurora) may differ by one rounding step depending on the product order, so it gets a tolerance.
			for _, event in { "clear", "rain", "night", "gold", "aurora" } do
				local luck, want = rollLuck(event, 0)
				local factor = expected[event][1]
				local limit = factor * baseLuck
				flag(
					"weather_roll_luck_" .. event,
					type(luck) == "number"
						and luck == want
						and (luck == factor * clearLuck or event == "aurora" and near(luck, factor * clearLuck, 1e-9)),
					type(luck) == "number" and luck or -1,
					limit
				)
			end
			-- TurboCount 9 makes this the turbo roll (x10 with no Turbo tier): the multi is the 3rd value, never in luck.
			local turboLuck, turboWant, turboMulti = rollLuck("rain", 9)
			flag(
				"weather_roll_luck_excludes_turbo",
				type(turboMulti) == "number"
					and turboMulti > 1
					and type(turboLuck) == "number"
					and turboLuck == turboWant
					and near(turboLuck, 2 * baseLuck),
				type(turboLuck) == "number" and turboLuck or -1,
				2 * baseLuck
			)
			local restoredLuck, restoredWant = rollLuck("", 0)
			flag(
				"weather_roll_luck_restored_after_clear",
				type(restoredLuck) == "number" and restoredLuck == restoredWant and restoredLuck == clearLuck,
				type(restoredLuck) == "number" and restoredLuck or -1,
				baseLuck
			)
			p:SetAttribute("TurboCount", 0)
		end
		-- Spec: "Three permanent catalog keys are available only during their matching event (Clear and Aurora
		-- have none)."
		for _, event in { "clear", "aurora" } do
			local count = 0
			for _, spec in catalog.All() do
				if spec.Event == event then
					count += 1
				end
			end
			flag("weather_no_event_only_car_" .. event, count == 0, count, 0)
		end
		for _, event in { "rain", "night", "gold" } do
			local eventCar
			for _, spec in catalog.All() do
				if spec.Event == event then
					eventCar = spec
					break
				end
			end
			flag("weather_event_only_car_exists_" .. event, eventCar ~= nil)
			if eventCar then
				-- Own model since the car art redesign (owner 2026-10-20, docs/CAR_REDESIGN_SPEC.md section 5).
				local models = ReplicatedStorage:FindFirstChild("CarModels")
				local template = models and models:FindFirstChild(eventCar.Id)
				flag(
					"weather_variant_own_model_" .. event,
					eventCar.Model == eventCar.Id and template ~= nil and template:IsA("Model")
				)
				for _, active in { "", "rain", "night", "gold", "clear", "aurora" } do
					-- the state must really be `active`: a refused SetEvent would leave the previous weather on
					local set = weather.SetEvent(active, at) == true and weather.Current() == active
					local eligible = {}
					for _, spec in catalog.Rollable() do
						if spec.Chance and (not spec.Event or spec.Event == active) then
							table.insert(eligible, spec)
						end
					end
					local index = 0
					local rng = {
						NextNumber = function()
							index += 1
							-- Inactive: target the event car in the UNFILTERED order,
							-- proving a missing filter can actually select it.
							local order = active == event and eligible or catalog.Rollable()
							return order[index] == eventCar and 0 or 0.999999
						end,
					}
					p:SetAttribute("TurboCount", 0)
					local rolled = gacha.Roll(p, rng)
					flag(
						"weather_event_car_eligibility_" .. event .. "_" .. label(active),
						set and (active == event and rolled == eventCar.Id or active ~= event and rolled ~= eventCar.Id)
					)
				end
			end
		end
		-- Every current car gets a deterministic boundary test in EVERY weather
		-- state, including variants beyond the first car of each event.
		local catchAll
		for _, spec in catalog.All() do
			if spec.Chance == nil then
				catchAll = spec.Id
			end
		end
		for _, active in { "", "rain", "night", "gold", "clear", "aurora" } do
			local eligible = {}
			for _, spec in catalog.Rollable() do
				if spec.Chance and (spec.Event == nil or spec.Event == active) then
					table.insert(eligible, spec)
				end
			end
			local draws = 0
			local fallback = gachaConfig.Roll({
				NextNumber = function()
					draws += 1
					return 1
				end,
			}, 1, active)
			flag(
				"weather_filters_before_rng_" .. label(active),
				draws == #eligible and fallback == catchAll,
				draws,
				#eligible
			)
			for _, candidate in catalog.All() do
				local allowed = candidate.Event == nil or candidate.Event == active
				if candidate.Chance then
					for _, boundary in { "below", "equal" } do
						local index = 0
						local rng = {
							NextNumber = function()
								index += 1
								local order = allowed and eligible or catalog.Rollable()
								return order[index] == candidate
										and (boundary == "below" and 0.5 or 1) / candidate.Chance
									or 1
							end,
						}
						local got = gachaConfig.Roll(rng, 1, active)
						local want = allowed and boundary == "below" and candidate.Id or catchAll
						-- When filtered, the unfiltered target index can hit a normal
						-- car; the required assertion is exclusion of this event car.
						flag(
							"weather_catalog_roll_" .. candidate.Id .. "_" .. label(active) .. "_" .. boundary,
							allowed and got == want or not allowed and got ~= candidate.Id
						)
					end
				else
					local got = gachaConfig.Roll({
						NextNumber = function()
							return 1
						end,
					}, 1, active)
					flag("weather_catalog_catch_all_" .. label(active), got == candidate.Id and candidate.Event == nil)
				end
			end
		end
		-- Event restrictions affect acquisition only. Every current car remains
		-- owned, equippable, indexed and serializable after its event ends.
		weather.SetEvent("", at)
		local inventory = fake("EntireCatalog", data, gacha)
		table.insert(extraPlayers, inventory)
		-- Owner rule: the car model sets cruise speed (CarSpeedMulti) and never the Speed-stat gain (SpeedMulti)
		local gainMulti = gacha.SpeedMulti(inventory)
		for _, spec in catalog.All() do
			flag("catalog_grant_" .. spec.Id, gacha.Grant(inventory, spec.Id) == true)
			flag(
				"catalog_equip_after_event_" .. spec.Id,
				gacha.Equip(inventory, spec.Id) == true
					and inventory:GetAttribute("EquippedCar") == spec.Id
					and type(gacha.CarSpeedMulti) == "function"
					and near(gacha.CarSpeedMulti(inventory), spec.SpeedMulti)
					and near(gacha.SpeedMulti(inventory), gainMulti)
			)
		end
		flag(
			"catalog_all_discoveries_count",
			gacha.UniqueCount(inventory) == #catalog.All()
				and gacha.EarnedPoints(inventory) == math.floor(#catalog.All() / gachaConfig.DISCOVERIES_PER_POINT)
		)
		local snapshot = gacha.Snapshot(inventory)
		local restored = fake("EntireCatalogRestored", data, gacha)
		table.insert(extraPlayers, restored)
		gacha.Apply(restored, snapshot)
		flag(
			"catalog_all_cars_round_trip",
			#snapshot.Cars == #catalog.All()
				and gacha.UniqueCount(restored) == #catalog.All()
				and restored:GetAttribute("EquippedCar") == inventory:GetAttribute("EquippedCar")
		)
		for _, spec in catalog.All() do
			local owned = restored:FindFirstChild("GachaData")
			flag("catalog_saved_ownership_" .. spec.Id, owned ~= nil and owned:FindFirstChild(spec.Id) ~= nil)
		end
	end)
	-- BRIEF (owner, 2026-10-13; docs/GAME_DESIGN_REQUIREMENTS.md "Weather events", docs/WEATHER_EVENTS_SPEC.md
	-- "Schedule" and "Weather icon"): "A weather starts every 15 minutes (WeatherConfig.INTERVAL, start to start)
	-- and lasts 3 minutes (DURATION) ... The server picks one id from WeatherConfig.Order with equal chance
	-- (1 in 5): clear, rain, night, gold, aurora. An explicit WeatherService.SetEvent(id, at) restarts the 15
	-- minutes from at; a weather that simply expires does not move the next start." "Describe lists every
	-- multiplier that is not 1 as LUCK x2, MONEY x2, NPC SPEED x1.25, joined by ' • ', and returns NO BONUS for
	-- Clear, for '' and for an unknown id."
	local scheduleOk, scheduleErr = pcall(function()
		local interval, duration = config.INTERVAL, config.DURATION
		flag("weather_interval_15_minutes", interval == 15 * 60, type(interval) == "number" and interval or -1, 900)
		flag("weather_duration_3_minutes", duration == 3 * 60, type(duration) == "number" and duration or -1, 180)
		flag("weather_random_interval_removed", config.MIN_INTERVAL == nil and config.MAX_INTERVAL == nil)
		local wantOrder = { "clear", "rain", "night", "gold", "aurora" }
		local wantNames =
			{ clear = "CLEAR", rain = "RAIN", night = "NIGHT RACE", gold = "GOLD RUSH", aurora = "AURORA" }
		local wantMultis = {
			clear = { 1, 1, 1 },
			rain = { 2, 1, 1 },
			night = { 1, 2, 1.25 },
			gold = { 1, 3, 1 },
			aurora = { 1.5, 1.5, 1 },
		}
		local order = type(config.Order) == "table" and config.Order or {}
		local orderExact = #order == #wantOrder
		for i, id in wantOrder do
			orderExact = orderExact and order[i] == id
		end
		flag("weather_order_exact_five", orderExact, #order, #wantOrder)
		local inOrder = {}
		for _, id in wantOrder do
			inOrder[id] = true
			local spec = type(config.Events) == "table" and config.Events[id] or nil
			local values = wantMultis[id]
			flag("weather_config_name_" .. id, type(spec) == "table" and spec.Name == wantNames[id])
			flag(
				"weather_config_icon_" .. id,
				type(spec) == "table" and type(spec.Icon) == "string" and spec.Icon ~= ""
			)
			flag(
				"weather_config_multipliers_" .. id,
				type(spec) == "table"
					and spec.Luck == values[1]
					and spec.Money == values[2]
					and spec.NpcSpeed == values[3]
			)
		end

		-- Schedule. Every time is explicit; the background loop is suspended while CarTestRunning is true.
		local timed = type(interval) == "number" and type(duration) == "number" and interval > duration + 1
		-- true when an automatic weather from Order is running that started at `start`
		local function startedAt(start)
			local id, ends = weather.Current()
			return inOrder[id] == true
				and near(ends, start + duration)
				and ReplicatedStorage:GetAttribute("WeatherEvent") == id
				and near(ReplicatedStorage:GetAttribute("WeatherEndsAt"), start + duration)
		end
		local t = Workspace:GetServerTimeNow() + 100000
		-- 1. From the state between weathers: SetEvent("", t) restarts the 15 minutes from t.
		local quiet, onTime = false, false
		if timed then
			weather.SetEvent("", t)
			weather.Tick(t + interval - 1)
			quiet = weather.Current() == ""
			weather.Tick(t + interval)
			onTime = startedAt(t + interval)
		end
		flag("weather_none_nothing_before_interval", quiet)
		flag("weather_none_starts_exactly_at_interval", onTime)
		-- 2. The automatic weather that started at s = t + INTERVAL counts start to start: the next one is at
		-- s + INTERVAL, and its own expiry at s + DURATION moves nothing.
		local s = t + (timed and interval or 0)
		local expired, stillQuiet, nextOnTime = false, false, false
		if timed and onTime then
			weather.Tick(s + duration)
			expired = weather.Current() == ""
			weather.Tick(s + interval - 1)
			stillQuiet = weather.Current() == ""
			weather.Tick(s + interval)
			nextOnTime = startedAt(s + interval)
		end
		flag("weather_auto_expires_after_duration", expired)
		flag("weather_auto_expiry_does_not_move_next_start", stillQuiet)
		flag("weather_auto_start_to_start_interval", nextOnTime)
		-- 3. An explicit weather, for every id: it expires through Tick and the next start stays at at + INTERVAL.
		for _, id in wantOrder do
			t += 100000
			local set, gone, calm, again = false, false, false, false
			if timed then
				set = weather.SetEvent(id, t) == true and weather.Current() == id
				weather.Tick(t + duration)
				gone = weather.Current() == ""
				weather.Tick(t + interval - 1)
				calm = weather.Current() == ""
				weather.Tick(t + interval)
				again = startedAt(t + interval)
			end
			flag("weather_schedule_expires_" .. id, set and gone)
			flag("weather_schedule_nothing_before_interval_" .. id, set and calm)
			flag("weather_schedule_starts_exactly_at_interval_" .. id, set and again)
		end

		-- Equal chance: 2000 automatic picks. The band is about 6.7 standard deviations around 1/5, so a uniform
		-- pick practically never fails it, while a missing weather (0) or a 3-weather pick (1/3) always does.
		local PICKS = 2000
		local counts, valid = {}, 0
		if timed then
			for _ = 1, PICKS do
				t += interval + duration + 10
				weather.SetEvent("", t)
				weather.Tick(t + interval)
				local id = weather.Current()
				if inOrder[id] then
					valid += 1
					counts[id] = (counts[id] or 0) + 1
				end
			end
		end
		weather.SetEvent("")
		flag("weather_pick_always_from_order", valid == PICKS, valid, PICKS)
		for _, id in wantOrder do
			local share = (counts[id] or 0) / PICKS
			flag("weather_pick_share_" .. id, share >= 0.14 and share <= 0.26, share, 0.2)
		end

		-- Describe: multipliers that are not 1, in the order Luck, Money, NPC speed.
		local describe = config.Describe
		flag("weather_describe_api_exists", type(describe) == "function")
		local function described(name, id, want)
			local called, got = pcall(function()
				return describe(id)
			end)
			flag(
				"weather_describe_" .. name,
				called and got == want,
				called and type(got) == "string" and got or -1,
				want
			)
		end
		described("rain", "rain", "LUCK x2")
		described("night", "night", "MONEY x2 • NPC SPEED x1.25")
		described("gold", "gold", "MONEY x3")
		described("aurora", "aurora", "LUCK x1.5 • MONEY x1.5")
		described("clear", "clear", "NO BONUS")
		described("none", "", "NO BONUS")
		described("unknown", "nope", "NO BONUS")
		described("nil", nil, "NO BONUS")
	end)
	weather.SetEvent("")
	flag("weather_schedule_no_runtime_error", scheduleOk, nil, scheduleOk and 1 or tostring(scheduleErr))
	-- BRIEF (owner, 2026-10-12; docs/WEATHER_EVENTS_SPEC.md "Sky"): "Each event also changes the sky, and the
	-- clear state restores the exact baseline values that WeatherService.Start saved. No uploaded skybox
	-- textures: the server sets Lighting.Atmosphere (Color, Density, Haze), Terrain.Clouds (Cover, Density,
	-- Color) and Lighting.Sky.StarCount from WeatherConfig.Events[id].Sky." Table: Rain = grey-blue, dense,
	-- hazy / heavy cover, dark / 0 stars; Night Race = dark violet, thin / light cover / many stars;
	-- Gold Rush = warm gold, light haze / thin, golden / 0 stars. Numbers come from the config, never from here.
	-- Owner, 2026-10-13: Aurora = teal-green, thin / light cover, violet / many stars. "clear is a real pick with
	-- its own 3 minutes, but it has no Sky, ClockTime, Brightness or Color effect: Lighting and the sky stay at
	-- the baseline."
	local skyOk, skyErr = pcall(function()
		local Lighting = game:GetService("Lighting")
		local ids = { "rain", "night", "gold", "aurora" }
		local function only(parent, class)
			local found, count = nil, 0
			for _, child in parent:GetChildren() do
				if child:IsA(class) then
					found = found or child
					count += 1
				end
			end
			return found, count
		end
		local function num(v)
			return type(v) == "number" and v == v and math.abs(v) ~= math.huge
		end
		local function shaped(sky)
			return type(sky) == "table"
				and type(sky.Atmosphere) == "table"
				and typeof(sky.Atmosphere.Color) == "Color3"
				and num(sky.Atmosphere.Density)
				and num(sky.Atmosphere.Haze)
				and type(sky.Clouds) == "table"
				and num(sky.Clouds.Cover)
				and num(sky.Clouds.Density)
				and typeof(sky.Clouds.Color) == "Color3"
				and num(sky.StarCount)
		end
		local skies, allShaped = {}, true
		for _, id in ids do
			local sky = config.Events[id] and config.Events[id].Sky
			local good = shaped(sky)
			flag("weather_sky_config_shape_" .. id, good)
			flag(
				"weather_sky_config_ranges_" .. id,
				good
					and sky.Atmosphere.Density >= 0
					and sky.Atmosphere.Density <= 1
					and sky.Atmosphere.Haze >= 0
					and sky.Clouds.Cover >= 0
					and sky.Clouds.Cover <= 1
					and sky.Clouds.Density >= 0
					and sky.Clouds.Density <= 1
					and sky.StarCount >= 0
					and sky.StarCount % 1 == 0
			)
			skies[id] = good and sky or nil
			allShaped = allShaped and good
		end
		local rain, night, gold, aurora = skies.rain, skies.night, skies.gold, skies.aurora
		flag(
			"weather_sky_rain_densest_haziest",
			allShaped
				and rain.Atmosphere.Density > night.Atmosphere.Density
				and rain.Atmosphere.Density > gold.Atmosphere.Density
				and rain.Atmosphere.Density > aurora.Atmosphere.Density
				and rain.Atmosphere.Haze > night.Atmosphere.Haze
				and rain.Atmosphere.Haze > gold.Atmosphere.Haze
				and rain.Atmosphere.Haze > aurora.Atmosphere.Haze
		)
		flag(
			"weather_sky_rain_heaviest_cloud_cover",
			allShaped
				and rain.Clouds.Cover > night.Clouds.Cover
				and rain.Clouds.Cover > gold.Clouds.Cover
				and rain.Clouds.Cover > aurora.Clouds.Cover
		)
		flag(
			"weather_sky_night_thinnest_atmosphere",
			allShaped
				and night.Atmosphere.Density < rain.Atmosphere.Density
				and night.Atmosphere.Density <= gold.Atmosphere.Density
		)
		flag(
			"weather_sky_stars_only_at_night_and_aurora",
			allShaped and rain.StarCount == 0 and gold.StarCount == 0 and night.StarCount > 0 and aurora.StarCount > 0
		)
		flag(
			"weather_sky_aurora_teal_green_atmosphere",
			allShaped and aurora.Atmosphere.Color.G > aurora.Atmosphere.Color.R,
			allShaped and aurora.Atmosphere.Color.G - aurora.Atmosphere.Color.R or -1,
			0
		)
		flag(
			"weather_sky_aurora_violet_clouds",
			allShaped and aurora.Clouds.Color.B > aurora.Clouds.Color.G,
			allShaped and aurora.Clouds.Color.B - aurora.Clouds.Color.G or -1,
			0
		)
		flag(
			"weather_sky_gold_warm_atmosphere",
			allShaped and gold.Atmosphere.Color.R > gold.Atmosphere.Color.B,
			allShaped and gold.Atmosphere.Color.R - gold.Atmosphere.Color.B or -1,
			0
		)
		flag(
			"weather_sky_gold_thin_golden_clouds",
			allShaped and gold.Clouds.Density < rain.Clouds.Density and gold.Clouds.Color.R > gold.Clouds.Color.B
		)

		-- Main ran WeatherService.Start() before the harness: the three instances must already exist.
		weather.SetEvent("")
		local atmosphere, atmospheres = only(Lighting, "Atmosphere")
		local skyBox, skyBoxes = only(Lighting, "Sky")
		local clouds, cloudCount = only(Workspace.Terrain, "Clouds")
		flag("weather_sky_atmosphere_exists", atmospheres == 1, atmospheres, 1)
		flag("weather_sky_skybox_exists", skyBoxes == 1, skyBoxes, 1)
		flag("weather_sky_clouds_exist", cloudCount == 1, cloudCount, 1)
		local live = atmosphere ~= nil and skyBox ~= nil and clouds ~= nil
		local function read()
			return {
				atmosphere.Color,
				atmosphere.Density,
				atmosphere.Haze,
				clouds.Cover,
				clouds.Density,
				clouds.Color,
				skyBox.StarCount,
			}
		end
		-- The clear state IS the baseline Start saved; a read-back of a property is exact.
		local baseline = live and read() or nil
		local function restored()
			if not (live and allShaped) then
				return false
			end
			local got = read()
			for i, want in baseline do
				if got[i] ~= want then
					return false
				end
			end
			return true
		end
		-- Instance properties are 32-bit floats: "exactly the config value" is within one float step.
		local function applied(id)
			local sky = skies[id]
			return live
				and sky ~= nil
				and atmosphere.Color == sky.Atmosphere.Color
				and near(atmosphere.Density, sky.Atmosphere.Density, 1e-5)
				and near(atmosphere.Haze, sky.Atmosphere.Haze, 1e-5)
				and near(clouds.Cover, sky.Clouds.Cover, 1e-5)
				and near(clouds.Density, sky.Clouds.Density, 1e-5)
				and clouds.Color == sky.Clouds.Color
				and skyBox.StarCount == sky.StarCount
		end
		local at = Workspace:GetServerTimeNow()
		for _, id in ids do
			weather.SetEvent(id, at)
			local _, expiry = weather.Current()
			flag("weather_sky_applied_" .. id, applied(id))
			weather.Tick(expiry - 0.001)
			flag("weather_sky_held_until_expiry_" .. id, applied(id))
			weather.Tick(expiry)
			flag("weather_sky_restored_on_expiry_" .. id, weather.Current() == "" and restored())
			at += config.DURATION + 10
			weather.SetEvent(id, at)
			flag("weather_sky_reapplied_" .. id, applied(id))
			weather.SetEvent("", at)
			flag("weather_sky_restored_on_clear_" .. id, restored())
		end
		-- Clear is a weather that changes nothing: started over Rain or Aurora, the sky and Lighting are the same
		-- as with no weather active. ClockTime and Brightness are read back from Lighting, hence the tolerance.
		weather.SetEvent("", at)
		local lightingBase = { Lighting.ClockTime, Lighting.Brightness, Lighting.OutdoorAmbient }
		local function lightingRestored()
			return near(Lighting.ClockTime, lightingBase[1], 1e-3)
				and near(Lighting.Brightness, lightingBase[2], 1e-4)
				and Lighting.OutdoorAmbient == lightingBase[3]
		end
		for _, before in { "rain", "aurora" } do
			at += config.DURATION + 10
			local changed = weather.SetEvent(before, at) == true and applied(before)
			local set = weather.SetEvent("clear", at) == true
			local current, ends = weather.Current()
			local active = set and current == "clear" and near(ends, at + config.DURATION)
			flag("weather_clear_starts_after_" .. before, changed and active)
			flag("weather_clear_keeps_sky_baseline_after_" .. before, changed and active and restored())
			flag("weather_clear_keeps_lighting_baseline_after_" .. before, changed and active and lightingRestored())
			weather.Tick(at + config.DURATION - 0.001)
			flag(
				"weather_clear_held_until_expiry_after_" .. before,
				changed and active and weather.Current() == "clear" and restored() and lightingRestored()
			)
			weather.Tick(at + config.DURATION)
			flag(
				"weather_clear_expires_to_baseline_after_" .. before,
				changed and active and weather.Current() == "" and restored() and lightingRestored()
			)
		end
		-- One event replacing another must not move the baseline: clear restores Start's values, not rain's.
		weather.SetEvent("rain", at)
		weather.SetEvent("night", at)
		flag("weather_sky_switch_applies_new_event", applied("night"))
		weather.SetEvent("gold", at)
		weather.SetEvent("", at)
		flag("weather_sky_restored_after_event_switch", restored())
		local _, atmospheresAfter = only(Lighting, "Atmosphere")
		local _, skyBoxesAfter = only(Lighting, "Sky")
		local _, cloudsAfter = only(Workspace.Terrain, "Clouds")
		flag(
			"weather_sky_no_duplicate_instances",
			atmospheresAfter == 1 and skyBoxesAfter == 1 and cloudsAfter == 1,
			atmospheresAfter + skyBoxesAfter + cloudsAfter,
			3
		)
	end)
	weather.SetEvent("")
	flag("weather_sky_no_runtime_error", skyOk, nil, skyOk and 1 or tostring(skyErr))
	for i = #resources, 1, -1 do
		pcall(function()
			resources[i]:Destroy()
		end)
	end
	for _, extra in extraPlayers do
		extra:Destroy()
	end
	p:Destroy()
	pad:Destroy()
	flag("weather_no_runtime_error", ok, nil, ok and 1 or tostring(err))
	return r
end

-- BRIEF (owner, 2026-10-12; docs/GAME_DESIGN_REQUIREMENTS.md "Rebirth system", docs/SAVE_SPEC.md sections 2 and 3):
-- "Rebirthing resets Money, Speed, Level and XP." RebirthService.Rebirth(player) sets both leaderstats values to 0,
-- Level to 1 and XP to 0. A refused rebirth changes nothing. The rebirth level, cars, upgrades, workshop level,
-- MoneyEarned and DuelWins survive.
function Tests.rebirth()
	local r, flag = report("rebirth")
	local service = module(Server, "RebirthService")
	local data = module(Server, "PlayerData")
	local gacha = module(Server, "GachaService")
	local upgrades = module(Server, "UpgradeService")
	local config = module(Shared, "RebirthConfig")
	local api = service
		and data
		and gacha
		and upgrades
		and config
		and type(service.Rebirth) == "function"
		and type(config.Requirements) == "function"
		and type(upgrades.Apply) == "function"
		and type(upgrades.Snapshot) == "function"
	flag("rebirth_api_exists", api == true)
	if not api then
		return r
	end
	local gachaConfig = module(Shared, "GachaConfig")
	-- design doc "Rebirth system": "Rebirth Points per rebirth: 1" (placeholder, owner 2026-10-15)
	local perRebirth = config.POINTS_PER_REBIRTH
	flag("rebirth_points_per_rebirth_is_1", perRebirth == 1, perRebirth, 1)
	-- design doc "Rebirth system", owner 2026-10-27 rev. 4 (docs/REBIRTH_SPEC.md "Automatic bonus rev. 4"): the
	-- rebirth level sets one TOTAL multi from a fixed table: level 0 = 1, then 1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7.5, 10,
	-- then x10 per rebirth up to 1e11 at rebirth 20 (the last one; later levels stay 1e11). Luck uses the same multi.
	local TOTALS = { 1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7.5, 10, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11 }
	flag("rebirth_max_level_is_20", config.MAX_LEVEL == 20, config.MAX_LEVEL, 20)
	local tableOk = type(config.TOTALS) == "table" and #config.TOTALS == #TOTALS
	for i, want in TOTALS do
		tableOk = tableOk and config.TOTALS[i] == want
	end
	flag("rebirth_totals_table_rev4", tableOk)
	for _, case in
		{
			{ 0, 1 },
			{ 1, 1.5 },
			{ 2, 2 },
			{ 9, 7.5 },
			{ 10, 10 },
			{ 11, 100 },
			{ 12, 1000 },
			{ 20, 1e11 },
			{ 21, 1e11 },
		}
	do
		local level, want = case[1], case[2]
		local got = config.SpeedGainMulti(level)
		flag("rebirth_multi_level_" .. level .. "_is_" .. tostring(want), got == want, got, want)
	end
	local curveOk = config.SpeedGainMulti(0) == 1
	for level = 1, 40 do
		local got = config.SpeedGainMulti(level)
		curveOk = curveOk and got == TOTALS[math.min(level, #TOTALS)]
	end
	flag("rebirth_multi_follows_totals_then_flat", curveOk)
	local huge = config.SpeedGainMulti(1e9)
	flag("rebirth_multi_level_1e9_is_1e11", huge == 1e11, huge, 1e11)
	flag(
		"rebirth_late_step_and_effective_cap_removed",
		config.LATE_STEP == nil and config.MAX_EFFECTIVE_MULTIPLIER == nil
	)
	flag("rebirth_rev3_step_removed", config.EARLY_STEP == nil and config.ADD_UNTIL == nil)
	-- docs/REBIRTH_SPEC.md "Requirement" rev. 4: level needed for the next rebirth, by current rebirth level 0..19
	local levelConfigReq = module(Shared, "LevelConfig")
	local REQ = { 15, 25, 40, 60, 75, 100, 125, 150, 175, 200, 225, 260, 300, 340, 380, 420, 465, 510, 560, 600 }
	local reqOk = levelConfigReq ~= nil and type(levelConfigReq.RebirthLevelRequirement) == "function"
	for n, want in REQ do
		reqOk = reqOk
			and levelConfigReq.RebirthLevelRequirement(n - 1) == want
			and config.Requirements(n - 1).Level == want
	end
	flag("rebirth_requirement_table_rev4", reqOk)
	local past = reqOk
		and levelConfigReq.RebirthLevelRequirement(19) == 600
		and levelConfigReq.RebirthLevelRequirement(50)
	flag("rebirth_requirement_past_last_is_600", past == 600, past, 600)
	flag(
		"rebirth_cannot_rebirth_at_max",
		config.CanRebirth(20, 1e9) == false
			and config.CanRebirth(25, 1e9) == false
			and config.CanRebirth(19, 600) == true
	)
	flag("rebirth_old_x10_totals_removed", config.REBIRTH_TOTALS == nil and config.REPEAT_FACTOR == nil)
	local luckSame = true
	for _, level in { 0, 1, 2, 5, 10, 11, 19, 20, 21, 60 } do
		luckSame = luckSame and config.LuckMulti(level) == config.SpeedGainMulti(level)
	end
	flag("rebirth_luck_multi_equals_speed_gain_multi", luckSame)
	local nextOk = type(config.NextMultiplier) == "function"
	for _, level in { 0, 1, 9, 10, 18, 19, 20, 21 } do
		nextOk = nextOk and config.NextMultiplier(level) == config.SpeedGainMulti(level + 1)
	end
	flag("rebirth_next_multiplier_is_next_level_total", nextOk)
	flag(
		"rebirth_old_factor_tables_removed",
		config.REBIRTH_MULTIPLIERS == nil
			and config.REPEAT_MULTIPLIER == nil
			and config.SPEED_GAIN_MULTIPLIER == nil
			and config.LUCK_MULTIPLIER == nil
	)
	local players = {}
	local oldCooldown = service.REMOTE_COOLDOWN
	local ok, err = pcall(function()
		service.REMOTE_COOLDOWN = 0 -- the remote's rate limit is tested on its own below
		local need = config.Requirements(0).Level
		local function ready(name, level)
			local p = fake("Rebirth" .. name, data, gacha)
			table.insert(players, p)
			p:SetAttribute("DataLoaded", true)
			p:SetAttribute("Level", level)
			p:SetAttribute("XP", 37)
			p:SetAttribute("WorkshopLevel", 1)
			p:SetAttribute("MoneyEarned", 9000)
			p:SetAttribute("DuelWins", 3)
			p.leaderstats.Money.Value = 5000
			p.BaseSpeed.Value = 321.5
			gacha.Grant(p, "wooden_car")
			gacha.Grant(p, "go_kart")
			gacha.Equip(p, "go_kart")
			upgrades.Apply(p, { Upgrades = { "money_1", "rollspeed_1" }, BestTrack = 2, TurboCount = 7 })
			return p
		end
		local function untouched(p, money, speed, level)
			return p.leaderstats.Money.Value == money
				and near(p.BaseSpeed.Value, speed)
				and p:GetAttribute("RebirthLevel") == level
		end
		-- every refusal leaves Money, Speed and the rebirth level alone
		local function refused(label, p, change, restore)
			change()
			local accepted = service.Rebirth(p)
			flag("rebirth_refused_" .. label, accepted == false)
			flag(
				"rebirth_refused_" .. label .. "_keeps_money_and_speed",
				untouched(p, 5000, 321.5, 0),
				p.BaseSpeed.Value,
				321.5
			)
			restore()
		end
		local low = ready("Low", need - 1)
		refused("below_level", low, function() end, function() end)
		local p = ready("Main", need)
		refused("unloaded", p, function()
			p:SetAttribute("DataLoaded", false)
		end, function()
			p:SetAttribute("DataLoaded", true)
		end)
		refused("failed_load", p, function()
			p:SetAttribute("DataFailed", true)
		end, function()
			p:SetAttribute("DataFailed", nil)
		end)
		refused("auto_racing", p, function()
			p:SetAttribute("AutoRacing", true)
		end, function()
			p:SetAttribute("AutoRacing", nil)
		end)

		-- Rebirth Points (owner 2026-10-15): spend every index point first, so any free point after the rebirth
		-- can only come from the rebirth itself
		for _ = 1, 100 do
			if not gacha.Allocate(p, "Speed") then
				break
			end
		end
		local pointsBefore = p:GetAttribute("StatPoints")
		local carsBefore = gacha.Snapshot(p)
		local upgradesBefore = upgrades.Snapshot(p)
		-- docs/WORKSHOP_SPEC.md 5b (owner 2026-10-22): a rebirth keeps cars, so it keeps copies and the showcase
		gacha.Grant(p, "go_kart") -- a duplicate: 1 copy, no Money
		local showcaseSet = type(gacha.SetShowcase) == "function" and gacha.SetShowcase(p, { "go_kart", "wooden_car" })
		local accepted, newLevel = service.Rebirth(p)
		flag("rebirth_accepted_at_required_level", accepted == true and newLevel == 1)
		flag("rebirth_level_raised", p:GetAttribute("RebirthLevel") == 1, p:GetAttribute("RebirthLevel"), 1)
		flag("rebirth_resets_money", p.leaderstats.Money.Value == 0, p.leaderstats.Money.Value, 0)
		flag("rebirth_resets_speed", p.BaseSpeed.Value == 0, p.BaseSpeed.Value, 0)
		task.wait() -- the shown Speed follows BaseSpeed on its Changed signal (may be deferred)
		-- Owner 2026-10-21: leaderstats.Speed shows base x ShownSpeedMulti, so it is 0 too (go_kart stays equipped)
		flag("rebirth_resets_shown_speed", p.leaderstats.Speed.Value == 0, p.leaderstats.Speed.Value, 0)
		-- design doc "Rebirth system" (owner 2026-10-27 rev. 4): rebirth 1 = total x1.5 (no points, aura or trail here)
		flag(
			"rebirth_multiplier_refreshes_immediately",
			p:GetAttribute("SpeedGainMulti") == 1.5 and p:GetAttribute("LuckMulti") == 1.5,
			p:GetAttribute("SpeedGainMulti"),
			1.5
		)
		flag("rebirth_speed_stat_is_0", data.SpeedStat(p) == 0, data.SpeedStat(p), 0)
		local carsAfter = gacha.Snapshot(p)
		flag(
			"rebirth_keeps_cars",
			#carsAfter.Cars == #carsBefore.Cars
				and table.find(carsAfter.Cars, "wooden_car") ~= nil
				and table.find(carsAfter.Cars, "go_kart") ~= nil
				and carsAfter.Equipped == "go_kart"
				and p:GetAttribute("EquippedCar") == "go_kart"
		)
		flag(
			"rebirth_keeps_copies_and_showcase",
			showcaseSet == true
				and type(gacha.Copies) == "function"
				and gacha.Copies(p, "go_kart") == 1
				and p:GetAttribute("Showcase") == "go_kart,wooden_car"
		)
		local upgradesAfter = upgrades.Snapshot(p)
		flag(
			"rebirth_keeps_upgrades",
			#upgradesAfter.Upgrades == #upgradesBefore.Upgrades
				and table.find(upgradesAfter.Upgrades, "money_1") ~= nil
				and table.find(upgradesAfter.Upgrades, "rollspeed_1") ~= nil
				and upgradesAfter.BestTrack == 2
				and upgradesAfter.TurboCount == 7
		)
		flag("rebirth_keeps_workshop_level", p:GetAttribute("WorkshopLevel") == 1)
		flag("rebirth_resets_level", p:GetAttribute("Level") == 1, p:GetAttribute("Level"), 1)
		flag("rebirth_resets_xp", p:GetAttribute("XP") == 0, p:GetAttribute("XP"), 0)
		local levelConfig = module(Shared, "LevelConfig")
		flag(
			"rebirth_resets_xp_to_next",
			levelConfig ~= nil and p:GetAttribute("XPToNext") == levelConfig.XPToNext(1),
			p:GetAttribute("XPToNext"),
			levelConfig and levelConfig.XPToNext(1) or "missing"
		)
		flag("rebirth_keeps_money_earned", p:GetAttribute("MoneyEarned") == 9000, p:GetAttribute("MoneyEarned"), 9000)
		flag("rebirth_keeps_duel_wins", p:GetAttribute("DuelWins") == 3, p:GetAttribute("DuelWins"), 3)

		-- Rebirth Points (docs/REBIRTH_SPEC.md "Rules (server)"): earned = index points + RebirthLevel * per rebirth;
		-- they join the free StatPoints pool and are spent through the normal Allocate path
		local per = (type(perRebirth) == "number" and perRebirth >= 1) and perRebirth or 1
		flag("rebirth_index_points_spent_before", pointsBefore == 0, pointsBefore, 0)
		local pointsAfter = p:GetAttribute("StatPoints")
		flag(
			"rebirth_grants_stat_points",
			type(pointsBefore) == "number" and pointsAfter == pointsBefore + per,
			pointsAfter,
			(tonumber(pointsBefore) or 0) + per
		)
		local wantEarned = gachaConfig.EarnedPoints(gacha.UniqueCount(p)) + 1 * per
		flag(
			"rebirth_earned_points_include_rebirths",
			gacha.EarnedPoints(p) == wantEarned,
			gacha.EarnedPoints(p),
			wantEarned
		)
		-- Rev. 4 requirement table (docs/REBIRTH_SPEC.md "Requirement"): rebirth level 5 requires level 100.
		local high = ready("Level100", 100)
		high:SetAttribute("RebirthLevel", 5)
		local highOk, highNext = service.Rebirth(high)
		flag("rebirth_level_100_requirement", config.Requirements(5).Level == 100, config.Requirements(5).Level, 100)
		flag("rebirth_level_100_accepted", highOk == true and highNext == 6, highNext, 6)
		-- rebirth 20 is the last: refused with "Max rebirth" at any level, Money and Speed untouched
		local maxed = ready("Max", 1e6)
		maxed:SetAttribute("RebirthLevel", 20)
		local maxOk, maxMsg = service.Rebirth(maxed)
		flag("rebirth_refused_at_max_rebirth", maxOk == false and maxMsg == "Max rebirth", maxMsg, "Max rebirth")
		flag(
			"rebirth_refused_at_max_keeps_money_and_speed",
			untouched(maxed, 5000, 321.5, 20),
			maxed.BaseSpeed.Value,
			321.5
		)
		local luckBefore = p:GetAttribute("Alloc_Luck") or 0
		local spent = gacha.Allocate(p, "Luck")
		flag(
			"rebirth_point_allocates",
			spent == true and p:GetAttribute("Alloc_Luck") == luckBefore + 1,
			p:GetAttribute("Alloc_Luck"),
			luckBefore + 1
		)
		flag(
			"rebirth_point_allocate_drops_stat_points",
			p:GetAttribute("StatPoints") == (tonumber(pointsAfter) or 0) - 1,
			p:GetAttribute("StatPoints"),
			(tonumber(pointsAfter) or 0) - 1
		)

		-- the next rebirth needs the next milestone: refused, and the stats earned since are not wiped
		p.leaderstats.Money.Value = 60
		p.BaseSpeed.Value = 50
		local again = service.Rebirth(p)
		flag(
			"rebirth_refused_next_milestone_keeps_money_and_speed",
			again == false and untouched(p, 60, 50, 1),
			p.BaseSpeed.Value,
			50
		)
		-- rate limit: a second request inside REMOTE_COOLDOWN is refused and changes nothing
		service.REMOTE_COOLDOWN = 60
		local spam = ready("Spam", need - 1)
		service.Rebirth(spam) -- refused (level), starts the cooldown
		spam:SetAttribute("Level", need)
		local spammed = service.Rebirth(spam)
		flag("rebirth_refused_cooldown_keeps_money_and_speed", spammed == false and untouched(spam, 5000, 321.5, 0))

		-- Load trim: PlayerData.Load runs GachaService.Apply BEFORE RebirthService.Apply, so the trim must count the
		-- SAVED RebirthLevel; rebirth-funded allocations survive, anything beyond index + rebirth points is cut.
		local function loaded(name, workshopAlloc)
			local q = fake("Rebirth" .. name, data, gacha)
			table.insert(players, q)
			q:SetAttribute("RebirthLevel", 0) -- not applied yet, as in PlayerData.Load
			local save = {
				Cars = { "go_kart", "rusty_hatchback", "wooden_car" },
				StatAlloc = { Workshop = workshopAlloc, Speed = 1 },
				RebirthLevel = 2,
			}
			gacha.Apply(q, save)
			local index = gachaConfig.EarnedPoints(gacha.UniqueCount(q))
			local trimmed = { Workshop = q:GetAttribute("Alloc_Workshop"), Speed = q:GetAttribute("Alloc_Speed") }
			service.Apply(q, save)
			return q, index, trimmed
		end
		local keep, index, kept = loaded("LoadKeep", 2 * per)
		flag("rebirth_load_index_points_is_1", index == 1, index, 1)
		flag(
			"rebirth_load_keeps_rebirth_allocations",
			kept.Workshop == 2 * per and kept.Speed == 1,
			kept.Workshop,
			2 * per
		)
		flag("rebirth_load_stat_points_0", keep:GetAttribute("StatPoints") == 0, keep:GetAttribute("StatPoints"), 0)
		flag(
			"rebirth_load_earned_points",
			gacha.EarnedPoints(keep) == index + 2 * per,
			gacha.EarnedPoints(keep),
			index + 2 * per
		)
		local _, _, cut = loaded("LoadOver", 2 * per + 3)
		flag("rebirth_load_trims_over_allocation", cut.Workshop == 2 * per and cut.Speed == 1, cut.Workshop, 2 * per)

		-- BRIEF (owner 2026-10-27, docs/GAME_DESIGN_REQUIREMENTS.md "Level system"): XP per second =
		-- LevelConfig.XP_PER_SECOND (1) x GachaService.SpeedMulti (Speed Gain x rebirth x aura x trail), not sqrt(Speed).
		local levels = module(Server, "LevelService")
		-- XP curve (owner 2026-10-27, LevelConfig): XPToNext(L) = XP_LINEAR x L up to level 225, then x10 every XP_DECADE
		-- levels; CleanXP keeps up to 1e300 (late rebirths need far more than 1e15 XP).
		-- Owner 2026-10-28: XP_LINEAR 122 (was 10), XP_DECADE 37.2 (was 40), so XPToNext(225) = 27,450. The numbers are
		-- pinned here as literals, never read from LevelConfig. 225 + 5 x 37.2 = 411 is exactly x10^5.
		local function xpCurve(level)
			return 27450 * 10 ^ ((level - 225) / 37.2)
		end
		local lc = module(Shared, "LevelConfig")
		local function xpNear(a, b)
			return type(a) == "number" and math.abs(a - b) <= 1e-9 * b
		end
		flag(
			"level_xp_curve_rev4",
			lc ~= nil
				and lc.XPToNext(1) == 122
				and lc.XPToNext(100) == 12200
				and lc.XPToNext(225) == 27450
				and xpNear(lc.XPToNext(226), xpCurve(226))
				and xpNear(lc.XPToNext(300), xpCurve(300))
				and xpNear(lc.XPToNext(411), 2745000000)
				and lc.XP_BASE == nil
				and lc.XP_GROWTH == nil,
			lc and lc.XPToNext(300),
			xpCurve(300)
		)
		flag(
			"level_clean_xp_caps_at_1e300",
			lc ~= nil and lc.CleanXP(1e200) == 1e200 and lc.CleanXP(1e301) == 1e300 and lc.CleanXP(-1) == 0,
			lc and lc.CleanXP(1e301),
			1e300
		)
		flag("level_xp_tick_exists", levels ~= nil and type(levels.Tick) == "function")
		if levels and type(levels.Tick) == "function" then
			local xpP = fake("LevelXp", data, gacha)
			table.insert(players, xpP)
			xpP:SetAttribute("DataLoaded", true)
			-- XP gained by one Tick from level XP_KNEE (225) / 0 XP. Owner 2026-10-28: XPToNext(L) = 122 x L, so level 1
			-- needs 122 XP; at 225 it needs 27,450, far above every probe below, so no tick levels up.
			local probeLevel = 225
			local function gain(dt, m)
				xpP:SetAttribute("Level", probeLevel)
				xpP:SetAttribute("XP", 0)
				levels.Tick(xpP, dt, m)
				return (xpP:GetAttribute("Level") == probeLevel) and xpP:GetAttribute("XP") or -1
			end
			local function near(a, b)
				return type(a) == "number" and math.abs(a - b) < 1e-6
			end
			local one = gain(1, 1)
			flag("level_xp_tick_base_is_1_per_second", near(one, 1), one, 1)
			local m25 = gain(1, 25)
			flag("level_xp_tick_scales_with_gain_multi", near(m25, 25 * one), m25, 25 * one)
			xpP.leaderstats.Speed.Value = 0
			xpP.BaseSpeed.Value = 0
			local low = gain(1, 3)
			xpP.leaderstats.Speed.Value = 1e6
			xpP.BaseSpeed.Value = 1e6
			local high = gain(1, 3)
			flag("level_xp_ignores_speed_stat", near(low, 3) and near(high, low), high, low)
			xpP:SetAttribute("RebirthLevel", 1)
			xpP:SetAttribute("EquippedAura", "azure_aura")
			xpP:SetAttribute("EquippedTrail", "rainbow_trail")
			local multi = gacha.SpeedMulti(xpP)
			flag("level_xp_speed_multi_above_1", type(multi) == "number" and multi > 1, multi, ">1")
			local viaMulti = gain(2, multi)
			flag("level_xp_tick_uses_speed_multi", near(viaMulti, multi * 2), viaMulti, multi * 2)
		end
	end)
	service.REMOTE_COOLDOWN = oldCooldown
	for _, p in players do
		p:Destroy()
	end
	flag("rebirth_no_runtime_error", ok, nil, ok and 1 or tostring(err))
	return r
end

-- BRIEF (owner, 2026-10-12; docs/GAME_DESIGN_REQUIREMENTS.md "Economy (Money)", docs/SAVE_SPEC.md section 3): Money
-- comes ONLY from race cash-outs (owner 2026-10-22: duplicate cars are no longer sold, they add a copy). "Daily login rewards contain no Money (no Money field on
-- any day; every day grants a potion or the guaranteed rare car). DailyLoginService.Claim never changes
-- leaderstats.Money." Seven days.
function Tests.daily_login()
	local r, flag = report("daily_login")
	local service = module(Server, "DailyLoginService")
	local config = module(Shared, "DailyLoginConfig")
	local boostConfig = module(Shared, "BoostConfig")
	local boosts = module(Server, "BoostService")
	local data = module(Server, "PlayerData")
	local gacha = module(Server, "GachaService")
	local api = service
		and config
		and boostConfig
		and boosts
		and data
		and gacha
		and type(service.Claim) == "function"
		and type(config.Rewards) == "table"
		and type(boostConfig.Get) == "function"
		and type(boosts.Count) == "function"
		and type(gacha.UniqueCount) == "function"
	flag("daily_login_api_exists", api == true)
	if not api then
		return r
	end
	local DAYS = 7
	flag("daily_rewards_seven_days", #config.Rewards == DAYS, #config.Rewards, DAYS)
	for day = 1, DAYS do
		local reward = config.Rewards[day]
		local isTable = type(reward) == "table"
		flag("daily_reward_" .. day .. "_has_no_money", isTable and reward.Money == nil)
		local potion = isTable and type(reward.Boost) == "string" and boostConfig.Get(reward.Boost) ~= nil
		flag("daily_reward_" .. day .. "_grants_potion_or_rare", isTable and (potion or reward.GuaranteedRare == true))
	end
	local players = {}
	local oldCooldown = service.REMOTE_COOLDOWN
	local ok, err = pcall(function()
		service.REMOTE_COOLDOWN = 0
		for day = 1, DAYS do
			local reward = config.Rewards[day]
			local p = fake("Daily" .. day, data, gacha)
			table.insert(players, p)
			p:SetAttribute("DataLoaded", true)
			p.leaderstats.Money.Value = 1234
			-- yesterday's claim was day - 1, so this claim is `day` (UTC day number, as the service counts it)
			p:SetAttribute("DailyLast", math.floor(os.time() / 86400) - 1)
			p:SetAttribute("DailyStreak", day - 1)
			local potionsBefore = type(reward) == "table" and reward.Boost and boosts.Count(p, reward.Boost) or 0
			local carsBefore = gacha.UniqueCount(p)
			local claimed, info = service.Claim(p)
			flag(
				"daily_claim_" .. day .. "_succeeds",
				claimed == true and type(info) == "table" and info.Day == day,
				type(info) == "table" and tonumber(info.Day) or -1,
				day
			)
			flag(
				"daily_claim_" .. day .. "_money_unchanged",
				p.leaderstats.Money.Value == 1234,
				p.leaderstats.Money.Value,
				1234
			)
			local resultMoney = type(info) == "table" and info.Money or nil
			flag(
				"daily_claim_" .. day .. "_result_has_no_money",
				type(info) == "table" and not (type(resultMoney) == "number" and resultMoney > 0)
			)
			flag("daily_claim_" .. day .. "_no_money_earned", (p:GetAttribute("MoneyEarned") or 0) == 0)
			local gotPotion = type(reward) == "table"
				and reward.Boost ~= nil
				and boosts.Count(p, reward.Boost) == potionsBefore + (reward.BoostCount or 1)
			local gotCar = type(reward) == "table"
				and reward.GuaranteedRare == true
				and gacha.UniqueCount(p) == carsBefore + 1
			flag("daily_claim_" .. day .. "_grants_potion_or_rare", gotPotion or gotCar)
			-- a second claim the same day is refused and still pays nothing
			local twice = service.Claim(p)
			flag("daily_claim_" .. day .. "_once_per_day", twice == false and p.leaderstats.Money.Value == 1234)
		end
	end)
	service.REMOTE_COOLDOWN = oldCooldown
	for _, p in players do
		p:Destroy()
	end
	flag("daily_login_no_runtime_error", ok, nil, ok and 1 or tostring(err))
	return r
end

return Tests
