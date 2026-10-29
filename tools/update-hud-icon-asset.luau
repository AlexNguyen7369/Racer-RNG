-- Narrow image-only update: preserve all authored GUI instances and car atlas art.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local path = "assets/studio/StarterGui.rbxm"
local roots = roblox.deserializeModel(fs.readFile(path))
assert(#roots == 1 and roots[1]:IsA("StarterGui"))
local gui = roots[1]
local changed = 0
local otherScreens = {}
for _, screen in gui:GetChildren() do
    if screen.Name ~= "RacerHud" then otherScreens[screen.Name] = roblox.serializeModel({screen}) end
end
for _, item in gui:GetDescendants() do
    local imageOk, image = pcall(function() return item.ImageContent end)
    if (item:IsA("ImageLabel") or item:IsA("ImageButton")) and imageOk and tostring(image) == "Content(Uri=rbxassetid://81490848854515)" then
        item.ImageContent = roblox.Content.fromUri("rbxassetid://131875159358960")
        changed += 1
    end
end
assert(changed == 1, "Expected exactly one authored Settings image")
for name, bytes in otherScreens do
    assert(roblox.serializeModel({gui:FindFirstChild(name)}) == bytes, "Unrelated GUI changed: " .. name)
end
fs.writeFile(path, roblox.serializeModel(roots))
print("PASS: one Settings image replaced; all other ScreenGuis preserved")
