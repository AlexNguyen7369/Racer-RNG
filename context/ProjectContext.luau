--!nonstrict
--[=[
PROJECT CONTEXT - Idle Vehicle Simulator (read me first)
Shown in Studio at: ServerScriptService > ProjectContext   (source file: context/ProjectContext.luau)
Do NOT edit this in Studio: edit the file on disk, Rojo syncs it. Claude updates it at the end of every loop.
Last updated: 2026-09-30 (lane/stability + toggle + implicit suspension all IMPLEMENTED; NO full run has passed since: re-run the suite)

WHAT IT IS
A baby-blue mini car auto-races a chain of tracks (Oval -> Hill -> ...). No steering: the car drives itself,
gains a Speed stat while it drives, and is paid $ when it passes each track's winnings pad.

WHERE THINGS ARE (Explorer)
ReplicatedStorage.Shared   CarConfig, CarFactory, CarPhysics, PhysicsTargets (feel limits: owner decides),
                           TrackBuilder, TrackRegistry, TrackValidator, RaceConfig (economy), PathDriver (auto driver),
                           HudFormat (HUD maths), Tracks/{Oval, Hill, Circuit, Serpentine}
ServerScriptService.Server Main, CarService, RaceService (drives cars), MoneyService (Money), PlayerData (saves),
                           CarTest/{Harness, Scenarios, TestConfig, Bot, TrackTests/{Oval, Hill}}
StarterPlayerScripts.Client CarController (skips AutoRace cars), SpeedHud (left panel: SPEED, then MONEY),
                           AutoRaceButton (top-centre "Stop Auto" / "Auto Race")
ReplicatedStorage.Remotes  SetAutoRace (RemoteEvent, client fires a boolean; created by CarService.Start)
Workspace.Baseplate (green studs, Rojo-owned) and Workspace.Track (Oval, Hill built at run time, chained)

RULES (details: CLAUDE.md "Track rules" and "Auto race, Speed stat and HUD")
- Tracks: numbered, point-to-point, finish of track N is the start of track N+1; last straight >= CHECKPOINT_LENGTH+4.
- Checkpoint at each finish: apron wider than the road, yellow Neon WinPad on the LEFT apron, "$N" text (N = track number x 100).
- Car drives the path; pad pays when the path index passes it. Server decides every number.
- Speed stat: grows with ACTUAL speed at diminishing rates; cruise speed = RaceConfig.SpeedFor(stat) (30 -> 75 studs/s).
- Stop Auto / Auto Race: the server decides (CarService.SetAutoRace); the button only shows the player attribute AutoRacing.
  Stopping removes the car and puts the visible avatar on foot beside Track 1 (CarService.WalkSpawnCFrame, clear of every road);
  resuming spawns a fresh car at the start. The Speed stat is kept (a run commits its pending gain when it stops).
- Stats saved by PlayerData (DataStore). In Studio turn on Game Settings > Security > "Enable Studio Access to API Services".
- Workflow: test-first subagent loop (/build-track, /car-loop). test-writer -> red run -> implement -> audit -> full green run.
  Only test-writer edits tests. Never loosen PhysicsTargets.

CHANGE LOG (newest last)
1. Baseplate: grey -> green studs, defined in default.project.json (Position, not CFrame: Rojo rejected the CFrame form, which silently
   broke project-file syncing until 2026-09-30; fixed, `rojo build` passes). Also applied directly in the open place. SAVE THE PLACE (Ctrl+S).
   Track chain lifted 1 stud (TRACK_LIFT).
2. Loop rewritten for the track rules; Oval reworked to point-to-point; Hill built from drafts/tracks/track-02-hill.
3. Checkpoint area + WinPad + proximity text; MoneyService (Money stat, 5 s cooldown per pad); $ replaces wins.
4. Test harness: warm-up wait before the first scenario, max_dt per scenario.
5. Auto race: RaceService + PathDriver (Bot is a wrapper), RaceConfig, PlayerData saves, CarController skips AutoRace,
   cars in collision group "Cars". Wide checkpoint (apron 30 each side), pad 24 studs left of centre.
6. Passive Speed stat (NumberValue), diminishing gain, HUD on the left, car halved (CarConfig scale 1.5,
   DampingRatio 1.0), camera zoom 10-40, pad no longer on the path (CHECKPOINT_LENGTH 60; Oval last straight 80, Hill 100).
7. Wall at the Hill checkpoint now stops 0.5 stud short of the apron (a rounding tie made walls_open_at_checkpoint flaky).
8. Car drives in a right-hand lane (TrackBuilder.LANE_OFFSET 10; RacePath shifted right with adjusted curvature; CarService spawns in the
   lane), $ text distance 40 -> 60, stability in RaceService (FLIP_UP_Y 0.5 / FLIP_SECONDS 0.4 flip recovery via physics:Reset,
   run.MinUpY, run.MaxPathDeviation after a 3 s grace, run.FlipRecoveries). CODE APPLIED (red run first: track:Oval 10, flip_recovery 14,
   race 11 failing checks, all the new ones). stylua + selene clean. Not yet run green.
9. Half-size car stability: CarConfig STATIC_COMPRESSION 0.45 + DampingRatio 0.6; targeted quick check passed (static_settle, accel, brake,
   skidpad, car_size, lap:Oval 14.1 s, lap:Hill 20.6 s). Item 11 (implicit solver) came from a parallel session and changes CarPhysics again.
10. IN PROGRESS (2026-09-30): Stop Auto / Auto Race toggle. Tests first: Scenarios.auto_toggle (attach, stop, walk, resume,
    rapid toggles, bad input, idempotence, death while racing, late accessories) and hud checks for AutoButtonText / MoneyText.
    Red run confirmed. Implemented: CarService (SetAutoRace, IsAutoRacing, GetCar, GetRun, WalkSpawnCFrame, TOGGLE_COOLDOWN 0.75,
    Remotes.SetAutoRace, respawn on foot stays on foot, no resume while dead), RaceService (GetRoute; run:Destroy commits the
    pending Speed), PlayerData.OnLeaving (car run stopped before the leave save), HudFormat.MoneyText / AutoButtonText,
    Client/AutoRaceButton, SpeedHud MONEY row.
11. IN PROGRESS (2026-09-30): CarPhysics suspension solved implicitly (heave/pitch/roll 3x3 solve using the chassis' real inertia).
    Cause of the flips: the explicit spring/damper was only just stable at 60 Hz and unstable below ~52 Hz for the half-size car.
    No CarConfig, test or PhysicsTargets change. Verified offline only (Python model); NOT yet run in Studio.
12. test-writer audit fixed Scenarios stat_api_matches_value (exact == on a value rounded to 3 decimals; now tolerance 1e-3). Nothing else loosened.
13. Git: the project is a git repo, origin = https://github.com/AlexNguyen7369/Racer-RNG.git, branch `initial-import` (first push: 65 files).
    Later commits are LOCAL ONLY. Push only when the full suite ends `[CARTEST] END fail=0`. Never push to main.
14. Tooling: Herdr 0.9.3 (brew) + Claude integration hook (~/.claude/hooks/herdr-agent-state.sh) for several repos in one terminal.
    Slack app "Racer RNG Claude" exists (workspace Racer RNG, channel #racer-dev C0C5LM8Q8F7, team T0C5AK11CNB). The `slack` MCP entry in the user
    config was added with the wrong token type (xoxp) and a bad team id: remove and re-add with an xoxb- bot token.

TEST RESULTS (latest first; update after every full run)
- 2026-09-30 (lane round): targeted RED run confirmed the new checks fail (track:Oval 10, flip_recovery 14, race 11). The code was then applied.
  The FULL run afterwards was stopped by the user before it finished: NO RESULT.
- 2026-09-30 (toggle, round 1): run started but lost: the tester stalled and the place was no longer open in Studio. NO RESULT.
- 2026-09-30 (toggle, red run, before implementation): END pass=9 fail=6. auto_toggle and hud failed on the missing API (expected).
  race, flip_recovery, track:Oval (flips at progress 0.14), track:Hill (up-Y 0.839) failed from the car instability (item 11).
- 2026-09-30 (stat / HUD / half-size car): END pass=9 fail=4, NOT GREEN. The half-size car is unstable at speed: accel top_speed 64.8 (limit 76.5)
  and drift 20 (limit 3); the car flips in both bot laps and in the race (race never finishes, no pad paid). Passing: static_settle, brake,
  skidpad, car_size, chain, money, economy, data, hud. Also walls_open_at_checkpoint on Hill (fixed since, not re-run). Live: HUD exists on
  the left (Panel AnchorPoint 0,0.5) but the number only rises while the car drives; the car was lying on its side.
- 2026-09-30 (auto race, saved stats, wide checkpoint): END pass=10 fail=0. Race: target 50, held 49.8 studs/s, 2 pads paid once,
  0 flips. Live: car moving on its own, pads 24 studs left, Money rose to 700.
- 2026-09-30 (money / $ round): cold starts gave pass=7 fail=1 (static_settle settle_speed 0.598 > 0.5) and pass=8 fail=0.

TODO (in order)
1. Reopen the place, connect Rojo, run the FULL suite; loop (physics-tuner / PathDriver / track-designer) until `[CARTEST] END fail=0`.
   Watch: path deviation <= 5 and up-Y >= 0.9 at MAX_STAT speed, flip_recovery, the lane checks, auto_toggle, the static_settle cold-start flake.
2. When green: update this file, commit, push branch `initial-import`, make it GitHub's default branch (or open a PR).
3. Slack: revoke the exposed xoxp token, install the app with bot scopes chat:write, channels:read, channels:history, groups:read,
   groups:history, users:read, reactions:write; `claude mcp remove slack --scope user`, re-add with the xoxb- token and SLACK_TEAM_ID=T0C5AK11CNB;
   /invite the bot to #racer-dev; then post results and TODOs there after each green run. Claude in Slack also needs the GitHub repo linked.
4. Test real DataStore saving (Studio: Game Settings > Security > Enable Studio Access to API Services). Save the place (Ctrl+S).
5. Bring Circuit and Serpentine up to the track rules; an upgrade shop (nothing raises Speed except driving).

KNOWN ISSUES / NOT VERIFIED
- Two sessions edited the project in parallel (lane work and the toggle / implicit solver). Only one session should run the physics tests at a time.
- Toggle cases the server harness cannot test (real CharacterAdded / PlayerRemoving / remote cooldown) are handled in code, untested.
- Whether the half-size car still flips at speed is unknown until the full run (two fixes exist: CarConfig damping and the implicit solver).
- static_settle failed intermittently on cold starts (0.58-0.78 vs limit 0.5) in 4 of ~8 runs; DampingRatio raised to 1.0, not yet re-verified.
- Real DataStore saving untested (Studio blocks it by default). Only a stubbed store is tested.
- Nothing raises the Speed stat except driving; no upgrade shop yet. Circuit and Serpentine do not follow the track rules.
- Visuals (checkpoint, pad, HUD) are checked by numbers and live reads, not by eye.

HOW TO RUN TESTS
Play in Studio, then ReplicatedStorage:SetAttribute("CarTestRun", true) (or TestConfig.Enabled = true).
Read "[CARTEST] ..." lines and "[CARTEST] END pass=N fail=N". A full run takes 10-30 minutes real time.
]=]

return {
	Updated = "2026-09-30",
	Read = "Open this script and read the comment block above.",
}
