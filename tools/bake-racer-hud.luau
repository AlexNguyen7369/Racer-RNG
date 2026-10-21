-- Bake only the generated RacerHud into the native StarterGui asset.
-- The other StarterGui ScreenGuis are carried through unchanged.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local root = process.args[1] or "."
local assetPath = root .. "/assets/studio/StarterGui.rbxm"
local sourcePath = root .. "/src/client/RollToast/Ui/RacerHud.luau"

roblox.implementMethod("Instance", "WaitForChild", function(inst, child)
	return assert(inst:FindFirstChild(child), child)
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function()
	return { Connect = function() end }
end)

local camera = { ViewportSize = roblox.Vector2.new(1280, 720) }
function camera:GetPropertyChangedSignal(_property)
	return { Connect = function() end }
end

local env = {
	workspace = { CurrentCamera = camera },
	task = {
		defer = function(callback)
			callback()
		end,
		delay = function(_seconds, callback)
			callback()
		end,
	},
}
for _, key in { "Instance", "Enum", "Vector2", "UDim", "UDim2", "Color3", "ColorSequence" } do
	env[key] = roblox[key]
end

local module = luau.load(fs.readFile(sourcePath), { environment = env, injectGlobals = true })()
local freshParent = roblox.Instance.new("Folder")
local fresh = module.Build(freshParent).Gui
for _, inst in fresh:GetDescendants() do
	if inst:IsA("TextLabel") then
		-- Lune 0.10 serializes legacy Enum.Font values poorly; preserve the
		-- authored FredokaOne appearance through the serializable FontFace.
		inst.FontFace = roblox.Font.new("rbxasset://fonts/families/FredokaOne.json")
	end
end

local model = roblox.deserializeModel(fs.readFile(assetPath))
assert(#model == 1 and model[1]:IsA("StarterGui"), "StarterGui asset must contain one StarterGui")
local starterGui = model[1]
local saved = assert(starterGui:FindFirstChild("RacerHud"), "StarterGui is missing RacerHud")
assert(#starterGui:GetChildren() >= 6, "StarterGui must preserve its ScreenGuis")
local preserved = {}
for _, child in starterGui:GetChildren() do
	if child ~= saved then
		preserved[child.Name] = roblox.serializeModel({ child })
	end
end

saved:Destroy()
fresh.Name = "RacerHud"
fresh.Parent = starterGui
assert(#starterGui:GetChildren() >= 6, "bake changed StarterGui ScreenGui count")
for name, bytes in preserved do
	local child = assert(starterGui:FindFirstChild(name), "bake lost " .. name)
	assert(roblox.serializeModel({ child }) == bytes, "bake changed preserved " .. name)
end

fs.writeFile(assetPath, roblox.serializeModel({ starterGui }))
print("PASS: baked transparent enlarged RacerHud; preserved all other ScreenGuis")
