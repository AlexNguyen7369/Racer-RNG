--!nonstrict
-- ui_friends_chip: the FRIENDS +N% chip in the bottom-right potion row (UiSpec.FriendsChip; docs/FRIENDS_BOOST_SPEC.md
-- sections 4-5, docs/HUD_LAYOUT_SPEC.md sections 5-6). Owned by ui-test-writer. Display only: nothing here fires a
-- remote or changes an attribute; the friends_* server fixtures (UiTestSetup) set the Studio override.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(script.Parent.UiSpec)
local UiResponsive = require(script.Parent.UiResponsive)

local Friends = {}

local lastSeen = nil -- { count, tag } of the previous ui_friends_chip run in this session (no rejoin between runs)

-- h: check, checkList, find, visible, player, pathOf, render, provider, viewports, viewport, contains, intersects,
-- rstr, realRect, waitGuis (UiScenarios' helpers). Returns { Scenarios }.
function Friends.Build(h)
	local cfg = Spec.FriendsChip
	local TOL = Spec.Tolerance

	local function R(x, y, w, hh)
		return { x = x, y = y, w = w, h = hh }
	end

	-- The weather icon's right edge (ProgressionUi placeCorner, modelled in UiResponsive.Progression): the potion row
	-- is anchored to it, so moving the corner moves the row.
	local function cornerX(vp)
		local node = UiResponsive.Progression(cfg.Weather, vp)
		return vp.X + node.Position.X.Offset
	end

	-- shortcut: the row's content is laid out live (UIListLayout + AutomaticSize X, not modelled by the solver), so at a
	-- simulated viewport each row element keeps its live offset from the bottom-right corner. Valid while nothing in
	-- the row scales with the viewport (a UIScale makes friends_layout_model_supported fail); model it then.
	local function rowRect(obj, vpSpec, vp)
		local live = h.realRect(obj)
		if not vpSpec.Size then
			return live
		end
		local lv = h.viewport()
		return R(live.x - cornerX(lv) + cornerX(vp), live.y - lv.Y + vp.Y, live.w, live.h)
	end

	local function rowScales(obj)
		local found, node = {}, obj
		while node and node:IsA("GuiObject") do
			for _, child in node:GetChildren() do
				if child:IsA("UIScale") and not Spec.TransientScales[child.Name] then
					table.insert(found, h.pathOf(child))
				end
			end
			node = node.Parent
		end
		return found
	end

	local function potionButtons(row)
		local list = {}
		for _, child in row and row:GetChildren() or {} do
			if child:IsA("GuiButton") and child.Visible then
				table.insert(list, child)
			end
		end
		return list
	end

	-- Every other reachable element the chip must stay clear of: Clear, each Guis entry's AlwaysOn, the persistent
	-- HUD buttons. The row and its own children are judged separately.
	local function others(row)
		local paths, seen = {}, {}
		local function add(path)
			if not seen[path] then
				seen[path] = true
				table.insert(paths, path)
			end
		end
		for _, path in cfg.Clear do
			add(path)
		end
		for guiName, gui in Spec.Guis do
			for _, rel in gui.AlwaysOn or {} do
				add(guiName .. "/" .. rel)
			end
		end
		for _, path in Spec.PanelDimmers.PersistentButtons do
			add(path)
		end
		local list = {}
		for _, path in paths do
			local obj = h.find(path)
			if
				obj
				and obj:IsA("GuiObject")
				and h.visible(obj)
				and not (row and (obj == row or obj:IsAncestorOf(row) or row:IsAncestorOf(obj)))
			then
				table.insert(list, { path = path, obj = obj })
			end
		end
		return list
	end

	-- Phone = viewport height <= PhoneMaxHeight (owner 2026-10-30, HUD_LAYOUT_SPEC section 5): the chip is hidden there
	-- whatever the count; the boost attributes are unchanged.
	local function isPhone(vp)
		return vp.Y <= cfg.PhoneMaxHeight
	end

	local function chipState(chip, shown, want)
		if not chip then
			return false
		end
		if shown then
			return h.visible(chip) and chip.Text == want
		end
		return chip.Visible == false
	end

	local function waitFor(seconds, fn)
		local t0 = os.clock()
		while not fn() and os.clock() - t0 < seconds do
			task.wait(0.05)
		end
		return fn()
	end

	-- Bounds of the shown potion buttons at this viewport: leftmost x, rightmost right edge, highest top, lowest bottom.
	local function potionBounds(rects)
		if #rects == 0 then
			return nil
		end
		local b = { left = math.huge, right = -math.huge, top = math.huge, bottom = -math.huge }
		for _, r in rects do
			b.left = math.min(b.left, r.x)
			b.right = math.max(b.right, r.x + r.w)
			b.top = math.min(b.top, r.y)
			b.bottom = math.max(b.bottom, r.y + r.h)
		end
		return b
	end

	-- The DailyBoosts status line's home at this (non-phone) viewport: BoostDailyUi placeStatus, AnchorPoint (1, 0),
	-- Position (1, -Right, 1, -Bottom), Width x Height. It never moves for the chip (owner 2026-10-30).
	local function statusRect(vp)
		local st = cfg.Status
		return R(vp.X - st.Right - st.Width, vp.Y - st.Bottom, st.Width, st.Height)
	end

	-- Which of the two allowed placements (owner 2026-10-30, HUD_LAYOUT_SPEC section 5) a chip rect is in:
	-- "row" = left of every shown potion icon; "stacked" = bottom at least StackGap above the status line's top (sr) and
	-- right edge aligned with the rightmost icon's right edge. Anything else is "neither". No potions: only "row" exists.
	local function placementOf(cr, pb, sr)
		if not pb then
			return "row"
		end
		if cr.x + cr.w <= pb.left + TOL then
			return "row"
		end
		if cr.y + cr.h <= sr.y - cfg.StackGap + TOL and math.abs(cr.x + cr.w - pb.right) <= TOL then
			return "stacked"
		end
		return "neither"
	end

	local function geometry(res, chip, row)
		local potions = potionButtons(row)
		-- The stacked chip is reparented out of the row, so the row's own scales are collected as well
		local scales = rowScales(chip)
		for _, path in rowScales(row) do
			if not table.find(scales, path) then
				table.insert(scales, path)
			end
		end
		local weather = h.find(cfg.Weather)
		local list = others(row)
		local layout = row:FindFirstChildWhichIsA("UIListLayout")
		local pad = layout and layout.Padding.Offset or 0
		local liveRects = {}
		for _, b in potions do
			table.insert(liveRects, h.realRect(b))
		end
		local liveVp = h.viewport()
		local livePlacement = placementOf(h.realRect(chip), potionBounds(liveRects), statusRect(liveVp))
		-- Only the row placement lives inside PotionStatus; the stacked chip is reparented out of it (owner 2026-10-30)
		if livePlacement ~= "stacked" then
			h.check(
				res,
				"friends_chip_in_row",
				h.rstr(h.realRect(chip)),
				h.rstr(h.realRect(row)),
				h.contains(h.realRect(row), h.realRect(chip))
			)
		end
		-- The status line keeps its home whatever the chip does (HUD_LAYOUT_SPEC section 5)
		local statusObj = h.find(cfg.Status.Path)
		local liveStatus = statusRect(liveVp)
		local sReal = statusObj and h.realRect(statusObj)
		h.check(
			res,
			"friends_status_line_home_current",
			sReal and h.rstr(sReal) or "missing",
			h.rstr(liveStatus),
			sReal ~= nil
				and math.abs(sReal.x - liveStatus.x) <= TOL
				and math.abs(sReal.y - liveStatus.y) <= TOL
				and math.abs(sReal.w - liveStatus.w) <= TOL
				and math.abs(sReal.h - liveStatus.h) <= TOL
		)
		for _, vpSpec in h.viewports do
			local rectOf, vp, ctx = h.provider(vpSpec)
			if isPhone(vp) then
				-- The chip is hidden on phones (checked live by friends_chip_hidden_phone_*); nothing to place
				continue
			end
			local suffix = "_" .. vpSpec.Name
			local screen = R(0, 0, vp.X, vp.Y)
			local pRects = {}
			for _, b in potions do
				table.insert(pRects, { name = b.Name, r = rowRect(b, vpSpec, vp) })
			end
			local plain = {}
			for _, p in pRects do
				table.insert(plain, p.r)
			end
			local pb = potionBounds(plain)
			local wr = weather and h.visible(weather) and rectOf(weather)
			if wr == false then
				wr = nil
			end
			local sr = statusRect(vp)
			-- Both candidate rects at this viewport, with the chip's live size. Row: the live rect when the chip is in the
			-- row (rowRect), else built from the icons and the row's layout padding. Stacked: the live rect only at the
			-- live viewport; at a simulated one it is built from the status line there (bottom StackGap above its top)
			-- and the rightmost icon's right edge, since the stacked chip follows the status line, not the row.
			local live = rowRect(chip, vpSpec, vp)
			local w, hh = live.w, live.h
			local cand = {}
			if not vpSpec.Size or livePlacement ~= "stacked" then
				cand[livePlacement] = live
			end
			if pb then
				cand.row = cand.row or R(pb.left - pad - w, pb.bottom - hh, w, hh)
				cand.stacked = cand.stacked or R(pb.right - w, sr.y - cfg.StackGap - hh, w, hh)
			end
			-- Problems of a rect against the screen, the potions, the weather icon and the other HUD
			local function problems(cr)
				local out = { potions = {}, hud = {} }
				out.onScreen = h.contains(screen, cr)
				for _, p in pRects do
					if h.intersects(cr, p.r) then
						table.insert(out.potions, p.name .. h.rstr(p.r))
					end
				end
				out.weatherClear = wr ~= nil and not h.intersects(cr, wr)
				for _, o in list do
					local orr = rectOf(o.obj)
					if h.intersects(cr, orr) then
						table.insert(out.hud, o.path .. h.rstr(orr))
					end
				end
				out.clear = out.onScreen and #out.potions == 0 and out.weatherClear and #out.hud == 0
				return out
			end
			-- In the row whenever that is clear (or no potions are shown); stacked above only when the row is not
			local rowCand = cand.row
			local rowClear = rowCand ~= nil and problems(rowCand).clear
			local expected = (not pb or rowClear) and "row" or "stacked"
			if not vpSpec.Size then
				h.check(res, "friends_chip_placement" .. suffix, livePlacement, expected, livePlacement == expected)
			end
			if vpSpec.Name == cfg.RowRequiredAt and pb then
				h.check(
					res,
					"friends_chip_row_fits" .. suffix,
					rowCand and h.rstr(rowCand) or "no row rect",
					"in the row, clear of every element",
					rowClear
				)
			end
			local cr = (vpSpec.Size and cand[expected]) or live
			local p = problems(cr)
			h.check(res, "friends_chip_on_screen" .. suffix, h.rstr(cr), h.rstr(screen), p.onScreen)
			if expected == "row" then
				local notLeft = {}
				for _, q in pRects do
					if cr.x + cr.w > q.r.x + TOL then
						table.insert(notLeft, q.name .. h.rstr(q.r))
					end
				end
				h.checkList(res, "friends_chip_left_of_potions" .. suffix, notLeft)
			else
				h.check(
					res,
					"friends_chip_above_potions" .. suffix,
					h.rstr(cr),
					("bottom <= %d"):format(pb.top),
					cr.y + cr.h <= pb.top + TOL
				)
				h.check(
					res,
					"friends_chip_above_status" .. suffix,
					h.rstr(cr),
					("bottom <= %d (%s top %d - gap %d)"):format(
						sr.y - cfg.StackGap,
						cfg.Status.Path,
						sr.y,
						cfg.StackGap
					),
					cr.y + cr.h <= sr.y - cfg.StackGap + TOL
				)
				h.check(
					res,
					"friends_chip_right_aligned" .. suffix,
					cr.x + cr.w,
					pb.right,
					math.abs(cr.x + cr.w - pb.right) <= TOL
				)
			end
			h.checkList(res, "friends_chip_clear_of_potions" .. suffix, p.potions)
			h.check(
				res,
				"friends_chip_clear_of_weather" .. suffix,
				h.rstr(cr),
				wr and h.rstr(wr) or "weather icon not shown",
				p.weatherClear
			)
			h.checkList(res, "friends_chip_clear_of_hud" .. suffix, p.hud)
			local unsupported = table.clone(scales)
			for path, what in ctx and ctx.unsupported or {} do
				for _, o in list do
					if path == o.path or string.sub(path, 1, #o.path + 1) == o.path .. "/" then
						table.insert(unsupported, path .. ": " .. tostring(what))
						break
					end
				end
			end
			h.checkList(res, "friends_layout_model_supported" .. suffix, unsupported)
		end
	end

	local scenarios = {}
	scenarios.ui_friends_chip = function(res)
		h.waitGuis()
		h.render()
		local fixture = ReplicatedStorage:GetAttribute(cfg.FixtureAttr)
		local fx = fixture and cfg.Fixtures[fixture] or nil
		local tag = fx and fixture or "rest"
		local override = ReplicatedStorage:GetAttribute(cfg.Override)
		local p = h.player

		if fx and fx.Count then
			h.check(res, "friends_override_set_" .. tag, override, fx.Count, override == fx.Count)
			-- The server refreshes the attributes at once (spec section 5); allow replication time
			waitFor(2, function()
				return p:GetAttribute(cfg.CountAttr) == fx.Count
			end)
		elseif fx and fx.Restored then
			h.check(res, "friends_override_restored", override, "nil", override == nil)
		end
		local count, boost = p:GetAttribute(cfg.CountAttr), p:GetAttribute(cfg.BoostAttr)
		h.check(res, "friends_count_attr_" .. tag, count, "number >= 0", type(count) == "number" and count >= 0)
		h.check(res, "friends_boost_attr_" .. tag, boost, "number >= 1", type(boost) == "number" and boost >= 1)
		local n = type(count) == "number" and count or 0
		if type(boost) == "number" then
			local want = cfg.Boost(n)
			h.check(res, "friends_boost_matches_count_" .. tag, boost, want, math.abs(boost - want) < 1e-6)
		end
		if fx and fx.Count then
			h.check(res, "friends_count_matches_override_" .. tag, count, fx.Count, count == fx.Count)
		end
		local want = n > 0 and type(boost) == "number" and cfg.Text:format(math.floor((boost - 1) * 100 + 0.5)) or nil

		-- In the row, or reparented to the row's ScreenGui while stacked (StackedChip); exactly one of the two
		local inRow, stackedChip = h.find(cfg.Chip), h.find(cfg.StackedChip)
		local chip = inRow or stackedChip
		local row = h.find(cfg.Row)
		h.check(
			res,
			"friends_chip_present_" .. tag,
			chip
					and (h.pathOf(chip) .. " " .. chip.ClassName .. (inRow and stackedChip and " (and a second one)" or ""))
				or "missing",
			cfg.Chip .. " or " .. cfg.StackedChip .. " " .. cfg.Class,
			chip ~= nil
				and not (inRow and stackedChip)
				and chip:IsA(cfg.Class)
				and (chip.Parent == row or (row ~= nil and chip.Parent == row:FindFirstAncestorWhichIsA("ScreenGui")))
		)
		if chip then
			h.check(
				res,
				"friends_chip_display_only_" .. tag,
				chip.ClassName .. " Active=" .. tostring(chip:IsA("GuiObject") and chip.Active),
				"not a GuiButton, not Active",
				not chip:IsA("GuiButton") and not (chip:IsA("GuiObject") and chip.Active)
			)
		end
		local phone = isPhone(h.viewport())
		local shown = n > 0 and not phone
		local ok = waitFor(cfg.FollowSeconds, function()
			return chipState(chip, shown, want)
		end)
		h.render()
		if shown then
			h.check(
				res,
				"friends_chip_shown_" .. tag,
				chip and h.visible(chip) or false,
				true,
				chip ~= nil and h.visible(chip)
			)
			h.check(res, "friends_chip_text_" .. tag, chip and chip.Text or "missing", want or "nil", ok)
			if fx and fx.Text then
				h.check(res, "friends_chip_text_spec_" .. tag, want or "nil", fx.Text, want == fx.Text)
			end
		else
			local vpNow = h.viewport()
			h.check(
				res,
				(n > 0 and "friends_chip_hidden_phone_" or "friends_chip_hidden_") .. tag,
				("%s at %dx%d, friends %d"):format(chip and tostring(chip.Visible) or "missing", vpNow.X, vpNow.Y, n),
				false,
				chip ~= nil and chip.Visible == false
			)
			-- The row looks as before: shown exactly when a potion is, and only as wide as the potions
			local potions = potionButtons(row)
			local rowShown = row ~= nil and h.visible(row)
			h.check(
				res,
				"friends_row_shown_only_with_potions_" .. tag,
				rowShown,
				#potions > 0,
				rowShown == (#potions > 0)
			)
			if row and rowShown then
				local layout = row:FindFirstChildWhichIsA("UIListLayout")
				local pad = layout and layout.Padding.Offset or 0
				local w = 0
				for i, b in potions do
					w += b.AbsoluteSize.X + (i > 1 and pad or 0)
				end
				h.check(
					res,
					"friends_row_width_unchanged_" .. tag,
					row.AbsoluteSize.X,
					w,
					math.abs(row.AbsoluteSize.X - w) <= TOL
				)
			end
		end
		if fx and fx.Potions then
			local potions = potionButtons(row)
			h.check(res, "friends_potions_shown_" .. tag, #potions, ">= 1", #potions >= 1)
		end
		if lastSeen and lastSeen.count ~= n then
			h.check(
				res,
				"friends_chip_follows_change_" .. tag,
				("%s(%d) -> %d: %s"):format(lastSeen.tag, lastSeen.count, n, ok and "followed" or "stale"),
				"followed, same session",
				ok
			)
		end
		lastSeen = { count = n, tag = tag }
		if shown and chip and row and h.visible(chip) then
			geometry(res, chip, row)
		end
	end
	return { Scenarios = scenarios }
end

return Friends
