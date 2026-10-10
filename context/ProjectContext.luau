--!nonstrict
--[=[
PROJECT CONTEXT - Idle Vehicle Simulator (read me first)
Shown in Studio at: ServerScriptService > ProjectContext   (source file: context/ProjectContext.luau)
Do NOT edit this in Studio: edit the file on disk, Rojo syncs it. Claude updates it at the end of every loop.
Last updated: 2026-10-10 (Ropilot delta inventory and stale-UI repair; no publish/push)

COMPATIBILITY REVIEW - 2026-10-10
- Added urgent dashboard TODO `urgent-auto-race-path-stability` in Doing with
  `urgent: true`; dashboard API returned 404, so todo.json was updated directly
  and README TODO was regenerated.
- Dashboard tests 13/13 pass; todo.json parses; README sync, Rojo build, and
  git diff --check pass.
- Static compatibility review found no remaining SPEED_MARGIN or old bounded
  SpeedFor assertions. Recent UI cleanup/readout changes and uncapped speed
  TargetSpeed plumbing are structurally compatible.
- No ALL GREEN stamp: fresh Studio/Play validation remains required for live
  HUD behavior, Auto Race toggle/exit, high-speed corners, and off-track safety.

LATEST HANDOFF - SPEED CEILING REPAIR (2026-10-10)
- Roblox speed was stuck near 80-81 because three independent limits existed:
  RaceConfig.SpeedFor asymptoted at 75, PathDriver capped targets at 92% of
  CarConfig.TopSpeed (82.8), and CarPhysics tapered forward throttle to
  CarConfig.TopSpeed (90).
- RaceConfig now uses logarithmic diminishing returns that preserve the old
  midpoint at HALF_STAT but continue above the old MAX_SPEED reference.
- PathDriver no longer applies the fixed 92% ceiling and includes TargetSpeed
  in its control input; CarPhysics uses that target for forward throttle taper.
- Economy scenario/docs were updated to assert high-stat speed can exceed the
  legacy car baseline. Source changes are uncommitted and still need test,
  Rojo build, and fresh Studio/Play validation.
- Next session must also recheck the existing UI repair: Auto Race toggle and
  exit, exact Speed/Money readouts, Level bar, and removal of stale bottom-right
  controls. Do not publish/push before live verification.

HIGH-SPEED AUTO-RACE PATH NOTE - 2026-10-10
- User reports that once Speed is high, car physics carries too much lateral
  momentum through turns; the car drifts, can rotate 180 degrees, and leaves
  the track.
- Requirement: preserve high speed but make auto-race static to the authored
  route. The car must not drift or move away from its absolute path.
- Not implemented yet (user requested this as a note only in the current turn).
  Next implementation should be auto-race-only and server authoritative, using
  nearest path segment/tangent correction plus lateral-velocity cancellation
  and safe orientation recovery without removing forward speed. Add a high-
  speed corner regression for path deviation, reversal, and off-track exit.

ROpilot delta versus origin/main 3c661e3
- Progression/data: Level/XP and save VERSION 7, LevelService, level-gated
  rebirth with permanent Speed/Luck bonuses, potion inventory and expiry,
  daily login, duplicate-car scrap Money, offline Money, and race/workshop
  integration. Main files: PlayerData, LevelService, RebirthService,
  BoostService, DailyLoginService, GachaService, RaceService and
  WorkshopService, plus phase-2 test expectations.
- Racer UI: regenerated RacerHud/specs and UI modules, Level/XP display,
  runtime HUD baking, RacerUiController/progression updates, and UI test/spec
  changes. StarterGui.rbxm was not regenerated, leaving an old baked UI in
  Studio and causing the recent missing Level/duplicate-controls symptoms.
- World/art: marketplace, race-start pavilion and workshop garage templates,
  mesh manifests, default.project mappings, and SpawnArea/WorkshopBuilder
  native-mesh preparation.
- Documentation/tooling: README, Workshop spec, handoff, dashboard metadata,
  UI verification and Windows agent-bus changes.

CURRENT UI REPAIR - 2026-10-10
- Generated UI Bind functions rebuild stale ScreenGuis when SpecHash does not
  match the current module, so an old baked StarterGui no longer aborts the
  Racer controller.
- RacerUiController removes stale top-level legacy GUIs; legacy AutoRaceButton,
  SpeedHud, StatsUi, RollUi and IndexUi scripts also self-disable whenever the
  canonical RollToast client exists.
- Speed/Money/Unbanked readouts now update directly from replicated server
  values instead of exponential smoothing that visibly lagged behind them.
- Auto Race remains server-authoritative via SetAutoRace and AutoRacing; fresh
  Play must verify on/off toggling and stop/cash-out behavior.

SPAWN MARKETPLACE - 2026-10-10
- SpawnArea now builds Blender-authored Marketplace at original Market center
  (50,-70): three modular timber/striped-awning vendors, stone courtyard, Aura
  displays, workshop counter and fuel/parts displays. Source blender/marketplace;
  template ReplicatedStorage.SpawnMarketplace; MarketplaceBuilder and mesh manifest.
- 37 native mesh groups/34,796 triangles, anchored/double-sided cosmetic art,
  smooth box boundaries,24stud central entrance,5 local shadow-free lanterns.
  Vendor E prompts use existing Market browser; named NPC/button/display points.
- Runtime spawn/native mesh validation and11 collision-route casts PASS including
  vehicle-sized central entry. Actual walking/prompt/UI interaction UNVERIFIED
  due input timeout/disconnected or stale test context. See handoff exact routes.
  Build/Python compile/diff checks pass. Temporary art previews removed.

WORKSHOP WHITE-BOX FIX - 2026-10-10
- Original seven synced MeshParts lost MeshId/native geometry at runtime.
  WorkshopBuilder now prepares geometry once with CreateMeshPartAsync/ApplyMesh
  using WorkshopMeshAssets, retains textures and clones the prepared cache.
- Fresh runtime all13 meshes have matching ids/positive MeshSize. Garage front
  rendered correctly in Studio preview; preview removed. Workshop56/56 and
  purchase guards passed. Removed plugin-only runtime fidelity writes in SpawnArea
  that blocked startup. Play stopped. Existing phase2 line281 oracle error remains.

WORKSHOP REFERENCE GARAGE - 2026-10-10
- Rojo maps assets/studio/RacingGarage.rbxmx into ReplicatedStorage.RacingGarage.
  Builder clones13 cosmetic mesh groups and adds4 warm lights; Blender source
  and packed textures are under blender/workshop. Bolted steel/copper portal,
  caged lanterns, workbench/tools, cabinets/tires, rear-right flywheel/dyno,
  cyan chambers, floor grate and racing signage complete the reference pass.
- Gameplay plots/ownership/Zone/Pad/wall boundaries/prices are unchanged.
  Real player plus6 fixture owners verified all7 owned garages and release/reuse.
  Workshop regression56/56 and server purchase/guard checks passed. Art builds
  at levels1/2/10 all retain13 meshes/four lights and original Zone/Pad geometry.
- Client Lua timeouts prevent real E/Buy/navigation validation. Existing phase2
  test still fails at line281 on undefined Workshop.OfflineMoney (bug99c953ae).
- Owner reports setting place capacity to7. Studio still reads60; published
  setting is not independently confirmed. No publish, push or data reset.

DELIVERY SNAPSHOT - 2026-10-09
- The complete current worktree is being committed and pushed on `main` at the
  owner's explicit request. The pre-push compatibility hook is intentionally
  bypassed for this delivery; this must not be interpreted as a green gate.
- Included changes cover Level/XP progression, rebirth, potion inventory and
  purchases, daily login rewards, duplicate-roll Money, workshop offline Money,
  Market effects, Hill support geometry, Racer UI/roll-toast behavior, related
  specs, and dashboard metadata. New source files include BoostDailyUi,
  BoostService, DailyLoginService, LevelService, RebirthService, BoostConfig,
  DailyLoginConfig, and LevelConfig.
- Dashboard API was unavailable during this snapshot (`Connection refused`),
  while the local agent bus was available. Fresh Studio/Rojo validation and
  stale test-expectation reconciliation remain pending.

CURRENT DOING IMPLEMENTATION - 2026-10-09
- Progression systems now include server-owned RebirthService (Money-only reset with permanent
  Rebirth multiplier and design-doc Level milestone gates), LevelService (Speed-based XP and saved
  player levels), BoostService (one-minute Luck/Money/Speed I/II/III
  consumables with saved inventory and expirations),
  DailyLoginService (UTC streak rewards and day-7 guaranteed rare index grant), and direct duplicate-car
  scrap Money payouts from GachaService. PlayerData save VERSION is 7. New shared configs are
  BoostConfig, DailyLoginConfig, and LevelConfig; new remotes are Rebirth, PurchaseBoost, UseBoost and DailyClaim.
- The rebirth panel is live-bound in RacerUiController; BoostDailyUi provides Bag and Daily Rewards modals.
- Rebirth preserves Speed and resets only Money.
- Rebirth now follows the design milestones: Level 10, 25, 50, 75, 100, then every 25 levels. Level starts at 1;
  XP gain is based on sqrt(current Speed), and XP to next level is 100 x 1.15^(level-1). Speed remains preserved
  across rebirth per the owner request, despite the design PDF's older reset proposal.
- Each rebirth permanently increases passive Speed gain and roll Luck by 10% per rebirth level; the Luck bonus is
  included in the server-owned GachaService roll multiplier.
- Bag purchases/uses potion tiers in the modal. Daily Rewards shows all seven fixed days, remains manual while
  the next UTC claim timer is running, and opens automatically when the claim window becomes available.
- Static checks after this round: StyLua, Selene, Rojo build, and git diff --check pass. Studio full
  harness/UI/multiplayer/world validation has not yet been run for this source fingerprint.
- Current Studio Edit inspection still shows the prior synced server tree without the three new progression
  services; reconnect Rojo at localhost:34872 before treating any Play run as evidence for VERSION 6.
- The existing CarTest save-version expectation remains VERSION 5 until test-writer updates it; no test files
  were edited by Codex.
- Track wins now award a deterministic potion through `BoostConfig.WinReward`: track 1/4/... Luck, track
  2/5/... Money, and track 3/6/... Speed. The compact boost HUD refreshes active countdowns every second.
- Hill supports now account for each sloped piece's full vertical span and sit 0.05 studs below the lowest
  road underside (`TrackBuilder.SUPPORT_CLEARANCE`), addressing the Support12 poke reported by world-tester.
  This geometry change still needs the required full track/world Studio run.
- OWNER SPEED BALANCE (started 2026-10-08): equipped car models now multiply the player's current
  base/cruise race speed only. Passive racing Speed gain uses the server-owned RebirthLevel multiplier;
  car models and stat-allocation multipliers do not affect it. Workshop gain is independent of car model.
  Rebirth remains coming soon in the UI; new players default to RebirthLevel 0.
- Added ProgressionUi: hex upgrade tree with server-owned purchases, badge, hub world pad, workshop E modal,
  WorkshopRate HUD, offline welcome panel, and replicated weather banner. Workshop stat allocation is enabled.
- Workshop defaults are configurable: ten levels, level 2 costs $500, subsequent cost x5, Speed gain x2 per level.
  Owner balancing feedback remains pending. Offline gain is exactly integrated at 25%, capped at eight hours;
  Money is credited at 10% of that Speed result. OfflineAt is claimed with UpdateAsync before exposing either
  reward, so reconnecting cannot replay a saved absence. The welcome panel displays both credits.
- WeatherService schedules Rain / Night Race / Gold Rush every 10-20 minutes for three minutes, applies luck,
  Money and NPC speed server-side, restores lighting on expiry, and pauses scheduling during harness runs.
  Three event-only permanent catalog IDs reuse existing meshes: rain_runner, midnight_kart, golden_racer.
- test-writer added workshop_offline, workshop_phase2 and weather scenarios and expanded catalog assertions while
  preserving the original seven car requirements. ui-test-writer added progression scenarios and real-click contracts.
- Local checks: StyLua, Selene, and Rojo build pass. Live compatibility is now verified for the current source
  fingerprint. With Studio API access enabled, a temporary-key SetAsync/GetAsync/RemoveAsync probe against
  PlayerStats_v1 passed; the long game harness did not emit a terminal result in this session.
- Rojo is running at localhost:34872. The reopened Racer RNG Studio session now contains WeatherConfig,
  Phase2Tests and ProgressionUi; dedicated script_read confirms the current progression layout and controller.
- 2026-10-08 live verification: Play started; RacerUiReady=true and all ten gallery entries are present.
  The console reports StudioAccessToApisNotAllowed for PlayerStats_v1. No harness or UI END line was observed.
  Server execute_luau calls (even read-only probes) are rejected: "MCP tool call requires approval, but approval
  policy is never". Full suites and test fixtures remain blocked by that tool approval setting.
- Live inspection also found bottom RollControls re-enabled by responsive fits. Added a Visible property guard
  and set RollControls visible=false in the HUD spec. Fresh Play inspection now confirms Visible=false and
  RacerUiReady=true. The generated/baked HUD artifact still needs refresh; gen.py is unavailable in this checkout.
- Real DataStore persistence is now an independent verified TODO: the live API probe passed without touching a
  player record, and the temporary key was removed after the check.
- Runtime execute_luau permissions are now working. Full 31-scenario harness is running in the same synced
  Play session at fingerprint 64b1ba5787cf; physics-tester monitors it. No final END observed yet.
  Isolated real DataStore read still fails: "Studio access to APIs is not allowed". Owner asked to enable it.
  Portable UI generator repair is in progress under ui/tooling only; no game-source edits during the run.
- Full harness completed at 64b1ba5787cf: `[CARTEST] END pass=30 fail=1`. Sole failure: data,
  v4_workshop_level_clamped value 1 (expected 0). Test-writer is auditing the failing boundary case.
  All other 30 scenarios passed, including NPC timing, physics, all five tracks, workshop phase 2,
  exact offline gain/atomic claims and weather. UI diagnostic preparation follows in the same Play session.
- UI diagnostic full suite: `[UITEST] END pass=11 fail=12` at the same fingerprint. Real-click checks continue.
  Failures include progression button/panel overlaps, disabled tile hover styling, roll geometry and LoserScreen
  coverage; test-writer also audits obsolete layout expectations/model support and fixture timing separately.
  Data clamp audit identifies +infinity: the unchanged CleanLevel rejects it to level 1, but the expected-value
  helper maps it to MAX_LEVEL. The old MAX_LEVEL=1 hid this discrepancy. No test correction applied yet.

CODEX HANDOFF - 2026-10-07
- The two genuinely unfinished Claude handoff items were audited: static-settle has a warm live pass with no bounded source fix needed, while the Racer UI test rewrite is present on disk and passes local lint/build checks.
- A live harness rerun reached `[CARTEST] END pass=24 fail=1`; the only observed failure was the timing-sensitive `npc_lose_player_time_measured` check (`33.092` vs `34.805` limit). Do not call the gate green from this run.
- A live UI rerun reached `[UITEST] END pass=15 fail=1`, but Studio was executing a stale pre-Rojo-connect UiTest module. The local scenario now excludes the intentionally hidden legacy `RacerHud/RollControls` subtree; reconnect Rojo at `localhost:34872` before rerunning.
- Track 3 `DragRace` was 180 studs and violated `TrackValidator.MIN_LENGTH = 300`; its straight was corrected to 320 studs. Full Studio track-chain validation remains unverified.
- Each owned workshop now builds a tagged, neon `UpgradePad` with an `UPGRADE` billboard just outside its open front. The E interaction/modal and economy remain separate follow-up work; live placement/walk validation is pending Rojo reconnect.
- Test-first track work added `CarTest/TrackTests/Circuit.luau` and `Serpentine.luau`; Circuit is now numbered 4 and point-to-point with a final straight, and Serpentine is numbered 5. Local lint/build pass; Studio geometry, chain, and lap validation remain pending.
- Added the missing tests-first `CarTest/TrackTests/DragRace.luau` contract for Track 3: 300–400 stud point-to-point sprint, straight ends, checkpoint, wide left pad, and right-hand race path. All five track-test/spec sets now pass local Stylua/Selene/build checks; Studio validation remains pending.
- The workshop scenario now asserts an owned workshop's tagged `UpgradePad` contains an `UpgradeSign` billboard labeled `UPGRADE`; the assertion passes local Stylua/Selene/build checks but has not run in Studio.
- The dashboard's historical `rojo-connect` manual item was reopened on 2026-10-07: current Studio Edit inspection still lacks repository-only `Tracks/DragRace` and `WorkshopBuilder.UpgradePad`, so the old "verified" completion record is not valid for this worktree.


DRAFT05 CARS + RACER UI (Isaac Li, branch studio/draft05-cars-ui, merged into initial-import 2026-10-06)
RESTORATION AND CONTINUOUS REEL - 2026-10-06
- Restored Shared.CarAppearance, Server.CarService, Client.RollToast, its nested
  RacerUiController and eight Ui modules from the finalized handoff source.
  Legacy AutoRaceButton/SpeedHud/IndexUi/StatsUi/RollUi remain disabled intentionally.
- Live checks: RacerUiReady=true; Index, Stats, Settings and Rebirth opened via real
  mouse clicks. Starter raced using the revision-5 Rusty visual. All seven car IDs plus
  starter swapped revision-5 visuals while retaining the same chassis and DriverSeat.
- Improved rolling: continuous decelerating six-icon strip, centre emphasis, larger
  compact car area, outlined odds, edge fades, winner settling before reveal and landing pop.
  Genuine filler odds and server-selected result/timings unchanged. Reduce-effects respected.
- Animation live samples verified Spin -> Land -> Hold and six reel sprites; no new
  runtime errors observed. Pre-existing Studio DataStore/Avatar warnings remain.
- Backup before restoring: ServerStorage.BeforeRacerRestore_1791272871.
  Previous roll source also backed up under RollToastBeforeContinuousReel_*.
- The earlier source-discrepancy section below describes the diagnosed state BEFORE
  restoration. It is retained as history and no longer describes the active implementation.
- Roblox Open Cloud: ROBLOX_API_KEY read-only Get Universe returned HTTP 200 for
  Racer RNG, universe 10767692874, place 126725530984268; secret never printed/stored in repo.
- Shared Studio save and updated GitHub commit are being verified as separate destinations.
  No live publication or main merge authorized. Full compatibility is still pending.
- Updated personal roblox-code skill requires verified shared Studio + GitHub delivery
  when requested; a local .rbxl or local commit alone is not shared completion.

ISAAC'S HANDOFF - 2026-10-06
Project: Racer RNG. This summary supersedes obsolete TODO/status statements below.
Owner requested this documentation update in Studio. Only ProjectContext is changed by this update.

UI WORK COMPLETED IN THIS CHAT
- Cyan Index, purple Stats, matching Settings, red text-only REBIRTH and coming-soon menu.
  Rebirth matches the other navigation button sizes; no rebirth icon. Workshop remains coming soon.
- Index displays discovered cars with their original illustrated icons and EQUIP action;
  undiscovered cars use black silhouettes / ???. Car art was enlarged.
- Stats presents Speed, Money, Luck and Workshop multiplier rows with allocation buttons,
  free-point count and centered upgrade rows. Economy and ownership remain server-authoritative.
- Money at bottom-left, icon raised to align with the main number; UNBANKED directly below it.
- Speed icon and number grouped centrally below the character; studs/s secondary line removed.
  Turbo Luck centered under the combined icon+number group, with rounded edges.
- Hover pop animation on buttons; improved rolling-card/showcase interface, larger car art,
  fading edges on both sides of the rolling reel, clearer AUTO OFF positioning/text outline.
- Settings at upper-right uses an uploaded illustrated gear, not an emoji. Secret rarity is black,
  not Epic purple. Original car icon atlas remains the UI art: imported models are for racing.
- Sources/specs/assets are included on the GitHub handoff branch described below.
  Some older UI scripts are deliberately disabled by Rojo metadata to avoid duplicate HUDs.

CAR ART / BLENDER / STUDIO IMPORT
- Blender MCP configured and used for successive car drafts. Owner approved Draft03;
  subsequent iterations made the fleet cute, smooth, clean and more rounded while low-poly.
- Draft05 is the actual Blender mesh import, not a primitive-part recreation of the render.
  Fleet: rusty_hatchback, wooden_car, go_kart, street_racer, rocket_car, hover_car, void_racer.
- Seven revision-5 templates currently exist in ReplicatedStorage.CarModels: 42 MeshParts total.
  Counts by order above: 7, 7, 4, 7, 5, 6, 6. Import batches cars_A.fbx and cars_B.fbx uploaded
  with the owner's explicit permission. Blender source and individual FBX/GLB exports retained.
- Triangle totals: Rusty 1365, Wooden 1670, Kart 1052, Street 1494, Rocket 1650,
  Hover 1442, Void 1486; largest material-group mesh 788 triangles.
- More dimensional kart with seat, steering and raised body details; beveled car body edges,
  tapered cabin, windows, bumpers, wheel hubs, mirrors, grille and visible round headlamp faces.
- Restrained toy-paint palette and small rust-colored chips; heavy corrosion textures rejected.
- Imported FBX 100x unit conversion corrected with ScaleTo(0.01), Blender base-centered pivots
  retained; Roblox forward is -Z. Material groups use SmoothPlastic, no external texture required.
- DoubleSided=true preserves glass and lamp polygons whose backfaces were visible in Blender
  but culled in Roblox. Decorative headlights stay visible; no working beams are intended.
- SpotLight headlight implementation was removed after owner clarification; HeadlightConfig
  moved out of active Shared. No Light descendants in the seven current car templates.
- Cosmetic skin code keeps the original physics chassis, seat and race run. Starter appearance
  defaults to Rusty Hatchback without granting ownership or changing its starter multiplier.
  Equipping changes the visible racing car, not the Index icons or physics/economy.
- Earlier templates, UI source and raw imports remain in ServerStorage backups, including
  BeforeEquippedRaceVisuals_1791261685, BeforeDraft05Import_1791263383 and
  Draft05InstallationBackup_1791263467. Do not delete those casually.

GITHUB / LOCAL SAVE
- Repository: https://github.com/AlexNguyen7369/Racer-RNG
- GitHub authentication succeeded. Pushed and verified branch studio/draft05-cars-ui.
- Commit 81cbeafb288a251f02e15e7c1b444e350486e8cc (81cbeaf), author Isaac Li,
  authorized email 527isaac@gmail.com. main was not changed; no PR or game publish performed.
- Branch includes finalized source, UI specs/generator/icons, .blend/FBX/GLB assets, imported
  CarModels and StarterGui snapshots, integration metadata, handoff notes and progress record.
- Checkout: C:/Users/theha/.codex/visualizations/2026/10/05/01a10e5c-0555-7db1-814f-d593c4dd6a8d/Racer-RNG
- Prior local save: C:/Users/theha/OneDrive/Documents/codex racer rng/RacerRNG_Draft05_Imported.rbxl
  Verified 474051 bytes on 2026-10-06. That snapshot predates this context update and retains
  older active scripts; it is not proof that all finalized integration source is currently active.
- Original working folder: C:/Users/theha/OneDrive/Documents/codex racer rng
- See repository docs/DRAFT05_HANDOFF.md. Blender helper output paths are session-local and
  must be adjusted on other computers; use included validated exports where appropriate.

CHECKS / LIMITATIONS / NEXT ACTION
- During Draft05 work, all seven equipment visuals plus starter were checked in live racing:
  shared chassis/seat retained, visual meshes massless/noncolliding, no artificial unlock saved.
  Front-view inspection confirmed beveled Rusty shape, glass and decorative headlamp surfaces.
- GitHub handoff: all 70 Luau sources compiled with Lune; Rojo 7.7.0 built the project.
  Structural checks passed for seven cars / 42 double-sided meshes, decorative-only lamps,
  six ScreenGuis, nested controller/modules and disabled superseded UI scripts; whitespace passed.
- Standard format/lint gate did not pass: StyLua was missing; Selene not run. No claim of a
  current-branch ALL GREEN compatibility stamp. Earlier main's f11ddc2d32ad result is historical.
- Next: reconcile finalized source with Studio, then run new-layout UI, full harness,
  multiplayer and world compatibility before merge/publish. Do not bypass main's gate.
- Existing limitations remain: real DataStore access/testing disabled, static_settle cold-start
  flake, old Circuit/Serpentine rule work, and money upgrade tree phase 2 not implemented here.
- Rebirth is a coming-soon panel. Workshop gameplay exists (phase 1, TODO item 9 below, docs/WORKSHOP_SPEC.md) but the new Stats panel still shows Workshop points as coming soon.

HISTORICAL PROJECT DETAILS AND LOG (PRESERVED BELOW)


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

DASHBOARD (2026-10-05)
CODEX INTEGRATION (2026-10-06): standalone dashboard supports Claude + workspace-filtered Codex sessions,
including Codex main/subagent cards and message/tool timelines. python3 tools/dashboard/client.py reads the
local API and performs requested board edits with --json. Start server.py --no-fetch --no-auto-branch for
board upkeep without automatic GitHub actions. Codex instructions: AGENTS.md; details: tools/dashboard/README.md.
Claude handoff and verification: docs/CODEX_DASHBOARD_HANDOFF.md; branch feature/alex/codex-dashboard.
CLAUDE <-> CODEX BUS (2026-10-06, Claude review of the Codex merge): tools/dashboard/agent_bus.py (git-ignored
.agents/, works without the server): messages between the agents (and the developer), what each SAYS it works on,
and `context --agent X` = the other agent's live activity (model, status, task, last tool, uncommitted files it
changed) + unread mail. Claude gets it via SessionStart/UserPromptSubmit hook; Codex via AGENTS.md. Dashboard:
Agents tab presence + thread + send form; Changes & history label each file/commit with agent + model
(Claude Edit/Write, Codex FileChange, commit trailers Co-Authored-By: Claude / Agent: Codex (<model>)).
NOT VERIFIED: shell-command edits (sed, heredocs) are unattributed ("no agent"); Codex only reads the bus when
it follows AGENTS.md (no automatic Codex hook yet).
Agent dashboard for every collaborator: python3 tools/dashboard/server.py (or /dashboard), http://127.0.0.1:8765.
Shows subagent progress and messages, uncommitted changes, commit history (developer, date, green/local), the compat
gate light, the shared TODO board (tools/dashboard/data/todo.json, Claude keeps it current) and suggested features
(/refresh-suggestions), and every test explained. Not under src/, so it never changes the compat fingerprint.
TEAM & GITHUB (2026-10-06): dashboard tab "Team & branches" + tools/collab.py. New features start on their own branch
feature/<handle>/<slug> from origin/main (dashboard form, moving a TODO card to Doing, /feature, or `python3 tools/collab.py
start "Title"`): an empty "Start feature" commit carries Feature-Title / Initiated-By trailers, it is pushed to GitHub and the
TODO card shows owner + branch. The tab fetches origin every 2 min and shows every unmerged branch: who started it, who
commits on it, systems touched, ahead/behind main, files that overlap your work, real merge conflicts, Rojo/Studio warnings,
handoff notes. People: tools/dashboard/data/team.json (Isaac Li = @issacli). Git actions only from the local machine.

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

RESOLVED 2026-10-05 (compat ALL GREEN f11ddc2d32ad, pushed to main). Was: !!! URGENT (2026-10-02): ROLL ANIMATION PUSHED TO MAIN UNTESTED !!!
The owner asked to commit and push the in-progress roll animation build to main WITHOUT an ALL GREEN /compat-check.
NOTE FOR THE NEXT SESSION (2026-10-03): the push has NOT happened yet. The commits are only on local `initial-import`
(2 ahead of origin; origin/main is still e0f9978). Claude's compat-gate hook blocks pushes to main, so the owner pushes by
hand: `git push --no-verify origin initial-import` then `git push --no-verify origin initial-import:main`. Check with
`git status -sb` / `git log origin/main` before assuming it is on main. The other session (car-gacha-stat-allocation) was
NOT told that Studio is free or that the roll build is committed (that message failed). Do not start implementation until
the owner asks; when they do, resume from the list below.
main is NOT verified. Resume here before any other feature (docs/ROLL_ANIMATION_CONTRACT.md "STATUS" has the same note):
- Built: Shared/RollAnimConfig (new), GachaConfig.IsEmphasized, GachaService (Roll returns 4 values incl. emphasized,
  Announce, SetAutoRoll / RequestSetAutoRoll, AutoRoll attribute, StartAutoRoll(player, roller) waits ROLL_INTERVAL +
  ExtraPause), Client/RollToast rewritten (compact = bare model + "1 in N" under Auto Race, 12% width; enlarged
  RollShowcase card + AutoButton; phases PopIn/Spin/Land/Hold/Exit), Client/RollAnnounce (new, chat), IndexUi panel top =
  RollAnimConfig.PANEL_TOP (138) with MinSize.Y 110, StatsUi panel width UDim2(0.44, -150) capped 300.
- Where the tests left off:
  * harness: roll_anim + gacha + index + data GREEN (`[CARTEST] END pass=6 fail=0`) BEFORE owner decision 6. Afterwards
    test-writer changed roll_anim_constants to the decision-6 numbers (0.12/100/230/66, PANEL_TOP, ENLARGED_WIDTH/MAX):
    NOT re-run. The FULL harness suite has NOT been run with these changes.
  * ui: red run on the old client confirmed (`[UITEST] END pass=10 fail=6`, all missing-client causes). UI round 1 (an
    intermediate design) was cut off by a usage limit and then stopped. UI round 2 (the FINAL design: decisions 4 and 6)
    stalled and was stopped by the owner's exception: NO [UITEST] END line. The ui tests rewritten for decisions 4 and 6
    (UiSpec.Compact, panel_clear_of_compact_roll_*, toast_stays_shown_while_*, compact_is_no_card, ...) have NEVER run.
    Studio was restored (UiTestSetup restore ran) and play stopped.
  * multiplayer-tester, world-tester: never run for this build.
- Next, in order: (1) UI round 2 again (ui-tester, full suite incl. clicks; snapshot once); fix RollToast / panels until
  green; (2) harness FULL suite; (3) /compat-check ALL GREEN; (4) update CLAUDE.md (roll toast no longer above the turbo
  bar; compact roll never hidden by panels) and this file. Owner scope: stop after that compat-check.
- Risks to check first: phone_landscape layout (Index panel only ~120 px tall, Stats panel ~221 px wide), the compact
  roll's hitbox padding with an invisible button, the Legendary card shake vs live-rect checks, emphasized auto-open/close.

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
- 2026-10-08 (/compat-check, fingerprint a42243ab82b4): ALL GREEN. Harness `[CARTEST] END pass=31 fail=0`
  (all configured scenarios plus track:Circuit/DragRace/Hill/Oval/Serpentine). UI `[UITEST] END pass=22 fail=0`.
  Multiplayer, world, and regression live probes were GREEN in the same Play session: server NPC leakage absent,
  owner client NPC correct and non-colliding, Cars self-noncolliding, track geometry anchored/stable, required
  remotes and tracks present, current GUI roots present and legacy GUI roots absent. DataStore persistence remains
  unverified only because Studio reports `StudioAccessToApisNotAllowed`.
- 2026-10-07 (fingerprint dffff4634f2a): full harness `[CARTEST] END pass=28 fail=0` after the odds-colour fix, including
  multiplayer, upgrades, workshop, and track:Circuit/DragRace/Hill/Oval/Serpentine. UI rerun with all documented setups plus
  `lose_event` reached `[UITEST] END pass=8 fail=8`: the real rarity-colour mismatch is fixed, and loser-event setup now passes;
  remaining failures are the headless Studio client contract (Camera.ViewportSize `1,1`, hit probes/contract rectangles/showcase
  scaling) plus the HUD check's stale `$N` expectation against the documented `UNBANKED $N` label. The HUD assertion was
  corrected to accept the documented prefix and rerun without a scenario error; world/regression were not launched because
  the required UI prerequisite was red. Device Simulator was reset to default; no compat stamp recorded.
- 2026-10-07 (fingerprint d16f2b58e6df): corrected the HUD UI assertion to use `UiSpec.Hud.UnbankedPrefix`; the UI rerun
  executes `ui_hud` without error but remains `[UITEST] END pass=8 fail=8` because the Studio client reports a `1,1`
  viewport for hit/contract geometry. A current-fingerprint CarTest rerun was started but did not reach `CarTestResult`
  or an END line after the first static-settle result, so Play was stopped and no new harness result was recorded.
- 2026-10-07 (fingerprint d16f2b58e6df): authoritative rerun completed the full harness with `[CARTEST] END pass=28 fail=0`,
  including all five tracks, workshop, upgrades, NPC, multiplayer, and roll animation. The documented UI setups completed
  with `[UITEST] END pass=9 fail=7`; `ui_hud`, state, rarity-colour, animation, and loser-event checks pass. The seven
  remaining failures are all current-client coordinate/layout checks against Camera.ViewportSize `1,1` (hit probes,
  contract rectangles, and derived layout geometry). Multiplayer/world/regression were not launched because the required
  UI prerequisite was red; no compat stamp recorded.
- 2026-10-07 (fingerprint d16f2b58e6df): independent live checks while Play was running found multiplayer collision-group
  state correct (`Cars` self-collision false), no server NPC leakage, and harness `multiplayer=true`. World checks passed
  anchoring, movement, decor collisions, and unanchored-object rules, but the world suite is RED on two duplicate purple
  `Workspace.Baseplate` parts at `(0,-8,0)` (2048x16x2048), matching the existing manual cleanup task; regression remains
  blocked by the UI prerequisite. No compat stamp recorded.
- 2026-10-07: Edit-mode cleanup removed one duplicate saved Baseplate and aligned the remaining Baseplate to the repo's
  green color; a fresh Play check confirmed exactly one green Baseplate. Studio save confirmation is still pending because
  the available Studio input tool cannot send Edit-mode Ctrl+S; source fingerprint unchanged.
- 2026-10-07 (compatibility gate, fingerprint e6528733fcba): ALL GREEN on the current Studio session. Full harness `[CARTEST] END pass=25 fail=0` (including static_settle, race, flip_recovery, multiplayer, roll_anim, upgrades, workshop, and track:Hill/Oval). UI `[UITEST] END pass=16 fail=0` across the current RacerHud/RollShowcase contract. World static/live probes GREEN: no unanchored or below-floor non-character geometry, decor collision rules correct, both tracks present, `Cars` self-noncolliding; server NPC leakage absent. Multiplayer/regression probes GREEN: required remotes present, client has exactly the current GUI roots and no legacy SpeedHud, server/client smoke checks passed. Regression suite GREEN. No compatibility exceptions or known failures introduced by this run.
- 2026-10-02 (roll animation, INCOMPLETE): harness roll_anim/gacha/index/data `[CARTEST] END pass=6 fail=0` (before decision 6;
  roll_anim_constants changed since, not re-run). ui red run `[UITEST] END pass=10 fail=6` (expected). UI green rounds: NO RESULT
  (cut off / stopped). multiplayer, world: not run. No compat stamp. Pushed to main anyway on the owner's explicit exception.
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

COMPAT CHECK 2026-10-05: ALL GREEN, fingerprint f11ddc2d32ad (pushed to main)
- harness `[CARTEST] END pass=24 fail=0` (roll_anim 65/65 and upgrades 49/49: first full verification of the roll
  animation), ui `[UITEST] END pass=16 fail=0` + 25/25 real-mouse clicks (fly icon now reaches INDEX: 0 px, was 91),
  multiplayer GREEN (live race: client-only NPC on the player's track, lanes -10/+10, owner-only remotes), world GREEN
  (cruise held with RollingDrag 1.0, up-Y >= 0.951, path dev <= 1.59; hidden-avatar torsos read CanCollide=true but stay
  in HiddenAvatar which collides with nothing: accepted per the auto_toggle rule).
- Fixes this check needed: stray Workspace.SpawnLocation removed from the place; harness isolation helpers
  (clearSpawnOfRealPlayers, settleOnFloor); RollToast fly-icon timing; place made to run the repo client (5 repo UI
  scripts re-enabled, Studio-only Racer HUD moved to ServerStorage.RacerHudStash, RollToast restored).
- STILL OPEN: static_settle cold-start flake (~1 in 3, vertical chassis jitter at rest; RollingDrag did not fix it).
- PLACE NOTE: the Racer HUD was built in Studio outside the repo and something kept editing the place during testing.
  Its complete scripts are on git branch studio/racer-hud-ui (drafts/ui/racer-hud/latest). Confirm who builds it before
  the next /compat-check; the place must run exactly the repo client for a check to count.

FINAL SUITE 2026-10-07: fingerprint f60c57e2f089096fbaacc7bed668a658d52c5bc9815c9d02356f45899991a5e6
- Fresh Studio full harness completed `[CARTEST] END pass=28 fail=0`, including all five tracks, multiplayer, roll animation,
  upgrades, and workshop. Static checks also pass: Stylua, Selene, dashboard unit tests (13/13), README sync, Rojo build,
  and `git diff --check`.
- UI suite was not accepted as a green gate: one fresh run ended `[UITEST] END pass=5 fail=11`; several failures were missing
  fixture state (`index_states`, `turbo_next`, `lose_event`, `auto_racing`) and the remaining live layout/emphasis checks need
  a fixture-controlled rerun. Source fix applied: RollToast now sets `IgnoreGuiInset = true`, matching UiSpec and removing the
  observed +4 px toast offset. `/compat-check` remains NOT GREEN because no passing run was recorded.

TODO (in order)
1. Reopen the place, connect Rojo, run the FULL suite; loop (physics-tuner / PathDriver / track-designer) until `[CARTEST] END fail=0`.
   Watch: path deviation <= 5 and up-Y >= 0.9 at MAX_STAT speed, flip_recovery, the lane checks, auto_toggle, the static_settle cold-start flake.
2. When green: update this file, commit, push branch `initial-import`, make it GitHub's default branch (or open a PR).
3. Slack: revoke the exposed xoxp token, install the app with bot scopes chat:write, channels:read, channels:history, groups:read,
   groups:history, users:read, reactions:write; `claude mcp remove slack --scope user`, re-add with the xoxb- token and SLACK_TEAM_ID=T0C5AK11CNB;
   /invite the bot to #racer-dev; then post results and TODOs there after each green run. Claude in Slack also needs the GitHub repo linked.
4. Test real DataStore saving (Studio: Game Settings > Security > Enable Studio Access to API Services). Save the place (Ctrl+S).
5. Bring Circuit and Serpentine up to the track rules; an upgrade shop (nothing raises Speed except driving).
6. STARTED 2026-10-05: money upgrade tree. Implementation design: docs/UPGRADE_TREE_DESIGN.md (modules, ids, hex layout, prices,
   save v4, tests, phases). PHASE 1 GREEN (2026-10-05): Shared/UpgradeConfig (data) + Shared/UpgradeTree (pure rules) implemented;
   harness `upgrades` red run (44 fails, stubs) then green 49/49 (`[CARTEST] END pass=3 fail=0` with track:Hill/Oval), test-writer
   audit OK. Server/UpgradeService is still stubs (not required by Main). Next: phase 2 (server, effects, save v4); the FULL harness
   and /compat-check have NOT been run with these changes.
   PHASE 2 IMPLEMENTED 2026-10-06, NOT VERIFIED (Studio was not connected): Server/UpgradeService (BuyUpgrade RemoteFunction,
   rate limit, gate with SetTrackCount(#chain), BestTrack via RaceService on a won/finished track, TurboCount turbo rolls,
   UpgradesBuyable badge), GachaConfig.Multis(alloc, bonuses) adds tree %, GachaService uses the tree for Luck/Money/Speed multis,
   per-player turbo tier and roll interval (3 s -> 2 s), CarService on-foot WalkSpeed, PlayerData VERSION 4, RollUi bar reads
   TurboCount/TurboEvery, /wipe clears the tree. test-writer wrote the phase 2 tests in the same round; NO red or green run seen.
   Next: full harness in Studio, then phase 3 (UPGRADES button + hex panel + world pad) and /compat-check. Was QUEUED (owner, 2026-10-02): (Luck %, roll speed, Speed %, turbo luck x10/x50/x100/x1000 with more rolls per
   turbo each tier, walkspeed, Money %). Spec + open questions: docs/UPGRADE_TREE_SPEC.md; references in references/upgrade_tree/.
7. IN PROGRESS, PUSHED UNTESTED (see URGENT at the top): roll animation + roll UI (compact card under Auto Race, enlarged reveal, spin reel, rarity
   effects, emphasized rolls = undiscovered and rarer than the 5th-rarest owned car, global chat announce, discovery cutscene).
   Decisions and UI conflicts: docs/ROLL_ANIMATION_SPEC.md; look: the design doc's "Roll animation" section.
8. QUEUED (owner, 2026-10-02): vehicle skins: a ride's look is any model (a car now, maybe a dragon later) welded on a shared
   invisible physics body; physics and tests never depend on the model. docs/VEHICLE_SKINS_SPEC.md. Car model drafts follow it
   Rusty Hatchback Blender draft DONE 2026-10-02 (drafts/cars/rusty-hatchback, CC0 "Car Hatchback" by Kay Lousberg, rusty
   restyle, Wheel_FL/FR/RL/RR). 2026-10-05: baked + exported headless (blender/scenes/export_rusty_hatchback.py -> blender/exports/rusty_hatchback/
   RustyHatchback.fbx, 6.6 studs long). DONE 2026-10-06: Isaac's Draft05 import was used instead of the textured
   blender/exports FBX (owner's choice): ReplicatedStorage.CarModels = assets/studio/CarModels.rbxm (Rojo), Cars/rusty_hatchback.luau
   Model = "rusty_hatchback"; live check: rolls clone CarModels.rusty_hatchback into the RollToast viewport, "?" hidden. 2026-10-06: the other six Cars/*.luau also set Model = their id (all seven CarModels templates wired). Blender MCP add-on updated to protocol 13; Poly Pizza on.
9. STARTED 2026-10-06 (owner brief): Mechanical Workshop. Spec: docs/WORKSHOP_SPEC.md. 7 plots in the spawn area, max 7 players
   (server size set by hand: dashboard "Needs you"). The spawn floor grew to (24,-188)..(252,44) = 228 x 232; the old floor is
   SpawnArea.HUB_MIN/MAX and keeps the spawn (same position). Shared/WorkshopConfig (plots, zone 32x12x32, BASE_RATE 1/s, levels),
   Shared/Workshop (pure: PlotCFrame, ZoneBounds, InZone, FreePlot, CleanLevel, LevelMulti, Rate), Shared/WorkshopBuilder (plot +
   level-1 workshop, all anchored, open front toward the hub), Server/WorkshopService (Workspace.Workshops.Plot_1..7, lowest free plot
   on join after the save loads, freed on leave, server zone check every 0.5 s pays BASE_RATE x SpeedMulti x W x Workshop points /
   (1 + stat/GAIN_SOFT)). Player attributes Plot, WorkshopLevel (saved, v4), InWorkshop, WorkshopRate. NOT VERIFIED (no Studio run).
   Open (owner): BASE_RATE, level prices, offline earnings.

KNOWN ISSUES / NOT VERIFIED
- 2026-10-06 /compat-check (upgrade tree phase 2 + workshop phase 1), NOT GREEN, main not cleared:
  round 1 (0354a64af31e): harness `[CARTEST] END pass=23 fail=2` (upgrades: badge did not follow Money for fake players,
  walkspeed_after_buy was a test bug (tier IV gated at BestTrack 0); workshop: Rate sign empty until in the zone). Fixed.
  round 2 (96313e6fc99c): harness `[CARTEST] END pass=24 fail=1`: upgrades 96/96, workshop 55/55, every car/race/track
  scenario green; spawn_area respawn_on_foot_standing_height 5.034 (band 1.5..5), green in round 1, avatar rests at ~3.8
  afterwards: probably measured while still settling (unproven flake). ui / multiplayer / world suites NOT run (stopped by
  the owner). The phase 2 / workshop tests were never seen red (written while the implementation was being written).
  round 3 (8c0a2290ce41, after the merge of Isaac's Draft05 cars + Racer UI): harness `[CARTEST] END pass=24 fail=1` (spawn_area
  green with the stricter settle wait; only gacha catalog_matches_design_doc failed: test still required Model = nil; test now
  accepts a Model that exists in ReplicatedStorage.CarModels and equals the Id; plus new upgrades_buy_isolated_between_players;
  neither re-run yet). world GREEN (walk spawn -> workshop zone pays, StartPad starts a race, all plots anchored, no overlaps).
  multiplayer RED (no code failure: no live race to inspect, starting one from a tool was blocked by permissions). ui RED: the
  UI tests (UiSpec/UiScenarios) still describe the old SpeedHud/AutoRaceButton/IndexUi/StatsUi/RollUi, which the Racer UI
  replaced (those scripts are disabled); all 25 clicks fail on missing targets; Racer HUD puts Speed at bottom centre (spec:
  left) and the showcase card does not match docs/ROLL_ANIMATION_CONTRACT.md. Needs an owner decision + ui-test-writer.
- 2026-10-01: another session is building gacha/index (scenarios gacha, index in TestConfig, red) and shares the same Studio; runs
  collide. Nothing can be ALL GREEN (so nothing can go to main) until gacha/index are implemented and one run has Studio to itself.
- NPC client view and LoserScreen are untested live (ui-tester / multiplayer-tester not run yet).
- Two sessions edited the project in parallel (lane work and the toggle / implicit solver). Only one session should run the physics tests at a time.
- Toggle cases the server harness cannot test (real CharacterAdded / PlayerRemoving / remote cooldown) are handled in code, untested.
- Whether the half-size car still flips at speed is unknown until the full run (two fixes exist: CarConfig damping and the implicit solver).
- static_settle failed intermittently on cold starts (0.53-0.78 vs limit 0.5). Cause (physics-tuner, 2026-10-05): leftover forward/back creep
  after the landing pitch kick, damped only by RollingDrag 0.15/s (DampingRatio is 0.6 on purpose since the half-size retune; the old
  "raised to 1.0" note was stale). Fix 2026-10-05: RollingDrag 1.0 (only acts with throttle 0 and brake 0). Being verified in /compat-check.
- Real DataStore saving untested (Studio blocks it by default). Only a stubbed store is tested.
- Circuit and Serpentine do not follow the track rules.
- Visuals (checkpoint, pad, HUD) are checked by numbers and live reads, not by eye.

HOW TO RUN TESTS
Play in Studio, then ReplicatedStorage:SetAttribute("CarTestRun", true) (or TestConfig.Enabled = true).
Read "[CARTEST] ..." lines and "[CARTEST] END pass=N fail=N". A full run takes 10-30 minutes real time.
]=]

return {
	Updated = "2026-10-07",
	Read = "Open this script and read the comment block above.",
}
