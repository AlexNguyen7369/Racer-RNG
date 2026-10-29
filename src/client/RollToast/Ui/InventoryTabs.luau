--!nonstrict
-- The Index header's tabs. Index is car discovery only (docs/HUD_LAYOUT_SPEC.md sections 1 and 3): consumables are
-- used from the Backpack's Misc tab, so the generated CONSUMABLES tab and its host are held hidden and stay empty.
local Tabs = {}
local Components = require(script.Parent.RacerComponents)
local CYAN = Color3.fromRGB(30, 216, 255)

function Tabs.Attach(refs, _player, refreshCars)
	-- The generated fit re-applies the authored Visible = true on every refit. refs.ConsumablesTab is the tab's
	-- Face button; its wrapper Frame (Header/Face/ConsumablesTab) is the visible tab.
	for _, retired in { refs.ConsumablesTab.Parent, refs.ConsumablesHost } do
		retired.Visible = false
		retired:GetPropertyChangedSignal("Visible"):Connect(function()
			if retired.Visible then
				retired.Visible = false
			end
		end)
	end
	local function showCars()
		refs.Gui:SetAttribute("InventoryTab", "Cars")
		refs.GridHost.Visible = true
		Components.Tint(refs.CarsTab, CYAN)
		refreshCars()
	end
	refs.CarsTab.Activated:Connect(showCars)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		task.defer(showCars)
	end)
	showCars()
end
return Tabs
