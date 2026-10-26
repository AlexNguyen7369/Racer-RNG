# Blender draft, round 3 (2026-10-26): Rainbow / Solar / Void trails and Azure / Ember / Galaxy auras.
# Owner feedback on round 1: longer and more flamboyant; Void too flat and without particles; Rainbow thinner
# but long, not a stub. Round 2: Solar more flamboyant, Void more particles / less static, auras more
# eccentric. Run inside Blender (MCP): exec(open(<this file>).read()). 1 unit = 1 stud, Z up.
# Cars drive +Y at cruise speed. Trails are flat ribbon meshes (length = SPEED x Lifetime, UV v = 1 at the head).
# Particles are a frozen frame of each Roblox emitter: every particle sits where its speed, drag and
# acceleration carry it at its age, with the size / transparency / colour / flipbook cell for that age.
import colorsys
import math
import os
import random

import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else "/Users/alexnguyen7369/Documents/RobloxGames/drafts/props/trail-vfx-redesign"
TEX = os.path.normpath(os.path.join(HERE, "..", "..", "..", "vfx", "trails", "out"))
SPEED = 45.0
CHASSIS_Y = 1.29  # chassis centre above the wheel bottoms (measured in Studio)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights, bpy.data.curves):
    for block in list(coll):
        if block.users == 0:
            coll.remove(block)

scene = bpy.context.scene
scene.view_settings.view_transform = "Standard"
CAM = bpy.data.objects.new("ViewCam", bpy.data.cameras.new("ViewCam"))
scene.collection.objects.link(CAM)
scene.camera = CAM


# ---------------------------------------------------------------- helpers
def lin(c):
    return tuple((v / 255) ** 2.2 for v in c)


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def at(points, t):
    """Sample a Roblox-style sequence [(t, value)] (value: number or tuple)."""
    for (t0, v0), (t1, v1) in zip(points, points[1:]):
        if t <= t1:
            f = (t - t0) / ((t1 - t0) or 1)
            return v0 + (v1 - v0) * f if isinstance(v0, (int, float)) else mix(v0, v1, f)
    return points[-1][1]


def image(name):
    img = bpy.data.images.get(name) or bpy.data.images.load(os.path.join(TEX, name))
    img.alpha_mode = "STRAIGHT"
    return img


def blended(mat):
    try:
        mat.surface_render_method = "BLENDED"
    except AttributeError:
        mat.blend_method = "BLEND"


def ramp(nodes, points, constant=False):
    node = nodes.new("ShaderNodeValToRGB")
    cr = node.color_ramp
    cr.interpolation = "CONSTANT" if constant else "LINEAR"
    while len(cr.elements) > 1:
        cr.elements.remove(cr.elements[-1])
    for i, (t, v) in enumerate(points):
        rgb = v if isinstance(v, tuple) else (v, v, v)
        el = cr.elements[0] if i == 0 else cr.elements.new(t)
        el.position, el.color = t, (*rgb, 1)
    return node


def shade(nodes, links, color_socket, alpha_socket, light_emission, brightness):
    """Roblox look: LightEmission 1 glows, 0 is lit matter; Brightness pushes both hotter."""
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(alpha_socket, bsdf.inputs["Alpha"])
    links.new(color_socket, bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = brightness * (0.25 + 0.75 * light_emission)
    if light_emission >= 0.5:
        bsdf.inputs["Base Color"].default_value = (0, 0, 0, 1)
    else:
        links.new(color_socket, bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.9
    links.new(bsdf.outputs[0], out.inputs[0])


def trail_material(name, tex, colors, transparency, light_emission, brightness, constant=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    blended(mat)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    uv = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(uv.outputs["UV"], sep.inputs[0])
    frac = nodes.new("ShaderNodeMath")  # age along the trail even when the texture tiles
    frac.name = "Frac"
    frac.operation = "DIVIDE"
    links.new(sep.outputs["Y"], frac.inputs[0])
    frac.inputs[1].default_value = 1.0
    age = nodes.new("ShaderNodeMath")
    age.operation = "SUBTRACT"
    age.inputs[0].default_value = 1.0
    links.new(frac.outputs[0], age.inputs[1])
    col = ramp(nodes, colors)
    links.new(age.outputs[0], col.inputs[0])
    tr = ramp(nodes, transparency, constant)
    links.new(age.outputs[0], tr.inputs[0])
    inv = nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    links.new(tr.outputs["Color"], inv.inputs[1])
    alpha = nodes.new("ShaderNodeMath")
    alpha.operation = "MULTIPLY"
    links.new(inv.outputs[0], alpha.inputs[1])
    tint = nodes.new("ShaderNodeMix")
    tint.data_type, tint.blend_type = "RGBA", "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    links.new(col.outputs["Color"], tint.inputs["A"])
    img = nodes.new("ShaderNodeTexImage")
    img.image = image(tex)
    links.new(uv.outputs["UV"], img.inputs["Vector"])
    links.new(img.outputs["Color"], tint.inputs["B"])
    links.new(img.outputs["Alpha"], alpha.inputs[0])
    shade(nodes, links, tint.outputs["Result"], alpha.outputs[0], light_emission, brightness)
    return mat


def card_material(name, tex, light_emission, brightness):
    """One material per emitter; each card's colour and alpha come from its object colour."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    blended(mat)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    info = nodes.new("ShaderNodeObjectInfo")
    uv = nodes.new("ShaderNodeTexCoord")
    img = nodes.new("ShaderNodeTexImage")
    img.image = image(tex)
    img.extension = "CLIP"
    links.new(uv.outputs["UV"], img.inputs["Vector"])
    tint = nodes.new("ShaderNodeMix")
    tint.data_type, tint.blend_type = "RGBA", "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    links.new(info.outputs["Color"], tint.inputs["A"])
    links.new(img.outputs["Color"], tint.inputs["B"])
    alpha = nodes.new("ShaderNodeMath")
    alpha.operation = "MULTIPLY"
    links.new(img.outputs["Alpha"], alpha.inputs[0])
    links.new(info.outputs["Alpha"], alpha.inputs[1])
    shade(nodes, links, tint.outputs["Result"], alpha.outputs[0], light_emission, brightness)
    return mat


def path_point(origin, s):
    """Centre of the wake s studs behind a car at origin: a gentle bend, then straight."""
    x0, y0 = origin
    bend = 5.0 * (1 - math.cos(min(s, 70) / 70 * math.pi)) / 2
    return x0 + bend, y0 - s


def ribbon(name, origin, half, height, lifetime, width_scale, mat, back=3.0, tile=None, segments=64):
    length = SPEED * lifetime
    verts, faces, uvs = [], [], []
    for i in range(segments + 1):
        a = i / segments
        cx, cy = path_point(origin, back + a * length)
        nx, ny = path_point(origin, back + a * length + 0.5)
        dx, dy = nx - cx, ny - cy
        n = math.hypot(dx, dy) or 1
        rx, ry = -dy / n, dx / n
        w = half * at(width_scale, a)
        for side in (-1, 1):
            verts.append((cx - rx * side * w, cy - ry * side * w, height))
            uvs.append((0 if side < 0 else 1, (1 - a) * (length / tile if tile else 1)))
    for i in range(segments):
        faces.append((i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    layer = mesh.uv_layers.new()
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            layer.data[li].uv = uvs[mesh.loops[li].vertex_index]
    if tile:
        mat.node_tree.nodes["Frac"].inputs[1].default_value = length / tile
    mesh.materials.append(mat)
    ob = bpy.data.objects.new(name, mesh)
    ob.visible_shadow = False
    scene.collection.objects.link(ob)
    return ob


_card_meshes = {}


def card_mesh(grid, cell, bucket, stretch):
    """A unit card (normal +Z) showing one flipbook cell, turned by bucket x 45 degrees in its plane."""
    key = (grid, cell, bucket, stretch)
    if key in _card_meshes:
        return _card_meshes[key]
    r, c = divmod(cell, grid)
    ang = bucket * math.pi / 4
    ca, sa = math.cos(ang), math.sin(ang)
    corners = [(-0.5, -0.5 * stretch), (0.5, -0.5 * stretch), (0.5, 0.5 * stretch), (-0.5, 0.5 * stretch)]
    verts = [(x * ca - y * sa, x * sa + y * ca, 0) for x, y in corners]
    mesh = bpy.data.meshes.new(f"card_{grid}_{cell}_{bucket}_{stretch}")
    mesh.from_pydata(verts, [], [(0, 1, 2, 3)])
    layer = mesh.uv_layers.new()
    for li, (u, v) in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]):
        layer.data[li].uv = ((c + u) / grid, 1 - (r + 1 - v) / grid)
    mesh.materials.append(None)
    _card_meshes[key] = mesh
    return mesh


def emitter(name, car_origin, e, rng):
    """Frozen frame of one ParticleEmitter. e: Roblox-like properties in chassis space (x right, y up, z back)."""
    mat = card_material(name, e["tex"], e.get("le", 0), e.get("br", 1))
    grid = e.get("grid", 1)
    life0, life1 = e["life"]
    made = 0
    for _ in range(int(e["rate"] * life1)):
        life = rng.uniform(life0, life1)
        age = rng.uniform(0, life1)
        if age > life:
            continue
        t = age / life
        bx, by, bz = e.get("box", (0, 0, 0))
        ox, oy, oz = e.get("at", (0, 0, 0))
        lx, ly, lz = ox + rng.uniform(-bx, bx), oy + rng.uniform(-by, by), oz + rng.uniform(-bz, bz)
        if e.get("ring"):  # spawn on an ellipse round the car (wheels / body edge)
            a = rng.uniform(0, 2 * math.pi)
            lx, lz = ox + math.cos(a) * e["ring"][0], oz + math.sin(a) * e["ring"][1]
        base = mathutils.Vector(e.get("dir", (0, 1, 0))).normalized()
        spread = math.radians(e.get("spread", 0))
        if spread > 0:
            rot = mathutils.Euler((rng.uniform(-spread, spread), 0, rng.uniform(-spread, spread)))
            base = (rot.to_matrix() @ base).normalized()
        sp = rng.uniform(*e.get("speed", (0, 0)))
        drag = e.get("drag", 0)
        travel = age if drag == 0 else (1 - math.exp(-drag * age)) / drag
        ax, ay, az = e.get("acc", (0, 0, 0))
        px = lx + base.x * sp * travel + 0.5 * ax * age * age
        py = ly + base.y * sp * travel + 0.5 * ay * age * age
        pz = lz + base.z * sp * travel + 0.5 * az * age * age
        vel = mathutils.Vector((base.x * sp + ax * age, base.y * sp + ay * age, base.z * sp + az * age))
        orb = e.get("orbit")
        if orb:  # spiral: a client script would move these round the car (axis y) or round the wake (axis z)
            r = rng.uniform(*orb["r"]) + orb.get("grow", 0) * age
            ang = rng.uniform(0, 2 * math.pi) + math.radians(orb["spin"]) * age
            if orb.get("axis", "y") == "y":
                px, py, pz = ox + math.cos(ang) * r * orb.get("squash", 1), oy + orb.get("rise", 0) * age + py - ly, oz + math.sin(ang) * r
            else:
                px, py, pz = ox + math.cos(ang) * r, oy + math.sin(ang) * r + orb.get("rise", 0) * age, pz
            tilt = orb.get("tilt")
            if tilt:
                v = mathutils.Euler([math.radians(a) for a in tilt]).to_matrix() @ mathutils.Vector((px - ox, py - oy, pz - oz))
                px, py, pz = ox + v.x, oy + v.y, oz + v.z
            vel = mathutils.Vector((-math.sin(ang), 0.2, math.cos(ang)))
        # unlocked particles were emitted when the car was SPEED x age further back
        back = 0 if e.get("locked") else SPEED * age
        cx, cy = path_point(car_origin, back) if back else car_origin
        world = mathutils.Vector((cx + px, cy - pz, CHASSIS_Y + py))
        size = at(e["size"], t)
        alpha = 1 - at(e.get("transparency", [(0, 0), (1, 1)]), t)
        color = at(e["color"], t) if isinstance(e["color"], list) else e["color"]
        if e.get("hue"):
            color = tuple(c**2.2 for c in colorsys.hsv_to_rgb(rng.random(), 0.65, 1))
        if size <= 0.01 or alpha <= 0.01:
            continue
        cell = min(grid * grid - 1, int(t * grid * grid)) if grid > 1 else 0
        orient = e.get("orient", "camera")
        bucket = rng.randrange(8) if e.get("spin", True) and orient != "parallel" else 0
        ob = bpy.data.objects.new(f"{name}_{made}", card_mesh(grid, cell, bucket, e.get("stretch", 1)))
        ob.material_slots[0].link = "OBJECT"
        ob.material_slots[0].material = mat
        ob.location = world
        ob.scale = (size, size, size)
        ob.color = (*color, alpha)
        ob.visible_shadow = False
        scene.collection.objects.link(ob)
        if orient == "camera":  # face the camera with the image's top up, as a FacingCamera particle does
            c = ob.constraints.new("TRACK_TO")
            c.target, c.track_axis, c.up_axis = CAM, "TRACK_Z", "UP_Y"
        elif orient == "fixed":  # a flat card at a fixed tilt (Roblox: a flat ring on a turned attachment)
            rx, ry, rz = e.get("rot", (0, 0, 0))
            ob.rotation_euler = (math.radians(rx), math.radians(rz), math.radians(ry + rng.uniform(0, 360) * e.get("spin_fixed", 0)))
        elif orient == "parallel":
            wv = mathutils.Vector((vel.x, -vel.z, vel.y))
            ob.rotation_mode = "QUATERNION"
            ob.rotation_quaternion = (wv if wv.length else mathutils.Vector((0, 1, 0))).to_track_quat("Y", "Z")
            c = ob.constraints.new("LOCKED_TRACK")
            c.target, c.track_axis, c.lock_axis = CAM, "TRACK_Z", "LOCK_Y"
        made += 1
    return made


def simple_mat(name, color, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*color, 1)
    if emission:
        b.inputs["Emission Color"].default_value = (*color, 1)
        b.inputs["Emission Strength"].default_value = emission
    return mat


def box(name, loc, size, mat):
    mesh = bpy.data.meshes.new(name)
    sx, sy, sz = (s / 2 for s in size)
    v = [(x * sx, y * sy, z * sz) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    mesh.from_pydata(v, [], f)
    mesh.materials.append(mat)
    ob = bpy.data.objects.new(name, mesh)
    ob.location = loc
    scene.collection.objects.link(ob)
    return ob


CAR_MATS = []


def car(label, x, y=0.0):
    if not CAR_MATS:
        CAR_MATS.extend([simple_mat("CarBody", lin((137, 207, 240))), simple_mat("CarGlass", lin((41, 107, 217))), simple_mat("CarTire", lin((41, 43, 56)))])
    body, glass, tire = CAR_MATS
    box(label + "_Body", (x, y, CHASSIS_Y), (3, 6.6, 1.05), body)
    box(label + "_Cabin", (x, y - 0.4, CHASSIS_Y + 0.85), (2.4, 3.0, 0.7), glass)
    for wx in (-1.5, 1.5):
        for wy in (-2.1, 2.1):
            box(label + "_Wheel", (x + wx, y + wy, 0.75), (0.6, 1.5, 1.5), tire)
    txt = bpy.data.curves.new(label + "_Label", "FONT")
    txt.body, txt.size, txt.align_x = label, 1.6, "CENTER"
    txt.materials.append(simple_mat(label + "_LabelMat", (1, 1, 1), 3))
    ob = bpy.data.objects.new(label + "_Label", txt)
    ob.location = (x, y + 7, 5)
    ob.visible_shadow = False
    scene.collection.objects.link(ob)
    c = ob.constraints.new("TRACK_TO")  # readable from any shot
    c.target, c.track_axis, c.up_axis = CAM, "TRACK_Z", "UP_Y"


def dashes(phase, count, fade_from):
    pts = []
    for i in range(count):
        x0 = i / count
        on = (i + phase) % 2 == 0 or (i + phase) % 3 == 0
        pts.append((x0, max(0, (x0 - fade_from) / (1 - fade_from)) if on else 1.0))
    return pts


def Y(roblox_y):
    return CHASSIS_Y + roblox_y  # world height of a chassis-local y


WHITE, BLACK = (1, 1, 1), (0, 0, 0)
VIOLET, TEAL, DEEP = lin((104, 52, 220)), lin((34, 230, 210)), lin((24, 6, 52))
GOLD, PALE, ORANGE, RED = lin((255, 188, 48)), lin((255, 245, 145)), lin((255, 120, 30)), lin((200, 40, 10))
CYAN, ICE = lin((80, 190, 255)), lin((180, 245, 255))
EMBER, FLAMEY = lin((255, 92, 38)), lin((255, 220, 75))
GALV, PINK, NAVY = lin((137, 80, 255)), lin((255, 91, 220)), lin((40, 30, 120))
FIRE = [(0, PALE), (0.3, GOLD), (0.6, ORANGE), (0.85, RED), (1, lin((40, 10, 5)))]

rng = random.Random(7)
LANES = {"Rainbow Trail": -36, "Solar Trail": -16, "Void Trail": 4, "Azure Aura": 26, "Ember Aura": 40, "Galaxy Aura": 54}

# Rainbow: thinner (1.2 studs) but 90 studs long, dark twin, hot core, hue glints and stardust.
X = LANES["Rainbow Trail"]
car("Rainbow Trail", X)
o = (X, 0)
ribbon("RainbowShadow", o, 0.75, Y(-0.77), 2.1, [(0, 1), (1, 0.45)],
       trail_material("RainbowShadow", "RainbowRibbon.png", [(0, (0.004, 0.002, 0.007)), (1, (0.004, 0.002, 0.007))], [(0, 0.45), (1, 1)], 0, 1))
ribbon("RainbowRibbon", o, 0.6, Y(-0.75), 2.0, [(0, 1), (1, 0.35)],
       trail_material("RainbowRibbon", "RainbowRibbon.png", [(0, WHITE), (1, WHITE)], [(0, 0), (0.6, 0.2), (1, 1)], 0.25, 4))
ribbon("RainbowCore", o, 0.12, Y(-0.72), 0.7, [(0, 1), (1, 0)],
       trail_material("RainbowCore", "CoreStreak.png", [(0, WHITE), (1, WHITE)], [(0, 0), (1, 1)], 1, 3))
emitter("RainbowGlints", o, dict(tex="Glint.png", rate=45, life=(0.8, 1.6), speed=(0.5, 2), dir=(0, 1, 0.3), spread=70, drag=1.5,
        acc=(0, 1, 0), size=[(0, 0), (0.2, 1.1), (1, 0)], color=WHITE, hue=True, le=1, br=3, at=(0, -0.5, 3), box=(0.6, 0.1, 0.3)), rng)
emitter("RainbowDust", o, dict(tex="Dot.png", rate=80, life=(1, 2), speed=(0.5, 1.5), spread=180, size=[(0, 0.3), (1, 0)],
        color=WHITE, hue=True, le=1, br=2, at=(0, -0.5, 3), box=(0.6, 0.1, 0.3)), rng)

# Solar (round 3: more flamboyant): wide heat glow, plasma ribbon, white-hot core, a roaring flame stream
# with flame "wings" flaring out to both sides, a hot flare at the exhaust, fire rings left on the road,
# spiralling sun-sparks, falling embers and warm smoke.
X = LANES["Solar Trail"]
car("Solar Trail", X)
o = (X, 0)
ribbon("SolarGlow", o, 2.4, Y(-0.8), 1.6, [(0, 1), (1, 0.6)],
       trail_material("SolarGlow", "SoftBand.png", [(0, ORANGE), (1, RED)], [(0, 0.1), (1, 1)], 1, 2.5))
ribbon("SolarPlasma", o, 0.95, Y(-0.75), 2.0, [(0, 1), (1, 0.3)],
       trail_material("SolarPlasma", "Plasma.png", [(0, PALE), (0.35, GOLD), (0.7, ORANGE), (1, RED)], [(0, 0), (0.5, 0.15), (1, 1)], 0.3, 5))
ribbon("SolarCore", o, 0.25, Y(-0.72), 0.6, [(0, 1), (1, 0)],
       trail_material("SolarCore", "CoreStreak.png", [(0, WHITE), (1, PALE)], [(0, 0), (1, 1)], 1, 5))
emitter("SolarFlames", o, dict(tex="Flame.flipbook.png", grid=4, rate=110, life=(0.5, 0.9), speed=(1, 3), dir=(0, 1, 0), spread=25,
        acc=(0, 4, 0), size=[(0, 2), (1, 4)], color=FIRE, le=0, br=6, at=(0, -0.3, 3.2), box=(0.8, 0.1, 0.5), spin=False), rng)
for side in (-1, 1):
    emitter(f"SolarWing{side}", o, dict(tex="Flame.flipbook.png", grid=4, rate=45, life=(0.4, 0.7), speed=(5, 8), dir=(side, 0.7, 0.3), spread=12,
            drag=1.5, acc=(0, 3, 0), size=[(0, 1.2), (1, 2.6)], color=FIRE, le=0, br=6, at=(side * 1.2, -0.3, 2.8), box=(0.2, 0.1, 0.3), spin=False), rng)
emitter("SolarFlare", o, dict(tex="Glint.png", rate=8, life=(0.15, 0.25), size=[(0, 5), (1, 3)], color=PALE, le=1, br=8, locked=True, at=(0, -0.2, 3.4)), rng)
emitter("SolarRings", o, dict(tex="Ring.png", rate=3, life=(0.9, 0.9), size=[(0, 2), (1, 9)], transparency=[(0, 0.1), (1, 1)], color=GOLD,
        le=1, br=3, orient="flat", at=(0, -1.25, 3.5)), rng)
emitter("SolarSunSparks", o, dict(tex="Glint.png", rate=50, life=(0.8, 1.4), size=[(0, 0.8), (1, 0)], color=[(0, PALE), (1, ORANGE)], le=1, br=4,
        at=(0, 0.3, 3.5), orbit=dict(r=(0.8, 1.6), spin=400, axis="z", rise=0.5)), rng)
emitter("SolarEmbers", o, dict(tex="Spark.png", rate=90, life=(0.6, 1.2), speed=(4, 10), dir=(0, 1, 0.5), spread=60, drag=1, acc=(0, -6, 0),
        size=[(0, 0.6), (1, 0.2)], stretch=3, color=[(0, PALE), (1, ORANGE)], le=1, br=4, orient="parallel", at=(0, -0.3, 3.2), box=(0.8, 0.1, 0.5)), rng)
emitter("SolarSmoke", o, dict(tex="VoidWisp.flipbook.png", grid=4, rate=14, life=(1.2, 1.8), speed=(1, 2), dir=(0, 1, 0), spread=30,
        acc=(0, 1.5, 0), size=[(0, 1.8), (1, 4)], transparency=[(0, 0.55), (1, 1)], color=[(0, lin((230, 140, 80))), (1, lin((140, 125, 120)))],
        le=0, br=1, at=(0, 0.5, 4), box=(0.9, 0.2, 0.6)), rng)

# Void (round 3: mostly particles, less static): only a thin dark core ribbon stays; the body of the trail is a
# churning stream of dark wisps and violet flames, with motes spiralling round it like a vortex, shards
# flung out, lightning, a black twin for depth, and the crackling edges as darting particles.
X = LANES["Void Trail"]
car("Void Trail", X)
o = (X, 0)
ribbon("VoidCore", o, 0.5, Y(-0.82), 1.4, [(0, 1), (1, 0.3)],
       trail_material("VoidCore", "VoidWake.png", [(0, mix(VIOLET, BLACK, 0.8)), (1, mix(VIOLET, BLACK, 0.95))], [(0, 0.1), (1, 1)], 0, 1))
emitter("VoidStream", o, dict(tex="VoidWisp.flipbook.png", grid=4, rate=70, life=(1.2, 2.0), speed=(0.5, 2), dir=(0, 1, 0), spread=70,
        acc=(0, 0.8, 0), size=[(0, 1.4), (1, 3.2)], transparency=[(0, 0.05), (1, 0.8)],
        color=[(0, mix(VIOLET, BLACK, 0.55)), (0.5, mix(VIOLET, BLACK, 0.85)), (1, BLACK)], le=0, br=1, at=(0, -0.5, 3.4), box=(1.2, 0.2, 0.5)), rng)
emitter("VoidFlames", o, dict(tex="Flame.flipbook.png", grid=4, rate=70, life=(0.6, 1.0), speed=(2, 4), dir=(0, 1, 0), spread=30, acc=(0, 5, 0),
        size=[(0, 1.6), (1, 3.2)], color=[(0, lin((200, 150, 255))), (0.35, VIOLET), (0.8, DEEP), (1, BLACK)], le=0.3, br=4,
        at=(0, -0.6, 3.5), box=(1.0, 0.1, 0.5), spin=False), rng)
emitter("VoidFlamesBlack", o, dict(tex="Flame.flipbook.png", grid=4, rate=30, life=(0.7, 1.1), speed=(2, 4), dir=(0, 1, 0), spread=35, acc=(0, 4, 0),
        size=[(0, 1.6), (1, 3)], color=(0.002, 0, 0.006), le=0, br=0, at=(0, -0.6, 3.5), box=(1.0, 0.1, 0.5), spin=False), rng)
emitter("VoidVortex", o, dict(tex="Glint.png", rate=90, life=(1.0, 1.8), size=[(0, 0.7), (1, 0)], color=[(0, TEAL), (0.5, lin((150, 120, 255))), (1, VIOLET)],
        le=1, br=4, at=(0, 0.3, 3.5), orbit=dict(r=(1.2, 2.2), spin=300, axis="z", rise=0.6, grow=0.8)), rng)
emitter("VoidOrbs", o, dict(tex="Dot.png", rate=20, life=(1.2, 2.0), size=[(0, 0.9), (1, 0.3)], color=(0.01, 0, 0.03), le=0, br=0,
        at=(0, 0.3, 3.5), orbit=dict(r=(1.0, 1.8), spin=-220, axis="z", rise=0.4)), rng)
emitter("VoidShards", o, dict(tex="Shard.png", rate=35, life=(1, 1.6), speed=(4, 8), dir=(0, 1, 0.4), spread=70, drag=0.5, acc=(0, 1, 0),
        size=[(0, 1), (1, 0)], stretch=2, color=[(0, TEAL), (1, VIOLET)], le=0.5, br=3, orient="parallel", at=(0, -0.5, 3.5), box=(1.2, 0.1, 0.5)), rng)
emitter("VoidDarts", o, dict(tex="Spark.png", rate=60, life=(0.3, 0.6), speed=(8, 14), dir=(0, 0.1, -1), spread=20, size=[(0, 0.5), (1, 0.2)],
        stretch=4, color=TEAL, le=1, br=5, orient="parallel", at=(0, -0.7, 3.5), box=(1.4, 0.1, 0.3)), rng)
emitter("VoidBolts", o, dict(tex="Bolt.flipbook.png", grid=4, rate=18, life=(0.25, 0.35), size=[(0, 5), (1, 5.5)], color=TEAL, le=1, br=5,
        at=(0, 0, 3.5), box=(1.6, 0.8, 0.5)), rng)
emitter("VoidMotes", o, dict(tex="Glint.png", rate=60, life=(0.6, 1.3), speed=(1.5, 4), dir=(0, 1, 0), spread=70, drag=2, acc=(0, 2, 0),
        size=[(0, 0.5), (1, 0)], color=[(0, TEAL), (1, VIOLET)], le=1, br=3, at=(0, -0.6, 3.3), box=(1.3, 0.1, 0.4)), rng)

# Azure (round 3: eccentric): an atom. Three tilted rings spin round the car like a gyroscope, electric orbs
# orbit on them, a lightning pillar crackles above the roof, arcs crawl over the body, charge streaks rise.
X = LANES["Azure Aura"]
car("Azure Aura", X)
o = (X, 0)
for i, tilt in enumerate(((70, 0, 0), (70, 60, 0), (70, -60, 0))):
    emitter(f"AzureGyro{i}", o, dict(tex="Ring.png", rate=0.5, life=(2, 2), size=[(0, 7), (1, 7)], transparency=[(0, 0.15), (1, 0.15)], color=CYAN,
            le=1, br=3, orient="fixed", rot=tilt, locked=True, at=(0, 0.4, 0)), rng)
    emitter(f"AzureOrbs{i}", o, dict(tex="Glint.png", rate=3, life=(1, 1), size=[(0, 1.4), (1, 1.4)], color=ICE, le=1, br=6, locked=True,
            at=(0, 0.4, 0), orbit=dict(r=(3.3, 3.3), spin=240, axis="y", tilt=(tilt[0] - 90, tilt[1], 0))), rng)
emitter("AzurePillar", o, dict(tex="Bolt.flipbook.png", grid=4, rate=10, life=(0.2, 0.3), size=[(0, 3), (1, 3.5)], stretch=2, color=ICE, le=1, br=6,
        orient="fixed", rot=(90, 90, 0), spin_fixed=1, locked=True, at=(0, 2.6, 0), box=(0.2, 0.3, 0.2)), rng)
emitter("AzureRing", o, dict(tex="Ring.png", rate=2, life=(1.2, 1.2), size=[(0, 3), (1, 10)], transparency=[(0, 0.1), (1, 1)], color=CYAN,
        le=1, br=3, orient="flat", locked=True, at=(0, -1.25, 0)), rng)
emitter("AzureArcs", o, dict(tex="Bolt.flipbook.png", grid=4, rate=24, life=(0.2, 0.3), size=[(0, 3.5), (1, 4.5)], color=ICE, le=1, br=6,
        locked=True, at=(0, 0.2, 0), box=(1.8, 0.8, 3.5)), rng)
emitter("AzureCharge", o, dict(tex="Spark.png", rate=30, life=(0.3, 0.6), speed=(6, 10), dir=(0, 1, 0), spread=15, size=[(0, 0.6), (1, 0.2)],
        stretch=4, color=[(0, WHITE), (1, CYAN)], le=1, br=5, orient="parallel", locked=True, at=(0, -0.8, 0), box=(1.8, 0.1, 3.3)), rng)
emitter("AzureFrost", o, dict(tex="Dot.png", rate=40, life=(0.8, 1.4), speed=(0.5, 1.5), spread=180, size=[(0, 0.22), (1, 0)],
        color=ICE, le=1, br=2, at=(0, -0.5, 0), box=(1.8, 0.4, 3.3)), rng)

# Ember (round 3: eccentric): a fire tornado. Flames spiral up round the car in a widening helix, fireballs
# orbit it, a ring of fire burns on the ground, sparks fly off the spin.
X = LANES["Ember Aura"]
car("Ember Aura", X)
o = (X, 0)
emitter("EmberTornado", o, dict(tex="Flame.flipbook.png", grid=4, rate=120, life=(0.7, 1.1), size=[(0, 1.6), (1, 2.4)], color=FIRE, le=0, br=6,
        locked=True, spin=False, at=(0, -0.8, 0), orbit=dict(r=(2.4, 3.0), spin=260, axis="y", rise=3.5, grow=1.4, squash=0.8)), rng)
emitter("EmberFireballs", o, dict(tex="Dot.png", rate=4, life=(1.5, 1.5), size=[(0, 1.3), (1, 1.3)], color=FLAMEY, le=1, br=6, locked=True,
        at=(0, 1.8, 0), orbit=dict(r=(3.6, 3.6), spin=-180, axis="y")), rng)
emitter("EmberFireballCore", o, dict(tex="Flame.flipbook.png", grid=4, rate=8, life=(0.5, 0.7), size=[(0, 1.6), (1, 2.2)], color=FIRE, le=0, br=6,
        locked=True, spin=False, at=(0, 2.1, 0), orbit=dict(r=(3.6, 3.6), spin=-180, axis="y")), rng)
emitter("EmberFireRing", o, dict(tex="Flame.flipbook.png", grid=4, rate=60, life=(0.4, 0.6), speed=(1, 2), dir=(0, 1, 0), acc=(0, 3, 0),
        size=[(0, 1), (1, 1.6)], color=FIRE, le=0, br=6, ring=(3.6, 4.6), at=(0, -1.0, 0), locked=True, spin=False), rng)
emitter("EmberSparks", o, dict(tex="Spark.png", rate=60, life=(0.8, 1.3), speed=(4, 8), dir=(0, 1, 0), spread=70, drag=0.8, acc=(0, -4, 0),
        size=[(0, 0.5), (1, 0.15)], stretch=3, color=[(0, PALE), (1, EMBER)], le=1, br=4, orient="parallel", at=(0, 1, 0), box=(2.4, 1, 3.2)), rng)
emitter("EmberSmoke", o, dict(tex="VoidWisp.flipbook.png", grid=4, rate=10, life=(1.2, 1.8), speed=(1, 2), dir=(0, 1, 0), spread=30,
        acc=(0, 1.5, 0), size=[(0, 1.6), (1, 3.2)], transparency=[(0, 0.55), (1, 1)], color=[(0, lin((230, 130, 70))), (1, lin((140, 125, 120)))],
        le=0, br=1, at=(0, 3, 2), box=(1.6, 0.4, 2)), rng)

# Galaxy (round 3: eccentric): an orrery. Two tilted rune rings counter-turn, little planets orbit on them,
# a swirling vortex spins above the roof, the ground sigil turns, nebula streams behind, stars twinkle,
# shooting stars streak past.
X = LANES["Galaxy Aura"]
car("Galaxy Aura", X)
o = (X, 0)
emitter("GalaxySigil", o, dict(tex="RuneRing.png", rate=0.8, life=(2.5, 2.5), size=[(0, 8.5), (1, 9.5)], transparency=[(0, 0.6), (0.2, 0.15), (1, 1)],
        color=PINK, le=1, br=2.5, orient="flat", locked=True, at=(0, -1.25, 0)), rng)
for i, tilt in enumerate(((60, 25, 0), (60, -35, 0))):
    emitter(f"GalaxyOrbitRing{i}", o, dict(tex="RuneRing.png", rate=0.5, life=(2, 2), size=[(0, 8), (1, 8)], transparency=[(0, 0.35), (1, 0.35)],
            color=GALV if i else PINK, le=1, br=2.5, orient="fixed", rot=tilt, locked=True, at=(0, 0.8, 0)), rng)
    for j, col in enumerate((lin((255, 200, 120)), lin((120, 220, 255)))):
        emitter(f"GalaxyPlanet{i}{j}", o, dict(tex="Dot.png", rate=1, life=(1, 1), size=[(0, 0.9 + 0.4 * j), (1, 0.9 + 0.4 * j)], color=col, le=1, br=4,
                locked=True, at=(0, 0.8, 0), orbit=dict(r=(3.8, 3.8), spin=150 * (1 if i else -1), axis="y", tilt=(tilt[0] - 90, tilt[1], 0))), rng)
emitter("GalaxyVortex", o, dict(tex="Nebula.png", rate=30, life=(1, 1.6), size=[(0, 1.2), (1, 0.3)], transparency=[(0, 0.2), (1, 1)],
        color=[(0, PINK), (1, GALV)], le=0.8, br=3, locked=True, at=(0, 3.2, 0), orbit=dict(r=(0.3, 2.2), spin=360, axis="y", grow=-1.2)), rng)
emitter("GalaxyNebula", o, dict(tex="Nebula.png", rate=18, life=(1.5, 2.5), speed=(0.3, 1), spread=180, size=[(0, 3), (1, 5)],
        transparency=[(0, 0.2), (1, 1)], color=[(0, GALV), (0.5, PINK), (1, NAVY)], le=0.8, br=2.5, at=(0, 0, 0), box=(1.8, 0.8, 3.3)), rng)
emitter("GalaxyNebulaDark", o, dict(tex="Nebula.png", rate=5, life=(1.6, 2.6), speed=(0.3, 1), spread=180, size=[(0, 3), (1, 4.5)],
        transparency=[(0, 0.5), (1, 1)], color=(0.003, 0.001, 0.01), le=0, br=0, at=(0, 0, 0), box=(1.8, 0.8, 3.3)), rng)
emitter("GalaxyStars", o, dict(tex="Glint.png", rate=70, life=(0.8, 1.5), size=[(0, 0), (0.3, 0.8), (1, 0)], color=[(0, WHITE), (1, PINK)],
        le=1, br=4, at=(0, 0.8, 0), box=(3, 2, 4.5)), rng)
emitter("GalaxyShooting", o, dict(tex="Spark.png", rate=6, life=(0.3, 0.5), speed=(15, 25), dir=(1, 0.2, 0), spread=90, size=[(0, 1.2), (1, 0.4)],
        stretch=4, color=WHITE, le=1, br=5, orient="parallel", locked=True, at=(0, 0.5, 0), box=(1, 0.5, 2)), rng)

# Ascended (Super Saiyan style) aura, draft 2026-10-26: spiky looping ki flames, a crown over the roof,
# lightning, a ground shockwave, dust and floating rocks.
WHITEGOLD, GOLDEN, AMBER, BOLTC = lin((255, 248, 200)), lin((255, 214, 64)), lin((255, 160, 20)), lin((150, 220, 255))
X = 72
car("Ascended Aura", X)
o = (X, 0)
emitter("AscSheathOuter", o, dict(tex="KiFlame.flipbook.png", grid=4, rate=70, life=(0.3, 0.5), speed=(6, 9), spread=6, acc=(0, 10, 0),
        size=[(0, 2.2), (0.5, 3.2), (1, 2)], color=[(0, WHITEGOLD), (0.4, GOLDEN), (1, AMBER)], le=0.5, br=6, locked=True, spin=False,
        ring=(1.9, 3.7), at=(0, -1.0, 0)), rng)
emitter("AscSheathInner", o, dict(tex="KiFlame.flipbook.png", grid=4, rate=50, life=(0.25, 0.4), speed=(4, 7), spread=6, acc=(0, 8, 0),
        size=[(0, 1.4), (1, 2.2)], color=[(0, WHITE), (1, WHITEGOLD)], le=1, br=4, locked=True, spin=False, ring=(1.4, 3.0), at=(0, -0.8, 0)), rng)
emitter("AscCrown", o, dict(tex="KiFlame.flipbook.png", grid=4, rate=20, life=(0.3, 0.5), speed=(8, 12), spread=5, acc=(0, 8, 0),
        size=[(0, 2.5), (1, 3.5)], color=[(0, WHITEGOLD), (1, GOLDEN)], le=0.7, br=5, locked=True, spin=False, at=(0, 1.2, 0), box=(1.2, 0.1, 2.4)), rng)
emitter("AscStreaks", o, dict(tex="Spark.png", rate=50, life=(0.2, 0.35), speed=(18, 26), spread=4, size=[(0, 0.6), (1, 0.25)], stretch=3,
        color=[(0, WHITE), (1, GOLDEN)], le=1, br=5, orient="parallel", locked=True, ring=(1.8, 3.5), at=(0, -0.8, 0)), rng)
emitter("AscLightning", o, dict(tex="Bolt.flipbook.png", grid=4, rate=12, life=(0.12, 0.2), size=[(0, 3.5), (1, 5)], color=BOLTC, le=1, br=7,
        locked=True, at=(0, 0.6, 0), box=(2, 1.2, 3.6)), rng)
emitter("AscGlow", o, dict(tex="Dot.png", rate=4, life=(0.6, 0.8), size=[(0, 10), (1, 10)], transparency=[(0, 0.7), (0.5, 0.55), (1, 1)],
        color=GOLDEN, le=1, br=1.5, orient="flat", locked=True, at=(0, -1.24, 0)), rng)
emitter("AscShockwave", o, dict(tex="Ring.png", rate=0.8, life=(0.7, 0.7), size=[(0, 4), (1, 14)], transparency=[(0, 0.2), (1, 1)],
        color=GOLDEN, le=1, br=3, orient="flat", locked=True, at=(0, -1.25, 0)), rng)
emitter("AscDebris", o, dict(tex="Shard.png", rate=8, life=(1.2, 2), speed=(1.5, 3), spread=20, size=[(0, 0.5), (1, 0.3)],
        transparency=[(0, 0), (0.8, 0), (1, 1)], color=lin((90, 85, 80)), le=0, br=1, locked=True, ring=(3.5, 5), at=(0, -1.1, 0)), rng)
emitter("AscDust", o, dict(tex="VoidWisp.flipbook.png", grid=4, rate=8, life=(0.8, 1.2), speed=(2, 4), spread=60, size=[(0, 1.5), (1, 3.5)],
        transparency=[(0, 0.5), (1, 1)], color=lin((170, 160, 150)), le=0, br=1, ring=(3, 4.5), at=(0, -1.1, 0)), rng)
emitter("AscSparkles", o, dict(tex="Glint.png", rate=25, life=(0.5, 1), size=[(0, 0), (0.3, 0.7), (1, 0)], color=WHITEGOLD, le=1, br=4,
        locked=True, at=(0, 0.8, 0), box=(2.2, 1.6, 3.8)), rng)

# ---------------------------------------------------------------- ground, light, camera
box("Road", (14, -40, -0.05), (140, 140, 0.1), simple_mat("Road", lin((120, 130, 150))))
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(40), 0, math.radians(30))
scene.collection.objects.link(sun)
world = scene.world or bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.45, 0.62, 0.85, 1)
bg.inputs["Strength"].default_value = 0.9

def bloom():
    """Compositor glare as a stand-in for Roblox Bloom (Threshold 2, Intensity 1, Size 24)."""
    try:
        tree = bpy.data.node_groups.new("TrailBloom", "CompositorNodeTree")
        scene.compositing_node_group = tree
        rl = tree.nodes.new("CompositorNodeRLayers")
        glare = tree.nodes.new("CompositorNodeGlare")
        out = tree.nodes.new("NodeGroupOutput")
        tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        tree.links.new(rl.outputs["Image"], glare.inputs[0])
        tree.links.new(glare.outputs[0], out.inputs[0])
        for key, value in (("glare_type", "BLOOM"), ("threshold", 0.9), ("size", 7), ("mix", 0.0)):
            if hasattr(glare, key):
                try:
                    setattr(glare, key, value)
                except TypeError:
                    pass
        for name, value in (("Threshold", 0.9), ("Strength", 0.7), ("Size", 0.6)):
            if name in glare.inputs:
                glare.inputs[name].default_value = value
        return "bloom on"
    except Exception as err:  # older/newer compositor API: the draft still works without bloom
        return f"bloom skipped: {err}"


print(bloom())

SHOTS = {  # name: (camera location, look-at, lens)
    "overview": ((8, 48, 34), (8, -25, 0), 24),
    "rainbow": ((-30, 16, 9), (-36, -30, 0), 30),
    "solar": ((-10, 16, 9), (-16, -30, 0), 30),
    "void": ((10, 16, 9), (4, -30, 0), 30),
    "auras": ((40, 30, 12), (40, -2, 1), 30),
    "ascended": ((80, 16, 7), (72, 0, 2), 32),
}


def shot(name):
    loc, look, lens = SHOTS[name]
    CAM.location = loc
    CAM.rotation_euler = (mathutils.Vector(look) - mathutils.Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    CAM.data.lens = lens
    bpy.context.view_layer.update()


shot("overview")
print("built", len(bpy.data.objects), "objects")
