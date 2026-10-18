"""Render previews from out/pack.blend.  python3 render.py <scene|lineup|car> [samples]"""
import bpy, math, os, sys
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
which = sys.argv[1] if len(sys.argv) > 1 else "scene"
samples = int(sys.argv[2]) if len(sys.argv) > 2 else 64
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, "pack.blend"))
sc = bpy.context.scene
O = bpy.data.objects
roots = {o.name: o for o in O if o.type == "EMPTY"}

# glow material for bulbs/headlights in preview only
glow = bpy.data.materials.new("Glow")
b = glow.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (1, 0.8, 0.4, 1)
b.inputs["Emission Color"].default_value = (1, 0.75, 0.35, 1)
b.inputs["Emission Strength"].default_value = 6
for o in O:
    if o.name.endswith("_Bulb"):
        o.data.materials[0] = glow


def place(name, x, y, rz=0.0, s=1.0):
    r = roots[name]
    r.location = (x, y, 0)
    r.rotation_euler = (0, 0, math.radians(rz))
    r.scale = (s, s, s)


def hide_all_but(names):
    keep = set(names)
    for n, r in roots.items():
        vis = n in keep
        for o in [r] + list(r.children_recursive):
            o.hide_render = not vis


# ---------- ground (Roblox-baseplate-like tiles)
bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -0.002))
g = bpy.context.active_object
gm = bpy.data.materials.new("Ground")
nt = gm.node_tree
bs = nt.nodes["Principled BSDF"]
bs.inputs["Roughness"].default_value = 0.9
br = nt.nodes.new("ShaderNodeTexBrick")
br.offset = 0.0
br.inputs["Color1"].default_value = (0.20, 0.22, 0.27, 1)
br.inputs["Color2"].default_value = (0.21, 0.23, 0.28, 1)
br.inputs["Mortar"].default_value = (0.13, 0.14, 0.17, 1)
br.inputs["Scale"].default_value = 0.35
br.inputs["Mortar Size"].default_value = 0.012
br.inputs["Brick Width"].default_value = 1.0
br.inputs["Row Height"].default_value = 1.0
tc = nt.nodes.new("ShaderNodeTexCoord")
nt.links.new(tc.outputs["Object"], br.inputs["Vector"])
nt.links.new(br.outputs["Color"], bs.inputs["Base Color"])
g.data.materials.append(gm)

# ---------- sky gradient world
w = bpy.data.worlds.new("Sky")
sc.world = w
wn = w.node_tree
bg = wn.nodes["Background"]
tcw = wn.nodes.new("ShaderNodeTexCoord")
sep = wn.nodes.new("ShaderNodeSeparateXYZ")
ramp = wn.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.0
ramp.color_ramp.elements[0].color = (0.50, 0.70, 0.95, 1)
ramp.color_ramp.elements[1].position = 0.30
ramp.color_ramp.elements[1].color = (0.10, 0.35, 0.80, 1)
wn.links.new(tcw.outputs["Generated"], sep.inputs["Vector"])
wn.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
wn.links.new(ramp.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 1.0

sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.2
sun.data.angle = math.radians(3)
sun.data.color = (1.0, 0.96, 0.88)
sun.rotation_euler = (math.radians(50), math.radians(8), math.radians(-35))
sc.collection.objects.link(sun)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam


def look(frm, at, lens=35):
    cam.location = frm
    d = Vector(at) - Vector(frm)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens


# ---------- layouts
if which == "lineup":
    order = ["Car_Red", "Car_Blue", "Car_Yellow", "Tree_Round", "Tree_Pine", "Bush", "Rock_Large",
             "Rock_Small", "Grass_Tuft", "Street_Lamp", "Traffic_Cone", "Road_Barrier", "Picket_Fence",
             "Stop_Sign", "Fire_Hydrant", "Park_Bench"]
    hide_all_but(order)
    row1 = [("Car_Red", -6, 0, 215), ("Car_Blue", 0, 0, 215), ("Car_Yellow", 6, 0, 215)]
    row2 = [("Tree_Round", -9, 7, 0), ("Tree_Pine", -4.5, 7, 0), ("Street_Lamp", 0, 7, -90), ("Bush", 3.5, 6, 0),
            ("Rock_Large", 7.5, 7, 20)]
    row3 = [("Rock_Small", -9.5, -5, 0), ("Grass_Tuft", -7.3, -5, 0), ("Traffic_Cone", -5.6, -5, 0),
            ("Road_Barrier", -3, -5, 0), ("Picket_Fence", 0.6, -5, 0), ("Stop_Sign", 3.4, -5, 0),
            ("Fire_Hydrant", 5.0, -5, 0), ("Park_Bench", 7.6, -5, 180)]
    for n, x, y, rz in row1 + row2 + row3:
        place(n, x, y, rz)
    look((0, -22, 9.5), (0, 1.5, 1.2), 30)
    res = (1920, 1080)
elif which == "car":
    hide_all_but(["Car_Red", "Road_Straight"])
    place("Road_Straight", 0, 0, 0)
    place("Car_Red", 2.0, 0.5, 0)
    look((-5.5, 7.5, 2.6), (1.6, 0.2, 0.75), 40)
    res = (1600, 1000)
else:  # scene
    names = list(roots)
    hide_all_but(names)
    for n in roots:
        place(n, 999, 999)
    T = 11.2
    place("Road_Straight", 0, 0)
    place("Road_Intersection", 0, T)
    place("Road_Corner", 0, -T, 180)
    place("Car_Red", 2.0, 2.5, 0)
    place("Car_Blue", -2.1, 9.5, 180)
    place("Car_Yellow", 6.5, 11.6, 90)
    place("Street_Lamp", 4.95, -1.0, 90)
    place("Fire_Hydrant", 4.8, 3.5)
    place("Stop_Sign", 4.9, 5.0, 0)
    place("Park_Bench", -5.0, 1.5, 90)
    place("Traffic_Cone", -1.2, -1.0)
    place("Road_Barrier", -2.4, -0.2, 8)
    place("Tree_Round", -10.5, 9.0, 0)
    place("Tree_Pine", -7.6, 4.0, 0)
    place("Bush", -6.8, 0.5)
    place("Rock_Large", 9.0, 0.5, 30)
    place("Rock_Small", 7.2, -2.8)
    place("Grass_Tuft", -6.3, -2.2)
    place("Picket_Fence", 8.0, 4.5, 0)
    look((-2.6, -12.5, 3.8), (0.4, 5.0, 1.6), 26)
    res = (1920, 1080)

sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = samples
sc.cycles.use_denoising = True
try:
    sc.cycles.denoiser = "OPENIMAGEDENOISE"
except Exception:
    pass
sc.render.resolution_x, sc.render.resolution_y = res
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Punchy"
sc.render.filepath = os.path.join(OUT, f"preview_{which}.png")
bpy.ops.render.render(write_still=True)
print("WROTE", sc.render.filepath)
