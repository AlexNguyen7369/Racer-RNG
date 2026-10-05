"""Bake the Rusty Hatchback draft and export it for Roblox Studio (run headless):

  /Applications/Blender.app/Contents/MacOS/Blender -b drafts/cars/rusty-hatchback/rusty_hatchback.blend \
      --python blender/scenes/export_rusty_hatchback.py

Roblox does not read Blender node materials, so each mesh's colour (procedural rust + palette texture) is baked to
its own texture on a fresh UV map. The model is scaled so 1 unit = 1 stud (draft units x CarConfig.Scale 1.5) and
exported as FBX with embedded textures to blender/exports/rusty_hatchback/.
"""
import math
import os

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(bpy.data.filepath), "..", "..", ".."))
OUT = os.path.join(ROOT, "blender", "exports", "rusty_hatchback")
SCALE = 1.5  # CarConfig.Scale: draft units -> studs
SIZES = {"Body": 1024}  # wheels get 256
os.makedirs(OUT, exist_ok=True)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 16
scene.render.bake.use_pass_direct = False
scene.render.bake.use_pass_indirect = False
scene.render.bake.use_pass_color = True
scene.render.bake.margin = 4

# drop the hidden starter reference so it is never exported
for o in list(bpy.data.objects):
    if o.name.startswith("Starter_") or o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o, do_unlink=True)

parts = [bpy.data.objects[n] for n in ("Body", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR")]


def principled(mat):
    return next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


for obj in parts:
    obj.data = obj.data.copy()  # single-user mesh
    for i, slot in enumerate(obj.material_slots):
        if slot.material:
            obj.material_slots[i].material = slot.material.copy()  # single-user materials, own bake target

    # fresh UV map for the bake; the original stays the render UV the palette texture reads
    original = obj.data.uv_layers.active.name  # by name: layer references go stale when a layer is added
    obj.data.uv_layers[original].active_render = True
    bake_uv = obj.data.uv_layers.new(name="Bake")
    obj.data.uv_layers.active = bake_uv
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")

    size = SIZES.get(obj.name, 256)
    img = bpy.data.images.new(f"RustyHatchback_{obj.name}", size, size)
    for slot in obj.material_slots:
        nodes = slot.material.node_tree.nodes
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = img
        nodes.active = tex
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_clear=True, margin=4)
    img.filepath_raw = os.path.join(OUT, f"{img.name}.png")
    img.file_format = "PNG"
    img.save()

    # one plain material that shows the baked texture, on the bake UV only
    flat = bpy.data.materials.new(f"RustyHatchback_{obj.name}")
    flat.use_nodes = True
    tex = flat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    bsdf = principled(flat)
    flat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    obj.data.materials.clear()
    obj.data.materials.append(flat)
    obj.data.uv_layers.remove(obj.data.uv_layers[original])
    obj.data.uv_layers["Bake"].active_render = True
    print("BAKED", obj.name, size)

root = bpy.data.objects["RustyHatchback"]
root.scale = (root.scale[0] * SCALE, root.scale[1] * SCALE, root.scale[2] * SCALE)
bpy.context.view_layer.update()

# Flatten: the FBX axis conversion misplaces parented children, so every part becomes a top-level object at its
# world pose with rotation and scale applied (origins stay at each part's centre, so wheels can spin in place).
world = {obj.name: obj.matrix_world.copy() for obj in parts}
for obj in parts:
    obj.parent = None
    obj.matrix_world = world[obj.name]
bpy.data.objects.remove(root, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
for obj in parts:
    print("STUDS", obj.name, tuple(round(v, 2) for v in obj.dimensions), tuple(round(v, 2) for v in obj.location))
bpy.ops.export_scene.fbx(
    filepath=os.path.join(OUT, "RustyHatchback.fbx"),
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
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender", "scenes", "rusty_hatchback_export.blend"), copy=True)
print("EXPORTED", OUT)
