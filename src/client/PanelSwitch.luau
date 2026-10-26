--!nonstrict
-- One big panel open at a time: opening the index closes the stats panel and the other way round, so two
-- panels never cover each other's buttons. Client UI scripts register their panel and call Toggle/Close.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local PanelSwitch = {}

local panels = {} -- name -> Frame
local wanted = {} -- name -> true while PanelSwitch opened it
local changed = Instance.new("BindableEvent")
PanelSwitch.Changed = changed.Event -- fires after any panel opens or closes (deferred)
local listeners = {}

-- Calls fn right away (same frame) whenever Toggle / Close / a registered panel's Visible changes the open set.
function PanelSwitch.OnChange(fn)
	table.insert(listeners, fn)
end

local function notify()
	for _, fn in listeners do
		-- One UI listener must not prevent the remaining panel chrome from refreshing.
		pcall(fn)
	end
	changed:Fire()
end

-- True while any registered panel is open.
function PanelSwitch.AnyOpen()
	for _, p in panels do
		if p.Visible then
			return true
		end
	end
	return false
end

-- Gamepad focus (docs/HUD_LAYOUT_SPEC.md section 7): an opened panel takes the selection and traps it; closing
-- gives the previous selection back. Mouse, touch and keyboard are untouched.
local FOCUS_GROUP, CLOSE_ACTION = "PanelSwitchFocus", "PanelSwitchClose"
local focused, restoreTo = nil, nil

local function usesGamepad()
	local ok, preferred = pcall(function()
		return UserInputService.PreferredInput
	end)
	if ok and preferred then
		return preferred == Enum.PreferredInput.Gamepad
	end
	return UserInputService:GetLastInputType().Name:find("^Gamepad") ~= nil
end

local function shown(inst, root)
	while inst and inst ~= root do
		if inst:IsA("GuiObject") and not inst.Visible then
			return false
		end
		inst = inst.Parent
	end
	return true
end

-- The top-left visible, selectable button in the panel.
local function firstButton(panel)
	local best
	for _, inst in panel:GetDescendants() do
		if inst:IsA("GuiButton") and inst.Selectable and inst.Name ~= "Backdrop" and shown(inst, panel) then
			local p = inst.AbsolutePosition
			if
				inst.AbsoluteSize.X > 0
				and (not best or p.Y < best.Y - 1 or (math.abs(p.Y - best.Y) <= 1 and p.X < best.X))
			then
				best = { Button = inst, Y = p.Y, X = p.X }
			end
		end
	end
	return best and best.Button
end

local function releaseFocus(panel)
	if focused ~= panel then
		return
	end
	focused = nil
	GuiService:RemoveSelectionGroup(FOCUS_GROUP)
	ContextActionService:UnbindAction(CLOSE_ACTION)
	local selected = GuiService.SelectedObject
	if selected == nil or selected:IsDescendantOf(panel) then
		GuiService.SelectedObject = (restoreTo and restoreTo:IsDescendantOf(game)) and restoreTo or nil
	end
	restoreTo = nil
end

local function takeFocus(panel)
	if not usesGamepad() then
		return
	end
	if focused then
		releaseFocus(focused)
	end
	focused = panel
	restoreTo = GuiService.SelectedObject
	GuiService:AddSelectionParent(FOCUS_GROUP, panel)
	ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin and focused == panel then
			panel.Visible = false
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
	task.defer(function() -- the layout settles first, so AbsolutePosition is real
		if focused == panel and panel.Visible then
			GuiService.SelectedObject = firstButton(panel)
		end
	end)
end

function PanelSwitch.Register(name, panel)
	panels[name] = panel
	wanted[name] = panel.Visible
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		-- Generated responsive fits re-apply the authored Visible = true on viewport changes; only Toggle opens
		-- a panel, so an unrequested show is undone (it would stack two panels on join).
		if panel.Visible and not wanted[name] then
			panel.Visible = false
			return
		end
		if panel.Visible then
			takeFocus(panel)
		else
			wanted[name] = false
			releaseFocus(panel)
		end
		notify()
	end)
end

-- Shows `name` and hides every other registered panel; hides it if it was already open. Returns the new state.
function PanelSwitch.Toggle(name)
	local panel = panels[name]
	if not panel then
		return false
	end
	local open = not panel.Visible
	if open then
		for other, p in panels do
			if other ~= name then
				p.Visible = false
			end
		end
	end
	wanted[name] = open
	panel.Visible = open
	notify()
	return open
end

-- A HUD entry whose panel needs more than Toggle (it rebuilds its content, or two entries share one panel)
-- registers its own action; Action falls back to Toggle. The owning script decides toggle behaviour.
local actions = {}
function PanelSwitch.SetAction(name, fn)
	actions[name] = fn
end

function PanelSwitch.Action(name)
	if actions[name] then
		actions[name]()
	else
		PanelSwitch.Toggle(name)
	end
end

function PanelSwitch.IsOpen(name)
	return panels[name] ~= nil and panels[name].Visible
end

function PanelSwitch.Close(name)
	if panels[name] and panels[name].Visible then
		panels[name].Visible = false
		notify()
	end
end

return PanelSwitch
