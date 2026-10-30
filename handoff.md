# Agent handoff

Only the current state and open work. Older entries (2026-10-02 .. 2026-10-26) were trimmed on 2026-10-27; they are
in git history (`git log -p -- handoff.md`, last full version at 2d99d78) and in `context/ProjectContext.luau`.

## State — 2026-10-27

- Codex delivery: `feature/isaac/simple-hud-icons-20261027` from main `c9dadc5`.
  Ten approved transparent HUD PNGs + IDs, scale-only hover, generated Settings
  icon and narrow StarterGui asset update. Saved and focused-live-checked in Studio.
  No server/gameplay changes, no main merge, no live publish. Full compatibility
  not rerun. Review phone readability before merging; retain all open work below.
  Luau compilation, Rojo build, deterministic UI generation and image-only
  StarterGui preservation checks passed; source PNGs + asset IDs are included.

- Current branch: `feature/alex/ember-wyvern-flight` (from origin/main 820cd25 + c4f4fee); see Open work 0.

- Branch `feature/alex/race-progress-map-completion`, everything committed and pushed (2d99d78): biome visual pass
  (scenery budget 800), Codex's loser screen fix, rendering pass + car geometry (e3f752a), trail / aura VFX,
  codebase re-audit and the three UI rules (UiMotion, SafeInsets, gamepad focus).
- 2026-10-27: owner asked for bigger scenery in mass and detailed City (Track 6) buildings. Rules in the design doc
  (Track environments, "scale and detail") and BIOME_DRESSING_SPEC (Budget 1200, Scale, City skyscrapers). Code:
  `BiomeDressing.SCALE`/`BUDGET`, `BiomeThemes` `skyscraper` helper. Verified live: `environment` 338/338, full harness
  `END pass=50 fail=0` (also 50/0 at budget 800 before the change). Bug 442639b1 (reduced-motion reveal early) fixed
  in RollToast, not run live.
- ui-test-writer added UI checks (2026-10-27): ui_reduced_motion, ui_safe_insets, ui_panel_focus (scripted),
  ui_safe_insets_notch, ui_gamepad_focus (manual), Index CarsTab, roll_odds panel closing. Not run live yet.
- Studio: open the place, `rojo serve`, click Connect in the Rojo plugin (it must be reconnected after every Studio
  restart). One Studio, one test run: check `agent_bus.py context --agent claude` before using it.

## Open work

ORCH-9. **Owner 2026-10-30: PAUSE w2 after task 1; work on nf3 friends boost, nf1 daily quests, nf2 codes; PLAN a spawn-area
   redesign (replace purple; plan only).** Goals file: world2 paused, new-features priority 2 (uncommitted -> committed with this handoff).
   OWNER ANSWERS 2026-10-30 (write them dated into the docs before code):
   (a) Quests ROTATE from a pool: each UTC day/week the server picks 3 quests from a larger pool, seeded by the period key (same for
       everyone); pool, targets, potion rewards written into docs/QUESTS_SPEC.md as placeholders first (+ design doc entry).
   (b) Friends boost HUD: a "FRIENDS +N%" chip next to the potion timers (RacerProgression/PotionStatus), hidden at 0 friends
       (FRIENDS_BOOST_SPEC 4 + HUD_LAYOUT_SPEC entry, then ui-test-writer red, then UI).
   (c) Codes: keep RELEASE only for now; owner adds real codes later.
   (d) Quest Claim bug 4796b256/12342e7c: repro in Studio first, fix whichever side (fixture or BoostDailyUi) is wrong.
   Gap audit (agent, read-only) ranked tasks: 1 new harness scenario `quests` (QuestTests.luau: progress, UTC reset, claim rejections,
   potion granted + Money unchanged, save round-trip); 2 quest Claim bug; 3 QUESTS_SPEC + SAVE_SPEC Quest* fields (QuestDailyKey,
   QuestWeeklyKey, QuestDaily, QuestWeekly, QuestDailyClaimed, QuestWeeklyClaimed), claim API (weekly, id); 4 UiSpec inventory
   (ShopUi, DailyBoosts/DailyQuestBar/*, RacerProgression/BagIcon; bugs 747c9737 e208fe51) via ui-test-writer; 5 Shop layout bug
   93e8fade (ShopUi.client.luau); 6 friends chip; 7 small tests (IsFriendsWith seam + leave recompute in FriendBoostTests; code 32-char
   limit + "Data not loaded" in ShopPurchaseTests); 8 board: ee591f0e / 6f721034 to doing (server side built), 9c8021bf open.
   Spawn redesign: drafts/environments/spawn-area-redesign/DRAFT.md (recommended theme A pit-lane paddock: charcoal floor
   (64,68,78), pit lane x184..200 z-132..-116, 40-stud timing tower (176,-92), floodlights, portal spot (96,-88); ~140 parts / 20k tris).
   CONFLICT: RENDERING_SPEC 2 says spawn floor stays SmoothPlastic; spawn_area tests check purple + SmoothPlastic. OWNER must pick
   theme, floor material, retint of leftover purple (pavilion RoofPurple, CheckpointNpc ring, leaderboard backs), portal spot, tower
   height OK, pit wall at x=24, W2 hub reuse. NOT shown to owner in detail yet.
   OWNER SPAWN ANSWERS 2026-10-30 (verbatim): "I want an open track theme, make the ground pixar themed. The floor can become concrete.
   Yes up to your design disgression. Portal spot is correct. 40 stud tower is ok. Continue implementation". So: theme = "open track"
   (read as open-air racetrack plaza; confirm only if the DRAFT's theme A/C do not cover it), ground Pixar-styled (stylised, soft,
   saturated, rounded shapes, not realistic), floor material Concrete OK (overrides RENDERING_SPEC 2 SmoothPlastic: write dated owner
   entry there), leftover purple retint + pit wall + W2 hub reuse = orchestrator's design discretion, portal (96,-88) confirmed, 40-stud
   tower OK. Owner said CONTINUE IMPLEMENTATION (spawn + nf1-nf3).
   DONE 2026-10-30 (tick, task nf-rules): owner answers written into docs on NEW integration branch feature/alex/new-features
   (from feature/alex/world2; merge ce51771, pushed; main tree now on it): design doc (spawn redesign entry, quests rotation, friends
   chip), SPAWN_AND_ROLLS_SPEC 1b (theme, Pixar palette placeholders, Concrete, retints, Decor rules, pit lane, tower, portal spot fixed /
   size placeholder, budget 250 parts / 20k tris), RENDERING_SPEC 2 (Concrete), QUESTS_SPEC "Rotation" (6+6 pool, PICK 3, Random.new(key),
   QuestConfig.Active), FRIENDS_BOOST_SPEC 4 + HUD_LAYOUT_SPEC 5 (chip), CHECKPOINT_SPEC / WORKSHOP_SPEC purple notes, goals nf4.
   rules-auditor PASS after one fix round. Owner has NOT re-read the written text (tell them; they may tweak placeholders).
   IN FLIGHT 2026-10-30 (owner: "implement those into code"; spawn assets as Blender meshes for TimingTower + TyreStack):
   - quests-rotation (worktree ../RobloxGames-orch/quests-rotation): QuestTests.luau `quests` (test-writer), QuestConfig PICK/Active
     + QuestService active-only + BoostDailyUi active list + SAVE_SPEC quest-fields line (implementer), UiScenarios/UiSpec/UiTestSetup
     use Active() (ui-test-writer). NOT run in Studio. rules-auditor PASS (minor: server os.time vs client GetServerTimeNow near UTC rollover). Then: Studio queue -> `quests` + UITEST quests.
   - spawn-paddock (worktree ../RobloxGames-orch/spawn-paddock): spawn_area updated + SpawnDecorTests `spawn_decor` (test-writer, done);
     SpawnArea/SpawnDecor implementer running; Blender agent building blender/paddock/build_paddock.py + SpawnPaddock.blend, upload,
     assets/studio/SpawnPaddockProps.rbxmx (ReplicatedStorage.SpawnPaddockProps, default.project.json). SpawnDecor falls back to parts.
     CLAUDE.md scenario list needs `spawn_decor` + `quests` added (orchestrator, at land).
   - friends-chip (worktree ../RobloxGames-orch/friends-chip): ui-test-writer red tests running; then UI implementer via .ui.json/generator.
   UPDATE 2026-10-30 (tick after /clear): friends-chip: ui-test-writer red tests + ProgressionUi.client.luau chip (runtime-built, no bake)
   + tests_explained entry; rules-auditor PASS; NOT run in Studio. quests-rotation: audit PASS; NOT run in Studio. Isolate recipe FAILED:
   `open -n -a RobloxStudio <wt>/.orch/<task>.rbxl` opens Studio on the start page, place not loaded (Studios closed, rojo 34874/34875
   stopped). Swapping shared rojo 34872 to a worktree was denied by the permission classifier -> owner must choose how to test.
   Spawn: Blender meshes done (blender/paddock/, assets/studio/SpawnPaddockProps.rbxmx, ids.json); SpawnDecor.luau + SpawnArea.luau now written
   (205 parts fallback / 177 with meshes; Lune geometry check 0 violations); rules-auditor run; Studio not run; queued 3rd. Bug 42b21c54 logged (write_redesign_rbxmx BOX_FIDELITY=1 is Hull).
   UPDATE 2 2026-10-30 (context handoff): quests-rotation LANDED: 0f7165d merged 26a0462 into feature/alex/new-features, pushed;
   quests 58/58, harness END pass=57 fail=0, UITEST pass=31 fail=6 (baseline; new bugs 80aefcdf efce0961 65067d48 3f0a7c5e logged).
   Worktree + branch removed. NOT YET: CLAUDE.md scenario list (+quests, +spawn_decor), ProjectContext, todo.json, progress-tracker.
   Owner approved swapping shared rojo 34872 between worktrees; owner must click Rojo Connect in Racer RNG after each swap (MCP cannot).
   ui-tester refuses to start play: use physics-tester for UITEST runs.
   friends-chip: UITEST pass=32 fail=6 (no new); ui_friends_chip fixtures friends_1/4/6/4_potions FAIL (chip overlaps
   HudChrome/UpgradeSlot, RacerHud/Turbo, Money on phone_landscape/phone_small_landscape; Turbo on tablet_4x3 with potions).
   OWNER DECISION 2026-10-30: HIDE the chip on phones (viewport height <= 500); on desktop/laptop/tablet keep it in the potion row,
   narrower two-line chip (~64 px wide) so tablet_4x3 fits; boost still applies on phones. NEXT: write it dated into
   docs/HUD_LAYOUT_SPEC.md:100, docs/FRIENDS_BOOST_SPEC.md:56, docs/GAME_DESIGN_REQUIREMENTS.md:1012 (friends-chip worktree), then
   ui-test-writer updates UiFriendsChip/UiSpec (hidden at phone viewports), implementer (agent a6cf68a8b3a75439c has context) edits
   ProgressionUi, physics-tester re-runs UITEST + 6 fixtures. Bug e5deb113 (UiTestFriendsFixture left set) for ui-test-writer.
   spawn-paddock: owner 2026-10-30 budget 300 parts whole redesign (spec 1b.9 + design doc + SpawnDecorTests updated, uncommitted in
   worktree); rules-auditor PASS. Rojo 34872 NOW SERVES ../RobloxGames-orch/spawn-paddock; waiting for owner "connected", then verify
   sync (Shared.SpawnDecor exists) and physics-tester runs spawn_area + spawn_decor + full harness (+UITEST). Then land.
   At the end: rojo serve --port 34872 from the main tree again (owner reconnects).
   UPDATE 3 2026-10-30: owner reconnected Rojo; Studio synced spawn-paddock (SpawnDecor, SpawnPaddockProps, SpawnDecorTests present).
   physics-tester running spawn_area + spawn_decor + full harness + UITEST on spawn-paddock. Friends-chip phone-hide decision written
   (uncommitted) into the 3 docs in the friends-chip worktree; ui-test-writer updating UiFriendsChip/UiSpec + bug e5deb113.
   Quests landing chores done in main tree: CLAUDE.md `quests`, ProjectContext, todo 9c8021bf done.
   HANDOFF (context 76%): background agents may still be writing when this window ends. Next window: check each worktree with
   `git -C ../RobloxGames-orch/<task> status --short` (spawn: SpawnDecor.luau + SpawnPaddockProps.rbxmx present? friends: UiTest edits?);
   re-run rules-auditor on quests-rotation if no PASS is recorded; then implement whatever is missing, then Studio verify (one at a time).
   Merge note: Scenarios.luau / TestConfig.luau / tests_explained.json touched by both spawn and quests branches: merge carefully.
   NEXT (worktree tasks off feature/alex/new-features, file sets disjoint, can run in parallel):
   (a) spawn-paddock: test-writer updates spawn_area (spawn_floor_purple / spawn_color / spawn_floor_smooth_plastic -> 1b rules) + new
       spawn_decor red; then world-builder/general builds SpawnArea.luau + SpawnDecor.luau (plain Parts first; meshes later); world-tester.
   (b) quests: test-writer `quests` scenario (QuestTests.luau: rotation determinism, progress, UTC reset, claim rejections incl. inactive
       quest, potion granted + Money unchanged, save round-trip) red; then QuestConfig.Active + QuestService.
   (c) friends chip: ui-test-writer red (UiSpec chip in PotionStatus row, hidden at 0, no overlap) -> UI via spec/generator -> ui-tester.
   (d) quest Claim bug 4796b256/12342e7c repro in Studio. Studio 1f339384 (Racer RNG), Rojo 34872 serves main tree. Codes: RELEASE only.

ORCH-8. **Orchestrator 2026-10-30: w2a task 1/4 `w2a-worldconfig` LANDED** on `feature/alex/world2` (merge 1109352, pushed;
   integration branch made from feature/alex/world1-ship 1c21c56 because main lacks world1-ship). Shared/WorldConfig (PLACE_IDS[1]
   126725530984268, [2] = -1 placeholder, WorldOverride wins), TrackRegistry Get/Chain/Names(world?), tracks in Shared/Tracks/World1
   (World2 empty, .gitkeep), scenario `worlds` (test-writer). Live: worlds 35/35, [CARTEST] END pass=56 fail=0 (Studio 1f339384);
   rules-auditor PASS. Live red step skipped (reds were module-missing). Worktree + task branch removed. Main tree now on
   feature/alex/world2. Owner Q open: manual world2-place-id (place id + when the World 1 cap at 10 turns on).
   NEXT tick: task 2 PlayerData VERSION 13 + migration (WORLDS_SPEC 3-4, SAVE_SPEC) via test-writer red tests in worktree
   ../RobloxGames-orch/w2a-save13; task 3 per-world consumers (Checkpoint/BestTrack/Level/XP/RaceBestTimes per world, World 2
   NPC ladder, payout n+10, cruise table); task 4 WorldService portal + teleport + rebirth cap (blocked on world2-place-id).

ORCH-7. **Owner 2026-10-30: next tick = NEW FEATURE w2a World 1 / World 2 split** (todo `worlds-split`, goal world2,
   docs/WORLDS_SPEC.md). Read WORLDS_SPEC + design doc "Worlds", rules-gate it, start the goal's integration branch if missing, split
   into worktree tasks (WorldConfig, per-world TrackRegistry, PlayerData VERSION 13 + migration, WorldService portal + teleport),
   test-writer red tests first. ORCH-6 UI follow-ups (85d9464c, e628ec7b) and ORCH-3 probe stay parked.

ORCH-6. **Orchestrator 2026-10-29: owner decisions + UI fix round 2 (worktrees ../RobloxGames-orch/{ui-tests,phone-hud,ui-polish}).**
   Owner 2026-10-29 (docs on feature/alex/world1-ship 1a33161 + 65cd315, HUD_LAYOUT_SPEC 6/9): the Items/Upgrade pair NEVER stacks; the phone
   Speed readout sits bottom right (bounds 24/130 px, may shrink to >= 50% of phone k). manual hud-pair-phone-rule + speed-float-phone done;
   new open manual hud-pair-tablet-shrink (doc says tablet shrinks, UiSpec.HudPair.Desktop says never).
   Task commits: ui-tests fb4be98 (phone checks, layout model, fixture panel close 081c684a, stricter hitbox content), phone-hud e56405f
   (HudChrome no stack, RacerUiController placeSpeedBottomRight event-driven, SpeedDial 0 on foot, fd2412fe), ui-polish da523e4
   (53e24a2e 3c0dcacf 7d99207f 0261e33b 12342e7c; adf68695 NOT fixed, no root cause). rules-auditor: PASS / PASS / owner Q answered (min 50%).
   Main tree is on orch/world1-ship/verify (= world1-ship + all three merged, NOT pushed) so Rojo 34872 serves it; ui-tester running full
   UITEST on Studio 7978e86d (Racer RNG).
   UITEST on verify (Studio now id 1f339384, Racer RNG): [UITEST] END pass=33 fail=4; clicks 118/121. Phone pair beside: PASS both phones;
   phone Speed bounds/min-scale PASS (modelled). New reds -> fix round 2 sent: phone-hud 102389fe (Speed x DailyBoosts/Status);
   ui-polish a4da1214 (compact roll rect regressed), 0261e33b (still red), 2568b64c (AUTO OFF toast late); ui-tests 8495ae70 (RetryLostPress),
   PhoneSpeed.Clear + Status, 78a303ce (Money float). Pre-existing reds, not this round: 9617a457 (Settings title/ProfileTab, Backpack tabs
   phone), f4a7be5c (Upgrades tiles over TurboLabel, Workshop Rate/Buy, Welcome phone), b53e7fa8/93e8fade (Market detail phone),
   tablet shrink (owner hud-pair-tablet-shrink), quest 4796b256 still red despite BoostDailyUi re-render. Live Device emulation phone check +
   2 PhoneOnly clicks need the owner (MCP cannot resize). After round 2: rebuild verify (delete + re-merge), rerun UITEST.
   DONE 2026-10-30: round 2 UITEST on verify 2e41c8e [UITEST] END pass=35 fail=2, clicks 119/121 (was 33/4); no regressions.
   LANDED on feature/alex/world1-ship 4427b4a (pushed); task branches, worktrees and verify deleted. Bugs fixed: 78a303ce a4da1214 8495ae70
   53e24a2e 3c0dcacf 7d99207f adf68695 fd2412fe 081c684a. Still red: speed_phone_clear/no_overlap phone (85d9464c test model lacks Status
   phone move), reduced_roll_lands_on_result + showcase_backdrop_closes (e628ec7b: Welcome offline modal stays open, test fixture),
   pre-existing 9617a457 f4a7be5c b53e7fa8 4796b256/12342e7c, tablet shrink (owner hud-pair-tablet-shrink).
   POSTPONED by owner 2026-10-30. NEXT: ui-test-writer task 85d9464c + e628ec7b; UI task for 9617a457/f4a7be5c phone overlaps; quest Claim 4796b256 live debug; then ORCH-3
   speed probe. Owner by hand: live Device emulation phone check (844x390, 667x375), PhoneOnly + MANUAL clicks.

ORCH-5. **Orchestrator 2026-10-28 ~19:15: UI fix round, 3 task branches off feature/alex/world1-ship 7d7cc70 (worktrees ../RobloxGames-orch/<task>).**
   - ui-style: COMMITTED d5d7c70 (WelcomeStyle Bangers line removed -> FredokaOne; UpgradeTreeView Panel transparency 0.38 -> 0.05). Bugs ccc13c4f, 03bad751.
     Owner look check: Upgrades tree now covers the world almost fully in dark blue.
   - ui-test-fixes (ui-test-writer): COMMITTED c3dabfa (shop_redeem_invalid_code expects one real RedeemCode call; new setup offline_double_open
     + restore; Help.waitCardRest for showcase card; speed-dial sampler drops time of skipped teleport frames). Bugs 38e4a78b, 3b10d310, 837519cd.
     Risk: speed dial may still fail (real cause could be rail sideways velocity in AssemblyLinearVelocity).
   - ui-hud-phone: NO CODE CHANGE (worktree removed). All 3 trace to tests/docs:
     9de32835 = test vs doc conflict: HUD_LAYOUT_SPEC 6 stacks the pair at height <= 400 (phone_landscape 390 stacks; HudChrome:144 and
     UiResponsive:1914 agree) but UiSpec.HudPair.Beside (UiSpec:745) lists phone_landscape; tablet_4x3 shrink 0.54 follows the doc's
     "phone and tablet scale down" but UiSpec.HudPair.Desktop (:746) says never shrunk. OWNER decides (manual hud-pair-phone-rule).
     d782d207 = test fault: Face 172x46 is the 1.035 HoverScale (mouse left on Race); ui-test-writer must un-hover before measuring.
     9617a457: MotionFloat cannot fit above Speed on phone (UiMotion:197/209, RacerUiController:808) -> OWNER (manual speed-float-phone);
     Settings Title/ProfileTab RacerUiController:266 + RacerSettings.ui.json:136; DailyBoosts/Status BoostDailyUi:226; Backpack CarsTab
     BackpackUi:167 (CLAUDE.md: Backpack has no Cars tab). Also HudChrome:328 comment says pair hides under panels but code never does.
   DONE 2026-10-28 ~20:30: un-hover fix e52bab7, rules-auditor PASS (both branches), merged 6ae5e90 + e2a5f70 into world1-ship, pushed;
   worktrees/branches removed. Live [UITEST] END pass=33 fail=4 (Studio fb39beec). Bugs fixed: ccc13c4f 38e4a78b 3b10d310 837519cd d782d207.
   Still red: 03bad751 -> new 53e24a2e (UpgradeTreeView 0.05 vs cap 0.05, float32; fix: panel 0.04 or test epsilon via ui-test-writer);
   3c0dcacf Upgrades Exit HoverScale 1.035 at rest; 7d99207f RollToast hitbox padding 22 px; adf68695 Rebirth band 4 px low / Close 2 px;
   0261e33b reduced-motion roll no viewport; fd2412fe speed float +12,344 vs +12,345 (+ dial '1' on foot); 4796b256 / 12342e7c quest Claim
   active; 081c684a harness leaves CheckpointUi + Offline modal open (test, ui-test-writer). Owner: hud-pair-phone-rule, speed-float-phone.
   NEXT: one worktree task per group: (a) UpgradeTreeView 53e24a2e + 3c0dcacf; (b) RollToast 7d99207f + 0261e33b; (c) PanelBand adf68695;
   (d) RacerUiController fd2412fe; (e) ui-test-writer 081c684a + quest fixture 4796b256; then full UITEST; then ORCH-3 speed probe.

ORCH-4. **Orchestrator 2026-10-28 evening (world1-ship 82929ed): [CARTEST] END pass=54 fail=1, [UITEST] END pass=34 fail=3.**
   CARTEST red = stale test economy stat_for_above_cap_is_huge (stf(1000) vs cap 1250, bug d5f9bdf9): test-writer fix 3430d85 on
   orch/world1-ship/economy-cap-test (worktree ../RobloxGames-orch/economy-cap-test), rules-auditor PASS; economy re-run [CARTEST] END pass=1 fail=0 on
   Studio fb39beec; LANDED as merge 71f4163 on feature/alex/world1-ship (pushed). Bug d5f9bdf9 fixed.
   UITEST reds (bugs logged): ui_layout phone HudChrome Items/Upgrade mid-screen (9de32835, HudChrome.client.luau:141), Upgrades tiles
   see-through (03bad751), phone overlaps (9617a457); ui_theme Welcome Bangers font (ccc13c4f, WelcomeStyle.luau:78); ui_speed_dial
   236.9 vs 178.8+-26.8 while racing (maybe timing); on-foot Race Face 172x46 > parent 166x44 (d782d207, RacerHud.luau:36).
   Clicks: quest Claim active when incomplete (12342e7c, UI suspected); TEST bugs for ui-test-writer: shop_redeem_invalid_code
   Remote=false (38e4a78b), missing setup offline_double_open (3b10d310); showcase pop-in timing (837519cd).
   Not run: manual Escape/gamepad/notch checks, PhoneOnly market clicks.
   WARNING: Studio 30ded902 died mid-UITEST; fixtures (index_states, stat_points, rebirth_eligible, daily_claimed, quest...) were not
   restored; if Studio DataStore writes are on they may be saved on the test account.
   Parallel Studio blocked: IdleVehicleSimulator.rbxl stale (2026-10-11; manual item fresh-place-copy-2026-10-28); port 34873 used by AnimeRun.
   NEXT: UI fix tasks in worktrees (HudChrome phone + Race Face; WelcomeStyle font; UpgradeTreeView tiles;
   test bugs via ui-test-writer), then full UITEST again.

ORCH-3. **Owner 2026-10-28: speed probe up to 2000; if every track is green through 2000 (highest_green_contiguous >= 2000),
   set RaceConfig.MAX_CRUISE = 2000 (owner decision, no 10% margin) with a dated design-doc + WORLDS_SPEC entry; else ask the owner.**
   Probe: CarTestOnly = "speed_probe", then CarTestRun = true (on feature/alex/world1-ship b737c85+). Queued after the UI runs.

ORCH-2. **Orchestrator, 2026-10-28 late: Isaac merged (4227363), hover test scale-only (548f1e8), all pushed on feature/alex/world1-ship.**
   Full UI suite (ui-tester): [UITEST] END pass=26 fail=13. Hover OK (1.000 -> 1.035, no outline). Bugs being logged in bugs.json.
   UI-code bugs (implementer, then ui-tester): RollToast must hide under open panels (steals clicks); Index tile / PanelSwitch.Action("Index")
   does nothing; Market/Shop do not close on outside click; Upgrades panel covers its toggle; Market phone tabs/Action ""; Shop overlap +
   phone band; phone Welcome/Workshop above Race button; pedestal BillboardGui/ProximityPrompt nil; MoneyValue outside plate; fonts
   LegacyArial not Fredoka; "Stats 37" label; Speed float +9 vs +0.5; weather icon phone order; Index ConsumablesTab; showcase Viewport
   outside card; Duel invite left open.
   TEST bugs (ui-test-writer only): ui_layout model mismatches the engine (no UIScale/AutomaticSize; Index off 879, Shop 1920); unknown
   setup ids daily_unclaimed/daily_claimed/checkpoint_locked/checkpoint_open; PrepareGift not intercepted; money fixtures broken by
   auto race payouts; gamepass cars Owned-vs-Equip fixture; ui_loser timing (hidden ~4 s after start); Backpack Cars order includes gamepass.
   Manual (owner, Device Simulator / Controller Emulator): ui_safe_insets_notch, ui_gamepad_focus, Escape keys.
   NEXT: one task per group in worktrees ../RobloxGames-orch/<task> on orch/world1-ship/<task> (UI code via ui-test-writer red ->
   implementer -> ui-tester; tests via ui-test-writer), then full [UITEST] + [CARTEST] (XP check level_xp_curve_rev4 not yet run live).
   Then td1-td7, w1a pad short text (owner approved), nf3 friends boost spec+build (owner approved +10%/friend cap 40%).

ORCH-1. **Orchestrator tick 1, 2026-10-28: LANDED on `feature/alex/world1-ship` (pushed): 50efb4d scenery fix, 677ad7d World 1 balance,
   2ac2f0f progress. Harness END pass=53 fail=0 (studio id now 4f40c05b-...; use CarTestOnly attribute, never gmatch the log).
   NEXT: merge origin/feature/isaac/simple-hud-icons-20261027 (conflicts README, ProjectContext, current_progress,
   ui/generated/RacerHud.*, StarterGui.rbxm: regenerate + re-bake), then full [UITEST] + harness, then test-debt td1-td7.**
   History:
   Branch switched in place from car-redesign (no file changes). Owners: world-two-speed-cap session (payout curve, rebirth rev 4,
   XP 122/225/37.2, owner-approved 2026-10-28, applied by that session, check level_xp_curve_rev4 not run yet, car odds rev, MAX_CRUISE 800, money cap 1e30, max-rebirth UI); dashboard
   files `tools/dashboard/{server.py,test_integration.py,static/flow.*}` belong to soft-car-finish-pilot: NEVER stage them.
   Done: rules-auditor FAIL (9) triaged: owner decided interim rule "rebirths 1-20 in one place until World 2 ships" (design doc,
   WORLDS_SPEC, REBIRTH_SPEC, 2026-10-28); stale doc lines fixed (CLAUDE.md cruise cap, HALF_STAT/no-cap/1e15 marked REPLACED,
   NPC_RACER_SPEC 1.51, HUD_LAYOUT_SPEC x1k); test-writer tightened race resync window, huge_multi ULP tolerance, added
   odds_rev_even_log_spacing. Scenery bugs ab037b16/b99e2c0b fixed (BiomeDressing Prune spawn columns + exact Blocks slots;
   BiomeThemes City Landmarks.Offset 96, Blocks.Spacing 32), made in worktree ../RobloxGames-orch/w1d-scenery and applied to
   the main tree. Harness before fixes: END pass=50 fail=3 (only the 3 scenery reds).
   Harness rerun (scenery + tightened tests): END pass=51 fail=2; scenery green (city_blocks_gap 0.755, overlaps 0); new reds race
   (max_speed_run_reports_path_deviation 1.929 (11) FAIL) and track:Space (completed 0, off_track 7.0 s); diagnosis agent running.
   Studio froze after the run (agent's gmatch log search); owner unfreezes it by hand. NEVER parse [CARTEST] lines with lazy gmatch.
   Race red = test sampled the finish frame (bug 3e2ab51f); test-writer fixed Scenarios.luau:1889 (`and not run.Finished`), not run yet.
   Space red = likely hitch flake (bug 24161ed7; scenery parts are CanCollide/CanQuery false, lap code untouched).
   2026-10-28 later: re-audit FAIL(2) fixed (CLAUDE.md NPC line 16 x1.51; owner OK'd spawn-area 'column' prune rule, written in
   BIOME_DRESSING_SPEC Clearance). Owner: Isaac's 153072a (origin/feature/isaac/simple-hud-icons-20261027, simple HUD icons +
   scale-only hover) is NOT in our branch; owner-approved order: commit our WIP, then merge Isaac, regenerate RacerHud from the
   merged spec and re-bake StarterGui.rbxm (conflicts: README, ProjectContext, current_progress, ui/generated/RacerHud.*,
   assets/studio/StarterGui.rbxm), then the UI suite. Studio reopened by owner (new studio_id 65d7c2bb-...).
   IN FLIGHT at handoff: physics-tester running track:Space alone then the full harness (studio 65d7c2bb). Its result arrives in
   session orchestrator-skill-setup; a new session re-runs it if lost. Owner 'approve everything' 2026-10-28: XP 122/37.2 (applied),
   friends boost +10%/friend cap +40% (write design-doc entry + docs/FRIENDS_BOOST_SPEC.md, then build), pad billboard short text
   (todo f3664748). Still awaiting owner: W2 HALF_STAT 2.07e15.
   Next: (1) run track:Space alone, then full harness (expect fail=0), mark bugs
   ab037b16, b99e2c0b, 3e2ab51f, 24161ed7 fixed with bugs.py; (2) ui-tester full [UITEST]; (3) rules-auditor re-run -> PASS;
   (4) commit WIP (excluding dashboard files) + scenery in two commits on feature/alex/world1-ship, push, bugs.py fixed,
   remove worktree w1d-scenery + branch orch/world1-ship/w1d-scenery, progress-tracker; (5) then goal test-debt td1..td7.
   Owner items: manual.json friends-boost-rule-2026-10-28 (nf3). nf1 quests / nf2 codes already have specs + code: verify only.

00000000. **Orchestrator + flow dashboard** (owner 2026-10-28; branch `feature/alex/orchestrator-and-flow-dashboard`, worktree
   `../RobloxGames-orchflow`, pushed through 33d3018). Skill `~/.claude/skills/orchestrator/` (SKILL.md, scripts/context_watch.py
   global hook, scripts/runner.py, scripts/install_launchd.sh); repo: `.claude/orchestrator.md`, agents `rules-auditor` and
   `merge-reviewer`, `/orchestrate`, `docs/ORCHESTRATOR_GOALS.md` (5 goals owner-confirmed 2026-10-28, test-debt first),
   dashboard `/static/flow.html` + `/api/flow`. Merges to main only via PR + fresh merge-reviewer. Next: owner runs
   `bash ~/.claude/skills/orchestrator/scripts/install_launchd.sh ~/Documents/RobloxGames` (launchd install was blocked for
   Claude), then the first tick does td1. Unverified: Studio MCP from headless `claude -p`; context_window 200000 is a guess.

0000000. **Payout + price curves, Speed float** (owner 2026-10-27, uncommitted on this tree). Rules: design doc "payout and
   price curves", UPGRADE_TREE_SPEC 2, WORKSHOP_SPEC 5, HUD_LAYOUT_SPEC 10. Code: `Shared/PayoutCurve` + its users,
   Money cap 1e15, RacerUiController Speed float, RaceProgressMap Path2D fix. Harness 39/4 (only known scenery bugs +
   npc timing check, rerun pending). Next: run [UITEST] (incl. ui_speed_float), commit on its own feature branch,
   progress-tracker. Open: pad billboard still shows full digits (rule 6).

000. **UI visual pass** (owner 2026-10-27; branch `feature/alex/ui-visual-pass`, git WORKTREE
   `/Users/alexnguyen7369/Documents/RobloxGames-ui` so the car-redesign tree stays untouched). Rules: design doc
   (lowercase suffixes from 1k incl. Money; "UI visual pass" entry), HUD_LAYOUT_SPEC 8-10, NPC_RACER_SPEC "Loser
   screen", RACE_PROGRESS_MAP_SPEC "Look". Code: `Shared/UiTheme` (new), `Client/UiMotion` presets
   (Pop/SlideIn/Shine/Pulse/Shake/Float/Cascade), `HudFormat` (lowercase, SUFFIX_FROM 1e3, MoneyText short, Multi),
   RacerHud spec (`SpeedDial`, `MoneyPlate`; regenerated + baked), `RollToast/Ui/SpeedDial` (Path2D arc + needle,
   real car speed), RacerUiController (count-up, pops, +$ float, bank pulse, Race breathing, turbo punch-in),
   NpcRacerView loser recap, RaceProgressMap Path2D route, restyle of HudChrome/Backpack/Market/Shop/BoostDaily/
   Progression/Checkpoint/Duel/GiftPicker/PanelSwitch open motion, billboards to Fredoka + UIStroke.
   Tests written first (test-writer: HudFormat, TimeAt, on_foot fixture; ui-test-writer: ui_hud, ui_speed_dial,
   ui_theme, ui_motion_reduced, loser recap, map). NOT RUN in Studio yet (Studio was busy with the car-redesign
   suite). Next: serve the worktree with rojo (stop the other rojo only when robloxgames-e7 says Studio is free),
   run [CARTEST] (hud/format, race_progress_map, environment, npc) and [UITEST], screenshot desktop + phone, fix,
   then ProjectContext/todo, commit, progress-tracker.
0000000a. **Cruise cap + World 1 / World 2** (owner 2026-10-27, plan `~/.claude/plans/nested-questing-thunder.md`).
   Phase 0 done (docs): design doc "Worlds", new `docs/WORLDS_SPEC.md`, notes in REBIRTH/SAVE/CHECKPOINT/NPC_RACER specs.
   Phase 1 DONE: speed_probe green to 1000 -> MAX_CRUISE 800, NPC growth 1.51; harness 49/4 then money fixes green.
   Phase 4 sim written (tools/balance_sim.py --fit): XP_LINEAR 122 / XP_DECADE 37.2 await owner OK.
   Next: set `RaceConfig.MAX_CRUISE` from the probe (700-800), then Phase 2 WorldConfig/TrackRegistry, Phase 3
   save VERSION 13 + WorldService teleport, Phase 4 `tools/balance_sim.py` (W1 30 h, W2 35 h), Phase 5 ten W2 tracks
   via /build-track, Phase 6 manual place setup. Commit on `feature/alex/worlds`.
000000. **Rebirth rev. 3 + Speed full digits** (owner 2026-10-27, uncommitted). Owner: gain too low after rev. 2 and
   "1.23k" looks frozen. Rules: design doc "Rebirth system" rev. 3 (+25 per rebirth, cap x1000 at 40) and "Large Speed
   numbers" later entry (Speed full digits below 1m); REBIRTH_SPEC, HUD_LAYOUT_SPEC 8. Code: `RebirthConfig`
   EARLY_STEP 25 / ADD_UNTIL 40, `HudFormat.SPEED_SUFFIX_FROM` 1e6 (SpeedText only), RacerUiController dial tier.
   test-writer updating Phase2Tests / Scenarios hud / UiSpec. Next: run `rebirth`, `hud`, `leaderboard` + UI tests live.
00000. **Rebirth curve rev. 2 + lost race gain** (2026-10-27, uncommitted). Owner: x10 per rebirth too high, and
   multi "not applied" while racing. Rules: design doc "Rebirth system" (rev. 2), REBIRTH_SPEC "Automatic bonus".
   Code: `RebirthConfig` (+EARLY_STEP 5 per rebirth, capped at x100 from ADD_UNTIL 20), `RaceService` commitStat caps
   each AddSpeed at `PlayerData.MAX_ADD` and carries the rest (was silently dropped above 1e6). test-writer updating
   Phase2Tests / UiSpec. Next: run `rebirth`, `economy`, `gacha` and the UI rebirth tests live.

0000. **Speed gain rebalance** (2026-10-27, uncommitted, on the car-redesign branch's tree; owner: balance like the
   "+1 Speed" keyboard games). Rules: design doc "Owner decision, 2026-10-27 (Speed gain rebalance", "Rebirth system",
   "Aura and trail ladders"; REBIRTH_SPEC; CLAUDE.md car-gacha bullets. Code: `RebirthConfig` (REBIRTH_TOTALS,
   REPEAT_FACTOR), `MarketConfig` (new multis/prices, frost_trail, prism_trail, `GainMulti`), `GachaService.SpeedGainMulti`,
   `VehicleEffects` / `MarketArtConfig` / `VfxArea` (2 trails, 9 lanes), `MarketUi` subtitle. Tests updated by
   test-writer + ui-test-writer. Next: run rebirth, gacha, economy, vehicle_effects, shop_purchases, data + UI tests
   live; look at the 2 new trails in `/tp vfxarea`; commit on its own feature branch, separate from the car redesign.

000. **Giant scenery in every biome** (2026-10-27, uncommitted, on this branch's tree): owner asked every biome to get
   big assets like the City. Design doc + BIOME_DRESSING_SPEC Layers 9 "Every biome"; data only in
   `src/shared/BiomeThemes.luau` (`giant`/`giants`, a `Blocks` entry per biome). Live: `environment` 343/344 (only
   city_blocks_gap, bug ab037b16). Next: owner looks while racing; full suite; commit separately from the car redesign.

00. **Car redesign v3 (toy racer) + Singularity orb: DONE, merged to main 2026-10-27 (6ad9717); full suite 50/3, all car / orb scenarios green, the 3 failures are the uncommitted giant-scenery work (bugs ab037b16, b99e2c0b). Left: owner look while racing, placeholder tuning.** History: (branch
   `feature/alex/car-redesign-v3-toy-racer`). Owner approved the pilot 2026-10-27 ("keep big wing"), then asked for the
   Singularity orb (small, spinning, floating / bobbing, bright neon glow). Rules: design doc entries 2026-10-27,
   CAR_REDESIGN_SPEC sections 10-11, VEHICLE_SKINS_SPEC. Done: all 111 cars rebuilt (max 13,496 tris, |x| <= 1.92),
   uploaded (new ids.json), meshes.json dumped, RedesignCarModels rbxmx rewritten (singularity: Orb parts + OrbGlow);
   `Shared/OrbMotion`, `Client/OrbAnimator`, `CarAppearance` orb Weld, `BestRollView` orb offset; test
   `singularity_orb` (test-writer) seen RED (missing feature only). Full suite run was cut off at `npc` by someone
   playtesting in the same Studio (FrozenCookie12345 admin commands); all scenarios through `npc` PASS, car_size
   length_ratio 0.534. NEXT: with Studio free, physics-tester full suite (car_redesign, singularity_orb, pass_cars,
   car_expansion, showcase, vehicle_effects must pass), Studio screenshot of the orb, then the owner looks at the cars
   in Studio; merge to main only after that. Upload needs `SSL_CERT_FILE=/etc/ssl/cert.pem` (python 3.14 has no CA
   bundle). Bug 1ec93137 (CarPhysics:266 clamp NaN on manual cars) logged, not fixed. The UI visual-pass session
   (worktree ../RobloxGames-ui) is waiting for Studio too.

0. **Ember Wyvern flight + breath — DONE, committed and pushed to main 2026-10-27; full suite END pass=51 fail=1 (only environment city_blocks_gap, bug ab037b16, City Blocks work still uncommitted in the tree)**. Next session goal: car redesign v3 (toy racer style, 15,000-triangle cap, pilot Rusty Hatchback / Street Racer / Singularity, owner 2026-10-27) on its own branch. (branch `feature/alex/ember-wyvern-flight`, all
   uncommitted; owner 2026-10-27: "stop test suite, begin implementation of features first").
   - Done: 33-bone rig (`drafts/cars/ember-wyvern/wyvern_rig.py`), long whip tail (template |z| 5.62), rigged upload
     Model 100205140229978 (`assets/meshes/cars/{ids,meshes}.json`, `assets/studio/RedesignCarModels/ember_wyvern.rbxmx`
     with bones, Motor6Ds, `Rig = "Wyvern"`); `Shared/WyvernMotion` (flap bursts / glides, livelier body, `Breath`),
     `Client/WyvernAnimator` (frame = Body part, waits for all bones), `Shared/WyvernBreath` (blue fire on the Head
     bone), `SkinScale` 2.5 race / `CarAppearance.DISPLAY_SKIN_MAX` 1.6 pedestal, `MAX_HALF_SPAN` 9,
     `VehicleEffects.TEXTURES`/`FLIPBOOKS` exported, `BestRollView` skips rigged wings. Specs: `docs/WYVERN_FLIGHT_SPEC.md`,
     `docs/WYVERN_BREATH_SPEC.md`, design doc entries, CAR_REDESIGN_SPEC 9, GAMEPASS_CARS_SPEC 5, VEHICLE_SKINS_SPEC.
   - Seen live in Play (test player, skin applied server-side with `CarAppearance.Apply`): flapping, body motion,
     breath from the jaws (`drafts/cars/ember_wyvern/redesign/views/studio_flight.jpg`, `studio_breath.jpg`).
   - Tests written by test-writer, not run on the latest code: `wyvern_flight` (106/106 before the size / tail change),
     `wyvern_breath` (never run), `pass_cars` (DISPLAY_SKIN_MAX), `car_redesign` (tail bound 5.8). Last full suite:
     49/2 before the latest changes (pass_cars scale, since fixed in the test; environment city_blocks_gap, bug
     ab037b16, from another session's uncommitted City Blocks work in this tree).
   - Studio: `RedesignCarModels.ember_wyvern` was built through MCP (Rojo cannot create MeshParts); the owner must
     save the place (manual.json save-place-wyvern-rig-2026-10-27).
   - Next, in order: (1) physics-tester full suite (wyvern_flight, wyvern_breath, pass_cars, car_redesign must pass;
     `breath_zero_in_flap_bursts` is a known judgement call, ask test-writer); (2) commit ONLY the wyvern files — keep
     out `src/shared/BiomeDressing.luau`, `src/shared/BiomeThemes.luau`, `src/server/CarTest/EnvironmentTests.luau`,
     `docs/BIOME_DRESSING_SPEC.md`, and stage only the wyvern parts of `docs/GAME_DESIGN_REQUIREMENTS.md` and
     `tools/dashboard/data/tests_explained.json` (they also hold the City Blocks edits); (3) owner asked to push to
     main when the tests pass: fast-forward / merge to `origin/main`, then the progress-tracker skill.
   - 2026-10-27 (session robloxgames-e7): low-speed flap glitch fixed. Wing / Breath used `os.clock() % period` and
     the period depends on speed below `CRUISE_SPEED` 45, so speed jitter jumped the phase (fine above 45). Now
     `WyvernMotion.CycleSeconds(speed)` + optional `state.Cycle` integrated by `WyvernAnimator`; Pose/Breath without
     Cycle unchanged. New checks `wyvern_low_speed_*` (needs the animator's `SMOOTH` 0.15 = test `ANIM_SMOOTH`).
     Tuned placeholders `FLAP_DOWN` 40 -> 34 deg, `BANK_MAX` 12 -> 8 deg so `wyvern_half_span_at_extremes` passes
     (9.31 -> 8.945, limit 9; sweep 48.8 >= 40). Rig backup in Studio `ServerStorage.WyvernRigBackup_2026_10_27`
     (delete after the place is saved). Still to run: pass_cars, car_redesign, full suite.
   - Not built: the draft's tail wake and wing-tip streams (`vfx_profile.luau`), not asked for.

1. Owner look at the bigger scenery and City towers while racing; tune `SCALE` / `BUDGET` (placeholders).
2. Live check of the loser screen after an NPC loss (Codex fix in `src/client/NpcRacerView.client.luau`, static
   checks only).
3. Cost of the denser scenery (5657 parts, 77 emitters): phone frame time and 7-player particles. Studio throttles to
   15 fps when unfocused, so this is manual (`data/manual.json` scenery-device-check-2026-10-27).
4. Owner by hand: Lighting.Technology = Future, save the place (`data/manual.json`; MCP cannot set it). Owner visual
   review of the biomes while racing.
5. Run `[UITEST]` live: new checks must be seen red first; then the manual ones (manual ui-rules-manual-2026-10-27).
6. Layout items band-vs-compact-roll and Rebirth tile vs Money at short viewports (UI test reconcile is done).
7. Showcase pedestal cars in the workshop not checked by eye (`SHOWCASE_Z = 11`, `SHOWCASE_CAR_SCALE = 1` are
   guesses).
8. `/compat-check` (on demand, not a gate): the UI, multiplayer, world and regression suites have not had a clean
   run since 2026-10-22; refresh before merging this branch.

## Known risks

- `npc` scenario can flake on load inside the full run (passes alone).
