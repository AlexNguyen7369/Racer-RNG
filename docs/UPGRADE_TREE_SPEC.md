# Upgrade tree (implemented)

Status: implemented in the HUD through `UpgradeService`; purchases persist and affect gameplay. The historical design
answers below are retained only where they describe the active tree contract.
All design points confirmed by the owner on 2026-10-02 (incl. the turbo roll counts in section 4).

References (RNG Heroes): `references/upgrade_tree/rng_heroes_upgrades_button.png` (UPGRADES button with a red count
badge next to ROLL) and `references/upgrade_tree/rng_heroes_upgrade_tree.png` (hex-tile tree from a central "Start",
branches per stat, roman-numeral tiers, price under each buyable tile, locked "?" tiles beyond, Close button at the bottom).

## Owner's brief and answers
An upgrade tree bought with Money that increases Luck %, roll speed, Speed %, turbo luck (x10 -> x50 -> x200 -> x500 -> x1000,
more auto rolls needed per turbo each upgrade; numbers updated 2026-10-12), player walkspeed and Money %.
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
| Money | I-V | +50 % each | +250 % | Money multi: track winnings (`MoneyService.Quote` / `Collect`) |
| Luck | I-V | +50 % each | +250 % | Luck multi in every roll (`GachaService.Luck`) |
| Speed Gain | I-V | +50 % each | +250 % | Speed-gain multi (`GachaService.SpeedMulti`), alongside rebirths. Car models affect cruise/base speed only |
| Roll Speed | I-V | +15 % each | +75 % | roll interval = 3 s / 1.15^tiers (compounding, owner 2026-10-22): 2.61, 2.27, **2.00 s** (the cap) |
| Walkspeed | I-V | 16 -> 20, 25, 31, 39, 49 | +33 | on-foot WalkSpeed (each step noticeable) |
| Turbo | I-IV | see section 4 | | turbo multi and rolls needed per turbo |

Added percentages: every multi = 1 + (stat-point bonus) + (tree bonus). Example: 2 Luck points (+10 %) and Luck I-II
(+25 %) give Luck x1.35.

## 2. Prices (scale with progression)
Income: winning Track N pays `PayoutCurve.Cash(N)` ($100, then x10 / x7.5 alternating per track; owner 2026-10-27,
design doc "payout and price curves"). Prices grow faster than payouts (owner 2026-10-27):

`price(tile) = round_nice(150 * PayoutCurve.Ratio(depth) ^ 1.5 * branchWeight)` (`PayoutCurve.Cost`; depth 1 = next to
Start; `Ratio(n)` = payout of Track n / payout of Track 1)

| Depth | Base price | Track payout at that depth |
|---|---|---|
| 1 | $150 | $100 |
| 2 | $4.7k | $1k |
| 3 | $97k | $7.5k |
| 4 | $3.1m | $75k |
| 5 | $63m | $563k |
| 6 (Turbo III) | $2.0b | $5.6m |
| 7 (Turbo IV) | $41b | $42m |

`branchWeight`: Walkspeed 0.5 (cheap, quality of life), Money 1, Speed 1, Luck 1.2, Roll Speed 1.5, Turbo 2.
Turbo tiers start at depth 2 so the first turbo upgrade is never the first purchase. Rounded to two significant figures. All numbers live in one config so they can be re-tuned.

**Progression gate** (so it can not go too fast even with lucky money): tiers III+ also need the player's best track
won so far (`BestTrack`, a new saved number): tier III needs Track 2, tier IV Track 3, tier V Track 4, ... The gate is
`MinTrack = min(tier - 1, number of tracks in the game)` so with 2 tracks today it never locks anyone out forever,
and it tightens by itself as tracks are added. A gated tile shows "Reach Track N".

## 3. Roll speed
Shown as a percentage on the tile ("Roll Speed II: +15 % (2.27 s)"). Interval = `3 / product(1 + tier bonus)` (compounding, owner 2026-10-22), never below 2 s.
`GachaService.StartAutoRoll` reads the player's interval every roll (no restart needed after a purchase).

## 4. Turbo luck (owner, 2026-10-12; replaces the 2026-10-02 table)
Without a Turbo tier every 10th auto roll is a "turbo roll" that rolls with x10 luck. Each Turbo upgrade makes the
turbo roll much luckier and makes you wait for MORE rolls between turbo rolls (the owner accepts the longer wait
because the multi grows with it):

| Tier | Turbo multi | Turbo every N rolls | At 3 s / roll | At 2 s / roll |
|---|---|---|---|---|
| none | x10 | 10 | 30 s | 20 s |
| Turbo I | x50 | 50 | 2 min 30 s | 1 min 40 s |
| Turbo II | x200 | 200 | 10 min | 6 min 40 s |
| Turbo III | x500 | 500 | 25 min | 16 min 40 s |
| Turbo IV | x1000 | 1000 | 50 min | 33 min 20 s |

The bar becomes "TURBO LUCK n/N" with the tier's N and pops "TURBO xM!". Progress is kept when buying a tier
(capped below the new N).

## 5. Where it is
- **UPGRADES button** next to INDEX / STATS on the right column, red badge = number of tiles the player can buy right
  now (like the Stats badge).
- **No world spot (owner, 2026-10-13):** the "UPGRADES" sign and pad in the spawn area (local (150, -70)) are removed;
  the Best Roll Ever pedestal (`docs/LEADERBOARD_SPEC.md` 3a) stands there. The tree opens only from the UPGRADES
  button. The upgrade pad of each workshop plot (`docs/WORKSHOP_SPEC.md`) is a different thing and stays.
- The tree panel is a PanelSwitch panel (mutually exclusive with Index / Stats). Owner 2026-10-26 (replaces "starts
  below the Auto Race button and ends above the turbo bar"): it is a full-screen overlay (Isaac's 2026-10-14 design)
  with the world blurred, drag to pan, mouse-wheel and +/- zoom, a Close (X) and an EXIT button; it fits phone
  landscape. Like the roll showcase it is exempt from the panel band and the HUD-stays-clickable rule
  (`docs/HUD_LAYOUT_SPEC.md` sections 1 and 6).
- All six branches are shown, Walkspeed included (owner 2026-10-26: the 2026-10-14 tree had hidden it).
- Tiles: owned = blue, buyable = its price (green if affordable, red if not), gated = "Reach Track N", beyond = "?".
  Neighbouring tiles' click areas never overlap.

## 6. Server rules
- `Remotes.BuyUpgrade(tileId)`: validated (known tile, previous tile owned, gate met, enough Money), rate-limited;
  the server takes the Money and grants the tile. The client never sends an amount.
- Tile ids are permanent save keys (like car ids). Saved by `PlayerData` (new version): owned tile ids and `BestTrack`.
  Unknown ids are kept.
- Effects are read through `GachaService` multis (Luck, Speed, Money), the roll interval, the turbo tier, and the
  on-foot WalkSpeed in `CarService` (respawn and Stop keep it).
- Tests: tree rules (order, gate, price, money taken once), every effect at each tier, save/load, UI (button, badge,
  panel layout at every viewport, no world pad in the spawn area), and the existing stability tests unchanged.
