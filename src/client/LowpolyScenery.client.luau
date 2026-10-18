-- Draw the supplied Blender scenery geometry on each client. EditableMesh content
-- does not replicate from the server, so scenery is built here. One EditableMesh holds
-- at most 60,000 vertices and 20,000 triangles, so the level is split into several meshes.
-- The active level gets its terrain and props; the neighbouring levels get their terrain
-- so the river valley continues past the edge of the map.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local dataFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LowpolyMeshData")
local player=game:GetService("Players").LocalPlayer
local Config=require(ReplicatedStorage.Shared.LevelConfig)
local Maps=require(ReplicatedStorage.Shared:WaitForChild("LevelMaps"))
local generated=workspace:WaitForChild("GeneratedLevel")
local palette = require(dataFolder:WaitForChild("Palette"))
local nativeIds = require(ReplicatedStorage.Shared:WaitForChild("SceneryMeshIds"))
local MAX_TRIANGLES, MAX_VERTICES = 18000, 54000
local built={}

local function clearMesh()
 for _,item in ipairs(built) do
  if item.Part then item.Part:Destroy() end
  if item.Mesh then item.Mesh:Destroy() end
 end
 table.clear(built)
end
local function terrainId(model) return tonumber(model.Name:match("^MapTerrain_L(%d+)$")) end
local function isTerrain(model) return terrainId(model)~=nil end
local function pieces(model)
 local id=terrainId(model)
 if id then
  local piece=Maps.TerrainPiece(id)
  return piece and {piece} or nil
 end
 local source=dataFolder:FindFirstChild(model.Name)
 return source and require(source) or nil
end
local function drawable(model)
 if not model:IsA("Model") or model:GetAttribute("DynamicMesh") then return false end
 local id=terrainId(model)
 if id then return Maps.Get(id)~=nil end
 return dataFolder:FindFirstChild(model.Name)~=nil
end
local function setFallback(model,hidden)
 for _,child in ipairs(model:GetDescendants()) do
  if child:IsA("BasePart") then
   if child.Name=="NativeSceneryMesh" then
    child.Transparency=hidden and 1 or 0
   else
    child.LocalTransparencyModifier=hidden and 1 or 0
   end
  end
 end
end

-- World-space triangles for one model. Flat pieces get their own vertices per triangle.
local function collect(model)
 local base=model:GetPivot()
 local scale=model:GetScale()
 local heightScale=model:GetAttribute("HeightScale") or 1
 local points,faces={},{}
 for _,piece in ipairs(pieces(model)) do
  local offset=Vector3.new(piece.Offset[1],piece.Offset[2],piece.Offset[3])
  local source,list=piece.Vertices,piece.Faces
  local world=table.create(#source//3)
  for i=1,#source,3 do
   local localPoint=(Vector3.new(source[i],source[i+1],source[i+2])+offset)*scale
   world[#world+1]=base:PointToWorldSpace(Vector3.new(localPoint.X,localPoint.Y*heightScale,localPoint.Z))
  end
  if piece.Flat then
   for i=1,#list,4 do
    local n=#points
    points[n+1]=world[list[i]]; points[n+2]=world[list[i+1]]; points[n+3]=world[list[i+2]]
    faces[#faces+1]={n+1,n+2,n+3,list[i+3]}
   end
  else
   local start=#points
   table.move(world,1,#world,start+1,points)
   for i=1,#list,4 do
    faces[#faces+1]={start+list[i],start+list[i+1],start+list[i+2],list[i+3]}
   end
  end
 end
 return {Model=model,Points=points,Faces=faces}
end

-- Common props are replicated as uploaded MeshParts by the server.
-- Never create a client copy: replication timing could otherwise show two props.
local function renderNative(model)
 if not nativeIds[model.Name] then return false end
 setFallback(model,false)
 return true
end

-- Build one MeshPart from several models. Returns false if the client is out of mesh memory.
local function flush(batches,parent)
 if #batches==0 then return true end
 local mesh=AssetService:CreateEditableMesh()
 if not mesh then warn("Blender scenery renderer: EditableMesh memory budget exhausted"); return false end
 local colorIds={}
 for i,hex in ipairs(palette) do colorIds[i]=mesh:AddColor(Color3.fromHex(hex),1) end
 local low=Vector3.new(math.huge,math.huge,math.huge)
 local high=-low
 for _,batch in ipairs(batches) do
  for _,point in ipairs(batch.Points) do low=low:Min(point); high=high:Max(point) end
 end
 local center=(low+high)*0.5
 local added=0
 for _,batch in ipairs(batches) do
  local ids=table.create(#batch.Points)
  for i,point in ipairs(batch.Points) do
   ids[i]=mesh:AddVertex(point-center)
   added+=1
   if added%1500==0 then task.wait() end
  end
  for i,face in ipairs(batch.Faces) do
   local id=mesh:AddTriangle(ids[face[1]],ids[face[2]],ids[face[3]])
   local color=colorIds[face[4]] or colorIds[1]
   mesh:SetFaceColors(id,{color,color,color})
   if i%1000==0 then task.wait() end
  end
 end
 local ok,part=pcall(function()
  return AssetService:CreateMeshPartAsync(Content.fromObject(mesh),{CollisionFidelity=Enum.CollisionFidelity.Box})
 end)
 if not ok then mesh:Destroy(); warn("Blender scenery renderer: "..tostring(part)); return false end
 part.Name="BlenderSceneryMesh"
 part.Anchored=true
 part.CanCollide=false
 part.CanTouch=false
 part.CanQuery=false
 part.Material=Enum.Material.SmoothPlastic
 part.Color=Color3.new(1,1,1)
 part.CFrame=CFrame.new(center)
 part.Parent=parent
 -- CreateMeshPartAsync can keep a reference to this EditableMesh content.
 -- Retain it for the lifetime of the visible part; destroying it empties the part.
 table.insert(built,{Mesh=mesh,Part=part})
 -- Keep server Parts as fallback until the original geometry is ready.
 for _,batch in ipairs(batches) do setFallback(batch.Model,true) end
 return true
end

local function render(models,parent)
 local batches,triangles,vertices={},0,0
 local meshes,totalVertices,totalFaces=0,0,0
 for _,model in ipairs(models) do
  local batch=collect(model)
  if triangles+#batch.Faces>MAX_TRIANGLES or vertices+#batch.Points>MAX_VERTICES then
   if not flush(batches,parent) then return false end
   meshes+=1
   batches,triangles,vertices={},0,0
  end
  table.insert(batches,batch)
  triangles+=#batch.Faces; vertices+=#batch.Points
  totalVertices+=#batch.Points; totalFaces+=#batch.Faces
 end
 if not flush(batches,parent) then return false end
 meshes+=1
 print(string.format("Blender scenery ready: %d vertices, %d faces in %d meshes", totalVertices, totalFaces, meshes))
 return true
end

local function scenery(id)
 local level=generated:FindFirstChild("Level"..id)
 local folder=level and level:FindFirstChild("LowpolyScenery")
 return folder and folder:GetAttribute("Ready") and folder or nil
end

local requested=0
local busy=false
local renderedId
local buildingId
local function refresh()
 local targetId=player:GetAttribute("ActiveLevelId") or 1
 if (busy and targetId==buildingId) or (not busy and targetId==renderedId) then return end
 requested+=1
 if busy then return end
 busy=true
 repeat
  local revision=requested
  player:SetAttribute("SceneryReadyLevel",0)
  clearMesh()
  local id=player:GetAttribute("ActiveLevelId") or 1
  buildingId=id
  local active=generated:WaitForChild("Level"..id):WaitForChild("LowpolyScenery")
  while not active:GetAttribute("Ready") do task.wait(.1) end
  do
   local models={}
   -- Other levels show only their terrain (neighbours, drawn below) or the server's terrain blocks.
   for other=1,#Config.Campaign do
    local folder=other~=id and scenery(other)
    if folder then
     for _,model in ipairs(folder:GetChildren()) do
      if drawable(model) then
       local neighbour=math.abs(other-id)==1 and isTerrain(model)
       setFallback(model,not isTerrain(model))
       -- Distant terrain keeps its server fallback; only the active map needs detailed geometry.
      end
     end
    end
   end
   local props={}
   for _,model in ipairs(active:GetChildren()) do
    if drawable(model) and not renderNative(model) then
     table.insert(isTerrain(model) and models or props,model)
    end
   end
   table.move(props,1,#props,#models+1,models)
   local ok,result=pcall(render,models,active)
   if not ok then warn("Blender scenery renderer: "..tostring(result)) end
   if ok and result then
    player:SetAttribute("SceneryReadyLevel",id)
    renderedId=id
   else
    -- Retry a failed mesh pass after freeing its partial output. Never claim
    -- that the detailed map is loaded while only fallback boxes are visible.
    clearMesh()
    renderedId=nil
    task.delay(2,refresh)
   end
  end
 until revision==requested
 buildingId=nil
 busy=false
end
player:GetAttributeChangedSignal("ActiveLevelId"):Connect(refresh)
refresh()
