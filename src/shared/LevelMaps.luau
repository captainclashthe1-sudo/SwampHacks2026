-- Terrain for the level maps adapted from the Pack 5 bay-crossing map.
-- tools/build_level_maps.py plans every map (road tiles, building pads, props) into LevelMapData.
-- This module rebuilds the land from that plan with the same rules as LevelMap.height() in the
-- tool: the server uses Boxes() for collision, the client draws TerrainPiece(). Keep both in step.
local Data=require(script.Parent:WaitForChild("LevelMapData"))
local Palette=require(script.Parent:WaitForChild("LowpolyMeshData"):WaitForChild("Palette"))
local Maps={}

local WATER,LAND,ROADBED=-12,3.65,3.3
local UMIN,UMAX,VHALF,SPACING=-520,520,325,650
local SKIRT_Y,SEABED_DEPTH,TILE_HALF=-36,9,16
local PLAY_U,PLAY_V=196,112
Maps.BoxBottom=SKIRT_Y

local function sstep(a,b,x)
 local t=math.clamp((x-a)/(b-a),0,1)
 return t*t*(3-2*t)
end
local function lerp(a,b,t) return a+(b-a)*t end
local function hash01(a,b,c)
 local x=math.sin(a*12.9898+b*78.233+c*37.719)*43758.5453
 return x-math.floor(x)
end
local function colorIndex(hex)
 for i,value in ipairs(Palette) do if value==hex then return i end end
 return 1
end
local COLORS={seabed=colorIndex("#C9B784"),sand=colorIndex("#E2CE93"),cliff=colorIndex("#8E8174"),
 turf=colorIndex("#5FAE4E"),turf_dark=colorIndex("#4E9A43")}

local Field={}
Field.__index=Field
local fields={}
local function field(id)
 if fields[id] then return fields[id] end
 local d=Data[id]
 if not d then return nil end
 local f=setmetatable({Half=d.Half,Oz=(id-1)*SPACING,Tiles=d.Tiles,Pads=d.Pads,Beaches=d.Beaches},Field)
 fields[id]=f
 return f
end
function Field:near(v) return 1-sstep(28,110,math.abs(v)) end
function Field:shore(v,side)
 local w=self.Oz+v
 local nw=66+10*math.sin(w*0.0157+1+side*2.1)+7*math.sin(w*0.041+side*0.7)
 local n=self:near(v)
 return self.Half*n+nw*(1-n)
end
function Field:rise(v,side)
 local w=self.Oz+v
 local rw=5+24*(0.5+0.5*math.sin(w*0.0113+side*1.3))
 local n=self:near(v)
 return 0.6*n+rw*(1-n)
end
function Field:base(u,v)
 local w=self.Oz+v
 local f=sstep(130,260,math.abs(v))
 local world=LAND-7.5*(0.5+0.5*math.sin(w*0.0083+0.4+u*0.004))
 return LAND*(1-f)+world*f
end
function Field:hills(u,v)
 local w=self.Oz+v
 local cell=150
 local total=0
 local ci,cj=math.floor(u/cell),math.floor(w/cell)
 for i=ci-2,ci+2 do
  for j=cj-2,cj+2 do
   local cx=(i+0.2+0.6*hash01(i,j,1))*cell
   local cz=(j+0.2+0.6*hash01(i,j,2))*cell
   local amp=14+58*hash01(i,j,3)^1.4
   local sig=42+46*hash01(i,j,4)
   local d2=(u-cx)^2+(w-cz)^2
   if d2<(3.2*sig)^2 then total+=amp*math.exp(-d2/(2*sig*sig)) end
  end
 end
 if u<0 then total*=lerp(0.22,1,sstep(260,470,-u)) else total*=lerp(0.55,1,sstep(60,220,u)) end
 -- Keep the camera side (+Z) of the crossing low so hills never block the build view.
 total*=1-0.78*sstep(-40,20,v)*(1-sstep(70,230,v))
 return total
end
function Field:roadDist(u,v)
 local d=math.huge
 local t=self.Tiles
 for i=1,#t,2 do d=math.min(d,math.max(math.abs(u-t[i]),math.abs(v-t[i+1]))-TILE_HALF) end
 return d
end
function Field:padInfo(u,v)
 local best,target=math.huge,LAND
 local p=self.Pads
 for i=1,#p,5 do
  local d=math.max(math.abs(u-p[i])-p[i+2],math.abs(v-p[i+1])-p[i+3])
  if d<best then best,target=d,p[i+4] end
 end
 return best,target
end
function Field:landDist(u,v)
 local side=u>=0 and 1 or -1
 return math.abs(u)-self:shore(v,side),side
end
function Field:height(u,v)
 local d,side=self:landDist(u,v)
 local r=self:rise(v,side)
 if d< -r then return WATER-math.min(SEABED_DEPTH,(-r-d)*1.3)-0.05 end
 local top=self:base(u,v)+self:hills(u,v)*sstep(10,90,d)
 local h=WATER+(top-WATER)*sstep(-r,0,d)
 if d>=0 then
  h+=(ROADBED-h)*(1-sstep(1.5,26,self:roadDist(u,v)))
  local pd,tz=self:padInfo(u,v)
  h+=(tz-h)*(1-sstep(1,18,pd))
 end
 return h
end
function Field:flatWeight(u,v)
 local pd=self:padInfo(u,v)
 return math.max(1-sstep(1.5,26,self:roadDist(u,v)),1-sstep(1,18,pd))
end

function Maps.Get(id) return Data[id] end
function Maps.Height(id,u,v)
 local f=field(id)
 return f and f:height(u,v)
end

-- The terrain mesh in the LowpolyMeshData piece format, relative to the level origin.
local pieces={}
function Maps.TerrainPiece(id)
 if pieces[id] then return pieces[id] end
 local f=field(id)
 if not f then return nil end
 local half=f.Half
 local breaks={-half,-(half-0.6),-(half-2),half-2,half-0.6,half}
 local isBreak={}
 for _,b in ipairs(breaks) do isBreak[b]=true end
 local us={}
 for i=0,64 do
  local u=UMIN+i*(UMAX-UMIN)/64
  local clear=true
  for _,b in ipairs(breaks) do if math.abs(u-b)<=3 then clear=false end end
  if clear then table.insert(us,u) end
 end
 for _,b in ipairs(breaks) do table.insert(us,b) end
 table.sort(us)
 local vs={}
 for j=0,40 do vs[j+1]=-VHALF+j*(2*VHALF)/40 end
 local nu,nv=#us,#vs
 local px,py,pz={},{},{}
 local index={}
 for i,u in ipairs(us) do
  index[i]={}
  for j,v in ipairs(vs) do
   local x,z=u,v
   local h=f:height(u,v)
   local edge=i==1 or i==nu or j==1 or j==nv
   local calm=(math.abs(v)<44 and math.abs(math.abs(u)-half)<22) or isBreak[u]
   if not edge and not calm and f:flatWeight(u,v)<0.05 then
    local w=f.Oz+v
    local ku,kw=math.round(u*4),math.round(w*4)
    x+=(hash01(ku,kw,11)*2-1)*3.4
    z+=(hash01(ku,kw,12)*2-1)*3.4
    h=f:height(x,z)+(hash01(ku,kw,13)*2-1)*(h>WATER and 1.2 or 0.6)
   end
   table.insert(px,x); table.insert(py,h); table.insert(pz,z)
   index[i][j]=#px
  end
 end
 local faces={}
 local function normal(a,b,c)
  local e1x,e1y,e1z=px[b]-px[a],py[b]-py[a],pz[b]-pz[a]
  local e2x,e2y,e2z=px[c]-px[a],py[c]-py[a],pz[c]-pz[a]
  return e1y*e2z-e1z*e2y,e1z*e2x-e1x*e2z,e1x*e2y-e1y*e2x
 end
 local function tri(a,b,c)
  local nx,ny,nz=normal(a,b,c)
  if ny<0 then b,c=c,b end
  local cx,cy,cz=(px[a]+px[b]+px[c])/3,(py[a]+py[b]+py[c])/3,(pz[a]+pz[b]+pz[c])/3
  local len=math.sqrt(nx*nx+ny*ny+nz*nz)
  if len==0 then len=1 end
  local hw=cy-WATER
  local color
  if hw< -1.5 then color=COLORS.seabed
  elseif hw<5*f.Beaches+1 and math.abs(cy-ROADBED)>0.2 then color=COLORS.sand
  elseif math.abs(ny/len)<0.72 then color=COLORS.cliff
  elseif (math.floor(cx/48)+math.floor((f.Oz+cz)/66))%3~=0 then color=COLORS.turf
  else color=COLORS.turf_dark end
  table.insert(faces,a); table.insert(faces,b); table.insert(faces,c); table.insert(faces,color)
 end
 for i=1,nu-1 do
  for j=1,nv-1 do
   local a,b,c,d=index[i][j],index[i+1][j],index[i+1][j+1],index[i][j+1]
   if (i+j)%2==0 then tri(a,b,c); tri(a,c,d) else tri(a,b,d); tri(b,c,d) end
  end
 end
 -- Skirt down so the map edge reads as a solid block (level1.py does the same).
 local ring={}
 for i=1,nu do table.insert(ring,index[i][1]) end
 for j=2,nv do table.insert(ring,index[nu][j]) end
 for i=nu-1,1,-1 do table.insert(ring,index[i][nv]) end
 for j=nv-1,2,-1 do table.insert(ring,index[1][j]) end
 local low={}
 local mx,mz=0,0
 for k,r in ipairs(ring) do
  table.insert(px,px[r]); table.insert(py,SKIRT_Y); table.insert(pz,pz[r])
  low[k]=#px
  mx+=px[r]; mz+=pz[r]
 end
 mx/=#ring; mz/=#ring
 for k=1,#ring do
  local k2=k%#ring+1
  for _,t in ipairs({{ring[k],ring[k2],low[k2]},{ring[k],low[k2],low[k]}}) do
   local a,b,c=t[1],t[2],t[3]
   local nx,_,nz=normal(a,b,c)
   if nx*((px[a]+px[b])/2-mx)+nz*((pz[a]+pz[b])/2-mz)<0 then b,c=c,b end
   table.insert(faces,a); table.insert(faces,b); table.insert(faces,c); table.insert(faces,COLORS.cliff)
  end
 end
 local vertices=table.create(#px*3)
 for k=1,#px do
  vertices[3*k-2]=px[k]; vertices[3*k-1]=py[k]; vertices[3*k]=pz[k]
 end
 local piece={Name="MapTerrain_L"..id.."_Land",Offset={0,0,0},Flat=true,Vertices=vertices,Faces=faces}
 pieces[id]=piece
 return piece
end

-- Terrain blocks: {minX, maxX, minZ, maxZ, topY, kind, collide}. Collidable 8-stud blocks cover
-- the play area (split exactly at the anchors); coarse non-colliding blocks stand in elsewhere
-- until the client mesh is ready.
function Maps.Boxes(id)
 local f=field(id)
 if not f then return {} end
 local half=f.Half
 local function edges(lo,hi,step,extra)
  local vals={}
  for i=0,math.round((hi-lo)/step) do
   local x=lo+i*step
   local keep=true
   for _,e in ipairs(extra) do if math.abs(x-e)<=step*0.3 then keep=false end end
   if keep then table.insert(vals,x) end
  end
  for _,e in ipairs(extra) do if e>lo and e<hi then table.insert(vals,e) end end
  table.sort(vals)
  return vals
 end
 local function cell(u0,u1,v0,v1)
  local uc,vc=(u0+u1)/2,(v0+v1)/2
  local points={{uc,vc},{lerp(u0,u1,.25),lerp(v0,v1,.25)},{lerp(u0,u1,.75),lerp(v0,v1,.25)},
   {lerp(u0,u1,.25),lerp(v0,v1,.75)},{lerp(u0,u1,.75),lerp(v0,v1,.75)}}
  local hs={}
  local lo,hi=math.huge,-math.huge
  for k,p in ipairs(points) do
   hs[k]=f:height(p[1],p[2]); lo=math.min(lo,hs[k]); hi=math.max(hi,hs[k])
  end
  local dc,side=f:landDist(uc,vc)
  local top
  if dc< -f:rise(vc,side) then
   top=lo
  else
   local sum,count=0,0
   for _,h in ipairs(hs) do if h>=WATER-0.5 then sum+=h; count+=1 end end
   if count==0 then for _,h in ipairs(hs) do sum+=h; count+=1 end end
   top=sum/count
  end
  top=math.round(top*4)/4
  local hw=top-WATER
  local kind=hw< -1.5 and "seabed" or hw<5*f.Beaches+1 and "sand" or hi-lo>7 and "cliff" or "turf"
  return top,kind
 end
 local out={}
 local ue=edges(-PLAY_U,PLAY_U,8,{-half,half})
 local ve=edges(-PLAY_V,PLAY_V,8,{})
 for j=1,#ve-1 do
  local merged={}
  for i=1,#ue-1 do
   local top,kind=cell(ue[i],ue[i+1],ve[j],ve[j+1])
   local last=merged[#merged]
   if last and last[3]==top and last[4]==kind and math.abs(math.abs(last[2])-half)>0.01 then
    last[2]=ue[i+1]
   else
    table.insert(merged,{ue[i],ue[i+1],top,kind})
   end
  end
  for _,c in ipairs(merged) do table.insert(out,{c[1],c[2],ve[j],ve[j+1],c[3],c[4],true}) end
 end
 local BREAK={}   -- play-area cells interrupt a run of coarse blocks
 local ue2=edges(UMIN,UMAX,40,{-PLAY_U,PLAY_U})
 local ve2=edges(-VHALF,VHALF,40*650/640,{-PLAY_V,PLAY_V})
 for j=1,#ve2-1 do
  local merged={}
  for i=1,#ue2-1 do
   local u0,u1,v0,v1=ue2[i],ue2[i+1],ve2[j],ve2[j+1]
   if -PLAY_U<=u0 and u1<=PLAY_U and -PLAY_V<=v0 and v1<=PLAY_V then
    table.insert(merged,BREAK)
   else
    local top,kind=cell(u0,u1,v0,v1)
    top=math.round(top)
    local last=merged[#merged]
    if last and last~=BREAK and last[3]==top and last[4]==kind then last[2]=u1 else table.insert(merged,{u0,u1,top,kind}) end
   end
  end
  for _,c in ipairs(merged) do
   if c~=BREAK then table.insert(out,{c[1],c[2],ve2[j],ve2[j+1],c[3],c[4],false}) end
  end
 end
 -- Join blocks that continue unchanged into the next row.
 table.sort(out,function(a,b)
  if a[7]~=b[7] then return a[7] end
  if a[1]~=b[1] then return a[1]<b[1] end
  if a[2]~=b[2] then return a[2]<b[2] end
  if a[5]~=b[5] then return a[5]<b[5] end
  if a[6]~=b[6] then return a[6]<b[6] end
  return a[3]<b[3]
 end)
 local joined={}
 for _,b in ipairs(out) do
  local last=joined[#joined]
  if last and last[1]==b[1] and last[2]==b[2] and last[5]==b[5] and last[6]==b[6] and last[7]==b[7]
   and math.abs(last[4]-b[3])<1e-6 then
   last[4]=b[4]
  else
   table.insert(joined,b)
  end
 end
 return joined
end

return Maps
