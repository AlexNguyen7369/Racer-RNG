--!nonstrict
-- Hover Car. Id "hover_car" is permanent: saves refer to it, never rename or reuse it. Model = nil would show the "?" placeholder.
return {
	Id = "hover_car",
	Name = "Hover Car",
	Rarity = "Mythic",
	Chance = 10000, -- 1 in N
	SpeedMulti = 150,
	Order = 6,
	Model = "hover_car", -- ReplicatedStorage.CarModels.hover_car (assets/studio/CarModels.rbxm, Draft05 import)
}
