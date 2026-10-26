--!nonstrict
-- Interactive UI stays inside the device safe area (docs/HUD_LAYOUT_SPEC.md section 7). DeviceSafeInsets, like the
-- authored IgnoreGuiInset = true, does not reserve the top bar, so nothing moves on screens without a notch;
-- full-screen dims and overlays keep bleeding edge to edge.
local Players = game:GetService("Players")

local FULL_BLEED = { PanelDim = true, LoserScreen = true, RollShowcase = true }

local function apply(gui)
	if gui:IsA("ScreenGui") and not FULL_BLEED[gui.Name] then
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
playerGui.ChildAdded:Connect(apply)
for _, gui in playerGui:GetChildren() do
	apply(gui)
end
