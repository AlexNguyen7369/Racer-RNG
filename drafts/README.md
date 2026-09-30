# Drafts

Rough, low-effort Blender drafts of assets, kept so they can be fully implemented later.
Nothing here is shipped to Roblox as-is.

```
drafts/
  _template/DRAFT.md        copy this into every new asset folder
  _tools/                   scripts that build drafts (blender_track_builder.py: tracks, slopes, loops)
  tracks/<track-id>/        e.g. track-01-oval/
  cars/<car-id>/            e.g. starter-car/
  props/<prop-id>/          cones, barriers, signs, trees
  environments/<env-id>/    City, Desert, Snow, Volcano, Space backdrops
  ui/<screen-id>/           layout sketches
```

## Rules
- One folder per asset. Inside: the `.blend`, a `preview.png`, optional `export/` (FBX/GLB) and a `DRAFT.md`.
- **Scale: 1 Blender unit = 1 stud.** Forward is +Y in Blender, which is -Z in Roblox.
- A draft that matches a Rojo spec (e.g. a track in `src/shared/Tracks/`) must name that spec in its `DRAFT.md`, so the two stay in sync.
- Status in `DRAFT.md`: `draft` -> `ready-to-implement` -> `implemented`. Move nothing out of `drafts/`; link to where it was implemented instead.
