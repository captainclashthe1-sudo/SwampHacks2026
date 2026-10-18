"""Convert the supplied glTF meshes into Rojo-friendly EditableMesh source data.

Run from the project root: py tools/export_lowpoly.py
The generated Luau contains geometry and palette indices, not uploaded asset IDs.
"""

import json
import pathlib
import re
import struct


ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Swamphacks_Lowpoly_Pack3" / "models"
DEST = ROOT / "src" / "shared" / "LowpolyMeshData"


def accessor(document, binary, index):
    spec = document["accessors"][index]
    view = document["bufferViews"][spec["bufferView"]]
    kind = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[spec["componentType"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[spec["type"]]
    decoder = struct.Struct("<" + kind * width)
    offset = view.get("byteOffset", 0) + spec.get("byteOffset", 0)
    stride = view.get("byteStride", decoder.size)
    return [decoder.unpack_from(binary, offset + i * stride) for i in range(spec["count"])]


def number(value):
    rounded = round(float(value), 5)
    return str(int(rounded)) if rounded.is_integer() else f"{rounded:.5f}".rstrip("0").rstrip(".")


def vector(values):
    return ",".join(number(value) for value in values)


def read_model(path):
    raw = path.read_bytes()
    if raw[:4] != b"glTF" or struct.unpack_from("<I", raw, 4)[0] != 2:
        raise ValueError(f"Unsupported GLB: {path}")
    json_length = struct.unpack_from("<I", raw, 12)[0]
    document = json.loads(raw[20 : 20 + json_length])
    binary_start = 20 + json_length
    binary_length = struct.unpack_from("<I", raw, binary_start)[0]
    binary = raw[binary_start + 8 : binary_start + 8 + binary_length]
    pieces = []
    for node in document["nodes"]:
        if "mesh" not in node:
            continue
        primitive = document["meshes"][node["mesh"]]["primitives"][0]
        positions = accessor(document, binary, primitive["attributes"]["POSITION"])
        uvs = accessor(document, binary, primitive["attributes"]["TEXCOORD_0"])
        indices = [entry[0] for entry in accessor(document, binary, primitive["indices"])]
        vertices = []
        for x, y, z in positions:
            # glTF is right handed. Roblox's front is -Z, so flip Z and winding.
            vertices.extend((x * 3.57142857, y * 3.57142857, -z * 3.57142857))
        faces = []
        for i in range(0, len(indices), 3):
            first, second, third = indices[i : i + 3]
            u, v = uvs[first]
            palette_index = min(7, int(u * 8)) + 8 * min(7, int(v * 8)) + 1
            faces.extend((first + 1, third + 1, second + 1, palette_index))
        translation = node.get("translation", [0, 0, 0])
        offset = [translation[0] * 3.57142857, translation[1] * 3.57142857, -translation[2] * 3.57142857]
        pieces.append((node["name"], offset, vertices, faces))
    return pieces


def main():
    palette_source = (SOURCE.parent / "source" / "build.py").read_text()
    palette_block = palette_source.split("PALETTE = [", 1)[1].split("\n]", 1)[0]
    palette = re.findall(r'\("[^"]+", "([0-9A-Fa-f]{6})"\)', palette_block)
    for filename in ("level1.py", "buildings.py"):
        extra = (SOURCE.parent / "source" / filename).read_text()
        block = extra.split('for n, hx in [', 1)[1].split(']:', 1)[0]
        palette.extend(re.findall(r'\("[^"]+", "([0-9A-Fa-f]{6})"\)', block))
    DEST.mkdir(exist_ok=True)
    (DEST / "Palette.luau").write_text("-- Generated palette from the supplied Blender pack.\nreturn {" + ",".join('"#' + code + '"' for code in palette) + "}\n")
    for source in sorted(SOURCE.glob("*.glb")):
        lines = [
            "-- Generated from " + source.name + " by tools/export_lowpoly.py.",
            "-- Vertices are in studs; faces list three vertex indices and a palette index.",
            "return {",
        ]
        for name, offset, vertices, faces in read_model(source):
            lines.append("\t\t{")
            lines.append(f'\t\t\tName = "{name}", Offset = {{{vector(offset)}}},')
            lines.append("\t\t\tVertices = {" + vector(vertices) + "},")
            lines.append("\t\t\tFaces = {" + ",".join(map(str, faces)) + "},")
            lines.append("\t\t},")
        lines.append("}")
        (DEST / f"{source.stem}.luau").write_text("\n".join(lines) + "\n")
    print(f"Wrote {len(list(SOURCE.glob('*.glb')))} model modules in {DEST}")


if __name__ == "__main__":
    main()
