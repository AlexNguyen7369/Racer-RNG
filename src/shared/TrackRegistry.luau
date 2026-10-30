--!nonstrict
-- Auto-loads every ModuleScript in Shared/Tracks/World<N>, so adding a track is just adding a file.
-- Each world has its own tracks (docs/WORLDS_SPEC.md section 2); the world argument defaults to WorldConfig.Current().

local Tracks = script.Parent:WaitForChild("Tracks")
local WorldConfig = require(script.Parent:WaitForChild("WorldConfig"))

local TrackRegistry = {}

local specsByWorld = {}
for world in WorldConfig.PLACE_IDS do
	local specs = {}
	for _, module in Tracks:WaitForChild("World" .. world):GetChildren() do
		if module:IsA("ModuleScript") then
			local spec = require(module)
			spec.Name = spec.Name or module.Name
			specs[spec.Name] = spec
		end
	end
	specsByWorld[world] = specs
end

local function specsFor(world)
	return specsByWorld[world or WorldConfig.Current()] or {}
end

function TrackRegistry.Get(name, world)
	return specsFor(world)[name]
end

-- Specs that have a Number, in ladder order. Track N+1 is built from track N's finish.
function TrackRegistry.Chain(world)
	local chain = {}
	for _, spec in specsFor(world) do
		if spec.Number then
			table.insert(chain, spec)
		end
	end
	table.sort(chain, function(a, b)
		return a.Number < b.Number
	end)
	return chain
end

function TrackRegistry.Names(world)
	local names = {}
	for name in specsFor(world) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return TrackRegistry
