# Rebirth panel and Rebirth Points — spec

Owner request 2026-10-15. Must not contradict `docs/GAME_DESIGN_REQUIREMENTS.md` ("Rebirth system").

## Rules (server)

- Requirement: player level >= `LevelConfig.RebirthLevelRequirement(RebirthLevel)` (milestones 10, 25, 50, 75, 100,
  then every 25 forever: 125, 150, ...). There is no maximum rebirth level. Not while auto racing.
  `RebirthService.Rebirth` decides; the client only displays.
- A rebirth resets `leaderstats.Money` and `leaderstats.Speed` to 0, resets `Level` to 1 and `XP` to 0, updates `XPToNext`, and adds 1 to `RebirthLevel`.
- Player list (owner 2026-10-27): `leaderstats.Rebirth` (IntValue, created by `RebirthService.Setup` after Money
  and Speed) always equals the `RebirthLevel` attribute, whoever sets it (rebirth, load, admin commands).
- Automatic bonus (owner 2026-10-27 rev. 2; the x10-per-rebirth growth was too high): the rebirth level sets one
  TOTAL multi for passive Speed Gain and roll Luck, growing by addition. Levels 1-`ADD_UNTIL` (20) add
  `RebirthConfig.EARLY_STEP` = 5 each (1 = 5, 2 = 10, ... 20 = 100); from level 20 on the total is capped at
  x100 (`ADD_UNTIL * EARLY_STEP`; 21, 22, 30 ... stay 100). Level 0 remains 1.00x. Rebirths do not multiply Money.
- Rebirth Points: `RebirthConfig.POINTS_PER_REBIRTH` = 1 (placeholder). Earned stat points =
  car-index points (`GachaConfig.EarnedPoints`) + `RebirthLevel * POINTS_PER_REBIRTH`. Free points
  (`StatPoints`) = earned - allocated. Nothing new is saved (PlayerData VERSION unchanged); on load the
  over-allocation trim counts the saved `RebirthLevel`, so rebirth-funded allocations are never cut.
  `StatPoints` refreshes when `RebirthLevel` changes.

## Panel (`RacerRebirth`, client display only)

Layout follows the owner's reference image: title band "REBIRTH" with close X, then

1. WARNING (red heading): "Rebirth resets your Money and Speed" / "(Robux purchases stay)".
2. REWARDS UNLOCKED (yellow heading): three tiles for the NEXT rebirth, each with an icon and a caption:
   the next rebirth's TOTAL multi (`RebirthConfig.NextMultiplier`, e.g. `x10` at level 1) as `xN Luck`, `xN Speed Gain`, and `+1 Stat Point` (numbers from `RebirthConfig`, never hard-coded in the UI).
3. REQUIREMENTS (purple heading): a progress bar filled `Level / required`, text `"<Level> / <required> Level"`.
   Green fill when met.
4. REBIRTH button: active whenever the requirement is met; shows the server's reply
   ("Reach Level N", "Stop Auto before rebirthing", "REBIRTH COMPLETE").

Built from `ui/specs/RacerRebirth.ui.json` by `ui/tooling/gen_atlas.py`; `RacerUiController` binds the live values.
The panel stays mutually exclusive with Index/Stats/Settings (`PanelSwitch`) and fits the phone variant.
