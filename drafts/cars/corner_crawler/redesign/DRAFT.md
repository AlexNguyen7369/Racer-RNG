# Corner Crawler (redesign)

- **Status:** Toy racer pass 2026-10-27 (CAR_REDESIGN_SPEC section 10). Geometry pass 2026-10-26 (CAR_REDESIGN_SPEC section 8). built 2026-10-20, rebuilt 2026-10-21 with the sport kit (splitter + neon lip, diffuser, spoiler/wing, wider tyres, lowered) (docs/CAR_REDESIGN_SPEC.md); family city_utility.
- **Reference:** `references/car_redesign/Corner Crawler.png` (git-ignored concept render; modelling aid only).
- **Source:** `tools/build_redesign_cars.py` `recipe_car()`: the car's `recipe.json` blockout converted part by part (bevelled edges, wider tyres, neon at full brightness), run through the Blender MCP. Original artwork: no brand, logo or extracted asset.
- **Files:** `corner_crawler.blend`, `corner_crawler.fbx`, `preview.png`, `parts.json`. Uploaded as Roblox Model 99223576038029
  (`assets/meshes/cars/ids.json`); Roblox export `assets/studio/RedesignCarModels/corner_crawler.rbxmx`.
- **Budget:** 7048 triangles (cap 15,000); bounds min [-1.554, -2.444, 0.002] max [1.554, 2.536, 2.753] (Blender x/y/z, 1 unit = 1 stud).
- **Parts:** Trim2, Body, Accent3, Light3, Glass, Light, Light2, Accent2, Wheel_FL, Metal2, Wheel_RL, Wheel_FR, Wheel_RR, Trim, Metal, Accent, Accent4, Light4.
