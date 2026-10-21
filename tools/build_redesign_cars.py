"""Car art redesign (docs/CAR_REDESIGN_SPEC.md). Execute through the Blender MCP:

    exec(open('/Users/alexnguyen7369/Documents/RobloxGames/tools/build_redesign_cars.py').read())
    build('go_kart')

Each car is hand-built from bevelled primitives against references/car_redesign/<Name>.png, then joined into one
mesh per material group (MeshPart per group in Roblox, colour from the part's Color/Material, no textures).
Blender axes: +Y forward (Roblox -Z), +Z up, 1 unit = 1 stud, origin at the base centre.
"""
import bpy
import bmesh
import json
import colorsys
import math
import re
from pathlib import Path
from mathutils import Euler, Matrix, Vector

ROOT = Path('/Users/alexnguyen7369/Documents/RobloxGames')
MAX_X, MAX_Y, MAX_TRIS = 1.95, 3.3, 6000

ROBLOX_TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

# Material group -> Roblox Material. Wheel_* parts are tyres (Tyre material); hubs go in Metal.
GROUP_MATERIAL = {
    'Body': 'SmoothPlastic', 'Trim': 'SmoothPlastic', 'Accent': 'SmoothPlastic', 'Metal': 'Metal',
    'Glass': 'Glass', 'Light': 'Neon', 'Tyre': 'SmoothPlastic',
}


class Car:
    def __init__(self, car_id, colors, seg=1):
        self.seg = seg  # bevel segments: 1 = the flat chamfer of the references, 2 = rounder (Go-Kart)
        self.view = 'front'  # preview camera: 'front' (original roster refs) or 'rear' (expansion refs)
        self.id = car_id
        self.colors = colors  # group -> (r, g, b) 0..1
        self.pieces = {}  # group or wheel name -> [objects]
        self.scene = bpy.data.scenes.new('Redesign_' + car_id)
        bpy.context.window.scene = self.scene

    def _take(self, group, ob):
        self.scene.collection.objects.link(ob)
        self.pieces.setdefault(group, []).append(ob)
        return ob

    def box(self, group, center, size, bevel=0.06, taper=None, rot=(0, 0, 0)):
        """Bevelled box. taper=(sx, sy) shrinks the top face (chamfered roof / sloped nose)."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1)
        for v in bm.verts:
            v.co.x *= size[0]
            v.co.y *= size[1]
            v.co.z *= size[2]
            if taper and v.co.z > 0:
                v.co.x *= taper[0]
                v.co.y *= taper[1]
                if len(taper) > 2:
                    v.co.y += taper[2]  # shift the top face forward (+) or back (-)
        if bevel > 0:
            bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=self.seg, profile=0.5, affect='EDGES')
        return self._finish(group, bm, center, rot)

    def cyl(self, group, center, radius, depth, axis='X', verts=16, bevel=0.03, rot=None):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=radius, radius2=radius, depth=depth)
        if bevel > 0:
            rim = [e for e in bm.edges if abs(e.verts[0].co.z) > depth / 2 - 1e-4 and abs(e.verts[1].co.z) > depth / 2 - 1e-4]
            bmesh.ops.bevel(bm, geom=rim, offset=bevel, segments=2, profile=0.5, affect='EDGES')
        r = rot or {'X': (0, math.pi / 2, 0), 'Y': (math.pi / 2, 0, 0), 'Z': (0, 0, 0)}[axis]
        return self._finish(group, bm, center, r)

    def tube(self, group, a, b, radius=0.07, verts=10):
        a, b = Vector(a), Vector(b)
        d = b - a
        ob = self.cyl(group, (a + b) / 2, radius, d.length, axis='Z', verts=verts, bevel=0)
        ob.rotation_mode = 'QUATERNION'
        ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
        return ob

    def _finish(self, group, bm, center, rot):
        mesh = bpy.data.meshes.new(group)
        bm.to_mesh(mesh)
        bm.free()
        ob = bpy.data.objects.new(group, mesh)
        ob.location = center
        ob.rotation_euler = rot
        return self._take(group, ob)

    def prim(self, group, shape, pos, size, rot, bevel=None):
        """One recipe part, built in Roblox coordinates (x, y up, -z forward) and converted to Blender (x, -z, y)."""
        sx, sy, sz = size
        bm = bmesh.new()
        if shape == 'Cylinder':  # Roblox cylinders run along local X; size = (length, diameter, diameter)
            bmesh.ops.create_cone(bm, cap_ends=True, segments=20 if group.startswith('Wheel_') else 12,
                                  radius1=sy / 2, radius2=sy / 2, depth=sx)
            rim = [e for e in bm.edges if all(abs(abs(v.co.z) - sx / 2) < 1e-4 for v in e.verts)]
            b = bevel if bevel is not None else min(0.1, sx * 0.2, sy * 0.15)
            if b > 0.01:
                bmesh.ops.bevel(bm, geom=rim, offset=b, segments=1, profile=0.5, affect='EDGES')
            bm.transform(Matrix.Rotation(math.pi / 2, 4, 'Y'))
        elif shape == 'Ball':
            bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=sx / 2)
        else:
            if shape == 'Wedge':  # Roblox WedgePart: full bottom, tall at +Z, slope facing -Z
                co = [(-.5, -.5, -.5), (.5, -.5, -.5), (-.5, -.5, .5), (.5, -.5, .5), (-.5, .5, .5), (.5, .5, .5)]
                vs = [bm.verts.new((x * sx, y * sy, z * sz)) for x, y, z in co]
                for f in ((0, 1, 3, 2), (2, 3, 5, 4), (0, 4, 5, 1), (0, 2, 4), (1, 5, 3)):
                    bm.faces.new([vs[i] for i in f])
                bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
            else:
                bmesh.ops.create_cube(bm, size=1)
                bm.transform(Matrix.Diagonal((sx, sy, sz, 1)))
            b = bevel if bevel is not None else min(0.06, min(size) * 0.22)
            if b > 0.008:
                bmesh.ops.bevel(bm, geom=bm.edges[:], offset=b, segments=1, profile=0.5, affect='EDGES', clamp_overlap=True)
        rotation = Euler(tuple(math.radians(v) for v in rot), 'XYZ').to_matrix().to_4x4()
        bm.transform(ROBLOX_TO_BLENDER @ Matrix.Translation(pos) @ rotation)
        return self._finish(group, bm, (0, 0, 0), (0, 0, 0))

    def wheel(self, name, center, radius, width, hub_color_group='Metal', hub_sides=8, cap_group='Trim', hub_scale=0.48):
        """Tyre (its own Wheel_* part, bevelled shoulders) plus an octagonal hub cap in the Metal group."""
        side = 1 if center[0] > 0 else -1
        self.cyl(name, center, radius, width, verts=20, bevel=min(0.12, radius * 0.22))
        cap = (center[0] + side * (width / 2 + 0.02), center[1], center[2])
        self.cyl(hub_color_group, cap, radius * hub_scale, 0.1, verts=hub_sides, bevel=0.02)
        self.cyl(cap_group, (cap[0] + side * 0.06, cap[1], cap[2]), radius * 0.16, 0.06, verts=hub_sides, bevel=0)

    def torus(self, group, center, major, minor, rot=(0, 0, 0), segments=24, ring=6):
        """A ring lying in the local XY plane (Saturn ring, halo)."""
        bm = bmesh.new()
        grid = [[bm.verts.new(((major + minor * math.cos(b)) * math.cos(a), (major + minor * math.cos(b)) * math.sin(a),
                               minor * math.sin(b)))
                 for b in (2 * math.pi * j / ring for j in range(ring))]
                for a in (2 * math.pi * i / segments for i in range(segments))]
        for i in range(segments):
            for j in range(ring):
                bm.faces.new((grid[i][j], grid[(i + 1) % segments][j], grid[(i + 1) % segments][(j + 1) % ring],
                              grid[i][(j + 1) % ring]))
        return self._finish(group, bm, center, rot)

    def cone(self, group, a, b, r1, r2, verts=8):
        """A tapered tube from point a (radius r1) to point b (radius r2): rocket nozzles, crystal tips."""
        a, b = Vector(a), Vector(b)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r1, radius2=r2, depth=(b - a).length)
        ob = self._finish(group, bm, (a + b) / 2, (0, 0, 0))
        ob.rotation_mode = 'QUATERNION'
        ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
        return ob

    def sphere(self, group, center, radius, segments=16):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=segments // 2, radius=radius)
        return self._finish(group, bm, center, (0, 0, 0))

    def mirror(self, fn):
        """Run fn(side) for side = -1 and +1 (left/right symmetric details)."""
        for side in (-1, 1):
            fn(side)

    def finish(self):
        """Join each group into one object, apply transforms, check budgets, write files. Returns a report."""
        out = ROOT / 'drafts/cars' / self.id / 'redesign'
        out.mkdir(parents=True, exist_ok=True)
        joined = []
        for group, obs in self.pieces.items():
            if not obs:
                continue
            for ob in obs:
                ob.select_set(False)
            bpy.context.view_layer.update()
            ctx = {'active_object': obs[0], 'selected_editable_objects': obs, 'selected_objects': obs}
            with bpy.context.temp_override(**ctx):
                bpy.ops.object.join()
            ob = obs[0]
            # Object names are global in the .blend and become the Roblox part names, so free the exact name first.
            taken = bpy.data.objects.get(group)
            if taken and taken != ob:
                taken.name = group + '.prev'
            ob.name = ob.data.name = group
            with bpy.context.temp_override(active_object=ob, selected_editable_objects=[ob], selected_objects=[ob]):
                bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            # Wheels pivot on their axle so the part centre is the wheel centre.
            if group.startswith('Wheel_'):
                centre = sum((v.co for v in ob.data.vertices), Vector()) / len(ob.data.vertices)
                ob.data.transform(__import__('mathutils').Matrix.Translation(-centre))
                ob.location = centre
            # Smooth curved surfaces (tyres, tubes), keep the bevelled creases sharp.
            with bpy.context.temp_override(active_object=ob, selected_editable_objects=[ob], selected_objects=[ob]):
                bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
            color = self.colors.get(group) or self.colors['Tyre']
            mat = bpy.data.materials.new(self.id + '_' + group)
            mat.use_nodes = True
            bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
            bsdf.inputs['Base Color'].default_value = (*color, 1)
            bsdf.inputs['Roughness'].default_value = 0.45
            if group.startswith('Metal'):
                bsdf.inputs['Metallic'].default_value = 0.8
            if group.startswith('Light'):
                bsdf.inputs['Emission Color'].default_value = (*color, 1)
                bsdf.inputs['Emission Strength'].default_value = 2
            mat.diffuse_color = (*color, 1)
            ob.data.materials.clear()
            ob.data.materials.append(mat)
            joined.append((group, ob))
        bpy.context.view_layer.update()
        # Budgets (docs/CAR_REDESIGN_SPEC.md section 2).
        lo, hi, tris = Vector((1e9,) * 3), Vector((-1e9,) * 3), 0
        for _, ob in joined:
            for v in ob.data.vertices:
                w = ob.matrix_world @ v.co
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
            tris += sum(len(p.vertices) - 2 for p in ob.data.polygons)
        assert lo.x >= -MAX_X and hi.x <= MAX_X and lo.y >= -MAX_Y and hi.y <= MAX_Y and lo.z >= -1e-3, (self.id, lo, hi)
        assert tris <= MAX_TRIS, (self.id, tris)
        wheels = sorted(g for g in self.pieces if g.startswith('Wheel_'))
        kind = lambda g: 'Tyre' if g.startswith('Wheel_') else re.sub(r'\d+$', '', g)
        report = {'id': self.id, 'parts': [g for g, _ in joined], 'tris': tris, 'wheels': wheels,
                  'min': [round(c, 3) for c in lo], 'max': [round(c, 3) for c in hi],
                  'materials': {g: {'material': GROUP_MATERIAL[kind(g)],
                                    'color': list(self.colors.get(g) or self.colors['Tyre'])}
                                for g, _ in joined}}
        joined = [ob for _, ob in joined]
        self._preview(out)
        # Roblox's importer ignores the FBX axis settings and maps Blender (x, y, z) to Roblox (-x, z, y), so turn the
        # car 180 degrees about Z for the export only: the nose (+Y) then lands on Roblox -Z (Go-Kart pilot).
        turn = __import__('mathutils').Matrix.Rotation(math.pi, 4, 'Z')
        for ob in joined:
            ob.matrix_world = turn @ ob.matrix_world
        with bpy.context.temp_override(selected_objects=joined, selected_editable_objects=joined, active_object=joined[0]):
            bpy.ops.export_scene.fbx(filepath=str(out / (self.id + '.fbx')), use_selection=True,
                                     object_types={'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE',
                                     # Checked on the Go-Kart pilot: without it Roblox imports at x100 (cm units).
                                     global_scale=0.01, axis_forward='-Z', axis_up='Y', mesh_smooth_type='OFF', add_leaf_bones=False)
        for ob in joined:
            ob.matrix_world = turn.inverted() @ ob.matrix_world
        bpy.data.libraries.write(str(out / (self.id + '.blend')), {self.scene}, fake_user=True, compress=True)
        (out / 'parts.json').write_text(json.dumps(report, indent=2) + '\n')
        return report

    def _preview(self, out):
        scene = self.scene
        cam = bpy.data.objects.new('Preview', bpy.data.cameras.new('Preview'))
        scene.collection.objects.link(cam)
        # Same angle as the reference renders: high 3/4 view from the front-right.
        # Expansion refs were rendered from the original recipe preview camera (rear 3/4, tools/build_expansion_cars.py).
        cam.location, target, scale = ((7.5, 7.5, 6.2), (0, 0, 0.7), 8.2) if self.view == 'front' else ((7, -9, 6), (0, 0, 1.2), 7.9)
        cam.rotation_euler = (Vector(target) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        cam.data.type = 'ORTHO'
        cam.data.ortho_scale = scale
        scene.camera = cam
        try:
            scene.render.engine = 'BLENDER_WORKBENCH'
        except TypeError:
            pass
        scene.render.resolution_x, scene.render.resolution_y = 724, 543
        scene.render.film_transparent = False
        scene.world = bpy.data.worlds.new('PreviewWorld')
        scene.display.shading.light = 'STUDIO'
        scene.display.shading.color_type = 'MATERIAL'
        scene.display.shading.background_type = 'VIEWPORT'
        scene.display.shading.background_color = (0.04, 0.04, 0.05)
        scene.display.shading.show_shadows = True
        scene.display.shading.show_cavity = True
        scene.render.filepath = str(out / 'preview.png')
        bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- cars

def go_kart(colors=None, car_id='go_kart', hub='Metal'):
    c = Car(car_id, colors or {
        'Body': (0.93, 0.33, 0.42), 'Trim': (0.16, 0.17, 0.19), 'Accent': (0.93, 0.91, 0.87),
        'Metal': (0.70, 0.72, 0.75), 'Tyre': (0.11, 0.11, 0.12),
    }, seg=2)
    c.colors.setdefault('Light', neon(c.colors['Body']))
    # Floor tray and tube frame.
    c.box('Metal', (0, 0, 0.3), (2.3, 5.2, 0.12), bevel=0.03)
    c.tube('Metal', (-1.35, 2.95, 0.36), (1.35, 2.95, 0.36), 0.1)
    c.tube('Metal', (-1.7, -1.95, 0.62), (1.7, -1.95, 0.62), 0.09)
    c.tube('Metal', (-1.7, 2.05, 0.52), (1.7, 2.05, 0.52), 0.08)
    # Side pods with a white stripe along the outer face.
    def pod(s):
        c.box('Body', (s * 1.0, -0.25, 0.62), (0.8, 2.7, 0.56), bevel=0.08, taper=(0.82, 0.94))
        c.box('Accent', (s * 1.41, -0.15, 0.6), (0.04, 1.5, 0.08), bevel=0.01)
    c.mirror(pod)
    # Nose pod: sloped top, white centre stripe, front number board.
    c.box('Body', (0, 2.2, 0.58), (2.3, 1.45, 0.5), bevel=0.08, taper=(0.86, 0.8, -0.1))
    c.box('Accent', (0, 2.12, 0.84), (0.45, 1.0, 0.04), bevel=0.01, rot=(-0.12, 0, 0))
    c.box('Accent', (0.5, 0.95, 0.75), (0.5, 0.08, 0.45), bevel=0.02)
    # Seat with bolsters, steering column and octagonal wheel.
    c.box('Trim', (0, -0.55, 0.5), (1.05, 1.0, 0.3), bevel=0.06)
    c.box('Trim', (0, -1.05, 1.08), (1.05, 0.3, 1.15), bevel=0.06, rot=(-0.2, 0, 0))
    c.mirror(lambda s: c.box('Metal', (s * 0.58, -0.75, 0.95), (0.1, 0.55, 0.5), bevel=0.02, rot=(-0.2, 0, 0)))
    c.tube('Metal', (0, 1.35, 0.6), (0, 0.45, 1.05), 0.05)
    c.cyl('Trim', (0, 0.42, 1.08), 0.3, 0.09, verts=8, bevel=0.02, rot=(math.radians(-60), 0, 0))
    # Engine block behind the seat (left) and the exhaust stub.
    c.box('Accent', (-0.9, -1.55, 1.05), (0.6, 0.6, 0.5), bevel=0.05)
    c.tube('Metal', (-0.6, -1.85, 1.0), (-0.3, -2.35, 1.0), 0.06)
    # Wheels: wider, taller rears.
    c.mirror(lambda s: c.wheel('Wheel_F' + ('R' if s > 0 else 'L'), (s * 1.5, 2.05, 0.52), 0.52, 0.55, hub))
    c.mirror(lambda s: c.wheel('Wheel_R' + ('R' if s > 0 else 'L'), (s * 1.38, -1.95, 0.62), 0.62, 0.84, hub))
    # Sport kit (owner 2026-10-20): splitter with a neon lip, diffuser fins, low rear wing on chrome posts.
    c.box('Trim', (0, 2.78, 0.27), (2.2, 0.45, 0.05), bevel=0.01)
    c.box('Light', (0, 3.0, 0.27), (2.1, 0.03, 0.03), bevel=0)
    for i in range(5):
        c.box('Trim', (-0.6 + i * 0.3, -2.42, 0.36), (0.05, 0.4, 0.18), bevel=0)
    c.box('Body', (0, -2.42, 1.3), (2.3, 0.4, 0.06), bevel=0.02, taper=(1.0, 0.7))
    c.box('Light', (0, -2.6, 1.33), (2.2, 0.03, 0.03), bevel=0)
    c.mirror(lambda s: c.tube('Metal', (s * 0.75, -2.3, 0.62), (s * 0.75, -2.42, 1.27), 0.04))
    return c


def midnight_kart():
    return go_kart({
        'Body': (0.90, 0.36, 0.42), 'Trim': (0.20, 0.21, 0.24), 'Accent': (0.93, 0.91, 0.87),
        'Metal': (0.62, 0.64, 0.68), 'Tyre': (0.13, 0.13, 0.14),
    }, 'midnight_kart', hub='Accent')


GLASS = (0.20, 0.26, 0.33)
TRIM = (0.20, 0.21, 0.23)
CHROME = (0.78, 0.79, 0.81)
TYRE = (0.12, 0.12, 0.13)
WARM = (1.0, 0.92, 0.66)


def sedan(car_id, paint, accent=(0.93, 0.91, 0.87), light=WARM, hood=None, roof=False, flares=False, wing=False,
          rockets=False, clamps=False, hover=False, tyre=(0.7, 0.62), metal=CHROME, lamp='Light'):
    """The stubby boxy sedan shared by the original roster (Rusty Hatchback ... Void Racer references):
    short body, tall cabin, big wheels."""
    c = Car(car_id, {'Body': paint, 'Trim': TRIM, 'Accent': accent, 'Metal': metal, 'Glass': GLASS,
                     'Light': light, 'Tyre': TYRE})
    L, AX = 2.7, 1.75  # half length, axle distance from the centre
    lift = 0.25 if hover else 0.0
    z0, z1, z2 = 0.49 + lift, 1.39 + lift, 2.32 + lift  # sill, belt line, roof (lowered for the sport look)
    cy, cl = -0.35, 2.6  # cabin centre and length
    c.box('Body', (0, 0, (z0 + z1) / 2), (3.0, 2 * L, z1 - z0), bevel=0.1)
    c.box('Body', (0, cy, (z1 + z2) / 2), (2.6, cl, z2 - z1), bevel=0.08, taper=(0.86, 0.7))
    if roof:  # roof plate a touch bigger than the roof
        c.box('Accent', (0, cy, z2 + 0.06), (2.4, 1.95, 0.12), bevel=0.04)
    # Glass: windshield, rear window, two side panes per side (slopes follow the cabin taper).
    run = cl * 0.15
    lean = math.atan2(run, z2 - z1)
    mid = (z1 + z2) / 2 + 0.02
    c.box('Glass', (0, cy + cl / 2 - run / 2 + 0.03, mid), (2.0, 0.04, 0.74), bevel=0.01, rot=(lean, 0, 0))
    c.box('Glass', (0, cy - cl / 2 + run / 2 - 0.03, mid), (2.0, 0.04, 0.68), bevel=0.01, rot=(-lean, 0, 0))
    side = math.atan2(0.18, z2 - z1)
    def panes(s):
        for y, length in ((cy - 0.6, 0.85), (cy + 0.5, 0.95)):
            c.box('Glass', (s * 1.215, y, mid + 0.01), (0.04, length, 0.62), bevel=0.01, rot=(0, -s * side, 0))
        c.box('Body', (s * 1.47, cy + cl / 2 - 0.15, z1 + 0.22), (0.2, 0.26, 0.18), bevel=0.04)  # mirror
        c.box('Trim', (s * 1.36, cy + cl / 2 - 0.15, z1 + 0.1), (0.1, 0.06, 0.18), bevel=0)
        c.box('Metal', (s * 1.52, cy + 0.1, z1 - 0.18), (0.04, 0.3, 0.07), bevel=0.01)  # door handle
    c.mirror(panes)
    # Front: round headlights with chrome rims, grille, bumper. Rear: bumper and tail lights.
    def lamps(s):
        c.cyl('Metal', (s * 1.0, L, z0 + 0.5), 0.3, 0.12, axis='Y', verts=10, bevel=0.02)
        c.cyl(lamp, (s * 1.0, L + 0.07, z0 + 0.5), 0.23, 0.06, axis='Y', verts=10, bevel=0)
        c.box('Trim', (s * 1.0, -L, z0 + 0.5), (0.6, 0.06, 0.22), bevel=0.01)
    c.mirror(lamps)
    c.box('Trim', (0, L + 0.01, z0 + 0.45), (1.05, 0.06, 0.3), bevel=0.02)
    for i in range(3):
        c.box('Metal' if hood != 'vents' else 'Trim', (0, L + 0.05, z0 + 0.37 + i * 0.08), (0.9, 0.02, 0.03), bevel=0)
    c.box('Trim', (0, L - 0.05, z0 + 0.02), (3.2, 0.36, 0.26), bevel=0.05)
    c.box('Trim', (0, -L + 0.05, z0 + 0.02), (3.1, 0.3, 0.24), bevel=0.05)
    # Sport kit (owner 2026-10-20): splitter with a neon lip, diffuser fins, lip spoiler unless it has a wing.
    lip = 'Light'
    c.box('Trim', (0, L + 0.08, z0 - 0.15), (3.0, 0.45, 0.06), bevel=0.01)
    c.box(lip, (0, L + 0.3, z0 - 0.15), (2.9, 0.03, 0.035), bevel=0)
    for i in range(5):
        c.box('Trim', (-0.8 + i * 0.4, -L - 0.02, z0 - 0.13), (0.05, 0.45, 0.18), bevel=0)
    if not wing:
        c.box('Body', (0, -L + 0.22, z1 + 0.06), (2.8, 0.4, 0.12), bevel=0.02, taper=(1.0, 0.5, -0.1))
    hy = (L + cy + cl / 2) / 2  # middle of the hood
    if hood == 'emblem':
        c.box('Accent', (0, hy + 0.2, z1 + 0.02), (0.36, 0.22, 0.05), bevel=0.02, taper=(0.7, 0.6))
    elif hood == 'stripes':
        c.mirror(lambda s: c.box('Accent', (s * 0.4, hy, z1 + 0.005), (0.16, 1.0, 0.02), bevel=0))
    elif hood == 'vents':
        def vent(s):
            c.box('Accent', (s * 0.42, hy, z1 + 0.01), (0.26, 0.9, 0.04), bevel=0.01)
            c.box('Trim', (s * 0.42, hy, z1 + 0.025), (0.14, 0.75, 0.03), bevel=0)
        c.mirror(vent)
    elif hood == 'pad':
        c.box('Light', (0, hy, z1 + 0.02), (0.6, 0.6, 0.05), bevel=0.02)
    r, w = tyre
    if flares:  # dark arches wrapping the top of each wheel
        for y in (AX, -AX):
            def flare(s, y=y):
                c.box('Trim', (s * 1.56, y, r + r * 0.92), (0.36, 1.05, 0.16), bevel=0.04)
                for e in (-1, 1):
                    c.box('Trim', (s * 1.56, y + e * 0.66, r + 0.62), (0.36, 0.42, 0.16), bevel=0.04, rot=(-e * 0.7, 0, 0))
            c.mirror(flare)
    if wing:
        c.box('Body', (0, -L + 0.3, z2 + 0.12), (3.4, 0.62, 0.1), bevel=0.04, taper=(1.0, 0.8))
        c.mirror(lambda s: c.box('Trim', (s * 0.95, -L + 0.3, (z1 + z2 + 0.12) / 2), (0.1, 0.16, z2 - z1 + 0.12), bevel=0.02))
    if rockets:
        def rocket(s):
            x = s * 0.6
            c.cyl('Metal', (x, cy - 0.05, z2 + 0.4), 0.4, 1.5, axis='Y', verts=8, bevel=0.1)
            c.box('Body', (x, cy - 0.75, z2 + 0.95), (0.14, 0.7, 1.0), bevel=0.03, taper=(1.0, 0.25, -0.25))
            if clamps:
                for y in (cy + 0.45, cy - 0.5):
                    c.box('Trim', (x, y, z2 + 0.4), (0.86, 0.1, 0.86), bevel=0)
        c.mirror(rocket)
    if hover:
        # Hover pods at the corners with glowing undersides, a door light strip, side vents and rear fins.
        for y in (AX + 0.1, -AX - 0.1):
            def pod(s, y=y):
                c.cyl('Trim', (s * 1.22, y, 0.55), 0.7, 0.55, axis='Z', verts=8, bevel=0.06)
                c.cyl('Light', (s * 1.22, y, 0.26), 0.62, 0.08, axis='Z', verts=8, bevel=0)
                c.box('Light', (s * 1.88, y, 0.6), (0.04, 0.4, 0.06), bevel=0)
            c.mirror(pod)
        def side(s):
            c.box('Light', (s * 1.51, -0.2, z0 + 0.42), (0.04, 1.9, 0.08), bevel=0)
            for y in (L - 0.45, -L + 0.4):
                c.box('Trim', (s * 1.505, y, z0 + 0.6), (0.03, 0.42, 0.26), bevel=0.01)
            c.box('Light', (s * 0.85, cy - cl / 2 + 0.15, z2 + 0.3), (0.12, 0.55, 0.85), bevel=0.04,
                  taper=(1.0, 0.35, -0.2), rot=(-0.35, 0, 0))
        c.mirror(side)
        c.mirror(lambda s: c.box('Light', (s * 1.1, L + 0.14, z0 + 0.02), (0.45, 0.02, 0.06), bevel=0))
    else:
        w *= 1.2  # wider tyres, outer face unchanged
        x = 1.83 - w / 2 - 0.12
        c.mirror(lambda s: c.wheel('Wheel_F' + ('R' if s > 0 else 'L'), (s * x, AX, r), r, w))
        c.mirror(lambda s: c.wheel('Wheel_R' + ('R' if s > 0 else 'L'), (s * x, -AX, r), r, w))
    return c


def rusty_hatchback():
    return sedan('rusty_hatchback', (0.97, 0.73, 0.38), accent=(0.78, 0.52, 0.38), hood='emblem', flares=True)


def wooden_car():
    return sedan('wooden_car', (0.96, 0.87, 0.64), accent=(0.80, 0.63, 0.45), roof=True)


def street_racer():
    return sedan('street_racer', (0.74, 0.58, 0.92), hood='stripes', wing=True)


def rain_runner():
    return sedan('rain_runner', (0.77, 0.60, 0.93), hood='vents', wing=True, tyre=(0.72, 0.7))


def rocket_car():
    return sedan('rocket_car', (0.94, 0.42, 0.46), rockets=True)


def golden_racer():
    return sedan('golden_racer', (0.95, 0.45, 0.46), rockets=True, clamps=True, flares=True)


def hover_car():
    return sedan('hover_car', (0.97, 0.68, 0.84), light=(0.45, 0.95, 1.0), hover=True)


def void_racer():
    return sedan('void_racer', (0.22, 0.22, 0.25), accent=(1.0, 0.93, 0.74), light=(0.66, 0.42, 1.0), hood='pad',
                 hover=True, metal=(0.72, 0.73, 0.76), lamp='Accent')


def singularity():
    """Black wedge hypercar with gold trim and a black hole (gold ring, black core) on the engine deck."""
    gold, black = (1.0, 0.74, 0.12), (0.07, 0.07, 0.08)  # gold is bright neon (owner 2026-10-20)
    c = Car('singularity', {'Body': black, 'Trim': (0.14, 0.14, 0.16), 'Accent': CHROME, 'Light': gold,
                            'Light2': (0.8, 0.92, 1.0), 'Metal': (0.02, 0.02, 0.03), 'Glass': (0.13, 0.15, 0.2),
                            'Tyre': TYRE})
    c.box('Body', (0, -0.1, 0.62), (3.3, 6.0, 0.5), bevel=0.06)
    c.box('Body', (0, 2.55, 0.62), (3.1, 0.9, 0.42), bevel=0.05, taper=(0.95, 0.5, -0.2))  # knife nose
    c.box('Glass', (0, 0.35, 1.18), (1.9, 2.3, 0.62), bevel=0.05, taper=(0.68, 0.5, -0.15))  # canopy
    c.box('Body', (0, -1.75, 1.0), (2.2, 1.4, 0.26), bevel=0.04)  # engine deck
    c.box('Light', (0.35, 0.9, 1.28), (0.16, 1.0, 0.03), bevel=0, rot=(-0.55, 0, 0))  # gold roof stripe
    def flank(s):
        c.box('Body', (s * 1.5, -1.25, 1.05), (0.5, 1.9, 0.5), bevel=0.05, taper=(0.6, 0.85))  # rear haunch
        c.box('Trim', (s * 1.76, -0.6, 1.0), (0.04, 0.35, 0.22), bevel=0)  # intake
        c.box('Body', (s * 1.45, 2.15, 1.0), (0.55, 1.0, 0.24), bevel=0.04, taper=(0.8, 0.8))  # front fender
        c.box('Light', (s * 1.66, 0.4, 0.55), (0.03, 3.4, 0.07), bevel=0)  # gold sill line
    c.mirror(flank)
    # Black hole (never removed, owner 2026-10-20): a black core inside a tilted neon-gold accretion ring and a pale
    # neon halo, standing on a chrome spindle above the engine deck. Metal here is the near-black core.
    hole = (0, -1.7, 1.72)
    c.tube('Accent', (0, -1.7, 1.12), (0, -1.7, 1.4), 0.06)
    c.sphere('Metal', hole, 0.34, segments=12)
    tilt = (math.radians(24), math.radians(8), 0)
    c.torus('Light', hole, 0.6, 0.075, tilt)
    c.torus('Light', hole, 0.84, 0.03, tilt, segments=20, ring=4)
    c.torus('Light2', hole, 0.44, 0.022, (math.radians(90), 0, math.radians(25)), segments=20, ring=4)
    # Rear wing with endplates and a gold lip, chrome posts; diffuser blocks and exhaust.
    c.box('Body', (0, -2.85, 1.75), (3.5, 0.6, 0.08), bevel=0.02)
    c.box('Light', (0, -2.6, 1.8), (3.3, 0.06, 0.03), bevel=0)
    c.mirror(lambda s: c.box('Body', (s * 1.78, -2.85, 1.55), (0.06, 0.8, 0.6), bevel=0.02, taper=(1.0, 0.6, -0.1)))
    c.mirror(lambda s: c.tube('Accent', (s * 0.6, -2.7, 0.95), (s * 0.6, -2.8, 1.72), 0.05))
    for i in range(7):
        c.box('Trim', (-1.2 + i * 0.4, -3.05, 0.32), (0.3, 0.3, 0.22), bevel=0.02)
    c.box('Light', (0, -3.0, 0.68), (3.0, 0.04, 0.05), bevel=0)  # gold tail line
    c.cyl('Accent', (0, -3.15, 0.45), 0.1, 0.2, axis='Y', verts=10, bevel=0.02)
    for y in (2.0, -2.0):
        c.mirror(lambda s, y=y: c.wheel('Wheel_' + ('F' if y > 0 else 'R') + ('R' if s > 0 else 'L'),
                                        (s * 1.5, y, 0.56), 0.56, 0.5, 'Light', cap_group='Accent', hub_scale=0.72, hub_sides=12))
    return c


def zero_g_zipper():
    """Its reference is a pink open-wheel roadster (not its recipe): angular nose with hex headlights and a white
    centre stripe, two seats, twin rocket thrusters with neon crystal tips, big exposed wheels on suspension arms."""
    c = Car('zero_g_zipper', {'Body': (0.95, 0.46, 0.52), 'Accent': (0.98, 0.9, 0.92), 'Trim': (0.2, 0.2, 0.23),
                              'Metal': (0.64, 0.66, 0.7), 'Glass': (0.55, 0.46, 0.78), 'Light': WARM,
                              'Light2': (1.0, 0.42, 0.86), 'Tyre': TYRE})
    # Low central tub, nose with headlight cheeks and a grille slot, side pods with white vent slats.
    c.box('Body', (0, -0.2, 0.62), (1.9, 4.6, 0.5), bevel=0.06, taper=(0.9, 0.96))
    c.box('Body', (0, 2.2, 0.58), (2.0, 1.6, 0.42), bevel=0.06, taper=(0.85, 0.85, -0.1))
    c.box('Accent', (0, 1.4, 0.82), (0.62, 3.1, 0.03), bevel=0.01, rot=(math.radians(-3), 0, 0))
    def nose(s):
        c.box('Body', (s * 0.78, 2.82, 0.6), (0.62, 0.55, 0.42), bevel=0.06, taper=(0.85, 0.8))
        c.cyl('Trim', (s * 0.78, 3.08, 0.6), 0.22, 0.06, axis='Y', verts=6, bevel=0)
        c.cyl('Light', (s * 0.78, 3.11, 0.6), 0.16, 0.04, axis='Y', verts=6, bevel=0)
        c.box('Trim', (s * 0.62, 1.0, 0.89), (0.22, 0.2, 0.05), bevel=0.01)  # hood vent
        c.box('Body', (s * 0.98, -0.75, 0.82), (0.5, 2.3, 0.5), bevel=0.06, taper=(0.75, 0.9))  # side pod
        for i in range(3):
            c.box('Accent', (s * 1.22, -0.2 - i * 0.2, 0.8), (0.04, 0.1, 0.24), bevel=0.01)
        c.tube('Metal', (s * 0.85, 1.9, 0.6), (s * 1.18, 1.9, 0.6), 0.05)  # suspension arms
        c.tube('Metal', (s * 0.85, -1.9, 0.65), (s * 1.12, -1.9, 0.65), 0.05)
    c.mirror(nose)
    c.box('Trim', (0, 3.08, 0.42), (0.7, 0.06, 0.12), bevel=0.01)
    # Cockpit: tinted windscreen, two bucket seats.
    c.box('Glass', (0, 0.7, 1.0), (1.25, 0.05, 0.36), bevel=0.01, rot=(math.radians(-55), 0, 0))
    c.mirror(lambda s: c.box('Trim', (s * 0.42, -0.6, 1.25), (0.55, 0.22, 0.85), bevel=0.06, rot=(math.radians(-12), 0, 0)))
    c.box('Trim', (0, -0.2, 0.9), (1.3, 0.8, 0.12), bevel=0.03)
    # Twin rocket thrusters rising behind the seats: pink housing, grey sleeve, neon crystal tip.
    d = Vector((0, -math.cos(math.radians(35)), math.sin(math.radians(35))))
    for s in (-1, 1):
        b = Vector((s * 0.55, -1.05, 1.0))
        c.cone('Body', b, b + d * 1.0, 0.26, 0.24)
        c.cone('Metal', b + d * 1.0, b + d * 1.45, 0.27, 0.25)
        c.cone('Light2', b + d * 1.45, b + d * 2.0, 0.2, 0.03, verts=6)
    # Sport kit: splitter with a neon lip, diffuser fins.
    c.box('Trim', (0, 3.0, 0.3), (2.0, 0.4, 0.05), bevel=0.01)
    c.box('Light2', (0, 3.2, 0.3), (1.9, 0.03, 0.03), bevel=0)
    for i in range(5):
        c.box('Trim', (-0.6 + i * 0.3, -2.52, 0.4), (0.05, 0.36, 0.18), bevel=0)
    for y, r, w in ((1.9, 0.6, 0.62), (-1.9, 0.66, 0.74)):
        c.mirror(lambda s, y=y, r=r, w=w: c.wheel('Wheel_' + ('F' if y > 0 else 'R') + ('R' if s > 0 else 'L'),
                                                  (s * (1.82 - w / 2 - 0.1), y, r), r, w, cap_group='Body',
                                                  hub_scale=0.72, hub_sides=16))
    return c


def neon(color):
    """Neon at full brightness (owner 2026-10-20): keep the hue and saturation, push the value to 1."""
    h, sat, _ = colorsys.rgb_to_hsv(*color)
    return tuple(round(c, 4) for c in colorsys.hsv_to_rgb(h, sat, 1.0))


RECIPE_GLASS, RECIPE_RUBBER = (0.18, 0.3, 0.39), (0.09, 0.1, 0.15)


def recipe_car(car_id):
    """An expansion car rebuilt from its recipe.json blockout (the source of its reference render): every part kept,
    edges bevelled, tyres rounder, parts grouped by colour into Body / Trim / Accent / Glass / Metal / Light."""
    parts = json.loads((ROOT / 'drafts/cars' / car_id / 'recipe.json').read_text())
    key = lambda p: tuple(round(c, 3) for c in p['color'])
    paint = key(next(p for p in parts if p['name'] == 'Body'))

    def role(p):
        if re.fullmatch(r'Wheel_(FL|FR|RL|RR)', p['name']):
            return p['name']
        if p['material'] == 'Neon':
            return 'Light'
        if p['material'] == 'Metal':
            return 'Metal'
        k = key(p)
        if k == RECIPE_GLASS:
            return 'Glass'
        if k == paint:
            return 'Body'
        if k == RECIPE_RUBBER or sum(k) / 3 < 0.12:
            return 'Trim'
        return 'Accent'

    counts = {}
    for p in parts:
        r = role(p)
        if not r.startswith('Wheel_'):
            counts.setdefault(r, {}).setdefault(key(p), 0)
            counts[r][key(p)] += 1
    names, colors = {}, {}
    for r, by_color in counts.items():
        for i, (k, _) in enumerate(sorted(by_color.items(), key=lambda kv: -kv[1])):
            name = r if i == 0 else r + str(i + 1)
            names[(r, k)] = name
            colors[name] = neon(k) if r == 'Light' else k
    tyre = next((key(p) for p in parts if p['name'] == 'Wheel_FL'), RECIPE_RUBBER)
    colors['Tyre'] = tyre
    colors.setdefault('Trim', RECIPE_RUBBER)
    colors.setdefault('Light', neon(paint))
    colors.setdefault('Metal', (0.72, 0.79, 0.85))
    c = Car(car_id, colors)
    c.view = 'rear'
    # Sport look (owner 2026-10-20): body lowered over the wheels; fantasy/novelty cars are also squashed to 72% height
    # (less bulky) and dropped further. Wheels, hubs and spokes keep their place; tyres grow 20% inward.
    family = re.search(r'Family\s*=\s*"([^"]+)"', (ROOT / 'src/shared/Cars' / (car_id + '.luau')).read_text())
    novelty = family is not None and family[1] == 'fantasy_novelty'
    wheelish = lambda p: re.match(r'(Wheel_|Spoke|.*Hub)', p['name']) is not None
    body = [p for p in parts if not wheelish(p)]
    base = min(p['pos'][1] - p['size'][1] / 2 for p in parts if p['name'] in ('Sill', 'Body'))
    squash, drop = (0.72, 0.16) if novelty else (1.0, 0.06)
    for p in body:
        p['pos'] = [p['pos'][0], base + (p['pos'][1] - base) * squash - drop, p['pos'][2]]
        p['size'] = [p['size'][0], p['size'][1] * squash, p['size'][2]]
    for p in parts:
        if re.fullmatch(r'Wheel_(FL|FR|RL|RR)', p['name']):
            grow = p['size'][0] * 0.2
            p['size'] = [p['size'][0] + grow, p['size'][1], p['size'][2]]
            p['pos'] = [p['pos'][0] - math.copysign(grow / 2, p['pos'][0]), p['pos'][1], p['pos'][2]]
    for p in parts:
        r = role(p)
        group = r if r.startswith('Wheel_') else names[(r, key(p))]
        c.prim(group, p['shape'], p['pos'], p['size'], p['rotation'])
    # Kit pieces in Roblox space (front is -Z): splitter + neon lip, diffuser fins, lip spoiler or (novelty) a wing.
    width = next(p for p in parts if p['name'] == 'Body')['size'][0]
    front = min(p['pos'][2] - p['size'][2] / 2 for p in body)
    rear = max(p['pos'][2] + p['size'][2] / 2 for p in body)
    floor = base - drop
    c.prim('Trim', 'Block', (0, floor - 0.02, front + 0.12), (width * 0.92, 0.06, 0.42), (0, 0, 0))
    c.prim('Light', 'Block', (0, floor - 0.02, front - 0.08), (width * 0.88, 0.035, 0.035), (0, 0, 0), bevel=0)
    for i in range(5):
        c.prim('Trim', 'Block', (-0.6 + i * 0.3, floor + 0.04, rear - 0.12), (0.05, 0.18, 0.42), (0, 0, 0), bevel=0)
    tail = next((p for p in parts if p['name'] == 'Tail'), None)
    has_wing = any(re.search(r'Ducktail|Wing|Spoiler', p['name']) for p in parts)
    if tail and novelty:
        top = tail['pos'][1] + tail['size'][1] / 2
        z = min(rear - 0.3, 3.0)
        c.prim('Body', 'Block', (0, top + 0.5, z), (width * 0.96, 0.07, 0.55), (-8, 0, 0))
        c.prim('Light', 'Block', (0, top + 0.53, z + 0.27), (width * 0.94, 0.03, 0.03), (0, 0, 0), bevel=0)
        for sgn in (-1, 1):
            c.prim('Body', 'Block', (sgn * width * 0.48, top + 0.4, z), (0.06, 0.4, 0.62), (0, 0, 0))
            c.prim('Metal', 'Block', (sgn * width * 0.25, top + 0.24, z), (0.07, 0.48, 0.1), (0, 0, 0))
    elif tail and not has_wing:
        top = tail['pos'][1] + tail['size'][1] / 2
        c.prim('Body', 'Wedge', (0, top + 0.06, tail['pos'][2] + tail['size'][2] / 2 - 0.2), (width * 0.85, 0.12, 0.4),
               (0, 0, 0))
    return c


BUILDERS = {fn.__name__: fn for fn in (go_kart, midnight_kart, rusty_hatchback, wooden_car, street_racer, rain_runner,
                                       rocket_car, golden_racer, hover_car, void_racer, singularity, zero_g_zipper)}


def build(car_id):
    previous = bpy.context.window.scene
    try:
        car = BUILDERS[car_id]() if car_id in BUILDERS else recipe_car(car_id)
        report = car.finish()
    finally:
        bpy.context.window.scene = previous
    print(json.dumps(report))
    return report
