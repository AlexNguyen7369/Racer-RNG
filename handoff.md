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
