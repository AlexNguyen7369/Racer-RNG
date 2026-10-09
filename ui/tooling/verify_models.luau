-- Offline verification only: emits XML to stdout, never writes a model asset.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")
local root, project = process.args[1], process.args[2]
-- Lune 0.10.5 redirects legacy Font to FontFace without converting the enum.
-- These specs use FredokaOne exclusively; do not generalize silently.
local results = {}
local names =
	{ "RacerHud", "RacerIndex", "RacerStats", "RacerSettings", "RacerRebirth", "RollShowcase", "RacerHudConcept" }
local sizes = { { 1280, 720 }, { 1920, 1080 }, { 1024, 768 }, { 844, 390 }, { 1280, 500 }, { 1280, 501 } }
-- WaitForChild is an engine method; offline fixtures are already present.
roblox.implementMethod("Instance", "WaitForChild", function(inst, child)
	return assert(inst:FindFirstChild(child), child)
end)
local function loadUi(path, width, height)
	local camera = { ViewportSize = roblox.Vector2.new(width, height) }
	local callbacks = {}
	function camera:GetPropertyChangedSignal(_property)
		return {
			Connect = function(_self, callback)
				table.insert(callbacks, callback)
			end,
		}
	end
	local env = { workspace = { CurrentCamera = camera } }
	for _, key in { "Instance", "Enum", "Vector2", "UDim", "UDim2", "Color3", "ColorSequence" } do
		env[key] = roblox[key]
	end
	local ui = luau.load(fs.readFile(path), { environment = env, injectGlobals = true })()
	return ui, camera, callbacks
end
for _, name in names do
	for _, size in sizes do
		local pair = { name = name, width = size[1], height = size[2] }
		for _, variant in { "original", "generated" } do
			local base = if variant == "original" then project else root
			local ui, camera, callbacks =
				loadUi(base .. "/src/client/RollToast/Ui/" .. name .. ".luau", size[1], size[2])
			local parent = roblox.Instance.new("Folder")
			local refs = ui.Build(parent)
			assert(refs.Gui.Name == name)
			for _, inst in refs.Gui:GetDescendants() do
				if inst:IsA("TextLabel") then
					assert(
						tostring(inst.Font) == "Enum.Font.FredokaOne",
						"Add explicit font mapping: " .. tostring(inst.Font)
					)
					inst.FontFace = roblox.Font.new("rbxasset://fonts/families/FredokaOne.json")
				end
			end
			-- Exercise desktop -> phone -> original viewport through the actual fit callback.
			camera.ViewportSize = roblox.Vector2.new(844, 390)
			for _, callback in callbacks do
				callback()
			end
			camera.ViewportSize = roblox.Vector2.new(size[1], size[2])
			for _, callback in callbacks do
				callback()
			end
			local bytes = roblox.serializeModel({ refs.Gui })
			local restored = roblox.deserializeModel(bytes)
			assert(#restored == 1 and restored[1].Name == name)
			if variant == "generated" then
				local savedParent = roblox.Instance.new("Folder")
				restored[1].Parent = savedParent
				local bound = ui.Bind(savedParent)
				for id, instance in refs do
					assert(bound[id] and bound[id].ClassName == instance.ClassName, id)
				end
				assert(roblox.serializeModel({ bound.Gui }) == bytes, "Bind changed saved properties")
			end
			pair[variant] = roblox.serializeModel({ refs.Gui }, true)
		end
		table.insert(results, pair)
	end
end
local asset = roblox.deserializeModel(fs.readFile(project .. "/assets/studio/StarterGui.rbxm"))
assert(#asset == 1 and asset[1]:IsA("StarterGui"), "preserve the saved StarterGui container")
local inventory = {}
for _, gui in asset[1]:GetChildren() do
	assert(gui:IsA("ScreenGui"), "unexpected saved child")
	local ui = loadUi(root .. "/src/client/RollToast/Ui/" .. gui.Name .. ".luau", 1280, 720)
	local fresh = ui.Build(roblox.Instance.new("Folder")).Gui
	local function paths(parent)
		local found = {}
		local function walk(inst, path)
			found[path] = inst.ClassName
			for _, child in inst:GetChildren() do
				walk(child, path .. "/" .. child.Name)
			end
		end
		walk(parent, parent.Name)
		return found
	end
	local base, extra = paths(fresh), {}
	for path in paths(gui) do
		if not base[path] then
			table.insert(extra, path)
		end
	end
	table.sort(extra)
	table.insert(inventory, {
		name = gui.Name,
		class = gui.ClassName,
		descendants = #gui:GetDescendants(),
		generatedDescendants = #fresh:GetDescendants(),
		extraCount = #extra,
		extraExamples = { unpack(extra, 1, math.min(#extra, 6)) },
	})
end
assert(#inventory == 6, "expected six saved ScreenGuis")
print(serde.encode("json", { comparisons = results, asset = inventory }))
