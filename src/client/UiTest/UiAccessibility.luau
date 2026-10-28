--!nonstrict
-- Motion, safe area and gamepad focus (docs/HUD_LAYOUT_SPEC.md section 7, owner 2026-10-26; design doc "Owner
-- decision, 2026-10-26 (accessibility and devices)"). Limits and paths: UiSpec.Accessibility. Owned by ui-test-writer.
--   ui_reduced_motion    Client/UiMotion: Reduced() = ReducedMotionEnabled OR ReduceEffects; Create lands at once and
--                        never loops while reduced; the roll reel does not spin and the reveal keeps its time.
--   ui_motion_reduced    Client/UiMotion presets (docs/HUD_LAYOUT_SPEC.md section 10, owner 2026-10-27): with
--                        ReduceEffects on, Pop / SlideIn / Shine / Pulse / Shake / Float land on their end state at
--                        once and nothing loops; with it off (and Roblox's Reduced Motion off) Pop and Pulse animate.
--   ui_safe_insets       Client/SafeInsets: every player ScreenGui except the full-bleed ones uses DeviceSafeInsets
--                        (also one added later); every shown button / label lies inside its gui's safe rect.
--   ui_safe_insets_notch (MANUAL, Device Simulator notched phone) the same, and the safe rect really is inset.
--   ui_panel_focus       Client/PanelSwitch with the current input: mouse / keyboard / touch leave the selection and
--                        ButtonB alone; with a gamepad it runs the gamepad checks.
--   ui_gamepad_focus     (MANUAL, Controller Emulator) first button selected, ButtonB bound while open, selection
--                        restored (or cleared) on close.
-- Gamepad presses (ButtonB closes, DPad stays inside) are the manual Key clicks gamepad_* in UiSpec.Clicks.
-- Every attribute, panel and selection touched is put back.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Spec = require(script.Parent.UiSpec)

local Access = {}

function Access.Build(h)
	local cfg = Spec.Accessibility
	local player = h.player
	local playerGui = h.playerGui
	local scenarios, after = {}, {}

	local function motionModule()
		local m = script.Parent.Parent:FindFirstChild(cfg.MotionModule)
		if not (m and m:IsA("ModuleScript")) then
			return nil
		end
		local ok, mod = pcall(require, m)
		return ok and type(mod) == "table" and mod or nil
	end

	---------------------------------------------------------------------------------------------------------------
	-- Reduced motion

	-- The playing card of the next roll while motion is reduced: its reel and streaks must not move during Spin,
	-- the result must land, and the reveal (Hold) must come at the normal time (section 7: "The outcome, timing of
	-- the result reveal and all server values are unchanged").
	local function reducedReelChecks(res)
		local events = h.events
		local before = #events.rolls
		local deadline = os.clock() + cfg.RollWait
		while #events.rolls == before and os.clock() < deadline do
			task.wait(0.05)
		end
		if #events.rolls == before then
			h.stateMissing(
				res,
				"reduced_roll_received",
				"auto_roll_on",
				("no RollResult within %d s"):format(cfg.RollWait)
			)
			return
		end
		local ev = events.rolls[#events.rolls]
		local rec
		local recDeadline = os.clock() + 1
		while not rec and os.clock() < recDeadline do
			for i = #events.recs, 1, -1 do
				if events.recs[i].ev == ev then
					rec = events.recs[i]
					break
				end
			end
			if not rec then
				task.wait()
			end
		end
		if not rec then
			h.check(res, "reduced_roll_recorded", "no SampleRoll record", "recorded", false)
			return
		end
		local key = rec.playKey
		local card = h.rollCards()[key]
		local maxMove, samples, start = 0, 0, {}
		local landBy = ev.t + h.animNum("POP") + h.animNum("SPIN") + h.animNum("LAND") + h.animNum("SWITCH") + 3
		while not rec.hold[key] and os.clock() < landBy do
			if card and card:GetAttribute("Phase") == "Spin" then
				samples += 1
				for _, partName in { "Reel", "Streaks" } do
					local host = h.partOf(card, partName)
					if host and host:IsA("GuiObject") then
						for _, d in host:GetDescendants() do
							if d:IsA("GuiObject") and h.visible(d) then
								local pos = d.AbsolutePosition - host.AbsolutePosition
								if start[d] then
									maxMove = math.max(maxMove, (pos - start[d]).Magnitude)
								else
									start[d] = pos
								end
							end
						end
					end
				end
			end
			task.wait()
		end
		h.check(
			res,
			"reduced_reel_does_not_spin",
			("%.1f px over %d Spin frames"):format(maxMove, samples),
			"<= " .. cfg.ReelStill .. " px",
			maxMove <= cfg.ReelStill
		)
		local hold = rec.hold[key]
		h.check(res, "reduced_roll_reached_hold", hold ~= nil, true, hold ~= nil)
		if not hold then
			return
		end
		h.checkList(res, "reduced_roll_lands_on_result", hold.problems or {})
		local popAt, holdAt
		for _, p in h.phaseSeq(rec, key) do
			if p.phase == "PopIn" and not popAt then
				popAt = p.t
			elseif p.phase == "Hold" and not holdAt then
				holdAt = p.t
			end
		end
		local want = h.animNum("POP") + h.animNum("SPIN") + h.animNum("LAND")
		local tol = Spec.RollAnim.PhaseTolerance
		local got = popAt and holdAt and holdAt - popAt
		h.check(
			res,
			"reduced_reveal_at_normal_time",
			got or "no PopIn / Hold phase",
			("%.2f +- %.2f s from PopIn to Hold (POP + SPIN + LAND)"):format(want, tol),
			got ~= nil and math.abs(got - want) <= tol
		)
	end

	function scenarios.ui_reduced_motion(res)
		local motion = motionModule()
		h.check(
			res,
			"ui_motion_module_present",
			motion and "module" or "missing",
			"Client/" .. cfg.MotionModule .. " with Reduced and Create",
			motion ~= nil and type(motion.Reduced) == "function" and type(motion.Create) == "function"
		)
		if not (motion and type(motion.Reduced) == "function" and type(motion.Create) == "function") then
			return
		end
		local saved = player:GetAttribute(cfg.ReduceAttr)
		local osReduced = GuiService.ReducedMotionEnabled
		-- 1. Reduced() is the OR of Roblox's Reduced Motion and the REDUCED EFFECTS toggle
		for _, on in { false, true } do
			player:SetAttribute(cfg.ReduceAttr, on)
			local want = osReduced or on
			h.check(
				res,
				"reduced_" .. (on and "with" or "without") .. "_reduce_effects",
				motion.Reduced(),
				("%s (ReducedMotionEnabled=%s)"):format(tostring(want), tostring(osReduced)),
				motion.Reduced() == want
			)
		end
		-- 2. A looping tween made while reduced takes no time, does not repeat and is on its goal at once
		player:SetAttribute(cfg.ReduceAttr, true)
		local probe = Instance.new("Frame")
		probe.BackgroundTransparency = 0
		local info = TweenInfo.new(cfg.ProbeSeconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, true)
		local tween = motion.Create(probe, info, { BackgroundTransparency = 0.5 })
		local ti = tween.TweenInfo
		h.check(res, "reduced_tween_takes_no_time", ti.Time, 0, ti.Time == 0)
		h.check(
			res,
			"reduced_tween_does_not_loop",
			("repeat=%d reverses=%s"):format(ti.RepeatCount, tostring(ti.Reverses)),
			"repeat=0 reverses=false",
			ti.RepeatCount == 0 and not ti.Reverses
		)
		tween:Play()
		h.frames(3)
		h.check(
			res,
			"reduced_tween_lands_on_goal",
			probe.BackgroundTransparency,
			0.5,
			math.abs(probe.BackgroundTransparency - 0.5) <= 0.001
		)
		h.check(
			res,
			"reduced_tween_completed",
			tween.PlaybackState.Name,
			"Completed",
			tween.PlaybackState == Enum.PlaybackState.Completed
		)
		tween:Cancel()
		-- 3. Not reduced: the tween is exactly the caller's (motion is unchanged for everyone else)
		player:SetAttribute(cfg.ReduceAttr, false)
		local normal = motion.Create(probe, info, { BackgroundTransparency = 1 }).TweenInfo
		if osReduced then
			h.check(res, "os_reduced_motion_alone_reduces", normal.Time, 0, normal.Time == 0)
		else
			h.check(
				res,
				"normal_tween_unchanged",
				("time=%s repeat=%d reverses=%s"):format(
					tostring(normal.Time),
					normal.RepeatCount,
					tostring(normal.Reverses)
				),
				("time=%s repeat=-1 reverses=true"):format(tostring(cfg.ProbeSeconds)),
				normal.Time == cfg.ProbeSeconds and normal.RepeatCount == -1 and normal.Reverses
			)
		end
		probe:Destroy()
		-- 4. The roll reel while reduced
		player:SetAttribute(cfg.ReduceAttr, true)
		local ok, err = pcall(reducedReelChecks, res)
		player:SetAttribute(cfg.ReduceAttr, saved)
		if not ok then
			error(err)
		end
	end

	---------------------------------------------------------------------------------------------------------------
	-- Motion presets while reduced (section 10)

	function scenarios.ui_motion_reduced(res)
		local motion = motionModule()
		local presets = { "Pop", "SlideIn", "Shine", "Pulse", "Shake", "Float" }
		local missing = {}
		for _, name in presets do
			if not (motion and type(motion[name]) == "function") then
				table.insert(missing, name)
			end
		end
		h.checkList(res, "motion_presets_present", missing)
		if #missing > 0 then
			return
		end
		local saved = player:GetAttribute(cfg.ReduceAttr)
		local probeGui = Instance.new("ScreenGui")
		probeGui.Name = "UiTestMotionProbe"
		probeGui.Enabled = false
		probeGui.Parent = playerGui
		local function frame(class)
			local f = Instance.new(class or "Frame")
			f.Position = UDim2.fromOffset(100, 100)
			f.Size = UDim2.fromOffset(100, 40)
			f.BackgroundTransparency = 0
			f.Parent = probeGui
			return f
		end
		local ok, err = pcall(function()
			player:SetAttribute(cfg.ReduceAttr, true)
			-- Pop: no MotionScale left away from 1
			local pop = frame()
			motion.Pop(pop)
			h.frames(1)
			local scale = pop:FindFirstChild("MotionScale")
			h.check(res, "reduced_pop_lands", scale and scale.Scale or 1, 1, scale == nil or scale.Scale == 1)
			-- SlideIn: already at its place, fully shown
			local group = frame("CanvasGroup")
			local home = group.Position
			motion.SlideIn(group, Vector2.new(0, 40))
			h.frames(1)
			h.check(
				res,
				"reduced_slidein_lands",
				("%s t=%.2f"):format(tostring(group.Position), group.GroupTransparency),
				("%s t=0"):format(tostring(home)),
				group.Position == home and group.GroupTransparency == 0
			)
			-- Shine: no band left mid-sweep (no overlay, or its band already at the end)
			local plate = frame()
			motion.Shine(plate)
			h.frames(1)
			local overlay = plate:FindFirstChild("MotionShine")
			local band = overlay and overlay:FindFirstChildOfClass("UIGradient")
			h.check(
				res,
				"reduced_shine_no_sweep",
				band and tostring(band.Offset) or "no overlay",
				"no overlay or band at (1, 0)",
				overlay == nil or (band ~= nil and band.Offset == Vector2.new(1, 0))
			)
			-- Pulse: returns a stop function and nothing loops (the property stays put)
			local glow = frame()
			local stop = motion.Pulse(glow, { BackgroundTransparency = 0.8 }, 0.2)
			h.frames(3)
			task.wait(0.15)
			h.check(res, "reduced_pulse_returns_stop", typeof(stop), "function", type(stop) == "function")
			h.check(res, "reduced_pulse_no_loop", glow.BackgroundTransparency, 0, glow.BackgroundTransparency == 0)
			if type(stop) == "function" then
				stop()
			end
			-- Shake: stays at home
			local shaken = frame()
			local shakeHome = shaken.Position
			motion.Shake(shaken, 8, 0.3)
			h.frames(1)
			task.wait(0.06)
			h.check(
				res,
				"reduced_shake_still",
				tostring(shaken.Position),
				tostring(shakeHome),
				shaken.Position == shakeHome
			)
			-- Float: no rising text
			local host = frame()
			motion.Float(host, "+$1", Color3.new(1, 1, 1), UDim2.fromOffset(0, 0))
			h.frames(1)
			h.check(
				res,
				"reduced_float_nothing",
				host:FindFirstChild("MotionFloat") and "MotionFloat shown" or "none",
				"none",
				host:FindFirstChild("MotionFloat") == nil
			)
			-- Not reduced (proves the checks above are not vacuous): Pop grows and Pulse moves
			if not GuiService.ReducedMotionEnabled then
				player:SetAttribute(cfg.ReduceAttr, false)
				local popped = frame()
				motion.Pop(popped)
				local peak = 1
				for _ = 1, 6 do
					h.frames(1)
					local s = popped:FindFirstChild("MotionScale")
					peak = math.max(peak, s and s.Scale or 1)
				end
				h.check(res, "pop_animates_when_not_reduced", peak, "> 1", peak > 1.001)
				local pulsing = frame()
				local stopPulse = motion.Pulse(pulsing, { BackgroundTransparency = 0.8 }, 0.2)
				task.wait(0.12)
				local moved = pulsing.BackgroundTransparency
				if type(stopPulse) == "function" then
					stopPulse()
				end
				h.check(res, "pulse_animates_when_not_reduced", moved, "> 0", moved > 0.001)
				h.check(
					res,
					"pulse_stop_restores",
					pulsing.BackgroundTransparency,
					0,
					pulsing.BackgroundTransparency == 0
				)
			end
		end)
		player:SetAttribute(cfg.ReduceAttr, saved)
		probeGui:Destroy()
		if not ok then
			error(err)
		end
	end

	---------------------------------------------------------------------------------------------------------------
	-- Safe area

	-- A ScreenGui's drawing area in screen pixels (its own AbsolutePosition / AbsoluteSize follow ScreenInsets), in
	-- the same space as h.rect.
	local function guiRect(gui)
		local tl = GuiService:GetGuiInset()
		return h.R(gui.AbsolutePosition.X + tl.X, gui.AbsolutePosition.Y + tl.Y, gui.AbsoluteSize.X, gui.AbsoluteSize.Y)
	end

	local function insetGuis()
		local list = {}
		for _, gui in playerGui:GetChildren() do
			if
				gui:IsA("ScreenGui")
				and not Spec.IgnoreGuis[gui.Name]
				and not cfg.FullBleed[gui.Name]
				and gui.Name ~= cfg.ProbeGui
			then
				table.insert(list, gui)
			end
		end
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
		return list
	end

	local function probeGui(insets)
		local g = Instance.new("ScreenGui")
		g.Name = cfg.ProbeGui
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.Parent = playerGui
		if insets then
			g.ScreenInsets = insets
		end
		return g
	end

	local function insetChecks(res, notch)
		h.waitGuis()
		local wrong = {}
		for _, gui in insetGuis() do
			if gui.ScreenInsets ~= Enum.ScreenInsets.DeviceSafeInsets then
				table.insert(wrong, gui.Name .. "=" .. gui.ScreenInsets.Name)
			end
		end
		h.checkList(res, "screen_insets_device_safe", wrong)
		-- A ScreenGui added after join gets it too (SafeInsets listens to PlayerGui.ChildAdded)
		local late = probeGui(nil)
		h.frames(2)
		local got = late.ScreenInsets
		late:Destroy()
		h.check(res, "screen_insets_late_gui", got.Name, "DeviceSafeInsets", got == Enum.ScreenInsets.DeviceSafeInsets)
		-- Every shown button and text inside its gui's safe rect (clipped by scrolling frames)
		local outside = {}
		for _, gui in insetGuis() do
			if gui.Enabled then
				local safe = guiRect(gui)
				for _, d in gui:GetDescendants() do
					local judged = d:IsA("GuiButton") or (d:IsA("TextLabel") and d.Text ~= "")
					if judged and h.visible(d) then
						local r = h.clipped(d, h.rect)
						if r and r.w > 0 and r.h > 0 and not h.contains(safe, r) then
							table.insert(outside, h.pathOf(d) .. h.rstr(r) .. " safe " .. h.rstr(safe))
						end
					end
				end
			end
		end
		h.checkList(res, "ui_inside_safe_area", outside)
		if notch then
			-- The device really has an unsafe area: the safe-area rect is smaller than the full screen
			local full, safe = probeGui(Enum.ScreenInsets.None), probeGui(Enum.ScreenInsets.DeviceSafeInsets)
			h.frames(2)
			local fs, ss = full.AbsoluteSize, safe.AbsoluteSize
			full:Destroy()
			h.check(
				res,
				"device_has_unsafe_area",
				("full %s safe %s"):format(tostring(fs), tostring(ss)),
				"safe smaller than full (notched device)",
				ss.X < fs.X - 0.5 or ss.Y < fs.Y - 0.5
			)
			local mismatched = {}
			for _, gui in insetGuis() do
				if gui.IgnoreGuiInset and (gui.AbsoluteSize - ss).Magnitude > 0.5 then
					table.insert(mismatched, ("%s %s"):format(gui.Name, tostring(gui.AbsoluteSize)))
				end
			end
			safe:Destroy()
			h.checkList(res, "guis_use_safe_area_rect", mismatched)
		end
	end

	function scenarios.ui_safe_insets(res)
		insetChecks(res, false)
	end
	function scenarios.ui_safe_insets_notch(res)
		insetChecks(res, true)
	end

	---------------------------------------------------------------------------------------------------------------
	-- Gamepad focus

	local function usesGamepad()
		local ok, preferred = pcall(function()
			return UserInputService.PreferredInput
		end)
		if ok and preferred then
			return preferred == Enum.PreferredInput.Gamepad
		end
		return string.find(UserInputService:GetLastInputType().Name, "^Gamepad") ~= nil
	end

	-- ContextActionService actions bound to ButtonB (any name)
	local function buttonBCount()
		local ok, all = pcall(function()
			return ContextActionService:GetAllBoundActionInfo()
		end)
		local n = 0
		for _, info in ok and all or {} do
			for _, input in info.inputTypes or {} do
				if input == cfg.ButtonB then
					n += 1
				end
			end
		end
		return n
	end

	-- The panel's top-left visible, selectable button (topmost row first, 1 px rows, then leftmost); nil if none.
	local function topLeftButton(panel)
		local best
		for _, d in panel:GetDescendants() do
			if d:IsA("GuiButton") and d.Selectable and not cfg.NotFocusable[d.Name] and h.visible(d) then
				local r = h.clipped(d, h.rect)
				if r and r.w > 0 and r.h > 0 then
					if not best or r.y < best.r.y - 1 or (math.abs(r.y - best.r.y) <= 1 and r.x < best.r.x) then
						best = { b = d, r = r }
					end
				end
			end
		end
		return best and best.b
	end

	local function name(obj)
		return obj and h.pathOf(obj) or "nil"
	end

	local function setSelection(obj)
		pcall(function()
			GuiService.SelectedObject = obj
		end)
	end

	local function panelList()
		local list = {}
		for path, switchName in Spec.PanelSwitch.Names do
			table.insert(list, { Path = path, Name = switchName, Tag = string.lower(switchName) })
		end
		table.sort(list, function(a, b)
			return a.Path < b.Path
		end)
		return list
	end

	local function eachPanel(res, fn)
		local switch = h.panelSwitch()
		h.check(
			res,
			"panel_switch_module",
			switch and "module" or "missing",
			"Client/PanelSwitch with Toggle and Close",
			switch ~= nil and type(switch.Toggle) == "function" and type(switch.Close) == "function"
		)
		if not (switch and type(switch.Toggle) == "function" and type(switch.Close) == "function") then
			return
		end
		local savedSel = GuiService.SelectedObject
		local restore = h.setPanels({})
		for _, p in panelList() do
			local panel = h.find(p.Path)
			if not panel then
				h.check(res, "panel_present_" .. p.Tag, "missing", p.Path, false)
				continue
			end
			h.setPanels({})
			fn(switch, p, panel)
		end
		restore()
		setSelection(savedSel)
	end

	local function gamepadChecks(res)
		local target = h.find(cfg.RestoreTarget)
		h.check(
			res,
			"restore_target_present",
			name(target),
			cfg.RestoreTarget .. " (a shown GuiButton)",
			target ~= nil and target:IsA("GuiButton") and h.visible(target)
		)
		eachPanel(res, function(switch, p, panel)
			setSelection(target)
			h.frames(1)
			local bBefore = buttonBCount()
			switch.Toggle(p.Name)
			h.frames(cfg.FocusFrames)
			h.check(res, "gamepad_panel_opened_" .. p.Tag, panel.Visible, true, panel.Visible == true)
			if not panel.Visible then
				return
			end
			local want = topLeftButton(panel)
			local sel = GuiService.SelectedObject
			h.check(res, "gamepad_first_button_" .. p.Tag, name(sel), name(want), sel == want)
			local bOpen = buttonBCount()
			h.check(res, "gamepad_buttonb_bound_" .. p.Tag, bOpen - bBefore, ">= 1 new ButtonB action", bOpen > bBefore)
			switch.Close(p.Name)
			h.frames(2)
			sel = GuiService.SelectedObject
			h.check(res, "gamepad_selection_restored_" .. p.Tag, name(sel), name(target), sel == target)
			h.check(res, "gamepad_buttonb_unbound_" .. p.Tag, buttonBCount(), bBefore, buttonBCount() == bBefore)
		end)
		-- Nothing was selected before: closing clears the selection
		local switch = h.panelSwitch()
		local index = h.find("RacerIndex/Panel")
		if switch and index then
			local restore = h.setPanels({})
			setSelection(nil)
			switch.Toggle("Index")
			h.frames(cfg.FocusFrames)
			switch.Close("Index")
			h.frames(2)
			local sel = GuiService.SelectedObject
			h.check(res, "gamepad_selection_cleared_index", name(sel), "nil", sel == nil)
			restore()
		end
	end

	local function mouseChecks(res)
		eachPanel(res, function(switch, p, panel)
			setSelection(nil)
			h.frames(1)
			local bBefore = buttonBCount()
			switch.Toggle(p.Name)
			h.frames(cfg.FocusFrames)
			local sel = GuiService.SelectedObject
			h.check(res, "no_gamepad_open_keeps_selection_" .. p.Tag, name(sel), "nil", sel == nil)
			h.check(res, "no_gamepad_no_buttonb_bind_" .. p.Tag, buttonBCount(), bBefore, buttonBCount() == bBefore)
			switch.Close(p.Name)
			h.frames(2)
			sel = GuiService.SelectedObject
			h.check(res, "no_gamepad_close_keeps_selection_" .. p.Tag, name(sel), "nil", sel == nil)
			h.check(res, "no_gamepad_panel_closed_" .. p.Tag, panel.Visible, false, panel.Visible == false)
		end)
	end

	function scenarios.ui_panel_focus(res)
		h.waitGuis()
		if usesGamepad() then
			gamepadChecks(res)
		else
			mouseChecks(res)
		end
	end

	function scenarios.ui_gamepad_focus(res)
		h.waitGuis()
		local pad = usesGamepad()
		h.check(res, "preferred_input_is_gamepad", pad, true, pad)
		if pad then
			gamepadChecks(res)
		end
	end

	-- After a gamepad DPad press with a panel open (Key click): the selection is still inside that panel
	after.gamepad_selection_in_panel = function(res, ctx)
		local open = ctx.spec and ctx.spec.Prepare and ctx.spec.Prepare.Open or {}
		local panel = open[1] and h.find(open[1])
		local sel = GuiService.SelectedObject
		h.check(
			res,
			"gamepad_selection_in_panel",
			name(sel),
			"a descendant of " .. tostring(open[1]),
			panel ~= nil and sel ~= nil and sel:IsDescendantOf(panel)
		)
	end

	return { Scenarios = scenarios, After = after }
end

return Access
