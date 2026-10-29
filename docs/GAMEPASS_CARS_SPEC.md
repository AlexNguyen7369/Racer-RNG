# Gamepass cars (contract for tests and implementation)

Owner brief, 2026-10-13: two smaller pedestals stand left and right of the Best Roll Ever pedestal. Each shows a car
that is locked behind a gamepass. Walking up to one offers the purchase for Robux. Design rule:
`docs/GAME_DESIGN_REQUIREMENTS.md`, "Monetization" (Gamepass cars).

Status: rule written 2026-10-13, before tests and code.

## 1. The cars (`src/shared/Cars/`)

| Id (permanent) | Name | Rarity | `SpeedMulti` (proposed) | `GamepassId` |
|---|---|---|---|---|
| `ember_wyvern` | Ember Wyvern | Secret | 2000 | 0 until the owner creates the pass |
| `singularity` | Singularity | Mythic | 500 | 0 until the owner creates the pass |

`SpeedMulti` values are proposed; the owner tunes them. Owner, 2026-10-16: rarities swapped (Ember Wyvern is the
stronger car) and each car file has `RobuxPrice`, the listed price the Shop shows: Ember Wyvern 1999, Singularity
999. Roblox charges the Creator Dashboard price; once `GamepassId > 0` the Shop shows Roblox's live price
(`docs/GAMEPASS_SHOP_SPEC.md`).

## 2. Catalog rules (`Shared/CarCatalog`)

- A car file with a `GamepassId` field (a number, 0 allowed) is a gamepass car: `Rollable = false`, `Chance = nil`.
- It is NOT in `CarCatalog.All()` (so not in the Index) and NOT in `CarCatalog.Rollable()` (never rolled, never the
  catch-all, never a daily-login or admin `/roll` result). `CarCatalog.Get(id)` returns it. `CarCatalog.Passes()`
  returns every gamepass car, sorted by `Order`.
- It gives no stat points, is never in `GachaData`, is never saved in `Cars`, and never counts on the Rarest Car board.

## 3. Ownership (`Server/PassCarService`)

- Roblox is the source of truth; nothing is saved (`PlayerData` VERSION unchanged).
- After a player's save loaded, the server asks `MarketplaceService:UserOwnsGamePassAsync` for every gamepass car with
  `GamepassId > 0` (in `pcall`; a failure counts as not owned for this session) and sets player attribute
  `Pass_<carId>` to `true`, else leaves it `nil`. `PassChecked = true` once every pass was asked.
- `MarketplaceService.PromptGamePassPurchaseFinished(player, passId, wasPurchased)`: with `wasPurchased` and a known
  pass id, set `Pass_<carId> = true` and equip that car.
- `GamepassId = 0` is never asked and never owned by a player.
- Owner 2026-10-20: an admin (`AdminService.IsAdmin`, real Players only) owns every gamepass car, on sale or not:
  `Check` sets `Pass_<carId> = true` for them, so the pedestal, the Shop and the Backpack equip it.
- Owner 2026-10-20: an owned gamepass car is playable. The Shop's Featured card turns its price button into
  "Equip" / "Equipped" (it fires `EquipCar`), and the Backpack `Cars` tab lists owned gamepass cars.
- `PassCarService.SetMarket(fake)` lets tests inject `{ Owns(userId, passId) -> boolean, Prompt(player, passId) }`;
  `nil` restores the real service. `PassCarService.Check(player)` runs the ownership check now.
  `PassCarService.Trigger(player, carId)` is what a pedestal prompt calls. `PassCarService.Purchased(player, passId)`
  is the purchase-finished path.

## 4. Equip (`Server/GachaService`)

- `GachaService.Equip(player, id)` accepts a gamepass car only while `Pass_<id>` is `true`. The existing
  `Remotes.EquipCar` path is the same function.
- A saved `Equipped` gamepass car is kept by `GachaService.Apply` (the pass is not known yet). When the ownership
  check finishes and the pass is not owned, the server equips the starter car.
- Effects are those of any car: `SpeedMulti` and the skin (`Shared/CarAppearance`). Physics never changes.

## 5. Pedestals (`Shared/SpawnArea`, numbers in `Shared/PassCarConfig`)

- `Workspace.SpawnArea.PassCars` (Model) holds one `Pass_<carId>` Model per entry of `PassCarConfig.Pedestals`
  (`{ CarId, X, Z }`, hub local): `Pedestal` (round, `RADIUS` studs, anchored, `CanCollide` true), decorative parts
  inside the same footprint, `Pedestal.Stats` (BillboardGui, `MaxDistance = TEXT_DISTANCE`) with TextLabels `Title`
  (the car's `Name`) and `Tag` ("GAMEPASS"), and `Pedestal.Buy` (ProximityPrompt, keyboard E, `HoldDuration` 0,
  `MaxActivationDistance = PROMPT_DISTANCE`).
- Every pedestal is inside `HUB_MIN..HUB_MAX` and overlaps none of: plot, pad, `Spawn`, marketplace footprint, race
  platform, track part, leaderboard sign, the Best Roll pedestal, the other pass pedestal.
- The server puts a `Car` Model on each pedestal at start: the `CarModels` entry named by the car's `Model`, at scale
  `CAR_SCALE` times the car's `SkinScale` when it has one, at most `CarAppearance.DISPLAY_SKIN_MAX` (Ember Wyvern,
  `docs/WYVERN_FLIGHT_SPEC.md` section 1, owner 2026-10-27), every part anchored with `CanCollide`, `CanTouch`, `CanQuery` off (same as the Best Roll car).
- Prompt: `ObjectText` = the car's name; `ActionText` = "Coming soon" when `GamepassId = 0`, else "Unlock".
  Triggering it (server-side, `Buy.Triggered`):
  - `GamepassId = 0`: nothing happens.
  - `Pass_<carId>` is `true`: the car is equipped.
  - else: `MarketplaceService:PromptGamePassPurchase(player, GamepassId)`. Roblox shows the price and asks.
- The client (`Client/BestRollView`) turns every showcase car, flaps parts named `Wing_L` / `Wing_R` and bobs the car.
  Display only.

## 6. Draft models (`Shared/DraftCarModels`)

Rough, Part-built stand-ins, created under `ReplicatedStorage.CarModels` at server start only when no model of that
name exists there. A real mesh with the same name replaces them. Concepts: `drafts/cars/ember-wyvern/DRAFT.md`,
`drafts/cars/singularity/DRAFT.md`. They are skins (`docs/VEHICLE_SKINS_SPEC.md`): no collision, inside the size
budget.

## 7. Tests

`pass_cars` harness scenario: catalog rules of section 2; never rolled in many rolls; equip refused without the pass
and accepted with it; `Apply` keeps a saved gamepass car and the check resets it when not owned; id 0 never prompts
and is never owned; a fake purchase sets the attribute and equips; a failing market raises no error; the pedestals,
labels, prompt and `Car` models exist and the footprints overlap nothing in the list of section 5.
Not testable in Studio: a real Robux purchase.


## Owner override — 2026-10-28 UI



Owner-approved UI delivery, 2026-10-28: white rounded racing-check Welcome reward panel, larger OFFLINE REWARD heading, smaller subtitle, centered speed icon and thick outlines; Claim dismisses using the existing flow. DOUBLE IT / 19 ROBUX is a visual placeholder until the owner creates the product. Offline amounts/rates/caps and server grants unchanged. Shop uses the same white checks. Detailed gamepass cutouts and separately drifting fire/space backgrounds, pooled embers/nebula/stars, Money-style card shine and scale-only 3.5% mouse hover (0.16s); no white hover border. Singularity art reduced about 12%. Gamepass section follows every rollable Index car and contributes no discoveries or stat points. Wyvern 799 Robux / x2000 Speed, Singularity 399 / x500; gamepass IDs remain 0. No Equip/Gift on these two cards; equip remains available elsewhere. Source art, Roblox IDs and prompts: ui/gamepass-cards/20261028. Focused desktop Studio checks and Luau compilation passed; full compatibility, phone and FPS checks not run. Shared Studio saved with version notes; no live publish. Other sessions have newer HUD/offline purchase work in Studio; this branch deliberately isolates this session's presentation changes.
