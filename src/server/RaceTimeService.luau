--!nonstrict
-- Private, server-owned per-player NPC race personal bests.
local RaceTimeService = {}
local records = setmetatable({}, { __mode = "k" })

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
			local key = tostring(track)
			local value = clean(seconds)
			if key:match("^%d+$") and value then
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
	return RaceTimeService.Setup(player)[tostring(trackNumber)]
end

function RaceTimeService.Record(player, trackNumber, seconds)
	local value = clean(seconds)
	if not value then
		return RaceTimeService.Best(player, trackNumber), false
	end
	local key = tostring(trackNumber)
	local old = RaceTimeService.Setup(player)[key]
	if not old or value < old then
		RaceTimeService.Setup(player)[key] = value
		return value, true
	end
	return old, false
end

return RaceTimeService
