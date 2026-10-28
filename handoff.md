# Agent handoff

Only the current state and open work. Older entries (2026-10-02 .. 2026-10-26) were trimmed on 2026-10-27; they are
in git history (`git log -p -- handoff.md`, last full version at 2d99d78) and in `context/ProjectContext.luau`.

## State — 2026-10-27

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
