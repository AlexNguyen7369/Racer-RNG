# Market trail / aura VFX redesign

- **Type:** prop (vehicle cosmetic VFX)
- **Status:** draft (rainbow_trail and void_trail shipped 2026-10-26; solar_trail and the auras in progress)
- **Blender file:** `trails.blend` (built by `build_scene.py`)
- **Scale:** 1 Blender unit = 1 stud
- **Matches spec:** `src/shared/VehicleEffects.luau`, `docs/PANEL_ART_GIFTING_SPEC.md` (effects on the chassis, no mass)

## What this is
A frozen-frame Blender stand-in for the six Market cosmetics: Roblox Trails as flat ribbon meshes and every
ParticleEmitter as cards placed where its speed, drag and acceleration carry each particle at its age.

## What the draft includes
- Rainbow / Solar / Void trails and Azure / Ember / Galaxy auras on the blocky car, textures from `vfx/trails/out/`.
- Shots: in Blender's console `bpy.app.driver_namespace["trail_shot"]("overview" | "rainbow" | "solar" | "void" | "auras")`.

## Left for full implementation
- Solar trail and the three auras (owner 2026-10-26: auras less flamboyant, Ember aura like a Dragon Ball Z aura).

## Notes
- Live Studio version of the same layers: `vfx/trails/preview.luau` (local rbxasset preview textures).
