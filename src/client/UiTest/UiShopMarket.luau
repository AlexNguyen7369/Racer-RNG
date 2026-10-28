--!nonstrict
-- The Robux Shop (Client/ShopUi, docs/GAMEPASS_SHOP_SPEC.md) and the Money Market (Client/MarketUi,
-- docs/HUD_LAYOUT_SPEC.md section 2 "Market"): what they show against the config modules and the player's attributes,
-- their geometry at every UiSpec viewport, and the post-conditions of the shop_* / market_* clicks. Owned by
-- ui-test-writer. Nothing here invokes a remote; the clicks do (UiSpec.Clicks, purchases only through the spy proxy).

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local HudFormat = require(Shared:WaitForChild("HudFormat"))
local MarketConfig = require(Shared:WaitForChild("MarketConfig"))
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))
local Spec = require(script.Parent.UiSpec)

local ShopMarket = {}

-- The PanelBand rect (left, top, right, bottom; screen px, inset included) from the HUD rects, as Client/PanelBand
-- computes it: past the grid (and what sticks out of it) and the Shop column, with the wider margin on both sides;
-- Gap below the Race button; Gap above the TURBO bar, and above Money when Money reaches into the band.
-- d: Race, Turbo, Navigation, NavigationParts (rects of the grid's visible descendants), ShopColumn, Money, MoneyShown.
function ShopMarket.Band(vp, d)
	local gap = Spec.Band.Gap
	local gridRight = d.Navigation.x + d.Navigation.w
	for _, r in d.NavigationParts or {} do
		gridRight = math.max(gridRight, r.x + r.w)
	end
	local margin = math.max(gridRight, vp.X - d.ShopColumn.x) + gap
	local bottom = d.Turbo.y
	if d.MoneyShown and d.Money and d.Money.x + d.Money.w > margin then
		bottom = math.min(bottom, d.Money.y)
	end
	return margin, d.Race.y + d.Race.h + gap, vp.X - margin, bottom - gap
end

-- Client/PanelBand.Fit for the layout solver: centred in the band, at most maxWidth wide, never under Band.MinSize.
function ShopMarket.BandFit(vp, d, maxWidth)
	local left, top, right, bottom = ShopMarket.Band(vp, d)
	local min = Spec.Band.MinSize
	return {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((left + right) / 2, (top + bottom) / 2),
		Size = UDim2.fromOffset(math.max(min.X, math.min(maxWidth, right - left)), math.max(min.Y, bottom - top)),
	}
end

-- h: check, checkList, find, visible, setPanels, player, pathOf, render, frames, provider, viewports, contains,
-- intersects, rstr, realRect, topAt, allText (UiScenarios' helpers). Returns { Scenarios, After }.
function ShopMarket.Build(h)
	local SH, MK = Spec.Shop, Spec.Market
	local scenarios, after = {}, {}
	local TOL = Spec.Tolerance

	local function attr(name)
		return h.player:GetAttribute(name)
	end
	local function has(text, piece)
		return string.find(string.upper(text), string.upper(piece), 1, true) ~= nil
	end
	local function textOf(obj)
		return obj and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and obj.Text or "missing"
	end
	-- The text a button shows: its own Text, else (the shared PanelFrame close: Text "" with a TextLabel "X" child)
	-- its visible child TextLabel's
	local function shownText(obj)
		local own = textOf(obj)
		if own ~= "" or not obj then
			return own
		end
		for _, child in obj:GetChildren() do
			if child:IsA("TextLabel") and h.visible(child) and child.Text ~= "" then
				return child.Text
			end
		end
		return own
	end
	local function redFamily(c)
		return Spec.Rebirth.Colours.red(c)
	end
	-- 1999 -> "1,999"
	local function thousands(n)
		local s = tostring(math.floor(n))
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end

	-- Purchase prompts seen (a "Coming soon" click must not open one)
	local prompts = {}
	for _, name in { "PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished", "PromptPurchaseFinished" } do
		pcall(function()
			MarketplaceService[name]:Connect(function()
				table.insert(prompts, { name = name, t = os.clock() })
			end)
		end)
	end

	-- Descendants of root named `name` (and of class `class` when given)
	local function named(root, name, class)
		local list = {}
		for _, d in root and root:GetDescendants() or {} do
			if d.Name == name and (not class or d:IsA(class)) then
				table.insert(list, d)
			end
		end
		return list
	end

	-- The HUD rects the band is built from, at one viewport
	local function bandAt(rectOf, vp)
		local d, missing = {}, {}
		for key, path in
			{
				Race = Spec.Band.Race,
				Turbo = Spec.Band.Turbo,
				Navigation = Spec.Band.Grid,
				ShopColumn = Spec.Band.ShopColumn,
				Money = Spec.Band.Money,
			}
		do
			local o = h.find(path)
			if o then
				d[key] = rectOf(o)
			else
				table.insert(missing, path)
			end
		end
		if #missing > 0 then
			return nil, missing
		end
		d.NavigationParts = {}
		for _, part in h.find(Spec.Band.Grid):GetDescendants() do
			if part:IsA("GuiObject") and part.Visible then
				table.insert(d.NavigationParts, rectOf(part))
			end
		end
		local money = h.find(Spec.Band.Money)
		d.MoneyShown = money:IsA("GuiObject") and money.Visible
		local l, t, r, b = ShopMarket.Band(vp, d)
		return { x = l, y = t, w = r - l, h = b - t }
	end

	-- Shared geometry of a band panel at every viewport: inside the screen and the band, its interactive parts
	-- (buttons, text boxes) inside their parent and apart from each other, and the solver able to model it.
	local function panelGeometry(res, prefix, panel)
		local guiName = panel:FindFirstAncestorWhichIsA("LayerCollector").Name
		for _, vpSpec in h.viewports do
			local rectOf, vp, ctx = h.provider(vpSpec)
			local suffix = "_" .. vpSpec.Name
			local pr = rectOf(panel)
			local screen = { x = 0, y = 0, w = vp.X, h = vp.Y }
			h.check(res, prefix .. "_panel_on_screen" .. suffix, h.rstr(pr), h.rstr(screen), h.contains(screen, pr))
			local band, missing = bandAt(rectOf, vp)
			if band then
				h.check(res, prefix .. "_panel_in_band" .. suffix, h.rstr(pr), h.rstr(band), h.contains(band, pr))
			else
				h.check(
					res,
					prefix .. "_panel_in_band" .. suffix,
					table.concat(missing, ", ") .. " missing",
					"HUD",
					false
				)
			end
			local controls, spill, overlaps = {}, {}, {}
			for _, d in panel:GetDescendants() do
				if (d:IsA("GuiButton") or d:IsA("TextBox")) and h.visible(d) then
					table.insert(controls, { obj = d, r = rectOf(d) })
					local parent = d.Parent
					if parent and parent:IsA("GuiObject") and not parent:IsA("ScrollingFrame") then
						local parentRect = rectOf(parent)
						if not h.contains(parentRect, rectOf(d)) then
							table.insert(
								spill,
								h.pathOf(d) .. h.rstr(rectOf(d)) .. " outside " .. parent.Name .. h.rstr(parentRect)
							)
						end
					elseif parent and parent:IsA("ScrollingFrame") then
						-- In a scroll list: inside its width (it scrolls vertically, never sideways)
						local sr, r = rectOf(parent), rectOf(d)
						if r.x < sr.x - TOL or r.x + r.w > sr.x + sr.w + TOL then
							table.insert(spill, h.pathOf(d) .. h.rstr(r) .. " wider than " .. parent.Name .. h.rstr(sr))
						end
					end
				end
			end
			for a = 1, #controls do
				for b = a + 1, #controls do
					local A, B = controls[a], controls[b]
					if not A.obj:IsAncestorOf(B.obj) and not B.obj:IsAncestorOf(A.obj) and h.intersects(A.r, B.r) then
						table.insert(
							overlaps,
							h.pathOf(A.obj) .. h.rstr(A.r) .. " x " .. h.pathOf(B.obj) .. h.rstr(B.r)
						)
					end
				end
			end
			h.checkList(res, prefix .. "_hitboxes_inside_parent" .. suffix, spill)
			h.checkList(res, prefix .. "_controls_no_overlap" .. suffix, overlaps)
			local unsupported = {}
			for path, what in ctx and ctx.unsupported or {} do
				if string.sub(path, 1, #guiName + 1) == guiName .. "/" then
					table.insert(unsupported, path .. ": " .. tostring(what))
				end
			end
			h.checkList(res, prefix .. "_layout_model_supported" .. suffix, unsupported)
		end
	end

	-- Children (by name) of a rect group apart and inside their parent, at every viewport
	local function groupGeometry(res, name, parent, parts)
		for _, vpSpec in h.viewports do
			local rectOf = h.provider(vpSpec)
			local suffix = "_" .. vpSpec.Name
			local pr = rectOf(parent)
			local outside, overlaps, rects = {}, {}, {}
			for _, part in parts do
				local r = rectOf(part)
				table.insert(rects, { part, r })
				if not h.contains(pr, r) then
					table.insert(outside, part.Name .. h.rstr(r) .. " outside " .. parent.Name .. h.rstr(pr))
				end
			end
			for a = 1, #rects do
				for b = a + 1, #rects do
					if h.intersects(rects[a][2], rects[b][2]) then
						table.insert(
							overlaps,
							rects[a][1].Name .. h.rstr(rects[a][2]) .. " x " .. rects[b][1].Name .. h.rstr(rects[b][2])
						)
					end
				end
			end
			h.checkList(res, name .. "_inside" .. suffix, outside)
			h.checkList(res, name .. "_no_overlap" .. suffix, overlaps)
		end
	end

	-- At the live viewport every shown control whose centre is in view is the topmost Active object there
	local function topmostChecks(res, prefix, panel, clip)
		local covered = {}
		local clipRect = clip and h.realRect(clip)
		for _, d in panel:GetDescendants() do
			if d:IsA("GuiButton") and h.visible(d) then
				local r = h.realRect(d)
				local cx, cy = r.x + r.w / 2, r.y + r.h / 2
				local inView = not clipRect
					or not clip:IsAncestorOf(d)
					or (
						cx >= clipRect.x
						and cx <= clipRect.x + clipRect.w
						and cy >= clipRect.y
						and cy <= clipRect.y + clipRect.h
					)
				if inView then
					local top = h.topAt(cx, cy)
					if not (top and (top == d or d:IsAncestorOf(top))) then
						table.insert(covered, h.pathOf(d) .. " under " .. (top and h.pathOf(top) or "nothing"))
					end
				end
			end
		end
		h.checkList(res, prefix .. "_buttons_topmost", covered)
	end

	local function closeChecks(res, prefix, close, want)
		local text = shownText(close)
		h.check(
			res,
			prefix .. "_close_is_button",
			close and close.ClassName or "missing",
			"TextButton",
			close ~= nil and close:IsA("TextButton")
		)
		h.check(res, prefix .. "_close_text", text, want, text == want)
		if close and close:IsA("GuiObject") then
			local s = close.AbsoluteSize
			h.check(res, prefix .. "_close_square", ("%dx%d"):format(s.X, s.Y), "w = h", math.abs(s.X - s.Y) <= TOL)
			local c = close.BackgroundColor3
			h.check(
				res,
				prefix .. "_close_red",
				tostring(c),
				"red",
				close.BackgroundTransparency < 0.5 and redFamily(c)
			)
		end
	end

	---------------------------------------------------------------------------------------------------------------
	-- Shop

	-- The card for item `id` under `section`: exactly one GuiObject named id, holding exactly one Buy TextButton
	local function card(section, id, bad)
		local found = named(section, id, "GuiObject")
		if #found ~= 1 then
			table.insert(bad, ("%s/%s: found %d, want 1"):format(section.Name, id, #found))
			return nil
		end
		local buys = named(found[1], SH.BuyName, "TextButton")
		if #buys ~= 1 then
			table.insert(bad, ("%s/%s: %d Buy TextButtons, want 1"):format(section.Name, id, #buys))
			return nil
		end
		return found[1], buys[1]
	end

	-- What a price button must show: the listed price (thousands separated) and "Coming soon" for id 0.
	-- ownedNow: the car id of an owned gamepass car (its button shows Equip / Equipped, SH.OwnedCar), else false
	local function priceProblems(bad, label, buy, price, onSaleId, ownedNow)
		local text = h.allText(buy)
		if ownedNow then
			local equipped = attr("EquippedCar") == ownedNow
			local want = equipped and SH.OwnedCar.Equipped or SH.OwnedCar.Equip
			-- "Equipped" contains "Equip": the not-equipped button must not read "Equipped"
			if not has(text, want) or (not equipped and has(text, SH.OwnedCar.Equipped)) then
				table.insert(bad, label .. ": shows " .. text .. ", want " .. want)
			end
			return
		end
		if onSaleId == 0 then
			if not (has(text, thousands(price)) and has(text, SH.ComingSoon)) then
				table.insert(bad, ("%s: shows %q, want %s and %q"):format(label, text, thousands(price), SH.ComingSoon))
			end
		elseif not string.find(text, "%d") then
			-- id > 0: the live PriceInRobux may replace RobuxPrice, but a price is always shown
			table.insert(bad, label .. ": shows " .. text .. ", want a price")
		end
	end

	function scenarios.ui_shop(res)
		local restore = h.setPanels({ "ShopUi/Backdrop" })
		h.frames(2)
		local panel, items = h.find(SH.Panel), h.find(SH.Items)
		h.check(res, "shop_panel_present", panel and panel.ClassName or "missing", SH.Panel, panel ~= nil)
		h.check(
			res,
			"shop_items_is_scrolling",
			items and items.ClassName or "missing",
			"ScrollingFrame",
			items ~= nil and items:IsA("ScrollingFrame")
		)
		if not (panel and items) then
			restore()
			return
		end
		h.check(res, "shop_panel_shown", h.visible(panel), true, h.visible(panel))
		closeChecks(res, "shop", h.find(SH.Close), SH.CloseText)

		-- Sections: direct children of Items, exactly once each, top to bottom in spec order
		local sections, bad = {}, {}
		for _, name in SH.Sections do
			local n = 0
			for _, child in items:GetChildren() do
				if child.Name == name and child:IsA("GuiObject") then
					n += 1
					sections[name] = child
				end
			end
			if n ~= 1 then
				table.insert(bad, ("%s: %d direct children of Items, want 1"):format(name, n))
				sections[name] = nil
			end
		end
		h.checkList(res, "shop_sections_present", bad)
		local order = {}
		for i = 2, #SH.Sections do
			local a, b = sections[SH.Sections[i - 1]], sections[SH.Sections[i]]
			if a and b and b.AbsolutePosition.Y < a.AbsolutePosition.Y + a.AbsoluteSize.Y - TOL then
				table.insert(order, SH.Sections[i] .. " not below " .. SH.Sections[i - 1])
			end
		end
		h.checkList(res, "shop_sections_in_order", order)
		local titles = {}
		for name, title in SH.SectionTitles do
			local ok = false
			for _, d in sections[name] and sections[name]:GetDescendants() or {} do
				ok = ok or (d:IsA("TextLabel") and string.upper(d.Text) == string.upper(title))
			end
			if not ok then
				table.insert(titles, name .. ": no title " .. title)
			end
		end
		h.checkList(res, "shop_section_titles", titles)

		-- Cards: one per config entry, each with one Buy showing its price; no other Buy in the section
		local cardBad, priceBad = {}, {}
		local function sectionCards(name, entries, idOf, extra)
			local section = sections[name]
			if not section then
				return
			end
			for _, entry in entries do
				local c, buy = card(section, entry.Id, cardBad)
				if c then
					idOf(entry, c, buy)
				end
			end
			local buys = #named(section, SH.BuyName, "TextButton")
			if buys ~= #entries + (extra or 0) then
				table.insert(cardBad, ("%s: %d Buy buttons, want %d"):format(name, buys, #entries + (extra or 0)))
			end
		end
		sectionCards("Featured", CarCatalog.Passes(), function(car, c, buy)
			local text = h.allText(c)
			-- The car preview: a ViewportFrame, or the "?" placeholder when the car has no model yet
			local preview = false
			for _, d in c:GetDescendants() do
				preview = preview or d:IsA("ViewportFrame") or (d:IsA("TextLabel") and d.Text == "?")
			end
			if not preview then
				table.insert(cardBad, "Featured/" .. car.Id .. ': no ViewportFrame car preview (or "?")')
			end
			for _, piece in { car.Name, car.Rarity, HudFormat.Multi(car.SpeedMulti) } do
				if not has(text, piece) then
					table.insert(cardBad, ("Featured/%s: text has no %q"):format(car.Id, piece))
				end
			end
			priceProblems(
				priceBad,
				"Featured/" .. car.Id,
				buy,
				car.RobuxPrice or 0,
				car.GamepassId or 0,
				attr("Pass_" .. car.Id) == true and car.Id
			)
		end)
		sectionCards("Gamepasses", MonetizationConfig.Gamepasses, function(pass, c, buy)
			if not has(h.allText(c), pass.Name) then
				table.insert(cardBad, ("Gamepasses/%s: text has no %q"):format(pass.Id, pass.Name))
			end
			priceProblems(priceBad, "Gamepasses/" .. pass.Id, buy, pass.RobuxPrice, pass.GamepassId or 0, false)
		end)
		local bySection = { Potions = {}, Bundle = {}, ServerLuck = {} }
		for _, product in MonetizationConfig.Products do
			if bySection[product.Section] then
				table.insert(bySection[product.Section], product)
			end
		end
		local function productCard(product, _, buy)
			priceProblems(
				priceBad,
				product.Section .. "/" .. product.Id,
				buy,
				product.RobuxPrice,
				product.ProductId or 0,
				false
			)
		end
		sectionCards("Potions", bySection.Potions, productCard, #bySection.Bundle)
		sectionCards("ServerLuck", bySection.ServerLuck, productCard)
		-- The Bundle banner (Frame "Bundle" under Potions) holds the Section "Bundle" product's one Buy
		if sections.Potions then
			local banners = named(sections.Potions, SH.Bundle, "GuiObject")
			if #banners ~= 1 then
				table.insert(cardBad, ("Potions/Bundle: found %d, want 1"):format(#banners))
			else
				local buys = named(banners[1], SH.BuyName, "TextButton")
				if #buys ~= #bySection.Bundle then
					table.insert(cardBad, ("Potions/Bundle: %d Buy buttons, want %d"):format(#buys, #bySection.Bundle))
				elseif bySection.Bundle[1] then
					local b = bySection.Bundle[1]
					priceProblems(priceBad, "Potions/Bundle", buys[1], b.RobuxPrice, b.ProductId or 0, false)
				end
			end
		end
		h.checkList(res, "shop_cards_match_config", cardBad)
		h.checkList(res, "shop_buy_shows_price", priceBad)

		-- Codes: one Input box, one Redeem button, one Status label
		local codesBad = {}
		for key, class in { Input = "TextBox", Redeem = "TextButton", Status = "TextLabel" } do
			local n = #named(sections.Codes, SH.Codes[key], class)
			if n ~= 1 then
				table.insert(codesBad, ("%s (%s): %d, want 1"):format(SH.Codes[key], class, n))
			end
		end
		h.checkList(res, "shop_codes_parts", codesBad)
		local thanks = sections.Thanks and h.allText(sections.Thanks) or "missing"
		h.check(res, "shop_thanks_text", thanks, SH.ThanksText, has(thanks, SH.ThanksText))

		-- Geometry: band, hitboxes, no overlap; sections stacked apart; the header parts apart
		panelGeometry(res, "shop", panel)
		local stacked = {}
		for _, name in SH.Sections do
			table.insert(stacked, sections[name])
		end
		if #stacked == #SH.Sections then
			for _, vpSpec in h.viewports do
				local rectOf = h.provider(vpSpec)
				local apart = {}
				for a = 1, #stacked do
					for b = a + 1, #stacked do
						local ra, rb = rectOf(stacked[a]), rectOf(stacked[b])
						if h.intersects(ra, rb) then
							table.insert(apart, stacked[a].Name .. h.rstr(ra) .. " x " .. stacked[b].Name .. h.rstr(rb))
						end
					end
				end
				h.checkList(res, "shop_sections_no_overlap_" .. vpSpec.Name, apart)
			end
		end
		local close = h.find(SH.Close)
		if close then
			groupGeometry(res, "shop_header", panel, { close, items })
		end
		topmostChecks(res, "shop", panel, items)
		restore()
	end

	---------------------------------------------------------------------------------------------------------------
	-- Market

	local function tileName(kind, id)
		return MK.TileFormat:format(kind, id)
	end
	-- The tiles in the grid now: the kind they show (nil when mixed / empty) and the problems against MarketConfig
	local function gridProblems(wantKind)
		local grid = h.find(MK.Grid)
		if not grid then
			return nil, { MK.Grid .. " missing" }
		end
		local tiles, kinds = {}, {}
		for _, child in grid:GetChildren() do
			if child:IsA("GuiButton") then
				tiles[child.Name] = child
				local kind = string.match(child.Name, "^([^_]+)_")
				kinds[kind or "?"] = true
			end
		end
		local kind = wantKind
		if not kind then
			for k in kinds do
				kind = kind and "mixed" or k
			end
		end
		local bad = {}
		local items = MarketConfig.Items[kind or ""]
		if not items then
			return nil, { "grid shows kind " .. tostring(kind) .. ", want one of MarketConfig.Items" }
		end
		local want = {}
		for _, item in items do
			want[tileName(kind, item.Id)] = true
			local t = tiles[tileName(kind, item.Id)]
			if not t then
				table.insert(bad, tileName(kind, item.Id) .. " missing")
			elseif not h.visible(t) then
				table.insert(bad, tileName(kind, item.Id) .. " not shown")
			end
		end
		for name, t in tiles do
			if not want[name] and h.visible(t) then
				table.insert(bad, name .. " shown, not a " .. kind .. " item")
			end
		end
		return kind, bad
	end

	-- What the Detail pane must show for (kind, item): Name, Price (HudFormat.MoneyText), Description, a Rarity,
	-- and the Action label the server's attributes give (potions BUY; owned + equipped EQUIPPED; owned EQUIP; BUY).
	local function detailProblems(kind, item)
		local detail = h.find(MK.Detail)
		local bad = {}
		if not detail then
			return { MK.Detail .. " missing" }
		end
		local function part(name)
			return detail:FindFirstChild(name)
		end
		if string.upper(textOf(part("Name"))) ~= string.upper(item.Name) then
			table.insert(bad, ("Name shows %q, want %q"):format(textOf(part("Name")), item.Name))
		end
		-- Price row (a Frame since 016c467): its Value label. Potions: price and the owned count (Boost_<Id>); an
		-- owned trail / aura: "Owned"; else the price.
		local priceRow = part("Price")
		local priceText = textOf(priceRow and priceRow:FindFirstChild(MK.PriceText))
		local wantPrice = { HudFormat.MoneyText(item.Price) }
		local ok = has(priceText, wantPrice[1])
		if kind == "Potion" then
			-- Backpack counts are shortened like every number ("x1.2k", docs/HUD_LAYOUT_SPEC.md section 8)
			local count = HudFormat.Short(attr("Boost_" .. item.Id) or 0)
			table.insert(wantPrice, "x" .. count)
			ok = ok and string.match(priceText, "[xX]([%d%.]+%a*)%s*$") == count
		elseif attr("Own" .. kind .. "_" .. item.Id) == true then
			wantPrice = { "Owned" }
			ok = has(priceText, "Owned")
		end
		if not ok then
			table.insert(bad, ("Price shows %q, want %q"):format(priceText, table.concat(wantPrice, " + ")))
		end
		if not has(textOf(part("Description")), item.Description) then
			table.insert(bad, ("Description shows %q, want %q"):format(textOf(part("Description")), item.Description))
		end
		local rarity = textOf(part("Rarity"))
		if rarity == "" or rarity == "missing" or (item.Rarity and not has(rarity, item.Rarity)) then
			table.insert(bad, ("Rarity shows %q, want %s"):format(rarity, item.Rarity or "a rarity"))
		end
		-- Trail / aura subtitle names its Speed Gain multi (owner 2026-10-27, docs/GAME_DESIGN_REQUIREMENTS.md "Aura and
		-- trail ladders"): "Trail  •  x<SpeedMulti> Speed Gain", auras add "+ cruise". MarketConfig decides the number.
		if kind == "Trail" or kind == "Aura" then
			local wantMulti = "x" .. tostring(item.SpeedMulti)
			if
				type(item.SpeedMulti) ~= "number"
				or not has(rarity, kind)
				or not has(rarity, wantMulti .. " Speed Gain")
				or (kind == "Aura") ~= (has(rarity, "cruise") == true)
			then
				table.insert(
					bad,
					("Subtitle shows %q, want %s %s Speed Gain%s"):format(
						rarity,
						kind,
						wantMulti,
						kind == "Aura" and " + cruise" or ""
					)
				)
			end
		end
		local want = MK.ActionText.Buy
		if kind ~= "Potion" and attr("Own" .. kind .. "_" .. item.Id) == true then
			want = attr("Equipped" .. kind) == item.Id and MK.ActionText.Equipped or MK.ActionText.Equip
		end
		-- The text the Action button shows (its own Text, else its Label child's: Client/MarketUi actionLabel)
		local shown = shownText(part("Action"))
		if shown ~= want then
			table.insert(bad, ("Action shows %q, want %q"):format(shown, want))
		end
		return bad
	end

	function scenarios.ui_market(res)
		local restore = h.setPanels({ "MarketUi/Backdrop" })
		h.frames(2)
		local panel = h.find(MK.Panel)
		h.check(res, "market_panel_present", panel and panel.ClassName or "missing", MK.Panel, panel ~= nil)
		if not panel then
			restore()
			return
		end
		h.check(res, "market_panel_shown", h.visible(panel), true, h.visible(panel))
		local header, tabs, grid, detail = h.find(MK.Header), h.find(MK.Tabs), h.find(MK.Grid), h.find(MK.Detail)
		local parts = {}
		for name, o in { Header = header, Tabs = tabs, Grid = grid, Detail = detail } do
			if not (o and o:IsA("GuiObject")) then
				table.insert(parts, name .. " missing")
			end
		end
		if grid and not grid:IsA("ScrollingFrame") then
			table.insert(parts, "Grid is " .. grid.ClassName .. ", want ScrollingFrame")
		end
		h.checkList(res, "market_parts_present", parts)
		closeChecks(res, "market", h.find(MK.Close), MK.CloseText)

		-- Side tabs: one TextButton per kind, stacked top to bottom, left of the grid
		local tabBad, tabList = {}, {}
		for _, name in MK.TabOrder do
			local t = tabs and tabs:FindFirstChild(name)
			if not (t and t:IsA("TextButton")) then
				table.insert(tabBad, name .. " missing (TextButton)")
			else
				table.insert(tabList, t)
				if not MarketConfig.Items[MK.TabKinds[name]] then
					table.insert(tabBad, name .. ": MarketConfig.Items has no " .. MK.TabKinds[name])
				end
			end
		end
		for i = 2, #tabList do
			if
				tabList[i].AbsolutePosition.Y
				< tabList[i - 1].AbsolutePosition.Y + tabList[i - 1].AbsoluteSize.Y - TOL
			then
				table.insert(tabBad, tabList[i].Name .. " not below " .. tabList[i - 1].Name)
			end
		end
		if tabs and grid and tabs.AbsolutePosition.X + tabs.AbsoluteSize.X > grid.AbsolutePosition.X + TOL then
			table.insert(tabBad, "Tabs not left of Grid")
		end
		h.checkList(res, "market_tabs", tabBad)

		-- Grid: exactly the tiles of one kind; Detail: one of them, with its truth
		local kind, gridBad = gridProblems(nil)
		h.checkList(res, "market_grid_matches_config", gridBad)
		local detailBad = {}
		local dParts = {}
		for _, p in MK.DetailParts do
			local o = detail and detail:FindFirstChild(p.Name)
			if not (o and o:IsA(p.Class)) then
				table.insert(detailBad, ("%s missing (%s)"):format(p.Name, p.Class))
			else
				table.insert(dParts, o)
			end
		end
		local priceRow = detail and detail:FindFirstChild("Price")
		local priceLabel = priceRow and priceRow:FindFirstChild(MK.PriceText)
		if priceRow and not (priceLabel and priceLabel:IsA("TextLabel")) then
			table.insert(detailBad, ("Price/%s missing (TextLabel)"):format(MK.PriceText))
		end
		h.checkList(res, "market_detail_parts", detailBad)
		local shown = textOf(detail and detail:FindFirstChild("Name"))
		local selected = nil
		for _, item in kind and MarketConfig.Items[kind] or {} do
			if string.upper(item.Name) == string.upper(shown) then
				selected = item
			end
		end
		h.check(res, "market_detail_is_a_grid_item", shown, "a " .. tostring(kind) .. " item name", selected ~= nil)
		if selected then
			h.checkList(res, "market_detail_matches_item", detailProblems(kind, selected))
		end

		-- Geometry at every viewport
		panelGeometry(res, "market", panel)
		if header and tabs and grid and detail then
			groupGeometry(res, "market_sections", panel, { header, tabs, grid, detail })
		end
		local close = h.find(MK.Close)
		if close and header then
			groupGeometry(res, "market_close_in_header", header, { close })
		end
		if #tabList == #MK.TabOrder then
			groupGeometry(res, "market_tab_buttons", tabs, tabList)
		end
		if #dParts == #MK.DetailParts then
			groupGeometry(res, "market_detail_parts", detail, dParts)
		end
		topmostChecks(res, "market", panel, grid)
		restore()
	end

	---------------------------------------------------------------------------------------------------------------
	-- Click post-conditions (UiSpec.Clicks Expect.After)

	local function waitFor(seconds, fn)
		local deadline = os.clock() + seconds
		local ok, a, b = fn()
		while not ok and os.clock() < deadline do
			task.wait(0.1)
			ok, a, b = fn()
		end
		return ok, a, b
	end

	for kindName, kind in { aura = "Aura", trail = "Trail", potion = "Potion" } do
		after["market_grid_shows_" .. kindName] = function(res)
			local _, _, bad = waitFor(1, function()
				local _, problems = gridProblems(kind)
				return #problems == 0, nil, problems
			end)
			h.checkList(res, "market_grid_shows_" .. kindName, bad)
		end
	end

	after.market_detail_shows_tile = function(res, ctx)
		local segs = string.split(ctx.path, "/")
		local kind, id = string.match(segs[#segs], "^([^_]+)_(.+)$")
		local item = kind and MarketConfig.Get(kind, id)
		if not item then
			h.check(res, "market_detail_shows_tile", segs[#segs], "a MarketConfig <Kind>_<Id>", false)
			return
		end
		local _, _, bad = waitFor(1, function()
			local problems = detailProblems(kind, item)
			return #problems == 0, nil, problems
		end)
		h.checkList(res, "market_detail_shows_tile", bad)
	end

	after.shop_no_purchase_prompt = function(res)
		local recent = {}
		for _, p in prompts do
			if os.clock() - p.t <= Spec.Waits.ClickSettle + 3 then
				table.insert(recent, p.name)
			end
		end
		h.checkList(res, "shop_no_purchase_prompt", recent)
	end

	after.shop_redeem_status_from_server = function(res)
		local status = h.find("ShopUi/Backdrop/Panel/Items/Codes/**/" .. SH.Codes.Status)
		local ok, text = waitFor(SH.ReplyWait, function()
			local t = textOf(status)
			return table.find(SH.BadCodeReplies, t) ~= nil, t
		end)
		h.check(res, "shop_redeem_status_from_server", text, table.concat(SH.BadCodeReplies, " | "), ok)
	end

	return {
		Scenarios = scenarios,
		After = after,
		Geometry = { Panel = panelGeometry, Group = groupGeometry, Topmost = topmostChecks },
	}
end

return ShopMarket
