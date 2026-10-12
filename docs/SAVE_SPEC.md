# Saves: session lock and VERSION 8 (contract for tests and implementation)

Design rule (`docs/GAME_DESIGN_REQUIREMENTS.md`, "Technical and data requirements"): DataStores with session locking
so data can not duplicate across servers; save on leave, on an interval and on server shutdown. Owner decision
2026-10-12: fix the code now (`Server/PlayerData` used plain `GetAsync` / `SetAsync`).

## 1. Lock

The saved record gains `Lock = { Id = string, At = number }`: the server session that holds the save, and when it
last confirmed it (`PlayerData` clock, seconds).

| Constant | Value |
|---|---|
| `PlayerData.LOCK_TIMEOUT` | 120 s: a lock older than this is dead and may be taken |
| `PlayerData.LOAD_RETRIES` | 3 attempts in total |
| `PlayerData.LOAD_RETRY_WAIT` | 2 s between attempts |

- `PlayerData.SessionId()` -> this server's id: `game.JobId`, or a GUID made once per server when `JobId` is empty
  (Studio). `PlayerData.SetSessionId(id)` overrides it (tests; `nil` restores the default).
- **Load** is one `UpdateAsync` on the player's key. Inside the transform: if `current.Lock` belongs to ANOTHER id
  and `clock() - Lock.At < LOCK_TIMEOUT`, return `nil` (write nothing). Otherwise write the record back with
  `Lock = { Id = SessionId(), At = clock() }`; a missing record becomes `{ Lock = ... }`. The offline Speed claim
  (`docs/WORKSHOP_SPEC.md`) is applied in the same transform, so it can still never be paid twice.
  A refused load is retried up to `LOAD_RETRIES` times, `LOAD_RETRY_WAIT` apart, then the player gets `DataFailed`
  (and, as before, is never saved). A DataStore error also gives `DataFailed`.
- **Save** is one `UpdateAsync`. Inside the transform: if `current.Lock` belongs to another id and is not timed out,
  return `nil` and `Save` returns false (this server lost the session; it must not overwrite). Otherwise write the
  payload with `Lock = { Id = SessionId(), At = clock() }`, which refreshes the lock on every autosave.
- **Release:** the save on `PlayerRemoving` and the saves in `BindToClose` write `Lock = nil`
  (`PlayerData.Save(player, userId, true)`).
- The existing rules stay: never write before the load finished, never write for `DataFailed`, unknown fields a
  service owns are kept by that service's `Snapshot`.
- The fake store used by tests must provide `UpdateAsync(key, transform)` (returning the new value, and writing
  nothing when the transform returns `nil`) as well as `GetAsync` / `SetAsync`.

## 2. VERSION 8 fields

- `Version = 8`. Older versions load unchanged and are upgraded by the next save.
- `MoneyEarned` (integer >= 0, capped like Money): lifetime Money earned. `MoneyService.Award(player, amount)` adds
  the amount it actually paid to the player attribute `MoneyEarned`. Spending and admin commands do not change it.
  Missing = 0.
- `DuelWins` (integer >= 0), player attribute `DuelWins`. Missing = 0. (`docs/DUEL_SPEC.md`.)
- A rebirth keeps both.

## 3. What Money and Speed do on load (owner, 2026-10-12)

- Offline earnings are Speed only: no Money is credited on load, `Workshop.OfflineMoney` and
  `WorkshopConfig.OFFLINE_MONEY_FRACTION` do not exist, and the player attribute `OfflineMoney` is not set.
- A rebirth sets `leaderstats.Money` AND `leaderstats.Speed` to 0 (`Server/RebirthService`).
- Daily login rewards contain no Money (`Shared/DailyLoginConfig`: no `Money` field on any day; every day grants a
  potion or the guaranteed rare car). `DailyLoginService.Claim` never changes `leaderstats.Money`.
