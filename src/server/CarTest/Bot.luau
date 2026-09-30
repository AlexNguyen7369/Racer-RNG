--!nonstrict
-- The test bot is the shared PathDriver (see Shared/PathDriver): same driver the auto race uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PathDriver"))
