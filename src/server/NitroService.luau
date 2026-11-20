--!nonstrict
-- Timed nitro boost while auto racing (proposed by Vic2CS, 2026-11-19; design doc "Timed nitro boost",
-- docs/NITRO_SPEC.md). The server owns the bar: it sets when the bar is ready (the needle's time origin), grades
-- every press from the needle position at the press time, and starts the boost on the player's run.
--
-- Player attributes (read by Client/NitroInput, never trusted back):
--   NitroReadyAt  server time the bar is (or becomes) ready; the needle sweeps from it
--   NitroUntil    server time the current boost ends (0 when none)
--   NitroMulti    cruise multi of the current / last boost
--   NitroGrade    "Perfect", "Good" or "Miss" for the last press
--   NitroPresses  count of graded presses, so the client sees every result (even two equal grades in a row)
--   NitroTarget   centre of the green / gold zones (-1..1) for the bar that is (or next becomes) ready
--   NitroPressPos needle position (-1..1) the last press was graded at, drawn as the press marker
--   NitroSaved    seconds of track time the last boost saved (NitroConfig.SavedSeconds of the multi and the run time
--                 it really boosted: less than nominal when a reset cut it short), set when that boost ends
--   NitroSavedAt  server time the last boost ended; changes once per boost, so the client shows every saving
--
-- A press is ignored (nil, no lock) while the run is decided: run.Finished (past the last finish) or run.Lost (a lost
-- race between the NPC's finish and the reset, set by RaceService). docs/NITRO_SPEC.md "Saved time" / "Authority".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NitroConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NitroConfig"))
local CarService = require(script.Parent.CarService)

local NitroService = {}

local rng = Random.new()
local watching = {} -- [player] = token of the boost being watched for its end

-- A boost that ends with this many seconds still left was cut short (a reset), not counted down to 0 frame by frame
local CUT_LEFT = 0.1
-- s past the boost's planned end after which a watcher gives up (a run that stopped stepping without being reset)
local WATCH_GRACE = 1

local function now()
	return workspace:GetServerTimeNow()
end

-- The next bar's zones move to a new random spot (the client keeps drawing the old one until that bar is ready)
local function newTarget(player)
	player:SetAttribute("NitroTarget", NitroConfig.NewTarget(rng, player:GetAttribute("NitroTarget")))
end

local function reset(player, racing)
	if racing then
		newTarget(player)
		player:SetAttribute("NitroReadyAt", now() + NitroConfig.START_DELAY)
		player:SetAttribute("NitroUntil", 0)
	else
		player:SetAttribute("NitroReadyAt", nil)
		player:SetAttribute("NitroUntil", nil)
	end
	watching[player] = nil
	player:SetAttribute("NitroSaved", nil)
	player:SetAttribute("NitroSavedAt", nil)
end

-- Watches the boost just started on `run` until it ends, then publishes the time it saved (NitroSaved, NitroSavedAt).
-- RaceService counts run.NitroLeft down in run time and sets it to 0 on every reset, so the last value seen before 0
-- tells a natural end (about one frame left) from a cut (the rest was never driven). A run without NitroLeft (a test
-- stub) ends at the planned time. A run that is no longer the player's, or stops stepping, publishes nothing.
local function watchBoost(player, run, multi, untilTime)
	local token = {}
	watching[player] = token
	local lastLeft = type(run.NitroLeft) == "number" and run.NitroLeft or nil
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if watching[player] ~= token then
			connection:Disconnect()
			return
		end
		local t = now()
		if CarService.GetRun(player) ~= run or t > untilTime + WATCH_GRACE then
			watching[player] = nil
			connection:Disconnect()
			return
		end
		local boosted = nil
		if lastLeft == nil then
			if t >= untilTime then
				boosted = NitroConfig.DURATION
			end
		else
			local left = run.NitroLeft
			if type(left) == "number" and left > 0 then
				lastLeft = left
			else
				boosted = lastLeft <= CUT_LEFT and NitroConfig.DURATION or math.max(0, NitroConfig.DURATION - lastLeft)
			end
		end
		if boosted == nil then
			return
		end
		watching[player] = nil
		connection:Disconnect()
		if boosted < NitroConfig.DURATION and player:GetAttribute("NitroUntil") == untilTime then
			player:SetAttribute("NitroUntil", t) -- cut short: the client stops drawing the boost now
		end
		player:SetAttribute("NitroSaved", NitroConfig.SavedSeconds(multi, boosted))
		player:SetAttribute("NitroSavedAt", t)
	end)
end

-- The press time the server grades: the client's claimed time when it is plausible (ping), else the arrival time.
-- A client can shift its press by at most LATENCY_WINDOW, never into the future.
local function pressTime(claimed, arrived)
	if type(claimed) == "number" and claimed == claimed and claimed <= arrived + 0.05 then
		if claimed >= arrived - NitroConfig.LATENCY_WINDOW then
			return math.min(claimed, arrived)
		end
	end
	return arrived
end

-- Grades a press and applies it. Returns the grade, or nil when the press was ignored (not racing, not ready).
function NitroService.Press(player, claimed)
	local readyAt = player:GetAttribute("NitroReadyAt")
	if type(readyAt) ~= "number" or not CarService.IsAutoRacing(player) then
		return nil
	end
	local run = CarService.GetRun(player)
	if not run or type(run.Nitro) ~= "function" then
		return nil
	end
	if run.Finished == true or run.Lost == true then
		return nil -- the race is decided (past the last finish, or lost and waiting for the reset): no press counts
	end
	local arrived = now()
	local t = pressTime(claimed, arrived)
	local boostingUntil = player:GetAttribute("NitroUntil") or 0
	if t < readyAt or arrived < boostingUntil then
		return nil -- charging, locked after a miss, or still boosting: the press does nothing and costs nothing
	end
	local position = NitroConfig.NeedleAt(t, readyAt)
	local grade = NitroConfig.Grade(position, player:GetAttribute("NitroTarget"))
	local multi = NitroConfig.MultiFor(grade)
	player:SetAttribute("NitroPressPos", position)
	newTarget(player) -- graded against the shown target; the next bar gets a new one
	if grade ~= "Miss" and run:Nitro(multi, NitroConfig.DURATION) then
		local untilTime = arrived + NitroConfig.DURATION
		player:SetAttribute("NitroUntil", untilTime)
		player:SetAttribute("NitroMulti", multi)
		player:SetAttribute("NitroReadyAt", untilTime + NitroConfig.RECHARGE)
		watchBoost(player, run, multi, untilTime)
	else
		grade = "Miss" -- includes a good press the run refused (a duel, a stopped run)
		player:SetAttribute("NitroReadyAt", arrived + NitroConfig.MISS_COOLDOWN) -- MISS_COOLDOWN = RECHARGE
	end
	player:SetAttribute("NitroGrade", grade)
	player:SetAttribute("NitroPresses", (player:GetAttribute("NitroPresses") or 0) + 1)
	return grade
end

local function watch(player)
	player:GetAttributeChangedSignal("AutoRacing"):Connect(function()
		reset(player, player:GetAttribute("AutoRacing") == true)
	end)
	reset(player, player:GetAttribute("AutoRacing") == true)
end

function NitroService.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("Nitro")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "Nitro"
		remote.Parent = remotes
	end
	-- No extra rate limit: a press while not ready is ignored, and every graded press locks the bar for seconds.
	remote.OnServerEvent:Connect(function(player, claimed)
		NitroService.Press(player, claimed)
	end)
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		watching[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return NitroService
