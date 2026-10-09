--!nonstrict
-- BRIEF: Track 3 "DragRace": a short, straight point-to-point sprint after Hill.
--        Keep the numbered ladder, separate start and finish, straight ends, a
--        320-stud-class geometry, and the shared checkpoint/left-pad contract.
-- Written by test-writer BEFORE the track implementation. Never loosen a limit
-- to make a track pass.
return {
	Number = 3,
	Closed = false,
	MinStartFinishGap = 2, -- at least two road widths between start and finish
	StraightEndsMin = 40, -- the sprint is straight into and out of its joins
	Checkpoint = true,
	WidePad = true, -- wide checkpoint, left-apron pad, right-hand RacePath
	MinLength = 300, -- TrackValidator's minimum; current implementation is 320
	MaxLength = 400, -- preserve a short drag-race rather than a full circuit
	MinWidth = 36,
	MinRadius = 60, -- the shared corner floor; a straight has no tighter turn
	MinLapTime = 3,
	MaxLapTime = 20,
}
