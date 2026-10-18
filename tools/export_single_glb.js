// Export one palette-textured Blender GLB into the game's EditableMesh data format.
// Usage: node tools/export_single_glb.js input.glb output.luau
const fs = require("fs");

const [input, output] = process.argv.slice(2);
const paletteOffset = Number(process.argv[4] || 0);
if (!input || !output) throw new Error("Expected input.glb and output.luau");
const raw = fs.readFileSync(input);
if (raw.toString("ascii", 0, 4) !== "glTF" || raw.readUInt32LE(4) !== 2) throw new Error("GLB v2 required");
const jsonLength = raw.readUInt32LE(12);
const document = JSON.parse(raw.subarray(20, 20 + jsonLength).toString());
const binaryStart = 20 + jsonLength;
const binary = raw.subarray(binaryStart + 8, binaryStart + 8 + raw.readUInt32LE(binaryStart));
const component = {
  5121: {bytes: 1, read: "readUInt8"},
  5123: {bytes: 2, read: "readUInt16LE"},
  5125: {bytes: 4, read: "readUInt32LE"},
  5126: {bytes: 4, read: "readFloatLE"},
};
const width = {SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4};
function accessor(index) {
  const spec = document.accessors[index];
  const view = document.bufferViews[spec.bufferView];
  const type = component[spec.componentType];
  const elements = width[spec.type];
  const start = (view.byteOffset || 0) + (spec.byteOffset || 0);
  const stride = view.byteStride || type.bytes * elements;
  return Array.from({length: spec.count}, (_, i) =>
    Array.from({length: elements}, (_, j) => binary[type.read](start + i * stride + j * type.bytes)));
}
const scale = 3.57142857;
const number = value => String(Number(value.toFixed(5)));
const vector = values => values.map(number).join(",");
const lines = [
  `-- Generated from ${input.split(/[\\/]/).pop()} by tools/export_single_glb.js.`,
  "-- Vertices are in studs; faces list three vertex indices and a palette index.",
  "return {",
];
for (const node of document.nodes) {
  if (node.mesh === undefined) continue;
  for (const primitive of document.meshes[node.mesh].primitives) {
    const positions = accessor(primitive.attributes.POSITION);
    const uvs = accessor(primitive.attributes.TEXCOORD_0);
    const indices = accessor(primitive.indices).map(item => item[0]);
    const vertices = positions.flatMap(([x, y, z]) => [x * scale, y * scale, -z * scale]);
    const faces = [];
    for (let i = 0; i < indices.length; i += 3) {
      const [first, second, third] = indices.slice(i, i + 3);
      const [u, v] = uvs[first];
      const palette = Math.min(7, Math.floor(u * 8)) + 8 * Math.min(7, Math.floor(v * 8)) + 1 + paletteOffset;
      faces.push(first + 1, third + 1, second + 1, palette);
    }
    const [x, y, z] = node.translation || [0, 0, 0];
    lines.push("\t{", `\t\tName = ${JSON.stringify(node.name)}, Offset = {${vector([x * scale, y * scale, -z * scale])}},`,
      `\t\tVertices = {${vector(vertices)}},`, `\t\tFaces = {${faces.join(",")}},`, "\t},");
  }
}
lines.push("}");
fs.writeFileSync(output, lines.join("\n") + "\n");
console.log(`Wrote ${output}`);
