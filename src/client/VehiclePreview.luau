-- Paintable vehicle GLB geometry in a ViewportFrame, with a simple fallback while it loads.
local Preview={}
local AssetService=game:GetService("AssetService")
local data=game:GetService("ReplicatedStorage").Shared:WaitForChild("PaintableVehicleData")
local palette=require(game:GetService("ReplicatedStorage").Shared.LowpolyMeshData.Palette)
local templates={}
local loading={}
local active={}
local generation=0
local function paintableName(name)
 if name:find("Truck",1,true) then return "Truck_Orange" end
 if name:find("Motorbike",1,true) then return "Motorbike_Blue" end
 if name:find("Sports",1,true) then return "Sports_Red" end
 return "Car_Yellow"
end

local function makeExactTemplate(name,paint)
 local key=name..":"..paint:ToHex()
 if templates[key] then return templates[key] end
 while loading[key] do task.wait() end
 if templates[key] then return templates[key] end
 loading[key]=true
 local startedAt=generation
 local created={}
 local ok,result=pcall(function()
  local source=data:WaitForChild(name,5)
  if not source then error("Paintable vehicle data missing: "..name) end
  local pieces=require(source)
  local low,high=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
  for _,piece in ipairs(pieces) do
   local offset=Vector3.new(table.unpack(piece.Offset))
   for i=1,#piece.Vertices,3 do
    local point=Vector3.new(piece.Vertices[i],piece.Vertices[i+1],piece.Vertices[i+2])+offset
    low=low:Min(point);high=high:Max(point)
   end
  end
  local center=(low+high)*0.5
  local mesh=assert(AssetService:CreateEditableMesh(),"EditableMesh memory unavailable")
  table.insert(created,mesh)
  local colorIds={}
  local count=0
  for _,piece in ipairs(pieces) do
     local offset=Vector3.new(table.unpack(piece.Offset))
     local vertices={}
     for i=1,#piece.Vertices,3 do
      vertices[#vertices+1]=mesh:AddVertex(Vector3.new(piece.Vertices[i],piece.Vertices[i+1],piece.Vertices[i+2])+offset-center)
      count+=1
      if count%750==0 then task.wait() end
     end
     for i=1,#piece.Faces,4 do
      local index=piece.Faces[i+3]
      if not colorIds[index] then
       local color=index==0 and paint or index==-1 and Color3.fromRGB(165,216,240) or Color3.fromHex(palette[index])
       colorIds[index]=mesh:AddColor(color,index==-1 and 0.4 or 1)
      end
      local face=mesh:AddTriangle(vertices[piece.Faces[i]],vertices[piece.Faces[i+1]],vertices[piece.Faces[i+2]])
      local colorId=colorIds[index]
      mesh:SetFaceColors(face,{colorId,colorId,colorId})
     end
  end
  local part=AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
  table.insert(created,part)
  part.Name="ExactVehicle";part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
  part.Material=Enum.Material.SmoothPlastic;part.Color=Color3.new(1,1,1)
  return {Part=part,Mesh=mesh,Size=high-low}
 end)
 loading[key]=nil
 if not ok or startedAt~=generation then
  for _,object in ipairs(created) do object:Destroy() end
  if not ok then warn("Paintable vehicle preview: "..tostring(result)) end
  return nil
 end
 templates[key]=result
 return result
end
local colors={
 Car_Red=Color3.fromRGB(217,68,58),Car_Blue=Color3.fromRGB(58,123,217),
 Truck_Orange=Color3.fromRGB(242,122,33),Truck_Blue=Color3.fromRGB(65,117,205),
 Motorbike_Blue=Color3.fromRGB(46,118,217),Motorbike_Lime=Color3.fromRGB(148,211,49),
 Sports_Red=Color3.fromRGB(224,61,55),Sports_Yellow=Color3.fromRGB(242,192,45),
}

function Preview.Attach(parent,name,paintColor)
 local viewport=Instance.new("ViewportFrame")
 viewport.Name="VehicleViewport";viewport.Size=UDim2.fromScale(1,1)
 viewport.BackgroundTransparency=1
 viewport.Ambient=Color3.fromRGB(200,200,200)
 viewport.LightColor=Color3.fromRGB(255,249,231)
 viewport.LightDirection=Vector3.new(-1,-1,-1)
 viewport.Parent=parent
 local world=Instance.new("WorldModel");world.Parent=viewport
 local camera=Instance.new("Camera");camera.Parent=viewport;viewport.CurrentCamera=camera
 local truck=name:find("Truck",1,true)~=nil
 local bike=name:find("Motorbike",1,true)~=nil
 local sports=name:find("Sports",1,true)~=nil
 local paint=paintColor or colors[name] or Color3.fromRGB(240,190,50)
 local glass=Color3.fromRGB(53,79,103)
 local dark=Color3.fromRGB(36,38,44)
 local function part(label,size,position,color,shape)
  local object=Instance.new("Part")
  object.Name=label;object.Size=size;object.Position=position;object.Color=color
  object.Material=Enum.Material.SmoothPlastic
  if shape then object.Shape=shape end
  object.Anchored=true;object.CanCollide=false;object.Parent=world
  return object
 end
 if bike then
  part("Frame",Vector3.new(.7,.7,4.3),Vector3.new(0,.1,0),paint)
  part("Tank",Vector3.new(1.15,1,1.5),Vector3.new(0,.65,.8),paint)
  part("Seat",Vector3.new(1.1,.3,1.6),Vector3.new(0,.73,-.85),dark)
  part("Fork",Vector3.new(.3,1.5,.3),Vector3.new(0,-.1,2),Color3.fromRGB(190,193,197))
  part("Handlebar",Vector3.new(2,.2,.2),Vector3.new(0,.85,1.85),dark)
  for _,z in ipairs({-2.1,2.1}) do
   part("Wheel",Vector3.new(.4,1.55,1.55),Vector3.new(0,-.7,z),dark,Enum.PartType.Cylinder)
   part("Hub",Vector3.new(.42,.55,.55),Vector3.new(0,-.7,z),Color3.fromRGB(207,211,217),Enum.PartType.Cylinder)
  end
 elseif sports then
  part("LowBody",Vector3.new(5.6,1,10.2),Vector3.new(0,-.15,0),paint)
  part("Cockpit",Vector3.new(4.35,1.35,4.3),Vector3.new(0,.75,.5),paint)
  part("Windshield",Vector3.new(4.2,.9,.12),Vector3.new(0,1,2.72),glass)
  part("RearWing",Vector3.new(5.7,.2,.65),Vector3.new(0,1.05,-4.25),dark)
  part("Hood",Vector3.new(5.3,.15,3.1),Vector3.new(0,.43,3.15),paint:Lerp(Color3.new(1,1,1),.1))
 elseif truck then
  part("TruckBed",Vector3.new(5.6,1.5,7.2),Vector3.new(0,.2,-2.2),paint)
  part("Cab",Vector3.new(5.4,3.4,4.4),Vector3.new(0,1.3,3.1),paint)
  part("Windshield",Vector3.new(5.08,1.6,.12),Vector3.new(0,1.9,5.34),glass)
  for _,x in ipairs({-2.75,2.75}) do part("SideWindow",Vector3.new(.12,1.4,2.3),Vector3.new(x,1.9,3.5),glass) end
  part("CargoTop",Vector3.new(5.2,.18,7),Vector3.new(0,1.04,-2.2),paint:Lerp(Color3.new(1,1,1),.12))
 else
  part("Body",Vector3.new(5.2,1.35,10),Vector3.new(0,0,0),paint)
  part("Cabin",Vector3.new(4.7,1.8,5),Vector3.new(0,1.55,.6),paint)
  part("Windshield",Vector3.new(4.55,1.3,.12),Vector3.new(0,1.55,3.18),glass)
  for _,x in ipairs({-2.4,2.4}) do part("SideWindow",Vector3.new(.12,1.25,3.1),Vector3.new(x,1.6,.6),glass) end
  part("Hood",Vector3.new(5,.18,2.3),Vector3.new(0,.79,3.7),paint:Lerp(Color3.new(1,1,1),.1))
 end
 if not bike then for _,x in ipairs({-(truck and 3 or 2.8),truck and 3 or 2.8}) do
  for _,z in ipairs(truck and {-4.4,3.7} or {-3.2,3.2}) do
   part("Wheel",Vector3.new(.8,1.75,1.75),Vector3.new(x,-.88,z),dark,Enum.PartType.Cylinder)
   part("Hub",Vector3.new(.84,.82,.82),Vector3.new(x,-.88,z),Color3.fromRGB(207,211,217),Enum.PartType.Cylinder)
  end
 end end
 if not bike then for _,x in ipairs({-1.7,1.7}) do
  part("Headlight",Vector3.new(.72,.38,.13),Vector3.new(x,.1,truck and 5.36 or 5.08),Color3.fromRGB(255,247,192))
 end end
 local position=bike and Vector3.new(7,5,10) or (truck and Vector3.new(13,9,19) or Vector3.new(11,7,16))
 viewport:SetAttribute("OrbitRadius",Vector3.new(position.X,0,position.Z).Magnitude)
 viewport:SetAttribute("OrbitHeight",position.Y)
 viewport:SetAttribute("OrbitYaw",math.atan2(position.X,position.Z))
 camera.CFrame=CFrame.lookAt(position,Vector3.new(0,.3,0))
 camera.FieldOfView=35
 active[viewport]={Name=paintableName(name),Paint=paint,Busy=false}
 viewport.Destroying:Connect(function() active[viewport]=nil end)
 Preview.Render(viewport)
 return viewport
end

local function visibleOnScreen(viewport)
 local item=viewport
 while item do
  if item:IsA("GuiObject") and not item.Visible then return false end
  item=item.Parent
 end
 return true
end

function Preview.Render(viewport)
 local entry=active[viewport]
 if not entry or entry.Busy or not viewport.Parent then return end
 entry.Busy=true
 task.spawn(function()
  local startedAt=generation
  while viewport.Parent and not visibleOnScreen(viewport) do task.wait(0.1) end
  if not viewport.Parent then entry.Busy=false;return end
  local exact=makeExactTemplate(entry.Name,entry.Paint)
  if not exact or not viewport.Parent or not visibleOnScreen(viewport) then
   entry.Busy=false
   if generation~=startedAt and viewport.Parent and visibleOnScreen(viewport) then task.defer(Preview.Render,viewport) end
   return
  end
  local world=viewport:FindFirstChildOfClass("WorldModel")
  local camera=viewport.CurrentCamera
  if not world or not camera then entry.Busy=false;return end
  local prior=world:FindFirstChild("ExactVehicle")
  if prior then prior:Destroy() end
  exact.Part:Clone().Parent=world
  for _,child in ipairs(world:GetChildren()) do
   if child:IsA("BasePart") and child.Name~="ExactVehicle" then child.Transparency=1 end
  end
  local radius=math.max(exact.Size.Z*1.9,exact.Size.X*2.5,12)
  local height=math.max(exact.Size.Y*1.4,4)
  local yaw=viewport:GetAttribute("OrbitYaw") or 0.6
  viewport:SetAttribute("OrbitRadius",radius)
  viewport:SetAttribute("OrbitHeight",height)
  camera.CFrame=CFrame.lookAt(Vector3.new(math.sin(yaw)*radius,height,math.cos(yaw)*radius),Vector3.zero)
  entry.Busy=false
 end)
end

function Preview.RefreshAll()
 for viewport in pairs(active) do
  if viewport.Parent and visibleOnScreen(viewport) and not viewport:FindFirstChildOfClass("WorldModel"):FindFirstChild("ExactVehicle") then
   Preview.Render(viewport)
  end
 end
end

function Preview.ReleaseAll()
 generation+=1
 for viewport in pairs(active) do
  local world=viewport.Parent and viewport:FindFirstChildOfClass("WorldModel")
  if world then
   local exact=world:FindFirstChild("ExactVehicle")
   if exact then exact:Destroy() end
   for _,child in ipairs(world:GetChildren()) do
    if child:IsA("BasePart") and child.Name~="GarageTrail" then child.Transparency=0 end
   end
  end
 end
 for key,template in pairs(templates) do
  template.Part:Destroy();template.Mesh:Destroy()
  templates[key]=nil
 end
end

function Preview.Rotate(viewport,delta)
 local camera=viewport and viewport.CurrentCamera
 if not camera then return end
 local yaw=(viewport:GetAttribute("OrbitYaw") or 0)+delta
 local radius=viewport:GetAttribute("OrbitRadius") or 18
 local height=viewport:GetAttribute("OrbitHeight") or 8
 viewport:SetAttribute("OrbitYaw",yaw)
 camera.CFrame=CFrame.lookAt(Vector3.new(math.sin(yaw)*radius,height,math.cos(yaw)*radius),Vector3.new(0,.3,0))
end

function Preview.SetTrail(viewport,enabled,color)
 local world=viewport and viewport:FindFirstChildOfClass("WorldModel")
 if not world then return end
 for _,child in ipairs(world:GetChildren()) do if child.Name=="GarageTrail" then child:Destroy() end end
 if not enabled then return end
 for _,x in ipairs({-0.8,0.8}) do
  local streak=Instance.new("Part")
  streak.Name="GarageTrail";streak.Size=Vector3.new(0.18,0.18,4)
  streak.Position=Vector3.new(x,-0.7,-5.4)
  streak.Material=Enum.Material.Neon;streak.Color=color
  streak.Transparency=world:FindFirstChild("ExactVehicle") and 0 or 1
  streak.Anchored=true;streak.CanCollide=false;streak.Parent=world
 end
end


return Preview
