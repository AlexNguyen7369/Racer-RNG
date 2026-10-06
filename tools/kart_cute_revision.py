import bpy, math, json
from pathlib import Path
OUT=Path(r'C:/Users/theha/.codex/visualizations/2026/10/05/01a10e5c-0555-7db1-814f-d593c4dd6a8d/kart-cute')
OUT.mkdir(parents=True,exist_ok=True)
assert not (OUT/'go_kart_cute.blend').exists()
old=bpy.data.scenes['GoKart_Draft04']
scene=bpy.data.scenes.new('GoKart_Cute')
bpy.context.window.scene=scene
col=bpy.data.collections.new('GoKart_Cute_Model');scene.collection.children.link(col)
objects=[]
for original in bpy.data.collections['go_kart_draft04'].objects:
    ob=original.copy();ob.data=original.data.copy();col.objects.link(ob)
    ob.name=original.name.replace('draft04','cute');ob.data.name=ob.name
    mat=ob.data.materials[0].copy();ob.data.materials[0]=mat
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.4;bs.inputs['Metallic'].default_value=.08
    if ob.name.endswith('red'):
        color=(.94,.09,.13,1);mat.diffuse_color=color;bs.inputs['Base Color'].default_value=color
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
        mod=ob.modifiers.new('Soft toy edges','BEVEL');mod.width=.07;mod.segments=1;mod.limit_method='ANGLE';mod.angle_limit=.6
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if ob.name.endswith('black'):
        for poly in ob.data.polygons:
            # Smooth only outer tire rings; keep bucket-seat planes and rim caps crisp.
            poly.use_smooth=abs(poly.center.x)>1.5 and abs(poly.normal.x)<.8
    objects.append(ob)
bpy.context.view_layer.update()
report=[]
for ob in objects:
    ob.data.calc_loop_triangles();tris=len(ob.data.loop_triangles)
    assert tris<=1000,(ob.name,tris)
    report.append({'name':ob.name,'triangles':tris})
assert sum(r['triangles'] for r in report)<1500
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'go_kart_cute.glb'),export_format='GLB',use_selection=True,use_active_scene=True)
bpy.ops.export_scene.fbx(filepath=str(OUT/'go_kart_cute.fbx'),use_selection=True,object_types={'MESH'},apply_unit_scale=False,bake_space_transform=True,axis_forward='-Z',axis_up='Y',bake_anim=False,use_triangles=True)
stage=bpy.data.collections.new('GoKart_Cute_Stage');scene.collection.children.link(stage)
for original in bpy.data.collections['Kart04_Preview'].objects:
    ob=original.copy();stage.objects.link(ob)
    if ob.type=='CAMERA':scene.camera=ob
scene.world=old.world
scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.filepath=str(OUT/'go_kart_cute.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'go_kart_cute.blend'),copy=True)
(OUT/'triangle_report.json').write_text(json.dumps(report,indent=2))
bpy.ops.render.render(write_still=True)
result={'triangles':sum(r['triangles'] for r in report),'meshes':report,'render':scene.render.filepath,'preserved':old.name}
