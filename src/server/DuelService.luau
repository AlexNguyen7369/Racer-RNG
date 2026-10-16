--!nonstrict
-- Duels, player vs player (docs/DUEL_SPEC.md). A requests (the "Duel" prompt on B's on-foot character), A picks a
-- track both unlocked, B accepts or declines. Both get a car held at that track's start; COUNTDOWN after both are
-- seated the cars are released in the same step and auto-race that ONE track. The server decides everything; the
-- winner gets DuelWins + 1. No stake: a duel run has no NPC, pays no pad and banks nothing.
--
-- One table per pair, in duelOf[player] for both players. Phases: "Picking" -> "Invited" -> "Countdown" ->
-- "Racing". Tick() (every Heartbeat) handles the timeouts, the release, forfeits and finished races.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.DuelConfig)
local CarService = require(script.Parent.CarService)
local RaceService = require(script.Parent.RaceService)

local DuelService = {}

local PROMPT = "DuelPrompt"

local clock = os.clock
local notifyOverride = nil
local remote = nil
local duelOf = {} -- player -> duel
local lastRequest = {} -- player -> clock of their last accepted request
local lastMessage = {} -- player -> os.clock of their last remote message
local started = false

-- Tests: every timer of the service reads this clock. nil restores the real one.
function DuelService.SetClock(fn)
	clock = fn or os.clock
end

-- Tests: fn(player, message) receives every message a client would get. nil restores the remote.
function DuelService.SetNotify(fn)
	notifyOverride = fn
end

local function notify(player, message)
	if notifyOverride then
		notifyOverride(player, message)
	elseif remote and typeof(player) == "Instance" and player:IsA("Player") and player.Parent then
		remote:FireClient(player, message)
	end
end

local function trackCount()
	local route = RaceService.GetRoute()
	return route and type(route.Tracks) == "table" and #route.Tracks or 0
end

-- The highest track the player may duel on: the one after the best track they won (Track 1 always).
function DuelService.Unlocked(player)
	local best = player:GetAttribute("BestTrack")
	best = (type(best) == "number" and best == best) and math.floor(best) or 0
	return math.clamp(best + 1, 1, math.max(trackCount(), 1))
end

-- The tracks both players unlocked: 1 .. min(Unlocked(a), Unlocked(b)).
function DuelService.Choices(a, b)
	local list = {}
	for n = 1, math.min(DuelService.Unlocked(a), DuelService.Unlocked(b)) do
		table.insert(list, n)
	end
	return list
end

function DuelService.StateOf(player)
	local duel = duelOf[player]
	return duel and duel.Phase or "None"
end

local function loaded(player)
	return player:GetAttribute("DataLoaded") == true and player:GetAttribute("DataFailed") ~= true
end

local function onFoot(player)
	local character = CarService.GetCharacter(player)
	local humanoid = character and character.Parent and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil
		and humanoid.Health > 0
		and player:GetAttribute("AutoRacing") ~= true
		and player:GetAttribute("RaceEvent") == "Off"
end

local function other(duel, player)
	return duel.A == player and duel.B or duel.A
end

local function clear(duel)
	for _, p in { duel.A, duel.B } do
		if duelOf[p] == duel then
			duelOf[p] = nil
		end
	end
end

-- Ends a request that never became a race. `except` (a player who left) is not told.
local function cancel(duel, reason, except)
	clear(duel)
	for _, p in { duel.A, duel.B } do
		-- B knows nothing of the request before the pick
		if p ~= except and (p == duel.A or duel.Phase ~= "Picking") then
			notify(p, { Type = "Cancelled", Reason = reason })
		end
	end
end

-- Ends a race (or its countdown): results, DuelWins, both cars removed, both players on foot at the walk spawn.
local function finish(duel, resultA, resultB)
	clear(duel)
	local results = { [duel.A] = resultA, [duel.B] = resultB }
	for _, p in { duel.A, duel.B } do
		if results[p] == "Win" then
			p:SetAttribute("DuelWins", (p:GetAttribute("DuelWins") or 0) + 1)
		end
		notify(p, {
			Type = "Result",
			Result = results[p],
			Track = duel.Track,
			Time = duel.Finish[p],
			OpponentTime = duel.Finish[other(duel, p)],
		})
		task.spawn(pcall, CarService.SetAutoRace, p, false) -- yields until the avatar stands
	end
end

-- A requests a duel against B. Returns true, or false and the reason; a refusal changes nothing.
function DuelService.Request(a, b)
	if a == b then
		return false, "Self"
	end
	if not (loaded(a) and loaded(b)) then
		return false, "NotLoaded"
	end
	if not (onFoot(a) and onFoot(b)) then
		return false, "NotOnFoot"
	end
	if duelOf[a] or duelOf[b] then
		return false, "Busy"
	end
	local now = clock()
	if lastRequest[a] and now - lastRequest[a] < Config.REQUEST_COOLDOWN then
		return false, "Cooldown"
	end
	lastRequest[a] = now
	local duel = { A = a, B = b, Phase = "Picking", At = now, Seated = {}, Finish = {} }
	duelOf[a], duelOf[b] = duel, duel
	notify(a, { Type = "PickTrack", Opponent = b.Name, Tracks = DuelService.Choices(a, b) })
	return true
end

-- A's track pick, validated against a freshly computed list.
function DuelService.Pick(a, trackNumber)
	local duel = duelOf[a]
	if not duel or duel.A ~= a or duel.Phase ~= "Picking" then
		return false, "NoRequest"
	end
	if type(trackNumber) ~= "number" or not table.find(DuelService.Choices(duel.A, duel.B), trackNumber) then
		return false, "BadTrack"
	end
	duel.Track = trackNumber
	duel.Phase = "Invited"
	duel.At = clock()
	notify(duel.B, { Type = "Invite", Opponent = a.Name, Track = trackNumber })
	return true
end

-- B's answer. Rule 1 is checked again on accept.
function DuelService.Respond(b, accept)
	local duel = duelOf[b]
	if type(accept) ~= "boolean" or not duel or duel.B ~= b or duel.Phase ~= "Invited" then
		return false, "NoRequest"
	end
	if not accept then
		cancel(duel, "Declined")
		return true
	end
	for _, p in { duel.A, duel.B } do
		if not (loaded(p) and onFoot(p)) then
			cancel(duel, "NotOnFoot")
			return false, "NotOnFoot"
		end
	end
	duel.Phase = "Countdown"
	duel.At = clock()
	for slot, p in { duel.A, duel.B } do
		-- Yields until the avatar is seated in its held car, so each player is seated on their own thread
		task.spawn(pcall, CarService.SetAutoRace, p, true, {
			Track = duel.Track,
			Slot = slot,
			OnSeated = function()
				if duelOf[p] ~= duel or duel.Phase ~= "Countdown" then
					return
				end
				duel.Seated[p] = true
				if duel.Seated[duel.A] and duel.Seated[duel.B] then
					duel.CountdownAt = clock()
					local message = {
						Type = "Countdown",
						Track = duel.Track,
						ServerStart = workspace:GetServerTimeNow() + Config.COUNTDOWN,
					}
					notify(duel.A, message)
					notify(duel.B, message)
				end
			end,
		})
	end
	return true
end

-- Stop Auto, death, a respawn or leaving during the countdown or the race.
local function forfeited(duel, player)
	return duel.Left == player or not CarService.IsAutoRacing(player) or CarService.GetCar(player) == nil
end

local function release(duel)
	duel.Phase = "Racing"
	duel.At = clock()
	for _, p in { duel.A, duel.B } do
		CarService.ReleaseDuel(p, {
			Track = duel.Track,
			OnFinish = function(_, seconds)
				duel.Finish[p] = seconds
			end,
		})
	end
end

local function tickDuel(duel, now)
	if duel.Phase == "Picking" then
		if now - duel.At >= Config.PICK_TIMEOUT then
			cancel(duel, "PickTimeout")
		end
	elseif duel.Phase == "Invited" then
		if now - duel.At >= Config.INVITE_TIMEOUT then
			cancel(duel, "InviteTimeout")
		end
	else
		local outA, outB = forfeited(duel, duel.A), forfeited(duel, duel.B)
		if outA or outB then
			finish(
				duel,
				(outA and outB) and "Draw" or outA and "Lose" or "Win",
				(outA and outB) and "Draw" or outB and "Lose" or "Win"
			)
		elseif duel.Phase == "Countdown" then
			if duel.CountdownAt and now - duel.CountdownAt >= Config.COUNTDOWN then
				release(duel)
			end
		else
			local timeA, timeB = duel.Finish[duel.A], duel.Finish[duel.B]
			if timeA or timeB then
				-- First to the finish; both in the same step: the lower time, then a draw
				if timeA and timeB and timeA == timeB then
					finish(duel, "Draw", "Draw")
				elseif timeA and (not timeB or timeA < timeB) then
					finish(duel, "Win", "Lose")
				else
					finish(duel, "Lose", "Win")
				end
			elseif now - duel.At >= Config.RACE_TIMEOUT then
				finish(duel, "Draw", "Draw")
			end
		end
	end
end

function DuelService.Tick()
	local now = clock()
	local seen = {}
	for _, duel in table.clone(duelOf) do
		if not seen[duel] then
			seen[duel] = true
			tickDuel(duel, now)
		end
	end
end

-- A player left: a pending request is cancelled, a countdown or race is forfeited.
function DuelService.PlayerLeft(player)
	local duel = duelOf[player]
	if duel then
		if duel.Phase == "Picking" or duel.Phase == "Invited" then
			cancel(duel, "Left", player)
		else
			duel.Left = player
			tickDuel(duel, clock())
		end
	end
	lastRequest[player] = nil
	lastMessage[player] = nil
end

-- The "Duel" prompt on a character's root: only shown while its owner is on foot.
local function addPrompt(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or root:FindFirstChild(PROMPT) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT
	prompt.ActionText = "Duel"
	prompt.ObjectText = player.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0.5 -- a hold, so walking past somebody never challenges them
	prompt.MaxActivationDistance = Config.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = player:GetAttribute("AutoRacing") ~= true
	prompt.Parent = root
	prompt.Triggered:Connect(function(from)
		local ok, reason = DuelService.Request(from, player)
		if not ok then
			notify(from, { Type = "Cancelled", Reason = reason }) -- a refused request tells A why
		end
	end)
end

function DuelService.Start()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	remote = remotes:FindFirstChild("Duel")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "Duel"
		remote.Parent = remotes
	end
	remote.OnServerEvent:Connect(function(player, action, value)
		local now = os.clock()
		if lastMessage[player] and now - lastMessage[player] < Config.REMOTE_INTERVAL then
			return
		end
		lastMessage[player] = now
		if action == "Pick" and type(value) == "number" then
			DuelService.Pick(player, value)
		elseif action == "Respond" and type(value) == "boolean" then
			DuelService.Respond(player, value)
		end
	end)

	local function onPlayer(player)
		player.CharacterAdded:Connect(function(character)
			addPrompt(player, character)
		end)
		if player.Character then
			task.spawn(addPrompt, player, player.Character)
		end
		player:GetAttributeChangedSignal("AutoRacing"):Connect(function()
			local prompt = player.Character and player.Character:FindFirstChild(PROMPT, true)
			if prompt then
				prompt.Enabled = player:GetAttribute("AutoRacing") ~= true
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(DuelService.PlayerLeft)
	RunService.Heartbeat:Connect(DuelService.Tick)
end

return DuelService
