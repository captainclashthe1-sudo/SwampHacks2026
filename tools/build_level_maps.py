"""Adapt the Pack 5 bay-crossing map (Swamphacks_Lowpoly_Pack5/source/level1.py) to the five campaign levels.

Run from the project root:  python tools/build_level_maps.py

The original map is a 400-stud bay with the deck 50 studs above the water. The campaign levels
need 64-96-stud gaps 16 studs above the water, so the bay is cut out of the map: the south (city)
bank is placed against the left anchor and the north (hill) bank against the right anchor. Land,
roads, building lots, street dressing, docks, the lighthouse, the palm island and the nature
scatter follow level1.py's rules, scaled to the game's 0.8 road scale and themed per level.

Writes:
  src/shared/LevelMapData.luau                  per level: gap, road tiles, building pads and every prop
  src/shared/LowpolyMeshData/Tree_Palm.luau     palm tree from Pack 5 (palette colours sampled)
  src/shared/LowpolyMeshData/Palette.luau       palette, extended only if the palm needs colours
  tools/level_map_previews/Level<n>.png         top-down check images

The terrain itself is not written out: src/shared/LevelMaps.luau rebuilds it in game from
LevelMapData with the same height rules as LevelMap.height() below (server: collision blocks,
client: the low-poly mesh). If you change the terrain rules here, change them there too.

Game axes: X runs along the road (start on -X), Z across it (the build camera sits on +Z and looks
toward -Z), Y up. Every level shares X; level n sits at Z = (n-1)*650, so terrain away from the
crossing is computed from world coordinates only and neighbouring maps join into one river valley.
"""

import io
import json
import math
import pathlib
import random
import re
import struct
import sys

from PIL import Image, ImageDraw

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[1]
MESH_DIR = ROOT / "src" / "shared" / "LowpolyMeshData"
PACK5 = ROOT / "Swamphacks_Lowpoly_Pack5"

S = 25 / 7            # studs per Blender metre (pack convention)
K = S * 0.8           # the game uses the pack's road kit at 0.8 scale (32-stud tiles, 24-stud road)
MAP_SHORE = 56.0      # level1.py SHORE_BRIDGE: the bay shore at the bridge, in metres

WATER = -12.0         # LevelConfig River.SurfaceY
LAND = 3.65           # grass level beside the road (unchanged from the old generated mainland)
ROADBED = 3.3         # terrain under road tiles
ROAD_Y = 3.328        # road tile origin (unchanged from CampaignScenery)
WALK_Y = ROAD_Y + 0.8  # sidewalk top at 0.8 scale
ASPHALT_Y = ROAD_Y + 0.4
TILE = 32.0           # Road_Straight at 0.8 scale
UMIN, UMAX = -520.0, 520.0
VHALF = 325.0
SPACING = 650.0
SKIRT_Y = -36.0
SEABED_DEPTH = 9.0
PLAY_U, PLAY_V = 196.0, 112.0   # LevelGenerator boundaries are +/-190 x +/-104

# ----------------------------------------------------------------- helpers

def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def hash01(a, b, c):
    """Same hash as Shared.LevelMaps (Luau), so both sides agree on the hills."""
    x = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
    return x - math.floor(x)


def num(value):
    r = round(float(value), 3)
    return str(int(r)) if r.is_integer() else f"{r:.3f}".rstrip("0").rstrip(".")


def read_palette():
    return re.findall(r'"(#[A-Fa-f0-9]{6})"', (MESH_DIR / "Palette.luau").read_text())


def mesh_bounds():
    out = {}
    for path in MESH_DIR.glob("*.luau"):
        if path.stem in ("Palette",) or path.stem.startswith("MapTerrain"):
            continue
        text = path.read_text()
        lo = [1e9] * 3
        hi = [-1e9] * 3
        for m in re.finditer(r"Offset\s*=\s*\{([^}]*)\}\s*,\s*(?:Flat\s*=\s*\w+\s*,\s*)?Vertices\s*=\s*\{([^}]*)\}", text):
            off = [float(x) for x in m.group(1).split(",")]
            vals = [float(x) for x in m.group(2).split(",") if x.strip()]
            for i in range(0, len(vals), 3):
                for k in range(3):
                    p = vals[i + k] + off[k]
                    lo[k] = min(lo[k], p)
                    hi[k] = max(hi[k], p)
        if lo[0] < 1e8:
            out[path.stem] = (lo, hi)
    return out


# ----------------------------------------------------------------- Tree_Palm export (Pack 5)

def export_palm(palette):
    """Same method as tools/export_additions.py: original triangles, colours sampled from the texture."""
    path = PACK5 / "models" / "Tree_Palm.glb"
    raw = path.read_bytes()
    n = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + n])
    binary = raw[28 + n:]

    def accessor(index):
        spec = doc["accessors"][index]
        view = doc["bufferViews"][spec["bufferView"]]
        kind = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[spec["componentType"]]
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[spec["type"]]
        dec = struct.Struct("<" + kind * width)
        off = view.get("byteOffset", 0) + spec.get("byteOffset", 0)
        stride = view.get("byteStride", dec.size)
        return [dec.unpack_from(binary, off + i * stride) for i in range(spec["count"])]

    image = doc["images"][0]
    view = doc["bufferViews"][image["bufferView"]]
    off = view.get("byteOffset", 0)
    texture = Image.open(io.BytesIO(binary[off:off + view["byteLength"]])).convert("RGB")
    lines = ["-- Generated from Swamphacks_Lowpoly_Pack5/models/Tree_Palm.glb by tools/build_level_maps.py.",
             "-- Original triangles; colours sampled from the embedded palette texture.", "return {"]
    for node in doc["nodes"]:
        if "mesh" not in node:
            continue
        prim = doc["meshes"][node["mesh"]]["primitives"][0]
        pos = accessor(prim["attributes"]["POSITION"])
        uv = accessor(prim["attributes"]["TEXCOORD_0"])
        idx = [e[0] for e in accessor(prim["indices"])]
        # Shared positions + Flat = true keeps the module small; the renderer still gives
        # every triangle its own vertices, so the shading stays faceted.
        verts, remap, faces = [], {}, []

        def vid(i):
            x, y, z = pos[i]
            key = (round(x * S, 2), round(y * S, 2), round(-z * S, 2))
            if key not in remap:
                remap[key] = len(remap) + 1
                verts.extend(key)
            return remap[key]
        for i in range(0, len(idx), 3):
            a, b, c = idx[i:i + 3]
            u, v = uv[a]
            rgb = texture.getpixel((min(texture.width - 1, max(0, int(u * texture.width))),
                                    min(texture.height - 1, max(0, int(v * texture.height)))))
            hx = "#%02X%02X%02X" % rgb
            if hx not in palette:
                palette.append(hx)
            faces += [vid(a), vid(c), vid(b), palette.index(hx) + 1]
        t = node.get("translation", [0, 0, 0])
        lines.append("{Name=" + json.dumps(node["name"]) + ",Offset={" + ",".join(num(v) for v in (t[0] * S, t[1] * S, -t[2] * S)) +
                     "},Flat=true,Vertices={" + ",".join(num(v) for v in verts) + "},Faces={" + ",".join(map(str, faces)) + "}},")
    lines.append("}")
    (MESH_DIR / "Tree_Palm.luau").write_text("\n".join(lines) + "\n")


# ----------------------------------------------------------------- map content (level1.py, metres)

# Building lots from level1.py plan_buildings(): model, x, y, rz (front faces the street).
MAP_LOTS = [
    ("Office_Tower", 14.0, -70.0, -90), ("Shop_Corner", 12.8, -83.4, -90), ("Gas_Station", 30.0, -81.0, 0),
    ("Apartment_Block", 48.5, -70.0, 0),
    ("House_Cottage", -11.0, -68.5, 90), ("House_TwoStory", -12.0, -80.6, 90),
    ("Apartment_Block", -28.0, -81.5, 0), ("Shop_Corner", -45.0, -84.0, 0), ("House_Cottage", -46.0, -70.5, 0),
    ("Apartment_Block", 13.5, -112.5, -90), ("Office_Tower", 14.5, -130.0, -90),
    ("Shop_Corner", 30.0, -107.0, 180), ("House_TwoStory", 48.0, -108.5, 180),
    ("House_Cottage", -55.0, -111.0, 180), ("House_TwoStory", -12.0, -112.5, 90),
    ("House_Cottage", -12.5, -128.0, 90), ("Shop_Corner", -33.0, -107.0, 180),
]

THEMES = {
    # Lots: which map lots to use and model swaps. Lots on the camera side (map x < 0) stay low-rise.
    "village": dict(
        lots="all", swap={"Office_Tower": "House_TwoStory", "Apartment_Block": "House_Cottage"},
        cross=True, lighthouse=False, dress="light", cars=["Car_Blue", "Car_Yellow"],
        docks=[(-1, 170)], island=None, fences=True,
        nature={"Tree_Round": 40, "Tree_Pine": 45, "Bush": 40, "Rock_Large": 10, "Rock_Small": 14, "Grass_Tuft": 16},
        sparse_city=True, beaches=0.6),
    "forest": dict(
        lots=[("House_Cottage", -11.0, -68.5, 90), ("House_Cottage", -46.0, -70.5, 0), ("House_TwoStory", 14.0, -72.0, -90)],
        swap={}, cross=False, lighthouse=False, dress="none", cars=["Truck_Blue"],
        docks=[(1, -150)], island=None, fences=False,
        nature={"Tree_Pine": 150, "Tree_Round": 14, "Bush": 34, "Rock_Large": 24, "Rock_Small": 24},
        sparse_city=False, beaches=0.3),
    "city": dict(
        lots="all", swap={}, cross=True, lighthouse=True, dress="full", cars=["Car_Blue", "Car_Yellow", "Truck_Blue"],
        docks=[(-1, -190)], island=None, fences=True,
        nature={"Tree_Pine": 55, "Tree_Round": 18, "Bush": 30, "Rock_Large": 12, "Rock_Small": 18, "Grass_Tuft": 16},
        sparse_city=True, beaches=0.6),
    "coast": dict(
        lots=[("Gas_Station", 30.0, -81.0, 0), ("Shop_Corner", 12.8, -83.4, -90), ("House_Cottage", -11.0, -68.5, 90),
              ("House_TwoStory", -12.0, -80.6, 90), ("Shop_Corner", -45.0, -84.0, 0), ("House_Cottage", -46.0, -70.5, 0),
              ("House_Cottage", -55.0, -111.0, 180), ("House_TwoStory", 48.0, -108.5, 180), ("Shop_Corner", 30.0, -107.0, 180),
              ("House_TwoStory", -12.0, -112.5, 90)],
        swap={}, cross=True, lighthouse=True, dress="light", cars=["Car_Blue"],
        docks=[(1, -175), (-1, 195)], island=None, fences=False,
        nature={"Tree_Palm": 34, "Tree_Pine": 22, "Tree_Round": 8, "Bush": 26, "Rock_Large": 16, "Rock_Small": 16},
        sparse_city=True, beaches=1.0),
    "harbor": dict(
        lots="all", swap={}, cross=True, lighthouse=True, dress="full", cars=["Car_Blue", "Car_Yellow", "Truck_Blue"],
        docks=[(-1, -165), (-1, 165), (1, 175)], island=(0.0, -248.0, 0.42), fences=True,
        nature={"Tree_Pine": 40, "Tree_Round": 14, "Tree_Palm": 14, "Bush": 24, "Rock_Large": 14, "Rock_Small": 18},
        sparse_city=True, beaches=0.8),
}

# Model footprints used for flat building pads (studs at scale 1; rotated per placement).
FOOT_MARGIN = 3.0


class LevelMap:
    def __init__(self, level_id, title, theme, gap, bounds):
        self.id = level_id
        self.title = title
        self.theme = theme
        self.t = THEMES[theme]
        self.half = gap / 2
        self.oz = (level_id - 1) * SPACING
        self.bounds = bounds
        self.props = []      # (model, u, y, v, yaw_deg, scale)
        self.tiles = []      # road tiles (u, v) for flattening
        self.pads = []       # (cu, cv, hu, hv, target)
        self.rng = random.Random(1000 + level_id)

    # --- map metres -> game studs (relative to the level origin)
    def mu(self, y):
        return -self.half + (y + MAP_SHORE) * K if y < 0 else self.half + (y - MAP_SHORE) * K

    @staticmethod
    def mv(x):
        return -x * K

    @staticmethod
    def myaw(rz):
        return 90.0 - rz

    # --- terrain fields
    def near(self, v):
        return 1 - sstep(28, 110, abs(v))

    def shore(self, v, side):
        w = self.oz + v
        nw = 66 + 10 * math.sin(w * 0.0157 + 1 + side * 2.1) + 7 * math.sin(w * 0.041 + side * 0.7)
        n = self.near(v)
        return self.half * n + nw * (1 - n)

    def rise(self, v, side):
        w = self.oz + v
        rw = 5 + 24 * (0.5 + 0.5 * math.sin(w * 0.0113 + side * 1.3))
        n = self.near(v)
        return 0.6 * n + rw * (1 - n)

    def base(self, u, v):
        w = self.oz + v
        f = sstep(130, 260, abs(v))
        world = LAND - 7.5 * (0.5 + 0.5 * math.sin(w * 0.0083 + 0.4 + u * 0.004))
        return LAND * (1 - f) + world * f

    def hills(self, u, v):
        w = self.oz + v
        cell = 150.0
        total = 0.0
        ci, cj = math.floor(u / cell), math.floor(w / cell)
        for i in range(ci - 2, ci + 3):
            for j in range(cj - 2, cj + 3):
                cx = (i + 0.2 + 0.6 * hash01(i, j, 1)) * cell
                cz = (j + 0.2 + 0.6 * hash01(i, j, 2)) * cell
                amp = 14 + 58 * hash01(i, j, 3) ** 1.4
                sig = 42 + 46 * hash01(i, j, 4)
                d2 = (u - cx) ** 2 + (w - cz) ** 2
                if d2 < (3.2 * sig) ** 2:
                    total += amp * math.exp(-d2 / (2 * sig * sig))
        if u < 0:   # the city bank stays fairly flat, like the map's south shore
            total *= lerp(0.22, 1.0, sstep(260, 470, -u))
        else:       # the hill bank, like the map's north shore
            total *= lerp(0.55, 1.0, sstep(60, 220, u))
        # Keep the camera side (+Z) of the crossing low so hills never block the build view.
        total *= 1 - 0.78 * sstep(-40, 20, v) * (1 - sstep(70, 230, v))
        return total

    def road_dist(self, u, v):
        d = 1e9
        for tu, tv in self.tiles:
            d = min(d, max(abs(u - tu), abs(v - tv)) - TILE / 2)
        return d

    def pad_info(self, u, v):
        best, target = 1e9, LAND
        for cu, cv, hu, hv, tz in self.pads:
            d = max(abs(u - cu) - hu, abs(v - cv) - hv)
            if d < best:
                best, target = d, tz
        return best, target

    def land_dist(self, u, v):
        side = 1 if u >= 0 else -1
        return abs(u) - self.shore(v, side), side

    def height(self, u, v):
        d, side = self.land_dist(u, v)
        r = self.rise(v, side)
        if d < -r:
            return WATER - min(SEABED_DEPTH, (-r - d) * 1.3) - 0.05
        top = self.base(u, v) + self.hills(u, v) * sstep(10, 90, d)
        h = WATER + (top - WATER) * sstep(-r, 0, d)
        if d >= 0:
            w = 1 - sstep(1.5, 26, self.road_dist(u, v))
            h += (ROADBED - h) * w
            pd, tz = self.pad_info(u, v)
            w = 1 - sstep(1.0, 18, pd)
            h += (tz - h) * w
        return h

    def flat_weight(self, u, v):
        pd, _ = self.pad_info(u, v)
        return max(1 - sstep(1.5, 26, self.road_dist(u, v)), 1 - sstep(1.0, 18, pd))

    # --- content
    def place(self, model, u, y, v, yaw=0.0, scale=0.8):
        self.props.append((model, u, y, v, yaw % 360, scale))

    def tile(self, model, u, v, yaw):
        self.tiles.append((u, v))
        self.place(model, u, ROAD_Y, v, yaw)

    def footprint(self, model, yaw, scale=0.8):
        lo, hi = self.bounds[model]
        hx = max(abs(lo[0]), abs(hi[0])) * scale
        hz = max(abs(lo[2]), abs(hi[2])) * scale
        if round(yaw / 90) % 2 == 1:
            hx, hz = hz, hx
        return hx, hz

    def plan_roads(self):
        cross = self.t["cross"]
        half = self.half
        # South (start) bank: main street from the left anchor to the map edge, intersection 4th tile.
        n = 0
        while True:
            u = -(half + TILE / 2 + TILE * n)
            if u < UMIN + TILE / 2:
                break
            if cross and n == 3:
                self.tile("Road_Intersection", u, 0.0, 90)
            else:
                self.tile("Road_Straight", u, 0.0, 90)
            n += 1
        self.left_end = u + TILE
        if cross:
            self.cross_u = -(half + TILE / 2 + TILE * 3)
            for k in range(1, 6):
                for sgn in (-1, 1):
                    self.tile("Road_Straight", self.cross_u, sgn * k * TILE, 0)
        # North (finish) bank: straight past the play boundary, then the map's corner turning away
        # from the camera (-Z) and a closed road along the ridge.
        n_corner = math.ceil((206 - half - TILE / 2) / TILE)
        for k in range(n_corner):
            self.tile("Road_Straight", half + TILE / 2 + TILE * k, 0.0, 90)
        self.corner_u = half + TILE / 2 + TILE * n_corner
        self.tiles.append((self.corner_u, 0.0))
        self.place("Road_Corner", self.corner_u, ROAD_Y, 0.0, 90)
        for k in range(1, 7):
            self.tile("Road_Straight", self.corner_u, -k * TILE, 0)
        self.ridge_end = -6 * TILE

    def plan_lots(self):
        lots = MAP_LOTS if self.t["lots"] == "all" else self.t["lots"]
        for model, x, y, rz in lots:
            model = self.t["swap"].get(model, model)
            if x < 0 and model in ("Apartment_Block", "Office_Tower"):
                model = "House_TwoStory"   # camera side stays low-rise
            u, v, yaw = self.mu(y), self.mv(x), self.myaw(rz)
            hx, hz = self.footprint(model, yaw)
            self.pads.append((u, v, hx + FOOT_MARGIN, hz + FOOT_MARGIN, LAND))
            self.lots_placed = getattr(self, "lots_placed", []) + [(model, u, v, yaw)]
        if self.t["lighthouse"]:
            v = -114.0   # the map's north headland, moved to the far side of the river so it stays in view
            u = self.shore(v, 1) + 34
            self.light = (u, v)
            self.pads.append((u, v, 13, 13, None))

    def finish_pads(self):
        # Lighthouse pad height follows the natural land (level1.py does the same).
        fixed = []
        for cu, cv, hu, hv, tz in self.pads:
            if tz is None:
                saved, self.pads = self.pads, [p for p in self.pads if p[4] is not None]
                tz = round(self.height(cu, cv), 2)
                self.pads = saved
            fixed.append((cu, cv, hu, hv, tz))
        self.pads = fixed

    def dress(self):
        t = self.t
        for model, u, v, yaw in getattr(self, "lots_placed", []):
            self.place(model, u, LAND, v, yaw)
        if t["lighthouse"]:
            u, v = self.light
            _, tz = self.pad_info(u, v)
            self.place("Lighthouse", u, tz, v, 90)
        mode = t["dress"]
        if mode in ("full", "light"):
            ys = (-61.6, -84.0, -106.4, -128.8) if mode == "full" else (-72.8, -117.6)
            for y in ys:
                self.place("Street_Lamp", self.mu(y), WALK_Y, self.mv(4.95), self.myaw(90))
                self.place("Street_Lamp", self.mu(y - 11.2), WALK_Y, self.mv(-4.95), self.myaw(-90))
            if t["cross"]:
                for x in ((22.4, 44.8) if mode == "full" else (33.6,)):
                    self.place("Street_Lamp", self.mu(-90.25), WALK_Y, self.mv(x), self.myaw(180))
                    self.place("Street_Lamp", self.mu(-100.15), WALK_Y, self.mv(-x), self.myaw(0))
                self.place("Stop_Sign", self.mu(-87.5), WALK_Y, self.mv(-4.9), self.myaw(180))
                self.place("Stop_Sign", self.mu(-102.9), WALK_Y, self.mv(4.9), self.myaw(0))
            self.place("Fire_Hydrant", self.mu(-78.0), WALK_Y, self.mv(4.8))
            self.place("Park_Bench", self.mu(-66.0), WALK_Y, self.mv(-4.9), self.myaw(90))
            if t["cross"]:
                self.place("Fire_Hydrant", self.mu(-100.4), WALK_Y, self.mv(-15.0))
                self.place("Park_Bench", self.mu(-100.4), WALK_Y, self.mv(30.0), self.myaw(180))
            # A lamp at each end of the finish bank's road, matching the start side.
            self.place("Street_Lamp", self.half + 40, WALK_Y, self.mv(4.95), self.myaw(90))
        if t["cross"]:
            for sgn in (-1, 1):   # road-closed ends of the cross street
                v = sgn * (5 * TILE + TILE / 2 + 4)
                self.place("Road_Barrier", self.cross_u, ASPHALT_Y, v, 0)
                for du in (-9, 9):
                    self.place("Traffic_Cone", self.cross_u + du, ASPHALT_Y, v - sgn * 4, 0)
        # Closed ends of the main street and of the ridge road.
        self.place("Road_Barrier", self.left_end - TILE / 2 + 4, ASPHALT_Y, 0, 90)
        self.place("Road_Barrier", self.corner_u, ASPHALT_Y, self.ridge_end - TILE / 2 + 4, 0)
        for dz in (-9, 9):
            self.place("Traffic_Cone", self.left_end - TILE / 2 + 9, ASPHALT_Y, dz, 0)
            self.place("Traffic_Cone", self.corner_u + dz, ASPHALT_Y, self.ridge_end - TILE / 2 + 9, 0)
        if t["fences"]:
            for x in (-50, -60):
                self.place("Picket_Fence", self.mu(-105.5), LAND, self.mv(x), self.myaw(0))
            if self.theme == "village":
                for model, u, v, yaw in getattr(self, "lots_placed", []):
                    if model == "House_Cottage":
                        hx, hz = self.footprint(model, yaw)
                        edge = v - math.copysign(hz + 2, v)
                        for du in (-hx + 4, hx - 4):
                            self.place("Picket_Fence", u + du, LAND, edge, 0)
        # Parked vehicles from the map.
        cars = {
            "Car_Blue": (self.mu(-118.0), ASPHALT_Y, self.mv(-2.1), self.myaw(180)),
            "Car_Yellow": (self.mu(-97.3) if self.t["cross"] else self.mu(-120), ASPHALT_Y,
                           self.mv(-30.0) if self.t["cross"] else self.mv(2.1), self.myaw(-90 if self.t["cross"] else 0)),
            "Truck_Blue": (self.mu(-84.5), LAND, self.mv(30.0), self.myaw(0)),
        }
        if self.theme == "forest":
            cars["Truck_Blue"] = (self.mu(-58.5), LAND, self.mv(-11.0) + 2, self.myaw(90))
        for name in t["cars"]:
            u, y, v, yaw = cars[name]
            self.place(name, u, y, v, yaw, 0.75)

    def bank_u(self, v, side):
        """Distance from the river centre to the point on the bank just above the waterline."""
        s = self.shore(v, side)
        u = s - self.rise(v, side) - 4
        while u < s + 40:
            if self.height(side * u, v) >= WATER + 1.0:
                return u
            u += 0.5
        return s

    def water(self):
        for side, v in self.t["docks"]:
            u = self.bank_u(v, side)
            yaw = -90 if side > 0 else 90          # the dock runs from the bank into the river
            self.place("Wooden_Dock", side * (u + 1.5), WATER, v, yaw)
            # A moored speedboat alongside, as at the map's south-west dock.
            self.place("Boat_Speedboat", side * (u - 16), WATER, v + 8.5, yaw + 90)
        if self.t["island"]:
            u, v, scale = self.t["island"]
            self.place("Island_Palm", u, WATER, v, 90, scale)

    def land_ok(self, u, v, big):
        if not (UMIN + 10 < u < UMAX - 10 and -VHALF + 10 < v < VHALF - 10):
            return False
        d, side = self.land_dist(u, v)
        if d < 7:
            return False
        h = self.height(u, v)
        if h < WATER + 3:
            return False
        if self.road_dist(u, v) < (10 if big else 5):
            return False
        pd, _ = self.pad_info(u, v)
        if pd < (6 if big else 3):
            return False
        if abs(u) < self.half + 46 and abs(v) < 40:   # keep the anchors and platforms clear
            return False
        if self.island_clear(u, v):
            return False
        e = 1.5
        gx = (self.height(u + e, v) - self.height(u - e, v)) / (2 * e)
        gz = (self.height(u, v + e) - self.height(u, v - e)) / (2 * e)
        return math.hypot(gx, gz) < 0.6

    def island_clear(self, u, v):
        return False

    def nature(self):
        want = dict(self.t["nature"])
        counts = {k: 0 for k in want}
        spots = []
        rng = self.rng
        tries = 0
        while any(counts[k] < want[k] for k in want) and tries < 60000:
            tries += 1
            u, v = rng.uniform(UMIN, UMAX), rng.uniform(-VHALF, VHALF)
            pool = [k for k in want if counts[k] < want[k]]
            if self.t["sparse_city"] and u < 0 and -(self.half + 280) < u and abs(v) < 210:
                if rng.random() < 0.85:   # level1.py keeps the city bank open
                    continue
            m = rng.choice(pool)
            big = m in ("Tree_Pine", "Tree_Round", "Tree_Palm", "Rock_Large")
            if m == "Tree_Palm":   # palms stay near the water, like the island's
                d, _ = self.land_dist(u, v)
                if d > 70:
                    continue
            if not self.land_ok(u, v, big):
                continue
            if any((u - a) ** 2 + (v - b) ** 2 < (12 if big else 6) ** 2 for a, b in spots):
                continue
            spots.append((u, v))
            counts[m] += 1
            scale = rng.uniform(0.85, 1.25) if big else rng.uniform(0.8, 1.15)
            self.place(m, u, self.height(u, v) - 0.3, v, rng.uniform(0, 360), round(scale, 2))

    def build(self):
        self.plan_roads()
        self.plan_lots()
        self.finish_pads()
        self.dress()
        self.water()
        self.nature()

    # ------------------------------------------------------------- terrain mesh
    def grid(self):
        half = self.half
        breaks = [s * b for s in (-1, 1) for b in (half, half - 0.6, half - 2.0)]
        us = [UMIN + i * (UMAX - UMIN) / 64 for i in range(65)]
        us = [u for u in us if all(abs(u - b) > 3.0 for b in breaks)] + breaks
        us.sort()
        vs = [-VHALF + j * (2 * VHALF) / 40 for j in range(41)]
        return us, vs, set(breaks)

    def terrain(self, colors):
        us, vs, breaks = self.grid()
        nu, nv = len(us), len(vs)
        verts = []
        index = {}
        for i, u in enumerate(us):
            for j, v in enumerate(vs):
                x, z = u, v
                h = self.height(u, v)
                edge = i in (0, nu - 1) or j in (0, nv - 1)
                calm = (abs(v) < 44 and abs(abs(u) - self.half) < 22) or u in breaks
                if not edge and not calm and self.flat_weight(u, v) < 0.05:
                    w = self.oz + v
                    jx = hash01(round(u * 4), round(w * 4), 11) * 2 - 1
                    jz = hash01(round(u * 4), round(w * 4), 12) * 2 - 1
                    jy = hash01(round(u * 4), round(w * 4), 13) * 2 - 1
                    x += jx * 3.4
                    z += jz * 3.4
                    h = self.height(x, z) + jy * (1.2 if h > WATER else 0.6)
                index[i, j] = len(verts)
                verts.append((x, h, z))
        faces = []

        def face_color(a, b, c):
            pa, pb, pc = verts[a], verts[b], verts[c]
            cx, cy, cz = [(pa[k] + pb[k] + pc[k]) / 3 for k in range(3)]
            e1 = [pb[k] - pa[k] for k in range(3)]
            e2 = [pc[k] - pa[k] for k in range(3)]
            n = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
            ln = math.sqrt(sum(q * q for q in n)) or 1
            ny = n[1] / ln
            hw = cy - WATER
            if hw < -1.5:
                return colors["seabed"], n
            if hw < 5.0 * self.t["beaches"] + 1.0 and abs(cy - ROADBED) > 0.2:
                return colors["sand"], n
            if abs(ny) < 0.72:
                return colors["cliff"], n
            w = self.oz + cz
            return (colors["turf"] if (math.floor(cx / 48) + math.floor(w / 66)) % 3 else colors["turf_dark"]), n

        def tri(a, b, c, color=None):
            col, n = face_color(a, b, c)
            if n[1] < 0:
                b, c = c, b
            faces.append((a, b, c, color or col))

        for i in range(nu - 1):
            for j in range(nv - 1):
                a, b, c, d = index[i, j], index[i + 1, j], index[i + 1, j + 1], index[i, j + 1]
                if (i + j) % 2 == 0:
                    tri(a, b, c)
                    tri(a, c, d)
                else:
                    tri(a, b, d)
                    tri(b, c, d)
        # Skirt down so the map edge reads as a solid block (level1.py does the same).
        ring = [index[i, 0] for i in range(nu)] + [index[nu - 1, j] for j in range(1, nv)] + \
               [index[i, nv - 1] for i in range(nu - 2, -1, -1)] + [index[0, j] for j in range(nv - 2, 0, -1)]
        low = []
        for r in ring:
            x, _, z = verts[r]
            low.append(len(verts))
            verts.append((x, SKIRT_Y, z))
        cx = sum(verts[r][0] for r in ring) / len(ring)
        cz = sum(verts[r][2] for r in ring) / len(ring)
        for k in range(len(ring)):
            k2 = (k + 1) % len(ring)
            for a, b, c in ((ring[k], ring[k2], low[k2]), (ring[k], low[k2], low[k])):
                pa, pb, pc = verts[a], verts[b], verts[c]
                e1 = [pb[q] - pa[q] for q in range(3)]
                e2 = [pc[q] - pa[q] for q in range(3)]
                n = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
                mx, mz = (pa[0] + pb[0]) / 2 - cx, (pa[2] + pb[2]) / 2 - cz
                if n[0] * mx + n[2] * mz < 0:
                    b, c = c, b
                faces.append((a, b, c, colors["cliff"]))
        return verts, faces

    # ------------------------------------------------------------- collision / fallback boxes
    def boxes(self):
        out = []
        half = self.half

        def edges(lo, hi, step, extra):
            vals = [lo + i * step for i in range(int(round((hi - lo) / step)) + 1)]
            vals = [x for x in vals if all(abs(x - e) > step * 0.3 for e in extra)] + [e for e in extra if lo < e < hi]
            return sorted(vals)

        def cell(u0, u1, v0, v1, collide):
            uc, vc = (u0 + u1) / 2, (v0 + v1) / 2
            pts = [(uc, vc), (lerp(u0, u1, .25), lerp(v0, v1, .25)), (lerp(u0, u1, .75), lerp(v0, v1, .25)),
                   (lerp(u0, u1, .25), lerp(v0, v1, .75)), (lerp(u0, u1, .75), lerp(v0, v1, .75))]
            hs = [self.height(u, v) for u, v in pts]
            dc, side = self.land_dist(uc, vc)
            if dc < -self.rise(vc, side):
                top = min(hs)
            else:
                land = [h for h in hs if h >= WATER - 0.5] or hs
                top = sum(land) / len(land)
            top = round(top * 4) / 4
            hw = top - WATER
            spread = max(hs) - min(hs)
            kind = "seabed" if hw < -1.5 else "sand" if hw < 5.0 * self.t["beaches"] + 1.0 else "cliff" if spread > 7 else "turf"
            return top, kind

        # Play area: 8-stud collidable cells, split exactly at the anchor edges.
        ue = edges(-PLAY_U, PLAY_U, 8, [-half, half])
        ve = edges(-PLAY_V, PLAY_V, 8, [])
        for j in range(len(ve) - 1):
            row = []
            for i in range(len(ue) - 1):
                top, kind = cell(ue[i], ue[i + 1], ve[j], ve[j + 1], True)
                row.append([ue[i], ue[i + 1], top, kind])
            merged = []
            for c in row:
                if merged and merged[-1][2] == c[2] and merged[-1][3] == c[3] and \
                        not (abs(merged[-1][1] - half) < 0.01 or abs(merged[-1][1] + half) < 0.01):
                    merged[-1][1] = c[1]
                else:
                    merged.append(c)
            for u0, u1, top, kind in merged:
                out.append((u0, u1, ve[j], ve[j + 1], top, kind, True))
        # Everything else: coarse non-colliding fallback (only seen before the client mesh loads).
        step = 40.0
        ue2 = edges(UMIN, UMAX, step, [-PLAY_U, PLAY_U])
        ve2 = edges(-VHALF, VHALF, step * 650 / 640, [-PLAY_V, PLAY_V])
        for j in range(len(ve2) - 1):
            row = []
            for i in range(len(ue2) - 1):
                u0, u1, v0, v1 = ue2[i], ue2[i + 1], ve2[j], ve2[j + 1]
                if -PLAY_U <= u0 and u1 <= PLAY_U and -PLAY_V <= v0 and v1 <= PLAY_V:
                    if row:
                        row.append(None)
                    continue
                top, kind = cell(u0, u1, v0, v1, False)
                top = round(top)
                row.append([u0, u1, top, kind])
            merged = []
            for c in row:
                if c is None:
                    merged.append(None)
                elif merged and merged[-1] is not None and merged[-1][2] == c[2] and merged[-1][3] == c[3]:
                    merged[-1][1] = c[1]
                else:
                    merged.append(c)
            for c in merged:
                if c:
                    out.append((c[0], c[1], ve2[j], ve2[j + 1], c[2], c[3], False))
        # Join boxes that continue unchanged into the next row.
        out.sort(key=lambda b: (b[6], b[0], b[1], b[4], b[5], b[2]))
        joined = []
        for b in out:
            last = joined[-1] if joined else None
            if last and last[0] == b[0] and last[1] == b[1] and last[4] == b[4] and last[5] == b[5] \
                    and last[6] == b[6] and abs(last[3] - b[2]) < 1e-6:
                joined[-1] = (last[0], last[1], last[2], b[3], last[4], last[5], last[6])
            else:
                joined.append(b)
        return joined


# ----------------------------------------------------------------- writers

def r(value, digits):
    value = round(float(value), digits)
    return str(int(value)) if float(value).is_integer() else f"{value:.{digits}f}".rstrip("0").rstrip(".")


def write_data(levels):
    lines = ["-- Generated by tools/build_level_maps.py from the Pack 5 bay-crossing map",
             "-- (Swamphacks_Lowpoly_Pack5/source/level1.py). Positions are relative to each level's Origin.",
             "-- Tiles: road tile centres {x, z, ...}; Pads: flat building lots {x, z, halfX, halfZ, groundY, ...}.",
             "-- Props: {model, x, y, z, yawDegrees, scale}. Shared.LevelMaps builds the terrain from this.",
             "return {"]
    for lv in levels:
        lines.append(f"\t[{lv.id}] = {{")
        lines.append(f'\t\tTitle = "{lv.title}", Theme = "{lv.theme}", Half = {num(lv.half)}, Beaches = {num(lv.t["beaches"])},')
        lines.append("\t\tTiles = {" + ",".join(f"{num(u)},{num(v)}" for u, v in lv.tiles) + "},")
        lines.append("\t\tPads = {" + ",".join(",".join(r(x, 2) for x in p) for p in lv.pads) + "},")
        lines.append("\t\tProps = {")
        for model, u, y, v, yaw, scale in lv.props:
            lines.append(f'\t\t\t{{"{model}",{r(u, 1)},{r(y, 2)},{r(v, 1)},{r(yaw, 0)},{r(scale, 2)}}},')
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    (ROOT / "src" / "shared" / "LevelMapData.luau").write_text("\n".join(lines) + "\n")


def preview(level, verts, faces, palette):
    scale = 1.0
    w, h = int((UMAX - UMIN) * scale), int(2 * VHALF * scale)
    img = Image.new("RGB", (w, h), (61, 143, 203))
    dr = ImageDraw.Draw(img)

    def p(x, z):
        return ((x - UMIN) * scale, (z + VHALF) * scale)

    for a, b, c, col in sorted(faces, key=lambda f: (verts[f[0]][1] + verts[f[1]][1] + verts[f[2]][1])):
        ya = (verts[a][1] + verts[b][1] + verts[c][1]) / 3
        if ya <= WATER - 0.2:
            continue
        hx = palette[col - 1].lstrip("#")
        rgb = tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4))
        dr.polygon([p(verts[q][0], verts[q][2]) for q in (a, b, c)], fill=rgb)
    for model, u, y, v, yaw, s in level.props:
        r = {"Office_Tower": 18, "Apartment_Block": 17, "Gas_Station": 24, "House_Cottage": 12, "House_TwoStory": 13,
             "Shop_Corner": 14, "Lighthouse": 8, "Island_Palm": 40, "Wooden_Dock": 4}.get(model, 3)
        if model.startswith("Road_") and model != "Road_Barrier":
            dr.rectangle([p(u - 16, v - 16), p(u + 16, v + 16)], fill=(70, 72, 80))
        elif model.startswith("Tree"):
            dr.ellipse([p(u - 4, v - 4), p(u + 4, v + 4)], fill=(30, 100, 40))
        else:
            dr.rectangle([p(u - r, v - r), p(u + r, v + r)], outline=(250, 250, 250))
    half = level.half
    dr.rectangle([p(-190, -104), p(190, 104)], outline=(255, 60, 60))
    dr.line([p(-half, -12), p(-half, 12)], fill=(255, 220, 0), width=3)
    dr.line([p(half, -12), p(half, 12)], fill=(255, 220, 0), width=3)
    out = ROOT / "tools" / "level_map_previews"
    out.mkdir(exist_ok=True)
    img.save(out / f"Level{level.id}.png")


def main():
    config = (ROOT / "src" / "shared" / "LevelConfig.luau").read_text()
    campaign = re.findall(r'Title="([^"]+)", Theme="(\w+)", Gap=(\d+)', config)
    palette = read_palette()
    known = len(palette)
    export_palm(palette)
    if len(palette) != known:   # only rewrite the palette when the palm needed new colours
        (MESH_DIR / "Palette.luau").write_text("return {" + ",".join(json.dumps(c) for c in palette) + "}\n")
    colors = {}
    for name, hx in (("seabed", "#C9B784"), ("sand", "#E2CE93"), ("cliff", "#8E8174"), ("turf", "#5FAE4E"), ("turf_dark", "#4E9A43")):
        colors[name] = palette.index(hx) + 1
    bounds = mesh_bounds()
    levels = []
    for i, (title, theme, gap) in enumerate(campaign, start=1):
        lv = LevelMap(i, title, theme, float(gap), bounds)
        lv.build()
        verts, faces = lv.terrain(colors)
        lv.box_list = lv.boxes()
        preview(lv, verts, faces, palette)
        levels.append(lv)
        print(f"Level {i} {title} ({theme}, gap {gap}): {len(lv.props)} props, {len(faces)} terrain triangles, "
              f"{len(verts)} vertices, {len(lv.box_list)} terrain boxes")
    write_data(levels)


if __name__ == "__main__":
    main()
