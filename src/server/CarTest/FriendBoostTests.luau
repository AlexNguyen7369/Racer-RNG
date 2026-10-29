--!nonstrict
-- BRIEF: docs/FRIENDS_BOOST_SPEC.md (owner 2026-10-28). FriendBoost = 1 + min(0.1 x friends, 0.4) multiplies
-- GachaService.Luck and MoneyMulti (so MoneyService.Quote); never Speed gain or cruise speed. Studio override
-- ReplicatedStorage attribute FriendBoostTestCount; player attributes FriendsInServer / FriendBoost.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Tests = {}

local EPS = 1e-9
local ATTR = "FriendBoostTestCount"

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or EPS)
end

function Tests.friends_boost()
	local r, flag = H.report("friends_boost")
	local service = H.module(Server, "FriendBoostService")
	flag("friend_boost_service_exists", service ~= nil)
	if not service then
		return r
	end
	local Gacha = require(Server.GachaService)
	local Money = require(Server.MoneyService)
	local RaceConfig = require(Shared.RaceConfig)
	local saved = ReplicatedStorage:GetAttribute(ATTR)
	local cleanup = {}
	local ok, err = pcall(function()
		-- MultiFor curve (spec section 2)
		local expected = { [0] = 1.0, 1.1, 1.2, 1.3, 1.4, 1.4 }
		for n = 0, 5 do
			local got = service.MultiFor(n)
			flag("multi_for_" .. n, near(got, expected[n]), got, expected[n])
		end
		flag("multi_for_nan", service.MultiFor(0 / 0) == 1, service.MultiFor(0 / 0), 1)
		flag("multi_for_negative", service.MultiFor(-1) == 1, service.MultiFor(-1), 1)
		flag("multi_for_string", service.MultiFor("3") == 1)
		flag("multi_for_nil", service.MultiFor(nil) == 1)
		flag("multi_for_inf", near(service.MultiFor(math.huge), 1.4), service.MultiFor(math.huge), 1.4)

		-- Luck / Money stack (spec section 3) on a fake player; weather is cleared by the harness
		local player = H.player(cleanup, 997701)
		Money.Setup(player)
		local pad = Instance.new("Part")
		pad.Name = "CarTestFriendPad"
		pad.Anchored, pad.CanCollide, pad.Transparency = true, false, 1
		pad.Position = Vector3.new(0, -500, 0)
		pad:SetAttribute("Cash", 1000000)
		CollectionService:AddTag(pad, "WinPad")
		pad.Parent = workspace
		table.insert(cleanup, pad)
		local function sample(count)
			ReplicatedStorage:SetAttribute(ATTR, count)
			local stat = 1000
			return {
				luck = Gacha.Luck(player),
				money = Gacha.MoneyMulti(player),
				quote = Money.Quote(player, pad),
				speedMulti = Gacha.SpeedMulti(player),
				cruise = RaceConfig.SpeedFor(stat, Gacha.CruiseMultis(player)),
				cruise0 = RaceConfig.SpeedFor(0, Gacha.CruiseMultis(player)),
				multi = service.Multi(player),
			}
		end
		local s0, s3, s5 = sample(0), sample(3), sample(5)
		flag("multi_override_0", near(s0.multi, 1), s0.multi, 1)
		flag("multi_override_3", near(s3.multi, 1.3), s3.multi, 1.3)
		flag("multi_override_5", near(s5.multi, 1.4), s5.multi, 1.4)
		local function ratio(a, b)
			return b ~= 0 and a / b or 0
		end
		flag("luck_x1_3_at_3", near(ratio(s3.luck, s0.luck), 1.3, 1e-9), ratio(s3.luck, s0.luck), 1.3)
		flag("luck_x1_4_at_5", near(ratio(s5.luck, s0.luck), 1.4, 1e-9), ratio(s5.luck, s0.luck), 1.4)
		flag("money_multi_x1_3_at_3", near(ratio(s3.money, s0.money), 1.3, 1e-9), ratio(s3.money, s0.money), 1.3)
		flag("money_multi_x1_4_at_5", near(ratio(s5.money, s0.money), 1.4, 1e-9), ratio(s5.money, s0.money), 1.4)
		-- Quote floors cash x multi, so allow 1 unit of rounding on a 1e6 pad
		flag("quote_positive", s0.quote > 0, s0.quote, 1)
		flag("quote_x1_3_at_3", near(s3.quote, s0.quote * 1.3, 1), s3.quote, s0.quote * 1.3)
		flag("quote_x1_4_at_5", near(s5.quote, s0.quote * 1.4, 1), s5.quote, s0.quote * 1.4)
		-- never Speed gain or cruise (spec section 3)
		flag(
			"speed_multi_unchanged",
			s0.speedMulti == s3.speedMulti and s0.speedMulti == s5.speedMulti,
			s5.speedMulti,
			s0.speedMulti
		)
		flag("cruise_unchanged", s0.cruise == s3.cruise and s0.cruise == s5.cruise, s5.cruise, s0.cruise)
		flag("cruise_base_unchanged", s0.cruise0 == s5.cruise0, s5.cruise0, s0.cruise0)

		-- Attributes on real players refresh with the override (spec sections 4-5)
		local real = Players:GetPlayers()
		flag("attr_real_player_present", #real > 0, #real, 1)
		for count, multi in { [0] = 1, [3] = 1.3, [5] = 1.4 } do
			ReplicatedStorage:SetAttribute(ATTR, count)
			task.wait() -- deferred signals
			for _, p in real do
				local fc, fb = p:GetAttribute("FriendsInServer"), p:GetAttribute("FriendBoost")
				flag(("attr_friends_in_server_%d_%s"):format(count, p.Name), fc == count, fc, count)
				flag(("attr_friend_boost_%d_%s"):format(count, p.Name), near(fb, multi), fb, multi)
			end
		end

		-- IsFriendsWith failure: the pair check is a private task with no injection point
		r.metrics.skipped_is_friends_with_error =
			"FriendBoostService exposes no stub for IsFriendsWith (check/onAdded are local); pcall path untested"
	end)
	ReplicatedStorage:SetAttribute(ATTR, saved)
	task.wait()
	flag("override_restored", ReplicatedStorage:GetAttribute(ATTR) == saved)
	for _, inst in cleanup do
		inst:Destroy()
	end
	if not ok then
		flag("friends_boost_no_error", false, tostring(err), 0)
	end
	return r
end

return Tests
