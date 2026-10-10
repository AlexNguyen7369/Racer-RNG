# Race start pavilion

Built from the owner's neon race-start reference: purple beveled canopy, four
green columns, cyan/green edge lighting, dimensional white title, checker flags,
yellow signal lamps, side rails, teal deck and readable two-lane starting grid.

- Source: `build_pavilion.py` and `RaceStartPavilion.blend` (1 unit = 1 stud).
- Shared texture: `RaceChecker.png`, 128 x 128; other groups use solid colors.
- Studio template: `assets/studio/RaceStartPavilion.rbxmx`, mapped by Rojo to
  `ReplicatedStorage.RaceStartPavilion`.
- `RaceStartMeshAssets` records the eleven uploaded IDs. Like WorkshopBuilder,
  SpawnArea prepares a private template at module load and restores native mesh
  geometry if file sync clears MeshContent. The cache is cloned without repeated
  asset loading; checker textures are preserved during repair.
- Eleven material groups, approximately 12,000 triangles in total; largest group
  is 5,312 triangles. Meshes are anchored, double-sided decorative surfaces with
  collision, touch, query and shadow casting disabled.
- Template coordinates have bottom at y=0. `SpawnArea.PadBase` positions and
  turns the authored pad center (2,20) to the owner's captured hub location
  (34.303,28.499), with sign outward direction +X, square to the hub.
  `SpawnArea.Build` raises the template to the original StartPad top (1.2).
- `SpawnArea.RaceBoundaries` uses seven invisible box colliders. The hub entrance
  spans local z=10..30; there is no center barrier. Grid lanes are 18.5 studs wide.
- Three shadow-free local point lights. No global Lighting/weather overrides,
  animations, new race timing, waypoint changes or finish-checkpoint changes.
- Existing Spawn, StartPad, Floor, market/upgrade pads and gameplay tags are kept.
  The original pad BillboardGui is disabled after cloning the other pad signs.
- Only the intersecting near curb is opened, from x=24 to approximately 54.303,
  to keep the relocated front/right entrances accessible. Roads and vehicle race
  spawn/waypoints stay unchanged; Bounds and walk-spawn facing use the new pad.

Rebuild in Blender, inspect front/iso, and import the collection. Normalize the
imported mesh CFrames to their authored local coordinates before exporting the
template. Do not put a second copy of the pavilion in Workspace: Main builds it
as part of SpawnArea when Play starts.
