"""Cute toy-car revision; additive scene, actual low-poly mesh previews."""
import bpy, math, ast, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/theha/.codex/visualizations/2026/10/05/01a10e5c-0555-7db1-814f-d593c4dd6a8d/cars-draft05')
ROOT.mkdir(parents=True,exist_ok=True)
assert not (ROOT/'cars_draft05.blend').exists()
assert bpy.context.mode=='OBJECT'
previous=bpy.context.scene.name
scene=bpy.data.scenes.new('RacerCars_Draft05_Cute');bpy.context.window.scene=scene
scene.unit_settings.system='NONE';scene.unit_settings.scale_length=1
palette={'orange':'#FBA052','wood':'#B98650','woodlight':'#E9BE79','red':'#F34F5C','white':'#FAF0DD','purple':'#AD79EB','pink':'#F795C8','cyan':'#79E5F0','black':'#252B36','glass':'#40596D','gray':'#99A5B1','yellow':'#FFE5A2','rust':'#AA7750'}
mats={}
for key,h in palette.items():
    rgb=tuple(int(h[i:i+2],16)/255 for i in (1,3,5))
    mat=bpy.data.materials.new('Cute05_'+key);mat.diffuse_color=(*rgb,1);mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*rgb,1)
    bs.inputs['Roughness'].default_value=.42 if key not in ('black','rust') else .65
    bs.inputs['Metallic'].default_value=.18 if key=='gray' else 0
    mats[key]=mat
tree=ast.parse(Path(r'C:/Users/theha/OneDrive/Documents/codex racer rng/tools/build_draft03_cars.py').read_text())
helpers=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ('mesh','box','taper','cyl','fin')]
exec(compile(ast.Module(body=helpers,type_ignores=[]),'<car primitives>','exec'))
current=None

def soft(ob,width=.08,segments=1):
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
    mod=ob.modifiers.new('Soft edges','BEVEL');mod.width=width;mod.segments=segments;mod.limit_method='ANGLE';mod.angle_limit=.65
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob
def B(name,p,s,color,width=.07):return soft(box(name,p,s,color),width)
def T(name,*args,width=.09,segments=1):return soft(taper(name,*args),width,segments)
def wheels():
    for side in (-1,1):
        for i,y in enumerate((-1.55,1.55)):
            ob=cyl('Tyre'+str(side)+str(i),(side*1.7,y,.67),.68,.58,'black',sides=12)
            for p in ob.data.polygons:p.use_smooth=len(p.vertices)==4
            cyl('Rim'+str(side)+str(i),(side*2.0,y,.67),.34,.045,'gray',sides=10)
            cyl('Hub'+str(side)+str(i),(side*2.035,y,.67),.14,.055,'black',sides=8)
def lamps(color='yellow'):
    for side in (-1,1):
        cyl('LampTrim'+str(side),(side*1.06,-2.57,1.18),.31,.10,'gray',axis='Y',sides=12)
        cyl('LampLens'+str(side),(side*1.06,-2.635,1.18),.25,.065,color,axis='Y',sides=12)
        B('TailLight'+str(side),(side*1.13,2.47,1.11),(.44,.09,.24),'red',.035)
    B('FrontBumper',(0,-2.67,.79),(2.94,.25,.22),'black')
    B('Grille',(0,-2.592,1.09),(.9,.08,.22),'black',.065)
def cabin(color,top=2.5,rear=1.4):
    # A low cabin, generous window area, and two-segment roof edges.
    T('Cabin',2.75,-.68,1.92,1.43,top,2.32,-.10,rear,color,width=.11,segments=2)
    low=1.62;high=top-.16;fraction=lambda z:(z-1.43)/(top-1.43)
    yl=-.68+.58*fraction(low)-.016;yh=-.68+.58*fraction(high)-.016
    mesh('Windshield',[(-1.13,yl,low),(1.13,yl,low),(1.03,yh,high),(-1.03,yh,high)],[(0,1,2,3)],'glass')
    for side in (-1,1):
        xl=side*(1.375-.215*fraction(low)+.016);xh=side*(1.375-.215*fraction(high)+.016)
        mesh('SideGlass'+str(side),[(xl,-.43,low),(xl,1.55,low),(xh,rear-.18,high),(xh,.05,high)],[(0,1,2,3)],'glass')
        # Painted B pillar and door handle break up the long window.
        mesh('Pillar'+str(side),[(xl+side*.004,.63,low),(xl+side*.004,.73,low),(xh+side*.004,.73,high),(xh+side*.004,.63,high)],[(0,1,2,3)],color)
        B('Handle'+str(side),(side*1.575,.75,1.37),(.035,.28,.07),'gray',.02)
        B('Mirror'+str(side),(side*1.54,-.46,1.78),(.30,.25,.19),color,.07)
def base(color,top=1.48):
    T('Body',3.2,-2.7,2.55,.63,top,3.05,-2.44,2.4,color,width=.13,segments=2)
    for side in (-1,1):
        B('Sill'+str(side),(side*1.52,.0,.78),(.15,3.25,.17),color,.04)

ids=['rusty_hatchback','wooden_car','go_kart','street_racer','rocket_car','hover_car','void_racer']
report=[]
for index,carid in enumerate(ids):
    current=bpy.data.collections.new('Cute05_'+carid);scene.collection.children.link(current)
    if carid=='go_kart':
        for original in bpy.data.collections['GoKart_Cute_Model'].objects:
            ob=original.copy();ob.data=original.data.copy();current.objects.link(ob)
            key=original.name.split('_')[-1];ob.data.materials.clear();ob.data.materials.append(mats[key])
            ob.name=carid+'_'+key
    else:
        color={'rusty_hatchback':'orange','wooden_car':'woodlight','street_racer':'purple','rocket_car':'red','hover_car':'pink','void_racer':'black'}[carid]
        base(color);cabin(color,top=2.48 if carid in ('rusty_hatchback','wooden_car') else 2.24,rear=1.38)
        if carid in ('hover_car','void_racer'):
            for side in (-1,1):
                for j,y in enumerate((-1.55,1.55)):
                    soft(cyl('HoverPod'+str(side)+str(j),(side*1.72,y,.58),.65,.40,'black',axis='Z',sides=10),.05)
                    cyl('PodAccent'+str(side)+str(j),(side*1.72,y,.37),.57,.065,'cyan' if carid=='hover_car' else 'purple',axis='Z',sides=10)
        else:wheels()
        lamps('cyan' if carid=='hover_car' else 'yellow')
        if carid=='rusty_hatchback':
            # Small painted chips, not a noisy corroded texture over the whole body.
            mesh('HoodRust',[(-.8,-1.83,1.486),(-.44,-1.78,1.486),(-.39,-1.54,1.486),(-.6,-1.44,1.486),(-.86,-1.59,1.486)],[(0,1,2,3,4)],'rust')
            B('RustChip',(1.587,1.18,1.17),(.016,.24,.12),'rust',.02)
            B('RearBumper',(0,2.57,.82),(2.84,.22,.19),'gray')
        elif carid=='wooden_car':
            for side in (-1,1):
                B('WoodPanel'+str(side),(side*1.595,.3,1.09),(.035,3.34,.36),'wood',.06)
                for y in (-.95,.6,1.6):B('PlankJoint'+str(side)+str(y),(side*1.616,y,1.1),(.018,.035,.29),'woodlight',.01)
            B('RoofRack',(0,.65,2.53),(2.25,1.3,.12),'wood',.045)
        elif carid=='street_racer':
            for side in (-1,1):
                B('SpoilerPost'+str(side),(side*.93,2.13,1.77),(.16,.18,.50),'black',.03)
                B('HoodStripe'+str(side),(side*.36,-1.72,1.486),(.17,1.03,.025),'white',.015)
            B('Spoiler',(0,2.12,2.04),(3.1,.48,.18),'purple',.075)
        elif carid=='rocket_car':
            for side in (-1,1):
                soft(cyl('Rocket'+str(side),(side*.79,1.38,2.42),.39,1.27,'gray',axis='Y',sides=10),.055)
                cyl('Nozzle'+str(side),(side*.79,2.04,2.42),.28,.13,'black',axis='Y',sides=10)
                B('RocketMount'+str(side),(side*.79,1.37,1.90),(.16,.55,.39),'red',.04)
                soft(fin('Fin'+str(side),side*.79,1.64,2.60,'red',height=.63),.035)
        else:
            accent='cyan' if carid=='hover_car' else 'purple'
            for side in (-1,1):
                soft(fin('TailFin'+str(side),side*1.06,1.8,1.48,accent,height=.64),.035)
                B('SideAccent'+str(side),(side*1.6,.3,1.1),(.06,2.15,.105),accent,.03)
            if carid=='void_racer':B('HoodEmblem',(0,-1.64,1.51),(.6,.56,.07),'purple',.12)
    # Compact material-group meshes; all transforms baked before export.
    for key,mat in mats.items():
        group=[o for o in current.objects if o.type=='MESH' and o.data.materials[0]==mat]
        if not group:continue
        bpy.ops.object.select_all(action='DESELECT')
        for ob in group:ob.select_set(True)
        bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join()
        ob=group[0];ob.name=carid+'_'+key;ob.data.name=ob.name
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    objects=list(current.objects);counts=[]
    for ob in objects:
        ob.data.calc_loop_triangles();count=len(ob.data.loop_triangles);assert count<=1000,(ob.name,count);counts.append(count)
    total=sum(counts);assert total<2000,(carid,total)
    out=ROOT/'export'/carid;out.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out/(carid+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True)
    bpy.ops.export_scene.fbx(filepath=str(out/(carid+'.fbx')),use_selection=True,object_types={'MESH'},apply_unit_scale=False,bake_space_transform=True,axis_forward='-Z',axis_up='Y',bake_anim=False,use_triangles=True)
    report.append({'id':carid,'triangles':total,'meshes':len(objects),'largest_mesh':max(counts)})
    offset=Vector(((index%4)*7.6-11.4,(index//4)*9,0))
    for ob in objects:ob.location+=offset

current=bpy.data.collections.new('Cute05_PreviewStage');scene.collection.children.link(current)
B('Floor',(0,4,-.15),(120,120,.2),'white')
camdata=bpy.data.cameras.new('Cute05_Camera');camera=bpy.data.objects.new('Cute05_Camera',camdata);current.objects.link(camera)
target=Vector((0,3.9,1.1));camera.location=(20,-30,24);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camdata.type='ORTHO';camdata.ortho_scale=35;scene.camera=camera
for name,pos,power,size in [('Key',(0,-8,18),2200,15),('Fill',(-16,2,13),1700,12)]:
    data=bpy.data.lights.new('Cute05_'+name,'AREA');light=bpy.data.objects.new(data.name,data);current.objects.link(light)
    light.location=pos;light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler();data.energy=power;data.size=size
scene.world=bpy.data.worlds.new('Cute05_World');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.73,.85,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.view_settings.view_transform='Standard'
scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.filepath=str(ROOT/'fleet.png')
(ROOT/'triangle_report.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'cars_draft05.blend'),copy=True)
bpy.ops.render.render(write_still=True)
# Front three-quarter hatchback close-up, using the same actual exported mesh.
hatch=Vector((-11.4,0,1.1));camera.location=hatch+Vector((7,-10,5.8));camera.rotation_euler=(hatch-camera.location).to_track_quat('-Z','Y').to_euler();camdata.ortho_scale=7.7
scene.render.resolution_x=1100;scene.render.resolution_y=850;scene.render.filepath=str(ROOT/'rusty_hatchback.png')
bpy.ops.render.render(write_still=True)
result={'models':report,'fleet':str(ROOT/'fleet.png'),'hatchback':str(ROOT/'rusty_hatchback.png'),'previous_scene_preserved':previous}
