"""Vehicles (boat, plane), bridge kit, and the Level 1 bay map.
Run: python3 level1.py   -> out/models/*.glb, out/level1/*, out/level1.blend
Coordinates are Blender meters (Z up, front = +Y). Roblox: X = x*S, Y = z*S, Z = -y*S, S = 25/7.
"""
import bpy, bmesh, math, random, os, json
from mathutils import Vector, Matrix, Euler
import build as B
from build import new_bm, L, paint, merge, xform, bevel, top_paint, box, cyl, ico, frustum, root, mk
import buildings as BL
import apple as AP
import truck as TK
import loads as LD

OUT = B.OUT
LV = os.path.join(OUT, "level1")
os.makedirs(LV, exist_ok=True)
STUDS = 25 / 7

# ---- palette additions (existing indices unchanged)
for n, hx in [("bridge", "C4452F"), ("bridge_dark", "9A3322"), ("concrete", "ABA79F"), ("water", "3D8FCB"),
              ("sand", "E2CE93"), ("cliff", "8E8174"), ("turf", "5FAE4E"), ("hull_navy", "24395C"),
              ("seabed", "C9B784"), ("turf_dark", "4E9A43")]:
    B.PALETTE.append((n, hx))
    B.C[n] = len(B.PALETTE) - 1
BL.register_colors()
AP.register_colors()
LD.register_colors()
C = B.C


def loft(sections, cid, cap=True):
    bm = new_bm()
    rings = [[bm.verts.new(p) for p in s] for s in sections]
    n = len(sections[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap:
        bm.faces.new(rings[0])
        bm.faces.new(rings[-1][::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return paint(bm, cid)


def rod(p0, p1, r, cid, seg=6):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    bm = cyl(r, r, d.length, seg, cid, centered=True)
    M = Matrix.Translation((p0 + p1) / 2) @ d.to_track_quat("Z", "X").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm


def oct_ring(y, hw, zb, zt, n=8):
    zc, hh = (zb + zt) / 2, (zt - zb) / 2
    return [(hw * math.cos(a), y, zc + hh * math.sin(a))
            for a in (math.pi * 2 * k / n + math.pi / n for k in range(n))]


# ================================================================== SPEEDBOAT
def build_boat(name):
    r = root(name)
    # (y, gunwale half-beam, gunwale z, chine half-beam, chine z, keel z); waterline is z=0
    st = [(-3.2, 1.20, 0.95, 1.05, -0.05, -0.30), (-1.0, 1.22, 1.00, 1.05, -0.10, -0.38),
          (1.2, 1.10, 1.08, 0.82, 0.02, -0.30), (2.7, 0.72, 1.20, 0.40, 0.35, 0.00),
          (3.7, 0.08, 1.30, 0.04, 0.90, 0.75)]
    secs = [[(-g, y, gz), (-c, y, cz), (0, y, k), (c, y, cz), (g, y, gz)] for y, g, gz, c, cz, k in st]
    hull = loft(secs, C["white"])
    hull.normal_update()
    l = L(hull)
    for f in hull.faces:
        z = f.calc_center_median().z
        if f.normal.z > 0.8:
            f[l] = C["wood"]
        elif z < 0.12:
            f[l] = C["hull_navy"]
        elif z < 0.32:
            f[l] = C["car_red"]
    trim = [box((0.08, 4.6, 0.10), (sx * 1.18, -0.8, 1.0), C["chrome"]) for sx in (-1, 1)]
    for sx in (-1, 1):   # red racing stripe along each side
        band = []
        for y, g, gz, c, cz, k in st[:4]:
            p = lambda t: Vector((sx * (c + (g - c) * t), y, cz + (gz - cz) * t))
            n = Vector((sx, 0, 0)) * 0.025
            p0, p1 = p(0.50), p(0.66)
            band.append([p0 + n, p1 + n, p1 - n, p0 - n] if sx > 0 else [p0 - n, p1 - n, p1 + n, p0 + n])
        trim.append(loft(band, C["car_red"]))
    cockpit = [
        frustum((0, 0.75, 1.0, 2.0, 0.30), (0, 0.55, 1.55, 1.75, 0.08), C["glass"]),   # windshield
        box((0.9, 0.6, 0.5), (0.45, 0.2, 1.2), C["white"], bev=0.04),                  # console
        box((0.55, 0.55, 0.35), (-0.5, -0.4, 1.15), C["hull_navy"], bev=0.05),         # seats
        box((0.55, 0.55, 0.35), (0.5, -0.4, 1.15), C["hull_navy"], bev=0.05),
        box((2.0, 0.6, 0.35), (0, -2.2, 1.15), C["hull_navy"], bev=0.05),              # rear bench
        box((0.08, 0.08, 0.25), (0.45, 0.35, 1.55), C["metal"]),
        cyl(0.16, 0.16, 0.04, 8, C["metal"], loc=(0.45, 0.32, 1.68), rot=(1.1, 0, 0), centered=True),  # wheel
    ]
    merge(hull, *trim, *cockpit)
    mk(f"{name}_Hull", hull, r)
    motor = merge(box((0.45, 0.55, 0.65), (0, 0, 0.45), C["trim"], bev=0.06),
                  box((0.18, 0.25, 0.9), (0, -0.05, -0.25), C["metal"]),
                  box((0.12, 0.4, 0.12), (0, -0.05, -0.65), C["metal"]))
    mk(f"{name}_Motor", motor, r, loc=(0, -3.45, 0.55))
    return r


# ================================================================== PROP PLANE
def build_plane(name):
    r = root(name)
    st = [(3.55, 0.42, 0.95, 1.65), (3.0, 0.62, 0.78, 1.95), (1.2, 0.66, 0.72, 2.05),
          (-0.4, 0.62, 0.78, 2.08), (-2.0, 0.40, 1.08, 1.98), (-4.25, 0.12, 1.62, 1.98)]
    fus = loft([oct_ring(*s) for s in st], C["white"])
    fus.normal_update()
    l = L(fus)
    for f in fus.faces:
        if f.normal.z < -0.35:
            f[l] = C["car_red"]
    # stripe band along the sides
    stripe = loft([oct_ring(y, hw + 0.012, zb + (zt - zb) * 0.42, zb + (zt - zb) * 0.58)
                   for y, hw, zb, zt in st[1:5]], C["car_blue"])
    def wing(x0, x1, y_root, c_root, y_tip, c_tip, z0, z1, t0, t1, cid):
        def sec(x, y, c, z, t):
            return [(x, y - c / 2, z), (x, y + c / 2, z + t * 0.2), (x, y + c / 2 - 0.15, z + t), (x, y - c / 2, z + t * 0.6)]
        return loft([sec(x0, y_root, c_root, z0, t0), sec(x1, y_tip, c_tip, z1, t1)], cid)
    wings = [wing(0, sx * 5.6, 0.7, 1.7, 0.75, 1.05, 0.95, 1.25, 0.2, 0.12, C["white"]) for sx in (-1, 1)]
    tips = [box((0.35, 1.08, 0.15), (sx * 5.55, 0.75, 1.31), C["car_red"]) for sx in (-1, 1)]
    stab = [wing(0, sx * 1.9, -3.7, 0.9, -3.9, 0.55, 1.78, 1.85, 0.1, 0.07, C["white"]) for sx in (-1, 1)]
    fin = loft([[(-0.06, -4.35, 1.95), (-0.06, -3.1, 1.95), (-0.06, -3.85, 3.05), (-0.06, -4.45, 3.1)],
                [(0.06, -4.35, 1.95), (0.06, -3.1, 1.95), (0.06, -3.85, 3.05), (0.06, -4.45, 3.1)]], C["car_red"])
    canopy = frustum((0, 0.7, 2.0, 1.12, 1.9), (0, 0.45, 2.45, 0.8, 1.0), C["glass"], bev=0.03)
    gear = []
    for sx in (-1, 1):
        gear += [box((0.08, 0.08, 0.55), (sx * 1.1, 0.6, 0.55), C["metal"], rot=(0, sx * 0.25, 0)),
                 cyl(0.27, 0.27, 0.16, 8, C["tire"], loc=(sx * 1.2, 0.6, 0.27), rot=(0, math.pi / 2, 0), centered=True),
                 cyl(0.12, 0.12, 0.17, 6, C["rim"], loc=(sx * 1.2, 0.6, 0.27), rot=(0, math.pi / 2, 0), centered=True)]
    gear += [box((0.08, 0.08, 0.6), (0, 2.6, 0.55), C["metal"]),
             cyl(0.22, 0.22, 0.13, 8, C["tire"], loc=(0, 2.6, 0.22), rot=(0, math.pi / 2, 0), centered=True)]
    merge(fus, stripe, *wings, *tips, *stab, fin, canopy, *gear)
    mk(f"{name}_Body", fus, r)
    prop = merge(cyl(0.32, 0.04, 0.55, 8, C["car_red"], rot=(-math.pi / 2, 0, 0)),
                 box((0.18, 0.05, 2.1), (0, 0.08, 0), C["trim"], rot=(0, 0.12, 0)))
    mk(f"{name}_Propeller", prop, r, loc=(0, 3.58, 1.3))
    return r


# ================================================================== BRIDGE KIT
LEG_X = 7.4
TOWER_TOP = 52.6


def build_tower(name):
    """Origin at water level, centred between the legs. Deck (40 studs wide) passes between the legs."""
    r = root(name)
    bm = box((22, 9.5, 9.0), (0, 0, -1.5), C["concrete"], bev=0.25)   # pier, top at z=3
    stages = [(3, 16, 3.4, 4.6), (16, 28.5, 3.1, 4.2), (28.5, 40.5, 2.8, 3.8), (40.5, 51, 2.5, 3.4)]
    for sx in (-1, 1):
        for i, (z0, z1, w, d) in enumerate(stages):
            nw, nd = (stages[i + 1][2], stages[i + 1][3]) if i + 1 < len(stages) else (w - 0.1, d - 0.1)
            leg = frustum((sx * LEG_X, 0, z0, w, d), (sx * LEG_X, 0, z1, w - 0.1, d - 0.1), C["bridge"])
            # recessed vertical grooves on the broad faces
            leg.normal_update()
            faces = [f for f in leg.faces if abs(f.normal.y) > 0.9]
            ret = bmesh.ops.inset_individual(leg, faces=faces, thickness=0.35, depth=-0.12)
            for f in faces:
                f[L(leg)] = C["bridge_dark"]
            merge(bm, leg, box((w + 0.3, d + 0.3, 0.45), (sx * LEG_X, 0, z1), C["bridge_dark"]))
        merge(bm, box((2.9, 3.8, 0.8), (sx * LEG_X, 0, 51.4), C["bridge"], bev=0.1),
              box((1.8, 2.8, 1.0), (sx * (LEG_X - 0.3), 0, 52.1), C["bridge_dark"], bev=0.1))
    for zc, h in ((9.4, 2.4), (25.5, 2.6), (37.6, 2.3), (48.6, 2.6)):
        span = 2 * LEG_X - 2.2
        s = box((span, 2.4, h), (0, 0, zc), C["bridge"])
        s.normal_update()
        faces = [f for f in s.faces if abs(f.normal.y) > 0.9]
        bmesh.ops.inset_individual(s, faces=faces, thickness=0.3, depth=-0.12)
        for f in faces:
            f[L(s)] = C["bridge_dark"]
        merge(bm, s)
    mk(f"{name}_Mesh", bm, r)
    return r


DECK = 11.2


def build_deck(name):
    """One 11.2 m (40 stud) segment along Y. Road surface matches Road_Straight (top z=0.14)."""
    r = root(name)
    T, AW = DECK / 2, 4.2
    road = box((2 * AW, DECK, 0.44), (0, 0, -0.08), C["asphalt"])
    lines = [box((0.16, 1.4, 0.02), (0, y, 0.14), C["line_yellow"]) for y in (-4.2, -1.4, 1.4, 4.2)]
    edges = [box((0.14, DECK, 0.02), (sx * (AW - 0.3), 0, 0.14), C["line_white"]) for sx in (-1, 1)]
    walks = [box((1.4, DECK, 0.58), (sx * (AW + 0.7), 0, -0.01), C["curb"], top=C["concrete"]) for sx in (-1, 1)]
    merge(road, *lines, *edges, *walks)
    mk(f"{name}_Road", road, r)
    st = new_bm()
    for sx in (-1, 1):
        x = sx * 5.45
        merge(st, box((0.1, DECK, 0.1), (x, 0, 1.3), C["bridge"]), box((0.08, DECK, 0.08), (x, 0, 0.8), C["bridge"]))
        for k in range(8):
            merge(st, box((0.12, 0.12, 1.05), (x, -T + 0.7 + k * 1.4, 0.8), C["bridge"]))
        gx = sx * 5.0
        merge(st, box((0.45, DECK, 0.35), (gx, 0, -0.45), C["bridge"]),
              box((0.45, DECK, 0.35), (gx, 0, -3.0), C["bridge"]))
        for k in range(4):
            y0 = -T + k * 2.8
            merge(st, box((0.3, 0.3, 2.3), (gx, y0 + 1.4, -1.72), C["bridge"]),
                  rod((gx, y0 + 0.15, -2.85), (gx, y0 + 1.25, -0.6), 0.13, C["bridge_dark"], seg=4),
                  rod((gx, y0 + 2.65, -2.85), (gx, y0 + 1.55, -0.6), 0.13, C["bridge_dark"], seg=4))
    for y in (-2.8, 2.8):
        merge(st, box((10.4, 0.3, 0.3), (0, y, -3.0), C["bridge_dark"]),
              rod((-4.8, y - 2.6, -3.0), (4.8, y + 2.6, -3.0), 0.1, C["bridge_dark"], seg=4))
    mk(f"{name}_Steel", st, r)
    return r


def build_dock(name):
    """Pier along +Y, 12 m long; origin at the shore end, deck at z=1.0."""
    r = root(name)
    bm = new_bm()
    for k in range(20):
        merge(bm, box((2.4, 0.55, 0.12), (0, 0.3 + k * 0.6, 1.0), C["wood"] if k % 3 else C["wood_dark"], bev=0.02))
    for y in (0.4, 4.2, 8.0, 11.6):
        for sx in (-1, 1):
            merge(bm, cyl(0.15, 0.13, 3.6, 6, C["wood_dark"], loc=(sx * 1.15, y, -2.4)))
    merge(bm, box((0.12, 12, 0.18), (-1.25, 6, 0.85), C["wood_dark"]), box((0.12, 12, 0.18), (1.25, 6, 0.85), C["wood_dark"]))
    for y in (11.6,):
        for sx in (-1, 1):
            merge(bm, cyl(0.12, 0.12, 0.3, 6, C["metal"], loc=(sx * 1.0, y, 1.06)))  # cleats
    mk(f"{name}_Mesh", bm, r)
    return r


# ================================================================== LEVEL 1 TERRAIN
X0, X1, Y0, Y1, G = -140.0, 140.0, -145.6, 145.6, 5.6
TOWER_Y, SHORE_BRIDGE, DECK_Z = 36.0, 56.0, 14.0
ROAD_TILES = []   # (model, x, y, rz)
PADS = []         # flat building lots: (cx, cy, half_x, half_y, z)
BLDS = []         # (model, x, y, z, rz)


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def shore(x):
    w = sstep(16, 40, abs(x))
    return SHORE_BRIDGE + w * (8 * math.sin(x * 0.045 + 1) + 5 * math.sin(x * 0.11))


def gauss(x, y, cx, cy, h, s):
    return h * math.exp(-((x - cx) ** 2 + (y - cy) ** 2) / s)


def road_dist(x, y):
    d = 1e9
    for _, tx, ty, _ in ROAD_TILES:
        d = min(d, max(abs(x - tx), abs(y - ty)) - 5.6)
    return d


def natural_h(x, y):
    d = abs(y) - shore(x)
    if d < 0:
        return max(-6.0, d * 1.2)
    far = sstep(60, 130, abs(x))
    base = 14 - 10 * far
    rise = 7 + 18 * sstep(30, 90, abs(x))
    z = base * sstep(0, rise, d)
    m = sstep(0, 22, d)
    if y > 0:
        z += m * (gauss(x, y, -62, 112, 24, 900) + gauss(x, y, 18, 132, 17, 700) + gauss(x, y, 98, 112, 13, 650)
                  + gauss(x, y, -112, 80, 9, 500))
    else:
        z += m * (gauss(x, y, -112, -118, 9, 600) + gauss(x, y, 115, -125, 7, 500))
    return z


def pad_dist(x, y):
    d = 1e9
    for cx, cy, hx, hy, _ in PADS:
        d = min(d, max(abs(x - cx) - hx, abs(y - cy) - hy))
    return d


def height(x, y):
    z = natural_h(x, y)
    d = abs(y) - shore(x)
    if d >= -0.01:
        rd = road_dist(x, y)
        w = 1 - sstep(0.5, 12, rd)
        z = z + (DECK_Z - z) * w
        for cx, cy, hx, hy, pz in PADS:
            pd = max(abs(x - cx) - hx, abs(y - cy) - hy)
            w = 1 - sstep(0.5, 9, pd)
            z = z + (pz - z) * w
    return z


def plan_buildings():
    lots = [  # model, x, y, yaw (front faces the street)
        ("Office_Tower", 14.0, -70.0, -90), ("Shop_Corner", 12.8, -83.4, -90), ("Gas_Station", 30.0, -81.0, 0),
        ("Apartment_Block", 48.5, -70.0, 0),
        ("House_Cottage", -11.0, -68.5, 90), ("House_TwoStory", -12.0, -80.6, 90),
        ("Apartment_Block", -28.0, -81.5, 0), ("Shop_Corner", -45.0, -84.0, 0), ("House_Cottage", -46.0, -70.5, 0),
        ("Apartment_Block", 13.5, -112.5, -90), ("Office_Tower", 14.5, -130.0, -90),
        ("Shop_Corner", 30.0, -107.0, 180), ("House_TwoStory", 48.0, -108.5, 180),
        ("House_Cottage", -55.0, -111.0, 180), ("House_TwoStory", -12.0, -112.5, 90),
        ("House_Cottage", -12.5, -128.0, 90), ("Shop_Corner", -33.0, -107.0, 180),
    ]
    for m, x, y, rz in lots:
        fw, fd = BL.FOOT[m]
        if rz in (90, -90):
            fw, fd = fd, fw
        PADS.append((x, y, fw / 2 + 1.0, fd / 2 + 1.0, DECK_Z))
        BLDS.append((m, x, y, DECK_Z, rz))
    # lighthouse on the north headland west of the bridge
    lx = -40.0
    ly = shore(lx) + 11.0
    lz = round(natural_h(lx, ly), 2)
    PADS.append((lx, ly, 4.5, 4.5, lz))
    BLDS.append(("Lighthouse", lx, ly, lz, 200))


def jitter(i, j):
    rng = random.Random(i * 7919 + j * 104729)
    return rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)


def build_terrain(name):
    r = root(name)
    nx, ny = int(round((X1 - X0) / G)), int(round((Y1 - Y0) / G))
    bm = new_bm()
    l = L(bm)
    V = {}
    for i in range(nx + 1):
        for j in range(ny + 1):
            x, y = X0 + i * G, Y0 + j * G
            z = height(x, y)
            edge = i in (0, nx) or j in (0, ny)
            flat = (road_dist(x, y) < 2.5 or pad_dist(x, y) < 1.5) and abs(y) >= shore(x)
            if not edge and not flat:
                jx, jy, jz = jitter(i, j)
                x += jx * 1.1
                y += jy * 1.1
                z += jz * (0.25 if abs(z - DECK_Z) < 0.5 else 0.6)
            V[i, j] = bm.verts.new((x, y, z))
    def color(f):
        c = f.calc_center_median()
        n = f.normal
        if c.z < -0.6:
            return C["seabed"]
        if c.z < 1.6:
            return C["sand"]
        if n.z < 0.72:
            return C["cliff"]
        return C["turf"] if (int(c.x // 17) + int(c.y // 23)) % 3 else C["turf_dark"]
    for i in range(nx):
        for j in range(ny):
            a, b, c2, d = V[i, j], V[i + 1, j], V[i + 1, j + 1], V[i, j + 1]
            tris = [(a, b, c2), (a, c2, d)] if (i + j) % 2 == 0 else [(a, b, d), (b, c2, d)]
            for t in tris:
                f = bm.faces.new(t)
                f.normal_update()
                f[l] = color(f)
    # skirt down to the sea floor so the map edge reads as a solid block
    ring = [V[i, 0] for i in range(nx + 1)] + [V[nx, j] for j in range(1, ny + 1)] + \
           [V[i, ny] for i in range(nx - 1, -1, -1)] + [V[0, j] for j in range(ny - 1, 0, -1)]
    low = [bm.verts.new((v.co.x, v.co.y, -8.0)) for v in ring]
    for k in range(len(ring)):
        k2 = (k + 1) % len(ring)
        f = bm.faces.new((ring[k2], ring[k], low[k], low[k2]))
        f[l] = C["cliff"]
    bot = bm.faces.new(low[::-1])
    bot[l] = C["cliff"]
    mk(f"{name}_Land", bm, r, recalc=False)
    mk(f"{name}_Water", box((420, 420, 0.6), (0, 0, -0.3), C["water"]), r)
    return r


def build_cables(name):
    """Main cables, suspenders and anchor blocks for the Level 1 span (towers at y=+-36)."""
    r = root(name)
    bm = new_bm()
    ANCH_Y, ANCH_Z, ANCH_X = 62.0, 14.9, 7.4
    def cable_pt(sx, y):
        ay = abs(y)
        if ay <= TOWER_Y:
            z = 16.2 + (TOWER_TOP - 16.2) * (ay / TOWER_Y) ** 2
            x = 6.6
        else:
            t = (ay - TOWER_Y) / (ANCH_Y - TOWER_Y)
            z = TOWER_TOP + (ANCH_Z - TOWER_TOP) * t - 3.0 * 4 * t * (1 - t)
            x = 6.6 + (ANCH_X - 6.6) * t
        return Vector((sx * x, y, z))
    ys = [i * 2.8 for i in range(-int(ANCH_Y // 2.8), int(ANCH_Y // 2.8) + 1)]
    ys = [-ANCH_Y] + [y for y in ys if abs(y) < ANCH_Y] + [ANCH_Y]
    for sx in (-1, 1):
        pts = [cable_pt(sx, y) for y in ys]
        for a, b in zip(pts, pts[1:]):
            merge(bm, rod(a, b, 0.38, C["bridge"]))
        for k in range(-10, 11):
            y = k * 5.6
            if abs(abs(y) - TOWER_Y) < 2.0 or abs(y) > 56:
                continue
            top = cable_pt(sx, y)
            bottom = Vector((sx * 5.6, y, DECK_Z + 0.3))
            if top.z - bottom.z > 0.8:
                merge(bm, rod(top, bottom, 0.07, C["bridge_dark"], seg=4))
        for sy in (-1, 1):
            merge(bm, box((3.2, 5.0, 2.4), (sx * ANCH_X, sy * (ANCH_Y + 1.6), DECK_Z + 0.9), C["concrete"], bev=0.2))
    mk(f"{name}_Mesh", bm, r)
    return r


# ================================================================== INSTANCING
PLACED = []   # (model, x, y, z, rz_deg)
LEVEL_ROOT = None


def instance(model, x, y, z, rz=0.0):
    src = B.MODELS[model]
    e = bpy.data.objects.new(f"L1_{model}", None)
    B.COLL.objects.link(e)
    e.location = (x, y, z)
    e.rotation_euler = (0, 0, math.radians(rz))
    e.parent = LEVEL_ROOT
    for c in src.children:
        o = c.copy()            # shares mesh data -> instanced in the GLB
        B.COLL.objects.link(o)
        o.parent = e
    PLACED.append((model, round(x, 3), round(y, 3), round(z, 3), round(rz, 2)))
    return e


def plan_roads():
    T = 11.2
    # bridge deck segments
    for k in range(10):
        ROAD_TILES.append(("Bridge_Deck", 0.0, -56 + T / 2 + k * T, 0))
    # south (city side): main street, intersection, cross street
    for y in (-61.6, -72.8, -84.0, -106.4, -117.6, -128.8, -140.0):
        ROAD_TILES.append(("Road_Straight", 0.0, y, 0))
    ROAD_TILES.append(("Road_Intersection", 0.0, -95.2, 0))
    for x in (11.2, 22.4, 33.6, 44.8, 56.0):
        ROAD_TILES.append(("Road_Straight", x, -95.2, 90))
        ROAD_TILES.append(("Road_Straight", -x, -95.2, 90))
    # north (hill side): up from the bridge, corner, then east along the ridge
    for y in (61.6, 72.8):
        ROAD_TILES.append(("Road_Straight", 0.0, y, 0))
    ROAD_TILES.append(("Road_Corner", 0.0, 84.0, 0))
    for x in (11.2, 22.4, 33.6, 44.8, 56.0, 67.2):
        ROAD_TILES.append(("Road_Straight", x, 84.0, 90))


def land_ok(x, y, clear=4.0):
    if not (X0 + 4 < x < X1 - 4 and Y0 + 4 < y < Y1 - 4):
        return False
    if abs(y) - shore(x) < 5:
        return False
    if road_dist(x, y) < clear or pad_dist(x, y) < clear * 0.6:
        return False
    if abs(x) < 14 and abs(y) < 70:
        return False
    e = 1.0
    gx = height(x + e, y) - height(x - e, y)
    gy = height(x, y + e) - height(x, y - e)
    return math.hypot(gx, gy) / (2 * e) < 0.55


def layout_level():
    for m, x, y, rz in ROAD_TILES:
        instance(m, x, y, DECK_Z, rz)
    instance("Bridge_Tower", 0, -TOWER_Y, 0)
    instance("Bridge_Tower", 0, TOWER_Y, 0)
    instance("Level1_Terrain", 0, 0, 0)
    instance("Level1_Bridge_Cables", 0, 0, 0)
    Z = DECK_Z
    ZS, ZR = DECK_Z + 0.28, DECK_Z + 0.14     # sidewalk top, asphalt top
    # city street dressing
    for y in (-61.6, -84.0, -106.4, -128.8):
        instance("Street_Lamp", 4.95, y, ZS, 90)
        instance("Street_Lamp", -4.95, y - 11.2, ZS, -90)
    for x in (22.4, 44.8):
        instance("Street_Lamp", x, -90.25, ZS, 180)
        instance("Street_Lamp", -x, -100.15, ZS, 0)
    instance("Stop_Sign", -4.9, -87.5, ZS, 180)
    instance("Stop_Sign", 4.9, -102.9, ZS, 0)
    instance("Fire_Hydrant", 4.8, -78.0, ZS)
    instance("Fire_Hydrant", -15.0, -100.4, ZS)
    instance("Park_Bench", -4.9, -66.0, ZS, 90)
    instance("Park_Bench", 30.0, -100.4, ZS, 180)
    instance("Car_Red", 2.0, -70.0, ZR, 0)                # player start, facing the bridge
    instance("Car_Blue", -2.1, -118.0, ZR, 180)
    instance("Car_Yellow", -30.0, -97.3, ZR, -90)
    for sx in (-1, 1):                                    # road-closed ends of the cross street
        instance("Road_Barrier", sx * 61.0, -95.2, ZR, 90)
        instance("Traffic_Cone", sx * 59.5, -92.0, ZR)
        instance("Traffic_Cone", sx * 59.5, -98.4, ZR)
    instance("Road_Barrier", 72.5, 84.0, ZR, 90)
    instance("Traffic_Cone", 71.0, 81.0, ZR)
    instance("Traffic_Cone", 71.0, 87.0, ZR)
    for m, x, y, z, rz in BLDS:
        instance(m, x, y, z, rz)
    def load_on(load, tx, ty, tz, rz):
        # a load placed straight after its truck is parented into that truck by the Roblox builder
        a = math.radians(rz)
        bx, by, bz = LD.BED_POINT
        instance(load, tx + bx * math.cos(a) - by * math.sin(a), ty + bx * math.sin(a) + by * math.cos(a), tz + bz, rz)
    instance("Truck_Orange", 30.0, -84.5, DECK_Z + 0.12, 0)    # between the pump islands at the gas station
    load_on("Load_Barrels", 30.0, -84.5, DECK_Z + 0.12, 0)
    instance("Truck_Blue", -2.1, -131.0, ZR, 180)              # following the blue car south
    load_on("Load_Apples", -2.1, -131.0, ZR, 180)
    for x in (-50, -60):
        instance("Picket_Fence", x, -105.5, Z, 0)
    # water: speedboat in the bay, one moored at the dock, plane over the bay
    instance("Boat_Speedboat", 34.0, -12.0, 0, -100)
    sx_d = -100.0
    sy_d = -shore(sx_d) - 3.0
    instance("Wooden_Dock", sx_d, sy_d, 0, 0)
    instance("Boat_Speedboat", sx_d + 2.6, sy_d + 8.0, 0, 180)
    instance("Plane_Prop", -40.0, 8.0, 46.0, -70)
    # nature scatter
    rng = random.Random(42)
    counts = {"Tree_Pine": 0, "Tree_Round": 0, "Bush": 0, "Rock_Large": 0, "Rock_Small": 0, "Grass_Tuft": 0}
    want = {"Tree_Pine": 55, "Tree_Round": 26, "Bush": 30, "Rock_Large": 12, "Rock_Small": 18, "Grass_Tuft": 40}
    spots = []
    tries = 0
    while any(counts[k] < want[k] for k in want) and tries < 40000:
        tries += 1
        x, y = rng.uniform(X0, X1), rng.uniform(Y0, Y1)
        north = y > 0
        pool = [k for k in want if counts[k] < want[k]]
        if not north:   # south side keeps open city land; sparser nature near the edges
            if abs(x) < 70 and rng.random() < 0.85:
                continue
            pool = [k for k in pool if k != "Tree_Pine" or rng.random() < 0.3]
            if not pool:
                continue
        m = rng.choice(pool)
        big = m in ("Tree_Pine", "Tree_Round", "Rock_Large")
        if not land_ok(x, y, clear=6 if big else 3):
            continue
        if any(math.hypot(x - a, y - b) < (5 if big else 2.5) for a, b in spots):
            continue
        spots.append((x, y))
        counts[m] += 1
        instance(m, x, y, height(x, y) - 0.25, rng.uniform(0, 360))


# ================================================================== MAIN
def export_sel(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True)


def luau_script(bounds):
    lines = ["-- Level 1 builder: Swamphacks Lowpoly Pack",
             "-- 1. Import the .glb files from models/ and level1/Level1_Terrain.glb + Level1_Bridge_Cables.glb.",
             "-- 2. Put the imported Models in a Folder named LowpolyAssets inside ServerStorage (names unchanged).",
             "-- 3. Paste this whole script into the Studio command bar and press Enter (or run it once as a Script).",
             "",
             "local S = 25 / 7 -- studs per meter used by the importer",
             "local assets = game:GetService(\"ServerStorage\"):WaitForChild(\"LowpolyAssets\")",
             "",
             "-- model -> {origin offset from bounding-box centre, bounding-box size}, in studs (Roblox axes)",
             "local INFO = {"]
    for n, (off, size) in sorted(bounds.items()):
        lines.append(f'\t["{n}"] = {{Vector3.new({off[0]:.3f}, {off[1]:.3f}, {off[2]:.3f}), Vector3.new({size[0]:.3f}, {size[1]:.3f}, {size[2]:.3f})}},')
    lines += ["}", "", "-- {model, x, y, z (Blender meters, Z up), yaw degrees}", "local PLACE = {"]
    for m, x, y, z, rz in PLACED:
        lines.append(f'\t{{"{m}", {x}, {y}, {z}, {rz}}},')
    lines += ["}", "",
              "local function prepare(template, name)",
              "\tlocal info = INFO[name]",
              "\tlocal cf, size = template:GetBoundingBox()",
              "\tif info then",
              "\t\tlocal want = info[2]",
              "\t\tlocal ratio = size.Magnitude / want.Magnitude",
              "\t\tif math.abs(ratio - 1) > 0.05 then",
              "\t\t\twarn(string.format(\"%s imported at %.2fx the expected size; re-import with meter units\", name, ratio))",
              "\t\tend",
              "\t\ttemplate.WorldPivot = CFrame.new(cf.Position + info[1])",
              "\tend",
              "end",
              "",
              "local old = workspace:FindFirstChild(\"Level1\")",
              "if old then old:Destroy() end",
              "local level = Instance.new(\"Model\")",
              "level.Name = \"Level1\"",
              "local folders = {}",
              "local prepared = {}",
              "local lastTruck = nil",
              "for _, e in ipairs(PLACE) do",
              "\tlocal name = e[1]",
              "\tlocal template = assets:FindFirstChild(name)",
              "\tif not template then",
              "\t\twarn(\"Missing asset in ServerStorage.LowpolyAssets: \" .. name)",
              "\telse",
              "\t\tif not prepared[name] then prepare(template, name); prepared[name] = true end",

              "\t\tlocal m = template:Clone()",
              "\t\tm:PivotTo(CFrame.new(e[2] * S, e[4] * S, -e[3] * S) * CFrame.Angles(0, math.rad(e[5]), 0))",
              "\t\tfor _, p in ipairs(m:GetDescendants()) do",
              "\t\t\tif p:IsA(\"BasePart\") then p.Anchored = true end",
              "\t\tend",
              "\t\tif string.sub(name, 1, 5) == \"Load_\" and lastTruck then",
              "\t\t\tm.Name = \"Load\" -- cargo rides in the truck placed just before it (see TruckLoads)",
              "\t\t\tm:SetAttribute(\"LoadType\", name)",
              "\t\t\tlastTruck:SetAttribute(\"Load\", name)",
              "\t\t\tm.Parent = lastTruck",
              "\t\telse",
              "\t\t\tlocal folder = folders[name]",
              "\t\t\tif not folder then",
              "\t\t\t\tfolder = Instance.new(\"Folder\")",
              "\t\t\t\tfolder.Name = name",
              "\t\t\t\tfolder.Parent = level",
              "\t\t\t\tfolders[name] = folder",
              "\t\t\tend",
              "\t\t\tm.Parent = folder",
              "\t\tend",
              "\t\tlastTruck = (string.sub(name, 1, 6) == \"Truck_\") and m or nil",
              "\tend",
              "end",
              "level.Parent = workspace",
              "local spawnCar = folders[\"Car_Red\"] and folders[\"Car_Red\"]:GetChildren()[1]",
              "if spawnCar then",
              "\tlocal sp = workspace:FindFirstChildOfClass(\"SpawnLocation\") or Instance.new(\"SpawnLocation\")",
              "\tsp.Anchored = true",
              "\tsp.Size = Vector3.new(8, 1, 8)",
              "\tsp.CFrame = spawnCar:GetPivot() * CFrame.new(11, 1.6, 0)",
              "\tsp.Parent = workspace",
              "end",
              "print(\"Level1 built: \" .. #PLACE .. \" objects\")"]
    return "\n".join(lines) + "\n"


def model_bounds(name):
    """Bounding box of a model at its origin, in Roblox studs: (origin - centre, size)."""
    ro = B.MODELS[name]
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for c in ro.children:
        for v in c.data.vertices:
            p = c.matrix_local @ v.co
            mn = Vector(map(min, mn, p))
            mx = Vector(map(max, mx, p))
    cen, size = (mn + mx) / 2, mx - mn
    to_r = lambda v: (v.x * STUDS, v.z * STUDS, -v.y * STUDS)
    off = to_r(-cen)
    sz = (size.x * STUDS, size.z * STUDS, size.y * STUDS)
    return off, sz


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    B.COLL = bpy.context.scene.collection
    pal = B.make_palette_image()
    # original pack
    for n, cid in (("Car_Red", "car_red"), ("Car_Blue", "car_blue"), ("Car_Yellow", "car_yellow")):
        B.build_car(n, C[cid])
    B.build_tree_round("Tree_Round"); B.build_tree_pine("Tree_Pine"); B.build_bush("Bush")
    B.build_rock("Rock_Large", big=True); B.build_rock("Rock_Small", big=False, seed=21); B.build_grass("Grass_Tuft")
    B.build_road_straight("Road_Straight"); B.build_road_corner("Road_Corner"); B.build_road_cross("Road_Intersection")
    B.build_street_lamp("Street_Lamp"); B.build_cone("Traffic_Cone"); B.build_barrier("Road_Barrier")
    B.build_fence("Picket_Fence"); B.build_stop_sign("Stop_Sign"); B.build_hydrant("Fire_Hydrant"); B.build_bench("Park_Bench")
    # new
    build_boat("Boat_Speedboat"); build_plane("Plane_Prop")
    build_tower("Bridge_Tower"); build_deck("Bridge_Deck"); build_dock("Wooden_Dock")
    BL.build_all()
    AP.build_all()
    TK.build_all()
    LD.build_all()
    plan_roads()
    plan_buildings()
    build_terrain("Level1_Terrain"); build_cables("Level1_Bridge_Cables")
    B.finalize(pal)
    for ro in B.MODELS.values():   # library models live off to the side
        pass
    for n, ro in B.MODELS.items():
        sub = LV if n.startswith("Level1_") else os.path.join(OUT, "models")
        export_sel([ro] + list(ro.children_recursive), os.path.join(sub, f"{n}.glb"))
    bounds = {n: model_bounds(n) for n in B.MODELS}
    tris = {}
    for n, ro in B.MODELS.items():
        t = 0
        for c in ro.children:
            c.data.calc_loop_triangles()
            t += len(c.data.loop_triangles)
        tris[n] = t
    print("TRIS", json.dumps(tris))
    # level
    LEVEL_ROOT = bpy.data.objects.new("Level1", None)
    B.COLL.objects.link(LEVEL_ROOT)
    layout_level()
    export_sel([LEVEL_ROOT] + list(LEVEL_ROOT.children_recursive), os.path.join(LV, "Level1_Full.glb"))
    with open(os.path.join(LV, "BuildLevel1.lua"), "w") as f:
        f.write(luau_script(bounds))
    with open(os.path.join(LV, "level1_layout.json"), "w") as f:
        json.dump([dict(model=m, x=x, y=y, z=z, yaw=rz) for m, x, y, z, rz in PLACED], f, indent=1)
    for ro in B.MODELS.values():   # hide library originals; the level uses instances
        ro.location.z = -500
    print("PLACED", len(PLACED))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "level1.blend"))
