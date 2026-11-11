# On-foot sprint

Requested by Vic2CS, 2026-11-10, on branch `feature/vic2cs/dev-changes`. Not yet reviewed by the owner.
Rule source: `docs/GAME_DESIGN_REQUIREMENTS.md`, "On-foot sprint".

## Behaviour

- Holding Left or Right Shift while on foot moves the avatar at `CarService.SPRINT_MULTI` (1.5, placeholder) times
  its current WalkSpeed. Releasing Shift returns it to normal.
- The base is `UpgradeService.WalkSpeed(player)`, so each Walkspeed tier also raises the sprint: 16 -> 24 with no
  upgrades, 49 -> 73.5 at tier V.
- Sprint never affects a car. A riding avatar keeps WalkSpeed 0. If Shift is still held after Stop or a respawn, the
  avatar sprints as soon as it is back on foot.
- Shift typed into a text box (chat) does not start a sprint. Losing window focus ends it.
- Nothing is saved.

## Authority

`Client/SprintInput` sends only the intent, `Remotes.SetSprint(boolean)`. `Server/CarService` checks that the value
is a boolean and decides the speed, so a client can never ask for a number. The remote has no cooldown: a dropped
release would leave the player stuck sprinting, and spamming it gains nothing over holding Shift.

## Shift Lock

`StarterPlayer.EnableMouseLockOption` is `false` in `default.project.json`, because Roblox's Shift Lock uses the same
keys.

## Open questions

- Does a free sprint undercut the early paid Walkspeed tiers (20, 25)?
- Phones and gamepads have no Shift key and no sprint control yet.
