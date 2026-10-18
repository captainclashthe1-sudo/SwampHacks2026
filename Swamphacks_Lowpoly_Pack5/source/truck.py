"""Low-poly pickup truck. Same conventions as the car: origin at ground centre, front = +Y
(Roblox -Z / LookVector), Body + four separate wheels pivoting at their centres."""
import math
import bmesh
import build as B
from build import new_bm, L, paint, merge, xform, bevel, box, cyl, frustum, prism_x, root, mk, boolean_cut

C = B.C
WR, WW = 0.48, 0.36            # wheel radius, width
AX_F, AX_R, TRACK = 1.55, -1.75, 0.86


def build_truck(name, paint_cid):
    r = root(name)
    prof = [(-2.60, 0.55), (2.45, 0.55), (2.62, 0.75), (2.60, 1.15), (2.45, 1.30), (1.00, 1.35),
            (-2.55, 1.35), (-2.62, 1.25), (-2.62, 0.70)]
    body = bevel(prism_x(prof, -1.05, 1.05, paint_cid), 0.05)
    paint(body, paint_cid)
    cutters = []
    for sx in (-1, 1):
        for ay in (AX_F, AX_R):
            cutters.append(cyl(0.60, 0.60, 0.60, 12, C["trim"], loc=(sx * 1.08, ay, WR),
                               rot=(0, math.pi / 2, 0), centered=True, spin=math.pi / 12))
    cutters.append(box((1.80, 1.92, 1.0), (0, -1.56, 1.35), C["bumper"]))   # the open bed
    body = boolean_cut(body, cutters)

    cab = frustum((0, 0.24, 1.33, 1.96, 1.62), (0, 0.05, 2.18, 1.70, 1.10), paint_cid, bev=0.05)
    cab.normal_update()
    sides = [f for f in cab.faces if abs(f.normal.z) < 0.95 and f.calc_area() > 0.25]
    bmesh.ops.inset_individual(cab, faces=sides, thickness=0.08, depth=-0.015, use_even_offset=True)
    for f in sides:
        f[L(cab)] = C["glass"]

    parts = [
        # front: bumper, big grille with chrome bars, headlights
        box((2.20, 0.26, 0.30), (0, 2.60, 0.66), C["chrome"], bev=0.05),
        box((1.10, 0.08, 0.36), (0, 2.62, 1.00), C["trim"]),
        box((1.14, 0.10, 0.05), (0, 2.63, 1.12), C["chrome"]),
        box((1.14, 0.10, 0.05), (0, 2.63, 0.98), C["chrome"]),
        box((1.14, 0.10, 0.05), (0, 2.63, 0.86), C["chrome"]),
        box((0.36, 0.10, 0.22), (-0.78, 2.61, 1.02), C["headlight"], bev=0.02),
        box((0.36, 0.10, 0.22), (0.78, 2.61, 1.02), C["headlight"], bev=0.02),
        # rear: bumper, tailgate handle, tall tail lights, plate
        box((2.20, 0.24, 0.26), (0, -2.66, 0.66), C["bumper"], bev=0.05),
        box((0.40, 0.06, 0.08), (0, -2.64, 1.20), C["trim"]),
        box((0.10, 0.08, 0.40), (-0.98, -2.63, 1.05), C["taillight"]),
        box((0.10, 0.08, 0.40), (0.98, -2.63, 1.05), C["taillight"]),
        box((0.44, 0.04, 0.14), (0, -2.79, 0.68), C["white"]),
        # bed rails, running boards, mirrors, door handles, roof lights
        box((0.14, 1.95, 0.06), (-0.98, -1.56, 1.38), C["trim"]),
        box((0.14, 1.95, 0.06), (0.98, -1.56, 1.38), C["trim"]),
        box((1.96, 0.14, 0.06), (0, -2.55, 1.38), C["trim"]),
        box((0.22, 1.05, 0.07), (-1.15, -0.10, 0.55), C["metal"]),
        box((0.22, 1.05, 0.07), (1.15, -0.10, 0.55), C["metal"]),
        box((0.06, 0.24, 0.20), (-1.13, 0.95, 1.55), C["trim"], bev=0.02),
        box((0.06, 0.24, 0.20), (1.13, 0.95, 1.55), C["trim"], bev=0.02),
        box((0.20, 0.06, 0.06), (-1.04, 0.95, 1.50), C["trim"]),
        box((0.20, 0.06, 0.06), (1.04, 0.95, 1.50), C["trim"]),
        box((0.05, 0.24, 0.05), (-1.06, 0.10, 1.20), C["chrome"]),
        box((0.05, 0.24, 0.05), (1.06, 0.10, 1.20), C["chrome"]),
        box((1.20, 0.22, 0.10), (0, 0.42, 2.24), C["trim"]),
    ]
    for x in (-0.42, -0.14, 0.14, 0.42):
        parts.append(box((0.18, 0.08, 0.10), (x, 0.54, 2.25), C["glow"]))
    # bed floor ribs
    for x in (-0.55, 0, 0.55):
        parts.append(box((0.10, 1.85, 0.03), (x, -1.56, 0.86), C["bumper"]))
    merge(body, cab, *parts)
    mk(f"{name}_Body", body, r)

    for tag, sx, ay in (("FL", -1, AX_F), ("FR", 1, AX_F), ("RL", -1, AX_R), ("RR", 1, AX_R)):
        w = cyl(WR, WR, WW, 10, C["tire"], rot=(0, math.pi / 2, 0), centered=True, bev=0.06)
        hub = cyl(0.28, 0.26, 0.05, 10, C["rim"], loc=(sx * (WW / 2 + 0.005), 0, 0),
                  rot=(0, sx * math.pi / 2, 0), centered=True)
        cap = cyl(0.10, 0.07, 0.05, 6, C["metal"], loc=(sx * (WW / 2 + 0.045), 0, 0),
                  rot=(0, sx * math.pi / 2, 0), centered=True)
        lugs = []
        for k in range(5):
            a = k * 2 * math.pi / 5
            lugs.append(cyl(0.03, 0.03, 0.05, 5, C["metal"],
                            loc=(sx * (WW / 2 + 0.035), math.cos(a) * 0.17, math.sin(a) * 0.17),
                            rot=(0, sx * math.pi / 2, 0), centered=True))
        merge(w, hub, cap, *lugs)
        mk(f"{name}_Wheel_{tag}", w, r, loc=(sx * TRACK, ay, WR))
    return r


def build_all():
    build_truck("Truck_Orange", C["cone"])
    build_truck("Truck_Blue", C["car_blue"])
