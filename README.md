# Idle Vehicle Simulator

A Roblox idle racing game where everything feeds one number: **Speed**.

## Project vision

Idle Vehicle Simulator is about watching a number climb and making smart bets to make it climb faster. Players
earn Speed while their car races on its own, race NPCs for Money, roll for faster cars, spend Money on
multipliers, and eventually rebirth for bigger permanent boosts.

**Design pillars** (from `Idle Vehicle Simulator — Game Design Requirements.pdf`):

- **Speed is the score.** Every system either raises Speed gain or is unlocked by it.
- **Progress while idle.** Auto-racing, auto-rolling and (later) the workshop keep paying out while the player is AFK.
- **Push your luck.** Race winnings are banked during a run and lost on a defeat; cashing out is a choice.
- **Resets that feel huge.** Each rebirth wipes Money and Speed and makes the next run dramatically faster.

**The loop:** idle for Speed, race to turn Speed into Money, spend Money on multipliers, roll for faster cars,
then rebirth at a level milestone.

```
Auto race / workshop ──Speed/sec──▶ SPEED ──▶ Race the NPC ladder ──cash out──▶ MONEY
        ▲                                                                         │
        │                     multipliers ◀── upgrades, fuel, auras, spoilers ◀───┘
        ├──────── car multi ◀── auto-roll car gacha (luck, turbo rolls)
        └──────── rebirth multis + stat points ◀── level milestones ◀── XP from Speed
```

**Principles we hold to:**

- **The server decides every number** (Speed, Money, rolls, race results); the client only displays.
- **The car never flips and never leaves its route**, at any stat speed. Tests enforce it.
- **Nothing reaches `main` without a green compatibility check** (`/compat-check`: physics harness, UI, multiplayer, world).
- **Test-first** for every track and every car-physics change (`/build-track`, `/car-loop`).

## Features implemented

Offline reward and gamepass UI (2026-10-28): rounded white racing checks, detailed
animated Shop/Index cards, dragon embers, space layers and scale-only hover.
See [delivery and validation](docs/OFFLINE_GAMEPASS_UI_DELIVERY.md).


Approved HUD icons (2026-10-27): ten simple transparent cartoon icons, including
the red/tan Shop house, brown Items backpack and detailed red Market bag without
a coin. Hover feedback is scale-only (no white box). Source PNGs and Roblox IDs:
[icon art](ui/icons/simple-20261027/README.md). Focused Studio checks passed;
full compatibility was not rerun for this art-only update.

Accessibility and devices (2026-10-26, `docs/HUD_LAYOUT_SPEC.md` section 7): UI motion follows Roblox's Reduced
Motion setting or the in-game REDUCED EFFECTS toggle (tweens land at once, the roll reel lands without spinning),
buttons stay inside the device safe area on notched phones, and panels support gamepads (first button selected,
focus kept in the panel, B closes, selection restored).

Workshop car Showcase (2026-10-22, `docs/WORKSHOP_SPEC.md` section 5b): duplicate rolls are kept as copies (no longer
sold for Money); players pick 3 owned cars in the Workshop panel (or BEST 3), the cars stand on pedestals in their
workshop, and `ShowcaseMulti` (car SpeedMulti x copies, log-damped) multiplies workshop and offline Speed gain.

100-car expansion (2026-10-20, `docs/CAR_EXPANSION_SPEC.md`): 100 new original rollable cars in five families
(Uncommon to 8 Secrets) with Blender-authored part skins; the Index, the roll card and the new Backpack Cars tab (owned
cars, least rare first, click to equip) show each car's own 3D model. Shop gifting of potion products to players in
the server with a durable mailbox for offline delivery (`docs/PANEL_ART_GIFTING_SPEC.md`, save VERSION 10).

Biome drive-by scenery (2026-10-20, `docs/BIOME_DRESSING_SPEC.md`): every track has a theme (Speedway, Forest, Docks,
Suburb, Pirate Coast, City, Desert, Snow, Volcano, Space) dressed with CC0 Kenney / KayKit / Quaternius props:
roadside rhythm, landmarks on corners and crests, horizon silhouettes and a start gate. The art is baked in Blender and
built on each client as EditableMesh near the camera; plain-part fallbacks show everywhere else.
Checkpoints (2026-10-16, `docs/CHECKPOINT_SPEC.md`): a Checkpoints NPC beside the RACE START pavilion (press E)
opens a panel of track cards. Players pick which track their auto race starts on; Track 1 is always open, other
tracks only once beaten (locked cards are dimmed with a lock). A loss and the loop return to the checkpoint; the
choice is saved. Live-checked in Studio; harness and UI tests not written yet.

Shop redesign (2026-10-16, `docs/GAMEPASS_SHOP_SPEC.md`): one scrolling Shop in the style of the references:
FEATURED gamepass cars (Ember Wyvern 1999 R$, Singularity 999 R$), a Gamepasses grid, Potions with a Potion Bundle,
a DOUBLE Server Luck banner and a Codes box. Potion packs are Robux developer products granted once per purchase by
`Server/ShopService` (saved in VERSION 9); codes give potions only. The Market now uses the Backpack look with a
detail pane. Harness shop_purchases 76/76; UI suite and the full compatibility gate not run yet.

HUD redesign (2026-10-15, `docs/HUD_LAYOUT_SPEC.md`): cartoon icon tiles (Index / Stats / Rebirth on the left,
Shop on the right, Items and Upgrade beside the level bar), Roblox-style Daily / Quests / Market pills and a round
Settings button top right, a Backpack with Misc / Trails / Auras tabs, ON/OFF pill toggles in Settings, and potion
bottles with "9m 33s" timers. Every panel opens in one shared band, so nothing overlaps. Checked live on desktop;
the UI test suite and the full compatibility gate have not been run yet.

Rebirth panel (2026-10-15): the REBIRTH panel shows the reset WARNING, the next rebirth's REWARDS (+10% Luck,
+10% Speed Gain, +1 Stat Point) and a player-level REQUIREMENTS bar; each rebirth now grants 1 stat point into the
STATS pool (harness 41/41, ui_rebirth 38/38; full compatibility gate not run).

Design-doc fixes (2026-10-12, NOT yet run in Studio): the design docs are hard rules. A rebirth now resets Money
and Speed; Money comes only from race cash-outs and duplicate car sales (no offline or daily-login Money); saves
are session-locked (VERSION 8, with lifetime MoneyEarned and DuelWins); turbo luck is x10 every 10 rolls, and the
Turbo tiers are 50 / x50, 200 / x200, 500 / x500, 1000 / x1000.
Inventory/upgrade UI (2026-10-14, review branch): CARS and CONSUMABLES tabs,
generated potion bottle icons, spaced/shadowed HUD buttons, illustrated rolls,
and a full-screen draggable/zoomable hex tree. Walkspeed nodes are hidden without
changing saved effects. Focused live checks passed; full compatibility remains
pending. See [delivery notes](docs/INVENTORY_UPGRADE_UI_HANDOFF.md) before syncing.

Auto-race rail (2026-10-11): the server rail follows a smooth Hermite curve through the path, so corners turn
continuously at any Speed stat; harness 31/31, full compatibility gate not run for this change.

Current worktree additions (2026-10-07) still require live compatibility verification: five-track chain,
workshop E upgrades and exact offline earnings, Workshop stat allocation, the hex money-upgrade panel and
hub pad, plus server weather every 15 minutes (five weathers picked with equal chance: Clear, Rain, Night Race, Gold Rush, Aurora; sky, lighting, a bottom-right weather icon with a hover card, and roll odds shown at catalog rarity) and three event-only car variants. Local formatting, lint, compilation
and builds pass; these additions are not a current ALL GREEN stamp. See
[workshop defaults](docs/WORKSHOP_SPEC.md) and [event rules](docs/WEATHER_EVENTS_SPEC.md).

The workshop now uses a Blender-authored mechanical racing garage: open steel
portal, copper framing, warm caged lanterns, workbench/tools, cabinets/tire stacks,
rear flywheel/dyno, cyan chambers and racing signage. Player join/leave assigns
and frees one owned garage per fixed plot; all seven ownership slots were verified
in Studio. Earning regression passed 56/56 and server purchase checks passed.
Client UI navigation remains unverified due to test-client timeouts. Source and
validation notes are in [the workshop spec](docs/WORKSHOP_SPEC.md).

### Draft05 UI and car handoff

The redesigned Racer UI, original car icon atlas, seven rounded Blender car models, uploaded Studio templates, and local place snapshot are included in this branch. See [the handoff notes](docs/DRAFT05_HANDOFF.md) for synchronization and validation limitations before merging or publishing.

### Racing
- **Auto race:** the player's avatar becomes a small blocky car that the server drives along a chain of
  point-to-point tracks (Track 1 Oval, Track 2 Hill), looping back to Track 1 after the last finish. Real
  raycast-suspension physics (`CarPhysics`) steered by `PathDriver` in the right-hand lane.
- **Track rules:** numbered ladder, separate start and finish, each finish is the next track's start, a wide
  checkpoint area with a yellow `$` winnings pad, validated by `TrackValidator` (min radius, closure, no overlap).
- **NPC racers:** one per track (Track 1 red and very easy, faster on every later track), driving the left lane,
  visible only to their owner. Beat the NPC to the finish or lose the run and go back to Track 1.
- **Banked winnings:** each won track adds its pad value to the run's bank (UNBANKED in the HUD); a loss empties
  it, and Stop, death or leaving pays it out.
- **Stability:** flip watchdog that rights the car on the path; tests check up-vector and path deviation at
  normal and maximum stat speed.

### Progression and economy
- **Speed stat** grows while driving, proportional to actual speed with diminishing returns; cruise speed rises
  with the stat up to a cap. Smooth count-up HUD on the left.
- **Money** from race winnings, scaled by track number and the Money multi.
- **Saving:** `PlayerData` saves Money, Speed, cars, equipped car, rolls, stat allocation, upgrades, market inventory, rebirth, boosts, daily-login state, and Level/XP (save version 7).
- **Upgrade tree, phase 1:** pure rules and numbers (`UpgradeConfig`, `UpgradeTree`) for Luck %, roll speed,
  Speed %, turbo tiers, walkspeed and Money %. Server effects and UI are still to come (see TODO).

### Car gacha
- **Free auto-roll** every 3 seconds; rarer cars are checked first with `min(1, luck / chance)`.
- **Seven cars:** Rusty Hatchback (Common) to Void Racer (Secret, 1 in 100,000), each with a Speed multi.
- **Turbo luck:** every 10th roll gets x5 luck, with a filling turbo bar and a "TURBO x5!" pop.
- **Roll animation and showcase:** compact roll toast, click to open a big card with the car model, odds, rarity
  and multi; emphasized rolls announced in chat.
- **Index and stat points:** discovering cars earns stat points to spend on Speed, Money and Luck multis.

### World and UI
- **Spawn area:** purple floor beside Track 1's start; walk onto the green RACE pad (or press Auto Race) to start.
- **Best Roll Ever pedestal:** the rarest car rolled across all servers turns on a platform in the hub, with its
  odds, name and the player's name above it (`docs/LEADERBOARD_SPEC.md` 3a).
- **Gamepass cars:** Ember Wyvern and Singularity on two pedestals beside the Best Roll pedestal; walk up to buy
  or equip (`docs/GAMEPASS_CARS_SPEC.md`). Passes not created yet.
- **Ember Wyvern skin (2026-10-27):** a textured cyan shadow wyvern (MeshParts with colour + normal maps, flapping
  wings on the pedestal), built in Blender by `drafts/cars/ember-wyvern/build_wyvern.py` (`docs/CAR_REDESIGN_SPEC.md` section 9).
- **Ember Wyvern flight (2026-10-27):** the dragon flies while auto racing and on its pedestal: a skinned 33-bone rig
  posed every frame by `Shared/WyvernMotion` (flap bursts and glides, heave, neck and tail waves, bank and head turn into
  curves), shown 2.5x bigger with a long whip tail (`docs/WYVERN_FLIGHT_SPEC.md`), and it breathes blue fire in each
  glide (`docs/WYVERN_BREATH_SPEC.md`). Client-only; the physics body is unchanged.
- **HUD and panels:** Speed HUD, Auto Race button, Index and Stats panels, turbo bar, roll toast and showcase,
  loser screen.
- **Admin chat commands:** `/help /money /addmoney /givemoney /speed /addspeed /givespeed /resetspeed /luck /giveluck /resetluck /weather /give /equip /roll /wipe /tp` for admins only.

### Tooling
- **Test harness** (24 scenarios: physics, tracks, money, race, NPC, bank, gacha, data, admin, multiplayer...)
  and a **UI test suite** checking overlap, hitboxes and that every button does what it shows.
- **Claude Code subagents and slash commands** for test-first track and physics loops and the compat check.
- **Main-branch gate:** `.githooks/pre-push` refuses a push to `main` unless `/compat-check` was ALL GREEN for
  exactly that code.
- **Agent dashboard** (`/dashboard`): subagent progress, changes, commits, compat light, TODO board, feature
  suggestions, "Needs you" tasks and every test explained. Supports workspace-filtered Codex sessions
  alongside Claude, plus a local read/write client (`python3 tools/dashboard/client.py`).
- **Car art pipeline** in Blender (`CAR_MODELING_WORKFLOW.md`); the Rusty Hatchback and the six other Draft05 cars are in the game (`assets/studio/CarModels.rbxm`, shown in rolls and as the racing car's look).

## Future features

The live work queue is the TODO section below. Beyond it, the design document plans these layers:

| Layer | What it adds |
|---|---|
| Upgrade tree (phases 2-3) | Server effects, PlayerData v4 and the hex-tile upgrade UI |
| Mechanical Workshop | A personal base zone that earns Speed while you stand in it, with money upgrades |
| More environments | City, Desert, Snow, Volcano, Space: each a ladder of tracks with faster NPCs |
| Cash out or continue | A real gamble after each win: take the pot home or risk it on a harder race |
| Money shop | Fuel, auras and spoilers, each a Speed multiplier with a visual |
| Levels and rebirth | XP from Speed, rebirths at level milestones, Rebirth Points for permanent stats |
| Vehicle skins | Any car model welded on a shared physics body (`docs/VEHICLE_SKINS_SPEC.md`) |
| Offline earnings | A welcome-back payout for time away, so the AFK kick feels like a reward |
| Monetization | Gamepasses (2x auto-roll, extra rolls, Speed Doubler, 2x Money, luck), Server Luck, odds display and paid-luck compliance |

## TODO

Generated from the team TODO board (`tools/dashboard/data/todo.json`, also shown in the agent dashboard). It
updates automatically whenever the board changes; do not edit this block by hand.

<!-- TODO:START (generated by tools/readme_sync.py from tools/dashboard/data/todo.json; edit the board, not this block) -->

### In progress (22)

- **Harder NPCs, imported NPC car models, wider label**: Owner 2026-10-20: Track 1 NPC 30 studs/s (x2 per track), label 200 studs with NPC RIVAL title, tracks 1-10 skinned with imported catalog cars (NpcConfig.Tracks). Code + docs done; needs full CarTest (npc, bank, multiplayer, weather) and a live look in Studio.
- **Live-check the NPC client view and LoserScreen**: ui-tester / multiplayer-tester have not checked them live.
- **Automatic bus delivery for Codex**: Claude receives bus messages via a hook; Codex only when it follows AGENTS.md and runs agent_bus.py context. If the Codex CLI's hook support covers session start / prompt submit, wire `agent_bus.py hook --agent codex` there. Also: edits made via shell commands (sed, heredoc, python rewrites) are not attributed; consider attributing via git diff snapshots per tool call. 2026-10-11: wired in .codex/hooks.json (SessionStart, UserPromptSubmit) and shell-edit attribution added (agent_bus.py shell, Pre/PostToolUse in both agents). Codex does not run the project hook until the developer trusts it (Needs you: codex-trust-bus-hook), so delivery is not verified yet.
- **HUD redesign: icon tiles, top-right pills, Backpack, Settings pills, potion timers**: docs/HUD_LAYOUT_SPEC.md. Code done and checked live on desktop; waiting on the UI test update (ui-test-writer), a phone-viewport check and /compat-check.
- **Shop redesign + Robux potions + codes + Market restyle**: Shop sections per images/UI_ShopReference1-4 (Featured cars 1999/999, Gamepasses, Potions + bundle, Server Luck, Codes); Server/ShopService receipts + codes (save VERSION 9); Market in the Backpack look. Harness shop_purchases 76/76. Pending: UI suite, phone viewport, /compat-check. 2026-10-20: shop_purchases 76/76 live; Market tab-rail + render-on-show fixed; ui_market fixtures updated for the PanelFrame close/price row. Left: hitbox backdrop decision, /compat-check.
- **Biome drive-by scenery on all 10 tracks (Kenney / itch.io CC0)**: docs/BIOME_DRESSING_SPEC.md, branch feature/alex/biome-drive-by-scenery. Built: 10 themes, generic BiomeDressing + Prune, 24 CC0 packs baked to runtime EditableMesh props (Client/BiomeMeshes), environment test green. Left: owner enables Mesh / Image APIs (Needs you), merge to main, visual tuning of Prune losses on tracks 1/4/5, art for the props that are still plain parts.
- **Biome drive-by scenery**
- **100-car expansion + Index/Backpack car models**: Done 2026-10-20: 100 cars + Blender art (detail pass), Index/roll card/Backpack Cars tab show models, harness car_expansion 2692/2692, ui_backpack_cars + ui_car_icons green. Left: phone-landscape ui-tester pass, /compat-check, commit.
- **Shop gifting (potions) with durable mailbox**: GiftService/GiftMailbox/GiftPicker, save VERSION 10. gifting 30/30, gift_mailbox 25/25 live 2026-10-20. Left: UI pass of the gift picker, /compat-check, real dev product ids.
- **Panels dim only the world; HUD stays bright**: Owner 2026-10-20 (HUD_LAYOUT_SPEC 6): HudChrome/PanelDim (DisplayOrder 0) replaces the per-HUD veils; Shop/Market/Daily backdrops transparent. Code done; ui-test-writer updating PanelDimmers checks; UI suite not run yet.
- **Checkpoint and Quest panels use the Backpack look**: Owner 2026-10-20: CheckpointUi on PanelFrame (flag icon), navy/blue tiles; quest rows/tabs/detail in Backpack colours + Fredoka. Not checked visually in Studio yet.
- **Sharper, more unique car models**: Owner 2026-10-20: build_expansion_cars.py shell rewritten (chamfered shoulders, wedge nose, fastback/Kamm/ducktail, tapered glass, seeded proportions/paint); all 100 re-authored. Blender preview wedge mesh fixed (was upside down). The 7 Draft05 MeshPart cars are NOT changed: need new meshes uploaded by hand.
- **Singularity: sharp supercar, playable after purchase, admin access**: Owner 2026-10-20: new singularity_recipe (69 parts) exported to ExpansionCarModels/singularity.rbxmx; admins own every pass car (PassCarService); Shop Featured button equips owned cars; Backpack Cars lists owned pass cars. Verified live: admin gets Pass_singularity, Equip works. GamepassId still 0 (owner must create the pass).
- **Car art redesign: 111 MeshPart skins from the concept renders**: docs/CAR_REDESIGN_SPEC.md. All 111 cars built, uploaded and synced (assets/studio/RedesignCarModels). Review page: https://claude.ai/artifact/X5NTsqk2FWamprTYyRwpHQ. Left: owner review of the 100 expansion cars, run car_redesign + gacha + weather + car_size in Studio, commit.
- **Workshop car Showcase (dupes kept as copies)**: Owner 2026-10-22: duplicates are never sold; 3 player-picked cars stand in the workshop and multiply workshop Speed gain by SpeedMulti x copies (docs/WORKSHOP_SPEC.md 5b). Code + docs done; Studio harness/UI runs and balance pending.
- **Honour Reduced Motion in UI animations**: Owner rule 2026-10-26 (HUD_LAYOUT_SPEC 7). Implemented: Client/UiMotion (ReducedMotionEnabled or ReduceEffects) routes UI tweens; reel spin, fly icon, ring pulse and streak loops skip. Needs a Studio check and ui-test-writer coverage.
- **Gamepad / console focus for panels**: Owner rule 2026-10-26 (HUD_LAYOUT_SPEC 7). Implemented in Client/PanelSwitch: first button selected, AddSelectionParent trap, ButtonB closes, selection restored. Needs a Controller Emulator check and ui-test-writer coverage.
- **Safe-area policy for IgnoreGuiInset GUIs**: Owner rule 2026-10-26 (HUD_LAYOUT_SPEC 7). Implemented: Client/SafeInsets sets DeviceSafeInsets on every PlayerGui ScreenGui except PanelDim, LoserScreen, RollShowcase. Needs a notched-phone Device Simulator check.
- **VFX showcase area (/tp vfxarea, /tp home)**: Owner 2026-10-26. Shared/VfxArea floor at (1600,0,0), Client/VfxShowcase local cars per trail/aura, CarService.Teleport + admin /tp vfxarea \| home. Verified live. Next: run admin + vehicle_effects in the full harness; test-writer may add admin checks for the two new /tp forms.
- **Bigger scenery in mass + detailed City skyscrapers**: Owner 2026-10-27: design doc Track environments (scale and detail), BIOME_DRESSING_SPEC Rules Budget 1200 / Scale (Landmarks x1.75, Horizon x2 with 0.25 shrink steps, Scatter x1.5) / City skyscrapers. BiomeThemes skyscraper helper (podium, setbacks, window bands, fins, neon crown, rooftop tank/spire/antenna), Billboard moved to City scatter. environment 338/338, full harness 50/0. Left: owner look while racing, device frame check (Needs you).
- **Ember Wyvern flight**: Owner 2026-10-27: no flying animation while auto racing; bigger (exception) on the pedestal and in races; dynamic wing flaps and body motion; physics test suite. Spec docs/WYVERN_FLIGHT_SPEC.md. Done: 33-bone rig (drafts/cars/ember-wyvern/wyvern_rig.py), rigged upload Model 110915918385893, Shared/WyvernMotion, Client/WyvernAnimator, SkinScale 1.6 (placeholder), wyvern_flight scenario red then 106/106 green alone; live: flaps and heaves while racing and on the pedestal. Then (owner): livelier body, long tail, SkinScale 2.5 (pedestal cap 1.6), blue fire breath (WYVERN_BREATH_SPEC). Owner: implement first; tests written (wyvern_flight, wyvern_breath, pass_cars, car_redesign updated) but not run since. Next: full suite, then selective commit and push to main.
- **Car redesign v3 toy racer**: Owner 2026-10-27: all 111 cars as toy racers (15,000 tris), pilot approved; Singularity orb spins / bobs / glows. Built, uploaded, rbxmx + orb code done (CAR_REDESIGN_SPEC 10-11). Left: full suite with Studio free (car_redesign, singularity_orb, pass_cars, showcase), owner look in Studio, merge.

### Up next (9)

- **Daily Quest System**: Add a daily quest system with rotating objectives and rewards; define the design/spec before implementation.
- **Redeem Codes section**: Add a Redeem Codes section projected for the Shop area where the gamepasses are located.
- **Friends-in-server boost**: +10% luck and Money per friend in the same server, up to +40%. Fits this game: Encourages inviting friends; one multiplier in GachaService and MoneyService. Inspired by: Common in 2025-2026 simulators
- **roll_odds_* UI fixtures must close open panels first**: The offline RacerWelcome/Panel opens on join and hides the compact roll (correct behaviour), so roll_odds_compact_odds fails although the text is right. ui-test-writer: have the fixture or ui_roll_odds close every PanelSwitch panel before the planted roll. 2026-10-27: ui-test-writer closes every PanelSwitch panel before the planted roll; not run live yet.
- **DailyBoosts Status overlaps Daily Rewards / Bag on phones**: Bug 3a6d9cb3, found by ui-tester 2026-10-13 at 844x390 and 667x375. Older than the weather change.
- **Run the UI suite for the removed world upgrade pad**: upgrade_no_world_pad and upgrade_no_spawn_area_pad (ui_upgrades) were written 2026-10-13 and never run. Run [UITEST] alone in Studio.
- **Reconcile UI tests with Isaac's inventory/upgrade-tree UI (ccea607)**: ui-test-writer updates UiSpec/UiScenarios for INVENTORY tabs, removed Bag, full-screen hex upgrade tree; then ui-tester and /compat-check. Blocks the green stamp for main.
- **Checkpoint tests (harness + UiSpec)**: test-writer: checkpoint scenario (validation, start track, loss resets to checkpoint, loop). ui-test-writer: CheckpointUi in UiSpec (overlap, locked cards, phone landscape). docs/CHECKPOINT_SPEC.md.
- **Shop/Market panels cover the compact roll toast**: ui_hitboxes button_topmost_at_centre_shop_open/market_open: RollToast/Toast under the panel. PanelBand top = below Race button; the compact roll also sits below Race. Owner: band below the compact roll, or panel over the dimmed toast?

### Backlog (future work) (11)

- **static_settle cold-start flake**: Failed 4 of ~8 cold starts (0.58-0.78 vs 0.5). DampingRatio raised to 1.0, not yet re-verified.
- **Slack bot setup for test results**: Revoke the exposed token, install the app with bot scopes, re-add the MCP, post results after each green run.
- **Weighted weather chances (bigger benefit, lower chance)**: Design doc "Weather events", planned by the owner 2026-10-13. The pick is uniform (1 in 5) until the owner sets the weights.
- **Image icons for the weather icon**: The icon uses text glyphs (WeatherConfig.Events[id].Icon). Replace with uploaded image icons when art exists.
- **Wing flap and fire on the Ember Wyvern while racing**: Pedestal animation exists (Client/BestRollView). The race skin is welded with WeldConstraints in CarAppearance, so the wings are static in races. Needs its own test round (VEHICLE_SKINS_SPEC).
- **Final meshes for Ember Wyvern and Singularity**: Current models are Part-built stand-ins from Shared/DraftCarModels. A real model with the same name in CarModels replaces them. Concepts in drafts/cars/.
- **Re-bake StarterGui.rbxm with the new RacerRebirth panel**: The baked RacerRebirth still has the old spec hash; Bind rebuilds it from code at runtime. Bake it in Studio Edit and export assets/studio/StarterGui.rbxm.
- **Restyle the Daily, Quests, Shop and Market panels to the Backpack frame**: They still use the plain dark Gotham modal; the owner gave references only for their buttons.
- **Icon art for trails and auras in the Backpack**: Backpack shows a colour streak / orb swatch until real art exists.
- **Build Server Luck (2x/4x/8x developer products)**: Design doc lists it; the Shop shows it as Coming soon (no Grants, receipt never granted).
- **Gift buttons in the Shop**: References show gift buttons; not built.

### Recently done (57)

- ~~Biome visual pass: scatter + ground patches, horizon fit, landmark particles, oriented-box Prune~~ (2026-10-27)
- ~~Ember Wyvern skin: cyan shadow wyvern in Studio (draft 4 approved)~~ (2026-10-27)
- ~~Ember Wyvern blue-fire effects~~ (2026-10-27)
- ~~Market trail / aura VFX redesign (all six)~~ (2026-10-26)
- ~~Rendering pass + car finish (lighting baseline, Asphalt/Concrete, LOD, glossy car finish)~~ (2026-10-26)
- ~~Race progress map completion~~ (2026-10-21)
- ~~Gate signs: biome + recommended Speed~~ (2026-10-21)
- ~~Shown Speed = base x car multi; cruise from shown Speed~~ (2026-10-21)
- ~~Rebalance NPC speeds vs cruise curve~~ (2026-10-21)
- ~~Decide: Shop/Market/Daily backdrops cover the HUD tiles~~ (2026-10-20)

<!-- TODO:END -->

## Getting started

Needs Roblox Studio with the Rojo plugin and the Roblox Studio MCP, plus `stylua`, `selene` and `python3`
(and the Blender MCP for art work).

```
git config core.hooksPath .githooks   # once per clone (Claude Code does this for you)
rojo serve                            # then click Connect in Studio's Rojo plugin
stylua src                            # format
selene src                            # lint
python3 tools/dashboard/server.py     # agent dashboard at http://127.0.0.1:8765
```

Run the test harness during play with `ReplicatedStorage:SetAttribute("CarTestRun", true)`; results print as
`[CARTEST]` lines in the Studio console.

## Project layout

| Path | What lives there |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared`: car physics and config, tracks, gacha and upgrade rules |
| `src/server` | `ServerScriptService.Server`: race, car, money, gacha, upgrade, admin services, saving, test harness |
| `src/client` | `StarterPlayerScripts.Client`: HUD, panels, roll UI, NPC view, UI tests |
| `docs/` | Feature specs (spawn and rolls, NPC racers, admin commands, roll animation, upgrade tree, vehicle skins) |
| `tools/` | Compat gate (`compat.py`), agent dashboard, README sync |
| `blender/`, `assets/`, `references/`, `drafts/` | Car art pipeline and rough drafts |
| `context/ProjectContext.luau` | Collaborator context synced into Studio: rules, change log, latest test results |

More detail for contributors and Claude Code is in `CLAUDE.md`; progress history is in `current_progress.md`.
