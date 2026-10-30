# Spawn area, race payouts, turbo luck and the roll feed

Owner's brief (2026-10-01):
- Create a spawn area, relatively large and purple for now (colour superseded 2026-10-30 by section 1b), close to Track 1 and connected to its start, so players
  can walk onto the start platform to start auto racing.
- It is the spawn point (join and respawn) and where Stop always sends the player, out of the race.
- Each won track pays its current/last-track reward immediately; stopping does not cash out a growing pot.
- An "Unbanked" HUD line.
- A turbo luck bar: every X auto rolls one roll gets multiplied luck. The bar fills one step per roll and plays a short
  animation on every turbo roll.
- Clicking the roll toast at the bottom enlarges it into a showcase of each roll as it happens (like RNG Heroes):
  the car (model when it has one, "?" until then), odds, name, rarity and speed multiplier; clicking anywhere off the
  card closes it. (First draft had a ROLLS button + card feed; the owner removed it.)

Owner's current answer (2026-10-21): join/respawn = on foot in the spawn area; NPC race payout = **pay the
current/last track immediately**. The earlier bank/pay-on-stop proposal is historical.

## 1. Spawn area (`Shared/SpawnArea`, built by `Server/Main` after the chain)

All positions are in the local space of Track 1's `Start` part (`Workspace.Track.<Track 1>.Start`), which today is
the world origin facing -Z (local +X = world +X, local +Z = behind the start line). Track 1's start straight runs
from local z = 0 to z = -240 between walls at x = ±21; Track 1's finish/checkpoint area and Track 2 pass behind
the start at z ~ 40..140, so the area sits to the RIGHT of the start straight, not behind it.

| Constant | Value |
|---|---|
| `SpawnArea.COLOR` | `Color3.fromRGB(206, 196, 180)` (warm paddock concrete, placeholder; owner 2026-10-30 replaces purple (140, 70, 220), section 1b) |
| `SpawnArea.SPAWN_COLOR` | `Color3.fromRGB(245, 245, 240)` (the `Spawn` part, placeholder) |
| `SpawnArea.AREA_MIN` / `AREA_MAX` | local (x, z) `(24, -188)` / `(252, 44)`: the floor, 228 x 232 studs (hub + 7 workshop plots, 2026-10-06) |
| `SpawnArea.HUB_MIN` / `HUB_MAX` | local (x, z) `(24, -100)` / `(184, 44)`: the hub, 160 x 144 studs, kept free of plots; `Spawn` and the walk spawn are at its centre |
| `SpawnArea.PAD_MIN` / `PAD_MAX` | local (x, z) `(-20, 2)` / `(24, 38)`: the start platform AS AUTHORED (44 x 36). Its placement comes from the two rows below |
| `SpawnArea.PAD_CENTER` | local (x, z) `(34.3031235, 28.4993916)`: centre of the placed platform, inside the hub (owner, 2026-10-10) |
| `SpawnArea.PAD_FRONT` | `(1, 0)`: the sign faces local +X, the hub entrance faces -Z. Placed footprint: 36 (x) by 44 (z) |
| `SpawnArea.TOP_Y` | `1`: floor top = road top (`TRACK_LIFT` road surface) |
| `SpawnArea.START_COOLDOWN` | `2` s: a player can not be started by the pad again this soon after a stop or a pad start |
| `SpawnArea.WALK_ROOT_HEIGHT` | `3` studs: HumanoidRootPart above the floor top when standing |

`Workspace.SpawnArea` (Model) contains:
- `Floor`: anchored Part, `COLOR`, `Material = Concrete` (owner 2026-10-30), covers AREA_MIN..AREA_MAX, top at `TOP_Y`.
- `Edge*`: low (2 stud) anchored edge walls on the three outer sides of the area (not the side facing the pad/road).
- `Spawn`: `SpawnLocation` in the middle of the area (`Neutral = true`, `Duration = 0`, 12 x 1 x 12, `SPAWN_COLOR`), top
  at `TOP_Y`. It is the game's only SpawnLocation.
- `StartPad`: anchored Part covering PAD_MIN..PAD_MAX in the frame `SpawnArea.PadBase(startCFrame)` (which moves
  the pad, pavilion meshes, boundaries and lights together to `PAD_CENTER` facing `PAD_FRONT`), top at
  `TOP_Y + 0.2`, bright green, tagged `StartPad`, under the "RACE START" pavilion. It never overlaps a road part
  or a wall. The near curb is open only where the platform crosses it (local x = 24 .. 54.303); the hub entrance
  in the platform's side rail is 20 studs wide.

API: `SpawnArea.Build(startCFrame) -> Model`, `SpawnArea.WalkCFrame(startCFrame) -> CFrame` (hub centre,
root at `TOP_Y + WALK_ROOT_HEIGHT`, facing the pad), `SpawnArea.Bounds(startCFrame) -> { Area = {Min, Max},
Pad = {Min, Max} }` (world Vector3 corners, Y = TOP_Y). `CarService.WalkSpawnCFrame()` returns
`SpawnArea.WalkCFrame(start)`.

Rules (tests): the area and pad overlap no road / wall / checkpoint part of ANY chained track (horizontally,
ignoring each track's `Ground`); every waypoint of the race path is at least `CarService` `WALK_CLEARANCE` (75)
from the walk spawn; the placed pad footprint is `PAD_CENTER` ± (18, 22). Since the 2026-10-10 move the pad no
longer spans the road centre or touches Track 1's Start: walking onto it starts the race by teleport (section 2).

## 1b. Paddock theme (owner 2026-10-30)

Owner's answers (2026-10-30, verbatim): "I want an open track theme, make the ground pixar themed. The floor can become
concrete. Yes up to your design disgression. Portal spot is correct. 40 stud tower is ok. Continue implementation".
Layout reference: `drafts/environments/spawn-area-redesign/DRAFT.md` section 3 (theme A, open-air pit-lane paddock).
Every colour, size and count below is a placeholder unless marked fixed.

1. **Theme:** an open-air race-track paddock plaza. The plots read as pit garages on one pit lane, the pavilion as
   the pit exit, a timing tower as the landmark. Style is Pixar-like: stylised, warm, saturated, rounded shapes
   (bevelled or rounded tops on tall pieces), never realistic or gritty.
2. **Palette (placeholders):** floor `COLOR` (206, 196, 180); walkway paint (245, 232, 200); pit lane (78, 82, 96)
   with white (245, 245, 240) edge lines; kerbs red (235, 70, 60) and white; accent teal (40, 200, 190); highlight
   amber (255, 190, 65). Floor `Concrete` (fixed, owner); paint `SmoothPlastic`; tower and masts `Metal`.
3. **Leftover purple (developer's discretion, owner 2026-10-30):** the `CheckpointNpc` ring becomes teal
   (40, 200, 190); the leaderboard sign backs (52, 56, 72); the edge walls kerb red / white; the pavilion
   `RoofPurple` mesh red (235, 70, 60) by a `Color` change only. The x = 24 road side stays open (no pit wall).
4. **Decor folder:** every theme piece is under `Workspace.SpawnArea.Decor`. Every decor part is anchored with
   `CanTouch = false`; flat paint (0.1 high, top at `TOP_Y + 0.05`) is `CanCollide = false` and `CanQuery = false`;
   tall pieces collide only through invisible box boundaries. No decor part lies inside a plot rect, the placed pad
   footprint, the marketplace footprint, a pedestal / pass-car stand radius, or outside `AREA_MIN..AREA_MAX` at
   any height, and none is taller than 0.1 within 10 studs of the walk spawn.
5. **Pit lane:** the strips in front of the plots (x 184..200 and z -132..-116) hold no part taller than 0.1, so
   plot fronts are never blocked.
6. **Timing tower:** 40 studs tall (owner OK), 6 x 6, at local (176, -92), decorative only (no live data).
7. **Portal spot:** the World 1 `WorldPortal` stands at local (96, -88) inside the hub (fixed, owner); its
   24 x 12 footprint and +Z facing are placeholders. The decor task only reserves it (nothing else is placed there); the World 2 task builds it.
8. **Lighting:** decor never changes `Lighting`, `Atmosphere`, `Sky` or post effects. At most 4 new local lights,
   all `Shadows = false`.
9. **Budget:** at most 300 new BaseParts in the whole spawn redesign (`Decor` plus the red/white `Edge*` kerb blocks
   and any other new SpawnArea part; owner 2026-10-30, was 250 in `Decor` only) and 20,000 mesh triangles in `Decor`;
   parts with `Size.Magnitude` <= 30 cast no shadow (`RENDERING_SPEC.md` section 3).
10. **World 2 hub:** reuses this layout and theme in its own palette, chosen when the World 2 hub is built.
11. Unchanged: `Spawn` size and place, `StartPad`, `PAD_CENTER`, plots, marketplace, leaderboards, pedestals and
    every section 1 overlap rule. Test: `spawn_area` (updated) and a new `spawn_decor` scenario (test-writer).

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
- **Stop:** the run ends with no additional payout, the car is removed and the avatar stands at the walk spawn.
- Death while racing: the run is destroyed with no additional payout, and the respawn is on foot in the area.

## 3. Race payout (`Server/RaceService`, NPC mode)

- Winning track `n` awards `MoneyService.Quote(player, pad)` (`floor(Cash * MoneyMulti)`, no cooldown) at the
  finish, exactly once. Losing track `n` awards nothing for that track; earlier awards remain in `leaderstats.Money`.
- `run:CashOut()` is retained as a deprecated no-op for old callers and returns 0. `run:Destroy()` never adds a
  second payout. The `Unbanked` attribute and `Banked`/`Unbanked` result fields remain zero for compatibility.
- Result events use `Paid` for the current track's award. `run.Payouts` / `run.PaidTotal` count awards.
- Runs without NPC mode (the `race` test, CLAUDE.md track rule 8) still pay the pad directly, unchanged.

## 4. Turbo luck (`Shared/GachaConfig`, `Server/GachaService`)

| Constant | Value |
|---|---|
| `GachaConfig.TURBO_EVERY` | `10`: every 10th roll (Rolls = 10, 20, ...) is a turbo roll |
| `GachaConfig.TURBO_LUCK` | `10`: the turbo roll's luck is `Luck * 10` (owner, 2026-10-12; upgrade tiers: `docs/UPGRADE_TREE_SPEC.md` section 4) |

- `GachaConfig.IsTurbo(rollNumber)` -> `rollNumber > 0 and rollNumber % TURBO_EVERY == 0`.
- `GachaConfig.TurboProgress(rolls)` -> `rolls % TURBO_EVERY` (0..TURBO_EVERY-1; rolls done towards the next turbo).
- `GachaService.Roll(player, roller)` rolls with `Luck * (IsTurbo(Rolls + 1) and TURBO_LUCK or 1)`, then
  increments `Rolls`, and returns `id, isNew, turboMulti, emphasized, scrapMoney`. Duplicate rolls award direct Money
  from the car's rarity table; `Remotes.RollResult:FireClient(player, id, isNew, turboMulti, emphasized, scrapMoney, luck)`
  includes the server-calculated payout for the duplicate card. No Parts currency is created.
  (`turboMulti` = 1 or TURBO_LUCK). Derived from the saved `Rolls`, so nothing new is saved.

## 5. UI (client only displays)

- The legacy `UNBANKED` HUD row may remain for compatibility, but it is always zero and is not an active economy
  mechanic.
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
      colour: `HudFormat.Odds(Chance)` style "1 in 250"; temporary luck does not alter the catalog rarity; catch-all cars use "1 in ?"), `CarName`, `Rarity`
      (rarity colour; Secret readable), `SpeedMulti` ("Speed x6"), `NewBadge` (first discovery), `TurboBadge`
      ("TURBO x5" on a turbo roll).
    - Opening it closes any open panel (Index / Stats). While it is open the toast does not show.
- Panels (Index, Stats) end above the bottom strip (toast area excluded: the toast hides while a panel is open).
- `Client/NpcRacerView` loser screen: a full race recap, see `docs/NPC_RACER_SPEC.md` "Loser screen" (owner 2026-10-27; banking is deprecated).
