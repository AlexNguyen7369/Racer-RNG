local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local game = roblox.deserializePlace(fs.readFile(assert(process.args[1], "Pass a saved .rbxl")))
local function normalized(source)
	return (source:gsub("\r\n", "\n"):gsub("%s+$", ""))
end
local checked = 0
local function check(instance, file)
	assert(instance and instance:IsA("LuaSourceContainer"), "Missing " .. file)
	assert(normalized(instance.Source) == normalized(fs.readFile(file)), "Saved source differs: " .. file)
	checked += 1
end
check(game:GetService("ReplicatedStorage").Shared.CarAppearance, "src/shared/CarAppearance.luau")
check(game:GetService("ServerScriptService").Server.CarService, "src/server/CarService.luau")
check(game:GetService("ServerScriptService").ProjectContext, "context/ProjectContext.luau")
local roll = game:GetService("StarterPlayer").StarterPlayerScripts.Client.RollToast
check(roll, "src/client/RollToast/init.client.luau")
check(roll.RacerUiController, "src/client/RollToast/RacerUiController.luau")
for _, module in roll.Ui:GetChildren() do
	check(module, "src/client/RollToast/Ui/" .. module.Name .. ".luau")
end
assert(checked == 13, "Unexpected restored source count")
print("PASS: all 13 restored/UI/context sources match the native saved place")
