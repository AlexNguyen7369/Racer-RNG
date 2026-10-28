--!nonstrict
-- Friends-in-server boost (docs/FRIENDS_BOOST_SPEC.md): +10% Luck and +10% Money per Roblox friend in the
-- same server, capped at +40%. Friendships are checked once per player pair on join (never per roll) and
-- cached; player attributes FriendsInServer and FriendBoost show the result to the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FriendBoostService = {}
FriendBoostService.PER_FRIEND = 0.10 -- placeholder
FriendBoostService.CAP = 0.40 -- placeholder: the most the boost adds
FriendBoostService.RETRY_DELAY = 10 -- seconds before a failed IsFriendsWith is tried once more
FriendBoostService.TEST_ATTRIBUTE = "FriendBoostTestCount" -- ReplicatedStorage, Studio only

local friends = {} -- player -> { [otherPlayer] = true }

-- The multi for a friend count. NaN, negative and inf counts are safe.
function FriendBoostService.MultiFor(count)
	if type(count) ~= "number" or count ~= count or count <= 0 then
		return 1
	end
	return 1 + math.min(FriendBoostService.PER_FRIEND * math.floor(math.min(count, 1e6)), FriendBoostService.CAP)
end

local function testCount()
	local n = ReplicatedStorage:GetAttribute(FriendBoostService.TEST_ATTRIBUTE)
	if RunService:IsStudio() and type(n) == "number" and n == n then
		return n
	end
	return nil
end

function FriendBoostService.Count(player)
	local override = testCount()
	if override then
		return math.clamp(math.floor(override), 0, 1e6)
	end
	local count = 0
	for other in friends[player] or {} do
		if other.Parent == Players then
			count += 1
		end
	end
	return count
end

function FriendBoostService.Multi(player)
	return FriendBoostService.MultiFor(FriendBoostService.Count(player))
end

local function publish(player)
	if player.Parent ~= Players then
		return
	end
	local count = FriendBoostService.Count(player)
	player:SetAttribute("FriendsInServer", count)
	player:SetAttribute("FriendBoost", FriendBoostService.MultiFor(count))
end

local function link(a, b)
	if friends[a] and friends[b] and a.Parent == Players and b.Parent == Players then
		friends[a][b] = true
		friends[b][a] = true
		publish(a)
		publish(b)
	end
end

-- Friendship is mutual, so one IsFriendsWith call per pair; a failure counts as not-friends and is retried once.
local function check(a, b)
	task.spawn(function()
		for attempt = 1, 2 do
			local ok, isFriend = pcall(a.IsFriendsWith, a, b.UserId)
			if ok then
				if isFriend == true then
					link(a, b)
				end
				return
			end
			if attempt == 1 then
				task.wait(FriendBoostService.RETRY_DELAY)
				if a.Parent ~= Players or b.Parent ~= Players then
					return
				end
			end
		end
	end)
end

local function onAdded(player)
	if friends[player] then
		return
	end
	friends[player] = {}
	publish(player)
	for _, other in Players:GetPlayers() do
		if other ~= player and friends[other] then
			check(player, other)
		end
	end
end

local function onRemoving(player)
	local mine = friends[player]
	friends[player] = nil
	for other in mine or {} do
		if friends[other] then
			friends[other][player] = nil
			publish(other)
		end
	end
end

function FriendBoostService.Start()
	Players.PlayerAdded:Connect(onAdded)
	Players.PlayerRemoving:Connect(onRemoving)
	for _, player in Players:GetPlayers() do
		onAdded(player)
	end
	ReplicatedStorage:GetAttributeChangedSignal(FriendBoostService.TEST_ATTRIBUTE):Connect(function()
		for _, player in Players:GetPlayers() do
			publish(player)
		end
	end)
end

-- Self-check of the curve (cheap, runs once on require).
assert(FriendBoostService.MultiFor(0) == 1 and FriendBoostService.MultiFor(0 / 0) == 1, "FriendBoost curve")
assert(
	math.abs(FriendBoostService.MultiFor(2) - 1.2) < 1e-9
		and math.abs(FriendBoostService.MultiFor(math.huge) - 1.4) < 1e-9,
	"FriendBoost curve"
)

return FriendBoostService
