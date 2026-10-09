--!nonstrict
-- Observe actual rendered viewport changes. Never sets ViewportSize, visibility or gameplay state.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Spec = require(script.Parent.UiSpec)
local LegacyControls = {}

function LegacyControls.Sample(h)
	local controls = h.find(Spec.LegacyControls.Path)
	local sample = { hidden = controls == nil or controls.Visible == false, hiddenButtons = {}, hits = {} }
	if not controls then
		return sample
	end
	for _, obj in controls:GetDescendants() do
		if obj:IsA("GuiButton") then
			if h.visible(obj) then
				table.insert(sample.hiddenButtons, obj.Name)
			end
			local r = h.rect(obj)
			if r.w > 0 and r.h > 0 then
				for _, hit in h.hits(h.centre(r)) do
					if hit == obj or obj:IsAncestorOf(hit) then
						table.insert(sample.hits, obj.Name)
						break
					end
				end
			end
		end
	end
	return sample
end

function LegacyControls.Observe(h)
	local history = { samples = 0, resizes = 0, desktop = false, phone = false, violations = {} }
	local lastSize = nil
	local function sample()
		local camera = Workspace.CurrentCamera
		if h.playerGui:GetAttribute("RacerUiReady") ~= true or not camera or camera.ViewportSize.X <= 0 then
			return
		end
		local size = camera.ViewportSize
		local changed = lastSize ~= nil and size ~= lastSize
		if changed then
			history.resizes += 1
		end
		if lastSize == nil or changed then
			history.samples += 1
			if size.Y <= Spec.LegacyControls.PhoneMaxHeight then
				history.phone = true
			else
				history.desktop = true
			end
		end
		lastSize = size
		local current = LegacyControls.Sample(h)
		if not current.hidden or #current.hiddenButtons > 0 or #current.hits > 0 then
			-- Keep the first evidence even if a later fit hides it again.
			if #history.violations < 20 then
				table.insert(
					history.violations,
					("%dx%d Visible=%s drawn=%s hits=%s"):format(
						size.X,
						size.Y,
						tostring(not current.hidden),
						table.concat(current.hiddenButtons, ","),
						table.concat(current.hits, ",")
					)
				)
			end
		end
	end
	RunService.RenderStepped:Connect(sample)
	return {
		Run = function(res, requireResize)
			h.frames(2)
			sample()
			local hud = h.find("RacerHud")
			h.check(
				res,
				"racer_hud_ready",
				hud ~= nil and h.playerGui:GetAttribute("RacerUiReady") == true,
				true,
				hud ~= nil and h.playerGui:GetAttribute("RacerUiReady") == true
			)
			local current = LegacyControls.Sample(h)
			h.check(res, "legacy_controls_visible_property_false", current.hidden, true, current.hidden)
			h.check(
				res,
				"legacy_buttons_not_visible",
				table.concat(current.hiddenButtons, ","),
				"",
				#current.hiddenButtons == 0
			)
			h.check(res, "legacy_buttons_not_hit", table.concat(current.hits, ","), "", #current.hits == 0)
			h.check(
				res,
				"legacy_controls_never_reenabled_on_render",
				table.concat(history.violations, " | "),
				"",
				#history.violations == 0
			)
			if requireResize then
				h.check(res, "actual_viewport_resizes_observed", history.resizes, ">=2", history.resizes >= 2)
				h.check(res, "desktop_variant_observed", history.desktop, true, history.desktop)
				h.check(res, "phone_variant_observed", history.phone, true, history.phone)
			end
		end,
	}
end

return LegacyControls
