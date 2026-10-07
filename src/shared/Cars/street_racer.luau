--!nonstrict
-- Street Racer. Id "street_racer" is permanent: saves refer to it, never rename or reuse it. Model = nil would show the "?" placeholder.
return {
	Id = "street_racer",
	Name = "Street Racer",
	Rarity = "Epic",
	Chance = 250, -- 1 in N
	SpeedMulti = 6,
	Order = 4,
	Model = "street_racer", -- ReplicatedStorage.CarModels.street_racer (assets/studio/CarModels.rbxm, Draft05 import)
}
