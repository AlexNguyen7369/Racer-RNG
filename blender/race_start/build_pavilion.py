import bpy, math, os, numpy as np
from mathutils import Vector

OUT = r'C:/Users/alex/Desktop/RobloxGame/Racer-RNG/blender/race_start'
os.makedirs(OUT, exist_ok=True)
NAME = 'RaceStartPavilion'
old = bpy.data.collections.get(NAME)
if old:
    for ob in list(old.objects): bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.collections.remove(old)
col = bpy.data.collections.new(NAME)
bpy.context.scene.collection.children.link(col)
groups = {}
def material(name, rgb):
    mat = bpy.data.materials.new('Race_' + name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (*rgb, 1)
    mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = .32
    return mat
mats = {k:material(k,v) for k,v in {
    'RoofPurple':(.19,.055,.48), 'StructureGreen':(.025,.55,.18),
    'DarkHousings':(.018,.045,.10), 'CyanLights':(.025,.94,1),
    'GreenLights':(.08,1,.28), 'AmberLights':(1,.86,.035),
    'WhiteLettering':(.96,.985,1), 'LetterBacking':(.025,.055,.28),
    'GridMarkings':(.72,1,.95), 'CheckerPanels':(1,1,1),
    'DeckTeal':(.018,.22,.19)}.items()}
# One small shared checker image; every other surface is intentionally solid-color.
img = bpy.data.images.new('RaceChecker', width=128, height=128)
yy,xx=np.mgrid[:128,:128]; mask=((xx//32+yy//32)%2)==0
px=np.ones((128,128,4),dtype=np.float32)
px[:,:,:3]=np.where(mask[:,:,None],np.array([.97,.99,1]),np.array([.015,.035,.045]))
img.pixels.foreach_set(px.ravel()); img.filepath_raw=OUT+'/RaceChecker.png'; img.file_format='PNG'; img.save(); img.pack()
tex=mats['CheckerPanels'].node_tree.nodes.new('ShaderNodeTexImage'); tex.image=img
mats['CheckerPanels'].node_tree.links.new(tex.outputs['Color'],mats['CheckerPanels'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
def register(ob, group):
    for c in list(ob.users_collection): c.objects.unlink(ob)
    col.objects.link(ob); ob.data.materials.clear(); ob.data.materials.append(mats[group])
    if ob.type=='MESH' and not ob.data.uv_layers: ob.data.uv_layers.new(name='UVMap')
    groups.setdefault(group,[]).append(ob)
    return ob
def box(name, center, size, group, bevel=0):
    # Coordinates below use Roblox local x, z, height; Blender -Y is Roblox +Z.
    x,z,h=center; sx,sz,sh=size
    bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-z,h)); ob=bpy.context.object; ob.name=name
    ob.scale=(sx,sz,sh); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('SoftEdges','BEVEL'); mod.width=bevel; mod.segments=1
        bpy.context.view_layer.objects.active=ob; bpy.ops.object.modifier_apply(modifier=mod.name)
    return register(ob,group)
def line(name,a,b,width,group):
    av=Vector((a[0],-a[1],a[2])); bv=Vector((b[0],-b[1],b[2]))
    ob=box(name,(0,0,0),(width,width,(bv-av).length),group,.035)
    ob.location=(av+bv)/2; ob.rotation_euler=(bv-av).to_track_quat('Z','Y').to_euler(); return ob
def text(name,words,x,z,h,size,group,depth=.12):
    cu=bpy.data.curves.new(name,'FONT'); cu.body=words; cu.align_x='CENTER'; cu.size=size; cu.extrude=depth; cu.bevel_depth=.025; cu.bevel_resolution=0; cu.resolution_u=3
    font=r'C:/Windows/Fonts/arialbd.ttf'
    if os.path.exists(font): cu.font=bpy.data.fonts.load(font)
    ob=bpy.data.objects.new(name,cu); col.objects.link(ob); ob.location=(x,-z,h); ob.rotation_euler=(math.pi/2,0,0)
    bpy.context.view_layer.objects.active=ob; ob.select_set(True); bpy.ops.object.convert(target='MESH'); ob.select_set(False)
    return register(ob,group)
def panel(name,x,z,h,w,height):
    box(name+'Frame',(x,z,h),(w+.5,.4,height+.5),'LetterBacking',.12)
    # Single quad with explicit UVs avoids repeating tiles on narrow cube edges.
    me=bpy.data.meshes.new(name); me.from_pydata([(x-w/2,-z-.23,h-height/2),(x+w/2,-z-.23,h-height/2),(x+w/2,-z-.23,h+height/2),(x-w/2,-z-.23,h+height/2)],[],[(0,1,2,3)]); me.uv_layers.new()
    for loop,uv in zip(me.uv_layers.active.data,[(0,0),(1,0),(1,1),(0,1)]): loop.uv=uv
    ob=bpy.data.objects.new(name,me); col.objects.link(ob); register(ob,'CheckerPanels')

# Raised beveled roof, deep purple fascia, four green supports outside the lanes.
box('Canopy',(0,20,13.2),(46,30,1.3),'RoofPurple',.5)
box('UpperCap',(0,20,14.1),(42,26,.65),'LetterBacking',.3)
for x in [-20.5,20.5]:
    for z in [7,33]:
        box('ColumnFoot',(x,z,.25),(3.3,3.3,.5),'DarkHousings',.15)
        box('Column',(x,z,6.5),(2.6,2.6,12.5),'StructureGreen',.2)
        box('ColumnCyanStrip',(x,z+1.34,6.5),(.35,.1,7),'CyanLights')
        panel('ColumnChecker',x,z+1.4,2.2,2.65,2.65)
for z in [4.9,35.1]:
    box('RoofCyanEdge',(0,z,13.7),(46,.25,.25),'CyanLights',.05)
    box('RoofGreenBlade',(0,z+.1,14.65),(39,.5,.24),'GreenLights',.08)
for x in [-22.8,22.8]: box('SideCyanEdge',(x,20,13.7),(.25,30,.25),'CyanLights',.05)
for x in [-13,0,13]:
    for z in [11,20,29]: box('CeilingLight',(x,z,12.5),(4,2,.17),'CyanLights',.14)
# Big dimensional lettering and checker flags, like the supplied image.
box('HeroSignBackboard',(0,34.3,17.4),(36,.85,5.6),'LetterBacking',.35)
text('HeroShadow','RACE START',.12,34.8,15.05,6.3,'LetterBacking',.3)
text('HeroLetters','RACE START',0,35.2,15.15,6.3,'WhiteLettering',.17)
for x in [-20,20]: panel('HeroCheckerFlag',x,35,17,4.3,3.5)
box('SignalHousing',(0,35,14.4),(13,.65,1.15),'DarkHousings',.2)
for x in [-4.5,-1.5,1.5,4.5]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.46,location=(x,-35.42,14.45))
    register(bpy.context.object,'AmberLights')
# Open rail edges: 20-stud gap on the hub side; no divider between racing lanes.
for x,spans in [(-21,[(2,38)]),(23,[(2,10),(30,38)])]:
    for a,b in spans:
        for z in sorted(set([a,b]+list(range(int(a)+8,int(b),8)))):
            box('RailBollard',(x,z,1.5),(1.15,1.3,3),'DarkHousings',.1)
            box('BollardLamp',(x,z,3.15),(1.05,1.15,.4),'CyanLights',.08)
        for h in [.85,2.15]: box('RailBeam',(x,(a+b)/2,h),(.45,b-a,.38),'GreenLights',.08)
# Floor paint is decorative, suspended a hair above the original trigger surface.
box('DeckTeal',(0,20,.01),(37.6,35.4,.018),'DeckTeal')
for x in [-18.5,0,18.5]: box('LaneStripe',(x,20,.035),(.15,34,.025),'GridMarkings')
for x in [-10,10]:
    for z in [14,27]:
        for dx in [-7,7]: box('GridBoxEdge',(x+dx,z,.04),(.16,7,.03),'GridMarkings')
        box('GridBoxRear',(x,z+3.5,.04),(14,.18,.03),'GridMarkings')
    for z in [8,18,31]:
        line('ForwardChevron',(x-2,z+1,.045),(x,z-1,.045),.32,'GridMarkings')
        line('ForwardChevron',(x,z-1,.045),(x+2,z+1,.045),.32,'GridMarkings')
# Pylon arrows and a small hub-facing directional sign, kept off the road.
for x in [-20.5,20.5]:
    box('ArrowPlate',(x,34.6,4.5),(3.1,.35,1.45),'DarkHousings',.12)
    for dx in [-.65,.65]:
        line('YellowChevron',(x+dx-.3,34.85,4),(x+dx+.3,34.85,4.5),.24,'AmberLights')
        line('YellowChevron',(x+dx+.3,34.85,4.5),(x+dx-.3,34.85,5),.24,'AmberLights')
box('HubSign',(23,20,8),(1,10,3),'LetterBacking',.2)
# Side lettering faces +X (readable from the spawn hub).
ob=text('HubLetters','START RACING',0,0,0,1.25,'WhiteLettering')
ob.rotation_euler=(math.pi/2,0,math.pi/2); ob.location=(23.6,-20,7.65)

# Batch by material for a small, deterministic mesh count.
for group, obs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs: ob.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]; bpy.ops.object.join()
    ob=bpy.context.object; ob.name=group
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    if group == 'GridMarkings':
        bpy.ops.object.transform_apply(location=True,rotation=False,scale=False)
        for vertex in ob.data.vertices: vertex.co.z = .025 + (vertex.co.z + .115) * .04
    if not ob.data.uv_layers: ob.data.uv_layers.new(name='UVMap')
    ob.data.calc_loop_triangles()
    print(group, 'triangles',len(ob.data.loop_triangles))
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/RaceStartPavilion.blend')
result={'collection':NAME,'meshes':len(col.objects)}
