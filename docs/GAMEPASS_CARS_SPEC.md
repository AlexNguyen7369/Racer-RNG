# Gamepass cars (contract for tests and implementation)

Owner brief, 2026-10-13: two smaller pedestals stand left and right of the Best Roll Ever pedestal. Each shows a car
that is locked behind a gamepass. Walking up to one offers the purchase for Robux. Design rule:
`docs/GAME_DESIGN_REQUIREMENTS.md`, "Monetization" (Gamepass cars).

Status: rule written 2026-10-13, before tests and code.

## 1. The cars (`src/shared/Cars/`)

| Id (permanent) | Name | Rarity | `SpeedMulti` (proposed) | `GamepassId` |
|---|---|---|---|---|
| `ember_wyvern` | Ember Wyvern | Mythic | 500 | 0 until the owner creates the pass |
| `singularity` | Singularity | Secret | 2000 | 0 until the owner creates the pass |

`SpeedMulti` values are proposed; the owner tunes them. The price is set in the Creator Dashboard; the game never
states or stores a price.

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
- `GamepassId = 0` is never asked and never owned.
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
  `CAR_SCALE`, every part anchored with `CanCollide`, `CanTouch`, `CanQuery` off (same as the Best Roll car).
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
