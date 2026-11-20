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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NitroConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NitroConfig"))
local CarService = require(script.Parent.CarService)

local NitroService = {}

local rng = Random.new()

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
	else
		grade = "Miss" -- includes a good press the run refused (a duel, or past the last finish)
		player:SetAttribute("NitroReadyAt", arrived + NitroConfig.MISS_COOLDOWN)
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
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return NitroService
