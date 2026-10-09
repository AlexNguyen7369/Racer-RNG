--!nonstrict
-- BRIEF: Track 4 "Circuit": a technical point-to-point circuit with four 90-degree
--        corners and two S-bends (eight direction-change turns total). It must use
--        the numbered track ladder, have straight join/finish ends, stay at least
--        two road widths from its start at the finish, and retain the shared
--        checkpoint and left-side winnings-pad contract.
-- Written by test-writer BEFORE the track implementation. Never loosen a limit to
-- make a track pass.
return {
	Number = 4,
	Closed = false, -- every numbered route is point-to-point; the finish is not the start
	MinStartFinishGap = 2, -- at least two road widths between start and finish
	StraightEndsMin = 40, -- straight into the previous finish and straight at this finish
	Checkpoint = true,
	WidePad = true, -- wide finish area, left apron pad, right-hand RacePath
	MinLength = 1100, -- preserves the full technical circuit rather than a shortened loop
	MaxLength = 1300,
	MinWidth = 36,
	MinRadius = 60,
	MinTurns = 8, -- four 90-degree corners plus two two-part S-bends
	MinLapTime = 15,
	MaxLapTime = 60,
}
