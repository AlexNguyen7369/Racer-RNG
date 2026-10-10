--!nonstrict
-- BRIEF: Workshop phase 2: exact integrated 25% offline rate, eight-hour cap,
-- MAX_STAT, guarded next-level purchase, OfflineAt persistence and one-time credit.
-- Weather: rain luck 2, night NPC speed 1.25/money 2, gold money 3, expiry,
-- actual rolls/payouts and Event-only catalog eligibility. No owner prices assumed.

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

-- Independent oracle: ds/dt = A/(1+s/H). Rationalized to avoid cancellation
-- close to MAX_STAT; this deliberately never calls Workshop.Rate/OfflineGain.
local function integrated(stat, speedMulti, levelMulti, workshopMulti, seconds, config, race)
	local a = 0.25 * config.BASE_RATE * speedMulti * levelMulti * workshopMulti
	local h = race.GAIN_SOFT
	local t = math.clamp(seconds, 0, 8 * 60 * 60)
	local q = 2 * h * a * t
	local gain = q / (math.sqrt((stat + h) ^ 2 + q) + stat + h)
	return math.min(gain, math.max(0, race.MAX_STAT - stat))
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
		local want = integrated(stat, sm, config.Levels[level].Multi, wm, seconds, config, race)
		local ok, got = pcall(workshop.OfflineGain, stat, sm, level, wm, seconds)
		flag(label, ok and near(got, want), type(got) == "number" and got or -1, want)
		return got, want
	end
	exact("offline_exact_quarter_rate_from_zero", 0, 1, 1, 1, 3600)
	exact("offline_exact_diminishing_existing_stat", race.GAIN_SOFT, 3, 1, 2, 7200)
	exact("offline_eight_hour_cap", 1234, 2, 1, 3, 8 * 3600)
	exact("offline_beyond_eight_hours_same_gain", 1234, 2, 1, 3, 48 * 3600)
	exact("offline_zero_seconds", 100, 2, 1, 3, 0)
	exact("offline_negative_seconds", 100, 2, 1, 3, -1)
	exact("offline_zero_speed_multi", 100, 0, 1, 3, 3600)
	exact("offline_zero_workshop_multi", 100, 2, 1, 0, 3600)
	exact("offline_max_stat_no_gain", race.MAX_STAT, 2, 1, 3, 8 * 3600)
	exact("offline_crossing_max_stat_clamped", race.MAX_STAT - 0.25, 1e8, 1, 2, 8 * 3600)
	-- A frozen rate * seconds approximation must fail this discriminating fixture.
	local got, want = exact("offline_integrates_instead_of_frozen_rate", 0, 10, 1, 5, 8 * 3600)
	local frozen = 0.25 * config.BASE_RATE * 10 * 5 * 8 * 3600
	flag("offline_oracle_distinguishes_linear_shortcut", math.abs(want - frozen) > 1 and near(got, want))
	local first = workshop.OfflineGain(500, 2, 1, 3, 1800)
	local second = workshop.OfflineGain(500 + first, 2, 1, 3, 1800)
	local whole = workshop.OfflineGain(500, 2, 1, 3, 3600)
	flag("offline_integral_composes", near(first + second, whole))
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
		function store:UpdateAsync(_key, transform)
			self.claims += 1
			local updated = transform(table.clone(initial))
			if updated ~= nil then
				initial = updated
			end
			return initial
		end
		data.SetStore(store)
		local p = player("OfflineLoad")
		gacha.Apply(p, initial)
		local want = initial.Speed
			+ integrated(
				initial.Speed,
				gacha.SpeedMulti(p),
				config.Levels[1].Multi,
				gacha.WorkshopMulti(p),
				3600,
				config,
				race
			)
		flag("offline_load_succeeds", data.Load(p, 74002, at) == true)
		flag(
			"offline_load_credits_exact_integral",
			near(p.leaderstats.Speed.Value, want, 0.002),
			p.leaderstats.Speed.Value,
			want
		)
		flag(
			"offline_claim_persisted_before_any_save",
			store.claims == 1
				and near(initial.Speed, want, 0.002)
				and initial.OfflineAt == at
				and initial.Money
					== 41 + Workshop.OfflineMoney(2500, gacha.SpeedMulti(p), 1, gacha.WorkshopMulti(p), 3600)
				and initial.WorkshopLevel == 1
		)
		flag(
			"offline_welcome_attributes",
			near(p:GetAttribute("OfflineSpeed"), want - 2500, 0.002) and p:GetAttribute("OfflineSeconds") == 3600
		)
		local reconnect = player("ReconnectBeforeSave")
		data.Load(reconnect, 74002)
		flag(
			"offline_no_replay_on_reconnect_without_save",
			near(reconnect.leaderstats.Speed.Value, want, 0.002) and reconnect:GetAttribute("OfflineSpeed") == 0
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
			return updated or claimed
		end
		data.SetStore(racedStore)
		local raced = player("ConcurrentClaim")
		local raceLoaded = data.Load(raced, 74002)
		flag(
			"offline_stale_read_cannot_replay_claim",
			raceLoaded == true
					and near(raced.leaderstats.Speed.Value, want, 0.002)
					and raced:GetAttribute("OfflineSpeed") == 0
				or raceLoaded == false
					and raced:GetAttribute("DataFailed") == true
					and raced:GetAttribute("DataLoaded") ~= true
					and raced.leaderstats.Speed.Value <= 2500
		)
		data.SetStore(store)
		-- Include a subsequent live gain: reloading must neither replay offline credit nor reset live progress.
		data.AddSpeed(p, 7)
		local once = p.leaderstats.Speed.Value
		clock = at + 60
		local claimsBefore = store.claims
		data.Load(p, 74002)
		flag("offline_repeated_load_preserves_once_credit_and_live_gain", near(p.leaderstats.Speed.Value, once, 0.002))
		flag("offline_repeated_load_no_store_claim", store.claims == claimsBefore)
		flag("offline_save_succeeds", data.Save(p, 74002) == true)
		flag(
			"offline_at_saved_unix_timestamp",
			saved ~= nil and type(saved.OfflineAt) == "number" and saved.OfflineAt == clock and saved.Version == 7
		)
		local afterSave = player("ReconnectAfterSave")
		data.Load(afterSave, 74002)
		flag(
			"offline_save_does_not_replay_previous_absence",
			near(afterSave.leaderstats.Speed.Value, once, 0.002) and afterSave:GetAttribute("OfflineSpeed") == 0
		)
		clock = at
		for _, case in { { "Legacy", nil }, { "Future", at + 3600 }, { "Malformed", "bad" } } do
			initial = { Speed = 99, WorkshopLevel = 1, OfflineAt = case[2] }
			local legacy = player(case[1])
			data.Load(legacy, 74003, at)
			flag("offline_no_credit_" .. string.lower(case[1]), legacy.leaderstats.Speed.Value == 99)
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
					and failedClaim.leaderstats.Speed.Value <= 99
					and data.Save(failedClaim, 74005) == false
					and initial.OfflineAt == at - 3600
			)
		end
		data.SetStore(store)
		function store:GetAsync(_key)
			error("injected load failure")
		end
		local failed = player("Failed")
		flag(
			"offline_failed_load_no_credit_or_save",
			data.Load(failed, 74004, at) == false
				and failed.leaderstats.Speed.Value == 0
				and data.Save(failed, 74004) == false
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
		local expected = { rain = { 2, 1, 1 }, night = { 1, 2, 1.25 }, gold = { 1, 3, 1 } }
		for _, id in { "rain", "night", "gold" } do
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
			for _, event in { "", "night" } do
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
				local wantSpeed = route.Tracks[1].Npc.Config.Speed * (event == "night" and 1.25 or 1)
				flag(
					"weather_reaches_npc_track_start_" .. (event == "" and "clear" or event),
					start ~= nil and near(start.Speed, wantSpeed)
				)
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
				local sharedMesh = false
				for _, spec in catalog.All() do
					if not spec.Event and spec.Model ~= nil and spec.Model == eventCar.Model then
						sharedMesh = true
					end
				end
				flag("weather_variant_shares_existing_mesh_" .. event, sharedMesh)
				for _, active in { "", "rain", "night", "gold" } do
					weather.SetEvent(active, at)
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
						"weather_event_car_eligibility_" .. event .. "_" .. (active == "" and "clear" or active),
						active == event and rolled == eventCar.Id or active ~= event and rolled ~= eventCar.Id
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
		for _, active in { "", "rain", "night", "gold" } do
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
				"weather_filters_before_rng_" .. (active == "" and "clear" or active),
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
							"weather_catalog_roll_"
								.. candidate.Id
								.. "_"
								.. (active == "" and "clear" or active)
								.. "_"
								.. boundary,
							allowed and got == want or not allowed and got ~= candidate.Id
						)
					end
				else
					local got = gachaConfig.Roll({
						NextNumber = function()
							return 1
						end,
					}, 1, active)
					flag(
						"weather_catalog_catch_all_" .. (active == "" and "clear" or active),
						got == candidate.Id and candidate.Event == nil
					)
				end
			end
		end
		-- Event restrictions affect acquisition only. Every current car remains
		-- owned, equippable, indexed and serializable after its event ends.
		weather.SetEvent("", at)
		local inventory = fake("EntireCatalog", data, gacha)
		table.insert(extraPlayers, inventory)
		for _, spec in catalog.All() do
			flag("catalog_grant_" .. spec.Id, gacha.Grant(inventory, spec.Id) == true)
			flag(
				"catalog_equip_after_event_" .. spec.Id,
				gacha.Equip(inventory, spec.Id) == true
					and inventory:GetAttribute("EquippedCar") == spec.Id
					and near(gacha.SpeedMulti(inventory), spec.SpeedMulti)
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
	weather.SetEvent("")
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

return Tests
