"""Blender draft builder for tracks. Run inside Blender (e.g. through the Blender MCP):

    exec(open("/Users/alexnguyen7369/Documents/RobloxGames/drafts/_tools/blender_track_builder.py").read())
    S = build_track(spec, "Track02_Draft")

Mirrors the centreline maths of src/shared/TrackBuilder.luau. Scale: 1 Blender unit = 1 stud.
Blender coordinates are (x, y, z) = (Roblox x, -Roblox z, Roblox y), so forward is +Y and up is +Z.

spec = dict(width=40, closed=True, segs=[...]) with segments:
    ("S", length)                     straight
    ("T", angle_deg, radius)          flat turn, + = left
    ("H", run, rise)                  smooth hill/slope   (Roblox: Type = "Slope", Length, Rise)
    ("L", radius, shift)              vertical loop       (Roblox: Type = "Loop", Radius, Shift)
"""

import math

import bmesh
import bpy
from mathutils import Euler, Vector

WALL_H, WALL_T, GROUND = 5, 2, -1.0
UP = Vector((0, 0, 1))


def fwd(h):
    return Vector((-math.sin(h), math.cos(h), 0))


def left(h):
    return Vector((-math.cos(h), -math.sin(h), 0))


def clear_track():
    for c in list(bpy.data.collections):
        if c.name.startswith("Track") or c.name.startswith("Element"):
            for o in list(c.objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(c)
    for m in list(bpy.data.materials):
        if m.name.startswith("T_"):
            bpy.data.materials.remove(m)


def mat(name, col, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = col
    b.inputs["Roughness"].default_value = rough
    m.diffuse_color = col
    return m


def sample_path(spec):
    W = spec["width"]
    pos = Vector((0, 0, 0))
    h = 0.0
    S = [dict(p=pos.copy(), l=left(h), n=UP.copy(), turn=False, loop=False)]
    for seg in spec["segs"]:
        k = seg[0]
        if k == "S":
            n = math.ceil(seg[1] / 10)
            for i in range(1, n + 1):
                S.append(dict(p=pos + fwd(h) * seg[1] * i / n, l=left(h), n=UP.copy(), turn=False, loop=False))
            pos = pos + fwd(h) * seg[1]
        elif k == "T":
            th = math.radians(seg[1])
            R = seg[2]
            s = 1 if th >= 0 else -1
            c = pos + left(h) * R * s
            n = math.ceil(abs(seg[1]) / 3)
            d = th / n
            for i in range(1, n + 1):
                hh = h + d * i
                S.append(dict(p=c - left(hh) * R * s, l=left(hh), n=UP.copy(), turn=True, loop=False))
            pos = c - left(h + th) * R * s
            h += th
        elif k == "H":
            run, rise = seg[1], seg[2]
            n = math.ceil(run / 8)
            for i in range(1, n + 1):
                t = i / n
                p = pos + fwd(h) * run * t + Vector((0, 0, rise * (1 - math.cos(math.pi * t)) / 2))
                S.append(dict(p=p, l=left(h), n=UP.copy(), turn=False, loop=False))
            pos = pos + fwd(h) * run + Vector((0, 0, rise))
        elif k == "L":
            R = seg[1]
            shift = seg[2] if len(seg) > 2 else W + 10
            f, l, n = fwd(h), left(h), 72
            for i in range(1, n + 1):
                phi = 2 * math.pi * i / n
                p = (
                    pos
                    + f * R * math.sin(phi)
                    + UP * R * (1 - math.cos(phi))
                    + l * shift * (phi - math.sin(phi)) / (2 * math.pi)
                )
                T = (
                    f * R * math.cos(phi) + UP * R * math.sin(phi) + l * shift * (1 - math.cos(phi)) / (2 * math.pi)
                ).normalized()
                n0 = -f * math.sin(phi) + UP * math.cos(phi)
                N = (n0 - T * n0.dot(T)).normalized()
                S.append(dict(p=p, l=N.cross(T).normalized(), n=N, turn=False, loop=True))
            pos = pos + l * shift
    return S


def build_track(spec, coll_name):
    clear_track()
    W = spec["width"]
    closed = spec["closed"]
    M = dict(
        road=mat("T_Road", (0.42, 0.47, 0.58, 1)),
        side=mat("T_RoadSide", (0.30, 0.34, 0.44, 1)),
        wall=mat("T_Wall", (0.91, 0.94, 0.98, 1), 0.5),
        kp=mat("T_KerbPink", (1.0, 0.55, 0.62, 1), 0.5),
        kw=mat("T_KerbWhite", (0.98, 0.98, 1.0, 1), 0.5),
        grass=mat("T_Grass", (0.60, 0.86, 0.63, 1), 0.9),
        wl=mat("T_LineWhite", (1, 1, 1, 1), 0.4),
        wk=mat("T_LineDark", (0.15, 0.17, 0.22, 1), 0.4),
        arch=mat("T_Arch", (0.537, 0.812, 0.941, 1), 0.5),
        hill=mat("T_HillFill", (0.40, 0.72, 0.48, 1), 0.9),
    )
    order = list(M.keys())
    idx = {k: i for i, k in enumerate(order)}
    S = sample_path(spec)
    if closed and (S[-1]["p"] - S[0]["p"]).length < 1.0:
        S.pop()
    N = len(S)
    coll = bpy.data.collections.new(coll_name)
    bpy.context.scene.collection.children.link(coll)

    def new_obj(nm, bm):
        me = bpy.data.meshes.new(nm)
        bm.to_mesh(me)
        bm.free()
        for k in order:
            me.materials.append(M[k])
        o = bpy.data.objects.new(nm, me)
        coll.objects.link(o)
        return o

    def quad(bm, a, b, c, d, m):
        try:
            f = bm.faces.new((a, b, c, d))
            f.material_index = idx[m]
        except ValueError:
            pass

    def V(bm, q):
        return bm.verts.new(q)

    rng = range(N) if closed else range(N - 1)

    def off(s, o):
        return s["p"] + s["l"] * o

    # road: top, plus a fill down to the grass (hills) or a 2-stud skirt (loops)
    bm = bmesh.new()
    Lt = [V(bm, off(s, W / 2)) for s in S]
    Rt = [V(bm, off(s, -W / 2)) for s in S]
    Lb, Rb = [], []
    for s in S:
        if s["loop"]:
            Lb.append(V(bm, off(s, W / 2) - s["n"] * 2))
            Rb.append(V(bm, off(s, -W / 2) - s["n"] * 2))
        else:
            e = off(s, W / 2)
            Lb.append(V(bm, Vector((e.x, e.y, GROUND))))
            e = off(s, -W / 2)
            Rb.append(V(bm, Vector((e.x, e.y, GROUND))))
    for i in rng:
        j = (i + 1) % N
        quad(bm, Rt[i], Rt[j], Lt[j], Lt[i], "road")
        elevated = max(S[i]["p"].z, S[j]["p"].z) > 0.5 and not (S[i]["loop"] or S[j]["loop"])
        m = "hill" if elevated else "side"
        quad(bm, Lt[i], Lt[j], Lb[j], Lb[i], m)
        quad(bm, Rb[i], Rb[j], Rt[j], Rt[i], m)
        if S[i]["loop"] and S[j]["loop"]:
            quad(bm, Rb[i], Lb[i], Lb[j], Rb[j], "side")
    bm.normal_update()
    new_obj("Road", bm)

    # walls
    bm = bmesh.new()
    for sg in (1, -1):
        rings = []
        for s in S:
            a = s["p"] + s["l"] * sg * W / 2
            b = s["p"] + s["l"] * sg * (W / 2 + WALL_T)
            rings.append([V(bm, a), V(bm, a + s["n"] * WALL_H), V(bm, b + s["n"] * WALL_H), V(bm, b)])
        for i in rng:
            j = (i + 1) % N
            for k in range(4):
                quad(bm, rings[i][k], rings[j][k], rings[j][(k + 1) % 4], rings[i][(k + 1) % 4], "wall")
    bm.normal_update()
    new_obj("Walls", bm)

    # kerbs on flat turns
    bm = bmesh.new()
    KW = 3.0
    z = Vector((0, 0, 0.06))
    for sg in (1, -1):
        for i in rng:
            j = (i + 1) % N
            if not (S[i]["turn"] and S[j]["turn"]):
                continue
            m = "kp" if (i // 2) % 2 == 0 else "kw"
            a = off(S[i], sg * (W / 2 - KW)) + z
            b = off(S[i], sg * W / 2) + z
            c = off(S[j], sg * W / 2) + z
            d = off(S[j], sg * (W / 2 - KW)) + z
            if sg > 0:
                quad(bm, V(bm, a), V(bm, d), V(bm, c), V(bm, b), m)
            else:
                quad(bm, V(bm, a), V(bm, b), V(bm, c), V(bm, d), m)
    bm.normal_update()
    new_obj("Kerbs", bm)

    # checker start line
    bm = bmesh.new()
    cols, rows = 10, 2
    cw = W / cols
    y0 = 6 - 1.5
    rh = 1.5
    for r in range(rows):
        for c_ in range(cols):
            x0 = -W / 2 + c_ * cw
            vs = [
                V(bm, (x0, y0 + r * rh, 0.08)),
                V(bm, (x0 + cw, y0 + r * rh, 0.08)),
                V(bm, (x0 + cw, y0 + (r + 1) * rh, 0.08)),
                V(bm, (x0, y0 + (r + 1) * rh, 0.08)),
            ]
            f = bm.faces.new(vs)
            f.material_index = idx["wl"] if (r + c_) % 2 == 0 else idx["wk"]
    bm.normal_update()
    new_obj("StartLine", bm)

    # grass
    xs = [s["p"].x for s in S]
    ys = [s["p"].y for s in S]
    pad = W * 3 + 200
    bm = bmesh.new()
    vs = [
        V(bm, (min(xs) - pad, min(ys) - pad, GROUND)),
        V(bm, (max(xs) + pad, min(ys) - pad, GROUND)),
        V(bm, (max(xs) + pad, max(ys) + pad, GROUND)),
        V(bm, (min(xs) - pad, max(ys) + pad, GROUND)),
    ]
    f = bm.faces.new(vs)
    f.material_index = idx["grass"]
    bm.normal_update()
    new_obj("Grass", bm)

    # start arch
    def box(nm, size, loc):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        o = bpy.context.active_object
        o.name = nm
        o.scale = size
        bpy.ops.object.transform_apply(scale=True)
        o.data.materials.append(M["arch"])
        for c_ in list(o.users_collection):
            c_.objects.unlink(o)
        coll.objects.link(o)
        bv = o.modifiers.new("Soft", "BEVEL")
        bv.width = 0.6
        bv.segments = 3

    box("ArchPostL", (3, 3, 16), (-W / 2 - 3, 14, 8))
    box("ArchPostR", (3, 3, 16), (W / 2 + 3, 14, 8))
    box("ArchBeam", (W + 9, 3, 4), (0, 14, 17))

    # starter car at scale (car model is 1 unit = 3 studs)
    car = bpy.data.objects.get("Car")
    if car:
        car.parent = None
        car.scale = (3, 3, 3)
        car.rotation_euler = (0, 0, math.radians(90))
        car.location = (-9, -14, 0)
    return S


def set_view(center, dist, rx, rz):
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            sp = area.spaces[0]
            sp.shading.type = "MATERIAL"
            sp.clip_end = 6000
            sp.overlay.show_floor = False
            sp.overlay.show_axis_x = False
            sp.overlay.show_axis_y = False
            r = sp.region_3d
            r.view_perspective = "PERSP"
            r.view_location = Vector(center)
            r.view_distance = dist
            r.view_rotation = Euler((math.radians(rx), 0, math.radians(rz))).to_quaternion()


def save_draft(folder, blend_name, glb_name, coll_name):
    """Deselect, screenshot the viewport, export the collection to GLB and save the .blend."""
    import os

    os.makedirs(os.path.join(folder, "export"), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    area = next(a for a in bpy.context.screen.areas if a.type == "VIEW_3D")
    with bpy.context.temp_override(area=area, region=next(r for r in area.regions if r.type == "WINDOW")):
        bpy.ops.screen.screenshot_area(filepath=os.path.join(folder, "preview.png"))
    for o in bpy.data.collections[coll_name].objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(folder, "export", glb_name), use_selection=True, export_format="GLB"
    )
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(folder, blend_name))
    return sorted(os.listdir(folder))
