"""Spawn paddock props (docs/SPAWN_AND_ROLLS_SPEC.md section 1b): TimingTower and TyreStack.

    blender -b -P blender/paddock/build_paddock.py

1 Blender unit = 1 stud, Z up, base of each prop at z = 0, centred on x = y = 0. Each prop is ONE mesh coloured by a
shared 64 x 64 palette atlas (PaddockPalette.png, 4 x 4 solid cells): every face's UVs sit on one cell centre, so a
single MeshPart carries every colour. Writes SpawnPaddock.blend, <Prop>.fbx, PaddockPalette.png, preview PNGs and
props.json (tris, size) next to this file.
"""
import bpy, bmesh, json, math, os
from mathutils import Matrix, Vector

OUT = os.path.dirname(os.path.abspath(__file__))
# Section 1b.2 palette (placeholders); cell index = position in this list (row-major, 4 per row, row 0 at the top).
PALETTE = {
	'White': (245, 245, 240), 'Charcoal': (52, 56, 72), 'Teal': (40, 200, 190), 'Red': (235, 70, 60),
	'Amber': (255, 190, 65), 'Rubber': (40, 42, 50), 'Cream': (245, 232, 200),
}
KEYS = list(PALETTE)
CELL = 16
SIZE = 4 * CELL

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# Palette atlas.
px = [0.0] * (SIZE * SIZE * 4)
for i, key in enumerate(KEYS):
	r, g, b = (c / 255 for c in PALETTE[key])
	cx, cy = i % 4, i // 4
	for y in range(cy * CELL, (cy + 1) * CELL):
		row = SIZE - 1 - y  # Blender image rows start at the bottom
		for x in range(cx * CELL, (cx + 1) * CELL):
			o = (row * SIZE + x) * 4
			px[o:o + 4] = [r, g, b, 1.0]
img = bpy.data.images.new('PaddockPalette', SIZE, SIZE)
img.pixels.foreach_set(px)
img.filepath_raw = os.path.join(OUT, 'PaddockPalette.png')
img.file_format = 'PNG'
img.save()
img.pack()
mat = bpy.data.materials.new('PaddockPalette')
mat.use_nodes = True
bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = img
tex.interpolation = 'Closest'
mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
bsdf.inputs['Roughness'].default_value = 0.5


def uv_of(key):
	i = KEYS.index(key)
	return ((i % 4 + 0.5) / 4, 1 - (i // 4 + 0.5) / 4)


pieces = []


def paint(ob, key_for_face):
	"""Give every face of ob the UV of its palette cell; key_for_face(poly) -> palette key."""
	me = ob.data
	if not me.uv_layers:
		me.uv_layers.new(name='UVMap')
	uv = me.uv_layers.active.data
	for poly in me.polygons:
		u = uv_of(key_for_face(poly))
		for li in poly.loop_indices:
			uv[li].uv = u
	return ob


def add(ob, key):
	paint(ob, lambda _p: key if isinstance(key, str) else key(_p))
	pieces.append(ob)
	return ob


def box(c, s, key, bevel=0.0, seg=3):
	bpy.ops.mesh.primitive_cube_add(size=1, location=c)
	ob = bpy.context.object
	ob.scale = s
	bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)  # mesh in world space, so face turns work
	if bevel:
		m = ob.modifiers.new('Round', 'BEVEL')
		m.width = bevel
		m.segments = seg
		m.limit_method = 'NONE'
		bpy.ops.object.modifier_apply(modifier=m.name)
	return add(ob, key)


def finish(name):
	"""Join the pieces into one object called name, smooth by angle, report tris and size."""
	global pieces
	bpy.ops.object.select_all(action='DESELECT')
	for ob in pieces:
		ob.select_set(True)
	bpy.context.view_layer.objects.active = pieces[0]
	bpy.ops.object.join()
	ob = bpy.context.object
	ob.name = ob.data.name = name
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	ob.data.materials.clear()
	ob.data.materials.append(mat)
	bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
	pieces = []
	ob.data.calc_loop_triangles()
	lo = Vector(map(min, *(v.co for v in ob.data.vertices)))
	hi = Vector(map(max, *(v.co for v in ob.data.vertices)))
	return ob, len(ob.data.loop_triangles), lo, hi


# ---- TimingTower: 6 x 6 footprint, 40 tall (section 1b.6). ----
box((0, 0, 1), (6, 6, 2), 'Charcoal', 0.45)  # plinth
# Kerb ring around the plinth top: alternating red / white 1-stud blocks.
for side in range(4):
	for i in range(6):
		t = -2.5 + i
		x, y = [(t, -2.92), (2.92, t), (-t, 2.92), (-2.92, -t)][side]
		sx, sy = (1.0, 0.2) if side % 2 == 0 else (0.2, 1.0)
		box((x, y, 1.0), (sx, sy, 0.5), 'Red' if (i + side) % 2 == 0 else 'White')
box((0, 0, 17.5), (5, 5, 31), 'White', 0.5)  # shaft z 2..33
for side in range(4):
	rot = Matrix.Rotation(side * math.pi / 2, 4, 'Z')
	# Checkered face: 4 x 6 squares of 1 stud, z 24..30, dark squares raised 0.06 off the face.
	for col in range(4):
		for row in range(6):
			if (col + row) % 2 == 0:
				ob = box((-1.5 + col, -2.53, 24.5 + row), (1, 0.12, 1), 'Charcoal')
				ob.data.transform(rot)
	# Decorative timing rows: amber position bar + cream time bar, 7 rows z 8..21.
	for row in range(7):
		z = 8.5 + row * 1.9
		ob = box((-1.35, -2.55, z), (1.2, 0.16, 1.3), 'Amber')
		ob.data.transform(rot)
		ob = box((0.75, -2.55, z), (2.6, 0.16, 1.3), 'Cream')
		ob.data.transform(rot)
	ob = box((0, -2.56, 5), (4, 0.18, 0.5), 'Red')  # red trim under the rows
	ob.data.transform(rot)
box((0, 0, 34.5), (5.8, 5.8, 3), 'Teal', 0.45)  # teal top band z 33..36
box((0, 0, 37.4), (6, 6, 2.8), 'Red', 0.9, 4)  # rounded red cap z 36..38.8
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.6, location=(0, 0, 39.4))
add(bpy.context.object, 'Amber')  # beacon, top at 40
tower = finish('TimingTower')

# ---- TyreStack: 3 rounded tyres, 3 x 3 x 3 (draft section 3), one mesh reused 12 times. ----
for i in range(3):
	bpy.ops.mesh.primitive_torus_add(major_segments=16, minor_segments=6, major_radius=1.08, minor_radius=0.42,
		location=(0, 0, 0))
	ob = bpy.context.object
	ob.rotation_euler[2] = math.pi / 16 * i  # stagger the facets so the stack reads hand-placed
	ob.scale = (1.0, 1.0, 0.5 / 0.42 * 0.98)
	bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
	ob.location.z = 0.5 + i
	sidewall = 'White' if i == 1 else 'Red'
	# Tread (outward-facing faces) stays rubber; the painted sidewalls carry the kerb red / white.
	add(ob, lambda p, s=sidewall: 'Rubber' if abs(p.normal.z) < 0.55 and p.center.xy.length > 1.0 else s)
tyre = finish('TyreStack')

report = {}
for (ob, tris, lo, hi) in [tower, tyre]:
	report[ob.name] = {'tris': tris, 'size': [round(hi.x - lo.x, 4), round(hi.z - lo.z, 4), round(hi.y - lo.y, 4)],
		'min_z': round(lo.z, 4)}
	print(ob.name, tris, report[ob.name]['size'])
assert report['TimingTower']['tris'] <= 4500, report
assert report['TyreStack']['tris'] <= 650, report
assert abs(report['TimingTower']['size'][1] - 40) < 1e-3 and report['TimingTower']['size'][0] <= 6.2, report

# FBX export with the car pipeline's settings (tools/build_redesign_cars.py): Roblox maps Blender (x, y, z) to
# Roblox (-x, z, y); both props are symmetric under that turn, so no extra rotation is needed.
for ob in (tower[0], tyre[0]):
	with bpy.context.temp_override(selected_objects=[ob], selected_editable_objects=[ob], active_object=ob):
		bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, ob.name + '.fbx'), use_selection=True,
			object_types={'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE', global_scale=0.01,
			axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE', add_leaf_bones=False, path_mode='COPY',
			embed_textures=True)

# Previews (the Blender MCP `look` substitute when building headless): Workbench, texture colours.
tyre[0].location = (6, 0, 0)
try:
	scene.render.engine = 'BLENDER_WORKBENCH'
except TypeError as e:  # enum names differ between Blender builds; the message lists the valid ones
	raise SystemExit(f'No Workbench engine: {e}')
scene.display.shading.color_type = 'TEXTURE'
scene.display.shading.light = 'STUDIO'
scene.render.resolution_x, scene.render.resolution_y = 640, 900
cam = bpy.data.objects.new('Preview', bpy.data.cameras.new('Preview'))
scene.collection.objects.link(cam)
scene.camera = cam
for name, loc, target in [('preview_iso', (40, -46, 34), (3, 0, 20)), ('preview_tyre', (9, -6, 5), (6, 0, 1.4))]:
	cam.location = loc
	cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
	scene.render.filepath = os.path.join(OUT, name + '.png')
	bpy.ops.render.render(write_still=True)
tyre[0].location = (0, 0, 0)
bpy.data.objects.remove(cam)

with open(os.path.join(OUT, 'props.json'), 'w') as f:
	json.dump(report, f, indent=2)
	f.write('\n')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'SpawnPaddock.blend'))
