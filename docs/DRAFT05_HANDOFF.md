# Racer RNG: UI and imported cars

The finalized source changes, saved Studio objects, and editable Blender assets are included on this branch. No game publication was performed.

## Included

- HUD, Index with unlocked car art and locked silhouettes, Stats, Settings, Rebirth coming-soon panel, and rolling showcase.
- Larger car icons, hover pop animation, rolling edge fades, centered speed/turbo group, tighter money/unbanked spacing, rounded turbo bar, outlined text, themed settings gear, and black Secret rarity.
- Seven beveled, low-poly Draft05 Blender cars, individual FBX/GLB exports, two exact Studio-import FBX batches, triangle report, and previews under assets/meshes/draft05.
- assets/studio/CarModels.rbxm: seven uploaded, material-grouped MeshPart templates, revision 5. Meshes are double-sided to preserve the Blender window and lamp surfaces. Headlights are decorative only; no active Light objects.
- assets/studio/StarterGui.rbxm: authored UI objects.
- places/RacerRNG_Draft05_Restored.rbxl: the latest native Studio download, taken after restoring the active scripts and saving to Roblox on 2026-10-06.
- places/RacerRNG_Draft05_Imported.rbxl: the older pre-restoration snapshot, retained unchanged for recovery; do not use it as the latest implementation.

## Source and synchronization

CarAppearance welds the selected cosmetic model to the existing physics chassis and seat. The starter uses Rusty Hatchback visually without granting that car or changing progression. UI cards continue using the original icon atlas, not model viewports.

default.project.json includes the model/UI objects, disables the five superseded legacy UI scripts, and places the controller and UI modules beneath RollToast where its requires expect them.

The earlier source discrepancy has been repaired: Studio now has CarAppearance, the updated CarService, RollToast, its controller and all eight UI modules. Targeted live checks confirmed Index, Stats, Settings, Rebirth and Auto Race buttons work, and all seven equipped visuals use revision 5 while preserving the original chassis and driver seat. Pre-restoration instances remain backed up in ServerStorage.

The compact reel now scrolls six car icons continuously, eases to the server-selected result, finishes its landing before revealing the result, and uses larger art and outlined odds. Reduced-effects mode avoids the sway/pop. Existing edge fades remain.

Studio's File > Save to Roblox was used in Edit mode for the existing Racer RNG experience (place 126725530984268). The place tab returned to the current Racer RNG name without the older revision timestamp and no save error appeared. A subsequent native Download a Copy produced the restored snapshot. No live publication was performed. Collaborators should open the latest shared save and use this branch before connecting Rojo; syncing an older checkout can overwrite the restored scripts.

## Validation status

This GitHub handoff compiled all 70 Luau sources, built default.project.json with Rojo 7.7.0, and verified the built place contains seven revision-5 cars / 42 double-sided meshes, six ScreenGuis, the nested controller/modules, and disabled legacy UI scripts. Git whitespace checks passed. StyLua/Selene and the full compatibility suites were not run.

The restored native snapshot is checked with tools/verify-saved-sources.luau against all 13 restored/UI/context sources. Targeted live reel checks reached Spin, Land and Hold without new runtime errors. These are focused checks, not a replacement for full compatibility certification.

Prior Draft05 work checked all seven cars in live races and visually checked beveled shapes, glass and decorative headlamps. Individual exports and batch imports passed the model checker. Full current-branch physics/UI/multiplayer/world compatibility is NOT certified; main's gate must not be bypassed. Real Studio DataStore access remains disabled.

Blender helper scripts retain the original local output paths from this session; adjust those paths before regenerating elsewhere. Prefer the included .blend and validated exports for reproduction.
