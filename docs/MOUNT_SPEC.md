# Car mount

Requested by Vic2CS, 2026-11-10, on branch `feature/vic2cs/dev-changes`. Not yet reviewed by the owner.
Rule source: `docs/GAME_DESIGN_REQUIREMENTS.md`, "Car mount".

## Behaviour

- Pressing C on foot rides the equipped car; pressing C again gets off. Keyboard only so far.
- The car is a cosmetic attached under the avatar, which sits on top of it. It moves with the normal walking controls,
  so it can not flip or get stuck. The car has no collision of its own.
- Jump and Shift sprint work while riding. Trails and auras show on the ridden car.
- Changing the equipped car while riding swaps the ridden car and its speed at once.
- Allowed anywhere on foot. Not allowed while racing, and starting a race (button, pad or duel) gets off first.
- Riding counts as on foot: workshop Speed gain and duels are unchanged. Reaching the race pad gets off and starts the
  race, checked by position because a raised avatar does not touch the pad.
- Dying, respawning or leaving ends the ride. Nothing is saved.

## Speed (`Shared/MountConfig`, all placeholders)

`ride speed = min(walk speed x MountConfig.SpeedMulti(car SpeedMulti), MAX_SPEED)`, where walk speed already includes
Walkspeed upgrades and sprint, and `SpeedMulti(m) = min(1 + SPEED_SCALE x log10(max(m, 1)), MAX_MULTI)`.

| Constant | Value |
|---|---|
| `SPEED_SCALE` | 0.5 |
| `MAX_MULTI` | 3 |
| `MAX_SPEED` | 100 studs/s |
| `MAX_SEAT_HEIGHT` | 6 studs: how high a tall ride (Ember Wyvern) can lift the avatar |
| `TOGGLE_COOLDOWN` | 0.4 s |

Examples with no upgrades: Starter x1 (16), a 7.5 car x1.44 (23), a 65 car x1.91 (31), the 2800 car x2.72 (44).

Only the catalog `SpeedMulti` is used, so Speed stat points and boosts do not change ride speed.

## Authority

`Client/MountController` sends only `Remotes.ToggleMount()`, with no arguments. `Server/CarService` checks the avatar is
alive and on foot, applies the cooldown, builds the car and sets the speed. The player attribute `Mounted` shows the
state.

## Open questions

- Should riding speed be this generous next to the paid Walkspeed tiers?
- Phones and gamepads have no ride control yet.
