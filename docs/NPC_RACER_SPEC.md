# NPC racer: design spec (contract for tests and implementation)

User brief (2026-10-01):
- One NPC racer per track. For now it is the starter car (`CarFactory`) in a different colour per track: red on
  Track 1, a different colour on every other track. The model must be swappable per track later.
- The NPC drives in the LEFT lane (road centre line shifted `TrackBuilder.LANE_OFFSET` to the LEFT); the player
  keeps the right-hand lane.
- The NPC race starts automatically every time the player starts a track: spawning at Track 1's start, or
  leaving the previous track's checkpoint (finish) onto the next track.
- The NPC is per player: it races only against its own player. Other players never see it (it exists only on the
  owning client, never in the server Workspace).
- NPC speeds rise per track: very easy on Track 1, increasing on every later track.
- A numbers game: if the NPC reaches the finish of the track before the player, the player LOSES. The race still
  plays out (the player's car keeps driving to the finish), then the player sees a loser screen and is sent back
  to the spawn point (start of Track 1) where the Track 1 race starts again.
- Money: a track's checkpoint money (its WinPad `Cash`) is paid only when the player WINS that track. Losing a
  track pays nothing for it; money from checkpoints already won is kept.
- Floating text above each NPC, proximity based (finite `MaxDistance`), editable. Default `track01_NPC`,
  `track02_NPC`, ...
- Players pass through each other on the track.

## Modules and API

### `src/shared/NpcConfig.luau` (editable knobs)
- `BASE_SPEED` (studs/s, Track 1, very easy, below `RaceConfig.BASE_SPEED`): 20
- `SPEED_STEP` (studs/s added per track number): 12
- `LABEL_DISTANCE` (studs, BillboardGui `MaxDistance`): 60
- `LOSE_SCREEN_SECONDS`: 3
- `LABEL_FORMAT`: `"track%02d_NPC"`
- `Tracks = { [number] = { Color?, Speed?, Label?, Model? } }` per-track overrides. Track 1 `Color` is red.
- `NpcConfig.For(number)` -> `{ Number, Speed, Color, Label, Model }`
  - `Speed` = override or `BASE_SPEED + SPEED_STEP * (number - 1)`; strictly increasing with the number.
  - `Color` = override or a palette entry; Track 1 is red (R high, G and B low); the colours of tracks 1..5 are all
    different and none equals the player's `CarConfig.Colors.Body`.
  - `Label` = override or `LABEL_FORMAT:format(number)` (Track 1 -> `track01_NPC`).
  - `Model` = override name of a Model under `ReplicatedStorage.NpcModels`, or nil (= starter car in `Color`).

### `src/shared/NpcRacer.luau` (pure maths + model builder, used by server and client)
- `NpcRacer.LanePath(entry)` -> `{ Waypoints, Curvature, Length }` in WORLD space for a chain entry
  `{ Layout, Origin }`: `TrackBuilder.RacePath(layout, -TrackBuilder.LANE_OFFSET)` (the left lane).
  `TrackBuilder.RacePath(layout, offset)` gains an optional signed offset (positive = right, default `LANE_OFFSET`,
  so existing behaviour is unchanged).
- `NpcRacer.Profile(path, speed)` -> `{ Times, TotalTime, Length }`: the NPC holds `speed`, slowing only where
  corner grip requires (same limit as `PathDriver`: `sqrt(Mu * g * 0.55 / curvature)`), never faster than `speed`.
  `TotalTime` is strictly decreasing in `speed`.
- `NpcRacer.PoseAt(path, profile, t)` -> CFrame on the lane at time `t` (clamped to [0, TotalTime]), at
  `CarConfig.RestHeight` above the road, facing along the path.
- `NpcRacer.ChainEntries()` -> `{ { Layout, Origin, Number }, ... }` computed purely from `TrackRegistry.Chain()`
  (same origins as `Main` builds), so the client can rebuild the lanes without the track models.
- `NpcRacer.BuildModel(info)` -> Model named `"NPC_" .. info.Label`, attribute `IsNpc = true`, attribute
  `TrackNumber`. Starter car body in `info.Color` (or a clone of `ReplicatedStorage.NpcModels[info.Model]`). Every
  BasePart: `Anchored`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`. A `BillboardGui` named
  `NpcLabel` with a `TextLabel` whose `Text == info.Label` and `MaxDistance == NpcConfig.LABEL_DISTANCE`.
  The builder does not parent it; the client parents it to its own Workspace.

### `PathDriver.Chain(entries)`
Also returns `StartIndices[i]` and `FinishIndices[i]` (route waypoint index of each track's first / last point).

### `RaceService`
- `RaceService.BuildRoute(entries)` also returns `route.Tracks[i] = { Number, StartIndex, FinishIndex, PadIndex,
  Pad, Npc = { Config, Path, Profile } }`.
- `RaceService.NewRun(car, route, player, options)`; NPC racing is ON when `options.Npc == true`
  (`RaceService.Attach` passes it; existing tests that do not pass it keep the old behaviour, pads paid on pass).
  Test-only options: `NpcSpeeds = { [number] = speed }` overrides `NpcConfig.For(n).Speed`; `LoseScreenSeconds`;
  `OnRaceEvent = function(event)` receives every event (also sent to a real Player with
  `Remotes.NpcRace:FireClient(player, event)`, never `FireAllClients`).
- Events:
  - `{ Type = "Start", Track = n, ServerStart = workspace:GetServerTimeNow(), Speed, Color, Label, Model }`, when the
    player starts track n (spawn on Track 1, after crossing track n-1's finish, after a reset).
  - `{ Type = "Result", Track = n, Result = "Win" | "Lose", PlayerTime, NpcTime, Paid }` when the player's car
    reaches track n's finish (`FinishIndex`). Win if the player's time on the track < the NPC's `TotalTime`.
  - `{ Type = "Reset", Track = 1 }` after a loss: after `LoseScreenSeconds` the car is put back at the start of
    Track 1 (upright, facing along the path) and a new Track 1 `Start` follows.
- Run fields: `run.RaceTrack` (current track number), `run.Results` (list of Result events), `run.Wins`,
  `run.Losses`, `run.Resets`, plus all existing fields (`PaidTotal`, `Payouts`, `MinUpY`, `MaxPathDeviation`, ...).
- Money in NPC mode: track n's pad pays (`MoneyService.Collect`) exactly once, at its finish, only on a Win.
  A Lose pays nothing for that track; earlier wins stay paid.
- After winning the LAST track the car loops back to Track 1 (as today) and a new Track 1 race starts.
- The run's stability rules are unchanged: no flips/tilt past `MinUpYStrict`, stays on the path.

### Client
- `src/client/NpcRacerView.client.luau`: on `Start` builds the NPC with `NpcRacer.BuildModel` into the client's
  own Workspace (removing the previous one) and moves it each frame with `PoseAt(GetServerTimeNow() - ServerStart)`.
  On `Result Lose` shows a ScreenGui `LoserScreen` for `LOSE_SCREEN_SECONDS`. On `Reset` removes the NPC.

### Multiplayer
- The server Workspace never contains a model with `IsNpc` (so nothing replicates to other players).
- Player cars stay in the `Cars` collision group, which does not collide with itself: two players' cars on the
  same spot pass through each other and both keep racing on their paths without flips.
- Each player's run has its own NPC race state; two players racing at once get only their own events.
