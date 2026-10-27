"""Ember Wyvern draft 4 (drafts/cars/ember-wyvern/DRAFT.md). Shape after references/ember_wyvern/images/
owner_ref_front_spread.png (finger-bone wings, belly plates, horned crown, spiked tail, clawed hind legs); look after
owner_ref_shadow_wyvern_a/b.png (owner 2026-10-27): black shadow body with glowing cyan crevices and chest, cyan
membranes with tattered flame edges, raised S-neck, glowing face lines, smoke tendrils. Original design.

Headless:  Blender -b --factory-startup --python drafts/cars/ember-wyvern/build_wyvern.py
Blender MCP:  exec(open('<repo>/drafts/cars/ember-wyvern/build_wyvern.py').read())

Reuses the Car class of tools/build_redesign_cars.py (material groups, bounds, FBX export, preview), so the output
follows docs/CAR_REDESIGN_SPEC.md: drafts/cars/ember_wyvern/redesign/. Special-case ride (section 9, owner
2026-10-27): over the 6,000-triangle budget, with baked textures (procedural scales / membrane veins baked to one
image per part, textures/*.png, embedded in the FBX). Blender axes: +Y forward (Roblox -Z), +Z up, 1 unit = 1 stud,
origin at the base centre. Body, neck, tail, legs and bones are Skin-modifier tubes; Wing_L / Wing_R are single
parts so Client/BestRollView can flap them, and the .blend carries a 24-frame flap cycle (WingFlap actions).
"""
import json
import math
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = Path('/Users/alexnguyen7369/Documents/RobloxGames')
exec(open(ROOT / 'tools/build_redesign_cars.py').read())

MAX_TRIS = 40000  # special-case ride (CAR_REDESIGN_SPEC section 9); each part is checked against MESH_LIMIT
MESH_LIMIT = 20000  # Roblox triangles per MeshPart
# Wings are their own groups: the flap needs one part per side (BestRollView looks for Wing_L / Wing_R exactly).
GROUP_MATERIAL['Wing_L'] = GROUP_MATERIAL['Wing_R'] = 'SmoothPlastic'

BLACK = (0.02, 0.022, 0.035)  # blue-black shadow
CYAN = (0.12, 0.82, 1.0)
COLORS = {
    'Body': BLACK,
    'Trim': (0.012, 0.014, 0.022),  # horns, claws, spikes, smoke tendrils
    'Accent': (0.08, 0.55, 0.7),  # belly / tail plates (textured)
    'Light': CYAN,  # glowing chest and neck plates, face lines, mouth (Neon)
    'Light2': (0.75, 1.0, 1.0),  # eyes, teeth (Neon)
    'Wing_L': CYAN,
    'Wing_R': CYAN,
    'Tyre': (0.1, 0.1, 0.1),  # unused, the finish() fallback
}
TEXTURE = {'Body': ('scales', 1024), 'Trim': ('horn', 512), 'Accent': ('plates', 1024), 'Wing_L': ('wing', 1024),
           'Wing_R': ('wing', 1024)}

# Hinges (Blender coords) for the Roblox PivotOffset of each wing, and the mouth point for the fire breath VFX.
WING_HINGE = (0.3, 1.05, 1.75)
# The head is built level, then raised onto the S-neck and tilted nose-up (pivot at the back of the skull).
HEAD_M = (Matrix.Translation((0, -0.05, 0.85)) @ Matrix.Translation((0, 2.3, 2.3)) @ Matrix.Rotation(math.radians(18), 4, 'X')
          @ Matrix.Translation((0, -2.3, -2.3)))
MOUTH = tuple(HEAD_M @ Vector((0.0, 3.14, 2.2)))

# Spine from the tail tip to the nose: (x, y, z, radius across, radius up). Long neck, long tail (reference).
SPINE = [
    (0.0, -3.28, 1.0, 0.025, 0.025), (0.12, -2.95, 1.02, 0.05, 0.045), (0.18, -2.6, 1.05, 0.08, 0.07),
    (0.12, -2.2, 1.1, 0.11, 0.1), (0.04, -1.8, 1.15, 0.15, 0.14), (0.0, -1.35, 1.22, 0.21, 0.2),
    (0.0, -0.85, 1.3, 0.3, 0.28), (0.0, -0.3, 1.38, 0.36, 0.33), (0.0, 0.25, 1.48, 0.34, 0.32),
    (0.0, 0.75, 1.64, 0.28, 0.27), (0.0, 1.1, 1.9, 0.19, 0.19), (0.0, 1.35, 2.25, 0.14, 0.14),
    (0.0, 1.62, 2.62, 0.12, 0.12), (0.0, 1.95, 2.95, 0.11, 0.11), (0.0, 2.3, 3.15, 0.115, 0.11),
]  # raised S-neck; the head is a separate angular loft (head(), moved by HEAD_M)


def along(y):
    """Spine (x, z, radius across, radius up) at y, linear between points."""
    pts = SPINE
    if y <= pts[0][1]:
        return pts[0][0], pts[0][2], pts[0][3], pts[0][4]
    for a, b in zip(pts, pts[1:]):
        if a[1] <= y <= b[1]:
            t = (y - a[1]) / (b[1] - a[1])
            return tuple(a[i] + (b[i] - a[i]) * t for i in (0, 2, 3, 4))
    return pts[-1][0], pts[-1][2], pts[-1][3], pts[-1][4]


def skin(c, group, chain, branches=(), subdiv=1, mirror=False, ratio=1.0):
    """Organic tube through chain = [(x, y, z, rx, rz), ...]; branches = [(index, [(x, y, z, rx, rz), ...]), ...]
    hang off chain[index]. mirror adds the -x copy of every branch. ratio < 1 decimates."""
    verts, edges, radii = [], [], []

    def add(points, start):
        for i, (x, y, z, rx, rz) in enumerate(points):
            verts.append((x, y, z))
            radii.append((rx, rz))
            if i or start is not None:
                edges.append((len(verts) - 2 if i else start, len(verts) - 1))

    add(chain, None)
    for index, points in branches:
        add(points, index)
        if mirror:
            add([(-x, y, z, rx, rz) for x, y, z, rx, rz in points], index)
    mesh = bpy.data.meshes.new('skin_tmp')
    mesh.from_pydata(verts, edges, [])
    tmp = bpy.data.objects.new('skin_tmp', mesh)
    c.scene.collection.objects.link(tmp)
    tmp.modifiers.new('Skin', 'SKIN')
    for sv, r in zip(mesh.skin_vertices[0].data, radii):
        sv.radius = r
    mesh.skin_vertices[0].data[0].use_root = True
    if subdiv:
        tmp.modifiers.new('Sub', 'SUBSURF').levels = subdiv
    if ratio < 1:
        tmp.modifiers.new('Dec', 'DECIMATE').ratio = ratio
    deps = bpy.context.evaluated_depsgraph_get()
    out = bpy.data.meshes.new_from_object(tmp.evaluated_get(deps))
    bpy.data.objects.remove(tmp)
    bpy.data.meshes.remove(mesh)
    return c._take(group, bpy.data.objects.new(group, out))


def cone(c, group, base, tip, radius, verts=6):
    """Spike from base to tip."""
    base, tip = Vector(base), Vector(tip)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=radius, radius2=0.0, depth=(tip - base).length)
    ob = c._finish(group, bm, (base + tip) / 2, (0, 0, 0))
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((tip - base).normalized())
    return ob


def horn(c, points, radius, group='Trim'):
    """Curved tapering horn / claw along points (base to tip)."""
    n = len(points)
    skin(c, group, [(*p, radius * (1 - i / n) + 0.008, radius * (1 - i / n) + 0.008) for i, p in enumerate(points)],
         subdiv=1)


def ball(c, group, center, radius, squash=(1, 1, 1), seg=(12, 8)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg[0], v_segments=seg[1], radius=radius)
    for v in bm.verts:
        v.co = Vector(tuple(a * b for a, b in zip(v.co, squash)))
    return c._finish(group, bm, center, (0, 0, 0))


def claw(c, base, direction, length, radius, group='Trim'):
    """Hooked claw: a short curved horn bending downward."""
    d = Vector(direction).normalized()
    base = Vector(base)
    mid = base + d * length * 0.55
    tip = base + d * length + Vector((0, 0, -length * 0.45))
    horn(c, [tuple(base), tuple(mid), tuple(tip)], radius, group)


def wing(c, side):
    """Bat wing raised in a V (bounds |x| <= 1.95): arm, four long fingers and a thumb claw, an amber membrane with
    ragged scallops between the fingers, solidified so both faces render. Faces of the membrane carry kind = 1 for the
    texture bake (bones stay 0)."""
    s = side
    name = 'Wing_L' if s < 0 else 'Wing_R'
    shoulder = Vector((s * WING_HINGE[0], WING_HINGE[1], WING_HINGE[2]))
    elbow = Vector((s * 0.95, 1.3, 2.55))
    wrist = Vector((s * 1.45, 1.05, 3.55))
    tips = [Vector((s * 1.8, 0.4, 4.6)), Vector((s * 1.83, -0.45, 4.05)), Vector((s * 1.8, -1.2, 3.3)),
            Vector((s * 1.64, -1.85, 2.45))]
    knuckles = [wrist + (t - wrist) * 0.45 + Vector((s * 0.06, 0, 0.05)) for t in tips]
    root = Vector((s * 0.22, -1.1, 1.55))
    # Membrane fan from the wrist, panels between neighbouring fingers; trailing edges sag in two ragged scallops.
    bm = bmesh.new()
    edge = [tips[0]]
    for i, (a, b) in enumerate(zip(tips, tips[1:] + [root])):
        depth = 0.5 if i < len(tips) - 1 else 0.6
        for k in range(1, 12):
            t = k / 12
            p = a + (b - a) * t
            # Tattered flame edge: tongues licking outward between notches (owner reference, shadow wyvern).
            tongue = -(0.08 + 0.05 * ((i * 7 + k) % 3)) if k % 2 else 0.06
            edge.append(p + (wrist - p).normalized() * (depth * math.sin(math.pi * t) + tongue))
        edge.append(b)
    vw = bm.verts.new(wrist)
    ve = [bm.verts.new(p) for p in edge]
    for a, b in zip(ve, ve[1:]):
        bm.faces.new((vw, a, b))
    vs, vel = bm.verts.new(shoulder), bm.verts.new(elbow)
    bm.faces.new((vw, ve[-1], vs, vel))  # the skin between arm and body
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    mem = c._finish(name, bm, (0, 0, 0), (0, 0, 0))
    mod = mem.modifiers.new('Thick', 'SOLIDIFY')
    mod.thickness = 0.03
    mod.offset = 0
    deps = bpy.context.evaluated_depsgraph_get()
    solid = bpy.data.meshes.new_from_object(mem.evaluated_get(deps))
    mem.modifiers.clear()
    mem.data = solid
    kind = solid.attributes.new('kind', 'FLOAT', 'FACE')
    kind.data.foreach_set('value', [1.0] * len(solid.polygons))
    # Bones: arm, then each finger through its knuckle, tapering to a hooked tip.
    skin(c, name, [(*shoulder, 0.12, 0.12), (*elbow, 0.085, 0.085), (*wrist, 0.075, 0.075)],
         branches=[(2, [(*k, 0.04, 0.04), (*t, 0.016, 0.016)]) for k, t in zip(knuckles, tips)], subdiv=1)
    for t in tips:
        cone(c, name, t, t + (t - wrist).normalized() * 0.16, 0.025, 5)
    # Thumb claw on the wrist and spikes along the arm's leading edge (reference).
    claw(c, wrist + Vector((0, 0.04, 0)), (s * 0.15, 0.9, 0.3), 0.3, 0.045, name)
    for t in (0.3, 0.55, 0.8):
        p = elbow + (wrist - elbow) * t
        cone(c, name, p, p + Vector((s * 0.08, 0.22, 0.12)), 0.035, 5)  # in the wing part, so they flap with it
    for t in (0.4, 0.75):
        p = shoulder + (elbow - shoulder) * t
        cone(c, name, p, p + Vector((s * 0.05, 0.2, 0.1)), 0.03, 5)
    # Smoke tendril curling back off the elbow (flaps with the wing).
    horn(c, [tuple(elbow), tuple(elbow + Vector((s * 0.12, -0.3, -0.05))), tuple(elbow + Vector((s * 0.08, -0.55, 0.08))),
             tuple(elbow + Vector((s * 0.16, -0.75, 0.02)))], 0.03, name)


def loft(c, group, sections):
    """Faceted head piece: sections = [(y, zc, half width, top, bottom), ...] back to front, each a 10-sided ring
    (flat top ridge, hard cheek line, keel underneath), capped at both ends. Angular on purpose (owner 2026-10-27:
    the round head was not aggressive enough)."""
    bm = bmesh.new()
    rings = []
    for y, zc, w, t, b in sections:
        ring = [(0, t), (0.6 * w, 0.85 * t), (w, 0.25 * t), (0.9 * w, 0.5 * b), (0.55 * w, b), (0, b),
                (-0.55 * w, b), (-0.9 * w, 0.5 * b), (-w, 0.25 * t), (-0.6 * w, 0.85 * t)]
        rings.append([bm.verts.new((x, y, zc + z)) for x, z in ring])
    for r0, r1 in zip(rings, rings[1:]):
        n = len(r0)
        for i in range(n):
            bm.faces.new((r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.006, segments=1, affect='EDGES', clamp_overlap=True)
    return c._finish(group, bm, (0, 0, 0), (0, 0, 0))


def head(c):
    """Aggressive wedge head: flat sloping skull with cheekbones, angled brow blades over slit eyes, a jutting open
    jaw with chin and jaw-line spikes, a nose horn, fangs, swept-back horns, a frill and glowing face lines. Built
    level, then moved onto the neck by HEAD_M."""
    before = {g: len(obs) for g, obs in c.pieces.items()}
    skull = [(2.28, 2.3, 0.15, 0.13, -0.12), (2.45, 2.34, 0.19, 0.15, -0.11), (2.62, 2.35, 0.17, 0.13, -0.08),
             (2.8, 2.32, 0.13, 0.09, -0.07), (3.0, 2.29, 0.095, 0.065, -0.06), (3.16, 2.27, 0.06, 0.045, -0.05),
             (3.25, 2.26, 0.02, 0.02, -0.03)]
    loft(c, 'Body', skull)
    # Hinged into the skull at the back, opening toward the front.
    jaw = [(2.3, 2.21, 0.125, 0.06, -0.06), (2.55, 2.15, 0.11, 0.045, -0.055), (2.8, 2.12, 0.085, 0.035, -0.045),
           (3.0, 2.11, 0.06, 0.03, -0.04), (3.12, 2.11, 0.035, 0.025, -0.035)]
    loft(c, 'Body', jaw)
    for s in (-1, 1):
        # Brow ridge: a horn from above the eye sweeping up and back (low inner front, high outer back: a scowl).
        horn(c, [(s * 0.08, 2.8, 2.4), (s * 0.13, 2.62, 2.47), (s * 0.17, 2.45, 2.54)], 0.045)
        eye = ball(c, 'Light2', (s * 0.135, 2.69, 2.4), 0.04, (0.5, 1.9, 0.25))
        eye.rotation_euler = (0, s * 0.3, s * 0.3)
        ball(c, 'Trim', (s * 0.035, 3.17, 2.29), 0.014, seg=(6, 4))
        # Cheek blades and spikes along the jaw line and chin.
        horn(c, [(s * 0.17, 2.47, 2.25), (s * 0.27, 2.33, 2.24), (s * 0.34, 2.18, 2.28)], 0.032)
        for y, z, x in ((2.45, 2.13, 0.09), (2.68, 2.1, 0.07)):
            cone(c, 'Trim', (s * x, y, z), (s * (x + 0.1), y - 0.17, z - 0.07), 0.025, 5)
        cone(c, 'Trim', (s * 0.03, 3.0, 2.08), (s * 0.05, 2.86, 1.97), 0.022, 5)
        # Swept-back horns and the frill.
        horn(c, [(s * 0.09, 2.42, 2.45), (s * 0.15, 2.25, 2.62), (s * 0.17, 2.0, 2.72), (s * 0.15, 1.75, 2.76)], 0.055)
        for dx, dz, ln in ((0.1, 0.16, 0.42), (0.15, 0.06, 0.36), (0.16, -0.05, 0.28)):
            base = (s * 0.09, 2.36, 2.3 + dz * 0.5)
            horn(c, [base, (s * (0.09 + dx * 0.7), 2.36 - ln * 0.5, 2.3 + dz), (s * (0.09 + dx), 2.36 - ln, 2.3 + dz * 1.3)],
                 0.026)
        # Fangs, then rows of small teeth on both jaws.
        cone(c, 'Light2', (s * 0.07, 3.0, 2.25), (s * 0.07, 3.0, 2.1), 0.02, 5)
        cone(c, 'Light2', (s * 0.05, 3.07, 2.13), (s * 0.05, 3.07, 2.24), 0.016, 5)
        for i in range(6):
            y = 2.6 + i * 0.07
            x = s * (0.11 - i * 0.013)
            cone(c, 'Light2', (x, y, 2.27), (x, y, 2.2), 0.011, 4)
            cone(c, 'Light2', (x * 0.85, y - 0.03, 2.15), (x * 0.85, y - 0.03, 2.21), 0.01, 4)
    cone(c, 'Trim', (0, 3.02, 2.31), (0, 2.88, 2.4), 0.025, 6)  # nose horn, raked back
    ball(c, 'Light', (0, 2.8, 2.2), 0.05, (1.2, 3, 0.4))  # glowing mouth
    for s in (-1, 1):
        # Glowing face lines from the eye to the nose and back along the cheek.
        skin(c, 'Light', [(s * 0.155, 2.7, 2.37, 0.012, 0.012), (s * 0.11, 2.95, 2.32, 0.01, 0.01),
                          (s * 0.06, 3.15, 2.29, 0.007, 0.007)], subdiv=0)
        skin(c, 'Light', [(s * 0.16, 2.62, 2.36, 0.011, 0.011), (s * 0.19, 2.42, 2.3, 0.009, 0.009),
                          (s * 0.2, 2.25, 2.28, 0.006, 0.006)], subdiv=0)
        # Smoke tendril curling back from the jaw hinge.
        horn(c, [(s * 0.12, 2.36, 2.12), (s * 0.22, 2.15, 2.02), (s * 0.2, 1.95, 1.9), (s * 0.27, 1.78, 1.86)], 0.022)
    for g, obs in c.pieces.items():
        for ob in obs[before.get(g, 0):]:
            ob.matrix_world = HEAD_M @ ob.matrix_world


def wyvern():
    c = Wyvern('ember_wyvern', COLORS)
    legs = [
        (6, [(0.26, -0.8, 1.12, 0.16, 0.16), (0.36, -0.55, 0.72, 0.11, 0.11), (0.33, -0.95, 0.48, 0.065, 0.065),
             (0.33, -1.15, 0.38, 0.05, 0.045)]),
    ]
    skin(c, 'Body', SPINE, branches=legs, mirror=True, subdiv=2)
    head(c)
    # Belly plates: overlapping amber bands under the spine from chin to tail, pitched along the spine.
    y = 2.35
    while y > -2.95:
        x, z, rx, rz = along(y)
        x2, z2, _, _ = along(y - 0.1)
        pitch = math.atan2(z - z2, 0.1)
        w = rx * 1.25
        c.box('Light' if y > -0.6 else 'Accent', (x, y, z - rz * 0.86), (w, 0.13, 0.04), bevel=0.012,
              rot=(pitch, 0, 0))  # the chest glows (reference), the belly and tail plates fade to textured teal
        y -= 0.11 if y > -1.5 else 0.13
    # Dorsal spikes: neck to tail tip, a big ridge over the back, small over the tail; paired side spikes on the tail.
    y = 2.05
    i = 0
    while y > -3.15:
        x, z, rx, rz = along(y)
        h = 0.05 + 0.18 * max(0.0, min(1.0, rz / 0.3)) + (0.03 if i % 2 else 0)
        cone(c, 'Trim', (x, y + 0.03, z + rz * 0.85), (x, y - 0.12, z + rz + h), 0.03 + rz * 0.12, 5)
        if y < -1.5 and i % 2 == 0:
            for s in (-1, 1):
                cone(c, 'Trim', (x + s * rx * 0.8, y, z), (x + s * (rx + 0.12), y - 0.1, z + 0.03), 0.02, 4)
        y -= 0.15
        i += 1
    # Raised diamond scutes in staggered rows over the back, flanks and neck (geometry the silhouette can show).
    row = 0
    y = 2.1
    while y > -2.75:
        x, z, rx, rz = along(y)
        size = 0.03 + 0.07 * rz
        for k, th in enumerate((0.42, 0.9, 1.38)):
            yy = y - (0.06 if k % 2 else 0.0)
            for s in (-1, 1):
                n = Vector((s * math.sin(th) / max(rx, 1e-3), 0, math.cos(th) / max(rz, 1e-3))).normalized()
                base = Vector((x + s * math.sin(th) * rx, yy, z + math.cos(th) * rz)) - n * 0.012
                cone(c, 'Body', base, base + n * size * 0.5 + Vector((0, -size * 0.7, 0)), size, 4)
        y -= 0.12
        row += 1
    # Tail tip barb.
    x, z, _, _ = along(-3.2)
    cone(c, 'Trim', (x, -3.12, z), (x, -3.28, z + 0.02), 0.05, 6)
    # Smoke tendrils trailing off the tail tip and the hips (shadow look).
    for s in (-1, 1):
        x, z, _, _ = along(-2.9)
        horn(c, [(x, -2.9, z), (x + s * 0.15, -3.05, z + 0.12), (x + s * 0.12, -3.2, z + 0.25)], 0.02)
        horn(c, [(s * 0.3, -0.7, 1.2), (s * 0.45, -1.0, 1.05), (s * 0.42, -1.35, 0.95), (s * 0.5, -1.6, 0.98)], 0.022)
    # Feet: three toes with hooked claws each, plus a dew claw.
    for s in (-1, 1):
        foot = Vector((s * 0.33, -1.15, 0.38))
        for dx in (-0.07, 0.0, 0.07):
            claw(c, foot + Vector((s * dx, -0.04, -0.02)), (s * dx * 0.8, -1, -0.5), 0.2, 0.025)
        claw(c, foot + Vector((s * 0.02, 0.06, 0.05)), (0, 0.6, -0.6), 0.12, 0.02)
    wing(c, -1)
    wing(c, 1)
    return c


def procedural(kind, normal=False):
    """Bake material (object-space, so it lines up across the joined pieces): Emission = the colour map, or with
    normal=True a Principled BSDF bumped by the same pattern's height, for the normal-map bake."""
    mat = bpy.data.materials.new('bake_' + kind + ('_n' if normal else ''))
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N = nt.nodes.new
    out = N('ShaderNodeOutputMaterial')
    em = N('ShaderNodeEmission')
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    coord = N('ShaderNodeTexCoord')

    def ramp(fac, stops):
        r = N('ShaderNodeValToRGB')
        cr = r.color_ramp
        cr.elements[0].position, cr.elements[0].color = stops[0][0], (*stops[0][1], 1)
        cr.elements[1].position, cr.elements[1].color = stops[-1][0], (*stops[-1][1], 1)
        for pos, col in stops[1:-1]:
            e = cr.elements.new(pos)
            e.color = (*col, 1)
        nt.links.new(fac, r.inputs['Fac'])
        return r.outputs['Color']

    def mix(fac, a, b, blend='MIX'):
        m = N('ShaderNodeMix')
        m.data_type = 'RGBA'
        m.blend_type = blend
        socks = [s for s in m.inputs if s.type == 'RGBA']
        if isinstance(fac, float):
            m.inputs['Factor'].default_value = fac
        else:
            nt.links.new(fac, m.inputs['Factor'])
        for sock, v in zip(socks, (a, b)):
            if isinstance(v, tuple):
                sock.default_value = (*v, 1)
            else:
                nt.links.new(v, sock)
        return next(s for s in m.outputs if s.type == 'RGBA')

    def voronoi(scale, feature='DISTANCE_TO_EDGE'):
        v = N('ShaderNodeTexVoronoi')
        v.feature = feature
        v.inputs['Scale'].default_value = scale
        nt.links.new(coord.outputs['Object'], v.inputs['Vector'])
        return v

    def noise(scale):
        n = N('ShaderNodeTexNoise')
        n.inputs['Scale'].default_value = scale
        nt.links.new(coord.outputs['Object'], n.inputs['Vector'])
        return n.outputs['Fac']

    # Scales big enough to read at racing distance (owner 2026-10-27: "too smooth"): plates of about 0.1 stud with a
    # thin glowing cyan seam, a dark groove, a lighter rim and a dark centre, plus fine scales inside each plate.
    def scales():
        edge = ramp(voronoi(11).outputs['Distance'],
                    [(0.0, (0.0, 0.5, 0.7)), (0.018, (0.003, 0.004, 0.008)), (0.05, (0.045, 0.05, 0.07)),
                     (0.25, (0.01, 0.012, 0.02))])
        fine = ramp(voronoi(34).outputs['Distance'], [(0.0, (0.45, 0.45, 0.5)), (0.07, (1, 1, 1))])
        cell = voronoi(11, 'F1')
        return mix(0.3, mix(1.0, edge, fine, 'MULTIPLY'), cell.outputs['Color'], 'MULTIPLY')

    def scales_height():
        big = ramp(voronoi(11).outputs['Distance'], [(0.0, (0, 0, 0)), (0.07, (0.85, 0.85, 0.85)), (0.35, (1, 1, 1))])
        fine = ramp(voronoi(34).outputs['Distance'], [(0.0, (0.55, 0.55, 0.55)), (0.1, (1, 1, 1))])
        return mix(1.0, big, fine, 'MULTIPLY')

    if normal:
        nt.nodes.remove(em)
        bsdf = N('ShaderNodeBsdfPrincipled')
        nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
        bump = N('ShaderNodeBump')
        bump.inputs['Strength'].default_value = 0.8
        bump.inputs['Distance'].default_value = 0.02
        nt.links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
        if kind == 'scales':
            h = scales_height()
        elif kind == 'horn':  # growth ridges
            h = ramp(noise(24), [(0.3, (0.82, 0.82, 0.82)), (0.7, (1, 1, 1))])
        elif kind == 'plates':
            h = ramp(noise(14), [(0.3, (0.6, 0.6, 0.6)), (0.7, (1, 1, 1))])
        else:  # wing: bones scaled, membrane nearly flat with faint raised veins
            wave = N('ShaderNodeTexWave')
            wave.inputs['Scale'].default_value = 1.6
            wave.inputs['Distortion'].default_value = 6
            nt.links.new(coord.outputs['Object'], wave.inputs['Vector'])
            membrane = ramp(wave.outputs['Fac'], [(0.0, (1, 1, 1)), (0.04, (0.7, 0.7, 0.7))])
            attr = N('ShaderNodeAttribute')
            attr.attribute_name = 'kind'
            h = mix(attr.outputs['Fac'], scales_height(), membrane)
        nt.links.new(h, bump.inputs['Height'])
        return mat

    if kind == 'scales':
        col = scales()
    elif kind == 'horn':
        col = ramp(noise(9), [(0.3, (0.012, 0.011, 0.012)), (0.7, (0.07, 0.06, 0.055))])
    elif kind == 'plates':
        col = ramp(noise(7), [(0.3, (0.02, 0.08, 0.13)), (0.45, (0.08, 0.5, 0.68)), (0.8, (0.3, 0.92, 1.0))])
    else:  # wing: mottled amber membrane, dark veins, darker toward the bones; bones (kind 0) get the scales
        mott = ramp(noise(3), [(0.35, (0.02, 0.28, 0.6)), (0.6, (0.12, 0.68, 0.95)), (0.8, (0.45, 0.95, 1.0))])
        wave = N('ShaderNodeTexWave')
        wave.inputs['Scale'].default_value = 1.6
        wave.inputs['Distortion'].default_value = 6
        nt.links.new(coord.outputs['Object'], wave.inputs['Vector'])
        veins = ramp(wave.outputs['Fac'], [(0.0, (0.35, 0.45, 0.6)), (0.04, (1, 1, 1))])  # faint veins
        membrane = mix(1.0, mott, veins, 'MULTIPLY')
        attr = N('ShaderNodeAttribute')
        attr.attribute_name = 'kind'
        col = mix(attr.outputs['Fac'], scales(), membrane)
    nt.links.new(col, em.inputs['Color'])
    return mat


class Wyvern(Car):
    def _preview(self, out):
        """Bake the textures, then render the car preview angle (framed for the raised wings) and four views."""
        self._texture(out)
        scene = self.scene
        cam = bpy.data.objects.new('Preview', bpy.data.cameras.new('Preview'))
        scene.collection.objects.link(cam)
        cam.data.type = 'ORTHO'
        scene.camera = cam
        # EEVEE, so the normal maps and the Neon glow show (Workbench draws neither).
        for engine in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
            try:
                scene.render.engine = engine
                break
            except TypeError:
                pass
        scene.render.resolution_x, scene.render.resolution_y = 724, 543
        world = scene.world = bpy.data.worlds.new('PreviewWorld')
        world.use_nodes = True
        bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
        bg.inputs['Color'].default_value = (0.62, 0.64, 0.68, 1)
        bg.inputs['Strength'].default_value = 0.7
        for rot, power in (((math.radians(50), 0, math.radians(35)), 4.0), ((math.radians(70), 0, math.radians(-140)), 1.5)):
            sun = bpy.data.objects.new('PreviewSun', bpy.data.lights.new('PreviewSun', 'SUN'))
            sun.data.energy = power
            sun.rotation_euler = rot
            scene.collection.objects.link(sun)
        target = Vector((0, 0, 2.2))
        views = {'preview': ((7.5, 7.5, 6.2), 10.5), 'side': ((12, 0, 0), 8.4), 'front': ((0, 12, 0), 6.5),
                 'top': ((0, 0, 14), 8.4), 'rear34': ((-7, -9, 5), 10.5), 'head': ((2.2, 3.2, 0.9), 1.9)}
        (out / 'views').mkdir(exist_ok=True)
        for name, (loc, scale) in views.items():
            aim = HEAD_M @ Vector((0, 2.65, 2.3)) if name == 'head' else target
            cam.location = Vector(loc) + aim
            look = aim if name != 'top' else aim + Vector((0, 0.001, 0))
            cam.rotation_euler = (look - cam.location).to_track_quat('-Z', 'Y').to_euler()
            cam.data.ortho_scale = scale
            scene.render.filepath = str(out / ('preview.png' if name == 'preview' else 'views/%s.png' % name))
            with bpy.context.temp_override(scene=scene):
                bpy.ops.render.render(write_still=True)

    def _texture(self, out):
        scene = self.scene
        scene.render.engine = 'CYCLES'
        scene.cycles.samples = 4
        scene.cycles.device = 'CPU'
        tex = out / 'textures'
        tex.mkdir(exist_ok=True)
        layer = scene.view_layers[0]
        for name, (kind, res) in TEXTURE.items():
            ob = scene.objects.get(name)
            tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
            assert tris <= MESH_LIMIT, (name, tris)
            for o in scene.objects:
                o.select_set(False)
            ob.select_set(True)
            layer.objects.active = ob
            ctx = dict(scene=scene, view_layer=layer, active_object=ob, object=ob, selected_objects=[ob],
                       selected_editable_objects=[ob])
            with bpy.context.temp_override(**ctx):
                bpy.ops.object.mode_set(mode='EDIT')
                bpy.ops.mesh.select_all(action='SELECT')
                bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
                bpy.ops.object.mode_set(mode='OBJECT')
            img = bpy.data.images.new('ember_wyvern_' + name, res, res)
            mat = procedural(kind)
            node = mat.node_tree.nodes.new('ShaderNodeTexImage')
            node.image = img
            mat.node_tree.nodes.active = node
            ob.data.materials.clear()
            ob.data.materials.append(mat)
            with bpy.context.temp_override(**ctx):
                bpy.ops.object.bake(type='EMIT', margin=6, use_clear=True)
            img.filepath_raw = str(tex / ('%s.png' % name))
            img.file_format = 'PNG'
            img.save()
            img.pack()
            # Normal map from the same pattern's height (scale relief without triangles).
            nimg = bpy.data.images.new('ember_wyvern_%s_normal' % name, res, res)
            nimg.colorspace_settings.name = 'Non-Color'
            nmat = procedural(kind, normal=True)
            node = nmat.node_tree.nodes.new('ShaderNodeTexImage')
            node.image = nimg
            nmat.node_tree.nodes.active = node
            ob.data.materials.clear()
            ob.data.materials.append(nmat)
            with bpy.context.temp_override(**ctx):
                bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT', margin=6, use_clear=True)
            nimg.filepath_raw = str(tex / ('%s_normal.png' % name))
            nimg.file_format = 'PNG'
            nimg.save()
            nimg.pack()
            # Final material: the baked image as base colour.
            final = bpy.data.materials.new('ember_wyvern_' + name)
            final.use_nodes = True
            bsdf = next(n for n in final.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
            it = final.node_tree.nodes.new('ShaderNodeTexImage')
            it.image = img
            final.node_tree.links.new(it.outputs['Color'], bsdf.inputs['Base Color'])
            nt_ = final.node_tree.nodes.new('ShaderNodeTexImage')
            nt_.image = nimg
            nm = final.node_tree.nodes.new('ShaderNodeNormalMap')
            final.node_tree.links.new(nt_.outputs['Color'], nm.inputs['Color'])
            final.node_tree.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
            bsdf.inputs['Roughness'].default_value = 0.5
            final.diffuse_color = (*COLORS[name], 1)
            ob.data.materials.clear()
            ob.data.materials.append(final)


def after_build(report):
    """Re-export the FBX with embedded textures, add the flap cycle to the .blend, record pivots and the mouth."""
    out = ROOT / 'drafts/cars/ember_wyvern/redesign'
    scene = bpy.data.scenes['Redesign_ember_wyvern']
    obs = [scene.objects[g] for g in report['parts']]
    turn = Matrix.Rotation(math.pi, 4, 'Z')  # same export turn as Car.finish
    for ob in obs:
        ob.matrix_world = turn @ ob.matrix_world
    with bpy.context.temp_override(scene=scene, selected_objects=obs, selected_editable_objects=obs, active_object=obs[0]):
        bpy.ops.export_scene.fbx(filepath=str(out / 'ember_wyvern.fbx'), use_selection=True, object_types={'MESH'},
                                 apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE', global_scale=0.01,
                                 axis_forward='-Z', axis_up='Y', mesh_smooth_type='OFF', add_leaf_bones=False,
                                 path_mode='COPY', embed_textures=True)
    for ob in obs:
        ob.matrix_world = turn.inverted() @ ob.matrix_world
    # Flap cycle (24 frames at 24 fps): wings pivot on their hinge about the body axis, downstroke then recovery.
    scene.frame_start, scene.frame_end, scene.render.fps = 1, 24, 24
    for name, s in (('Wing_L', -1), ('Wing_R', 1)):
        ob = scene.objects[name]
        hinge = Vector((s * WING_HINGE[0], WING_HINGE[1], WING_HINGE[2]))
        ob.data.transform(Matrix.Translation(-hinge))
        ob.location = hinge
        for frame, deg in ((1, -8), (8, 38), (16, 10), (24, -8)):
            ob.rotation_euler = (0, math.radians(deg) * s, 0)
            ob.keyframe_insert('rotation_euler', index=1, frame=frame)
        ob.animation_data.action.name = 'WingFlap_' + name
    bpy.data.libraries.write(str(out / 'ember_wyvern.blend'), {scene}, fake_user=True, compress=True)
    data = json.loads((out / 'parts.json').read_text())
    data['mouth'] = list(MOUTH)
    data['wing_hinge'] = {'Wing_L': [-WING_HINGE[0], *WING_HINGE[1:]], 'Wing_R': list(WING_HINGE)}
    data['textures'] = {name: 'textures/%s.png' % name for name in TEXTURE}
    data['part_tris'] = {ob.name: sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in obs}
    (out / 'parts.json').write_text(json.dumps(data, indent=2) + '\n')
    print('PARTS', json.dumps(data['part_tris']))


BUILDERS['wyvern'] = wyvern
after_build(build('wyvern'))
