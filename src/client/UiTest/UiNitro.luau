--!nonstrict
-- Timed nitro bar (docs/NITRO_SPEC.md; design doc "Timed nitro boost", proposed by Vic2CS 2026-11-19 and approved by
-- the developer for feature/vic2cs/dev-changes, not yet reviewed by the owner). Paths and limits: UiSpec.Nitro and
-- UiSpec.Guis.NitroBar; numbers from Shared/NitroConfig. Owned by ui-test-writer.
--   ui_nitro_bar   while auto racing (ServerSetup auto_racing): the bar shows, centred just above RacerHud/Speed, its
--                  FitScale following the short-screen rule (never into the compact roll), 340 x 34 px x FitScale;
--                  every promised label text fits the label; when ready the green / gold zones are drawn exactly
--                  where the server grades Good / Perfect, centred on the bar's NitroTarget, and no press marker is
--                  left; the needle sweeps on the server's clock; a press with the needle ON THE TARGET is Perfect
--                  (NitroUntil in the future, the recharge after it, the label shows the grade, the bar drains); the
--                  press marker shows at the server's NitroPressPos and takes no click; NitroTarget moves at least
--                  TARGET_MIN_MOVE at once, but the zones stay on the graded bar's target while boosting / charging;
--                  a press while boosting does nothing; when the boost ends the label shows the server's NitroSaved
--                  ("SAVED x s", Vic2CS 2026-11-20; at most NitroConfig.SavedSeconds(PERFECT_MULTI, DURATION)), then
--                  NITRO CHARGING, then READY with the zones on the new target and
--                  the marker gone; a press off the green is a Miss that locks the bar for MISS_COOLDOWN (= RECHARGE,
--                  Vic2CS 2026-11-20; label MISS,
--                  needle gone, marker shown, zones kept); a press while locked does nothing; when the lock ends the
--                  zones move again and the marker goes.
-- Presses the scenario can not make (a click / tap on the bar, Space, a click on the world, STOP AUTO / AUTO RACE) are
-- the UiSpec.Clicks nitro_* (UiTestClick protocol); their Prepare keys (Prepare) and After conditions (After) are here.
-- The scenario presses the way Client/NitroInput does: Remotes.Nitro(workspace:GetServerTimeNow()) at the moment the
-- needle is where it wants it. Nothing is saved (NITRO_SPEC "Authority"); a boost only speeds the current run for
-- NitroConfig.DURATION s. It opens no panel and puts back the ones it closed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Spec = require(script.Parent.UiSpec)

local Nitro = {}

function Nitro.Build(h)
	local cfg = Spec.Nitro
	local TOL = Spec.Tolerance
	local player = h.player
	local scenarios, after = {}, {}

	-- One record per graded press the server reported (NitroPresses changed): its grade, the server's press position
	-- and next target, and what the bar drew two frames later (label, press marker, zones)
	local records = {}

	local function config()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local m = shared and shared:FindFirstChild(cfg.Module)
		if not (m and m:IsA("ModuleScript")) then
			return nil
		end
		local ok, mod = pcall(require, m)
		return ok and type(mod) == "table" and mod or nil
	end
	local function now()
		return workspace:GetServerTimeNow()
	end
	local function attr(name)
		return player:GetAttribute(name)
	end
	local function readyAt()
		local v = attr("NitroReadyAt")
		return type(v) == "number" and v or nil
	end
	local function boostUntil()
		local v = attr("NitroUntil")
		return type(v) == "number" and v or 0
	end
	local function presses()
		return attr("NitroPresses") or 0
	end
	local function target()
		local v = attr("NitroTarget")
		return type(v) == "number" and v == v and v or nil
	end
	local function isReady()
		local r = readyAt()
		return r ~= nil and now() >= r and now() >= boostUntil()
	end
	local function labelText()
		local l = h.find(cfg.Label)
		return l and l:IsA("TextLabel") and l.Text or "missing"
	end
	local function startsWith(text, prefix)
		return type(text) == "string" and string.sub(text, 1, #prefix) == prefix
	end
	local function centreX(r)
		return r.x + r.w / 2
	end
	local function waitUntil(cond, seconds)
		local deadline = os.clock() + seconds
		while not cond() and os.clock() < deadline do
			h.frames(1)
		end
		return cond()
	end
	-- The longest the bar can be not ready from now: first start, a boost and its recharge, or a miss lock
	local function readyWait(C)
		-- (MISS_COOLDOWN = RECHARGE since 2026-11-20, so this is about 18 s with the placeholders)
		return C.START_DELAY + C.DURATION + C.RECHARGE + C.MISS_COOLDOWN + 2
	end
	-- The label text a graded press must show (NITRO_SPEC "Feedback")
	-- The label after a boost ends (NITRO_SPEC "Feedback", Vic2CS 2026-11-20): %.1f = the server's NitroSaved, shown
	-- for SavedShow s. Client/NitroInput SAVED_TEXT / SAVED_SHOW; the fallbacks stand in until UiSpec.Nitro has them.
	local savedFormat = cfg.Text.Saved or "SAVED %.1f s"
	local savedShow = cfg.SavedShow or 1.5
	local function gradeText(C, grade)
		if grade == "Perfect" then
			return string.format(cfg.Text.Perfect, C.MultiFor("Perfect"))
		elseif grade == "Good" then
			return string.format(cfg.Text.Good, C.MultiFor("Good"))
		end
		return cfg.Text.Miss
	end
	-- Screen x of a bar position (-1 left edge .. 1 right edge) on the bar rect `br`
	local function xOn(br, position)
		return br.x + (math.clamp(position, -1, 1) + 1) / 2 * br.w
	end
	-- Root's live FitScale (nil when it is missing)
	local function liveScale()
		local root = h.find(cfg.Root)
		local s = root and root:FindFirstChild(cfg.FitScale)
		return s and s:IsA("UIScale") and s.Scale or nil
	end

	-- What the bar draws now: its rect, the zones' centres and the press marker (shown, centre x, rect)
	local function drawnNow()
		local bar, good, perfect, mark = h.find(cfg.Bar), h.find(cfg.Good), h.find(cfg.Perfect), h.find(cfg.PressMark)
		if not (bar and good and perfect and mark) then
			return nil
		end
		local mr = h.rect(mark)
		return {
			bar = h.rect(bar),
			good = centreX(h.rect(good)),
			perfect = centreX(h.rect(perfect)),
			markShown = h.visible(mark),
			markX = centreX(mr),
			markRect = mr,
		}
	end

	player:GetAttributeChangedSignal("NitroPresses"):Connect(function()
		local rec = {
			presses = presses(),
			grade = attr("NitroGrade"),
			multi = attr("NitroMulti"),
			pressPos = attr("NitroPressPos"),
			target = target(), -- the NEXT bar's target (the server picks it when it grades)
			t = now(),
		}
		table.insert(records, rec)
		task.spawn(function()
			h.frames(2) -- Client/NitroInput writes the label and places the marker on its next RenderStepped
			rec.drawn = drawnNow()
			rec.label = labelText()
		end)
	end)
	local function recordFor(n, seconds)
		local found = nil
		waitUntil(function()
			for i = #records, 1, -1 do
				if records[i].presses == n and records[i].label ~= nil then
					found = records[i]
					return true
				end
			end
			return false
		end, seconds)
		return found
	end

	-- The first server time >= `from` at which the needle (sweeping from `ready`, NitroConfig.NeedleAt) is at one of
	-- `phases` (fractions of PERIOD: 0 left edge, 0.25 centre, 0.5 right edge, 0.75 centre).
	local function nextAt(C, ready, phases, from)
		local base = math.max(from, ready)
		local k = math.floor((base - ready) / C.PERIOD)
		local best = nil
		for cycle = k, k + 1 do
			for _, ph in phases do
				local t = ready + (cycle + ph) * C.PERIOD
				if t >= base and (best == nil or t < best) then
					best = t
				end
			end
		end
		return best
	end
	-- The phases at which the needle (1 - 4 |phase - 0.5|) is at bar position p: on the way right and on the way back
	local function phasesAt(p)
		local d = (1 - math.clamp(p, -1, 1)) / 4
		return { 0.5 - d, 0.5 + d }
	end

	-- Where the needle is drawn now (screen x of its centre) and the bar's rect, or nil
	local function needleDrawn()
		local bar, needle = h.find(cfg.Bar), h.find(cfg.Needle)
		if not (bar and needle and needle:IsA("GuiObject")) then
			return nil
		end
		local br, nr = h.rect(bar), h.rect(needle)
		return { x = centreX(nr), bar = br, shown = h.visible(needle) }
	end

	-- One press the way Client/NitroInput sends it, at the next moment the needle is at `phases`. Returns the graded
	-- record (or nil and why), the press time and what was drawn at the press frame.
	local function pressAt(C, phases)
		local remote = ReplicatedStorage:FindFirstChild("Remotes")
		remote = remote and remote:FindFirstChild(cfg.Remote)
		if not (remote and remote:IsA("RemoteEvent")) then
			return nil, "Remotes." .. cfg.Remote .. " missing"
		end
		local ready = readyAt()
		if not ready then
			return nil, "NitroReadyAt is not a number"
		end
		local t = nextAt(C, ready, phases, math.max(now() + 0.05, boostUntil()))
		local lastFrame = os.clock()
		local frameDt = 1 / 60
		waitUntil(function()
			local c = os.clock()
			frameDt, lastFrame = math.max(c - lastFrame, 1 / 240), c
			return now() >= t
		end, t - now() + 2)
		local drawn = needleDrawn()
		if drawn then
			drawn.frameDt = frameDt
		end
		local before = presses()
		remote:FireServer(t)
		local rec = recordFor(before + 1, cfg.GradeWait)
		if not rec then
			return nil, ("no graded press within %.1f s (NitroPresses %d)"):format(cfg.GradeWait, presses()), t, drawn
		end
		return rec, nil, t, drawn
	end

	-- A press that must do nothing: NitroPresses, NitroGrade and NitroTarget stay as they are
	local function ignoredPress(res, name)
		local remote = ReplicatedStorage.Remotes:FindFirstChild(cfg.Remote)
		local before, grade, tgt = presses(), attr("NitroGrade"), target()
		if remote then
			remote:FireServer(now())
		end
		task.wait(cfg.IgnoreWatch)
		h.check(
			res,
			name,
			("NitroPresses %d -> %d, grade %s, target %s -> %s"):format(
				before,
				presses(),
				tostring(attr("NitroGrade")),
				tostring(tgt),
				tostring(target())
			),
			"unchanged",
			remote ~= nil and presses() == before and attr("NitroGrade") == grade and target() == tgt
		)
	end

	-- Both zones centred on bar position `tgt` in `d` (a drawnNow()); a list of problems
	local function zonesOffTarget(d, tgt, what)
		if not d then
			return { "NitroBar parts missing" }
		end
		if type(tgt) ~= "number" then
			return { what .. ": NitroTarget is " .. tostring(tgt) }
		end
		local bad = {}
		local want = xOn(d.bar, tgt)
		for _, z in { { "Good", d.good }, { "Perfect", d.perfect } } do
			if math.abs(z[2] - want) > TOL then
				table.insert(bad, ("%s centre x %.1f, want %.1f (%s %.3f)"):format(z[1], z[2], want, what, tgt))
			end
		end
		return bad
	end
	-- The press marker shown at bar position `pos` within MarkTolerance px; a list of problems
	local function markOff(d, pos)
		if not d then
			return { "NitroBar parts missing" }
		end
		if type(pos) ~= "number" then
			return { "NitroPressPos is " .. tostring(pos) }
		end
		local bad = {}
		if not d.markShown then
			table.insert(bad, "PressMark hidden")
		end
		local want = xOn(d.bar, pos)
		if math.abs(d.markX - want) > cfg.MarkTolerance then
			table.insert(bad, ("PressMark centre x %.1f, want %.1f (NitroPressPos %.3f)"):format(d.markX, want, pos))
		end
		return bad
	end
	-- The next bar's target: a valid target, at least TARGET_MIN_MOVE from the graded bar's
	local function targetMoved(C, old, new)
		return type(old) == "number"
			and type(new) == "number"
			and math.abs(new - old) >= C.TARGET_MIN_MOVE - 1e-9
			and math.abs(new) <= C.TARGET_RANGE + 1e-9
	end

	-- What makes the bar look hidden / not clickable; empty when it is
	local function hiddenProblems()
		local bad = {}
		local bar, label = h.find(cfg.Bar), h.find(cfg.Label)
		if not (bar and label) then
			table.insert(bad, "NitroBar Root/Bar or Root/Label missing")
			return bad
		end
		for _, o in { bar, label } do
			if h.visible(o) then
				table.insert(bad, h.pathOf(o) .. " shown")
			end
		end
		local r = h.rect(bar)
		if r.w > 0 and r.h > 0 and table.find(h.hitsAt(r.x + r.w / 2, r.y + r.h / 2), bar) then
			table.insert(bad, h.pathOf(bar) .. " takes a click at its centre")
		end
		return bad
	end
	local function shownNow()
		local bar, label = h.find(cfg.Bar), h.find(cfg.Label)
		return bar ~= nil and label ~= nil and h.visible(bar) and h.visible(label)
	end
	-- Charging / locked / boosting look: the fill is shown and the needle is not
	local function notReadyLook()
		local charge, needle = h.find(cfg.Charge), h.find(cfg.Needle)
		return ("charge shown=%s needle shown=%s"):format(
			tostring(charge ~= nil and h.visible(charge)),
			tostring(needle ~= nil and h.visible(needle))
		),
			charge ~= nil and needle ~= nil and h.visible(charge) and not h.visible(needle)
	end
	local function readyLook()
		local charge, needle = h.find(cfg.Charge), h.find(cfg.Needle)
		return ("charge shown=%s needle shown=%s"):format(
			tostring(charge ~= nil and h.visible(charge)),
			tostring(needle ~= nil and h.visible(needle))
		),
			charge ~= nil and needle ~= nil and not h.visible(charge) and h.visible(needle)
	end

	-- The shown press marker is drawing only: a Frame that takes no click. Where it pokes out above the bar nothing of
	-- NitroBar takes the click; on the bar the click still goes to the bar; it never reaches over RacerHud/Speed.
	local function markTakesNoClick(res, prefix)
		local mark, bar = h.find(cfg.PressMark), h.find(cfg.Bar)
		local d = drawnNow()
		local bad = {}
		if not (mark and bar and d) then
			table.insert(bad, "NitroBar parts missing")
		else
			if mark:IsA("GuiButton") or mark:IsA("TextBox") or mark.Active then
				table.insert(bad, ("PressMark is %s Active=%s"):format(mark.ClassName, tostring(mark.Active)))
			end
			local br, mr = d.bar, d.markRect
			if not d.markShown then
				table.insert(bad, "PressMark hidden (nothing to probe)")
			else
				local x = math.clamp(d.markX, br.x + 1, br.x + br.w - 1)
				-- Above the bar, inside the marker
				if mr.y < br.y - 1 then
					local y = (mr.y + br.y) / 2
					for _, o in h.hitsAt(x, y) do
						if
							(o:IsA("GuiButton") or o:IsA("TextBox") or o.Active) and o:IsDescendantOf(bar.Parent.Parent)
						then
							table.insert(
								bad,
								("%s takes a click above the bar at (%.0f, %.0f)"):format(h.pathOf(o), x, y)
							)
						end
					end
				end
				-- On the bar, under the marker: the first object that takes the click is the bar
				local first = nil
				for _, o in h.hitsAt(x, br.y + br.h / 2) do
					if o:IsA("GuiButton") or o:IsA("TextBox") or o.Active then
						first = o
						break
					end
				end
				if first ~= bar then
					table.insert(
						bad,
						("click on the bar under PressMark goes to %s"):format(first and h.pathOf(first) or "nothing")
					)
				end
			end
		end
		h.checkList(res, prefix .. "_press_mark_takes_no_click", bad)
		local speed = h.find(Spec.Hud.Speed)
		if d and d.markShown and speed then
			local sr = h.rect(speed)
			local clear = d.markRect.y + d.markRect.h <= sr.y + TOL
			h.check(res, prefix .. "_press_mark_clear_of_speed", d.markRect.y + d.markRect.h - sr.y, "<= 0 px", clear)
		end
	end

	---------------------------------------------------------------------------------------------------------------

	function scenarios.ui_nitro_bar(res)
		h.waitGuis()
		local C = config()
		h.check(res, "nitro_config_present", C ~= nil, true, C ~= nil)
		local parts = {
			{ cfg.Root, "Frame" },
			{ cfg.Root .. "/" .. cfg.FitScale, "UIScale" },
			{ cfg.Label, "TextLabel" },
			{ cfg.Bar, "TextButton" },
			{ cfg.Good, "Frame" },
			{ cfg.Perfect, "Frame" },
			{ cfg.Charge, "Frame" },
			{ cfg.Needle, "Frame" },
			{ cfg.PressMark, "Frame" },
		}
		local missing = {}
		for _, p in parts do
			local o = h.find(p[1])
			if not (o and o:IsA(p[2])) then
				table.insert(missing, p[1] .. " (" .. p[2] .. ")")
			end
		end
		h.checkList(res, "nitro_bar_parts_present", missing)
		if not C or #missing > 0 then
			return
		end
		-- The bar hides while a panel is open (UiSpec.HiddenWhilePanelOpen): judge it with none open
		local restore = h.setPanels({})
		if attr("AutoRacing") ~= true then
			h.checkList(res, "nitro_bar_hidden_when_not_racing", hiddenProblems())
			h.stateMissing(
				res,
				"auto_racing_for_nitro",
				"auto_racing",
				"AutoRacing is " .. tostring(attr("AutoRacing"))
			)
			restore()
			return
		end
		-- An emphasized roll may have opened the showcase (the bar hides under it): let it close by itself
		local showcase = h.playerGui:FindFirstChild(Spec.Showcase.Gui)
		waitUntil(function()
			return not (showcase and showcase.Enabled)
		end, 12)

		-- 1. Shown while auto racing, from the server's NitroReadyAt
		local shown = waitUntil(function()
			return readyAt() ~= nil and shownNow()
		end, cfg.ShowGrace + 1)
		h.check(
			res,
			"nitro_bar_shown_while_racing",
			("NitroReadyAt=%s shown=%s"):format(tostring(attr("NitroReadyAt")), tostring(shownNow())),
			"number, shown",
			shown
		)
		if not shown then
			restore()
			return
		end
		h.frames(2)

		-- 2. Placement (engine, live viewport): centred, bottom edge GapAboveSpeed px above RacerHud/Speed's top,
		-- FitScale by the short-screen rule, sizes x FitScale, never into the compact roll
		local root, speed, toast = h.find(cfg.Root), h.find(Spec.Hud.Speed), h.find(cfg.Roll)
		local label, bar = h.find(cfg.Label), h.find(cfg.Bar)
		local vp = h.viewport()
		local rr = h.rect(root)
		local s = liveScale() or 1
		h.check(res, "nitro_bar_centred_x", centreX(rr), vp.X / 2, math.abs(centreX(rr) - vp.X / 2) <= TOL)
		if speed and toast then
			local sr, tr = h.rect(speed), h.rect(toast)
			local gap = sr.y - (rr.y + rr.h)
			h.check(res, "nitro_bar_gap_above_speed", gap, cfg.GapAboveSpeed, math.abs(gap - cfg.GapAboveSpeed) <= TOL)
			local room = (sr.y - cfg.GapAboveSpeed) - (tr.y + tr.h + cfg.GapBelowRoll)
			local want = math.clamp(room / cfg.RootSize.Y, cfg.MinScale, 1)
			h.check(
				res,
				"nitro_fit_scale_matches_rule",
				s,
				("%.3f (room %.1f px / %d)"):format(want, room, cfg.RootSize.Y),
				math.abs(s - want) <= cfg.ScaleTolerance
			)
			-- Strict: even at MinScale the bar may not reach into the compact roll
			local clear = rr.y - (tr.y + tr.h)
			h.check(res, "nitro_bar_clear_of_compact_roll", clear, ">= 0 px", clear >= 0)
		else
			h.check(
				res,
				"nitro_bar_gap_above_speed",
				"missing " .. (speed and cfg.Roll or Spec.Hud.Speed),
				cfg.GapAboveSpeed,
				false
			)
		end
		local sizeBad = {}
		for _, want in
			{
				{ "Root", rr, cfg.RootSize.X, cfg.RootSize.Y },
				{ "Bar", h.rect(bar), cfg.BarSize.X, cfg.BarSize.Y },
			}
		do
			local r = want[2]
			if math.abs(r.w - want[3] * s) > TOL or math.abs(r.h - want[4] * s) > TOL then
				table.insert(
					sizeBad,
					("%s %.1f x %.1f, want %.1f x %.1f (x FitScale %.3f)"):format(
						want[1],
						r.w,
						r.h,
						want[3] * s,
						want[4] * s,
						s
					)
				)
			end
		end
		local lr = h.rect(label)
		if math.abs(lr.h - cfg.LabelHeight * s) > TOL or math.abs(lr.w - cfg.RootSize.X * s) > TOL then
			table.insert(
				sizeBad,
				("Label %.1f x %.1f, want %.1f x %.1f"):format(lr.w, lr.h, cfg.RootSize.X * s, cfg.LabelHeight * s)
			)
		end
		if label.TextSize ~= cfg.LabelTextSize then
			table.insert(sizeBad, ("Label TextSize %s, want %d"):format(tostring(label.TextSize), cfg.LabelTextSize))
		end
		h.checkList(res, "nitro_bar_size_x_fit_scale", sizeBad)

		-- See-through fill (brief): the zones and the marker stay readable while charging; the marker draws over it
		local charge, mark = h.find(cfg.Charge), h.find(cfg.PressMark)
		h.check(
			res,
			"nitro_charge_see_through",
			charge.BackgroundTransparency,
			cfg.ChargeTransparency,
			math.abs(charge.BackgroundTransparency - cfg.ChargeTransparency) <= 0.01
		)
		h.check(
			res,
			"nitro_press_mark_drawn_over_fill",
			("PressMark ZIndex %d, Charge %d"):format(mark.ZIndex, charge.ZIndex),
			"PressMark above Charge",
			mark.ZIndex > charge.ZIndex
		)

		-- 3. Every promised label text is drawn inside the label (the overlap rules measure its rect). TextService
		-- measures design pixels; FitScale scales the text with the label.
		local function textSize(text)
			local ok, size = pcall(function()
				return TextService:GetTextSize(text, label.TextSize, label.Font, Vector2.new(100000, 100000))
			end)
			return ok and size * s or Vector2.new(math.huge, math.huge)
		end

		-- 4. Ready: label READY, needle shown and sweeping on the server's clock, no old press marker, the zones on
		-- this bar's NitroTarget
		local ready = waitUntil(isReady, readyWait(C))
		h.frames(2)
		h.check(res, "nitro_ready_within_wait", ready, true, ready)
		if not ready then
			restore()
			return
		end
		local readyText = labelText()
		local readyWant = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
				and cfg.Text.ReadyTouch
			or cfg.Text.ReadyKeyboard
		h.check(res, "nitro_label_ready", readyText, readyWant, readyText == readyWant)
		local lookText, lookOk = readyLook()
		h.check(res, "nitro_ready_needle_shown", lookText, "charge shown=false needle shown=true", lookOk)
		local tooBig = {}
		if not (label.TextScaled or label.TextWrapped) then
			for _, text in
				{
					readyText,
					cfg.Text.ReadyKeyboard,
					cfg.Text.ReadyTouch,
					gradeText(C, "Perfect"),
					gradeText(C, "Good"),
					cfg.Text.Miss,
					cfg.Text.Charging,
					savedFormat:format(C.SavedSeconds(C.PERFECT_MULTI, C.DURATION)),
				}
			do
				local size = textSize(text)
				if size.X > label.AbsoluteSize.X + TOL or size.Y > label.AbsoluteSize.Y + TOL then
					table.insert(
						tooBig,
						("%q %.0f x %.0f px > %.0f x %.0f px"):format(
							text,
							math.ceil(size.X),
							math.ceil(size.Y),
							label.AbsoluteSize.X,
							label.AbsoluteSize.Y
						)
					)
				end
			end
		end
		h.checkList(res, "nitro_label_text_fits", tooBig)

		local T = target()
		h.check(
			res,
			"nitro_target_in_range",
			T,
			("|t| <= %.2f"):format(C.TARGET_RANGE),
			T ~= nil and math.abs(T) <= C.TARGET_RANGE + 1e-9
		)
		local d = drawnNow()
		h.check(res, "nitro_press_mark_hidden_when_ready", d and d.markShown, false, d ~= nil and not d.markShown)
		h.checkList(res, "nitro_zones_on_target_when_ready", zonesOffTarget(d, T, "NitroTarget"))
		-- The zones are drawn where the server grades: Good covers |needle - target| <= GOOD_ZONE, Perfect <=
		-- PERFECT_ZONE (needle -1 .. 1 across the bar's width, so a zone is ZONE x bar width wide), all on the bar
		local br = h.rect(bar)
		for _, zone in { { "good", cfg.Good, C.GOOD_ZONE }, { "perfect", cfg.Perfect, C.PERFECT_ZONE } } do
			local zr = h.rect(h.find(zone[2]))
			local want = zone[3] * br.w
			h.check(
				res,
				"nitro_" .. zone[1] .. "_zone_width_matches_grading",
				zr.w,
				want,
				math.abs(zr.w - want) <= TOL + 0.5
			)
			h.check(
				res,
				"nitro_" .. zone[1] .. "_zone_on_bar",
				("%.1f .. %.1f"):format(zr.x, zr.x + zr.w),
				("%.1f .. %.1f"):format(br.x, br.x + br.w),
				zr.x >= br.x - TOL and zr.x + zr.w <= br.x + br.w + TOL
			)
		end

		local ready0 = readyAt()
		local pxPerSec = (4 / C.PERIOD) * br.w / 2 -- needle speed in screen px
		local samples, worst, minX, maxX = 0, 0, math.huge, -math.huge
		local last = os.clock()
		local t0 = os.clock()
		while os.clock() - t0 < cfg.SweepSeconds do
			h.frames(1)
			local c = os.clock()
			local dt = math.max(c - last, 1 / 240)
			last = c
			local nd = needleDrawn()
			if nd and nd.shown then
				local want = xOn(nd.bar, C.NeedleAt(now(), ready0))
				-- NitroInput and this sampler read the clock in different callbacks of the same frame: allow the
				-- motion of one frame and a half, plus rounding
				local err = math.abs(nd.x - want) - (pxPerSec * dt * 1.5 + 2)
				worst = math.max(worst, err)
				minX, maxX = math.min(minX, nd.x), math.max(maxX, nd.x)
				samples += 1
			end
		end
		h.check(res, "nitro_needle_sampled", samples, ">= 3", samples >= 3)
		local travel = samples > 0 and (maxX - minX) or 0
		h.check(res, "nitro_needle_moves", travel, ">= " .. cfg.SweepMinTravel, travel >= cfg.SweepMinTravel)
		h.check(res, "nitro_needle_follows_server_clock", worst, "<= 0 px over the allowance", worst <= 0)

		-- 5. A press with the needle ON THE TARGET: Perfect, a boost until NitroUntil, then RECHARGE; the marker at the
		-- server's press position; the next target picked at once, the zones kept on this bar's target
		T = target() or 0
		local rec, why, t, drawn = pressAt(C, phasesAt(T))
		if drawn then
			-- What the player saw at the press frame: the needle on the gold zone (within one frame of motion)
			local off = math.abs(drawn.x - xOn(drawn.bar, T))
			local allow = C.PERFECT_ZONE * drawn.bar.w / 2 + pxPerSec * drawn.frameDt + TOL
			h.check(res, "nitro_needle_on_gold_at_target_press", off, "<= " .. math.floor(allow), off <= allow)
		end
		if not rec then
			h.check(res, "nitro_perfect_press_graded", why, "graded", false)
			restore()
			return
		end
		h.check(res, "nitro_target_press_grade", rec.grade, "Perfect", rec.grade == "Perfect")
		h.check(res, "nitro_perfect_multi", rec.multi, C.PERFECT_MULTI, rec.multi == C.PERFECT_MULTI)
		local posWant = C.NeedleAt(t, ready0)
		local posTol = (4 / C.PERIOD) * cfg.TimeTolerance
		h.check(
			res,
			"nitro_press_pos_is_needle_at_press",
			rec.pressPos,
			("%.3f +- %.3f"):format(posWant, posTol),
			type(rec.pressPos) == "number" and math.abs(rec.pressPos - posWant) <= posTol
		)
		h.checkList(res, "nitro_press_mark_at_press_pos", markOff(rec.drawn, rec.pressPos))
		h.check(
			res,
			"nitro_target_moves_after_press",
			("%s -> %s"):format(tostring(T), tostring(rec.target)),
			(">= %.2f apart, |t| <= %.2f"):format(C.TARGET_MIN_MOVE, C.TARGET_RANGE),
			targetMoved(C, T, rec.target)
		)
		h.checkList(res, "nitro_zones_stay_while_boosting", zonesOffTarget(rec.drawn, T, "graded bar's target"))
		local untilT = boostUntil()
		h.check(
			res,
			"nitro_until_in_future",
			untilT - now(),
			("0 .. %s s"):format(C.DURATION),
			untilT > now() and untilT <= t + C.DURATION + cfg.TimeTolerance + 0.5
		)
		local r2 = readyAt() or 0
		h.check(
			res,
			"nitro_recharge_after_boost",
			r2 - untilT,
			C.RECHARGE,
			math.abs(r2 - untilT - C.RECHARGE) <= cfg.TimeTolerance
		)
		h.check(
			res,
			"nitro_label_shows_perfect",
			rec.label,
			gradeText(C, "Perfect"),
			rec.label == gradeText(C, "Perfect")
		)
		lookText, lookOk = notReadyLook()
		h.check(res, "nitro_boost_drains_bar", lookText, "charge shown=true needle shown=false", lookOk)
		markTakesNoClick(res, "nitro")
		ignoredPress(res, "nitro_press_while_boosting_ignored")

		-- 6. After the boost: the label shows the time it saved (the server's NitroSaved, set when the boost ended:
		-- above 0 and at most the nominal Perfect saving; less only when a reset cut the boost short), then NITRO
		-- CHARGING until ready (zones and marker kept), then READY again with the zones on the new target and the
		-- marker gone
		local savedAtBefore = attr("NitroSavedAt")
		waitUntil(function()
			return now() >= boostUntil() + 0.3
		end, C.DURATION + 2)
		waitUntil(function()
			return attr("NitroSavedAt") ~= savedAtBefore
		end, cfg.GradeWait)
		h.frames(2)
		local saved, savedAt = attr("NitroSaved"), attr("NitroSavedAt")
		local nominal = C.SavedSeconds(C.PERFECT_MULTI, C.DURATION)
		h.check(
			res,
			"nitro_saved_set_when_boost_ends",
			("NitroSaved %s at %s (boost until %.2f)"):format(tostring(saved), tostring(savedAt), boostUntil()),
			("0 < saved <= %.2f, at the boost's end"):format(nominal),
			type(saved) == "number"
				and saved > 0
				and saved <= nominal + 1e-6
				and type(savedAt) == "number"
				and savedAt ~= savedAtBefore
				and math.abs(savedAt - boostUntil()) <= cfg.TimeTolerance + 0.1
		)
		local savedText = type(saved) == "number" and savedFormat:format(saved) or "none"
		local shownText = labelText()
		h.check(res, "nitro_label_shows_saved", shownText, savedText, shownText == savedText)
		waitUntil(function()
			return labelText() ~= savedText
		end, savedShow + 0.5)
		h.frames(2)
		if not isReady() then
			local text = labelText()
			h.check(res, "nitro_label_charging", text, cfg.Text.Charging, text == cfg.Text.Charging)
			lookText, lookOk = notReadyLook()
			h.check(res, "nitro_charging_fills_bar", lookText, "charge shown=true needle shown=false", lookOk)
			d = drawnNow()
			h.checkList(res, "nitro_zones_stay_while_charging", zonesOffTarget(d, T, "graded bar's target"))
			h.checkList(res, "nitro_press_mark_stays_while_charging", markOff(d, rec.pressPos))
		end
		ready = waitUntil(isReady, readyWait(C))
		h.frames(2)
		h.check(res, "nitro_ready_again_after_recharge", ready, true, ready)
		if not ready then
			restore()
			return
		end
		local T2 = target()
		h.check(
			res,
			"nitro_next_bar_target_is_new",
			("%s -> %s"):format(tostring(T), tostring(T2)),
			("%s, >= %.2f from %s"):format(tostring(rec.target), C.TARGET_MIN_MOVE, tostring(T)),
			T2 ~= nil and T2 == rec.target and targetMoved(C, T, T2)
		)
		d = drawnNow()
		h.checkList(res, "nitro_zones_move_when_next_bar_ready", zonesOffTarget(d, T2, "new NitroTarget"))
		h.check(
			res,
			"nitro_press_mark_hides_when_next_bar_ready",
			d and d.markShown,
			false,
			d ~= nil and not d.markShown
		)

		-- 7. A press with the needle at the edge farthest from the target (off the green): Miss, no boost, the bar
		-- locked for MISS_COOLDOWN; the marker and the zones kept until the lock ends
		T2 = T2 or 0
		local untilBefore = boostUntil()
		rec, why, t, drawn = pressAt(C, { T2 >= 0 and 0 or 0.5 })
		if drawn then
			local gr = h.rect(h.find(cfg.Good))
			local onGreen = drawn.x >= gr.x and drawn.x <= gr.x + gr.w
			h.check(res, "nitro_needle_off_green_at_edge_press", onGreen, false, not onGreen)
		end
		if not rec then
			h.check(res, "nitro_miss_press_graded", why, "graded", false)
			restore()
			return
		end
		h.check(res, "nitro_edge_press_grade", rec.grade, "Miss", rec.grade == "Miss")
		h.check(res, "nitro_miss_no_boost", boostUntil(), untilBefore, boostUntil() == untilBefore)
		local lockLeft = (readyAt() or 0) - now()
		h.check(
			res,
			"nitro_miss_locks_bar",
			lockLeft,
			("0 .. %s s"):format(C.MISS_COOLDOWN),
			lockLeft > 0 and lockLeft <= C.MISS_COOLDOWN + cfg.TimeTolerance
		)
		h.check(res, "nitro_label_shows_miss", rec.label, cfg.Text.Miss, rec.label == cfg.Text.Miss)
		lookText, lookOk = notReadyLook()
		h.check(res, "nitro_locked_bar_look", lookText, "charge shown=true needle shown=false", lookOk)
		h.checkList(res, "nitro_press_mark_at_miss_pos", markOff(rec.drawn, rec.pressPos))
		h.check(
			res,
			"nitro_target_moves_after_miss",
			("%s -> %s"):format(tostring(T2), tostring(rec.target)),
			(">= %.2f apart, |t| <= %.2f"):format(C.TARGET_MIN_MOVE, C.TARGET_RANGE),
			targetMoved(C, T2, rec.target)
		)
		h.checkList(res, "nitro_zones_stay_while_locked", zonesOffTarget(rec.drawn, T2, "missed bar's target"))
		ignoredPress(res, "nitro_press_while_locked_ignored")
		ready = waitUntil(isReady, C.MISS_COOLDOWN + 2)
		h.frames(2)
		h.check(res, "nitro_ready_after_lock", ready, true, ready)
		if ready then
			d = drawnNow()
			h.checkList(res, "nitro_zones_move_after_lock", zonesOffTarget(d, target(), "new NitroTarget"))
			h.check(res, "nitro_press_mark_hides_after_lock", d and d.markShown, false, d ~= nil and not d.markShown)
		end
		restore()
	end

	---------------------------------------------------------------------------------------------------------------
	-- Clicks (UiSpec.Clicks nitro_*): Prepare runs after the panels are set and before the spy baseline is read.
	-- Returns nil when the state is there, else why not (the runner reports state_missing).

	local function prepare(res, prep)
		local C = config()
		if not C then
			return "Shared." .. cfg.Module .. " missing"
		end
		if not waitUntil(isReady, readyWait(C)) then
			return ("bar not ready within %d s (NitroReadyAt=%s)"):format(readyWait(C), tostring(attr("NitroReadyAt")))
		end
		h.frames(2)
		if prep.NitroReady then
			-- The label and the zones show the server's state before the click
			local text = labelText()
			h.check(
				res,
				"nitro_label_ready_before_press",
				text,
				cfg.Text.Ready .. "...",
				startsWith(text, cfg.Text.Ready)
			)
			h.checkList(res, "nitro_zones_on_target_before_press", zonesOffTarget(drawnNow(), target(), "NitroTarget"))
			return nil
		end
		if prep.NitroCharging then
			local rec, why = pressAt(C, phasesAt(target() or 0))
			if not rec then
				return "harness target press: " .. tostring(why)
			end
			if rec.grade ~= "Perfect" then
				return "harness target press graded " .. tostring(rec.grade) .. ", want Perfect"
			end
			if isReady() then
				return "bar ready right after the boost started"
			end
			return nil
		end
		return nil
	end

	-- Exactly one graded press, graded from the needle at the time the press carried and measured from the bar's
	-- NitroTarget, Label showing that grade, PressMark at NitroPressPos, the zones kept while NitroTarget moved on
	after.nitro_press_graded = function(res, ctx)
		local C = config()
		local pre = ctx.pre or {}
		local call = nil
		for _, f in ctx.fired or {} do
			if f.name == cfg.Remote then
				call = f
			end
		end
		local claimed = call and call.args and call.args[1]
		local want = (pre.NitroPresses or 0) + 1
		local rec = recordFor(want, cfg.GradeWait)
		h.check(res, "nitro_press_counted", presses(), want, rec ~= nil and presses() == want)
		if
			not (
				C
				and rec
				and type(claimed) == "number"
				and type(pre.NitroReadyAt) == "number"
				and type(pre.NitroTarget) == "number"
			)
		then
			h.check(
				res,
				"nitro_grade_matches_needle_at_press",
				("claimed=%s readyAt=%s target=%s record=%s"):format(
					tostring(claimed),
					tostring(pre.NitroReadyAt),
					tostring(pre.NitroTarget),
					tostring(rec ~= nil)
				),
				"a graded press of a ready bar",
				false
			)
			return
		end
		-- The press carries the time it happened (Client/NitroInput sends workspace:GetServerTimeNow() at the press)
		h.check(
			res,
			"nitro_press_carries_press_time",
			ctx.pressT and (claimed - ctx.pressT) or "no press seen",
			("|d| <= %s s"):format(cfg.PressTimeTolerance),
			ctx.pressT ~= nil and math.abs(claimed - ctx.pressT) <= cfg.PressTimeTolerance
		)
		local grade = C.Grade(C.NeedleAt(claimed, pre.NitroReadyAt), pre.NitroTarget)
		h.check(res, "nitro_grade_matches_needle_at_press", rec.grade, grade, rec.grade == grade)
		local posWant = C.NeedleAt(claimed, pre.NitroReadyAt)
		local posTol = (4 / C.PERIOD) * cfg.TimeTolerance
		h.check(
			res,
			"nitro_press_pos_is_needle_at_press",
			rec.pressPos,
			("%.3f +- %.3f"):format(posWant, posTol),
			type(rec.pressPos) == "number" and math.abs(rec.pressPos - posWant) <= posTol
		)
		-- What the marker shows against the zones is the grade the server gave
		local markGrade = type(rec.pressPos) == "number" and C.Grade(rec.pressPos, pre.NitroTarget) or "none"
		h.check(res, "nitro_grade_matches_press_mark", rec.grade, markGrade, rec.grade == markGrade)
		h.checkList(res, "nitro_press_mark_at_press_pos", markOff(rec.drawn, rec.pressPos))
		h.check(
			res,
			"nitro_target_moves_after_press",
			("%s -> %s"):format(tostring(pre.NitroTarget), tostring(rec.target)),
			(">= %.2f apart, |t| <= %.2f"):format(C.TARGET_MIN_MOVE, C.TARGET_RANGE),
			targetMoved(C, pre.NitroTarget, rec.target)
		)
		h.checkList(
			res,
			"nitro_zones_stay_after_press",
			zonesOffTarget(rec.drawn, pre.NitroTarget, "graded bar's target")
		)
		h.check(
			res,
			"nitro_label_shows_grade",
			rec.label,
			gradeText(C, rec.grade),
			rec.label == gradeText(C, rec.grade)
		)
		if rec.grade == "Miss" then
			local r = readyAt() or 0
			h.check(
				res,
				"nitro_miss_locks_bar",
				r - claimed,
				">= " .. C.MISS_COOLDOWN,
				r >= claimed + C.MISS_COOLDOWN - cfg.TimeTolerance
			)
		else
			h.check(res, "nitro_boost_started", boostUntil() - claimed, "> 0", boostUntil() > claimed)
		end
		markTakesNoClick(res, "nitro_click")
	end

	-- The press happened while the bar was boosting or recharging (else the click came too late to prove anything)
	after.nitro_not_ready_at_press = function(res, ctx)
		local pre = ctx.pre or {}
		local until_ = math.max(pre.NitroReadyAt or 0, pre.NitroUntil or 0)
		h.check(
			res,
			"nitro_not_ready_at_press",
			ctx.pressT and (until_ - ctx.pressT) or "no press seen",
			"> 0 s of charge left",
			ctx.pressT ~= nil and ctx.pressT < until_
		)
	end

	-- Nothing graded: NitroPresses, NitroTarget and NitroPressPos as before the press
	after.nitro_press_ignored = function(res, ctx)
		local pre = ctx.pre or {}
		task.wait(cfg.IgnoreWatch)
		h.check(res, "nitro_press_ignored", presses(), pre.NitroPresses or 0, presses() == (pre.NitroPresses or 0))
		h.check(
			res,
			"nitro_ignored_press_keeps_target",
			("target %s -> %s, pos %s -> %s"):format(
				tostring(pre.NitroTarget),
				tostring(attr("NitroTarget")),
				tostring(pre.NitroPressPos),
				tostring(attr("NitroPressPos"))
			),
			"unchanged",
			attr("NitroTarget") == pre.NitroTarget and attr("NitroPressPos") == pre.NitroPressPos
		)
	end

	-- Not auto racing: the server cleared NitroReadyAt and the bar is gone, with no hitbox left
	after.nitro_bar_hidden = function(res, _ctx)
		waitUntil(function()
			return #hiddenProblems() == 0
		end, cfg.ShowGrace)
		h.check(res, "nitro_ready_cleared_when_stopped", attr("NitroReadyAt"), "nil", attr("NitroReadyAt") == nil)
		h.checkList(res, "nitro_bar_hidden_when_stopped", hiddenProblems())
	end

	-- Auto racing again: the bar shows, first ready START_DELAY s after the start, its label telling which
	after.nitro_bar_shown_after_start = function(res, ctx)
		local C = config()
		local shown = waitUntil(shownNow, cfg.ShowGrace)
		h.check(res, "nitro_bar_shown_after_start", shown, true, shown)
		local r = readyAt()
		if C and r and ctx.pressT then
			local d = r - ctx.pressT
			h.check(
				res,
				"nitro_first_ready_after_start_delay",
				d,
				("%s .. %s s after the press"):format(C.START_DELAY, C.START_DELAY + Spec.Waits.ClickSettle),
				d >= C.START_DELAY - cfg.TimeTolerance and d <= C.START_DELAY + Spec.Waits.ClickSettle
			)
		else
			h.check(
				res,
				"nitro_first_ready_after_start_delay",
				("NitroReadyAt=%s press=%s"):format(tostring(r), tostring(ctx.pressT)),
				"a number",
				false
			)
		end
		h.frames(2)
		local text = labelText()
		if r and now() < r then
			h.check(res, "nitro_label_after_start", text, cfg.Text.Charging, text == cfg.Text.Charging)
		else
			h.check(res, "nitro_label_after_start", text, cfg.Text.Ready .. "...", startsWith(text, cfg.Text.Ready))
		end
	end

	return { Scenarios = scenarios, After = after, Prepare = prepare }
end

return Nitro
