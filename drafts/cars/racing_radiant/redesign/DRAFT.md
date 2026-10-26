# Racing Radiant (redesign)

- **Status:** Geometry pass 2026-10-26 (CAR_REDESIGN_SPEC section 8). built 2026-10-20, rebuilt 2026-10-21 with the sport kit (splitter + neon lip, diffuser, spoiler/wing, wider tyres, lowered) (docs/CAR_REDESIGN_SPEC.md); family track_hyper.
- **Reference:** `references/car_redesign/Racing Radiant.png` (git-ignored concept render; modelling aid only).
- **Source:** `tools/build_redesign_cars.py` `recipe_car()`: the car's `recipe.json` blockout converted part by part (bevelled edges, wider tyres, neon at full brightness), run through the Blender MCP. Original artwork: no brand, logo or extracted asset.
- **Files:** `racing_radiant.blend`, `racing_radiant.fbx`, `preview.png`, `parts.json`. Uploaded as Roblox Model 126917120300485
  (`assets/meshes/cars/ids.json`); Roblox export `assets/studio/RedesignCarModels/racing_radiant.rbxmx`.
- **Budget:** 4824 triangles; bounds min [-1.7, -2.75, 0.004] max [1.7, 2.957, 2.001] (Blender x/y/z, 1 unit = 1 stud).
- **Parts:** Trim2, Body, Light, Accent2, Glass, Light2, Light3, Accent3, Wheel_FL, Metal2, Wheel_RL, Wheel_FR, Wheel_RR, Trim, Metal, Accent, Accent4.
