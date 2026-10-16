--!nonstrict
-- Ember Wyvern, a gamepass car (docs/GAMEPASS_CARS_SPEC.md): bought, never rolled, not in the index.
-- Id "ember_wyvern" is permanent: never rename or reuse it.
return {
	Id = "ember_wyvern",
	Name = "Ember Wyvern",
	Rarity = "Mythic",
	Chance = nil,
	SpeedMulti = 500, -- proposed
	Order = 101,
	Model = "ember_wyvern", -- Shared/DraftCarModels builds a stand-in until a real mesh has this name
	GamepassId = 0, -- 0 = not on sale yet; the owner pastes the pass id from the Creator Dashboard
}
