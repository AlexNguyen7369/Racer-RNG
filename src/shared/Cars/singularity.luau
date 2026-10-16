--!nonstrict
-- Singularity, a gamepass car (docs/GAMEPASS_CARS_SPEC.md): bought, never rolled, not in the index.
-- Id "singularity" is permanent: never rename or reuse it.
return {
	Id = "singularity",
	Name = "Singularity",
	Rarity = "Mythic",
	Chance = nil,
	SpeedMulti = 500, -- proposed
	Order = 102,
	Model = "singularity", -- Shared/DraftCarModels builds a stand-in until a real mesh has this name
	GamepassId = 0, -- 0 = not on sale yet; the owner pastes the pass id from the Creator Dashboard
	RobuxPrice = 999, -- listed price the Shop shows until Roblox reports the live one (owner, 2026-10-16)
}
