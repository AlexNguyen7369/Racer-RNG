import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/theha/.codex/visualizations/2026/10/05/01a10e5c-0555-7db1-814f-d593c4dd6a8d/cars-draft05/import')
ROOT.mkdir(parents=True,exist_ok=True)
assert not (ROOT/'cars_A.fbx').exists()
assert bpy.context.mode=='OBJECT'
source=bpy.data.scenes['RacerCars_Draft05_Cute']
scene=bpy.data.scenes.new('Draft05_ImportExport');bpy.context.window.scene=scene
scene.unit_settings.scale_length=1
ids=['rusty_hatchback','wooden_car','go_kart','street_racer','rocket_car','hover_car','void_racer']
groups=[]
for i,carid in enumerate(ids):
    collection=bpy.data.collections.new('D05_'+carid);scene.collection.children.link(collection)
    parent=bpy.data.objects.new('D05_'+carid,None);collection.objects.link(parent)
    offset=Vector(((i%4)*7.6-11.4,(i//4)*9,0))
    parts=[]
    for original in bpy.data.collections['Cute05_'+carid].objects:
        ob=original.copy();ob.data=original.data.copy();collection.objects.link(ob)
        key=original.data.materials[0].name.removeprefix('Cute05_')
        ob.name='D05_'+carid+'_'+key;ob.data.name=ob.name
        ob.location-=offset;ob.parent=parent
        parts.append(ob)
    groups.append([parent]+parts)
paths=[]
for name,subset in [('cars_A',groups[:4]),('cars_B',groups[4:])]:
    bpy.ops.object.select_all(action='DESELECT')
    for group in subset:
        for ob in group:ob.select_set(True)
    out=ROOT/(name+'.fbx')
    bpy.ops.export_scene.fbx(filepath=str(out),use_selection=True,object_types={'MESH','EMPTY'},apply_unit_scale=False,bake_space_transform=True,axis_forward='-Z',axis_up='Y',bake_anim=False,use_triangles=True)
    paths.append(str(out))
bpy.context.window.scene=source
result={'files':paths,'sourceUnchanged':source.name,'carGroups':len(groups)}
