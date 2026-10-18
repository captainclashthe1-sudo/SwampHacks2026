"""Writes out/ui/TruckLoads.lua with offsets measured from out/level1.blend.  python3 gen_truckloads.py"""
import bpy, os
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
S = 25 / 7
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "out", "level1.blend"))
O = bpy.data.objects
import sys
sys.path.insert(0, HERE)
from loads import BED_POINT, LOADS


def bbox(objs):
    mn, mx = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            p = o.matrix_local @ v.co
            mn = Vector(map(min, mn, p))
            mx = Vector(map(max, mx, p))
    return mn, mx


def to_r(v):          # Blender meters -> Roblox studs (X, Y up, Z = -y)
    return (v.x * S, v.z * S, -v.y * S)


mn, mx = bbox([O["Truck_Orange_Body"]])
body_center = (mn + mx) / 2
bed = to_r(Vector(BED_POINT) - body_center)

info = {}
for n in LOADS:
    mn, mx = bbox(list(O[n].children))
    c, size = (mn + mx) / 2, mx - mn
    off = to_r(-c)
    info[n] = (off, (size.x * S, size.z * S, size.y * S))

lines = []
for n in LOADS:
    off, size = info[n]
    lines.append(f'\t["{n}"] = {{ origin = Vector3.new({off[0]:.3f}, {off[1]:.3f}, {off[2]:.3f}), '
                 f'size = Vector3.new({size[0]:.3f}, {size[1]:.3f}, {size[2]:.3f}) }},')

lua = open(os.path.join(HERE, "ui", "TruckLoads.template.lua")).read()
lua = lua.replace("--@BED_OFFSET@", f"Vector3.new({bed[0]:.3f}, {bed[1]:.3f}, {bed[2]:.3f})")
lua = lua.replace("--@LOAD_INFO@", "\n".join(lines))
lua = lua.replace("--@LOAD_LIST@", ", ".join(f'"{n}"' for n in LOADS))
with open(os.path.join(HERE, "ui", "TruckLoads.lua"), "w") as f:
    f.write(lua)
print("bed offset", bed)
