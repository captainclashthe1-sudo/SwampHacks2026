-- Client geometry follows replicated server pivots; physics and decisions stay on server.
local Assets=game:GetService("AssetService")
local RunService=game:GetService("RunService")
local player=game:GetService("Players").LocalPlayer
local data=game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LowpolyMeshData")
local paintable=game:GetService("ReplicatedStorage").Shared:WaitForChild("PaintableVehicleData")
local palette=require(data.Palette)
local generated=workspace:WaitForChild("GeneratedLevel")
local active={}
local function makeVisual(model,pieces)
 local mesh=assert(Assets:CreateEditableMesh(),"Moving mesh memory unavailable")
 local colors={} for i,hex in ipairs(palette) do colors[i]=mesh:AddColor(Color3.fromHex(hex),1) end
 colors[0]=mesh:AddColor(model:GetAttribute("PaintColor") or Color3.fromRGB(240,190,50),1)
 colors[-1]=mesh:AddColor(Color3.fromRGB(165,216,240),0.4)
 local scale=model:GetScale()
 for _,piece in ipairs(pieces) do
  local vertices={}; local offset=Vector3.new(table.unpack(piece.Offset))
  for i=1,#piece.Vertices,3 do
   table.insert(vertices,mesh:AddVertex((Vector3.new(piece.Vertices[i],piece.Vertices[i+1],piece.Vertices[i+2])+offset)*scale))
  end
  for i=1,#piece.Faces,4 do
   local f=mesh:AddTriangle(vertices[piece.Faces[i]],vertices[piece.Faces[i+1]],vertices[piece.Faces[i+2]])
   local c=colors[piece.Faces[i+3]]; mesh:SetFaceColors(f,{c,c,c})
  end
 end
 -- Center explicitly, just like the static scenery renderer.
 local low=Vector3.new(math.huge,math.huge,math.huge); local high=-low
 for _,id in ipairs(mesh:GetVertices()) do local p=mesh:GetPosition(id);low=low:Min(p);high=high:Max(p) end
 local center=(low+high)/2
 for _,id in ipairs(mesh:GetVertices()) do mesh:SetPosition(id,mesh:GetPosition(id)-center) end
 local part=Assets:CreateMeshPartAsync(Content.fromObject(mesh))
 part.Name="MovingBlenderMesh"; part.Anchored=true; part.CanCollide=false; part.CanTouch=false; part.CanQuery=false
 part.Material=Enum.Material.SmoothPlastic; part.Color=Color3.new(1,1,1)
 return {Mesh=mesh,Part=part,Center=center}
end
local function create(model)
 local name=model:GetAttribute("DynamicMesh")
 local source=paintable:FindFirstChild(name) or data:FindFirstChild(name)
 if not source then return end
 local pieces=require(source)
 local entry
 if name=="Plane_Prop" then
  local body,propeller={},{}
  for _,piece in ipairs(pieces) do
   table.insert(piece.Name:find("Propeller") and propeller or body,piece)
  end
  entry=makeVisual(model,body)
  entry.Propeller=makeVisual(model,propeller)
  entry.Spin=0
 else entry=makeVisual(model,pieces) end
 if not model.Parent then
  entry.Part:Destroy();entry.Mesh:Destroy()
  if entry.Propeller then entry.Propeller.Part:Destroy();entry.Propeller.Mesh:Destroy() end
  return
 end
 for _,p in ipairs(model:GetDescendants()) do
  if p:IsA("BasePart") and not p:GetAttribute("KeepVisible") then p.LocalTransparencyModifier=1 end
 end
 entry.Part.Parent=workspace
 if entry.Propeller then entry.Propeller.Part.Parent=workspace end
 active[model]=entry
end
RunService.RenderStepped:Connect(function(dt)
 local level=generated:FindFirstChild("Level"..(player:GetAttribute("ActiveLevelId") or 1))
 for model,entry in pairs(active) do
  if not model.Parent or not level or not model:IsDescendantOf(level) then
   entry.Part:Destroy();entry.Mesh:Destroy()
   if entry.Propeller then entry.Propeller.Part:Destroy();entry.Propeller.Mesh:Destroy() end
   active[model]=nil
  else
   local pivot=model:GetPivot()
   entry.Part.CFrame=pivot*CFrame.new(entry.Center)
   if entry.Propeller then
    if model:GetAttribute("PlaneFlying") then entry.Spin=(entry.Spin+dt*30)%(math.pi*2) end
    entry.Propeller.Part.CFrame=pivot*CFrame.new(entry.Propeller.Center)*CFrame.Angles(0,0,entry.Spin)
   end
  end
 end
end)
while true do
 local level=generated:FindFirstChild("Level"..(player:GetAttribute("ActiveLevelId") or 1))
 if level then for _,model in ipairs(level:GetDescendants()) do
  if model:IsA("Model") and model:GetAttribute("DynamicMesh") and not active[model] then
   local ok,err=pcall(create,model);if not ok then warn("Moving mesh: "..tostring(err)) end
  end
 end end
 task.wait(.5)
end
