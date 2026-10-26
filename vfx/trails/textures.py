# Draft textures for the Rainbow Trail and Void Trail redesign (2026-10-26).
# Trail textures are vertical strips: image top = trail head (at the car), left edge = Attachment0.
# Run: python3 vfx/trails/textures.py  -> vfx/trails/out/*.png
import colorsys
import os
import sys

import numpy

sys.path.insert(0, os.path.expanduser("~/.claude/skills/roblox-vfx/scripts"))
import vfxtex as vt

vt.OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")

STREAKS = vt.tex_noise(256, scale=8, octaves=3, seed=11)
TEAR = vt.tex_noise(256, scale=5, octaves=5, seed=21)
HOLES = vt.tex_noise(256, scale=6, octaves=4, seed=31)


# Rainbow ribbon: six hue bands across the width (baked colour), soft outer rims,
# streaks running back from the head that thin out toward the tail.
def rainbow(size):
    x, y = vt.tex_coords(size)
    u = (x + 1) / 2  # 0 at Attachment0, 1 at Attachment1
    tail = (1 - y) / 2  # 0 at the head, 1 at the tail
    bands = 6
    k = numpy.clip(u * bands, 0, bands - 1e-3)
    i = numpy.floor(k)
    blend = numpy.clip((k - i - 0.85) / 0.15, 0, 1)  # thin soft seam between bands
    hues = [0.0, 0.08, 0.15, 0.33, 0.55, 0.78]
    rgb = numpy.zeros((size, size, 3), dtype=numpy.float32)
    for n, h in enumerate(hues):
        nxt = hues[min(n + 1, bands - 1)]
        c0 = numpy.array(colorsys.hsv_to_rgb(h, 0.85, 1.0))
        c1 = numpy.array(colorsys.hsv_to_rgb(nxt, 0.85, 1.0))
        mask = (i == n)[..., None]
        rgb += mask * (c0 * (1 - blend[..., None]) + c1 * blend[..., None])
    rim = numpy.clip(1 - numpy.abs(x) ** 6, 0, 1)
    streak = vt.tex_sample(STREAKS, u * 3.0, tail * 0.35)  # long streaks along the length
    alpha = rim * numpy.clip(1.25 - tail * 0.9 - (streak - 0.5) * 1.6 * tail, 0, 1)
    return numpy.concatenate([rgb, alpha[..., None]], axis=-1)


# Thin hot core streak (white, tinted by Color): a bright line that splits into strands at the tail.
def core_streak(size):
    x, y = vt.tex_coords(size)
    tail = (1 - y) / 2
    wx, _ = vt.tex_warp(x, y, amount=0.05 * tail, scale=4, seed=3)
    line = numpy.exp(-(wx / (0.12 + 0.25 * tail)) ** 2)
    strands = vt.tex_sample(STREAKS, (x + 1) * 2.5, tail * 0.25)
    return numpy.clip(line * (1.1 - tail * 0.6) * (0.55 + strands * 0.9), 0, 1)


# Four-point glint (light): equal straight arms fading to the tips, one hot core, faint halo.
def glint(size):
    x, y = vt.tex_coords(size)
    r = numpy.hypot(x, y)

    def arm(along, across, length, width):
        fade = numpy.clip(1 - numpy.abs(along) / length, 0, 1)
        return numpy.exp(-((across / (width * fade + 1e-4)) ** 2)) * fade**1.5

    rays = numpy.maximum(arm(y, x, 0.95, 0.035), arm(x, y, 0.95, 0.035))
    return numpy.clip(rays + numpy.exp(-((r / 0.07) ** 2)) + 0.3 * numpy.exp(-((r / 0.3) ** 2)), 0, 1)


# Void wake (drawn matter, white -> tinted near-black): torn ragged rims that eat inward
# toward the tail, and holes that open as the wake ages.
def void_wake(size):
    x, y = vt.tex_coords(size)
    tail = (1 - y) / 2
    u = (x + 1) / 2
    rag = vt.tex_sample(TEAR, u * 0.5, tail * 1.5) - 0.5
    half = 0.9 - 0.5 * tail + rag * (0.3 + 0.6 * tail)
    body = half - numpy.abs(x)
    holes = vt.tex_sample(HOLES, u * 1.2, tail * 1.1) - tail * 1.1 + 0.42
    return vt.tex_edge(body, soft=0.01) * vt.tex_edge(holes, soft=0.02)


# Neon crackle edge: a jagged electric line down the strip, broken into segments (tiles with Wrap).
def crackle(size):
    x, y = vt.tex_coords(size)
    v = (y + 1) / 2
    zig = (vt.tex_sample(TEAR, 0.13, v * 1.5) - 0.5) * 0.7 + (vt.tex_sample(STREAKS, 0.4, v * 6.0) - 0.5) * 0.25
    d = numpy.abs(x - zig)
    line = numpy.exp(-((d / 0.09) ** 2)) + 0.35 * numpy.exp(-((d / 0.3) ** 2))
    gaps = vt.tex_edge(vt.tex_sample(HOLES, 0.7, v * 4.0) - 0.38, soft=0.02)
    return numpy.clip(line * gaps, 0, 1)


# Void wisp flipbook: a lumpy two-tone puff that swells, then tears into pieces and is gone.
def wisp(t, size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.1, scale=4, seed=8, t=t * 0.4)
    radius = 0.2 + 0.4 * vt.tex_ease(t * 2.0)
    body = vt.tex_blob(wx, wy, radius=radius, lumps=8, roughness=0.8, seed=12)
    lit = vt.tex_blob(wx + 0.12, wy - 0.12, radius=radius, lumps=8, roughness=0.8, seed=12)
    holes = vt.tex_sample(HOLES, x * 0.5 + 0.3, y * 0.5 + t * 0.25) - t * 1.3 + 0.62
    alpha = vt.tex_edge(body, soft=0.006) * vt.tex_edge(holes + body * 0.4, soft=0.01)
    return alpha, 0.55 + 0.45 * vt.tex_edge(lit, 0.03, soft=0.006)


# Soft band (light): a wide falloff across the strip that fades toward the tail; the glow under the void wake.
def soft_band(size):
    x, y = vt.tex_coords(size)
    tail = (1 - y) / 2
    return numpy.clip(numpy.exp(-((x / 0.55) ** 2)) * (1 - tail**1.5), 0, 1)


vt.draw_texture("SoftBand", soft_band, size=256)
vt.draw_texture("RainbowRibbon", rainbow, size=512)
vt.draw_texture("CoreStreak", core_streak, size=256)
vt.draw_texture("Glint", glint, size=256)
vt.draw_texture("VoidWake", void_wake, size=512)
vt.draw_texture("VoidCrackle", crackle, size=256)
vt.draw_flipbook("VoidWisp", wisp, grid=4, fps=16)


# ---- round 2 (owner 2026-10-26: longer, more flamboyant trails; solar trail and auras too) ----

# Flame tongue flipbook (drawn, two tones): a lopsided tongue that licks up, then splits and burns out.
def flame(t, size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.14, scale=3, seed=51, t=t * 0.8)
    grow = 0.4 + 0.6 * vt.tex_ease(t * 2.5)
    ry = numpy.clip((wy + 0.85) / (1.6 * grow), 0, 1)  # 0 at the base, 1 at the tip
    half = 0.72 * numpy.sin(numpy.pi * numpy.clip(ry * 0.85 + 0.15, 0, 1)) ** 0.6 * (1 - ry) ** 0.35 * (1 - 0.35 * t)
    body = numpy.where(ry < 1, half - numpy.abs(wx + 0.12 * ry**2 * numpy.sin(t * 6)), -1)
    core = half * 0.5 - numpy.abs(wx) - 0.04
    holes = vt.tex_sample(HOLES, x * 0.6 + 0.5, y * 0.6 - t * 0.6) - t * 1.35 + 0.75
    alpha = vt.tex_edge(body, soft=0.006) * vt.tex_edge(holes + body, soft=0.01)
    return alpha, 0.6 + 0.4 * vt.tex_edge(core, soft=0.01)


# Spark streak (light): a long thin streak with a hot head at the image top (VelocityParallel, Rotation -90).
def spark(size):
    x, y = vt.tex_coords(size)
    along = numpy.clip((y + 1) / 2, 0, 1)  # 1 at the head
    return numpy.clip(numpy.exp(-((x / (0.03 + 0.07 * along)) ** 2)) * along**1.5 + numpy.exp(-((x**2 + (y - 0.75) ** 2) / 0.02)), 0, 1)


# Shock ring (light): one thin bright ring with a soft halo; symmetric, it is light.
def ring(size):
    x, y = vt.tex_coords(size)
    r = numpy.hypot(x, y)
    return numpy.clip(numpy.exp(-(((r - 0.78) / 0.035) ** 2)) + 0.35 * numpy.exp(-(((r - 0.72) / 0.16) ** 2)), 0, 1)


# Rune ring (symbol, precise): two rings, ticks and dots, for the galaxy aura's turning sigil.
def rune_ring(size):
    x, y = vt.tex_coords(size)
    r, a = vt.tex_polar(x, y)
    rings = numpy.maximum(0.02 - numpy.abs(r - 0.9), 0.012 - numpy.abs(r - 0.7))
    tick = numpy.minimum(0.018 - numpy.abs(((a / (2 * numpy.pi) * 24) % 1 - 0.5) * r * 0.26), 0.09 - numpy.abs(r - 0.8))
    da = (a / (2 * numpy.pi) * 6) % 1 - 0.5
    dots = 0.045 - numpy.hypot(da * r * 1.05, r - 0.58)
    return vt.tex_edge(numpy.maximum(numpy.maximum(rings, tick), dots), soft=0.004)


# Lightning flipbook (light): a jagged bolt across the cell with one fork, re-drawn each frame, flickering out.
def bolt(t, size):
    rng = numpy.random.default_rng(int(t * 97) + 5)
    x, y = vt.tex_coords(size)
    pts = [(-0.85, rng.uniform(-0.2, 0.2))]
    for i in range(1, 8):
        pts.append((-0.85 + i * 0.243, pts[-1][1] * 0.5 + rng.uniform(-0.32, 0.32)))
    d = numpy.full(x.shape, 9.0, dtype=numpy.float32)
    def seg(p, q):
        px, py, qx, qy = p[0], p[1], q[0], q[1]
        vx, vy = qx - px, qy - py
        h = numpy.clip(((x - px) * vx + (y - py) * vy) / (vx * vx + vy * vy), 0, 1)
        return numpy.hypot(x - px - vx * h, y - py - vy * h)
    for p, q in zip(pts, pts[1:]):
        d = numpy.minimum(d, seg(p, q))
    k = rng.integers(2, 5)
    fork = (pts[k][0] + 0.35, pts[k][1] + rng.choice([-1, 1]) * 0.45)
    d = numpy.minimum(d, seg(pts[k], fork) + 0.01)
    on = 1.0 if t < 0.75 else 1.0 - (t - 0.75) * 4
    return numpy.clip((numpy.exp(-((d / 0.018) ** 2)) + 0.4 * numpy.exp(-((d / 0.09) ** 2))) * on, 0, 1)


# Void shard (drawn): a crisp lopsided blade, point up.
def shard(size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.03, scale=4, seed=61)
    ry = (wy + 0.9) / 1.8
    half = numpy.where(ry < 0.3, 0.2 * ry / 0.3, 0.2 * numpy.clip(1 - (ry - 0.3) / 0.7, 0, 1) ** 1.3)
    body = numpy.where((ry > 0) & (ry < 1), half - numpy.abs(wx - 0.05 * (ry - 0.3)), -1)
    return vt.tex_edge(body, soft=0.005), 0.55 + 0.45 * (wx > 0.0)


# Solar plasma ribbon (trail strip, two tones): hot core, flame licks along both rims, tearing at the tail.
def plasma(size):
    x, y = vt.tex_coords(size)
    tail = (1 - y) / 2
    lick = vt.tex_sample(STREAKS, (x + 1) * 0.8, tail * 1.6) - 0.5
    half = 0.75 - 0.25 * tail + lick * (0.5 + 0.4 * tail)
    body = half - numpy.abs(x)
    holes = vt.tex_sample(TEAR, (x + 1) * 0.7, tail * 2.0) - tail * 1.0 + 0.55
    alpha = vt.tex_edge(body, soft=0.02) * vt.tex_edge(holes, soft=0.03)
    core = numpy.exp(-((x / (0.28 - 0.15 * tail)) ** 2))
    return alpha, numpy.clip(0.45 + 0.55 * core, 0, 1)


# Nebula puff (light): a soft lopsided cloud with baked pin-prick stars.
def nebula(size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.25, scale=2, seed=72)
    cloud = numpy.clip(1 - numpy.hypot(wx, wy * 1.3), 0, 1) ** 1.5 * (0.5 + vt.tex_sample(TEAR, x * 0.5, y * 0.5))
    rng = numpy.random.default_rng(73)
    stars = numpy.zeros_like(x)
    for sx, sy, b in zip(rng.uniform(-0.8, 0.8, 28), rng.uniform(-0.8, 0.8, 28), rng.uniform(0.4, 1, 28)):
        stars += b * numpy.exp(-((x - sx) ** 2 + (y - sy) ** 2) / 0.00012)  # pin-prick stars
    return numpy.clip(cloud * 0.75 + stars, 0, 1)


# Soft dot (light): plain round glow for dust and embers.
def dot(size):
    x, y = vt.tex_coords(size)
    return numpy.exp(-((numpy.hypot(x, y) / 0.38) ** 2))


vt.draw_flipbook("Flame", flame, grid=4, fps=20)
vt.draw_flipbook("Bolt", bolt, grid=4, fps=24)
vt.draw_texture("Spark", spark, size=128)
vt.draw_texture("Ring", ring, size=512)
vt.draw_texture("RuneRing", rune_ring, size=512)
vt.draw_texture("Shard", shard, size=256)
vt.draw_texture("Plasma", plasma, size=512)
vt.draw_texture("Nebula", nebula, size=256)
vt.draw_texture("Dot", dot, size=64)
