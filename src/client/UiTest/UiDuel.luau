--!nonstrict
-- Duel UI contract (docs/DUEL_SPEC.md section 3, Client/DuelUi), written before the UI exists. Owned by ui-test-writer.
-- The server fixtures (UiTestSetup duel_*) fire Remotes.Duel at the test client; this module records every message
-- when it arrives and samples the UI by itself (the countdown lasts 3 s, the toast 3 s: a scenario triggered later
-- would miss them). ui_duel then judges the LATEST message from those samples. Nothing here fires a remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(script.Parent.UiSpec)
local D = Spec.Duel

local Duel = {}

local h = nil -- helpers from UiScenarios (Observe)
local records = {} -- one per Remotes.Duel message: { msg, t, left, prep, shown, samples, probe, done }
local lastPrep = nil

local function shown(path)
	local o = h.find(path)
	return o ~= nil and o:IsA("GuiObject") and h.visible(o)
end

local function textOf(path)
	local o = h.find(path)
	return o and (o:IsA("TextLabel") or o:IsA("TextButton")) and o.Text or "missing"
end

-- Every other PanelSwitch panel that is open (Index, Stats, Settings, Rebirth, Upgrades, Workshop, Welcome).
local function othersOpen()
	local list = {}
	for path in Spec.PanelSwitch.Names do
		if path ~= D.Pick and path ~= D.Invite and shown(path) then
			table.insert(list, path)
		end
	end
	table.sort(list)
	return table.concat(list, ",")
end

-- "Track1:TextButton:TRACK 1,..." for every GuiButton in PickPanel/Tracks.
local function trackButtons()
	local tracks = h.find(D.Pick .. "/Tracks")
	local list = {}
	for _, c in tracks and tracks:GetChildren() or {} do
		if c:IsA("GuiButton") then
			table.insert(list, ("%s:%s:%s"):format(c.Name, c.ClassName, c:IsA("TextButton") and c.Text or ""))
		end
	end
	table.sort(list)
	return table.concat(list, ",")
end

local function snapshot()
	return {
		pick = shown(D.Pick),
		invite = shown(D.Invite),
		toast = shown(D.Toast),
		toastText = textOf(D.Toast),
		others = othersOpen(),
		rollToast = shown("RollToast/Toast"),
		tracks = trackButtons(),
		opponent = textOf(D.Pick .. "/Opponent"),
		inviteText = textOf(D.Invite .. "/Text"),
	}
end

-- Opens a PanelSwitch panel by its name through the real switch. Returns its path and the switch.
local function openPanel(name)
	local module = script.Parent.Parent:FindFirstChild(Spec.PanelSwitch.Module)
	local ok, Switch = pcall(require, module)
	if not (ok and type(Switch) == "table" and type(Switch.Toggle) == "function") then
		return nil
	end
	for path, switchName in Spec.PanelSwitch.Names do
		if switchName == name then
			local o = h.find(path)
			if o and not o.Visible then
				Switch.Toggle(name)
			end
			h.frames(2)
			return path, Switch
		end
	end
	return nil
end

local function sample(rec)
	local msg = rec.msg
	task.wait(D.ShowGrace)
	h.frames(1)
	rec.shown = snapshot()
	if msg.Type == "Countdown" and type(msg.ServerStart) == "number" then
		rec.samples = {}
		local stop = msg.ServerStart + D.GoSeconds + D.Grace + 0.3
		local deadline = os.clock() + 15
		while workspace:GetServerTimeNow() < stop and os.clock() < deadline do
			local label = h.find(D.Countdown)
			local visible = label ~= nil and label:IsA("GuiObject") and h.visible(label)
			if visible and not rec.rect then
				rec.rect, rec.viewport = h.rect(label), h.viewport()
			end
			table.insert(rec.samples, {
				dt = workspace:GetServerTimeNow() - msg.ServerStart,
				shown = visible,
				text = textOf(D.Countdown),
			})
			task.wait(0.05)
		end
	elseif msg.Type == "Result" or msg.Type == "Cancelled" then
		rec.samples = {}
		local probe = msg[D.ProbeField]
		while os.clock() - rec.t < D.ToastSeconds + D.Grace + 0.3 do
			local dt = os.clock() - rec.t
			if type(probe) == "string" and dt >= D.ProbeAt then
				-- A panel opens while the toast shows: the toast must hide (UiSpec.HiddenWhilePanelOpen)
				local before = shown(D.Toast)
				local path, Switch = openPanel(probe)
				local deadline = os.clock() + Spec.HiddenWhilePanelOpenWait
				while shown(D.Toast) and os.clock() < deadline do
					h.frames(1)
				end
				rec.probe = { before = before, panel = path ~= nil and shown(path), toast = shown(D.Toast) }
				if Switch and type(Switch.Close) == "function" then
					Switch.Close(probe)
				end
				break
			end
			table.insert(rec.samples, { dt = dt, shown = shown(D.Toast), text = textOf(D.Toast) })
			task.wait(0.05)
		end
	end
	rec.done = true
end

-- Starts the recorder (once, when the harness starts). helpers: check, checkList, find, frames, visible, rect,
-- viewport, player, playerGui.
function Duel.Observe(helpers)
	if h then
		return
	end
	h = helpers
	-- Fixtures duel_*_over_*: the server asks for a panel to be open BEFORE its message arrives
	h.player:GetAttributeChangedSignal(D.PrepAttr):Connect(function()
		local name = string.match(tostring(h.player:GetAttribute(D.PrepAttr)), "^(%w+):")
		if name then
			local path = openPanel(name)
			lastPrep = { name = name, open = path ~= nil and shown(path), t = os.clock() }
		end
	end)
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
		local remote = remotes and remotes:WaitForChild(D.Remote, 30)
		if not (remote and remote:IsA("RemoteEvent")) then
			return
		end
		remote.OnClientEvent:Connect(function(msg)
			if type(msg) ~= "table" then
				return
			end
			local rec = { msg = msg, t = os.clock() }
			if type(msg.ServerStart) == "number" then
				rec.left = msg.ServerStart - workspace:GetServerTimeNow()
			end
			if lastPrep and os.clock() - lastPrep.t < 3 then
				rec.prep = lastPrep
			end
			lastPrep = nil
			table.insert(records, rec)
			task.spawn(sample, rec)
		end)
	end)
end

-- UiSpec Count = "duel_tracks": the number of tracks the latest PickTrack message offered (0 before any).
function Duel.OfferedTracks()
	for i = #records, 1, -1 do
		local msg = records[i].msg
		if msg.Type == "PickTrack" and type(msg.Tracks) == "table" then
			return #msg.Tracks
		end
	end
	return 0
end

function Duel.Build()
	local scenarios = {}

	-- A Cancelled / Result / Countdown / the other panel's message hides the duel panel(s) `wantOpen` does not name.
	-- When the fixture opened a panel just before (the previous message), that panel must really have been open,
	-- or the hide proves nothing.
	local function panels(res, rec, prefix, wantOpen)
		local s = rec.shown
		h.check(res, prefix .. "_pick_panel", s.pick, wantOpen == "pick", s.pick == (wantOpen == "pick"))
		h.check(res, prefix .. "_invite_panel", s.invite, wantOpen == "invite", s.invite == (wantOpen == "invite"))
		local index = table.find(records, rec)
		local prev = index and records[index - 1]
		if prev and rec.t - prev.t <= 2 and prev.shown and prev.msg.Type ~= rec.msg.Type then
			local opener = prev.msg.Type == "PickTrack" and "pick" or prev.msg.Type == "Invite" and "invite" or nil
			if opener then
				h.check(
					res,
					prefix .. "_panel_open_before_message",
					prev.shown[opener],
					true,
					prev.shown[opener] == true
				)
			end
		end
	end

	-- Samples judged against `wantAt(sample)` -> key, wanted text (false = hidden) or nil (not judged).
	local function judge(res, name, rec, wantAt, phases)
		local bad, seen = {}, {}
		for _, x in rec.samples or {} do
			local want = wantAt(x)
			if want ~= nil then
				local key = want or "hidden"
				seen[key] = true
				local ok = (want == false and not x.shown) or (want ~= false and x.shown and x.text == want)
				if not ok then
					table.insert(bad, ("%+.2fs %s want %s"):format(x.dt, x.shown and x.text or "hidden", key))
				end
			end
		end
		h.checkList(res, name, bad)
		local missing = {}
		for _, key in phases do
			if not seen[key] then
				table.insert(missing, key)
			end
		end
		h.checkList(res, name .. "_phases_sampled", missing)
	end

	function scenarios.ui_duel(res)
		local gui = h.playerGui:FindFirstChild(D.Gui)
		local isGui = gui ~= nil and gui:IsA("ScreenGui")
		h.check(res, "duel_gui_present", gui and gui.ClassName or "missing", "ScreenGui", isGui)
		h.check(res, "duel_gui_ignores_inset", isGui and gui.IgnoreGuiInset, true, isGui and gui.IgnoreGuiInset == true)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local remote = remotes and remotes:FindFirstChild(D.Remote)
		h.check(
			res,
			"duel_remote_present",
			remote and remote.ClassName or "missing",
			"RemoteEvent",
			remote ~= nil and remote:IsA("RemoteEvent")
		)

		-- Every part of the contract, with the texts that never change
		for _, part in
			{
				{ "pick_panel", D.Pick, "Frame" },
				{ "pick_title", D.Pick .. "/Title", "TextLabel", D.PickTitle },
				{ "pick_opponent", D.Pick .. "/Opponent", "TextLabel" },
				{ "pick_tracks", D.Pick .. "/Tracks", "Frame" },
				{ "pick_close", D.Pick .. "/Close", "TextButton", D.CloseText },
				{ "invite_panel", D.Invite, "Frame" },
				{ "invite_title", D.Invite .. "/Title", "TextLabel", D.InviteTitle },
				{ "invite_text", D.Invite .. "/Text", "TextLabel" },
				{ "invite_accept", D.Invite .. "/Accept", "TextButton", D.AcceptText },
				{ "invite_decline", D.Invite .. "/Decline", "TextButton", D.DeclineText },
				{ "countdown", D.Countdown, "TextLabel" },
				{ "toast", D.Toast, "TextLabel" },
			}
		do
			local o = h.find(part[2])
			local ok = o ~= nil and o.ClassName == part[3]
			h.check(res, "duel_part_" .. part[1], o and o.ClassName or "missing", part[3], ok)
			if ok and part[4] then
				h.check(res, "duel_text_" .. part[1], o.Text, part[4], o.Text == part[4])
			end
		end
		-- The countdown and the toast never take a click
		for _, key in { "Countdown", "Toast" } do
			local o = h.find(D[key])
			local inactive = o ~= nil and o:IsA("GuiObject") and not o:IsA("GuiButton") and o.Active == false
			h.check(
				res,
				"duel_" .. string.lower(key) .. "_never_active",
				o and o:IsA("GuiObject") and o.Active,
				false,
				inactive
			)
		end
		local both = shown(D.Pick) and shown(D.Invite)
		h.check(res, "duel_panels_never_both_open", both, false, not both)

		local rec = records[#records]
		if not rec then
			-- No duel message yet: nothing of the duel UI shows (both panels Visible = false at start)
			for _, key in { "Pick", "Invite" } do
				local o = h.find(D[key])
				local hidden = o ~= nil and o:IsA("GuiObject") and o.Visible == false
				h.check(
					res,
					"duel_rest_" .. string.lower(key) .. "_panel_hidden",
					o and o:IsA("GuiObject") and o.Visible,
					false,
					hidden
				)
			end
			for _, key in { "Countdown", "Toast" } do
				local o = h.find(D[key])
				local hidden = o ~= nil and o:IsA("GuiObject") and not h.visible(o)
				h.check(res, "duel_rest_" .. string.lower(key) .. "_hidden", not hidden, false, hidden)
			end
			return
		end

		local deadline = os.clock() + 15
		while not rec.done and os.clock() < deadline do
			task.wait(0.05)
		end
		h.check(res, "duel_message_sampled", rec.done == true, true, rec.done == true)
		if not rec.done then
			return
		end
		local msg, s = rec.msg, rec.shown
		local kind = tostring(msg.Type)
		res.message = kind
		if rec.prep then
			-- duel_*_over_*: another panel was open when the message arrived
			h.check(res, "duel_prepared_panel_was_open_" .. rec.prep.name, rec.prep.open, true, rec.prep.open == true)
		end

		if kind == "PickTrack" then
			panels(res, rec, "duel_pick_message", "pick")
			h.check(res, "duel_pick_closes_other_panels", s.others, "", s.others == "")
			h.check(res, "duel_pick_roll_toast_hidden", s.rollToast, false, s.rollToast == false)
			local opponent = D.OpponentText:format(tostring(msg.Opponent))
			h.check(res, "duel_pick_opponent", s.opponent, opponent, s.opponent == opponent)
			local want = {}
			for _, n in type(msg.Tracks) == "table" and msg.Tracks or {} do
				table.insert(want, ("%s:TextButton:%s"):format(D.TrackName:format(n), D.TrackText:format(n)))
			end
			table.sort(want)
			local wanted = table.concat(want, ",")
			h.check(res, "duel_pick_track_buttons_are_the_offered_tracks", s.tracks, wanted, s.tracks == wanted)
		elseif kind == "Invite" then
			panels(res, rec, "duel_invite_message", "invite")
			h.check(res, "duel_invite_closes_other_panels", s.others, "", s.others == "")
			h.check(res, "duel_invite_roll_toast_hidden", s.rollToast, false, s.rollToast == false)
			local text = D.InviteText:format(tostring(msg.Opponent), tonumber(msg.Track) or -1)
			h.check(res, "duel_invite_text", s.inviteText, text, s.inviteText == text)
		elseif kind == "Countdown" then
			panels(res, rec, "duel_countdown_message", nil)
			local guard = D.BoundaryGuard
			local phases = { D.GoText, "hidden" }
			for n = 1, 3 do
				-- whole second n is watched when its window (n - 1 + guard .. n - guard left) started after sampling did
				if (rec.left or 0) - D.ShowGrace - 0.1 >= n - guard then
					table.insert(phases, tostring(n))
				end
			end
			judge(res, "duel_countdown_follows_server_start", rec, function(x)
				local left = -x.dt
				if left > 0 then
					local frac = left % 1
					if frac >= guard and frac <= 1 - guard then
						return tostring(math.ceil(left))
					end
				elseif x.dt >= guard and x.dt <= D.GoSeconds - guard then
					return D.GoText
				elseif x.dt >= D.GoSeconds + D.Grace then
					return false
				end
				return nil
			end, phases)
			if rec.rect then
				local dx = math.abs(rec.rect.x + rec.rect.w / 2 - rec.viewport.X / 2)
				local dy = math.abs(rec.rect.y + rec.rect.h / 2 - rec.viewport.Y / 2)
				h.check(
					res,
					"duel_countdown_centred_on_screen",
					math.max(dx, dy),
					Spec.Tolerance,
					math.max(dx, dy) <= Spec.Tolerance
				)
			else
				h.check(res, "duel_countdown_centred_on_screen", "never shown", Spec.Tolerance, false)
			end
		elseif kind == "Result" or kind == "Cancelled" then
			local prefix = kind == "Result" and "duel_result" or "duel_cancelled"
			local want = kind == "Result" and D.ResultText[msg.Result] or (D.CancelText[msg.Reason] or D.CancelDefault)
			panels(res, rec, prefix .. "_message", nil)
			h.check(
				res,
				prefix .. "_toast_text",
				s.toast and s.toastText or "hidden",
				want,
				s.toast and s.toastText == want
			)
			if rec.probe then
				local p = rec.probe
				h.check(res, "duel_toast_shown_before_panel_opens", p.before, true, p.before == true)
				h.check(res, "duel_toast_probe_panel_open", p.panel, true, p.panel == true)
				h.check(res, "duel_toast_hidden_while_panel_open", p.toast, false, p.toast == false)
			else
				judge(res, prefix .. "_toast_shown_for_3_s", rec, function(x)
					if x.dt <= D.ToastSeconds - D.Grace then
						return want
					elseif x.dt >= D.ToastSeconds + D.Grace then
						return false
					end
					return nil
				end, { want or "text", "hidden" })
			end
		else
			h.check(res, "duel_message_type_known", kind, "PickTrack, Invite, Countdown, Result or Cancelled", false)
		end
	end

	return scenarios
end

return Duel
