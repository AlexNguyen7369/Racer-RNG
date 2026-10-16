--!nonstrict
-- The Rebirth panel's live parts and the Bag / Daily Rewards gui (Client/BoostDailyUi): what they show against the
-- server's attributes and the config modules. Owned by ui-test-writer. Nothing here invokes a remote; the clicks
-- (UiSpec.Clicks rebirth_*, bag_*, daily_*) only run with the RemoteFunctions intercepted (Prepare.Intercept).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoostConfig = require(Shared:WaitForChild("BoostConfig"))
local DailyLoginConfig = require(Shared:WaitForChild("DailyLoginConfig"))
local RebirthConfig = require(Shared:WaitForChild("RebirthConfig"))
local Spec = require(script.Parent.UiSpec)

local Extras = {}

-- h: check, checkList, find, visible, setPanels, player. Returns { Scenarios, After, Snapshot, BoostToken }.
function Extras.Build(h)
	local RB, DB = Spec.Rebirth, Spec.DailyBoosts
	local scenarios, after = {}, {}

	local function attr(name)
		return h.player:GetAttribute(name)
	end
	local function has(text, piece)
		return string.find(text, piece, 1, true) ~= nil
	end
	local function today()
		return math.floor(os.time() / 86400)
	end

	-- Rebirth -------------------------------------------------------------------------------------------------

	local function rebirthTruth()
		local level = attr("RebirthLevel") or 0
		local percent = function(perLevel)
			return math.floor((level + 1) * perLevel * 100 + 0.5)
		end
		return {
			eligible = RebirthConfig.CanRebirth(level, attr("Level") or 1) and level < RebirthConfig.MAX_LEVEL,
			pieces = {
				{ "level", RB.LevelText:format(level) },
				{ "next_speed_bonus", RB.SpeedText:format(percent(RebirthConfig.GAIN_PER_LEVEL)) },
				{ "next_luck_bonus", RB.LuckText:format(percent(RebirthConfig.LUCK_GAIN_PER_LEVEL)) },
				{ "resets_money_and_speed", RB.ResetText },
				{ "required_level", RB.RequiredText:format(RebirthConfig.Requirements(level).Level) },
			},
		}
	end

	local function rebirthStatus(res)
		local status = h.find(RB.Status)
		local text = status and status:IsA("TextLabel") and status.Text or "missing"
		for _, piece in rebirthTruth().pieces do
			h.check(res, "rebirth_status_" .. piece[1], text, "contains " .. piece[2], has(text, piece[2]))
		end
	end

	function scenarios.ui_rebirth(res)
		local restore = h.setPanels({ "RacerRebirth/Panel" })
		local title = h.find(RB.Title)
		local titleText = title and title:IsA("TextLabel") and title.Text or "missing"
		h.check(res, "rebirth_title", titleText, RB.TitleText, titleText == RB.TitleText)
		local placeholder = h.find(RB.Placeholder)
		local placeholderShown = placeholder ~= nil and placeholder:IsA("GuiObject") and h.visible(placeholder)
		h.check(res, "rebirth_coming_soon_not_shown", placeholderShown, false, not placeholderShown)
		local status = h.find(RB.Status)
		local statusShown = status ~= nil and status:IsA("TextLabel") and h.visible(status)
		h.check(res, "rebirth_status_shown", statusShown, true, statusShown)
		rebirthStatus(res)
		local button = h.find(RB.Button)
		local isButton = button ~= nil and button:IsA("TextButton")
		h.check(res, "rebirth_button_present", button and button.ClassName or "missing", "TextButton", isButton)
		if isButton then
			h.check(res, "rebirth_button_shown", h.visible(button), true, h.visible(button))
			h.check(res, "rebirth_button_label", button.Text, RB.ButtonText, button.Text == RB.ButtonText)
			local eligible = rebirthTruth().eligible
			h.check(res, "rebirth_button_enabled_matches_server", button.Active, eligible, button.Active == eligible)
		end
		restore()
	end

	-- After the (intercepted, refused) click: nothing was reset and the panel still shows the server's level
	function after.rebirth_not_optimistic(res, ctx)
		local level = attr("RebirthLevel") or 0
		h.check(res, "rebirth_level_unchanged", level, ctx.pre.RebirthLevel, level == ctx.pre.RebirthLevel)
		local stats = h.player:FindFirstChild("leaderstats")
		local money, speed = stats and stats:FindFirstChild("Money"), stats and stats:FindFirstChild("Speed")
		local moneyNow, speedNow = money and money.Value, speed and speed.Value
		h.check(
			res,
			"rebirth_money_not_reset",
			moneyNow,
			ctx.pre.ProgressionMoney,
			moneyNow == ctx.pre.ProgressionMoney
		)
		local kept = speedNow ~= nil and ctx.pre.Speed ~= nil and speedNow >= ctx.pre.Speed
		h.check(res, "rebirth_speed_not_reset", speedNow, ">= " .. tostring(ctx.pre.Speed), kept)
		rebirthStatus(res)
	end

	-- Bag / Daily Rewards ---------------------------------------------------------------------------------------

	-- The DailyRewardButton's text against the server's DailyLast. Returns shown, wanted, ok.
	local function dailyButton()
		local button = h.find(DB.Daily)
		local text = button and button:IsA("TextButton") and button.Text or "missing"
		if attr("DailyLast") ~= today() then
			return text, DB.DailyText[false], text == DB.DailyText[false]
		end
		local left = 86400 - os.time() % 86400
		local want = DB.DailyText[true]:format(math.floor(left / 3600), math.floor(left / 60) % 60, left % 60)
		local hh, mm, ss = string.match(text, "(%d%d):(%d%d):(%d%d)$")
		local shownLeft = hh and (tonumber(hh) * 3600 + tonumber(mm) * 60 + tonumber(ss))
		local prefix = string.sub(want, 1, #want - 8)
		local ok = shownLeft ~= nil
			and string.sub(text, 1, #prefix) == prefix
			and #text == #want
			and math.abs(shownLeft - left) <= DB.TimerTolerance
		return text, want, ok
	end

	local function modalView()
		local title = h.find(DB.Title)
		local text = title and title:IsA("TextLabel") and title.Text or ""
		-- "BAG • CONSUMABLES" / "DAILY REWARDS • 7 DAYS"
		return has(text, DB.DailyTitle) and "daily" or has(text, DB.BagTitle) and "bag" or "unknown", text
	end

	-- Where the Bag view differs from the server's inventory: one row per potion owned or active, nothing else.
	local function bagProblems()
		local view, title = modalView()
		local content = h.find(DB.Content)
		if view ~= "bag" or not content then
			return { ("modal shows %q, not the Bag"):format(title) }
		end
		local bad = {}
		for _, category in BoostConfig.Order do
			for _, item in BoostConfig.ItemsFor(category) do
				local count = attr("Boost_" .. item.Id) or 0
				local active = (attr("BoostUntil_" .. item.Id) or 0) > os.time()
				local row = content:FindFirstChild(item.Id)
				local label, use = row and row:FindFirstChild("Label"), row and row:FindFirstChild("Use")
				if count <= 0 and not active then
					if row then
						table.insert(bad, item.Id .. ": row shown with none owned")
					end
				elseif not (label and label:IsA("TextLabel") and use and use:IsA("TextButton")) then
					table.insert(bad, item.Id .. ": no row with Label and Use")
				else
					if not (has(label.Text, item.Name) and string.find(label.Text, "x" .. count .. "%f[%D]")) then
						table.insert(bad, ("%s: label %q, want %s x%d"):format(item.Id, label.Text, item.Name, count))
					end
					local usable = count > 0 and not active
					if use.Active ~= usable then
						table.insert(
							bad,
							("%s: Use Active=%s, want %s"):format(item.Id, tostring(use.Active), tostring(usable))
						)
					end
					local textOk = (active and has(use.Text, DB.ActiveText)) or (not active and use.Text == DB.UseText)
					if not textOk then
						table.insert(bad, ("%s: Use shows %q"):format(item.Id, use.Text))
					end
				end
			end
		end
		return bad
	end

	-- Where the Daily view differs from the server's DailyStreak / DailyLast.
	local function dailyProblems()
		local view, title = modalView()
		local content = h.find(DB.Content)
		if view ~= "daily" or not content then
			return { ("modal shows %q, not the Daily Rewards"):format(title) }
		end
		local bad = {}
		local days = #DailyLoginConfig.Rewards
		local streak = math.clamp(attr("DailyStreak") or 0, 0, days)
		local claimed = attr("DailyLast") == today()
		for day = 1, days do
			local row = content:FindFirstChild(DB.DayRow:format(day))
			if not (row and row:IsA("TextLabel") and has(row.Text, DB.DayText:format(day))) then
				table.insert(bad, ("day %d: no row"):format(day))
			elseif has(row.Text, DB.DoneMark) ~= (day <= streak) then
				table.insert(bad, ("day %d: %q with DailyStreak %d"):format(day, row.Text, streak))
			end
		end
		local claim = content:FindFirstChild("Claim")
		local want = claimed and DB.ClaimText[true] or DB.ClaimText[false]:format(math.min(streak + 1, days))
		if not (claim and claim:IsA("TextButton")) then
			table.insert(bad, "no Claim button")
		elseif claim.Text ~= want or claim.Active ~= not claimed then
			table.insert(
				bad,
				("Claim shows %q Active=%s, want %q Active=%s"):format(
					claim.Text,
					tostring(claim.Active),
					want,
					tostring(not claimed)
				)
			)
		end
		return bad
	end

	function scenarios.ui_daily_boosts(res)
		for _, part in
			{
				{ "bag_button", DB.Bag, "TextButton", "BAG" },
				{ "daily_button", DB.Daily, "TextButton" },
				{ "status", DB.Status, "TextLabel" },
				{ "modal", DB.Panel, "Frame" },
				{ "modal_title", DB.Title, "TextLabel" },
				{ "modal_close", DB.Close, "TextButton", "×" },
				{ "modal_content", DB.Content, "ScrollingFrame" },
			}
		do
			local o = h.find(part[2])
			local ok = o ~= nil and o.ClassName == part[3]
			h.check(res, "daily_boosts_part_" .. part[1], o and o.ClassName or "missing", part[3], ok)
			if ok and part[4] then
				h.check(res, "daily_boosts_text_" .. part[1], o.Text, part[4], o.Text == part[4])
			end
		end
		local text, want, ok = dailyButton()
		h.check(res, "daily_button_follows_server_daily_last", text, want, ok)
		-- Whatever the modal last rendered must be the server's truth (the clicks render and re-check each view)
		local view = modalView()
		if view == "daily" then
			h.checkList(res, "daily_view_matches_server", dailyProblems())
		elseif view == "bag" then
			-- The Bag re-renders once a second while shown; hidden, it keeps its last render (not judged)
			local panel = h.find(DB.Panel)
			if panel and panel:IsA("GuiObject") and h.visible(panel) then
				h.checkList(res, "bag_view_matches_server", bagProblems())
			end
		end
	end

	function after.bag_shows_server_inventory(res)
		h.checkList(res, "bag_shows_server_inventory", bagProblems())
	end
	function after.daily_shows_server_streak(res)
		h.checkList(res, "daily_shows_server_streak", dailyProblems())
		local text, want, ok = dailyButton()
		h.check(res, "daily_button_follows_server_daily_last", text, want, ok)
	end
	-- After the (intercepted, refused) click: the server's values are what they were
	function after.boost_not_optimistic(res, ctx)
		for _, key in { "Boost_" .. DB.FixtureBoost, "BoostUntil_" .. DB.FixtureBoost } do
			h.check(res, "unchanged_" .. string.lower(key), attr(key), ctx.pre[key], attr(key) == ctx.pre[key])
		end
	end
	function after.daily_not_optimistic(res, ctx)
		for _, key in { "DailyLast", "DailyStreak" } do
			h.check(res, "unchanged_" .. string.lower(key), attr(key), ctx.pre[key], attr(key) == ctx.pre[key])
		end
	end

	-- Extra values the click protocol remembers before a click (merged into its attribute snapshot).
	local function snapshot(into)
		local stats = h.player:FindFirstChild("leaderstats")
		local speed = stats and stats:FindFirstChild("Speed")
		into.Speed = speed and speed.Value
		into.RebirthLevel = attr("RebirthLevel") or 0
		for _, key in { "DailyLast", "DailyStreak", "Boost_" .. DB.FixtureBoost, "BoostUntil_" .. DB.FixtureBoost } do
			into[key] = attr(key)
		end
		return into
	end

	-- "{boost}" in a click path: the fixture's potion, when the server says the Bag has a row for it.
	local function boostToken()
		local id = DB.FixtureBoost
		if (attr("Boost_" .. id) or 0) > 0 or (attr("BoostUntil_" .. id) or 0) > os.time() then
			return id
		end
		return nil
	end

	return { Scenarios = scenarios, After = after, Snapshot = snapshot, BoostToken = boostToken }
end

return Extras
