# Timed nitro boost

Requested by Vic2CS, 2026-11-19, on branch `feature/vic2cs/dev-changes`; playtest follow-up 2026-11-20 (miss lock,
gold zone, saved time, no presses once a race is decided). Not yet reviewed by the owner.
Rule source: `docs/GAME_DESIGN_REQUIREMENTS.md`, "Timed nitro boost". It is a proposed exception to the owner's
"one steady speed" rule (2026-10-20).

## Behaviour

- While the player is auto racing, `Client/NitroInput` shows the `NitroBar` ScreenGui just above the HUD's
  `RacerHud.Speed` readout: a dark bar with a green zone, a gold centre and a white needle.
- The needle sweeps left -> right -> left at a constant rate, once per `NitroConfig.PERIOD` (1.6 s). It starts at the
  left edge when the bar becomes ready.
- Press: Space, a left click on the world (not on a button), a click or tap on the bar itself, or gamepad X / R1.
  Typing in chat never presses.
- Target (Vic2CS 2026-11-19): the green and gold zones are centred on the player attribute `NitroTarget`, a new
  random spot for every bar (`NitroConfig.NewTarget`): within `TARGET_RANGE` (1 - GOOD_ZONE, so the green zone always
  fits on the bar) and at least `TARGET_MIN_MOVE` (0.3) from the previous target. The server picks the next target
  when it grades a press (and when auto racing starts); the client keeps drawing the old zones until the next bar is
  ready, so the press marker is seen against the zones it was graded on.
- Press marker: `Bar/PressMark` (pink, white outline) appears at the press position at once and moves to the server's
  graded position (`NitroPressPos`); it stays until the next bar is ready.
- Size: the bar is 340 x 34 px with a 20 px label above it.
- Grades (needle position -1..1, `NitroConfig.Grade(position, target)`, measured from the target):
  - Perfect: within `PERFECT_ZONE` (0.11, Vic2CS 2026-11-20, was 0.08) of the target -> cruise speed x
    `PERFECT_MULTI` (1.7).
  - Good: within `GOOD_ZONE` (0.3) -> x `GOOD_MULTI` (1.4).
  - Miss: anywhere else -> the bar is locked for `MISS_COOLDOWN`, which is `RECHARGE` (6 s; Vic2CS 2026-11-20, was
    2 s): a miss costs as much as a boost's recharge, so spamming no longer pays.
- A boost lasts `DURATION` (2 s); the bar then recharges for `RECHARGE` (6 s). The bar is first ready `START_DELAY`
  (2 s) after auto racing starts. A press while charging, locked or boosting does nothing.
- Feedback: the label shows "NITRO READY", "PERFECT! x1.7", "NITRO x1.4", "MISS" or "NITRO CHARGING", and for
  1.5 s after a boost ends "SAVED 1.4 s" (see "Saved time"); the bar fills while charging and drains while boosting;
  the camera's field of view widens by 8 degrees during a boost.
- The bar hides while a panel, the roll showcase or the loser screen (`LoserScreen`) covers the screen.
- All numbers are placeholders.

## Saved time

- A boost of multi `m` held for `b` seconds of run time covers `(m - 1) x b` seconds of extra cruise distance, so at a
  constant cruise speed it saves `(m - 1) x b` seconds of track time: `NitroConfig.SavedSeconds(m, b)`. A full boost
  saves 0.8 s (Good) or 1.4 s (Perfect) with the placeholders.
- `Server/NitroService` watches each boost it starts (`run.NitroLeft` every frame). When it ends it sets
  `NitroSaved` = `SavedSeconds(multi, boosted)` and then `NitroSavedAt` = the end's server time (it changes once per
  boost, so two equal savings in a row both show). `boosted` is `DURATION` when the boost counted down to 0, and the
  part really driven when a reset (a loss, the loop to the start, `JumpToTrack`) set `NitroLeft` to 0 early; then
  `NitroUntil` also moves to the cut, so the client stops drawing the boost. A run that stops or changes publishes
  nothing; stopping auto racing clears both attributes.
- The client shows "SAVED x s" with `NitroSaved` for 1.5 s when `NitroSavedAt` changes (only if it is under 1 s old).
  The saving assumes the cruise speed did not change during the boost (it can creep up as the stat grows).

## Effect

- `RaceService` holds `run.TargetSpeed x run.NitroMulti` on the rail while `run.NitroLeft > 0` (counted in run time).
  The car reaches the finish sooner, and the NPC race is decided by finish time as before, so a boost can win a race.
- It never changes the Speed stat, its gain (flat per second), Money, payouts or the NPC.
- Every reset of the car ends a boost: a loss, the loop back to the start after the last finish, and a jump to a
  track (`run:JumpToTrack`: checkpoint start, admin `/tp`). NPC races only: a duel run, a run without an NPC, and a
  finished or stopped run refuse it (`run:Nitro` returns false; a press the run refuses counts as a Miss).
- Once a race is decided no press counts: `NitroService.Press` ignores it (nil, no grade, no lock) while
  `run.Finished` is true (past the last finish) or `run.Lost` is true (a lost race from the NPC's finish until the
  car is reset, while the loser screen shows; `RaceService` sets it).
- `run:Nitro` also refuses a multi above 10 or a duration above 30 s, as a sanity limit far above the placeholders.
- Track 1's NPC is only ~2% faster than a stat-0 car, so with nitro a brand-new player can win Track 1 on the first
  lap. Without nitro a stat-0 car still loses.

## Authority

`Remotes.Nitro(pressTime)` carries only the client's `workspace:GetServerTimeNow()` at the press. `Server/NitroService`
grades it: the claimed time is used only if it lies between `LATENCY_WINDOW` (0.35 s) before arrival and arrival
(so ping does not punish the player), otherwise the arrival time is used. The server owns the bar through player
attributes `NitroReadyAt`, `NitroUntil`, `NitroMulti`, `NitroGrade`, `NitroPresses`, `NitroTarget`, `NitroPressPos`,
`NitroSaved` and `NitroSavedAt`; the client only draws them.
An exploiter can at most pick the best moment within the 0.35 s window, still once per charge. Nothing is saved.

## Open questions

- Does a skill element fit an idle game, and should AFK players be able to turn the bar off?
- How big may the boost be? With every press Good or better the car averages ~10-17% faster, so a player can beat an
  NPC up to that much faster than their cruise speed. Since a miss locks for the full recharge, spamming averages less.
- `UiSpec.Nitro.Text` has no `Saved` entry ("SAVED %.1f s") or `SavedShow` (1.5 s) yet; `UiTest/UiNitro` falls back
  to those values until `ui-test-writer` adds them.
