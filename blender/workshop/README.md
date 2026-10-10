# Racing garage source

`RacingGarage.blend` is the editable Blender source (1 unit = 1 stud, front = -Y).
Four 128 x 128 surface images are packed into the blend and also saved here.
The imported template is `assets/studio/RacingGarage.rbxmx`, mapped by Rojo to
`ReplicatedStorage.RacingGarage`. It contains 13 material-group meshes, each below
20,000 triangles. Mesh and texture assets were uploaded through the Studio owner.

The builder rotates the imported +Z-facing template by 180 degrees into plot-local
-Z and places its bottom 0.2 studs above the original plot base lift. Model bounds
are about 37.1 x 17 x 37 studs. Gameplay Floor, three wall collision boundaries,
Zone, Rate and UpgradePad are built separately. Cosmetic meshes are anchored,
double-sided, and have collision/touch/query disabled.

Keep the central/front walk route and camera volume open. Do not move gameplay
rectangles while revising art. When changing source, import the RacingGarage
collection, update the checked-in template mesh/texture ids and transforms, and
verify the model on a real player plot and after an upgrade.
