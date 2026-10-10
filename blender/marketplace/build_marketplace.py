import bpy, math, os, numpy as np
from mathutils import Vector
OUT = r'C:/Users/alex/Desktop/RobloxGame/Racer-RNG/blender/marketplace'
os.makedirs(OUT, exist_ok=True)
NAME='SpawnMarketplace'
if NAME in bpy.data.collections:
    for ob in list(bpy.data.collections[NAME].all_objects): bpy.data.objects.remove(ob,do_unlink=True)
    bpy.data.collections.remove(bpy.data.collections[NAME])
col=bpy.data.collections.new(NAME); bpy.context.scene.collection.children.link(col)
groups={}; zone='Courtyard'
palette={'Wood':(.34,.16,.055),'Metal':(.25,.29,.34),'Gold':(.8,.48,.12),'Dark':(.025,.038,.07),'Cream':(.92,.79,.58),'Red':(.72,.045,.035),'Cyan':(.015,.8,1),'Purple':(.65,.025,.95),'Green':(.025,.7,.12),'Amber':(1,.6,.035),'Stone':(.64,.55,.43),'White':(.93,.93,.85)}
mats={}
for key,rgb in palette.items():
    mat=bpy.data.materials.new('Market_'+key); mat.use_nodes=True; mat.diffuse_color=(*rgb,1)
    node=mat.node_tree.nodes.get('Principled BSDF'); node.inputs['Base Color'].default_value=(*rgb,1); node.inputs['Roughness'].default_value=.6
    if key in ['Wood','Stone']:
        yy,xx=np.mgrid[:256,:256]; rng=np.random.default_rng(6)
        if key=='Wood': v=.88+.10*np.sin(xx*.27+np.sin(yy*.045)*2)+rng.random((256,256))*.07
        else: v=.94+rng.random((256,256))*.10-.07*np.sin(xx*.17)*np.sin(yy*.13)
        px=np.ones((256,256,4),dtype=np.float32); px[:,:,:3]=np.array(rgb)*v[:,:,None]
        im=bpy.data.images.new('Market'+key,width=256,height=256); im.pixels.foreach_set(px.ravel()); im.filepath_raw=OUT+'/Market'+key+'.png'; im.file_format='PNG'; im.save(); im.pack()
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im; mat.node_tree.links.new(tex.outputs['Color'],node.inputs['Base Color']); mat.diffuse_color=(1,1,1,1)
    mats[key]=mat
def reg(ob,mat):
    for c in list(ob.users_collection): c.objects.unlink(ob)
    col.objects.link(ob); ob.data.materials.clear(); ob.data.materials.append(mats[mat])
    if not ob.data.uv_layers: ob.data.uv_layers.new(name='UVMap')
    groups.setdefault(zone+'_'+mat,[]).append(ob); return ob
def box(name,p,s,mat,bevel=.06):
    x,z,h=p; sx,sz,sh=s; bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-z,h)); ob=bpy.context.object; ob.name=name; ob.scale=(sx,sz,sh); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=ob.modifiers.new('SoftEdges','BEVEL'); m.width=bevel; m.segments=1; bpy.ops.object.modifier_apply(modifier=m.name)
    return reg(ob,mat)
def cyl(name,p,r,depth,mat,axis='Z',vertices=12):
    x,z,h=p; bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=(x,-z,h)); ob=bpy.context.object; ob.name=name
    if axis=='Y': ob.rotation_euler[0]=math.pi/2
    if axis=='X': ob.rotation_euler[1]=math.pi/2
    return reg(ob,mat)
def line(name,a,b,r,mat):
    av=Vector((a[0],-a[1],a[2])); bv=Vector((b[0],-b[1],b[2])); ob=cyl(name,(0,0,0),r,(bv-av).length,mat); ob.location=(av+bv)/2; ob.rotation_euler=(bv-av).to_track_quat('Z','Y').to_euler(); return ob
def ring(name,p,r,t,mat,vertical=False):
    x,z,h=p; bpy.ops.mesh.primitive_torus_add(major_segments=20,minor_segments=6,location=(x,-z,h),major_radius=r,minor_radius=t); ob=bpy.context.object; ob.name=name
    if vertical: ob.rotation_euler[0]=math.pi/2
    return reg(ob,mat)
def text(words,x,z,h,size,mat):
    cu=bpy.data.curves.new(words,'FONT'); cu.body=words; cu.align_x='CENTER'; cu.size=size; cu.extrude=.04; cu.resolution_u=2
    cu.font=bpy.data.fonts.load(r'C:/Windows/Fonts/arialbd.ttf')
    ob=bpy.data.objects.new(words,cu); col.objects.link(ob); ob.location=(x,-z,h); ob.rotation_euler=(math.pi/2,0,0)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active=ob; bpy.ops.object.convert(target='MESH'); return reg(ob,mat)
def gear(x,z,h,r,mat):
    ring('Gear',(x,z,h),r*.7,r*.22,mat,True)
    for i in range(10):
        a=i*math.tau/10; ob=box('GearTooth',(x+math.sin(a)*r,z,h+math.cos(a)*r),(.48,.14,.55),mat,.015); ob.rotation_euler[1]=a
def checker(x,z,h,w,ht):
    for i in range(4):
        for j in range(4): box('Check',(x-w/2+(i+.5)*w/4,z,h-ht/2+(j+.5)*ht/4),(w/4,.045,ht/4),'Cream' if (i+j)%2==0 else 'Dark',0)
def post(x,z,height):
    box('Timber',(x,z,height/2+.22),(1.2,1.2,height),'Wood',.10)
    for h in [.6,height-1.0,height+.1]:
        box('MetalJoint',(x,z,h),(1.5,1.5,.65),'Metal',.10)
        for dx in [-.43,.43]: cyl('Bolt',(x+dx,z+.78,h),.10,.10,'Gold','Y',6)
def lantern(x,z,h):
    box('LanternGlow',(x,z,h),(.65,.65,1),'Amber',.05)
    for hh in [h-.58,h+.58]: box('LanternCap',(x,z,hh),(.95,.95,.18),'Dark',.05)
    for dx in [-.35,.35]:
        for dz in [-.35,.35]: line('LanternCage',(x+dx,z+dz,h-.55),(x+dx,z+dz,h+.55),.055,'Gold')
    line('LanternHook',(x,z,h+.65),(x,z,h+1.35),.09,'Dark')
def planter(x,z):
    box('Planter',(x,z,1.2),(2.8,2.8,2),'Wood',.13)
    for h in [.4,2.1]: box('PlanterBand',(x,z,h),(2.95,2.95,.18),'Metal',.03)
    for i in range(7):
        a=i*math.tau/7; p=Vector((x,-z,2)); tip=p+Vector((math.sin(a)*1.6,math.cos(a)*1.6,1.4+(i%2)*.7))
        side=Vector((math.cos(a)*.5,-math.sin(a)*.5,0)); mid=(p+tip)/2+Vector((0,0,.45))
        me=bpy.data.meshes.new('Leaf'); me.from_pydata([p,mid+side,tip,mid-side,mid+Vector((0,0,.12))],[],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)])
        ob=bpy.data.objects.new('Leaf',me); col.objects.link(ob); reg(ob,'Green')
def roof(x,back,front,width,height,colors):
    for i in range(6):
        sx=x-width/2+(i+.5)*width/6
        ob=box('CanvasStripe',(sx,(back+front)/2,height+1),(width/6,front-back,.13),colors[i%len(colors)],.04); ob.rotation_euler[0]=math.atan2(2,front-back)
        box('ScallopedValance',(sx,front,height-.55),(width/6,.20,1.1),colors[i%len(colors)],.17)
    for xx in [x-width/2,x+width/2]: line('AwningBrace',(xx,back,height+2),(xx,front,height),.13,'Cream')
def timberwall(x,z,w):
    for i in range(int(w)): box('BackPlank',(x-w/2+i+.5,z,5.2),(.92,.42,10),'Wood',.04)
    for h in [1,6,10.3]: box('CrossBeam',(x,z+.3,h),(w,.5,.45),'Wood',.06)
def counter(x,z,w):
    box('CounterBody',(x,z,2.1),(w,2.4,3.8),'Wood',.08)
    for i in range(int(w)): box('CounterPlank',(x-w/2+i+.5,z+1.25,2),(.85,.15,3.4),'Wood',.04)
    box('Countertop',(x,z,4.1),(w+.5,3,.4),'Wood',.08)
    for xx in [x-w/2,x+w/2]: box('CounterCorner',(xx,z+1.3,2.1),(.45,.2,3.8),'Metal',.05)

# Square stone apron and recessed paving: flush, wide open front.
for ix in range(12):
    for iz in range(10): box('PavingTile',(-22+(ix+.5)*44/12,-20+(iz+.5)*40/10,.10),(44/12-.06,3.94,.20),'Stone',.04)
for x in [-23,23]:
    for z in range(-20,22,4): box('EdgeStone',(x,z,.16),(2,3.95,.32),'Stone',.10)
for x in range(-20,22,4): box('RearStone',(x,-21,.16),(3.95,2,.32),'Stone',.10)
box('RugBorder',(0,6,.23),(13,10,.04),'Cream',.02); box('RedRug',(0,6,.26),(12.4,9.4,.025),'Red',.02)
# Horizontal gear motif on courtyard rug.
ring('RugGear',(0,6,.29),2,.6,'Cream')
for i in range(10):
    a=i*math.tau/10; ob=box('RugTooth',(math.sin(a)*2.6,6+math.cos(a)*2.6,.29),(.8,1,.02),'Cream',0); ob.rotation_euler[2]=a
for x in [-21,21]:
    post(x,18,3); planter(x,11); lantern(x,18,4.3)
    for z in [14,19]: box('PerimeterBeam',(x,z,1.4),(1,4,1.1),'Wood',.05)

zone='Workshop'
for x in [-10,10]: post(x,-19,15.5); post(x,-10,12.5)
timberwall(0,-19.5,20); roof(0,-20,-9,22,13.1,['Red','Cream','Red'])
counter(0,-11,18)
box('CounterBanner',(0,-9.43,2.6),(4.8,.08,4.3),'Red',.05); gear(0,-9.35,2.6,1,'Cream')
box('MarketSign',(0,-8.9,15),(14,.45,3.5),'Dark',.14)
box('SignTop',(0,-8.65,16.75),(14.5,.12,.16),'Red'); box('SignBottom',(0,-8.65,13.25),(14.5,.12,.16),'Red')
text('MARKET',0,-8.55,14.1,2.1,'Cream')
for x in [-9,9]: checker(x,-8.85,14.8,2.5,2.5)
box('ToolBoard',(0,-19.0,7),(8,.25,5),'Gold',.10)
for x in [-3,-1.5,0,1.5,3]:
    line('Wrench',(x,-18.7,5.5),(x,-18.7,8),.13,'Metal'); ring('WrenchHead',(x,-18.7,8.1),.36,.12,'Metal',True)
for x in [-7.8,7.8]: lantern(x,-9.5,10.5)
for x in [-6.5,-4.8]:
    box('Toolbox',(x,-17.8,5),(1.6,1.1,1),'Cyan' if x==-6.5 else 'Red',.12); box('ToolboxLatch',(x,-17.16,5),(.3,.08,.28),'Gold')
for h in [1,2.2,3.4]: ring('StackedTyre',(-8,-7.5,h),1.2,.35,'Dark')
box('FuelPump',(7,-17.1,3.2),(2.4,1.6,5.5),'Amber',.12); box('PumpScreen',(7,-16.25,4.7),(1.8,.06,1),'Green'); text('FUEL',7,-16.15,4.4,.45,'Cream')
for x in [6.5,7.5]: line('FuelHose',(x,-16.2,3.5),(x,-15.8,1.2),.10,'Dark')
box('DisplayStand',(5,-11,4.65),(3,2,.6),'Metal',.10)
for x in [4.2,5.1,6]: cyl('EngineIntake',(x,-10.0,5.2),.33,.65,'Metal','Y')

zone='Aura'
for x in [-22,-12]:
    for z in [-16,-2]: post(x,z,11)
timberwall(-17,-16.5,10); roof(-17,-17,-1,12,10.4,['Purple','Dark','Cyan','Dark'])
box('AuraSign',(-17,-1,13.1),(12,.5,2.9),'Dark',.12); text('AURA',-17,-.68,12.1,2.3,'Cyan')
for h in [11.65,14.55]: box('AuraSignGlow',(-17,-.7,h),(12,.10,.10),'Purple',.025)
counter(-17,-3,9)
for i,mat in enumerate(['Cyan','Amber','Purple','Green']):
    x=-20.2+(i%2)*3; z=-8+(i//2)*4
    box('AuraPlinth',(x,z,3.8),(2.4,2.4,.5),'Metal',.1); cyl('AuraVial',(x,z,4.6),.4,1.2,mat); cyl('VialCap',(x,z,5.3),.47,.18,'Metal'); ring('AuraHalo',(x,z,6.2),1,.08,mat)
for i,mat in enumerate(['Cyan','Purple','Green']):
    cyl('DisplayCanister',(-20+i*2.8,-2.8,5.1),.45,1.4,mat); cyl('Cap',(-20+i*2.8,-2.8,5.9),.52,.2,'Metal')
lantern(-22,-.8,7.5)
box('AuraCrate',(-19,5,1.5),(5,3,2.6),'Wood',.13)
for x,mat in [(-20.5,'Cyan'),(-19,'Amber'),(-17.5,'Green')]:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.7,location=(x,-5,3.3)); reg(bpy.context.object,mat)
checker(-22,18.6,1.5,1.2,1.2)

zone='Parts'
for x in [12,22]:
    for z in [-16,-2]: post(x,z,11)
timberwall(17,-16.5,10); roof(17,-17,-1,12,10.4,['Cyan','Dark','Amber','Dark'])
box('FuelSign',(17,-1,13.1),(12,.5,2.9),'Dark',.12); text('FUEL TYPES',17,-.68,12.35,1.3,'Amber')
for h in [11.65,14.55]: box('FuelSignGlow',(17,-.7,h),(12,.10,.10),'Amber',.02)
box('PartsSign',(17,-.7,9.6),(11.5,.25,1.6),'Dark',.10); text('TRAILS & PARTS',17,-.51,9.1,.85,'Cream')
counter(17,-3,9)
for x in [14,17,20]:
    ring('Wheel',(x,-15.85,7.5),1,.25,'Dark',True); ring('WheelRim',(x,-15.5,7.5),.67,.10,'Metal',True)
    for i in range(5):
        a=i*math.tau/5; line('Spoke',(x,-15.48,7.5),(x+math.sin(a)*.67,-15.48,7.5+math.cos(a)*.67),.055,'Metal')
for i,mat in enumerate(['Cyan','Purple','Green']):
    z=-15.8; h=4.5+i*.7
    line('TrailDisplay',(13,z,h),(20,z,h+.25),.07,mat)
    for x in [15,17,19]: line('TrailSpark',(x,z,h),(x+.8,z,h+.5),.06,mat)
for x in [14,16,18,20]: cyl('Exhaust',(x,-3,4.6),.35,1.8,'Metal','Y')
for i,mat in enumerate(['Amber','Red','Cyan','Green']):
    x=13.6+i*2.3; cyl('FuelDrum',(x,2.5,1.9),.9,3.2,mat)
    for h in [.5,3.3]: ring('DrumHoop',(x,2.5,h),.92,.07,'Metal')
    cyl('DrumLid',(x,2.5,3.55),.88,.1,'Metal')
lantern(22,-.8,7.5)
box('PartsDisplay',(19,6.5,1.5),(5,3,2.6),'Wood',.12)
box('EngineBlock',(19,6.5,3.4),(3,1.8,1.2),'Metal',.12); box('EngineHead',(19,6.5,4.1),(3.2,2,.25),'Red',.08)
for x in [18,19,20]: cyl('Intake',(x,7.55,3.5),.3,.45,'Dark','Y')

# Join only within vendor and material: each vendor stays independently reusable.
for group,obs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs: ob.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]; bpy.ops.object.join(); ob=bpy.context.object; ob.name=group
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    if group == 'Courtyard_Cream':
        for v in ob.data.vertices:
            if v.co.z < .20 or v.co.z > .251: v.co.z=.275+(v.co.z-.29)*.015
    ob.data.calc_loop_triangles(); print(group,len(ob.data.loop_triangles))
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/SpawnMarketplace.blend')
result={'collection':NAME,'meshes':len(col.objects),'footprint':[48,44],'front':'Roblox +Z'}
