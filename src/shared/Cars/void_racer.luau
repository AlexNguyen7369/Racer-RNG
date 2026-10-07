--!nonstrict
-- Void Racer. Id "void_racer" is permanent: saves refer to it, never rename or reuse it. Model = nil would show the "?" placeholder.
return {
	Id = "void_racer",
	Name = "Void Racer",
	Rarity = "Secret",
	Chance = 100000, -- 1 in N
	SpeedMulti = 1000,
	Order = 7,
	Model = "void_racer", -- ReplicatedStorage.CarModels.void_racer (assets/studio/CarModels.rbxm, Draft05 import)
}
