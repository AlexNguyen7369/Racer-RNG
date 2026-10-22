# Shop purchases and codes (contract for tests and implementation)

Design rule: `GAME_DESIGN_REQUIREMENTS.md`, "Monetization" (Shop, Codes). Owner decision 2026-10-16. Server module:
`Server/ShopService`. Config: `Shared/MonetizationConfig.Products` (public) and `Server/CodeConfig` (server only).

## 1. Products (`MonetizationConfig.Products`, array)

Each entry: `Id` (permanent string), `Name`, `Description`, `Section` ("Potions" | "Bundle" | "ServerLuck"),
`ProductId` (Roblox developer product id, 0 = not on sale), `RobuxPrice` (proposed), `Grants`
(`{ [boostId] = count }`, boost ids from `Shared/BoostConfig`; nil for Server Luck).

| Id | Grants | RobuxPrice (proposed) |
|---|---|---|
| `potion_luck_pack` | `LuckIII` x5 | 49 |
| `potion_money_pack` | `MoneyIII` x5 | 49 |
| `potion_speed_pack` | `SpeedIII` x5 | 49 |
| `potion_bundle` | x10 of every one of the 9 potions (90) | 999 |
| `server_luck_2x` / `_4x` / `_8x` | none (display only) | 199 / 399 / 799 |

## 2. Receipts (`ShopService.ProcessReceipt(receiptInfo)`, set as `MarketplaceService.ProcessReceipt`)

Returns an `Enum.ProductPurchaseDecision`:
- No product with `ProductId == receiptInfo.ProductId` (ids 0 never match), or it has no `Grants`: `NotProcessedYet`.
- Player `receiptInfo.PlayerId` not in the server, or their save not loaded (`DataLoaded` not true, or
  `DataFailed`): `NotProcessedYet`.
- `receiptInfo.PurchaseId` already in the player's saved receipts: `PurchaseGranted`, nothing granted again.
- A receipt with the same `PurchaseId` already being processed: `NotProcessedYet`.
- Else: add every grant with `BoostService.Add`, record the `PurchaseId`, then save (`PlayerData.Save`).
  Save true: `PurchaseGranted`. Save false: remove the grants and the `PurchaseId` again, `NotProcessedYet`.
- Receipts kept per player: the last `ShopService.MAX_RECEIPTS` (100) purchase ids.
- `ShopService.SetSave(fn)` lets tests replace the save (`fn(player) -> boolean`); nil restores `PlayerData.Save`.

## 3. Codes (`ShopService.Redeem(player, text)` -> ok, message; `Remotes.RedeemCode`, RemoteFunction)

- `Server/CodeConfig.Codes = { [CODE] = { Grants = { [boostId] = count } } }`; keys are upper case. It lives in
  ServerScriptService and never replicates.
- The text is trimmed and upper-cased. Not a string, empty, or longer than 32 characters: `false, "Invalid code"`.
- Save not loaded: `false, "Data not loaded"`. A second request within `ShopService.CODE_COOLDOWN` (2 s) of the
  last one: `false, "Please wait"`.
- Unknown code: `false, "Invalid code"`. Already redeemed by this player: `false, "Already redeemed"`.
- Else: add the grants with `BoostService.Add`, record the code, `true, "Code redeemed!"`.
- A code never changes `leaderstats.Money` or `Speed`.

## 4. Save

`PlayerData` VERSION 11 schema (`docs/SAVE_SPEC.md`; fields introduced in VERSION 9): `Receipts` (array of purchase id strings) and `Codes` (array of
upper-case code strings). `ShopService.Apply(player, data)` loads them (missing or bad entries = empty / skipped),
`ShopService.Snapshot(player)` returns `{ Receipts = {...}, Codes = {...} }`. A rebirth keeps both.
