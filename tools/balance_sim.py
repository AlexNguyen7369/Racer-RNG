#!/usr/bin/env python3
"""Balance model for World 1 / World 2 pacing (docs/WORLDS_SPEC.md, owner 2026-10-27).

One average free player auto-races the whole time (no workshop, no upgrade tree, no stat points, no potions, no
Robux): Speed gain = GAIN_PER_SECOND x rebirth x aura x trail, XP/s = rebirth x aura x trail, cruise =
min(curve(Speed) x damped best-car multi, MAX_CRUISE). A track is won when cruise > its NPC speed (both hold a
fixed speed on the rail). Each lap drives tracks 1..best winnable, cashes out their payouts, buys the next aura /
trail it can afford, and rebirths as soon as the level allows. Rebirth resets Money, Speed, Level and XP.

Formulas mirror src/shared/{RaceConfig,LevelConfig,RebirthConfig,PayoutCurve,MarketConfig,NpcConfig}.luau.
Usage: python3 tools/balance_sim.py [--fit]   (--fit searches the placeholder knobs for the hour targets)
"""
import glob
import math
import re
import sys

MAX_CRUISE = 800  # RaceConfig.MAX_CRUISE
GAIN_PER_SECOND = 2
TOTALS = [1, 1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7.5, 10, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11]
REBIRTH_LEVELS = [15, 25, 40, 60, 75, 100, 125, 150, 175, 200, 225, 260, 300, 340, 380, 420, 465, 510, 560, 600]
ROLL_INTERVAL, TURBO_EVERY, TURBO_LUCK = 3, 10, 10
RESTART_SECONDS = 5  # loser screen / cash-out / restart overhead per lap
W1_LENGTHS = [560, 1120, 320, 900, 600, 1200, 1400, 1360, 1566, 1230]  # straights only, studs
W2_LENGTHS = [30000 + 30000 * i / 9 for i in range(10)]  # WORLDS_SPEC section 6
TARGET_HOURS = {1: 30, 2: 35}

DEFAULTS = {
    "w1_npc_base": 16, "w1_npc_growth": 1.51,
    "w2_npc_base": 160, "w2_npc_growth": 1.18,
    "w1_half_stat": 1e4, "w2_half_stat": 1e12,
    "w1_base": 10, "w1_max_speed": 88, "w2_base": 150, "w2_max_speed": 300,
    "xp_linear": 122, "xp_knee": 225, "xp_decade": 37.2,  # owner 2026-10-28
}


def load_cars():
    cars = []
    for path in glob.glob("src/shared/Cars/*.luau"):
        text = open(path).read()
        c = re.search(r"\n\tChance = ([0-9.e]+),", text)
        m = re.search(r"\n\tSpeedMulti = ([0-9.e]+),", text)
        if c and m:
            cars.append((float(c.group(1)), float(m.group(1))))
    return sorted(cars)


def ratio(n):
    r = 1.0
    for k in range(2, n + 1):
        r *= (10, 7.5)[(k - 2) % 2]
    return r


def nice(x):
    unit = 10 ** (math.floor(math.log10(x)) - 1)
    return math.floor(x / unit + 0.5) * unit


def cost(base, step):
    return nice(base * ratio(step) ** 1.5)


SHOP = sorted(
    [(cost(2500, k + 1), "aura", m) for k, m in enumerate([1.2, 2, 3])]
    + [(cost(500, k + 1), "trail", m) for k, m in enumerate([1.5, 2, 3, 4, 5])]
)


def cruise(stat, car, half, lo=10, ref=88):
    rng = ref - lo
    if stat <= half:
        base = lo + rng * stat / half
    else:
        base = ref + rng / 2 * math.log2(1 + (stat - half) / half)
    damped = min(max(1 + math.log10(car), 0.1), 1.5)
    return min(base * damped, MAX_CRUISE)


def xp_to_next(level, p):
    if level <= p["xp_knee"]:
        return p["xp_linear"] * level
    return p["xp_linear"] * p["xp_knee"] * 10 ** ((level - p["xp_knee"]) / p["xp_decade"])


def simulate(p, verbose=False):
    cars = load_cars()
    t, rebirth, money, speed, level, xp, aura, trail = 0.0, 0, 0.0, 0.0, 1, 0.0, 1, 1
    best_car, world, best, lap_left, lap_cash, lap_k = 1.1, 1, 0, 0.0, 0.0, 0
    done, rows, next_row, step = {}, [], 0, 20.0
    car_i = 0  # cars sorted by chance: own every car whose expected hits over all rolls so far reach 1
    luck_rolls = 0.0
    while t < 300 * 3600:
        w = world
        lengths = W1_LENGTHS if w == 1 else W2_LENGTHS
        base, growth = p[f"w{w}_npc_base"], p[f"w{w}_npc_growth"]
        c = cruise(speed, best_car, p[f"w{w}_half_stat"], p[f"w{w}_base"], p[f"w{w}_max_speed"])
        if lap_left <= 0:  # start a lap: drive every track the cruise beats (or lose on the first one)
            k = 0
            while k < 10 and c > base * growth ** k:
                k += 1
            best = max(best, k)
            lap_k = k
            lap_left = sum(lengths[: max(k, 1)]) + RESTART_SECONDS * c
            offset = 0 if w == 1 else 10
            lap_cash = sum(100 * ratio(offset + i + 1) for i in range(k))
        dt = min(step, lap_left / c)
        lap_left -= c * dt
        multi = TOTALS[rebirth] * aura * trail
        speed += GAIN_PER_SECOND * multi * dt
        xp += multi * dt
        while xp >= xp_to_next(level, p):
            xp -= xp_to_next(level, p)
            level += 1
        if lap_left <= 1e-6:
            lap_left = 0.0
            money += lap_cash
            for price, kind, m in SHOP:
                if m > (aura if kind == "aura" else trail) and money >= price:
                    money -= price
                    if kind == "aura":
                        aura = m
                    else:
                        trail = m
        luck_rolls += dt / ROLL_INTERVAL * TOTALS[rebirth] * (1 + (TURBO_LUCK - 1) / TURBO_EVERY)
        while car_i < len(cars) and cars[car_i][0] <= luck_rolls:
            best_car = max(best_car, cars[car_i][1])
            car_i += 1
        t += dt
        if verbose and t >= next_row:
            rows.append((t / 3600, w, rebirth, level, speed, c, best, money, aura * trail, best_car))
            next_row += 3600
        cap = 10 if w == 1 else 20
        if rebirth < cap and level >= REBIRTH_LEVELS[rebirth]:
            rebirth += 1
            money = speed = xp = 0.0
            level, lap_left = 1, 0.0
        if w == 1 and best >= 10 and "w1_track10" not in done:
            done["w1_track10"] = t / 3600
        if w == 1 and rebirth >= 10 and "w1_rebirth10" not in done:
            done["w1_rebirth10"] = t / 3600
        if w == 1 and rebirth >= 10 and best >= 10:
            done[1] = t / 3600
            world, speed, level, xp, best, lap_left = 2, 0.0, 1, 0.0, 0, 0.0
        if w == 2 and best >= 10 and "w2_track10" not in done:
            done["w2_track10"] = t / 3600 - done[1]
        if w == 2 and rebirth >= 20 and "w2_rebirth20" not in done:
            done["w2_rebirth20"] = t / 3600 - done[1]
        if w == 2 and rebirth >= 20 and best >= 10:
            done[2] = t / 3600 - done[1]
            break
    return done, rows


def fit():
    p = dict(DEFAULTS)
    knobs = (("xp_linear", "w1_rebirth10", 1, 0.5, 1000.0, False),
             ("xp_decade", "w2_rebirth20", 2, 2.0, 400.0, True),
             ("w2_half_stat", "w2_track10", 2, 1e4, 1e30, False))
    for key, metric, world, lo, hi, bigger_is_faster in knobs:
        for _ in range(40):
            mid = (lo * hi) ** 0.5
            p[key] = mid
            got = simulate(p)[0].get(metric, 1e9)
            faster = got < TARGET_HOURS[world]
            # a slower knob value lengthens the time: grow xp_linear / half_stat, shrink xp_decade
            if faster != bigger_is_faster:
                lo = mid
            else:
                hi = mid
        p[key] = float("%.3g" % ((lo * hi) ** 0.5))
    return p


def main():
    p = fit() if "--fit" in sys.argv else dict(DEFAULTS)
    done, rows = simulate(p, verbose=True)
    print("params:", {k: v for k, v in p.items()})
    print("hours:", {k: round(v, 1) for k, v in done.items()}, "targets:", TARGET_HOURS)
    print("%5s %2s %3s %5s %10s %7s %4s %10s %8s %7s" % ("hour", "W", "RB", "level", "speed", "cruise", "best", "money", "auraxtr", "car"))
    for h, w, rb, lv, sp, c, k, mo, at, car in rows:
        print("%5.0f %2d %3d %5d %10.3g %7.0f %4d %10.3g %8.3g %7.3g" % (h, w, rb, lv, sp, c, k, mo, at, car))


if __name__ == "__main__":
    main()
