-- Preserve the native place bytes; export only StarterGui, never round-trip terrain.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local bytes = fs.readFile(assert(process.args[1], "Pass native Studio snapshot"))
local game = roblox.deserializePlace(bytes)
local gui = game:GetService("StarterGui")
for name, hash in {
    RacerHud = "37da31f77505",
    RacerIndex = "80e4155a1165",
    RacerUpgrades = "d11f56f95c73",
} do
    local item = assert(gui:FindFirstChild(name), "Missing " .. name)
    assert(item:GetAttribute("SpecHash") == hash, name .. " spec hash differs")
end
local client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local function normalized(s) return s:gsub("\r\n", "\n"):gsub("%s+$", "") end
for _, name in {"HudButtonStyle", "InventoryTabs", "PotionIcons", "UpgradeTreeView", "RacerHud", "RacerIndex"} do
    assert(normalized(client.RollToast.Ui[name].Source) == normalized(fs.readFile("src/client/RollToast/Ui/" .. name .. ".luau")), name .. " differs from snapshot")
end
assert(normalized(client.Ui.RacerUpgrades.Source) == normalized(fs.readFile("src/client/Ui/RacerUpgrades.luau")))
assert(game:GetService("ServerScriptService").ProjectContext.Source:find("INVENTORY + UPGRADE UI", 1, true))
fs.writeFile("assets/studio/StarterGui.rbxm", roblox.serializeModel({gui}))
fs.writeFile("places/RacerRNG_Inventory_UpgradeUI_20261014.rbxl", bytes)
print("PASS: native snapshot, UI module sources and three spec hashes; StarterGui exported")
