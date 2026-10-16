# Global leaderboards (contract for tests and implementation)

Owner brief (2026-10-12, dashboard card `487b1922`): OrderedDataStore boards for Speed, Money earned, rolls and
rarest car, shown on signs in the spawn area. Server-only. Design rule: `docs/GAME_DESIGN_REQUIREMENTS.md`,
"Global leaderboards".

Status: BUILT 2026-10-13 (server source present; full CarTest leaderboard scenario 109/109 passed).
Live sign visual validation remains pending. This file remains the implementation contract.

## 1. Boards (`src/shared/LeaderboardConfig.luau`)

| Id | Sign title | Score (integer) | Store name |
|---|---|---|---|
| `Speed` | TOP SPEED | best `leaderstats.Speed` reached, floored. Never goes down (a rebirth resets Speed) | `LB_Speed_v1` |
| `MoneyEarned` | MONEY EARNED | lifetime Money earned (`MoneyEarned`, saved), floored | `LB_MoneyEarned_v1` |
| `Rolls` | MOST ROLLS | saved `Rolls` | `LB_Rolls_v1` |
| `RarestCar` | RAREST CAR | the highest `Chance` among the player's owned catalog cars (0 with none) | `LB_RarestCar_v1` |

`TOP_N = 10`, `REFRESH = 60` s (read), `WRITE_INTERVAL = 300` s (write).

`MoneyEarned` counts every amount `MoneyService.Award` pays (race cash-outs and duplicate car sales). Spending never
lowers it. Admin `/money` and `/addmoney` do not count.

## 2. Server (`Server/LeaderboardService`)

- `Start()`, `Scores(player) -> { [id] = integer }`, `Write(player) -> boolean`, `Refresh()`,
  `Top(id) -> { { UserId, Name, Score }, ... }` (the last successful read, highest first, at most `TOP_N`),
  `SetStore(fn)` (tests inject a fake store, like `PlayerData.SetStore`).
- Writes: when a player leaves (`PlayerData.OnLeaving`) and every `WRITE_INTERVAL`. Never for a player with
  `DataFailed` or without `DataLoaded`. A score of 0 is not written. `Speed` is written with `UpdateAsync` keeping the
  larger value; the others are set to the current value.
- Reads: `GetSortedAsync(false, TOP_N)` per board every `REFRESH`. Names come from
  `Players:GetNameFromUserIdAsync`, cached; a failed lookup shows `Player <UserId>`.
- Every DataStore call is in `pcall`. A failure keeps the last good rows. With no store (Studio without API
  access) the signs show "No data yet" and nothing errors.
- No remote. Clients can not write a score or ask for a refresh.

## 3. Signs (`Shared/SpawnArea`)

- `Workspace.SpawnArea.Leaderboards` (Model) holds one `Board_<Id>` Part per board: anchored, `CanCollide` true,
  inside `HUB_MIN..HUB_MAX`, and it overlaps no plot, pad, `Spawn`, marketplace footprint, race platform or track
  part. Each has a `SurfaceGui` named `Board` with a `Title` TextLabel and rows `Row1 .. Row10`.
- A row reads `<rank>. <Name>  <score>`; scores use `Shared/HudFormat`; `RarestCar` shows the car's name and
  `1 in <Chance>`. Empty rows are blank.
- The server sets the text; the signs replicate like any other part.

## 3a. Best Roll Ever pedestal (owner, 2026-10-13)

Status: rule written 2026-10-13, before tests and code.

- What it shows: row 1 of the `RarestCar` board, `LeaderboardService.Top("RarestCar")[1]`. No new store, no remote.
  Owned cars survive a rebirth, so this score never drops. Players who own the same rarest car tie; which of them
  is row 1 is the store's choice.
- `Workspace.SpawnArea.BestRoll` (Model, built by `Shared/SpawnArea`, numbers in `LeaderboardConfig.BEST_ROLL`):
  - `Pedestal`: a round platform (anchored, `CanCollide` true), centre local (`X`, `Z`) = (150, -70), where the spawn-area
    upgrade pad stood until 2026-10-13 (owner), `RADIUS` studs, inside `HUB_MIN..HUB_MAX`. It overlaps none of: plot, pad, `Spawn`, marketplace footprint, race platform, track part,
    leaderboard sign. Extra decorative parts of the platform stay inside the same footprint.
  - `Pedestal.Stats` (BillboardGui above the car, finite `MaxDistance` = `TEXT_DISTANCE`) with TextLabels `Title`
    ("BEST ROLL EVER"), `Odds`, `Car`, `Player`.
- The server (`LeaderboardService`, after every board read) sets:
  - with a row 1: `Odds` = `HudFormat.Odds(score)` ("1 in 100,000"), `Car` = the catalog car with that `Chance`
    (its `Name`; blank when no car matches), `Player` = "by <Name>", attribute `BestRoll.CarId` = that car's id, and
    a `Car` Model under `BestRoll`: a clone of `ReplicatedStorage.CarModels[spec.Model]` standing on the platform at
    scale `CAR_SCALE`, every part anchored with `CanCollide`, `CanTouch` and `CanQuery` off. No template: no `Car` model.
  - with no row: `Odds` = "No data yet", `Car` and `Player` blank, no `CarId`, no `Car` model.
  - The `Car` model is rebuilt only when `CarId` changes.
- The client (`Client/BestRollView`) only turns `BestRoll.Car` about the vertical axis (`SPIN` degrees per second),
  locally. It decides nothing.

- Owner, 2026-10-13: the pedestal is much larger (`RADIUS` 12, `CAR_SCALE` 3.5) and is the centre of a row of three:
  the two gamepass car pedestals of `docs/GAMEPASS_CARS_SPEC.md` stand left and right of it. Shared numbers
  (`HEIGHT`, `SPIN`) stay in `LeaderboardConfig.BEST_ROLL`.

## 4. Tests

- Pedestal (in the `leaderboard` scenario): the model, `Pedestal` and the four labels exist; the footprint is inside
  the hub and overlaps nothing in the list above; after `Refresh()` with a fake store the labels, `CarId` and the
  `Car` model match row 1; an empty or throwing store shows "No data yet", no `Car`, no error; the `Car` parts are
  anchored and non-colliding.

- `leaderboard` harness scenario with a fake store: descending order and the `TOP_N` cap, integer scores, the Speed
  max rule (a lower Speed never overwrites), nothing written for a failed or unloaded save, zero not written, the
  signs exist and overlap nothing in the list above, the rows match `Top(id)`, a throwing store raises no error.
- `world-tester`: the signs are anchored and block no walking route in the hub.
- Not testable in Studio without API access: real OrderedDataStore rows. "Needs you" item: enable Studio API access.
