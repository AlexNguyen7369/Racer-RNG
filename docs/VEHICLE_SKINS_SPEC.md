# Vehicle skins: any model can be the "car" (QUEUED design rule)

Owner, 2026-10-02: car models must be swappable and dynamic. Down the line the player's ride could be something that is
not a car at all (example: a dragon). Models do not have to follow the starter car's build or dynamics.

## The rule: physics and looks are separate
- **The ride's physics never comes from its model.** `CarPhysics` drives an invisible, fixed **physics body** (the
  chassis box + raycast suspension points from `CarConfig`). Every ride uses the same body, so speed, grip, the
  stability tests (`PhysicsTargets`, never flip, stay on the path) and the race results do not change when the look
  changes.
- **The look is a skin:** any `Model` in `ReplicatedStorage.CarModels` (the name in the catalog's `Model` field), welded
  onto the physics body, `CanCollide = false`, `Massless = true`, no effect on physics. A car, a dragon, a hovering
  board: anything that fits the size budget below.
- **Skin size budget:** fits the physics body's footprint (about the starter car's 13 x 6 studs footprint, see
  `CarConfig`) within a small margin so it never visibly sinks into the road or clips track walls; taller is fine.
  The skin sets its own offset/scale (attributes, e.g. `SkinOffset`, `SkinScale`) so the body need not change.
- **Optional animated parts:** a skin MAY have named parts the client animates, all optional:
  `Wheel_FL/FR/RL/RR` (spin with speed and steer, as today), `Wing_L/Wing_R` or other names declared in the catalog
  (e.g. `Animations = { Flap = "Wing_*" }`) or an `AnimationController` + animation ids (a dragon's flying loop).
  A skin with no wheels is valid: nothing spins.
- **Effects:** a skin may bring its own trail, particles or sounds (e.g. fire breath, engine). Client-side only.
- **Same skin everywhere:** the race car, the NPC car (`NpcConfig.Tracks[n].Model`), the Index tile, the roll card's
  ViewportFrame and the discovery cutscene all clone the same `CarModels` entry.

## What this needs in code (later, its own test-first build)
1. `CarFactory` builds the invisible physics body + seat, then attaches the equipped car's skin (or the starter skin).
2. `CarPhysics` keeps steering the body; wheel visuals only if the skin has `Wheel_*` parts (already looked up by name).
3. Changing the equipped car swaps the skin live (no new physics, no reset).
4. Tests: every catalog skin keeps all stability/race tests green (the body is the same), the skin never collides, its
   bounding box fits the budget, a wheel-less skin works.

## For model drafts (Blender, `drafts/cars/`)
Build each model as a skin: one root (an empty) at the physics body's center, forward = +X, up = +Z, 1 unit = the
draft's scale noted in its DRAFT.md. Wheels, when the model has them, are separate objects named `Wheel_FL/FR/RL/RR`.
Nothing else about the starter car's construction is required.
