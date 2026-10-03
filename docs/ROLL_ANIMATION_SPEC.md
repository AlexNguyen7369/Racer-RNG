# Roll animation and roll UI (QUEUED, not started)

Status: queued 2026-10-02. Source of truth for the look: the "Roll animation" section of the owner's design doc
"Idle Vehicle Simulator — Game Design Requirements" (Claude doc, https://claude.ai/artifact/8T7LeaMi4K41NNGhcACZYP).
This file records the owner's decisions of 2026-10-02 and the conflicts with what is already built. Build it
test-first like the spawn area (test-writer + ui-test-writer first, red run, implement, `/compat-check` ALL GREEN).

## What the design doc asks for (summary)
- **Two views.** Compact (default): just the car model and its "1 in N" at top-center, about 12% of screen width (no card, smaller and always shown, see decisions 4 and 6). Enlarged: a big
  center-screen card about 3x the compact one; the switch takes about 0.3 s with a slight overshoot, closing plays it
  in reverse. In the enlarged view the bottom HUD shrinks to an AUTO toggle.
- **Card:** rarity-colored hexagon badge behind a slowly turning 3D car, italic "1 in N" odds decal, name, the car's
  Speed multi underneath, a Turbo Luck meter under the card.
- **One roll (~1.5 s):** pop in 0.15 s -> spin 0.8 s (5-6 cars drive through and slow down like a slot reel) ->
  land 0.15 s (brakes into the center with a skid, card pops to 1.15x, smoke puff) -> hold 0.3 s (longer for rare)
  -> exit 0.15 s (car icon flies to the Garage button). Must fit the roll interval; shorten the spin first when
  rolls get faster (the upgrade tree goes down to 2 s per roll).
- **Effects by rarity:** glow color per rarity, extras grow with rarity (brighter streaks, pulsing ring, gold burst +
  light screen shake, headlight flare, full-screen takeover for Secret with tap to skip). Hold 0.3 s to 4 s.
- **Turbo rolls** show a blue-flame frame and "TURBO xM" (the tier's multiplier) before the spin.
- **Extra Roll passes:** 2-3 cards at once (compact side by side; enlarged in a row, rarest in the middle).
- **Discovery cutscene:** an undiscovered car with a Speed multi at least 10x the equipped car's plays a 3-4 s 3D
  drive-in once, tap to skip. Needs 3D car models (none yet).
- **Build notes:** the server picks the car, the client only animates; the reel is filled from the real odds (no
  fake near-misses); 2D icons for the spin, a ViewportFrame for the result; TweenService (Back easing), rotating
  UIGradient, UIStroke; no ParticleEmitters in 2D UI (sprite sheets instead); a "Reduce effects" setting (no shake or
  flashes); AUTO and the close area big enough to tap on a phone.

## Owner decisions (2026-10-02)
1. **Emphasized rolls, not "Legendary and up".** A roll is emphasized (plays enlarged, then drops back to compact on
   its own) when the car is **undiscovered** AND its odds are **rarer than the player's 5th-rarest discovered car**
   (while the player has discovered fewer than 5 cars, any undiscovered car counts). The rarity name alone never
   triggers it. Server decides and sends an `Emphasized` flag with the roll result.
2. **Global chat for emphasized rolls.** Every emphasized roll is announced in global chat to everyone in the server:
   player, car, odds and the player's total rolls. Showing other players' data from outside (a card above the head,
   inspect, etc.) is planned for later, not part of this build.
3. **Start state.** New players always start on foot (regular avatar) at the spawn point, with the roll UI in the
   compact view (already true for the avatar since the spawn area build).

4. **Compact = no card (owner, 2026-10-02, later the same day).** An auto roll shows ONLY the car model with its
   "1 in N" odds under it: no card frame, no name, no rarity text, no Speed multi, no description. The card (frame,
   name, rarity, Speed multi, odds, badges) appears only in the enlarged view, after a click on the compact roll.
   The spin/land animation plays on the bare model in compact; the stats appear when it is enlarged.
6. **Smaller, and independent of every HUD click (owner, 2026-10-02).** Today clicking INDEX hides the roll
   animation (the old "hide the toast while a panel is open" rule). New rule: the compact roll keeps playing no
   matter what HUD button is clicked or which panel (Index, Stats, later Upgrades) is open; opening or closing a
   panel never pauses, hides or restarts it. Make it smaller than the 20%-of-width placeholder (target about 12% of
   screen width, readable "1 in N" on phone landscape). So the two never overlap, the panels start BELOW the compact
   roll's area (raise their top margin) instead of the roll hiding. Only the enlarged view (a click on the roll)
   closes open panels.
5. **Scope of the current build (owner):** finish the UI round, then `/compat-check`, and stop there. No further
   features in that build.

## Conflicts with what is built (decided)
1. **Top-center is the Auto Race button.** The compact roll card goes directly UNDER the Auto Race button.
2. **Closing.** Click anywhere off the card closes the enlarged view (no HIDE button), and the screen always says so
   ("Tap anywhere to close"), as the current `RollShowcase` does.
3. **Roll logic follows what is built.** The design doc was updated to match the game: turbo every 10th roll at x5,
   upgrade tiers x10/15, x50/25, x100/40, x1000/100 (docs/UPGRADE_TREE_SPEC.md). Rolls every 3 s, down to 2 s.
4. **UI not built yet (do not overlook when implementing):**
   - The doc's bottom HUD (Garage, ROLL, Upgrades) does not exist. Today: INDEX and STATS on the right column, the
     TURBO LUCK bar and the roll toast at the bottom center, the HUD panel on the left.
   - "Garage" replaces the INDEX button; "Upgrades" comes with the upgrade tree; "ROLL" opens the enlarged view (until
     it exists, clicking the compact card does).
   - The exit animation flies to the Garage button: until Garage exists, fly to INDEX.
   - The compact card under Auto Race must not cover the Index / Stats panels' top margin or the loser screen.
   - Every new button goes into `UiSpec` (ui-test-writer) and must pass the overlap checks at every viewport,
     including phone landscape.

## How it replaces today's roll UI
Today: a bottom-center toast per roll (`Client/RollToast`) that opens the `RollShowcase` overlay (one big card, live,
click off to close) and the `TurboBar` (`Client/RollUi`). The compact card replaces the toast (moves to top-center
under Auto Race); the enlarged view replaces `RollShowcase` (same click-off-to-close and blur); the Turbo Luck meter
moves under the card or stays as the bottom bar (decide with the bottom HUD rework).
