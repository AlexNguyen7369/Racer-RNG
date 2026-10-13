--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Config = require(ReplicatedStorage.Shared.WeatherConfig)

local WeatherService = {}
local eventId, expiresAt, nextAt = "", 0, 0
local rng = Random.new()
local baseline = nil
local started = false
-- The sky instances (made by Start when the place has none) and the properties an event sets on each.
local sky = {}
local SKY_PROPS = {
	Atmosphere = { "Color", "Density", "Haze" },
	Clouds = { "Cover", "Density", "Color" },
}

local function now()
	return workspace:GetServerTimeNow()
end

local function publish()
	ReplicatedStorage:SetAttribute("WeatherEvent", eventId)
	ReplicatedStorage:SetAttribute("WeatherEndsAt", expiresAt)
	-- A weather without a Sky (clear) leaves Lighting and the sky at the baseline.
	local spec = Config.Events[eventId]
	spec = spec and spec.Sky and spec
	if baseline then
		Lighting.ClockTime = spec and spec.ClockTime or baseline.ClockTime
		Lighting.Brightness = spec and spec.Brightness or baseline.Brightness
		Lighting.OutdoorAmbient = spec and spec.Color:Lerp(Color3.new(1, 1, 1), 0.6) or baseline.OutdoorAmbient
		local to = spec and spec.Sky or baseline.Sky
		for name, props in SKY_PROPS do
			for _, prop in props do
				sky[name][prop] = to[name][prop]
			end
		end
		sky.Sky.StarCount = to.StarCount
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
	nextAt = at + Config.INTERVAL
	publish()
	return true
end

function WeatherService.Tick(at)
	at = at or now()
	if type(at) ~= "number" or at ~= at or math.abs(at) == math.huge then
		return
	end
	if eventId ~= "" and at >= expiresAt then
		-- An expiry does not move the next start: weathers begin INTERVAL apart, start to start.
		eventId, expiresAt = "", 0
		publish()
	end
	if eventId == "" and at >= nextAt then
		WeatherService.SetEvent(Config.Order[rng:NextInteger(1, #Config.Order)], at)
	end
end

function WeatherService.Start()
	if started then
		return
	end
	started = true
	-- A place without these gets them in a state that leaves the clear sky as it looked: no haze, no clouds.
	sky.Atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not sky.Atmosphere then
		sky.Atmosphere = Instance.new("Atmosphere")
		sky.Atmosphere.Density = 0
		sky.Atmosphere.Haze = 0
		sky.Atmosphere.Parent = Lighting
	end
	sky.Sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.Sky.Parent = Lighting
	sky.Clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not sky.Clouds then
		sky.Clouds = Instance.new("Clouds")
		sky.Clouds.Cover = 0
		sky.Clouds.Parent = workspace.Terrain
	end
	baseline = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Sky = { Atmosphere = {}, Clouds = {}, StarCount = sky.Sky.StarCount },
	}
	for name, props in SKY_PROPS do
		for _, prop in props do
			baseline.Sky[name][prop] = sky[name][prop]
		end
	end
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
