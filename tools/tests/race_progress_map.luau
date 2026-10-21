--!nonstrict
-- Run from the repo root: lune run tools/tests/race_progress_map.luau
-- Loads the real geometry/PB implementations and the shared acceptance assertions.
-- No Roblox Studio, DataStore, network, or player state is accessed.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local function loadSource(path, extra)
	local env = { Vector3 = roblox.Vector3, Vector2 = roblox.Vector2 }
	for key, value in extra or {} do
		env[key] = value
	end
	return luau.load(fs.readFile(path), { debugName = path, environment = env, injectGlobals = true })()
end

-- RaceTimeService's only dependency is the set of numbered tracks. Read the same
-- track files as TrackRegistry so adding a numbered track expands the test fixture.
local chain, numbers = {}, {}
for _, name in fs.readDir("src/shared/Tracks") do
	if name:match("%.luau$") then
		local spec = loadSource(
			"src/shared/Tracks/" .. name,
			{ CFrame = roblox.CFrame, Color3 = roblox.Color3, Enum = roblox.Enum }
		)
		if spec.Number then
			table.insert(chain, spec)
		end
	end
end
table.sort(chain, function(a, b)
	return a.Number < b.Number
end)
for _, track in chain do
	table.insert(numbers, track.Number)
end
local registry = {
	Chain = function()
		return chain
	end,
}
local token = {}
local replicated = { Shared = { TrackRegistry = token } }
local times = loadSource("src/server/RaceTimeService.luau", {
	game = {
		GetService = function(_, name)
			assert(name == "ReplicatedStorage", "Unexpected offline service: " .. name)
			return replicated
		end,
	},
	require = function(target)
		assert(target == token, "Unexpected offline PB dependency")
		return registry
	end,
})
local tests = loadSource("src/server/CarTest/RaceProgressTests.luau")
local map = loadSource("src/shared/RaceProgressMap.luau")
local passed, failed = 0, 0
for _, item in
	{
		{
			"geometry",
			function()
				return tests.Geometry(map)
			end,
		},
		{
			"records",
			function()
				return tests.Records(times, numbers)
			end,
		},
	}
do
	local ok, result = xpcall(item[2], debug.traceback)
	if not ok then
		failed += 1
		print("FAIL " .. item[1] .. ": " .. tostring(result))
	else
		local sectionPassed, sectionFailed = 0, 0
		for _, check in result.checks do
			if check.pass then
				sectionPassed += 1
			else
				sectionFailed += 1
				print("FAIL " .. check.name .. " (" .. tostring(check.value) .. ")")
			end
		end
		passed += sectionPassed
		failed += sectionFailed
		print(string.format("%s: %d passed, %d failed", item[1], sectionPassed, sectionFailed))
	end
end
print(string.format("Race progress offline: %d passed, %d failed (%d numbered tracks)", passed, failed, #numbers))
if failed > 0 then
	process.exit(1)
end
