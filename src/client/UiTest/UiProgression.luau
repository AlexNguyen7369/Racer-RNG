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
local CarCatalog = require(Shared.CarCatalog)
local GachaConfig = require(Shared.GachaConfig)
local MonetizationConfig = require(Shared.MonetizationConfig)
local MarketplaceService = game:GetService("MarketplaceService")
local Spec = require(script.Parent.UiSpec)
local Responsive = require(script.Parent.UiResponsive)
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
		local canvas = h.find(Spec.Progression.Canvas)
		local world = h.find(Spec.Progression.TreeWorld)
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
			local button = world and world:FindFirstChild(tile.Id)
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
				-- UPGRADE_TREE_SPEC section 5: a buyable price is green if affordable, red if not
				local price = button:FindFirstChild("Price", true)
				if canBuy or reason == "money" then
					local c = price and price:IsA("TextLabel") and price.TextColor3
					local green = Spec.Progression.AffordableColour
					h.check(
						res,
						"tile_price_colour_" .. tile.Id,
						c and tostring(c) or "no Price label",
						canBuy and tostring(green) or "red (R > G and R > B)",
						c ~= nil
							and (
								canBuy
									and math.abs(c.R - green.R) + math.abs(c.G - green.G) + math.abs(c.B - green.B) <= 0.02
								or not canBuy and c.R > c.G and c.R > c.B
							)
					)
				end
				local angled = 0
				for _, part in button:GetDescendants() do
					if part:IsA("Frame") and part.BackgroundTransparency < 1 and math.abs(part.Rotation) % 90 > 1 then
						angled += 1
					end
				end
				h.check(res, "tile_hex_geometry_" .. tile.Id, angled, ">=2 slanted visible polygon parts", angled >= 2)
			end
		end
		local restore = h.setPanels({ "RacerUpgrades/Panel" })
		h.frames(2)
		-- The hex tree pans by drag / wheel (UpgradeTreeView sets CanvasPosition itself; native scrolling is off), so
		-- the canvas must be a clipping ScrollingFrame whose canvas spans the whole zoomed TreeWorld (measured with
		-- the tree open): every tile can be panned into the window (tile_pan_reachable_* / tile_pan_hit_* prove it).
		local spans = canvas ~= nil
			and world ~= nil
			and canvas:IsA("ScrollingFrame")
			and canvas.ClipsDescendants
			and world.AbsoluteSize.X > 0
			and canvas.CanvasSize.X.Offset + Spec.Tolerance >= world.AbsoluteSize.X
			and canvas.CanvasSize.Y.Offset + Spec.Tolerance >= world.AbsoluteSize.Y
		h.check(
			res,
			"upgrade_canvas_scrolls",
			canvas
					and world
					and ("%s canvas %s world %s"):format(
						canvas.ClassName,
						tostring(canvas:IsA("ScrollingFrame") and canvas.CanvasSize or "-"),
						tostring(world.AbsoluteSize)
					)
				or "missing",
			"clipping ScrollingFrame, CanvasSize >= TreeWorld size",
			spans
		)
		if canvas and canvas:IsA("ScrollingFrame") then
			local original = canvas.CanvasPosition
			for _, tile in Tree.Tiles() do
				local b = world and world:FindFirstChild(tile.Id)
				if b and b:IsA("GuiButton") then
					-- Pan the tile to the middle of the window (clear of the chrome along the screen edges)
					local position = b.AbsolutePosition - canvas.AbsolutePosition + canvas.CanvasPosition
					local target = position + b.AbsoluteSize / 2 - canvas.AbsoluteSize / 2
					canvas.CanvasPosition = Vector2.new(math.max(0, target.X), math.max(0, target.Y))
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
		end
		restore()
		-- Owner 2026-10-13: the spawn-area upgrade pad is removed; the tree opens only from the HUD Upgrade button
		-- (clicks open_upgrades / close_upgrades / exit_upgrades). Only the workshop plots keep an UpgradePad.
		local plots = workspace:FindFirstChild("Workshops")
		local worldPads = 0
		for _, pad in CollectionService:GetTagged("UpgradePad") do
			if pad:IsDescendantOf(workspace) and not (plots and pad:IsDescendantOf(plots)) then
				worldPads += 1
			end
		end
		expect(res, "upgrade_no_world_pad", worldPads, 0)
		local spawnArea = workspace:FindFirstChild("SpawnArea")
		local spawnPad = spawnArea and spawnArea:FindFirstChild("UpgradePad", true)
		expect(res, "upgrade_no_spawn_area_pad", spawnPad and spawnPad:GetFullName() or "none", "none")
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
				local race, turbo = h.find(Spec.Hud.Race), h.find(Spec.Hud.Turbo)
				local lower = string.lower(name) .. "_" .. vpSpec.Name
				if Spec.FullScreenPanels["Racer" .. name .. "/Panel"] then
					-- Owner 2026-10-26 (HUD_LAYOUT_SPEC sections 1 and 6): a full-screen overlay, exempt from the band
					for _, rule in { "panel_in_band_top_", "panel_below_race_", "panel_above_turbo_" } do
						h.check(res, rule .. lower, "exempt", "exempt (full-screen overlay)", true)
					end
				end
				if Spec.FullScreenPanels["Racer" .. name .. "/Panel"] and panel then
					local p = rect(panel)
					h.check(
						res,
						"panel_positive_size_" .. lower,
						{ p.w, p.h },
						"positive viewport-contained area",
						p.w > 0 and p.h > 0 and p.x >= 0 and p.x + p.w <= vp.X and p.y + p.h <= vp.Y
					)
				elseif panel and race and turbo then
					local p, a, t = rect(panel), rect(race), rect(turbo)
					-- Owner 2026-10-28 (HUD_LAYOUT_SPEC section 6): the compact roll HIDES while a panel is open, so
					-- the panel no longer has to clear it (ui_toast checks the hiding). The panel opens in the
					-- PanelBand: top at least Band.Gap below the Race button (Client/PanelBand.Rect).
					local bandTop = a.y + a.h + Spec.Band.Gap
					h.check(
						res,
						"panel_in_band_top_" .. string.lower(name) .. "_" .. vpSpec.Name,
						p.y,
						">= " .. bandTop,
						p.y >= bandTop - Spec.Tolerance
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
	-- Workshop Showcase (UiSpec.WorkshopShowcase; docs/WORKSHOP_SPEC.md "5b. Showcase"). Truth: player attributes
	-- Showcase / ShowcaseMulti and player.GachaData (Copies attribute per car); bonuses from GachaConfig.SlotBonus.
	local SC = Spec.WorkshopShowcase
	local function copiesOf(id)
		local data = h.player:FindFirstChild("GachaData")
		local entry = data and data:FindFirstChild(id)
		local n = entry and entry:GetAttribute("Copies")
		return type(n) == "number" and n or 0
	end
	local function bonusOf(id)
		local spec = CarCatalog.Get(id)
		return spec and GachaConfig.SlotBonus(spec, copiesOf(id)) or -math.huge
	end
	-- Owned rollable cars { Id, Spec, Bonus }, highest slot bonus first (ties by id)
	local function ownedRollable()
		local list = {}
		local data = h.player:FindFirstChild("GachaData")
		for _, entry in data and data:GetChildren() or {} do
			local spec = CarCatalog.Get(entry.Name)
			if spec and spec.Rollable then
				table.insert(list, { Id = entry.Name, Spec = spec, Bonus = bonusOf(entry.Name) })
			end
		end
		table.sort(list, function(a, b)
			if a.Bonus ~= b.Bonus then
				return a.Bonus > b.Bonus
			end
			return a.Id < b.Id
		end)
		return list
	end
	local function shownIds(value)
		local ids = {}
		if type(value) == "string" then
			for id in string.gmatch(value, "[^,]+") do
				table.insert(ids, id)
			end
		end
		return ids
	end
	local function asSet(list)
		local set, n = {}, 0
		for _, id in type(list) == "table" and list or {} do
			if type(id) == "string" and not set[id] then
				set[id] = true
				n += 1
			end
		end
		return set, n
	end
	-- The id list a showcase click must send, from the Showcase attribute before the click (RunClick)
	function Progression.ShowcaseWant(argSpec, preShowcase, rowId)
		local before = shownIds(preShowcase)
		if argSpec == "showcase_best3" then
			local best = {}
			for i, car in ownedRollable() do
				if i <= SC.Slots then
					table.insert(best, car.Id)
				end
			end
			return best
		end
		local drop = argSpec == "showcase_hide" and rowId or nil
		local slot = tonumber(string.match(argSpec, "^showcase_clear:(%d+)$"))
		if slot then
			drop = before[slot] or "?"
		end
		local want = {}
		for _, id in before do
			if id ~= drop then
				table.insert(want, id)
			end
		end
		if argSpec == "showcase_show" and rowId and not table.find(want, rowId) then
			table.insert(want, rowId)
		end
		return want
	end
	-- Whether `got` (the ids sent or now shown) is `want`: the same set, no duplicates. BEST 3 accepts any equal-bonus
	-- swap: as many distinct owned rollable ids, none with a lower bonus than the weakest wanted one.
	function Progression.SameShowcase(argSpec, got, want)
		if type(got) ~= "table" or #got ~= #want then
			return false
		end
		local gotSet, n = asSet(got)
		if n ~= #got then
			return false
		end
		if argSpec == "showcase_best3" then
			local owned = {}
			for _, car in ownedRollable() do
				owned[car.Id] = true
			end
			local floor = #want > 0 and bonusOf(want[#want]) or math.huge
			for id in gotSet do
				if not owned[id] or bonusOf(id) < floor - 1e-9 then
					return false
				end
			end
			return true
		end
		local wantSet = asSet(want)
		for id in gotSet do
			if not wantSet[id] then
				return false
			end
		end
		return true
	end
	-- RunClick row tokens: the first shown id, or the highest-bonus owned rollable car not shown
	function Progression.ShowcaseTarget(shown)
		local ids = shownIds(h.player:GetAttribute("Showcase"))
		if shown then
			return ids[1]
		end
		for _, car in ownedRollable() do
			if not table.find(ids, car.Id) then
				return car.Id
			end
		end
		return nil
	end
	local function present(res, name, obj, class)
		local ok = obj ~= nil and obj:IsA(class)
		h.check(res, name, obj and obj.ClassName or "missing", class, ok)
		return ok
	end
	-- What the panel shows against the server's truth (the panel must be open)
	local function showcaseContent(res)
		local root = h.find(SC.Root)
		if not present(res, "showcase_frame_present", root, "Frame") then
			return
		end
		local ids = shownIds(h.player:GetAttribute("Showcase"))
		local multi = h.player:GetAttribute("ShowcaseMulti")
		h.check(res, "showcase_multi_replicated", multi or "missing", "number", type(multi) == "number")
		local slots = {}
		for _, id in ids do
			local spec = CarCatalog.Get(id)
			if spec then
				table.insert(slots, { Spec = spec, Copies = copiesOf(id) })
			end
		end
		local formula = GachaConfig.ShowcaseMulti(slots)
		h.check(
			res,
			"showcase_multi_matches_formula",
			multi or "missing",
			formula,
			type(multi) == "number" and math.abs(multi - formula) <= SC.MultiTolerance
		)
		h.check(res, "showcase_at_most_slots", #ids, "<= " .. SC.Slots, #ids <= SC.Slots)
		local multiLabel = root:FindFirstChild("Multi")
		if present(res, "showcase_multi_label_present", multiLabel, "TextLabel") then
			local want = Format.Multi(type(multi) == "number" and multi or 1)
			local text = h.text(multiLabel)
			local at = string.find(text, want, 1, true)
			local after = at and string.sub(text, at + #want, at + #want) or ""
			h.check(res, "showcase_multi_text", text, want, at ~= nil and not string.match(after, "[%d%.]"))
		end
		present(res, "showcase_best3_present", root:FindFirstChild("Best3"), "TextButton")
		for i = 1, SC.Slots do
			local slot = root:FindFirstChild("Slot" .. i)
			local tag = "showcase_slot" .. i
			if present(res, tag .. "_present", slot, "Frame") then
				local nameLabel, clear = slot:FindFirstChild("Name"), slot:FindFirstChild("Clear")
				local spec = ids[i] and CarCatalog.Get(ids[i])
				local wantName = spec and spec.Name or SC.EmptyText
				if present(res, tag .. "_name_present", nameLabel, "TextLabel") then
					expect(res, tag .. "_name", nameLabel.Text, wantName)
				end
				if present(res, tag .. "_clear_present", clear, "TextButton") then
					expect(res, tag .. "_clear_shown_only_with_car", h.visible(clear), ids[i] ~= nil)
				end
			end
		end
		local list = root:FindFirstChild("List")
		if not present(res, "showcase_list_present", list, "ScrollingFrame") then
			return
		end
		local owned = ownedRollable()
		local rows, extra = {}, {}
		for _, row in list:GetChildren() do
			if row:IsA("GuiObject") and string.sub(row.Name, 1, #SC.RowPrefix) == SC.RowPrefix then
				local id = string.sub(row.Name, #SC.RowPrefix + 1)
				local spec = CarCatalog.Get(id)
				local data = h.player:FindFirstChild("GachaData")
				if not (spec and spec.Rollable and data and data:FindFirstChild(id)) then
					table.insert(extra, row.Name)
				end
				table.insert(rows, row)
			end
		end
		h.check(
			res,
			"showcase_list_only_owned_rollable",
			#extra > 0 and table.concat(extra, ", ") or "none",
			"none",
			#extra == 0
		)
		expect(res, "showcase_list_row_count", #rows, #owned)
		local full = #ids >= SC.Slots
		local problems = {}
		for _, car in owned do
			local row = list:FindFirstChild(SC.RowPrefix .. car.Id)
			local nameLabel = row and row:FindFirstChild("Name")
			local show = row and row:FindFirstChild("Show")
			local isShown = table.find(ids, car.Id) ~= nil
			if not row then
				table.insert(problems, car.Id .. ": no row")
			elseif not (nameLabel and nameLabel:IsA("TextLabel") and nameLabel.Text == car.Spec.Name) then
				table.insert(
					problems,
					car.Id .. (": Name %q want %q"):format(nameLabel and nameLabel.Text or "nil", car.Spec.Name)
				)
			end
			if row and not (show and show:IsA("TextButton")) then
				table.insert(problems, car.Id .. ": no Show TextButton")
			elseif show then
				local want = isShown and SC.ShownText or SC.ShowText
				if h.text(show) ~= want then
					table.insert(problems, car.Id .. (": Show %q want %q"):format(h.text(show), want))
				end
				local enabled = isShown or not full
				if show.Active ~= enabled then
					table.insert(
						problems,
						car.Id .. (": Show Active %s want %s"):format(tostring(show.Active), tostring(enabled))
					)
				end
			end
		end
		h.check(
			res,
			"showcase_rows_show_server_truth",
			#problems > 0 and table.concat(problems, "; ") or "none",
			"none",
			#problems == 0
		)
		-- Sorted by slot bonus, highest first (screen order of the rows)
		table.sort(rows, function(a, b)
			if math.abs(a.AbsolutePosition.Y - b.AbsolutePosition.Y) > Spec.Tolerance then
				return a.AbsolutePosition.Y < b.AbsolutePosition.Y
			end
			return a.AbsolutePosition.X < b.AbsolutePosition.X
		end)
		local unsorted = {}
		for i = 2, #rows do
			local a = bonusOf(string.sub(rows[i - 1].Name, #SC.RowPrefix + 1))
			local b = bonusOf(string.sub(rows[i].Name, #SC.RowPrefix + 1))
			if b > a + 1e-9 then
				table.insert(unsorted, rows[i - 1].Name .. " < " .. rows[i].Name)
			end
		end
		h.check(
			res,
			"showcase_list_sorted_by_bonus",
			#unsorted > 0 and table.concat(unsorted, "; ") or "sorted",
			"sorted",
			#unsorted == 0
		)
	end
	-- Placement at every tested viewport (solver for the fixed controls) and hit tests at the live one
	local function showcaseGeometry(res)
		local panel, root = h.find(SC.Panel), h.find(SC.Root)
		if not (panel and root) then
			expect(res, "showcase_geometry_dependencies", false, true)
			return
		end
		local function child(parent, name)
			local o = parent and parent:FindFirstChild(name)
			return o and o:IsA("GuiObject") and o or nil
		end
		local best3, list = child(root, "Best3"), child(root, "List")
		local slots, clears = {}, {}
		for i = 1, SC.Slots do
			slots[i] = child(root, "Slot" .. i)
			local clear = child(slots[i], "Clear")
			clears[i] = clear and h.visible(clear) and clear or nil
		end
		for _, vpSpec in Spec.Viewports do
			local rect, _, ctx = h.provider(vpSpec)
			local tag = vpSpec.Name
			local P, S = rect(panel), rect(root)
			h.check(res, "showcase_inside_panel_" .. tag, { S, P }, "Showcase inside the panel", h.contains(P, S))
			h.check(
				res,
				"showcase_right_part_" .. tag,
				S.x - P.x,
				">= " .. SC.ShowcaseMinStart .. " x panel width",
				S.x >= P.x + SC.ShowcaseMinStart * P.w - Spec.Tolerance
			)
			for _, name in SC.LeftControls do
				local o = child(panel, name)
				local r = o and rect(o)
				h.check(
					res,
					"showcase_left_control_" .. string.lower(name) .. "_" .. tag,
					r or "missing",
					"right edge <= " .. SC.LeftShare .. " x panel width, off the Showcase",
					r ~= nil and r.x + r.w <= P.x + SC.LeftShare * P.w + Spec.Tolerance and not h.intersects(r, S)
				)
			end
			-- Each control inside its parent
			local parented = {
				{ "multi", child(root, "Multi"), S },
				{ "best3", best3, S },
				{ "list", list, S },
			}
			for i = 1, SC.Slots do
				table.insert(parented, { "slot" .. i, slots[i], S })
				if clears[i] and slots[i] then
					table.insert(parented, { "slot" .. i .. "_clear", clears[i], rect(slots[i]) })
				end
			end
			for _, item in parented do
				local r = item[2] and rect(item[2])
				h.check(
					res,
					"showcase_inside_parent_" .. item[1] .. "_" .. tag,
					r or "missing",
					"inside its parent",
					r ~= nil and h.contains(item[3], r)
				)
			end
			-- No two of the panel's controls overlap: Buy, Close, BEST 3, the slots (and shown CLEAR buttons), the list
			local controls = {
				{ "buy", child(panel, "Buy") },
				{ "close", child(panel, "Close") },
				{ "best3", best3 },
				{ "list", list },
			}
			for i = 1, SC.Slots do
				table.insert(controls, { "slot" .. i, slots[i] })
			end
			local rects = {}
			for _, c in controls do
				rects[c[1]] = c[2] and rect(c[2])
			end
			for i = 1, SC.Slots do
				if clears[i] then
					rects["slot" .. i .. "_clear"] = rect(clears[i])
				end
			end
			local overlaps = {}
			local names = {}
			for name in rects do
				table.insert(names, name)
			end
			table.sort(names)
			for i = 1, #names do
				for j = i + 1, #names do
					local a, b = names[i], names[j]
					-- a CLEAR sits inside its own slot by design
					local own = (a .. "_clear" == b) or (b .. "_clear" == a)
					if not own and h.intersects(rects[a], rects[b]) then
						table.insert(overlaps, a .. " x " .. b)
					end
				end
			end
			for _, c in controls do
				if not c[2] then
					table.insert(overlaps, c[1] .. " missing")
				end
			end
			h.check(
				res,
				"showcase_no_overlap_" .. tag,
				#overlaps > 0 and table.concat(overlaps, ", ") or "none",
				"none",
				#overlaps == 0
			)
			local unsolved = {}
			for path, why in ctx.unsupported do
				if string.sub(path, 1, #SC.Root) == SC.Root then
					table.insert(unsolved, path .. ": " .. tostring(why))
				end
			end
			h.check(
				res,
				"showcase_layout_solvable_" .. tag,
				#unsolved > 0 and table.concat(unsolved, "; ") or "none",
				"none",
				#unsolved == 0
			)
		end
		-- Live viewport: each row inside the list's width, Show inside its row, and every fully visible button is
		-- the topmost clickable object at its centre
		local hits = { { "best3", best3 } }
		for i = 1, SC.Slots do
			table.insert(hits, { "slot" .. i .. "_clear", clears[i] })
		end
		if list then
			local L = h.rect(list)
			local bad = {}
			for _, row in list:GetChildren() do
				if row:IsA("GuiObject") and string.sub(row.Name, 1, #SC.RowPrefix) == SC.RowPrefix then
					local R = h.rect(row)
					local show = row:FindFirstChild("Show")
					if R.x < L.x - Spec.Tolerance or R.x + R.w > L.x + L.w + Spec.Tolerance then
						table.insert(bad, row.Name .. " wider than the list")
					end
					if show and show:IsA("GuiObject") then
						if not h.contains(R, h.rect(show)) then
							table.insert(bad, row.Name .. "/Show outside its row")
						elseif h.contains(L, h.rect(show)) then
							table.insert(hits, { row.Name .. "_show", show })
						end
					end
				end
			end
			h.check(res, "showcase_rows_inside_list", #bad > 0 and table.concat(bad, "; ") or "none", "none", #bad == 0)
		end
		for _, item in hits do
			local b = item[2]
			if b and h.visible(b) then
				local top = h.top(h.centre(h.rect(b)))
				h.check(
					res,
					"showcase_hit_" .. string.lower(item[1]),
					top and top.Name or "nothing",
					b.Name,
					top ~= nil and (top == b or b:IsAncestorOf(top))
				)
			end
		end
	end
	function scenarios.ui_workshop_showcase(res)
		local restore = h.setPanels({ SC.Panel })
		local panel = h.find(SC.Panel)
		local deadline = os.clock() + Spec.HiddenWhilePanelOpenWait
		while panel and not h.visible(panel) and os.clock() < deadline do
			h.frames(1)
		end
		expect(res, "showcase_panel_open", panel ~= nil and h.visible(panel), true)
		h.frames(2)
		showcaseContent(res)
		showcaseGeometry(res)
		restore()
	end
	-- Waits until the Showcase attribute holds `want` (SameShowcase), up to SC.AnswerWait
	local function waitShowcase(argSpec, want)
		local deadline = os.clock() + SC.AnswerWait
		local ids = shownIds(h.player:GetAttribute("Showcase"))
		while not Progression.SameShowcase(argSpec, ids, want) and os.clock() < deadline do
			h.frames(1)
			ids = shownIds(h.player:GetAttribute("Showcase"))
		end
		return ids
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
	-- Offline reward double (UiSpec.OfflineDouble; docs/OFFLINE_DOUBLE_SPEC.md section 5). The player attributes are
	-- set on the client only (they do not replicate), standing in for the server's replicated changes, and restored.
	local OD = Spec.OfflineDouble
	local productPrompts = 0
	pcall(function()
		MarketplaceService.PromptProductPurchaseFinished:Connect(function()
			productPrompts += 1
		end)
	end)
	local function doubleShown(want)
		local button = h.find(OD.Button)
		local deadline = os.clock() + Spec.Waits.ClickSettle
		while button and h.visible(button) ~= want and os.clock() < deadline do
			h.frames(1)
		end
		h.frames(2)
		return button
	end
	local function priceChecks(res, suffix)
		local product = MonetizationConfig.OfflineDouble
		local configured = product ~= nil and product.ProductId > 0
		local button, price = h.find(OD.Button), h.find(OD.Price)
		h.check(
			res,
			"offline_double_price_label_present" .. suffix,
			price and price.ClassName or "missing",
			"TextLabel",
			price ~= nil and price:IsA("TextLabel")
		)
		local want = configured and string.format(OD.PriceFormat, product.RobuxPrice) or OD.ComingSoon
		expect(res, "offline_double_price_text" .. suffix, price and price:IsA("TextLabel") and price.Text, want)
		expect(res, "offline_double_active_iff_product" .. suffix, button and button.Active, configured)
		expect(
			res,
			"offline_double_purchase_configured_attr" .. suffix,
			button and button:GetAttribute("PurchaseConfigured"),
			configured
		)
		return configured
	end
	function scenarios.ui_offline_double(res)
		local p = h.player
		local saved = {}
		for _, name in { "OfflineDoubleOpen", "OfflineDoubled" } do
			saved[name] = p:GetAttribute(name)
		end
		local speed = p:GetAttribute("OfflineSpeed")
		h.check(
			res,
			"offline_double_fixture_present",
			speed,
			"offline_welcome setup: positive OfflineSpeed",
			type(speed) == "number" and speed > 0
		)
		speed = type(speed) == "number" and speed or 0
		local restore = h.setPanels({ OD.Panel })
		local button = h.find(OD.Button)
		h.check(
			res,
			"offline_double_button_present",
			button and button.ClassName or "missing",
			"GuiButton",
			button ~= nil and button:IsA("GuiButton")
		)

		-- Closed window: hidden and not clickable at its own centre
		p:SetAttribute("OfflineDoubleOpen", false)
		doubleShown(false)
		expect(res, "offline_double_hidden_when_closed", button and h.visible(button), false)
		if button then
			local top = h.top(h.centre(h.rect(button)))
			expect(
				res,
				"offline_double_not_clickable_when_closed",
				top ~= nil and (top == button or top:IsDescendantOf(button)),
				false
			)
		end
		p:SetAttribute("OfflineDoubleOpen", nil)
		doubleShown(false)
		expect(res, "offline_double_hidden_when_attr_missing", button and h.visible(button), false)

		-- Open window: visible, price per ProductId, inside the panel, clear of Claim / Away / Earnings
		p:SetAttribute("OfflineDoubleOpen", true)
		doubleShown(true)
		expect(res, "offline_double_visible_when_open", button and h.visible(button), true)
		priceChecks(res, "")
		local panel = h.find(OD.Panel)
		if button and panel and h.visible(button) then
			local b = h.rect(button)
			h.check(res, "offline_double_inside_panel", b, "inside RacerWelcome/Panel", h.contains(h.rect(panel), b))
			for _, path in OD.NoOverlap do
				local other = h.find(path)
				local name = "offline_double_no_overlap_" .. string.lower(string.match(path, "[^/]+$"))
				if other and h.visible(other) then
					local o = h.rect(other)
					h.check(res, name, { b, o }, "no intersection", not h.intersects(b, o))
				else
					h.check(res, name, other and "hidden" or "missing", "visible element", false)
				end
			end
			local top = h.top(h.centre(b))
			h.check(
				res,
				"offline_double_topmost_at_centre",
				top and top:GetFullName() or "nothing",
				OD.Button,
				top ~= nil and (top == button or top:IsDescendantOf(button))
			)
		end

		-- Granted double: Earnings shows OfflineSpeed + OfflineDoubled; ungranted it shows OfflineSpeed alone
		local earnings = h.find(OD.Earnings)
		p:SetAttribute("OfflineDoubled", nil)
		h.frames(2)
		expect(
			res,
			"offline_double_earnings_before_grant",
			earnings and earnings.Text,
			string.format(OD.EarningsFormat, Format.SpeedText(speed))
		)
		p:SetAttribute("OfflineDoubleOpen", false)
		p:SetAttribute("OfflineDoubled", speed)
		h.frames(2)
		expect(
			res,
			"offline_double_earnings_after_grant",
			earnings and earnings.Text,
			string.format(OD.EarningsFormat, Format.SpeedText(speed * 2))
		)
		doubleShown(false)
		expect(res, "offline_double_hidden_after_grant", button and h.visible(button), false)

		p:SetAttribute("OfflineDoubleOpen", saved.OfflineDoubleOpen)
		p:SetAttribute("OfflineDoubled", saved.OfflineDoubled)
		h.frames(2)
		restore()
	end
	-- Weather icon (UiSpec.Weather; docs/WEATHER_EVENTS_SPEC.md "Weather icon"). The weather the UI must show now:
	-- the replicated id, its WeatherConfig entry (the Clear entry when no weather is active) and whether one runs.
	local W = Spec.Weather
	local function weatherNow()
		local event = ReplicatedStorage:GetAttribute("WeatherEvent")
		local endsAt = ReplicatedStorage:GetAttribute("WeatherEndsAt")
		local active = type(event) == "string" and event ~= ""
		return event, endsAt, active, WeatherConfig.Events[active and event or W.ClearId]
	end
	-- The Card's three labels against the server's weather (the Card may be hidden: labels are kept current).
	local function weatherCardContent(res)
		local _, endsAt, active, config = weatherNow()
		local texts = {}
		for _, name in W.Labels do
			local obj = h.find(W.Card .. "/" .. name)
			h.check(
				res,
				"weather_card_label_" .. string.lower(name),
				obj and obj.ClassName or "missing",
				"TextLabel",
				obj ~= nil and obj:IsA("TextLabel")
			)
			texts[name] = obj and obj:IsA("TextLabel") and obj.Text or "missing"
		end
		expect(res, "weather_card_title", texts.Title, active and config and config.Name or W.ClearTitle)
		local parts = {}
		for _, part in W.StatParts do
			local multi = config and config[part.Key]
			if type(multi) == "number" and multi ~= 1 then
				table.insert(parts, part.Text .. tostring(multi))
			end
		end
		expect(res, "weather_card_stats", texts.Stats, #parts > 0 and table.concat(parts, W.Separator) or W.NoBonus)
		if active and type(endsAt) == "number" then
			local shown = tonumber(string.match(texts.Time, W.TimeText))
			local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			h.check(
				res,
				"weather_card_time_server_countdown",
				shown or texts.Time,
				remaining,
				shown ~= nil and math.abs(shown - remaining) <= W.TimeTolerance
			)
		else
			expect(res, "weather_card_time_empty_without_weather", texts.Time, "")
		end
	end
	-- Waits (ProgressionUi polls its visibility) until the icon's shown state is `want`, then returns the state.
	local function iconShown(want)
		local deadline = os.clock() + Spec.HiddenWhilePanelOpenWait
		local icon = h.find(W.Icon)
		while icon and h.visible(icon) ~= want and os.clock() < deadline do
			h.frames(1)
		end
		return icon ~= nil and h.visible(icon)
	end
	function scenarios.ui_weather(res)
		local event, endsAt, active, config = weatherNow()
		h.check(res, "weather_event_replicated", event or "missing", "string", type(event) == "string")
		h.check(res, "weather_end_replicated", endsAt or "missing", "number", type(endsAt) == "number")
		h.check(
			res,
			"weather_event_in_config",
			event or "missing",
			"'' or a WeatherConfig.Events id",
			event == "" or (active and WeatherConfig.Events[event] ~= nil)
		)
		local banner = h.find(W.Banner)
		h.check(res, "weather_banner_removed", banner and banner.ClassName or "absent", "absent", banner == nil)

		local restore = h.setPanels({})
		local icon, card = h.find(W.Icon), h.find(W.Card)
		h.check(
			res,
			"weather_icon_is_textbutton",
			icon and icon.ClassName or "missing",
			"TextButton",
			icon ~= nil and icon:IsA("TextButton")
		)
		h.check(
			res,
			"weather_card_is_frame",
			card and card.ClassName or "missing",
			"Frame",
			card ~= nil and card:IsA("Frame")
		)
		-- Always on the HUD, with or without a weather
		expect(res, "weather_icon_visible", iconShown(true), true)
		local wantIcon = config and config.Icon
		h.check(
			res,
			"weather_icon_text",
			icon and icon:IsA("TextButton") and icon.Text or "missing",
			wantIcon or "WeatherConfig.Events[id].Icon missing",
			icon ~= nil
				and icon:IsA("TextButton")
				and type(wantIcon) == "string"
				and wantIcon ~= ""
				and icon.Text == wantIcon
		)
		expect(res, "weather_card_hidden_at_rest", card and card.Visible, false)
		weatherCardContent(res)

		-- Geometry at every tested viewport. The live one is also solved ("current_sim"), so the hidden Card's
		-- rect never depends on the engine laying out an invisible Frame.
		local _, liveVp = h.provider({ Name = "current" })
		for _, vpSpec in Spec.Viewports do
			local rect, vp, ctx = h.provider(vpSpec)
			local tag = vpSpec.Name
			if icon and icon:IsA("GuiObject") then
				local r = rect(icon)
				h.check(
					res,
					"weather_icon_size_" .. tag,
					("%gx%g"):format(r.w, r.h),
					("%gx%g"):format(W.IconSize.X, W.IconSize.Y),
					math.abs(r.w - W.IconSize.X) <= Spec.Tolerance and math.abs(r.h - W.IconSize.Y) <= Spec.Tolerance
				)
				local right, bottom = vp.X - (r.x + r.w), vp.Y - (r.y + r.h)
				local bottomOk = bottom >= -Spec.Tolerance and bottom <= W.CornerMargin
				if vp.Y <= Responsive.PHONE_MAX_HEIGHT then
					h.check(
						res,
						"weather_icon_bottom_right_" .. tag,
						("right %g, bottom %g"):format(right, bottom),
						("phone: right edge %d px, bottom edge 0..%d px from the screen's"):format(
							W.PhoneRight,
							W.CornerMargin
						),
						math.abs(right - W.PhoneRight) <= Spec.Tolerance and bottomOk
					)
					local market = h.find(W.MarketButton)
					local m = market and rect(market)
					h.check(
						res,
						"weather_icon_left_of_market_" .. tag,
						-- px the icon's right edge passes the Market button's left edge (a number, not a table)
						m and (r.x + r.w) - m.x or "MarketButton missing",
						"<= " .. Spec.Tolerance .. " (icon right edge - Market button left edge)",
						m ~= nil and r.x + r.w <= m.x + Spec.Tolerance and not h.intersects(r, m)
					)
				else
					h.check(
						res,
						"weather_icon_bottom_right_" .. tag,
						("right %g, bottom %g"):format(right, bottom),
						"right and bottom edge 0.." .. W.CornerMargin .. " px from the screen's",
						right >= -Spec.Tolerance and right <= W.CornerMargin and bottomOk
					)
				end
			else
				expect(res, "weather_icon_size_" .. tag, "missing", "present")
				expect(res, "weather_icon_bottom_right_" .. tag, "missing", "present")
			end
			if card and card:IsA("GuiObject") then
				if not vpSpec.Size then
					rect, vp, ctx = h.provider({ Name = "current_sim", Size = liveVp })
				end
				local r = rect(card)
				local unsupported = ctx.unsupported[W.Card] or ctx.unsupported[W.Icon]
				h.check(
					res,
					"weather_card_inside_screen_" .. tag,
					unsupported and ("layout the solver can not model: " .. unsupported) or r,
					"whole Card on screen, positive size",
					not unsupported and r.w > 0 and r.h > 0 and h.contains({ x = 0, y = 0, w = vp.X, h = vp.Y }, r)
				)
			else
				expect(res, "weather_card_inside_screen_" .. tag, "missing", "present")
			end
		end
		restore()
		-- WEATHER_EVENTS_SPEC "Displayed odds": a roll during Rain keeps its catalog rarity. Only
		-- with the weather_rain_roll fixture (it plants that roll; checks roll_odds_*, see UiSpec.RollOdds).
		local fixture = h.rollOddsFixture()
		if fixture and fixture.fixture == "weather_rain_roll" then
			expect(res, "weather_rain_roll_event_is_rain", event, "rain")
			h.rollOdds(res)
		end
	end
	function scenarios.ui_offline_zero(res)
		expect(res, "offline_zero_fixture_speed", h.player:GetAttribute("OfflineSpeed"), 0)
		expect(res, "offline_zero_fixture_seconds", h.player:GetAttribute("OfflineSeconds"), 0)
		local panel = h.find("RacerWelcome/Panel")
		expect(res, "offline_zero_hides_welcome", panel and panel.Visible, false)
	end
	-- Click post-conditions (UiSpec.Clicks Expect.After), run by UiScenarios.RunClick.
	local function cardVisible(res, name, want)
		local card = h.find(W.Card)
		local deadline = os.clock() + Spec.HiddenWhilePanelOpenWait
		while card and h.visible(card) ~= want and os.clock() < deadline do
			h.frames(1)
		end
		h.check(res, name, card and h.visible(card), want, card ~= nil and h.visible(card) == want)
		return card
	end
	Progression.After = {
		-- offline_double_click (UiSpec.Clicks): ProductId 0 = nothing changed and no product prompt; ProductId > 0 =
		-- still open and active (the prompt itself is Roblox's, confirmed on screen by ui-tester)
		offline_double_click_result = function(res)
			local before = productPrompts
			task.wait(Spec.Waits.ClickSettle)
			local configured = priceChecks(res, "_after_click")
			local button = h.find(OD.Button)
			expect(res, "offline_double_still_visible_after_click", button and h.visible(button), true)
			if not configured then
				expect(res, "offline_double_coming_soon_no_prompt", productPrompts - before, 0)
			end
		end,
		weather_card_shown = function(res)
			local card = cardVisible(res, "weather_card_shown_after_click", true)
			weatherCardContent(res)
			if card then
				local _, vp = h.provider({ Name = "current" })
				local r = h.rect(card)
				h.check(
					res,
					"weather_card_inside_screen_live",
					r,
					"whole Card on screen, positive size",
					r.w > 0 and r.h > 0 and h.contains({ x = 0, y = 0, w = vp.X, h = vp.Y }, r)
				)
			end
		end,
		weather_card_hidden = function(res)
			cardVisible(res, "weather_card_hidden_after_second_click", false)
			expect(res, "weather_icon_still_visible", iconShown(true), true)
		end,
		weather_icon_hidden_while_showcase_open = function(res)
			h.check(res, "weather_icon_present", h.find(W.Icon) ~= nil, true, h.find(W.Icon) ~= nil)
			expect(res, "weather_icon_hidden_while_showcase_open", iconShown(false), false)
		end,
		weather_icon_shown_after_showcase = function(res)
			expect(res, "weather_icon_shown_after_showcase", iconShown(true), true)
		end,
		-- Workshop Showcase clicks (UiSpec.WorkshopShowcase): the server's Showcase attribute after the click
		showcase_attr_follows = function(res, ctx)
			local want = ctx and ctx.wantArg
			if type(want) ~= "table" then
				expect(res, "showcase_attr_follows_server", "no wanted id list", "SetShowcase click")
				return
			end
			local ids = waitShowcase(ctx.argSpec, want)
			h.check(
				res,
				"showcase_attr_follows_server",
				table.concat(ids, ","),
				table.concat(want, ","),
				Progression.SameShowcase(ctx.argSpec, ids, want)
			)
			if ctx.argSpec == "showcase_best3" then
				local owned = #ownedRollable()
				expect(res, "showcase_best3_fills_slots", #ids, math.min(SC.Slots, owned))
				h.check(res, "showcase_best3_fixture_owns_3", owned, ">= " .. SC.Slots, owned >= SC.Slots)
			end
		end,
		showcase_unchanged = function(res, ctx)
			local now = h.player:GetAttribute("Showcase")
			local before = ctx and ctx.pre and ctx.pre.Showcase
			h.check(res, "showcase_attr_unchanged", now, before, now == before)
			expect(res, "showcase_full_before_disabled_click", #shownIds(before), SC.Slots)
		end,
		-- The panel follows the server (labels from attributes, not the click)
		showcase_ui_follows = function(res)
			local restore = h.setPanels({ SC.Panel })
			local ids = shownIds(h.player:GetAttribute("Showcase"))
			local slot1 = h.find(SC.Root .. "/Slot1/Name")
			local want = ids[1] and CarCatalog.Get(ids[1]) and CarCatalog.Get(ids[1]).Name or SC.EmptyText
			local deadline = os.clock() + SC.AnswerWait
			while slot1 and slot1.Text ~= want and os.clock() < deadline do
				h.frames(1)
			end
			showcaseContent(res)
			restore()
		end,
	}
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
