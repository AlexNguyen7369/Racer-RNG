# Ember Wyvern flight: size and dynamic animation

Owner, 2026-10-27: "when the dragon is auto racing, there is no flying animation, have a physics test suite for that,
also make the dragon bigger (this is an exception case) on the pedestal and when auto racing. there should be dynamic
wing flapping and the body should also have dynamic animations." Design doc entry: "Owner car art redesign",
2026-10-27 (Ember Wyvern flight). Skin rules: `docs/VEHICLE_SKINS_SPEC.md`; mesh rules: `docs/CAR_REDESIGN_SPEC.md`
section 9. Numbers marked *placeholder* are tunable.

## 1. Size (exception)
- The catalog car file may set `SkinScale` (a number). `ember_wyvern` has `SkinScale = 2.5` *(placeholder; owner
  2026-10-27: "dragon model size a lot bigger", was 1.6)*; no other car sets it, so every other skin is unchanged.
- While racing, `Shared/CarAppearance.Apply` scales the cloned skin by `SkinScale` about its base pivot, then places
  the base at tyre contact height as before. On a pedestal `CarAppearance.Display` uses
  `CAR_SCALE * min(SkinScale, DISPLAY_SKIN_MAX)` with `CarAppearance.DISPLAY_SKIN_MAX = 1.6` *(placeholder)*, so the
  pedestal model stays clear of the Best Roll pedestal and the other pedestal.
- This is the skin size-budget exception of `VEHICLE_SKINS_SPEC.md`: the scaled skin may pass the chassis footprint.
  It stays cosmetic (no collision, massless, `CanQuery`/`CanTouch` off), so the physics body, speed, grip and every
  stability rule are unchanged.
- At any pose of the animation (section 3) the scaled skin's wings stay within `MAX_HALF_SPAN` = 9 studs of the chassis
  centre sideways *(placeholder, was 6)*: inside the road (half width 20) from the right-hand lane (offset 10).
- Long tail (owner 2026-10-27: "make dragon tail longer"): the tail reaches about 5.6 studs behind the base centre
  (template scale), past the car bound; `docs/CAR_REDESIGN_SPEC.md` section 9.

## 2. Rig
- The skin is a skinned mesh: one armature exported with the FBX (Blender, `drafts/cars/ember-wyvern/build_wyvern.py`),
  imported as `Bone` instances. Bone names (all required): `Root`, `Spine1`, `Spine2`, `Neck1`..`Neck4`, `Head`, `Jaw`,
  `Tail1`..`Tail6`, `Thigh_L`/`_R`, `Shin_L`/`_R`, and per wing `Arm_<s>`, `Fore_<s>`, `Hand_<s>`, `Finger<k>_<s>`
  (k = 1..4, s = L/R).
- Every part keeps its section 9 name and `SurfaceAppearance`; `Wing_L` / `Wing_R` stay separate parts (weighted to
  their wing bones) and keep their hinge `PivotOffset`.

## 3. Motion (`Shared/WyvernMotion`, pure maths)
- `WyvernMotion.Pose(t, state)` returns `{ [boneName] = CFrame }` (local bone transforms) for time `t` (s) and
  `state = { Speed = studs/s, Turn = rad/s, Reduced = bool }`. Same inputs, same pose (deterministic).
- **Flap cycle:** bursts of `FLAP_BEATS` = 3 beats then a glide of `GLIDE_SECONDS` = 1.2 s *(placeholders)*. A beat
  takes `1 / FLAP_HZ` with `FLAP_HZ` = 1.8 at rest falling to 1.2 at cruise speed and above *(placeholders)*. Downstroke
  `FLAP_DOWN` = 34 deg (was 40; 2026-10-27, so the banked downstroke stays within `MAX_HALF_SPAN`), upstroke `FLAP_UP` = 15 deg past level at the shoulder; the forearm and fingers follow with a
  phase lag (the wing folds on the upstroke and spreads on the downstroke). Glide: wings held spread with a small
  flutter (at most 4 deg).
- **Body** (owner 2026-10-27: "make the dragon body also dynamically animated"): the body heaves up by `HEAVE` =
  0.3 studs (times `SkinScale`) on each downstroke and sinks a little on the upstroke *(placeholder)*; the chest pitches
  up as the wings drive down and the spine sways and curves into turns; the legs kick back on each downstroke and tuck
  tighter at speed, where the neck also stretches out; the neck sways in an S that lags the body; the head stays level and turns into curves (yaw = `Turn` x 0.35,
  at most 25 deg); the tail swings as a travelling wave whose amplitude grows to the tip (at most 14 deg per bone); the
  body banks into curves (roll up to 8 deg, was 12; 2026-10-27, same reason); the jaw opens slightly every few seconds. Legs stay tucked with a small
  lag.
- **Reduced motion** (`state.Reduced`: Roblox Reduced Motion or REDUCED EFFECTS): one slow flap every 2 s at half the
  amplitude, no bank, no head turn.
- Limits (tests): every bone rotation stays within 60 deg of the rest pose; the shoulder sweeps at least 40 deg over a
  burst at any speed; the pose changes between frames 0.1 s apart while racing.

## 4. Who plays it
- `Client/WyvernAnimator` (client only, nothing replicates per frame) sets `Bone.Transform` every RenderStepped from
  `WyvernMotion.Pose` for: the local player's and other players' equipped `EquippedVisual` skins that carry the rig
  (attribute `Rig = "Wyvern"` on the template), NPC skins of that model, and the pedestal / Best Roll cars.
  `Speed` and `Turn` come from the chassis' velocity and yaw rate.
- `Client/BestRollView` stops rotating `Wing_L` / `Wing_R` parts on a rigged car (the bones flap them).

## 5. Tests (`wyvern_flight` scenario)
- Catalog: `ember_wyvern.SkinScale` is a number > 1; every other car has none.
- Template: `CarModels.ember_wyvern` has `Rig = "Wyvern"` and every bone of section 2.
- Size: an applied skin's bounding box is `SkinScale` times the template's (within 2%); on a pedestal
  `CAR_SCALE * SkinScale`. Every skin part stays non-colliding and massless.
- Motion: the section 3 limits over 10 s of poses at Speed 0, 45 and 300, Turn -1/0/1, Reduced on/off; flaps then
  glides (shoulder angle has both phases); the tail tip moves more than the tail root; deterministic.
- Bounds: posing the scaled template at the extreme poses keeps every part within `MAX_HALF_SPAN` sideways.
- Physics: a race on Track 1-2 with `ember_wyvern` equipped keeps the stability rules (0 flips, up-vector Y >= 0.9,
  path deviation within `PhysicsTargets.race.MaxPathDeviation`) and the same cruise speed as the starter.
