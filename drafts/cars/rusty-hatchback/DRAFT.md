# Rusty Hatchback

- **Type:** car (vehicle skin, see `docs/VEHICLE_SKINS_SPEC.md`)
- **Status:** exported for Studio (2026-10-05), Studio import pending
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

## Export (done 2026-10-05)
`blender/scenes/export_rusty_hatchback.py` (headless, no MCP needed) bakes every mesh's colour to its own texture on a
fresh UV map, flattens the hierarchy (the FBX axis conversion misplaces parented wheels), scales to studs and writes
`blender/exports/rusty_hatchback/RustyHatchback.fbx` (textures embedded, copies as PNG next to it):
- 5 meshes: `Body` (1024 px texture) and `Wheel_FL/FR/RL/RR` (256 px), 1,194 triangles in all
- size 6.6 x 3.43 x 3.02 studs (length matches the half-size starter car's 6.6 stud body); wheel centres at
  +-2.0 / 2.1 studs along the length, +-1.44 across, 1.18 studs across each wheel
```
/Applications/Blender.app/Contents/MacOS/Blender -b drafts/cars/rusty-hatchback/rusty_hatchback.blend --python blender/scenes/export_rusty_hatchback.py
```

## Studio import (pending: needs Studio open)
1. Owner: Studio > File > Import 3D > `blender/exports/rusty_hatchback/RustyHatchback.fbx`. In the importer set the
   file units so the preview reads about 6.6 studs long, keep "Import as one model", Import.
2. Claude (Studio MCP): rename to `RustyHatchback`, PrimaryPart = Body, front faces -Z (Wheel_F* at -Z, Wheel_*L at -X),
   every part Anchored, CanCollide/CanTouch/CanQuery false, Massless; check MeshId/TextureID are uploaded
   `rbxassetid://` ids; parent to `ReplicatedStorage.CarModels`.
3. Owner: right-click the model > Save to File > `assets/CarModels/RustyHatchback.rbxm`; Claude maps
   `ReplicatedStorage.CarModels` to `assets/CarModels` in `default.project.json` so every collaborator gets it through Rojo.
4. Set `Model = "RustyHatchback"` in `src/shared/Cars/rusty_hatchback.luau` (roll card / showcase show it; the race car
   keeps the starter look until vehicle skins are built), then the UI suite + /compat-check.

## Notes
- Wheels are 0.79 units across (starter: 1.0). Fine for a skin: the physics uses the invisible body's suspension, not these wheels.
- The asset came lying along Y with quaternion rotation on its root; it was rotated 90 degrees about Z through its world matrix.
