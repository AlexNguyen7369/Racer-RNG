--!nonstrict
-- BRIEF: Track 1 "Oval" (Number 1): easy beginner point-to-point oval, Closed=false. Two long straights,
--        a wide 180 degree hairpin, then a 90 degree turn and a short finish straight, so the FINISH is a
--        different place from the START (>= 2 road widths apart). Keep the old bands: length 900-1300,
--        width >= 36, MinRadius 60, MinTurns 2, lap time 10-40 s.
-- CHANGE (user): wider checkpoint area, winnings pad off to the LEFT; the car auto-races on the plain centre line
--               (no swing over the pad) and is paid when it passes the pad. Checkpoint zone is CHECKPOINT_LENGTH=60.
-- Written by test-writer BEFORE the track. Never loosen a limit to make a track pass.
return {
	Number = 1,
	Closed = false, -- point-to-point: finish is not the start
	MinStartFinishGap = 2, -- road widths between start and finish
	StraightEndsMin = 40, -- first and last segments are straights of at least 40 studs
	Checkpoint = true,
	WidePad = true, -- wide CheckpointArea, pad on the LEFT apron, RacePath is the RIGHT-HAND lane, LANE_OFFSET=10 right of the centre line (pad beside it, abeam at PadIndex)
	MinLength = 900,
	MaxLength = 1300,
	MinWidth = 36,
	MinRadius = 60, -- beginner friendly: no tight corners
	MinTurns = 2, -- the 180 hairpin and the 90 turn
	MinLapTime = 10, -- a run faster than this means the track is too short/trivial
	MaxLapTime = 40,
}
