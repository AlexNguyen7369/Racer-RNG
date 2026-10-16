--!nonstrict
-- One big panel open at a time: opening the index closes the stats panel and the other way round, so two
-- panels never cover each other's buttons. Client UI scripts register their panel and call Toggle/Close.

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
		if not panel.Visible then
			wanted[name] = false
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
