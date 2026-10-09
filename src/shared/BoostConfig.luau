--!nonstrict
-- Consumable timed boosts. IDs are permanent save keys.

local BoostConfig = {}

BoostConfig.Order = { "Luck", "Money", "Speed" }
BoostConfig.Roman = { "I", "II", "III" }
BoostConfig.Items = {}
BoostConfig.ByCategory = {}
local multipliers = { 1.25, 1.5, 2 }
local prices = { 5000, 10000, 20000 }
for _, category in BoostConfig.Order do
	BoostConfig.ByCategory[category] = {}
	for tier, roman in ipairs(BoostConfig.Roman) do
		local id = category .. roman
		local item = {
			Id = id,
			Category = category,
			Tier = tier,
			Roman = roman,
			Name = category .. " Potion " .. roman,
			Duration = 60,
			Multiplier = multipliers[tier],
			Price = prices[tier],
		}
		BoostConfig.Items[id] = item
		if tier == 1 then
			-- Category aliases keep older callers and v6 saves compatible.
			BoostConfig.Items[category] = item
		end
		BoostConfig.ByCategory[category][tier] = item
	end
end

-- Every completed track awards one deterministic potion. This keeps wins
-- valuable without introducing a random economy result into physics tests.
function BoostConfig.WinReward(trackNumber)
	local index = math.max(1, math.floor(tonumber(trackNumber) or 1))
	return BoostConfig.Order[((index - 1) % #BoostConfig.Order) + 1]
end

function BoostConfig.Get(id)
	return BoostConfig.Items[id] or (BoostConfig.ByCategory[id] and BoostConfig.ByCategory[id][1])
end

function BoostConfig.ItemsFor(category)
	return BoostConfig.ByCategory[category] or {}
end

return BoostConfig
