--!nonstrict
--[=[
PROJECT CONTEXT - Idle Vehicle Simulator (read me first)
Shown in Studio at: ServerScriptService > ProjectContext   (source file: context/ProjectContext.luau)
Do NOT edit this in Studio: edit the file on disk, Rojo syncs it. Claude updates it at the end of every loop.
Last updated: 2026-10-02 (spawn area, banked winnings, turbo luck, roll showcase, race start event: /compat-check ALL GREEN, fingerprint 736c261dea05)

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
  Players join/respawn ON FOOT in the purple spawn area (Workspace.SpawnArea, Shared/SpawnArea, right of Track 1's start straight);
  walking onto its green StartPad (or the button) starts racing; Stop cashes out the bank and sends the avatar back to the area.
  The Speed stat is kept (a run commits its pending gain when it stops).
- NPC-mode money is BANKED: a won track adds its pad value to Unbanked (HUD "UNBANKED"); a loss empties it; Stop/death/leave pays it.
- Turbo luck: every 10th roll uses luck x5 (GachaConfig.TURBO_*); bottom-centre ROLLS button + TURBO LUCK bar (Client/RollUi) opens a live card feed.
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
15. IN PROGRESS (2026-10-01): NPC racers (spec docs/NPC_RACER_SPEC.md). One NPC per track (Shared/NpcConfig: Track 1 red, 20 studs/s,
    +12 per track, label track01_NPC..., 60-stud label distance, per-track Model override via ReplicatedStorage.NpcModels). Pure-maths
    NPC in the LEFT lane (Shared/NpcRacer; TrackBuilder.RacePath(layout, offset)); RaceService NPC mode (Attach passes Npc = true):
    race per track, loss plays out then loser screen + back to Track 1 start after 3 s, pad pays only on a WIN; events only to the owner
    (Remotes.NpcRace), NPC drawn client-side only (Client/NpcRacerView, LoserScreen). PathDriver.Chain Start/FinishIndices.
    Also: every run now starts START_AHEAD (5) studs onto the road (the old start on the road's back edge left the car stuck: race and
    flip_recovery failures); Stop Auto removes the SeatWeld before the car (auto_toggle stop_unseated). Tests: npc, multiplayer (red run
    confirmed), test-writer added <pre>_npc_race_on to auto_toggle. New agent multiplayer-tester.
16. Compatibility gate (2026-10-01): /compat-check (.claude/commands/compat-check.md) runs harness (physics-tester) + ui-tester +
    multiplayer-tester + world-tester; tools/compat.py records a green stamp (.compat/green.json, local) for a fingerprint of src/ +
    default.project.json. Pushes to main are blocked unless that stamp matches: .claude/hooks/compat-gate.py (Claude's push / PR merge;
    its Stop hook asks for the run when src changed) and .githooks/pre-push (enabled by core.hooksPath = .githooks).
14. Tooling: Herdr 0.9.3 (brew) + Claude integration hook (~/.claude/hooks/herdr-agent-state.sh) for several repos in one terminal.
    Slack app "Racer RNG Claude" exists (workspace Racer RNG, channel #racer-dev C0C5LM8Q8F7, team T0C5AK11CNB). The `slack` MCP entry in the user
    config was added with the wrong token type (xoxp) and a bad team id: remove and re-add with an xoxb- bot token.
17. DONE (2026-10-01): Car gacha, index and stat points. Shared/CarCatalog + Shared/Cars/* (7 placeholder cars from the design doc, Model = nil
   shows a "?"), Shared/GachaConfig (roll every 3 s, rarest-first min(1, luck/N), 1 stat point per 3 unique cars, +0.1/+0.1/+0.05/+0.2 per
   point), Server/GachaService (GachaData folder + attributes, remotes EquipCar/AllocateStat/RollResult), Client IndexUi/StatsUi/RollToast.
   PlayerData VERSION 3 saves Cars (sorted array of owned ids; no duplicate counts), Equipped, Rolls, StatAlloc (earned points derived, never saved). Speed gain x SpeedMulti
   (RaceService), pad cash x MoneyMulti (MoneyService). Cruise speed/physics untouched. Workshop points stored, no effect yet.
18. DONE (2026-10-01): UI compatibility tests (src/client/UiTest, written by the new ui-test-writer agent; run by ui-tester in
   /compat-check; server setups via the Studio-only CarTest/UiTestSetup script), admin chat commands (Server/AdminService, AdminConfig,
   Client/AdminChat, RaceService run:JumpToTrack; spec docs/ADMIN_COMMANDS_SPEC.md), Client/PanelSwitch.
19. DONE (2026-10-02): Spawn area, banked winnings, turbo luck, roll feed (spec docs/SPAWN_AND_ROLLS_SPEC.md). New Shared/SpawnArea
   (floor x 24..184, z -100..44 of Track 1's Start; pad x -20..24, z 2..38; only SpawnLocation), CarService.OnCharacter / PadTouched,
   MoneyService.Quote, RaceService run.Unbanked / BankedTotal / CashOut (Destroy cashes out), Result events Banked/Unbanked,
   GachaConfig TURBO_EVERY 10 / TURBO_LUCK 5 / IsTurbo / TurboProgress, RollResult (id, isNew, turboMulti), Client/RollUi (RollsButton,
   TurboBar, Feed cards), SpeedHud UNBANKED row, toast moved above the turbo bar, Index panel ends above the strip.
   Tests first: test-writer (spawn_area, bank, npc/multiplayer/admin/gacha/auto_toggle updates, UiTestSetup roll_burst/turbo_next),
   ui-test-writer (RollUi, Unbanked HUD, ui_rolls). Red run confirmed (spawn_area, bank, gacha, npc failed on the missing features).
   Owner revisions: the roll feed / ROLLS button was removed; the roll toast is now a button that opens Client/RollToast's
   RollShowcase overlay (big card per roll, live; "?" until car models exist; Backdrop click off the card closes; blur).
   Bugs found live and fixed: Stop left a real player's avatar where the car was (client-owned physics undid the teleport:
   placeAtWalkSpawn now holds it for 2 s); a fast Stop -> Auto Race made the car path from the spawn area (race start is now
   an event: anchored car at the start line, avatar teleported then seated - checked via Occupant + SeatWeld - then the run
   starts; RaceEvent attribute Teleporting/Racing/Off; Sit only when SeatPart is nil and the seat is enabled, since repeated
   Sit calls can leave SeatPart stuck); a click on the showcase card also closed it (Active frames don't block the button
   under them: the backdrop ignores presses inside the card).

TEST RESULTS (latest first; update after every full run)
- 2026-10-02 (/compat-check round 3, fingerprint 736c261dea05): ALL GREEN, stamp recorded. harness `[CARTEST] END pass=22 fail=0`
  (auto_toggle 173, spawn_area 134, bank 40, npc 114, gacha 79 checks); ui `[UITEST] END pass=14 fail=0`, 21/21 real clicks;
  multiplayer GREEN; world GREEN. Rounds 1-2 RED on auto_toggle event_cancel_* / event_seat_fail_* (stale Humanoid.SeatPart, fixed).
  Unverified: real two-client play, a 3rd/4th player's start (row 1 spawns on the StartPad, 2-stud gap to the road), real DataStore.
  Test-setup bug (not shipped code): UiTestSetup 'restore' resets Money before SetAutoRace(false), whose cash-out then adds the run's
  bank on top (Studio session only) - restore should stop racing first. Intermittent: static_settle settle_speed and spawn_area
  respawn_on_foot_standing_height (passed in round 3; 4.409 in band).
- 2026-10-01 (/compat-check round 3, fingerprint 076fe6662e79): ALL GREEN, stamp recorded.
  harness `[CARTEST] END pass=20 fail=0` (incl. gacha, index, npc, multiplayer, admin, track:Hill/Oval); ui GREEN (`[UITEST] END pass=12
  fail=0`, 16/16 clicks); multiplayer GREEN; world GREEN. Fixed on the way: race metrics stop after the finish (path dev spike past the
  route end), standUp waits until SeatPart clears (order-dependent stop_unseated), hidden avatar in collision group HiddenAvatar
  (collides with nothing; seated Humanoid re-enables torso CanCollide), StartLine CanCollide=false, Index/Stats panels exclusive and below
  the Auto Race button, LoserScreen DisplayOrder 10, toast hidden while a panel is open, SpeedHud on Heartbeat, admin commands from the
  NPC session's drafts. Unverified: real DataStore saving (Studio has no API access), a real two-client test (fake players only), NPC
  motion live while the Studio window is in the background (it stops rendering).
- 2026-10-01 (gacha / index / stat points): red run as expected (gacha, index, data, hud failed on the missing API / Version 3).
  After implementing, FULL run END pass=16 fail=3: gacha failed only catalog_ids_snake_case (a broken Lua pattern in the test, fixed by
  test-writer; gacha rerun alone 66/66 PASS). index 40/40, data 74/74, hud, money, economy, npc 110/110, multiplayer, track:* PASS.
  Still failing, NOT from the gacha change (already failing in NPC round 1): race (up-Y 0.883 < 0.9, path dev 14 > 11 at normal and max
  stat speed) and auto_toggle (stop_unseated, walk_still_not_racing, bad_input_ignored_walking, double_stop_unseated). No compat stamp:
  NOT cleared for main.
- 2026-10-01 (NPC round 1, full run INTERRUPTED by another session restarting play at ~13 min): static_settle, accel, brake, skidpad,
  car_size, chain, money, economy, data, hud PASS; race and flip_recovery FAIL (car stuck behind the road start: fixed after, unverified);
  auto_toggle FAIL stop_unseated / double_stop_unseated (fixed after, unverified); npc / multiplayer / track:* NO RESULT. No compat stamp.
- 2026-10-01 (ad-hoc, Speed stat 5000 = target 67.5 studs/s, live server, NOT the full suite): real RaceService.NewRun on the 2-track
  chain. Single pass: finished in 38.3 s, 0 flip recoveries, min up-Y 0.946 (limit 0.9), max path deviation 2.31 (limit 5), 0 s off
  track, never stuck, max speed 70.9, both pads paid once ($300). Looped 2 laps (77.2 s): loop-back OK, 0 flips, min up-Y 0.943, dev 2.32,
  4 payouts ($600), stat grew 5000 -> 5069.6.
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
6. QUEUED (owner, 2026-10-02): money upgrade tree (Luck %, roll speed, Speed %, turbo luck x10/x50/x100/x1000 with more rolls per
   turbo each tier, walkspeed, Money %). Spec + open questions: docs/UPGRADE_TREE_SPEC.md; references in references/upgrade_tree/.
7. QUEUED (owner, 2026-10-02): roll animation + roll UI (compact card under Auto Race, enlarged reveal, spin reel, rarity
   effects, emphasized rolls = undiscovered and rarer than the 5th-rarest owned car, global chat announce, discovery cutscene).
   Decisions and UI conflicts: docs/ROLL_ANIMATION_SPEC.md; look: the design doc's "Roll animation" section.
8. QUEUED (owner, 2026-10-02): vehicle skins: a ride's look is any model (a car now, maybe a dragon later) welded on a shared
   invisible physics body; physics and tests never depend on the model. docs/VEHICLE_SKINS_SPEC.md. Car model drafts follow it
   Rusty Hatchback Blender draft DONE 2026-10-02 (drafts/cars/rusty-hatchback, CC0 "Car Hatchback" by Kay Lousberg, rusty
   restyle, Wheel_FL/FR/RL/RR). Next for it: bake the procedural rust, export FBX, import to Studio as CarModels.RustyHatchback,
   set Model in Cars/rusty_hatchback.luau (needs Studio free). Blender MCP add-on updated to protocol 13; Poly Pizza on.

KNOWN ISSUES / NOT VERIFIED
- 2026-10-01: another session is building gacha/index (scenarios gacha, index in TestConfig, red) and shares the same Studio; runs
  collide. Nothing can be ALL GREEN (so nothing can go to main) until gacha/index are implemented and one run has Studio to itself.
- NPC client view and LoserScreen are untested live (ui-tester / multiplayer-tester not run yet).
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
	Updated = "2026-10-01",
	Read = "Open this script and read the comment block above.",
}
