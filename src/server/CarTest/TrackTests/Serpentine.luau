--!nonstrict
-- BRIEF: Track 5 "Serpentine": a point-to-point sprint with four alternating
--        90-degree direction changes and long entry, mid-course, and finish
--        straights. It must use the numbered ladder, keep its finish separate from
--        its start, and retain the shared straight-end, checkpoint, and left-side
--        winnings-pad contract.
-- Written by test-writer BEFORE the track implementation. Never loosen a limit to
-- make a track pass.
return {
	Number = 5,
	Closed = false,
	MinStartFinishGap = 2, -- at least two road widths between start and finish
	StraightEndsMin = 40, -- level straights are required at both chain boundaries
	Checkpoint = true,
	WidePad = true, -- wide finish area, left apron pad, right-hand RacePath
	MinLength = 900, -- four corners and the five specified sprint straights
	MaxLength = 1100,
	MinWidth = 36,
	MinRadius = 60,
	MinTurns = 4, -- alternating 90-degree corners
	MinLapTime = 12,
	MaxLapTime = 55,
}
