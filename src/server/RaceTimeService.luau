--!nonstrict
-- Private, server-owned per-player NPC race personal bests.
local RaceTimeService = {}
local records = setmetatable({}, { __mode = "k" })
local TrackRegistry = require(game:GetService("ReplicatedStorage").Shared.TrackRegistry)
local tracks = {}
for _, track in TrackRegistry.Chain() do
	tracks[tostring(track.Number)] = true
end

local function trackKey(track)
	if type(track) ~= "string" and type(track) ~= "number" then
		return nil
	end
	local key = tostring(track)
	return tracks[key] and key or nil
end

local function clean(value)
	return type(value) == "number" and value == value and value > 0 and value < math.huge and value or nil
end

function RaceTimeService.Setup(player)
	if type(records[player]) ~= "table" then
		records[player] = {}
	end
	return records[player]
end

function RaceTimeService.Apply(player, data)
	local result = {}
	if type(data) == "table" and type(data.RaceBestTimes) == "table" then
		for track, seconds in pairs(data.RaceBestTimes) do
			local key = type(track) == "string" and trackKey(track)
			local value = clean(seconds)
			if key and value then
				result[key] = value
			end
		end
	end
	records[player] = result
	return result
end

function RaceTimeService.Snapshot(player)
	local result = {}
	for track, seconds in pairs(RaceTimeService.Setup(player)) do
		result[tostring(track)] = seconds
	end
	return result
end

function RaceTimeService.Best(player, trackNumber)
	local key = trackKey(trackNumber)
	return key and RaceTimeService.Setup(player)[key] or nil
end

function RaceTimeService.Record(player, trackNumber, seconds)
	local key, value = trackKey(trackNumber), clean(seconds)
	if not key or not value then
		return RaceTimeService.Best(player, trackNumber), false
	end
	local old = RaceTimeService.Setup(player)[key]
	if not old or value < old then
		RaceTimeService.Setup(player)[key] = value
		return value, true
	end
	return old, false
end

return RaceTimeService
