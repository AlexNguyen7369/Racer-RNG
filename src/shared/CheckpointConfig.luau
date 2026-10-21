--!nonstrict
-- Checkpoints (docs/CHECKPOINT_SPEC.md): the track a player's auto race starts on. Track 1 is always open; track n
-- opens once the player has beaten it (BestTrack >= n). The server decides; the client only shows it.

local CheckpointConfig = {}

CheckpointConfig.PICK_COOLDOWN = 0.5 -- seconds between accepted SetCheckpoint calls per player
CheckpointConfig.NPC_POS = Vector2.new(32, -6) -- hub-local (x, z): in front of the RACE START pavilion's -Z side
CheckpointConfig.NPC_FACE = Vector2.new(104, -28) -- hub-local point the NPC faces (the hub centre)
CheckpointConfig.PROMPT_DISTANCE = 10
CheckpointConfig.TEXT_DISTANCE = 80

local function count(n)
	return type(n) == "number" and n == n and math.floor(n) or 0
end

-- The highest track that can be picked.
function CheckpointConfig.Max(bestTrack, trackCount)
	return math.max(1, math.min(count(bestTrack), count(trackCount)))
end

function CheckpointConfig.IsOpen(number, bestTrack, trackCount)
	return type(number) == "number"
		and number == math.floor(number)
		and number >= 1
		and number <= CheckpointConfig.Max(bestTrack, trackCount)
end

-- The track a run really starts on: the saved pick, clamped to what is open now.
function CheckpointConfig.Effective(checkpoint, bestTrack, trackCount)
	return math.clamp(math.max(1, count(checkpoint)), 1, CheckpointConfig.Max(bestTrack, trackCount))
end

return CheckpointConfig
