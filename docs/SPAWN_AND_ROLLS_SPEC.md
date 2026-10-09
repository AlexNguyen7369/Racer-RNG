# Spawn area, banked winnings, turbo luck and the roll feed

Owner's brief (2026-10-01):
- Create a spawn area, relatively large and purple for now, close to Track 1 and connected to its start, so players
  can walk onto the start platform to start auto racing.
- It is the spawn point (join and respawn) and where Stop always sends the player, out of the race.
- Stopping pays the winnings of the checkpoints cleared in this run (banked, see below).
- An "Unbanked" HUD line.
- A turbo luck bar: every X auto rolls one roll gets multiplied luck. The bar fills one step per roll and plays a short
  animation on every turbo roll.
- Clicking the roll toast at the bottom enlarges it into a showcase of each roll as it happens (like RNG Heroes):
  the car (model when it has one, "?" until then), odds, name, rarity and speed multiplier; clicking anywhere off the
  card closes it. (First draft had a ROLLS button + card feed; the owner removed it.)

Owner's answers: join/respawn = on foot in the spawn area; stop payout = **bank, pay on stop**.

## 1. Spawn area (`Shared/SpawnArea`, built by `Server/Main` after the chain)

All positions are in the local space of Track 1's `Start` part (`Workspace.Track.<Track 1>.Start`), which today is
the world origin facing -Z (local +X = world +X, local +Z = behind the start line). Track 1's start straight runs
from local z = 0 to z = -240 between walls at x = ±21; Track 1's finish/checkpoint area and Track 2 pass behind
the start at z ~ 40..140, so the area sits to the RIGHT of the start straight, not behind it.

| Constant | Value |
|---|---|
| `SpawnArea.COLOR` | `Color3.fromRGB(140, 70, 220)` (purple) |
| `SpawnArea.AREA_MIN` / `AREA_MAX` | local (x, z) `(24, -100)` / `(184, 44)`: 160 x 144 studs |
| `SpawnArea.PAD_MIN` / `PAD_MAX` | local (x, z) `(-20, 2)` / `(24, 38)`: the start platform, right behind the start line, joining the area to the road |
| `SpawnArea.TOP_Y` | `1`: floor top = road top (`TRACK_LIFT` road surface) |
| `SpawnArea.START_COOLDOWN` | `2` s: a player can not be started by the pad again this soon after a stop or a pad start |
| `SpawnArea.WALK_ROOT_HEIGHT` | `3` studs: HumanoidRootPart above the floor top when standing |

`Workspace.SpawnArea` (Model) contains:
- `Floor`: anchored Part, `COLOR`, `Material = SmoothPlastic`, covers AREA_MIN..AREA_MAX, top at `TOP_Y`.
- `Edge*`: low (2 stud) anchored edge walls on the three outer sides of the area (not the side facing the pad/road).
- `Spawn`: `SpawnLocation` in the middle of the area (`Neutral = true`, `Duration = 0`, 12 x 1 x 12, `COLOR`), top
  at `TOP_Y`. It is the game's only SpawnLocation.
- `StartPad`: anchored Part covering PAD_MIN..PAD_MAX, top at `TOP_Y + 0.2`, bright green `Neon`, tagged
  `StartPad`, with a `SurfaceGui`/`BillboardGui` "RACE ▶". It never overlaps a road part or a wall.

API: `SpawnArea.Build(startCFrame) -> Model`, `SpawnArea.WalkCFrame(startCFrame) -> CFrame` (area centre,
root at `TOP_Y + WALK_ROOT_HEIGHT`, facing the pad), `SpawnArea.Bounds(startCFrame) -> { Area = {Min, Max},
Pad = {Min, Max} }` (world Vector3 corners, Y = TOP_Y). `CarService.WalkSpawnCFrame()` returns
`SpawnArea.WalkCFrame(start)`.

Rules (tests): the area and pad overlap no road / wall / checkpoint part of ANY chained track (horizontally,
ignoring each track's `Ground`); every waypoint of the race path is at least `CarService` `WALK_CLEARANCE` (75)
from the walk spawn; the pad touches the area (gap <= 1 stud) and touches the road's first edge (Track 1 Start).

## 2. Player flow (`Server/CarService`)

- **Join and every respawn:** on foot (visible, walking, jumping) at the walk spawn in the area, `AutoRacing = false`,
  button shows "Auto Race". No car exists until the player starts.
- **Start:** the "Auto Race" button (unchanged), or touching `StartPad` with the avatar (server-side `Touched`): a
  living, visible, non-racing avatar of a real player whose last stop/pad start is >= `START_COOLDOWN` ago ->
  `CarService.SetAutoRace(player, true)`. Touches by cars, hidden avatars or racing players do nothing.
- **Start is an event (owner, 2026-10-01: a fast Stop then Auto Race made the car path from the spawn area):**
  1. the car is built at the Track 1 start line with its chassis ANCHORED (nothing can drag it);
  2. the avatar is teleported into the seat, repeatedly, until the server sees `Humanoid.SeatPart == DriverSeat`
     with the root within `SEAT_SLACK` (6) studs of the seat;
  3. only then the chassis is unanchored and `RaceService.Attach` starts the run (driver, NPC race, Speed gain).
  Player attribute `RaceEvent`: `"Teleporting"` (steps 1-2), `"Racing"` (from 3), `"Off"` on foot. No run exists
  before step 3. Not seated within `SEAT_TIMEOUT` (3 s) or dead: no race, the player is put back on foot.
  A newer request (Stop) during steps 1-2 cancels the start: no run is ever created for it.
- **Stop:** the car's run cashes out (section 3), the car is removed and the avatar stands at the walk spawn.
- Death while racing: the run is destroyed (cashes out), the respawn is on foot in the area.

## 3. Banked winnings (`Server/RaceService`, NPC mode)

- Winning a track no longer pays at its finish. It adds `MoneyService.Quote(player, pad)`
  (`floor(Cash * MoneyMulti)`, no cooldown) to the run's bank: `run.Unbanked`, mirrored in the player attribute
  `Unbanked` (number, server-set, 0 when not racing).
- Losing a track clears the bank at the moment of the loss (`Result = "Lose"`): `Unbanked = 0`.
- `run:CashOut()` awards the bank to `leaderstats.Money` (`MoneyService.Award`), sets it to 0 and returns the amount.
  `run:Destroy()` cashes out first, so Stop, death and leaving all bank it (leaving: before the leave save).
- Laps keep adding to the bank. Admin `/tp` does not change the bank.
- `Result` events carry `Banked` (amount added, 0 on a loss) and `Unbanked` (bank after the result) instead of `Paid`.
  run counters: `run.Payouts` / `run.PaidTotal` count cash-outs; `run.BankedTotal` sums what wins added.
- Runs without NPC mode (the `race` test, CLAUDE.md track rule 8) still pay the pad directly, unchanged.

## 4. Turbo luck (`Shared/GachaConfig`, `Server/GachaService`)

| Constant | Value |
|---|---|
| `GachaConfig.TURBO_EVERY` | `10`: every 10th roll (Rolls = 10, 20, ...) is a turbo roll |
| `GachaConfig.TURBO_LUCK` | `5`: the turbo roll's luck is `Luck * 5` |

- `GachaConfig.IsTurbo(rollNumber)` -> `rollNumber > 0 and rollNumber % TURBO_EVERY == 0`.
- `GachaConfig.TurboProgress(rolls)` -> `rolls % TURBO_EVERY` (0..TURBO_EVERY-1; rolls done towards the next turbo).
- `GachaService.Roll(player, roller)` rolls with `Luck * (IsTurbo(Rolls + 1) and TURBO_LUCK or 1)`, then
  increments `Rolls`, and returns `id, isNew, turboMulti`. `Remotes.RollResult:FireClient(player, id, isNew, turboMulti)`
  (`turboMulti` = 1 or TURBO_LUCK). Derived from the saved `Rolls`, so nothing new is saved.

## 5. UI (client only displays)

- `SpeedHud/Panel` gains `UnbankedTitle` ("UNBANKED") and `UnbankedValue` (`HudFormat.MoneyText`, smoothed) under
  Money, reading the player attribute `Unbanked`. The panel stays non-interactive and on the left.
- **Owner's revision (2026-10-01): no roll feed / ROLLS button.** The roll toast itself is the way in:
  - ScreenGui **`RollUi`** (`Client/RollUi`) keeps only the **`TurboBar`** (Frame, AlwaysOn, non-interactive) at the
    bottom centre (bottom edge 10 px above the screen bottom, 240 x 16): `Fill` (width = TurboProgress / TURBO_EVERY),
    `Label` "TURBO LUCK n/10", and `TurboPop` ("TURBO x5!", shown about a second on a turbo roll, then the bar is empty).
  - **`RollToast/Toast` becomes a `TextButton`** above the TurboBar: it appears on every roll (name · rarity, "NEW!")
    and fades out; it is clickable only while shown (`Visible = false` once faded). Still hidden while any panel is open.
    Clicking it opens the **showcase**.
  - ScreenGui **`RollShowcase`** (created by `Client/RollToast`, an Overlay, `DisplayOrder` above the HUD):
    - `Backdrop`: full-screen `TextButton`, dark (BackgroundTransparency ~0.35, no text). Clicking it (anywhere off
      the card) closes the showcase: back to the normal view. A client `BlurEffect` named `RollShowcaseBlur` in
      `Lighting` is enabled while open and disabled when closed.
    - `Card` (Frame on top of the backdrop, centred, Active so clicks on it do NOT close): the CURRENT roll, updated
      live on every RollResult while open (it opens on the latest roll): `Viewport` (ViewportFrame; the car's model
      from `ReplicatedStorage.CarModels[spec.Model]` when it has one, else `Placeholder` "?"), `Odds` (big, rarity
      colour: `HudFormat.Odds(Chance)` style "1 in 250"; catch-all cars use "1 in ?"), `CarName`, `Rarity`
      (rarity colour; Secret readable), `SpeedMulti` ("Speed x6"), `NewBadge` (first discovery), `TurboBadge`
      ("TURBO x5" on a turbo roll).
    - Opening it closes any open panel (Index / Stats). While it is open the toast does not show.
- Panels (Index, Stats) end above the bottom strip (toast area excluded: the toast hides while a panel is open).
- `Client/NpcRacerView` / loser screen wording: "Banked $X" instead of "Paid $X".
