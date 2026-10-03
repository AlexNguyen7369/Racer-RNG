# Roll animation: build contract (2026-10-02)

> **STATUS (URGENT, 2026-10-02): implemented, pushed to main WITHOUT a green /compat-check (owner exception).**
> Harness roll tests were green before owner decision 6 (constants changed since, not re-run). The UI tests for the final
> design (decisions 4 and 6) have never completed a run. Resume: UI suite -> fix -> full harness -> `/compat-check`.
> Details: `context/ProjectContext.luau` (URGENT block at the top).

The names, numbers and behaviour the tests and the code share for the roll animation. The look and the owner's
decisions are in `docs/ROLL_ANIMATION_SPEC.md` and the design doc's "Roll animation" section; this file fixes what
the first build does. Built test-first (`ui-test-writer` + `test-writer`, red run, implement, `/compat-check`).

## Phases of the build
1. **Placement first.** The compact card moves from the bottom centre to top centre, directly UNDER the Auto Race
   button, and passes every overlap / hitbox check at every viewport (incl. phone landscape). Only then:
2. **Animation.** Pop in, spin reel, land, hold, exit; the enlarged view; rarity effects; turbo; emphasized rolls.

## Not in this build (recorded, later)
Extra Roll passes (2-3 cards), the discovery cutscene, a Reduce-effects settings UI (the client already honours a
LocalPlayer attribute `ReduceEffects = true`: no shake, no flashes), a Garage button (exit flies to INDEX), the bottom
ROLL / Upgrades HUD, per-tier turbo multipliers (turbo stays x5 every 10th roll). The TURBO LUCK bar stays at the
bottom centre (`Client/RollUi`, unchanged).

## Shared/RollAnimConfig (new, pure, shared by client, server and tests)
| Name | Value |
|---|---|
| `POP` / `SPIN` / `LAND` / `EXIT` | 0.15 / 0.8 / 0.15 / 0.15 s |
| `SWITCH` | 0.3 s: compact <-> enlarged (Back easing, slight overshoot; closing is the reverse) |
| `HOLD` | Common 0.3, Uncommon 0.3, Rare 0.4, Epic 0.6, Legendary 1.5, Mythic 2.5, Secret 4 (s) |
| `REEL_CARS` | 6: cars that drive through the reel; the LAST one is the result |
| `LAND_POP` | 1.15: the card pops to 1.15x size on landing, then settles to 1x |
| `COMPACT_WIDTH` | 0.12 of the screen width (owner decision 6), clamped to [`COMPACT_MIN`, `COMPACT_MAX`] = [100, 230] px |
| `COMPACT_HEIGHT` | 66 px: fixed compact roll height (model ~70%, "1 in N" ~30%; an aspect ratio is not in the UI solver's layout model) |
| `COMPACT_GAP` | 8 px from the Auto Race button's bottom edge to the card's top edge |
| `ENLARGED_FACTOR` | 3 (nominal). The enlarged card no longer derives from the compact size: `ENLARGED_WIDTH` = 0.6, `ENLARGED_MAX` = Vector2(780, 336). `RollShowcase/Card` AnchorPoint (0.5, 0.5), Position UDim2(0.5, 0, 0.5, -55), Size UDim2(ENLARGED_WIDTH, 0, 1, -170) + UISizeConstraint MaxSize = ENLARGED_MAX (unchanged geometry) |
| `PANEL_TOP` | 60 + COMPACT_GAP + COMPACT_HEIGHT + 4 = 138 px: the Index panel's top edge (below the compact roll) |

Functions:
- `RollAnimConfig.Hold(rarity) -> seconds` (unknown rarity: Common's).
- `RollAnimConfig.Duration(rarity, emphasized) -> seconds` = POP + SPIN + LAND + Hold + EXIT, plus 2 x SWITCH
  when emphasized (it opens and closes the enlarged view).
- `RollAnimConfig.ExtraPause(rarity, emphasized) -> seconds` = max(0, Duration - GachaConfig.ROLL_INTERVAL).
- `RollAnimConfig.Reel(rng, resultId) -> { id x REEL_CARS }`: the last entry is `resultId`; every other entry is a
  fresh `GachaConfig.Roll(rng, 1)` (the real odds at luck 1, never a planted rare car: no fake near-misses).

## Server
- `GachaConfig.IsEmphasized(id, ownedIds) -> bool` (pure): false if `id` is owned (in `ownedIds`, BEFORE this roll)
  or not rollable. Else, if fewer than 5 rollable cars are owned: true. Else: true only when the car is rarer than
  the player's 5th-rarest owned rollable car (rarer = larger `Chance`; the catch-all has no `Chance` and is the least
  rare). Rarity names are never used.
- `GachaService.Roll(player, roller)` returns `id, isNew, turboMulti, emphasized` and fires
  `Remotes.RollResult:FireClient(player, id, isNew, turboMulti, emphasized)`.
- **Global announcement:** an emphasized roll fires `Remotes.RollAnnounce:FireAllClients(userId, displayName, id,
  rolls)` (rolls = the player's `Rolls` after this roll). `Client/RollAnnounce` shows it in `RBXGeneral` with
  `DisplaySystemMessage`: `"<DisplayName> rolled <Car Name> (<HudFormat.Odds(Chance)>)! Total rolls: <n>"`.
- **Pause during a long animation:** the auto-roll loop waits `ROLL_INTERVAL + RollAnimConfig.ExtraPause(rarity,
  emphasized)` after each roll, so the next roll never covers one still playing.
- **Test seams:** `GachaService.Announce(player, id, rolls)` (Roll calls it through the module table; no-op for
  non-Players), `GachaService.RequestSetAutoRoll(player, value) -> bool` (what the remote calls),
  `GachaService.StartAutoRoll(player, roller?)`, `GachaService.WaitAfter(id, emphasized)`.
- **AUTO toggle:** player attribute `AutoRoll` (bool, true on join, not saved). `Remotes.SetAutoRoll(bool)`
  (validated: booleans only; rate-limited like `AllocateStat`). While false the loop makes no roll and `Rolls` does
  not change.

## Client (Client/RollToast rewritten; Client/RollAnnounce new)
ScreenGui and button names stay as they are, so the existing UI tests keep their meaning.
- **Compact card `RollToast/Toast`** (TextButton, Text ""): AnchorPoint (0.5, 0), top centre, top edge
  `COMPACT_GAP` below `AutoRaceButton/Toggle`'s bottom edge; Size = UDim2(COMPACT_WIDTH, 0, 0, COMPACT_HEIGHT) with a
  UISizeConstraint (MinSize.X = COMPACT_MIN, MaxSize.X = COMPACT_MAX). Shown only while a roll plays
  (Visible = false at rest: no invisible hitbox), hidden only while the enlarged view is open. **Independent of every
  HUD click (owner decision 6):** opening/closing Index, Stats or any panel, or clicking any HUD button, never hides,
  pauses or restarts it (`RollToast/Toast` is no longer in `UiSpec.HiddenWhilePanelOpen`). Only enlarging closes
  panels.
- **Panels make room (owner decision 6):** `IndexUi/Panel` top edge = `PANEL_TOP` (below the compact roll; its
  UISizeConstraint MinSize.Y drops to 110 so it still ends above the bottom strip on a phone). `StatsUi/Panel` keeps
  its top (68) but its width is UDim2(0.44, -150) capped at 300 px, so its left edge stays right of the compact
  roll's right edge (0.56 x screen width) at every viewport. No overlap between the compact roll and either panel. Clicking it
  opens the enlarged view. While `AutoRoll` is false it stays shown with the last result (or "?") and the caption
  `AUTO OFF`, so the enlarged view (and its AUTO button) can always be reached.
- **Enlarged view `RollShowcase`** (Overlay, as now): `Backdrop` (click off the card closes), `Backdrop/Hint`
  "Tap anywhere to close", `Card` centred, and **`AutoButton`** (TextButton, child of `RollShowcase`, bottom centre
  (AnchorPoint (0.5, 1), bottom edge 76 px above the screen bottom, 180 x 44 px) above the Hint and the TURBO LUCK bar: tap-sized on a phone): text `AUTO: ON` / `AUTO: OFF` from the
  `AutoRoll` attribute; clicking it fires `SetAutoRoll(not AutoRoll)` and does NOT close the view. Opening closes
  any panel and enables `Lighting.RollShowcaseBlur`; closing disables it.
- **Compact = no card (owner decision 4, 2026-10-02).** The compact roll is ONLY the car model with its "1 in N"
  under it. `RollToast/Toast` keeps its rect, but its background is invisible and it holds a transparent `Body` that
  fills it with exactly these parts: `Reel` + `Streaks` + `Smoke` (the spin/land play on the bare model), `Viewport`
  (+ `Placeholder` "?") filling the top 70% of the rect, and `Odds` filling the bottom 30% ("1 in 250" / "Common",
  rarity-coloured, italic). Plus the `AutoOff` caption only while AutoRoll is false. NO `Glow`, `CarName`,
  `SpeedMulti`, `Rarity`, `NewBadge`, `TurboBadge`, `TurboFlames`, `Ring`, `Burst`, `Flare`, frame or stroke in the
  compact view. Turbo, NEW and rarity effects show only in the enlarged card.
- **Enlarged card parts** (found by name anywhere in `RollShowcase/Card`): `Glow` (rarity-coloured badge, slowly turning
  UIGradient), `Reel` (ClipsDescendants frame the reel cars drive through, left to right, slowing down), `Viewport`
  (ViewportFrame, the landed car's model from `ReplicatedStorage.CarModels[spec.Model]`, else `Placeholder` "?"),
  `Odds` (italic decal, "1 in 250" or "Common"), `CarName` (bold, dark UIStroke outline), `SpeedMulti`
  ("25x Speed"), `Rarity`, `NewBadge`, `TurboBadge` ("TURBO x5", shown from pop-in on a turbo roll),
  `TurboFlames` (blue flame frame on a turbo roll), `Streaks`, `Smoke` (landing puff), `Ring` (Epic+ pulsing ring),
  `Burst` (Legendary+ radial burst). Secret: a full-screen `Takeover` frame in `RollShowcase` during its hold, tap to
  skip.
- **Observable state** (for tests): `RollToast/Toast` and `RollShowcase/Card` each have attributes `Phase` (`"Idle" | "PopIn" | "Spin" | "Land" | "Hold" |
  "Exit"`), `RollId` (car id of the roll it is playing), `RollSerial` (+1 per RollResult received). The `RollToast`
  ScreenGui has attribute `View`: `"Compact"` or `"Enlarged"`. `Reel` has attribute `ReelIds`
  (comma-separated ids in drive order; last = the result).
- **One roll:** PopIn (card grows from 0 and fades in) -> Spin (REEL_CARS car tiles drive through, each slower) ->
  Land (result brakes into centre, card to LAND_POP x then 1x, Smoke) -> Hold (`Hold(rarity)`) -> Exit (card shrinks,
  a `FlyIcon` (non-interactive, a small car icon, no text) flies to `IndexUi/OpenIndex`, then Phase "Idle" and the compact card hides). A new
  RollResult during a roll restarts the sequence for the new roll (never two rolls at once).
- **Emphasized roll** (`emphasized == true`): the view switches to Enlarged at PopIn and, if the player did not open
  it themselves, back to Compact after Exit. A roll that arrives while Enlarged plays there.
- **Rarity effects** (on landing): Common/Uncommon none; Rare brighter `Streaks`; Epic pulsing `Ring`; Legendary
  `Burst` + gold `Odds` + light shake of the card; Mythic `Burst` + a headlight flare; Secret `Takeover`. With
  `ReduceEffects` no shake and no flashes.
- Effects are 2D (no ParticleEmitters in UI). Layout uses only what the UI test solver supports (UDim2 Position /
  Size, AnchorPoint, UISizeConstraint, UICorner, UIStroke); UIGradient and TextLabel Rotation are visual only.
