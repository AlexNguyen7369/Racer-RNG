--!nonstrict
-- BRIEF: docs/QUESTS_SPEC.md (incl. "Rotation", owner 2026-10-30), docs/GAME_DESIGN_REQUIREMENTS.md "Progression"
-- (quests never pay Money), docs/SAVE_SPEC.md. Each UTC day / week QuestConfig.Active(weekly, now) picks
-- QuestConfig.PICK (3) quests from a 6-Id pool, seeded only by the period key; progress and claims count only for
-- active quests; rewards are potion items granted through BoostService. Pool values are placeholders (read from
-- QuestConfig); the 6 Ids per pool in the spec tables are permanent save keys and must exist.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Tests = {}

local DAILY_IDS = {
	"daily_races",
	"daily_rolls",
	"daily_discover",
	"daily_races_long",
	"daily_rolls_long",
	"daily_potions",
}
local WEEKLY_IDS = {
	"weekly_races",
	"weekly_discover",
	"weekly_potions",
	"weekly_races_long",
	"weekly_rolls",
	"weekly_discover_long",
}
local METRICS = { Races = true, Rolls = true, Discoveries = true, Potions = true }
-- Fixed instants (no os.time()) so the rotation checks are deterministic: 2026-01-01 00:00 UTC + offsets.
local BASE = 1767225600
local DAY = 86400

local function ids(quests)
	local out = {}
	if type(quests) == "table" then
		for _, quest in quests do
			table.insert(out, type(quest) == "table" and quest.Id or tostring(quest))
		end
	end
	return out
end

local function inPool(pool, id)
	for _, quest in pool do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

local function checkPool(flag, BoostConfig, label, pool, expected)
	flag(label .. "_pool_size", type(pool) == "table" and #pool == #expected, type(pool) == "table" and #pool or -1, 6)
	if type(pool) ~= "table" then
		return
	end
	for _, id in expected do
		flag(label .. "_has_" .. id, inPool(pool, id) ~= nil)
	end
	local metricsOk, rewardsOk, targetsOk, unique, seen = true, true, true, true, {}
	for _, quest in pool do
		metricsOk = metricsOk and METRICS[quest.Metric] == true
		targetsOk = targetsOk and type(quest.Target) == "number" and quest.Target >= 1
		local reward = quest.Reward
		rewardsOk = rewardsOk
			and type(reward) == "string"
			and reward ~= "Money"
			and BoostConfig.Get(reward) ~= nil
			and type(quest.RewardCount) == "number"
			and quest.RewardCount >= 1
			and quest.Money == nil
			and quest.RewardMoney == nil
		unique = unique and not seen[quest.Id]
		seen[quest.Id] = true
	end
	flag(label .. "_metrics_known", metricsOk)
	flag(label .. "_targets_positive", targetsOk)
	flag(label .. "_rewards_are_potions", rewardsOk)
	flag(label .. "_ids_unique", unique)
end

local function checkRotation(flag, Config, label, weekly, pool, period)
	local function active(now)
		local ok, value = pcall(Config.Active, weekly, now)
		return ok and type(value) == "table" and value or nil
	end
	local a = active(BASE + 3600)
	local okShape = a ~= nil and #a == Config.PICK
	flag(label .. "_active_pick_count", okShape, a and #a or -1, Config.PICK)
	if not a then
		return
	end
	local distinct, fromPool, seen = true, true, {}
	for _, quest in a do
		distinct = distinct and not seen[quest.Id]
		seen[quest.Id] = true
		fromPool = fromPool and inPool(pool, quest.Id) == quest
	end
	flag(label .. "_active_distinct", distinct)
	flag(label .. "_active_from_pool", fromPool)
	-- Same period: start and the last second of the period give the same pick.
	local key = Config.PeriodKey(BASE + 3600, weekly)
	local startOf, endOf = BASE + 3600, BASE + 3600
	while Config.PeriodKey(startOf - 1, weekly) == key do
		startOf -= 3600
	end
	while Config.PeriodKey(endOf + 3600, weekly) == key do
		endOf += 3600
	end
	local first, last = active(startOf), active(endOf)
	flag(
		label .. "_same_period_same_pick",
		first ~= nil and H.same(ids(first), ids(last)) and H.same(ids(first), ids(a))
	)
	flag(label .. "_deterministic", H.same(ids(active(BASE + 3600)), ids(a)))
	-- Across many periods the pick changes and more than PICK Ids appear.
	local union, count, changes, previous = {}, 0, 0, nil
	for i = 0, 29 do
		local pick = active(BASE + 3600 + i * period)
		local list = ids(pick)
		for _, id in list do
			if not union[id] then
				union[id] = true
				count += 1
			end
		end
		if previous and not H.same(previous, list) then
			changes += 1
		end
		previous = list
	end
	flag(label .. "_rotation_varies", count > Config.PICK and changes > 0, count, Config.PICK + 1)
end

function Tests.quests()
	local r, flag = H.report("quests")
	local Config = H.module(Shared, "QuestConfig")
	local Quest = H.module(Server, "QuestService")
	local Boost = H.module(Server, "BoostService")
	local BoostConfig = H.module(Shared, "BoostConfig")
	flag("quest_config_exists", Config ~= nil)
	flag("quest_service_exists", Quest ~= nil)
	flag("boost_service_exists", Boost ~= nil)
	if not (Config and Quest and Boost and BoostConfig) then
		return r
	end
	checkPool(flag, BoostConfig, "daily", Config.Daily, DAILY_IDS)
	checkPool(flag, BoostConfig, "weekly", Config.Weekly, WEEKLY_IDS)
	flag("pick_is_3", Config.PICK == 3, Config.PICK, 3)
	flag("active_exists", type(Config.Active) == "function")
	if type(Config.Active) ~= "function" then
		return r
	end
	checkRotation(flag, Config, "daily", false, Config.Daily, DAY)
	checkRotation(flag, Config, "weekly", true, Config.Weekly, 7 * DAY)

	local cleanup = {}
	local savedCooldown = Quest.REMOTE_COOLDOWN
	local ok, err = pcall(function()
		Quest.REMOTE_COOLDOWN = 0
		local now = os.time()
		local player = H.player(cleanup, 997801)
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local money = Instance.new("NumberValue")
		money.Name = "Money"
		money.Value = 12345
		money.Parent = stats
		stats.Parent = player
		Boost.Setup(player)
		Quest.Setup(player)
		local active = Config.Active(false, now)
		local activeSet = {}
		for _, quest in active do
			activeSet[quest.Id] = true
		end
		local inactive
		for _, quest in Config.Daily do
			if not activeSet[quest.Id] then
				inactive = quest
				break
			end
		end
		flag("daily_has_inactive_quest", inactive ~= nil)
		local target = active[1]

		-- Incomplete claim is rejected.
		local claimedEarly = Quest.Claim(player, false, target.Id)
		flag("claim_incomplete_rejected", claimedEarly == false)

		-- Progress counts only for active quests.
		for metric in METRICS do
			Quest.Progress(player, metric, 1000)
		end
		local snap = Quest.Snapshot(player)
		local activeFull = true
		for _, quest in active do
			activeFull = activeFull and (snap.QuestDaily[quest.Id] or 0) >= quest.Target
		end
		flag("progress_counts_active", activeFull)
		local leak = 0
		for _, quest in Config.Daily do
			if not activeSet[quest.Id] then
				leak += snap.QuestDaily[quest.Id] or 0
			end
		end
		flag("progress_ignores_inactive", leak == 0, leak, 0)

		-- Inactive quest with saved full progress still cannot be claimed.
		if inactive then
			local saved = Quest.Snapshot(player)
			saved.QuestDaily[inactive.Id] = inactive.Target
			Quest.Apply(player, saved)
			local before = Boost.Count(player, inactive.Reward)
			local claimed = Quest.Claim(player, false, inactive.Id)
			flag("claim_inactive_rejected", claimed == false)
			flag("claim_inactive_no_potion", Boost.Count(player, inactive.Reward) == before)
		end

		-- Valid claim grants the potion via BoostService; Money never changes.
		local before = Boost.Count(player, target.Reward)
		local claimed = Quest.Claim(player, false, target.Id)
		flag("claim_valid_accepted", claimed == true)
		local after = Boost.Count(player, target.Reward)
		flag("claim_grants_potion", after - before == target.RewardCount, after - before, target.RewardCount)
		flag("claim_money_unchanged", money.Value == 12345, money.Value, 12345)
		local again = Quest.Claim(player, false, target.Id)
		flag("claim_twice_rejected", again == false)
		flag("claim_twice_no_potion", Boost.Count(player, target.Reward) == after)

		-- Save round-trip of the quest fields (Snapshot -> Apply -> Snapshot).
		local saved = H.copy(Quest.Snapshot(player))
		local other = H.player(cleanup, 997802)
		Boost.Setup(other)
		Quest.Setup(other)
		Quest.Apply(other, H.copy(saved))
		flag("save_round_trip", H.same(Quest.Snapshot(other), saved))
		local fields = {
			"QuestDailyKey",
			"QuestWeeklyKey",
			"QuestDaily",
			"QuestWeekly",
			"QuestDailyClaimed",
			"QuestWeeklyClaimed",
		}
		local hasAll = true
		for _, name in fields do
			hasAll = hasAll and saved[name] ~= nil
		end
		flag("save_has_quest_fields", hasAll)

		-- UTC reset: a save from earlier periods loads with empty progress and claims.
		local stale = H.copy(saved)
		stale.QuestDailyKey = Config.PeriodKey(now) - 1
		stale.QuestWeeklyKey = Config.PeriodKey(now, true) - 1
		stale.QuestWeekly = { [Config.Weekly[1].Id] = 1 }
		stale.QuestWeeklyClaimed = { [Config.Weekly[1].Id] = 1 }
		Quest.Apply(other, stale)
		local fresh = Quest.Snapshot(other)
		flag(
			"reset_daily_key",
			fresh.QuestDailyKey == Config.PeriodKey(now),
			fresh.QuestDailyKey,
			Config.PeriodKey(now)
		)
		flag("reset_weekly_key", fresh.QuestWeeklyKey == Config.PeriodKey(now, true))
		flag("reset_daily_progress", next(fresh.QuestDaily) == nil and next(fresh.QuestDailyClaimed) == nil)
		flag("reset_weekly_progress", next(fresh.QuestWeekly) == nil and next(fresh.QuestWeeklyClaimed) == nil)
		flag("reset_reclaim_needs_progress", Quest.Claim(other, false, target.Id) == false)
	end)
	Quest.REMOTE_COOLDOWN = savedCooldown
	for _, item in cleanup do
		item:Destroy()
	end
	flag("quests_no_error", ok, ok and 1 or tostring(err), 1)
	return r
end

return Tests
