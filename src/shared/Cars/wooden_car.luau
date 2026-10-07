--!nonstrict
-- Wooden Car. Id "wooden_car" is permanent: saves refer to it, never rename or reuse it. Model = nil would show the "?" placeholder.
return {
	Id = "wooden_car",
	Name = "Wooden Car",
	Rarity = "Uncommon",
	Chance = 10, -- 1 in N
	SpeedMulti = 1.25,
	Order = 2,
	Model = "wooden_car", -- ReplicatedStorage.CarModels.wooden_car (assets/studio/CarModels.rbxm, Draft05 import)
}
