# Upgrade tree (QUEUED, not started)

Status: queued by the owner on 2026-10-02; design answers given the same day (below). Nothing is implemented. Build it
test-first like the spawn area (test-writer + ui-test-writer first, red run, implement, `/compat-check` ALL GREEN).
All design points confirmed by the owner on 2026-10-02 (incl. the turbo roll counts in section 4).

References (RNG Heroes): `references/upgrade_tree/rng_heroes_upgrades_button.png` (UPGRADES button with a red count
badge next to ROLL) and `references/upgrade_tree/rng_heroes_upgrade_tree.png` (hex-tile tree from a central "Start",
branches per stat, roman-numeral tiers, price under each buyable tile, locked "?" tiles beyond, Close button at the bottom).

## Owner's brief and answers
An upgrade tree bought with Money that increases Luck %, roll speed, Speed %, turbo luck (x10 -> x50 -> x100 -> x1000,
more auto rolls needed per turbo each upgrade), player walkspeed and Money %.
1. Prices scale with progression (money per checkpoint), early upgrades come quickly, later ones slowly. The game will
   have many more tracks than 2, so prices must keep scaling as income grows.
2. Turbo roll counts: confirmed as in section 4.
3. Roll speed is tiered and shown as a percentage; the fastest it ever gets is **2 s per roll** (today 3 s).
4. Walkspeed: **5 tiers**, each one noticeable.
5. Bonuses are **added percentages** (like stat points today).
6. A **real tree** as in the reference: tiers in order, branches grow out from Start.
7. Both an **UPGRADES button** and a **spot in the world**: for now inside the spawn area.

## 1. The tree
Hex grid with `Start` in the middle and one branch per hex direction (six stats, six directions). Each branch is a chain:
tier I touches Start, tier II touches tier I, and so on. A tile can be bought only when the tile before it is owned
(Start is owned from the beginning). Tiles further out than the next buyable one show a locked "?".
Room is left at the ends of branches and between them for future tiles (more tiers, new stats).

| Branch | Tiers | Per tier (added) | Total | Effect |
|---|---|---|---|---|
| Money | I-V | +10, +10, +15, +15, +20 % | +70 % | Money multi: track winnings (`MoneyService.Quote` / `Collect`) |
| Luck | I-V | +10, +15, +20, +25, +30 % | +100 % | Luck multi in every roll (`GachaService.Luck`) |
| Speed | I-V | +10, +10, +15, +15, +20 % | +70 % | Speed-stat GAIN multi (`GachaService.SpeedMulti`). Never the car's cruise speed or physics (stability rule) |
| Roll Speed | I-V | +10 % each | +50 % | roll interval = 3 s / (1 + bonus): 2.73, 2.50, 2.31, 2.14, **2.00 s** (the cap) |
| Walkspeed | I-V | 16 -> 18, 20, 23, 26, 30 | +14 | on-foot WalkSpeed (each step about +12 %, noticeable) |
| Turbo | I-IV | see section 4 | | turbo multi and rolls needed per turbo |

Added percentages: every multi = 1 + (stat-point bonus) + (tree bonus). Example: 2 Luck points (+10 %) and Luck I-II
(+25 %) give Luck x1.35.

## 2. Prices (scale with progression)
Income today: winning Track N pays `N * 100` (`TrackBuilder.CashFor`), banked until Stop. Early game a Track 1 win
(~30-40 s) is $100; a full 2-track lap is $300. With more tracks, a lap of K tracks pays `100 * K(K+1)/2`, so income
grows about with the square of the tracks reached. Prices therefore grow exponentially with how deep a tile is:

`price(tile) = round_nice(150 * 2.2 ^ (depth - 1) * branchWeight)` (depth 1 = next to Start)

| Depth | Base price | About how long at that point |
|---|---|---|
| 1 | $150 | 1-2 Track 1 wins (first minute or two) |
| 2 | $330 | a couple of laps |
| 3 | $750 | |
| 4 | $1.6k | |
| 5 | $3.5k | ~10-15 min of 2-track laps |
| 6 (Turbo III) | $7.8k | |
| 7 (Turbo IV) | $17k | |

`branchWeight`: Walkspeed 0.5 (cheap, quality of life), Money 1, Speed 1, Luck 1.2, Roll Speed 1.5, Turbo 2.
Turbo tiers start at depth 2 so the first turbo upgrade is never the first purchase. Rounded to "nice" numbers
($150, $330, $750, $1.6k...). All numbers live in one config so they can be re-tuned.

**Progression gate** (so it can not go too fast even with lucky money): tiers III+ also need the player's best track
won so far (`BestTrack`, a new saved number): tier III needs Track 2, tier IV Track 3, tier V Track 4, ... The gate is
`MinTrack = min(tier - 1, number of tracks in the game)` so with 2 tracks today it never locks anyone out forever,
and it tightens by itself as tracks are added. A gated tile shows "Reach Track N".

## 3. Roll speed
Shown as a percentage on the tile ("Roll Speed II: +20 % (2.50 s)"). Interval = `3 / (1 + bonus)`, never below 2 s.
`GachaService.StartAutoRoll` reads the player's interval every roll (no restart needed after a purchase).

## 4. Turbo luck (confirmed)
Today: every 10th auto roll is a "turbo roll" that rolls with x5 luck (the TURBO LUCK bar fills 1/10 per roll).
Each Turbo upgrade makes the turbo roll much luckier but makes you wait for MORE rolls between turbo rolls:

| Tier | Turbo multi | Turbo every N rolls | At 3 s / roll | At 2 s / roll |
|---|---|---|---|---|
| today | x5 | 10 | 30 s | 20 s |
| Turbo I | x10 | 15 | 45 s | 30 s |
| Turbo II | x50 | 25 | 75 s | 50 s |
| Turbo III | x100 | 40 | 2 min | 80 s |
| Turbo IV | x1000 | 100 | 5 min | 200 s |

The bar becomes "TURBO LUCK n/N" with the tier's N and pops "TURBO xM!". Progress is kept when buying a tier
(capped below the new N).

## 5. Where it is
- **UPGRADES button** next to INDEX / STATS on the right column, red badge = number of tiles the player can buy right
  now (like the Stats badge).
- **World spot in the spawn area:** an "UPGRADES" sign with a pad in front of it in the free part of the area, away
  from the walk spawn and the StartPad (around local (150, -70) of Track 1's Start). Stepping on the pad opens the tree
  (client-side, the local avatar only); stepping off closes it. Must not overlap the spawn, the StartPad or the edges.
- The tree panel is a PanelSwitch panel (mutually exclusive with Index / Stats), starts below the Auto Race button and
  ends above the turbo bar, Close button at the bottom, fits phone landscape.
- Tiles: owned = blue, buyable = its price (green if affordable, red if not), gated = "Reach Track N", beyond = "?".

## 6. Server rules
- `Remotes.BuyUpgrade(tileId)`: validated (known tile, previous tile owned, gate met, enough Money), rate-limited;
  the server takes the Money and grants the tile. The client never sends an amount.
- Tile ids are permanent save keys (like car ids). Saved by `PlayerData` (new version): owned tile ids and `BestTrack`.
  Unknown ids are kept.
- Effects are read through `GachaService` multis (Luck, Speed, Money), the roll interval, the turbo tier, and the
  on-foot WalkSpeed in `CarService` (respawn and Stop keep it).
- Tests: tree rules (order, gate, price, money taken once), every effect at each tier, save/load, UI (button, badge,
  panel layout at every viewport, world pad opens/closes), and the existing stability tests unchanged.
