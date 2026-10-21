# Shared panels, cosmetic art and gifting

Owner plan approved 2026-10-20. Top-level rules: GAME_DESIGN_REQUIREMENTS.md.

## Panel frame and art

`Client/PanelFrame` provides a reusable rounded outline, gradient header, icon/title,
red Close button, backdrop and PanelBand fitting. Daily uses red, Quests blue, Shop
purple, Market orange. Existing named content paths and PanelSwitch identities stay.
Tabs and typography use the same spacing at desktop and phone landscape; content
scrolls within the available band. No remote is renamed.

All six current Trail/Aura items have `Icon` metadata and a shared `Client/MarketArt`
renderer used in Backpack tiles/tabs and Market tiles/tabs/detail. Original vector
sources have transparent backgrounds, with source/license notes. In-game vector
geometry can render immediately without invented Roblox upload ids. Uploaded image
ids may replace the vector rendering later.

`Shared/VehicleEffects` selects an authored profile for each item. Effects attach to
the chassis, have no collision, and never change mass or controls. Equip, respawn and
skin replacement preserve the server-owned EquippedAura/EquippedTrail attributes.

## Gift flow

Potion packs and bundle only. Account-bound gamepasses/cars and server-wide luck have
disabled Gift controls with a reason. Select another current player, review product and
recipient, confirm, then request `Remotes.PrepareGift(productId, recipientUserId)`.
Server validates both players loaded, recipient in this server, not self, product grant
allowlist, cooldown and one pending purchase per buyer.

Products use a separate `GiftProductId` (0 = unavailable) with the same server-configured
grants. Distinct gift developer-product ids prevent an old ordinary purchase receipt
from being redirected to a newly chosen recipient. Real ids must be created by the owner.
The server persists a pending route before opening the Roblox prompt. The client never
supplies a price or grant. Only server purchase-cancel events may cancel a reservation.

`Server/GiftService` stores pending routes and receipt routes in a dedicated DataStore.
An atomic route binds PurchaseId to a single recipient/product. Duplicate receipts reuse
that route even after a later gift is prepared. Mailbox enqueue uses UpdateAsync on the
recipient's existing PlayerStats key, preserving every field including session Lock.
Receipt returns PurchaseGranted only once the mailbox entry is durable; all failures
return NotProcessedYet. Recipient may leave after selection.

`PlayerData` VERSION 10 persists `GiftMailbox` and `GiftReceipts`. Saves are serialized per
player. Mailbox grants are merged into the saved Boosts and receipt markers together in
one UpdateAsync; live potion counts change only after success. Claim retries and duplicate
enqueue cannot grant the same PurchaseId twice. Old VERSION 9 saves default to empty.
Gift mailbox receipts remain durable for deduplication; no 100-receipt eviction is used
for gifts. Gift state is kept on rebirth. Online delivery is requested after enqueue;
offline gifts are claimed on join and subsequent saves.

## Acceptance

Reject invalid/self/offline-at-selection recipients and invalid/zero products. Cover
one-pending/cooldown, canceled prompt, sender leave/rejoin, recipient leaving after prompt,
duplicate/old receipts, failed route/mailbox/profile saves, offline claim, and exactly-once
potion delivery. Frame tests cover common structure, switching and phone geometry.
Catalog tests cover exactly 100 expansion entries (18/24/22/17/11/8), 20 per family,
single base catch-all, exclusion of passes/events, model bounds and non-colliding skin
attachment, seeded rolls, discovery and save/load.
