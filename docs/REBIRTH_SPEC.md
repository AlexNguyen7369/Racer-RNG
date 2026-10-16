# Rebirth panel and Rebirth Points — spec

Owner request 2026-10-15. Must not contradict `docs/GAME_DESIGN_REQUIREMENTS.md` ("Rebirth system").

## Rules (server)

- Requirement: player level >= `LevelConfig.RebirthLevelRequirement(RebirthLevel)` (milestones 10, 25, 50, 75, 100,
  then every 25). Not while auto racing. `RebirthService.Rebirth` decides; the client only displays.
- A rebirth resets `leaderstats.Money` and `leaderstats.Speed` to 0 and adds 1 to `RebirthLevel`.
- Automatic bonus per rebirth: `RebirthConfig.GAIN_PER_LEVEL` passive Speed gain and
  `RebirthConfig.LUCK_GAIN_PER_LEVEL` roll luck (both +10% now, placeholders).
- Rebirth Points: `RebirthConfig.POINTS_PER_REBIRTH` = 1 (placeholder). Earned stat points =
  car-index points (`GachaConfig.EarnedPoints`) + `RebirthLevel * POINTS_PER_REBIRTH`. Free points
  (`StatPoints`) = earned - allocated. Nothing new is saved (PlayerData VERSION unchanged); on load the
  over-allocation trim counts the saved `RebirthLevel`, so rebirth-funded allocations are never cut.
  `StatPoints` refreshes when `RebirthLevel` changes.

## Panel (`RacerRebirth`, client display only)

Layout follows the owner's reference image: title band "REBIRTH" with close X, then

1. WARNING (red heading): "Rebirth resets your Money and Speed" / "(Robux purchases stay)".
2. REWARDS UNLOCKED (yellow heading): three tiles for the NEXT rebirth, each with an icon and a caption:
   `+10% Luck`, `+10% Speed Gain`, `+1 Stat Point` (numbers from `RebirthConfig`, never hard-coded in the UI).
3. REQUIREMENTS (purple heading): a progress bar filled `Level / required`, text `"<Level> / <required> Level"`.
   Green fill when met.
4. REBIRTH button: active only when the requirement is met (and below `MAX_LEVEL`); shows the server's reply
   ("Reach Level N", "Stop Auto before rebirthing", "REBIRTH COMPLETE").

Built from `ui/specs/RacerRebirth.ui.json` by `ui/tooling/gen_atlas.py`; `RacerUiController` binds the live values.
The panel stays mutually exclusive with Index/Stats/Settings (`PanelSwitch`) and fits the phone variant.
