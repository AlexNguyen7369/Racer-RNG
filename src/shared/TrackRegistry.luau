--!nonstrict
-- Auto-loads every ModuleScript in Shared/Tracks, so adding a track is just adding a file.

local Tracks = script.Parent:WaitForChild("Tracks")

local TrackRegistry = {}

local specs = {}
for _, module in Tracks:GetChildren() do
	if module:IsA("ModuleScript") then
		local spec = require(module)
		spec.Name = spec.Name or module.Name
		specs[spec.Name] = spec
	end
end

function TrackRegistry.Get(name)
	return specs[name]
end

-- Specs that have a Number, in ladder order. Track N+1 is built from track N's finish.
function TrackRegistry.Chain()
	local chain = {}
	for _, spec in specs do
		if spec.Number then
			table.insert(chain, spec)
		end
	end
	table.sort(chain, function(a, b)
		return a.Number < b.Number
	end)
	return chain
end

function TrackRegistry.Names()
	local names = {}
	for name in specs do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return TrackRegistry
