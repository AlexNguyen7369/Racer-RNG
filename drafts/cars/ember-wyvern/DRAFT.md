# Ember Wyvern

- **Type:** car
- **Status:** mesh approved and in the game 2026-10-27 (cyan shadow wyvern, `RedesignCarModels/ember_wyvern`); the
  blue-fire effects draft and the race flap are still to do.
- **Blender file:** `drafts/cars/ember_wyvern/redesign/ember_wyvern.blend` (built by `build_wyvern.py` here; details
  in that folder's `DRAFT.md`). Effects draft: `vfx_profile.luau` here.
- **Scale:** 1 Blender unit = 1 stud
- **Matches spec:** `src/shared/Cars/ember_wyvern.luau`, `docs/GAMEPASS_CARS_SPEC.md`

## What this is
A gamepass ride that is a dragon, not a car. It glides just above the road on the normal physics body.

## What the draft includes
- Stand-in built from Parts by `src/shared/DraftCarModels.luau`: body, neck, horned head, tail, `Wing_L`, `Wing_R`.
- Pedestal animation (client): wing flap, hover bob, slow turn.

## Left for full implementation
- Look: armoured red-black scales, horned head as the hood, molten glow in the seams, clawed feet tucked under the
  body, tail as a rear fin.
- Effects: fire and embers from the jaws on boost, ember trail, wing-beat sound.
- Animation: wing flap during races (needs the skin welds changed, own test round); later a rigged mesh with a
  flying loop (`AnimationController`), uploaded by hand in Studio.
- Final mesh in Blender as a skin (`docs/VEHICLE_SKINS_SPEC.md`): root empty at the body centre, forward = +X.

## Notes
No real flight: every ride uses the same ground physics body (stability rules).
