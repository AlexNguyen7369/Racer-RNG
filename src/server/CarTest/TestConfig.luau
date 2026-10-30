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
		"auto_toggle",
		"spawn_area",
		"gacha",
		"index",
		"npc",
		"bank",
		"multiplayer",
		"admin",
		"roll_anim",
		"upgrades",
		"workshop",
		"workshop_offline",
		"workshop_phase2",
		"weather",
		"rebirth",
		"daily_login",
		"leaderboard",
		"duel",
		"pass_cars",
		"shop_purchases",
		"offline_double",
		"environment",
		"car_expansion",
		"car_redesign",
		"gifting",
		"gift_mailbox",
		"vehicle_effects",
		"race_progress_map",
		"showcase",
		"wyvern_flight",
		"wyvern_breath",
		"singularity_orb",
		"friends_boost",
		"worlds",
		"spawn_decor",
	},
	-- Not in the full suite (each takes minutes). Run on demand during play:
	--   ReplicatedStorage:SetAttribute("CarTestOnly", "speed_probe"); ReplicatedStorage:SetAttribute("CarTestRun", true)
	-- CarTestOnly (comma-separated names) runs only those scenarios; clear it (nil) for the full suite again.
	OnDemand = {
		"speed_probe", -- docs/WORLDS_SPEC.md section 1: highest green cruise speed for RaceConfig.MAX_CRUISE
	},
}
