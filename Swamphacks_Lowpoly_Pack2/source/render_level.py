"""Render Level 1 previews from out/level1.blend.  python3 render_level.py <hero|plan|models|start> [samples]"""
import bpy, math, os, sys
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
which = sys.argv[1] if len(sys.argv) > 1 else "hero"
samples = int(sys.argv[2]) if len(sys.argv) > 2 else 48
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, "level1.blend"))
sc = bpy.context.scene
O = bpy.data.objects
level = O["Level1"]
lib_roots = [o for o in O if o.type == "EMPTY" and o.parent is None and o is not level]


def mat(name, color, rough=0.5, emit=None, alpha=None):
    m = bpy.data.materials.new(name)
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 5
    if alpha is not None:
        b.inputs["Alpha"].default_value = alpha
    return m


water = mat("WaterPreview", (0.05, 0.28, 0.55), rough=0.08, alpha=0.82)
glow = mat("Glow", (1, 0.8, 0.4), emit=(1, 0.75, 0.35))
for o in O:
    if o.type != "MESH":
        continue
    if "_Water" in o.name:
        o.data = o.data.copy()
        o.data.materials[0] = water
    if o.name.startswith("Street_Lamp_Bulb"):
        o.data = o.data.copy()
        o.data.materials[0] = glow

for r in lib_roots:   # library originals hidden unless used in the models shot
    for o in [r] + list(r.children_recursive):
        o.hide_render = True

# sky: golden-hour gradient (warm horizon, blue zenith)
w = bpy.data.worlds.new("Sky")
sc.world = w
wn = w.node_tree
bg = wn.nodes["Background"]
tc = wn.nodes.new("ShaderNodeTexCoord")
sep = wn.nodes.new("ShaderNodeSeparateXYZ")
ramp = wn.nodes.new("ShaderNodeValToRGB")
cr = ramp.color_ramp
cr.elements[0].position, cr.elements[0].color = 0.0, (0.95, 0.66, 0.62, 1)
cr.elements[1].position, cr.elements[1].color = 0.45, (0.20, 0.42, 0.85, 1)
e = cr.elements.new(0.12)
e.color = (0.62, 0.62, 0.86, 1)
wn.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
wn.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
wn.links.new(ramp.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 0.9

sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.4
sun.data.angle = math.radians(2)
sun.data.color = (1.0, 0.86, 0.70)
sun.rotation_euler = (math.radians(62), 0, math.radians(-128))
sc.collection.objects.link(sun)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.clip_end = 3000
sc.collection.objects.link(cam)
sc.camera = cam


def look(frm, at, lens=35):
    cam.location = frm
    cam.rotation_euler = (Vector(at) - Vector(frm)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens


res = (1920, 1080)
if which == "hero":
    look((58, 108, 44), (-4, -6, 22), 30)
elif which == "start":
    look((-3.5, -88, 18.5), (1.5, -40, 18), 30)
elif which == "plan":
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 300
    cam.location = (0, 0, 400)
    cam.rotation_euler = (0, 0, 0)
    sun.rotation_euler = (math.radians(35), 0, math.radians(-40))
    sun.data.color = (1, 0.97, 0.92)
    res = (1600, 1680)
elif which == "models":
    for o in level.children_recursive:
        o.hide_render = True
    level.hide_render = True
    sun.rotation_euler = (math.radians(50), math.radians(8), math.radians(-35))
    sun.data.color = (1, 0.96, 0.88)
    bpy.ops.mesh.primitive_plane_add(size=300, location=(1000, 0, -0.001))
    gnd = bpy.context.active_object
    gnd.data.materials.append(mat("Ground", (0.17, 0.19, 0.24), rough=0.9))
    show = {"Plane_Prop": (1000 - 5.5, 1.5, 0, -35), "Boat_Speedboat": (1000 + 5.0, -1.5, 0.4, 215),
            "Wooden_Dock": (1000 + 2.0, 7.0, 1.2, 90)}
    for n, (x, y, z, rz) in show.items():
        r = O[n]
        r.location = (x, y, z)
        r.rotation_euler = (0, 0, math.radians(rz))
        for o in [r] + list(r.children_recursive):
            o.hide_render = False
    look((1000 + 1, -19, 7.5), (1000 + 0.2, 1.0, 1.3), 34)

sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = samples
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = res
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Punchy"
sc.render.filepath = os.path.join(OUT, "level1", f"preview_{which}.png")
bpy.ops.render.render(write_still=True)
print("WROTE", sc.render.filepath)
