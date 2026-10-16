--!nonstrict
-- Singularity, a gamepass car (docs/GAMEPASS_CARS_SPEC.md): bought, never rolled, not in the index.
-- Id "singularity" is permanent: never rename or reuse it.
return {
	Id = "singularity",
	Name = "Singularity",
	Rarity = "Secret",
	Chance = nil,
	SpeedMulti = 2000, -- proposed
	Order = 102,
	Model = "singularity", -- Shared/DraftCarModels builds a stand-in until a real mesh has this name
	GamepassId = 0, -- 0 = not on sale yet; the owner pastes the pass id from the Creator Dashboard
}
