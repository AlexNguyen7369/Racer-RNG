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
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local UiSpec = require(script.Parent:WaitForChild("UiSpec"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudFormat = require(Shared:WaitForChild("HudFormat"))
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local GachaConfig = require(Shared:WaitForChild("GachaConfig"))
local NpcConfig = require(Shared:WaitForChild("NpcConfig"))
local TrackBuilder = require(Shared:WaitForChild("TrackBuilder"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UiScenarios = {}

UiScenarios.Names = {
	"ui_client_rendering",
	"ui_inventory",
	"ui_layout",
	"ui_hitboxes",
	"ui_buttons",
	"ui_hud",
	"ui_index",
	"ui_stats",
	"ui_toast",
	"ui_rolls",
	"ui_showcase",
	"ui_loser",
	"ui_billboards",
	"ui_panels",
}

local TOL = UiSpec.Tolerance
local STATES = {
	{ Name = "rest", Open = {} },
	{ Name = "index_open", Open = { "IndexUi/Panel" } },
	{ Name = "stats_open", Open = { "StatsUi/Panel" } },
	-- Two panels open at once is NOT a reachable state: ui_panels proves the panels are mutually exclusive
	-- through the real mechanism (PanelSwitch) and the Clicks open_*_while_*_open prove it through the buttons.
	-- If exclusivity ever breaks, ui_panels fails, and this state must be added back here.
}
local UNSUPPORTED_LAYOUT = {
	UIListLayout = true,
	UIPadding = true,
	UIAspectRatioConstraint = true,
	UIScale = true,
	UIPageLayout = true,
	UITableLayout = true,
	UIFlexItem = true,
}

---------------------------------------------------------------------------------------------------------------
-- Results

local function newResult(name)
	return { scenario = name, pass = true, checks = {} }
end

local function check(res, name, value, limit, ok)
	-- snake_case names like the server harness: "right_column_y_IndexUi/OpenIndex" -> "right_column_y_indexui_openindex"
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

local function viewport()
	local cam = Workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(0, 0)
end

-- The ScreenGui's drawing area in screen pixels: below the top bar unless IgnoreGuiInset.
local function rootRect(gui, vp)
	local tl, br = inset()
	if gui:IsA("ScreenGui") and not gui.IgnoreGuiInset then
		return R(tl.X, tl.Y, vp.X - tl.X - br.X, vp.Y - tl.Y - br.Y)
	end
	return R(0, 0, vp.X, vp.Y)
end

-- Engine rectangle, converted to screen pixels through the ScreenGui's own origin.
local function realRect(obj)
	local gui = guiOf(obj)
	local root = rootRect(gui, viewport())
	if obj == gui then
		return root
	end
	local ox, oy = root.x - gui.AbsolutePosition.X, root.y - gui.AbsolutePosition.Y
	return R(obj.AbsolutePosition.X + ox, obj.AbsolutePosition.Y + oy, obj.AbsoluteSize.X, obj.AbsoluteSize.Y)
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

local function gridCell(obj, parent, grid, base, ctx)
	if
		grid.FillDirection ~= Enum.FillDirection.Horizontal
		or grid.StartCorner ~= Enum.StartCorner.TopLeft
		or grid.HorizontalAlignment ~= Enum.HorizontalAlignment.Left
		or grid.VerticalAlignment ~= Enum.VerticalAlignment.Top
		or (grid.SortOrder ~= Enum.SortOrder.LayoutOrder and grid.SortOrder ~= Enum.SortOrder.Name)
	then
		ctx.unsupported[pathOf(grid)] = "UIGridLayout options"
	end
	local cw = base.w * grid.CellSize.X.Scale + grid.CellSize.X.Offset
	local ch = base.h * grid.CellSize.Y.Scale + grid.CellSize.Y.Offset
	local px = base.w * grid.CellPadding.X.Scale + grid.CellPadding.X.Offset
	local py = base.h * grid.CellPadding.Y.Scale + grid.CellPadding.Y.Offset
	local items = {}
	for _, c in parent:GetChildren() do
		if c:IsA("GuiObject") and c.Visible then
			table.insert(items, c)
		end
	end
	local byName = grid.SortOrder == Enum.SortOrder.Name
	table.sort(items, function(a, b)
		if not byName and a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return a.Name < b.Name
	end)
	local idx = table.find(items, obj)
	if not idx then
		return R(base.x, base.y, 0, 0)
	end
	local cols = math.max(1, math.floor((base.w + px) / (cw + px)))
	if grid.FillDirectionMaxCells > 0 then
		cols = math.min(cols, grid.FillDirectionMaxCells)
	end
	local i = idx - 1
	return R(base.x + (i % cols) * (cw + px), base.y + math.floor(i / cols) * (ch + py), cw, ch)
end

-- Layout solver for a hypothetical viewport: UDim2 Position/Size, AnchorPoint, UISizeConstraint, UIGridLayout
-- (top-left, horizontal fill), ScrollingFrame CanvasPosition, and the top-bar inset. Anything else is recorded
-- in ctx.unsupported (the layout_model_supported check fails, so the solver must be extended, never ignored).
simRect = function(obj, ctx)
	local cached = ctx.cache[obj]
	if cached then
		return cached
	end
	local r
	if obj:IsA("LayerCollector") then
		r = rootRect(obj, ctx.vp)
	elseif not obj:IsA("GuiObject") then
		r = simRect(obj.Parent, ctx)
	else
		local parent = obj.Parent
		local pr = simRect(parent, ctx)
		for _, sibling in parent:GetChildren() do
			if UNSUPPORTED_LAYOUT[sibling.ClassName] then
				ctx.unsupported[pathOf(parent)] = sibling.ClassName
			end
		end
		if obj.AutomaticSize ~= Enum.AutomaticSize.None then
			ctx.unsupported[pathOf(obj)] = "AutomaticSize"
		end
		local base = pr
		if parent:IsA("ScrollingFrame") then
			base = R(pr.x - parent.CanvasPosition.X, pr.y - parent.CanvasPosition.Y, pr.w, pr.h)
		end
		local grid = parent:FindFirstChildWhichIsA("UIGridLayout")
		if grid then
			r = gridCell(obj, parent, grid, base, ctx)
		else
			local w = base.w * obj.Size.X.Scale + obj.Size.X.Offset
			local h = base.h * obj.Size.Y.Scale + obj.Size.Y.Offset
			w, h = constrain(obj, w, h)
			local x = base.x + base.w * obj.Position.X.Scale + obj.Position.X.Offset - obj.AnchorPoint.X * w
			local y = base.y + base.h * obj.Position.Y.Scale + obj.Position.Y.Offset - obj.AnchorPoint.Y * h
			r = R(x, y, w, h)
		end
	end
	ctx.cache[obj] = r
	return r
end

-- Rect function for a UiSpec.Viewports entry.
local function provider(vpSpec)
	if not vpSpec.Size then
		return realRect, viewport(), { unsupported = {} }
	end
	local ctx = { vp = vpSpec.Size, cache = {}, unsupported = {} }
	return function(obj)
		return simRect(obj, ctx)
	end, vpSpec.Size, ctx
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

local events = { rolls = {}, npcStart = nil, lastLose = nil, loses = {}, turbos = {}, rollsChanged = 0 }

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
	player:GetAttributeChangedSignal("Rolls"):Connect(function()
		events.rollsChanged = os.clock()
	end)
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
		if not remotes then
			return
		end
		task.spawn(function()
			local roll = remotes:WaitForChild("RollResult", 30)
			if roll then
				roll.OnClientEvent:Connect(function(id, isNew, turboMulti)
					local ev = {
						id = id,
						isNew = isNew,
						turboMulti = type(turboMulti) == "number" and turboMulti or 1,
						t = os.clock(),
					}
					table.insert(events.rolls, ev)
					if ev.turboMulti > 1 then
						task.spawn(UiScenarios.SampleTurbo, ev)
					end
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
-- Rolls strip helpers (RollUi, docs/SPAWN_AND_ROLLS_SPEC.md sections 4 and 5)

local function turboEvery()
	return type(GachaConfig.TURBO_EVERY) == "number" and GachaConfig.TURBO_EVERY or UiSpec.RollUi.FallbackTurbo.Every
end

local function turboLuck()
	return type(GachaConfig.TURBO_LUCK) == "number" and GachaConfig.TURBO_LUCK or UiSpec.RollUi.FallbackTurbo.Luck
end

local function turboProgress(rolls)
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
		if (o:IsA("TextLabel") or o:IsA("TextButton")) and o.Text ~= "" and o.Visible then
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
	local bar = findPath("RollUi/TurboBar")
	local fill = bar and bar:FindFirstChild("Fill")
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
	local gui = playerGui:FindFirstChild("RollUi")
	local pop = gui and gui:FindFirstChild("TurboPop", true)
	if not pop then
		return nil, false, true
	end
	local textObj = (pop:IsA("TextLabel") or pop:IsA("TextButton")) and pop
		or pop:FindFirstChildWhichIsA("TextLabel", true)
	if not textObj then
		return nil, false, not effectivelyVisible(pop)
	end
	local visible = effectivelyVisible(pop) and effectivelyVisible(textObj)
	local shown = visible and textObj.Text ~= "" and textObj.TextTransparency < 0.5
	local gone = not visible or textObj.Text == "" or textObj.TextTransparency >= 0.99
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

-- What is wrong with the showcase card as the card for roll event `ev` (empty when it shows the roll's truth).
local function showcaseCardProblems(ev)
	local _, _, card = showcaseParts()
	if not card then
		return { "no " .. UiSpec.Showcase.Card }
	end
	if not ev then
		return { "no RollResult received yet" }
	end
	local bad = {}
	local spec = CarCatalog.Get(ev.id)
	if not spec then
		return { "roll id " .. tostring(ev.id) .. " not in CarCatalog" }
	end
	local function part(name)
		return card:FindFirstChild(name, true)
	end
	local cardRect = realRect(card)
	for _, name in UiSpec.Showcase.CardParts do
		local o = part(name)
		if o and o:IsA("GuiObject") and effectivelyVisible(o) and not contains(cardRect, realRect(o)) then
			table.insert(bad, name .. rstr(realRect(o)) .. " outside the card")
		end
	end
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
	local wantOdds = spec.Chance and HudFormat.Odds(spec.Chance) or "Common"
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
	local wantMulti = "Speed x" .. fmtNum(m)
	if
		not (multi and multi:IsA("TextLabel") and (multi.Text == wantMulti or multi.Text == "Speed x" .. tostring(m)))
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
-- Element sets per panel state

-- Every element that is interactive or always on in the given state: AlwaysOn elements, the open panels and
-- every button inside an open panel (buttons that only show in some data state, e.g. Equip on an undiscovered
-- tile, are included: they WILL be shown, so their place must already be free).
local function elementsFor(open)
	local list = {}
	for _, guiName in declaredGuis() do
		local g = UiSpec.Guis[guiName]
		for _, p in g.AlwaysOn or {} do
			local obj = findPath(guiName .. "/" .. p)
			-- Elements that hide while a panel is open are only placed in the rest state (ui_toast proves they hide)
			local hides = #open > 0 and table.find(UiSpec.HiddenWhilePanelOpen, guiName .. "/" .. p) ~= nil
			if obj and not hides then
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

local function overlapAllowed(a, b)
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

	-- Every GuiButton is declared, and every declared button exists the expected number of times
	local counts, undeclared = {}, {}
	for _, b in allButtons() do
		local path = pathOf(b)
		local guiName = splitPath(path)[1]
		local rel = string.sub(path, #guiName + 2)
		local matched = false
		for i, spec in UiSpec.Guis[guiName].Buttons or {} do
			if pathMatches(spec.Path, rel) then
				local key = guiName .. "#" .. i
				counts[key] = (counts[key] or 0) + 1
				matched = true
				break
			end
		end
		if not matched then
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
						and not overlapAllowed(a.path, b.path)
						and intersects(ra, rb)
					then
						table.insert(overlaps, a.path .. rstr(ra) .. " x " .. b.path .. rstr(rb))
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
										table.insert(textHits, pathOf(l) .. " text" .. rstr(tr) .. " x " .. b.path)
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
				for _, item in ipairs(UiSpec.RightColumn) do
					local o = findPath(item.Path)
					if o then
						local r, root = rectOf(o), rootOf(item.Path)
						local _, cy = centre(r)
						local wantY = root.y + root.h / 2 + item.CentreYOffset
						check(
							res,
							"right_column_y_" .. item.Path .. "_" .. vpSpec.Name,
							cy,
							wantY,
							math.abs(cy - wantY) <= TOL
						)
						local gap = root.x + root.w - (r.x + r.w)
						check(
							res,
							"right_column_edge_" .. item.Path .. "_" .. vpSpec.Name,
							gap,
							UiSpec.RightColumn.MaxRightGap,
							gap >= -TOL and gap <= UiSpec.RightColumn.MaxRightGap
						)
					else
						check(res, "right_column_" .. item.Path .. "_" .. vpSpec.Name, "missing", "present", false)
					end
				end
				local hud = findPath("SpeedHud/Panel")
				if hud then
					local r, root = rectOf(hud), rootOf("SpeedHud/Panel")
					local cx = centre(r)
					check(res, "hud_on_left_" .. vpSpec.Name, cx, root.x + root.w / 3, cx < root.x + root.w / 3)
				else
					check(res, "hud_on_left_" .. vpSpec.Name, "missing", "present", false)
				end
				local toggle = findPath("AutoRaceButton/Toggle")
				if toggle then
					local r, root = rectOf(toggle), rootOf("AutoRaceButton/Toggle")
					local cx, cy = centre(r)
					local midX = root.x + root.w / 2
					check(res, "autorace_top_centre_x_" .. vpSpec.Name, cx, midX, math.abs(cx - midX) <= TOL)
					check(
						res,
						"autorace_top_centre_y_" .. vpSpec.Name,
						cy,
						root.y + root.h / 4,
						cy < root.y + root.h / 4
					)
				else
					check(res, "autorace_top_centre_" .. vpSpec.Name, "missing", "present", false)
				end
				-- Rolls strip (spec section 5, owner's revision): only the TurboBar, bottom centre, its bottom edge
				-- BottomGap px above the screen bottom, BarSize; the toast sits above it
				local turboBar, toastEl = findPath("RollUi/TurboBar"), findPath("RollToast/Toast")
				if turboBar then
					local bb, root = rectOf(turboBar), rootOf("RollUi/TurboBar")
					local cx = centre(bb)
					local midX = root.x + root.w / 2
					check(res, "turbobar_bottom_centre_x_" .. vpSpec.Name, cx, midX, math.abs(cx - midX) <= TOL)
					local gap = root.y + root.h - (bb.y + bb.h)
					local wantGap = UiSpec.RollUi.BottomGap
					check(res, "turbobar_bottom_gap_" .. vpSpec.Name, gap, wantGap, math.abs(gap - wantGap) <= TOL)
					local size = UiSpec.RollUi.BarSize
					check(
						res,
						"turbobar_size_" .. vpSpec.Name,
						("%dx%d"):format(math.floor(bb.w + 0.5), math.floor(bb.h + 0.5)),
						("%dx%d"):format(size.X, size.Y),
						math.abs(bb.w - size.X) <= TOL and math.abs(bb.h - size.Y) <= TOL
					)
				else
					check(res, "turbobar_bottom_centre_" .. vpSpec.Name, "missing", "present", false)
				end
				if turboBar and toastEl then
					local bb, tr = rectOf(turboBar), rectOf(toastEl)
					check(
						res,
						"toast_above_turbobar_" .. vpSpec.Name,
						tr.y + tr.h,
						"<= " .. bb.y,
						tr.y + tr.h <= bb.y + TOL
					)
				else
					check(res, "toast_above_turbobar_" .. vpSpec.Name, "missing", "present", false)
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
					local mx, my = centre(root)
					local d = math.max(math.abs(ccx - mx), math.abs(ccy - my))
					check(res, "showcase_card_centred_" .. vpSpec.Name, d, TOL, d <= TOL)
					check(
						res,
						"showcase_card_inside_viewport_" .. vpSpec.Name,
						rstr(cr),
						rstr(full),
						contains(full, cr)
					)
					local ci = UiSpec.Showcase.CornerInset
					local cornerOnCard = vp.X - ci >= cr.x
						and vp.X - ci <= cr.x + cr.w
						and vp.Y - ci >= cr.y
						and vp.Y - ci <= cr.y + cr.h
					check(res, "showcase_corner_off_card_" .. vpSpec.Name, cornerOnCard, false, not cornerOnCard)
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
			if state.Name == "index_open" then
				local p = findPath("IndexUi/Panel")
				if p then
					local r, root = rectOf(p), rootRect(guiOf(p), vp)
					local cx = centre(r)
					local dx = math.abs(cx - (root.x + root.w / 2))
					check(res, "index_panel_centred_x_" .. vpSpec.Name, dx, TOL, dx <= TOL)
					-- Vertically: below the top-centre Auto Race button (+ margin) and above the screen bottom
					local toggle = findPath("AutoRaceButton/Toggle")
					if toggle then
						local tr = rectOf(toggle)
						local minTop = tr.y + tr.h + UiSpec.PanelTopMargin
						check(res, "index_panel_below_autorace_" .. vpSpec.Name, r.y, minTop, r.y >= minTop - TOL)
					else
						check(res, "index_panel_below_autorace_" .. vpSpec.Name, "missing", "present", false)
					end
					local bottom = root.y + root.h
					check(res, "index_panel_above_bottom_" .. vpSpec.Name, r.y + r.h, bottom, r.y + r.h <= bottom + TOL)
				else
					check(res, "index_panel_centred_x_" .. vpSpec.Name, "missing", "present", false)
				end
			end
			if state.Name == "stats_open" then
				local p = findPath("StatsUi/Panel")
				local col = {}
				for _, item in ipairs(UiSpec.RightColumn) do
					local o = findPath(item.Path)
					if o then
						table.insert(col, rectOf(o).x)
					end
				end
				if p and #col > 0 then
					local right = rectOf(p).x + rectOf(p).w
					local limit = math.min(table.unpack(col))
					check(res, "stats_panel_left_of_buttons_" .. vpSpec.Name, right, limit, right <= limit + TOL)
				else
					check(res, "stats_panel_left_of_buttons_" .. vpSpec.Name, "missing", "present", false)
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
			if effectivelyVisible(e.obj) then
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
		local open = findPath("IndexUi/OpenIndex")
		local ok = false
		if open then
			local cx, cy = centre(realRect(open))
			ok = table.find(hitsAt(cx, cy), open) ~= nil
		end
		check(res, "probe_coordinates_valid", ok, true, ok)
		restore()
		restore = setPanels({ "IndexUi/Panel" })
		local close, panel = findPath("IndexUi/Panel/Close"), findPath("IndexUi/Panel")
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
				if not contains(pr, r) then
					table.insert(spill, path .. rstr(r) .. " outside " .. rstr(pr))
				end
				-- no bigger than what it shows
				local opaque = b.BackgroundTransparency < 0.95
					or (b:IsA("ImageButton") and b.Image ~= "" and b.ImageTransparency < 0.95)
				if not opaque then
					local content = nil
					if b:IsA("TextButton") then
						content = textRect(b, r)
					end
					for _, d in b:GetDescendants() do
						if d:IsA("GuiObject") and effectivelyVisible(d) then
							local drawn = d.BackgroundTransparency < 0.95
								or ((d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.TextTransparency < 0.95)
								or (
									(d:IsA("ImageLabel") or d:IsA("ImageButton"))
									and d.Image ~= ""
									and d.ImageTransparency < 0.95
								)
							if drawn then
								content = union(content, realRect(d))
							end
						end
					end
					if not content then
						table.insert(padded, path .. " shows nothing")
					elseif r.w > content.w + 2 * pad + TOL or r.h > content.h + 2 * pad + TOL then
						table.insert(padded, path .. rstr(r) .. " content" .. rstr(content))
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
	local toggle = findPath("AutoRaceButton/Toggle")
	local racing = attr("AutoRacing") == true
	if toggle then
		check(
			res,
			"autorace_label_matches_server",
			toggle.Text,
			HudFormat.AutoButtonText(racing),
			toggle.Text == HudFormat.AutoButtonText(racing)
		)
	else
		check(res, "autorace_label_matches_server", "missing", "present", false)
	end
	for _, item in { { "IndexUi/OpenIndex", "INDEX" }, { "StatsUi/OpenStats", "STATS" } } do
		local b = findPath(item[1])
		local text = b and b:IsA("TextButton") and b.Text or "missing"
		check(res, "label_" .. item[1], text, item[2], text == item[2])
	end
	local close = findPath("IndexUi/Panel/Close")
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
		local b = findPath("IndexUi/Panel/Grid/" .. spec.Id .. "/Equip")
		if not b then
			table.insert(wrong, spec.Id .. ": no Equip button")
		elseif not owned(spec.Id) then
			if b.Visible then
				table.insert(wrong, spec.Id .. ": undiscovered but Equip visible")
			end
		elseif equipped == spec.Id then
			if not (b.Visible and b.Text == "Equipped" and b.Active == false) then
				table.insert(
					wrong,
					("%s: equipped shows %q Visible=%s Active=%s"):format(
						spec.Id,
						b.Text,
						tostring(b.Visible),
						tostring(b.Active)
					)
				)
			end
		elseif not (b.Visible and b.Text == "Equip" and b.Active == true) then
			table.insert(
				wrong,
				("%s: owned shows %q Visible=%s Active=%s"):format(
					spec.Id,
					b.Text,
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
		local b = findPath("StatsUi/Panel/" .. stat .. "/Plus")
		local want = points > 0 and not UiSpec.Guis.StatsUi.DisabledStats[stat]
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
	local ws = findPath("StatsUi/Panel/Workshop/Plus")
	check(
		res,
		"workshop_plus_disabled",
		ws and ws.Active,
		false,
		ws ~= nil and ws.Active == false and ws.AutoButtonColor == false
	)
end

function S.ui_hud(res)
	waitGuis()
	local stats = player:WaitForChild("leaderstats", 10)
	local speed = stats and stats:FindFirstChild("Speed")
	local money = stats and stats:FindFirstChild("Money")
	local value, rate, moneyValue =
		findPath("SpeedHud/Panel/Value"), findPath("SpeedHud/Panel/Rate"), findPath("SpeedHud/Panel/MoneyValue")
	check(res, "leaderstats_present", speed ~= nil and money ~= nil, true, speed ~= nil and money ~= nil)
	check(
		res,
		"hud_labels_present",
		value ~= nil and rate ~= nil and moneyValue ~= nil,
		true,
		value ~= nil and rate ~= nil and moneyValue ~= nil
	)
	-- Unbanked row (spec section 5): title "UNBANKED" and the smoothed player attribute Unbanked, under Money
	local unbankedTitle, unbankedValue =
		findPath("SpeedHud/Panel/UnbankedTitle"), findPath("SpeedHud/Panel/UnbankedValue")
	check(
		res,
		"unbanked_title_text",
		unbankedTitle and unbankedTitle.Text,
		"UNBANKED",
		unbankedTitle ~= nil and unbankedTitle:IsA("TextLabel") and unbankedTitle.Text == "UNBANKED"
	)
	check(
		res,
		"unbanked_value_present",
		unbankedValue ~= nil,
		true,
		unbankedValue ~= nil and unbankedValue:IsA("TextLabel")
	)
	check(res, "unbanked_attribute_present", typeof(attr("Unbanked")), "number", type(attr("Unbanked")) == "number")
	local hudPanel = findPath("SpeedHud/Panel")
	if hudPanel and moneyValue and unbankedTitle and unbankedValue then
		renderFrame()
		local mv, ut, uv = realRect(moneyValue), realRect(unbankedTitle), realRect(unbankedValue)
		check(res, "unbanked_title_under_money", ut.y, ">= " .. (mv.y + mv.h), ut.y >= mv.y + mv.h - TOL)
		check(res, "unbanked_value_under_title", uv.y, ">= " .. (ut.y + ut.h), uv.y >= ut.y + ut.h - TOL)
		local pr = realRect(hudPanel)
		local outside = {}
		for _, l in hudPanel:GetDescendants() do
			if l:IsA("TextLabel") and l.Visible and not contains(pr, realRect(l)) then
				table.insert(outside, pathOf(l) .. rstr(realRect(l)) .. " outside " .. rstr(pr))
			end
		end
		checkList(res, "hud_labels_inside_panel", outside)
	end
	if not (speed and money and value and rate and moneyValue) then
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
			and string.sub(unbankedValue.Text, 1, 1) == "$"
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
	local okRate = rate.Text == HudFormat.RateText(s1)
		or (shown ~= nil and (rate.Text == HudFormat.RateText(shown) or rate.Text == HudFormat.RateText(shown + 1)))
	check(res, "hud_rate_matches_stat", rate.Text, HudFormat.RateText(s1), okRate)
	local toggle = findPath("AutoRaceButton/Toggle")
	local racing = attr("AutoRacing") == true
	check(
		res,
		"autorace_label_follows_server",
		toggle and toggle.Text,
		HudFormat.AutoButtonText(racing),
		toggle ~= nil and toggle.Text == HudFormat.AutoButtonText(racing)
	)
end

function S.ui_index(res)
	waitGuis()
	local gui = playerGui:FindFirstChild("IndexUi")
	local panel = findPath("IndexUi/Panel")
	local open = findPath("IndexUi/OpenIndex")
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
	local restore = setPanels({ "IndexUi/Panel" })
	local all = CarCatalog.All()
	local tiles, missing = {}, {}
	for _, spec in all do
		local tile = findPath("IndexUi/Panel/Grid/" .. spec.Id)
		if tile then
			table.insert(tiles, { spec = spec, tile = tile })
		else
			table.insert(missing, spec.Id)
		end
	end
	checkList(res, "one_tile_per_catalog_car", missing)
	local grid = findPath("IndexUi/Panel/Grid")
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
		local name, icon, equip =
			tile:FindFirstChild("CarName"), tile:FindFirstChild("Icon"), tile:FindFirstChild("Equip")
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
			if not (icon and icon.Text == "?") then
				table.insert(wrong, id .. ": undiscovered but icon is " .. tostring(icon and icon.Text))
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
		local ok = e ~= nil and e.Text == "Equipped" and e.Active == false and e.AutoButtonColor == false
		check(
			res,
			"equipped_tile_shows_equipped_and_is_disabled",
			e and ("%s Active=%s AutoButtonColor=%s"):format(e.Text, tostring(e.Active), tostring(e.AutoButtonColor)),
			"Equipped Active=false AutoButtonColor=false",
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
	local progress = findPath("IndexUi/Panel/Progress")
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
	local open = findPath("StatsUi/OpenStats")
	local panel = findPath("StatsUi/Panel")
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
	local badge = findPath("StatsUi/OpenStats/Badge")
	if points > 0 then
		local ok = badge ~= nil and effectivelyVisible(badge) and badge.Text == tostring(points)
		check(res, "badge_shows_free_points", badge and badge.Text, tostring(points), ok)
	else
		local ok = badge == nil or not effectivelyVisible(badge)
		check(res, "badge_hidden_at_zero", badge and effectivelyVisible(badge), false, ok)
	end

	local restore = setPanels({ "StatsUi/Panel" })
	local pts = findPath("StatsUi/Panel/Points")
	check(res, "points_label_matches_server", pts and pts.Text, points, pts ~= nil and hasNumber(pts.Text, points))

	local rows, missing = {}, {}
	for _, stat in GachaConfig.STATS do
		local row = findPath("StatsUi/Panel/" .. stat)
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
		local disabled = UiSpec.Guis.StatsUi.DisabledStats[r.stat]
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

-- The roll toast (owner's revision): a TextButton that shows every roll, is clickable only while shown
-- (Visible = false once faded: no invisible hitbox) and hides while any panel is open.
function S.ui_toast(res)
	waitGuis()
	local toast = findPath("RollToast/Toast")
	check(res, "toast_present", toast ~= nil, true, toast ~= nil)
	if not toast then
		return
	end
	check(res, "toast_is_text_button", toast.ClassName, "TextButton", toast:IsA("TextButton"))
	local function hidden()
		return not effectivelyVisible(toast)
	end

	-- Hidden (Visible = false) while any panel is open: at once, and when a roll arrives meanwhile
	for _, p in allPanels() do
		local restorePanel = setPanels({ p })
		frames(3)
		check(res, "toast_hidden_while_open_" .. p, hidden(), true, hidden())
		if waitNewRoll(UiSpec.Waits.RollToast) then
			frames(3)
			check(res, "toast_hidden_on_roll_while_open_" .. p, hidden(), true, hidden())
		else
			stateMissing(res, "toast_hidden_on_roll_while_open_" .. p, "auto_racing", "no Remotes.RollResult")
		end
		restorePanel()
	end

	-- With no panel open: shown on a roll (the roll's truth, clickable), then gone (Visible = false, not clickable).
	-- Uses a roll with no other roll before ToastGone (3 tries).
	local restore = setPanels({})
	local ev, shownRec, goneRec = nil, nil, nil
	for _ = 1, 3 do
		if not waitNewRoll(UiSpec.Waits.RollToast) then
			break
		end
		local mine = events.rolls[#events.rolls]
		local n = #events.rolls
		task.wait(math.max(0, UiSpec.Waits.ToastShown - (os.clock() - mine.t)))
		renderFrame()
		local x, y = centre(realRect(toast))
		local top = topAt(x, y)
		shownRec = {
			visible = effectivelyVisible(toast),
			opaque = toast:IsA("TextButton") and toast.TextTransparency < 0.5,
			text = toast:IsA("TextButton") and toast.Text or "",
			colour = toast:IsA("TextButton") and toast.TextColor3 or nil,
			top = top,
		}
		task.wait(math.max(0, UiSpec.Waits.ToastGone - (os.clock() - mine.t)))
		renderFrame()
		local hit = false
		for _, h in hitsAt(x, y) do
			hit = hit or h == toast or h:IsDescendantOf(toast)
		end
		goneRec = { visible = effectivelyVisible(toast), hit = hit }
		ev = mine
		if #events.rolls == n then
			break -- isolated: no other roll changed the toast meanwhile
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
		("Visible=%s opaque=%s"):format(tostring(shownRec.visible), tostring(shownRec.opaque)),
		("shown within %.1f s"):format(UiSpec.Waits.ToastShown),
		shownRec.visible and shownRec.opaque
	)
	check(res, "toast_shows_car_name", shownRec.text, spec.Name, string.find(shownRec.text, spec.Name, 1, true) ~= nil)
	local hasNew = string.find(shownRec.text, "NEW!", 1, true) ~= nil
	check(res, "toast_new_matches_server", hasNew, ev.isNew == true, hasNew == (ev.isNew == true))
	local colour = GachaConfig.RARITY_COLORS[spec.Rarity]
	local stroke = toast:FindFirstChildWhichIsA("UIStroke")
	-- Secret's colour is near-black: it may be carried by the outline instead of the text
	local ok = sameColour(shownRec.colour, colour)
		or (spec.Rarity == "Secret" and stroke ~= nil and sameColour(stroke.Color, colour))
	check(res, "toast_in_rarity_colour", tostring(shownRec.colour), tostring(colour), ok == true)
	local top = shownRec.top
	check(
		res,
		"toast_clickable_while_shown",
		top and pathOf(top) or "nothing",
		"RollToast/Toast",
		top ~= nil and (top == toast or toast:IsAncestorOf(top))
	)
	check(res, "toast_not_visible_after_fade", goneRec.visible, false, goneRec.visible == false)
	check(res, "faded_toast_not_clickable", goneRec.hit, false, goneRec.hit == false)
	restore()
end

-- The TURBO LUCK bar, the only part of RollUi left (docs/SPAWN_AND_ROLLS_SPEC.md sections 4 and 5).
function S.ui_rolls(res)
	waitGuis()
	local every, luck = turboEvery(), turboLuck()
	local cfgOk = type(GachaConfig.TURBO_EVERY) == "number"
		and type(GachaConfig.TURBO_LUCK) == "number"
		and type(GachaConfig.IsTurbo) == "function"
		and type(GachaConfig.TurboProgress) == "function"
	check(res, "gacha_turbo_config_present", cfgOk, true, cfgOk)

	local gui = playerGui:FindFirstChild("RollUi")
	local missing = {}
	for _, p in { "TurboBar", "TurboBar/Fill", "TurboBar/Label" } do
		if not findPath("RollUi/" .. p) then
			table.insert(missing, "RollUi/" .. p)
		end
	end
	if not (gui and gui:FindFirstChild("TurboPop", true)) then
		table.insert(missing, "RollUi/**/TurboPop")
	end
	checkList(res, "rollui_parts_present", missing)
	-- Owner's revision: no ROLLS button and no roll feed any more
	local stale = {}
	for _, name in UiSpec.RollUi.Removed do
		local o = gui and gui:FindFirstChild(name, true)
		if o then
			table.insert(stale, pathOf(o))
		end
	end
	checkList(res, "rollui_feed_and_button_removed", stale)
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
		("%.2f +- %.2f"):format(wantFrac, UiSpec.RollUi.FillTolerance),
		frac ~= nil and math.abs(frac - wantFrac) <= UiSpec.RollUi.FillTolerance
	)
	local barLabel = findPath("RollUi/TurboBar/Label")
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
		local exists = gui:FindFirstChild("TurboPop", true) ~= nil
		check(res, "turbo_pop_hidden_at_rest", exists and gone or "missing", true, exists and gone)
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
		("0 +- %.2f"):format(UiSpec.RollUi.FillTolerance),
		rec.fill ~= nil and rec.fill <= UiSpec.RollUi.FillTolerance
	)
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
	restore()
end

function UiScenarios.Run(name)
	local res = newResult(name)
	local fn = S[name]
	if not fn then
		check(res, "scenario_exists", name, "known", false)
		return res
	end
	fn(res)
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
		EquippedCar = attr("EquippedCar"),
		StatPoints = attr("StatPoints") or 0,
	}
	for _, stat in GachaConfig.STATS do
		snap["Alloc_" .. stat] = attr("Alloc_" .. stat) or 0
	end
	return snap
end

-- Shown to the player: visible, and for text buttons the text is not faded out.
local function shownNow(obj)
	return effectivelyVisible(obj) and (not obj:IsA("TextButton") or obj.TextTransparency < 0.5)
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
	waitGuis()
	local prep = spec.Prepare or {}

	-- The showcase is never forced: it must already be in the state this click starts from
	local preShowcase = showcaseState()
	if prep.Showcase ~= nil then
		local want = prep.Showcase and "open" or "closed"
		-- A missing showcase gui counts as closed here (ui_showcase / ui_inventory fail on it)
		if preShowcase ~= want and not (want == "closed" and preShowcase == "missing") then
			stateMissing(
				res,
				"showcase_state_before_click",
				prep.Showcase and "click:open_showcase_from_toast" or "click:showcase_backdrop_closes",
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
	local rowStat = spec.Gui == "StatsUi" and splitPath(path)[2] or nil
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
	local grid = findPath("IndexUi/Panel/Grid")
	local savedCanvas = grid and grid.CanvasPosition
	frames(2)
	if tileId and grid then
		local tile = findPath("IndexUi/Panel/Grid/" .. tileId)
		local rel = tile.AbsolutePosition.Y - grid.AbsolutePosition.Y + grid.CanvasPosition.Y
		grid.CanvasPosition = Vector2.new(0, math.max(0, rel - 8))
		frames(2)
	end
	if prep.WaitSeconds then
		task.wait(prep.WaitSeconds)
	end
	local function restore()
		for o, v in saved do
			o.Visible = v
		end
		if grid and savedCanvas then
			grid.CanvasPosition = savedCanvas
		end
	end

	local preSpy = readSpy()
	if not preSpy then
		stateMissing(res, "spy_installed", "spy", "ReplicatedStorage.UiTestSpy missing")
		restore()
		return res
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
	for attempt = 1, attempts do
		-- Wait for a fresh show of the target (the toast only shows after a RollResult, for ~1.6 s)
		if prep.WaitShown then
			local shown = false
			if waitNewRoll(UiSpec.Waits.RollToast) then
				local deadline = os.clock() + UiSpec.Waits.ToastShown
				repeat
					renderFrame()
					shown = shownNow(button)
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

		pre = attrSnapshot()
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
				press = { x = px, y = py, hit = topAt(px, py), targetShown = shownNow(button) }
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
		end
		local names = {}
		for _, f in fired do
			table.insert(names, f.name .. "(" .. tostring(f.args[1]) .. ")")
		end
		local want = expect.Remote.Name .. "(" .. tostring(wantArg) .. ")"
		local ok = #fired == 1 and fired[1].name == expect.Remote.Name and fired[1].args[1] == wantArg
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
		if cond == "autorace_label_follows_server" then
			local want = HudFormat.AutoButtonText(attr("AutoRacing") == true)
			check(res, cond, button.Text, want, button.Text == want)
		elseif cond == "autoracing_is_arg" then
			check(res, cond, attr("AutoRacing") == true, wantArg, (attr("AutoRacing") == true) == wantArg)
		elseif cond == "equipped_is_tile" then
			check(res, cond, attr("EquippedCar"), tileId, attr("EquippedCar") == tileId)
		elseif cond == "tile_shows_equipped" then
			local e = findPath("IndexUi/Panel/Grid/" .. tileId .. "/Equip")
			check(res, cond, e and e.Text, "Equipped", e ~= nil and e.Text == "Equipped" and e.Active == false)
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
		elseif cond == "alloc_unchanged" then
			local k = "Alloc_" .. rowStat
			check(res, cond, attr(k) or 0, pre[k], (attr(k) or 0) == pre[k])
		elseif cond == "points_unchanged" then
			check(res, cond, attr("StatPoints") or 0, pre.StatPoints, (attr("StatPoints") or 0) == pre.StatPoints)
		elseif cond == "row_shows_alloc" then
			local v = findPath("StatsUi/Panel/" .. rowStat .. "/Value")
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
			-- Opens on the latest roll (or a newer one that arrived during the settle: it updates live)
			checkList(res, cond, showcaseCardProblems(events.rolls[#events.rolls]))
		elseif cond == "showcase_blur_on" then
			local b = blurState()
			check(res, cond, b, "enabled", b == "enabled")
		elseif cond == "showcase_blur_off" then
			local b = blurState()
			check(res, cond, b, "disabled", b == "disabled")
		elseif cond == "showcase_layout" then
			local gui, backdrop, card = showcaseParts()
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
				local mx, my = centre(root)
				local d = math.max(math.abs(ccx - mx), math.abs(ccy - my))
				check(res, "showcase_card_centred", d, TOL, d <= TOL)
				check(res, "showcase_card_inside_viewport", rstr(cr), rstr(full), contains(full, cr))
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
			-- turbo_next made the next auto roll a turbo roll: the open card follows it, badge included
			if waitNewRoll(UiSpec.Waits.RollToast) then
				task.wait(UiSpec.Waits.ToastShown)
				frames(3)
				local ev = events.rolls[#events.rolls]
				local st = showcaseState()
				check(res, "showcase_still_open_on_roll", st, "open", st == "open")
				checkList(res, "showcase_updates_live", showcaseCardProblems(ev))
				if ev.turboMulti > 1 then
					check(
						res,
						"showcase_live_roll_turbo_multi",
						ev.turboMulti,
						turboLuck(),
						ev.turboMulti == turboLuck()
					)
				else
					stateMissing(
						res,
						"showcase_live_roll_is_turbo",
						"turbo_next",
						"turboMulti " .. tostring(ev.turboMulti)
					)
				end
			else
				stateMissing(res, "showcase_updates_live", "auto_racing", "no Remotes.RollResult")
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
