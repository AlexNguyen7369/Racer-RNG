"""Ember Wyvern draft 2 (drafts/cars/ember-wyvern/DRAFT.md): an organic dragon skin, no reference image.

Headless:  Blender -b --factory-startup --python drafts/cars/ember-wyvern/build_wyvern.py
Blender MCP:  exec(open('<repo>/drafts/cars/ember-wyvern/build_wyvern.py').read())

Reuses the Car class of tools/build_redesign_cars.py (material groups, budgets, FBX export, preview), so the output
follows docs/CAR_REDESIGN_SPEC.md: drafts/cars/ember_wyvern/redesign/. Blender axes: +Y forward (Roblox -Z), +Z up,
1 unit = 1 stud, origin at the base centre. Body, neck, tail, legs and jaw are Skin-modifier tubes (smooth organic
forms at a low triangle count); Wing_L / Wing_R are single parts so Client/BestRollView can flap them.
"""
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path('/Users/alexnguyen7369/Documents/RobloxGames')
exec(open(ROOT / 'tools/build_redesign_cars.py').read())

# Wings are their own groups: the flap needs one part per side (BestRollView looks for Wing_L / Wing_R exactly).
GROUP_MATERIAL['Wing_L'] = GROUP_MATERIAL['Wing_R'] = 'SmoothPlastic'

SCALE = (0.42, 0.05, 0.04)  # crimson scales
COLORS = {
    'Body': SCALE,
    'Trim': (0.05, 0.04, 0.045),  # horns, claws, dorsal spikes, tail blade
    'Accent': (0.16, 0.06, 0.04),  # belly plates
    'Light': (1.0, 0.36, 0.05),  # molten seams, throat, mouth glow (Neon)
    'Light2': (1.0, 0.85, 0.35),  # eyes (Neon)
    'Wing_L': (0.24, 0.035, 0.03),
    'Wing_R': (0.24, 0.035, 0.03),
    'Tyre': (0.1, 0.1, 0.1),  # unused, the finish() fallback
}

# Hinges (Blender coords) for the Roblox PivotOffset of each wing, and the mouth point for the fire breath VFX.
WING_HINGE = (0.42, 0.75, 1.72)
MOUTH = (0.0, 3.12, 2.02)


def skin(c, group, chain, branches=(), subdiv=1, mirror=False, ratio=1.0):
    """Organic tube through chain = [(x, y, z, rx, rz), ...]; branches = [(index, [(x, y, z, rx, rz), ...]), ...]
    hang off chain[index]. mirror adds the -x copy of every point with x != 0 (legs). ratio < 1 decimates (tri budget).
    Returns the evaluated object."""
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
    """Spike from base to tip (horns, claws, dorsal plates)."""
    base, tip = Vector(base), Vector(tip)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=radius, radius2=0.0, depth=(tip - base).length)
    ob = c._finish(group, bm, (base + tip) / 2, (0, 0, 0))
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((tip - base).normalized())
    return ob


def horn(c, points, radius):
    """Curved horn: tapering tube along points (base to tip)."""
    skin(c, 'Trim', [(*p, radius * (1 - i / len(points)) + 0.015, radius * (1 - i / len(points)) + 0.015)
                     for i, p in enumerate(points)], subdiv=1, ratio=0.45)


def ball(c, group, center, radius, squash=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=radius)
    for v in bm.verts:
        v.co = Vector(tuple(a * b for a, b in zip(v.co, squash)))
    return c._finish(group, bm, center, (0, 0, 0))


def wing(c, side):
    """Bat wing raised in a V: arm and three fingers (bones), a scalloped membrane, solidified so both faces render."""
    s = side
    shoulder = Vector((s * WING_HINGE[0], WING_HINGE[1], WING_HINGE[2]))
    elbow = Vector((s * 1.05, 0.95, 2.55))
    wrist = Vector((s * 1.55, 0.55, 3.35))
    tips = [Vector((s * 1.92, -0.35, 3.95)), Vector((s * 1.9, -1.25, 3.3)), Vector((s * 1.62, -1.95, 2.45))]
    root = Vector((s * 0.36, -1.35, 1.6))
    name = 'Wing_L' if s < 0 else 'Wing_R'
    # Membrane: fan from the wrist; each panel's trailing edge sags toward the body (scallops).
    bm = bmesh.new()
    rim = [shoulder, elbow, wrist]
    edge = [tips[0]]
    for a, b in zip(tips, tips[1:] + [root]):
        mid = (a + b) / 2
        sag = (wrist - mid).normalized() * 0.55
        edge += [mid + sag, b]
    vw = bm.verts.new(wrist)
    ve = [bm.verts.new(p) for p in edge]
    for a, b in zip(ve, ve[1:]):
        bm.faces.new((vw, a, b))
    # Inner panel: wrist, root, elbow, shoulder (the skin between arm and body).
    vs, vel = bm.verts.new(shoulder), bm.verts.new(elbow)
    bm.faces.new((vw, ve[-1], vs, vel))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mem = c._finish(name, bm, (0, 0, 0), (0, 0, 0))
    mod = mem.modifiers.new('Thick', 'SOLIDIFY')
    mod.thickness = 0.035
    mod.offset = 0
    deps = bpy.context.evaluated_depsgraph_get()
    solid = bpy.data.meshes.new_from_object(mem.evaluated_get(deps))
    mem.modifiers.clear()
    mem.data = solid
    # Bones: arm (shoulder-elbow-wrist) then the fingers, with a claw on the wrist thumb.
    skin(c, name, [(*shoulder, 0.13, 0.13), (*elbow, 0.1, 0.1), (*wrist, 0.08, 0.08)],
         branches=[(2, [(*t, 0.035, 0.035)]) for t in tips], subdiv=1, ratio=0.25)
    cone(c, 'Trim', wrist, wrist + Vector((s * 0.05, 0.28, 0.12)), 0.05)


class Wyvern(Car):
    def _preview(self, out):
        """Car preview angle, framed for the taller raised wings; also writes side / front / top / rear views."""
        scene = self.scene
        cam = bpy.data.objects.new('Preview', bpy.data.cameras.new('Preview'))
        scene.collection.objects.link(cam)
        cam.data.type = 'ORTHO'
        scene.camera = cam
        scene.render.engine = 'BLENDER_WORKBENCH'
        scene.render.resolution_x, scene.render.resolution_y = 724, 543
        scene.world = bpy.data.worlds.new('PreviewWorld')
        sh = scene.display.shading
        sh.light, sh.color_type, sh.background_type = 'STUDIO', 'MATERIAL', 'VIEWPORT'
        sh.background_color = (0.04, 0.04, 0.05)
        sh.show_shadows = sh.show_cavity = True
        target = Vector((0, 0, 1.9))
        views = {'preview': ((7.5, 7.5, 6.2), 9.5), 'side': ((12, 0, 1.9), 8.2), 'front': ((0, 12, 1.9), 6.5),
                 'top': ((0, 0, 14), 8.2), 'rear34': ((-7, -9, 5), 9.5)}
        (out / 'views').mkdir(exist_ok=True)
        for name, (loc, scale) in views.items():
            cam.location = Vector(loc) + (target if name != 'preview' else Vector((0, 0, 1.2)))
            look = target if name != 'top' else target + Vector((0, 0.001, 0))
            cam.rotation_euler = (look - cam.location).to_track_quat('-Z', 'Y').to_euler()
            cam.data.ortho_scale = scale
            scene.render.filepath = str(out / ('preview.png' if name == 'preview' else 'views/%s.png' % name))
            bpy.ops.render.render(write_still=True)


def wyvern():
    c = Wyvern('ember_wyvern', COLORS)
    # Spine: tail tip to the nose tip. (x, y, z, radius across, radius up)
    spine = [
        (0, -3.25, 1.05, 0.04, 0.04), (0, -2.75, 1.06, 0.09, 0.08), (0, -2.15, 1.12, 0.17, 0.15),
        (0, -1.5, 1.18, 0.28, 0.25), (0, -0.8, 1.22, 0.46, 0.42), (0, -0.05, 1.27, 0.56, 0.5),
        (0, 0.7, 1.38, 0.5, 0.47), (0, 1.25, 1.6, 0.34, 0.33), (0, 1.62, 1.88, 0.25, 0.24),
        (0, 1.95, 2.12, 0.22, 0.21), (0, 2.3, 2.27, 0.27, 0.24), (0, 2.68, 2.26, 0.22, 0.17),
        (0, 3.0, 2.2, 0.14, 0.11), (0, 3.24, 2.16, 0.07, 0.06),
    ]
    # Hind legs folded under the hips (glide pose), feet trailing.
    leg = [(0.42, -0.65, 1.0, 0.24, 0.24), (0.55, -0.25, 0.62, 0.17, 0.17), (0.5, -0.85, 0.42, 0.1, 0.1),
           (0.5, -1.2, 0.3, 0.08, 0.06)]
    skin(c, 'Body', spine, branches=[(4, leg)], mirror=True, subdiv=2, ratio=0.35)
    # Lower jaw, a little open for the fire breath.
    skin(c, 'Body', [(0, 2.35, 2.08, 0.2, 0.12), (0, 2.75, 1.98, 0.15, 0.08), (0, 3.12, 1.95, 0.08, 0.05)])
    # Head detail: brow ridges, nostrils.
    for s in (-1, 1):
        ball(c, 'Body', (s * 0.15, 2.62, 2.39), 0.11, (1, 1.8, 0.6))
        ball(c, 'Trim', (s * 0.06, 3.2, 2.22), 0.025)
    # Eyes (neon) under the brows.
    for s in (-1, 1):
        ball(c, 'Light2', (s * 0.2, 2.58, 2.31), 0.07, (0.7, 1.4, 0.75))
    # Horns: two long swept-back, two short cheek horns.
    for s in (-1, 1):
        horn(c, [(s * 0.14, 2.38, 2.42), (s * 0.24, 2.05, 2.7), (s * 0.3, 1.7, 2.85), (s * 0.3, 1.45, 2.8)], 0.075)
        horn(c, [(s * 0.22, 2.25, 2.18), (s * 0.36, 1.98, 2.25), (s * 0.42, 1.8, 2.22)], 0.045)
    # Teeth along the upper jaw.
    for s in (-1, 1):
        for y in (2.8, 2.95, 3.08):
            cone(c, 'Light2', (s * (0.24 - (y - 2.8) * 0.45), y, 2.1), (s * (0.22 - (y - 2.8) * 0.45), y, 2.0), 0.022, 4)
    # Mouth glow between the jaws and a molten throat.
    ball(c, 'Light', (0, 2.85, 2.04), 0.1, (0.9, 2.4, 0.35))
    ball(c, 'Light', (0, 1.55, 1.68), 0.13, (0.9, 1.6, 0.7))
    # Dorsal spikes from the neck to the tail tip, shrinking.
    for i in range(13):
        t = i / 12
        y = 2.05 - t * 4.9
        z = max(p[2] + p[4] for p in spine if abs(p[1] - y) == min(abs(q[1] - y) for q in spine))
        h = 0.28 * (1 - t) + 0.08
        cone(c, 'Trim', (0, y, z - 0.05), (0, y - 0.14, z + h), 0.08 * (1 - t) + 0.03, 5)
    # Tail blade (spade).
    bm = bmesh.new()
    pts = [(0, -2.65, 1.06), (0.32, -2.95, 1.06), (0, -3.3, 1.06), (-0.32, -2.95, 1.06)]
    bm.faces.new([bm.verts.new(p) for p in pts])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.05)
    c._finish('Trim', bm, (0, 0, 0), (0, 0, 0))
    # Belly plates (dark, overlapping) under chest and belly.
    for i in range(7):
        y = 1.05 - i * 0.36
        p = min(spine, key=lambda q: abs(q[1] - y))
        c.box('Accent', (0, y, p[2] - p[4] * 0.86), (p[3] * 1.15, 0.34, 0.1), bevel=0.03, rot=(math.radians(-6), 0, 0))
    # Molten seams: glowing cracks along both flanks and the spine.
    for s in (-1, 1):
        seam = [(s * 0.47, 0.65, 1.45, 0.045, 0.045), (s * 0.55, -0.1, 1.33, 0.055, 0.055),
                (s * 0.45, -0.85, 1.3, 0.045, 0.045), (s * 0.25, -1.55, 1.22, 0.035, 0.035), (s * 0.12, -2.2, 1.15, 0.025, 0.025)]
        skin(c, 'Light', seam, subdiv=0, ratio=0.5)
    for s in (-1, 1):
        # Claws on the folded feet.
        for dx in (-0.06, 0.06):
            cone(c, 'Trim', (s * (0.5 + dx), -1.25, 0.3), (s * (0.5 + dx), -1.45, 0.16), 0.035, 5)
    wing(c, -1)
    wing(c, 1)
    return c


def mouth_marker(report):
    """Record the VFX and flap points next to the export (no geometry: the Roblox side adds the Attachments)."""
    import json
    out = ROOT / 'drafts/cars/ember_wyvern/redesign/parts.json'
    data = json.loads(out.read_text())
    data['mouth'] = list(MOUTH)
    data['wing_hinge'] = {'Wing_L': [-WING_HINGE[0], *WING_HINGE[1:]], 'Wing_R': list(WING_HINGE)}
    out.write_text(json.dumps(data, indent=2) + '\n')


BUILDERS['wyvern'] = wyvern
report = build('wyvern')
mouth_marker(report)
