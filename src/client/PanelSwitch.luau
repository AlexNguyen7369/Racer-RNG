--!nonstrict
-- One big panel open at a time: opening the index closes the stats panel and the other way round, so two
-- panels never cover each other's buttons. Client UI scripts register their panel and call Toggle/Close.

local PanelSwitch = {}

local panels = {} -- name -> Frame
local changed = Instance.new("BindableEvent")
PanelSwitch.Changed = changed.Event -- fires after any panel opens or closes

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
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		changed:Fire()
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
	panel.Visible = open
	return open
end

function PanelSwitch.Close(name)
	if panels[name] then
		panels[name].Visible = false
	end
end

return PanelSwitch
