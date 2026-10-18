"""Low-poly apple (red + green variants). One mesh per apple, origin at the bottom centre.
Real-world size: ~0.36 m wide (about 1.3 studs), handy as a pickup or Tool handle; scale up freely."""
import math, random
import bmesh
from mathutils import Vector
import build as B
from build import new_bm, L, merge, xform, cyl, root, mk

C = B.C


def register_colors():
    for n, hx in [("apple_red", "D7322B"), ("apple_red_dark", "A41F1C"), ("apple_red_light", "E8573A"),
                  ("apple_green", "8CC63F"), ("apple_green_dark", "6A9F2C"), ("apple_green_light", "B5D95A")]:
        if n not in C:
            B.PALETTE.append((n, hx))
            C[n] = len(B.PALETTE) - 1


def apple_body(base, dark, light, seed):
    rng = random.Random(seed)
    seg = 10
    # (z, radius, lobe strength) from bottom to top
    prof = [(0.012, 0.055, 0.10), (0.035, 0.115, 0.08), (0.085, 0.160, 0.05), (0.155, 0.182, 0.02),
            (0.225, 0.172, 0.0), (0.275, 0.130, 0.0), (0.300, 0.070, 0.0)]
    bm = new_bm()
    l = L(bm)
    rings = []
    for k, (z, r, lobe) in enumerate(prof):
        ring = []
        for i in range(seg):
            a = 2 * math.pi * i / seg + (math.pi / seg if k % 2 else 0)   # offset rings -> faceted look
            rr = r * (1 + lobe * math.cos(5 * a)) * rng.uniform(0.97, 1.03)
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z + rng.uniform(-0.004, 0.004))))
        rings.append(ring)
    bot = bm.verts.new((0, 0, 0.03))      # dimple underneath
    top = bm.verts.new((0, 0, 0.262))     # dimple where the stem sits
    faces = []
    for i in range(seg):
        j = (i + 1) % seg
        faces.append(bm.faces.new((bot, rings[0][j], rings[0][i])))
        faces.append(bm.faces.new((top, rings[-1][i], rings[-1][j])))
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            faces.append(bm.faces.new((a[i], a[j], b[j])))
            faces.append(bm.faces.new((a[i], b[j], b[i])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    for f in bm.faces:
        c = f.calc_center_median()
        if f.normal.z < -0.35 or c.z < 0.05:
            f[l] = dark
        elif c.z > 0.17 and rng.random() < 0.35:
            f[l] = light
        else:
            f[l] = base if rng.random() > 0.15 else dark
    return bm


def leaf():
    bm = new_bm()
    pts = {"base": (0, 0, 0), "tip": (0.15, 0, 0.0), "l": (0.07, 0.045, 0.012), "r": (0.07, -0.045, 0.012),
           "up": (0.07, 0, 0.018), "dn": (0.07, 0, -0.004)}
    V = {k: bm.verts.new(p) for k, p in pts.items()}
    for a, b, c in (("base", "l", "up"), ("l", "tip", "up"), ("tip", "r", "up"), ("r", "base", "up"),
                    ("base", "dn", "l"), ("l", "dn", "tip"), ("tip", "dn", "r"), ("r", "dn", "base")):
        bm.faces.new((V[a], V[b], V[c]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f[L(bm)] = C["leaf"]
    return bm


def build_apple(name, kind="red", seed=7):
    r = root(name)
    base, dark, light = (C["apple_red"], C["apple_red_dark"], C["apple_red_light"]) if kind == "red" else \
                        (C["apple_green"], C["apple_green_dark"], C["apple_green_light"])
    body = apple_body(base, dark, light, seed)
    stem = cyl(0.014, 0.010, 0.10, 5, C["trunk"], loc=(0, 0, 0.25), rot=(0, 0.25, 0))
    lf = leaf()
    xform(lf, loc=(0.02, 0.0, 0.32), rot=(0.35, -0.45, 0.6))
    mk(f"{name}_Mesh", merge(body, stem, lf), r)
    return r


def build_all():
    build_apple("Apple_Red", "red", seed=7)
    build_apple("Apple_Green", "green", seed=11)
