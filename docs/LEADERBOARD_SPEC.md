# Global leaderboards (contract for tests and implementation)

Owner brief (2026-10-12, dashboard card `487b1922`): OrderedDataStore boards for Speed, Money earned, rolls and
rarest car, shown on signs in the spawn area. Server-only. Design rule: `docs/GAME_DESIGN_REQUIREMENTS.md`,
"Global leaderboards".

Status: NOT BUILT. This file is the contract; `test-writer` writes the `leaderboard` scenario from it first.

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

## 4. Tests

- `leaderboard` harness scenario with a fake store: descending order and the `TOP_N` cap, integer scores, the Speed
  max rule (a lower Speed never overwrites), nothing written for a failed or unloaded save, zero not written, the
  signs exist and overlap nothing in the list above, the rows match `Top(id)`, a throwing store raises no error.
- `world-tester`: the signs are anchored and block no walking route in the hub.
- Not testable in Studio without API access: real OrderedDataStore rows. "Needs you" item: enable Studio API access.
