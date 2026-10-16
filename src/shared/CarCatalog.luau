--!nonstrict
-- The car catalog: auto-loads every ModuleScript in Shared/Cars, so adding a car is just adding a file.
-- Car Ids are permanent keys (saves store { [Id] = count }), never list positions. The starter car is
-- built in here: every player has it, it can not be rolled and it is not in the index.

local Cars = script.Parent:WaitForChild("Cars")

local CarCatalog = {}

CarCatalog.STARTER_ID = "starter"

local STARTER = {
	Id = CarCatalog.STARTER_ID,
	Name = "Starter Car",
	Rarity = "Common",
	Chance = nil,
	SpeedMulti = 1,
	Order = 0,
	Model = nil,
	Rollable = false,
}

local specs = {} -- Id -> spec (rollable cars and gamepass cars)
for _, module in Cars:GetChildren() do
	if module:IsA("ModuleScript") then
		local spec = require(module)
		spec.Id = spec.Id or module.Name
		-- A gamepass car (docs/GAMEPASS_CARS_SPEC.md) is bought: never rolled, not in the index
		spec.Rollable = spec.GamepassId == nil
		assert(spec.Id ~= CarCatalog.STARTER_ID, "car id 'starter' is reserved")
		assert(specs[spec.Id] == nil, "duplicate car id " .. spec.Id)
		specs[spec.Id] = spec
	end
end

local byOrder = {}
local rarestFirst = {}
local passes = {}
for _, spec in specs do
	if spec.Rollable then
		table.insert(byOrder, spec)
		table.insert(rarestFirst, spec)
	else
		table.insert(passes, spec)
	end
end
local function inOrder(a, b)
	return a.Order < b.Order
end
table.sort(byOrder, inOrder)
table.sort(passes, inOrder)
-- Largest "1 in N" first; the catch-all (Chance = nil) last
table.sort(rarestFirst, function(a, b)
	return (a.Chance or 0) > (b.Chance or 0)
end)

-- The spec for an Id (the starter car included), or nil.
function CarCatalog.Get(id)
	if id == CarCatalog.STARTER_ID then
		return STARTER
	end
	return specs[id]
end

-- Every index car (the starter excluded), in index Order. Do not modify the returned table.
function CarCatalog.All()
	return byOrder
end

-- Every rollable car, rarest first, the catch-all last. Do not modify the returned table.
function CarCatalog.Rollable()
	return rarestFirst
end

-- Every gamepass car, in Order. Do not modify the returned table.
function CarCatalog.Passes()
	return passes
end

return CarCatalog
