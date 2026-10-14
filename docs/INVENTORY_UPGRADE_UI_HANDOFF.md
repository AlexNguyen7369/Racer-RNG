# Inventory and upgrade UI delivery — 2026-10-14

Review branch: `fix/isaac/hud-text-and-roll-art`, base `39350ed`.
Shared Studio place: `126725530984268` (Racer RNG).

## Changes

- INDEX becomes INVENTORY with CARS / CONSUMABLES header tabs. Existing discovery,
  silhouettes and equip handlers remain; potion quantities, active timers and
  UseBoost intent use the existing server API. Bag button and panel removed.
- STATS and AUTO RACE use the styled white outlined caption, not plain button
  Text. Utility buttons have more spacing, highlights, slight shadows and hover.
- Full-screen hex upgrade tree with dragging, cursor-anchored wheel zoom and
  +/- buttons. No clipping at the heading. Walkspeed nodes hidden; prior saved
  purchases and effects remain valid. Purchases still server-authoritative.
- Compact/enlarged rolls use original illustrated car icons, not model clones.
  Physical racing/equipped Blender models and server gameplay remain untouched.
- Three transparent generated potion icons: Luck `128405731425889`,
  Money `86771144323676`, Speed `79990997148018`.
  Source images and exact prompts: [potions](../ui/icons/potions/README.md).

## Safe collaboration workflow

Studio includes newer Oct13 collaborator weather/leaderboard/duel/pass-car work
not present in this branch's main baseline. Both versions were patched narrowly,
preserving their respective existing source. ProjectContext history is preserved
independently, not copied wholesale from older main into Studio.

Do not start Rojo from this older-baseline branch over the current Studio place.
Review/cherry-pick these UI patches onto the collaborator's current source.
The native place snapshot preserves the entire current Studio state; the branch's
source is a narrow UI patch on main, not an export of all unpublished collaborator
code. StarterGui.rbxm is exported from the updated native snapshot. Shared saving
is separate from publishing; no live publish is authorized or performed.

## Validation

Focused live checks passed: inventory tab clicks, STATS opening, actual race
toggle, upgrade opening/closing and HUD suppression/restoration, +/- and wheel
zoom, dragging, no visible Walkspeed nodes, no roll Model descendants, all three
potion images loaded. No potion deliberately consumed and no player data granted
or reset. Existing Avatar-plugin warnings are unrelated to these UI changes.

Offline checks: Luau compilation, Rojo build, focused four-viewport button tests,
portable UI spec verification and upgrade-chrome generation checks. These are
not the repository's full compatibility suite. StyLua standard gate unavailable;
Selene and current-source UI/multiplayer/world/regression suites remain pending.
UI test contracts need reconciliation by the UI test-writer for the new design
before main merge; do not claim a new ALL GREEN stamp.

## Delivery artifacts

Native backup: `places/RacerRNG_Inventory_UpgradeUI_20261014.rbxl`.
This is the unchanged native `Downloads/racer rng save.rbxl` saved at 00:50 on
Oct14, verified against the six shared UI modules, generated chrome and spec
hashes. It includes the updated Studio ProjectContext and newer collaborator code.
Authored UI: `assets/studio/StarterGui.rbxm`.
Specs: RacerHud, RacerIndex and RacerUpgrades under `ui/specs/`.
Generated potion art: `ui/icons/potions/`; tier labels distinguish I/II/III.
