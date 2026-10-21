# HUD layout

**Status: owner decision 2026-10-15.** It replaces the left INDEX / STATS / REBIRTH text column, the right-side
SHOP / DAILY / QUESTS / MARKET stack, and the Bag / Upgrades icons beside the bottom bars. The game design doc
("HUD layout") points here. The server still owns every number. The HUD only displays values and opens panels.

## 1. Icon tiles

Owner, 2026-10-15 (same day, replaces the first 2 x 3 grid):

- Left edge, vertically centred: `HudChrome/Grid`, one column of Index, Stats, Rebirth.
- Right edge, vertically centred: `HudChrome/ShopColumn` with the Shop tile.
- Bottom centre: Items (`ItemsSlot`) left of the LEVEL / TURBO LUCK bars and Upgrade (`UpgradeSlot`) right of
  them, each icon centred on the gap between the two bars, at 75% of the edge tiles' size. Both remain visible as
  dimmed background buttons while a panel is open. The panel's X or Escape closes it.
- Each tile is a cartoon icon with a white label and a dark outline under it. There is no button box behind the
  icon (the Index tile has its rounded blue card, as in the reference).
- Badges: Upgrade shows the number of buyable upgrades (`UpgradesBuyable`) and Stats shows the free stat points.
  A badge is a red circle at the top right of the icon and is hidden at 0.
- A tile opens its panel. A second click on the same tile closes it. Only one panel is open at a time
  (`PanelSwitch`).
- Shop opens the gamepass Shop (`docs/GAMEPASS_SHOP_SPEC.md`). Items opens the Backpack (section 3). Upgrade opens
  the upgrade tree. Index, Stats and Rebirth open their existing panels.
- Panels open between the left grid and the Shop column.

## 2. Top-right pills

These sit in the Roblox top-bar row at the top right, styled like Roblox's own top-bar buttons: dark translucent
pills, white text, and a round button for Settings.

- `Daily`: a calendar icon and the text "Daily". When today's reward was claimed, it shows the time left until
  the next one. It opens the 7-day daily reward panel.
- `Quests`: it opens the Daily / Weekly quest panel.
- `Market`: it opens the Money market (trails, auras and potions bought with Money). Owner 2026-10-16: it uses the
  Backpack look (section 3): gradient header with icon, title and square red X, side tabs Trails / Auras / Potions,
  a tile grid, and a detail pane (name, rarity, preview, price, description, Buy / Equip).
- `Settings`: a round gear button. It opens Settings.

The Daily Rewards panel follows `images/UI_DailyRewardsReference.png`: a red gradient header with a calendar icon and
close button, seven large reward cards, darkened completed cards with a green checkmark, and a prominent next-reward
countdown. Days 1–6 form a two-by-three card grid beside a larger Day 7 card on desktop; phone landscape stacks the
cards into a two-column layout. Cards use existing potion and car/HUD artwork, and claiming remains server-authoritative.

Owner 2026-10-20: the quest panel and the Checkpoints panel use the Backpack / Market look (section 3): the
`PanelFrame` header, dark body, navy tiles with a blue glow border (white or green on the selection), grey tabs and
Fredoka text with a dark outline.

The quest panel follows the supplied quest reference using only existing quest data: Daily / Weekly category tabs,
a scrollable selectable quest list, and a read-only detail pane showing the selected quest's name, progress and
reward. On phone landscape the detail pane collapses and the list uses the available width. Hovering a quest row
adds the shared white highlight and slight enlargement; its Claim button remains the only action that grants a reward.

## 3. Backpack (Items)

- It has a blue checkered header with an icon and the title "Backpack", and a square red X close button.
- Side tabs on the left: `Misc`, `Trails`, `Auras` and `Cars` (owner, 2026-10-20; replaces the 2026-10-15
  rule that kept cars out of the Backpack). The Index stays the discovery gallery of every car.
- The body is a grid of square tiles with a blue glow border. Each tile shows its icon.
- Misc: every consumable with a count above 0 (potions for now, later every consumable type), with the count in
  the bottom right (`x12`, `x1.2k`). Clicking one asks the server to use it (`UseBoost`). Hovering a tile shows its
  name and effect.
- Trails and Auras: every owned trail or aura, with its name under the art. Clicking one asks the server to equip
  it (`MarketEquip`). The equipped one has a green border. They are bought in the Market.
- Cars (owner, 2026-10-20): every owned car, ordered by rarity from least to most rare (Common, Uncommon, Rare,
  Epic, Legendary, Mythic, Secret; gamepass and event cars by their catalog rarity), then by catalog `Order`.
  Each tile shows the car's model, its name and its speed multi. Clicking one asks the server to equip it
  (`EquipCar`, the same validated remote the Index uses). The equipped car has a green border.

## 4. Settings

- It has the same frame as the Backpack (grey checkered header, gear icon, title "Settings", red X).
- It has two categories in its header: `Settings` and `Player Profile`. Settings is the default category.
- Its rows are the existing local settings: Sound, Reduced Effects and Top-Down View. Each row has the
  setting's name on the left and a pill toggle on the right: green "ON" on the right side of the track, or red
  "OFF" on the left side. No new settings are added.
- Player Profile uses the reference's scrollable white outlined rows and displays total rolls, best owned/rolled
  car odds, cars discovered, level, current Speed, Luck multiplier and allocated Luck points, and time spent in
  the current session. These are read-only displays of replicated player data.
- The separate Stats HUD button remains the rebirth/index stat-point allocation screen: Speed, Money, Luck and
  Workshop rows with their `+` buttons. It does not show the player profile. Following the allocation reference,
  these are light cards with a distinct colour per stat, a one-line per-point effect, the current/next multiplier,
  and a large matching allocation button; the UI must not invent a maximum or currency cost.

## 5. Potion status

- Each active potion category (strongest tier, as before) shows its bottle icon at the bottom right, left of the
  weather icon. The time left is written under the icon in white outlined text: `9m 33s`, `49m 42s`, or `42s`
  under one minute.
- Hovering an icon (or tapping it on touch) shows the name and the effect, as before.

## 6. No overlap

- Owner 2026-10-20: Daily, Quests, Shop and Market use `Client/PanelFrame` for the Backpack
  header/frame vocabulary; Daily remains red. Trail/Aura art is shared through `MarketArt`
  and `MarketConfig.Icon`. Details: `PANEL_ART_GIFTING_SPEC.md`.

- Whenever a `PanelSwitch` panel is open, every persistent HUD entry remains drawn: the HudChrome
  tiles/pills, Auto Race, the compact roll when it would otherwise be shown, the weather button and active potion
  buttons. Owner 2026-10-20 (replaces the per-HUD veil): a panel never dims the whole screen. Only the world
  behind the UI is dimmed, by one non-interactive layer (`HudChrome` creates ScreenGui `PanelDim`, DisplayOrder 0,
  below every HUD ScreenGui); the HUD stays at full brightness. Panels' own full-screen `Backdrop` frames are
  transparent. The full-screen roll showcase is exempt because it intentionally replaces the HUD.
- Owner 2026-10-20: the HUD tiles stay clickable while Shop, Market or Daily is open. Their full-screen dim
  `Backdrop` is a non-interactive Frame (it never swallows clicks); clicking a HUD tile switches panels, and a click
  on empty screen that no GUI handles closes Shop or Market (`PanelFrame.CloseOnOutsideClick`).
- No two reachable buttons, panels or labels overlap at any tested viewport, phone landscape included
  (`UiSpec` / `UiResponsive`).
- On phones (viewport height <= 500) the grid tiles and pills shrink.
