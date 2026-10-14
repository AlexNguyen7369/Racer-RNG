-- Focused offline presentation checks; not the full Roblox UI compatibility suite.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local callbacks = {}
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(object, property)
	return { Connect = function(_, callback)
		callbacks[object] = callbacks[object] or {}
		callbacks[object][property] = callback
	end }
end)
local function environment(camera)
	local env = { workspace = { CurrentCamera = camera } }
	for _, key in { "Instance", "Enum", "Vector2", "UDim", "UDim2", "Color3", "ColorSequence" } do
		env[key] = roblox[key]
	end
	return env
end
for _, size in { {640,360}, {844,390}, {1366,768}, {1920,1080} } do
	local fitCallbacks = {}
	local camera = { ViewportSize = roblox.Vector2.new(size[1], size[2]) }
	function camera:GetPropertyChangedSignal()
		return { Connect = function(_, callback) table.insert(fitCallbacks, callback) end }
	end
	local env = environment(camera)
	local components = luau.load(fs.readFile("src/client/RollToast/Ui/RacerComponents.luau"), {environment=env,injectGlobals=true})()
	env.require = function() return components end
	env.script = { Parent = { RacerComponents = {} } }
	local style = luau.load(fs.readFile("src/client/RollToast/Ui/HudButtonStyle.luau"), {environment=env,injectGlobals=true})()
	local previousBottom = 0
	for slot, name in {"Upgrades","Daily","Market"} do
		local button = roblox.Instance.new("TextButton")
		button.Name, button.Text = name, name
		style.Utility(button, slot, style.Colors[name])
		local x = size[1] + button.Position.X.Offset - button.Size.X.Offset
		local y, height = button.Position.Y.Offset, button.Size.Y.Offset
		assert(x >= 0 and x + button.Size.X.Offset <= size[1])
		assert(y >= 58 and y + height <= size[2])
		assert(height >= 44 and y >= previousBottom)
		assert(button.HudCaption.TextColor3 == roblox.Color3.new(1,1,1))
		assert(button.HudCaption.RacerTextOutline.Thickness == 3)
		assert(button.Text == "" and button.HudCaption.Text == name)
		previousBottom = y + height + 3
	end
	local parent = roblox.Instance.new("Frame")
	parent.Name = "Stats"
	local face = roblox.Instance.new("TextButton")
	face.Name, face.Parent = "Face", parent
	local caption = roblox.Instance.new("TextLabel")
	caption.Name, caption.Parent = "StatsLabel", face
	local badge = roblox.Instance.new("TextLabel")
	badge.Name, badge.Text, badge.Parent = "PointsBadge", "7", face
	style.SetCaption(face, "STATS")
	assert(face.Text == "" and caption.Text == "STATS" and badge.Text == "7")
	caption.Text = ""
	callbacks[caption].Text()
	assert(caption.Text == "STATS", "Responsive reset erased live caption")
	print("PASS HUD entries/caption isolation at " .. size[1] .. "x" .. size[2])
end
