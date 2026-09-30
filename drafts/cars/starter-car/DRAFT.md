# Starter Car (baby-blue wagon)

- **Type:** car
- **Status:** draft
- **Blender file:** `starter_car.blend`
- **Scale:** Blender model is 4.4 units long; multiply by 3 to get studs (13.2 studs). `CarConfig.Scale = 3`
- **Matches spec:** `src/shared/CarConfig.luau` and `src/shared/CarFactory.luau` (built from parts, same layout numbers)

## What this is
The first car: a chunky, cute wagon in baby blue (#89CFF0), based on a yellow wagon reference mixed with the soft blocky Roblox look.

## What the draft includes
- Body, hood panel, tall cabin, sloped windshield
- Three side windows per side, rear window, mirrors, roof rack
- Bumpers, cream headlights, pink taillights, soft-navy side trim
- Four bevelled wheels with white hubcaps, all parented to an empty named `Car`
- Wide bevels and smooth shading for the soft look

## Left for full implementation
- Join parts by material and apply modifiers, then export as FBX/GLB
- Decide how Studio gets the rounded look: MeshParts imported from this file, or keep `CarFactory`'s plain blocks
- Wheels must stay separate meshes named `Wheel_FL/FR/RL/RR` so `CarPhysics` can move them
- Extra cars from the gacha list (Rusty Hatchback, Wooden Car, Go-Kart, Street Racer, ...) as their own folders next to this one

## Notes
- The Blender car has a sloped windshield and a tapered cabin front; `CarFactory` uses a plain vertical windshield and a shorter box cabin, so the two differ slightly.
