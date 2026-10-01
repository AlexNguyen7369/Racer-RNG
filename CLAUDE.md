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
- Shared Claude Code tooling is in the repo: agents in `.claude/agents/`, slash commands in `.claude/commands/` (`/build-track`, `/car-loop`, `/compat-check`, `/progress-tracker`, `/system-design-brainstorm`), hooks in `.claude/hooks/` wired by `.claude/settings.json`. Personal overrides go in `.claude/settings.local.json` (git-ignored).
- Needs: Roblox Studio with the Roblox Studio MCP and the Rojo plugin (`rojo serve`), `stylua`, `selene`, `python3`; the Blender MCP for art work.
- The main-branch gate: Claude Code runs `git config core.hooksPath .githooks` at session start; without Claude Code run it once by hand. Then `.githooks/pre-push` refuses any push to `main` unless `/compat-check` was ALL GREEN for exactly that code (`tools/compat.py`, stamp in the git-ignored `.compat/`, so every collaborator runs the check on their own machine).
- One Studio, one test run: never run the harness while someone else's session uses the same Studio.

## Car system
- `Shared/CarConfig` is the one place to change handling, size and colour.
- `Shared/CarFactory` builds the blocky baby-blue car procedurally (forward is -Z, wheels are `Wheel_FL/FR/RL/RR`).
- `Shared/CarPhysics` is a raycast-suspension model, shared by the player (`Client/CarController`) and the test harness.
- `Server/CarService` replaces the player's avatar with the car: the character is hidden and seated in the car's `VehicleSeat`. Keep the Humanoid, since Roblox needs it for camera and respawn. `Server/RaceService` then takes over the car and drives it (auto race, see below).
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

### Auto race, Speed stat and HUD
- The player does not steer. `Server/RaceService` drives each player's car with the real `CarPhysics` on the server, steered by `Shared/PathDriver` along the whole chain (Track 1, then 2, ...) on each track's `RacePath`, and loops back to Track 1 after the last finish. The client `CarController` does nothing for an `AutoRace` car.
- **Speed stat (`leaderstats.Speed`, a `NumberValue`, starts at 0):** while the car drives, the server adds `RaceConfig.GainPerSecond(stat, actualSpeed) * dt` to it. The gain is proportional to the ACTUAL speed and shrinks as the stat grows (diminishing returns). It is committed every `RaceService.COMMIT_INTERVAL` seconds.
- **Cruise speed** = `RaceConfig.SpeedFor(stat)`: `BASE_SPEED` at 0, approaching `MAX_SPEED` (below the car's `TopSpeed`) with diminishing returns (`HALF_STAT` is the stat at the halfway point). The driver holds it on straights and slopes and only slows where corner grip requires it. The run follows the stat as it grows.
- **HUD:** `Client/SpeedHud` shows the Speed stat on the LEFT of the screen and counts up smoothly as it grows (formatting and smoothing live in `Shared/HudFormat`).
- `Server/PlayerData` saves `Money` and `Speed` in a DataStore and loads them on join; it never writes before the load finished. The server owns every stat; clients only see `leaderstats`.
- **Car size:** the car is about half its original size (`CarConfig`: body, wheels, suspension and mounts scaled together, tuned by `physics-tuner`); speeds and `PhysicsTargets` are unchanged.
- **Stability rules (tests enforce them):** the car must never flip or noticeably tilt, by any means: on every race and every bot lap the body's up-vector Y never drops below `PhysicsTargets.lap.MinUpYStrict` (0.9) outside loops, at normal AND at maximum stat speed (`MAX_STAT`). `RaceService` also watches for a flipped car (up-vector Y below `FLIP_UP_Y` for `FLIP_SECONDS`) and puts it upright back on the path. The car must also stick to its route from the start to the last checkpoint: distance to the path never exceeds `PhysicsTargets.race.MaxPathDeviation` studs.
- Any track change must keep: the chain drivable at the stat speed with 0 flips / 0 off-track, the pad paid exactly once per pass, and the join between tracks smooth.

## Test harness
`src/server/CarTest/`: scenarios `static_settle`, `accel`, `brake`, `skidpad`, `car_size`, `chain`, `money`, `race`, `economy`, `data`, `hud`, `flip_recovery`, `lap:<Track>`, `track:<Track>`. Limits live in `Shared/PhysicsTargets`.
Output is `[CARTEST] {json}` lines and `[CARTEST] END pass=N fail=N` in the Studio console. Trigger with `ReplicatedStorage:SetAttribute("CarTestRun", true)` during play, or set `Enabled = true` in `CarTest/TestConfig.luau`.

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
