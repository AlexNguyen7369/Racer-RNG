--!nonstrict
-- Which world this place is (docs/WORLDS_SPEC.md section 2). World 1 is today's game; World 2 is a second
-- place in the same universe. ReplicatedStorage attribute WorldOverride (1 or 2) wins, for Studio and the harness.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = {}

WorldConfig.PLACE_IDS = {
	[1] = 126725530984268, -- Racer RNG
	[2] = -1, -- placeholder: the World 2 place does not exist yet (manual world2-place-id); -1 never matches a PlaceId
}

function WorldConfig.Current()
	local override = ReplicatedStorage:GetAttribute("WorldOverride")
	if override == 1 or override == 2 then
		return override
	end
	for world, placeId in WorldConfig.PLACE_IDS do
		if placeId == game.PlaceId then
			return world
		end
	end
	return 1
end

return WorldConfig
