--!nonstrict
-- BRIEF: Track 2 "Hill" (Number 2): same idea as before (hills on the straights, slightly harder than Oval)
--        but point-to-point, Closed=false, ONE 180 degree turn (right turn) instead of two, finish
--        different from start. Keep length 1300-1900, width >= 36, MinRadius 60, MinPeakHeight 24,
--        MaxGradeDeg 20, lap 15-60 s, but MinTurns = 1 (the second turn was removed by the user).
-- CHANGE (user): wider checkpoint area, winnings pad off to the LEFT; the car auto-races on the plain centre line
--               (no swing over the pad) and is paid when it passes the pad. Checkpoint zone is CHECKPOINT_LENGTH=60.
-- Written by test-writer BEFORE the track. Never loosen a limit to make a track pass.
return {
	Number = 2,
	Closed = false,
	MinStartFinishGap = 2,
	StraightEndsMin = 40,
	Checkpoint = true,
	WidePad = true, -- wide CheckpointArea, pad on the LEFT apron, RacePath is the RIGHT-HAND lane, LANE_OFFSET=10 right of the centre line (pad beside it, abeam at PadIndex)
	MinLength = 1300, -- longer than Oval's band (900-1300), about 1,600 studs intended
	MaxLength = 1900,
	MinWidth = 36, -- never narrower than Oval, beginner friendly
	MinRadius = 60, -- no tighter than Oval: the challenge is the hills, not the corners
	MinTurns = 1, -- the single 180 degree right turn
	MinPeakHeight = 24, -- must genuinely climb: about 30 studs intended, so a flat track fails
	MaxGradeDeg = 20, -- smooth hills the car can climb: about 16 degrees intended
	MinLapTime = 15,
	MaxLapTime = 60,
}
