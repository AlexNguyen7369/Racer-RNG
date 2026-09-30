--!nonstrict
-- Flip Enabled to true (or set ReplicatedStorage attribute "CarTestRun" = true during play) and press Play.
-- Results are printed as "[CARTEST] {json}" lines and a final "[CARTEST] END pass=N fail=N".
--
-- Scenarios listed here are the always-on car physics checks. Every file in CarTest/TrackTests/ is
-- added automatically as `track:<Name>` by the harness (those files are written by test-writer,
-- before the track exists). `lap:<Track>` can still be run by hand for any track.

return {
	Enabled = false,
	Scenarios = {
		"static_settle",
		"accel",
		"brake",
		"skidpad",
		"car_size",
		"chain",
		"money",
		"race",
		"flip_recovery",
		"economy",
		"data",
		"hud",
	},
}
