# Rebirth panel and Rebirth Points — spec

> Worlds (owner 2026-10-27, `docs/WORLDS_SPEC.md`): rebirths 1-10 happen in World 1, 11-20 only in World 2. World 1
> refuses a rebirth at RebirthLevel 10 with "Unlock World 2" and its panel points to the portal.
> Interim rule (owner 2026-10-28): until WorldService and World 2 ship, the single place allows rebirths 1-20
> and refuses only at 20 ("Max rebirth"); the World 1 cap at 10 starts with the World 2 release.

Owner request 2026-10-15. Must not contradict `docs/GAME_DESIGN_REQUIREMENTS.md` ("Rebirth system").

## Rules (server)

- Requirement: player level >= `LevelConfig.RebirthLevelRequirement(RebirthLevel)`. Rev. 4 (owner 2026-10-27, the
  "+1 Speed" genre table): 15, 25, 40, 60, 75, 100, 125, 150, 175, 200, 225, 260, 300, 340, 380, 420, 465, 510, 560,
  600. Rebirth 20 is the maximum (`RebirthConfig.MAX_LEVEL`; reply "Max rebirth", panel shows MAX REBIRTH). Not
  while auto racing.
  `RebirthService.Rebirth` decides; the client only displays.
- A rebirth resets `leaderstats.Money` and `leaderstats.Speed` to 0, resets `Level` to 1 and `XP` to 0, updates `XPToNext`, and adds 1 to `RebirthLevel`.
- Player list (owner 2026-10-27): `leaderstats.Rebirth` (IntValue, created by `RebirthService.Setup` after Money
  and Speed) always equals the `RebirthLevel` attribute, whoever sets it (rebirth, load, admin commands).
- Automatic bonus rev. 4 (owner 2026-10-27, replaces rev. 2 and 3 below): `RebirthConfig.TOTALS`, one TOTAL multi
  per rebirth level for Speed Gain, XP gain (XP follows the Speed gain multi) AND roll Luck: 1.5, 2, 2.5, 3, 3.5,
  4, 5, 6, 7.5, 10, then x10 per rebirth: 100, 1k, 10k, ... 100b at rebirth 20. Level 0 = 1. Shown as "x1k", "x100b".
- (Superseded) Automatic bonus (owner 2026-10-27 rev. 2; the x10-per-rebirth growth was too high): the rebirth level sets one
  TOTAL multi for passive Speed Gain and roll Luck, growing by addition. Rev. 3 (owner 2026-10-27, +5 was too
  slow): levels 1-`ADD_UNTIL` (40) add `RebirthConfig.EARLY_STEP` = 25 each (1 = 25, 2 = 50, ... 40 = 1000); from
  level 40 on the total is capped at x1000 (`ADD_UNTIL * EARLY_STEP`; 41, 50 ... stay 1000). Step and cap are
  placeholders. Level 0 remains 1.00x. Rebirths do not multiply Money.
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
