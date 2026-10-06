# Racer RNG: UI and imported cars

The finalized source changes, saved Studio objects, and editable Blender assets are included on this branch. No game publication was performed.

## Included

- HUD, Index with unlocked car art and locked silhouettes, Stats, Settings, Rebirth coming-soon panel, and rolling showcase.
- Larger car icons, hover pop animation, rolling edge fades, centered speed/turbo group, tighter money/unbanked spacing, rounded turbo bar, outlined text, themed settings gear, and black Secret rarity.
- Seven beveled, low-poly Draft05 Blender cars, individual FBX/GLB exports, two exact Studio-import FBX batches, triangle report, and previews under assets/meshes/draft05.
- assets/studio/CarModels.rbxm: seven uploaded, material-grouped MeshPart templates, revision 5. Meshes are double-sided to preserve the Blender window and lamp surfaces. Headlights are decorative only; no active Light objects.
- assets/studio/StarterGui.rbxm: authored UI objects.
- places/RacerRNG_Draft05_Imported.rbxl: the unchanged local save taken on 2026-10-06.

## Source and synchronization

CarAppearance welds the selected cosmetic model to the existing physics chassis and seat. The starter uses Rusty Hatchback visually without granting that car or changing progression. UI cards continue using the original icon atlas, not model viewports.

default.project.json includes the model/UI objects, disables the five superseded legacy UI scripts, and places the controller and UI modules beneath RollToast where its requires expect them.

Important: inspection found that the saved place and current Studio have the Draft05 models and HUD objects but older active CarService/RollToast scripts; their finalized versions remain on disk. This branch includes those finalized local sources rather than silently treating the saved place as source-identical. The saved snapshot is preserved unchanged. A fresh Studio integration/compatibility run is needed before merging or publishing.

## Validation status

This GitHub handoff compiled all 70 Luau sources, built default.project.json with Rojo 7.7.0, and verified the built place contains seven revision-5 cars / 42 double-sided meshes, six ScreenGuis, the nested controller/modules, and disabled legacy UI scripts. Git whitespace checks passed. StyLua/Selene and the full compatibility suites were not run.

Prior Draft05 work checked all seven cars in live races and visually checked beveled shapes, glass and decorative headlamps. Individual exports and batch imports passed the model checker. Full current-branch physics/UI/multiplayer/world compatibility is NOT certified; main's gate must not be bypassed. Real Studio DataStore access remains disabled.

Blender helper scripts retain the original local output paths from this session; adjust those paths before regenerating elsewhere. Prefer the included .blend and validated exports for reproduction.
