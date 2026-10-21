"""Original low-poly car authoring. Execute through Blender MCP; one wave of 20 at a time.

One primitive recipe feeds Blender sources/GLB/previews and Roblox Part model exports.
Roblox x/y/z -> Blender x/-z/y; no external meshes or textures are used.
"""
import bpy
import math
import re
import json
import colorsys
import zlib
import xml.etree.ElementTree as ET
from pathlib import Path
from mathutils import Vector

ROOT = Path('/Users/alexnguyen7369/Documents/RobloxGames')
OUT = ROOT / 'assets/studio/ExpansionCarModels'
OUT.mkdir(parents=True, exist_ok=True)
FAMILIES = ['city_utility', 'offroad_rally', 'track_hyper', 'futuristic_hover', 'fantasy_novelty']


def roster():
    rows = []
    for path in (ROOT / 'src/shared/Cars').glob('*.luau'):
        source = path.read_text()
        if 'Family =' not in source:
            continue
        row = {'Id': path.stem}
        for key in ['Name', 'Family', 'Rarity']:
            row[key] = re.search(r'\b' + key + r'\s*=\s*"([^"]+)"', source)[1]
        for key in ['Order', 'Chance', 'SpeedMulti']:
            row[key] = float(re.search(r'\b' + key + r'\s*=\s*([\d.]+)', source)[1])
        rows.append(row)
    return sorted(rows, key=lambda row: row['Order'])


def recipe(row, index):
    parts = []
    family = row['Family']
    n = index % 20
    hue = ((index * 0.61803398875) + 0.03) % 1
    paint = tuple(round(c, 4) for c in colorsys.hsv_to_rgb(hue, .66, .92))
    accent = tuple(round(c, 4) for c in colorsys.hsv_to_rgb((hue+.13) % 1, .4, 1))
    rubber, glass, metal = (.09,.10,.15), (.18,.30,.39), (.72,.79,.85)

    def add(name, pos, size, color=paint, shape='Block', material='SmoothPlastic', rotation=(0,0,0)):
        parts.append(dict(name=name, pos=pos, size=size, color=color, shape=shape, material=material, rotation=rotation))

    # Sharp-edged shell (owner 2026-10-20): a low full-length block, a narrower upper deck with chamfered
    # shoulder wedges, a wedge nose and an id-picked tail, so every silhouette has hard creases and its own shape.
    seed = zlib.crc32(row['Id'].encode())
    pick = lambda shift, count: (seed >> shift) % count
    width = 2.3 + pick(0, 5) * .1
    length = 4.6 + pick(3, 5) * .1
    height = .64
    utility = family in ['city_utility', 'offroad_rally']
    nose_len = length * ((.12 + pick(6, 3) * .03) if utility else (.2 + pick(6, 4) * .03))
    tail_style = ['kamm', 'duck', 'fastback'][pick(9, 3)] if utility else ['fastback', 'duck', 'fastback', 'kamm'][pick(9, 4)]
    tail_len = length * (.14 + pick(12, 3) * .03)
    mid = length - nose_len - tail_len
    zc = (nose_len - tail_len) / 2
    pattern = pick(15, 3)
    deck = rubber if pattern == 0 else paint
    add('Sill', (0,.55,0), (width,.24,length-.2), rubber)
    add('Body', (0,.67,0), (width,.3,length))
    add('BodyUpper', (0,.99,zc), (width-.4,.34,mid), deck)
    add('ShoulderL', (-(width/2-.1),.99,zc), (mid,.34,.2), deck, 'Wedge', rotation=(0,90,0))
    add('ShoulderR', (width/2-.1,.99,zc), (mid,.34,.2), deck, 'Wedge', rotation=(0,-90,0))
    add('Nose', (0,.99,-length/2+nose_len/2), (width,.34,nose_len), paint, 'Wedge')
    if tail_style == 'fastback':
        add('Tail', (0,.99,length/2-tail_len/2), (width,.34,tail_len), deck, 'Wedge', rotation=(0,180,0))
    else:
        add('Tail', (0,.99,length/2-tail_len/2), (width,.34,tail_len), deck)
        lip = .14 if tail_style == 'kamm' else .26
        add('Ducktail', (0,1.16+lip/2,length/2-.2), (width-.3,lip,.4), accent, 'Wedge')
    if pattern == 1:
        add('RaceStripe', (0,1.165,zc), (.36,.02,mid), accent, material='Neon')
    add('Hood', (0,1.175,zc-mid*.3), (width-.8,.03,mid*.3), accent)
    cab_z = zc - .3 + pick(18, 4) * .18
    cab_h = .5 + pick(20, 2) * .08 if family in ['track_hyper','futuristic_hover'] else .78+pick(20, 3)*.1
    cab_len = min(mid - .3, 1.4 + pick(22, 4) * .2)
    cab_w = width * .62
    add('Cabin', (0,1.16+cab_h/2,cab_z), (cab_w,cab_h,cab_len), glass)
    add('CabinSideL', (-(cab_w/2+.11),1.16+cab_h/2,cab_z), (cab_len,cab_h,.22), glass, 'Wedge', rotation=(0,90,0))
    add('CabinSideR', (cab_w/2+.11,1.16+cab_h/2,cab_z), (cab_len,cab_h,.22), glass, 'Wedge', rotation=(0,-90,0))
    add('Roof', (0,1.22+cab_h,cab_z+.05), (cab_w,.12,cab_len*.94))
    for side in [-1,1]:
        # Slit lamps: thin, wide and hard-edged on the low block's face.
        add('Headlamp'+str(side), (side*width*.33,.76,-length/2-.025), (.55,.1,.08), (1,.93,.62), material='Neon')
        add('TailLamp'+str(side), (side*width*.33,.76,length/2+.025), (.6,.09,.08), (1,.15,.19), material='Neon')
        add('Mirror'+str(side), (side*(cab_w/2+.3),1.32,cab_z-cab_len/2+.1), (.25,.12,.22), metal, 'Wedge')
        for front in [True, False]:
            z = (-1 if front else 1) * (length*.32)
            name = 'Wheel_'+('F' if front else 'R')+('L' if side < 0 else 'R')
            if family != 'futuristic_hover':
                radius = .58 if family == 'offroad_rally' else .48
                add(name, (side*(width/2+.12),radius,z), (.38,radius*2,radius*2), rubber, 'Cylinder')
                add(name+'Hub', (side*(width/2+.32),radius,z), (.035,radius,radius), accent, 'Cylinder', 'Metal')
            else:
                add('HoverPod'+name, (side*(width/2+.10),.45,z), (.36,.50,.85), rubber, 'Wedge', rotation=(0,0 if front else 180,0))
                add('IonPad'+name, (side*(width/2+.10),.18,z), (.40,.12,.70), accent, material='Neon')
    add('Grille', (0,.66,-length/2-.05), (.75,.18,.08), rubber)
    add('Bumper', (0,.5,-length/2-.13), (width*.96,.12,.24), metal, 'Wedge', rotation=(0,180,0))
    geo = dict(zc=zc, mid=mid, cab_w=cab_w)

    if family == 'city_utility':
        variant=n%5
        if variant == 0:
            add('CourierBox', (0,1.85,1.5), (1.65,1.2,1.25), accent)
            add('ParcelStrap', (0,2.47,1.5), (.15,.06,1.27), rubber)
        elif variant == 1:
            add('TaxiLight', (0,2.25,cab_z), (.9,.32,.38), (1,.82,.18), material='Neon')
        elif variant == 2:
            add('VanCargo', (0,1.8,1.1), (width*.93,1.35,2), accent)
            for side in [-1,1]: add('VanWindow'+str(side),(side*width*.47,2,1.1),(.03,.5,1.35),glass)
        elif variant == 3:
            add('PickupBed', (0,1.18,1.55), (width*.90,.18,1.35), rubber)
            for side in [-1,1]: add('BedRail'+str(side),(side*width*.43,1.5,1.55),(.12,.45,1.4),accent)
        else:
            add('RoofRack', (0,2.45,.3), (2.1,.12,2), metal)
            for z in [-.5,.3,1.1]: add('RackBar'+str(z),(0,2.55,z),(2.1,.12,.12),accent)
    elif family == 'offroad_rally':
        for side in [-1,1]:
            add('RollPillar'+str(side),(side*.9,1.95,.85),(.13,1.25,.13),metal)
            add('Fender'+str(side),(side*(width/2+.12),1.18,-length*.32),(.52,.15,1.2),accent)
        add('RollBar',(0,2.55,.85),(1.95,.14,.14),metal)
        add('BashBar',(0,.75,-length/2-.22),(width+.25,.20,.18),rubber)
        for j in range(2+n%4):
            add('RallyLamp'+str(j),(-.8+j*(1.6/(1+n%4)),2.42,-.25),(.24,.16,.08),(1,.92,.7),'Block','Neon')
        if n%3==0: add('RoofTent',(0,2.7,.7),(1.65,.28,1.4),accent)
        elif n%3==1: add('SpareTyre',(0,1.15,length/2+.18),(1.05,1.05,.30),rubber,'Cylinder',rotation=(0,90,0))
        else: add('Snorkel',(width*.44,2.1,-.7),(.18,1.6,.18),rubber)
    elif family == 'track_hyper':
        for side in [-1,1]:
            add('WingPost'+str(side),(side*.8,1.25,length*.38),(.12,.65,.15),rubber)
            add('AirIntake'+str(side),(side*width*.47,1,.65),(.15,.35,.8),rubber)
            add('Stripe'+str(side),(side*.32,1.28,-1.6),(.16,.04,1),accent,material='Neon')
        add('RearWing',(0,1.6+(n%3)*.12,length*.39),(width+.45,.12,.45),accent)
        add('Splitter',(0,.40,-length/2-.16),(width+.2,.10,.40),rubber)
        if n%2: add('DorsalFin',(0,1.7,.75),(.12,.75,1.2),accent,'Wedge')
    elif family == 'futuristic_hover':
        add('EnergyCore',(0,1.8,.9),(.60,.60,.60),accent,'Ball','Neon')
        for side in [-1,1]:
            add('FloatFin'+str(side),(side*(width/2+.14),1,.1),(.20,.15,2.6),accent,material='Neon')
            add('Thruster'+str(side),(side*.8,.85,length/2),(.65,.65,.55),metal,'Cylinder',rotation=(0,90,0))
            add('ThrusterGlow'+str(side),(side*.8,.85,length/2+.30),(.45,.45,.08),accent,material='Neon')
        if n%3==0: add('RadarMast',(0,2.1,0),(.10,.7,.10),metal)
        elif n%3==1: add('SolarSail',(0,2.2,.9),(2.3,.1,1.1),accent,material='Neon')
        else: add('BridgeFin',(0,2.1,-.5),(.12,1,1),accent,'Wedge')
    else:
        # Each fantasy identity receives a different recognizable sculptural motif.
        motif = n
        if motif in [0,4,9,12]:
            for j in range(3): add('CloudCap'+str(j),((j-1)*.58,2.15+(j%2)*.3,.2),(.95,.8,.95),accent,'Ball')
            if motif==9: add('Cherry',(0,2.9,.2),(.35,.35,.35),(1,.15,.25),'Ball')
        elif motif in [1,6,17,18]:
            for side in [-1,1]:
                add('Wing_'+('L' if side<0 else 'R'),(side*1.45,1.7,0),(.65,.14,1.75),accent,'Wedge')
                add('Claw'+str(side),(side*1.4,1.35,-2),(.45,.65,.65),paint,'Ball')
        elif motif in [2,7,14]:
            for j in range(3): add('Crystal'+str(j),((j-1)*.65,2.2,.5),(.45,1.5-j*.2,.55),accent,'Wedge','Neon')
        elif motif in [3,5]:
            add('Fruit',(0,2.0,.5),(1.65,1.5,1.65),accent,'Ball')
            add('Stem',(0,2.9,.5),(.22,.45,.22),(.2,.65,.25))
        elif motif in [8,11,16]:
            add('HatBrim',(0,2.25,0),(2,.12,1.7),accent)
            add('HatPeak',(0,2.7,0),(.9,1.1,.9),paint,'Wedge')
        elif motif==10:
            for side in [-1,1]: add('Wing_'+('L' if side<0 else 'R'),(side*1.4,2,0),(.7,.18,2.1),accent,'Wedge','Neon')
            add('PhoenixCrest',(0,2.5,-1),(.15,1.1,.9),(1,.5,.08),'Wedge','Neon')
        elif motif==13:
            for side in [-1,1]:
                add('CastleTower'+str(side),(side*.8,2.2,.5),(.65,1.5,.65),metal)
                add('Battlement'+str(side),(side*.8,3,.5),(.85,.2,.85),accent)
        elif motif==15:
            add('TreasureChest',(0,2,.7),(1.8,.9,1.2),(.6,.3,.1))
            add('GoldLatch',(0,2,-.02),(.3,.45,.15),(1,.8,.12),'Block','Metal')
        else:
            add('Drum',(0,2,.4),(1.2,1.5,1.5),accent,'Cylinder',rotation=(0,0,90))
            add('DrumStick',(.35,2.85,0),(.12,.12,1.7),metal,rotation=(0,35,0))
    detail(row, n, family, add, paint, accent, rubber, glass, metal, width, length, height, cab_z, cab_h, cab_len, geo)
    return parts


def detail(row, n, family, add, paint, accent, rubber, glass, metal, width, length, height, cab_z, cab_h, cab_len, geo):
    """Per-car detail pass (owner 2026-10-20): shared trim plus id-seeded extras, so no two cars match."""
    seed = zlib.crc32(row['Id'].encode())
    pick = lambda shift, count: (seed >> shift) % count
    trim = tuple(round(c, 4) for c in colorsys.hsv_to_rgb(((seed % 997) / 997), .55, .45 + pick(3, 4) * .15))
    plate, dark = (.93, .93, .88), (.05, .05, .07)
    top = 1.16 + cab_h
    front, rear = cab_z - cab_len / 2, cab_z + cab_len / 2
    # Glass: slanted windshield and rear window close the cabin box (Roblox wedge rises toward +Z).
    glass_w = geo['cab_w'] + .44
    add('Windshield', (0, top - cab_h / 2, front - .28), (glass_w, cab_h, .56), glass, 'Wedge')
    add('RearWindow', (0, top - cab_h / 2, rear + .2), (glass_w, cab_h, .4), glass, 'Wedge', rotation=(0, 180, 0))
    for side in [-1, 1]:
        s = str(side)
        add('APillar' + s, (side * (geo['cab_w'] / 2 + .2), top - cab_h / 2, front - .05), (.08, cab_h, .1), paint)
        add('DoorSeamF' + s, (side * (width / 2 + .01), .67, cab_z - .35), (.02, .28, .04), dark)
        add('DoorSeamR' + s, (side * (width / 2 + .01), .67, cab_z + .55), (.02, .28, .04), dark)
        add('DoorHandle' + s, (side * (width / 2 + .03), .74, cab_z + .3), (.04, .05, .22), metal, material='Metal')
        add('SideSkirt' + s, (side * (width / 2 + .02), .52, 0), (.06, .12, length * .42), trim)
        add('Stripe2Tone' + s, (side * (width / 2 + .015), .8, 0), (.03, .04, length * .96), trim)
        if family != 'futuristic_hover':
            radius = .58 if family == 'offroad_rally' else .48
            for z in [-length * .32, length * .32]:
                add('Arch' + s + str(z > 0), (side * (width / 2 + .06), radius * 2 + .05, z), (.26, .1, radius * 2.3), trim)
                for k in range(2 + pick(5, 2)):
                    add('Spoke' + s + str(z > 0) + str(k), (side * (width / 2 + .335), radius, z),
                        (.03, radius * 1.5, .09), metal, material='Metal', rotation=(k * 180 / (2 + pick(5, 2)), 0, 0))
    add('PlateF', (0, .6, -length / 2 - .06), (.6, .14, .03), plate)
    add('PlateR', (0, .62, length / 2 + .03), (.6, .14, .03), plate)
    for k in range(1 + pick(7, 2)):
        x = (-.55 + k * 1.1) if pick(7, 2) else .55
        add('Exhaust' + str(k), (x, .5, length / 2 + .08), (.22, .16, .16), metal, 'Cylinder', 'Metal', (0, 90, 0))
    hood = pick(9, 4)
    hood_z = geo['zc'] - geo['mid'] * .3
    if hood == 0:
        add('HoodScoop', (0, 1.26, hood_z), (.6, .2, .55), dark, 'Wedge')
    elif hood == 1:
        for k in range(3):
            add('HoodVent' + str(k), (-.4 + k * .4, 1.175, hood_z), (.22, .03, .5), dark)
    elif hood == 2:
        add('HoodStripe', (.5, 1.18, hood_z), (.12, .02, geo['mid'] * .5), trim)
    else:
        add('Emblem', (0, .82, -length / 2 - .04), (.22, .14, .06), (1, .82, .2), 'Wedge', 'Metal')
    # Family pool: two or three id-picked extras.
    pools = {
        'city_utility': ['RoofSign', 'Antenna', 'MudFlaps', 'Bullbar', 'Ladder', 'Beacon'],
        'offroad_rally': ['Winch', 'Jerrycan', 'LightBar', 'MudFlaps', 'Antenna', 'Skidplate'],
        'track_hyper': ['Canards', 'Diffuser', 'RoofScoop', 'Number', 'SideGills', 'TowHook'],
        'futuristic_hover': ['HaloRing', 'Antenna', 'PulseStrip', 'Canards', 'Diffuser', 'Beacon'],
        'fantasy_novelty': ['Star', 'Horns', 'Lantern', 'Bow', 'Gem', 'Tail'],
    }
    pool = pools[family]
    chosen = sorted({pool[(seed >> (11 + 3 * k)) % len(pool)] for k in range(3)})
    for extra in chosen:
        if extra == 'RoofSign':
            add('RoofSign', (0, top + .3, cab_z), (1.0, .35, .12), accent, material='Neon')
        elif extra == 'Antenna':
            add('Antenna', (width * .3, top + .45, rear - .1), (.05, .9, .05), metal)
        elif extra == 'MudFlaps':
            for side in [-1, 1]:
                add('MudFlap' + str(side), (side * width * .38, .4, length * .32 + .62), (.4, .4, .04), dark)
        elif extra == 'Bullbar':
            add('Bullbar', (0, .78, -length / 2 - .25), (width * .7, .4, .08), metal, material='Metal')
        elif extra == 'Ladder':
            for side in [-1, 1]:
                add('LadderRail' + str(side), (side * .35, top + .12, cab_z + .3), (.06, .06, 1.6), metal)
        elif extra == 'Beacon':
            add('Beacon', (0, top + .15, cab_z), (.3, .3, .3), (1, .45, .1), 'Wedge', 'Neon')
        elif extra == 'Winch':
            add('Winch', (0, .78, -length / 2 - .3), (.6, .25, .2), dark, 'Cylinder')
        elif extra == 'Jerrycan':
            add('Jerrycan', (width * .3, 1.35, length / 2 - .35), (.35, .45, .25), (.2, .45, .2))
        elif extra == 'LightBar':
            add('LightBar', (0, top + .12, front + .2), (width * .7, .14, .14), (1, .95, .75), material='Neon')
        elif extra == 'Skidplate':
            add('Skidplate', (0, .4, -length / 2 + .2), (width * .7, .06, .6), metal, material='Metal')
        elif extra == 'Canards':
            for side in [-1, 1]:
                add('Canard' + str(side), (side * width * .44, .7, -length / 2 + .05), (.35, .04, .2), dark)
        elif extra == 'Diffuser':
            for k in range(4):
                add('DiffuserFin' + str(k), (-.6 + k * .4, .42, length / 2 - .1), (.04, .18, .4), dark)
        elif extra == 'RoofScoop':
            add('RoofScoop', (0, top + .15, cab_z + .2), (.45, .3, .6), dark, 'Wedge', rotation=(0, 180, 0))
        elif extra == 'Number':
            for side in [-1, 1]:
                add('NumberDisc' + str(side), (side * (width / 2 + .02), .95, -.2), (.03, .45, .45), plate, 'Cylinder')
        elif extra == 'SideGills':
            for side in [-1, 1]:
                for k in range(3):
                    add('Gill' + str(side) + str(k), (side * (width / 2 + .015), .95, .9 + k * .18), (.03, .3, .06), dark)
        elif extra == 'TowHook':
            add('TowHook', (width * .25, .55, -length / 2 - .2), (.12, .12, .2), (1, .2, .2))
        elif extra == 'HaloRing':
            add('HaloRing', (0, top + .4, cab_z), (.06, 1.2, 1.2), accent, 'Cylinder', 'Neon', (0, 0, 90))
        elif extra == 'PulseStrip':
            add('PulseStrip', (0, top + .08, cab_z), (.12, .04, cab_len * .9), accent, material='Neon')
        elif extra == 'Star':
            add('Star', (0, top + .5, cab_z), (.15, .6, .6), (1, .85, .2), 'Block', 'Neon', (45, 0, 0))
        elif extra == 'Horns':
            for side in [-1, 1]:
                add('Horn' + str(side), (side * .5, top + .3, front + .2), (.15, .6, .15), (.95, .9, .8), 'Wedge')
        elif extra == 'Lantern':
            add('Lantern', (-width * .3, top + .25, rear - .2), (.25, .35, .25), (1, .7, .3), material='Neon')
        elif extra == 'Bow':
            for side in [-1, 1]:
                add('BowLoop' + str(side), (side * .25, top + .2, rear), (.35, .3, .15), (1, .3, .55), 'Ball')
        elif extra == 'Gem':
            add('Gem', (0, 1.25, geo['zc']), (.3, .3, .3), (.4, .9, 1), 'Block', 'Neon', (45, 0, 45))
        elif extra == 'Tail':
            add('Tail', (0, 1.3, length / 2 + .1), (.2, .2, .5), accent, 'Wedge', rotation=(0, 180, 0))


def singularity_recipe():
    """Singularity gamepass hypercar (owner 2026-10-20): a knife-edge wedge supercar with a black-hole reactor."""
    parts = []

    def add(name, pos, size, color, shape='Block', material='SmoothPlastic', rotation=(0, 0, 0)):
        parts.append(dict(name=name, pos=pos, size=size, color=color, shape=shape, material=material, rotation=rotation))

    black, carbon, glass = (.03, .03, .05), (.09, .09, .11), (.08, .1, .18)
    ember, rim, chrome = (1, .5, .1), (.72, .88, 1), (.55, .58, .64)
    # Floor, low body and a knife-edge nose.
    add('Floor', (0, .42, .1), (3.1, .16, 5.8), carbon)
    add('Body', (0, .64, .15), (3.3, .28, 5.3), black)
    add('NoseTip', (0, .64, -2.75), (3.1, .28, .5), black, 'Wedge')
    add('Nose', (0, .93, -1.95), (3.1, .3, 1.5), black, 'Wedge')
    add('Splitter', (0, .46, -2.95), (3.3, .08, .5), carbon, 'Wedge', rotation=(0, 180, 0))
    add('SplitterLip', (0, .42, -3.17), (3.1, .03, .05), ember, material='Neon')
    # Mid deck with hard chamfered shoulders.
    add('BodyUpper', (0, .93, .35), (2.3, .3, 2.1), black)
    for side, rot in [(-1, 90), (1, -90)]:
        s_ = 'L' if side < 0 else 'R'
        add('Shoulder' + s_, (side * 1.4, .93, .35), (2.1, .3, .5), black, 'Wedge', rotation=(0, rot, 0))
        # Rear haunches: tall angular fenders over the rear wheels, ramped at the front.
        add('Haunch' + s_, (side * 1.38, 1.02, 2.05), (.55, .48, 1.3), black)
        add('HaunchRamp' + s_, (side * 1.38, 1.02, 1.05), (.55, .48, .7), black, 'Wedge', rotation=(0, 180, 0))
        # Side intakes: dark scoops with an ember throat.
        add('Intake' + s_, (side * 1.66, .8, .9), (.04, .26, 1.1), carbon)
        add('IntakeGlow' + s_, (side * 1.67, .74, .95), (.03, .05, .9), ember, material='Neon')
        # Slit headlights angled back like a supercar's.
        add('Headlamp' + s_, (side * 1.0, .84, -2.35), (.75, .05, .1), rim, material='Neon', rotation=(0, side * -14, 0))
        add('DRL' + s_, (side * 1.38, .74, -2.55), (.06, .16, .4), rim, material='Neon')
        add('Mirror' + s_, (side * 1.02, 1.36, -.85), (.32, .1, .2), black, 'Wedge')
        # Wheels: black with an ember ring (the accretion rims).
        for front in [True, False]:
            z = -1.95 if front else 1.95
            r = .5 if front else .56
            name = 'Wheel_' + ('F' if front else 'R') + s_
            add(name, (side * 1.5, r, z), (.46, r * 2, r * 2), black, 'Cylinder')
            add(name + 'Rim', (side * 1.74, r, z), (.03, r * 1.5, r * 1.5), ember, 'Cylinder', 'Neon')
            add(name + 'Hub', (side * 1.76, r, z), (.03, r * .6, r * .6), chrome, 'Cylinder', 'Metal')
            add('Arch' + name, (side * 1.5, r * 2 + .08, z), (.58, .12, r * 2.3), carbon)
    # Low canopy: raked windshield, tapered sides, short rear glass.
    add('Cabin', (0, 1.28, -.05), (1.3, .4, 1.3), glass)
    add('Windshield', (0, 1.28, -1.25), (1.9, .4, 1.1), glass, 'Wedge')
    add('RearWindow', (0, 1.28, .85), (1.9, .4, .5), glass, 'Wedge', rotation=(0, 180, 0))
    add('CabinSideL', (-.8, 1.28, -.05), (1.3, .4, .3), glass, 'Wedge', rotation=(0, 90, 0))
    add('CabinSideR', (.8, 1.28, -.05), (1.3, .4, .3), glass, 'Wedge', rotation=(0, -90, 0))
    add('Roof', (0, 1.52, -.05), (1.3, .08, 1.2), black)
    add('RoofSpine', (0, 1.57, .2), (.14, .04, 1.6), ember, material='Neon')
    # Engine deck: the black hole sits in a reactor bay under glass, ringed by its accretion disc.
    add('EngineDeck', (0, 1.0, 2.25), (2.2, .44, 1.7), black, 'Wedge', rotation=(0, 180, 0))
    add('Core', (0, 1.5, 1.75), (.55, .55, .55), (0, 0, 0), 'Ball')
    add('Disc', (0, 1.5, 1.75), (.04, 1.1, 1.1), ember, 'Cylinder', 'Neon', (0, 0, 14))
    add('Halo', (0, 1.5, 1.75), (.03, .8, .8), rim, 'Cylinder', 'Neon', (0, 0, -24))
    for k in range(5):
        add('EngineSlat' + str(k), (-.6 + k * .3, 1.25, 2.6), (.06, .03, .7), carbon)
    # Swan-neck wing with sharp endplates, diffuser and a full-width light blade.
    for side in [-1, 1]:
        add('WingPost' + str(side), (side * .7, 1.5, 2.85), (.08, .55, .2), carbon)
        add('Endplate' + str(side), (side * 1.77, 1.72, 2.85), (.05, .4, .7), black, 'Wedge', rotation=(0, 180, 0))
    add('Wing', (0, 1.8, 2.85), (3.55, .07, .6), black)
    add('WingEdge', (0, 1.84, 2.6), (3.45, .02, .06), ember, material='Neon')
    add('TailBlade', (0, .9, 2.92), (3.0, .05, .06), ember, material='Neon')
    for k in range(6):
        add('DiffuserFin' + str(k), (-1.0 + k * .4, .45, 2.75), (.04, .2, .7), carbon)
    add('Exhaust', (0, .62, 2.85), (.5, .2, .2), chrome, 'Cylinder', 'Metal', (0, 90, 0))
    return parts


def build_singularity():
    row = {'Id': 'singularity', 'Name': 'Singularity', 'Family': 'gamepass_hyper'}
    previous = bpy.context.window.scene
    try:
        report = author(row, 0, singularity_recipe())
    finally:
        bpy.context.window.scene = previous
    print(json.dumps(report))


def export_xml(row, parts):
    doc = ET.Element('roblox', version='4')
    model = ET.SubElement(doc,'Item', {'class':'Model','referent':'RBXMODEL'})
    props=ET.SubElement(model,'Properties')
    ET.SubElement(props,'string',name='Name').text=row['Id']
    def vec(parent, tag, name, values):
        e=ET.SubElement(parent,tag,name=name)
        for axis,v in zip('XYZ',values): ET.SubElement(e,axis).text=str(v)
    for i,p in enumerate(parts):
        item=ET.SubElement(model,'Item',{'class':'WedgePart' if p['shape']=='Wedge' else 'Part','referent':f'RBX{i}'})
        pr=ET.SubElement(item,'Properties');ET.SubElement(pr,'string',name='Name').text=p['name']
        for name,value in [('Anchored',True),('CanCollide',False),('CanTouch',False),('CanQuery',False),('Massless',True)]:
            ET.SubElement(pr,'bool',name=name).text=str(value).lower()
        vec(pr,'Vector3','size',p['size'])
        c=ET.SubElement(pr,'Color3',name='Color')
        for channel,v in zip('RGB',p['color']): ET.SubElement(c,channel).text=str(v)
        cf=ET.SubElement(pr,'CoordinateFrame',name='CFrame')
        for axis,v in zip('XYZ',p['pos']): ET.SubElement(cf,axis).text=str(v)
        from mathutils import Euler
        matrix=Euler(tuple(math.radians(v) for v in p['rotation']),'XYZ').to_matrix()
        for a in range(3):
            for b in range(3): ET.SubElement(cf,f'R{a}{b}').text=str(matrix[a][b])
        ET.SubElement(pr,'token',name='Material').text=str({'SmoothPlastic':272,'Neon':288,'Metal':1088}[p['material']])
        if p['shape']!='Wedge': ET.SubElement(pr,'token',name='shape').text=str({'Ball':0,'Block':1,'Cylinder':2}[p['shape']])
    # Explicit base-centred model pivot, Roblox Y up.
    pivot=ET.SubElement(props,'OptionalCoordinateFrame',name='WorldPivotData')
    cf=ET.SubElement(pivot,'CFrame')
    for axis in 'XYZ': ET.SubElement(cf,axis).text='0'
    for a in range(3):
        for b in range(3): ET.SubElement(cf,f'R{a}{b}').text=str(int(a==b))
    ET.indent(doc)
    ET.ElementTree(doc).write(OUT/(row['Id']+'.rbxmx'),encoding='utf-8',xml_declaration=True)


def author(row, index, parts=None):
    from mathutils import Euler, Matrix
    parts=parts or recipe(row,index)
    path=ROOT/'drafts/cars'/row['Id'];path.mkdir(parents=True,exist_ok=True)
    scene=bpy.data.scenes.new('Expansion_'+row['Id'])
    bpy.context.window.scene=scene
    mats={}
    conversion=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
    for p in parts:
        shape=p['shape']
        if shape=='Cylinder': bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.5,depth=1)
        elif shape=='Ball': bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.5)
        elif shape=='Wedge':
            mesh=bpy.data.meshes.new(p['name']);mesh.from_pydata([(-.5,-.5,-.5),(.5,-.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(-.5,.5,.5),(.5,.5,.5)],[],[(0,1,3,2),(2,3,5,4),(0,4,5,1),(0,2,4),(1,5,3)])
            ob=bpy.data.objects.new(p['name'],mesh);scene.collection.objects.link(ob);bpy.context.view_layer.objects.active=ob
        else: bpy.ops.mesh.primitive_cube_add(size=1)
        ob=bpy.context.object;ob.name=p['name']
        # Construct in Roblox coordinates, then rotate the whole object to Blender axes.
        matrix=Euler(tuple(math.radians(v) for v in p['rotation']),'XYZ').to_matrix()
        if shape=='Cylinder':
            # Blender cylinders use local Z, Roblox cylinders use local X.
            cylinder_rotation=Euler((0,math.pi/2,0),'XYZ').to_matrix()
            matrix=matrix @ cylinder_rotation
            ob.scale=(p['size'][2],p['size'][1],p['size'][0])
        else: ob.scale=p['size']
        ob.rotation_euler=(conversion @ matrix).to_euler()
        ob.location=conversion @ Vector(p['pos'])
        key=(tuple(p['color']),p['material'])
        if key not in mats:
            mat=bpy.data.materials.new(row['Id']+'_color'+str(len(mats)));mat.diffuse_color=(*p['color'],1)
            mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF')
            bs.inputs['Base Color'].default_value=(*p['color'],1);bs.inputs['Roughness'].default_value=.35
            if p['material']=='Metal': bs.inputs['Metallic'].default_value=.7
            if p['material']=='Neon':
                bs.inputs['Emission Color'].default_value=(*p['color'],1);bs.inputs['Emission Strength'].default_value=.5
            mats[key]=mat
        ob.data.materials.append(mats[key])
    camera_data=bpy.data.cameras.new('Preview');cam=bpy.data.objects.new('Preview',camera_data);scene.collection.objects.link(cam)
    cam.location=(7,-9,6);cam.rotation_euler=(Vector((0,0,1.2))-cam.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type='ORTHO';camera_data.ortho_scale=7.9;scene.camera=cam
    scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=320;scene.render.resolution_y=240;scene.render.resolution_percentage=100
    scene.render.film_transparent=True;scene.world=bpy.data.worlds.new('PreviewWorld')
    scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL'
    scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(path/'preview.png')
    bpy.ops.render.render(write_still=True)
    bpy.ops.export_scene.gltf(filepath=str(path/(row['Id']+'.glb')),export_format='GLB',use_active_scene=True,export_cameras=False)
    bpy.data.libraries.write(str(path/(row['Id']+'.blend')),{scene},fake_user=True,compress=True)
    (path/'recipe.json').write_text(json.dumps(parts,indent=2)+'\n')
    export_xml(row,parts)
    # Assert the exact emitted primitive bounds; rotations handled using every corner.
    lows=Vector((1e9,1e9,1e9));highs=-lows
    for p in parts:
        rot=Euler(tuple(math.radians(v) for v in p['rotation']),'XYZ').to_matrix()
        for x in [-.5,.5]:
            for y in [-.5,.5]:
                for z in [-.5,.5]:
                    v=Vector(p['pos'])+rot @ Vector((p['size'][0]*x,p['size'][1]*y,p['size'][2]*z))
                    lows=Vector(tuple(min(a,b) for a,b in zip(lows,v)));highs=Vector(tuple(max(a,b) for a,b in zip(highs,v)))
    assert lows.x>=-1.95 and highs.x<=1.95 and lows.z>=-3.3 and highs.z<=3.3 and lows.y>=-.001,(row['Id'],lows,highs)
    report={'id':row['Id'],'parts':len(parts),'min':list(lows),'max':list(highs),'wave':index//20+1}
    (path/'DRAFT.md').write_text('# '+row['Name']+'\n\nOriginal low-poly '+row['Family'].replace('_','/')+' skin. Authored for Racer-RNG, 2026-10-20.\n\nSource: `tools/build_expansion_cars.py` recipe '+str(index+1)+'. No third-party model, texture, brand, logo or extracted asset. Project-original artwork; no external license restrictions.\n\nFiles: '+row['Id']+'.blend, '+row['Id']+'.glb, recipe.json, preview.png. Roblox export: assets/studio/ExpansionCarModels/'+row['Id']+'.rbxmx.\n\nScale: 1 Blender unit = 1 stud. Blender forward +Y/up +Z; exported Roblox forward -Z/up +Y. Pivot at base centre. Part-built cosmetic skin; no custom physics.\n\nBounds validated: '+json.dumps(report)+'. Live Studio acceptance recorded separately in handoff.md.\n')
    return report


def build_wave(wave):
    assert 1 <= wave <= 5
    rows=roster();assert len(rows)==100
    previous=bpy.context.window.scene
    reports=[]
    try:
        for index in range((wave-1)*20,wave*20):
            reports.append(author(rows[index],index))
        (OUT/f'wave-{wave}.json').write_text(json.dumps(reports,indent=2)+'\n')
    finally:
        bpy.context.window.scene=previous
    print(json.dumps({'wave':wave,'count':len(reports),'parts':sum(r['parts'] for r in reports),'validated':True}))
