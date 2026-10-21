# Checkpoints: pick the starting track (contract for tests and implementation)

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
5. **Saved.** `Checkpoint` is saved (PlayerData, still VERSION 9: an additive field, `docs/SAVE_SPEC.md` 2b). Missing = 1. A rebirth keeps it.
   A saved value above `Max` is still saved but Rule 3 clamps it.
6. Duels and admin `/tp` are unchanged (duels pick their own track; `/tp` jumps inside the current run).

## 2. World

- `Shared/SpawnArea` builds `SpawnArea.Checkpoints` (Model "CheckpointNpc") at hub-local `CheckpointConfig.NPC_POS`
  (in front of the pavilion's -Z entrance, beside Track 1's wall), facing the hub centre: an anchored R15 rig,
  a neon purple ring under it, a BillboardGui "Checkpoints" / "Choose your start", and a `ProximityPrompt`
  `OpenCheckpoints` (E, ActionText "Checkpoints", `MaxActivationDistance` 10). Never overlaps a track or the pad.

## 3. UI

- `Client/CheckpointUi`: ScreenGui `CheckpointUi`, panel registered with `PanelSwitch` as `"Checkpoints"`, sized by
  `PanelBand`. The prompt toggles it; Escape / the X button closes it.
- Owner 2026-10-20: it uses the Backpack look (`docs/HUD_LAYOUT_SPEC.md` section 3): `PanelFrame` header (purple
  gradient, finish-flag icon, red X), navy cards with a blue glow border, green border on the selected checkpoint.
- One card per track in `Number` order: track number, track name, payout (`TrackBuilder.CashFor`). The current
  checkpoint shows "SELECTED"; an open card shows "SELECT". A locked card is dimmed (40% transparency) with a lock
  icon over it and "Beat Track n" text; clicking it does nothing.
