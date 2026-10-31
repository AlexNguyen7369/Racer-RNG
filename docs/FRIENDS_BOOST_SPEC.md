# Friends-in-server boost

**Status: owner decision 2026-10-28 (World 1 feature nf3).** Design rule: `GAME_DESIGN_REQUIREMENTS.md`,
"Friends-in-server boost". Server module: `Server/FriendBoostService`. Numbers marked *placeholder* are tunable.

## 1. Who counts

- A friend is another player in the same server for whom `player:IsFriendsWith(other.UserId)` returns true.
  The player never counts themself.
- Friendship is mutual, so the server checks each pair once, when the second of the two joins
  (`Players.PlayerAdded`), and caches the result for both players. `IsFriendsWith` is never called per roll,
  per payout or per frame.
- `IsFriendsWith` yields and can fail. Each call is wrapped in `pcall`; a failure counts as not-friends and is
  retried once after `RETRY_DELAY` (10 s, *placeholder*) if both players are still in the server. A second
  failure leaves the pair as not-friends until one of them rejoins.
- On `Players.PlayerRemoving` the leaver is dropped from every cache and every remaining friend's count is
  recomputed at once.

## 2. The multi

```
FriendBoost = 1 + min(PER_FRIEND x friends, CAP)
PER_FRIEND = 0.10 (placeholder), CAP = 0.40 (placeholder)
```

| friends | 0 | 1 | 2 | 3 | 4 | 5+ |
|---|---|---|---|---|---|---|
| FriendBoost | 1.0 | 1.1 | 1.2 | 1.3 | 1.4 | 1.4 |

`FriendBoostService.MultiFor(count)` returns 1 for a non-number, NaN, zero or negative count; a fractional
count is floored; inf gives the cap (1.4). `FriendBoostService.Multi(player)` is the multi for a player.

## 3. How it stacks

It is one more factor in the existing products (server only, `Server/GachaService`):

```
GachaService.Luck(player) = Multis.Luck x RebirthConfig.LuckMulti x BoostService(Luck) x Weather.Luck
                            x FriendBoost [x WorkshopConfig.LuckMulti in the workshop] [x AdminLuck]
GachaService.MoneyMulti(player) = Multis.Money x RebirthConfig.MoneyMulti x BoostService(Money)
                                  x Weather.Money x FriendBoost
```

- Luck: every roll uses `GachaService.Luck`, so `min(1, Luck / Chance)` per car and the turbo roll
  (`Luck x turbo multi`) both include it. The displayed odds stay the catalog rarity (WEATHER_EVENTS_SPEC
  "Displayed odds").
- Money: `MoneyService.Quote` and `MoneyService.Collect` multiply the pad cash by `GachaService.MoneyMulti`,
  so race payouts and the NPC-mode bank include it. Money is quoted when a pad is collected or a track is won;
  cashing out a bank never multiplies it again.
- It never affects Speed gain (race or workshop), offline earnings, cruise speed or car physics.

## 4. Client display

- Player attributes, set by the server: `FriendsInServer` (integer count) and `FriendBoost` (the multi).
  Updated on every join, leave and test-override change. No remote; clients cannot change either.
- HUD (owner 2026-10-30): a `FRIENDS +N%` chip in the bottom-right potion row
  (`RacerProgression/PotionStatus`, HUD_LAYOUT_SPEC section 5), where N = `round((FriendBoost - 1) x 100)`.
  It is hidden when `FriendsInServer` is 0 and updates when either attribute changes. Display only.
- Owner 2026-10-30: the chip is also hidden on phones (viewport height <= 500); the boost still applies.
  Elsewhere it is a narrow two-line chip (about 64 px wide, placeholder), see HUD_LAYOUT_SPEC section 5.
- Owner 2026-10-30 (later): when there is no room left of the potions (the chip would overlap other HUD), it stacks
  above the potion row, right-aligned (HUD_LAYOUT_SPEC section 5). Owner 2026-10-30: the stacked chip sits above the
  DailyBoosts status line too (bottom 10 px above it, placeholder), so it never covers that line.

## 5. Test override (Studio only)

- `ReplicatedStorage` attribute `FriendBoostTestCount` (number). While it is set and `RunService:IsStudio()`
  is true, every player's friend count is that number (floored, clamped to 0..1e6) instead of the cache, and the
  attributes refresh at once. Clear it (`nil`) to return to the real count. It has no effect in a live server.
