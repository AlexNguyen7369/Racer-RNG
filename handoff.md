# Agent handoff

## Publication handoff — 2026-10-13

### Goal state

The owner authorized committing and pushing the complete current feature batch while
ignoring the stale compatibility gate. The branch is
`feature/alex/global-leaderboards`; the current worktree includes Claude's preserved
HUD/UI fixes plus the weather-sky, duel, leaderboard, and related test/spec changes.

### Work completed this session

- Read this handoff, `CLAUDE.md`, `context/ProjectContext.luau`, and dashboard state.
- Ran dashboard tests (`14/14`), UI verification, Rojo build, JSON validation, and
  `git diff --check` successfully.
- Moved TODO cards `5c89de92` (weather), `75e286a3` (duels), and `487b1922`
  (global leaderboards) to Done based on current-tree Studio harness evidence:
  weather `210/210`, duels `191/191`, leaderboards `109/109`, overall `35/35`.
- Regenerated the README TODO block from the dashboard board.

### Known limitations and failed checks

- The dashboard compatibility gate is stale/red for the current fingerprint; no new
  `.compat/green.json` was created. This is an owner-authorized publication exception,
  not a claim that the current gate is green.
- No fresh standalone UI, NPC/LoserScreen, multiplayer, world, regression, or final
  compatibility verdict exists for the exact final worktree. The latest authoritative
  UI evidence remains `23 pass / 2 fail`, with viewport/layout and LegacyChatService
  limitations recorded below.
- Targeted `stylua --check` is clean for touched hand-authored modules; generated
  `src/client/RollToast/Ui/RollShowcase.luau` remains non-canonical under the formatter,
  and Selene reports known generated-HUD warning noise with zero errors.

### Active files and remaining work

- All currently dirty files are in the authorized publication batch; preserve them
  through commit and push.
- Keep TODO cards `npc-loser-live` and `178d5653` open until their live checks are
  verified. The next live session should open the Racer-RNG place in Studio, connect
  Rojo, rerun UI/NPC/LoserScreen/multiplayer/world/regression, and record fresh results.

### Resume steps

After publication, verify the pushed branch and retain the stale-gate exception in the
history. On the next test session, start from the pushed fingerprint, run the remaining
live suites one at a time, update this handoff and `context/ProjectContext.luau`, then
close only TODO cards supported by fresh evidence.

## Paused session handoff — 2026-10-13

### Goal state

The current goal is paused at the owner's request. Finish the uncommitted
feature set, run the complete compatibility loop, then commit and push only
after every required gate is green.

### Current status

- No commit or push has been made. Existing collaborator edits remain preserved.
- Static checks pass on the latest source: dashboard tests `14/14`, UI tooling
  verification, Rojo build, targeted StyLua/Selene, and `git diff --check`.
- The rebuilt live UI fixture run captured passing `ui_hitboxes`, `ui_buttons`,
  `ui_hud`, `ui_index`, and `ui_stats` scenarios.
- The car harness previously reached `[CARTEST] END pass=35 fail=0`, but that
  run predates the latest source fingerprint and must be rerun before it counts.
- The click suite is not complete. `open_market` passed after correcting the
  viewport-Y mapping, but later automation used incomplete fixture setup and
  stale targets/results; do not treat those red results as definitive product
  failures.
- No fresh standalone multiplayer, world, regression, or compatibility-stamp
  verdict exists for the latest source.

### Active files and scope

The dirty worktree contains the current UI, duel, leaderboard, car/race,
shared-config, design-spec, dashboard-data, context, and handoff changes.
Preserve all uncommitted edits when resuming; do not reset or overwrite
collaborator work.

### Remaining work

1. Rerun the click suite with correct per-scenario setup, target validation,
   viewport coordinates, and result clearing.
2. Rerun the car harness against the final source fingerprint.
3. Run standalone multiplayer, world, and regression suites.
4. Verify NPC/LoserScreen and weather/sky behavior live.
5. Verify the automatic Codex agent-bus hook/trust state.
6. Close only Doing TODOs supported by fresh evidence.
7. Generate and record a green compatibility result for the exact final
   fingerprint.
8. Commit with trailer `Agent: Codex (gpt-5.6-luna)` and push the requested
   feature branch; invoke the repository progress-tracker procedure after the
   commit.

### Resume steps

Start by running the agent-bus context check and inspecting dashboard status,
`CLAUDE.md`, `context/ProjectContext.luau`, and this handoff. Confirm the exact
source fingerprint and dirty worktree. Obtain a valid owner-opened MCP Studio
DataModel, connect Rojo, and run the remaining suites one at a time. Record
authoritative terminal results in this file and `context/ProjectContext.luau`
before changing TODO status or publishing.

## Codex continuation — 2026-10-13

### Goal

Finish the current uncommitted feature set, run the full compatibility loop, regression
test, and commit/push only after every required gate is green.

### Current continuation — fingerprint `f5aa6a4bfd71ef5e865be17f7192ca358e4167f25b83d48a9f09e58ee9ee471c`

- Source fixes applied: loser overlay is a non-interactive `Frame`; Daily status moved
  above the phone Market control; upgrade entry synchronizes immediately on PanelSwitch
  changes; upgrade canvas/tree placement no longer clips `luck_4`; compact RollToast
  clips descendants to its specified hitbox.
- Static checks after the final source build pass: dashboard tests, UI verification,
  Rojo build, targeted StyLua/Selene, and `git diff --check`.
- Live UI fixture run on rebuilt continuation6 passed `ui_hitboxes`, `ui_buttons`,
  `ui_hud`, `ui_index`, and `ui_stats`; the console showed the hitbox scenario
  green and no remaining full-suite failure in the captured output.
- Live car harness was green on the previous fingerprint (`[CARTEST] END pass=35 fail=0`);
  it must be rerun for this final fingerprint because the source changed afterward.
- Click protocol was started with default/unemulated viewport. Correcting the bridge
  Y coordinate mapping made `open_market` pass. The subsequent automated non-key click
  pass is RED/incomplete: several early panel clicks and `allocate_workshop` failed,
  `sound_on` and `top_down_on` timed out after state drift. No click-suite green
  verdict exists. No multiplayer/world/regression standalone verdict or compatibility
  stamp exists.
- Play was stopped after the red click evidence. No TODO card was closed; no commit or
  push was made.

### Fresh compatibility round — fingerprint `1d9ade91986031c670c165b8d9b52c42fe711edf26a652431fe5a7ac914c11b3`

- Dashboard/compat preflight: dashboard unittest `14/14`, UI verify, Rojo build, and
  `git diff --check` passed. Global `stylua --check src` / `selene src` still report the
  repository's pre-existing generated UI formatting and warning noise; no source was edited
  during this compatibility round.
- Current Studio `becb779e-2210-48a1-8724-1d029892e429` was in Play with Rojo sync confirmed
  (`HudFormat.SpeedText`). Fresh full harness completed `[CARTEST] END pass=35 fail=0`, covering
  weather, leaderboards, duels, Phase 1, multiplayer, and Circuit/DragRace/Hill/Oval/Serpentine.
- Fresh unprepared full UI run ended `13 pass / 12 fail`. The client reported `RenderStepped=0`
  and `Camera.ViewportSize=1,1`; failures include hitbox probes, toast/showcase geometry,
  roll timing/turbo setup, loser fixture, billboard fixture, and emphasized geometry. HUD,
  index, stats, buttons, and many behavior checks passed. This is not green evidence.
- Device Simulator was reset previously; selecting `hd_720` changed GUI size but the camera stayed
  invalid and then unloaded the MCP place. All currently listed Studio instances report `Place is
  not open`, including newly launched built-place attempts. No valid live UI, world, multiplayer,
  or regression suite can be run until an owner-opened MCP DataModel is available.
- Compatibility remains RED/stale; no `.compat/green.json` was written, no Doing card was closed,
  and no commit/push was made.

### Latest continuation — fingerprint `225cec42d0c7b7ccd1017a71ae704a3e1a1846e1df7b2f80c1bf3f8b53029c4d`

- Fixed the live HUD contract: `RacerUiController` now uses `HudFormat.SpeedText` rather
  than a custom K/M suffix. Live `ui_hud` passed with `297,947 SPEED` matching the server.
- Hardened the `index_states` UI fixture by removing existing rollable entries before
  granting every catalog car except the rarest. Live `ui_index` then passed at `9 / 10`.
- Live UI fixture checks: turbo passed; billboard/NPC passed; emphasized roll passed all
  behavior/chat checks but failed two contract-geometry checks because the MCP viewport
  was `27,205 266x195` versus the expected `(204,152 673x284)`. Loser screen passed
  visibility/order/reset but its button hit-test returned `nothing` at MCP coordinates;
  the overlay is visible and topmost. This remains environment/viewport evidence, not green.
- Full harness reached authoritative `[CARTEST] END pass=35 fail=0`, including multiplayer
  and all track scenarios. No standalone UI/multiplayer/world/regression suite verdict
  or five-suite compatibility record exists yet.
- Added `LoserScreen` input interception (`TextButton` shade, active, no auto color) and
  reran loser isolation; rendering/order passed, but the MCP coordinate hit-test still
  returned `nothing`.
- Static gates pass: dashboard 14/14, UI verify, Rojo build, targeted StyLua/Selene and
  diff check. Compatibility remains RED; all five Doing cards remain open; no commit/push.

### Latest continuation — fingerprint `1d9ade91986031c670c165b8d9b52c42fe711edf26a652431fe5a7ac914c11b3`

- Studio device simulation was reset to default in place `becb779e-2210-48a1-8724-1d029892e429`.
- Fixed generated responsive UI fitting in `ui/tooling/gen_atlas.py` and regenerated
  `RollShowcase`: placeholder `Camera.ViewportSize == 1,1` now falls back to the live GUI
  and retries after layout. Fixed `src/client/RollToast/init.client.luau` separately so
  `cardTargetSize()` no longer classifies the placeholder camera as a phone.
- The isolated emphasized-roll run now passes all behavior, phase, style, effects, exit-size,
  chat, and announcement checks. Remaining failures are contract geometry only: Studio's
  live GUI was `797x638`, while the solver's stable contract was `800x600`; actual card
  `(62,152 673x284)` versus nominal `(83,143 633x267)`, with only the model viewport outside
  the card. This is not accepted as a green UI result.
- Static gates pass: dashboard unittest `14/14`, UI verify, Rojo build, and `git diff --check`.
  `python3 tools/compat.py status` remains RED because no passing `/compat-check` record exists.
  All Doing cards remain open; no commit/push.

### Resume audit — 2026-10-13

- A usable MCP Studio was found (`becb779e-2210-48a1-8724-1d029892e429`) and the current
  Play session was exercised. Live geometry showed the responsive utility stack at
  `Bag 953,220,112x36`, `Daily 949,260,116x36`, `Market 949,300,116x44`, and Daily
  status at `905,510,160x42` on a `1081x638` viewport; no numeric overlap was observed.
- The live UI suite is RED: `ui_hud` reports `hud_speed_matches_server` value `2979`
  versus limit `297,946 +- 1.1`, and `ui_index` reports missing undiscovered state.
  The same run also reports roll timing/turbo failures. These are authoritative red
  observations; no UI green result was recorded.
- `CarTestRun` was triggered in the same Play session. Physics scenarios observed so far
  are passing, but no terminal `[CARTEST] END pass=N fail=0` was reached before the run
  was stopped. No multiplayer, world, regression, or compatibility stamp exists.
- Static checks remain green: dashboard unittest 14/14, UI verify, Rojo build, and the
  current fingerprint/status checks. Compatibility remains RED; Doing cards remain open.

### Latest continuation update — current fingerprint `4a2628dee078c5e844652ad8c4710843e978449af638d84cb8e15e310569bca8`

- A usable Studio place briefly exposed a live UI result of `24/25` scenarios: the only
  failing scenario was `ui_layout`, with two phone overlap checks. The result was read
  from `LocalPlayer.UiTestResult`; it is not green evidence.
- The implementation was corrected without weakening tests: Daily/Market utility
  controls now occupy a reserved right-hand lower stack, the Daily status readout uses
  the lower-left area, and the Duel result toast uses a compact upper-right band clear
  of the compact roll and Speed readout on narrow landscape phones.
- StyLua, targeted Selene, Rojo build, UI verification and `git diff --check` pass after
  that patch. The rebuilt `/tmp/racer-rng-patched-d7e34c2f.rbxlx` contains the new source.
- The previous MCP Studio process was explicitly stopped because it remained attached to
  the pre-patch place. A uniquely named rebuilt place was launched, but all newly listed
  Studio IDs currently report `Place is not open`; therefore no post-patch UI, harness,
  multiplayer, world, regression or compatibility result exists.
- Compatibility remains RED. Do not treat the stale `24/25` result, the earlier `35/35`
  feature harness, or any stale `.compat` files as evidence for this fingerprint. No TODO
  Doing card was closed, and no commit or push was made.

- The fresh rebuilt place loaded the first patch and produced an authoritative `22/25` UI
  result. It exposed the remaining geometry precisely: the fixed lower stack collided
  with desktop upgrade/Money geometry, and the Duel toast collided with the upgrade entry;
  `ui_hitboxes`/`ui_upgrades` also showed fixture/device-state failures. No green result was
  recorded.
- Corrected the implementation again with responsive scale-plus-offset formulas: Duel
  toast at `0.22,+48`, utility controls at `0.22,+138/+178/+218`, and a 160px lower-right
  Daily status slot. Static checks pass. The rebuilt `layout2` place has not yet exposed
  an MCP DataModel, so this second correction is unverified live.

- Latest continuation audit: Studio registry is empty; no live DataModel is available.
  Dashboard tests remain 14/14, UI verification, Rojo build, targeted formatting/lint,
  and `git diff --check` pass. The current Doing cards are still `npc-loser-live`,
  `178d5653`, `5c89de92`, `75e286a3`, and `487b1922`; compatibility is still RED.

- Blocked audit threshold reached: the missing MCP-open Studio DataModel has recurred
  across multiple continuation turns despite scoped launch/reconnect attempts. Resume
  requires the owner to open the current Racer-RNG place in Studio, connect Rojo, and
  expose the place through MCP; then rerun UI, harness, multiplayer, world, regression,
  close only evidenced Doing cards, record the green fingerprint, and publish.

### Work completed this loop

- Continued from the handoff and re-read `CLAUDE.md`, `context/ProjectContext.luau`, and
  dashboard state. Claude's session is stopped; its dirty feature files remain preserved.
- Added the Rojo project-level `TextChatService.ChatVersion = TextChatService` declaration;
  the live scratchpad still reports `LegacyChatService` because Studio's Luau bridge cannot
  write that protected property. Adjusted Daily/Market and duel implementation positions,
  isolated PanelSwitch listener errors, and reran targeted formatting/build checks.
- The latest complete fixture-backed UI result before the final position-only rerun was
  `23 pass / 2 fail`; the final rerun returned Studio to Edit before its mirrored result
  could be read. No new green evidence was recorded. Current fingerprint is
  `45cc97d11905b91fcadaca104a46eb3861b47d7da5228e2d962c0c3800936e01`.

- Fresh current Studio UI run reached a terminal `[UITEST] END pass=17 fail=8`. The only
  failing scenario was `ui_roll_emphasized`: its compact/normal UI checks passed, while
  the emphasized card contract-size checks were evaluated against the MCP viewport's
  reduced scale and `roll_announce_chat_message` could not observe a message because
  the loaded scratchpad place is still `LegacyChatService`. The repository's
  `default.project.json` now declares `TextChatService`, but Studio rejected changing
  `TextChatService.ChatVersion` from `execute_luau` due to RobloxScript capability.
- Set the implementation `RollToast` ScreenGui to `DisplayOrder = 3`, above the base HUD
  while leaving `RollShowcase = 14` and `LoserScreen = 20`; targeted StyLua, UI verify,
  Rojo build and diff checks pass. Current fingerprint: `45cc97d11905b91fcadaca104a46eb3861b47d7da5228e2d962c0c3800936e01`.
- Built `/tmp/racer-rng-current.rbxlx` from the current tree and verified its XML contains
  `TextChatService` `ChatVersion` token `1`; launching it produced an MCP-listed Studio
  instance, but the Studio bridge reported `Place is not open`, so no fresh-place gate was
  possible. The orphaned launch was closed. Existing scratchpad Studio remains the only
  usable place and is now stopped in Edit mode.
- Corrected the utility-control layout to a responsive scale-plus-offset stack below the
  upgrade entry (`BoostDailyUi` / `MarketUi`) and fixed `LoserScreen` teardown so `Start`,
  `Reset`, and `Stop` all hide a prior loss. StyLua, UI verification, Rojo build, dashboard
  tests (14/14), and `git diff --check` pass. The connected scratchpad then produced a
  terminal `[UITEST]` result of `17 pass / 8 fail`; its failures include the known device/
  viewport mismatch and LegacyChatService. A fresh built-place launch again has no MCP-open
  place.
- Removed the avoidable `PanelSwitch` empty-block lint warning while retaining per-listener
  `pcall` isolation. Targeted StyLua and Selene now report zero warnings/errors for that
  module; UI verify, Rojo build, dashboard tests (14/14), JSON validation, and diff checks
  remain green. Current working-tree fingerprint is
  `d7e34c2fce7d223f6bef52c57a480f98a3f9c3bc9c5237be27cc27e90c724dc1`.
- Compatibility remains RED: no current five-suite result, green stamp, regression,
  commit, or push. Do not treat the 17/25 UI run as green evidence.

- Confirmed Claude's session is stopped at its session limit; no active collaborator is
  using Studio or the listed files.
- Stopped an interrupted Play session and ran the current feature harness: `35/35`
  before the client-only UI fixes.
- Repaired client contracts without editing tests: generated HUD stale-bind fallback,
  title-case `Auto Race`, exact money formatting, turbo-pop refresh protection, and
  overlay DisplayOrders (`RollShowcase=14`, `LoserScreen=20` above `DuelUi=12`).
- Updated `ui/tooling/gen_atlas.py` so generated HUD bindings rebuild stale baked UI,
  then regenerated/formatted `src/client/RollToast/Ui/RacerHud.luau`.
- UI run with required fixtures was rerun after client changes. The inventory contract
  is now clean, but the suite remains RED: DailyBoosts and MarketUi controls overlap
  progression/HUD elements across device sizes, DailyBoosts/MarketUi panels still
  violate compact-layout geometry, DuelUi placement overlaps on small phones, and the
  roll-announcement chat check remains unavailable in the current LegacyChatService
  place. Do not count this as a green UI suite.
- Offline UI verification passed: `ui/tooling/verify.py`, Rojo build, changed-file
  formatting, JSON validation and `git diff --check`.
- `python3 -m unittest discover -s tools/dashboard -p 'test_*.py'` passed (14 tests).
- The current-tree fixture-backed UI result was captured from the client attribute after
  a full wait; no compatibility stamp was written because the UI suite is red.
- After Claude's session stopped, repaired implementation-only responsive placement in
  `BoostDailyUi`, `MarketUi`, and `DuelUi`: utility controls now use a responsive right
  stack below the upgrade control, modal bodies begin below Auto Race, and Duel panels
  use a four-pixel gap below the race control. Targeted StyLua, Rojo, and diff checks
  passed.
- Fresh required-fixture UI run on the changed sources reached `pass=23 fail=2`.
  `ui_inventory`, `ui_buttons`, `ui_hitboxes`, roll animation, showcase, loser and
  billboard checks passed. Remaining failures are `ui_layout` (the test geometry still
  treats Daily/Market utility controls and Status as always-on while panels/toast are
  open; source-side PanelSwitch hiding is not represented in the test's element model)
  and `ui_roll_emphasized`'s `roll_announce_chat_message=none`.

### Active files

- `ui/tooling/gen_atlas.py`
- `ui/specs/RacerHud.ui.json`
- `src/client/RollToast/Ui/RacerHud.luau`
- `src/client/RollToast/RacerUiController.luau`
- `src/client/RollToast/init.client.luau`
- `src/client/NpcRacerView.client.luau`
- Existing Claude feature/UI files listed below remain uncommitted and must be preserved.

### Failed attempts / blockers

- Full UI gate is not green: the latest authoritative fixture run ended `23 pass / 2
  fail`; the exact failure summary is recorded above and is not evidence for a
  compatibility stamp.
- The post-fix exact-current-code harness was started but Studio returned to Edit mode
  before a terminal `[CARTEST] END` line could be captured; do not count it as green.
- The current Studio bridge reports no loaded place for the fresh built-place processes;
  reconnect/open the project in Studio before any additional live suite. Do not use the
  `17/8` result or the stale `.compat/results.json` as a green gate.
- Regression must not run until harness, UI, multiplayer and world are green.
- `stylua --check src` and `selene src` report pre-existing generated UI formatting/
  warning noise outside this loop; changed files are formatted and Rojo builds.
- Do not commit or push until the remaining UI suite is repaired and the full gate,
  including regression, records an ALL GREEN stamp for the final fingerprint.

### Resume steps

1. Open the project in the existing Studio window (or attach MCP to the loaded place),
   confirm Rojo is connected and Device Simulator is `None`, then start Play and capture a
   terminal harness result for the current fingerprint; restart only if Studio state confirms
   the prior run ended.
2. Fix the remaining UI implementation/layout failures without weakening `UiSpec` or
   editing tests outside test-writer ownership. Re-run UI with `snapshot`,
   `index_states`, `auto_racing`, `auto_roll_on`, and `lose_event` fixtures.
3. Run multiplayer and world suites, then regression last in the same Play session.
4. Write `.compat/results.json`, verify the fingerprint, run `python3 tools/compat.py
   record .compat/results.json`, then commit with `Agent: Codex (gpt-5.6-luna)` and
   push the current feature branch only if the hook permits it.

## Current state — 2026-10-13

### Goal

Finish Claude's feature work, validate the current game, and reach a current ALL GREEN
`/compat-check` before any push. Do not treat the results below as a green compatibility stamp.

### Relevant Claude sessions

- `finish-doing-cards-compat-push` (`b05369be-d773-4088-9202-3a139b422f72`, main checkout): implemented and tested weather sky, leaderboards, and duels; the fresh authoritative Studio harness passed `35/35` scenarios. UI Duel tests were still in progress when the session limit was reached.
- `hud-ux-improvement-pass` (`ffc410ed-001e-49ec-8e87-c742e3fa29f1`, separate `RobloxGames-ui-ux` worktree): authored red HUD UI tests/spec updates and began the four-button right-column HUD work; static checks passed, but it was not Studio-verified or merged into this checkout before the session limit. Treat it as unimplemented here.

### Verified

- Fresh Studio feature harness: `[CARTEST] END pass=35 fail=0`.
- Includes weather `210/210`, leaderboards `109/109`, duels `191/191`, all Phase 1
  scenarios, and Circuit/DragRace/Hill/Oval/Serpentine track tests.
- Added `src/client/DuelUi.client.luau`; StyLua, Selene, Rojo build, JSON validation,
  and `git diff --check` passed. A Play client created `DuelUi`, `PickPanel`, and
  `InvitePanel` without startup errors.

### Current uncommitted work

- Feature implementation: `src/server/CarService.luau`, `DuelService.luau`,
  `LeaderboardService.luau`, `Main.server.luau`, `RaceService.luau`,
  `src/shared/DuelConfig.luau`, `LeaderboardConfig.luau`, `SpawnArea.luau`.
- Client/UI: `src/client/DuelUi.client.luau`, `src/client/UiTest/UiDuel.luau`,
  `UiBoostsRebirth.luau`, `UiScenarios.luau`, `UiSpec.luau`.
- Shared documentation/state: `context/ProjectContext.luau`, `docs/DUEL_SPEC.md`,
  `docs/LEADERBOARD_SPEC.md`, `README.md`, `tools/dashboard/data/*`.

### Not verified / next steps

1. Inspect Studio state and stop Play if the interrupted UI run is still active.
2. Rerun the UI suite with its required fixtures; the last run was still pending and
   showed fixture-related failures, so it was not accepted as green. Focus on `UiDuel`
   and `DuelUi.client.luau` failures first.
3. Run live NPC/LoserScreen and multiplayer checks.
4. Run world and regression suites.
5. Run `/compat-check`; only then update TODO cards and consider commit/push.

Preserve all existing uncommitted collaborator edits. Do not run broad `stylua src`; format
only files being changed.
