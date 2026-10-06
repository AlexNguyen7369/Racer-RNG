"""Additive kart revision: preserve every previous Blender scene/model."""
import bpy, ast, math, json
from pathlib import Path
from mathutils import Vector

OUT = Path(r'C:/Users/theha/.codex/visualizations/2026/10/05/01a10e5c-0555-7db1-814f-d593c4dd6a8d/kart-draft04')
OUT.mkdir(parents=True, exist_ok=True)
assert not (OUT/'go_kart_draft04.blend').exists(), 'Use a new revision; do not overwrite.'
assert bpy.context.mode == 'OBJECT'
source_scene = bpy.context.scene
scene = bpy.data.scenes.new('GoKart_Draft04')
bpy.context.window.scene = scene
scene.unit_settings.system = 'NONE'
scene.unit_settings.scale_length = 1
current = bpy.data.collections.new('go_kart_draft04')
scene.collection.children.link(current)
mats = {}
for key, rgb in {'red':(.8,.035,.065),'white':(.87,.89,.93),'black':(.025,.03,.045),'gray':(.3,.34,.4),'yellow':(.92,.62,.05)}.items():
    mat = bpy.data.materials.new('Kart04_'+key)
    mat.diffuse_color = (*rgb,1)
    mat.use_nodes = True
    bs = mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*rgb,1)
    bs.inputs['Roughness'].default_value = .62
    bs.inputs['Metallic'].default_value = .35 if key=='gray' else .05
    mats[key] = mat
# Reuse checked primitive helpers from the previous build, not its scene/export side effects.
source = Path(r'C:/Users/theha/OneDrive/Documents/codex racer rng/tools/build_draft03_cars.py').read_text()
tree = ast.parse(source)
helpers = [n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ('mesh','box','taper','cyl')]
exec(compile(ast.Module(body=helpers,type_ignores=[]),'<draft03 primitives>','exec'))

def bar(name,a,b,r,color='gray',sides=6):
    mid=(Vector(a)+Vector(b))/2
    ob=cyl(name,(0,0,0),r,(Vector(b)-Vector(a)).length,color,axis='Z',sides=sides)
    ob.location=mid
    ob.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler()
    return ob

for side in (-1,1):
    x=side*1.25
    bar('FrameRail'+str(side),(x,-2.45,.57),(x,2.1,.57),.105)
    bar('SeatBrace'+str(side),(side*.58,.6,.65),(side*.58,1.35,1.95),.09)
    taper('SidePod'+str(side),.76,-.6,1.7,.6,1.28,.65,-.38,1.5,'red').location.x=side*1.2
    box('SideStripe'+str(side),(side*1.595,.55,1.0),(.012,1.6,.13),'white')
    for j,y in enumerate((-1.7,1.7)):
        cyl('Tire'+str(side)+str(j),(side*1.88,y,.68),.7,.68,'black',sides=12)
        cyl('Rim'+str(side)+str(j),(side*2.23,y,.68),.37,.045,'gray',sides=8)
        cyl('Hub'+str(side)+str(j),(side*2.26,y,.68),.13,.065,'black',sides=6)
bar('FrontAxle',(-1.9,-1.7,.64),(1.9,-1.7,.64),.11)
bar('RearAxle',(-1.9,1.7,.64),(1.9,1.7,.64),.11)
bar('FrontBumper',(-1.3,-2.6,.72),(1.3,-2.6,.72),.12,'black')
bar('RearBumper',(-1.35,2.35,.8),(1.35,2.35,.8),.12,'black')
taper('Nose',2.5,-2.48,-.9,.65,1.13,1.9,-2.3,-.85,'red')
taper('NoseStripe',.3,-2.3,-.95,1.14,1.16,.3,-2.3,-.95,'white')
box('Floor',(0,-.35,.62),(1.72,2.65,.12),'gray')
taper('SeatBase',1.16,.1,1.2,.75,1.03,.94,.22,1.16,'black')
taper('BucketBack',1.32,.94,1.3,1.0,2.16,1.04,1.18,1.5,'black')
for s in (-1,1):
    taper('SeatBolster'+str(s),.2,.16,1.19,.97,1.39,.16,.45,1.26,'black').location.x=s*.59
bar('SteeringColumn',(0,-.6,.72),(0,-.28,1.66),.075,'gray')
# Low-poly ring: unlike a solid disk, this has an open center.
v=[]; faces=[]
for z in (-.045,.045):
    for radius in (.32,.23):
        for i in range(10):
            a=i*math.tau/10;v.append((radius*math.cos(a),radius*math.sin(a),z))
for i in range(10):
    j=(i+1)%10
    faces.extend([(i,j,20+j,20+i),(10+i,30+i,30+j,10+j),(i,10+i,10+j,j),(20+i,20+j,30+j,30+i)])
wheel=mesh('SteeringRing',v,faces,'black');wheel.location=(0,-.26,1.67);wheel.rotation_euler.x=math.radians(55)
bar('SteeringSpoke',(-.22,-.27,1.64),(.22,-.27,1.64),.035,'gray',sides=4)
box('EngineBlock',(.66,1.86,1.18),(.75,.65,.62),'gray')
for z in (1.08,1.22,1.36):box('EngineFin'+str(z),(.66,1.87,z),(.9,.72,.055),'black')
cyl('AirFilter',(.67,1.87,1.62),.22,.18,'red',axis='Z',sides=8)
bar('Exhaust',(.95,1.9,1.0),(1.1,2.4,1.22),.1,'gray')
box('FuelTank',(-.53,1.78,1.04),(.56,.67,.43),'white')
box('NumberPlate',(0,-.86,1.47),(.68,.1,.59),'white')

# Merge material groups with a consistent base-center origin.
for key,mat in mats.items():
    group=[o for o in current.objects if o.data.materials[0]==mat]
    if not group:continue
    bpy.ops.object.select_all(action='DESELECT')
    for ob in group:ob.select_set(True)
    bpy.context.view_layer.objects.active=group[0]
    bpy.ops.object.join()
    ob=group[0];ob.name='go_kart_draft04_'+key
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
objects=list(current.objects)
tris=0
for ob in objects:ob.data.calc_loop_triangles();tris+=len(ob.data.loop_triangles)
assert tris<=1000, tris
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'go_kart_draft04.glb'),export_format='GLB',use_selection=True)
bpy.ops.export_scene.fbx(filepath=str(OUT/'go_kart_draft04.fbx'),use_selection=True,object_types={'MESH'},apply_unit_scale=False,bake_space_transform=True,axis_forward='-Z',axis_up='Y',bake_anim=False,use_triangles=True)
stage=bpy.data.collections.new('Kart04_Preview');scene.collection.children.link(stage)
current=stage
box('Floor',(0,0,-.15),(200,200,.15),'white')
camera_data=bpy.data.cameras.new('Kart04_Camera');camera=bpy.data.objects.new('Kart04_Camera',camera_data);stage.objects.link(camera)
camera.location=(8,-10,7);target=Vector((0,0,1.0));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO';camera_data.ortho_scale=8.7;scene.camera=camera
for name,pos,power,size in [('Key',(0,-5,9),1100,7),('Fill',(-5,3,6),800,6)]:
    data=bpy.data.lights.new('Kart04_'+name,'AREA');light=bpy.data.objects.new(data.name,data);stage.objects.link(light)
    light.location=pos;light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler();data.energy=power;data.size=size
scene.world=bpy.data.worlds.new('Kart04_World');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.filepath=str(OUT/'go_kart_draft04.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'go_kart_draft04.blend'),copy=True)
bpy.ops.render.render(write_still=True)
result={'triangles':tris,'meshes':len(objects),'render':str(OUT/'go_kart_draft04.png'),'previous_scene_preserved':source_scene.name}
