# Car Modeling Workflow

> Every model is a **skin** on a shared invisible physics body, not a physics object: any shape works (a car, or later a dragon). Rules: `docs/VEHICLE_SKINS_SPEC.md`.

Reference-driven pipeline: external generators and real-world sources provide **references**; Claude builds the final car in Roblox Studio and checks it against them.

## Tools

| Tool | Role |
|---|---|
| Image generators / real blueprints and photos | Orthographic and multi-angle references |
| Text/image-to-3D services (Meshy, Tripo, Hyper3D Rodin, etc.) | Rough 3D reference mesh (reference only) |
| Blender + Blender MCP | Import references, measure, render standard views |
| Roblox Studio MCP | Build the final car: `generate_mesh`, `generate_texture`, `generate_material`, `generate_procedural_model`, `search_asset`, `insert_asset`, `screen_capture` |

## Folder Layout

```
references/<car-name>/
  images/       orthographic views and photos (front, side, top, rear, 3/4)
  meshes/       generated reference meshes (GLB/FBX), never uploaded to Roblox
  blueprints/   manufacturer drawings
  renders/      standard-angle renders from Blender and Studio
  README.md     target dimensions and source/license notes
blender/scenes/    .blend working files
blender/exports/   cleaned FBX/OBJ exports intended for Studio
assets/meshes/     final mesh files
assets/textures/   final textures
```

Start a new car by copying `references/_template/` to `references/<car-name>/`.

## Steps

### 1. Collect references
- Gather front, side, top and rear views plus at least one 3/4 view.
- Optionally generate a rough 3D mesh with a text/image-to-3D service.
- Save everything under `references/<car-name>/`.
- Record each source and its license terms in the car's `README.md`.

### 2. Extract measurements (Blender MCP)
- Import the reference mesh into Blender.
- Read off length, width, height, wheelbase and wheel diameter.
- Render the standard views (front, side, top, rear, 3/4) into `renders/`, using fixed camera angles.

### 3. Set Roblox scale
- Convert the measurements to studs and fill in the target dimensions in the car's `README.md`.
- Use the same scale for every car so vehicles stay consistent.

### 4. Build in Studio
- Body: `generate_mesh`, guided by the reference images.
- Paint, glass and tires: `generate_texture` and `generate_material`.
- Wheels as **separate parts** so they can spin and steer.
- Set pivot points and part names to match the vehicle scripts.

### 5. Compare and iterate
- Capture the Studio model with `screen_capture` from the same angles as the references.
- Compare proportions, stance and panel lines against `renders/`.
- Adjust and repeat until they match.

### 6. Rig and test
- Add constraints and attachments for the vehicle scripts.
- Drive the car in play mode and check wheel alignment, suspension and center of mass.

## Rules

- **Reference meshes are never uploaded.** They are usually too heavy and messy for Roblox.
- **Check licensing** for every generator and source before using its output commercially. Using outputs as reference only lowers the risk but doesn't remove it.
- **Real car brands** can raise trademark issues on Roblox. Prefer original or generic designs.
- **Keep triangle counts low.** Check Roblox's current MeshPart limits before designing.
- **Use fixed camera angles** for every comparison so results are repeatable.

## Blender MCP Setup Status

- [x] `uv` installed (`brew install uv`)
- [x] Blender installed (`brew install --cask blender`)
- [x] Server registered (`claude mcp add blender -- uvx blender-mcp`)
- [x] Add-on downloaded to `blender/addon/addon.py`
- [ ] Add-on installed in Blender (Edit → Preferences → Add-ons → Install from Disk → `addon.py`, then enable it)
- [ ] Connected (Blender sidebar `N` → BlenderMCP → Connect)
- [ ] Claude Code restarted so it loads the `blender` server
