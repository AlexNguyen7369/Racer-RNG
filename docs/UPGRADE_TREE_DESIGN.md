# Upgrade tree: implementation design

Companion to `docs/UPGRADE_TREE_SPEC.md` (the owner's confirmed rules and numbers). This file is HOW it is built:
modules, data, remotes, layout, tests and build phases. Started 2026-10-05.

## What the reference games do (and what we take)
| Game | What it does | What we take |
|---|---|---|
| RNG Heroes (`references/upgrade_tree/`) | Hex-tile tree from a central Start. Branches snake outward (Money, Luck, Sell, Unit Storage, Damage, Walkspeed). Roll Speed hangs off the Luck branch. Roman-numeral tiers, price under the next buyable tile (green = affordable, red = not), locked "?" tiles beyond. Big red Close at the bottom. UPGRADES button next to ROLL with a red count badge. | The whole look: hex tiles, Start, roman numerals, price colours, "?" tiles, Close, the badge. A side branch hanging off another branch (our Turbo off Roll Speed). |
| Anime Dice | Same kind of tree (Money, Luck, Unit Storage, Roll Speed, Damage, Walkspeed). Players are told to buy Money and Luck first because they feed each other; Roll Speed comes later. Rebirths reset progress. | Money and Luck are the cheap, obvious first buys (weight 1 / 1.2); Roll Speed and Turbo cost more (1.5 / 2). Rebirth is NOT part of this build (it is a dashboard suggestion). |

## Architecture
```
Shared/UpgradeConfig    all numbers: branches, tiers, bonuses, price formula, gates, turbo and walkspeed tables, hex layout
Shared/UpgradeTree      pure maths on an owned-set (no Instances): tiles, Price, CanBuy, Bonuses, RollInterval,
                        Turbo, WalkSpeed, BuyableCount. Used by the server (truth) and the client (display only)
Server/UpgradeService   owns player.Upgrades (StringValue per owned tile id) and BestTrack; Buy (validated,
                        rate-limited), effects getters, Snapshot/Apply for PlayerData, Remotes.BuyUpgrade
Client/UpgradeUi        UPGRADES button + badge, the hex panel (a PanelSwitch panel), the world pad opener
```
The server decides everything. The client sends only a tile id; it never sends a price or an amount.

### Where the effects plug in (all added percentages, spec section 1)
| Effect | Today | Change |
|---|---|---|
| Money % | `GachaService.MoneyMulti` = `GachaConfig.Multis(alloc).Money` | `GachaConfig.Multis(alloc, UpgradeService.Bonuses(player))`: every multi = 1 + points bonus + tree bonus |
| Luck % | `GachaService.Luck` | same |
| Speed % (stat gain) | `GachaService.SpeedMulti` = points multi x rebirth multi | (1 + points + tree) x rebirth. Car models affect cruise/base speed only |
| Roll speed | `GachaConfig.ROLL_INTERVAL` (3 s) in `StartAutoRoll` / `WaitAfter` | `UpgradeService.RollInterval(player)` = 3 / (1 + bonus), floor 2 s, read every roll |
| Turbo | `IsTurbo(Rolls)` = every 10th roll ever, x5 | saved `TurboCount` (rolls since the last turbo roll). Turbo when `TurboCount + 1 >= Every`; then reset to 0. Tier sets `Every` and `Multi`. Buying a tier keeps progress, capped at `Every - 1`. Old saves: `TurboCount = Rolls % 10` |
| Walkspeed | Humanoid default 16 | `CarService` sets `Humanoid.WalkSpeed = UpgradeService.WalkSpeed(player)` on spawn, Stop and after each purchase |
| Gate | (none) | `BestTrack`: highest track number the player has won. `RaceService` raises it on a won track (NPC mode) or a finished one (no NPC) |

### Data and save (`PlayerData` VERSION 4)
- `Upgrades = { tileId, ... }` (sorted). Unknown ids are kept, like car ids. Tile ids are permanent save keys.
- `BestTrack = n` (0 for new players).
- `TurboCount = n`. Missing in a version-3 save: derived from `Rolls % 10`.
- Replication: `player.Upgrades` folder (StringValue per owned id), attributes `BestTrack`, `TurboCount`,
  `TurboEvery`, `TurboMulti`, `UpgradesBuyable` (the badge count, recomputed when Money, owned tiles or BestTrack change).

### Remote
`Remotes.BuyUpgrade` (RemoteFunction, client -> server, returns `ok, reason`). Rate-limited like `AllocateStat`
(`UpgradeService.REMOTE_COOLDOWN`). Rejects: unknown id, already owned, previous tile not owned, gate not met
(`"Reach Track N"`), not enough Money. On success: Money is taken once, the tile is granted, effects refresh.

## Tile ids and the tree
Ids: `<branch>_<tier>` in lower case, e.g. `money_1`, `luck_3`, `rollspeed_5`, `turbo_2`, `walkspeed_4`. `start` is
owned by everyone and is not saved.

Hex layout: axial coordinates `(q, r)`, Start at `(0, 0)`. Each branch walks out in one direction from Start; Turbo
forks off Roll Speed I and walks out in its own direction, so Turbo I is depth 2 (spec: "Turbo tiers start at depth 2").
One direction is left free for a future branch, and every branch end has room for more tiers.

```
              luck_5                      direction    branch       prerequisite of tier I
            luck_4                        ( 0,-1) up   Luck         start
  money_5   luck_3        rollspeed_5     ( 1,-1)      Roll Speed   start
   money_4  luck_2     rollspeed_4        ( 1, 0)      Turbo        rollspeed_1 (fork)
    money_3 luck_1  rollspeed_3           ( 0, 1) down Speed        start
     money_2   rollspeed_2                (-1, 1)      Walkspeed    start
      money_1 rollspeed_1 turbo_1 turbo_2 turbo_3 turbo_4
         [START]                          (-1, 0)      Money        start
   walkspeed_1  speed_1                   free:        a future branch
 walkspeed_2      speed_2
walkspeed_3         speed_3 ...
```
(Sketch only: the real positions come from `UpgradeConfig.Branches[*].Direction` / `Origin`.)

## Prices
`price = NiceRound(150 * 2.2 ^ (PriceDepth - 1) * BranchWeight)`, `NiceRound` = 2 significant figures, halves rounded up (225 -> 230, 165 -> 170, 495 -> 500).
`PriceDepth` is the tile's depth from Start, except Turbo, whose tiers I-IV are priced at depths 2, 4, 6, 7 (spec
table: Turbo III at depth 6, IV at depth 7). Weights: Walkspeed 0.5, Money 1, Speed 1, Luck 1.2, Roll Speed 1.5, Turbo 2.

| Tier | Money / Speed | Luck | Roll Speed | Walkspeed | Turbo |
|---|---|---|---|---|---|
| I | $150 | $180 | $230 | $75 | $660 |
| II | $330 | $400 | $500 | $170 | $3.2k (III/IV: $15k, $34k) |
| III | $730 | $870 | $1.1k | $360 | |
| IV | $1.6k | $1.9k | $2.4k | $800 | |
| V | $3.5k | $4.2k | $5.3k | $1.8k | |

(2 significant figures gives $730 / $7.7k where the spec's table said "about $750 / $7.8k".)

Gate: tiers III and up need `BestTrack >= min(tier - 1, TrackRegistry count)`. `UpgradeTree.RequiredTrack` fails
open (a missing or 0 track count gates nothing), so `UpgradeService` must always pass the real chain length; phase 2
tests that the server refuses a gated tile.

## UI (Client/UpgradeUi)
- **Button:** "UPGRADES" with a green up-arrow icon, on the right column with INDEX / STATS; red badge =
  `UpgradesBuyable` (hidden at 0).
- **Panel:** a `PanelSwitch` panel (exclusive with Index / Stats), below the Auto Race button and the compact roll,
  above the turbo bar. A `ScrollingFrame` (drag to pan on phones) holds the hex tiles; Close button at the bottom.
- **Tile states:** owned = blue with icon + name; buyable = name + price (green if affordable, red if not), click to buy;
  gated = grey "Reach Track N"; further out = dark "?". Hover/tap shows the effect ("Roll Speed II: +20 % (2.50 s)").
- **Feedback:** a buy plays a pop + coin sound; a rejected buy shakes the tile and shows the server's reason.
- **World pad:** "UPGRADES" sign + pad in the spawn area (spec section 5, around local (150, -70) of Track 1's Start;
  `SpawnArea` adds it, tag `UpgradePad`). Touching it with the local avatar opens the panel; leaving closes it.

## Tests (written first, by test-writer / ui-test-writer)
Harness `upgrades` (pure + server, no physics): tile list and ids; prerequisite order; Turbo forks off Roll Speed I;
every price matches the formula; gate per tier and track count; Bonuses / RollInterval (2.73, 2.50, 2.31, 2.14, 2.00,
never below 2) / Turbo table / WalkSpeed table; BuyableCount; `UpgradeService.Buy`: money taken exactly once, every
reject reason leaves Money and tiles unchanged, rate limit, non-string ids; effects reach `GachaService.Luck`,
`MoneyMulti`, `SpeedMulti` (added, not multiplied, with stat points), the auto-roll interval, turbo every N with
progress kept and capped on a tier buy, WalkSpeed on spawn and after Stop; BestTrack raised by a won track.
Harness `data`: VERSION 4 round trip, version-3 saves load (TurboCount from Rolls), unknown tile ids kept.
UI (`ui_upgrades`): button + badge, panel inside its area at every viewport, no overlap with Index / Stats / the
compact roll / turbo bar, Close works, buy click calls the remote, gated and "?" tiles not clickable, world pad opens it.
Unchanged: every stability test (the tree never touches cruise speed or physics).

## Build phases
1. **Logic** (this skeleton): `UpgradeConfig` (done: data) + `UpgradeTree` (stubs) -> test-writer writes `upgrades`
   pure-logic checks (red) -> implement `UpgradeTree` -> green.
2. **Server:** `UpgradeService` (stubs now), effects in GachaService / CarService / RaceService, TurboCount, PlayerData
   v4 -> test-writer extends `upgrades` + `data` first -> implement -> full harness green.
3. **UI:** ui-test-writer writes `ui_upgrades` first -> `Client/UpgradeUi`, world pad in `SpawnArea` -> UI suite green.
4. `/compat-check` ALL GREEN, update ProjectContext, dashboard TODO, progress log.

## Phase 2 plan (drafted 2026-10-06)
Server side only; the UI (phase 3) and `Client/RollUi` reading `TurboCount` / `TurboEvery` come after. Built in the
same round as workshop phase 1 (`docs/WORKSHOP_SPEC.md`) because both bump `PlayerData` to VERSION 4.

| Step | File | Change |
|---|---|---|
| 1 | `CarTest/Scenarios.luau` (test-writer) | extend `upgrades` with the server checks listed under Tests; extend `data` for VERSION 4 (`Upgrades`, `BestTrack`, `TurboCount`, `WorkshopLevel`); must be red against the stubs |
| 2 | `Server/UpgradeService` | implement every stub: `player.Upgrades` folder, attributes, `Buy` (rate limit, `UpgradeTree.CanBuy` with the real track count from `RaceService.GetRoute()`, Money taken once from `leaderstats.Money`), `Bonuses` / `RollInterval` / `Turbo` / `WalkSpeed`, `ReachTrack`, `Snapshot` / `Apply`, `Start` (remote + badge refresh on Money / tiles / BestTrack change) |
| 3 | `Shared/GachaConfig` | `Multis(alloc, bonuses)`: optional second table of added tree bonuses (Money, Luck, Speed); one-argument calls unchanged |
| 4 | `Server/GachaService` | `SpeedMulti` / `MoneyMulti` / `Luck` pass `UpgradeService.Bonuses`; `Roll` uses `TurboCount` and the player's Turbo tier instead of `IsTurbo(Rolls)`; `StartAutoRoll` / `WaitAfter` use `UpgradeService.RollInterval(player)` read every roll |
| 5 | `Server/CarService` | on-foot `Humanoid.WalkSpeed = UpgradeService.WalkSpeed(player)` on spawn, Stop (showCharacter) and after a Walkspeed buy |
| 6 | `Server/RaceService` | `UpgradeService.ReachTrack(player, n)` on a won track (NPC mode) or a finished one (no NPC) |
| 7 | `Server/PlayerData` | VERSION 4: save/load `UpgradeService.Snapshot` fields (and `WorkshopLevel`); a version-3 save loads with `TurboCount = Rolls % 10`, `BestTrack = 0`, no tiles |
| 8 | `Server/Main` | `UpgradeService.Start()` after `GachaService.Start()` |
| 9 | docs / context | ProjectContext, todo.json, tests_explained.json, README features after the full harness is green |

Dependency order to avoid require cycles: `UpgradeService` requires shared modules only (it reads and writes
`leaderstats.Money` itself, because `MoneyService` requires `GachaService`, which will require `UpgradeService`);
`GachaService`, `MoneyService` and `CarService` require `UpgradeService`; `UpgradeService` never requires them. The track count is
handed in by `Main` (`UpgradeService.SetTrackCount(#chain)`), so it does not need `RaceService` either.
