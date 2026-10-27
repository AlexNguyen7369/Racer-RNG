# Ember Wyvern (draft 2, Blender mesh)

- **Status:** draft 2026-10-27, not uploaded, not in the game. The Part stand-in in `Shared/DraftCarModels` still ships.
- **Reference:** none (`docs/CAR_REDESIGN_SPEC.md` section 1: no concept image). Brief from
  `drafts/cars/ember-wyvern/DRAFT.md`: armoured red-black scales, horned head, molten glow in the seams, clawed feet
  tucked under the body, tail as a rear fin.
- **Source:** `drafts/cars/ember-wyvern/build_wyvern.py` (reuses `tools/build_redesign_cars.py`), run headless:
  `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python drafts/cars/ember-wyvern/build_wyvern.py`.
  Body, neck, tail, legs, jaw and horns are Skin-modifier tubes (subdivided, then decimated for the budget); wings are
  solidified bat-wing membranes with arm and finger bones. Original artwork.
- **Files:** `ember_wyvern.blend`, `ember_wyvern.fbx`, `preview.png`, `views/` (side, front, top, rear 3/4),
  `parts.json`.
- **Budget:** 5144 triangles (limit 6000); bounds min [-1.936, -3.3, 0.16] max [1.936, 3.233, 3.96] (Blender x/y/z):
  inside |x| <= 1.95, |y| <= 3.3, z >= 0. Taller than the cars (raised wings), which the skin rules allow.
- **Parts:** `Body` (crimson), `Trim` (horns, claws, dorsal spikes, tail blade), `Accent` (belly plates), `Light`
  (Neon molten seams, throat, mouth), `Light2` (Neon eyes, teeth), `Wing_L`, `Wing_R` (one part each so
  `Client/BestRollView` can flap them).
- **Pivot points** (`parts.json`, Blender coords): wing hinges `Wing_L` [-0.42, 0.75, 1.72], `Wing_R`
  [0.42, 0.75, 1.72]: the Roblox model needs each wing's `PivotOffset` moved there. Mouth (fire breath)
  [0, 3.12, 2.02].
- **Effects draft:** `drafts/cars/ember-wyvern/vfx_profile.luau`.

## Left for full implementation
- Owner review of this draft, then upload the FBX by hand in Studio and save `assets/studio/RedesignCarModels/ember_wyvern.rbxmx`.
- Wing pivots and the `car_redesign` / `car_size` / `vehicle_effects` scenarios once it is in `RedesignCarModels`.
- Effects: a design-doc entry first, then the profile goes into `Shared/VehicleEffects`, played only on boost.
