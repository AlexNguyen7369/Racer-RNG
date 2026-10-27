# Car art redesign (MeshPart skins)

Owner decision, 2026-10-20. Design doc entry: `GAME_DESIGN_REQUIREMENTS.md`, "Owner car art redesign". Skin rules:
`docs/VEHICLE_SKINS_SPEC.md` (this spec never overrides them).

## 1. References
- Source: `drafts/cars/Roblox_Car_Redesign_References.zip`, extracted to `references/car_redesign/`. Both are
  git-ignored (219 MB, over GitHub's file limit). Modelling aids only: never shipped, uploaded or committed.
- 111 PNG renders (one 3/4 view each, dark studio background). Each file name is a catalog `Name`
  (`src/shared/Cars/*.luau`); the match is exact, one image per car. `manifest.json` gives each car's design
  direction. The `*.png~` copies in the zip are editor backups and are not used.
- Cars without a reference keep their current model: the built-in `starter`. `ember_wyvern` has owner references
  since 2026-10-27 (section 9).

## 2. Build rules
- Modelled in Blender (Blender MCP), starting from the car's current blockout: `drafts/cars/<id>/recipe.json` for
  the expansion cars, the `assets/studio/CarModels.rbxm` part layout for the Draft05 originals. The silhouette,
  colours and signature features follow the reference.
- Scale 1 unit = 1 stud. Roblox forward -Z, up +Y, pivot at the base centre. Bounds: |x| <= 1.95, |z| <= 3.3,
  y >= 0 (the same budget `tools/build_expansion_cars.py` asserts).
- One MeshPart per material group: `Body`, `Trim`, `Accent`, `Glass`, `Metal`, `Light` (any that the car needs).
  Wheeled cars have four separate tyre MeshParts `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR`, each centred on its
  axle; hub caps are in `Metal`. (The skin is welded static, `Shared/CarAppearance`, so the hubs need not spin.)
- Colour comes from the MeshPart's `Color` and `Material` (Light = Neon, Glass = Glass, Metal = Metal, others
  SmoothPlastic). No textures (exception: special-case rides, section 9). A car with more than one colour in a group gets numbered groups (`Light`, `Light2`,
  `Accent2`, ...): a part name is one of the base names, optionally followed by a number.
- **Neon (owner, 2026-10-20):** every glowing detail (lamps, light strips, neon trim, Singularity's gold) is a `Light*`
  part in `Neon` at full brightness, never a solid colour. Singularity's gold is bright neon gold.
- **Sport look (owner, 2026-10-20):** every car adds a dark front splitter with a thin neon lip, rear diffuser fins,
  a low lip spoiler when it has no wing or ducktail, tyres about 20% wider (outer face unchanged) and a body
  lowered by 0.06 studs over the wheels. Its silhouette, colours and signature parts stay as in the reference.
- **Singularity black hole (owner, 2026-10-20):** a black core sphere inside a tilted neon-gold accretion ring with a
  pale neon halo, standing on the engine deck. It must never be removed.
- The 100 expansion cars start from their `recipe.json` blockout, converted part by part (same layout, colours and
  wheel spokes as the reference) with bevelled edges, chunkier tyres and the neon rule above.
- At most 6,000 triangles per car (exception: special-case rides, section 9).
- Every part: `Anchored`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`, `Massless`,
  `CollisionFidelity = Box` (baked in the file; it cannot be set at runtime).
- Original artwork: no brands, logos or extracted assets.

## 3. Files
- Per car: `drafts/cars/<id>/redesign/` holds `<id>.blend`, `<id>.fbx` and `preview.png` (same camera angle as
  the reference); `DRAFT.md` records the source and export.
- Uploaded mesh ids: `assets/meshes/cars/ids.json` (id -> asset ids).
- Roblox models: `assets/studio/RedesignCarModels/<model>.rbxmx`, synced by Rojo to
  `ReplicatedStorage.RedesignCarModels`.

## 4. Load order
`Shared/DraftCarModels.Ensure` fills `ReplicatedStorage.CarModels`. A model in `RedesignCarModels` always wins and
replaces a template with the same name. After that come the existing fallbacks: `ExpansionCarModels` exports, the
`CarModels.rbxm` imports, the expansion placeholders and the `BUILDERS` stand-ins. Old models stay as fallbacks.
Redesigned templates carry the attribute `Redesign = true`; `Shared/CarAppearance` does not apply the catalog
`Tint` to them, because their colours already follow the reference.

## 5. Un-shared models
`midnight_kart`, `golden_racer` and `rain_runner` set `Model` to their own id. Their ids, rarities, chances and
multipliers are unchanged.

## 6. Delivery
| Wave | Cars |
|---|---|
| 1 | Rusty Hatchback, Wooden Car, Go-Kart, Midnight Kart, Street Racer, Rain Runner, Rocket Car, Golden Racer, Hover Car, Void Racer, Singularity |
| 2-6 | The 100 expansion cars, one family of 20 per wave in manifest `Order` |

Each wave is shown to the owner as a side-by-side sheet (reference next to the Studio capture). It is merged only
after the owner approves it.

## 7. Acceptance (test scenario `car_redesign`)
For every catalog car with a reference:
- `CarModels[Model]` comes from `RedesignCarModels`.
- Every MeshPart has a `MeshId`.
- Every part has `CanCollide = false` and is massless.
- The bounds fit section 2.
- Wheeled cars have all four `Wheel_*` parts.

The existing `car_size`, `gacha`, `index`, `race`, `lap:*` and `vehicle_effects` scenarios stay green.

## 8. Finish and geometry pass (owner, 2026-10-26)
- **Finish (runtime, `Shared/CarAppearance`, every skin: equipped, NPC and display):** groups keep their material
  (section 2). Paint groups (`Body`, `Accent`, `Trim`) get `Reflectance` 0.08 (gloss), `Metal` 0.25, `Glass` 0.2
  with `Transparency` 0.25. `Light*` parts cast no shadow, and neither do `Glass`, `Trim` or `Metal` parts (small
  detail). Wheels stay matte. Numbers live in `CarAppearance.FINISH` and are tunable (placeholders).
- **Geometry (Blender, `tools/build_redesign_cars.py`, `GEOM` level; owner 2026-10-26: "stronger"):** level 2 gives
  paint panels (`Body*`, `Accent*`) at least `ROUND_MIN` 0.12 thick a wider 2-segment bevel, door shut lines on the
  body sides, wheel-arch flares (`Trim`) and rim lips (`Metal`) on recipe wheels, a rim lip and five spokes on
  hand-built wheels, and 24-side tyres with a 1-segment shoulder. A car over 6,000 triangles steps down to level 1
  (lighter: panels >= 0.35, no seams / flares / spokes), then level 0 (pre-pass). 2026-10-26: 110 cars level 2,
  `golden_racer` level 1. Silhouette, colours, bounds and part names unchanged.

## 9. Special-case rides (owner, 2026-10-27)
- Special-case rides (first: `ember_wyvern`) may go over the 6,000-triangle budget and may use textures (an image per
  MeshPart, baked in Blender, `TextureID` / FBX-embedded). Each MeshPart still stays under Roblox's per-mesh limit
  (20,000 triangles). Bounds, collision and massless rules of section 2 still apply; part names are the section 2
  groups plus the skin spec's animated parts (`Wing_L`, `Wing_R`, `docs/VEHICLE_SKINS_SPEC.md`), each wing with its
  `PivotOffset` on the flap hinge. Textured parts carry a `SurfaceAppearance` (ColorMap + NormalMap).
- Ember Wyvern references (git-ignored, `references/ember_wyvern/images/`): shape from `owner_ref_front_spread.png`
  (finger-bone wings, belly plates from chin to tail, horned crown, long spiked tail, clawed hind legs); look from
  `owner_ref_shadow_wyvern_a.png` / `_b.png` (owner 2026-10-27, replacing amber): black shadow body with glowing cyan
  crevices and chest, cyan wing membranes with tattered flame edges, a raised S-curved neck, glowing face lines, smoke
  tendrils, blue fire effects. Inspiration only: original design, no existing character copied.
