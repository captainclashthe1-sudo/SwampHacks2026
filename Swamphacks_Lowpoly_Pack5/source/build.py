"""Low-poly Roblox-style asset pack: car + scenery.
Run: python3 build.py   (needs `pip install bpy`)
Units are meters; Roblox's importer converts at ~3.57 studs per meter
(11.2 m = 40 studs), so road tiles are 40x40 studs.
Every model uses ONE shared palette texture (palette.png); each face's UVs
point at the centre of a flat colour cell.
"""
import bpy, bmesh, math, random, os
from mathutils import Matrix, Vector, Euler

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(os.path.join(OUT, "models"), exist_ok=True)

# ------------------------------------------------------------------ palette
PALETTE = [
    ("car_red", "D9443A"), ("car_blue", "3A7BD9"), ("car_yellow", "F2B83A"), ("tire", "2B2B30"),
    ("rim", "C8CCD2"), ("glass", "2F4C6B"), ("headlight", "FFF2B0"), ("taillight", "B5161B"),
    ("leaf", "45A84F"), ("leaf_dark", "2F8A3C"), ("pine", "2E9457"), ("trunk", "7A4E2D"),
    ("wood", "C48A55"), ("rock", "BCC1C7"), ("rock_dark", "9AA0A7"), ("grass", "6CC05A"),
    ("asphalt", "4A4D55"), ("sidewalk", "BDB8AD"), ("curb", "9C978C"), ("line_white", "F2F2EE"),
    ("line_yellow", "F2C531"), ("metal", "3C4048"), ("glow", "FFD36B"), ("cone", "F27A21"),
    ("white", "F4F4F4"), ("sign_red", "C9302C"), ("hydrant", "D23B2F"), ("trim", "1E1F24"),
    ("chrome", "A9B0B8"), ("bumper", "55585F"), ("flower", "F5D04A"), ("wood_dark", "8F5E36"),
]
C = {n: i for i, (n, _) in enumerate(PALETTE)}
GRID = 8  # 8x8 cells
TEX = 512


def make_palette_image():
    img = bpy.data.images.new("palette", TEX, TEX, alpha=False)
    cell = TEX // GRID
    px = [0.0] * (TEX * TEX * 4)
    for i, (_, hx) in enumerate(PALETTE):
        r, g, b = (int(hx[k:k + 2], 16) / 255 for k in (0, 2, 4))
        col, row = i % GRID, i // GRID          # row 0 = top of the PNG
        y0 = (GRID - 1 - row) * cell             # blender pixels start at bottom
        for y in range(y0, y0 + cell):
            for x in range(col * cell, col * cell + cell):
                o = (y * TEX + x) * 4
                px[o:o + 4] = (r, g, b, 1.0)
    img.pixels = px
    img.filepath_raw = os.path.join(OUT, "palette.png")
    img.file_format = "PNG"
    img.save()
    return img


def cell_uv(i):
    col, row = i % GRID, i // GRID
    return ((col + 0.5) / GRID, 1 - (row + 0.5) / GRID)


# ------------------------------------------------------------------ bmesh helpers
def new_bm():
    bm = bmesh.new()
    bm.faces.layers.int.new("cid")
    return bm


def L(bm):
    return bm.faces.layers.int["cid"]


def paint(bm, cid):
    l = L(bm)
    for f in bm.faces:
        f[l] = cid
    return bm


def merge(dst, *srcs):
    for src in srcs:
        src.verts.index_update()
        vm = [dst.verts.new(v.co) for v in src.verts]
        ls, ld = L(src), L(dst)
        for f in src.faces:
            try:
                nf = dst.faces.new([vm[v.index] for v in f.verts])
                nf[ld] = f[ls]
            except ValueError:
                pass
        src.free()
    return dst


def xform(bm, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    M = Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*scale, 1))
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm


def bevel(bm, off):
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=off, offset_type="OFFSET",
                    segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
    return bm


def top_paint(bm, cid, thresh=0.7):
    bm.normal_update()
    l = L(bm)
    for f in bm.faces:
        if f.normal.z > thresh:
            f[l] = cid
    return bm


def box(size, loc=(0, 0, 0), cid=0, rot=(0, 0, 0), bev=0.0, top=None):
    bm = new_bm()
    bmesh.ops.create_cube(bm, size=1.0)
    xform(bm, scale=size)
    if bev:
        bevel(bm, bev)
    paint(bm, cid)
    if top is not None:
        top_paint(bm, top)
    return xform(bm, loc, rot)


def cyl(r1, r2, h, seg, cid, loc=(0, 0, 0), rot=(0, 0, 0), bev=0.0, centered=False, spin=0.0):
    """Cylinder/cone along local Z. Base at z=0 unless centered."""
    bm = new_bm()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                          radius1=r1, radius2=r2, depth=h)
    if spin:
        xform(bm, rot=(0, 0, spin))
    if not centered:
        xform(bm, (0, 0, h / 2))
    if bev:
        bevel(bm, bev)
    paint(bm, cid)
    return xform(bm, loc, rot)


def ico(r, cid, loc=(0, 0, 0), scale=(1, 1, 1), sub=2, jit=0.0, rng=None):
    bm = new_bm()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    if jit and rng:
        for v in bm.verts:
            v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * jit * r
    paint(bm, cid)
    return xform(bm, loc, scale=scale)


def hull(points, cid):
    bm = new_bm()
    vs = [bm.verts.new(p) for p in points]
    ret = bmesh.ops.convex_hull(bm, input=vs)
    dead = {g for g in ret["geom_interior"] + ret["geom_unused"] if isinstance(g, bmesh.types.BMVert)}
    if dead:
        bmesh.ops.delete(bm, geom=list(dead), context="VERTS")
    return paint(bm, cid)


def frustum(b, t, cid, bev=0.0):
    """b/t = (cx, cy, z, width_x, depth_y). Lofted box."""
    bm = new_bm()
    def ring(cx, cy, z, w, d):
        return [bm.verts.new((cx + sx * w / 2, cy + sy * d / 2, z))
                for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    a, c = ring(*b), ring(*t)
    bm.faces.new(list(reversed(a)))
    bm.faces.new(c)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((a[i], a[j], c[j], c[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bev:
        bevel(bm, bev)
    return paint(bm, cid)


def prism_x(profile, x0, x1, cid):
    """Extrude a (y, z) profile polygon along X."""
    bm = new_bm()
    a = [bm.verts.new((x0, y, z)) for y, z in profile]
    b = [bm.verts.new((x1, y, z)) for y, z in profile]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], b[i], b[j], a[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return paint(bm, cid)


def slab(polys, z0, z1, top_cid, side_cid):
    """Polygons (lists of xy) sharing verts, extruded from z0 to z1."""
    bm = new_bm()
    l = L(bm)
    key = {}
    def V(p):
        k = (round(p[0], 4), round(p[1], 4))
        if k not in key:
            key[k] = bm.verts.new((p[0], p[1], z1))
        return key[k]
    tops = []
    for poly in polys:
        f = bm.faces.new([V(p) for p in poly])
        tops.append(f)
    bm.normal_update()
    for f in tops:
        if f.normal.z < 0:
            f.normal_flip()
    ret = bmesh.ops.extrude_face_region(bm, geom=tops)
    nv = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, 0, z0 - z1), verts=nv)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    for f in bm.faces:
        f[l] = top_cid if f.normal.z > 0.5 else side_cid
    return bm


# ------------------------------------------------------------------ scene objects
COLL = bpy.context.scene.collection
MODELS = {}  # name -> root empty


def root(name):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.5
    COLL.objects.link(e)
    MODELS[name] = e
    return e


def mk(name, bm, parent, loc=(0, 0, 0), recalc=True):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.parent = parent
    COLL.objects.link(ob)
    return ob


def boolean_cut(bm, cutters):
    """Exact boolean difference; returns a new bmesh."""
    tmp = mk("_tmp", bm, None)
    cuts = []
    for i, c in enumerate(cutters):
        co = mk(f"_cut{i}", c, None)
        cuts.append(co)
        m = tmp.modifiers.new(f"b{i}", "BOOLEAN")
        m.operation = "DIFFERENCE"
        m.solver = "EXACT"
        m.object = co
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    out = bmesh.new()
    out.from_mesh(me)
    if "cid" not in out.faces.layers.int:
        out.faces.layers.int.new("cid")
    for o in cuts + [tmp]:
        bpy.data.objects.remove(o)
    bpy.data.meshes.remove(me)
    return out


# ================================================================== CAR
WR, WZ, WY, WX, WW = 0.40, 0.40, 1.35, 0.80, 0.30


def build_car(name, paint_cid):
    r = root(name)
    prof = [(-2.10, 0.30), (2.05, 0.30), (2.18, 0.50), (2.16, 0.80), (2.00, 0.93),
            (0.90, 0.98), (-2.00, 0.98), (-2.18, 0.87), (-2.18, 0.50)]
    body = bevel(prism_x(prof, -0.95, 0.95, paint_cid), 0.05)
    paint(body, paint_cid)
    cutters = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            cutters.append(cyl(0.49, 0.49, 0.70, 12, C["trim"], loc=(sx * 0.93, sy * WY, WZ),
                               rot=(0, math.pi / 2, 0), centered=True, spin=math.pi / 12))
    body = boolean_cut(body, cutters)

    # cabin with inset windows
    cab = frustum((0, -0.35, 0.95, 1.80, 2.25), (0, -0.58, 1.52, 1.46, 1.30), paint_cid, bev=0.04)
    cab.normal_update()
    sides = [f for f in cab.faces if abs(f.normal.z) < 0.95 and f.calc_area() > 0.15]
    bmesh.ops.inset_individual(cab, faces=sides, thickness=0.07, depth=-0.015, use_even_offset=True)
    l = L(cab)
    for f in sides:
        f[l] = C["glass"]
    # B-pillar strip on each side window
    pil = [box((0.04, 0.12, 0.50), (sx * 0.845, -0.50, 1.22), paint_cid, rot=(0, -sx * 0.09, 0)) for sx in (-1, 1)]

    parts = [
        box((1.96, 0.20, 0.22), (0, 2.16, 0.40), C["bumper"], bev=0.04),
        box((1.96, 0.20, 0.22), (0, -2.19, 0.40), C["bumper"], bev=0.04),
        box((0.70, 0.06, 0.16), (0, 2.17, 0.66), C["trim"]),
        box((0.40, 0.04, 0.13), (0, -2.30, 0.42), C["white"]),
        box((0.36, 0.08, 0.15), (-0.62, 2.16, 0.70), C["headlight"], bev=0.02),
        box((0.36, 0.08, 0.15), (0.62, 2.16, 0.70), C["headlight"], bev=0.02),
        box((0.40, 0.08, 0.13), (-0.64, -2.18, 0.74), C["taillight"], bev=0.02),
        box((0.40, 0.08, 0.13), (0.64, -2.18, 0.74), C["taillight"], bev=0.02),
        box((0.16, 0.10, 0.11), (-1.00, 0.62, 1.04), paint_cid, bev=0.02),
        box((0.16, 0.10, 0.11), (1.00, 0.62, 1.04), paint_cid, bev=0.02),
        box((0.05, 0.22, 0.04), (-0.96, 0.10, 0.80), C["chrome"]),   # door handles
        box((0.05, 0.22, 0.04), (0.96, 0.10, 0.80), C["chrome"]),
        box((0.05, 0.22, 0.04), (-0.96, -0.95, 0.80), C["chrome"]),
        box((0.05, 0.22, 0.04), (0.96, -0.95, 0.80), C["chrome"]),
    ]
    merge(body, cab, *pil, *parts)
    mk(f"{name}_Body", body, r)

    for tag, sx, sy in (("FL", -1, 1), ("FR", 1, 1), ("RL", -1, -1), ("RR", 1, -1)):
        w = cyl(WR, WR, WW, 10, C["tire"], rot=(0, math.pi / 2, 0), centered=True, bev=0.05)
        hub = cyl(0.25, 0.22, 0.05, 10, C["rim"], loc=(sx * (WW / 2 + 0.005), 0, 0),
                  rot=(0, sx * math.pi / 2, 0), centered=True)
        cap = cyl(0.08, 0.06, 0.04, 6, C["metal"], loc=(sx * (WW / 2 + 0.04), 0, 0),
                  rot=(0, sx * math.pi / 2, 0), centered=True)
        merge(w, hub, cap)
        mk(f"{name}_Wheel_{tag}", w, r, loc=(sx * WX, sy * WY, WZ))
    return r


# ================================================================== NATURE
def build_tree_round(name, seed=3):
    rng = random.Random(seed)
    r = root(name)
    trunk = cyl(0.34, 0.20, 2.6, 6, C["trunk"])
    roots = [box((0.18, 0.42, 0.16), (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.06), C["trunk"],
                 rot=(0.25, 0, a - math.pi / 2)) for a in (0.3, 2.4, 4.4)]
    branch = box((0.14, 0.14, 1.0), (0.35, 0, 2.3), C["trunk"], rot=(0, 0.6, 0))
    merge(trunk, *roots, branch)
    mk(f"{name}_Trunk", trunk, r)
    blobs = [((0, 0, 3.7), 1.65, "leaf"), ((1.05, 0.35, 3.25), 1.10, "leaf_dark"),
             ((-0.95, -0.35, 3.35), 1.20, "leaf_dark"), ((0.15, 0.55, 4.55), 1.05, "leaf"),
             ((-0.2, -0.8, 4.1), 0.9, "leaf")]
    can = new_bm()
    for loc, rad, col in blobs:
        merge(can, ico(rad, C[col], loc, scale=(1, 1, 0.88), sub=2, jit=0.07, rng=rng))
    mk(f"{name}_Leaves", can, r)
    return r


def build_tree_pine(name, seed=7):
    rng = random.Random(seed)
    r = root(name)
    mk(f"{name}_Trunk", cyl(0.24, 0.16, 1.3, 6, C["trunk"]), r)
    tiers = [(0.9, 1.75, 1.60), (1.85, 1.38, 1.45), (2.75, 1.02, 1.35), (3.6, 0.66, 1.45)]
    lv = new_bm()
    for i, (z, rad, h) in enumerate(tiers):
        top = 0.0 if i == len(tiers) - 1 else rad * 0.22
        t = cyl(rad, top, h, 8, C["pine"], loc=(0, 0, z), spin=rng.uniform(0, 1))
        for v in t.verts:
            if v.co.z < z + 0.01:
                v.co.x += rng.uniform(-0.08, 0.08) * rad
                v.co.y += rng.uniform(-0.08, 0.08) * rad
                v.co.z -= rng.uniform(0, 0.12)
        merge(lv, t)
    mk(f"{name}_Leaves", lv, r)
    return r


def build_bush(name, seed=11):
    rng = random.Random(seed)
    r = root(name)
    bm = new_bm()
    for loc, rad, col in (((0, 0, 0.45), 0.70, "leaf"), ((0.62, 0.15, 0.35), 0.50, "leaf_dark"),
                          ((-0.55, -0.2, 0.33), 0.52, "leaf_dark"), ((0.1, -0.45, 0.30), 0.45, "leaf")):
        merge(bm, ico(rad, C[col], loc, scale=(1, 1, 0.82), sub=1, jit=0.08, rng=rng))
    mk(f"{name}_Mesh", bm, r)
    return r


def rock_points(rng, n, rx, ry, rz, loc):
    """Jittered icosphere verts, bottom flattened -> chunky low-poly boulder."""
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=2, radius=1.0)
    pts = []
    for v in tmp.verts:
        if rng.random() < 0.45:   # drop some verts so facets get bigger / irregular
            continue
        k = rng.uniform(0.82, 1.05)
        z = max(v.co.z * rz * k + rz * 0.25, 0.0)
        pts.append(Vector((loc[0] + v.co.x * rx * k, loc[1] + v.co.y * ry * k, loc[2] + z)))
    tmp.free()
    return pts


def build_rock(name, big=True, seed=5):
    rng = random.Random(seed)
    r = root(name)
    bm = new_bm()
    specs = ([((0, 0, 0), 1.5, 1.15, 1.35, 20), ((1.3, 0.5, 0), 0.9, 0.8, 0.85, 14)] if big else
             [((0, 0, 0), 0.55, 0.45, 0.52, 12), ((0.62, 0.25, 0), 0.34, 0.3, 0.33, 10),
              ((-0.48, 0.35, 0), 0.27, 0.25, 0.26, 9)])
    for loc, rx, ry, rz, n in specs:
        h = hull(rock_points(rng, n, rx, ry, rz, loc), C["rock"])
        top_paint(h, C["rock"])
        h.normal_update()
        for f in h.faces:
            if f.normal.z < -0.2:
                f[L(h)] = C["rock_dark"]
        merge(bm, h)
    mk(f"{name}_Mesh", bm, r)
    return r


def build_grass(name, seed=13):
    rng = random.Random(seed)
    r = root(name)
    bm = new_bm()
    for i in range(9):
        a = i / 9 * 2 * math.pi + rng.uniform(-0.2, 0.2)
        d = rng.uniform(0.02, 0.12)
        h = rng.uniform(0.35, 0.6)
        b = cyl(0.05, 0.0, h, 3, C["grass"], spin=rng.uniform(0, 3))
        xform(b, (math.cos(a) * d, math.sin(a) * d, 0), rot=(0, 0, 0))
        xform(b, rot=(math.sin(a) * -0.45, math.cos(a) * 0.45, 0))
        merge(bm, b)
    for k in range(2):  # two little flowers
        a = rng.uniform(0, 2 * math.pi)
        fx, fy, fh = math.cos(a) * 0.1, math.sin(a) * 0.1, 0.62 + k * 0.08
        merge(bm, cyl(0.015, 0.015, fh, 4, C["grass"], loc=(fx, fy, 0)),
              cyl(0.09, 0.03, 0.04, 6, C["flower"], loc=(fx, fy, fh)))
    mk(f"{name}_Mesh", bm, r)
    return r


# ================================================================== ROADS (11.2 m = 40 studs)
T = 5.6          # half tile
AW = 4.2         # half asphalt width (30 studs road)
A_H, S_H = 0.14, 0.28


def build_road_straight(name):
    r = root(name)
    asp = slab([[(-AW, -T), (AW, -T), (AW, T), (-AW, T)]], 0, A_H, C["asphalt"], C["asphalt"])
    lines = [box((0.16, 1.4, 0.02), (0, y, A_H), C["line_yellow"]) for y in (-4.2, -1.4, 1.4, 4.2)]
    edges = [box((0.14, 2 * T, 0.02), (sx * (AW - 0.3), 0, A_H), C["line_white"]) for sx in (-1, 1)]
    merge(asp, *lines, *edges)
    mk(f"{name}_Asphalt", asp, r)
    sw = new_bm()
    for sx in (-1, 1):
        x0, x1 = sorted((sx * AW, sx * T))
        merge(sw, slab([[(x0, -T), (x1, -T), (x1, T), (x0, T)]], 0, S_H, C["sidewalk"], C["curb"]))
        for y in (-2.8, 0, 2.8):  # paving grooves
            merge(sw, box((1.4, 0.05, 0.01), ((x0 + x1) / 2, y, S_H), C["curb"]))
    mk(f"{name}_Sidewalk", sw, r)
    return r


def arc(cx, cy, rad, a0, a1, n):
    return [(cx + math.cos(a0 + (a1 - a0) * i / n) * rad, cy + math.sin(a0 + (a1 - a0) * i / n) * rad)
            for i in range(n + 1)]


def ring_polys(cx, cy, r0, r1, a0, a1, n):
    i, o = arc(cx, cy, r0, a0, a1, n), arc(cx, cy, r1, a0, a1, n)
    return [[i[k], o[k], o[k + 1], i[k + 1]] for k in range(n)]


def build_road_corner(name):
    r = root(name)
    cx, cy = T, -T
    a0, a1, N = math.pi / 2, math.pi, 8
    r_in, r_out = T - AW, T + AW   # 1.4, 9.8
    asp = slab(ring_polys(cx, cy, r_in, r_out, a0, a1, N), 0, A_H, C["asphalt"], C["asphalt"])
    for rad in (r_in + 0.3, r_out - 0.3):
        merge(asp, slab(ring_polys(cx, cy, rad - 0.07, rad + 0.07, a0, a1, N), A_H, A_H + 0.02,
                        C["line_white"], C["line_white"]))
    for t in (1 / 6, 3 / 6, 5 / 6):  # yellow dashes along the centre arc
        a = a0 + (a1 - a0) * t
        span = 0.7 / T
        merge(asp, slab(ring_polys(cx, cy, T - 0.08, T + 0.08, a - span, a + span, 2), A_H, A_H + 0.02,
                        C["line_yellow"], C["line_yellow"]))
    mk(f"{name}_Asphalt", asp, r)
    inner = arc(cx, cy, r_in, a0, a1, 4)
    sw = slab([[(cx, cy)] + inner], 0, S_H, C["sidewalk"], C["curb"])
    outer_ring = ring_polys(cx, cy, r_out, 2 * T, a0, a1, N)
    o = arc(cx, cy, 2 * T, a0, a1, N)
    fan = [[(-T, T), o[k + 1], o[k]] for k in range(N)]
    merge(sw, slab(outer_ring + fan, 0, S_H, C["sidewalk"], C["curb"]))
    mk(f"{name}_Sidewalk", sw, r)
    return r


def build_road_cross(name):
    r = root(name)
    c = T - AW  # 1.4 corner radius
    pts = []
    for (qx, qy, a0) in ((T, -T, math.pi / 2), (-T, -T, 0), (-T, T, 1.5 * math.pi), (T, T, math.pi)):
        pts += arc(qx, qy, c, a0, a0 + math.pi / 2, 4)
    asp = slab([pts], 0, A_H, C["asphalt"], C["asphalt"])
    for rot in range(4):  # zebra crossings near each edge
        ang = rot * math.pi / 2
        for k in range(-3, 4):
            x = k * 1.0
            p = Vector((x, T - 1.2, 0))
            p.rotate(Euler((0, 0, ang)))
            merge(asp, box((0.55, 1.5, 0.02), (p.x, p.y, A_H), C["line_white"], rot=(0, 0, ang)))
    mk(f"{name}_Asphalt", asp, r)
    sw = new_bm()
    for (qx, qy, a0) in ((T, -T, math.pi / 2), (T, T, math.pi), (-T, T, 1.5 * math.pi), (-T, -T, 0)):
        merge(sw, slab([[(qx, qy)] + arc(qx, qy, c, a0, a0 + math.pi / 2, 4)], 0, S_H, C["sidewalk"], C["curb"]))
    mk(f"{name}_Sidewalk", sw, r)
    return r


# ================================================================== STREET PROPS
def build_street_lamp(name):
    r = root(name)
    bm = merge(cyl(0.28, 0.24, 0.35, 8, C["metal"], bev=0.03),
               cyl(0.10, 0.07, 5.2, 6, C["metal"], loc=(0, 0, 0.35)),
               cyl(0.13, 0.13, 0.12, 6, C["metal"], loc=(0, 0, 1.4)),
               box((0.09, 1.25, 0.09), (0, 0.55, 5.45), C["metal"], rot=(0.18, 0, 0)),
               box((0.07, 0.6, 0.07), (0, 0.2, 5.15), C["metal"], rot=(-0.75, 0, 0)),
               frustum((0, 1.25, 5.42, 0.42, 0.62), (0, 1.25, 5.62, 0.22, 0.34), C["metal"], bev=0.02))
    mk(f"{name}_Pole", bm, r)
    mk(f"{name}_Bulb", box((0.34, 0.52, 0.06), (0, 1.25, 5.39), C["glow"]), r)
    return r


def build_cone(name):
    r = root(name)
    bm = merge(box((0.50, 0.50, 0.05), (0, 0, 0.025), C["cone"], bev=0.015),
               cyl(0.19, 0.145, 0.22, 8, C["cone"], loc=(0, 0, 0.05)),
               cyl(0.145, 0.11, 0.15, 8, C["white"], loc=(0, 0, 0.27)),
               cyl(0.11, 0.035, 0.26, 8, C["cone"], loc=(0, 0, 0.42)))
    mk(f"{name}_Mesh", bm, r)
    return r


def build_barrier(name):
    r = root(name)
    bm = new_bm()
    for sx in (-0.85, 0.85):
        for sy in (-1, 1):
            merge(bm, box((0.08, 0.08, 1.1), (sx, sy * 0.2, 0.52), C["white"], rot=(sy * -0.38, 0, 0)))
    n = 7
    for i in range(n):
        w = 2.1 / n
        merge(bm, box((w, 0.06, 0.28), (-1.05 + w * (i + 0.5), 0, 0.85), C["sign_red"] if i % 2 == 0 else C["white"]))
    merge(bm, box((2.1, 0.06, 0.12), (0, 0, 0.45), C["white"]))
    for sx in (-0.85, 0.85):
        merge(bm, box((0.16, 0.16, 0.12), (sx, 0, 1.06), C["metal"]))
    mk(f"{name}_Mesh", bm, r)
    mk(f"{name}_Lights", merge(box((0.12, 0.08, 0.10), (-0.85, 0, 1.17), C["cone"]),
                               box((0.12, 0.08, 0.10), (0.85, 0, 1.17), C["cone"])), r)
    return r


def build_fence(name):
    r = root(name)
    bm = new_bm()
    for x in (-1.2, 1.2):
        merge(bm, box((0.14, 0.14, 1.15), (x, 0, 0.575), C["wood_dark"], bev=0.02),
              frustum((x, 0, 1.15, 0.16, 0.16), (x, 0, 1.25, 0.04, 0.04), C["wood_dark"]))
    for z in (0.35, 0.8):
        merge(bm, box((2.5, 0.06, 0.1), (0, 0.08, z), C["wood_dark"]))
    for i in range(9):
        x = -1.0 + i * 0.25
        merge(bm, box((0.13, 0.04, 0.85), (x, 0.13, 0.5), C["wood"]),
              frustum((x, 0.13, 0.925, 0.13, 0.04), (x, 0.13, 1.02, 0.02, 0.04), C["wood"]))
    mk(f"{name}_Mesh", bm, r)
    return r


def build_stop_sign(name):
    r = root(name)
    pole = cyl(0.04, 0.04, 2.35, 6, C["chrome"])
    plate = cyl(0.40, 0.40, 0.04, 8, C["sign_red"], rot=(math.pi / 2, 0, 0), centered=True, spin=math.pi / 8)
    plate.normal_update()
    front = [f for f in plate.faces if f.normal.y < -0.9][0]  # after rot, local +z -> -y
    back = [f for f in plate.faces if f.normal.y > 0.9][0]
    l = L(plate)
    back[l] = C["metal"]
    ret = bmesh.ops.inset_individual(plate, faces=[front], thickness=0.045, depth=0.005)
    for f in ret["faces"]:
        f[l] = C["white"]
    xform(plate, (0, -0.06, 2.15))
    mk(f"{name}_Mesh", merge(pole, plate), r)
    return r


def build_hydrant(name):
    r = root(name)
    bm = merge(cyl(0.21, 0.21, 0.07, 8, C["hydrant"]),
               cyl(0.15, 0.15, 0.45, 8, C["hydrant"], loc=(0, 0, 0.07)),
               cyl(0.18, 0.18, 0.06, 8, C["hydrant"], loc=(0, 0, 0.50)),
               cyl(0.15, 0.05, 0.14, 8, C["hydrant"], loc=(0, 0, 0.56)),
               cyl(0.045, 0.03, 0.06, 5, C["chrome"], loc=(0, 0, 0.70)),
               cyl(0.065, 0.06, 0.12, 6, C["chrome"], loc=(0.15, 0, 0.36), rot=(0, math.pi / 2, 0), centered=True),
               cyl(0.065, 0.06, 0.12, 6, C["chrome"], loc=(-0.15, 0, 0.36), rot=(0, -math.pi / 2, 0), centered=True),
               cyl(0.085, 0.08, 0.12, 6, C["chrome"], loc=(0, -0.15, 0.33), rot=(math.pi / 2, 0, 0), centered=True))
    mk(f"{name}_Mesh", bm, r)
    return r


def build_bench(name):
    r = root(name)
    bm = new_bm()
    for y in (-0.14, 0.0, 0.14):
        merge(bm, box((1.7, 0.12, 0.05), (0, y, 0.46), C["wood"], bev=0.01))
    for z in (0.66, 0.84):
        merge(bm, box((1.7, 0.05, 0.13), (0, 0.23 + (z - 0.6) * 0.18, z), C["wood"], rot=(-0.18, 0, 0), bev=0.01))
    for x in (-0.7, 0.7):
        merge(bm, box((0.06, 0.06, 0.44), (x, -0.16, 0.22), C["metal"]),
              box((0.06, 0.06, 0.92), (x, 0.2, 0.46), C["metal"], rot=(-0.18, 0, 0)),
              box((0.06, 0.42, 0.05), (x, 0.0, 0.42), C["metal"]))
    mk(f"{name}_Mesh", bm, r)
    return r


# ================================================================== BUILD ALL
def finalize(pal_img):
    mat = bpy.data.materials.new("Palette")
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = pal_img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    for ob in COLL.objects:
        if ob.type != "MESH":
            continue
        me = ob.data
        uv = me.uv_layers.new(name="UVMap")
        attr = me.attributes["cid"]
        for p in me.polygons:
            u, v = cell_uv(attr.data[p.index].value)
            for li in p.loop_indices:
                uv.data[li].uv = (u, v)
        me.attributes.remove(me.attributes["cid"])
        me.materials.append(mat)


def export(root_obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    root_obj.select_set(True)
    for c in root_obj.children_recursive:
        c.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True)


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    COLL = bpy.context.scene.collection
    pal = make_palette_image()
    build_car("Car_Red", C["car_red"])
    build_car("Car_Blue", C["car_blue"])
    build_car("Car_Yellow", C["car_yellow"])
    build_tree_round("Tree_Round")
    build_tree_pine("Tree_Pine")
    build_bush("Bush")
    build_rock("Rock_Large", big=True)
    build_rock("Rock_Small", big=False, seed=21)
    build_grass("Grass_Tuft")
    build_road_straight("Road_Straight")
    build_road_corner("Road_Corner")
    build_road_cross("Road_Intersection")
    build_street_lamp("Street_Lamp")
    build_cone("Traffic_Cone")
    build_barrier("Road_Barrier")
    build_fence("Picket_Fence")
    build_stop_sign("Stop_Sign")
    build_hydrant("Fire_Hydrant")
    build_bench("Park_Bench")
    finalize(pal)
    for n, ro in MODELS.items():
        export(ro, os.path.join(OUT, "models", f"{n}.glb"))
    tris = {}
    for n, ro in MODELS.items():
        t = 0
        for c in ro.children:
            c.data.calc_loop_triangles()
            t += len(c.data.loop_triangles)
        tris[n] = t
    print("TRIS", tris)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "pack.blend"))
