--!nonstrict
-- Rusty Hatchback. Id "rusty_hatchback" is permanent: saves refer to it, never rename or reuse it. Model = nil would show the "?" placeholder.
return {
	Id = "rusty_hatchback",
	Name = "Rusty Hatchback",
	Rarity = "Common",
	Chance = nil, -- 1 in N (nil = the catch-all: whatever no rarer car wins)
	SpeedMulti = 1.1,
	Order = 1,
	Model = "rusty_hatchback", -- ReplicatedStorage.CarModels.rusty_hatchback (assets/studio/CarModels.rbxm, Draft05 import)
}
