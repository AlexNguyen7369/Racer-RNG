# Oversteer Orbit (redesign)

- **Status:** Toy racer pass 2026-10-27 (CAR_REDESIGN_SPEC section 10). Geometry pass 2026-10-26 (CAR_REDESIGN_SPEC section 8). built 2026-10-20, rebuilt 2026-10-21 with the sport kit (splitter + neon lip, diffuser, spoiler/wing, wider tyres, lowered) (docs/CAR_REDESIGN_SPEC.md); family track_hyper.
- **Reference:** `references/car_redesign/Oversteer Orbit.png` (git-ignored concept render; modelling aid only).
- **Source:** `tools/build_redesign_cars.py` `recipe_car()`: the car's `recipe.json` blockout converted part by part (bevelled edges, wider tyres, neon at full brightness), run through the Blender MCP. Original artwork: no brand, logo or extracted asset.
- **Files:** `oversteer_orbit.blend`, `oversteer_orbit.fbx`, `preview.png`, `parts.json`. Uploaded as Roblox Model 109522087380306
  (`assets/meshes/cars/ids.json`); Roblox export `assets/studio/RedesignCarModels/oversteer_orbit.rbxmx`.
- **Budget:** 6944 triangles (cap 15,000); bounds min [-1.704, -2.585, 0.002] max [1.704, 2.78, 1.988] (Blender x/y/z, 1 unit = 1 stud).
- **Parts:** Trim2, Body, Light, Accent4, Glass, Light2, Light3, Accent3, Wheel_FL, Metal2, Wheel_RL, Wheel_FR, Wheel_RR, Trim, Metal, Accent, Accent2.
