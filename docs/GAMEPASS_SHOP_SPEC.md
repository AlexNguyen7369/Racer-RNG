# Shop (contract for tests and implementation)

Design rule: `GAME_DESIGN_REQUIREMENTS.md`, "Monetization" (Shop, Codes, Gamepass cars). Owner rewrite 2026-10-16
from the references `images/UI_ShopReference1-4.png`. Purchases and codes: `docs/SHOP_PURCHASES_SPEC.md`.

## 1. Layout (`Client/ShopUi`, ScreenGui `ShopUi`)

- `ShopUi/Backdrop` (non-interactive dim Frame; a click on empty screen closes the Shop, HUD tiles stay clickable, owner 2026-10-20) holds `Panel`: a light panel with a hex pattern, a tilted "Shop" title
  tab at its top left and a square red `Close` X at its top right. It opens in the PanelBand (`docs/HUD_LAYOUT_SPEC.md`).
- `Panel/Items` is one vertical ScrollingFrame with these sections, in this order (each a Frame named as shown):
  1. `Featured`: one card per gamepass car (`CarCatalog.Passes()`), each with a car preview (the car's
     `CarModels` model in a ViewportFrame, "?" if missing), name, rarity (in its rarity colour), `xN Speed` and a
     price button.
  2. `Gamepasses`: title "Gamepasses", a 3-column grid of colour cards, one per `MonetizationConfig.Gamepasses`
     entry: name, one-line description, icon, price button.
  3. `Potions`: title "Potions", subtitle with the potion duration from `BoostConfig`, one card per
     `MonetizationConfig.Products` entry with `Section = "Potions"`, then a full-width `Bundle` banner for the entry
     with `Section = "Bundle"` (its potions shown with their counts).
  4. `ServerLuck`: the DOUBLE Server Luck banner for the `Section = "ServerLuck"` entries.
  5. `Codes`: title "Codes", a TextBox `Input` and a `Redeem` button; a `Status` label shows the server's reply.
  6. `Thanks`: "Thanks for your support!".
- Every price button is named `Buy`.

## 2. Prices

- Every gamepass and product has `RobuxPrice` (whole Robux). The two cars keep theirs in their car file
  (`docs/GAMEPASS_CARS_SPEC.md`). All other `RobuxPrice` values are proposed.
- A `Buy` button shows the Robux icon and `RobuxPrice` (thousands separated). When the item's id
  (`GamepassId` / `ProductId`) is above 0, the client asks `MarketplaceService:GetProductInfo` in a `pcall` (in the
  background) and shows its `PriceInRobux` instead. A failure keeps `RobuxPrice`.
- Id 0: the button shows "Coming soon" under the price, and clicking does nothing.
- Id > 0: a gamepass button calls `PromptGamePassPurchase`, a product button `PromptProductPurchase`. Roblox shows
  the real price and asks. An owned gamepass car (player attribute `Pass_<carId>`) shows "Owned".
- Potion packs/bundle have Gift controls (owner 2026-10-20,
  `PANEL_ART_GIFTING_SPEC.md`). Gamepasses, cars and Server Luck display a disabled Gift
  control with the account-bound/server-wide reason. The frame uses `Client/PanelFrame`.

## 3. Server Luck

Server Luck (2x / 4x / 8x, 15 min, from the design doc) is listed with `ProductId = 0` and no `Grants`. It is
display-only until the Server Luck feature exists; the receipt handler never grants it.
