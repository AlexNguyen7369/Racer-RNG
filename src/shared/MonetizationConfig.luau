--!nonstrict
-- Shop catalogue (docs/GAMEPASS_SHOP_SPEC.md, docs/SHOP_PURCHASES_SPEC.md). The Creator Dashboard supplies the real
-- ids; zero keeps an entry visible as "Coming soon". RobuxPrice is the listed price (proposed) shown until Roblox
-- reports the live one. Title/Color/Icon are presentation only.
local MonetizationConfig = {}

local function pass(id, name, price, description, color, icon)
	return {
		Id = id,
		Name = name,
		GamepassId = 0,
		RobuxPrice = price,
		Description = description,
		Color = color,
		Icon = icon,
	}
end
local GOLD = Color3.fromRGB(255, 196, 70)
local MINT = Color3.fromRGB(110, 230, 160)
local SKY = Color3.fromRGB(110, 205, 255)
local VIOLET = Color3.fromRGB(175, 120, 255)
local ROSE = Color3.fromRGB(255, 130, 190)
local LIME = Color3.fromRGB(200, 240, 110)

MonetizationConfig.Gamepasses = {
	pass("vip", "VIP", 499, "VIP title, perks and priority treatment!", GOLD, "Rebirth"),
	pass("auto_roll_2x", "2x Auto-Roll", 199, "Roll twice as fast!", MINT, "Index"),
	pass("extra_roll_1", "Extra Roll I", 299, "+1 auto-roll at once (2 total)!", SKY, "Index"),
	pass("extra_roll_2", "Extra Roll II", 599, "+1 more auto-roll (3 total)!", VIOLET, "Index"),
	pass("speed_doubler_1", "Speed Doubler I", 99, "Doubles Speed gain!", SKY, "Upgrade"),
	pass("speed_doubler_2", "Speed Doubler II", 199, "Doubles it again (4x)!", SKY, "Upgrade"),
	pass("speed_doubler_3", "Speed Doubler III", 399, "Doubles it again (8x)!", VIOLET, "Upgrade"),
	pass("speed_doubler_4", "Speed Doubler IV", 799, "Doubles it again (16x)!", VIOLET, "Upgrade"),
	pass("speed_doubler_5", "Speed Doubler V", 1599, "Doubles it again (32x)!", ROSE, "Upgrade"),
	pass("money_2x", "2x Money", 249, "Doubles race payouts!", GOLD, "Shop"),
	pass("luck_1", "Lucky", 149, "Permanent +1 Luck!", LIME, "Stats"),
	pass("luck_2", "ULTRA Lucky", 299, "Permanent +2 Luck!", VIOLET, "Stats"),
	pass("workshop_gold", "Gold Workshop", 199, "Permanent Gold workshop tier!", GOLD, "Upgrade"),
	pass("workshop_diamond", "Diamond Workshop", 499, "Permanent Diamond workshop tier!", SKY, "Upgrade"),
	pass("workshop_void", "Void Workshop", 999, "Permanent Void workshop tier!", VIOLET, "Upgrade"),
}

-- Developer products. Grants are boost ids from Shared/BoostConfig; Server/ShopService grants them per receipt.
local bundle = {}
for _, category in { "Luck", "Money", "Speed" } do
	for _, roman in { "I", "II", "III" } do
		bundle[category .. roman] = 10
	end
end
MonetizationConfig.Products = {
	{
		Id = "potion_luck_pack",
		Name = "x5 Luck Potion III",
		Description = "x2 Luck",
		Section = "Potions",
		ProductId = 0,
		RobuxPrice = 49,
		Grants = { LuckIII = 5 },
	},
	{
		Id = "potion_money_pack",
		Name = "x5 Money Potion III",
		Description = "x2 Money",
		Section = "Potions",
		ProductId = 0,
		RobuxPrice = 49,
		Grants = { MoneyIII = 5 },
	},
	{
		Id = "potion_speed_pack",
		Name = "x5 Speed Potion III",
		Description = "x2 Speed gain",
		Section = "Potions",
		ProductId = 0,
		RobuxPrice = 49,
		Grants = { SpeedIII = 5 },
	},
	{
		Id = "potion_bundle",
		Name = "POTION BUNDLE!",
		Description = "x10 of EVERY potion",
		Section = "Bundle",
		ProductId = 0,
		RobuxPrice = 999,
		Grants = bundle,
	},
	{
		Id = "server_luck_2x",
		Name = "2x Server Luck",
		Description = "Whole server, 15 min",
		Section = "ServerLuck",
		ProductId = 0,
		RobuxPrice = 199,
	},
	{
		Id = "server_luck_4x",
		Name = "4x Server Luck",
		Description = "Whole server, 15 min",
		Section = "ServerLuck",
		ProductId = 0,
		RobuxPrice = 399,
	},
	{
		Id = "server_luck_8x",
		Name = "8x Server Luck",
		Description = "Whole server, 15 min",
		Section = "ServerLuck",
		ProductId = 0,
		RobuxPrice = 799,
	},
}

-- Offline reward double (docs/OFFLINE_DOUBLE_SPEC.md). Not a Shop entry: it is sold only from the offline reward
-- panel. ProductId 0 = not on sale yet; set the real id: create a 19 R$ developer product on the Creator Dashboard
-- and paste its id here. RobuxPrice and WINDOW_SECONDS are placeholders.
MonetizationConfig.OfflineDouble = {
	Id = "offline_double",
	Name = "Double offline Speed",
	ProductId = 0,
	RobuxPrice = 19,
	WINDOW_SECONDS = 300,
}

-- Separate ids keep a delayed ordinary receipt from consuming a gift reservation.
-- Owner creates the corresponding recipient-owned developer products before enabling.
for _, product in MonetizationConfig.Products do
	if product.Grants then
		product.GiftProductId = 0
	end
end

return MonetizationConfig
