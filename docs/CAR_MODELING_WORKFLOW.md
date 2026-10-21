# Car modeling workflow

Every shipped car skin keeps the shared physics body and is a cosmetic model only.

1. Create an original Blender file under `drafts/cars/<snake_case_id>/<snake_case_id>.blend`.
2. Keep the forward direction on negative Z, the origin at the chassis base centre, and the
   complete silhouette within the skin size budget. Optional wheel parts use
   `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, and `Wheel_RR`.
3. Export the model to the corresponding Roblox-ready asset. Record the export command,
   author, source references, and license/originality note in `DRAFT.md`; do not import
   proprietary game assets or reverse-engineered files.
4. Validate every BasePart: `CanCollide`, `CanTouch`, and `CanQuery` false on the skin;
   anchored only in the template; massless after attachment; no scripts or constraints that
   drive the physics body. `CarAppearance` owns the weld and collision-group conversion.
5. Preview the model on the shared chassis at desktop and phone camera scales. Import in
   waves of 20 and run the catalog, skin-size, roll, respawn, and car-replacement checks
   before the next wave.

The 100-car expansion currently ships deterministic procedural templates through
`Shared/DraftCarModels` so catalog and gameplay work can be exercised before the Blender
art pass. Those templates are explicitly not the final art deliverables.
