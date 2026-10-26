--!nonstrict
-- Reduced motion for UI (docs/HUD_LAYOUT_SPEC.md section 7): Roblox's Reduced Motion setting or the in-game
-- REDUCED EFFECTS toggle. UI tweens go through Create so they land at once while motion is reduced.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UiMotion = {}

local INSTANT = TweenInfo.new(0)

function UiMotion.Reduced()
	local player = Players.LocalPlayer
	return GuiService.ReducedMotionEnabled or (player ~= nil and player:GetAttribute("ReduceEffects") == true)
end

-- TweenService:Create with the same arguments; a reduced tween takes 0 s and never repeats.
function UiMotion.Create(instance, info, goal)
	return TweenService:Create(instance, UiMotion.Reduced() and INSTANT or info, goal)
end

return UiMotion
