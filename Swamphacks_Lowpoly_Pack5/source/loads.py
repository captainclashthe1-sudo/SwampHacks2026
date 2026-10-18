"""Swappable truck loads. Each load's origin is the centre of the truck bed floor, so a load
sits correctly when its origin is placed at BED_POINT on a truck. Footprint stays inside the bed
(x +-0.88, y +-0.95) so nothing pokes through the bed walls or tailgate."""
import math, random
import bmesh
import build as B
from build import new_bm, L, paint, merge, xform, box, cyl, ico, root, mk

C = B.C
BED_POINT = (0.0, -1.56, 0.85)     # truck-local bed floor centre (meters, Blender axes)
LOADS = ["Load_Crates", "Load_Barrels", "Load_Logs", "Load_Hay", "Load_Apples"]


def register_colors():
    for n, hx in [("hay", "E9C865"), ("hay_dark", "C9A545"), ("crate", "D69A5C"), ("crate_dark", "9C6436")]:
        if n not in C:
            B.PALETTE.append((n, hx))
            C[n] = len(B.PALETTE) - 1


def crate(s, loc, rz=0.0, open_top=False):
    """Wooden crate with dark edge frame and X braces, like the reference props."""
    h = s / 2
    t = 0.07 * s
    parts = []
    if open_top:
        wall = 0.05 * s
        parts += [box((s, s, wall), (0, 0, wall / 2), C["crate"]),
                  box((s, wall, s * 0.8), (0, -h + wall / 2, s * 0.4), C["crate"]),
                  box((s, wall, s * 0.8), (0, h - wall / 2, s * 0.4), C["crate"]),
                  box((wall, s - 2 * wall, s * 0.8), (-h + wall / 2, 0, s * 0.4), C["crate"]),
                  box((wall, s - 2 * wall, s * 0.8), (h - wall / 2, 0, s * 0.4), C["crate"])]
        top = s * 0.8
    else:
        parts.append(box((s, s, s), (0, 0, h), C["crate"]))
        top = s
    # frame: vertical posts + top/bottom rims
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box((t, t, top), (sx * (h - t / 2 + 0.01), sy * (h - t / 2 + 0.01), top / 2), C["crate_dark"]))
    for z in (t / 2, top - t / 2):
        for sy in (-1, 1):
            parts.append(box((s + 0.02, t, t), (0, sy * (h + 0.005), z), C["crate_dark"]))
        for sx in (-1, 1):
            parts.append(box((t, s + 0.02, t), (sx * (h + 0.005), 0, z), C["crate_dark"]))
    diag = math.hypot(s - 2 * t, top - 2 * t)
    ang = math.atan2(top - 2 * t, s - 2 * t)
    for sy in (-1, 1):
        parts.append(box((diag, t * 0.8, t), (0, sy * (h + 0.012), top / 2), C["crate_dark"], rot=(0, -ang * sy, 0)))
    for sx in (-1, 1):
        parts.append(box((t * 0.8, diag, t), (sx * (h + 0.012), 0, top / 2), C["crate_dark"], rot=(ang * sx, 0, 0)))
    bm = merge(*parts)
    return xform(bm, loc, rot=(0, 0, rz))


def barrel(loc, r=0.27, h=0.78, rz=0.0):
    parts = [cyl(r * 0.88, r, h * 0.5, 8, C["trunk"], loc=(0, 0, 0)),
             cyl(r, r * 0.88, h * 0.5, 8, C["trunk"], loc=(0, 0, h * 0.5)),
             cyl(r * 0.84, r * 0.84, 0.03, 8, C["wood"], loc=(0, 0, h - 0.01))]
    for z in (0.1, h - 0.14):
        rr = r * 0.92 + 0.012
        parts.append(cyl(rr, rr, 0.06, 8, C["rim"], loc=(0, 0, z)))
    parts.append(cyl(r + 0.012, r + 0.012, 0.05, 8, C["rim"], loc=(0, 0, h * 0.5 - 0.025)))
    return xform(merge(*parts), loc, rot=(0, 0, rz))


def build_load_crates(name):
    r = root(name)
    parts = [crate(0.84, (sx * 0.44, sy * 0.47, 0)) for sx in (-1, 1) for sy in (-1, 1)]
    parts.append(crate(0.74, (0.05, -0.05, 0.84), rz=0.25))
    mk(f"{name}_Mesh", merge(*parts), r)
    return r


def build_load_barrels(name):
    r = root(name)
    parts = [barrel((sx * 0.44, y, 0), rz=y) for sx in (-1, 1) for y in (-0.62, 0.0, 0.62)]
    mk(f"{name}_Mesh", merge(*parts), r)
    return r


def build_load_logs(name, seed=3):
    rng = random.Random(seed)
    r = root(name)
    parts = []
    rad = 0.19
    rows = [(4, 0), (3, 1), (2, 2)]
    for n, k in rows:
        z = rad + k * rad * 1.72
        for i in range(n):
            x = (i - (n - 1) / 2) * rad * 2.02
            ln = rng.uniform(1.72, 1.86)
            log = cyl(rad * rng.uniform(0.9, 1.0), rad, ln, 7, C["trunk"], rot=(math.pi / 2, 0, 0), centered=True,
                      spin=rng.uniform(0, 1))
            log.normal_update()
            for f in log.faces:
                if abs(f.normal.y) > 0.9:
                    f[L(log)] = C["wood"]           # cut ends show pale wood
            parts.append(xform(log, (x, rng.uniform(-0.03, 0.03), z)))
    for y in (-0.6, 0.6):                           # side stakes hold the pile in
        for sx in (-1, 1):
            parts.append(box((0.07, 0.07, 1.05), (sx * 0.84, y, 0.52), C["trim"]))
    mk(f"{name}_Mesh", merge(*parts), r)
    return r


def bale(loc, rz=0.0):
    w, d, h = 0.84, 0.92, 0.5
    parts = [box((w, d, h), (0, 0, h / 2), C["hay"], bev=0.04)]
    for y in (-d / 4, d / 4):
        parts.append(box((w + 0.02, 0.05, h + 0.02), (0, y, h / 2), C["hay_dark"]))
    # a few straw tufts so it doesn't read as a plain block
    for sx, sy in ((-0.3, -0.35), (0.25, 0.3), (0.1, -0.1)):
        parts.append(box((0.12, 0.06, 0.05), (sx, sy, h + 0.02), C["hay_dark"], rot=(0, 0, sx * 3)))
    return xform(merge(*parts), loc, rot=(0, 0, rz))


def build_load_hay(name):
    r = root(name)
    parts = [bale((sx * 0.44, sy * 0.47, 0)) for sx in (-1, 1) for sy in (-1, 1)]
    parts += [bale((0.0, -0.46, 0.5), rz=math.pi / 2), bale((0.0, 0.48, 0.5), rz=math.pi / 2 + 0.08)]
    mk(f"{name}_Mesh", merge(*parts), r)
    return r


def build_load_apples(name, seed=9):
    rng = random.Random(seed)
    r = root(name)
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * 0.44, sy * 0.47
            parts.append(crate(0.84, (cx, cy, 0), open_top=True))
            green = (sx + sy) == 0
            for i in range(4):
                for j in range(4):
                    ax = cx + (i - 1.5) * 0.18 + rng.uniform(-0.02, 0.02)
                    ay = cy + (j - 1.5) * 0.18 + rng.uniform(-0.02, 0.02)
                    az = 0.62 + rng.uniform(0, 0.06) + (0.04 if 0 < i < 3 and 0 < j < 3 else 0)
                    col = C["apple_green"] if green else C["apple_red"]
                    if rng.random() < 0.25:
                        col = C["apple_green_dark"] if green else C["apple_red_dark"]
                    parts.append(ico(0.095, col, (ax, ay, az), scale=(1, 1, 0.9), sub=1, jit=0.08, rng=rng))
    mk(f"{name}_Mesh", merge(*parts), r)
    return r


def build_all():
    build_load_crates("Load_Crates")
    build_load_barrels("Load_Barrels")
    build_load_logs("Load_Logs")
    build_load_hay("Load_Hay")
    build_load_apples("Load_Apples")
