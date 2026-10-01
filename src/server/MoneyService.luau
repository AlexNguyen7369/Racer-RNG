--!nonstrict
-- Pays money into the player's stats. The server decides every number: a winnings pad (tag "WinPad")
-- carries a Cash attribute set by TrackBuilder, and touching it with your car adds that to
-- leaderstats.Money. Nothing the client sends is ever used as an amount.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local GachaService = require(script.Parent.GachaService)

local MoneyService = {}

MoneyService.COOLDOWN = 5 -- seconds before the same player can collect from the same pad again

local MAX_AWARD = 1e9

local lastCollect = setmetatable({}, { __mode = "k" }) -- player -> { [pad] = time }

function MoneyService.Setup(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local money = stats:FindFirstChild("Money")
	if not money then
		money = Instance.new("IntValue")
		money.Name = "Money"
		money.Value = 0
		money.Parent = stats
	end
	return money
end

-- Returns the new balance, or nil if the amount is not a sane number of at least $1.
function MoneyService.Award(player, amount)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount > MAX_AWARD then
		return nil
	end
	amount = math.floor(amount) -- IntValue: whole dollars only
	if amount < 1 then
		return nil
	end
	local money = MoneyService.Setup(player)
	money.Value += amount
	return money.Value
end

-- Pays the pad's Cash to the player unless it is cooling down. Returns the amount paid (0 if none).
function MoneyService.Collect(player, pad, now)
	if not CollectionService:HasTag(pad, "WinPad") then
		return 0
	end
	local cash = pad:GetAttribute("Cash")
	if type(cash) ~= "number" or cash <= 0 then
		return 0
	end
	cash = math.floor(cash * GachaService.MoneyMulti(player)) -- Base Money Multi from stat points
	now = now or os.clock()
	local perPlayer = lastCollect[player]
	if not perPlayer then
		perPlayer = setmetatable({}, { __mode = "k" })
		lastCollect[player] = perPlayer
	end
	local last = perPlayer[pad]
	if last and now - last < MoneyService.COOLDOWN then
		return 0
	end
	if MoneyService.Award(player, cash) == nil then
		return 0
	end
	perPlayer[pad] = now
	return math.floor(cash) -- what was actually paid
end

-- The player who owns the car this part belongs to (CarService tags cars with Owner = UserId).
function MoneyService.PlayerFromPart(part)
	local car = part:FindFirstAncestorOfClass("Model")
	local owner = car and car:GetAttribute("Owner")
	if type(owner) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(owner)
end

function MoneyService.Start()
	Players.PlayerAdded:Connect(MoneyService.Setup)
	for _, player in Players:GetPlayers() do
		MoneyService.Setup(player)
	end

	local function watchPad(pad)
		pad.Touched:Connect(function(hit)
			local player = MoneyService.PlayerFromPart(hit)
			if player then
				MoneyService.Collect(player, pad)
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal("WinPad"):Connect(watchPad)
	for _, pad in CollectionService:GetTagged("WinPad") do
		watchPad(pad)
	end
end

return MoneyService
