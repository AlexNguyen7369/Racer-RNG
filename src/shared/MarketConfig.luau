--!strict
-- Money purchases described by the design document's "What Money buys" section.
local MarketConfig = {}
local BoostConfig = require(script.Parent.BoostConfig)

MarketConfig.Items = {
	Aura = {
		{
			Id = "azure_aura",
			Name = "Azure Aura",
			Price = 1000,
			SpeedMulti = 1.25,
			Color = Color3.fromRGB(80, 190, 255),
			Accent = Color3.fromRGB(180, 245, 255),
			Description = "A cool, charged glow that lifts your cruise speed.",
		},
		{
			Id = "ember_aura",
			Name = "Ember Aura",
			Price = 1500,
			SpeedMulti = 1.35,
			Color = Color3.fromRGB(255, 92, 38),
			Accent = Color3.fromRGB(255, 220, 75),
			Description = "A hot orbit of sparks for high-energy racers.",
		},
		{
			Id = "galaxy_aura",
			Name = "Galaxy Aura",
			Price = 2500,
			SpeedMulti = 1.5,
			Color = Color3.fromRGB(137, 80, 255),
			Accent = Color3.fromRGB(255, 91, 220),
			Description = "A swirling cosmic field with a rare speed boost.",
		},
	},
	Trail = {
		{
			Id = "rainbow_trail",
			Name = "Rainbow Trail",
			Price = 500,
			SpeedMulti = 1,
			Color = Color3.fromRGB(255, 120, 235),
			Accent = Color3.fromRGB(90, 220, 255),
			Description = "A shifting rainbow ribbon behind your ride.",
		},
		{
			Id = "solar_trail",
			Name = "Solar Trail",
			Price = 900,
			SpeedMulti = 1,
			Color = Color3.fromRGB(255, 188, 48),
			Accent = Color3.fromRGB(255, 245, 145),
			Description = "A bright comet tail made of golden plasma.",
		},
		{
			Id = "void_trail",
			Name = "Void Trail",
			Price = 1800,
			SpeedMulti = 1,
			Color = Color3.fromRGB(104, 52, 220),
			Accent = Color3.fromRGB(34, 230, 210),
			Description = "A dark neon wake that flickers at the edges.",
		},
	},
	Potion = {},
}

for _, category in BoostConfig.Order do
	for _, boost in BoostConfig.ItemsFor(category) do
		table.insert(MarketConfig.Items.Potion, {
			Id = boost.Id,
			Name = boost.Name,
			Price = boost.Price,
			Color = category == "Luck" and Color3.fromRGB(190, 105, 255)
				or category == "Money" and Color3.fromRGB(255, 205, 65)
				or Color3.fromRGB(70, 190, 255),
			Accent = Color3.fromRGB(255, 255, 255),
			Description = string.format("%s multiplier for %d seconds. Added to your Bag.", category, boost.Duration),
			Category = category,
			Tier = boost.Tier,
		})
	end
end

local byId = {}
for kind, items in MarketConfig.Items do
	for _, item in items do
		item.Kind = kind
		byId[item.Id] = item
	end
end

function MarketConfig.Get(kind, id)
	local item = byId[id]
	return item and item.Kind == kind and item or nil
end

function MarketConfig.SpeedMulti(player)
	local id = typeof(player) == "Instance" and player:GetAttribute("EquippedAura") or nil
	local item = MarketConfig.Get("Aura", id)
	return item and item.SpeedMulti or 1
end

return MarketConfig
