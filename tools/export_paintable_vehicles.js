// Convert the supplied paintable GLBs to Rojo-friendly geometry for UI previews.
// Usage: node tools/export_paintable_vehicles.js <Vehicles_Paintable folder>
const fs = require("fs");
const path = require("path");

const source = process.argv[2];
if (!source) throw new Error("Pass the folder containing the paintable GLBs.");
const destination = path.join(__dirname, "..", "src", "shared", "PaintableVehicleData");
fs.mkdirSync(destination, {recursive: true});
const names = ["Car_Yellow", "Truck_Orange", "Motorbike_Blue", "Sports_Red"];
const types = {5121: [1, "readUInt8"], 5123: [2, "readUInt16LE"], 5125: [4, "readUInt32LE"], 5126: [4, "readFloatLE"]};
const widths = {SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4};
const scale = 3.57142857;
const number = x => String(Number((x * scale).toFixed(5)));
const array = values => values.join(",");

for (const name of names) {
  const raw = fs.readFileSync(path.join(source, name + ".glb"));
  if (raw.toString("ascii", 0, 4) !== "glTF") throw new Error("Expected GLB: " + name);
  const document = JSON.parse(raw.subarray(20, 20 + raw.readUInt32LE(12)).toString());
  const binaryStart = 20 + raw.readUInt32LE(12);
  const binary = raw.subarray(binaryStart + 8, binaryStart + 8 + raw.readUInt32LE(binaryStart));
  function accessor(index) {
    const spec = document.accessors[index];
    const view = document.bufferViews[spec.bufferView];
    const [bytes, read] = types[spec.componentType];
    const count = widths[spec.type];
    const start = (view.byteOffset || 0) + (spec.byteOffset || 0);
    const stride = view.byteStride || bytes * count;
    return Array.from({length: spec.count}, (_, i) => Array.from({length: count}, (_, j) => binary[read](start + i * stride + j * bytes)));
  }
  const lines = ["-- Generated from the supplied paintable " + name + ".glb.", "-- Face color 0 is paint; -1 is translucent glass; positive values use the shared atlas palette.", "return {"];
  for (const node of document.nodes) {
    if (node.mesh === undefined) continue;
    const kind = node.name.endsWith("_Paint") ? "Paint" : node.name.endsWith("_Glass") ? "Glass" : "Body";
    const primitive = document.meshes[node.mesh].primitives[0];
    const positions = accessor(primitive.attributes.POSITION);
    const uvs = primitive.attributes.TEXCOORD_0 === undefined ? null : accessor(primitive.attributes.TEXCOORD_0);
    const indices = accessor(primitive.indices).map(value => value[0]);
    const vertices = positions.flatMap(([x, y, z]) => [number(x), number(y), number(-z)]);
    const faces = [];
    for (let i = 0; i < indices.length; i += 3) {
      const [a, b, c] = indices.slice(i, i + 3);
      const uv = uvs && uvs[a];
      const color = kind === "Paint" ? 0 : kind === "Glass" ? -1 : Math.min(7, Math.floor(uv[0] * 8)) + 8 * Math.min(7, Math.floor(uv[1] * 8)) + 1;
      faces.push(a + 1, c + 1, b + 1, color);
    }
    const [x, y, z] = node.translation || [0, 0, 0];
    lines.push(" {Name=" + JSON.stringify(node.name) + ",Kind=" + JSON.stringify(kind) + ",Offset={" + array([number(x), number(y), number(-z)]) + "},Vertices={" + array(vertices) + "},Faces={" + array(faces) + "}},");
  }
  lines.push("}");
  fs.writeFileSync(path.join(destination, name + ".luau"), lines.join("\n") + "\n");
  console.log("Exported " + name);
}
