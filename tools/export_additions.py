from pathlib import Path
import importlib.util,json,struct,re,io
from PIL import Image
R=Path(__file__).resolve().parents[1]; P=R
spec=importlib.util.spec_from_file_location('exporter',P/'tools/export_lowpoly.py');e=importlib.util.module_from_spec(spec);spec.loader.exec_module(e)
dest=R/'src/shared/LowpolyMeshData'
palette=re.findall(r'"(#[A-Fa-f0-9]{6})"',(dest/'Palette.luau').read_text())
for pack,name in [(4,'Truck_Orange'),(5,'Island_Palm')]:
 path=P/f'Swamphacks_Lowpoly_Pack{pack}/models/{name}.glb'
 raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);binary=raw[28+n:]
 image=doc['images'][0];view=doc['bufferViews'][image['bufferView']];off=view.get('byteOffset',0)
 texture=Image.open(io.BytesIO(binary[off:off+view['byteLength']])).convert('RGB')
 pieces=e.read_model(path);nodes=[n for n in doc['nodes'] if 'mesh' in n]
 lines=['-- Original supplied GLB triangles, sampled palette colors.','return {']
 for (pn,offset,verts,faces),node in zip(pieces,nodes):
  prim=doc['meshes'][node['mesh']]['primitives'][0]
  uv=e.accessor(doc,binary,prim['attributes']['TEXCOORD_0']);indices=e.accessor(doc,binary,prim['indices'])
  for j in range(0,len(faces),4):
   u,v=uv[indices[(j//4)*3][0]]
   rgb=texture.getpixel((min(texture.width-1,max(0,int(u*texture.width))),min(texture.height-1,max(0,int(v*texture.height)))))
   hx='#%02X%02X%02X'%rgb
   if hx not in palette:palette.append(hx)
   faces[j+3]=palette.index(hx)+1
  lines.append('{Name='+json.dumps(pn)+',Offset={'+e.vector(offset)+'},Vertices={'+e.vector(verts)+'},Faces={'+','.join(map(str,faces))+'}},')
 lines.append('}');(dest/f'{name}.luau').write_text('\n'.join(lines))
 print(name,len(pieces),sum(len(p[2])//3 for p in pieces),'vertices')
(dest/'Palette.luau').write_text('return {'+','.join(json.dumps(c) for c in palette)+'}\n')
