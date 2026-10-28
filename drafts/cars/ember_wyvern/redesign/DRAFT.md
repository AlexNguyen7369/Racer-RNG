# Ember Wyvern (draft 4, Blender mesh)

- **Status:** approved by the owner 2026-10-27 (draft 4). Uploaded as Roblox Model 103082461956401
  (`assets/meshes/cars/ids.json`); Roblox export `assets/studio/RedesignCarModels/ember_wyvern.rbxmx` (SurfaceAppearance
  per textured part, wing PivotOffsets). It replaces the `Shared/DraftCarModels` stand-in.
- **References** (git-ignored, modelling aids only, `references/ember_wyvern/images/`): shape from
  `owner_ref_front_spread.png`; look from `owner_ref_shadow_wyvern_a.png` / `_b.png` (owner 2026-10-27, cyan replaces
  amber): black shadow body with thin glowing cyan cracks, a glowing cyan chest and neck (Neon plates, textured teal
  plates further back), cyan wing membranes with tattered flame-tongue edges, a raised S-neck with the head tilted
  nose-up, glowing face lines, smoke tendrils off the jaw, elbows, hips and tail. Inspiration only: original design.
  Special-case ride (`docs/CAR_REDESIGN_SPEC.md` section 9): over the 6,000-triangle budget and textured.
- **Source:** `drafts/cars/ember-wyvern/build_wyvern.py` (reuses `tools/build_redesign_cars.py`), run headless:
  `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python drafts/cars/ember-wyvern/build_wyvern.py`.
  Body, neck, tail, legs, horns and bones are Skin-modifier tubes; wings are solidified bat-wing membranes on an arm and
  four fingers with a thumb claw. The head (owner 2026-10-27: "more aggressive, too round") is an angular loft:
  flat sloping skull with cheekbones, brow-ridge horns, slit eyes, an open hinged jaw with fangs, chin and jaw-line
  spikes, a nose horn, swept-back horns and a frill. Textures are procedural (Voronoi scales with ember-red crevices, mottled amber
  membrane with faint veins, mottled plates, horn), baked with Cycles to one colour map and one tangent-space normal map per part (`textures/<Part>.png`,
  `<Part>_normal.png`; owner 2026-10-27 "scales too smooth": readable ~0.1-stud scales with a thin cyan seam, dark
  groove, lighter rim and fine inner scales, plus staggered rows of raised diamond scutes over the back, flanks and
  neck as geometry). In Roblox the normal maps need a `SurfaceAppearance` (ColorMap + NormalMap). Previews render in
  EEVEE so the normal maps and the Neon glow show. Original artwork.
- **Files:** `ember_wyvern.blend` (with the flap cycle), `ember_wyvern.fbx` (textures embedded), `textures/*.png`,
  `preview.png`, `views/` (side, front, top, rear34, head; studio_flight.jpg and studio_breath.jpg are live Studio captures), `parts.json`.
- **Budget:** 36096 triangles; per part {"Body": 11264, "Trim": 9368, "Light2": 512, "Light": 2140, "Accent": 1628, "Wing_L": 5576, "Wing_R": 5608} (each under Roblox's 20,000). Bounds min
  [-1.867, -5.62, 0.181] max [1.867, 3.173, 4.731] (Blender x/y/z): |x| <= 1.95, z >= 0, and the long tail to y -5.62 (special-case bound 5.8).
- **Parts:** `Body` (scales texture), `Trim` (horns, crown, claws, spikes; texture), `Accent` (belly plates;
  texture), `Light` (Neon chest / neck plates, face lines, mouth), `Light2` (Neon eyes, teeth), `Wing_L`, `Wing_R` (membrane + bones + claws +
  arm spikes in one part each, texture).
- **Flight:** the wings and body are posed live in Roblox from `Shared/WyvernMotion` (see Flight rig below).
- **Mouth** (fire breath): [0.0, 3.08, 3.314]. Effects draft: `drafts/cars/ember-wyvern/vfx_profile.luau` (blue fire, anchors moved
  for draft 4, not re-checked in Studio).

## Left for full implementation
- Effects: a design-doc entry first, then the profile goes into `Shared/VehicleEffects`.

## Flight rig (2026-10-27, `docs/WYVERN_FLIGHT_SPEC.md`)
- `drafts/cars/ember-wyvern/wyvern_rig.py`: 33 bones (spine, neck, head, jaw, tail, legs, wing arm / forearm / hand /
  four fingers per side), each vertex weighted to its two nearest allowed bones; the head and jaw are rigid. The FBX
  carries the armature; Roblox Model 100205140229978 (long tail, 2026-10-27). The motion is procedural (`Shared/WyvernMotion`), so the
  .blend has no animation.
