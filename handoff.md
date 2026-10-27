# Agent handoff

Only the current state and open work. Older entries (2026-10-02 .. 2026-10-26) were trimmed on 2026-10-27; they are
in git history (`git log -p -- handoff.md`, last full version at 2d99d78) and in `context/ProjectContext.luau`.

## State — 2026-10-27

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

0. Ember Wyvern skin (2026-10-27, approved): `RedesignCarModels/ember_wyvern` (Rojo-synced rbxmx). Next: blue-fire effects (design-doc entry first, `drafts/cars/ember-wyvern/vfx_profile.luau`) and the race flap
   (todo ember-wyvern-effects).

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
