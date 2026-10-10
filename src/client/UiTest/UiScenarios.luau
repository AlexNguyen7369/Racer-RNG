--!nonstrict
-- UI compatibility checks, run on the client by UiTestHarness. Owned by ui-test-writer.
-- Result shape matches Server/CarTest: { scenario, pass, checks = { { name, value, limit, pass } } }.
--
-- Geometry is in SCREEN pixels: (0, 0) is the window's top-left corner, the top-bar inset included.
-- "current" uses the engine's AbsolutePosition/AbsoluteSize; the other UiSpec.Viewports are solved with the same
-- layout rules (see simRect), and the solver is checked against the engine on the current viewport.
-- Nothing here fires a gameplay remote; panels, scroll positions and attributes touched are restored.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local UiSpec = require(script.Parent:WaitForChild("UiSpec"))
local UiResponsive = require(script.Parent:WaitForChild("UiResponsive"))
local UiLegacyControls = require(script.Parent:WaitForChild("UiLegacyControls"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudFormat = require(Shared:WaitForChild("HudFormat"))
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local GachaConfig = require(Shared:WaitForChild("GachaConfig"))
local NpcConfig = require(Shared:WaitForChild("NpcConfig"))
local TrackBuilder = require(Shared:WaitForChild("TrackBuilder"))
local UpgradeTree = require(Shared:WaitForChild("UpgradeTree"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Shared/RollAnimConfig (docs/ROLL_ANIMATION_CONTRACT.md), read live. While it is missing, the contract's values
-- (UiSpec.RollAnim.Fallback) keep the other checks computable and roll_anim_config_present fails.
local animModule = nil
local function anim()
	if animModule == nil then
		local m = Shared:FindFirstChild(UiSpec.RollAnim.Module)
		if m and m:IsA("ModuleScript") then
			local ok, cfg = pcall(require, m)
			if ok and type(cfg) == "table" then
				animModule = cfg
			end
		end
	end
	return animModule
end

local function animNum(name)
	local cfg = anim()
	local v = cfg and cfg[name]
	if type(v) ~= "number" then
		v = UiSpec.RollAnim.Fallback[name]
	end
	return v
end

local function holdFor(rarity)
	local cfg = anim()
	if cfg and type(cfg.Hold) == "function" then
		local ok, v = pcall(cfg.Hold, rarity)
		if ok and type(v) == "number" then
			return v
		end
	end
	local h = UiSpec.RollAnim.Fallback.HOLD
	return h[rarity] or h.Common
end

-- One roll's length: POP + SPIN + LAND + Hold(rarity) + EXIT (+ 2 x SWITCH when emphasized)
local function durationFor(rarity, emphasized)
	local d = animNum("POP") + animNum("SPIN") + animNum("LAND") + holdFor(rarity) + animNum("EXIT")
	if emphasized then
		d += 2 * animNum("SWITCH")
	end
	return d
end

local UiScenarios = {}

UiScenarios.Names = {
	"ui_client_rendering",
	"ui_inventory",
	"ui_legacy_controls",
	"ui_layout",
	"ui_hitboxes",
	"ui_buttons",
	"ui_hud",
	"ui_index",
	"ui_stats",
	"ui_toast",
	"ui_rolls",
	"ui_roll_anim",
	"ui_showcase",
	"ui_loser",
	"ui_billboards",
	"ui_panels",
	"ui_upgrades",
	"ui_workshop_modal",
	"ui_progression_layout",
	"ui_progression_hud",
	-- ui_offline_welcome needs its offline_welcome server fixture, so it runs only through
	-- UiSpec.Progression.FixtureChecks (UiTestScenario), like ui_offline_zero and ui_progression_world.
	"ui_weather",
	-- Last: its server setup (emphasized_next) takes the cars away until the emphasized roll happened
	"ui_roll_emphasized",
}

local TOL = UiSpec.Tolerance
local STATES = {
	{ Name = "rest", Open = {} },
	{ Name = "index_open", Open = { "RacerIndex/Panel" } },
	{ Name = "stats_open", Open = { "RacerStats/Panel" } },
	{ Name = "settings_open", Open = { "RacerSettings/Panel" } },
	{ Name = "rebirth_open", Open = { "RacerRebirth/Panel" } },
	{ Name = "upgrades_open", Open = { "RacerUpgrades/Panel" } },
	{ Name = "workshop_open", Open = { "RacerWorkshop/Panel" } },
	{ Name = "welcome_open", Open = { "RacerWelcome/Panel" } },
	-- Two panels open at once is NOT a reachable state: ui_panels proves the panels are mutually exclusive
	-- through the real mechanism (PanelSwitch) and the Clicks open_*_while_*_open prove it through the buttons.
	-- If exclusivity ever breaks, ui_panels fails, and this state must be added back here.
}
-- Layout objects the solver does not model (UIListLayout, UIGridLayout and UIPadding are solved in simRect).
local UNSUPPORTED_LAYOUT = {
	UIAspectRatioConstraint = true,
	UIScale = true,
	UIPageLayout = true,
	UITableLayout = true,
	UIFlexItem = true,
}
local legacyObserver = nil

---------------------------------------------------------------------------------------------------------------
-- Results

local function newResult(name)
	return { scenario = name, pass = true, checks = {} }
end

local function check(res, name, value, limit, ok)
	-- Check names use snake_case, matching the server harness.
	name = string.lower((string.gsub(name, "[^%w_]", "_")))
	if type(value) == "number" then
		value = math.floor(value * 1000 + 0.5) / 1000
	elseif value == nil then
		value = "nil"
	elseif type(value) ~= "string" and type(value) ~= "boolean" then
		value = tostring(value)
	end
	if limit == nil then
		limit = "nil"
	elseif type(limit) ~= "number" and type(limit) ~= "string" and type(limit) ~= "boolean" then
		limit = tostring(limit)
	end
	ok = ok == true
	table.insert(res.checks, { name = name, value = value, limit = limit, pass = ok })
	if not ok then
		res.pass = false
	end
end

-- One aggregated check: pass when `offenders` is empty; the value lists them (capped so the JSON stays short).
local function checkList(res, name, offenders)
	local shown = {}
	for i = 1, math.min(#offenders, 8) do
		shown[i] = offenders[i]
	end
	local value = #offenders == 0 and "none" or table.concat(shown, "; ")
	if #offenders > 8 then
		value ..= ("; ... +%d more"):format(#offenders - 8)
	end
	check(res, name, value, "none", #offenders == 0)
end

local function stateMissing(res, name, setupId, why)
	check(res, name, "state_missing:" .. setupId .. (why and (" (" .. why .. ")") or ""), "present", false)
end

---------------------------------------------------------------------------------------------------------------
-- Instances

local function findPath(path)
	local node = playerGui
	for part in string.gmatch(path, "[^/]+") do
		if not node then
			return nil
		end
		node = node:FindFirstChild(part)
	end
	return node
end

local function pathOf(obj)
	local parts = {}
	local node = obj
	while node and node ~= playerGui and node ~= game do
		table.insert(parts, 1, node.Name)
		node = node.Parent
	end
	return table.concat(parts, "/")
end

local function splitPath(path)
	local parts = {}
	for part in string.gmatch(path, "[^/]+") do
		table.insert(parts, part)
	end
	return parts
end

-- "Panel/Grid/*/Equip" matches "Panel/Grid/go_kart/Equip"; "{token}" segments in click paths count as "*".
local function pathMatches(pattern, path)
	local a, b = splitPath(pattern), splitPath(path)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		local seg = a[i]
		if seg ~= "*" and not string.match(seg, "^{.*}$") and seg ~= b[i] then
			return false
		end
	end
	return true
end

local function guiOf(obj)
	if obj:IsA("LayerCollector") then
		return obj
	end
	return obj:FindFirstAncestorWhichIsA("LayerCollector")
end

-- Shown on screen: every GuiObject up to the ScreenGui is Visible and the ScreenGui is Enabled.
local function effectivelyVisible(obj)
	local node = obj
	while node and node ~= playerGui do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

-- Takes clicks: any GuiButton (Active or not, it still sinks the click) or any other Active GuiObject.
local function swallows(obj)
	return obj:IsA("GuiButton") or obj:IsA("TextBox") or (obj:IsA("GuiObject") and obj.Active)
end

local function declaredGuis()
	local names = {}
	for name in UiSpec.Guis do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local function allPanels()
	local list = {}
	for _, guiName in declaredGuis() do
		for _, p in UiSpec.Guis[guiName].Panels or {} do
			table.insert(list, guiName .. "/" .. p)
		end
	end
	return list
end

local function buttonsIn(root)
	local list = {}
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("GuiButton") then
				table.insert(list, d)
			end
		end
	end
	table.sort(list, function(a, b)
		return pathOf(a) < pathOf(b)
	end)
	return list
end

local function allButtons()
	local list = {}
	for _, guiName in declaredGuis() do
		for _, b in buttonsIn(playerGui:FindFirstChild(guiName)) do
			table.insert(list, b)
		end
	end
	return list
end

-- Waits for one rendered frame, but never longer than `timeout` seconds (Heartbeat keeps running on a client
-- that does not render, e.g. a minimised window). Returns true if a frame was rendered. After one timeout the
-- client is marked as not rendering and later waits only give it a short chance, so the run always finishes;
-- the ui_client_rendering check reports it.
local RENDER_TIMEOUT = 3
local notRendering = false

local function renderFrame(timeout)
	local fired = false
	local conn = RunService.RenderStepped:Connect(function()
		fired = true
	end)
	local deadline = os.clock() + (timeout or (notRendering and 0.1 or RENDER_TIMEOUT))
	while not fired and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	conn:Disconnect()
	if not fired then
		notRendering = true
	end
	return fired
end

local function frames(n)
	for _ = 1, n or 2 do
		renderFrame()
	end
end

-- Forces exactly the panels in `open` visible (all other declared panels hidden). Returns a restore function.
local function setPanels(open)
	local saved = {}
	for _, p in allPanels() do
		local o = findPath(p)
		if o then
			saved[o] = o.Visible
			o.Visible = table.find(open, p) ~= nil
		end
	end
	frames(2)
	return function()
		for o, v in saved do
			o.Visible = v
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Geometry

local function R(x, y, w, h)
	return { x = x, y = y, w = w, h = h }
end

local function rstr(r)
	local function n(v)
		return math.floor(v + 0.5)
	end
	return ("(%d,%d %dx%d)"):format(n(r.x), n(r.y), n(r.w), n(r.h))
end

local function intersects(a, b)
	local ox = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
	local oy = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
	return ox > TOL and oy > TOL
end

local function contains(outer, inner)
	return inner.x >= outer.x - TOL
		and inner.y >= outer.y - TOL
		and inner.x + inner.w <= outer.x + outer.w + TOL
		and inner.y + inner.h <= outer.y + outer.h + TOL
end

local function intersection(a, b)
	local x1, y1 = math.max(a.x, b.x), math.max(a.y, b.y)
	local x2, y2 = math.min(a.x + a.w, b.x + b.w), math.min(a.y + a.h, b.y + b.h)
	if x2 <= x1 or y2 <= y1 then
		return nil
	end
	return R(x1, y1, x2 - x1, y2 - y1)
end

local function union(a, b)
	if not a then
		return b
	end
	if not b then
		return a
	end
	local x1, y1 = math.min(a.x, b.x), math.min(a.y, b.y)
	local x2, y2 = math.max(a.x + a.w, b.x + b.w), math.max(a.y + a.h, b.y + b.h)
	return R(x1, y1, x2 - x1, y2 - y1)
end

local function centre(r)
	return r.x + r.w / 2, r.y + r.h / 2
end

local function inset()
	local tl, br = GuiService:GetGuiInset()
	return tl, br
end

-- The screen size the engine lays the UI out in. A camera that has not rendered yet (a freshly created or swapped
-- CurrentCamera) reports ViewportSize (1, 1); then the screen comes from an IgnoreGuiInset ScreenGui, whose
-- AbsoluteSize is the whole screen. (A (1, 1) viewport made the enlarged card's model a 1-px rect.)
local function viewport()
	local cam = Workspace.CurrentCamera
	local size = cam and cam.ViewportSize
	if size and size.X > 1 and size.Y > 1 then
		return size
	end
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.IgnoreGuiInset and g.AbsoluteSize.X > 1 and g.AbsoluteSize.Y > 1 then
			return g.AbsoluteSize
		end
	end
	return size or Vector2.new(0, 0)
end

-- The ScreenGui's drawing area in screen pixels: below the top bar unless IgnoreGuiInset.
local function rootRect(gui, vp)
	local tl, br = inset()
	if gui:IsA("ScreenGui") and not gui.IgnoreGuiInset then
		return R(tl.X, tl.Y, vp.X - tl.X - br.X, vp.Y - tl.Y - br.Y)
	end
	return R(0, 0, vp.X, vp.Y)
end

-- Engine rectangle in screen pixels. AbsolutePosition is measured from the top-left of the area BELOW the top bar
-- for every ScreenGui (an IgnoreGuiInset gui's top edge reads -inset), the same space GetGuiObjectsAtPosition takes
-- (hitsAt), so screen = AbsolutePosition + GetGuiInset() top-left. It does not go through the ScreenGui's own
-- AbsolutePosition: under Studio device emulation (750x361, inset 58) that put every IgnoreGuiInset rect exactly
-- 58 px off (layout_model_matches_engine_rest).
local function realRect(obj)
	local gui = guiOf(obj)
	if obj == gui then
		return rootRect(gui, viewport())
	end
	local tl = inset()
	return R(obj.AbsolutePosition.X + tl.X, obj.AbsolutePosition.Y + tl.Y, obj.AbsoluteSize.X, obj.AbsoluteSize.Y)
end

local function constrain(obj, w, h)
	local c = obj:FindFirstChildWhichIsA("UISizeConstraint")
	if c then
		w = math.max(c.MinSize.X, math.min(c.MaxSize.X, w))
		h = math.max(c.MinSize.Y, math.min(c.MaxSize.Y, h))
	end
	return w, h
end

local simRect

-- True when ctx viewport uses the other generated variant (phone / desktop) than the live screen: the live properties
-- then describe the wrong variant and the model's (UiResponsive.Nodes / Grids) are used instead.
local function otherVariant(vp)
	return UiResponsive.VariantOf(vp) ~= UiResponsive.VariantOf(viewport())
end

local function sameSize(a, b)
	return math.abs(a.X - b.X) < 0.5 and math.abs(a.Y - b.Y) < 0.5
end

-- The layout factor of obj's own UIScale children at ctx.vp (1 without one). UIScale scales the object about its
-- AnchorPoint and all its descendants. Generated "UIScale"s come from the model (UiResponsive.ScaleAt) at every
-- viewport; hover / press scales (UiSpec.TransientScales) count as 1; any other UIScale is read live on the live
-- viewport and is unsupported (ctx.unsupported -> layout_model_supported fails) on a simulated one.
local function ownScale(obj, ctx)
	local s = 1
	for _, child in obj:GetChildren() do
		if child:IsA("UIScale") and not UiSpec.TransientScales[child.Name] then
			-- A runtime fit (RacerUiController.fitPanels) replaces the generated scale: ctx.scaleOverride[obj]
			local override = child.Name == "UIScale" and ctx.scaleOverride and ctx.scaleOverride[obj]
			local modelled = override or (child.Name == "UIScale" and UiResponsive.ScaleAt(pathOf(obj), ctx.vp))
			if modelled then
				s *= modelled
			else
				if not sameSize(ctx.vp, viewport()) then
					ctx.unsupported[pathOf(obj)] = "UIScale " .. child.Name
				end
				s *= child.Scale
			end
		end
	end
	return s
end

-- The product of the UIScale factors of obj and its GuiObject ancestors (what obj's children's offsets are scaled by).
local function inheritedScale(obj, ctx)
	ctx.scales = ctx.scales or {}
	local cached = ctx.scales[obj]
	if cached then
		return cached
	end
	local s = 1
	if obj:IsA("GuiObject") then
		s = ownScale(obj, ctx) * (obj.Parent and inheritedScale(obj.Parent, ctx) or 1)
	end
	ctx.scales[obj] = s
	return s
end

-- The layout props a node uses at ctx.vp: on the other variant than the live one a generated node takes the model's
-- variant props (UiResponsive.Nodes), else its live properties.
local function variantProps(obj, ctx)
	local node = otherVariant(ctx.vp) and UiResponsive.Nodes[pathOf(obj)]
	local props = node and node[UiResponsive.VariantOf(ctx.vp)] or {}
	return props.Size or obj.Size, props.Position or obj.Position, props.AnchorPoint or obj.AnchorPoint
end

-- obj's size in `base` (Offsets are design pixels scaled by the inherited UIScale c; UISizeConstraint limits the
-- design size; obj's own UIScale scales it about its anchor).
local function sizeIn(obj, size, base, ctx, c)
	local own = ownScale(obj, ctx)
	local w = base.w * size.X.Scale + c * size.X.Offset
	local h = base.h * size.Y.Scale + c * size.Y.Offset
	w, h = constrain(obj, w / c, h / c)
	return w * c * own, h * c * own
end

-- The area children are laid out in: a ScrollingFrame's canvas (moved by CanvasPosition; as wide and tall as the
-- window, AutomaticCanvasSize only grows it downwards) minus the parent's UIPadding (its offsets are design pixels
-- scaled by the parent's inherited UIScale c, its scales relative to that area).
local function contentBox(parent, pr, c)
	local base = pr
	if parent:IsA("ScrollingFrame") then
		base = R(pr.x - parent.CanvasPosition.X, pr.y - parent.CanvasPosition.Y, pr.w, pr.h)
	end
	local pad = parent:FindFirstChildWhichIsA("UIPadding")
	if pad then
		local function px(u, extent)
			return extent * u.Scale + c * u.Offset
		end
		local l, r = px(pad.PaddingLeft, base.w), px(pad.PaddingRight, base.w)
		local t, b = px(pad.PaddingTop, base.h), px(pad.PaddingBottom, base.h)
		base = R(base.x + l, base.y + t, base.w - l - r, base.h - t - b)
	end
	return base
end

-- The visible GuiObject children a layout arranges, in its order.
local function layoutItems(parent, layout)
	local items = {}
	for _, ch in parent:GetChildren() do
		if ch:IsA("GuiObject") and ch.Visible then
			table.insert(items, ch)
		end
	end
	local byName = layout.SortOrder == Enum.SortOrder.Name
	table.sort(items, function(a, b)
		if not byName and a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return a.Name < b.Name
	end)
	return items
end

-- Offset of a run of `length` px inside `extent` px for an alignment: 0 (Left / Top), half (Center), all (Right /
-- Bottom).
local function align(alignment, extent, length)
	if alignment == Enum.HorizontalAlignment.Center or alignment == Enum.VerticalAlignment.Center then
		return (extent - length) / 2
	elseif alignment == Enum.HorizontalAlignment.Right or alignment == Enum.VerticalAlignment.Bottom then
		return extent - length
	end
	return 0
end

-- UIGridLayout: cells fill rows left to right from the top-left (FillDirection Horizontal, StartCorner TopLeft);
-- HorizontalAlignment / VerticalAlignment place the whole block of cells (as wide as its fullest row) in the content
-- box, and a short last row fills from the block's left edge like the others (it is NOT centred on its own: the
-- engine put the Index's last-row tiles one column pitch left of a per-row-centred model, layout_model_matches_engine
-- 162 px at 1081x638). Other options are recorded as unsupported.
local function gridCell(obj, parent, grid, base, ctx, scale)
	if
		grid.FillDirection ~= Enum.FillDirection.Horizontal
		or grid.StartCorner ~= Enum.StartCorner.TopLeft
		or (grid.SortOrder ~= Enum.SortOrder.LayoutOrder and grid.SortOrder ~= Enum.SortOrder.Name)
	then
		ctx.unsupported[pathOf(grid)] = "UIGridLayout options"
	end
	-- Offsets are design pixels: the inherited UIScale factor `scale` applies to them. On the other variant than the live
	-- one the cell size comes from the model (Components.BindIndex fit()), else from the live UIGridLayout.
	local cellSize = grid.CellSize
	local gridModel = UiResponsive.Grids[pathOf(parent)]
	if gridModel and otherVariant(ctx.vp) then
		local variant = UiResponsive.VariantOf(ctx.vp)
		local host = UiResponsive.Nodes[gridModel.Host][variant]
		local cols = gridModel.Columns[variant]
		local width = host.Size.X.Offset - gridModel.Inset
		cellSize = UDim2.fromOffset(math.floor((width - (cols - 1) * gridModel.Gap) / cols), gridModel.CellHeight)
	end
	local cw = base.w * cellSize.X.Scale + scale * cellSize.X.Offset
	local ch = base.h * cellSize.Y.Scale + scale * cellSize.Y.Offset
	local px = base.w * grid.CellPadding.X.Scale + scale * grid.CellPadding.X.Offset
	local py = base.h * grid.CellPadding.Y.Scale + scale * grid.CellPadding.Y.Offset
	local items = layoutItems(parent, grid)
	local idx = table.find(items, obj)
	if not idx then
		return R(base.x, base.y, 0, 0)
	end
	-- (1e-9: an exact fit, e.g. the phone Index 3 x 146 + 2 x 12 = 462, must not lose a column to float error)
	local cols = math.max(1, math.floor((base.w + px) / (cw + px) + 1e-9))
	if grid.FillDirectionMaxCells > 0 then
		cols = math.min(cols, grid.FillDirectionMaxCells)
	end
	local i = idx - 1
	local row = math.floor(i / cols)
	local blockCols = math.min(cols, #items)
	local rows = math.ceil(#items / cols)
	local x0 = align(grid.HorizontalAlignment, base.w, blockCols * cw + (blockCols - 1) * px)
	local y0 = align(grid.VerticalAlignment, base.h, rows * ch + (rows - 1) * py)
	return R(base.x + x0 + (i % cols) * (cw + px), base.y + y0 + row * (ch + py), cw, ch)
end

-- UIListLayout (no Wraps, no flex): the visible children one after another along FillDirection with Padding between
-- them (Position and AnchorPoint ignored), the run aligned by the alignment along that axis and each child by the
-- other alignment across it.
local function listCell(obj, parent, list, base, ctx, scale)
	local okW, wraps = pcall(function()
		return list.Wraps
	end)
	local okF, flex = pcall(function()
		return list.HorizontalFlex ~= Enum.UIFlexAlignment.None or list.VerticalFlex ~= Enum.UIFlexAlignment.None
	end)
	if (okW and wraps) or (okF and flex) then
		ctx.unsupported[pathOf(list)] = "UIListLayout Wraps / flex"
	end
	local vertical = list.FillDirection == Enum.FillDirection.Vertical
	local items = layoutItems(parent, list)
	local gap = (vertical and base.h or base.w) * list.Padding.Scale + scale * list.Padding.Offset
	local sizes, total, before = {}, 0, nil
	for k, item in items do
		local size = variantProps(item, ctx)
		local w, h = sizeIn(item, size, base, ctx, scale)
		sizes[item] = { w = w, h = h }
		if item == obj then
			before = total
		end
		total += (vertical and h or w) + (k < #items and gap or 0)
	end
	if not before then
		return R(base.x, base.y, 0, 0)
	end
	local me = sizes[obj]
	if vertical then
		local y = base.y + align(list.VerticalAlignment, base.h, total) + before
		return R(base.x + align(list.HorizontalAlignment, base.w, me.w), y, me.w, me.h)
	end
	local x = base.x + align(list.HorizontalAlignment, base.w, total) + before
	return R(x, base.y + align(list.VerticalAlignment, base.h, me.h), me.w, me.h)
end

-- The Speed group's visible icon + number width at a viewport (RacerUiController centres exactly that): the number's
-- live TextBounds in design pixels (live UIScale and TextSize divided out, the variant's TextSize and UIScale applied),
-- or nil while the number draws nothing (the controller then does not move the group).
local function speedVisibleWidth(vp)
	local group, icon, value =
		findPath(UiSpec.Hud.Speed), findPath(UiSpec.Hud.SpeedIcon), findPath(UiSpec.Hud.SpeedValue)
	if not (group and icon and value) or value.TextBounds.X <= 0 then
		return nil
	end
	local liveScale = group:FindFirstChild("UIScale")
	liveScale = liveScale and liveScale:IsA("UIScale") and liveScale.Scale or 1
	local nodes = UiResponsive.Nodes
	local liveVariant, variant = UiResponsive.VariantOf(viewport()), UiResponsive.VariantOf(vp)
	local valueNode = nodes[UiSpec.Hud.SpeedValue]
	local iconNode = nodes[UiSpec.Hud.SpeedIcon]
	local textDesign = value.TextBounds.X / liveScale
	if valueNode and valueNode[liveVariant].TextSize and valueNode[variant].TextSize then
		textDesign *= valueNode[variant].TextSize / valueNode[liveVariant].TextSize
	end
	local valueX = valueNode and valueNode[variant].Position.X.Offset or value.Position.X.Offset
	local iconX = iconNode and iconNode[variant].Position.X.Offset or icon.Position.X.Offset
	local s = UiResponsive.ScaleAt(UiSpec.Hud.Speed, vp) or 1
	return s * (valueX + textDesign - iconX), s * iconX
end

-- The two roll cards animate (PopIn grows from 0, LAND_POP, Exit shrink, the 0.3 s SWITCH), so their live Size /
-- Position are only meaningful while settled. The solver places them at their CONTRACT rect
-- (docs/ROLL_ANIMATION_CONTRACT.md, numbers from Shared/RollAnimConfig) unless ctx.live; liveVsNominal proves the
-- live card sits exactly there (at every viewport) whenever it is settled.
local function cardKind(obj)
	if not obj:IsA("GuiObject") then
		return nil
	end
	local gui = obj.Parent
	if obj.Name == "Toast" and gui and gui.Name == "RollToast" and gui.Parent == playerGui then
		return "compact"
	end
	local lc = obj.Name == UiSpec.Showcase.Card and guiOf(obj)
	if lc and lc.Name == UiSpec.Showcase.Gui and lc.Parent == playerGui then
		return "enlarged"
	end
	return nil
end

-- Compact: AnchorPoint (0.5, 0), centred, top edge COMPACT_GAP under the Auto Race button, width
-- clamp(COMPACT_WIDTH x parent width, COMPACT_MIN, COMPACT_MAX), height COMPACT_HEIGHT.
local function compactNominal(base, toggleRect)
	local w = math.clamp(base.w * animNum("COMPACT_WIDTH"), animNum("COMPACT_MIN"), animNum("COMPACT_MAX"))
	local h = animNum("COMPACT_HEIGHT") + UiSpec.Compact.ExtraHeight
	local top = toggleRect and (toggleRect.y + toggleRect.h + animNum("COMPACT_GAP")) or base.y
	return R(base.x + base.w / 2 - w / 2, top, w, h)
end

-- Enlarged: the generated RollShowcase.ui.json card (Desktop 760x320 / Phone 540x224, AnchorPoint (0.5, 0.5),
-- Position (0.5, 0.46)) scaled by its generated UIScale k about its centre (UiResponsive.CardRect). The
-- docs/ROLL_ANIMATION_CONTRACT.md size formula (ENLARGED_WIDTH x screen width) is superseded by the owner-approved
-- ui.json, with no ENLARGED_MAX cap (owner decision 2026-10-08).
local function enlargedNominal(base, vp)
	local r = UiResponsive.CardRect(vp, base)
	return R(r.x, r.y, r.w, r.h)
end

-- Layout solver for a hypothetical viewport: UDim2 Position/Size, AnchorPoint, UISizeConstraint, UIScale, UIPadding,
-- UIListLayout, UIGridLayout, ScrollingFrame CanvasPosition, the top-bar inset, and the runtime rules of the UI
-- scripts mirrored in UiResponsive (Speed centring + R3, Racer panel band R2, compact roll BelowRace, ProgressionUi
-- fits incl. R4). Anything else is recorded in ctx.unsupported (the layout_model_supported check fails, so the solver
-- must be extended, never ignored). UIGradient, UICorner, UIStroke and GuiObject.Rotation do not move or size
-- anything (visual only).
simRect = function(obj, ctx)
	local cached = ctx.cache[obj]
	if cached then
		return cached
	end
	ctx.scaleOverride = ctx.scaleOverride or {}
	local r
	local kind = not ctx.live and cardKind(obj)
	local liveVp = sameSize(ctx.vp, viewport())
	if pathOf(obj) == UiSpec.Hud.Race then
		r = UiResponsive.RaceFaceRect(ctx.vp)
	elseif pathOf(obj) == UiSpec.Hud.Turbo then
		r = UiResponsive.ScaledHudRect(UiSpec.Hud.Turbo, ctx.vp)
	elseif pathOf(obj) == UiSpec.Hud.Speed then
		if liveVp then
			-- The live viewport: where RacerUiController put it (X centring and the R3 shift are live properties)
			r = UiResponsive.ScaledHudRect(UiSpec.Hud.Speed, ctx.vp, obj.Position.X)
			r.y += obj.Position.Y.Offset - UiResponsive.Nodes[UiSpec.Hud.Speed][UiResponsive.VariantOf(ctx.vp)].Position.Y.Offset
		else
			r = UiResponsive.ScaledHudRect(UiSpec.Hud.Speed, ctx.vp)
			local visible, iconX = speedVisibleWidth(ctx.vp)
			if visible then
				local toast, turbo = findPath("RollToast/Toast"), findPath(UiSpec.Hud.Turbo)
				r = UiResponsive.SpeedGroup(
					ctx.vp,
					r,
					visible,
					toast and simRect(toast, ctx),
					turbo and simRect(turbo, ctx)
				)
				r.x -= iconX
			end
		end
	elseif kind then
		local base = simRect(obj.Parent, ctx)
		if kind == "compact" then
			local toggle = findPath(UiSpec.Hud.Race)
			r = compactNominal(base, toggle and simRect(toggle, ctx))
		else
			r = enlargedNominal(base, ctx.vp)
		end
	elseif obj:IsA("LayerCollector") then
		r = rootRect(obj, ctx.vp)
	elseif not obj:IsA("GuiObject") then
		r = simRect(obj.Parent, ctx)
	else
		local parent = obj.Parent
		local pr = simRect(parent, ctx)
		for _, sibling in parent:GetChildren() do
			-- A UIScale under a GuiObject is solved (ownScale / inheritedScale); under a ScreenGui it is not
			local solved = sibling:IsA("UIScale") and parent:IsA("GuiObject")
			if UNSUPPORTED_LAYOUT[sibling.ClassName] and not solved then
				ctx.unsupported[pathOf(parent)] = sibling.ClassName
			end
			if
				(sibling:IsA("UIListLayout") or sibling:IsA("UIGridLayout") or sibling:IsA("UIPadding"))
				and not parent:IsA("GuiObject")
			then
				ctx.unsupported[pathOf(parent)] = sibling.ClassName .. " under a ScreenGui"
			end
		end
		local c = inheritedScale(parent, ctx)
		if obj.AutomaticSize ~= Enum.AutomaticSize.None then
			ctx.unsupported[pathOf(obj)] = "AutomaticSize"
		end
		local base = parent:IsA("GuiObject") and contentBox(parent, pr, c) or pr
		local grid = parent:FindFirstChildWhichIsA("UIGridLayout")
		local list = parent:FindFirstChildWhichIsA("UIListLayout")
		if grid then
			r = gridCell(obj, parent, grid, base, ctx, c)
		elseif list then
			r = listCell(obj, parent, list, base, ctx, c)
		else
			local path = pathOf(obj)
			local dependencies = {}
			local isProgressionPanel = path == "RacerUpgrades/Panel"
				or path == "RacerWorkshop/Panel"
				or path == "RacerWelcome/Panel"
			local isRate = path == "RacerProgression/WorkshopRate"
			local isRacerPanel = UiResponsive.IsRacerPanel(path)
			local wanted = {}
			if isProgressionPanel then
				wanted = {
					Toast = "RollToast/Toast",
					Turbo = UiSpec.Hud.Turbo,
					UpgradeButton = "RacerProgression/UpgradeButton",
					Navigation = UiSpec.RacerPanelBand.Navigation,
				}
			elseif isRate then
				wanted = { Speed = UiSpec.Hud.Speed, Toast = "RollToast/Toast" }
			elseif isRacerPanel then
				wanted =
					{ Race = UiSpec.Hud.Race, Turbo = UiSpec.Hud.Turbo, Navigation = UiSpec.RacerPanelBand.Navigation }
			end
			local missing = false
			for key, dependencyPath in wanted do
				local dependency = findPath(dependencyPath)
				if dependency then
					dependencies[key] = simRect(dependency, ctx)
				else
					missing = true
				end
			end
			-- The column's right edge includes its visible descendants (the STATS PointsBadge), as the game reads
			-- it: each GuiObject descendant whose own Visible is true (UiResponsive.ColumnRight).
			if dependencies.Navigation then
				local parts = {}
				for _, d in findPath(wanted.Navigation):GetDescendants() do
					if d:IsA("GuiObject") and d.Visible then
						table.insert(parts, simRect(d, ctx))
					end
				end
				dependencies.NavigationParts = parts
			end
			local fitted = nil
			if missing then
				ctx.unsupported[path] = "missing runtime layout dependency"
			elseif isRacerPanel then
				local size = variantProps(obj, ctx)
				fitted = UiResponsive.RacerPanelFit(ctx.vp, dependencies, size)
				ctx.scaleOverride[obj] = fitted.Scale
			elseif isProgressionPanel or isRate then
				fitted = UiResponsive.Progression(path, ctx.vp, dependencies)
			end
			local vSize, vPosition, vAnchor = variantProps(obj, ctx)
			local size = fitted and fitted.Size or vSize
			local position = fitted and fitted.Position or vPosition
			local anchor = fitted and fitted.AnchorPoint or vAnchor
			-- The compact roll's live Y offset is fitCompact's for the live screen: at a simulated viewport it is
			-- Race Face bottom + COMPACT_GAP there (UiResponsive.BelowRace)
			local below = UiResponsive.BelowRace[path]
			if below and not liveVp and findPath(below) then
				local race = simRect(findPath(below), ctx)
				position =
					UDim2.new(position.X.Scale, position.X.Offset, 0, race.y + race.h + animNum("COMPACT_GAP") - base.y)
			end
			local w, h = sizeIn(obj, size, base, ctx, c)
			local x = base.x + base.w * position.X.Scale + c * position.X.Offset - anchor.X * w
			local y = base.y + base.h * position.Y.Scale + c * position.Y.Offset - anchor.Y * h
			r = R(x, y, w, h)
		end
	end
	ctx.cache[obj] = r
	return r
end

-- Rect function for a UiSpec.Viewports entry ("current": the engine's rects, the roll cards at their contract rect).
local function provider(vpSpec)
	if not vpSpec.Size then
		local cardCtx = { vp = viewport(), cache = {}, unsupported = {} }
		return function(obj)
			if cardKind(obj) then
				return simRect(obj, cardCtx)
			end
			return realRect(obj)
		end,
			viewport(),
			{ unsupported = {} }
	end
	local ctx = { vp = vpSpec.Size, cache = {}, unsupported = {} }
	return function(obj)
		return simRect(obj, ctx)
	end, vpSpec.Size, ctx
end

-- A roll card's contract rect on the live viewport.
local function nominalOf(obj)
	return simRect(obj, { vp = viewport(), cache = {}, unsupported = {} })
end

local function sameRect(a, b)
	return math.abs(a.x - b.x) <= TOL
		and math.abs(a.y - b.y) <= TOL
		and math.abs(a.w - b.w) <= TOL
		and math.abs(a.h - b.h) <= TOL
end

-- Where a settled roll card differs from its contract rect: its live properties solved at every UiSpec viewport,
-- and the engine's rect on the live one. Empty when it sits exactly at the contract place everywhere.
local function liveVsNominal(obj)
	local bad = {}
	for _, vpSpec in UiSpec.Viewports do
		local vp = vpSpec.Size or viewport()
		local liveR = simRect(obj, { vp = vp, cache = {}, unsupported = {}, live = true })
		local nom = simRect(obj, { vp = vp, cache = {}, unsupported = {} })
		if not sameRect(liveR, nom) then
			table.insert(bad, vpSpec.Name .. " " .. rstr(liveR) .. " want " .. rstr(nom))
		end
	end
	local real, nom = realRect(obj), nominalOf(obj)
	if not sameRect(real, nom) then
		table.insert(bad, "engine " .. rstr(real) .. " want " .. rstr(nom))
	end
	return bad
end

-- The part of obj's rect that can be seen/clicked: cut by every ClipsDescendants ancestor (ScrollingFrames).
local function clipped(obj, rectOf)
	local r = rectOf(obj)
	local node = obj.Parent
	while r and node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and node.ClipsDescendants then
			r = intersection(r, rectOf(node))
		end
		node = node.Parent
	end
	return r
end

-- Where a label's text is actually drawn (TextService estimate), or nil when it draws nothing.
local function textRect(label, r)
	if label.Text == "" or label.TextTransparency >= 0.99 then
		return nil
	end
	if label.TextScaled then
		return r
	end
	local ok, size = pcall(function()
		return TextService:GetTextSize(
			label.Text,
			label.TextSize,
			label.Font,
			Vector2.new(label.TextWrapped and math.max(r.w, 1) or 100000, 100000)
		)
	end)
	if not ok then
		return r
	end
	local w, h = size.X, size.Y
	if label.TextWrapped or label.TextTruncate ~= Enum.TextTruncate.None then
		w = math.min(w, r.w)
	end
	local x, y = r.x, r.y
	if label.TextXAlignment == Enum.TextXAlignment.Center then
		x = r.x + (r.w - w) / 2
	elseif label.TextXAlignment == Enum.TextXAlignment.Right then
		x = r.x + r.w - w
	end
	if label.TextYAlignment == Enum.TextYAlignment.Center then
		y = r.y + (r.h - h) / 2
	elseif label.TextYAlignment == Enum.TextYAlignment.Bottom then
		y = r.y + r.h - h
	end
	return R(x, y, w, h)
end

-- GetGuiObjectsAtPosition takes the same space as AbsolutePosition of an inset-respecting ScreenGui.
local function hitsAt(sx, sy)
	local tl = inset()
	local ok, list = pcall(function()
		return playerGui:GetGuiObjectsAtPosition(sx - tl.X, sy - tl.Y)
	end)
	return ok and list or {}
end

---------------------------------------------------------------------------------------------------------------
-- Live state recorders (Init runs when the harness starts so events before the run are seen)

local events = {
	rolls = {},
	npcStart = nil,
	lastLose = nil,
	loses = {},
	turbos = {},
	rollsChanged = 0,
	recs = {}, -- one roll-animation record per RollResult (UiScenarios.SampleRoll)
	announces = {}, -- Remotes.RollAnnounce events
	chat = {}, -- TextChatService.MessageReceived
}

-- Topmost visible object at the centre of each always-on button, and whether it belongs to `gui`.
local function coversButtons(gui)
	local missed = {}
	for _, guiName in declaredGuis() do
		for _, p in UiSpec.Guis[guiName].AlwaysOn or {} do
			local b = findPath(guiName .. "/" .. p)
			if b and b:IsA("GuiButton") and effectivelyVisible(b) then
				local cx, cy = centre(realRect(b))
				local top = hitsAt(cx, cy)[1]
				if not (top and top:IsDescendantOf(gui)) then
					table.insert(missed, guiName .. "/" .. p .. " topmost=" .. (top and pathOf(top) or "nothing"))
				end
			end
		end
	end
	return missed
end

-- Samples the loser screen around a Result Lose: shown and on top shortly after it, hidden after the next
-- Reset / Start / Stop (UiSpec.Waits.LoserHideGrace later).
local function recordLose()
	local rec = { t = os.clock() }
	table.insert(events.loses, rec)
	task.wait(UiSpec.Waits.LoserShowGrace)
	local gui = playerGui:FindFirstChild("LoserScreen")
	rec.shown = gui ~= nil and gui.Enabled
	if gui then
		local highest, who = -math.huge, "none"
		for _, other in playerGui:GetChildren() do
			if
				other ~= gui
				and other:IsA("ScreenGui")
				and other.Enabled
				and not UiSpec.IgnoreGuis[other.Name]
				and other.DisplayOrder >= highest
			then
				highest, who = other.DisplayOrder, other.Name
			end
		end
		rec.order = gui.DisplayOrder
		rec.highestOther = ("%s (%s)"):format(tostring(highest), who)
		rec.onTop = gui.DisplayOrder > highest
		rec.coverMissed = coversButtons(gui)
	end
end

local function recordAfterLose(kind)
	local rec = events.loses[#events.loses]
	if not rec or rec.after then
		return
	end
	rec.after = kind
	task.wait(UiSpec.Waits.LoserHideGrace)
	local gui = playerGui:FindFirstChild("LoserScreen")
	rec.hiddenAfter = gui ~= nil and gui.Enabled == false
	rec.done = true
end

function UiScenarios.Init()
	if not legacyObserver then
		legacyObserver = UiLegacyControls.Observe({
			player = player,
			playerGui = playerGui,
			find = findPath,
			frames = frames,
			check = check,
			visible = effectivelyVisible,
			rect = realRect,
			centre = centre,
			hits = hitsAt,
		})
	end
	player:GetAttributeChangedSignal("Rolls"):Connect(function()
		events.rollsChanged = os.clock()
	end)
	pcall(function()
		TextChatService.MessageReceived:Connect(function(msg)
			table.insert(events.chat, {
				text = msg.Text,
				channel = msg.TextChannel and msg.TextChannel.Name or "",
				system = msg.TextSource == nil,
				t = os.clock(),
			})
		end)
	end)
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
		if not remotes then
			return
		end
		task.spawn(function()
			local roll = remotes:WaitForChild("RollResult", 30)
			if roll then
				roll.OnClientEvent:Connect(function(id, isNew, turboMulti, emphasized)
					local ev = {
						id = id,
						isNew = isNew,
						turboMulti = type(turboMulti) == "number" and turboMulti or 1,
						emphasized = emphasized == true,
						rolls = player:GetAttribute("Rolls"), -- set by the server before it fires RollResult
						t = os.clock(),
					}
					table.insert(events.rolls, ev)
					ev.n = #events.rolls
					if ev.turboMulti > 1 then
						task.spawn(UiScenarios.SampleTurbo, ev)
					end
					task.spawn(UiScenarios.SampleRoll, ev)
				end)
			end
		end)
		task.spawn(function()
			local ann = remotes:WaitForChild(UiSpec.Announce.Remote, 30)
			if ann and ann:IsA("RemoteEvent") then
				ann.OnClientEvent:Connect(function(userId, displayName, id, rolls)
					table.insert(events.announces, {
						userId = userId,
						displayName = displayName,
						id = id,
						rolls = rolls,
						t = os.clock(),
					})
				end)
			end
		end)
		task.spawn(function()
			local npc = remotes:WaitForChild("NpcRace", 30)
			if npc then
				npc.OnClientEvent:Connect(function(event)
					if type(event) ~= "table" then
						return
					end
					if event.Type == "Start" then
						events.npcStart = event
					end
					if event.Type == "Result" and event.Result == "Lose" then
						events.lastLose = os.clock()
						task.spawn(recordLose)
					elseif event.Type == "Reset" or event.Type == "Start" or event.Type == "Stop" then
						task.spawn(recordAfterLose, event.Type)
					end
				end)
			end
		end)
	end)
end

local function waitGuis()
	local deadline = os.clock() + UiSpec.Waits.GuiAppear
	for _, name in declaredGuis() do
		playerGui:WaitForChild(name, math.max(0.1, deadline - os.clock()))
	end
end

local function attr(name)
	return player:GetAttribute(name)
end

local function owned(id)
	local data = player:FindFirstChild("GachaData")
	return data ~= nil and data:FindFirstChild(id) ~= nil
end

local function digits(text)
	local s = string.gsub(text or "", "[^%d]", "")
	return tonumber(s)
end

local function hasNumber(text, n)
	return string.find(" " .. (text or "") .. " ", "%f[%d]" .. tostring(n) .. "%f[%D]") ~= nil
end

---------------------------------------------------------------------------------------------------------------
-- Turbo HUD helpers for RacerHud/Turbo.

local function turboEvery()
	local every = attr("TurboEvery")
	return type(every) == "number" and every >= 1 and every or (GachaConfig.TURBO_EVERY or 10)
end

local function turboLuck()
	local multi = attr("TurboMulti")
	return type(multi) == "number" and multi > 1 and multi
		or (type(GachaConfig.TURBO_LUCK) == "number" and GachaConfig.TURBO_LUCK or UiSpec.Turbo.FallbackMulti)
end

local function turboProgress(rolls)
	local count = attr("TurboCount")
	if type(count) == "number" then
		return math.max(0, math.floor(count))
	end
	if type(GachaConfig.TurboProgress) == "function" then
		return GachaConfig.TurboProgress(rolls)
	end
	return math.floor(rolls or 0) % turboEvery()
end

local function fmtNum(n)
	return ("%g"):format(n)
end

-- Every visible text inside obj (itself included), joined: a button may draw its label with child labels.
local function allText(obj)
	if not obj then
		return ""
	end
	local list = {}
	for _, o in { obj, table.unpack(obj:GetDescendants()) } do
		if o.Name ~= "PointsBadge" and (o:IsA("TextLabel") or o:IsA("TextButton")) and o.Text ~= "" and o.Visible then
			table.insert(list, o.Text)
		end
	end
	return table.concat(list, " ")
end

local function sameColour(a, b)
	return a ~= nil
		and b ~= nil
		and math.abs(a.R - b.R) < 0.01
		and math.abs(a.G - b.G) < 0.01
		and math.abs(a.B - b.B) < 0.01
end

-- TurboBar/Fill width as a fraction of TurboBar (a hidden Fill is an empty bar).
local function fillFraction()
	local bar = findPath(UiSpec.Hud.Turbo)
	local fill = findPath(UiSpec.Hud.TurboFill)
	if not (bar and fill and fill:IsA("GuiObject")) then
		return nil
	end
	local bw = realRect(bar).w
	if bw <= 0 then
		return nil
	end
	return effectivelyVisible(fill) and realRect(fill).w / bw or 0
end

-- TurboPop's text, whether it is clearly showing, and whether it is gone (hidden or fully transparent).
local function popState()
	local textObj = findPath(UiSpec.Hud.TurboLabel)
	if not (textObj and textObj:IsA("TextLabel")) then
		return nil, false, true
	end
	local visible = effectivelyVisible(textObj) and textObj.TextTransparency < 0.5
	local shown = visible and string.sub(textObj.Text, 1, 6) == "TURBO "
	local gone = not visible or string.sub(textObj.Text, 1, 11) == "TURBO LUCK "
	return textObj.Text, shown, gone
end

-- Samples the turbo animation around one turbo RollResult: TurboPop shown TurboPopShow s after it, hidden and
-- the bar back to TurboProgress (0) TurboPopHide s after it. Isolated = no other roll arrived meanwhile.
function UiScenarios.SampleTurbo(ev)
	local rec = { ev = ev }
	table.insert(events.turbos, rec)
	task.wait(UiSpec.Waits.TurboPopShow)
	rec.shownText, rec.shown = popState()
	task.wait(UiSpec.Waits.TurboPopHide - UiSpec.Waits.TurboPopShow)
	local _, _, gone = popState()
	rec.gone = gone
	rec.fill = fillFraction()
	rec.rolls = attr("Rolls")
	rec.isolated = true
	for _, other in events.rolls do
		if other ~= ev and other.t >= ev.t and other.t <= os.clock() then
			rec.isolated = false
		end
	end
	rec.done = true
end

---------------------------------------------------------------------------------------------------------------
-- Roll showcase helpers (RollShowcase, owner's revision of docs/SPAWN_AND_ROLLS_SPEC.md section 5)

local function showcaseParts()
	local gui = playerGui:FindFirstChild(UiSpec.Showcase.Gui)
	local backdrop = gui and gui:FindFirstChild(UiSpec.Showcase.Backdrop)
	local card = gui and gui:FindFirstChild(UiSpec.Showcase.Card, true)
	return gui, backdrop, card
end

-- "open": enabled, backdrop and card shown; "closed": neither shown; "partial" otherwise; "missing": no gui.
local function showcaseState()
	local gui, backdrop, card = showcaseParts()
	if not gui then
		return "missing"
	end
	local b = backdrop ~= nil and backdrop:IsA("GuiObject") and effectivelyVisible(backdrop)
	local c = card ~= nil and card:IsA("GuiObject") and effectivelyVisible(card)
	if b and c then
		return "open"
	elseif not b and not c then
		return "closed"
	end
	return "partial"
end

local function blurState()
	local blur = Lighting:FindFirstChild(UiSpec.Showcase.Blur)
	if not blur then
		return "missing"
	elseif not blur:IsA("BlurEffect") then
		return "not a BlurEffect: " .. blur.ClassName
	end
	return blur.Enabled and "enabled" or "disabled"
end

local function luminance(c)
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

-- A text in the rarity colour; Secret (near-black) must be readable instead (light text).
local function rarityColourProblem(label, rarity)
	if not label.TextColor3 then
		return nil
	end
	if rarity == "Secret" then
		local l = luminance(label.TextColor3)
		if l < UiSpec.Showcase.SecretMinLuminance then
			return ("%s Secret text not readable (luminance %.2f < %.2f)"):format(
				label.Name,
				l,
				UiSpec.Showcase.SecretMinLuminance
			)
		end
	elseif not sameColour(label.TextColor3, GachaConfig.RARITY_COLORS[rarity]) then
		return ("%s colour %s want %s"):format(label.Name, tostring(label.TextColor3), rarity)
	end
	return nil
end

-- What is wrong with a roll card (compact or enlarged) as the card for roll event `ev` once it has landed (empty
-- when it shows the roll's truth).
-- The enlarged card's content parts (UiSpec.Showcase.ContentParts) that are shown but not inside the card's rect.
local function contentOutside(card)
	local bad = {}
	local cardRect = realRect(card)
	for _, name in UiSpec.Showcase.ContentParts do
		local o = card:FindFirstChild(name, true)
		if o and o:IsA("GuiObject") and effectivelyVisible(o) and not contains(cardRect, realRect(o)) then
			table.insert(bad, name .. rstr(realRect(o)) .. " outside the card")
		end
	end
	return bad
end

-- The enlarged card's animated body (UiSpec.Showcase.Body) is back at 1x (within RollAnim.SettledTolerance of the
-- card's width): the LAND_POP has settled, so its parts' geometry is the resting one.
local function cardBodySettled(card)
	local gui = guiOf(card)
	local body = gui and findPath(gui.Name .. "/" .. UiSpec.Showcase.Body)
	if not (body and body:IsA("GuiObject")) or card.AbsoluteSize.X <= 0 then
		return true
	end
	return math.abs(body.AbsoluteSize.X / card.AbsoluteSize.X - 1) <= UiSpec.RollAnim.SettledTolerance
end

-- skipGeometry: leave out contentOutside (SampleRoll measures it once the body has settled from LAND_POP).
local function cardProblems(card, ev, skipGeometry)
	if not card then
		return { "no card" }
	end
	if not ev then
		return { "no RollResult received yet" }
	end
	local spec = CarCatalog.Get(ev.id)
	if not spec then
		return { "roll id " .. tostring(ev.id) .. " not in CarCatalog" }
	end
	local function part(name)
		return card:FindFirstChild(name, true)
	end
	local bad = skipGeometry and {} or contentOutside(card)
	local name = part("CarName")
	if not (name and name:IsA("TextLabel") and name.Text == spec.Name and effectivelyVisible(name)) then
		table.insert(bad, ("CarName %q want %q"):format(name and name.Text or "nil", spec.Name))
	end
	local rarity = part("Rarity")
	if not (rarity and rarity:IsA("TextLabel") and rarity.Text == spec.Rarity and effectivelyVisible(rarity)) then
		table.insert(bad, ("Rarity %q want %q"):format(rarity and rarity.Text or "nil", spec.Rarity))
	else
		local problem = rarityColourProblem(rarity, spec.Rarity)
		if problem then
			table.insert(bad, problem)
		end
	end
	local odds = part("Odds")
	local wantOdds = HudFormat.Odds(spec.Chance)
	if not (odds and odds:IsA("TextLabel") and odds.Text == wantOdds and effectivelyVisible(odds)) then
		table.insert(bad, ("Odds %q want %q"):format(odds and odds.Text or "nil", wantOdds))
	else
		local problem = rarityColourProblem(odds, spec.Rarity)
		if problem then
			table.insert(bad, problem)
		end
	end
	local multi = part("SpeedMulti")
	local m = spec.SpeedMulti or 1
	local wantMulti = fmtNum(m) .. "x Speed" -- contract: "25x Speed"
	if
		not (multi and multi:IsA("TextLabel") and (multi.Text == wantMulti or multi.Text == tostring(m) .. "x Speed"))
	then
		table.insert(bad, ("SpeedMulti %q want %q"):format(multi and multi.Text or "nil", wantMulti))
	end
	local newBadge = part("NewBadge")
	local isNew = ev.isNew == true
	if not newBadge then
		table.insert(bad, "no NewBadge")
	elseif effectivelyVisible(newBadge) ~= isNew then
		table.insert(bad, ("NewBadge shown=%s want %s"):format(tostring(effectivelyVisible(newBadge)), tostring(isNew)))
	end
	local turbo = part("TurboBadge")
	local isTurbo = ev.turboMulti > 1
	if not turbo then
		table.insert(bad, "no TurboBadge")
	elseif effectivelyVisible(turbo) ~= isTurbo then
		table.insert(
			bad,
			("TurboBadge shown=%s want %s"):format(tostring(effectivelyVisible(turbo)), tostring(isTurbo))
		)
	elseif isTurbo then
		local want = "TURBO x" .. fmtNum(ev.turboMulti)
		if not string.find(allText(turbo), want, 1, true) then
			table.insert(bad, ("TurboBadge %q want %q"):format(allText(turbo), want))
		end
	end
	local view = part("Viewport")
	if not (view and view:IsA("ViewportFrame")) then
		table.insert(bad, "no Viewport ViewportFrame")
	end
	local placeholder = part("Placeholder")
	if spec.Model == nil then
		if
			not (
				placeholder
				and placeholder:IsA("TextLabel")
				and placeholder.Text == "?"
				and effectivelyVisible(placeholder)
			)
		then
			table.insert(bad, 'no visible Placeholder "?" for a car without a model')
		end
	else
		local model = view and view:FindFirstChild(spec.Model, true)
		if not (model and model:IsA("Model")) then
			table.insert(bad, "Viewport lacks a clone of CarModels." .. tostring(spec.Model))
		end
		if placeholder and effectivelyVisible(placeholder) and placeholder.Text ~= "" then
			table.insert(bad, "Placeholder shown for a car with a model")
		end
	end
	return bad
end

local function showcaseCardProblems(ev)
	local _, _, card = showcaseParts()
	if not card then
		return { "no " .. UiSpec.Showcase.Card }
	end
	return cardProblems(card, ev)
end

-- The topmost click-taking, visible object at a screen point.
local function topAt(x, y)
	for _, h in hitsAt(x, y) do
		if h:IsA("GuiObject") and swallows(h) and effectivelyVisible(h) then
			return h
		end
	end
	return nil
end

-- Screen points to probe for stray clicks: the corners (CornerInset in), the centre and every AlwaysOn centre.
local function probePoints()
	local vp = viewport()
	local tl = inset()
	local ci = UiSpec.Showcase.CornerInset
	local pts = {
		{ "corner_tl", ci, tl.Y + ci },
		{ "corner_tr", vp.X - ci, tl.Y + ci },
		{ "corner_bl", ci, vp.Y - ci },
		{ "corner_br", vp.X - ci, vp.Y - ci },
		{ "centre", vp.X / 2, vp.Y / 2 },
	}
	for _, guiName in declaredGuis() do
		for _, p in UiSpec.Guis[guiName].AlwaysOn or {} do
			local o = findPath(guiName .. "/" .. p)
			if o and o:IsA("GuiObject") then
				local x, y = centre(realRect(o))
				table.insert(pts, { guiName .. "/" .. p, x, y })
			end
		end
	end
	return pts
end

-- Every visible AlwaysOn button is topmost at its own centre (nothing covers the normal view).
local function alwaysOnCovered()
	local bad = {}
	for _, guiName in declaredGuis() do
		for _, p in UiSpec.Guis[guiName].AlwaysOn or {} do
			local b = findPath(guiName .. "/" .. p)
			if b and b:IsA("GuiButton") and effectivelyVisible(b) then
				local top = topAt(centre(realRect(b)))
				if not (top and (top == b or b:IsAncestorOf(top))) then
					table.insert(bad, guiName .. "/" .. p .. " under " .. (top and pathOf(top) or "nothing"))
				end
			end
		end
	end
	return bad
end

-- Probe points where the showcase takes a click.
local function showcaseHits()
	local gui = playerGui:FindFirstChild(UiSpec.Showcase.Gui)
	local bad = {}
	if not gui then
		return bad
	end
	for _, pt in probePoints() do
		for _, h in hitsAt(pt[2], pt[3]) do
			if h:IsDescendantOf(gui) then
				table.insert(bad, pt[1] .. ": " .. pathOf(h))
				break
			end
		end
	end
	return bad
end

-- Waits for a moment HudSettle s after the last Rolls change / RollResult (the bar and label have settled).
local function waitRollsStable()
	local deadline = os.clock() + UiSpec.Waits.RollsStable
	while os.clock() < deadline do
		local last = events.rollsChanged
		local ev = events.rolls[#events.rolls]
		if ev and ev.t > last then
			last = ev.t
		end
		if os.clock() - last >= UiSpec.Waits.HudSettle then
			return true
		end
		task.wait(0.05)
	end
	return false
end

local function waitNewRoll(timeout)
	local before = #events.rolls
	local deadline = os.clock() + timeout
	while #events.rolls == before and os.clock() < deadline do
		task.wait(0.05)
	end
	return #events.rolls > before
end

---------------------------------------------------------------------------------------------------------------
-- Roll animation recorder (docs/ROLL_ANIMATION_CONTRACT.md). Every RollResult starts one: it samples both cards
-- each Heartbeat until the card that plays the roll is Idle again (or a newer roll arrives), then the view
-- SWITCH + SwitchGrace later.

local SETTLED = { Hold = true, Idle = true }

local function rarityOf(id)
	local spec = CarCatalog.Get(id)
	return spec and spec.Rarity or "Common"
end

local function rarityRank(rarity)
	return table.find(GachaConfig.RARITY_ORDER, rarity) or 1
end

local function rollCards()
	local toast = findPath("RollToast/Toast")
	local _, _, card = showcaseParts()
	return { Compact = toast, Enlarged = card }
end

local function viewNow()
	local gui = playerGui:FindFirstChild("RollToast")
	return gui and gui:GetAttribute(UiSpec.RollAnim.ViewAttr)
end

local function partOf(card, name)
	return card and card:FindFirstChild(name, true)
end

local function partShown(card, name)
	local p = partOf(card, name)
	return p ~= nil and p:IsA("GuiObject") and effectivelyVisible(p)
end

-- Draws something a player can see: itself or a visible descendant with an opaque-enough background, text or image.
local function drawsSomething(obj)
	for _, d in { obj, table.unpack(obj:GetDescendants()) } do
		if d:IsA("GuiObject") and effectivelyVisible(d) then
			if d.BackgroundTransparency < 0.5 then
				return true
			end
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.TextTransparency < 0.5 then
				return true
			end
			if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" and d.ImageTransparency < 0.5 then
				return true
			end
			if d:IsA("ViewportFrame") and d.ImageTransparency < 0.5 then
				return true
			end
		end
	end
	return false
end

-- The compact roll's element that grows / pops / shrinks: its transparent Body (the Toast keeps its rect).
local function compactBody(toast)
	local body = toast and toast:FindFirstChild(UiSpec.Compact.Body)
	return (body and body:IsA("GuiObject")) and body or toast
end

-- The compact roll's structure ("Compact = no card"): exactly the model parts, none of the card parts (they must
-- not exist at all), an invisible background, no frame or border stroke.
local function compactShapeProblems(toast)
	if not toast then
		return { "no RollToast/Toast" }
	end
	local bad = {}
	for _, name in UiSpec.Compact.Parts do
		if not toast:FindFirstChild(name, true) then
			table.insert(bad, "no " .. name)
		end
	end
	local view = toast:FindFirstChild("Viewport", true)
	if view and not view:IsA("ViewportFrame") then
		table.insert(bad, "Viewport is " .. view.ClassName .. ", want ViewportFrame")
	end
	for _, name in UiSpec.Compact.Forbidden do
		local o = toast:FindFirstChild(name, true)
		if o then
			table.insert(bad, pathOf(o) .. " exists (compact = no card)")
		end
	end
	if toast.BackgroundTransparency < 0.99 then
		table.insert(
			bad,
			("Toast background visible (BackgroundTransparency %.2f)"):format(toast.BackgroundTransparency)
		)
	end
	local body = toast:FindFirstChild(UiSpec.Compact.Body)
	if body and body:IsA("GuiObject") and body.BackgroundTransparency < 0.99 then
		table.insert(bad, ("Body not transparent (BackgroundTransparency %.2f)"):format(body.BackgroundTransparency))
	end
	for _, holder in { toast, body } do
		local stroke = holder and holder:FindFirstChildWhichIsA("UIStroke")
		if stroke and stroke.Enabled and stroke.Transparency < 0.99 then
			table.insert(bad, pathOf(stroke) .. " draws a frame")
		end
	end
	return bad
end

-- The landed compact roll shows the roll's truth: its odds (rarity-coloured, italic) under the bare model ("?" for a
-- car without a model), both inside the rect, and a Reel that clips its cars.
local function compactProblems(toast, ev)
	if not toast then
		return { "no RollToast/Toast" }
	end
	local spec = ev and CarCatalog.Get(ev.id)
	if not spec then
		return { "roll id " .. tostring(ev and ev.id) .. " not in CarCatalog" }
	end
	local bad = {}
	local tr = realRect(toast)
	local odds = toast:FindFirstChild("Odds", true)
	local wantOdds = HudFormat.Odds(spec.Chance)
	if not (odds and odds:IsA("TextLabel") and odds.Text == wantOdds and effectivelyVisible(odds)) then
		table.insert(bad, ("Odds %q want %q"):format(odds and odds:IsA("TextLabel") and odds.Text or "nil", wantOdds))
	else
		local problem = rarityColourProblem(odds, spec.Rarity)
		if problem then
			table.insert(bad, problem)
		end
		if odds.FontFace.Style ~= Enum.FontStyle.Italic then
			table.insert(bad, "Odds not italic")
		end
	end
	local view = toast:FindFirstChild("Viewport", true)
	if not (view and view:IsA("ViewportFrame") and effectivelyVisible(view)) then
		table.insert(bad, "no visible Viewport ViewportFrame")
	end
	local placeholder = toast:FindFirstChild("Placeholder", true)
	if spec.Model == nil then
		if
			not (
				placeholder
				and placeholder:IsA("TextLabel")
				and placeholder.Text == "?"
				and effectivelyVisible(placeholder)
			)
		then
			table.insert(bad, 'no visible Placeholder "?" for a car without a model')
		end
	else
		local model = view and view:FindFirstChild(spec.Model, true)
		if not (model and model:IsA("Model")) then
			table.insert(bad, "Viewport lacks a clone of CarModels." .. tostring(spec.Model))
		end
		if placeholder and effectivelyVisible(placeholder) and placeholder.Text ~= "" then
			table.insert(bad, "Placeholder shown for a car with a model")
		end
	end
	for _, o in { view, odds } do
		if o and o:IsA("GuiObject") and effectivelyVisible(o) and not contains(tr, realRect(o)) then
			table.insert(bad, o.Name .. rstr(realRect(o)) .. " outside the rect " .. rstr(tr))
		end
	end
	local reel = toast:FindFirstChild("Reel", true)
	if not (reel and reel:IsA("GuiObject") and reel.ClipsDescendants) then
		table.insert(bad, "Reel does not clip its cars (ClipsDescendants)")
	end
	return bad
end

-- At 1x (Hold): Body fills the rect, the model fills the top ModelShare of it and the odds the rest.
local function compactLayoutProblems(toast)
	if not toast then
		return { "no RollToast/Toast" }
	end
	local bad = {}
	local tr = realRect(toast)
	local tol = UiSpec.Compact.SplitTolerance * tr.h
	local body = toast:FindFirstChild(UiSpec.Compact.Body)
	if body and body:IsA("GuiObject") then
		local br = realRect(body)
		if not sameRect(br, tr) then
			table.insert(bad, "Body" .. rstr(br) .. " does not fill " .. rstr(tr))
		end
	end
	local split = tr.y + UiSpec.Compact.ModelShare * tr.h
	local function edges(name, top, bottom)
		local o = toast:FindFirstChild(name, true)
		if not (o and o:IsA("GuiObject")) then
			table.insert(bad, "no " .. name)
			return
		end
		local r = realRect(o)
		if math.abs(r.y - top) > tol or math.abs(r.y + r.h - bottom) > tol then
			table.insert(
				bad,
				("%s spans y %d..%d, want %d..%d (+- %d)"):format(
					name,
					math.floor(r.y + 0.5),
					math.floor(r.y + r.h + 0.5),
					math.floor(top + 0.5),
					math.floor(bottom + 0.5),
					math.floor(tol + 0.5)
				)
			)
		end
	end
	edges("Viewport", tr.y, split)
	edges("Odds", split, tr.y + tr.h)
	return bad
end

local function glowGradient(card)
	local glow = partOf(card, "Glow")
	if not glow then
		return nil
	end
	return glow:IsA("UIGradient") and glow or glow:FindFirstChildWhichIsA("UIGradient", true)
end

-- The look of a landed card: italic Odds, bold CarName with a dark UIStroke outline, a Glow with a UIGradient in
-- the rarity colour, a Reel that clips its cars.
local function styleProblems(card, spec)
	local bad = {}
	local odds = partOf(card, "Odds")
	if not (odds and odds:IsA("TextLabel") and odds.FontFace.Style == Enum.FontStyle.Italic) then
		table.insert(bad, "Odds not italic")
	end
	local name = partOf(card, "CarName")
	if not (name and name:IsA("TextLabel") and name.FontFace.Weight.Value >= Enum.FontWeight.Bold.Value) then
		table.insert(bad, "CarName not bold")
	end
	local stroke = name and name:FindFirstChildWhichIsA("UIStroke")
	if
		not (
			stroke
			and stroke.Transparency < 0.5
			and luminance(stroke.Color) <= UiSpec.Showcase.CarNameStrokeMaxLuminance
		)
	then
		table.insert(bad, "CarName has no dark UIStroke outline")
	end
	local glow = partOf(card, "Glow")
	if not glowGradient(card) then
		table.insert(bad, "Glow has no UIGradient")
	end
	local colour = GachaConfig.RARITY_COLORS[spec.Rarity]
	local found = false
	if glow then
		for _, o in { glow, table.unpack(glow:GetDescendants()) } do
			local colours = {}
			if o:IsA("GuiObject") and o.BackgroundTransparency < 1 then
				table.insert(colours, o.BackgroundColor3)
			end
			if o:IsA("ImageLabel") or o:IsA("ImageButton") then
				table.insert(colours, o.ImageColor3)
			end
			if o:IsA("UIStroke") then
				table.insert(colours, o.Color)
			end
			if o:IsA("UIGradient") then
				for _, k in o.Color.Keypoints do
					table.insert(colours, k.Value)
				end
			end
			for _, c in colours do
				found = found or sameColour(c, colour)
			end
		end
	end
	if not found then
		table.insert(bad, "Glow not in the " .. spec.Rarity .. " colour")
	end
	local reel = partOf(card, "Reel")
	if not (reel and reel:IsA("GuiObject") and reel.ClipsDescendants) then
		table.insert(bad, "Reel does not clip its cars (ClipsDescendants)")
	end
	return bad
end

-- Rarity effects at landing: Ring only from Epic, Burst only from Legendary (Legendary and Mythic must show it),
-- the full-screen Takeover only for Secret. Whether Legendary+ also shows the Ring is not specified: not tested.
local function effectProblems(card, spec)
	local bad = {}
	local r = rarityRank(spec.Rarity)
	local ring, burst = partShown(card, "Ring"), partShown(card, "Burst")
	if r < rarityRank("Epic") and ring then
		table.insert(bad, "Ring shown on a " .. spec.Rarity .. " roll")
	end
	if spec.Rarity == "Epic" and not ring then
		table.insert(bad, "no Ring on an Epic roll")
	end
	if r < rarityRank("Legendary") and burst then
		table.insert(bad, "Burst shown on a " .. spec.Rarity .. " roll")
	end
	if (spec.Rarity == "Legendary" or spec.Rarity == "Mythic") and not burst then
		table.insert(bad, "no Burst on a " .. spec.Rarity .. " roll")
	end
	local sgui = playerGui:FindFirstChild(UiSpec.Showcase.Gui)
	local takeover = sgui and sgui:FindFirstChild(UiSpec.Showcase.Takeover, true)
	local shown = takeover ~= nil and takeover:IsA("GuiObject") and effectivelyVisible(takeover)
	if spec.Rarity ~= "Secret" and shown then
		table.insert(bad, "Takeover shown on a " .. spec.Rarity .. " roll")
	end
	if spec.Rarity == "Secret" and not shown then
		table.insert(bad, "no Takeover on a Secret roll")
	end
	return bad
end

local function findFly()
	for _, name in declaredGuis() do
		local gui = playerGui:FindFirstChild(name)
		local f = gui and gui:FindFirstChild(UiSpec.RollAnim.FlyIcon, true)
		if f and f:IsA("GuiObject") then
			return f
		end
	end
	return nil
end

local function takesClicks(obj)
	for _, d in { obj, table.unpack(obj:GetDescendants()) } do
		if d:IsA("GuiObject") and swallows(d) then
			return true
		end
	end
	return false
end

local function distToRect(x, y, r)
	local dx = math.max(r.x - x, 0, x - (r.x + r.w))
	local dy = math.max(r.y - y, 0, y - (r.y + r.h))
	return math.sqrt(dx * dx + dy * dy)
end

function UiScenarios.SampleRoll(ev)
	local rec = {
		ev = ev,
		phases = { Compact = {}, Enlarged = {} }, -- { phase, t } on every Phase change
		seen = { Compact = {}, Enlarged = {} },
		ratios = {}, -- the playing card's width / its contract width, every frame it is not Idle
		spin = {}, -- per card, sampled on entering Spin (turbo badge from pop-in, reel)
		hold = {}, -- per card, sampled on entering Hold (landed: the roll's truth, 1x)
		fly = {}, -- FlyIcon samples from Exit on
		views = {},
		viewAtStart = viewNow(),
	}
	-- The card that plays it: the enlarged one for an emphasized roll or while the player has it open
	rec.playKey = (ev.emphasized or rec.viewAtStart == "Enlarged") and "Enlarged" or "Compact"
	table.insert(events.recs, rec)
	local limit = ev.t + durationFor(rarityOf(ev.id), ev.emphasized) + 3
	local last, lastView, holdAt, nominalW = {}, nil, {}, {}
	local function sampleFly(now)
		local fly = findFly()
		if fly and effectivelyVisible(fly) then
			local x, y = centre(realRect(fly))
			table.insert(rec.fly, { t = now, x = x, y = y, text = allText(fly), clicks = takesClicks(fly) })
			return true
		end
		return false
	end
	while os.clock() < limit do
		if events.rolls[#events.rolls] ~= ev then
			rec.interruptedAt = os.clock()
			break
		end
		local now = os.clock()
		local view = viewNow()
		if view ~= lastView then
			table.insert(rec.views, { view = tostring(view), t = now })
			lastView = view
		end
		for key, card in rollCards() do
			local phase = card:GetAttribute("Phase")
			if phase ~= last[key] then
				last[key] = phase
				table.insert(rec.phases[key], { phase = tostring(phase), t = now })
				rec.seen[key][tostring(phase)] = true
				if phase == "Spin" and not rec.spin[key] then
					local badge, reel = partOf(card, "TurboBadge"), partOf(card, "Reel")
					rec.spin[key] = {
						badge = partShown(card, "TurboBadge"),
						badgeText = badge and allText(badge) or "",
						flames = partShown(card, "TurboFlames"),
						reelIds = reel and reel:GetAttribute("ReelIds"),
						view = view,
					}
				elseif phase == "Hold" and not rec.hold[key] then
					holdAt[key] = now
					local spec = CarCatalog.Get(ev.id)
					local toast = findPath("RollToast/Toast")
					local reel = partOf(card, "Reel")
					local grad = glowGradient(card)
					local compact = key == "Compact"
					rec.hold[key] = {
						rollId = card:GetAttribute("RollId"),
						serial = card:GetAttribute("RollSerial"),
						reelIds = reel and reel:GetAttribute("ReelIds"),
						-- The compact roll is only the model and its odds; the card checks apply to the enlarged card
						-- The enlarged card enters Hold still popped (LAND_POP settles early in Hold): its content-inside
						-- -the-card geometry is added once the body is back at 1x (geomPending below)
						problems = compact and compactProblems(card, ev)
							or (spec and cardProblems(card, ev, true) or { "roll id not in CarCatalog" }),
						geomPending = not compact and spec ~= nil,
						styles = (not compact and spec) and styleProblems(card, spec) or {},
						effects = (not compact and spec) and effectProblems(card, spec) or {},
						shape = compact and compactShapeProblems(card) or nil,
						layout = compact and compactLayoutProblems(card) or nil,
						autoOffShown = compact and partShown(card, UiSpec.Compact.AutoOff),
						glowRot = grad and grad.Rotation or false,
						view = view,
						showcase = showcaseState(),
						blur = blurState(),
						toastShown = toast ~= nil and effectivelyVisible(toast),
						real = realRect(card),
						nominal = nominalOf(card),
						live = key == "Compact" and liveVsNominal(card) or nil,
					}
				end
			end
			if key == rec.playKey and phase ~= nil and phase ~= "Idle" then
				nominalW[key] = nominalW[key] or math.max(nominalOf(card).w, 1)
				-- The compact roll grows / pops / shrinks on its Body; the enlarged card on itself
				local scaled = key == "Compact" and compactBody(card) or card
				table.insert(
					rec.ratios,
					{ phase = tostring(phase), r = scaled.AbsoluteSize.X / nominalW[key], t = now }
				)
			end
			local h = rec.hold[key]
			-- Settled (or leaving Hold, the latest resting moment: the enlarged card does not shrink on Exit)
			if h and h.geomPending and (phase ~= "Hold" or cardBodySettled(card)) then
				h.geomPending = false
				h.geomPhase = tostring(phase)
				for _, problem in contentOutside(card) do
					table.insert(h.problems, problem)
				end
			end
			if phase == "Hold" and h and h.glowRot2 == nil and now - holdAt[key] >= UiSpec.RollAnim.GlowTurnWait then
				local grad = glowGradient(card)
				h.glowRot2 = grad and grad.Rotation or false
			end
			if
				key == rec.playKey
				and (phase == "Land" or (phase == "Hold" and now - (holdAt[key] or now) < 0.25))
				and partShown(card, "Smoke")
			then
				rec.smoke = true
			end
		end
		local seen = rec.seen[rec.playKey]
		if seen.Exit then
			sampleFly(now)
			if last[rec.playKey] == "Idle" then
				rec.idleAt = now
				break
			end
		end
		RunService.Heartbeat:Wait()
	end
	if rec.idleAt then
		local untilT = rec.idleAt + animNum("SWITCH") + UiSpec.RollAnim.SwitchGrace
		local flyShown = false
		while os.clock() < untilT and events.rolls[#events.rolls] == ev do
			RunService.Heartbeat:Wait()
			flyShown = sampleFly(os.clock())
		end
		local toast = findPath("RollToast/Toast")
		rec.after = {
			complete = events.rolls[#events.rolls] == ev,
			view = viewNow(),
			showcase = showcaseState(),
			blur = blurState(),
			toastShown = toast ~= nil and effectivelyVisible(toast),
			flyShown = flyShown,
		}
	end
	rec.done = true
end

-- An enlarged Hold sample's problems once its settled geometry is in (SampleRoll adds contentOutside when the body
-- is back at 1x, at the latest when Hold ends). A sample whose geometry never got measured reports that.
local function settledProblems(rec, hold)
	local deadline = os.clock() + holdFor("Secret") + 2
	while hold.geomPending and not rec.done and os.clock() < deadline do
		task.wait(0.05)
	end
	if hold.geomPending then
		local list = table.clone(hold.problems)
		table.insert(list, "card geometry not measured (no settled Hold frame)")
		return list
	end
	return hold.problems
end

local function recFor(ev)
	for i = #events.recs, 1, -1 do
		if events.recs[i].ev == ev then
			return events.recs[i]
		end
	end
	return nil
end

-- The phases of the playing card from its first PopIn up to the next Idle.
local function phaseSeq(rec, key)
	local out, started = {}, false
	for _, p in rec.phases[key] do
		started = started or p.phase == "PopIn"
		if started then
			table.insert(out, p)
			if p.phase == "Idle" then
				break
			end
		end
	end
	return out
end

local function seqNames(seq)
	local names = {}
	for _, p in seq do
		table.insert(names, p.phase)
	end
	return table.concat(names, ",")
end

-- The enlarged card's look on a landed roll: style, rarity effects and the slowly turning Glow gradient.
local function enlargedLookChecks(res, prefix, hold)
	checkList(res, prefix .. "card_style", hold.styles)
	checkList(res, prefix .. "rarity_effects_match", hold.effects)
	local r1, r2 = hold.glowRot, hold.glowRot2
	local turned = type(r1) == "number" and type(r2) == "number" and math.abs(r2 - r1) >= UiSpec.RollAnim.GlowTurnMin
	check(
		res,
		prefix .. "glow_gradient_turns",
		("%s -> %s"):format(tostring(r1), tostring(r2)),
		("changes >= %g deg in %.1f s"):format(UiSpec.RollAnim.GlowTurnMin, UiSpec.RollAnim.GlowTurnWait),
		turned
	)
end

-- PopIn -> Spin -> Land -> Hold -> Exit -> Idle, each phase as long as RollAnimConfig says (+- PhaseTolerance).
local function phaseChecks(res, rec, key, prefix)
	local seq = phaseSeq(rec, key)
	local names = seqNames(seq)
	local want = table.concat(UiSpec.RollAnim.Phases, ",")
	check(res, prefix .. "phase_sequence", names == "" and "none" or names, want, names == want)
	if names ~= want then
		return false
	end
	local delay = seq[1].t - rec.ev.t
	local maxDelay = UiSpec.RollAnim.PhaseStart + (rec.ev.emphasized and animNum("SWITCH") or 0)
	check(res, prefix .. "phase_starts_after_roll", delay, "<= " .. maxDelay, delay <= maxDelay)
	local rarity = rarityOf(rec.ev.id)
	local wants = { animNum("POP"), animNum("SPIN"), animNum("LAND"), holdFor(rarity), animNum("EXIT") }
	local tol = UiSpec.RollAnim.PhaseTolerance
	for i = 1, 5 do
		local d = seq[i + 1].t - seq[i].t
		local name = prefix .. "phase_" .. string.lower(seq[i].phase) .. "_seconds"
		local limit = ("%.2f +- %.2f%s"):format(wants[i], tol, seq[i].phase == "Hold" and (" (" .. rarity .. ")") or "")
		check(res, name, d, limit, math.abs(d - wants[i]) <= tol)
	end
	return true
end

-- Waits until the card's Phase is one of `wanted` for two frames running (geometry settled). False on timeout.
local function waitCardPhase(card, wanted, timeout)
	local deadline = os.clock() + timeout
	while card and os.clock() < deadline do
		if wanted[card:GetAttribute("Phase")] then
			RunService.Heartbeat:Wait()
			if wanted[card:GetAttribute("Phase")] then
				return true
			end
		end
		RunService.Heartbeat:Wait()
	end
	return false
end

---------------------------------------------------------------------------------------------------------------
-- Element sets per panel state

-- True when UiSpec.HiddenWhilePanelOpen hides the AlwaysOn element `path` while the panels in `open` are open.
local function hiddenByPanel(path, open)
	local rule = UiSpec.HiddenWhilePanelOpen[path]
	if not rule then
		return false
	end
	local except = string.match(rule, "^other_than:(.+)$")
	for _, p in open do
		if rule == "any" or (except and p ~= except) then
			return true
		end
	end
	return false
end

-- Every element that is interactive or always on in the given state: AlwaysOn elements (minus the ones declared hidden
-- while that panel is open, UiSpec.HiddenWhilePanelOpen: ui_panels / ui_toast prove they really are hidden then), the
-- open panels and every button inside an open panel (buttons that only show in some data state, e.g. Equip on an
-- undiscovered tile, are included: they WILL be shown, so their place must already be free). At rest the compact
-- roll's rect is reserved even between rolls.
local function elementsFor(open)
	local list = {}
	for _, guiName in declaredGuis() do
		local g = UiSpec.Guis[guiName]
		for _, p in g.AlwaysOn or {} do
			local obj = findPath(guiName .. "/" .. p)
			if obj and not hiddenByPanel(guiName .. "/" .. p, open) then
				table.insert(list, { path = guiName .. "/" .. p, obj = obj })
			end
		end
	end
	for _, p in open do
		local panel = findPath(p)
		if panel then
			table.insert(list, { path = p, obj = panel, panel = true })
			for _, b in buttonsIn(panel) do
				table.insert(list, { path = pathOf(b), obj = b })
			end
		end
	end
	return list
end

local function underPath(path, root)
	return path == root or string.sub(path, 1, #root + 1) == root .. "/"
end

-- UiSpec.PanelCoversReadouts: the PanelSwitch panel and the read-out an element pair belongs to, or nil.
local function panelReadoutPair(a, b)
	for panelPath in UiSpec.PanelSwitch.Names do
		for _, readout in UiSpec.PanelCoversReadouts.Readouts do
			if underPath(a, panelPath) and underPath(b, readout) then
				return panelPath, readout
			elseif underPath(b, panelPath) and underPath(a, readout) then
				return panelPath, readout
			end
		end
	end
	return nil
end

-- nil when the panel draws over the read-out across the whole region (UiSpec.PanelCoversReadouts), else why not.
local function panelCoverProblem(panelPath, readoutPath, region, rectOf)
	local cfg = UiSpec.PanelCoversReadouts
	local panel, readout = findPath(panelPath), findPath(readoutPath)
	if not (panel and readout) then
		return "missing panel or read-out"
	end
	local pg, rg = guiOf(panel), guiOf(readout)
	if not (pg and rg and pg:IsA("ScreenGui") and rg:IsA("ScreenGui")) then
		return "not in ScreenGuis"
	end
	if pg.DisplayOrder <= rg.DisplayOrder then
		return ("panel DisplayOrder %d <= read-out %d"):format(pg.DisplayOrder, rg.DisplayOrder)
	end
	local surface = panel:FindFirstChild(cfg.Surface) or panel
	if not (surface:IsA("GuiObject") and effectivelyVisible(surface)) then
		return "panel surface not shown"
	end
	if surface.BackgroundTransparency > cfg.MaxSurfaceTransparency then
		return ("panel surface BackgroundTransparency %.2f > %.2f"):format(
			surface.BackgroundTransparency,
			cfg.MaxSurfaceTransparency
		)
	end
	local node = surface
	while node and not node:IsA("LayerCollector") do
		if node:IsA("CanvasGroup") and node.GroupTransparency > cfg.MaxSurfaceTransparency then
			return "panel faded by CanvasGroup " .. pathOf(node)
		end
		node = node.Parent
	end
	local sr = clipped(surface, rectOf)
	if not (sr and region and contains(sr, region)) then
		return "overlap " .. (region and rstr(region) or "?") .. " outside the opaque panel surface"
	end
	return nil
end

-- a, b: element paths; ra, rb: their (clipped) rects; rectOf: the viewport's rect provider. Returns allowed, why-not.
local function overlapAllowed(a, b, ra, rb, rectOf)
	local panelPath, readout = panelReadoutPair(a, b)
	if panelPath then
		local problem = panelCoverProblem(panelPath, readout, ra and rb and intersection(ra, rb), rectOf)
		return problem == nil, problem
	end
	for _, pair in UiSpec.AllowOverlap do
		if (pair[1] == a and pair[2] == b) or (pair[1] == b and pair[2] == a) then
			return true
		end
	end
	return false
end

local function buttonsOf(elements)
	local list = {}
	for _, e in elements do
		if e.obj:IsA("GuiButton") then
			table.insert(list, e)
		end
	end
	return list
end

---------------------------------------------------------------------------------------------------------------
-- Scenarios

local S = {}

function S.ui_legacy_controls(res)
	if not legacyObserver then
		UiScenarios.Init()
	end
	legacyObserver.Run(res, false)
end

function S.ui_legacy_controls_resize(res)
	if not legacyObserver then
		UiScenarios.Init()
	end
	legacyObserver.Run(res, true)
end

-- The client must be rendering for any geometry or label check to mean anything: count RenderStepped frames
-- during 1 s of Heartbeat time.
function S.ui_client_rendering(res)
	local count = 0
	local conn = RunService.RenderStepped:Connect(function()
		count += 1
	end)
	local deadline = os.clock() + 1
	while os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	conn:Disconnect()
	if count >= 1 then
		notRendering = false
	end
	check(res, "client_rendering", count, ">= 1", count >= 1)
end

function S.ui_inventory(res)
	waitGuis()
	for _, name in declaredGuis() do
		local gui = playerGui:FindFirstChild(name)
		check(res, "gui_exists_" .. name, gui ~= nil, true, gui ~= nil and gui:IsA("ScreenGui"))
		if gui and gui:IsA("ScreenGui") then
			-- The UI scripts live in PlayerScripts and build their ScreenGui once: a reset would delete it for good
			check(res, "gui_survives_respawn_" .. name, gui.ResetOnSpawn, false, gui.ResetOnSpawn == false)
		end
	end
	local unknown = {}
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("LayerCollector") and not UiSpec.Guis[gui.Name] and not UiSpec.IgnoreGuis[gui.Name] then
			table.insert(unknown, gui.Name)
		end
	end
	checkList(res, "every_screengui_in_spec", unknown)
	-- Client scripts without a ScreenGui (UiSpec.ClientScripts), e.g. Client/RollAnnounce
	local folder = script.Parent.Parent
	for _, name in UiSpec.ClientScripts do
		local s = folder:FindFirstChild(name)
		check(
			res,
			"client_script_present_" .. name,
			s and s.ClassName or "missing",
			"LocalScript",
			s ~= nil and s:IsA("LocalScript")
		)
	end

	-- Every GuiButton is declared, and every declared button exists the expected number of times
	local counts, undeclared = {}, {}
	for _, b in allButtons() do
		local path = pathOf(b)
		local guiName = splitPath(path)[1]
		local rel = string.sub(path, #guiName + 2)
		-- RacerHud keeps the generated legacy RollControls subtree for compatibility with
		-- the UI asset, but it is not part of the live Racer UI inventory.
		local isLegacyRollControl = guiName == "RacerHud" and string.match(rel, "^RollControls/") ~= nil
		local matched = false
		for i, spec in UiSpec.Guis[guiName].Buttons or {} do
			if pathMatches(spec.Path, rel) then
				local key = guiName .. "#" .. i
				counts[key] = (counts[key] or 0) + 1
				matched = true
				break
			end
		end
		-- The generated HUD retains a hidden legacy RollControls subtree. It must stay hidden and is
		-- checked by ui_hitboxes, but it is not part of the live inventory.
		if not matched and not isLegacyRollControl and effectivelyVisible(b) then
			table.insert(undeclared, path)
		end
	end
	checkList(res, "every_button_in_spec", undeclared)
	for _, guiName in declaredGuis() do
		for i, spec in UiSpec.Guis[guiName].Buttons or {} do
			local want = 1
			if spec.Count == "catalog" then
				want = #CarCatalog.All()
			elseif spec.Count == "stats" then
				want = #GachaConfig.STATS
			elseif spec.Count == "upgrades" then
				want = #UpgradeTree.Tiles()
			end
			local got = counts[guiName .. "#" .. i] or 0
			check(res, "button_count_" .. guiName .. "/" .. spec.Path, got, want, got == want)
		end
	end

	-- Every declared button has a click in UiSpec.Clicks (each stat row and at least one tile)
	local missing = {}
	for _, guiName in declaredGuis() do
		for _, spec in UiSpec.Guis[guiName].Buttons or {} do
			if spec.Count == "stats" then
				for _, stat in GachaConfig.STATS do
					local path = string.gsub(spec.Path, "%*", stat)
					local found = false
					for _, c in UiSpec.Clicks do
						found = found or (c.Gui == guiName and c.Path == path)
					end
					if not found then
						table.insert(missing, guiName .. "/" .. path)
					end
				end
			else
				local found = false
				for _, c in UiSpec.Clicks do
					found = found or (c.Gui == guiName and pathMatches(spec.Path, c.Path))
				end
				if not found then
					table.insert(missing, guiName .. "/" .. spec.Path)
				end
			end
		end
	end
	checkList(res, "every_button_has_a_click", missing)

	for _, guiName in declaredGuis() do
		local g = UiSpec.Guis[guiName]
		local gui = playerGui:FindFirstChild(guiName)
		if g.NonInteractive and gui then
			local bad = {}
			for _, d in gui:GetDescendants() do
				if d:IsA("GuiObject") and swallows(d) then
					table.insert(bad, pathOf(d))
				end
			end
			checkList(res, "non_interactive_" .. guiName, bad)
		end
		for _, partName in g.NonInteractiveParts or {} do
			local bad = {}
			local part = gui and gui:FindFirstChild(partName, true)
			if not part then
				table.insert(bad, guiName .. ": no " .. partName)
			else
				for _, d in { part, table.unpack(part:GetDescendants()) } do
					if d:IsA("GuiObject") and swallows(d) then
						table.insert(bad, pathOf(d))
					end
				end
			end
			checkList(res, "non_interactive_" .. guiName .. "_" .. partName, bad)
		end
	end
end

-- The enlarged view's AUTO button and hint at one viewport (contract): RollShowcase/AutoButton at least MinSize,
-- bottom centre with its bottom edge BottomGap px above the screen bottom, above the Hint, clear of the card; the Hint
-- clear of the card; the backdrop click points (corner, INDEX button) off the AUTO button and the card. (AUTO button /
-- hint vs the TURBO LUCK bar is retired, owner decision 2026-10-08: the HUD and its bar are hidden while the view is
-- open, which hud_hidden_while_showcase_open checks.)
local function showcaseAutoButtonLayout(res, vpName, sim, vp, sgui, backdrop, cardRect)
	local cfg = UiSpec.Showcase.AutoButton
	local auto = sgui:FindFirstChild(cfg.Path)
	local hint = backdrop:FindFirstChild(UiSpec.Showcase.Hint)
	if not (auto and auto:IsA("GuiObject")) then
		check(res, "showcase_autobutton_present_" .. vpName, "missing", "RollShowcase/" .. cfg.Path, false)
		return
	end
	local ar = sim(auto)
	local root = rootRect(sgui, vp)
	local full = R(0, 0, vp.X, vp.Y)
	check(
		res,
		"autobutton_min_size_" .. vpName,
		("%dx%d"):format(math.floor(ar.w + 0.5), math.floor(ar.h + 0.5)),
		(">= %dx%d"):format(cfg.MinSize.X, cfg.MinSize.Y),
		ar.w >= cfg.MinSize.X - TOL and ar.h >= cfg.MinSize.Y - TOL
	)
	local cx = centre(ar)
	local midX = root.x + root.w / 2
	check(res, "autobutton_bottom_centre_x_" .. vpName, cx, midX, math.abs(cx - midX) <= TOL)
	local gap = full.y + full.h - (ar.y + ar.h)
	check(res, "autobutton_bottom_gap_" .. vpName, gap, cfg.BottomGap, math.abs(gap - cfg.BottomGap) <= TOL)
	check(res, "autobutton_inside_viewport_" .. vpName, rstr(ar), rstr(full), contains(full, ar))
	check(
		res,
		"autobutton_clear_of_card_" .. vpName,
		rstr(ar),
		"no overlap " .. rstr(cardRect),
		not intersects(ar, cardRect)
	)
	if hint and hint:IsA("GuiObject") then
		local hr = sim(hint)
		check(res, "autobutton_above_hint_" .. vpName, ar.y + ar.h, "<= " .. hr.y, ar.y + ar.h <= hr.y + TOL)
		check(
			res,
			"hint_clear_of_card_" .. vpName,
			rstr(hr),
			"no overlap " .. rstr(cardRect),
			not intersects(hr, cardRect)
		)
		check(res, "hint_inside_viewport_" .. vpName, rstr(hr), rstr(full), contains(full, hr))
	else
		check(res, "showcase_hint_present_" .. vpName, "missing", "Backdrop/" .. UiSpec.Showcase.Hint, false)
	end
	-- The backdrop clicks of UiSpec.Clicks must land on the backdrop: off the AUTO button (and off the card)
	local ci = UiSpec.Showcase.CornerInset
	local function inside(r, x, y)
		return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
	end
	local onAuto = inside(ar, vp.X - ci, vp.Y - ci)
	check(res, "showcase_corner_off_autobutton_" .. vpName, onAuto, false, not onAuto)
	-- The INDEX click point (showcase_backdrop_over_index_button) must not reach INDEX or any HUD button while the
	-- view is open: it lands on the full-screen backdrop, or on the Active card (owner-approved uncapped card, it may
	-- cover the point at large viewports; the backdrop ignores presses over the card). It fails on the AUTO button, on
	-- a button inside the card, outside the backdrop, or when the showcase does not draw above INDEX's ScreenGui.
	local index = findPath(UiSpec.Hud.NavButtons[1])
	if index then
		local ix, iy = centre(sim(index))
		local where
		if inside(ar, ix, iy) then
			where = "autobutton"
		elseif not inside(sim(backdrop), ix, iy) then
			where = "off_backdrop"
		else
			local hudGui = guiOf(index)
			if
				hudGui
				and hudGui:IsA("ScreenGui")
				and hudGui.Enabled
				and not (sgui:IsA("ScreenGui") and sgui.DisplayOrder > hudGui.DisplayOrder)
			then
				where = "hud_above_showcase"
			elseif inside(cardRect, ix, iy) then
				where = "card"
				local card = sgui:FindFirstChild(UiSpec.Showcase.Card, true)
				if not (card and card:IsA("GuiObject") and swallows(card)) then
					where = "card_not_active"
				else
					for _, d in card:GetDescendants() do
						-- Visible within the card (the view is closed during ui_layout, so not effectivelyVisible)
						local shownInCard = d:IsA("GuiButton")
						local node = d
						while shownInCard and node and node ~= card do
							shownInCard = not node:IsA("GuiObject") or node.Visible
							node = node.Parent
						end
						if shownInCard and inside(sim(d), ix, iy) then
							where = "card_button:" .. pathOf(d)
							break
						end
					end
				end
			else
				where = "backdrop"
			end
		end
		check(
			res,
			"showcase_index_point_on_backdrop_" .. vpName,
			where,
			"backdrop or card",
			where == "backdrop" or where == "card"
		)
	end
end

function S.ui_layout(res)
	waitGuis()
	for _, state in STATES do
		local restore = setPanels(state.Open)
		for _, vpSpec in UiSpec.Viewports do
			local rectOf, vp, ctx = provider(vpSpec)
			local tag = state.Name .. "_" .. vpSpec.Name
			local elements = elementsFor(state.Open)
			local rects = {}
			for _, e in elements do
				rects[e] = clipped(e.obj, rectOf)
			end

			-- 1. No two interactive / always-on elements overlap
			local overlaps = {}
			for i = 1, #elements do
				for j = i + 1, #elements do
					local a, b = elements[i], elements[j]
					local ra, rb = rects[a], rects[b]
					if
						ra
						and rb
						and not a.obj:IsAncestorOf(b.obj)
						and not b.obj:IsAncestorOf(a.obj)
						and intersects(ra, rb)
					then
						local allowed, why = overlapAllowed(a.path, b.path, ra, rb, rectOf)
						if not allowed then
							table.insert(
								overlaps,
								a.path
									.. rstr(ra)
									.. " x "
									.. b.path
									.. rstr(rb)
									.. (why and (" (" .. why .. ")") or "")
							)
						end
					end
				end
			end
			checkList(res, "no_overlap_" .. tag, overlaps)

			-- 2. Everything inside the viewport, and below the top bar unless IgnoreGuiInset
			local outside = {}
			for _, e in elements do
				local r = rects[e]
				if r and not contains(rootRect(guiOf(e.obj), vp), r) then
					table.insert(outside, e.path .. rstr(r))
				end
			end
			checkList(res, "inside_viewport_" .. tag, outside)

			-- 3. No label's drawn text runs under a button (text that hides a button or is hidden by it)
			local buttons = buttonsOf(elements)
			local textHits = {}
			for _, e in elements do
				if not e.obj:IsA("GuiButton") then
					local labels = { e.obj }
					for _, d in e.obj:GetDescendants() do
						table.insert(labels, d)
					end
					for _, l in labels do
						if
							(l:IsA("TextLabel") or l:IsA("TextBox"))
							and effectivelyVisible(l)
							and not l:FindFirstAncestorWhichIsA("GuiButton")
						then
							local lr = clipped(l, rectOf)
							local tr = lr and textRect(l, rectOf(l))
							tr = tr and intersection(tr, lr) or tr
							if tr then
								for _, b in buttons do
									local br = rects[b]
									if br and not b.obj:IsAncestorOf(l) and intersects(tr, br) then
										-- A read-out's text under a panel button is fine only where the panel
										-- verifiably draws over the read-out (UiSpec.PanelCoversReadouts)
										local lp = pathOf(l)
										local panelPath, readout = panelReadoutPair(lp, b.path)
										local why = panelPath
											and panelCoverProblem(panelPath, readout, intersection(tr, br), rectOf)
										if not panelPath or why then
											table.insert(
												textHits,
												lp
													.. " text"
													.. rstr(tr)
													.. " x "
													.. b.path
													.. (why and (" (" .. why .. ")") or "")
											)
										end
									end
								end
							end
						end
					end
				end
			end
			checkList(res, "text_clear_of_buttons_" .. tag, textHits)

			if state.Name == "rest" then
				-- 4. Placement promised by the brief / CLAUDE.md
				local function rootOf(path)
					local o = findPath(path)
					return o and rootRect(guiOf(o), vp)
				end
				-- Settings sits in the top-right corner (UiSpec.TopControls; the Race button's top-centre place is
				-- checked below)
				local settings = findPath(UiSpec.TopControls.Settings)
				if settings then
					local r, root = rectOf(settings), rootOf(UiSpec.TopControls.Settings)
					local gap = root.x + root.w - (r.x + r.w)
					check(
						res,
						"settings_top_right_edge_" .. vpSpec.Name,
						gap,
						UiSpec.TopControls.SettingsMaxRightGap,
						gap >= -TOL and gap <= UiSpec.TopControls.SettingsMaxRightGap
					)
					local topGap = r.y - root.y
					check(
						res,
						"settings_top_right_top_" .. vpSpec.Name,
						topGap,
						UiSpec.TopControls.SettingsMaxTopGap,
						topGap >= -TOL and topGap <= UiSpec.TopControls.SettingsMaxTopGap
					)
				else
					check(res, "settings_top_right_" .. vpSpec.Name, "missing", "present", false)
				end
				-- The VISIBLE icon + number are centred (not the Speed frame, whose number label is wider than its text):
				-- live from the engine (icon left edge .. number's left edge + TextBounds.X), simulated from the model
				local hud = findPath(UiSpec.Hud.Speed)
				local icon, value = findPath(UiSpec.Hud.SpeedIcon), findPath(UiSpec.Hud.SpeedValue)
				if hud and icon and value then
					local root = rootOf(UiSpec.Hud.Speed)
					local left, right = nil, nil
					if not vpSpec.Size then
						left = realRect(icon).x
						right = value.TextBounds.X > 0 and realRect(value).x + value.TextBounds.X or nil
					else
						local visible, iconX = speedVisibleWidth(vp)
						if visible then
							left = rectOf(hud).x + iconX
							right = left + visible
						end
					end
					local midX = root.x + root.w / 2
					local cx = right and (left + right) / 2
					check(
						res,
						"speed_group_centred_" .. vpSpec.Name,
						cx or "number draws nothing",
						midX,
						cx ~= nil and math.abs(cx - midX) <= UiSpec.Hud.SpeedCentreTolerance
					)
				else
					check(res, "speed_group_centred_" .. vpSpec.Name, "missing", "present", false)
				end
				local toggle = findPath(UiSpec.Hud.Race)
				if toggle then
					local r, root = rectOf(toggle), rootOf(UiSpec.Hud.Race)
					local cx, cy = centre(r)
					local midX = root.x + root.w / 2
					check(res, "autorace_top_centre_x_" .. vpSpec.Name, cx, midX, math.abs(cx - midX) <= TOL)
					check(
						res,
						"autorace_below_topbar_" .. vpSpec.Name,
						cy,
						UiSpec.Hud.RaceTop,
						r.y >= UiSpec.Hud.RaceTop - TOL
					)
				else
					check(res, "autorace_top_centre_" .. vpSpec.Name, "missing", "present", false)
				end
				-- Rolls strip (spec section 5, owner's revision): only the TurboBar, bottom centre, its bottom edge
				-- BottomGap px above the screen bottom, BarSize. (The compact roll card moved to the top centre,
				-- docs/ROLL_ANIMATION_CONTRACT.md: the overlap checks above place it at its contract rect, ui_toast
				-- proves the live card sits there.)
				local turboBar = findPath(UiSpec.Hud.Turbo)
				if turboBar then
					local bb, root = rectOf(turboBar), rootOf(UiSpec.Hud.Turbo)
					local cx = centre(bb)
					local midX = root.x + root.w / 2
					check(res, "turbobar_bottom_centre_x_" .. vpSpec.Name, cx, midX, math.abs(cx - midX) <= TOL)
					local gap = root.y + root.h - (bb.y + bb.h)
					local phone = vp.Y <= 500
					local wantGap = phone and UiSpec.Hud.TurboBottomGap.Phone or UiSpec.Hud.TurboBottomGap.Desktop
					check(res, "turbo_bottom_gap_" .. vpSpec.Name, gap, wantGap, math.abs(gap - wantGap) <= TOL)
					check(res, "turbo_centred_" .. vpSpec.Name, cx, midX, math.abs(cx - midX) <= TOL)
				else
					check(res, "turbo_bottom_centre_" .. vpSpec.Name, "missing", "present", false)
				end
				-- The showcase (an overlay, closed at rest): backdrop full screen, card centred and on screen
				local sgui = playerGui:FindFirstChild(UiSpec.Showcase.Gui)
				local backdrop = sgui and sgui:FindFirstChild(UiSpec.Showcase.Backdrop)
				local card = sgui and sgui:FindFirstChild(UiSpec.Showcase.Card, true)
				if backdrop and card and backdrop:IsA("GuiObject") and card:IsA("GuiObject") then
					local sim = provider(vpSpec.Size and vpSpec or { Name = "current_sim", Size = vp })
					local br, cr = sim(backdrop), sim(card)
					local full = R(0, 0, vp.X, vp.Y)
					check(
						res,
						"showcase_backdrop_full_screen_" .. vpSpec.Name,
						rstr(br),
						rstr(full),
						contains(br, full)
					)
					local root = rootRect(sgui, vp)
					local ccx, ccy = centre(cr)
					local mx = centre(root)
					-- Contract: the generated card is centred at CardCentreScale of the viewport.
					local d = math.max(
						math.abs(ccx - mx),
						math.abs(ccy - (root.y + root.h * UiSpec.Showcase.CardCentreScale))
					)
					check(res, "showcase_card_centred_" .. vpSpec.Name, d, TOL, d <= TOL)
					check(
						res,
						"showcase_card_inside_viewport_" .. vpSpec.Name,
						rstr(cr),
						rstr(full),
						contains(full, cr)
					)
					-- (No ENLARGED_MAX cap: owner decision 2026-10-08, the card follows RollShowcase.ui.json x k.)
					local ci = UiSpec.Showcase.CornerInset
					local cornerOnCard = vp.X - ci >= cr.x
						and vp.X - ci <= cr.x + cr.w
						and vp.Y - ci >= cr.y
						and vp.Y - ci <= cr.y + cr.h
					check(res, "showcase_corner_off_card_" .. vpSpec.Name, cornerOnCard, false, not cornerOnCard)
					showcaseAutoButtonLayout(res, vpSpec.Name, sim, vp, sgui, backdrop, cr)
				else
					check(res, "showcase_backdrop_full_screen_" .. vpSpec.Name, "missing", "Backdrop and Card", false)
				end
				local shade = playerGui:FindFirstChild("LoserScreen")
				shade = shade and shade:FindFirstChildWhichIsA("GuiObject")
				if shade then
					local sim = provider(vpSpec.Size and vpSpec or { Name = "current_sim", Size = vp })
					local r = sim(shade)
					local full = R(0, 0, vp.X, vp.Y)
					local ok = math.abs(r.x) <= TOL and math.abs(r.y) <= TOL and contains(r, full)
					check(res, "loser_overlay_full_screen_" .. vpSpec.Name, rstr(r), rstr(full), ok)
				else
					check(res, "loser_overlay_full_screen_" .. vpSpec.Name, "missing", "present", false)
				end
			end
			-- An open panel never covers the top controls (Race top centre, Settings top right): both stay clickable
			for _, panelPath in state.Open do
				local panel = findPath(panelPath)
				for _, key in { "Race", "Settings" } do
					local name = "panel_clear_of_top_controls_" .. panelPath .. "_" .. key .. "_" .. vpSpec.Name
					local control = findPath(UiSpec.TopControls[key])
					if panel and control then
						local pr, cr = rectOf(panel), rectOf(control)
						check(res, name, rstr(pr) .. " x " .. rstr(cr), "no overlap", not intersects(pr, cr))
					else
						check(res, name, "missing", "present", false)
					end
				end
			end
			-- The four Racer panels sit in the band between the Race button and the TURBO LUCK bar (owner decision
			-- 2026-10-08, RacerUiController.fitPanels; the compact roll is hidden while they are open): centred
			-- horizontally, Gap below the Race Face, Gap above the TURBO bar, clear of the INDEX / STATS / REBIRTH column
			-- by Gap (the same margin on the right), centred vertically in the band.
			for _, panelPath in state.Open do
				local prefix = UiSpec.RacerPanelBand.Panels[panelPath]
				if prefix then
					local p = findPath(panelPath)
					local race, turbo = findPath(UiSpec.Hud.Race), findPath(UiSpec.Hud.Turbo)
					local nav = findPath(UiSpec.RacerPanelBand.Navigation)
					local tagV = "_" .. vpSpec.Name
					if p and race and turbo and nav then
						local gap = UiSpec.RacerPanelBand.Gap
						local r, root = rectOf(p), rootRect(guiOf(p), vp)
						local ar, br, nr = rectOf(race), rectOf(turbo), rectOf(nav)
						local cx, cy = centre(r)
						local dx = math.abs(cx - (root.x + root.w / 2))
						check(res, prefix .. "_centred_x" .. tagV, dx, TOL, dx <= TOL)
						local minTop = ar.y + ar.h + gap
						check(res, prefix .. "_below_autorace" .. tagV, r.y, ">= " .. minTop, r.y >= minTop - TOL)
						local maxBottom = br.y - gap
						check(
							res,
							prefix .. "_above_turbo" .. tagV,
							r.y + r.h,
							"<= " .. maxBottom,
							r.y + r.h <= maxBottom + TOL
						)
						-- the column includes what sticks out of it (the STATS PointsBadge): every GuiObject
						-- descendant with Visible = true, as fitPanels reads it (UiResponsive.ColumnRight)
						local parts = {}
						for _, d in nav:GetDescendants() do
							if d:IsA("GuiObject") and d.Visible then
								table.insert(parts, rectOf(d))
							end
						end
						local side = UiResponsive.ColumnRight(nr, parts) + gap
						check(
							res,
							prefix .. "_clear_of_nav" .. tagV,
							("%s..%s"):format(math.floor(r.x + 0.5), math.floor(r.x + r.w + 0.5)),
							("%s..%s"):format(math.floor(side + 0.5), math.floor(vp.X - side + 0.5)),
							r.x >= side - TOL and r.x + r.w <= vp.X - side + TOL
						)
						local mid = (minTop + maxBottom) / 2
						check(res, prefix .. "_band_centred_y" .. tagV, cy, mid, math.abs(cy - mid) <= TOL)
						if prefix == "index_panel" then
							local bottom = root.y + root.h
							check(res, "index_panel_above_bottom" .. tagV, r.y + r.h, bottom, r.y + r.h <= bottom + TOL)
						end
					else
						check(res, prefix .. "_centred_x" .. tagV, "missing", "panel, Race, Turbo, Navigation", false)
					end
				end
			end

			-- 5. The layout model handles every layout object it met (and matches the engine, below)
			if vpSpec.Size then
				local list = {}
				for path, what in ctx.unsupported do
					table.insert(list, path .. ":" .. what)
				end
				table.sort(list)
				checkList(res, "layout_model_supported_" .. tag, list)
			end
		end

		-- The solver agrees with the engine on the live viewport (so the other viewports can be trusted)
		local sim = provider({ Name = "current_sim", Size = viewport() })
		local worst, worstPath = 0, "none"
		for _, e in elementsFor(state.Open) do
			-- The roll cards are placed at their contract rect here; liveVsNominal compares them with the engine
			if effectivelyVisible(e.obj) and not cardKind(e.obj) then
				local a, b = realRect(e.obj), sim(e.obj)
				local d = math.max(math.abs(a.x - b.x), math.abs(a.y - b.y), math.abs(a.w - b.w), math.abs(a.h - b.h))
				if d > worst then
					worst, worstPath = d, e.path
				end
			end
		end
		check(res, "layout_model_matches_engine_" .. state.Name, worst, TOL, worst <= TOL)
		if worst > TOL then
			check(res, "layout_model_worst_" .. state.Name, worstPath, "none", false)
		end
		restore()
	end
end

function S.ui_hitboxes(res)
	waitGuis()
	local pad = UiSpec.MaxHitboxPadding

	-- Probe sanity: the engine query works in the coordinates used here, front-most first
	do
		local restore = setPanels({})
		local open = findPath(UiSpec.Hud.NavButtons[1])
		local ok = false
		if open then
			local cx, cy = centre(realRect(open))
			ok = table.find(hitsAt(cx, cy), open) ~= nil
		end
		check(res, "probe_coordinates_valid", ok, true, ok)
		restore()
		restore = setPanels({ "RacerIndex/Panel" })
		local close, panel = findPath("RacerIndex/Panel/Face/Header/Face/Close/Face"), findPath("RacerIndex/Panel")
		local order = false
		if close and panel then
			local cx, cy = centre(realRect(close))
			local hits = hitsAt(cx, cy)
			local ic, ip = table.find(hits, close), table.find(hits, panel)
			order = ic ~= nil and ip ~= nil and ic < ip
		end
		check(res, "probe_order_frontmost_first", order, true, order)
		restore()
	end

	for _, state in STATES do
		local restore = setPanels(state.Open)
		local vp = viewport()
		local spill, padded, hiddenHit, covered, invisible, clippedHit, looks = {}, {}, {}, {}, {}, {}, {}
		for _, b in allButtons() do
			local path = pathOf(b)
			local r = realRect(b)
			local visible = effectivelyVisible(b)
			if visible then
				-- inside the visible parent (or the ScreenGui's area)
				local parent = b.Parent
				local pr = parent:IsA("LayerCollector") and rootRect(parent, vp) or realRect(parent)
				if pathOf(parent) == "RacerUpgrades/Panel/Canvas" and parent:IsA("ScrollingFrame") then
					-- A panning tree's parent is the full canvas. Off-window clicks remain checked below.
					pr = R(
						pr.x - parent.CanvasPosition.X,
						pr.y - parent.CanvasPosition.Y,
						pr.w * parent.CanvasSize.X.Scale + parent.CanvasSize.X.Offset,
						pr.h * parent.CanvasSize.Y.Scale + parent.CanvasSize.Y.Offset
					)
				end
				if not contains(pr, r) then
					table.insert(spill, path .. rstr(r) .. " outside " .. rstr(pr))
				end
				-- no bigger than what it shows
				local opaque = b.BackgroundTransparency < 0.95
					or (b:IsA("ImageButton") and b.Image ~= "" and b.ImageTransparency < 0.95)
				-- Only what can be SEEN and CLICKED counts: the hitbox and every part (and the button's own
				-- text) are cut by their ClipsDescendants ancestors first (a long reel strip inside a clipping
				-- window, a tree node half outside the panning Upgrades canvas). A button clipped away entirely
				-- is skipped here: clipped_buttons_not_clickable_* already proves it can not be clicked.
				local hitbox = clipped(b, realRect)
				if not opaque and hitbox then
					local content = nil
					if b:IsA("TextButton") then
						local tr = textRect(b, r)
						content = tr and intersection(tr, hitbox) or nil
					end
					for _, d in b:GetDescendants() do
						if d:IsA("GuiObject") and effectivelyVisible(d) then
							local drawn = d.BackgroundTransparency < 0.95
								or ((d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.TextTransparency < 0.95)
								or ((d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" and d.ImageTransparency < 0.95)
								-- a ViewportFrame draws its 3D content over its whole rect (the compact roll's model)
								or (d:IsA("ViewportFrame") and d.ImageTransparency < 0.95)
							local seen = drawn and clipped(d, realRect)
							if seen then
								content = union(content, seen)
							end
						end
					end
					if not content then
						table.insert(padded, path .. " shows nothing")
					elseif hitbox.w > content.w + 2 * pad + TOL or hitbox.h > content.h + 2 * pad + TOL then
						table.insert(padded, path .. rstr(hitbox) .. " content" .. rstr(content))
					end
				end
				-- disabled buttons look disabled (no hover/press highlight)
				if not b.Active and b.AutoButtonColor then
					table.insert(looks, path .. " Active=false but AutoButtonColor=true")
				end
				-- topmost at its centre (unless clipped away by a scrolling grid)
				local cr = clipped(b, realRect)
				local cx, cy = centre(r)
				if cr and cx >= cr.x and cx <= cr.x + cr.w and cy >= cr.y and cy <= cr.y + cr.h then
					local top = nil
					for _, h in hitsAt(cx, cy) do
						if h:IsA("GuiObject") and swallows(h) then
							if not effectivelyVisible(h) then
								table.insert(invisible, pathOf(h) .. " over " .. path)
							else
								top = h
								break
							end
						end
					end
					if top == nil then
						table.insert(covered, path .. " not hit at its centre")
					elseif top ~= b and not b:IsAncestorOf(top) then
						table.insert(covered, path .. " under " .. pathOf(top))
					end
				elseif r.w > 0 and r.h > 0 then
					if table.find(hitsAt(cx, cy), b) then
						table.insert(clippedHit, path .. " clickable outside its clip area")
					end
				end
			elseif r.w > 0 and r.h > 0 then
				local cx, cy = centre(r)
				if table.find(hitsAt(cx, cy), b) then
					table.insert(hiddenHit, path)
				end
			end
		end
		checkList(res, "hitbox_inside_parent_" .. state.Name, spill)
		checkList(res, "hitbox_padding_" .. state.Name, padded)
		checkList(res, "hidden_buttons_not_clickable_" .. state.Name, hiddenHit)
		checkList(res, "clipped_buttons_not_clickable_" .. state.Name, clippedHit)
		checkList(res, "button_topmost_at_centre_" .. state.Name, covered)
		checkList(res, "no_invisible_click_swallower_" .. state.Name, invisible)
		checkList(res, "disabled_buttons_look_disabled_" .. state.Name, looks)

		-- No transparent, unintended Active element anywhere on screen (a click sink with nothing drawn)
		local sinks = {}
		for _, guiName in declaredGuis() do
			local gui = playerGui:FindFirstChild(guiName)
			if gui and gui.Enabled then
				for _, d in gui:GetDescendants() do
					if d:IsA("GuiObject") and not d:IsA("GuiButton") and d.Active and effectivelyVisible(d) then
						local drawn = d.BackgroundTransparency < 0.95
							or ((d:IsA("TextLabel") or d:IsA("TextBox")) and d.Text ~= "" and d.TextTransparency < 0.95)
							or (d:IsA("ImageLabel") and d.Image ~= "" and d.ImageTransparency < 0.95)
						if not drawn and not d:IsA("ScrollingFrame") then
							table.insert(sinks, pathOf(d))
						end
					end
				end
			end
		end
		checkList(res, "no_transparent_click_sink_" .. state.Name, sinks)
		restore()
	end
end

function S.ui_buttons(res)
	waitGuis()
	local toggle = findPath(UiSpec.Hud.Race)
	local racing = attr("AutoRacing") == true
	if toggle then
		check(
			res,
			"autorace_label_matches_server",
			allText(toggle),
			HudFormat.AutoButtonText(racing),
			allText(toggle) == HudFormat.AutoButtonText(racing)
		)
	else
		check(res, "autorace_label_matches_server", "missing", "present", false)
	end
	for _, item in { { UiSpec.Hud.NavButtons[1], "INDEX" }, { UiSpec.Hud.NavButtons[2], "STATS" } } do
		local b = findPath(item[1])
		local text = b and allText(b) or "missing"
		check(res, "label_" .. item[1], text, item[2], text == item[2])
	end
	local close = findPath("RacerIndex/Panel/Face/Header/Face/Close/Face")
	check(
		res,
		"index_close_inside_index_panel",
		close ~= nil and close:IsA("GuiButton"),
		true,
		close ~= nil and close:IsA("GuiButton")
	)

	-- Equip buttons: hidden on undiscovered tiles, "Equip"+enabled on owned tiles, "Equipped"+disabled on the equipped one
	local equipped = attr("EquippedCar")
	local wrong = {}
	for _, spec in CarCatalog.All() do
		local b = findPath("RacerIndex/Panel/Face/GridHost/Gallery/" .. spec.Id .. "/Equip")
		local label = b and b:FindFirstChild("Label")
		if not b then
			table.insert(wrong, spec.Id .. ": no Equip button")
		elseif not owned(spec.Id) then
			if b.Visible then
				table.insert(wrong, spec.Id .. ": undiscovered but Equip visible")
			end
		elseif equipped == spec.Id then
			if not (b.Visible and label and label.Text == "EQUIPPED" and b.Active == false) then
				table.insert(
					wrong,
					("%s: equipped shows %q Visible=%s Active=%s"):format(
						spec.Id,
						label and label.Text or "nil",
						tostring(b.Visible),
						tostring(b.Active)
					)
				)
			end
		elseif not (b.Visible and label and label.Text == "EQUIP" and b.Active == true) then
			table.insert(
				wrong,
				("%s: owned shows %q Visible=%s Active=%s"):format(
					spec.Id,
					label and label.Text or "nil",
					tostring(b.Visible),
					tostring(b.Active)
				)
			)
		end
	end
	checkList(res, "equip_buttons_match_server", wrong)

	-- "+" buttons: enabled only with free points, never for a disabled stat (Workshop)
	local points = attr("StatPoints") or 0
	local plusWrong = {}
	for _, stat in GachaConfig.STATS do
		local b = findPath("RacerStats/Panel/Face/StatsHost/Rows/" .. stat .. "/Plus")
		local want = points > 0 and not UiSpec.Guis.RacerStats.DisabledStats[stat]
		if not b then
			table.insert(plusWrong, stat .. ": no + button")
		elseif b.Active ~= want then
			table.insert(
				plusWrong,
				("%s: Active=%s want %s (StatPoints=%d)"):format(stat, tostring(b.Active), tostring(want), points)
			)
		end
	end
	checkList(res, "plus_buttons_match_server", plusWrong)
	local ws = findPath("RacerStats/Panel/Face/StatsHost/Rows/Workshop/Plus")
	check(
		res,
		"workshop_plus_matches_free_points",
		ws and ws.Active,
		points > 0,
		ws ~= nil and ws.Active == (points > 0) and (points > 0 or ws.AutoButtonColor == false)
	)
end

function S.ui_hud(res)
	waitGuis()
	local stats = player:WaitForChild("leaderstats", 10)
	local speed = stats and stats:FindFirstChild("Speed")
	local money = stats and stats:FindFirstChild("Money")
	local value, moneyValue = findPath(UiSpec.Hud.SpeedValue), findPath(UiSpec.Hud.MoneyValue)
	check(res, "leaderstats_present", speed ~= nil and money ~= nil, true, speed ~= nil and money ~= nil)
	check(res, "hud_labels_present", value ~= nil and moneyValue ~= nil, true, value ~= nil and moneyValue ~= nil)
	-- Unbanked row (spec section 5): title "UNBANKED" and the smoothed player attribute Unbanked, under Money
	local unbankedValue = findPath(UiSpec.Hud.Unbanked)
	check(
		res,
		"unbanked_value_present",
		unbankedValue ~= nil,
		true,
		unbankedValue ~= nil and unbankedValue:IsA("TextLabel")
	)
	check(res, "unbanked_attribute_present", typeof(attr("Unbanked")), "number", type(attr("Unbanked")) == "number")
	local hudPanel = findPath(UiSpec.Hud.Money)
	if hudPanel and moneyValue and unbankedValue then
		renderFrame()
		local mv, uv = realRect(moneyValue), realRect(unbankedValue)
		check(res, "unbanked_under_money", uv.y, ">= " .. (mv.y + mv.h), uv.y >= mv.y + mv.h - TOL)
		local pr = realRect(hudPanel)
		local outside = {}
		for _, l in hudPanel:GetDescendants() do
			if l:IsA("TextLabel") and l.Visible and not contains(pr, realRect(l)) then
				table.insert(outside, pathOf(l) .. rstr(realRect(l)) .. " outside " .. rstr(pr))
			end
		end
		checkList(res, "hud_labels_inside_panel", outside)
	end
	if not (speed and money and value and moneyValue) then
		return
	end
	local s0, t0 = speed.Value, os.clock()
	task.wait(UiSpec.Waits.HudSettle)
	renderFrame()
	local s1, m1 = speed.Value, money.Value
	if unbankedValue then
		local u1 = attr("Unbanked")
		local shownUnbanked = digits(unbankedValue.Text)
		local ok = type(u1) == "number"
			and string.sub(unbankedValue.Text, 1, #UiSpec.Hud.UnbankedPrefix) == UiSpec.Hud.UnbankedPrefix
			and shownUnbanked ~= nil
			and math.abs(shownUnbanked - math.floor(u1)) <= 1
		check(
			res,
			"hud_unbanked_matches_server",
			unbankedValue.Text,
			type(u1) == "number" and HudFormat.MoneyText(u1) or "attribute Unbanked missing",
			ok
		)
	end
	local growth = math.max(0, (s1 - s0) / math.max(os.clock() - t0, 0.01))
	local shown = digits(value.Text)
	-- within one formatting step (floor) plus the smoothing lag of ~0.5 s of growth; never above the server
	local tol = 1 + growth * 0.5
	check(
		res,
		"hud_speed_matches_server",
		shown or "unparsable",
		("%s +- %.1f"):format(HudFormat.SpeedText(s1), tol),
		shown ~= nil and shown <= math.floor(s1) + 1 and shown >= s1 - tol
	)
	local shownMoney = digits(moneyValue.Text)
	check(
		res,
		"hud_money_matches_server",
		moneyValue.Text,
		HudFormat.MoneyText(m1),
		shownMoney ~= nil and math.abs(shownMoney - math.floor(m1)) <= 1
	)
	check(
		res,
		"hud_speed_suffix",
		value.Text,
		UiSpec.Hud.SpeedSuffix,
		string.find(value.Text, UiSpec.Hud.SpeedSuffix, 1, true) ~= nil
	)
	local toggle = findPath(UiSpec.Hud.Race)
	local racing = attr("AutoRacing") == true
	check(
		res,
		"autorace_label_follows_server",
		toggle and allText(toggle),
		HudFormat.AutoButtonText(racing),
		toggle ~= nil and allText(toggle) == HudFormat.AutoButtonText(racing)
	)
end

function S.ui_index(res)
	waitGuis()
	local gui = playerGui:FindFirstChild("RacerIndex")
	local panel = findPath("RacerIndex/Panel")
	local open = findPath(UiSpec.Hud.NavButtons[1])
	check(
		res,
		"index_button_present",
		open ~= nil and open:IsA("GuiButton"),
		true,
		open ~= nil and open:IsA("GuiButton")
	)
	check(res, "index_panel_hidden_at_rest", panel and panel.Visible, false, panel ~= nil and panel.Visible == false)
	if not (gui and panel) then
		return
	end
	local restore = setPanels({ "RacerIndex/Panel" })
	local all = CarCatalog.All()
	local tiles, missing = {}, {}
	for _, spec in all do
		local tile = findPath("RacerIndex/Panel/Face/GridHost/Gallery/" .. spec.Id)
		if tile then
			table.insert(tiles, { spec = spec, tile = tile })
		else
			table.insert(missing, spec.Id)
		end
	end
	checkList(res, "one_tile_per_catalog_car", missing)
	local grid = findPath("RacerIndex/Panel/Face/GridHost/Gallery")
	local extra = {}
	if grid then
		for _, c in grid:GetChildren() do
			if c:IsA("GuiObject") and not CarCatalog.Get(c.Name) then
				table.insert(extra, c.Name)
			end
		end
	end
	checkList(res, "no_extra_tiles", extra)

	-- Visual order = catalog Order (reading order: rows top to bottom, left to right)
	local byPos = table.clone(tiles)
	table.sort(byPos, function(a, b)
		local ra, rb = realRect(a.tile), realRect(b.tile)
		if math.abs(ra.y - rb.y) > TOL then
			return ra.y < rb.y
		end
		return ra.x < rb.x
	end)
	local seen, want = {}, {}
	for i, t in byPos do
		seen[i] = t.spec.Id
	end
	for i, spec in all do
		want[i] = spec.Id
	end
	check(
		res,
		"tiles_in_catalog_order",
		table.concat(seen, ","),
		table.concat(want, ","),
		table.concat(seen, ",") == table.concat(want, ",")
	)

	local equipped = attr("EquippedCar")
	local wrong = {}
	local anyFound, anyHidden, equippedTile = false, false, nil
	for _, t in tiles do
		local id, spec, tile = t.spec.Id, t.spec, t.tile
		local name, art, locked, equip =
			tile:FindFirstChild("CarName"),
			tile:FindFirstChild("Art"),
			tile:FindFirstChild("Locked"),
			tile:FindFirstChild("Equip")
		if owned(id) then
			anyFound = true
			if not (name and name.Text == spec.Name) then
				table.insert(wrong, id .. ": discovered but name is " .. tostring(name and name.Text))
			end
			if not (equip and effectivelyVisible(equip)) then
				table.insert(wrong, id .. ": discovered but no visible Equip")
			end
			if equipped == id then
				equippedTile = t
			end
		else
			anyHidden = true
			if not (name and name.Text == "???") then
				table.insert(wrong, id .. ": undiscovered but name is " .. tostring(name and name.Text))
			end
			if not (art and art:IsA("ImageLabel") and art.ImageColor3 == Color3.new(0, 0, 0)) then
				table.insert(wrong, id .. ": undiscovered art is not a silhouette")
			end
			if not (locked and locked:IsA("TextLabel") and locked.Text == "?" and effectivelyVisible(locked)) then
				table.insert(wrong, id .. ": undiscovered but lock marker is missing")
			end
			if equip and equip.Visible then
				table.insert(wrong, id .. ": undiscovered but Equip visible")
			end
		end
	end
	checkList(res, "tiles_match_gachadata", wrong)
	if not anyFound then
		stateMissing(res, "has_discovered_tile", "index_states", "no catalog car in GachaData")
	end
	if not anyHidden then
		stateMissing(res, "has_undiscovered_tile", "index_states", "every catalog car owned")
	end
	if equippedTile then
		local e = equippedTile.tile:FindFirstChild("Equip")
		local label = e and e:FindFirstChild("Label")
		local ok = e ~= nil
			and label ~= nil
			and label.Text == "EQUIPPED"
			and e.Active == false
			and e.AutoButtonColor == false
		check(
			res,
			"equipped_tile_shows_equipped_and_is_disabled",
			label
				and ("%s Active=%s AutoButtonColor=%s"):format(
					label.Text,
					tostring(e.Active),
					tostring(e.AutoButtonColor)
				),
			"EQUIPPED Active=false AutoButtonColor=false",
			ok
		)
	else
		stateMissing(
			res,
			"equipped_tile_shows_equipped_and_is_disabled",
			"index_states",
			"equipped car is " .. tostring(equipped)
		)
	end

	local unique = 0
	for _, spec in all do
		if owned(spec.Id) then
			unique += 1
		end
	end
	local progress = findPath("RacerIndex/Panel/Face/IndexProgress")
	local want2 = ("%d / %d"):format(unique, #all)
	check(
		res,
		"progress_matches_server",
		progress and progress.Text,
		want2,
		progress ~= nil and string.find(progress.Text, want2, 1, true) ~= nil
	)
	restore()
end

function S.ui_stats(res)
	waitGuis()
	local open = findPath(UiSpec.Hud.NavButtons[2])
	local panel = findPath("RacerStats/Panel")
	check(
		res,
		"stats_button_present",
		open ~= nil and open:IsA("GuiButton"),
		true,
		open ~= nil and open:IsA("GuiButton")
	)
	check(res, "stats_panel_hidden_at_rest", panel and panel.Visible, false, panel ~= nil and panel.Visible == false)
	if not (open and panel) then
		return
	end
	local points = attr("StatPoints") or 0
	local badge = findPath(UiSpec.Hud.PointsBadge)
	if points > 0 then
		local ok = badge ~= nil and effectivelyVisible(badge) and badge.Text == tostring(points)
		check(res, "badge_shows_free_points", badge and badge.Text, tostring(points), ok)
	else
		local ok = badge == nil or not effectivelyVisible(badge)
		check(res, "badge_hidden_at_zero", badge and effectivelyVisible(badge), false, ok)
	end

	local restore = setPanels({ "RacerStats/Panel" })
	local pts = findPath("RacerStats/Panel/Face/Header/Face/Points")
	check(res, "points_label_matches_server", pts and pts.Text, points, pts ~= nil and hasNumber(pts.Text, points))

	local rows, missing = {}, {}
	for _, stat in GachaConfig.STATS do
		local row = findPath("RacerStats/Panel/Face/StatsHost/Rows/" .. stat)
		if row and row:FindFirstChild("Plus") then
			table.insert(rows, { stat = stat, row = row })
		else
			table.insert(missing, stat)
		end
	end
	checkList(res, "one_row_per_stat", missing)
	local byY = table.clone(rows)
	table.sort(byY, function(a, b)
		return realRect(a.row).y < realRect(b.row).y
	end)
	local seen = {}
	for i, r in byY do
		seen[i] = r.stat
	end
	check(
		res,
		"rows_in_stats_order",
		table.concat(seen, ","),
		table.concat(GachaConfig.STATS, ","),
		table.concat(seen, ",") == table.concat(GachaConfig.STATS, ",")
	)

	local alloc = {}
	for _, stat in GachaConfig.STATS do
		alloc[stat] = attr("Alloc_" .. stat) or 0
	end
	local multis = GachaConfig.Multis(alloc)
	local wrong = {}
	for _, r in rows do
		local disabled = UiSpec.Guis.RacerStats.DisabledStats[r.stat]
		local v = r.row:FindFirstChild("Value")
		if not disabled then
			local multi = ("x%.2f"):format(multis[r.stat])
			if not (v and hasNumber(v.Text, alloc[r.stat]) and string.find(v.Text, multi, 1, true)) then
				table.insert(
					wrong,
					("%s: %q should show %d pts and %s"):format(r.stat, v and v.Text or "nil", alloc[r.stat], multi)
				)
			end
		end
		local plus = r.row:FindFirstChild("Plus")
		local want = points > 0 and not disabled
		if plus.Active ~= want then
			table.insert(wrong, ("%s: + Active=%s want %s"):format(r.stat, tostring(plus.Active), tostring(want)))
		end
	end
	checkList(res, "rows_match_server", wrong)
	restore()
end

-- The compact roll card RollToast/Toast (docs/ROLL_ANIMATION_CONTRACT.md; it replaced the bottom-centre toast): a
-- TextButton with no text of its own, shown while a roll plays and clickable only then (Visible = false at rest:
-- no invisible hitbox), hidden while any panel is open, landed on the roll's truth and placed exactly at its
-- contract rect (top centre, COMPACT_GAP under the Auto Race button) at every viewport.
function S.ui_toast(res)
	waitGuis()
	local toast = findPath("RollToast/Toast")
	check(res, "toast_present", toast ~= nil, true, toast ~= nil)
	if not toast then
		return
	end
	check(res, "toast_is_text_button", toast.ClassName, "TextButton", toast:IsA("TextButton"))
	local text = toast:IsA("TextButton") and toast.Text or "n/a"
	check(res, "toast_text_empty", text, "", text == "")
	local ap = toast.AnchorPoint
	check(res, "toast_anchor_top_centre", ("%g,%g"):format(ap.X, ap.Y), "0.5,0", ap.X == 0.5 and ap.Y == 0)
	local lim = toast:FindFirstChildWhichIsA("UISizeConstraint")
	local wantLim = ("%g..%g"):format(animNum("COMPACT_MIN"), animNum("COMPACT_MAX"))
	check(
		res,
		"toast_width_clamp",
		lim and ("%g..%g"):format(lim.MinSize.X, lim.MaxSize.X) or "no UISizeConstraint",
		wantLim,
		lim ~= nil and lim.MinSize.X == animNum("COMPACT_MIN") and lim.MaxSize.X == animNum("COMPACT_MAX")
	)
	if attr("AutoRoll") ~= true then
		stateMissing(res, "autoroll_on_for_toast", "auto_roll_on", "AutoRoll is " .. tostring(attr("AutoRoll")))
		return
	end

	-- Hidden while any panel is open (owner decision 2026-10-08, CLAUDE.md; supersedes ROLL_ANIMATION_CONTRACT
	-- decision 6): while a roll plays, opening each panel through Client/PanelSwitch (what the HUD buttons use) hides
	-- the compact roll at once and for as long as the panel is open; closing it while the roll still plays shows it
	-- again. The roll itself keeps playing hidden (same phases, not restarted), and a roll that arrives while a panel is
	-- open is not shown. (Enlarging hides it too: the showcase clicks check that.)
	local switchModule = script.Parent.Parent:FindFirstChild(UiSpec.PanelSwitch.Module)
	local Switch = nil
	if switchModule and switchModule:IsA("ModuleScript") then
		local ok, m = pcall(require, switchModule)
		if ok and type(m) == "table" and type(m.Toggle) == "function" then
			Switch = m
		end
	end
	local function setPanel(p, open)
		local o = findPath(p)
		local name = UiSpec.PanelSwitch.Names[p]
		if o and o.Visible ~= open then
			if Switch and name then
				Switch.Toggle(name)
			else
				o.Visible = open
			end
		end
	end
	local want = table.concat(UiSpec.RollAnim.Phases, ",")
	for _, p in allPanels() do
		local restorePanel = setPanels({})
		if waitNewRoll(UiSpec.Waits.RollToast) then
			local ev0 = events.rolls[#events.rolls]
			waitCardPhase(toast, { Spin = true }, animNum("POP") + 0.5)
			local serial0 = toast:GetAttribute("RollSerial")
			local shownBefore = effectivelyVisible(toast)
			setPanel(p, true)
			local panelObj = findPath(p)
			local opened = panelObj ~= nil and panelObj.Visible
			-- PanelSwitch.Changed -> refreshToast runs as the panel's Visible changes: hidden in the same frame
			local shownFrames, samples = effectivelyVisible(toast) and 1 or 0, 1
			local untilT = os.clock() + animNum("SPIN") + animNum("LAND")
			repeat
				RunService.Heartbeat:Wait()
				samples += 1
				if effectivelyVisible(toast) then
					shownFrames += 1
				end
			until os.clock() > untilT or toast:GetAttribute("Phase") == "Hold"
			check(
				res,
				"toast_hidden_while_" .. p .. "_open",
				("panel opened=%s, shown before=%s, %d of %d frames shown"):format(
					tostring(opened),
					tostring(shownBefore),
					shownFrames,
					samples
				),
				"panel opened=true, shown before=true, 0 frames shown",
				opened and shownBefore and shownFrames == 0
			)
			setPanel(p, false)
			frames(2)
			local phaseNow = toast:GetAttribute("Phase")
			local back = effectivelyVisible(toast)
			check(
				res,
				"toast_back_after_" .. p .. "_closes",
				("Phase %s, shown=%s"):format(tostring(phaseNow), tostring(back)),
				"roll still playing (not Idle), shown=true",
				phaseNow ~= "Idle" and back
			)
			local rec = recFor(ev0)
			local doneBy = os.clock() + durationFor(rarityOf(ev0.id), ev0.emphasized) + 2
			while rec and not rec.done and os.clock() < doneBy do
				task.wait(0.05)
			end
			local names = rec and seqNames(phaseSeq(rec, "Compact")) or "no record"
			check(res, "toast_keeps_playing_while_" .. p .. "_toggles", names, want, names == want)
			local hold = rec and rec.hold.Compact
			local serial1 = hold and hold.serial
			check(
				res,
				"toast_not_restarted_by_" .. p,
				("RollSerial %s -> %s, RollId %s"):format(
					tostring(serial0),
					tostring(serial1),
					tostring(hold and hold.rollId)
				),
				("unchanged, RollId %s"):format(tostring(ev0.id)),
				type(serial0) == "number" and serial1 == serial0 and hold.rollId == ev0.id
			)
		else
			stateMissing(res, "toast_hidden_while_" .. p .. "_open", "auto_racing", "no Remotes.RollResult")
		end
		setPanel(p, true)
		if waitNewRoll(UiSpec.Waits.RollToast) then
			task.wait(UiSpec.Waits.ToastShown)
			frames(2)
			local phaseNow = toast:GetAttribute("Phase")
			local shown = effectivelyVisible(toast)
			check(
				res,
				"toast_hidden_on_roll_while_" .. p .. "_open",
				("Phase %s, shown=%s"):format(tostring(phaseNow), tostring(shown)),
				"roll playing (not Idle), shown=false",
				phaseNow ~= nil and phaseNow ~= "Idle" and not shown
			)
		else
			stateMissing(res, "toast_hidden_on_roll_while_" .. p .. "_open", "auto_racing", "no Remotes.RollResult")
		end
		setPanel(p, false)
		restorePanel()
	end

	-- With no panel open: shown on a roll (clickable), landed on the roll's truth at its contract rect, then gone
	-- (Visible = false, not clickable) once the roll's animation is over. Uses a roll with no other roll before
	-- that (3 tries).
	local restore = setPanels({})
	local ev, shownRec, holdRec, goneRec = nil, nil, nil, nil
	for _ = 1, 3 do
		if not waitNewRoll(UiSpec.Waits.RollToast) then
			break
		end
		local mine = events.rolls[#events.rolls]
		local n = #events.rolls
		local spec = CarCatalog.Get(mine.id)
		local rarity = spec and spec.Rarity or "Common"
		task.wait(math.max(0, UiSpec.Waits.ToastShown - (os.clock() - mine.t)))
		renderFrame()
		local x, y = centre(nominalOf(toast))
		local top = topAt(x, y)
		shownRec = { visible = effectivelyVisible(toast), drawn = drawsSomething(toast), top = top }
		-- Landed (Hold): the bare model and its odds show the roll, at 1x ("Compact = no card", owner decision 4)
		local landBy = mine.t + animNum("POP") + animNum("SPIN") + animNum("LAND") + 0.5
		local landed = waitCardPhase(toast, { Hold = true }, math.max(0.1, landBy - os.clock()))
		local odds = partOf(toast, "Odds")
		local colourProblem = "no Odds label"
		if odds and odds:IsA("TextLabel") then
			colourProblem = rarityColourProblem(odds, rarity)
		end
		holdRec = {
			colourProblem = colourProblem,
			landed = landed,
			odds = odds and odds:IsA("TextLabel") and odds.Text or "missing",
			oddsShown = odds ~= nil and odds:IsA("GuiObject") and effectivelyVisible(odds),
			autoOffShown = partShown(toast, UiSpec.Compact.AutoOff),
			problems = compactProblems(toast, mine),
			shape = compactShapeProblems(toast),
			layout = compactLayoutProblems(toast),
			placement = liveVsNominal(toast),
		}
		local goneAt = mine.t + durationFor(rarity, mine.emphasized) + UiSpec.Waits.ToastGoneGrace
		task.wait(math.max(0, goneAt - os.clock()))
		renderFrame()
		local hit = false
		for _, h in hitsAt(x, y) do
			hit = hit or h == toast or h:IsDescendantOf(toast)
		end
		goneRec = { visible = effectivelyVisible(toast), hit = hit }
		ev = mine
		if #events.rolls == n and not mine.emphasized then
			break -- isolated: no other roll changed the card meanwhile
		end
		ev = nil
	end
	if not ev then
		stateMissing(
			res,
			"roll_result_received",
			"auto_racing",
			"no isolated Remotes.RollResult in " .. UiSpec.Waits.RollToast .. " s"
		)
		restore()
		return
	end
	local spec = CarCatalog.Get(ev.id)
	check(res, "roll_is_catalog_car", ev.id, "CarCatalog id", spec ~= nil)
	if not spec then
		restore()
		return
	end
	check(
		res,
		"toast_visible_after_roll",
		("Visible=%s drawn=%s"):format(tostring(shownRec.visible), tostring(shownRec.drawn)),
		("shown within %.1f s"):format(UiSpec.Waits.ToastShown),
		shownRec.visible and shownRec.drawn
	)
	local top = shownRec.top
	check(
		res,
		"toast_clickable_while_shown",
		top and pathOf(top) or "nothing",
		"RollToast/Toast",
		top ~= nil and (top == toast or toast:IsAncestorOf(top))
	)
	check(res, "toast_reached_hold", holdRec.landed, true, holdRec.landed == true)
	-- Owner decision 4: the compact roll shows the odds, not the car's name (CarName / NewBadge are checked on the
	-- enlarged card: showcase_card_is_latest_roll, showcase_updates_live, emphasized_card_matches_roll)
	local wantOdds = HudFormat.Odds(spec.Chance)
	check(res, "toast_shows_odds", holdRec.odds, wantOdds, holdRec.odds == wantOdds and holdRec.oddsShown == true)
	checkList(res, "toast_is_no_card", holdRec.shape)
	checkList(res, "toast_model_over_odds", holdRec.layout)
	check(
		res,
		"toast_auto_off_caption_hidden_while_auto_on",
		holdRec.autoOffShown,
		false,
		holdRec.autoOffShown == false
	)
	check(
		res,
		"toast_in_rarity_colour",
		holdRec.colourProblem or "ok",
		spec.Rarity .. " colour (Secret: light text)",
		holdRec.colourProblem == nil
	)
	checkList(res, "toast_card_matches_roll", holdRec.problems)
	-- The placement (phase 1 of the build): the live card at its contract rect at every viewport and in the engine
	checkList(res, "toast_at_contract_rect", holdRec.placement)
	check(res, "toast_not_visible_after_fade", goneRec.visible, false, goneRec.visible == false)
	check(res, "faded_toast_not_clickable", goneRec.hit, false, goneRec.hit == false)
	restore()
end

-- The TURBO LUCK bar is part of RacerHud; the removed bottom roll controls must not return.
function S.ui_rolls(res)
	waitGuis()
	local every, luck = turboEvery(), turboLuck()
	local cfgOk = type(GachaConfig.TURBO_EVERY) == "number"
		and type(GachaConfig.TURBO_LUCK) == "number"
		and type(GachaConfig.IsTurbo) == "function"
		and type(GachaConfig.TurboProgress) == "function"
	check(res, "gacha_turbo_config_present", cfgOk, true, cfgOk)

	local gui = playerGui:FindFirstChild("RacerHud")
	local missing = {}
	for _, p in { UiSpec.Hud.Turbo, UiSpec.Hud.TurboFill, UiSpec.Hud.TurboLabel } do
		if not findPath(p) then
			table.insert(missing, p)
		end
	end
	checkList(res, "turbo_hud_parts_present", missing)
	local legacy = findPath("RacerHud/RollControls")
	check(
		res,
		"legacy_roll_controls_hidden",
		legacy and effectivelyVisible(legacy),
		false,
		legacy == nil or not effectivelyVisible(legacy)
	)
	if not gui then
		return
	end

	-- 1. Label and bar follow the server once settled
	local restore = setPanels({})
	local stable = waitRollsStable()
	check(res, "rolls_settled_for_check", stable, true, stable)
	renderFrame()
	local rolls = attr("Rolls")
	check(res, "rolls_attribute_present", typeof(rolls), "number", type(rolls) == "number")
	rolls = type(rolls) == "number" and rolls or 0
	local progress = turboProgress(rolls)
	local frac = fillFraction()
	local wantFrac = progress / every
	check(
		res,
		"turbo_fill_matches_progress",
		frac or "missing",
		("%.2f +- %.2f"):format(wantFrac, UiSpec.Turbo.FillTolerance),
		frac ~= nil and math.abs(frac - wantFrac) <= UiSpec.Turbo.FillTolerance
	)
	local barLabel = findPath(UiSpec.Hud.TurboLabel)
	local wantLabel = ("TURBO LUCK %d/%d"):format(progress, every)
	check(
		res,
		"turbo_label_matches_progress",
		barLabel and barLabel.Text or "missing",
		wantLabel,
		barLabel ~= nil and string.find(barLabel.Text, wantLabel, 1, true) ~= nil
	)
	local recentTurbo = false
	for _, rec in events.turbos do
		recentTurbo = recentTurbo or os.clock() - rec.ev.t < UiSpec.Waits.TurboPopHide
	end
	if not recentTurbo then
		local _, _, gone = popState()
		check(res, "turbo_pop_hidden_at_rest", gone, true, gone)
	end
	restore()

	-- 2. Turbo roll: TurboPop "x<TURBO_LUCK>" shows, hides again, the bar is empty again
	local function isolatedTurbo()
		for i = #events.turbos, 1, -1 do
			local rec = events.turbos[i]
			if rec.done and rec.isolated then
				return rec
			end
		end
		return nil
	end
	local rec = isolatedTurbo()
	if not rec then
		player:SetAttribute("UiTestWaiting", "turbo_roll")
		print(
			("[UITEST] WAIT turbo_roll up to %d s (ServerSetup turbo_next makes it quick)"):format(
				UiSpec.Waits.TurboRoll
			)
		)
		local deadline = os.clock() + UiSpec.Waits.TurboRoll + UiSpec.Waits.TurboPopHide
		while not rec and os.clock() < deadline do
			task.wait(0.1)
			rec = isolatedTurbo()
		end
		player:SetAttribute("UiTestWaiting", nil)
	end
	if not rec then
		check(
			res,
			"turbo_roll_received",
			("none in %d s"):format(UiSpec.Waits.TurboRoll),
			"RollResult with turboMulti > 1 every TURBO_EVERY rolls",
			false
		)
		return
	end
	check(res, "turbo_multi_is_turbo_luck", rec.ev.turboMulti, luck, rec.ev.turboMulti == luck)
	local wantPop = "x" .. fmtNum(luck)
	check(
		res,
		"turbo_pop_shown_after_turbo",
		rec.shownText or "missing",
		("shown, contains %q within %.1f s"):format(wantPop, UiSpec.Waits.TurboPopShow),
		rec.shown == true and string.find(rec.shownText or "", wantPop, 1, true) ~= nil
	)
	check(res, "turbo_pop_hidden_after_turbo", rec.gone, true, rec.gone == true)
	check(
		res,
		"turbo_fill_empty_after_turbo",
		rec.fill or "missing",
		("0 +- %.2f"):format(UiSpec.Turbo.FillTolerance),
		rec.fill ~= nil and rec.fill <= UiSpec.Turbo.FillTolerance
	)
end

-- One roll on the compact card (docs/ROLL_ANIMATION_CONTRACT.md): PopIn -> Spin -> Land -> Hold -> Exit -> Idle with
-- RollAnimConfig's timings on a real RollResult, RollId / RollSerial / Reel.ReelIds, every card part, the land pop,
-- the FlyIcon to INDEX, the turbo badge and flames from pop-in, rarity effects, and no roll covering one still
-- playing (the server's ExtraPause).
function S.ui_roll_anim(res)
	waitGuis()
	local cfg = anim()
	local missing = {}
	if not cfg then
		table.insert(missing, "module ReplicatedStorage.Shared." .. UiSpec.RollAnim.Module)
	else
		for _, name in UiSpec.RollAnim.Numbers do
			if type(cfg[name]) ~= "number" then
				table.insert(missing, name)
			end
		end
		for _, name in UiSpec.RollAnim.Vectors do
			if typeof(cfg[name]) ~= "Vector2" then
				table.insert(missing, name .. " (Vector2)")
			end
		end
		for _, name in UiSpec.RollAnim.Functions do
			if type(cfg[name]) ~= "function" then
				table.insert(missing, name .. "()")
			end
		end
	end
	checkList(res, "roll_anim_config_present", missing)

	local toast = findPath("RollToast/Toast")
	local _, _, bigCard = showcaseParts()
	-- The compact roll is no card (owner decision 4): only its model parts exist, no card part at all
	checkList(res, "compact_is_no_card", compactShapeProblems(toast))
	for _, key in { "compact", "enlarged" } do
		local card = key == "compact" and toast or bigCard
		if key == "enlarged" then
			local absent = {}
			for _, name in UiSpec.Showcase.CardParts do
				if not partOf(card, name) then
					table.insert(absent, name)
				end
			end
			local view = partOf(card, "Viewport")
			if view and not view:IsA("ViewportFrame") then
				table.insert(absent, "Viewport is " .. view.ClassName .. ", want ViewportFrame")
			end
			if not card then
				absent = { "no card" }
			end
			checkList(res, "card_parts_present_" .. key, absent)
		end
		local phase = card and card:GetAttribute("Phase")
		check(
			res,
			"card_has_phase_attribute_" .. key,
			typeof(phase),
			"string (" .. table.concat(UiSpec.RollAnim.Phases, "|") .. ")",
			type(phase) == "string" and table.find(UiSpec.RollAnim.Phases, phase) ~= nil
		)
	end
	local rtGui = playerGui:FindFirstChild("RollToast")
	local view = rtGui and rtGui:GetAttribute(UiSpec.RollAnim.ViewAttr)
	check(res, "roll_view_attribute", tostring(view), "Compact|Enlarged", view == "Compact" or view == "Enlarged")

	if attr("AutoRoll") ~= true then
		stateMissing(res, "autoroll_on_for_anim", "auto_roll_on", "AutoRoll is " .. tostring(attr("AutoRoll")))
		return
	end
	local restore = setPanels({})

	-- 1. A whole compact roll, uninterrupted, started after this point
	local startN = #events.rolls
	local rec, lastDone = nil, nil
	local deadline = os.clock() + 3 * UiSpec.Waits.RollToast
	while not rec and os.clock() < deadline do
		task.wait(0.1)
		local done = 0
		for _, r in events.recs do
			if r.ev.n > startN and r.done then
				done += 1
				lastDone = r
				if not rec and r.playKey == "Compact" and r.idleAt and not r.ev.emphasized then
					rec = r
				end
			end
		end
		if done >= 3 then
			break
		end
	end
	if not rec then
		check(
			res,
			"roll_animation_completed",
			lastDone
					and (seqNames(phaseSeq(lastDone, "Compact")) .. (lastDone.interruptedAt and " (interrupted)" or ""))
				or "no RollResult",
			"PopIn,Spin,Land,Hold,Exit,Idle on RollToast/Toast before the next roll",
			false
		)
		restore()
		return
	end
	local ev = rec.ev
	local spec = CarCatalog.Get(ev.id)
	phaseChecks(res, rec, "Compact", "")
	local hold = rec.hold.Compact
	if not hold then
		check(res, "card_sampled_at_hold", "no Hold", "Hold", false)
		restore()
		return
	end
	check(res, "roll_id_matches_roll", tostring(hold.rollId), ev.id, hold.rollId == ev.id)
	-- Compact = the bare model and its odds (owner decision 4). The card style, rarity effects and the turning
	-- Glow are checked on the enlarged card (showcase_card_style / emphasized_card_style and friends).
	checkList(res, "compact_matches_roll", hold.problems)
	checkList(res, "compact_is_no_card_at_hold", hold.shape or { "no sample" })
	checkList(res, "compact_model_over_odds", hold.layout or { "no sample" })

	-- Reel: REEL_CARS rollable ids, the last one the result
	local reelIds = (rec.spin.Compact and rec.spin.Compact.reelIds) or hold.reelIds
	local ids = {}
	if type(reelIds) == "string" then
		for id in string.gmatch(reelIds, "[^,]+") do
			table.insert(ids, (string.gsub(id, "^%s*(.-)%s*$", "%1")))
		end
	end
	check(res, "reel_ids_count", #ids, animNum("REEL_CARS"), #ids == animNum("REEL_CARS"))
	check(res, "reel_ids_end_with_result", tostring(ids[#ids]), ev.id, ids[#ids] == ev.id)
	local notRollable = {}
	for _, id in ids do
		local s = CarCatalog.Get(id)
		if not (s and s.Rollable) then
			table.insert(notRollable, id)
		end
	end
	if #ids == 0 then
		notRollable = { "ReelIds " .. tostring(reelIds) }
	end
	checkList(res, "reel_ids_rollable_cars", notRollable)

	-- Size: grows from 0 in PopIn, LAND_POP x in Land, back to 1x in Hold, shrinks in Exit
	local minPop, peakLand, worstHold, minExit = math.huge, 0, 0, math.huge
	local holdStart = nil
	for _, p in phaseSeq(rec, "Compact") do
		if p.phase == "Hold" then
			holdStart = p.t
		end
	end
	for _, s in rec.ratios do
		if s.phase == "PopIn" then
			minPop = math.min(minPop, s.r)
		elseif s.phase == "Land" or (s.phase == "Hold" and holdStart and s.t - holdStart < 0.05) then
			peakLand = math.max(peakLand, s.r)
		elseif s.phase == "Hold" then
			worstHold = math.max(worstHold, math.abs(s.r - 1))
		elseif s.phase == "Exit" then
			minExit = math.min(minExit, s.r)
		end
	end
	check(
		res,
		"popin_grows_from_zero",
		minPop == math.huge and "no PopIn sample" or minPop,
		"<= " .. UiSpec.RollAnim.PopInStartMax,
		minPop <= UiSpec.RollAnim.PopInStartMax
	)
	local pop = animNum("LAND_POP")
	check(
		res,
		"land_pop_peak",
		peakLand,
		("%.2f +- %.2f"):format(pop, UiSpec.RollAnim.LandPopTolerance),
		math.abs(peakLand - pop) <= UiSpec.RollAnim.LandPopTolerance
	)
	check(
		res,
		"land_pop_settles_to_1x",
		worstHold,
		"<= " .. UiSpec.RollAnim.SettledTolerance,
		worstHold <= UiSpec.RollAnim.SettledTolerance
	)
	check(
		res,
		"exit_card_shrinks",
		minExit == math.huge and "no Exit sample" or minExit,
		"<= " .. UiSpec.RollAnim.ExitShrinkMax,
		minExit <= UiSpec.RollAnim.ExitShrinkMax
	)
	check(res, "smoke_puff_on_land", rec.smoke == true, true, rec.smoke == true)

	-- FlyIcon (a small car icon, no text) flies from the roll to the HUD INDEX button on Exit, takes no clicks, then
	-- is gone
	local target = findPath(UiSpec.RollAnim.FlyTarget)
	local fly = rec.fly
	check(res, "flyicon_shown_on_exit", #fly, ">= 1 sample", #fly >= 1)
	if #fly >= 1 and target and spec then
		local texts = {}
		for _, f in fly do
			if f.text ~= "" and not table.find(texts, f.text) then
				table.insert(texts, f.text)
			end
		end
		checkList(res, "flyicon_has_no_text", texts)
		local tr = realRect(target)
		local first, best = distToRect(fly[1].x, fly[1].y, tr), math.huge
		local clicks = false
		for _, f in fly do
			best = math.min(best, distToRect(f.x, f.y, tr))
			clicks = clicks or f.clicks
		end
		check(res, "flyicon_moves_toward_index", best, "< " .. first, best < first)
		check(res, "flyicon_reaches_index", best, "<= " .. UiSpec.RollAnim.FlyArrive, best <= UiSpec.RollAnim.FlyArrive)
		check(res, "flyicon_not_clickable", clicks, false, not clicks)
	elseif not target then
		check(res, "flyicon_target_present", "missing", UiSpec.RollAnim.FlyTarget, false)
	end
	local after = rec.after
	check(
		res,
		"flyicon_gone_after_exit",
		after and after.flyShown or "no sample after Idle",
		false,
		after ~= nil and after.flyShown == false
	)
	check(
		res,
		"compact_card_hidden_after_idle",
		after and after.toastShown or "no sample after Idle",
		false,
		after ~= nil and after.toastShown == false
	)
	local views = {}
	for _, v in rec.views do
		table.insert(views, v.view)
	end
	local allCompact = #views > 0
	for _, v in views do
		allCompact = allCompact and v == "Compact"
	end
	check(res, "normal_roll_stays_compact", table.concat(views, ","), "Compact", allCompact)

	-- 2. Turbo on the compact roll: no badge and no flames exist there (owner decision 4; the turbo badge and flames
	-- from pop-in are checked on the enlarged card: click showcase_card_click_stays_open,
	-- showcase_turbo_badge_from_popin)
	local turboRec = nil
	for i = #events.recs, 1, -1 do
		local r = events.recs[i]
		if not turboRec and r.done and r.ev.turboMulti > 1 and r.playKey == "Compact" and r.hold.Compact then
			turboRec = r
		end
	end
	if turboRec then
		checkList(res, "turbo_roll_compact_is_no_card", turboRec.hold.Compact.shape or { "no sample" })
	else
		stateMissing(res, "turbo_roll_compact_is_no_card", "turbo_next", "no turbo roll played on the compact roll")
	end

	-- 3. RollSerial +1 per RollResult received (pairs of rolls sampled on the same card)
	local prev, pairsSeen, serialBad = {}, 0, {}
	for _, r in events.recs do
		for key, h in r.hold do
			local p = prev[key]
			if p and type(h.serial) == "number" and type(p.serial) == "number" then
				pairsSeen += 1
				if h.serial - p.serial ~= r.ev.n - p.n then
					table.insert(
						serialBad,
						("%s: roll %d serial %d after roll %d serial %d"):format(key, r.ev.n, h.serial, p.n, p.serial)
					)
				end
			elseif p and type(h.serial) ~= "number" then
				table.insert(serialBad, key .. ": RollSerial " .. tostring(h.serial))
			end
			prev[key] = { n = r.ev.n, serial = h.serial }
		end
	end
	if pairsSeen == 0 and #serialBad == 0 then
		serialBad = { "fewer than 2 rolls sampled at Hold on one card" }
	end
	checkList(res, "roll_serial_counts_roll_results", serialBad)

	-- 4. No RollResult arrives while the previous roll still plays (server pauses ExtraPause after long rolls)
	local evaluated, covered = 0, {}
	for _, r in events.recs do
		if r.done and #phaseSeq(r, r.playKey) > 0 then
			evaluated += 1
			if r.interruptedAt and not r.idleAt then
				table.insert(
					covered,
					("roll %d (%s, %s) cut at %s"):format(
						r.ev.n,
						r.ev.id,
						rarityOf(r.ev.id),
						seqNames(phaseSeq(r, r.playKey))
					)
				)
			end
		end
	end
	if evaluated == 0 then
		covered = { "no roll animation recorded" }
	end
	checkList(res, "rolls_never_cut_an_animation", covered)
	restore()
end

-- The roll showcase at rest (closed): its parts exist, it draws above the HUD and nothing of it is visible or
-- clickable. Its open behaviour is checked by the showcase clicks (only a real toast click opens it).
function S.ui_showcase(res)
	waitGuis()
	local cfg = UiSpec.Showcase
	local gui, backdrop, card = showcaseParts()
	check(res, "showcase_gui_present", gui ~= nil, true, gui ~= nil and gui:IsA("ScreenGui"))
	if not gui then
		return
	end
	local state = showcaseState()
	check(res, "showcase_closed_at_rest", state, "closed", state == "closed")
	local blur = blurState()
	check(res, "showcase_blur_disabled_at_rest", blur, "disabled", blur == "disabled")
	checkList(res, "showcase_not_clickable_at_rest", showcaseHits())
	checkList(res, "normal_view_clickable_at_rest", alwaysOnCovered())

	check(
		res,
		"showcase_backdrop_is_text_button",
		backdrop and backdrop.ClassName or "missing",
		"TextButton",
		backdrop ~= nil and backdrop:IsA("TextButton")
	)
	if backdrop and backdrop:IsA("TextButton") then
		check(res, "showcase_backdrop_no_text", backdrop.Text, "", backdrop.Text == "")
		local t = backdrop.BackgroundTransparency
		check(
			res,
			"showcase_backdrop_transparency",
			t,
			("%.2f..%.2f"):format(cfg.BackdropTransparency.Min, cfg.BackdropTransparency.Max),
			t >= cfg.BackdropTransparency.Min and t <= cfg.BackdropTransparency.Max
		)
		local l = luminance(backdrop.BackgroundColor3)
		check(res, "showcase_backdrop_dark", l, "<= " .. cfg.BackdropMaxLuminance, l <= cfg.BackdropMaxLuminance)
	end
	check(
		res,
		"showcase_card_is_active_frame",
		card and ("%s Active=%s"):format(card.ClassName, tostring(card:IsA("GuiObject") and card.Active)) or "missing",
		"Frame Active=true",
		card ~= nil and card:IsA("Frame") and card.Active == true
	)
	local missing = {}
	for _, name in cfg.CardParts do
		local o = card and card:FindFirstChild(name, true)
		if not o then
			table.insert(missing, name)
		elseif name == "Viewport" and not o:IsA("ViewportFrame") then
			table.insert(missing, name .. " is " .. o.ClassName .. ", want ViewportFrame")
		end
	end
	checkList(res, "showcase_card_parts_present", missing)
	-- Nothing inside the card takes clicks except the card itself (a click on it must not close, nor do anything)
	local inner = {}
	if card then
		for _, d in card:GetDescendants() do
			if d:IsA("GuiObject") and d:IsA("GuiButton") then
				table.insert(inner, pathOf(d))
			end
		end
	end
	checkList(res, "showcase_card_has_no_buttons", inner)
	-- Same for the compact card: its parts never take a click of their own (the card itself is the button)
	local toast = findPath("RollToast/Toast")
	local innerToast = {}
	for _, d in toast and toast:GetDescendants() or {} do
		if d:IsA("GuiObject") and swallows(d) then
			table.insert(innerToast, pathOf(d))
		end
	end
	checkList(res, "toast_card_parts_not_clickable", innerToast)

	-- docs/ROLL_ANIMATION_CONTRACT.md: the hint, the AUTO button (label from the server's AutoRoll), the view state
	local hint = backdrop and backdrop:FindFirstChild(cfg.Hint)
	check(
		res,
		"showcase_hint_text",
		hint and hint:IsA("TextLabel") and hint.Text or "missing",
		cfg.HintText,
		hint ~= nil and hint:IsA("TextLabel") and hint.Text == cfg.HintText
	)
	local autoRoll = attr("AutoRoll")
	check(res, "autoroll_attribute_on", tostring(autoRoll), "true (on join; restored after tests)", autoRoll == true)
	local auto = gui:FindFirstChild(cfg.AutoButton.Path)
	check(
		res,
		"showcase_autobutton_is_text_button",
		auto and auto.ClassName or "missing",
		"TextButton",
		auto ~= nil and auto:IsA("TextButton")
	)
	local wantLabel = UiSpec.RollAnim.AutoButtonText[autoRoll == true]
	check(
		res,
		"autobutton_label_matches_server",
		auto and auto:IsA("TextButton") and auto.Text or "missing",
		wantLabel,
		auto ~= nil and auto:IsA("TextButton") and auto.Text == wantLabel
	)
	local rtGui = playerGui:FindFirstChild("RollToast")
	local view = rtGui and rtGui:GetAttribute(UiSpec.RollAnim.ViewAttr)
	check(res, "view_compact_at_rest", tostring(view), "Compact", view == "Compact")
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	for _, name in { "SetAutoRoll", UiSpec.Announce.Remote } do
		local r = remotes and remotes:FindFirstChild(name)
		check(
			res,
			"remote_present_" .. name,
			r and r.ClassName or "missing",
			"RemoteEvent",
			r ~= nil and r:IsA("RemoteEvent")
		)
	end

	-- Draws above every game UI but the loser screen (ui_loser keeps that one on top of the showcase)
	local highest, who = -math.huge, "none"
	for _, name in declaredGuis() do
		local other = playerGui:FindFirstChild(name)
		if
			name ~= cfg.Gui
			and not UiSpec.Guis[name].Overlay
			and other
			and other:IsA("ScreenGui")
			and other.DisplayOrder >= highest
		then
			highest, who = other.DisplayOrder, name
		end
	end
	check(
		res,
		"showcase_above_hud",
		gui.DisplayOrder,
		("> %s (%s)"):format(tostring(highest), who),
		gui.DisplayOrder > highest
	)
end

function S.ui_loser(res)
	waitGuis()
	local gui = playerGui:FindFirstChild("LoserScreen")
	check(res, "loser_screen_present", gui ~= nil, true, gui ~= nil)
	if not gui then
		return
	end
	local recent = events.lastLose and os.clock() - events.lastLose < NpcConfig.LOSE_SCREEN_SECONDS + 0.5
	if not recent then
		check(res, "loser_screen_hidden_at_rest", gui.Enabled, false, gui.Enabled == false)
	end
	check(res, "loser_screen_ignores_inset", gui.IgnoreGuiInset, true, gui.IgnoreGuiInset == true)
	-- A declared overlay must draw over every other game UI, not tie with it
	local highest, who = -math.huge, "none"
	for _, name in declaredGuis() do
		local other = playerGui:FindFirstChild(name)
		if name ~= "LoserScreen" and other and other:IsA("ScreenGui") and other.DisplayOrder >= highest then
			highest, who = other.DisplayOrder, name
		end
	end
	check(res, "loser_screen_on_top", gui.DisplayOrder, ("> %d (%s)"):format(highest, who), gui.DisplayOrder > highest)

	-- A real Result Lose (ServerSetup lose_event): shown, on top of everything, hidden again after Reset/Start
	local deadline = os.clock() + UiSpec.Waits.LoseEvent
	while #events.loses == 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	local rec = events.loses[#events.loses]
	if not rec then
		stateMissing(res, "loser_shown_after_lose", "lose_event", "no NpcRace Result Lose received")
		return
	end
	deadline = os.clock() + NpcConfig.LOSE_SCREEN_SECONDS + UiSpec.Waits.LoseEvent
	while not rec.done and os.clock() < deadline do
		task.wait(0.1)
	end
	check(res, "loser_shown_after_lose", rec.shown, true, rec.shown == true)
	check(res, "loser_draws_above_all_guis", rec.order, "> " .. tostring(rec.highestOther), rec.onTop == true)
	checkList(res, "loser_covers_buttons_while_shown", rec.coverMissed or { "not sampled" })
	if rec.done then
		check(res, "loser_hidden_after_" .. string.lower(rec.after), rec.hiddenAfter, true, rec.hiddenAfter == true)
	else
		check(res, "loser_hidden_after_reset", "no Reset/Start/Stop after the Lose", "hidden", false)
	end
end

function S.ui_billboards(res)
	local pads = CollectionService:GetTagged("WinPad")
	check(res, "win_pads_present", #pads, ">= 1", #pads >= 1)
	local wrong = {}
	for _, pad in pads do
		local bb = pad:FindFirstChild("WinText")
		local label = bb and bb:FindFirstChild("Amount")
		local cash = pad:GetAttribute("Cash")
		if not (bb and bb:IsA("BillboardGui")) then
			table.insert(wrong, pad:GetFullName() .. ": no WinText")
		else
			if bb.MaxDistance ~= TrackBuilder.WIN_TEXT_DISTANCE then
				table.insert(
					wrong,
					("%s: MaxDistance %s want %s"):format(
						pad:GetFullName(),
						tostring(bb.MaxDistance),
						tostring(TrackBuilder.WIN_TEXT_DISTANCE)
					)
				)
			end
			if not (label and label.Text == "$" .. tostring(cash)) then
				table.insert(
					wrong,
					("%s: text %q want $%s"):format(pad:GetFullName(), label and label.Text or "nil", tostring(cash))
				)
			end
			if bb.Active or #buttonsIn(bb) > 0 then
				table.insert(wrong, pad:GetFullName() .. ": WinText is clickable")
			end
		end
	end
	checkList(res, "win_text_matches_pad", wrong)

	local function npcs()
		local list = {}
		for _, m in Workspace:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("IsNpc") then
				table.insert(list, m)
			end
		end
		return list
	end
	local deadline = os.clock() + UiSpec.Waits.NpcStart
	local list = npcs()
	while #list == 0 and os.clock() < deadline do
		task.wait(0.25)
		list = npcs()
	end
	if #list == 0 then
		stateMissing(res, "npc_on_track", "auto_racing", "no IsNpc model in " .. UiSpec.Waits.NpcStart .. " s")
		return
	end
	check(res, "one_npc_at_a_time", #list, 1, #list == 1)
	local npc = list[1]
	local bb = npc:FindFirstChild("NpcLabel")
	local text = bb and bb:FindFirstChild("Text")
	local track = npc:GetAttribute("TrackNumber")
	local want = NpcConfig.For(track).Label
	local start = events.npcStart
	if start and start.Track == track and type(start.Label) == "string" then
		want = start.Label
	end
	check(res, "npc_label_text", text and text.Text, want, text ~= nil and text.Text == want)
	check(
		res,
		"npc_label_max_distance",
		bb and bb.MaxDistance,
		NpcConfig.LABEL_DISTANCE,
		bb ~= nil and bb.MaxDistance == NpcConfig.LABEL_DISTANCE
	)
	check(res, "npc_label_not_clickable", bb and bb.Active, false, bb ~= nil and not bb.Active and #buttonsIn(bb) == 0)
end

-- The two panels are mutually exclusive through the real mechanism the buttons use (Client/PanelSwitch).
function S.ui_panels(res)
	waitGuis()
	-- UiTest lives in StarterPlayerScripts.Client, next to the UI scripts and PanelSwitch
	local module = script.Parent.Parent:WaitForChild(UiSpec.PanelSwitch.Module, 5)
	check(res, "panel_switch_present", module ~= nil, true, module ~= nil and module:IsA("ModuleScript"))
	if not (module and module:IsA("ModuleScript")) then
		return
	end
	local ok, Switch = pcall(require, module)
	check(res, "panel_switch_loads", ok, true, ok and type(Switch) == "table" and type(Switch.Toggle) == "function")
	if not (ok and type(Switch) == "table" and type(Switch.Toggle) == "function") then
		return
	end
	local panels = allPanels()
	local restore = setPanels({})
	local function openSet()
		frames(2)
		local list = {}
		for _, p in panels do
			local o = findPath(p)
			if o and o.Visible then
				table.insert(list, p)
			end
		end
		return table.concat(list, ",")
	end
	for _, p in panels do
		check(
			res,
			"panel_registered_" .. p,
			UiSpec.PanelSwitch.Names[p] ~= nil,
			true,
			UiSpec.PanelSwitch.Names[p] ~= nil
		)
	end
	-- Open each panel in turn from every other open panel: exactly the newly opened one is visible
	for _, a in panels do
		for _, b in panels do
			if a ~= b then
				setPanels({})
				Switch.Toggle(UiSpec.PanelSwitch.Names[a])
				local afterA = openSet()
				check(res, "open_" .. a .. "_alone", afterA, a, afterA == a)
				Switch.Toggle(UiSpec.PanelSwitch.Names[b])
				local afterB = openSet()
				check(res, "open_" .. b .. "_closes_" .. a, afterB, b, afterB == b)
				Switch.Toggle(UiSpec.PanelSwitch.Names[b])
				local afterToggle = openSet()
				check(res, "toggle_" .. b .. "_closes_it", afterToggle, "", afterToggle == "")
			end
		end
	end
	if type(Switch.Close) == "function" then
		for _, p in panels do
			setPanels({})
			Switch.Toggle(UiSpec.PanelSwitch.Names[p])
			Switch.Close(UiSpec.PanelSwitch.Names[p])
			local after = openSet()
			check(res, "close_" .. p, after, "", after == "")
		end
	end

	-- UiSpec.HiddenWhilePanelOpen: each declared element really is hidden while a panel that hides it is open (the
	-- overlap lists leave it out then), and shown again once no panel is open. ProgressionUi polls every 0.25 s, so
	-- each state is waited for (UiSpec.HiddenWhilePanelOpenWait). The compact roll is also checked during a playing
	-- roll by ui_toast (toast_hidden_while_*_open), since between rolls it is hidden anyway.
	local function waitFor(cond)
		local deadline = os.clock() + UiSpec.HiddenWhilePanelOpenWait
		repeat
			frames(1)
		until cond() or os.clock() > deadline
		return cond()
	end
	local elems = {}
	for path in UiSpec.HiddenWhilePanelOpen do
		table.insert(elems, path)
	end
	table.sort(elems)
	setPanels({})
	local shownAtRest = {}
	waitFor(function()
		for _, path in elems do
			local o = findPath(path)
			if o and o:IsA("GuiObject") and path ~= "RollToast/Toast" and not effectivelyVisible(o) then
				return false
			end
		end
		return true
	end)
	for _, path in elems do
		local o = findPath(path)
		shownAtRest[path] = o ~= nil and o:IsA("GuiObject") and effectivelyVisible(o)
		check(res, "hidden_rule_element_present_" .. path, o ~= nil, true, o ~= nil and o:IsA("GuiObject"))
	end
	-- The upgrade entry stays visible at rest.
	for _, path in { "RacerProgression/UpgradeButton" } do
		if UiSpec.HiddenWhilePanelOpen[path] then
			check(res, "shown_with_no_panel_open_" .. path, shownAtRest[path], true, shownAtRest[path] == true)
		end
	end
	for _, panelPath in panels do
		setPanels({ panelPath })
		local function wantHidden(path)
			return hiddenByPanel(path, { panelPath })
		end
		waitFor(function()
			for _, path in elems do
				local o = findPath(path)
				if o and o:IsA("GuiObject") and wantHidden(path) and effectivelyVisible(o) then
					return false
				end
			end
			return true
		end)
		for _, path in elems do
			local o = findPath(path)
			if o and o:IsA("GuiObject") then
				local shown = effectivelyVisible(o)
				if wantHidden(path) then
					check(res, "hidden_while_open_" .. path .. "_" .. panelPath, shown, false, not shown)
				elseif shownAtRest[path] then
					check(res, "still_shown_while_open_" .. path .. "_" .. panelPath, shown, true, shown)
				end
			end
		end
	end
	restore()
end

-- An emphasized roll (RollResult 5th argument true; docs/ROLL_ANIMATION_CONTRACT.md): the view switches to Enlarged
-- at PopIn, the roll plays on the enlarged card at its contract size, the view goes back to Compact (closed, blur
-- off) after Exit because the player did not open it, and the roll is announced to everyone in RBXGeneral.
-- ServerSetup emphasized_next makes the next roll emphasized ('[UITEST] WAIT emphasized_roll').
function S.ui_roll_emphasized(res)
	waitGuis()
	if attr("AutoRoll") ~= true then
		stateMissing(res, "autoroll_on_for_emphasized", "auto_roll_on", "AutoRoll is " .. tostring(attr("AutoRoll")))
		return
	end
	local restore = setPanels({})
	local function find()
		for i = #events.recs, 1, -1 do
			if events.recs[i].ev.emphasized then
				return events.recs[i]
			end
		end
		return nil
	end
	local rec = find()
	if not rec then
		player:SetAttribute("UiTestWaiting", "emphasized_roll")
		print(
			("[UITEST] WAIT emphasized_roll up to %d s (run ServerSetup emphasized_next now)"):format(
				UiSpec.Waits.EmphasizedRoll
			)
		)
		local deadline = os.clock() + UiSpec.Waits.EmphasizedRoll
		while not rec and os.clock() < deadline do
			task.wait(0.1)
			rec = find()
		end
		player:SetAttribute("UiTestWaiting", nil)
	end
	if not rec then
		stateMissing(res, "emphasized_roll_received", "emphasized_next", "no RollResult with emphasized == true")
		restore()
		return
	end
	local ev = rec.ev
	local spec = CarCatalog.Get(ev.id)
	local deadline = os.clock() + durationFor(rarityOf(ev.id), true) + 5
	while not rec.done and os.clock() < deadline do
		task.wait(0.1)
	end
	check(res, "emphasized_roll_is_new", ev.isNew == true, true, ev.isNew == true)

	-- Switches to Enlarged at PopIn (already Enlarged when the enlarged card spins)
	local sp = rec.spin.Enlarged
	check(
		res,
		"emphasized_view_enlarged_at_popin",
		sp and tostring(sp.view) or "enlarged card never reached Spin",
		"Enlarged",
		sp ~= nil and sp.view == "Enlarged"
	)
	phaseChecks(res, rec, "Enlarged", "emphasized_")
	local hold = rec.hold.Enlarged
	if hold then
		check(res, "emphasized_view_open_at_hold", hold.showcase, "open", hold.showcase == "open")
		check(res, "emphasized_blur_on_at_hold", hold.blur, "enabled", hold.blur == "enabled")
		check(res, "emphasized_compact_hidden", hold.toastShown, false, hold.toastShown == false)
		check(res, "emphasized_roll_id", tostring(hold.rollId), ev.id, hold.rollId == ev.id)
		checkList(res, "emphasized_card_matches_roll", settledProblems(rec, hold))
		enlargedLookChecks(res, "emphasized_", hold)
		check(
			res,
			"emphasized_card_at_contract_size",
			rstr(hold.real),
			rstr(hold.nominal),
			sameRect(hold.real, hold.nominal)
		)
	else
		check(res, "emphasized_card_sampled_at_hold", "no Hold on RollShowcase/Card", "Hold", false)
	end
	-- The enlarged card does not shrink at Exit (only the compact one does)
	local minExit = math.huge
	for _, s in rec.ratios do
		if s.phase == "Exit" then
			minExit = math.min(minExit, s.r)
		end
	end
	check(
		res,
		"emphasized_card_not_shrunk_on_exit",
		minExit == math.huge and "no Exit sample" or minExit,
		">= " .. (1 - UiSpec.RollAnim.SettledTolerance),
		minExit ~= math.huge and minExit >= 1 - UiSpec.RollAnim.SettledTolerance
	)
	-- Back to Compact SWITCH (+ grace) after Exit: view closed, blur off
	local after = rec.after
	check(
		res,
		"emphasized_back_to_compact",
		after and tostring(after.view) or "no sample after Idle",
		"Compact",
		after ~= nil and after.view == "Compact"
	)
	check(
		res,
		"emphasized_view_closed_after",
		after and after.showcase or "no sample after Idle",
		"closed",
		after ~= nil and after.showcase == "closed"
	)
	check(
		res,
		"emphasized_blur_off_after",
		after and after.blur or "no sample after Idle",
		"disabled",
		after ~= nil and after.blur == "disabled"
	)

	-- Global announcement: Remotes.RollAnnounce(userId, displayName, id, rolls) and the RBXGeneral system message
	local function findAnnounce()
		for _, a in events.announces do
			if a.id == ev.id and a.t >= ev.t - 1 and a.t <= ev.t + UiSpec.Waits.AnnounceWait then
				return a
			end
		end
		return nil
	end
	local wait = ev.t + UiSpec.Waits.AnnounceWait
	local ann = findAnnounce()
	while not ann and os.clock() < wait do
		task.wait(0.1)
		ann = findAnnounce()
	end
	check(res, "roll_announce_received", ann ~= nil, true, ann ~= nil)
	if not ann then
		restore()
		return
	end
	local wantRolls = type(ev.rolls) == "number" and ev.rolls or attr("Rolls")
	local argsOk = ann.userId == player.UserId
		and ann.displayName == player.DisplayName
		and ann.id == ev.id
		and ann.rolls == wantRolls
	check(
		res,
		"roll_announce_args",
		("%s,%s,%s,%s"):format(tostring(ann.userId), tostring(ann.displayName), tostring(ann.id), tostring(ann.rolls)),
		("%d,%s,%s,%s"):format(player.UserId, player.DisplayName, ev.id, tostring(wantRolls)),
		argsOk
	)
	local odds = HudFormat.Odds(spec and spec.Chance)
	local want = UiSpec.Announce.Format:format(
		player.DisplayName,
		spec and spec.Name or tostring(ev.id),
		odds,
		tonumber(ann.rolls) or 0
	)
	local function findChat()
		for _, m in events.chat do
			local plain = string.gsub(m.text or "", "<[^>]+>", "")
			if m.t >= ann.t - 0.5 and plain == want then
				return m
			end
		end
		return nil
	end
	local msg = findChat()
	wait = ann.t + UiSpec.Waits.AnnounceWait
	while not msg and os.clock() < wait do
		task.wait(0.1)
		msg = findChat()
	end
	local seen = {}
	for _, m in events.chat do
		if m.t >= ann.t - 0.5 then
			table.insert(seen, (string.gsub(m.text or "", "<[^>]+>", "")))
		end
	end
	check(
		res,
		"roll_announce_chat_message",
		msg and msg.text or (#seen > 0 and table.concat(seen, " | ") or "none"),
		want,
		msg ~= nil
	)
	if msg then
		check(
			res,
			"roll_announce_in_general_as_system",
			("%s system=%s"):format(msg.channel, tostring(msg.system)),
			UiSpec.Announce.Channel .. " system=true",
			msg.channel == UiSpec.Announce.Channel and msg.system == true
		)
	end
	restore()
end

-- Progression scenarios reuse the same geometry provider and limits as the existing suite.
local Progression = require(script.Parent.UiProgression)
local progressionChecks = Progression.Build({
	check = check,
	find = findPath,
	frames = frames,
	text = allText,
	visible = effectivelyVisible,
	provider = provider,
	rect = realRect,
	contains = contains,
	intersects = intersects,
	setPanels = setPanels,
	top = topAt,
	centre = centre,
	player = player,
})
for name, fn in progressionChecks do
	S[name] = fn
end

-- The UiSpec.Clicks entries marked Manual (owner decision 2026-10-08), in order.
function UiScenarios.ManualClicks()
	local list = {}
	for _, c in UiSpec.Clicks do
		if c.Manual then
			table.insert(list, c)
		end
	end
	return list
end

-- The UiSpec.ManualScenarios entries ({ Name, Manual }), in order.
function UiScenarios.ManualScenarios()
	return UiSpec.ManualScenarios or {}
end

function UiScenarios.Run(name)
	local res = newResult(name)
	local fn = S[name]
	if not fn then
		check(res, "scenario_exists", name, "known", false)
		return res
	end
	fn(res)
	for _, m in UiScenarios.ManualScenarios() do
		if m.Name == name then
			res.manual = m.Manual -- run by hand (UiSpec.ManualScenarios): same checks, marked as the manual one
		end
	end
	return res
end

---------------------------------------------------------------------------------------------------------------
-- Click protocol (see UiSpec.Clicks)

local function readSpy()
	local folder = ReplicatedStorage:FindFirstChild("UiTestSpy")
	if not folder then
		return nil
	end
	local log = {}
	for name, raw in folder:GetAttributes() do
		local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
		log[name] = {}
		if ok and type(list) == "table" then
			for _, entry in list do
				if entry.user == player.UserId then
					table.insert(log[name], entry.args or {})
				end
			end
		end
	end
	return log
end

local function attrSnapshot()
	local snap = {
		AutoRacing = attr("AutoRacing") == true,
		AutoRoll = attr("AutoRoll") == true,
		ReduceEffects = attr("ReduceEffects") == true,
		TopDownView = attr("TopDownView") == true,
		EquippedCar = attr("EquippedCar"),
		StatPoints = attr("StatPoints") or 0,
		WorkshopLevel = attr("WorkshopLevel"),
		ProgressionMoney = player:FindFirstChild("leaderstats") and player.leaderstats.Money.Value,
		ProgressionOwned = player:FindFirstChild("Upgrades") and #player.Upgrades:GetChildren() or 0,
	}
	for _, stat in GachaConfig.STATS do
		snap["Alloc_" .. stat] = attr("Alloc_" .. stat) or 0
	end
	return snap
end

-- Shown to the player: visible and drawing something not faded out (the compact card has no text of its own).
local function shownNow(obj)
	return effectivelyVisible(obj) and drawsSomething(obj)
end

-- The compact card is fully popped in (its click point is on it) once it spins, lands or holds.
local POPPED = { Spin = true, Land = true, Hold = true }
local function poppedIn(obj)
	local phase = obj:GetAttribute("Phase")
	return phase == nil or POPPED[phase] == true
end

-- Remotes fired between two spy readings, in order.
local function firedSince(preSpy)
	local fired = {}
	for name, list in readSpy() or {} do
		local before = preSpy[name] and #preSpy[name] or 0
		for i = before + 1, #list do
			table.insert(fired, { name = name, args = list[i] })
		end
	end
	return fired
end

-- A key press from UiSpec.Clicks (Key = "Escape", ...), other than the workshop E prompt (Progression.RunInput).
-- A LocalScript can not send a key (VirtualInputManager needs plugin security), so ui-tester presses it (KEY
-- protocol in UiSpec.Clicks). Prepare is honoured like a click (AttrIs / AttrNot / Showcase are required, Open /
-- Closed panels are set); the harness records the REAL InputBegan for that key, then checks Expect exactly: every
-- panel is as Expect.Panels says (the rest unchanged), the showcase is untouched unless Expect.Showcase says
-- otherwise, and exactly the Expect.Remote call (or none) went to the server.
local function runKey(spec, res)
	waitGuis()
	local prep = spec.Prepare or {}
	local index = table.find(UiSpec.Clicks, spec)
	local previous = index and index > 1 and ("click:" .. UiSpec.Clicks[index - 1].Id) or "none"
	for name, want in prep.AttrIs or {} do
		if attr(name) ~= want then
			stateMissing(
				res,
				"attribute_before_key_" .. name,
				previous,
				("%s is %s, want %s"):format(name, tostring(attr(name)), tostring(want))
			)
			return res
		end
	end
	for name, forbidden in prep.AttrNot or {} do
		if attr(name) == forbidden then
			stateMissing(
				res,
				"attribute_not_before_key_" .. name,
				previous,
				("%s is %s, must not be %s"):format(name, tostring(attr(name)), tostring(forbidden))
			)
			return res
		end
	end
	local preShowcase = showcaseState()
	if prep.Showcase ~= nil then
		local want = prep.Showcase and "open" or "closed"
		if preShowcase ~= want and not (want == "closed" and preShowcase == "missing") then
			stateMissing(res, "showcase_state_before_key", previous, "showcase is " .. preShowcase .. ", want " .. want)
			return res
		end
	end

	local saved = {}
	for _, p in allPanels() do
		local o = findPath(p)
		if o then
			saved[o] = o.Visible
			if table.find(prep.Open or {}, p) then
				o.Visible = true
			elseif table.find(prep.Closed or {}, p) then
				o.Visible = false
			end
		end
	end
	local function restore()
		for o, v in saved do
			o.Visible = v
		end
	end
	frames(2)
	if prep.WaitSeconds then
		task.wait(prep.WaitSeconds)
	end
	-- The prepared panel really is open before the key (else the check below would prove nothing)
	for _, p in prep.Open or {} do
		local o = findPath(p)
		check(res, "prepared_open_" .. p, o and o.Visible, true, o ~= nil and o.Visible == true)
	end
	local preSpy = readSpy()
	if not preSpy then
		stateMissing(res, "spy_installed", "spy", "ReplicatedStorage.UiTestSpy missing")
		restore()
		return res
	end
	local prePanels = {}
	for _, p in allPanels() do
		local o = findPath(p)
		prePanels[p] = o and o.Visible
	end

	local pressed, consumed = false, nil
	local conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not pressed and input.KeyCode.Name == spec.Key then
			pressed, consumed = true, gameProcessed
		end
	end)
	ReplicatedStorage:SetAttribute("UiTestClickDone", nil)
	player:SetAttribute("UiTestClickTarget", HttpService:JSONEncode({ id = spec.Id, key = spec.Key, done = spec.Id }))
	print("[UITEST] KEY " .. spec.Id .. " key=" .. spec.Key .. " done=" .. spec.Id)
	local deadline = os.clock() + UiSpec.Waits.ClickDone
	while ReplicatedStorage:GetAttribute("UiTestClickDone") ~= spec.Id and os.clock() < deadline do
		task.wait(0.05)
	end
	conn:Disconnect()
	player:SetAttribute("UiTestClickTarget", nil)
	local done = ReplicatedStorage:GetAttribute("UiTestClickDone") == spec.Id
	local menuOpen = GuiService.MenuIsOpen
	check(res, "key_performed", done, true, done)
	-- consumed = gameProcessedEvent (true when Roblox's own UI took the key); menu = GuiService.MenuIsOpen at the
	-- acknowledgement (ui-tester closes Roblox's menu before acknowledging). Both are info for a failing panel check.
	check(
		res,
		"key_pressed_" .. string.lower(spec.Key),
		pressed and ("pressed consumed=%s menu=%s"):format(tostring(consumed), tostring(menuOpen)) or "no InputBegan",
		"pressed",
		pressed
	)
	if not done then
		restore()
		return res
	end
	task.wait(UiSpec.Waits.ClickSettle)
	frames(2)

	local expect = spec.Expect
	for _, p in allPanels() do
		local o = findPath(p)
		local want = prePanels[p]
		if expect.Panels and expect.Panels[p] ~= nil then
			want = expect.Panels[p]
		end
		check(res, "panel_" .. p, o and o.Visible, want, o ~= nil and o.Visible == want)
	end
	local wantShowcase = preShowcase
	if expect.Showcase ~= nil then
		wantShowcase = expect.Showcase and "open" or "closed"
	end
	local nowShowcase = showcaseState()
	check(res, "showcase_after_key", nowShowcase, wantShowcase, nowShowcase == wantShowcase)
	local fired = firedSince(preSpy)
	local names = {}
	for _, f in fired do
		table.insert(names, f.name)
	end
	local got = #names > 0 and table.concat(names, ",") or "nothing"
	if expect.Remote then
		check(
			res,
			"fires_" .. expect.Remote.Name,
			got,
			expect.Remote.Name,
			#fired == 1 and fired[1].name == expect.Remote.Name
		)
	else
		check(res, "fires_nothing", got, "nothing", #fired == 0)
	end
	restore()
	return res
end

function UiScenarios.RunClick(id)
	local spec = nil
	for _, c in UiSpec.Clicks do
		if c.Id == id then
			spec = c
		end
	end
	local res = newResult("click:" .. tostring(id))
	if not spec then
		check(res, "click_declared", id, "UiSpec.Clicks id", false)
		return res
	end
	-- A MANUAL check (UiSpec.Clicks Manual) run by hand: same checks; the result says it is the manual one
	res.manual = spec.Manual
	if spec.Key and spec.Expect.WorkshopOpen == nil then
		return runKey(spec, res)
	elseif spec.Key then
		-- The workshop E prompt contracts (Expect.WorkshopOpen) keep their own fixture-checked runner
		return Progression.RunInput(spec, res, {
			check = check,
			find = findPath,
			frames = frames,
			player = player,
			setPanels = setPanels,
			allPanels = allPanels,
		})
	end
	waitGuis()
	local prep = spec.Prepare or {}
	local index = table.find(UiSpec.Clicks, spec)
	local previous = index and index > 1 and ("click:" .. UiSpec.Clicks[index - 1].Id) or "none"

	-- Player attributes this click starts from (set by earlier clicks or ServerSetup, never forced here)
	for name, want in prep.AttrIs or {} do
		if attr(name) ~= want then
			stateMissing(
				res,
				"attribute_before_click_" .. name,
				previous,
				("%s is %s, want %s"):format(name, tostring(attr(name)), tostring(want))
			)
			return res
		end
	end
	for name, forbidden in prep.AttrNot or {} do
		if attr(name) == forbidden then
			stateMissing(
				res,
				"attribute_not_before_click_" .. name,
				previous,
				("%s is %s, must not be %s"):format(name, tostring(attr(name)), tostring(forbidden))
			)
			return res
		end
	end

	-- The showcase is never forced: it must already be in the state this click starts from
	local preShowcase = showcaseState()
	if prep.Showcase ~= nil then
		local want = prep.Showcase and "open" or "closed"
		-- A missing showcase gui counts as closed here (ui_showcase / ui_inventory fail on it)
		if preShowcase ~= want and not (want == "closed" and preShowcase == "missing") then
			stateMissing(
				res,
				"showcase_state_before_click",
				previous,
				"showcase is " .. preShowcase .. ", want " .. want
			)
			return res
		end
	end

	-- Resolve the target (tile tokens)
	local tileId = nil
	local path = spec.Path
	local equipped = attr("EquippedCar")
	if string.find(path, "{discovered_unequipped}", 1, true) then
		for _, car in CarCatalog.All() do
			if not tileId and owned(car.Id) and car.Id ~= equipped then
				tileId = car.Id
			end
		end
		if not tileId then
			stateMissing(res, "target_tile", "index_states", "no owned, unequipped catalog car")
			return res
		end
		path = string.gsub(path, "{discovered_unequipped}", tileId)
	elseif string.find(path, "{equipped}", 1, true) then
		if not (CarCatalog.Get(equipped) and CarCatalog.Get(equipped).Rollable) then
			stateMissing(res, "target_tile", "index_states", "equipped car is " .. tostring(equipped))
			return res
		end
		tileId = equipped
		path = string.gsub(path, "{equipped}", tileId)
	end
	local rowStat = spec.Gui == "RacerStats" and splitPath(path)[5] or nil
	local upgradeId = spec.Gui == "RacerUpgrades" and splitPath(path)[3] or nil
	local button = findPath(spec.Gui .. "/" .. path)
	if not button and spec.Gui == UiSpec.Showcase.Gui and #splitPath(path) == 1 then
		local sg = playerGui:FindFirstChild(spec.Gui)
		button = sg and sg:FindFirstChild(path, true) -- the card may sit inside the backdrop
	end
	check(res, "target_exists", spec.Gui .. "/" .. path, "present", button ~= nil)
	if not button then
		return res
	end

	-- Prepare panels and scroll
	local saved = {}
	for _, p in allPanels() do
		local o = findPath(p)
		if o then
			saved[o] = o.Visible
			if table.find(prep.Open or {}, p) then
				o.Visible = true
			elseif table.find(prep.Closed or {}, p) then
				o.Visible = false
			end
		end
	end
	local grid = upgradeId and findPath("RacerUpgrades/Panel/Canvas")
		or findPath("RacerIndex/Panel/Face/GridHost/Gallery")
	local savedCanvas = grid and grid.CanvasPosition
	local probe = nil
	frames(2)
	if tileId and grid then
		local tile = findPath("RacerIndex/Panel/Face/GridHost/Gallery/" .. tileId)
		local rel = tile.AbsolutePosition.Y - grid.AbsolutePosition.Y + grid.CanvasPosition.Y
		grid.CanvasPosition = Vector2.new(0, math.max(0, rel - 8))
		frames(2)
	end
	if upgradeId and grid and grid:IsA("ScrollingFrame") then
		local rel = button.AbsolutePosition - grid.AbsolutePosition + grid.CanvasPosition
		grid.CanvasPosition = Vector2.new(math.max(0, rel.X - 8), math.max(0, rel.Y - 8))
		frames(2)
	end
	local function restore()
		for o, v in saved do
			o.Visible = v
		end
		if grid and savedCanvas then
			grid.CanvasPosition = savedCanvas
		end
		if probe then
			probe:Destroy()
			probe = nil
		end
	end
	if prep.WaitSeconds then
		task.wait(prep.WaitSeconds)
	end
	if prep.LabelIs ~= nil then
		local actual = allText(button)
		if actual ~= prep.LabelIs then
			stateMissing(
				res,
				"label_before_click",
				previous,
				("%s shows %q, want %q"):format(pathOf(button), actual, prep.LabelIs)
			)
			return res
		end
	end
	local preSpy = readSpy()
	if not preSpy then
		stateMissing(res, "spy_installed", "spy", "ReplicatedStorage.UiTestSpy missing")
		restore()
		return res
	end
	if spec.Expect.Remote and table.find(UiSpec.RemoteFunctions, spec.Expect.Remote.Name) then
		local spyFolder = ReplicatedStorage:FindFirstChild("UiTestSpy")
		local remote = ReplicatedStorage.Remotes:FindFirstChild(spec.Expect.Remote.Name)
		local ready = spyFolder
			and spyFolder:GetAttribute("ProgressionIntercepted") == true
			and remote
			and remote:GetAttribute("UiTestIntercepted") == true
		check(res, "purchase_intercepted_before_click", ready, true, ready == true)
		if not ready then
			restore()
			return res
		end
	end

	-- Where to click: the target's centre, a corner, or another element's centre (the target must be topmost there)
	local function clickPoint()
		if spec.ClickAt == "corner" then
			local vp = viewport()
			local ci = UiSpec.Showcase.CornerInset
			return vp.X - ci, vp.Y - ci
		elseif type(spec.ClickAt) == "string" then
			local o = findPath(spec.ClickAt)
			if o then
				return centre(realRect(o))
			end
			return nil
		end
		return centre(realRect(button))
	end

	local attempts = 1 + (spec.Retries or 0)
	local pre, prePanels, done, press, cx, cy = nil, nil, false, nil, nil, nil
	local clickedAt = nil
	for attempt = 1, attempts do
		-- Wait for a fresh show of the target (the toast only shows after a RollResult, for ~1.6 s)
		if prep.WaitShown then
			local shown = false
			if waitNewRoll(UiSpec.Waits.RollToast) then
				local deadline = os.clock() + UiSpec.Waits.ToastShown
				repeat
					renderFrame()
					shown = shownNow(button) and poppedIn(button)
				until shown or os.clock() > deadline
			end
			if not shown then
				check(
					res,
					"target_shown_before_click",
					"not shown",
					("shown within %.1f s of a RollResult"):format(UiSpec.Waits.ToastShown),
					false
				)
				restore()
				return res
			end
		end

		if prep.RequireShown and not shownNow(button) then
			stateMissing(res, "target_shown_before_click", previous, pathOf(button) .. " is not shown")
			restore()
			return res
		end
		pre = attrSnapshot()
		if prep.SoundProbe and not probe then
			probe = Instance.new("Sound")
			probe.Name = "UiTestSoundProbe"
			probe.Volume = UiSpec.Settings.ProbeVolume
			probe.Parent = SoundService
		end
		prePanels = {}
		for _, p in allPanels() do
			local o = findPath(p)
			prePanels[p] = o and o.Visible
		end
		cx, cy = clickPoint()
		if not cx then
			check(res, "click_point_exists", spec.ClickAt, "present", false)
			restore()
			return res
		end
		local top = topAt(cx, cy)
		local lands = top ~= nil and (top == button or button:IsAncestorOf(top))
		if attempt == attempts or lands then
			check(res, "target_topmost_before_click", top and pathOf(top) or "nothing", pathOf(button), lands)
		end

		-- Where the click really lands: recorded at the press (before Activated changes anything), in screen
		-- pixels. InputObject.Position is below the top bar, so the inset is added back.
		press = nil
		local pressConn = UserInputService.InputBegan:Connect(function(input)
			if
				not press
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				local tl = inset()
				local px, py = input.Position.X + tl.X, input.Position.Y + tl.Y
				press = { x = px, y = py, hit = topAt(px, py), targetShown = shownNow(button), t = os.clock() }
			end
		end)

		local doneValue = attempt == 1 and id or (id .. "#" .. attempt)
		ReplicatedStorage:SetAttribute("UiTestClickDone", nil)
		-- Published in user_mouse_input's space (see UiSpec.ClickSpace): screen pixels minus the top-bar inset
		local tl = inset()
		local tx, ty = math.floor(cx - tl.X + 0.5), math.floor(cy - tl.Y + 0.5)
		player:SetAttribute(
			"UiTestClickTarget",
			HttpService:JSONEncode({
				id = id,
				x = tx,
				y = ty,
				screenX = math.floor(cx + 0.5),
				screenY = math.floor(cy + 0.5),
				-- The space x, y were computed in (UiSpec.ClickNeedsUnemulatedView): ui-tester checks it first
				viewportX = math.floor(viewport().X + 0.5),
				viewportY = math.floor(viewport().Y + 0.5),
				insetY = math.floor(tl.Y + 0.5),
				done = doneValue,
			})
		)
		print(("[UITEST] %s %s x=%d y=%d done=%s"):format(attempt == 1 and "CLICK" or "RETRY", id, tx, ty, doneValue))
		local deadline = os.clock() + UiSpec.Waits.ClickDone
		while ReplicatedStorage:GetAttribute("UiTestClickDone") ~= doneValue and os.clock() < deadline do
			task.wait(0.1)
		end
		done = ReplicatedStorage:GetAttribute("UiTestClickDone") == doneValue
		player:SetAttribute("UiTestClickTarget", nil)
		pressConn:Disconnect()
		-- Retry only a click that came too late for a fading target and hit nothing else
		local missedFade = done and press ~= nil and press.hit == nil and press.targetShown == false
		if not (missedFade and attempt < attempts) then
			break
		end
		task.wait(UiSpec.Waits.ClickSettle) -- nothing happened; let the view settle before the next try
	end
	check(res, "click_performed", done, true, done)
	-- When the click happened: the press if it was seen, else now (the done acknowledgement)
	clickedAt = press and press.t or os.clock()
	if done then
		if press then
			local landed = press.hit ~= nil and (press.hit == button or button:IsAncestorOf(press.hit))
			check(
				res,
				"click_landed_on_button",
				("(%d,%d) %s"):format(
					math.floor(press.x + 0.5),
					math.floor(press.y + 0.5),
					press.hit and pathOf(press.hit) or "nothing"
				),
				pathOf(button),
				landed
			)
		else
			-- No press event seen: fall back to the mouse position now (GetMouseLocation includes the top bar)
			local m = UserInputService:GetMouseLocation()
			local near = math.abs(m.X - cx) <= UiSpec.MaxHitboxPadding and math.abs(m.Y - cy) <= UiSpec.MaxHitboxPadding
			check(
				res,
				"click_landed_on_button",
				("mouse (%d,%d) no press seen"):format(math.floor(m.X), math.floor(m.Y)),
				("(%d,%d)"):format(math.floor(cx + 0.5), math.floor(cy + 0.5)),
				near
			)
		end
	end
	if not done then
		restore()
		return res
	end
	task.wait(UiSpec.Waits.ClickSettle)
	frames(2)

	local expect = spec.Expect
	-- Panels: exactly the expected ones changed
	for _, p in allPanels() do
		local o = findPath(p)
		local want = prePanels[p]
		if expect.Panels and expect.Panels[p] ~= nil then
			want = expect.Panels[p]
		end
		check(res, "panel_" .. p, o and o.Visible, want, o ~= nil and o.Visible == want)
	end
	-- Showcase: opened / closed as promised, otherwise untouched
	local wantShowcase = preShowcase
	if expect.Showcase ~= nil then
		wantShowcase = expect.Showcase and "open" or "closed"
	end
	local nowShowcase = showcaseState()
	check(res, "showcase_after_click", nowShowcase, wantShowcase, nowShowcase == wantShowcase)

	-- Remotes: exactly the promised call, or none
	local postSpy = readSpy() or {}
	local fired = {}
	for name, list in postSpy do
		local before = preSpy[name] and #preSpy[name] or 0
		for i = before + 1, #list do
			table.insert(fired, { name = name, args = list[i] })
		end
	end
	local wantArg = nil
	if expect.Remote then
		local argSpec = expect.Remote.Arg
		if type(argSpec) == "string" and string.sub(argSpec, 1, 9) == "not_attr:" then
			wantArg = not (pre[string.sub(argSpec, 10)] == true)
		elseif argSpec == "tile_id" then
			wantArg = tileId
		elseif argSpec == "row_stat" then
			wantArg = rowStat
		elseif argSpec == "upgrade_id" then
			wantArg = upgradeId
		end
		local names = {}
		for _, f in fired do
			table.insert(names, f.name .. "(" .. tostring(f.args[1]) .. ")")
		end
		local want = expect.Remote.Name .. "(" .. tostring(wantArg) .. ")"
		local ok = #fired == 1 and fired[1].name == expect.Remote.Name and fired[1].args[1] == wantArg
		if ok and (expect.Remote.Arg == "upgrade_id" or expect.Remote.Arg == "none") then
			ok = #fired[1].args == (expect.Remote.Arg == "none" and 0 or 1)
		end
		check(res, "fires_" .. expect.Remote.Name, #names > 0 and table.concat(names, ",") or "nothing", want, ok)
	else
		local names = {}
		for _, f in fired do
			table.insert(names, f.name)
		end
		check(res, "fires_nothing", #names > 0 and table.concat(names, ",") or "nothing", "nothing", #fired == 0)
	end

	-- Post-conditions
	local toast = findPath("RollToast/Toast")
	for _, cond in expect.After or {} do
		if cond == "progression_not_optimistic" then
			local now = attrSnapshot()
			for _, key in { "WorkshopLevel", "ProgressionMoney", "ProgressionOwned" } do
				check(res, "unchanged_" .. string.lower(key), now[key], pre[key], now[key] == pre[key])
			end
		elseif cond == "workshop_rejection_shown" then
			local result = findPath("RacerWorkshop/Panel/Result")
			local text = result and allText(result) or ""
			check(res, cond, text, "server rejection money", string.find(string.lower(text), "money", 1, true) ~= nil)
		elseif cond == "autorace_label_follows_server" then
			local want = HudFormat.AutoButtonText(attr("AutoRacing") == true)
			check(res, cond, allText(button), want, allText(button) == want)
		elseif cond == "autoracing_is_arg" then
			check(res, cond, attr("AutoRacing") == true, wantArg, (attr("AutoRacing") == true) == wantArg)
		elseif cond == "sound_label_off" or cond == "sound_label_on" then
			local want = cond == "sound_label_off" and "OFF" or "ON"
			local actual = allText(button)
			check(res, cond, actual, want, actual == want)
		elseif cond == "sound_probe_muted" or cond == "sound_probe_restored" then
			local want = cond == "sound_probe_muted" and 0 or UiSpec.Settings.ProbeVolume
			local actual = probe and probe.Volume
			check(res, cond, actual, want, actual ~= nil and math.abs(actual - want) <= 0.001)
		elseif cond == "reduce_effects_flipped" then
			local want = not pre.ReduceEffects
			check(res, cond, attr("ReduceEffects"), want, attr("ReduceEffects") == want)
		elseif cond == "effects_label_follows_attr" then
			local want = attr("ReduceEffects") == true and "ON" or "OFF"
			local actual = allText(button)
			check(res, cond, actual, want, actual == want)
		elseif cond == "top_down_flipped" then
			local want = not pre.TopDownView
			check(res, cond, attr("TopDownView"), want, attr("TopDownView") == want)
		elseif cond == "top_down_label_follows_attr" then
			local want = attr("TopDownView") == true and "ON" or "OFF"
			local actual = allText(button)
			check(res, cond, actual, want, actual == want)
		elseif cond == "equipped_is_tile" then
			check(res, cond, attr("EquippedCar"), tileId, attr("EquippedCar") == tileId)
		elseif cond == "tile_shows_equipped" then
			local e = findPath("RacerIndex/Panel/Face/GridHost/Gallery/" .. tileId .. "/Equip")
			local label = e and e:FindFirstChild("Label")
			check(
				res,
				cond,
				label and label.Text,
				"EQUIPPED",
				e ~= nil and label ~= nil and label.Text == "EQUIPPED" and e.Active == false
			)
		elseif cond == "alloc_incremented" then
			local k = "Alloc_" .. rowStat
			check(res, cond, attr(k) or 0, pre[k] + 1, (attr(k) or 0) == pre[k] + 1)
		elseif cond == "points_decremented" then
			check(
				res,
				cond,
				attr("StatPoints") or 0,
				pre.StatPoints - 1,
				(attr("StatPoints") or 0) == pre.StatPoints - 1
			)
		elseif cond == "points_label_follows_server" then
			-- The header read-out follows the server's StatPoints (after the answer), with the declared wording
			local statsSpec = UiSpec.Guis.RacerStats
			local n = attr("StatPoints") or 0
			local want = ((n == 1) and statsSpec.PointsText.Singular or statsSpec.PointsText.Plural):format(n)
			local label = findPath(statsSpec.PointsLabel)
			local text = label and (label:IsA("TextLabel") or label:IsA("TextButton")) and label.Text or "missing"
			check(res, cond, text, want, text == want and label ~= nil and effectivelyVisible(label))
		elseif cond == "alloc_unchanged" then
			local k = "Alloc_" .. rowStat
			check(res, cond, attr(k) or 0, pre[k], (attr(k) or 0) == pre[k])
		elseif cond == "points_unchanged" then
			check(res, cond, attr("StatPoints") or 0, pre.StatPoints, (attr("StatPoints") or 0) == pre.StatPoints)
		elseif cond == "row_shows_alloc" then
			local v = findPath("RacerStats/Panel/Face/StatsHost/Rows/" .. rowStat .. "/Value")
			local n = attr("Alloc_" .. rowStat) or 0
			local a = {}
			for _, stat in GachaConfig.STATS do
				a[stat] = attr("Alloc_" .. stat) or 0
			end
			local multi = ("x%.2f"):format(GachaConfig.Multis(a)[rowStat])
			check(
				res,
				cond,
				v and v.Text,
				("%d pts %s"):format(n, multi),
				v ~= nil and hasNumber(v.Text, n) and string.find(v.Text, multi, 1, true) ~= nil
			)
		elseif cond == "showcase_card_is_latest_roll" then
			-- Opens on the latest roll (or a newer one that arrived during the settle: it updates live), checked
			-- once the enlarged card has landed (Hold) or rests (Idle)
			local _, _, card = showcaseParts()
			local settled = waitCardPhase(card, SETTLED, UiSpec.Waits.CardSettle)
			check(res, "showcase_card_settled", settled, true, settled)
			checkList(res, cond, showcaseCardProblems(events.rolls[#events.rolls]))
		elseif cond == "showcase_blur_on" then
			local b = blurState()
			check(res, cond, b, "enabled", b == "enabled")
		elseif cond == "showcase_blur_off" then
			local b = blurState()
			check(res, cond, b, "disabled", b == "disabled")
		elseif cond == "showcase_layout" then
			local gui, backdrop, card = showcaseParts()
			-- The card animates (SWITCH, PopIn, LAND_POP): measure it landed (Hold) or resting (Idle)
			waitCardPhase(card, SETTLED, UiSpec.Waits.CardSettle)
			local vp = viewport()
			local full = R(0, 0, vp.X, vp.Y)
			local br = backdrop and realRect(backdrop)
			check(
				res,
				"showcase_backdrop_full_screen",
				br and rstr(br) or "missing",
				rstr(full),
				br ~= nil and contains(br, full)
			)
			if card and card:IsA("GuiObject") then
				local cr = realRect(card)
				local root = rootRect(gui, vp)
				local ccx, ccy = centre(cr)
				local mx = centre(root)
				local d =
					math.max(math.abs(ccx - mx), math.abs(ccy - (root.y + root.h * UiSpec.Showcase.CardCentreScale)))
				check(res, "showcase_card_centred", d, TOL, d <= TOL)
				check(res, "showcase_card_inside_viewport", rstr(cr), rstr(full), contains(full, cr))
				-- The live enlarged card at its contract rect at every viewport and in the engine
				checkList(res, "showcase_card_at_contract_rect", liveVsNominal(card))
				local top = topAt(ccx, ccy)
				check(
					res,
					"showcase_card_topmost_at_centre",
					top and pathOf(top) or "nothing",
					pathOf(card),
					top ~= nil and (top == card or card:IsAncestorOf(top))
				)
			else
				check(res, "showcase_card_centred", "missing", "present", false)
			end
			local ci = UiSpec.Showcase.CornerInset
			local top = topAt(vp.X - ci, vp.Y - ci)
			check(
				res,
				"showcase_backdrop_topmost_at_corner",
				top and pathOf(top) or "nothing",
				backdrop and pathOf(backdrop) or "Backdrop",
				backdrop ~= nil and top == backdrop
			)
			local auto = gui and gui:FindFirstChild(UiSpec.Showcase.AutoButton.Path)
			local atop = auto and auto:IsA("GuiObject") and topAt(centre(realRect(auto)))
			check(
				res,
				"showcase_autobutton_topmost",
				atop and pathOf(atop) or "nothing",
				auto and pathOf(auto) or "RollShowcase/AutoButton",
				atop ~= nil and atop ~= false and (atop == auto or auto:IsAncestorOf(atop))
			)
			local hint = backdrop and backdrop:FindFirstChild(UiSpec.Showcase.Hint)
			local hintOk = hint ~= nil
				and hint:IsA("TextLabel")
				and hint.Text == UiSpec.Showcase.HintText
				and effectivelyVisible(hint)
				and hint.TextTransparency < 0.5
			check(
				res,
				"showcase_hint_shown",
				hint and hint:IsA("TextLabel") and hint.Text or "missing",
				UiSpec.Showcase.HintText,
				hintOk
			)
		elseif cond == "showcase_covers_buttons" then
			local gui = playerGui:FindFirstChild(UiSpec.Showcase.Gui)
			checkList(res, cond, gui and coversButtons(gui) or { "no " .. UiSpec.Showcase.Gui })
		elseif cond == "toast_hidden_while_showcase_open" then
			-- At once, and still after the next roll arrives while the showcase is open
			local now = toast ~= nil and not effectivelyVisible(toast)
			check(res, cond .. "_at_once", toast and effectivelyVisible(toast), false, now)
			if waitNewRoll(UiSpec.Waits.RollToast) then
				task.wait(UiSpec.Waits.ToastShown)
				frames(2)
				local later = toast ~= nil and not effectivelyVisible(toast)
				check(res, cond .. "_on_roll", toast and effectivelyVisible(toast), false, later)
			else
				stateMissing(res, cond .. "_on_roll", "auto_racing", "no Remotes.RollResult")
			end
		elseif cond == "showcase_updates_live_turbo" then
			-- The open card plays a TURBO roll that arrives after the click and lands on it, badge and flames shown
			-- from pop-in. turbo_next arms one, but setup + mouse click can take longer than ROLL_INTERVAL, so the
			-- armed roll may land before the click: then the next natural turbo roll (every TURBO_EVERY rolls,
			-- within Waits.TurboRoll) is used. Read from the roll recorder, so a later roll can not hide it.
			local since = clickedAt or os.clock()
			local function turboAfterClick()
				for _, e in events.rolls do
					if e.t >= since and e.turboMulti > 1 then
						return e
					end
				end
				return nil
			end
			local ev = turboAfterClick()
			local deadline = os.clock() + UiSpec.Waits.TurboRoll
			while not ev and os.clock() < deadline do
				task.wait(0.1)
				ev = turboAfterClick()
			end
			if not ev then
				stateMissing(
					res,
					"showcase_live_roll_is_turbo",
					"turbo_next",
					("no turbo RollResult within %d s of the click"):format(UiSpec.Waits.TurboRoll)
				)
			else
				local rec = recFor(ev)
				local landBy = os.clock() + durationFor(rarityOf(ev.id), ev.emphasized) + 1
				while rec and not rec.hold.Enlarged and not rec.done and os.clock() < landBy do
					task.wait(0.05)
				end
				local hold = rec and rec.hold.Enlarged
				check(res, "showcase_live_roll_landed", hold ~= nil, true, hold ~= nil)
				local sp = rec and rec.spin.Enlarged
				local want = "TURBO x" .. fmtNum(turboLuck())
				check(
					res,
					"showcase_turbo_badge_from_popin",
					sp and ("shown=%s flames=%s %q"):format(tostring(sp.badge), tostring(sp.flames), sp.badgeText)
						or "no Spin sample",
					"shown=true flames=true " .. want,
					sp ~= nil
						and sp.badge == true
						and sp.flames == true
						and string.find(sp.badgeText, want, 1, true) ~= nil
				)
				check(
					res,
					"showcase_still_open_on_roll",
					hold and hold.showcase or "no Hold sample",
					"open",
					hold ~= nil and hold.showcase == "open"
				)
				checkList(
					res,
					"showcase_updates_live",
					hold and settledProblems(rec, hold) or { "no Hold sample on RollShowcase/Card" }
				)
				if hold then
					local glowBy = os.clock() + UiSpec.RollAnim.GlowTurnWait + 1
					while hold.glowRot2 == nil and not rec.done and os.clock() < glowBy do
						task.wait(0.05)
					end
					enlargedLookChecks(res, "showcase_", hold)
				end
				check(res, "showcase_live_roll_turbo_multi", ev.turboMulti, turboLuck(), ev.turboMulti == turboLuck())
			end
		elseif cond == "showcase_result_stays_after_exit" then
			-- In the enlarged view the landed result stays (1x, the roll's truth) until the next PopIn
			local _, _, card = showcaseParts()
			local ev = events.rolls[#events.rolls]
			local idle = waitCardPhase(card, { Idle = true }, durationFor(rarityOf(ev and ev.id), false) + 1)
			check(res, "showcase_card_idle_after_exit", idle, true, idle)
			frames(2)
			local st = showcaseState()
			check(res, "showcase_still_open_after_exit", st, "open", st == "open")
			if card and card:IsA("GuiObject") then
				local r, nom = realRect(card), nominalOf(card)
				check(res, "showcase_card_not_shrunk_after_exit", rstr(r), rstr(nom), sameRect(r, nom))
			end
			checkList(res, "showcase_result_shown_after_exit", showcaseCardProblems(ev))
		elseif cond == "view_enlarged" or cond == "view_compact" then
			local want = cond == "view_enlarged" and "Enlarged" or "Compact"
			local gui = playerGui:FindFirstChild("RollToast")
			local v = gui and gui:GetAttribute(UiSpec.RollAnim.ViewAttr)
			check(res, cond, tostring(v), want, v == want)
		elseif cond == "autobutton_label_follows_server" then
			local auto = findPath(UiSpec.Showcase.Gui .. "/" .. UiSpec.Showcase.AutoButton.Path)
			local want = UiSpec.RollAnim.AutoButtonText[attr("AutoRoll") == true]
			local text = auto and auto:IsA("TextButton") and auto.Text or "missing"
			check(res, cond, text, want, text == want)
		elseif cond == "autoroll_is_arg" then
			check(res, cond, attr("AutoRoll") == true, wantArg, (attr("AutoRoll") == true) == wantArg)
		elseif cond == "no_rolls_while_auto_off" then
			local n0, r0 = #events.rolls, attr("Rolls")
			task.wait(GachaConfig.ROLL_INTERVAL + UiSpec.Waits.AutoOffWatch)
			local n1, r1 = #events.rolls, attr("Rolls")
			check(
				res,
				cond,
				("%d RollResult, Rolls %s -> %s"):format(n1 - n0, tostring(r0), tostring(r1)),
				"0 RollResult, Rolls unchanged",
				n1 == n0 and r1 == r0
			)
		elseif cond == "rolls_resume" then
			local ok = waitNewRoll(UiSpec.Waits.RollToast)
			check(res, cond, ok, true, ok)
		elseif cond == "toast_hidden_at_once" then
			check(res, cond, toast and effectivelyVisible(toast), false, toast ~= nil and not effectivelyVisible(toast))
		elseif cond == "toast_shows_auto_off" then
			-- AUTO off: the compact card stays shown at rest, at its contract rect, clickable, with the last result
			-- and the caption "AUTO OFF", and it does not hide when a roll interval passes
			if attr("AutoRoll") ~= false then
				stateMissing(
					res,
					cond,
					"click:showcase_auto_off",
					"AutoRoll is " .. tostring(attr("AutoRoll")) .. ", want false"
				)
				continue
			end
			frames(2)
			local shown = toast ~= nil and shownNow(toast)
			check(res, "toast_shown_while_auto_off", shown, true, shown)
			local text = toast and allText(toast) or ""
			local cap = UiSpec.RollAnim.AutoOffCaption
			check(res, "toast_caption_auto_off", text, "contains " .. cap, string.find(text, cap, 1, true) ~= nil)
			check(
				res,
				"toast_auto_off_caption_shown",
				partShown(toast, UiSpec.Compact.AutoOff),
				true,
				partShown(toast, UiSpec.Compact.AutoOff)
			)
			-- The last result as the compact roll shows it: its model ("?" placeholder) and odds (owner decision 4)
			local last = events.rolls[#events.rolls]
			if last then
				checkList(res, "toast_auto_off_shows_last_result", compactProblems(toast, last))
			else
				local ph = partOf(toast, "Placeholder")
				local ok = ph ~= nil and ph:IsA("TextLabel") and ph.Text == "?" and effectivelyVisible(ph)
				check(res, "toast_auto_off_shows_last_result", ok, 'Placeholder "?" (no roll yet)', ok)
			end
			checkList(res, "toast_auto_off_is_no_card", compactShapeProblems(toast))
			if toast then
				local top = topAt(centre(nominalOf(toast)))
				check(
					res,
					"toast_clickable_while_auto_off",
					top and pathOf(top) or "nothing",
					"RollToast/Toast",
					top ~= nil and (top == toast or toast:IsAncestorOf(top))
				)
				checkList(res, "toast_auto_off_at_contract_rect", liveVsNominal(toast))
			end
			task.wait(GachaConfig.ROLL_INTERVAL + 0.5)
			frames(2)
			local still = toast ~= nil and shownNow(toast)
			check(res, "toast_stays_while_auto_off", still, true, still)
		elseif cond == "hud_hidden_while_showcase_open" then
			-- CLAUDE.md "UI tests": the HUD hides while the roll showcase is open. Pass when its ScreenGui is
			-- disabled, or when nothing in it is effectively visible and drawing (any background, text or image
			-- less than 95 % transparent) and no button in it is shown (so no HUD button can take a press).
			for _, guiName in UiSpec.Showcase.HiddenGuis do
				local gui = playerGui:FindFirstChild(guiName)
				if not (gui and gui:IsA("LayerCollector")) then
					check(res, cond .. "_" .. guiName, "missing", "hidden", false)
					continue
				end
				local shown = {}
				if gui.Enabled then
					for _, d in gui:GetDescendants() do
						if d:IsA("GuiObject") and effectivelyVisible(d) then
							local draws = d.BackgroundTransparency < 0.95
								or d:IsA("GuiButton")
								or ((d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text ~= "" and d.TextTransparency < 0.95)
								or ((d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" and d.ImageTransparency < 0.95)
								or (d:IsA("ViewportFrame") and d.ImageTransparency < 0.95)
							if draws then
								table.insert(shown, pathOf(d))
							end
						end
					end
				end
				checkList(res, cond .. "_" .. guiName, shown)
			end
		elseif cond == "normal_view_back" then
			checkList(res, "normal_view_buttons_clickable", alwaysOnCovered())
			checkList(res, "showcase_not_clickable_after_close", showcaseHits())
		else
			check(res, "unknown_condition_" .. tostring(cond), cond, "known", false)
		end
	end
	restore()
	return res
end

return UiScenarios
