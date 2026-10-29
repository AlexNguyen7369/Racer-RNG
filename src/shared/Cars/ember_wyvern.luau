--!nonstrict
-- Ember Wyvern, a gamepass car (docs/GAMEPASS_CARS_SPEC.md): bought, never rolled, shown separately in the Index Gamepass section.
-- Id "ember_wyvern" is permanent: never rename or reuse it.
return {
	Id = "ember_wyvern",
	Name = "Ember Wyvern",
	Rarity = "Secret",
	Chance = nil,
	SpeedMulti = 2000, -- proposed
	Order = 101,
	Model = "ember_wyvern", -- Shared/DraftCarModels builds a stand-in until a real mesh has this name
	GamepassId = 0, -- 0 = not on sale yet; the owner pastes the pass id from the Creator Dashboard
	RobuxPrice = 799, -- listed price the Shop shows until Roblox reports the live one (owner, 2026-10-28)
	SkinScale = 2.5, -- placeholder: shown much bigger in races, pedestal capped (docs/WYVERN_FLIGHT_SPEC.md section 1)
}
