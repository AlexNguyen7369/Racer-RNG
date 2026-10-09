--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Config = require(ReplicatedStorage.Shared.WeatherConfig)

local WeatherService = {}
local eventId, expiresAt, nextAt = "", 0, 0
local rng = Random.new()
local baseline = nil
local started = false

local function now()
	return workspace:GetServerTimeNow()
end

local function publish()
	ReplicatedStorage:SetAttribute("WeatherEvent", eventId)
	ReplicatedStorage:SetAttribute("WeatherEndsAt", expiresAt)
	local spec = Config.Events[eventId]
	if baseline then
		Lighting.ClockTime = spec and spec.ClockTime or baseline.ClockTime
		Lighting.Brightness = spec and spec.Brightness or baseline.Brightness
		Lighting.OutdoorAmbient = spec and spec.Color:Lerp(Color3.new(1, 1, 1), 0.6) or baseline.OutdoorAmbient
	end
end

function WeatherService.Current()
	return eventId, expiresAt
end

function WeatherService.Multipliers()
	local spec = Config.Events[eventId]
	return { Luck = spec and spec.Luck or 1, Money = spec and spec.Money or 1, NpcSpeed = spec and spec.NpcSpeed or 1 }
end

-- Server/test API only: no remote lets a client select or extend an event.
function WeatherService.SetEvent(id, at)
	at = at or now()
	if type(at) ~= "number" or at ~= at or math.abs(at) == math.huge then
		return false
	end
	if id ~= "" and not Config.Events[id] then
		return false
	end
	eventId = id
	expiresAt = id ~= "" and at + Config.DURATION or 0
	nextAt = at + (id ~= "" and Config.DURATION or 0) + rng:NextInteger(Config.MIN_INTERVAL, Config.MAX_INTERVAL)
	publish()
	return true
end

function WeatherService.Tick(at)
	at = at or now()
	if type(at) ~= "number" or at ~= at or math.abs(at) == math.huge then
		return
	end
	if eventId ~= "" and at >= expiresAt then
		WeatherService.SetEvent("", at)
	elseif eventId == "" and at >= nextAt then
		WeatherService.SetEvent(Config.Order[rng:NextInteger(1, #Config.Order)], at)
	end
end

function WeatherService.Start()
	if started then
		return
	end
	started = true
	baseline =
		{ ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, OutdoorAmbient = Lighting.OutdoorAmbient }
	WeatherService.SetEvent("")
	task.spawn(function()
		while started do
			task.wait(1)
			if ReplicatedStorage:GetAttribute("CarTestRunning") ~= true then
				WeatherService.Tick()
			end
		end
	end)
end

return WeatherService
