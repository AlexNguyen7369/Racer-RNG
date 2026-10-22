# Rebirth panel and Rebirth Points — spec

Owner request 2026-10-15. Must not contradict `docs/GAME_DESIGN_REQUIREMENTS.md` ("Rebirth system").

## Rules (server)

- Requirement: player level >= `LevelConfig.RebirthLevelRequirement(RebirthLevel)` (milestones 10, 25, 50, 75, 100,
  then every 25 forever: 125, 150, ...). There is no maximum rebirth level. Not while auto racing.
  `RebirthService.Rebirth` decides; the client only displays.
- A rebirth resets `leaderstats.Money` and `leaderstats.Speed` to 0, resets `Level` to 1 and `XP` to 0, updates `XPToNext`, and adds 1 to `RebirthLevel`.
- Automatic bonuses compound per rebirth. The next-rebirth factors for levels 1-6 are
  `5x, 7.5x, 7.5x, 10x, 10x, 7.5x`; level 7 onward repeats 7.5x. The same staged factors apply
  to passive Speed Gain and roll Luck, so level `n` is the product of the first `n` factors; level 0
  remains 1.00x. The effective result is capped only at `1e100` for numeric safety at absurd rebirth
  counts. Rebirths do not multiply Money.
- Rebirth Points: `RebirthConfig.POINTS_PER_REBIRTH` = 1 (placeholder). Earned stat points =
  car-index points (`GachaConfig.EarnedPoints`) + `RebirthLevel * POINTS_PER_REBIRTH`. Free points
  (`StatPoints`) = earned - allocated. Nothing new is saved (PlayerData VERSION unchanged); on load the
  over-allocation trim counts the saved `RebirthLevel`, so rebirth-funded allocations are never cut.
  `StatPoints` refreshes when `RebirthLevel` changes.

## Panel (`RacerRebirth`, client display only)

Layout follows the owner's reference image: title band "REBIRTH" with close X, then

1. WARNING (red heading): "Rebirth resets your Money and Speed" / "(Robux purchases stay)".
2. REWARDS UNLOCKED (yellow heading): three tiles for the NEXT rebirth, each with an icon and a caption:
   the next factor's `xN Luck`, `xN Speed Gain`, and `+1 Stat Point` (numbers from `RebirthConfig`, never hard-coded in the UI).
3. REQUIREMENTS (purple heading): a progress bar filled `Level / required`, text `"<Level> / <required> Level"`.
   Green fill when met.
4. REBIRTH button: active whenever the requirement is met; shows the server's reply
   ("Reach Level N", "Stop Auto before rebirthing", "REBIRTH COMPLETE").

Built from `ui/specs/RacerRebirth.ui.json` by `ui/tooling/gen_atlas.py`; `RacerUiController` binds the live values.
The panel stays mutually exclusive with Index/Stats/Settings (`PanelSwitch`) and fits the phone variant.
