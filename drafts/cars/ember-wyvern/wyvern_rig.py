"""Ember Wyvern rig (docs/WYVERN_FLIGHT_SPEC.md section 2), exec'd by build_wyvern.py after the parts are joined.

rig(scene, parts, points) adds one armature with the spec's bones and skins every part to it with distance weights
(each vertex follows its two nearest allowed bones, inverse-distance to the fourth power, so joints bend smoothly).
Body-group parts use the body bones; Wing_L / Wing_R use their wing bones; the lower jaw (below the mouth line in head
space) follows Jaw rigidly and the rest of the head follows Head. Blender axes: +Y forward, +Z up, 1 unit = 1 stud.
"""
import bpy
from mathutils import Vector


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def bones_for(points):
    """[(name, head, tail, parent)] from the builder's points: spine (tail tip to neck end), head, jaw, legs, wings."""
    sp = [Vector((x, y, z)) for x, y, z, _, _ in points['spine']]
    hip = points['hip']  # SPINE index of the hips (legs branch there)
    out = [('Root', sp[hip + 1], sp[hip + 2], None), ('Spine1', sp[hip + 2], sp[hip + 3], 'Root'),
           ('Spine2', sp[hip + 3], sp[hip + 4], 'Spine1')]
    neck = sp[hip + 4:]
    parent = 'Spine2'
    for i in range(4):
        name = 'Neck%d' % (i + 1)
        out.append((name, neck[i], neck[i + 1], parent))
        parent = name
    head_m = points['head_m']
    out.append(('Head', neck[4], head_m @ Vector((0, 3.0, 2.3)), 'Neck4'))
    out.append(('Jaw', head_m @ Vector((0, 2.32, 2.18)), head_m @ Vector((0, 3.1, 2.1)), 'Head'))
    # Tail from the hips back to the tip: Tail1 starts at the Root head.
    tail = [sp[hip + 1]] + sp[hip::-1]
    # Six bones spread evenly from the hips to the tip.
    tail = [tail[round(i * (len(tail) - 1) / 6)] for i in range(7)]
    parent = 'Root'
    for i in range(6):
        name = 'Tail%d' % (i + 1)
        out.append((name, tail[i], tail[i + 1], parent))
        parent = name
    for s, side in ((-1, 'L'), (1, 'R')):
        leg = [Vector((s * x, y, z)) for x, y, z in points['leg']]
        out.append(('Thigh_' + side, leg[0], leg[1], 'Tail1'))
        out.append(('Shin_' + side, leg[1], leg[2], 'Thigh_' + side))
        w = points['wing'](s)
        out.append(('Arm_' + side, w['shoulder'], w['elbow'], 'Spine2'))
        out.append(('Fore_' + side, w['elbow'], w['wrist'], 'Arm_' + side))
        hand_tail = w['wrist'] + (w['wrist'] - w['elbow']).normalized() * 0.15
        out.append(('Hand_' + side, w['wrist'], hand_tail, 'Fore_' + side))
        for k, tip in enumerate(w['tips']):
            out.append(('Finger%d_%s' % (k + 1, side), w['wrist'], tip, 'Hand_' + side))
    return out


def rig(scene, parts, points):
    """Build the armature 'WyvernRig' and skin parts to it. Returns the armature object."""
    arm = bpy.data.armatures.new('WyvernRig')
    rig_ob = bpy.data.objects.new('WyvernRig', arm)
    scene.collection.objects.link(rig_ob)
    layer = scene.view_layers[0]
    layer.objects.active = rig_ob
    spec = bones_for(points)
    with bpy.context.temp_override(scene=scene, view_layer=layer, active_object=rig_ob, object=rig_ob,
                                   selected_objects=[rig_ob], selected_editable_objects=[rig_ob]):
        bpy.ops.object.mode_set(mode='EDIT')
        for name, head, tail, parent in spec:
            eb = arm.edit_bones.new(name)
            eb.head, eb.tail = head, tail
            if (tail - head).length < 1e-3:
                eb.tail = head + Vector((0, 0.05, 0))
            if parent:
                eb.parent = arm.edit_bones[parent]
            eb.use_connect = False
        bpy.ops.object.mode_set(mode='OBJECT')
    segs = {name: (head, tail) for name, head, tail, _ in spec}
    body = [n for n, *_ in spec if not n.startswith(('Arm_', 'Fore_', 'Hand_', 'Finger', 'Jaw', 'Head'))]
    head_inv = points['head_m'].inverted()
    for ob in parts:
        if ob.name.startswith('Wing_'):
            side = ob.name[-1]
            allowed = [n for n in segs if n.endswith('_' + side) and n.startswith(('Arm_', 'Fore_', 'Hand_', 'Finger'))]
        else:
            allowed = body
        groups = {n: ob.vertex_groups.new(name=n) for n in allowed + (['Head', 'Jaw'] if not ob.name.startswith('Wing_') else [])}
        for v in ob.data.vertices:
            p = ob.matrix_world @ v.co
            if not ob.name.startswith('Wing_'):
                local = head_inv @ p
                if local.y > 2.28 and p.y > segs['Head'][0].y - 0.05:  # in the head
                    groups['Jaw' if local.z < 2.19 and local.y > 2.32 else 'Head'].add([v.index], 1.0, 'REPLACE')
                    continue
            near = sorted((_seg_dist(p, *segs[n]), n) for n in allowed)[:2]
            ws = [1.0 / (d ** 4 + 1e-6) for d, _ in near]
            total = sum(ws)
            for (d, n), w in zip(near, ws):
                groups[n].add([v.index], w / total, 'REPLACE')
        mod = ob.modifiers.new('WyvernRig', 'ARMATURE')
        mod.object = rig_ob
    return rig_ob
