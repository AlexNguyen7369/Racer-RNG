--!nonstrict
-- Test-first progression UI contract. No gameplay calls; state comes from the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tree = require(Shared.UpgradeTree)
local Tracks = require(Shared.TrackRegistry)
local WorkshopConfig = require(Shared.WorkshopConfig)
local Format = require(Shared.HudFormat)
local WeatherConfig = require(Shared.WeatherConfig)
local Spec = require(script.Parent.UiSpec)
local Progression = {}

function Progression.Build(h)
	local scenarios = {}
	local function expect(res, name, actual, wanted)
		h.check(res, name, actual, wanted, actual == wanted)
	end
	local function label(res, path)
		local obj = h.find(path)
		h.check(
			res,
			"label_present_" .. string.lower(path),
			obj and obj.ClassName or "missing",
			"TextLabel",
			obj ~= nil and obj:IsA("TextLabel")
		)
		return obj and h.text(obj) or ""
	end
	local function state()
		local owned = {}
		local data = h.player:FindFirstChild("Upgrades")
		if data then
			for _, tile in data:GetChildren() do
				owned[tile.Name] = true
			end
		end
		local stats = h.player:FindFirstChild("leaderstats")
		return {
			Owned = owned,
			Money = stats and stats.Money.Value or 0,
			BestTrack = h.player:GetAttribute("BestTrack") or 0,
			TrackCount = #Tracks.Chain(),
		}
	end
	function scenarios.ui_upgrades(res)
		local canvas = h.find("RacerUpgrades/Panel/Canvas")
		h.check(
			res,
			"upgrade_canvas_scrolls",
			canvas and canvas.ClassName or "missing",
			"ScrollingFrame",
			canvas ~= nil and canvas:IsA("ScrollingFrame") and canvas.ScrollingEnabled and canvas.ClipsDescendants
		)
		local truth = state()
		local count = h.player:GetAttribute("UpgradesBuyable")
		expect(res, "buyable_count_matches_tree", count, Tree.BuyableCount(truth))
		local badge = h.find("RacerProgression/UpgradeButton/Badge")
		h.check(res, "upgrade_badge_present", badge ~= nil, true, badge ~= nil)
		if badge then
			expect(res, "upgrade_badge_visible_with_buyable", badge.Visible, type(count) == "number" and count > 0)
			if type(count) == "number" and count > 0 then
				expect(res, "upgrade_badge_server_count", h.text(badge), tostring(count))
			end
		end
		for _, tile in Tree.Tiles() do
			local button = canvas and canvas:FindFirstChild(tile.Id)
			h.check(
				res,
				"tile_present_" .. tile.Id,
				button and button.ClassName or "missing",
				"GuiButton",
				button ~= nil and button:IsA("GuiButton")
			)
			if button and button:IsA("GuiButton") then
				local canBuy, reason = Tree.CanBuy(truth, tile.Id)
				expect(res, "tile_enabled_" .. tile.Id, button.Active, canBuy)
				expect(res, "tile_width_" .. tile.Id, button.Size.X.Offset, Spec.Progression.TileSize.X)
				expect(res, "tile_height_" .. tile.Id, button.Size.Y.Offset, Spec.Progression.TileSize.Y)
				local text = h.text(button)
				local wanted = reason == "owned" and "OWNED"
					or reason == "locked" and "?"
					or reason == "gated" and ("Reach Track " .. Tree.RequiredTrack(tile.Id, truth.TrackCount))
					or Format.MoneyText(Tree.Price(tile.Id))
				h.check(res, "tile_truth_" .. tile.Id, text, wanted, string.find(text, wanted, 1, true) ~= nil)
				local angled = 0
				for _, part in button:GetDescendants() do
					if part:IsA("Frame") and part.BackgroundTransparency < 1 and math.abs(part.Rotation) % 90 > 1 then
						angled += 1
					end
				end
				h.check(res, "tile_hex_geometry_" .. tile.Id, angled, ">=2 slanted visible polygon parts", angled >= 2)
			end
		end
		if canvas and canvas:IsA("ScrollingFrame") then
			local restore = h.setPanels({ "RacerUpgrades/Panel" })
			local original = canvas.CanvasPosition
			for _, tile in Tree.Tiles() do
				local b = canvas:FindFirstChild(tile.Id)
				if b and b:IsA("GuiButton") then
					local position = b.AbsolutePosition - canvas.AbsolutePosition + canvas.CanvasPosition
					canvas.CanvasPosition = Vector2.new(math.max(0, position.X - 8), math.max(0, position.Y - 8))
					h.frames(2)
					local br, cr = h.rect(b), h.rect(canvas)
					h.check(
						res,
						"tile_pan_reachable_" .. tile.Id,
						{ br, cr },
						"whole tile inside scrolled window",
						h.contains(cr, br)
					)
					local top = h.top(h.centre(br))
					h.check(
						res,
						"tile_pan_hit_" .. tile.Id,
						top and top.Name or "nothing",
						tile.Id,
						top ~= nil and (top == b or b:IsAncestorOf(top))
					)
				end
			end
			canvas.CanvasPosition = original
			restore()
		end
		local worldPad = false
		for _, pad in CollectionService:GetTagged("UpgradePad") do
			if pad:IsDescendantOf(workspace) and not pad:FindFirstAncestor("Workshops") then
				worldPad = pad:IsA("BasePart")
			end
		end
		expect(res, "upgrade_world_pad_present", worldPad, true)
	end
	function scenarios.ui_workshop_modal(res)
		local level = h.player:GetAttribute("WorkshopLevel")
		h.check(res, "workshop_level_replicated", level, "number", type(level) == "number")
		local current = type(level) == "number" and level or 1
		local nextLevel = WorkshopConfig.Levels[current + 1]
		local money = state().Money
		local buy = h.find("RacerWorkshop/Panel/Buy")
		h.check(
			res,
			"workshop_buy_present",
			buy and buy.ClassName or "missing",
			"GuiButton",
			buy ~= nil and buy:IsA("GuiButton")
		)
		if buy then
			expect(
				res,
				"workshop_buy_only_affordable_next_level",
				buy.Active,
				nextLevel ~= nil and money >= nextLevel.Price
			)
		end
		local text = label(res, "RacerWorkshop/Panel/Level")
		h.check(
			res,
			"workshop_current_level_shown",
			text,
			tostring(current),
			string.find(text, tostring(current), 1, true) ~= nil
		)
		local price = label(res, "RacerWorkshop/Panel/Price")
		local want = nextLevel and Format.MoneyText(nextLevel.Price) or "MAX"
		h.check(res, "workshop_next_money_price", price, want, string.find(price, want, 1, true) ~= nil)
		label(res, "RacerWorkshop/Panel/Result")
		local plots = workspace:FindFirstChild("Workshops")
		local plot = plots and plots:FindFirstChild("Plot_" .. tostring(h.player:GetAttribute("Plot")))
		h.check(
			res,
			"workshop_plot_owned",
			plot and plot:GetAttribute("Owner"),
			h.player.UserId,
			plot ~= nil and plot:GetAttribute("Owner") == h.player.UserId
		)
		local pad = plot and plot:FindFirstChild("UpgradePad", true)
		local prompt = pad and pad:FindFirstChildWhichIsA("ProximityPrompt", true)
		h.check(res, "workshop_e_prompt_present", prompt ~= nil, true, prompt ~= nil)
		if prompt then
			expect(res, "workshop_prompt_keyboard_e", prompt.KeyboardKeyCode.Name, "E")
			h.check(
				res,
				"workshop_prompt_reachable",
				prompt.MaxActivationDistance,
				">0",
				prompt.MaxActivationDistance > 0
			)
		end
	end
	function scenarios.ui_progression_layout(res)
		for _, vpSpec in Spec.Viewports do
			local rect, vp = h.provider(vpSpec)
			for _, name in { "Upgrades", "Workshop", "Welcome" } do
				local panel = h.find("Racer" .. name .. "/Panel")
				local race, roll, turbo = h.find(Spec.Hud.Race), h.find("RollToast/Toast"), h.find(Spec.Hud.Turbo)
				if panel and race and roll and turbo then
					local p, a, r, t = rect(panel), rect(race), rect(roll), rect(turbo)
					local minimum = math.max(a.y + a.h, r.y + r.h) + Spec.PanelTopMargin
					local beside = p.x >= r.x + r.w - Spec.Tolerance or p.x + p.w <= r.x + Spec.Tolerance
					h.check(
						res,
						"panel_below_roll_" .. string.lower(name) .. "_" .. vpSpec.Name,
						p.y,
						minimum,
						beside or p.y >= minimum - Spec.Tolerance
					)
					h.check(
						res,
						"panel_below_race_" .. string.lower(name) .. "_" .. vpSpec.Name,
						p.y,
						a.y + a.h + Spec.PanelTopMargin,
						p.y >= a.y + a.h + Spec.PanelTopMargin - Spec.Tolerance
					)
					h.check(
						res,
						"panel_compact_no_overlap_" .. string.lower(name) .. "_" .. vpSpec.Name,
						h.intersects(p, r),
						false,
						not h.intersects(p, r)
					)
					h.check(
						res,
						"panel_above_turbo_" .. string.lower(name) .. "_" .. vpSpec.Name,
						p.y + p.h,
						t.y,
						p.y + p.h <= t.y - Spec.PanelTopMargin + Spec.Tolerance
					)
					h.check(
						res,
						"panel_positive_size_" .. string.lower(name) .. "_" .. vpSpec.Name,
						{ p.w, p.h },
						"positive viewport-contained area",
						p.w > 0 and p.h > 0 and p.x >= 0 and p.x + p.w <= vp.X and p.y + p.h <= vp.Y
					)
				else
					expect(res, "panel_layout_dependencies_" .. string.lower(name) .. "_" .. vpSpec.Name, false, true)
				end
			end
		end
	end
	function scenarios.ui_progression_hud(res)
		-- The workshop rate is intentionally shown only inside the Workshop upgrade panel.
		local restore = h.setPanels({ "RacerWorkshop/Panel" })
		local rateLabel = h.find("RacerWorkshop/Panel/Rate")
		local deadline = os.clock() + Spec.HiddenWhilePanelOpenWait
		while rateLabel and not h.visible(rateLabel) and os.clock() < deadline do
			h.frames(1)
		end
		h.check(
			res,
			"workshop_rate_shown_in_upgrade_panel",
			rateLabel ~= nil and h.visible(rateLabel),
			true,
			rateLabel ~= nil and h.visible(rateLabel)
		)
		local rate = h.player:GetAttribute("WorkshopRate")
		local text = label(res, "RacerWorkshop/Panel/Rate")
		local shown = tonumber(string.match(text, "%+([%d%.]+)"))
		h.check(
			res,
			"workshop_panel_server_rate",
			shown or "missing",
			rate or "missing",
			type(rate) == "number" and shown ~= nil and math.abs(shown - rate) <= Spec.Progression.WorkshopRateStep
		)
		local inside = h.player:GetAttribute("InWorkshop") == true
		expect(res, "workshop_panel_active_state", string.find(text, "ACTIVE", 1, true) ~= nil, inside)
		local button = h.find("RacerProgression/UpgradeButton")
		if button then
			expect(res, "upgrade_button_width", button.Size.X.Offset, 110)
			expect(res, "upgrade_button_height", button.Size.Y.Offset, 40)
			-- UDim scales are float32 (0.22 reads back as 0.2199999988): compare within 1e-4, not exactly
			local top = button.Position.Y.Scale
			h.check(res, "upgrade_button_top", top, 0.22, math.abs(top - 0.22) <= 1e-4)
			expect(res, "upgrade_button_right", button.Position.X.Offset, -16)
		else
			expect(res, "upgrade_button_present", false, true)
		end
		restore()
	end
	function scenarios.ui_offline_welcome(res)
		local speed, seconds = h.player:GetAttribute("OfflineSpeed"), h.player:GetAttribute("OfflineSeconds")
		h.check(
			res,
			"offline_fixture_present",
			{ speed, seconds },
			"offline_welcome setup: positive Speed and Seconds",
			type(speed) == "number" and speed > 0 and type(seconds) == "number" and seconds > 0
		)
		local earnings = label(res, "RacerWelcome/Panel/Earnings")
		local away = label(res, "RacerWelcome/Panel/Away")
		local want = Format.SpeedText(speed)
		h.check(res, "offline_speed_matches_credit", earnings, want, string.find(earnings, want, 1, true) ~= nil)
		-- Seconds are displayed as a human duration; test exact 3661 fixture as 1h 1m 1s.
		if seconds == 3661 then
			for _, unit in { "1h", "1m", "1s" } do
				h.check(res, "offline_duration_" .. unit, away, unit, string.find(away, unit, 1, true) ~= nil)
			end
		end
		local panel = h.find("RacerWelcome/Panel")
		h.check(
			res,
			"offline_positive_shows_welcome",
			panel and h.visible(panel),
			true,
			panel ~= nil and h.visible(panel)
		)
	end
	function scenarios.ui_weather(res)
		local event = ReplicatedStorage:GetAttribute("WeatherEvent")
		local endsAt = ReplicatedStorage:GetAttribute("WeatherEndsAt")
		local text = label(res, "RacerProgression/WeatherBanner")
		local banner = h.find("RacerProgression/WeatherBanner")
		expect(
			res,
			"weather_banner_hidden_without_event",
			banner and banner.Visible,
			type(event) == "string" and event ~= ""
		)
		h.check(res, "weather_event_replicated", event or "missing", "string", type(event) == "string")
		h.check(res, "weather_end_replicated", endsAt or "missing", "number", type(endsAt) == "number")
		if type(event) == "string" then
			local config = WeatherConfig.Events[event]
			local name = config and config.Name or event
			h.check(
				res,
				"weather_banner_event",
				text,
				name,
				string.find(string.lower(text), string.lower(name), 1, true) ~= nil
			)
		end
		if type(endsAt) == "number" and endsAt > workspace:GetServerTimeNow() then
			local shown = tonumber(string.match(text, "(%d+)s"))
			local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			h.check(
				res,
				"weather_banner_server_countdown",
				shown or "missing",
				remaining,
				shown ~= nil and math.abs(shown - remaining) <= 1
			)
		end
	end
	function scenarios.ui_offline_zero(res)
		expect(res, "offline_zero_fixture_speed", h.player:GetAttribute("OfflineSpeed"), 0)
		expect(res, "offline_zero_fixture_seconds", h.player:GetAttribute("OfflineSeconds"), 0)
		local panel = h.find("RacerWelcome/Panel")
		expect(res, "offline_zero_hides_welcome", panel and panel.Visible, false)
	end
	function scenarios.ui_progression_world(res)
		h.frames(2)
		local setup = h.player:GetAttribute("UiTestProgressionFixture")
		-- ProgressionUi polls the pad every 0.25 s and the server's teleport must replicate first: wait (up to
		-- WorldPadWait s) for the panels to reach the expected state before judging them
		local function settled()
			for path in Spec.PanelSwitch.Names do
				local obj = h.find(path)
				if (obj and obj.Visible) ~= (setup == "upgrade_world_enter" and path == "RacerUpgrades/Panel") then
					return false
				end
			end
			return true
		end
		local deadline = os.clock() + Spec.Progression.WorldPadWait
		while not settled() and os.clock() < deadline do
			h.frames(1)
		end
		h.check(
			res,
			"world_fixture_present",
			setup,
			"upgrade_world_enter or upgrade_world_leave",
			setup == "upgrade_world_enter" or setup == "upgrade_world_leave"
		)
		for path in Spec.PanelSwitch.Names do
			local obj = h.find(path)
			local want = setup == "upgrade_world_enter" and path == "RacerUpgrades/Panel"
			expect(res, "world_pad_panel_" .. string.lower(path), obj and obj.Visible, want)
		end
	end
	return scenarios
end

-- E is real user input. Never fires a prompt signal or forges WorkshopOpen to prove owner handling.
function Progression.RunInput(spec, res, h)
	local restore = h.setPanels({})
	local expectedFixture = spec.Expect.WorkshopOpen and "workshop_owner_prompt" or "workshop_foreign_prompt"
	local ready = h.player:GetAttribute("UiTestProgressionFixture") == expectedFixture
	h.check(res, "prompt_fixture_ready", h.player:GetAttribute("UiTestProgressionFixture"), expectedFixture, ready)
	if not ready then
		restore()
		return res
	end
	-- The CLIENT's avatar must be inside the prompt's MaxActivationDistance (the server setup verifies the replicated
	-- position too): an E pressed out of range proves nothing, so the click fails here instead of passing as "no panel".
	local prompt, distance = nil, nil
	local plots = workspace:FindFirstChild("Workshops")
	for _, plot in plots and plots:GetChildren() or {} do
		local owner = plot:GetAttribute("Owner")
		local mine = owner == h.player.UserId
		local foreign = type(owner) == "number" and owner > 0 and owner ~= h.player.UserId
		if (spec.Expect.WorkshopOpen and mine) or (not spec.Expect.WorkshopOpen and foreign) then
			local pad = plot:FindFirstChild("UpgradePad", true)
			prompt = pad and pad:FindFirstChildWhichIsA("ProximityPrompt", true)
			break
		end
	end
	local root = h.player.Character and h.player.Character:FindFirstChild("HumanoidRootPart")
	if prompt and prompt.Parent:IsA("BasePart") and root then
		distance = (root.Position - prompt.Parent.Position).Magnitude
	end
	local inRange = distance ~= nil and distance <= prompt.MaxActivationDistance
	h.check(
		res,
		"prompt_in_range_client",
		distance and math.floor(distance * 10 + 0.5) / 10,
		prompt and prompt.MaxActivationDistance,
		inRange
	)
	if not inRange then
		restore()
		return res
	end
	local pressed = false
	local conn = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode.Name == spec.Key then
			pressed = true
		end
	end)
	ReplicatedStorage:SetAttribute("UiTestClickDone", nil)
	h.player:SetAttribute("UiTestClickTarget", HttpService:JSONEncode({ id = spec.Id, key = spec.Key, done = spec.Id }))
	print("[UITEST] KEY " .. spec.Id .. " key=" .. spec.Key .. " done=" .. spec.Id)
	local deadline = os.clock() + Spec.Waits.ClickDone
	while ReplicatedStorage:GetAttribute("UiTestClickDone") ~= spec.Id and os.clock() < deadline do
		task.wait(0.05)
	end
	conn:Disconnect()
	h.player:SetAttribute("UiTestClickTarget", nil)
	h.check(res, "prompt_e_pressed", pressed, true, pressed)
	h.check(
		res,
		"prompt_input_acknowledged",
		ReplicatedStorage:GetAttribute("UiTestClickDone"),
		spec.Id,
		ReplicatedStorage:GetAttribute("UiTestClickDone") == spec.Id
	)
	task.wait(Spec.Waits.ClickSettle)
	h.frames(2)
	for _, path in h.allPanels() do
		local panel = h.find(path)
		local want = spec.Expect.WorkshopOpen and path == "RacerWorkshop/Panel"
		h.check(
			res,
			"prompt_panel_" .. string.lower(path),
			panel and panel.Visible,
			want,
			panel ~= nil and panel.Visible == want
		)
	end
	restore()
	return res
end

return Progression
