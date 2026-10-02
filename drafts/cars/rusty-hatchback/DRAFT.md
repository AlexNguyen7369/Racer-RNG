# Rusty Hatchback

- **Type:** car (vehicle skin, see `docs/VEHICLE_SKINS_SPEC.md`)
- **Status:** draft
- **Blender file:** `rusty_hatchback.blend` (preview: `preview.png`)
- **Scale:** 4.4 Blender units long, the same as the starter car draft (multiply by 3 for studs: 13.2 studs, `CarConfig.Scale = 3`)
- **Matches spec:** `src/shared/Cars/rusty_hatchback.luau` (Common, `Model = nil` until this ships)

## What this is
The Common "Rusty Hatchback": a beat-up little hatchback in faded orange paint with rust blotches, a mismatched grey
primer hood and dull, rusty bumpers. Built on an existing CC0 asset instead of from scratch.

## Source asset (credit)
"Car Hatchback" by Kay Lousberg, https://poly.pizza/m/BG0KAhmGDt, licence CC0 1.0
(https://creativecommons.org/publicdomain/zero/1.0/). No credit required; recorded anyway, also stored on the root
object as `polypizza_attribution`.

## What the draft includes
- Root empty `RustyHatchback` (forward +X, left +Y, up +Z, wheels resting on Z = 0); size 4.4 x 2.29 x 2.01 units, 1,194 triangles
- `Body` plus four separate wheels `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR` (children of Body), named as the car physics expects
- Materials: `RustPaint` (faded orange + rust noise), `Primer` (grey hood panel + rust flecks), `RustyMetal` (bumpers,
  trim), `DirtyGlass`; lights, tyres and trim keep the asset's palette texture `citybits_texture.png`
- The old starter-car parts are kept in the hidden collection `StarterReference` (prefixed `Starter_`) for size comparison

## Left for full implementation
- Rust is a procedural Blender material: bake it to a texture (or use flat colours per face) before export, Roblox does
  not read Blender node materials
- Export FBX to `blender/exports/`, import to Studio as MeshParts, save as `ReplicatedStorage.CarModels.RustyHatchback`
  and set `Model = "RustyHatchback"` in `src/shared/Cars/rusty_hatchback.luau`
- Hook-up follows the vehicle-skins rule: a non-colliding, massless skin on the shared physics body; must fit the
  footprint budget (it is 2.29 wide vs the starter's 2.0 body + wheels at 2.44, so it fits)
- Do the Studio part only when Studio is free (the roll animation session is using it as of 2026-10-02)

## Notes
- Wheels are 0.79 units across (starter: 1.0). Fine for a skin: the physics uses the invisible body's suspension, not these wheels.
- The asset came lying along Y with quaternion rotation on its root; it was rotated 90 degrees about Z through its world matrix.
