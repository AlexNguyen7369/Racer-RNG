# Cornerfire (redesign)

- **Status:** Toy racer pass 2026-10-27 (CAR_REDESIGN_SPEC section 10). Geometry pass 2026-10-26 (CAR_REDESIGN_SPEC section 8). built 2026-10-20, rebuilt 2026-10-21 with the sport kit (splitter + neon lip, diffuser, spoiler/wing, wider tyres, lowered) (docs/CAR_REDESIGN_SPEC.md); family track_hyper.
- **Reference:** `references/car_redesign/Cornerfire.png` (git-ignored concept render; modelling aid only).
- **Source:** `tools/build_redesign_cars.py` `recipe_car()`: the car's `recipe.json` blockout converted part by part (bevelled edges, wider tyres, neon at full brightness), run through the Blender MCP. Original artwork: no brand, logo or extracted asset.
- **Files:** `cornerfire.blend`, `cornerfire.fbx`, `preview.png`, `parts.json`. Uploaded as Roblox Model 113998796846799
  (`assets/meshes/cars/ids.json`); Roblox export `assets/studio/RedesignCarModels/cornerfire.rbxmx`.
- **Budget:** 7788 triangles (cap 15,000); bounds min [-1.604, -2.491, 0.002] max [1.604, 2.686, 2.293] (Blender x/y/z, 1 unit = 1 stud).
- **Parts:** Trim2, Body, Accent2, Glass, Light, Light2, Accent3, Wheel_FL, Metal2, Wheel_RL, Wheel_FR, Wheel_RR, Light3, Trim, Metal, Accent, Accent4, Accent5.
