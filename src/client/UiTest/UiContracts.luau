--!nonstrict
-- Additive 2026-10-20 UI contracts. Read-only server truth; no real gameplay/purchase remote calls.
-- The main tester runs these at desktop AND real phone sizes; simulated geometry is additional evidence.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.CarCatalog)
local TrackRegistry = require(Shared.TrackRegistry)
local TrackBuilder = require(Shared.TrackBuilder)
local Format = require(Shared.HudFormat)
local RaceConfig = require(Shared.RaceConfig)
local NpcConfig = require(Shared.NpcConfig)
local Market = require(Shared.MarketConfig)
local Monetization = require(Shared.MonetizationConfig)
local Daily = require(Shared.DailyLoginConfig)
local Spec = require(script.Parent.UiSpec)

local Contracts = {}

function Contracts.Build(h)
	local scenarios, after = {}, {}
	local function check(res, name, got, want)
		h.check(res, name, got, want, got == want)
	end
	local function required(res, path, class)
		local object = h.find(path)
		h.check(
			res,
			"present_" .. path,
			object and object.ClassName or "missing",
			class,
			object ~= nil and object:IsA(class)
		)
		return object and object:IsA(class) and object or nil
	end
	local function text(object)
		return object and h.allText(object) or "missing"
	end
	local function containsText(value, needle)
		return string.find(string.lower(value), string.lower(needle), 1, true) ~= nil
	end
	local function modulePresent(res, name)
		local object = script.Parent.Parent:FindFirstChild(name)
		check(res, "shared_client_module_" .. name, object ~= nil and object:IsA("ModuleScript"), true)
	end
	local function sameLine(a, b)
		return math.abs(a.AbsolutePosition.Y - b.AbsolutePosition.Y) <= Spec.Tolerance
	end

	-- Independent oracle from CHECKPOINT_SPEC (never the UI's own IsOpen / Effective helpers): Track 1 and every track
	-- up to BestTrack are open; the current checkpoint is the saved one clamped into that range.
	local function checkpointState()
		local tracks = TrackRegistry.Chain()
		local best = math.clamp(math.floor(h.player:GetAttribute("BestTrack") or 0), 1, #tracks)
		local current = math.clamp(math.floor(h.player:GetAttribute("Checkpoint") or 1), 1, best)
		return tracks, best, current
	end
	local function speedNow()
		local stats = h.player:FindFirstChild("leaderstats")
		local speed = stats and stats:FindFirstChild("Speed")
		return speed and speed.Value or 0
	end
	-- "PirateCoast" -> "PIRATE COAST" (CHECKPOINT_SPEC section 4: the biome name, upper case)
	local function biomeTitle(biome)
		return string.upper((string.gsub(biome or "", "(%l)(%u)", "%1 %2")))
	end
	local function startText(n, best, current)
		local C = Spec.Checkpoints
		if n > best then
			return C.StartLocked, false
		elseif n == current then
			return C.StartSelected, false
		end
		return C.StartOpen, true
	end

	-- The detail pane (CHECKPOINT_SPEC section 4) showing track n. `speedFrom` is the player's Speed when the pane
	-- was drawn: YOUR SPEED and the status may show any Speed between then and now (the stat grows while racing).
	local function detailChecks(res, prefix, n, speedFrom)
		local C = Spec.Checkpoints
		local tracks, best, current = checkpointState()
		local spec = tracks[n]
		local detail = required(res, C.Detail, "Frame")
		if not (detail and spec) then
			return
		end
		check(res, prefix .. "_shown", h.visible(detail), true)
		required(res, C.Detail .. "/Preview", "ViewportFrame")
		local function label(name)
			local l = detail:FindFirstChild(name)
			return l and l:IsA("TextLabel") and l.Text or "missing"
		end
		check(res, prefix .. "_title", label("Title"), ("TRACK %d · %s"):format(n, string.upper(spec.Name)))
		check(res, prefix .. "_biome", label("Biome"), biomeTitle(spec.Biome))
		local rec = RaceConfig.StatFor(NpcConfig.For(n).Speed)
		check(res, prefix .. "_rec_speed", label("RecSpeed"), C.RecPrefix .. Format.SpeedText(rec))
		check(res, prefix .. "_cash", label("Cash"), C.CashPrefix .. Format.MoneyText(TrackBuilder.CashFor(n)))
		-- YOUR SPEED and the status chip, from one Speed value between speedFrom and now
		local lo, hi = speedFrom or speedNow(), speedNow()
		local your, status = label("YourSpeed"), label("Status")
		local matched = false
		for k = 0, 100 do
			local s = lo + (hi - lo) * k / 100
			local wantStatus = s >= rec and C.Ready or C.NeedFormat:format(Format.SpeedText(rec - s))
			if your == C.YourPrefix .. Format.SpeedText(s) and status == wantStatus then
				matched = true
				break
			end
		end
		local s = speedNow()
		h.check(
			res,
			prefix .. "_your_speed_and_status",
			("%q / %q"):format(your, status),
			("%q / %q"):format(
				C.YourPrefix .. Format.SpeedText(s),
				s >= rec and C.Ready or C.NeedFormat:format(Format.SpeedText(rec - s))
			),
			matched
		)
		local start = detail:FindFirstChild("Start")
		local wantText, wantActive = startText(n, best, current)
		h.check(
			res,
			prefix .. "_start_button",
			start and ("%s %q Active=%s"):format(start.ClassName, h.allText(start), tostring(start.Active)) or "missing",
			("TextButton %q Active=%s"):format(wantText, tostring(wantActive)),
			start ~= nil
				and start:IsA("TextButton")
				and h.allText(start) == wantText
				and start.Active == wantActive
				and (wantActive or start.AutoButtonColor == false)
		)
	end

	function scenarios.ui_checkpoints(res)
		local speedAtOpen = speedNow()
		local restore = h.setPanels({ Spec.Checkpoints.Panel })
		h.frames(2)
		local panel = required(res, Spec.Checkpoints.Panel, "Frame")
		local cards = required(res, Spec.Checkpoints.Cards, "ScrollingFrame")
		if not (panel and cards) then
			restore()
			return
		end
		check(res, "checkpoint_panel_shown", h.visible(panel), true)
		-- HUD_LAYOUT_SPEC section 2 + CHECKPOINT_SPEC section 3 (owner 2026-10-20): the panel uses PanelFrame.Attach
		check(res, "checkpoint_panel_frame_attached", panel:GetAttribute("PanelFrame"), true)
		check(res, "checkpoint_panel_theme", panel:GetAttribute("PanelTheme"), Spec.Checkpoints.PanelTheme)
		required(res, Spec.Checkpoints.Panel .. "/Header/Title", "TextLabel")
		required(res, Spec.Checkpoints.Panel .. "/Header/Icon", "GuiObject")
		local tracks, best, current = checkpointState()
		local expected, shown = {}, 0
		local previous
		-- CHECKPOINT_SPEC section 4 (owner 2026-10-27): each card shows a biome Preview, TRACK n and the biome; locked
		-- cards keep the dim and lock of section 3 but stay clickable (a click only shows the track in Detail).
		for _, track in tracks do
			local n = track.Number
			local prefix = "checkpoint_track_" .. n
			local card = required(res, Spec.Checkpoints.Cards .. "/Track_" .. n, "TextButton")
			expected["Track_" .. n] = true
			if not card then
				continue
			end
			check(res, prefix .. "_order", card.LayoutOrder, n)
			if previous then
				local a, b = previous.AbsolutePosition, card.AbsolutePosition
				check(
					res,
					prefix .. "_reading_order",
					b.Y > a.Y + Spec.Tolerance or (math.abs(b.Y - a.Y) <= Spec.Tolerance and b.X > a.X),
					true
				)
			end
			previous = card
			required(res, h.pathOf(card) .. "/Preview", "ViewportFrame")
			check(res, prefix .. "_number", text(card:FindFirstChild("Number")), "TRACK " .. n)
			check(res, prefix .. "_biome", text(card:FindFirstChild("Biome")), biomeTitle(track.Biome))
			local lock = required(res, h.pathOf(card) .. "/Lock", "Frame")
			local unlocked = n <= best
			if lock then
				check(res, prefix .. "_lock_visible", lock.Visible, not unlocked)
				-- (BackgroundTransparency is a float32: 0.4 reads back as 0.40000000596; equal within float precision only)
				h.check(
					res,
					prefix .. "_lock_transparency",
					lock.BackgroundTransparency,
					Spec.Checkpoints.LockTransparency,
					math.abs(lock.BackgroundTransparency - Spec.Checkpoints.LockTransparency) <= 1e-6
				)
				check(res, prefix .. "_lock_reason", text(lock:FindFirstChild("Need")), "Beat Track " .. n)
				local icon = required(res, h.pathOf(lock) .. "/Icon", "TextLabel")
				check(res, prefix .. "_lock_icon", icon ~= nil and icon.Text ~= "", true)
				-- The lock must not take the click from its card (locked cards are clickable now)
				local swallows = {}
				for _, o in { lock, table.unpack(lock:GetDescendants()) } do
					if o:IsA("GuiButton") or (o:IsA("GuiObject") and o.Active) then
						table.insert(swallows, h.pathOf(o))
					end
				end
				h.checkList(res, prefix .. "_lock_click_through", swallows)
			end
			check(res, prefix .. "_clickable", card.Active, true)
		end
		local extras = {}
		for _, child in cards:GetChildren() do
			if child:IsA("GuiObject") then
				shown += 1
				if not expected[child.Name] then
					table.insert(extras, child.Name)
				end
			end
		end
		check(res, "checkpoint_exact_card_count", shown, #tracks)
		h.checkList(res, "checkpoint_no_extra_cards", extras)
		-- On open the detail pane shows the current checkpoint (section 4)
		detailChecks(res, "checkpoint_detail_on_open", current, speedAtOpen)
		h.geometry.Panel(res, "checkpoint", panel)
		h.geometry.Topmost(res, "checkpoint", panel, cards)
		local header = required(res, Spec.Checkpoints.Panel .. "/Header", "Frame")
		local hint = required(res, Spec.Checkpoints.Panel .. "/Hint", "TextLabel")
		local detail = h.find(Spec.Checkpoints.Detail)
		if header and hint then
			-- Grid and detail pane side by side (phones: pane under the header row): no section overlaps another
			h.geometry.Group(res, "checkpoint_sections", panel, { header, hint, cards, detail })
		end
		local remote = ReplicatedStorage:FindFirstChild("Remotes")
		remote = remote and remote:FindFirstChild("SetCheckpoint")
		check(res, "checkpoint_remote_function", remote ~= nil and remote:IsA("RemoteFunction"), true)
		-- World entry is part of the UI inventory too; actual E/toggle behavior is a real input check.
		local prompts = {}
		for _, object in workspace:GetDescendants() do
			if object:IsA("ProximityPrompt") and object.Name == Spec.Checkpoints.Prompt then
				table.insert(prompts, object)
			end
		end
		check(res, "checkpoint_exactly_one_prompt", #prompts, 1)
		if #prompts == 1 then
			check(res, "checkpoint_prompt_key", prompts[1].KeyboardKeyCode, Enum.KeyCode.E)
			check(res, "checkpoint_prompt_action", prompts[1].ActionText, "Checkpoints")
			check(res, "checkpoint_prompt_distance", prompts[1].MaxActivationDistance, 10)
		end
		restore()
	end

	function after.checkpoint_not_optimistic(res, ctx)
		check(res, "checkpoint_unchanged_after_refused_pick", h.player:GetAttribute("Checkpoint"), ctx.pre.Checkpoint)
		scenarios.ui_checkpoints(res)
	end

	-- After a card click: the panel stays open, the detail pane shows THAT card's track (locked ones too), and the
	-- Start button's text / Active follow the server attributes (CHECKPOINT_SPEC section 4).
	function after.checkpoint_detail_shows_card(res, ctx)
		local n = tonumber(string.match(ctx.path or "", "Track_(%d+)$"))
		check(res, "checkpoint_card_click_target", n ~= nil, true)
		if n then
			detailChecks(res, "checkpoint_detail_after_card", n, ctx.pre and ctx.pre.Speed)
		end
	end

	function scenarios.ui_catalog_manifest(res)
		local module = Shared:FindFirstChild(Spec.Expansion.Module)
		check(res, "expansion_manifest_present", module ~= nil and module:IsA("ModuleScript"), true)
		if not module then
			return
		end
		local ok, manifest = pcall(require, module)
		check(
			res,
			"expansion_manifest_readable",
			ok and type(manifest) == "table" and type(manifest.Cars) == "table",
			true
		)
		if not ok or type(manifest) ~= "table" or type(manifest.Cars) ~= "table" then
			return
		end
		local restore = h.setPanels({ "RacerIndex/Panel" })
		h.frames(2)
		local root = "RacerIndex/Panel/Face/GridHost/Gallery/"
		local ids, rarities, families, missing, mismatches = {}, {}, {}, {}, {}
		check(res, "expansion_manifest_count", #manifest.Cars, Spec.Expansion.Count)
		for _, entry in manifest.Cars do
			check(res, "expansion_unique_" .. entry.Id, ids[entry.Id] == nil, true)
			ids[entry.Id] = true
			rarities[entry.Rarity] = (rarities[entry.Rarity] or 0) + 1
			families[entry.Family] = (families[entry.Family] or 0) + 1
			local car = Catalog.Get(entry.Id)
			local tile = h.find(root .. entry.Id)
			if not (car and tile) then
				table.insert(missing, entry.Id)
			end
			if car then
				for _, field in Spec.Expansion.Fields do
					if car[field] ~= entry[field] then
						table.insert(mismatches, entry.Id .. "." .. field)
					end
				end
				check(
					res,
					"expansion_base_rollable_" .. entry.Id,
					car.Rollable == true and car.GamepassId == nil and car.Weather == nil,
					true
				)
			end
			if tile then
				local odds = tile:FindFirstChild("Odds")
				-- Public rarity stays visible even for undiscovered cars, and never changes with luck.
				check(res, "expansion_odds_" .. entry.Id, text(odds), Format.Odds(entry.Chance))
				check(res, "expansion_tile_order_" .. entry.Id, tile.LayoutOrder, entry.Order)
			end
		end
		for rarity, amount in Spec.Expansion.Rarities do
			check(res, "expansion_rarity_" .. rarity, rarities[rarity] or 0, amount)
			rarities[rarity] = nil
		end
		check(res, "expansion_no_other_rarities", next(rarities) == nil, true)
		for _, family in Spec.Expansion.Families do
			check(res, "expansion_family_" .. family, families[family] or 0, Spec.Expansion.PerFamily)
			families[family] = nil
		end
		check(res, "expansion_no_other_families", next(families) == nil, true)
		h.checkList(res, "expansion_catalog_and_tiles_present", missing)
		h.checkList(res, "expansion_catalog_matches_manifest", mismatches)
		local catchalls = {}
		for _, car in Catalog.All() do
			if car.Chance == nil then
				table.insert(catchalls, car.Id)
			end
		end
		check(res, "index_single_original_catchall", table.concat(catchalls, ","), "rusty_hatchback")
		for _, car in Catalog.Passes() do
			check(res, "index_excludes_pass_" .. car.Id, h.find(root .. car.Id) == nil, true)
		end
		check(res, "index_excludes_starter", h.find(root .. Catalog.STARTER_ID) == nil, true)
		restore()
	end

	-- Reused Header children must not be duplicated or left covering the new frame.
	function scenarios.ui_shared_frames(res)
		modulePresent(res, "PanelFrame")
		local restore = h.setPanels({})
		for _, frame in Spec.SharedFrames do
			h.switch.Close("Daily")
			h.switch.Close(frame.Action)
			h.switch.Action(frame.Action)
			h.frames(2)
			local panel = required(res, frame.Panel, "Frame")
			if not panel then
				continue
			end
			local prefix = "frame_" .. string.lower(frame.Action)
			check(res, prefix .. "_shown", h.visible(panel), true)
			check(res, prefix .. "_shared_marker", panel:GetAttribute("PanelFrame"), true)
			local header = required(res, frame.Panel .. "/Header", "Frame")
			local legacyDaily = frame.Action == "Daily" or frame.Action == "Quests"
			local icon =
				required(res, frame.Panel .. (legacyDaily and "/Header/CalendarIcon" or "/Header/Icon"), "ImageLabel")
			local title = required(
				res,
				frame.Panel .. ((legacyDaily or frame.Action == "Shop") and "/Title" or "/Header/Title"),
				"TextLabel"
			)
			local close = required(res, frame.Panel .. "/" .. frame.Close, "GuiButton")
			if title then
				check(res, prefix .. "_title", containsText(title.Text, frame.Title), true)
			end
			if icon then
				check(res, prefix .. "_icon_drawn", icon.Image ~= "" and h.visible(icon), true)
			end
			local closes, headers = 0, 0
			for _, object in panel:GetDescendants() do
				if object:IsA("GuiButton") and object.Name == "Close" then
					closes += 1
				elseif object:IsA("Frame") and object.Name == "Header" then
					headers += 1
				end
			end
			check(res, prefix .. "_one_close", closes, 1)
			check(res, prefix .. "_one_header", headers, 1)
			check(res, prefix .. "_rounded", panel:FindFirstChildWhichIsA("UICorner") ~= nil, true)
			check(res, prefix .. "_outline", panel:FindFirstChildWhichIsA("UIStroke") ~= nil, true)
			if header then
				local gradient = header:FindFirstChildWhichIsA("UIGradient")
				check(res, prefix .. "_gradient", gradient ~= nil, true)
				if gradient then
					local c = gradient.Color.Keypoints[1].Value
					local colour = frame.Colour
					local matches = colour == "red" and c.R > c.G and c.R > c.B
						or colour == "blue" and c.B > c.R and c.B > c.G
						or colour == "purple" and c.R > c.G and c.B > c.G
						or colour == "orange" and c.R > c.G and c.G > c.B
					check(res, prefix .. "_colour_" .. colour, matches, true)
				end
			end
			if close then
				local c = close.BackgroundColor3
				check(res, prefix .. "_close_red", c.R > c.G and c.R > c.B and close.BackgroundTransparency < 0.5, true)
				h.check(
					res,
					prefix .. "_close_square",
					close.AbsoluteSize.X - close.AbsoluteSize.Y,
					0,
					math.abs(close.AbsoluteSize.X - close.AbsoluteSize.Y) <= Spec.Tolerance
				)
			end
			if header and icon and title and close then
				-- Legacy Close parent is Panel, but it must occupy the header band just like the reused Close.
				h.geometry.Group(res, prefix .. "_header", header, { icon, title, close })
			end
			h.geometry.Panel(res, prefix, panel)
		end
		restore()
	end

	function scenarios.ui_gift_cards(res)
		local restore = h.setPanels({ "ShopUi/Backdrop" })
		h.frames(2)
		local function gift(section, id, enabled, reason)
			local path = Spec.Shop.Items .. "/" .. section .. "/**/" .. id .. "/Gift"
			local button = required(res, path, "GuiButton")
			if not button then
				return
			end
			local prefix = "gift_" .. id
			check(res, prefix .. "_shown", h.visible(button), true)
			check(res, prefix .. "_active", button.Active, enabled)
			check(res, prefix .. "_hover", button.AutoButtonColor, enabled)
			local label = text(button)
			check(res, prefix .. "_label", containsText(label, "gift"), true)
			if not enabled then
				-- A reason must be visible, not only in an internal attribute.
				check(res, prefix .. "_reason", containsText(text(button.Parent), reason), true)
			end
			local count = 0
			for _, child in button.Parent:GetDescendants() do
				if child.Name == "Gift" and child:IsA("GuiButton") then
					count += 1
				end
			end
			check(res, prefix .. "_one_control", count, 1)
		end
		for _, car in Catalog.Passes() do
			gift("Featured", car.Id, false, Spec.Gifts.Reasons.Account)
		end
		for _, pass in Monetization.Gamepasses do
			gift("Gamepasses", pass.Id, false, Spec.Gifts.Reasons.Account)
		end
		for _, product in Monetization.Products do
			local eligible = product.Section == "Potions" or product.Section == "Bundle"
			local enabled = eligible and (product.ProductId or 0) > 0 and (product.GiftProductId or 0) > 0
			local section = product.Section == "Bundle" and "Potions" or product.Section
			gift(
				section,
				product.Section == "Bundle" and "Bundle" or product.Id,
				enabled,
				eligible and Spec.Gifts.Reasons.Unavailable or Spec.Gifts.Reasons.Server
			)
		end
		restore()
	end

	function scenarios.ui_cosmetic_art(res)
		modulePresent(res, "MarketArt")
		local seen, count = {}, 0
		for _, kind in { "Trail", "Aura" } do
			for _, item in Market.Items[kind] do
				count += 1
				check(res, "cosmetic_icon_metadata_" .. item.Id, type(item.Icon) == "string" and item.Icon ~= "", true)
				if type(item.Icon) == "string" then
					check(res, "cosmetic_distinct_icon_" .. item.Id, seen[item.Icon] == nil, true)
					seen[item.Icon] = true
				end
			end
		end
		-- 5 trails + 3 auras (owner 2026-10-27, "Aura and trail ladders"; icons in Shared/MarketArtConfig)
		check(res, "cosmetic_eight_authored_icons", count, 8)
	end

	function scenarios.ui_daily_cards(res)
		local restore = h.setPanels({})
		h.switch.Action("Daily")
		h.frames(2)
		local area = required(res, Spec.DailyBoosts.Content .. "/RewardCards", "Frame")
		if not area then
			restore()
			return
		end
		local cards, total = {}, 0
		local streak = math.clamp(h.player:GetAttribute("DailyStreak") or 0, 0, #Daily.Rewards)
		for _, child in area:GetChildren() do
			if child:IsA("Frame") then
				total += 1
			end
		end
		check(res, "daily_exactly_seven_cards", total, 7)
		for day, reward in Daily.Rewards do
			local card = required(res, h.pathOf(area) .. "/Day" .. day, "Frame")
			if card then
				cards[day] = card
				local prefix = "daily_card_" .. day
				local icon = required(res, h.pathOf(card) .. "/RewardIcon", "ImageLabel")
				if icon then
					check(res, prefix .. "_art", icon.Image ~= "", true)
					check(res, prefix .. "_completed_art_dimmed", icon.ImageTransparency > 0, day <= streak)
				end
				local rewardText = reward.GuaranteedRare and "GUARANTEED RARE"
					or string.format("x%d %s POTION", reward.BoostCount or 1, string.upper(reward.Boost))
				check(res, prefix .. "_reward", text(card:FindFirstChild("RewardText")), rewardText)
				local completion = card:FindFirstChild("Completion")
				check(
					res,
					prefix .. "_completed_mark",
					text(completion),
					day <= streak and Spec.DailyBoosts.DoneMark or ""
				)
			end
		end
		if #cards == 7 then
			-- Judge the actual branch, not the shape copied from the implementation in a simulated viewport.
			local phone = workspace.CurrentCamera.ViewportSize.Y <= Spec.DailyBoosts.PhoneMaxHeight
			check(res, "daily_live_first_row", sameLine(cards[1], cards[2]), true)
			check(res, "daily_live_columns", sameLine(cards[1], cards[3]), not phone)
			if phone then
				check(
					res,
					"daily_phone_day7_below_grid",
					cards[7].AbsolutePosition.Y
						>= cards[6].AbsolutePosition.Y + cards[6].AbsoluteSize.Y - Spec.Tolerance,
					true
				)
			else
				check(
					res,
					"daily_desktop_featured_beside_grid",
					cards[7].AbsolutePosition.X
						>= cards[3].AbsolutePosition.X + cards[3].AbsoluteSize.X - Spec.Tolerance,
					true
				)
				check(res, "daily_desktop_featured_larger", cards[7].AbsoluteSize.Y > cards[1].AbsoluteSize.Y, true)
			end
			h.geometry.Group(res, "daily_cards", area, cards)
		end
		local countdown = required(res, Spec.DailyBoosts.Content .. "/NextReward", "TextLabel")
		check(res, "daily_countdown_drawn", countdown ~= nil and h.visible(countdown) and countdown.Text ~= "", true)
		restore()
	end

	---------------------------------------------------------------------------------------------------------------
	-- Backpack Cars tab (docs/HUD_LAYOUT_SPEC.md section 3, owner 2026-10-20) and car model icons
	-- (docs/CAR_EXPANSION_SPEC.md "Car icons and model detail"). Live engine rects only: the rail's runtime UIScale
	-- is not in the layout model, so ui-tester runs ui_backpack_cars at desktop AND phone landscape (UiSpec.Backpack).
	local B = Spec.Backpack
	local BLACK = Color3.new(0, 0, 0)
	local function rstr(r)
		return ("(%d,%d %dx%d)"):format(r.x, r.y, r.w, r.h)
	end
	local function inside(outer, r)
		local t = Spec.Tolerance
		return r.x >= outer.x - t
			and r.y >= outer.y - t
			and r.x + r.w <= outer.x + outer.w + t
			and r.y + r.h <= outer.y + outer.h + t
	end
	local function overlap(a, b)
		local t = Spec.Tolerance
		return math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x) > t
			and math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y) > t
	end
	local function waitFor(seconds, fn)
		local deadline = os.clock() + seconds
		local ok, value = fn()
		while not ok and os.clock() < deadline do
			task.wait(0.1)
			ok, value = fn()
		end
		return ok, value
	end
	local function hasCar(art)
		local car = art and art:FindFirstChild("Car")
		return car ~= nil and car:IsA("Model")
	end
	local function rank(rarity)
		return table.find(B.RarityOrder, rarity) or math.huge
	end
	-- Owned cars, least rare first, then catalog Order: the spec's order. Index cars are owned through
	-- LocalPlayer.GachaData; gamepass cars through the attribute Pass_<carId> and sort by their catalog rarity
	-- (docs/HUD_LAYOUT_SPEC.md section 3, docs/GAMEPASS_CARS_SPEC.md "the Backpack Cars tab lists owned gamepass cars").
	local function ownedInOrder()
		local data = h.player:FindFirstChild("GachaData")
		local list = {}
		for _, car in Catalog.All() do
			if data and data:FindFirstChild(car.Id) then
				table.insert(list, car)
			end
		end
		for _, car in Catalog.Passes() do
			if h.player:GetAttribute("Pass_" .. car.Id) == true then
				table.insert(list, car)
			end
		end
		table.sort(list, function(a, b)
			if rank(a.Rarity) ~= rank(b.Rarity) then
				return rank(a.Rarity) < rank(b.Rarity)
			end
			return a.Order < b.Order
		end)
		return list
	end
	local function decimals(textValue)
		local fraction = string.match(textValue, "%.(%d+)")
		return fraction and #fraction or 0
	end
	local function tileStroke(tile)
		for _, child in tile:GetChildren() do
			if child:IsA("UIStroke") then
				return child
			end
		end
		return nil
	end

	-- Problems of the Backpack grid as the Cars view, per check name (empty lists = all good)
	local function carsGridProblems()
		local p = {
			backpack_cars_owned_only = {},
			backpack_cars_order = {},
			backpack_cars_model_art = {},
			backpack_cars_name = {},
			backpack_cars_multi = {},
			backpack_cars_multi_no_float_noise = {},
			backpack_cars_equipped_green = {},
			backpack_cars_empty_label = {},
		}
		local grid = h.find(B.Items)
		if not grid then
			table.insert(p.backpack_cars_owned_only, B.Items .. " missing")
			return p
		end
		local want = ownedInOrder()
		local wanted = {}
		for _, car in want do
			wanted[car.Id] = true
		end
		local tiles = {}
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				table.insert(tiles, child)
				if not wanted[child.Name] then
					table.insert(p.backpack_cars_owned_only, child.Name .. ": shown but not an owned car")
				end
			end
		end
		local shownIds = {}
		for _, tile in tiles do
			shownIds[tile.Name] = true
		end
		for _, car in want do
			if not shownIds[car.Id] then
				table.insert(p.backpack_cars_owned_only, car.Id .. ": owned but no tile")
			end
		end
		-- Order: LayoutOrder sequence and the reading order on screen both equal the spec order
		local byLayout, byScreen = table.clone(tiles), table.clone(tiles)
		table.sort(byLayout, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		table.sort(byScreen, function(a, b)
			local ay, by = a.AbsolutePosition.Y, b.AbsolutePosition.Y
			if math.abs(ay - by) > Spec.Tolerance then
				return ay < by
			end
			return a.AbsolutePosition.X < b.AbsolutePosition.X
		end)
		local wantIds, layoutIds, screenIds = {}, {}, {}
		for i, car in want do
			wantIds[i] = car.Id
		end
		for i, tile in byLayout do
			layoutIds[i] = tile.Name
		end
		for i, tile in byScreen do
			screenIds[i] = tile.Name
		end
		local wantText = table.concat(wantIds, ",")
		if table.concat(layoutIds, ",") ~= wantText then
			table.insert(p.backpack_cars_order, "LayoutOrder " .. table.concat(layoutIds, ",") .. " want " .. wantText)
		end
		if table.concat(screenIds, ",") ~= wantText then
			table.insert(p.backpack_cars_order, "screen " .. table.concat(screenIds, ",") .. " want " .. wantText)
		end
		local equipped = h.player:GetAttribute("EquippedCar")
		for _, tile in tiles do
			local car = Catalog.Get(tile.Name)
			if not car then
				continue
			end
			local art = tile:FindFirstChild("Art")
			if not (art and art:IsA("ViewportFrame") and hasCar(art)) then
				table.insert(
					p.backpack_cars_model_art,
					tile.Name
						.. ": Art is "
						.. (art and art.ClassName or "missing")
						.. (hasCar(art) and "" or ", no Car model")
				)
			end
			local name = tile:FindFirstChild("Name")
			if not (name and name:IsA("TextLabel") and name.Text == car.Name) then
				table.insert(p.backpack_cars_name, tile.Name .. ": " .. text(name) .. " want " .. car.Name)
			end
			local multi = tile:FindFirstChild("Multi")
			local wantMulti = Format.Multi(car.SpeedMulti) -- docs/HUD_LAYOUT_SPEC.md section 8
			local got = multi and multi:IsA("TextLabel") and multi.Text or "missing"
			if got ~= wantMulti then
				table.insert(p.backpack_cars_multi, tile.Name .. ": " .. got .. " want " .. wantMulti)
			end
			if decimals(got) > B.MaxDecimals then
				table.insert(p.backpack_cars_multi_no_float_noise, tile.Name .. ": " .. got)
			end
			local stroke = tileStroke(tile)
			local green = stroke ~= nil and B.Green(stroke.Color)
			if (tile.Name == equipped) ~= green then
				table.insert(
					p.backpack_cars_equipped_green,
					tile.Name
						.. (
							tile.Name == equipped and ": equipped but border not green"
							or ": not equipped but border green"
						)
				)
			end
		end
		local empty = h.find(B.Empty)
		local emptyShown = empty ~= nil and h.visible(empty)
		if emptyShown ~= (#want == 0) then
			table.insert(
				p.backpack_cars_empty_label,
				("Empty shown=%s with %d owned cars"):format(tostring(emptyShown), #want)
			)
		end
		return p
	end
	local function carsGridChecks(res)
		local _, problems = waitFor(B.ModelWait, function()
			local p = carsGridProblems()
			for _, list in p do
				if #list > 0 then
					return false, p
				end
			end
			return true, p
		end)
		local names = {}
		for name in problems do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			h.checkList(res, name, problems[name])
		end
	end

	function scenarios.ui_backpack_cars(res)
		local restore = h.setPanels({ B.Panel })
		h.frames(2)
		local panel = required(res, B.Panel, "Frame")
		local rail = required(res, B.Tabs, "Frame")
		local grid = required(res, B.Items, "ScrollingFrame")
		if not (panel and rail and grid) then
			restore()
			return
		end
		-- Exactly the four tabs, top to bottom in the spec's order, each labelled with its name
		local buttons = {}
		for _, child in rail:GetChildren() do
			if child:IsA("GuiButton") then
				table.insert(buttons, child.Name)
			end
		end
		table.sort(buttons)
		local wantButtons = {}
		for i, name in B.TabOrder do
			wantButtons[i] = name .. "Tab"
		end
		table.sort(wantButtons)
		check(res, "backpack_tabs_exactly", table.concat(buttons, ","), table.concat(wantButtons, ","))
		local tabs = {}
		for _, name in B.TabOrder do
			local tab = required(res, B.Tabs .. "/" .. name .. "Tab", "TextButton")
			if tab then
				check(res, "backpack_tab_label_" .. name, text(tab), name)
				check(res, "backpack_tab_shown_" .. name, h.visible(tab), true)
				table.insert(tabs, tab)
			end
		end
		local variant = workspace.CurrentCamera.ViewportSize.Y <= B.PhoneMaxHeight and "_phone" or "_desktop"
		if #tabs == #B.TabOrder then
			local order = {}
			for i = 2, #tabs do
				local a, b = h.realRect(tabs[i - 1]), h.realRect(tabs[i])
				if b.y < a.y + a.h - Spec.Tolerance then
					table.insert(order, tabs[i].Name .. " not below " .. tabs[i - 1].Name)
				end
			end
			h.checkList(res, "backpack_tabs_top_to_bottom" .. variant, order)
		end
		-- Live geometry: every tab inside the rail and the panel, apart from each other and from the Items grid,
		-- and the topmost clickable object at its own centre
		local railRect, panelRect, gridRect = h.realRect(rail), h.realRect(panel), h.realRect(grid)
		local outside, overlaps, covered = {}, {}, {}
		for i, tab in tabs do
			local r = h.realRect(tab)
			if not inside(railRect, r) then
				table.insert(outside, tab.Name .. rstr(r) .. " outside Tabs" .. rstr(railRect))
			end
			if not inside(panelRect, r) then
				table.insert(outside, tab.Name .. rstr(r) .. " outside Panel" .. rstr(panelRect))
			end
			if overlap(r, gridRect) then
				table.insert(overlaps, tab.Name .. rstr(r) .. " x Items" .. rstr(gridRect))
			end
			for j = i + 1, #tabs do
				local other = h.realRect(tabs[j])
				if overlap(r, other) then
					table.insert(overlaps, tab.Name .. rstr(r) .. " x " .. tabs[j].Name .. rstr(other))
				end
			end
			local top = h.topAt(r.x + r.w / 2, r.y + r.h / 2)
			if not (top and (top == tab or tab:IsAncestorOf(top))) then
				table.insert(covered, tab.Name .. " under " .. (top and h.pathOf(top) or "nothing"))
			end
		end
		h.checkList(res, "backpack_tabs_inside_rail" .. variant, outside)
		h.checkList(res, "backpack_tabs_no_overlap" .. variant, overlaps)
		h.checkList(res, "backpack_tabs_topmost" .. variant, covered)
		-- The Cars view itself is judged after the backpack_cars click (After backpack_cars_grid); when the grid
		-- already shows cars (an earlier click) it is judged here too.
		local showsCars = false
		for _, child in grid:GetChildren() do
			showsCars = showsCars or (child:IsA("GuiButton") and Catalog.Get(child.Name) ~= nil)
		end
		if showsCars then
			carsGridChecks(res)
		end
		restore()
	end

	-- Every Index gallery tile shows its car's own model (ViewportFrame Art with a Car model, never the atlas);
	-- an undiscovered car is a black silhouette, a discovered one is not.
	function scenarios.ui_car_icons(res)
		local restore = h.setPanels({ "RacerIndex/Panel" })
		h.frames(2)
		local templates = ReplicatedStorage:FindFirstChild("CarModels")
		local noTemplate = {}
		for _, car in Catalog.All() do
			local template = templates and templates:FindFirstChild(car.Model or car.Id)
			if not (template and template:IsA("Model")) then
				table.insert(noTemplate, car.Id)
			end
		end
		h.checkList(res, "catalog_cars_have_model_template", noTemplate)
		local function problems()
			local p = { index_tiles_model_art = {}, index_silhouette_state = {} }
			local data = h.player:FindFirstChild("GachaData")
			for _, car in Catalog.All() do
				local tile = h.find(B.IndexGallery .. "/" .. car.Id)
				local art = tile and tile:FindFirstChild("Art")
				if not (art and art:IsA("ViewportFrame") and hasCar(art)) then
					table.insert(
						p.index_tiles_model_art,
						car.Id
							.. ": Art is "
							.. (art and art.ClassName or "missing")
							.. (hasCar(art) and "" or ", no Car model")
					)
				end
				if art and art:IsA("ViewportFrame") then
					local owned = data ~= nil and data:FindFirstChild(car.Id) ~= nil
					if (art.ImageColor3 == BLACK) == owned then
						table.insert(
							p.index_silhouette_state,
							car.Id .. (owned and ": discovered but black" or ": undiscovered but not black")
						)
					end
				end
			end
			return p
		end
		local _, p = waitFor(B.ModelWait, function()
			local now = problems()
			return #now.index_tiles_model_art == 0 and #now.index_silhouette_state == 0, now
		end)
		h.checkList(res, "index_tiles_model_art", p.index_tiles_model_art)
		h.checkList(res, "index_silhouette_state", p.index_silhouette_state)
		restore()
	end

	-- Click post-conditions (UiSpec.Clicks Expect.After)
	function after.backpack_cars_grid(res)
		carsGridChecks(res)
	end
	function after.backpack_tile_shows_equipped(res, ctx)
		local segs = string.split(ctx.path, "/")
		local id = segs[#segs]
		local ok, got = waitFor(2, function()
			local tile = h.find(B.Items .. "/" .. id)
			local stroke = tile and tileStroke(tile)
			local green = stroke ~= nil and B.Green(stroke.Color)
			return green and h.player:GetAttribute("EquippedCar") == id,
				("%s green=%s EquippedCar=%s"):format(
					id,
					tostring(green),
					tostring(h.player:GetAttribute("EquippedCar"))
				)
		end)
		h.check(res, "backpack_tile_shows_equipped", got, id .. " green=true EquippedCar=" .. id, ok)
	end

	return { Scenarios = scenarios, After = after }
end

return Contracts
