# Offline reward double (contract for tests and implementation)

Design rule: `GAME_DESIGN_REQUIREMENTS.md`, "Monetization", "Offline reward double" (owner 2026-10-28). Offline
earnings themselves: `docs/WORKSHOP_SPEC.md` (Speed only, credited in the load transform, `docs/SAVE_SPEC.md`).
Receipts: `docs/SHOP_PURCHASES_SPEC.md` section 2. Server: `Server/ShopService`. Config:
`Shared/MonetizationConfig.OfflineDouble`. Client: `Client/WelcomeStyle` (button) and `Client/ProgressionUi`
(amount).

## 1. Product (`MonetizationConfig.OfflineDouble`)

| Field | Value |
|---|---|
| `Id` | `"offline_double"` (permanent) |
| `ProductId` | Roblox developer product id. `0` = not on sale (the owner creates the product and pastes its id) |
| `RobuxPrice` | 19 (proposed) |
| `WINDOW_SECONDS` | 300 (placeholder): how long after the load the reward stays claimable |

It is a developer product, not a Shop entry (`MonetizationConfig.Products` does not list it), and it is not
giftable.

## 2. The offline reward and its window (server)

- After a successful load, `PlayerData.Load` calls `ShopService.SetOfflineReward(player, gain)` with the offline
  Speed it just credited (the same value as the `OfflineSpeed` attribute).
- `gain > 0` (finite): the server remembers `{ Amount = gain }` for this session and sets the player attribute
  `OfflineDoubleOpen = true` and `OfflineDoubled = nil`. After `WINDOW_SECONDS` it sets `OfflineDoubleOpen = false`.
- `gain <= 0` or not a finite number: nothing is remembered and `OfflineDoubleOpen = false`.
- The window ends early when the double is granted. A rebirth does not change the remembered amount.
- The remembered amount lives only in server memory and is dropped when the player leaves. No new saved field and
  no VERSION change: idempotency uses the existing saved `Receipts` list.

## 3. Receipt (`ShopService.ProcessReceipt`, `receiptInfo.ProductId == OfflineDouble.ProductId`, id > 0)

In this order:
1. Player not in the server, or save not loaded (`DataLoaded` not true, or `DataFailed`): `NotProcessedYet`.
2. Same `PurchaseId` being processed: `NotProcessedYet`.
3. `PurchaseId` already in the player's saved `Receipts`: `PurchaseGranted`, nothing added again.
4. No remembered reward this session, or it was already doubled: `NotProcessedYet`, nothing added (see section 4).
5. Else: `PlayerData.AddSpeed(player, Amount)` (the server's amount, never a client value), mark the reward
   doubled, set `OfflineDoubleOpen = false` and `OfflineDoubled = Amount`, record the `PurchaseId`, save.
   Save true: `PurchaseGranted`. Save false: remove the added Speed (not below 0), the `PurchaseId` and
   `OfflineDoubled`, the reward is undoubled again, `NotProcessedYet`.

A double never changes `leaderstats.Money`, potions, or anything but Speed.

## 4. Bought outside the window (safest option, chosen)

Robux can not be refunded by the game, so:
- The client only offers the prompt while `OfflineDoubleOpen` is true.
- A receipt that arrives after the window closed but in the same session (the prompt was open when the window ran
  out) is still granted: the remembered amount is kept until it is doubled or the player leaves.
- A receipt with no undoubled reward (a second purchase of the same reward, or a retry after rejoining) returns
  `NotProcessedYet`. Roblox keeps the receipt and retries it later (next join or purchase); it then doubles that
  session's offline reward, if there is one. It is never granted without a reward to double, and no credit is
  saved (no saved field).

## 5. Client

- `RacerWelcome/Panel/Double` is visible only while the player attribute `OfflineDoubleOpen` is true.
- `ProductId > 0`: the button is `Active`, its `Price` shows `"<RobuxPrice> ROBUX"`, and clicking it calls
  `MarketplaceService:PromptProductPurchase(LocalPlayer, ProductId)`. Attribute `PurchaseConfigured = true`.
- `ProductId == 0`: the button is visible but inactive, `Price` shows `"COMING SOON"`, clicking does nothing.
  Attribute `PurchaseConfigured = false`.
- `RacerWelcome/Panel/Earnings` shows `+<OfflineSpeed + OfflineDoubled> SPEED` (`HudFormat.SpeedText`), so after
  a granted double it shows the doubled amount.
