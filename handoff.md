# Agent handoff

Only the current state and open work. Older entries (2026-10-02 .. 2026-10-26) were trimmed on 2026-10-27; they are
in git history (`git log -p -- handoff.md`, last full version at 2d99d78) and in `context/ProjectContext.luau`.

## State — 2026-10-27

- Branch `feature/alex/race-progress-map-completion`, everything committed and pushed (2d99d78): biome visual pass
  (scenery budget 800), Codex's loser screen fix, rendering pass + car geometry (e3f752a), trail / aura VFX,
  codebase re-audit and the three UI rules (UiMotion, SafeInsets, gamepad focus).
- Last verified: full harness `END pass=50 fail=0` on 2026-10-26 (scenery budget 400); `environment` 328/328 at 800.
- Studio: open the place, `rojo serve`, click Connect in the Rojo plugin (it must be reconnected after every Studio
  restart). One Studio, one test run: check `agent_bus.py context --agent claude` before using it.

## Open work

1. Full harness at scenery budget 800 (only `environment` has run at 800).
2. Live check of the loser screen after an NPC loss (Codex fix in `src/client/NpcRacerView.client.luau`, static
   checks only).
3. Cost of the denser scenery: phone frame time, and particle cost (78 emitters + trails / auras) with 7 players.
4. Owner by hand: Lighting.Technology = Future, save the place (`data/manual.json`; MCP cannot set it). Owner visual
   review of the biomes while racing.
5. Studio-only UI checks for the three UI rules: Controller Emulator (gamepad focus), notched phone in Device
   Simulator (safe insets), Reduced Motion on. ui-test-writer should add coverage for them.
6. ui-test-writer reconcile of stale UI tests (todo `isaac-ui-tests-reconcile`: ui_layout UIScale model,
   ui_upgrades tiles, ui_rebirth NextMultiplier, ui_inventory / progression); then layout items band-vs-compact-roll
   and Rebirth tile vs Money at short viewports.
7. Showcase pedestal cars in the workshop not checked by eye (`SHOWCASE_Z = 11`, `SHOWCASE_CAR_SCALE = 1` are
   guesses).
8. `/compat-check` (on demand, not a gate): the UI, multiplayer, world and regression suites have not had a clean
   run since 2026-10-22; refresh before merging this branch.

## Known risks

- `npc` scenario can flake on load inside the full run (passes alone).
