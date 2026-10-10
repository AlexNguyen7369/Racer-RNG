# Spawn marketplace

Blender recreation of the supplied visual reference: central red/cream workshop
awning, flanking Aura and fuel/parts stalls, bolted timber, warm lanterns, stone
paving, checker accents, bright display items and an open courtyard.

- Source: `build_marketplace.py`, `SpawnMarketplace.blend`; 1 unit = 1 stud.
- Two shared 256px textures: `MarketWood.png` and `MarketStone.png`. Solid-color
  canvas, trim, lettering and display parts have UV maps and named materials.
- 37 decorative mesh groups, 34,796 triangles, batched by vendor and material. Each group is below
  7,000 triangles. No scripts, physics bodies or NPCs are imported with the art.
- Rojo template: `assets/studio/SpawnMarketplace.rbxmx` maps to
  `ReplicatedStorage.SpawnMarketplace`. `MarketplaceMeshAssets` records uploaded
  IDs and `MarketplaceBuilder` restores native geometry if sync clears it.
- Runtime: `Workspace.SpawnArea.Marketplace`, centered on the original Market
  position `(50, -70)` relative to Track 1's flattened start. Footprint 48 x 44,
  rotated another 180 degrees from the previous clockwise quarter-turn (front +X), stone paving top 1.2, central entrance
  24 studs wide. The authored Blender template still faces +Z.
- `Vendors/Aura`, `Vendors/Workshop`, `Vendors/Parts` hold independent visual
  modules and named interaction points. All three current E prompts open the
  existing Market browser. No new upgrade, vehicle sale or fuel behavior is
  implied; those displays and NPC/ShopButton/ItemDisplay attachments are ready
  for later systems. The existing tagged MarketPad remains, hidden under the
  structure with its old prompt disabled to prevent duplicate prompts.
- All static geometry is anchored. Decorative meshes are double-sided and have
  collision/touch/query/shadows disabled; `CollisionBoundaries` contains smooth
  box surfaces for the floor, counters, posts and display areas. No detail mesh
  collisions intersect the central inlaid gear rug or the front entrance.
- Five local warm lights have shadows disabled. Global weather/Lighting, spawn,
  upgrades, workshops, race entrance, roads, scripts and saved data are preserved.

Rebuild in Blender, inspect iso/front/top, then import the collection at
`(50,1,-70)`. Normalize imported CFrames by subtracting that placement before
exporting the template. Refresh the asset manifest if geometry changes. Apply
native imported meshes to the existing mapped template instances to avoid
replacing their identity. Main builds the marketplace when Play starts; do not
leave a second standalone copy in Workspace.
