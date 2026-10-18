"""Low-poly tropical island + standalone palm tree.
Island origin = centre at the waterline (z=0); its underwater skirt reaches the Level 1 sea floor (-6 m).
About 46 m across (~165 studs): room for a boat landing, a few palms and a treasure chest."""
import math, random
import bmesh
from mathutils import Vector
import build as B
from build import new_bm, L, paint, merge, xform, box, cyl, ico, hull, root, mk

C = B.C


def register_colors():
    for n, hx in [("palm_trunk", "C9955B"), ("palm_trunk_dark", "A47640"), ("coconut", "7A4E2D"),
                  ("gold", "F5C842"), ("sand_wet", "D4BC7E")]:
        if n not in C:
            B.PALETTE.append((n, hx))
            C[n] = len(B.PALETTE) - 1


def loft(sections, cid):
    bm = new_bm()
    rings = [[bm.verts.new(p) for p in s] for s in sections]
    n = len(sections[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(rings[0])
    bm.faces.new(rings[-1][::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return paint(bm, cid)


# ------------------------------------------------------------------ palm tree
def palm(seed=1, height=6.5, lean=0.35, scale=1.0):
    """Returns a bmesh: curved segmented trunk, drooping fronds, coconuts. Origin at the trunk base."""
    rng = random.Random(seed)
    parts = []
    segs = 7
    yaw = rng.uniform(0, 2 * math.pi)
    d = Vector((math.cos(yaw), math.sin(yaw), 0))
    pts = []
    for i in range(segs + 1):
        t = i / segs
        pts.append(d * (lean * height * t * t) + Vector((0, 0, height * t)))
    for i in range(segs):
        a, b = pts[i], pts[i + 1]
        r0 = 0.32 - 0.14 * (i / segs)
        r1 = 0.32 - 0.14 * ((i + 1) / segs)
        seg = cyl(r0 * 1.12, r1, (b - a).length * 1.02, 6, C["palm_trunk"] if i % 2 else C["palm_trunk_dark"],
                  spin=rng.uniform(0, 1))
        q = (b - a).to_track_quat("Z", "X")
        bmesh.ops.transform(seg, matrix=q.to_matrix().to_4x4(), verts=seg.verts)
        xform(seg, tuple(a))
        parts.append(seg)
    top = pts[-1]
    n_fronds = 9
    for k in range(n_fronds):
        a = 2 * math.pi * k / n_fronds + rng.uniform(-0.2, 0.2)
        dirv = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-math.sin(a), math.cos(a), 0))
        length = rng.uniform(3.3, 3.9)
        rise = rng.uniform(0.5, 0.9)
        widths = [0.08, 0.55, 0.72, 0.6, 0.36, 0.03]
        secs = []
        for i, w in enumerate(widths):
            t = i / (len(widths) - 1)
            c = top + dirv * (length * t) + Vector((0, 0, rise * t - 1.7 * t * t))
            secs.append([tuple(c - side * w), tuple(c + Vector((0, 0, 0.07))),
                         tuple(c + side * w), tuple(c - Vector((0, 0, 0.05)))])
        parts.append(loft(secs, C["leaf"] if k % 2 else C["leaf_dark"]))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        parts.append(ico(0.17, C["coconut"], tuple(top + Vector((math.cos(a) * 0.28, math.sin(a) * 0.28, -0.22))),
                         sub=1, jit=0.05, rng=rng))
    bm = merge(*parts)
    if scale != 1.0:
        xform(bm, scale=(scale, scale, scale))
    return bm


def build_palm(name):
    r = root(name)
    mk(f"{name}_Mesh", palm(seed=4, height=6.8, lean=0.32), r)
    return r


# ------------------------------------------------------------------ island
R0 = 20.0          # beach radius (m)


def island_radius(a):
    return R0 * (1 + 0.13 * math.sin(2 * a + 0.4) + 0.07 * math.sin(5 * a + 1.3) + 0.04 * math.sin(9 * a))


def island_height(x, y):
    a = math.atan2(y, x)
    t = math.hypot(x, y) / island_radius(a)
    if t > 1.0:                                     # underwater shelf down to the sea floor
        return max(-6.5, -0.5 - (t - 1.0) * 22)
    if t > 0.86:                                    # wet sand at the waterline
        return -0.5 + (1.0 - t) / 0.14 * 1.0
    if t > 0.62:                                    # dry beach
        return 0.5 + (0.86 - t) / 0.24 * 0.9
    # grassy interior with a hill to the north-east and a gentle dip by the landing
    base = 1.4 + (0.62 - t) * 3.0
    hill = 5.5 * math.exp(-((x - 4.5) ** 2 + (y - 5.0) ** 2) / 40.0)
    return base + hill


def build_island(name, seed=12):
    rng = random.Random(seed)
    r = root(name)
    bm = new_bm()
    l = L(bm)
    segs, rings = 30, 18
    def ring_r(k):          # in units of the local island radius, extended out to the skirt
        return 1.3 * (k / rings) ** 0.85
    centre = bm.verts.new((0, 0, island_height(0, 0)))
    V = []
    for k in range(1, rings + 1):
        row = []
        for i in range(segs):
            a = 2 * math.pi * i / segs + (math.pi / segs if k % 2 else 0)
            rr = ring_r(k) * island_radius(a)
            x, y = math.cos(a) * rr, math.sin(a) * rr
            z = island_height(x, y)
            if k < rings:
                x += rng.uniform(-0.45, 0.45)
                y += rng.uniform(-0.45, 0.45)
                z += rng.uniform(-0.18, 0.18) if z > 1.4 else rng.uniform(-0.06, 0.06)
            row.append(bm.verts.new((x, y, z)))
        V.append(row)
    faces = []
    for i in range(segs):
        faces.append(bm.faces.new((centre, V[0][i], V[0][(i + 1) % segs])))
    for k in range(rings - 1):
        a_row, b_row = V[k], V[k + 1]
        for i in range(segs):
            j = (i + 1) % segs
            if k % 2 == 0:
                faces += [bm.faces.new((a_row[i], b_row[i], b_row[j])), bm.faces.new((a_row[i], b_row[j], a_row[j]))]
            else:
                faces += [bm.faces.new((a_row[i], b_row[i], a_row[j])), bm.faces.new((a_row[j], b_row[i], b_row[j]))]
    # close the bottom so the mesh is solid
    bot = bm.faces.new([v for v in V[-1]][::-1])
    bm.normal_update()
    for f in faces:
        if f.normal.z < 0:
            f.normal_flip()
    if bot.normal.z > 0:
        bot.normal_flip()
    for f in bm.faces:
        c = f.calc_center_median()
        if f is bot:
            f[l] = C["seabed"]
        elif c.z < -0.6:
            f[l] = C["seabed"]
        elif c.z < 0.45:
            f[l] = C["sand_wet"]
        elif c.z < 1.45:
            f[l] = C["sand"]
        elif f.normal.z < 0.75:
            f[l] = C["cliff"]
        else:
            f[l] = C["turf"] if rng.random() > 0.3 else C["turf_dark"]
    mk(f"{name}_Land", bm, r, recalc=False)

    # ---- props: palms, rocks, bushes, pier, treasure chest
    props = []
    def ground(x, y):
        return island_height(x, y) - 0.15
    for (x, y), s, lean, seed2 in (((-6.0, -4.0), 1.35, 0.38, 2), ((-10.5, 3.0), 1.2, 0.30, 5),
                                   ((-2.0, 10.0), 1.4, 0.25, 7), ((9.0, -6.5), 1.3, 0.40, 9),
                                   ((-12.5, -8.0), 1.1, 0.45, 11), ((13.5, 1.0), 1.15, 0.5, 13)):
        p = palm(seed=seed2, height=6.6, lean=lean, scale=s)
        props.append(xform(p, (x, y, ground(x, y))))
    for (x, y), rx, rz in (((9.0, 8.0), 2.4, 2.0), ((11.5, 5.5), 1.5, 1.3), ((7.0, 10.5), 1.3, 1.0),
                           ((-15.0, 10.0), 1.4, 1.0), ((14.0, -11.0), 1.2, 0.9)):
        pts = []
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=1, radius=1.0)
        for v in tmp.verts:
            k = rng.uniform(0.8, 1.05)
            pts.append(Vector((x + v.co.x * rx * k, y + v.co.y * rx * 0.85 * k,
                               ground(x, y) + max(v.co.z * rz * k + rz * 0.3, 0))))
        tmp.free()
        h = hull(pts, C["rock"])
        h.normal_update()
        for f in h.faces:
            if f.normal.z < -0.2:
                f[L(h)] = C["rock_dark"]
        props.append(h)
    for (x, y), rad in (((-4.5, 3.5), 0.8), ((2.0, -6.5), 0.7), ((-8.0, 7.0), 0.75), ((5.5, 1.0), 0.6)):
        props.append(ico(rad, C["leaf"], (x, y, ground(x, y) + rad * 0.6), scale=(1, 1, 0.8), sub=1, jit=0.1, rng=rng))
        props.append(ico(rad * 0.7, C["leaf_dark"], (x + rad * 0.7, y + 0.2, ground(x, y) + rad * 0.45),
                         scale=(1, 1, 0.8), sub=1, jit=0.1, rng=rng))
    # little pier on the south side, out into the water
    a = -math.pi / 2 - 0.15
    px, py = math.cos(a), math.sin(a)
    start = island_radius(a) * 0.78
    pier = []
    for k in range(16):
        d = start + k * 0.6
        pier.append(box((2.2, 0.55, 0.12), (0, d, 1.1), C["wood"] if k % 3 else C["wood_dark"], bev=0.02))
    for d in (start + 3.0, start + 6.0, start + 9.0):
        for sx in (-1, 1):
            pier.append(cyl(0.14, 0.12, 8.0, 6, C["wood_dark"], loc=(sx * 1.05, d, -6.6)))
    pb = merge(*pier)
    xform(pb, rot=(0, 0, a - math.pi / 2))
    props.append(pb)
    # treasure chest half-buried by the big palm
    cx, cy = -7.2, -2.0
    gz = ground(cx, cy) + 0.1
    chest = merge(box((1.1, 0.75, 0.55), (0, 0, 0.27), C["wood_dark"], bev=0.03),
                  box((1.14, 0.79, 0.12), (0, 0, 0.58), C["gold"]),
                  box((1.1, 0.75, 0.32), (0, 0, 0.78), C["wood"], bev=0.04),
                  box((0.1, 0.8, 0.95), (-0.35, 0, 0.5), C["gold"]),
                  box((0.1, 0.8, 0.95), (0.35, 0, 0.5), C["gold"]),
                  box((0.18, 0.06, 0.2), (0, -0.4, 0.55), C["gold"]))
    xform(chest, scale=(1.4, 1.4, 1.4))
    xform(chest, (cx, cy, gz), rot=(0.06, -0.08, 0.5))
    props.append(chest)
    mk(f"{name}_Props", merge(*props), r)
    return r


def build_all():
    build_palm("Tree_Palm")
    build_island("Island_Palm")
