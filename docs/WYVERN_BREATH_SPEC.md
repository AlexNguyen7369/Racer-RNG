# Ember Wyvern blue fire breath

Owner, 2026-10-27: "add the blue fire breath effects to the dragon". Design doc entry: "Owner car art redesign",
2026-10-27 (Ember Wyvern breath). Builds on `docs/WYVERN_FLIGHT_SPEC.md` (rig, `Shared/WyvernMotion`,
`Client/WyvernAnimator`) and the effects draft `drafts/cars/ember-wyvern/vfx_profile.luau`. Numbers marked
*placeholder* are tunable.

## 1. When it breathes
- `WyvernMotion.Breath(t, state)` returns the breath strength 0..1 for the same `t` and `state` as `Pose`: 0 during the
  flap burst, rising over `BREATH_RAMP` = 0.15 s at the start of each glide to 1, falling back to 0 over the last
  `BREATH_RAMP` of the glide *(placeholders)*. Same inputs, same value. Reduced motion: at most 0.4.
- So the wyvern flaps, then glides breathing a burst of blue fire, then flaps again, while auto racing and on its
  pedestal. The jaw opens with the breath (`Jaw` pitch follows the strength, still within the flight limits).

## 2. What it looks like (client only)
- Palette (five colours): white-hot `HOT` (230, 255, 255), `CYAN` (60, 220, 255), `BLUE` (20, 130, 230), `DEEP`
  (10, 40, 140), shadow `SOOT` (4, 6, 16). Textures: the uploaded VFX set (`Shared/VehicleEffects`, `Flame`,
  `VoidWisp`, `Spark`, `Glint`); nothing new is uploaded.
- Layers on one `Attachment` named `Breath` under the `Head` bone, at the mouth and facing along the jaw:
  `BreathCore` (white-hot flame jet, `LockedToPart`), `BreathBody` (cyan to deep-blue flame), `BreathSmoke` (shadow
  smoke, `LightEmission` 0), `BreathSparks` (streaking sparks), `MouthGlow` (glint at the mouth). Each layer's rate is
  its full rate times the breath strength; at 0 every layer has rate 0.
- Sizes and speeds scale with the model's scale (`SkinScale`, the pedestal scale). World-space layers inherit the
  ride's velocity (`VelocityInheritance`) so the fire keeps up with the ride instead of being left behind.
- Built by `Shared/WyvernBreath.Build(model)` (returns the attachment) and driven by `Client/WyvernAnimator` through
  `WyvernBreath.SetStrength(attachment, strength)`. The
  server never builds it; nothing replicates. Effects are cosmetic: no collision, no effect on physics or payouts.

## 3. Tests (`wyvern_breath` scenario)
- `Breath` exists, is deterministic, stays in 0..1, is 0 throughout every flap burst and reaches 1 in every glide at
  Speed 0 / 45 / 300; Reduced never passes 0.4.
- `WyvernBreath.Build` on a template clone makes the `Breath` attachment under `Head` with the five named emitters,
  every texture one of the uploaded `VehicleEffects` textures, colours from the palette only, and
  `WyvernBreath.SetStrength(attachment, 0)` gives every rate 0 (1 gives each layer its full rate, above 0).
- On the server no `Breath` attachment exists in any skin after a race (client only).
- The `wyvern_flight` limits still hold with the jaw following the breath.
