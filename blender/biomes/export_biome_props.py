# Bakes the CC0 biome props listed in drafts/environments/biome-props/props.json into one textured mesh
# each and exports one FBX per biome to assets/meshes/biomes/<Biome>.fbx (docs/BIOME_DRESSING_SPEC.md).
# Run headless:  Blender -b --python blender/biomes/export_biome_props.py -- <repo root> [Biome]
# 1 Blender unit = 1 stud; each prop is scaled to its listed height, origin at its base centre.
import bpy, glob, json, os, sys
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1 :]
ROOT = argv[0]
ONLY = argv[1] if len(argv) > 1 else None
OUT = os.path.join(ROOT, "assets", "meshes", "biomes")
TEX = os.path.join(OUT, "textures")
os.makedirs(TEX, exist_ok=True)
MANIFEST = json.load(open(os.path.join(ROOT, "drafts", "environments", "biome-props", "props.json")))
MAX_FACES = 4000  # Roblox allows 20k triangles per mesh; keep props light
TEX_SIZE = 256


def source(pack, name):
    base = os.path.join(ROOT, "references", "biome_packs", pack)
    hits = sorted(glob.glob(os.path.join(base, "**", name + ".glb"), recursive=True))
    hits += sorted(glob.glob(os.path.join(base, "**", name + ".gltf"), recursive=True))
    return hits[0]


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "CYCLES"
    except TypeError as e:
        print("ENGINE", e)
    scene.cycles.samples = 1
    scene.cycles.device = "CPU"
    scene.unit_settings.scale_length = 1.0


def import_prop(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    world = {o.name: o.matrix_world.copy() for o in meshes}
    for o in meshes:
        o.parent = None
        o.matrix_world = world[o.name]
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def normalise(obj, height):
    # Blender is Z-up here (glTF import converts); base centre to the origin, scaled to `height` studs.
    pts = [Vector(c) for c in obj.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    s = height / max(hi.z - lo.z, 1e-4)
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    obj.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(-centre))
    obj.location = (0, 0, 0)


def decimate(obj):
    faces = len(obj.data.polygons)
    if faces > MAX_FACES:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = MAX_FACES / faces
        bpy.ops.object.modifier_apply(modifier=mod.name)


def bake(obj, name):
    mesh = obj.data
    original = mesh.uv_layers[0] if mesh.uv_layers else None
    uv = mesh.uv_layers.new(name="Bake")
    mesh.uv_layers.active = uv
    if original:
        original.active_render = True  # material textures keep reading their own UVs
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    img = bpy.data.images.new(name, TEX_SIZE, TEX_SIZE)
    for mat in mesh.materials:
        if mat is None:
            continue
        mat.use_nodes = True
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        mat.node_tree.nodes.active = node
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=4)
    img.filepath_raw = os.path.join(TEX, name + ".png")
    img.file_format = "PNG"
    img.save()
    # One material that reads the baked texture through the Bake UVs.
    for layer in [l for l in mesh.uv_layers if l.name != "Bake"]:
        mesh.uv_layers.remove(layer)
    mesh.uv_layers["Bake"].name = "UVMap"
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    mesh.materials.clear()
    mesh.materials.append(mat)


for biome, props in MANIFEST.items():
    if biome.startswith("_") or (ONLY and biome != ONLY):
        continue
    setup_scene()
    x = 0.0
    for prop, (pack, model, height) in props.items():
        name = f"{biome}_{prop}"
        obj = import_prop(source(pack, model))
        normalise(obj, height)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        decimate(obj)
        bake(obj, name)
        obj.name = name
        obj.data.name = name
        width = obj.dimensions.x
        obj.location.x = x + width / 2
        x += width + 4
        print("PROP", name, len(obj.data.polygons), "faces", tuple(round(v, 1) for v in obj.dimensions))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, biome + ".fbx"),
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        bake_space_transform=False,
        axis_forward="-Z",
        axis_up="Y",
        path_mode="COPY",
        embed_textures=True,
        mesh_smooth_type="FACE",
    )
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "drafts", "environments", "biome-props", biome + ".blend"))
    print("EXPORTED", biome)
