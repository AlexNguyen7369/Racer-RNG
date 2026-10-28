--!nonstrict
-- Turns the cars on the spawn-area showcase pedestals (docs/LEADERBOARD_SPEC.md 3a, docs/GAMEPASS_CARS_SPEC.md 5),
-- bobs the ones marked Hover and flaps parts named Wing_L / Wing_R. Display only: the servers pick the cars. The
-- motion is local, so nothing replicates per frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("LeaderboardConfig"))
local PassCarConfig = require(Shared:WaitForChild("PassCarConfig"))
local area = Workspace:WaitForChild("SpawnArea")
local best = area:WaitForChild("BestRoll")

local LIFT = 1 -- studs above the platform (before CAR_SCALE): the lowest point of the bob stays clear of it
local BOB = 0.4 -- studs
local FLAP = math.rad(25)
-- car -> { [part] = { Rel, Side, Hinge } }: each part's place relative to the pedestal's CarMount, read once from the
-- server's placement. Model pivots are not used: on the client a Model's pivot may sit at its box centre instead of
-- its base, which put the cars into the platform. Not a weak table (a lost entry would be re-read mid-motion);
-- entries go when their car leaves the world.
local states = {}

local function animate(car, t)
	local pedestal = car.Parent and car.Parent:FindFirstChild("Pedestal")
	local mount = pedestal and pedestal:FindFirstChild("CarMount")
	if not mount then
		return
	end
	local parts = states[car]
	if not parts then
		parts = {}
		states[car] = parts
	end
	local bob = car:GetAttribute("Hover") and (LIFT + math.sin(t * 2) * BOB) * PassCarConfig.CAR_SCALE or 0
	local frame = mount.WorldCFrame * CFrame.new(0, bob, 0) * CFrame.Angles(0, math.rad(Config.BEST_ROLL.SPIN) * t, 0)
	local flap = FLAP * math.sin(t * 5)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			local entry = parts[part]
			if not entry then -- first sight (parts may stream in late): still where the server put it
				entry = { Rel = mount.WorldCFrame:ToObjectSpace(part.CFrame) }
				-- A rigged car flaps its wings through bones (Client/WyvernAnimator), not by turning the parts.
				local rigged = car:GetAttribute("Rig") ~= nil
				entry.Side = not rigged and ((part.Name == "Wing_L" and -1) or (part.Name == "Wing_R" and 1)) or nil
				entry.Hinge = entry.Side and part.PivotOffset
				parts[part] = entry
			end
			local cf = frame * entry.Rel
			if entry.Side then -- turn about the wing's inner edge (its pivot)
				cf = cf * entry.Hinge * CFrame.Angles(0, 0, entry.Side * flap) * entry.Hinge:Inverse()
			end
			part.CFrame = cf
		end
	end
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for car in states do
		if not car.Parent then
			states[car] = nil
		end
	end
	local car = best:FindFirstChild("Car")
	if car then
		animate(car, t)
	end
	local stands = area:FindFirstChild("PassCars")
	for _, stand in stands and stands:GetChildren() or {} do
		local passCar = stand:FindFirstChild("Car")
		if passCar then
			animate(passCar, t)
		end
	end
end)
