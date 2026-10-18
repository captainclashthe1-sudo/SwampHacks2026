"""Low-poly buildings. Every building: origin at ground centre, front door faces -Y (local).
Footprints (x by y, meters) are in FOOT so a map can reserve flat lots for them.
"""
import math, random
import bmesh
from mathutils import Vector
import build as B
from build import new_bm, L, paint, merge, xform, bevel, box, cyl, frustum, prism_x, root, mk

C = B.C
FOOT = {"House_Cottage": (9.2, 8.4), "House_TwoStory": (7.6, 8.6), "Shop_Corner": (10.4, 9.8),
        "Apartment_Block": (12.4, 11.4), "Office_Tower": (12.6, 12.6), "Gas_Station": (18.0, 17.0),
        "Lighthouse": (8.0, 8.0)}


def register_colors():
    for n, hx in [("wall_cream", "F2E4C4"), ("wall_mint", "A3D6BE"), ("wall_peach", "F3B08A"),
                  ("wall_blue", "93B9DF"), ("roof_red", "B04A3C"), ("roof_slate", "4D5868"),
                  ("brick", "B85A42"), ("office_glass", "5B9BCB"), ("glass_light", "4E7FA8"),
                  ("sign_teal", "2BA39B")]:
        if n not in C:
            B.PALETTE.append((n, hx))
            C[n] = len(B.PALETTE) - 1


# ------------------------------------------------------------------ pieces
def windows(parts, side, plane, centers, z, ww, wh, rng=None, frame=None, glass=None):
    """Windows on one wall. side in S(-y) N(+y) W(-x) E(+x); centers run along the wall."""
    frame = C["white"] if frame is None else frame
    for a in centers:
        g = glass if glass is not None else (C["glass_light"] if rng and rng.random() < 0.3 else C["glass"])
        if side in "SN":
            s = -1 if side == "S" else 1
            y = plane + s * 0.02
            parts += [box((ww, 0.12, wh), (a, y, z), g),
                      box((ww + 0.3, 0.22, 0.10), (a, plane + s * 0.08, z - wh / 2 - 0.05), frame),
                      box((ww + 0.2, 0.16, 0.10), (a, plane + s * 0.05, z + wh / 2 + 0.05), frame)]
        else:
            s = -1 if side == "W" else 1
            x = plane + s * 0.02
            parts += [box((0.12, ww, wh), (x, a, z), g),
                      box((0.22, ww + 0.3, 0.10), (plane + s * 0.08, a, z - wh / 2 - 0.05), frame),
                      box((0.16, ww + 0.2, 0.10), (plane + s * 0.05, a, z + wh / 2 + 0.05), frame)]


def spread(length, n, margin=1.0):
    if n == 1:
        return [0.0]
    step = (length - 2 * margin) / (n - 1)
    return [-length / 2 + margin + i * step for i in range(n)]


def parapet(parts, w, d, z, h=0.6, t=0.25, cid=None):
    cid = C["concrete"] if cid is None else cid
    parts += [box((w, t, h), (0, -d / 2 + t / 2, z + h / 2), cid), box((w, t, h), (0, d / 2 - t / 2, z + h / 2), cid),
              box((t, d - 2 * t - 0.02, h), (-w / 2 + t / 2, 0, z + h / 2), cid),
              box((t, d - 2 * t - 0.02, h), (w / 2 - t / 2, 0, z + h / 2), cid)]


def gable_shell(w, d, h, rise, wall, roof, z0=0.4):
    """Walls + gable ends + two roof slabs, ridge along X. Returns list of bmeshes."""
    parts = [box((w + 0.4, d + 0.4, z0), (0, 0, z0 / 2), C["concrete"]),
             box((w, d, h), (0, 0, z0 + h / 2), wall)]
    top = z0 + h
    parts.append(prism_x([(-d / 2, top), (d / 2, top), (0, top + rise)], -w / 2, w / 2, wall))
    slope = math.hypot(d / 2, rise)
    ang = math.atan2(rise, d / 2)
    over = 0.5
    L_ = slope + over
    for s in (-1, 1):
        # slab centre: midpoint of the slope pushed outward by half the overhang and lifted off the wall
        mid = Vector((0, s * d / 4, top + rise / 2))
        down = Vector((0, s * (d / 2) / slope, -rise / slope))
        nrm = Vector((0, s * rise / slope, (d / 2) / slope))
        c = mid + down * (over / 2) + nrm * 0.12
        parts.append(box((w + 0.8, L_, 0.22), tuple(c), roof, rot=(-s * ang, 0, 0)))
    parts.append(box((w + 0.9, 0.35, 0.3), (0, 0, top + rise + 0.05), roof))
    return parts


# ------------------------------------------------------------------ buildings
def build_house_cottage(name, wall="wall_mint", roof="roof_red", seed=1):
    rng = random.Random(seed)
    r = root(name)
    w, d, h = 8.4, 7.0, 3.1
    parts = gable_shell(w, d, h, 2.3, C[wall], C[roof])
    zc = 0.4 + 1.6
    # front: door + porch + two windows
    parts += [box((1.15, 0.14, 2.15), (1.6, -d / 2 - 0.03, 0.4 + 1.07), C["wood_dark"]),
              box((0.08, 0.06, 0.08), (2.0, -d / 2 - 0.12, 1.45), C["chrome"]),
              box((2.4, 1.4, 0.25), (1.6, -d / 2 - 0.7, 0.28), C["concrete"]),
              box((2.0, 1.1, 0.12), (1.6, -d / 2 - 0.5, 2.85), C[roof], rot=(0.25, 0, 0))]
    windows(parts, "S", -d / 2, [-2.2], zc, 1.6, 1.2, rng)
    windows(parts, "N", d / 2, [-2.2, 1.6], zc, 1.4, 1.2, rng)
    windows(parts, "W", -w / 2, [0.0], zc, 1.4, 1.2, rng)
    windows(parts, "E", w / 2, [0.0], zc, 1.4, 1.2, rng)
    windows(parts, "W", -w / 2, [0.0], 0.4 + h + 0.8, 0.9, 0.8, rng)   # attic window
    parts += [box((0.75, 0.75, 2.4), (-2.6, 1.3, 0.4 + h + 1.9), C["brick"]),
              box((0.95, 0.95, 0.2), (-2.6, 1.3, 0.4 + h + 3.1), C["concrete"])]
    # flower boxes under the front window
    parts += [box((1.6, 0.35, 0.25), (-2.2, -d / 2 - 0.25, zc - 0.85), C["wood"]),
              box((1.4, 0.25, 0.15), (-2.2, -d / 2 - 0.25, zc - 0.65), C["leaf"])]
    mk(f"{name}_Mesh", merge(*parts), r)
    return r


def build_house_twostory(name, wall="wall_peach", roof="roof_slate", seed=2):
    """Narrow two-storey house with the gable facing the street."""
    rng = random.Random(seed)
    r = root(name)
    w, d, h = 8.2, 7.2, 5.8          # built ridge-along-X, then turned so the gable faces -Y
    shell = merge(*gable_shell(w, d, h, 2.6, C[wall], C[roof]))
    xform(shell, rot=(0, 0, math.pi / 2))
    fw, fd = d, w                    # footprint after the turn: 7.2 wide, 8.2 deep
    parts = [shell]
    z1, z2 = 0.4 + 1.5, 0.4 + 4.4
    parts += [box((1.15, 0.14, 2.2), (-1.8, -fd / 2 - 0.03, 0.4 + 1.1), C["sign_teal"]),
              box((2.0, 1.2, 0.25), (-1.8, -fd / 2 - 0.6, 0.28), C["concrete"]),
              box((1.8, 1.0, 0.12), (-1.8, -fd / 2 - 0.45, 2.95), C[roof], rot=(0.25, 0, 0))]
    windows(parts, "S", -fd / 2, [1.6], z1, 1.6, 1.3, rng)
    windows(parts, "S", -fd / 2, [-1.6, 1.6], z2, 1.3, 1.3, rng)
    windows(parts, "S", -fd / 2, [0.0], 0.4 + h + 1.0, 0.9, 0.9, rng)   # gable window
    for side, pl in (("W", -fw / 2), ("E", fw / 2)):
        windows(parts, side, pl, [-2.0, 1.8], z1, 1.3, 1.2, rng)
        windows(parts, side, pl, [-2.0, 1.8], z2, 1.3, 1.2, rng)
    windows(parts, "N", fd / 2, [0.0], z1, 1.3, 1.2, rng)
    windows(parts, "N", fd / 2, [0.0], z2, 1.3, 1.2, rng)
    # little side garage
    parts += [box((3.2, 5.2, 2.8), (fw / 2 + 1.6, -1.2, 1.4), C[wall]),
              box((3.6, 5.6, 0.25), (fw / 2 + 1.6, -1.2, 2.9), C[roof]),
              box((2.6, 0.1, 2.2), (fw / 2 + 1.6, -3.82, 1.1), C["white"])]
    for k in range(4):
        parts.append(box((2.5, 0.06, 0.05), (fw / 2 + 1.6, -3.89, 0.35 + k * 0.55), C["concrete"]))
    mk(f"{name}_Mesh", merge(*parts), r)
    return r


def build_shop(name, wall="wall_cream", accent="sign_teal", seed=3):
    rng = random.Random(seed)
    r = root(name)
    w, d, h = 10.0, 8.0, 4.6
    parts = [box((w + 0.4, d + 0.4, 0.3), (0, 0, 0.15), C["concrete"]),
             box((w, d, h), (0, 0, 0.3 + h / 2), C[wall]),
             box((w - 0.4, d - 0.4, 0.1), (0, 0, 0.3 + h + 0.05), C["roof_slate"])]
    parapet(parts, w, d, 0.3 + h, 0.7, 0.3, C[wall])
    parts.append(box((w + 0.1, d + 0.1, 0.18), (0, 0, 0.3 + h + 0.7), C["concrete"]))
    # storefront
    fy = -d / 2
    parts += [box((6.0, 0.14, 2.4), (-1.3, fy - 0.03, 1.75), C["glass_light"]),
              box((6.3, 0.3, 0.15), (-1.3, fy - 0.1, 0.5), C[accent]),
              box((0.12, 0.18, 2.4), (-1.3, fy - 0.07, 1.75), C["white"]),
              box((1.3, 0.14, 2.5), (3.3, fy - 0.03, 1.55), C["glass"]),
              box((1.5, 0.2, 0.12), (3.3, fy - 0.06, 2.85), C["white"]),
              box((9.4, 0.3, 0.9), (0, fy - 0.15, 4.0), C[accent])]                     # sign band
    # striped awning
    n = 10
    for k in range(n):
        x = -w / 2 + 0.3 + (w - 0.6) / n * (k + 0.5)
        parts.append(box(((w - 0.6) / n, 1.5, 0.1), (x, fy - 0.72, 3.2), C["white"] if k % 2 else C[accent],
                         rot=(0.35, 0, 0)))
    parts.append(box((w - 0.6, 0.08, 0.3), (0, fy - 1.42, 2.92), C[accent]))
    windows(parts, "E", w / 2, [-1.5, 1.5], 2.0, 1.4, 1.4, rng)
    windows(parts, "W", -w / 2, [0.0], 2.0, 1.4, 1.4, rng)
    parts += [box((1.4, 1.0, 0.8), (2.5, 1.5, 0.3 + h + 0.5), C["rim"]),
              box((0.9, 0.9, 0.06), (2.5, 1.5, 0.3 + h + 0.93), C["metal"])]
    mk(f"{name}_Mesh", merge(*parts), r)
    return r


def build_apartment(name, wall="brick", seed=4):
    rng = random.Random(seed)
    r = root(name)
    w, d, fh, floors = 12.0, 10.0, 3.2, 4
    H = 0.3 + fh * floors
    parts = [box((w + 0.4, d + 0.4, 0.3), (0, 0, 0.15), C["concrete"]),
             box((w, d, H - 0.3), (0, 0, 0.3 + (H - 0.3) / 2), C[wall]),
             box((w - 0.4, d - 0.4, 0.1), (0, 0, H + 0.05), C["roof_slate"])]
    for f in range(1, floors):
        parts.append(box((w + 0.16, d + 0.16, 0.2), (0, 0, 0.3 + f * fh), C["concrete"]))
    parapet(parts, w + 0.16, d + 0.16, H, 0.8, 0.3, C["concrete"])
    for f in range(floors):
        zc = 0.3 + f * fh + 1.7
        front = spread(w, 4, 1.6)
        if f == 0:
            front = [front[0], front[3]]
        windows(parts, "S", -d / 2, front, zc, 1.4, 1.6, rng)
        windows(parts, "N", d / 2, spread(w, 4, 1.6), zc, 1.4, 1.6, rng)
        windows(parts, "W", -w / 2, spread(d, 3, 1.6), zc, 1.4, 1.6, rng)
        windows(parts, "E", w / 2, spread(d, 3, 1.6), zc, 1.4, 1.6, rng)
    # entrance
    parts += [box((2.4, 0.16, 2.5), (0, -d / 2 - 0.04, 1.55), C["glass_light"]),
              box((0.1, 0.2, 2.5), (0, -d / 2 - 0.08, 1.55), C["white"]),
              box((3.4, 1.6, 0.25), (0, -d / 2 - 0.8, 3.0), C["concrete"]),
              box((3.0, 1.6, 0.3), (0, -d / 2 - 0.8, 0.15), C["concrete"])]
    # roof kit: AC units + water tower
    parts += [box((1.4, 1.0, 0.9), (-3.5, 2.5, H + 0.45), C["rim"]),
              box((1.4, 1.0, 0.9), (-1.6, 2.5, H + 0.45), C["rim"]),
              box((1.6, 1.6, 2.0), (4.0, -2.8, H + 1.0), C["concrete"])]   # stair housing
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box((0.15, 0.15, 2.4), (2.5 + sx * 0.8, 2.3 + sy * 0.8, H + 1.2), C["metal"]))
    parts += [cyl(1.25, 1.25, 2.2, 8, C["wood"], loc=(2.5, 2.3, H + 2.4)),
              cyl(1.35, 0.05, 1.0, 8, C["wood_dark"], loc=(2.5, 2.3, H + 4.6)),
              cyl(1.3, 1.3, 0.12, 8, C["metal"], loc=(2.5, 2.3, H + 3.1))]
    mk(f"{name}_Mesh", merge(*parts), r)
    return r


def build_office(name, seed=5):
    rng = random.Random(seed)
    r = root(name)
    w, fh, floors = 12.0, 3.4, 9
    H = fh * floors
    parts = [box((w + 0.6, w + 0.6, 0.3), (0, 0, 0.15), C["concrete"]),
             box((w, w, H), (0, 0, 0.3 + H / 2), C["office_glass"])]
    for f in range(1, floors + 1):
        parts.append(box((w + 0.2, w + 0.2, 0.55), (0, 0, 0.3 + f * fh - 0.1), C["white"]))
    for sx in (-1, 1):            # corner piers + mid mullions
        for sy in (-1, 1):
            parts.append(box((0.7, 0.7, H + 0.4), (sx * w / 2, sy * w / 2, 0.3 + (H + 0.4) / 2), C["white"]))
    for a in (-2.0, 2.0):
        for side in ("S", "N", "E", "W"):
            if side in "SN":
                s = -1 if side == "S" else 1
                parts.append(box((0.25, 0.3, H), (a, s * w / 2, 0.3 + H / 2), C["concrete"]))
            else:
                s = -1 if side == "W" else 1
                parts.append(box((0.3, 0.25, H), (s * w / 2, a, 0.3 + H / 2), C["concrete"]))
    # lobby: darker glass, canopy, doors
    parts += [box((5.0, 0.2, 2.6), (0, -w / 2 - 0.05, 1.6), C["glass"]),
              box((6.4, 2.2, 0.3), (0, -w / 2 - 1.1, 3.4), C["white"]),
              box((0.2, 0.2, 3.1), (-3.0, -w / 2 - 2.0, 1.85), C["metal"]),
              box((0.2, 0.2, 3.1), (3.0, -w / 2 - 2.0, 1.85), C["metal"]),
              box((4.2, 0.18, 0.6), (0, -w / 2 - 0.12, 4.4), C["sign_teal"])]
    # roof: penthouse + antenna
    top = 0.3 + H + 0.2
    parts += [box((6.0, 6.0, 3.0), (0, 1.0, top + 1.5), C["white"]),
              box((6.4, 6.4, 0.25), (0, 1.0, top + 3.1), C["concrete"]),
              cyl(0.12, 0.06, 6.0, 6, C["metal"], loc=(1.5, 2.0, top + 3.2)),
              box((0.3, 0.3, 0.3), (1.5, 2.0, top + 9.25), C["taillight"])]
    parapet(parts, w + 0.2, w + 0.2, 0.3 + H + 0.15, 0.6, 0.3, C["white"])
    mk(f"{name}_Mesh", merge(*parts), r)
    return r


def build_gas_station(name, seed=6):
    rng = random.Random(seed)
    r = root(name)
    W, D = 18.0, 17.0
    parts = [box((W, D, 0.12), (0, 0, 0.06), C["concrete"], top=C["sidewalk"])]
    # canopy over the pumps (front half)
    cy = -3.5
    parts += [box((14.0, 7.0, 0.7), (0, cy, 5.0), C["white"]),
              box((14.2, 7.2, 0.4), (0, cy, 4.7), C["sign_red"]),
              box((13.4, 6.4, 0.06), (0, cy, 4.48), C["headlight"])]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box((0.45, 0.45, 4.4), (sx * 5.0, cy + sy * 2.2, 2.32), C["white"]))
    for px in (-3.0, 3.0):
        parts.append(box((1.2, 3.6, 0.22), (px, cy, 0.23), C["concrete"]))
        for py in (-0.9, 0.9):
            parts += [box((0.75, 0.55, 1.6), (px, cy + py, 1.14), C["sign_red"], bev=0.04),
                      box((0.6, 0.57, 0.35), (px, cy + py, 1.55), C["glass"]),
                      box((0.77, 0.57, 0.18), (px, cy + py, 0.5), C["white"]),
                      box((0.06, 0.06, 0.8), (px + 0.42, cy + py, 1.0), C["trim"])]
    # store at the back
    sy = 4.6
    parts += [box((11.0, 6.4, 3.8), (0, sy, 0.12 + 1.9), C["wall_cream"]),
              box((11.4, 6.8, 0.3), (0, sy, 0.12 + 3.95), C["concrete"]),
              box((10.6, 0.25, 0.8), (0, sy - 3.3, 3.4), C["sign_red"]),
              box((4.6, 0.14, 2.0), (-2.4, sy - 3.24, 1.6), C["glass_light"]),
              box((1.4, 0.14, 2.3), (2.6, sy - 3.24, 1.3), C["glass"]),
              box((1.0, 0.8, 1.4), (4.6, sy - 3.7, 0.82), C["white"]),          # ice chest
              box((1.0, 0.82, 0.3), (4.6, sy - 3.7, 1.4), C["car_blue"])]
    windows(parts, "E", 5.5, [sy], 1.9, 1.4, 1.2, rng)
    # tall price sign at the front corner
    parts += [box((0.3, 0.3, 6.5), (7.6, -7.6, 3.3), C["metal"]),
              box((2.4, 0.4, 2.0), (7.6, -7.6, 6.6), C["sign_red"], bev=0.05),
              box((2.0, 0.42, 0.9), (7.6, -7.6, 6.2), C["white"])]
    mk(f"{name}_Mesh", merge(*parts), r)
    return r


def build_lighthouse(name):
    r = root(name)
    parts = [cyl(3.6, 3.6, 0.6, 8, C["concrete"], spin=math.pi / 8),
             box((4.6, 3.6, 2.8), (0, -2.8, 2.0), C["white"]),
             box((5.0, 4.0, 0.3), (0, -2.8, 3.55), C["sign_red"]),
             box((1.0, 0.12, 1.9), (0, -4.62, 1.55), C["sign_red"])]
    z = 0.6
    radii = [2.1, 1.9, 1.7, 1.5, 1.35]
    for k in range(4):
        h = 3.0
        parts.append(cyl(radii[k], radii[k + 1], h, 8, C["white"] if k % 2 == 0 else C["sign_red"], loc=(0, 0, z),
                         spin=math.pi / 8))
        z += h
    for k in range(3):      # small windows up the tower
        a = -math.pi / 2
        parts.append(box((0.4, 0.15, 0.7), (0, -(radii[k + 1] + 0.1), 3.0 + k * 3.0), C["glass"]))
    parts += [cyl(2.0, 2.0, 0.3, 8, C["metal"], loc=(0, 0, z), spin=math.pi / 8)]
    for k in range(8):
        a = k * math.pi / 4
        parts.append(box((0.08, 0.08, 1.0), (math.cos(a) * 1.9, math.sin(a) * 1.9, z + 0.8), C["metal"]))
        a2 = a + math.pi / 8
        parts.append(box((1.5, 0.08, 0.08), (math.cos(a2) * 1.78, math.sin(a2) * 1.78, z + 1.25), C["metal"],
                         rot=(0, 0, a2 + math.pi / 2)))
    parts += [cyl(1.15, 1.15, 0.4, 8, C["metal"], loc=(0, 0, z + 0.3)),
              cyl(1.45, 0.25, 1.4, 8, C["sign_red"], loc=(0, 0, z + 2.5)),
              cyl(0.25, 0.25, 0.3, 6, C["metal"], loc=(0, 0, z + 3.9))]
    mk(f"{name}_Mesh", merge(*parts), r)
    mk(f"{name}_Light", cyl(1.05, 1.05, 1.8, 8, C["glow"], loc=(0, 0, z + 0.7)), r)
    return r


def build_all():
    build_house_cottage("House_Cottage")
    build_house_twostory("House_TwoStory")
    build_shop("Shop_Corner")
    build_apartment("Apartment_Block")
    build_office("Office_Tower")
    build_gas_station("Gas_Station")
    build_lighthouse("Lighthouse")
