# Ridge Rover (redesign)

- **Status:** Geometry pass 2026-10-26 (CAR_REDESIGN_SPEC section 8). built 2026-10-20, rebuilt 2026-10-21 with the sport kit (splitter + neon lip, diffuser, spoiler/wing, wider tyres, lowered) (docs/CAR_REDESIGN_SPEC.md); family offroad_rally.
- **Reference:** `references/car_redesign/Ridge Rover.png` (git-ignored concept render; modelling aid only).
- **Source:** `tools/build_redesign_cars.py` `recipe_car()`: the car's `recipe.json` blockout converted part by part (bevelled edges, wider tyres, neon at full brightness), run through the Blender MCP. Original artwork: no brand, logo or extracted asset.
- **Files:** `ridge_rover.blend`, `ridge_rover.fbx`, `preview.png`, `parts.json`. Uploaded as Roblox Model 139312390761355
  (`assets/meshes/cars/ids.json`); Roblox export `assets/studio/RedesignCarModels/ridge_rover.rbxmx`.
- **Budget:** 5156 triangles; bounds min [-1.53, -2.65, 0.008] max [1.53, 2.898, 2.84] (Blender x/y/z, 1 unit = 1 stud).
- **Parts:** Trim2, Body, Accent3, Glass, Light2, Light3, Accent2, Wheel_FL, Metal2, Wheel_RL, Wheel_FR, Wheel_RR, Light, Trim, Metal, Accent, Accent4.
