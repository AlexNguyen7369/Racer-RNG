# HUD layout

**Status: owner decision 2026-10-15.** It replaces the left INDEX / STATS / REBIRTH text column, the right-side
SHOP / DAILY / QUESTS / MARKET stack, and the Bag / Upgrades icons beside the bottom bars. The game design doc
("HUD layout") points here. The server still owns every number. The HUD only displays values and opens panels.

## 1. Icon tiles

Owner, 2026-10-15 (same day, replaces the first 2 x 3 grid):

- Left edge, vertically centred: `HudChrome/Grid`, one column of Index, Stats, Rebirth.
- Right edge, vertically centred: `HudChrome/ShopColumn` with the Shop tile.
- Bottom centre: Items (`ItemsSlot`) left of the LEVEL / TURBO LUCK bars and Upgrade (`UpgradeSlot`) right of
  them, each icon centred on the gap between the two bars, at 75% of the edge tiles' size. Both hide while any panel is open, because the panel
  fills the band above the bars. The panel's X or Escape closes it.
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
- `Market`: it opens the Money market (trails and auras).
- `Settings`: a round gear button. It opens Settings.

## 3. Backpack (Items)

- It has a blue checkered header with an icon and the title "Backpack", and a square red X close button.
- Side tabs on the left: `Misc`, `Trails` and `Auras` (owner, 2026-10-15). There are no cars in the Backpack:
  cars live only in the Index.
- The body is a grid of square tiles with a blue glow border. Each tile shows its icon.
- Misc: every consumable with a count above 0 (potions for now, later every consumable type), with the count in
  the bottom right (`x12`, `x1.2k`). Clicking one asks the server to use it (`UseBoost`). Hovering a tile shows its
  name and effect.
- Trails and Auras: every owned trail or aura, with its name under the art. Clicking one asks the server to equip
  it (`MarketEquip`). The equipped one has a green border. They are bought in the Market.

## 4. Settings

- It has the same frame as the Backpack (grey checkered header, gear icon, title "Settings", red X).
- Its rows are the existing local settings: Sound, Reduced Effects and Top-Down View. Each row has the
  setting's name on the left and a pill toggle on the right: green "ON" on the right side of the track, or red
  "OFF" on the left side. No new settings are added.

## 5. Potion status

- Each active potion category (strongest tier, as before) shows its bottle icon at the bottom right, left of the
  weather icon. The time left is written under the icon in white outlined text: `9m 33s`, `49m 42s`, or `42s`
  under one minute.
- Hovering an icon (or tapping it on touch) shows the name and the effect, as before.

## 6. No overlap

- No two reachable buttons, panels or labels overlap at any tested viewport, phone landscape included
  (`UiSpec` / `UiResponsive`).
- On phones (viewport height <= 500) the grid tiles and pills shrink.
