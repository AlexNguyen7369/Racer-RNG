local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local game = roblox.deserializePlace(fs.readFile(assert(process.args[1], "Pass a built .rbxl")))
local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
local models = game:GetService("ReplicatedStorage"):FindFirstChild("CarModels")
assert(shared:FindFirstChild("CarAppearance"))
assert(models and #models:GetChildren() == 7)
local meshCount = 0
for _, model in models:GetChildren() do
	assert(model:GetAttribute("MeshRevision") == 5, model.Name)
	for _, part in model:GetDescendants() do
		assert(not part:IsA("Light"), "Headlights must remain decorative")
		if part:IsA("MeshPart") then
			assert(part.DoubleSided and part.Anchored and not part.CanCollide and part.Massless)
			local ok, mesh = pcall(function() return part.MeshContent end)
			if not ok then mesh = part.MeshId end
			assert(mesh ~= nil and tostring(mesh) ~= "", "Missing mesh content")
			meshCount += 1
		end
	end
end
assert(meshCount == 42)
local client = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("Client")
local roll = client:FindFirstChild("RollToast")
assert(roll:IsA("LocalScript"))
assert(roll:FindFirstChild("RacerUiController"):IsA("ModuleScript"))
local ui = roll:FindFirstChild("Ui")
for _, name in {"RacerHud", "RacerIndex", "RacerStats", "RacerSettings", "RacerRebirth", "RollShowcase", "RacerMotion", "RacerComponents"} do
	assert(ui:FindFirstChild(name):IsA("ModuleScript"), name)
end
for _, name in {"AutoRaceButton", "SpeedHud", "IndexUi", "StatsUi", "RollUi"} do
	assert(client:FindFirstChild(name).Disabled, name .. " would duplicate the new HUD")
end
local guis = game:GetService("StarterGui")
for _, name in {"RacerHud", "RacerIndex", "RacerStats", "RacerSettings", "RacerRebirth", "RollShowcase"} do
	assert(guis:FindFirstChild(name):IsA("ScreenGui"), name)
end
print("PASS: seven Draft05 cars / 42 double-sided meshes, decorative headlights, six menus, controller hierarchy, legacy UI disabled")
