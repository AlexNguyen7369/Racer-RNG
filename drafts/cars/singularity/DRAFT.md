# Singularity

- **Type:** car
- **Status:** draft (concept + stand-in from existing parts, no Blender file yet)
- **Blender file:** none yet
- **Scale:** 1 Blender unit = 1 stud
- **Matches spec:** `src/shared/Cars/singularity.luau`, `docs/GAMEPASS_CARS_SPEC.md`

## What this is
A gamepass hypercar bent around a small black hole. No wheels: glowing accretion rings carry it.

## What the draft includes
- Stand-in built by `src/shared/DraftCarModels.luau`: the `void_racer` body in black, a dark core sphere and glowing
  rings where the wheels would be.
- Pedestal animation (client): hover bob, slow turn.

## Left for full implementation
- Look: sleek black body with a gap in the middle holding the core, orange-white accretion disc, light bending
  around the body (distortion effect or a bright rim).
- Effects: star-dust trail, rings that spin with speed, a low hum.
- Final mesh in Blender as a skin (`docs/VEHICLE_SKINS_SPEC.md`).

## Notes
The rings are decoration; they are not `Wheel_*` parts.
