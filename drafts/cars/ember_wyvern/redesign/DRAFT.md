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
  `preview.png`, `views/` (side, front, top, rear34, head, flap_cycle; studio_vfx*.jpg are from draft 2), `parts.json`.
- **Budget:** 32044 triangles; per part {"Body": 8164, "Trim": 9164, "Light2": 512, "Light": 2140, "Accent": 880, "Wing_L": 5576, "Wing_R": 5608} (each under Roblox's 20,000). Bounds min
  [-1.867, -3.28, 0.181] max [1.867, 3.173, 4.731] (Blender x/y/z): inside |x| <= 1.95, |y| <= 3.3, z >= 0 at rest.
- **Parts:** `Body` (scales texture), `Trim` (horns, crown, claws, spikes; texture), `Accent` (belly plates;
  texture), `Light` (Neon chest / neck plates, face lines, mouth), `Light2` (Neon eyes, teeth), `Wing_L`, `Wing_R` (membrane + bones + claws +
  arm spikes in one part each, texture).
- **Flap:** 24 frames at 24 fps, actions `WingFlap_Wing_L` / `WingFlap_Wing_R`: each wing turns about the body axis on
  its hinge (-8, +38, +10, -8 degrees at frames 1, 8, 16, 24). Hinges (`parts.json`, Blender coords) `Wing_L`
  [-0.3, 1.05, 1.75], `Wing_R` [0.3, 1.05, 1.75]: the Roblox model needs each wing's `PivotOffset` there. On the
  downstroke the wings reach past |x| 1.95, so a flap while racing must stay smaller or be checked against the walls.
- **Mouth** (fire breath): [0.0, 3.08, 3.314]. Effects draft: `drafts/cars/ember-wyvern/vfx_profile.luau` (blue fire, anchors moved
  for draft 4, not re-checked in Studio).

## Left for full implementation
- Wing PivotOffsets; flap in races (client code + its own test round); a full flying loop (neck / tail sway) needs a
  rig and an uploaded animation.
- Effects: a design-doc entry first, then the profile goes into `Shared/VehicleEffects`.
