--!nonstrict
-- Gamepass cars (docs/GAMEPASS_CARS_SPEC.md). Roblox owns the truth: the server asks UserOwnsGamePassAsync after a
-- save loads and listens to PromptGamePassPurchaseFinished, then sets the player attribute Pass_<carId>. Nothing is
-- saved. The two pedestal prompts in the spawn area buy (or equip) the car; GamepassId 0 means not on sale yet.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarAppearance = require(Shared.CarAppearance)
local CarCatalog = require(Shared.CarCatalog)
local Config = require(Shared.PassCarConfig)
local DraftCarModels = require(Shared.DraftCarModels)
local GachaService = require(script.Parent.GachaService)
local AdminService = require(script.Parent.AdminService)

local PassCarService = {}

local market = nil -- nil: the real MarketplaceService; tests: { Owns(userId, passId), Prompt(player, passId) }
local started = false

function PassCarService.SetMarket(fake)
	market = fake
end

local function userIdOf(player)
	if player:IsA("Player") then
		return player.UserId
	end
	return player:GetAttribute("UserId") -- fake players (tests)
end

local function passId(spec)
	local id = spec and spec.GamepassId
	return type(id) == "number" and id > 0 and id or nil
end

local function ownsPass(player, id)
	local ok, owned = pcall(function()
		if market then
			return market.Owns(userIdOf(player), id)
		end
		return MarketplaceService:UserOwnsGamePassAsync(userIdOf(player), id)
	end)
	return ok and owned == true -- a failed request counts as not owned for this session
end

-- Owner 2026-10-20 (GAMEPASS_CARS_SPEC section 3): admins own every gamepass car, on sale or not.
-- Only real Players: the harness's stand-in players are Folders and must not be admins through ALLOW_IN_STUDIO.
local function adminOwns(player)
	return player:IsA("Player") and AdminService.IsAdmin(player)
end

-- Asks Roblox about every pass, then takes off an equipped gamepass car the player does not own. Yields.
function PassCarService.Check(player)
	local admin = adminOwns(player)
	for _, spec in CarCatalog.Passes() do
		local id = passId(spec)
		if admin or (id and ownsPass(player, id)) then
			player:SetAttribute("Pass_" .. spec.Id, true)
		end
	end
	player:SetAttribute("PassChecked", true)
	local equipped = CarCatalog.Get(player:GetAttribute("EquippedCar"))
	if equipped and equipped.GamepassId and player:GetAttribute("Pass_" .. equipped.Id) ~= true then
		GachaService.Equip(player, CarCatalog.STARTER_ID)
	end
end

-- A finished purchase of `id` (a gamepass id): unlocks and equips its car.
function PassCarService.Purchased(player, id)
	for _, spec in CarCatalog.Passes() do
		if passId(spec) and spec.GamepassId == id then
			player:SetAttribute("Pass_" .. spec.Id, true)
			GachaService.Equip(player, spec.Id)
			return true
		end
	end
	return false
end

-- A pedestal prompt: equip when owned, else ask Roblox to show the purchase. Not on sale: nothing.
function PassCarService.Trigger(player, carId)
	if player:GetAttribute("Pass_" .. carId) == true then
		return GachaService.Equip(player, carId) -- an admin owns it even while it is not on sale
	end
	local id = passId(CarCatalog.Get(carId))
	if not id then
		return false
	end
	local ok = pcall(function()
		if market then
			market.Prompt(player, id)
		else
			MarketplaceService:PromptGamePassPurchase(player, id)
		end
	end)
	return ok
end

function PassCarService.Start()
	if started then
		return
	end
	started = true
	DraftCarModels.Ensure() -- stand-in models for cars without a real mesh yet
	local area = Workspace:FindFirstChild("SpawnArea")
	local stands = area and area:FindFirstChild("PassCars")
	for _, entry in Config.Pedestals do
		local stand = stands and stands:FindFirstChild("Pass_" .. entry.CarId)
		local pedestal = stand and stand:FindFirstChild("Pedestal")
		if pedestal then
			local car =
				CarAppearance.Display(CarCatalog.Get(entry.CarId), pedestal.CarMount.WorldCFrame, Config.CAR_SCALE)
			if car then
				car:SetAttribute("Hover", true) -- Client/BestRollView bobs it
				car.Parent = stand
			end
			pedestal.Buy.Triggered:Connect(function(player)
				PassCarService.Trigger(player, entry.CarId)
			end)
		end
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, wasPurchased)
		if wasPurchased then
			PassCarService.Purchased(player, id)
		end
	end)
	local function onPlayer(player)
		while player.Parent and not player:GetAttribute("DataLoaded") and not player:GetAttribute("DataFailed") do
			task.wait(0.2) -- the save's Equipped car must be applied before the check can take it off
		end
		if player.Parent then
			PassCarService.Check(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return PassCarService
