# Idle Vehicle Simulator (Roblox)

Design spec: `Idle Vehicle Simulator — Game Design Requirements.pdf`. Car art pipeline: `CAR_MODELING_WORKFLOW.md`.

## Project layout (Rojo)
`default.project.json` maps files to the DataModel:

| Folder | Lives in Studio at |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |

Non-Roblox folders: `assets/`, `blender/`, `references/` (car art), `tests/`.
Edit the `.luau` files on disk; Rojo syncs them into Studio. Do not edit synced scripts inside Studio.

## Running
```
rojo serve            # from the project root; then click Connect in Studio's Rojo plugin
stylua src            # format
selene src            # lint
```

## Collaborator setup (once per clone)
- Shared Claude Code tooling is in the repo: agents in `.claude/agents/`, slash commands in `.claude/commands/` (`/build-track`, `/car-loop`, `/compat-check`, `/dashboard`, `/progress-tracker`, `/refresh-suggestions`, `/system-design-brainstorm`), hooks in `.claude/hooks/` wired by `.claude/settings.json`. Personal overrides go in `.claude/settings.local.json` (git-ignored).
- Needs: Roblox Studio with the Roblox Studio MCP and the Rojo plugin (`rojo serve`), `stylua`, `selene`, `python3`; the Blender MCP for art work.
- The main-branch gate: Claude Code runs `git config core.hooksPath .githooks` at session start; without Claude Code run it once by hand. Then `.githooks/pre-push` refuses any push to `main` unless `/compat-check` was ALL GREEN for exactly that code (`tools/compat.py`, stamp in the git-ignored `.compat/`, so every collaborator runs the check on their own machine).
- Agent dashboard: `python3 tools/dashboard/server.py` (or `/dashboard`), http://127.0.0.1:8765. Subagent progress and messages, changes, commit history, the compat gate light, the shared TODO board, suggested features and every test explained. `--lan` lets teammates view it. Details: `tools/dashboard/README.md`.
- One Studio, one test run: never run the harness while someone else's session uses the same Studio.

## Car system
- `Shared/CarConfig` is the one place to change handling, size and colour.
- `Shared/CarFactory` builds the blocky baby-blue car procedurally (forward is -Z, wheels are `Wheel_FL/FR/RL/RR`).
- `Shared/CarPhysics` is a raycast-suspension model, shared by the player (`Client/CarController`) and the test harness.
- `Server/CarService` replaces the player's avatar with the car when auto racing starts: the character is hidden and seated in the car's `VehicleSeat`. Keep the Humanoid, since Roblox needs it for camera and respawn. `Server/RaceService` then takes over the car and drives it (auto race, see below).

### Spawn area (spec: `docs/SPAWN_AND_ROLLS_SPEC.md`)
- `Shared/SpawnArea` (built by `Main` after the chain): a purple 160 x 144 floor to the RIGHT of Track 1's start straight (Track 1's finish and Track 2 pass behind the start line), the game's only `SpawnLocation`, and the green `StartPad` (tag `StartPad`, "RACE" sign) right behind the start line joining the area to the road. Never overlaps any track.
- Players join and respawn ON FOOT there (`CarService.OnCharacter`); "Stop Auto" always sends them back (`CarService.WalkSpawnCFrame` = `SpawnArea.WalkCFrame`). Walking onto the StartPad starts auto racing (`CarService.PadTouched`, cooldown `SpawnArea.START_COOLDOWN` after any start/stop); the "Auto Race" button still works too.
- The car is auto-raced (no player steering). The old manual controls (W/S, A/D, Space, R via `VehicleSeat`) still exist in `Client/CarController` for cars without the `AutoRace` attribute.

## Tracks
One file per track in `src/shared/Tracks/`, auto-loaded by `TrackRegistry`. See `TrackBuilder.luau` for the spec format and `TrackValidator.luau` for the rules (min radius, closure, no overlap).

### Track rules (every track, enforced by `TrackValidator` + track tests)
1. **Numbered ladder:** each spec has `Number = N` (1, 2, 3...). Tracks are chained in `Number` order.
2. **Separate start and finish:** tracks are point-to-point (`Closed = false`). The finish is never the start: the two points are at least 2 road-widths apart and the road never touches itself.
3. **Finish is the connector:** the last segment is a level `Straight` (>= 40 studs) and the first segment is a `Straight` (>= 40). Track N+1 is built with its origin at track N's finish pose (`TrackBuilder.EndCFrame`), so its Start sits on N's finish. Chained tracks must not overlap each other.
4. **Wide checkpoint area at the finish:** `Checkpoint` model in the track: finish line and a `CheckpointArea` that is WIDER than the road (an apron of `CHECKPOINT_APRON` studs on each side; the track walls are opened there). It covers the last `CHECKPOINT_LENGTH` studs and ends at the finish pose.
5. **Winnings pad off to the left, car in the right-hand lane:** the `WinPad` (small, yellow, `Neon`, non-colliding, tagged `WinPad`, attribute `Cash`) sits on the LEFT apron, `PAD_LEFT_OFFSET` studs left of the road centre, beside the racing line, NOT on it. The race path (`TrackBuilder.RacePath`) is the road centre line shifted `LANE_OFFSET` (10 studs, a quarter of the road width) to the RIGHT, so the car drives in a right-hand lane, not dead centre; it also records `PadIndex`, the waypoint abeam of the pad.
6. **Winnings are money, scaled by the track number:** `Cash = Number * CASH_PER_TRACK` (`TrackBuilder.CashFor`). A `BillboardGui` on the pad shows `$Cash`, and it has a finite `MaxDistance` (`TrackBuilder.WIN_TEXT_DISTANCE` = 60 studs) so it only shows when the player is within 60 studs.
7. **Placement:** the chain is built 1 stud above the baseplate (`TRACK_LIFT`) so road never z-fights with it.
8. **The pad pays the driver:** when the auto-racing car passes the pad (its path index reaches `PadIndex`, checked server-side in `RaceService`) `MoneyService.Collect` adds the pad's `Cash` to `leaderstats.Money` (server decides the amount, once per pass, per-player cooldown `MoneyService.COOLDOWN`). The car never has to touch the pad.

### NPC racers (spec: `docs/NPC_RACER_SPEC.md`)
- Every track has an NPC (`Shared/NpcConfig`: speed, colour, label, model per track number; Track 1 red and very easy, faster on every later track). For now it is the starter car in the track's colour; set `Tracks[n].Model` to a Model under `ReplicatedStorage.NpcModels` to swap it.
- The NPC drives the LEFT lane (`TrackBuilder.RacePath(layout, -LANE_OFFSET)`) and is pure maths (`Shared/NpcRacer`: `LanePath`, `Profile`, `PoseAt`), so its track time is known when the race starts.
- A race starts every time the player starts a track (spawn on Track 1, or crossing the previous finish). `RaceService` (NPC mode, `options.Npc`) decides it: the player wins if their car reaches the finish before the NPC's time. A loss plays out to the finish, then the loser screen shows and after `NpcConfig.LOSE_SCREEN_SECONDS` the car goes back to the start of Track 1.
- **Money in NPC mode (banked):** winning a track adds its pad's value (`MoneyService.Quote` = Cash x Money multi) to the run's bank (`run.Unbanked`, player attribute `Unbanked`, shown as UNBANKED in the HUD); nothing is paid at the finish. A loss empties the bank. `run:CashOut()` pays the bank into `leaderstats.Money`; `run:Destroy()` cashes out, so Stop, death and leaving all pay it. `Result` events carry `Banked` and `Unbanked`. (Rule 8 above still describes runs without NPC, e.g. the `race` test.)
- Per player: race events go only to the owner (`Remotes.NpcRace:FireClient`), and the NPC car exists only in that client's Workspace (`Client/NpcRacerView`), never on the server. Its `NpcLabel` text (`track01_NPC`, ...) has `MaxDistance = NpcConfig.LABEL_DISTANCE`. Player cars are in the `Cars` collision group and pass through each other; NPC parts never collide.
- Tests: `npc` and `multiplayer` scenarios; the `multiplayer-tester` subagent also checks the live client/server perspective.

### Auto race, Speed stat and HUD
- The player does not steer. `Server/RaceService` drives each player's car with the real `CarPhysics` on the server, steered by `Shared/PathDriver` along the whole chain (Track 1, then 2, ...) on each track's `RacePath`, and loops back to Track 1 after the last finish. The client `CarController` does nothing for an `AutoRace` car.
- **Speed stat (`leaderstats.Speed`, a `NumberValue`, starts at 0):** while the car drives, the server adds `RaceConfig.GainPerSecond(stat, actualSpeed) * dt` to it. The gain is proportional to the ACTUAL speed and shrinks as the stat grows (diminishing returns). It is committed every `RaceService.COMMIT_INTERVAL` seconds.
- **Cruise speed** = `RaceConfig.SpeedFor(stat)`: `BASE_SPEED` at 0, approaching `MAX_SPEED` (below the car's `TopSpeed`) with diminishing returns (`HALF_STAT` is the stat at the halfway point). The driver holds it on straights and slopes and only slows where corner grip requires it. The run follows the stat as it grows.
- **HUD:** `Client/SpeedHud` shows the Speed stat on the LEFT of the screen and counts up smoothly as it grows (formatting and smoothing live in `Shared/HudFormat`).
- `Server/PlayerData` saves `Money` and `Speed` in a DataStore and loads them on join; it never writes before the load finished. The server owns every stat; clients only see `leaderstats`.
- **Car size:** the car is about half its original size (`CarConfig`: body, wheels, suspension and mounts scaled together, tuned by `physics-tuner`); speeds and `PhysicsTargets` are unchanged.
- **Stability rules (tests enforce them):** the car must never flip or noticeably tilt, by any means: on every race and every bot lap the body's up-vector Y never drops below `PhysicsTargets.lap.MinUpYStrict` (0.9) outside loops, at normal AND at maximum stat speed (`MAX_STAT`). `RaceService` also watches for a flipped car (up-vector Y below `FLIP_UP_Y` for `FLIP_SECONDS`) and puts it upright back on the path. The car must also stick to its route from the start to the last checkpoint: distance to the path never exceeds `PhysicsTargets.race.MaxPathDeviation` studs.
- Any track change must keep: the chain drivable at the stat speed with 0 flips / 0 off-track, the pad paid exactly once per pass, and the join between tracks smooth.

### Car gacha, index and stat points
- Catalog: one file per car in `src/shared/Cars/`, auto-loaded by `Shared/CarCatalog` (`STARTER_ID = "starter"` is built in, not rollable, not in the index). A car's `Id` is a permanent save key: never rename or reuse one. `Model = nil` shows the "?" placeholder.
- Rules and numbers live in `Shared/GachaConfig`: free auto-roll every `ROLL_INTERVAL` (3 s); a roll checks cars rarest first, each hits with `min(1, luck / Chance)`, else the catch-all common. **Turbo luck:** every `TURBO_EVERY` (10)th roll uses `Luck * TURBO_LUCK` (5) (`IsTurbo`, `TurboProgress`, derived from the saved `Rolls`); `RollResult` sends `(id, isNew, turboMulti)`.
- Roll UI: `Client/RollUi` is the bottom-centre `TurboBar` (fills per roll, "TURBO x5!" pop on a turbo roll). `Client/RollToast`: the roll toast above it is a button; clicking it opens the `RollShowcase` overlay (dimmed + `Lighting.RollShowcaseBlur`) with one big card showing every roll live: the car (`ReplicatedStorage.CarModels[spec.Model]` in a ViewportFrame, "?" until it has one), odds, name, rarity, speed multi, NEW / TURBO badges. Clicking anywhere off the card (`Backdrop`) closes it.
- `Server/GachaService` owns it: `player.GachaData` (StringValue per owned car; discovering a car = owning it, no duplicate counts) and player attributes `EquippedCar`, `Rolls`, `StatPoints` (free), `Alloc_<Stat>`. Earned points are derived from the index, never saved; only allocations are. Remotes `EquipCar`, `AllocateStat` (validated, rate-limited), `RollResult` (server -> owner).
- Effects: Speed-stat gain x `GachaService.SpeedMulti` (equipped car x Speed points) in `RaceService`; pad payouts x `MoneyMulti` in `MoneyService.Collect`; roll luck = `Luck`. Cruise speed and car physics never use the multis (stability tests unaffected). Workshop points are stored but do nothing until the workshop exists.
- Save (`PlayerData` VERSION 3): `Cars = { id, ... }` (sorted owned ids; an early `{ [id] = count }` map still loads), `Equipped`, `Rolls`, `StatAlloc`. Unknown ids are kept; over-allocation is trimmed on load.

## Test harness
`src/server/CarTest/`: scenarios `static_settle`, `accel`, `brake`, `skidpad`, `car_size`, `chain`, `money`, `race`, `economy`, `data`, `hud`, `flip_recovery`, `auto_toggle`, `spawn_area`, `npc`, `bank`, `multiplayer`, `gacha`, `index`, `admin`, `lap:<Track>`, `track:<Track>`. Limits live in `Shared/PhysicsTargets`.
Output is `[CARTEST] {json}` lines and `[CARTEST] END pass=N fail=N` in the Studio console. Trigger with `ReplicatedStorage:SetAttribute("CarTestRun", true)` during play, or set `Enabled = true` in `CarTest/TestConfig.luau`.

UI tests: `src/client/UiTest/` (written only by `ui-test-writer`; `UiSpec` lists every ScreenGui, button, allowed overlay and the clicks). Set `ReplicatedStorage` attribute `UiTestRun` false then true on the server during play; output is `[UITEST] {json}` and `[UITEST] END pass=N fail=N` (also LocalPlayer attribute `UiTestResult`). Clicks a script can not fire are done by `ui-tester` with mouse input (`UiTestClick` protocol in `UiSpec`). Rules they enforce: no two reachable buttons/panels overlap at any tested viewport (incl. phone landscape), hitboxes stay inside their parent and near their visuals, buttons do exactly what they show. The Index and Stats panels are mutually exclusive (`Client/PanelSwitch`), open below the Auto Race button and end above the bottom turbo bar; the roll toast sits above the turbo bar and hides while a panel or the roll showcase is open.

### Admin chat commands (spec: `docs/ADMIN_COMMANDS_SPEC.md`)
`Server/AdminService` (+ `Server/AdminConfig`: `UserIds`, `GROUP_MIN_RANK`, `ALLOW_IN_STUDIO`, `MAX_ROLLS`) runs `/help /money /addmoney /speed /addspeed /give /equip /roll /wipe /tp` from chat (TextChatCommands in `TextChatService.AdminCommands`). Server-only: non-admins change nothing; replies go to the sender only (`Remotes.AdminMessage`, shown by `Client/AdminChat`). `/tp n` uses `run:JumpToTrack(n)` in `RaceService` (earlier pads count as paid; NPC race restarts on that track).

## Subagent loop (test-first, mandatory for every track)
`/build-track <name> <brief>` runs the loop in `.claude/commands/build-track.md`. Any track created or changed MUST go through it:
1. `test-writer` writes `CarTest/TrackTests/<Track>.luau` first; `physics-tester` must see it fail (red).
2. Repeat: `track-designer` / `physics-tuner` implement -> `test-writer` audits that no test was loosened -> `physics-tester` runs the FULL suite.
3. Exit only on `[CARTEST] END fail=0`. No round cap; three identical rounds in a row means change strategy, then escalate to the user.
`/car-loop <goal>` is the same loop for car-physics work. A hook (`.claude/hooks/track-changed.py`) reminds Claude of this whenever a track or track test file is written.
Only `test-writer` edits tests. Never change `PhysicsTargets.luau` to make a test pass; those are feel decisions for the owner.

## Drafts
`drafts/` holds rough Blender drafts of assets for full implementation later (`drafts/tracks/`, `drafts/cars/`, `drafts/props/`, `drafts/environments/`, `drafts/ui/`). One folder per asset with a `DRAFT.md` (copy `drafts/_template/DRAFT.md`). Drafts are references, not shipped assets. Scale: 1 Blender unit = 1 stud.

## Context file (always keep current)
`context/ProjectContext.luau` is a small ModuleScript that Rojo syncs into Studio's Explorer at `ServerScriptService > ProjectContext`. It holds what collaborators need: where things live, the rules, a change log, the latest test results and known issues. Claude MUST update it at the end of every loop (after a full run: add the dated result, what changed, what is unverified) and whenever a rule, file or number in it changes. Edit the file on disk, never in Studio.

## Dashboard TODO (always keep current)
`tools/dashboard/data/todo.json` is the team's TODO board (statuses `doing`, `next`, `backlog`, `done`). Claude updates it in the same step as `ProjectContext.luau`: at the end of every loop move finished items to `done` (with `done` date), the next one to `doing`, and add new follow-ups or known issues. Never edit or remove a suggestion someone marked `added` or `dismissed` in `data/suggestions.json`. Whenever Claude needs the developer to do something by hand (Studio imports, settings, accounts, decisions), it adds it to `data/manual.json` (the dashboard's "Needs you" tab) with `why`, `blocks`, `when` and numbered `steps`, and marks it `done` once it has verified the result. A new test scenario needs an entry in `data/tests_explained.json`.
`README.md`'s TODO section (between the `TODO:START`/`TODO:END` markers) is generated from `todo.json` by `tools/readme_sync.py`; the dashboard, a PostToolUse hook and `.githooks/pre-commit` run it, so never edit that block by hand. When a feature ships, also update the hand-written "Features implemented" section of `README.md`.

## Conventions
- `.luau` files, tabs, `--!nonstrict` header. Server decides every number that matters; the client only displays (see the design doc's technical section).
- Studio work goes through the Roblox Studio MCP; Blender work through the Blender MCP.

## Progress tracking (required after every commit or push)
After making a commit or push in this repo, invoke the global
`progress-tracker` skill (also in this repo as `/progress-tracker`) before touching `current_progress.md` — it is
the authoritative, strict spec for how that file is created (if
missing) and updated (Completed appends, What's Next replacement,
formatting, attribution). Do not improvise the update from memory or
from this summary; invoke the skill every time this rule fires.
