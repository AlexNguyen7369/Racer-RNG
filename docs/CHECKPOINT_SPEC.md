# Checkpoints: pick the starting track (contract for tests and implementation)

> Worlds (owner 2026-10-27, `docs/WORLDS_SPEC.md`): checkpoints and BestTrack are per world; each place lists only
> its own world's tracks.

Owner brief (2026-10-16, reference `images` in the request: a hub NPC with an E prompt, like "Shadow Trials"):
a "Checkpoint" NPC beside the RACE START pavilion. Players choose which track (checkpoint) their run starts on.
A track must be beaten before it can be picked; locked cards are dimmed with a lock over them.
Design rule: `docs/GAME_DESIGN_REQUIREMENTS.md`, "Racing", "Checkpoints".

Owner answers (2026-10-16): beaten tracks only; a loss goes back to the checkpoint; saved; the loop after the
last track goes back to the checkpoint.

## 1. Rules

1. **Unlocked.** Track 1 is always open. Track `n > 1` is open when `BestTrack >= n` (`BestTrack`: the highest track
   the player has won, `UpgradeService`). `CheckpointConfig.Max(bestTrack, trackCount) = clamp(bestTrack, 1,
   trackCount)` is the highest track that can be picked.
2. **Pick.** Remote function `Remotes.SetCheckpoint(n)`: the server accepts an integer `1 .. Max` only, sets the
   player attribute `Checkpoint = n` and returns `true`; anything else changes nothing and returns `false, reason`.
   Rate-limited (`CheckpointConfig.PICK_COOLDOWN`). Picking does not move a car already racing; it applies to the
   next run.
3. **Start.** Every NPC run (`CarService`, StartPad or Auto Race button) starts on the effective checkpoint
   `CheckpointConfig.Effective(Checkpoint, BestTrack, trackCount) = clamp(Checkpoint, 1, Max)`: the car is built at
   that track's start (`START_AHEAD` in, in the lane) and that track's NPC race starts. Earlier pads count as paid.
4. **Loss and loop.** A loss resets the car to the start of the run's start track (Reset event `Track` = that
   track) and its race starts again. After winning the last track the car goes back to the start track too.
5. **Saved.** `Checkpoint` is saved in the current PlayerData VERSION 11 schema (additive field; older saves default
   to 1). A rebirth keeps it.
   A saved value above `Max` is still saved but Rule 3 clamps it.
6. Duels and admin `/tp` are unchanged (duels pick their own track; `/tp` jumps inside the current run).

## 2. World

- `Shared/SpawnArea` builds `SpawnArea.Checkpoints` (Model "CheckpointNpc") at hub-local `CheckpointConfig.NPC_POS`
  (in front of the pavilion's -Z entrance, beside Track 1's wall), facing the hub centre: an anchored R15 rig,
  a neon ring under it (purple; teal (40, 200, 190) from the 2026-10-30 paddock redesign,
  `SPAWN_AND_ROLLS_SPEC.md` 1b.3, placeholder), a BillboardGui "Checkpoints" / "Choose your start", and a `ProximityPrompt`
  `OpenCheckpoints` (E, ActionText "Checkpoints", `MaxActivationDistance` 10). Never overlaps a track or the pad.

## 3. UI

- `Client/CheckpointUi`: ScreenGui `CheckpointUi`, panel registered with `PanelSwitch` as `"Checkpoints"`, sized by
  `PanelBand`. The prompt toggles it; Escape / the X button closes it.
- Owner 2026-10-20: it uses the Backpack look (`docs/HUD_LAYOUT_SPEC.md` section 3): `PanelFrame` header (purple
  gradient, finish-flag icon, red X), navy cards with a blue glow border, green border on the selected checkpoint.
- One card per track in `Number` order: track number, track name, payout (`TrackBuilder.CashFor`). The current
  checkpoint shows "SELECTED"; an open card shows "SELECT". A locked card is dimmed (40% transparency) with a lock
  icon over it and "Beat Track n" text; clicking it does nothing.

## 4. Cards and detail pane (owner 2026-10-27, replaces the card content of section 3)

- The panel has the card grid on the left and a detail pane on the right (on narrow panels the grid uses 2
  columns instead of 3). Same `PanelFrame` look, theme of docs/HUD_LAYOUT_SPEC.md section 8.
- Each card (`Track_n`, a button) shows a small live 3D preview of its biome (`Preview`, a ViewportFrame: the biome's
  ground, a strip of road, its gate colours and 2-3 of its own props from `Shared/BiomeThemes`), `TRACK n` and the
  biome name (`Biome`, e.g. "PIRATE COAST"). Locked cards keep the dim and lock of section 3 but can still be clicked.
- Clicking a card no longer picks it: it shows that track in the detail pane (`Detail`): a larger preview, `TRACK n
  · NAME`, the biome, `REC. SPEED` (the recommended Speed: the stat whose cruise speed matches that track's NPC,
  `RaceConfig.StatFor(NpcConfig.For(n).Speed)`, the same number as the track's gate sign), `YOUR SPEED`, a status
  chip (`READY` when the player's Speed is at least the recommendation, else `NEED <x> MORE`), the payout and one
  button `Start` with the text `START HERE` (open, not the checkpoint), `SELECTED` (the current checkpoint,
  disabled) or `LOCKED` (disabled). `START HERE` calls `Remotes.SetCheckpoint(n)` exactly as a card click did.
- On open, the detail pane shows the current checkpoint. Numbers use `HudFormat` (lowercase suffixes).
- Motion (HUD_LAYOUT_SPEC section 10): the selected card's preview and the detail preview turn slowly; previews do
  not turn while motion is reduced or the panel is hidden. The detail pane slides in when the shown track changes.
- Presentation only: the server still decides the pick (section 1).
