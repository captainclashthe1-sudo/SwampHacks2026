local Assets=require(script.Parent.LowpolyAssets)
local Scene={}
function Scene.Place(level,layout,config)
 local scenery=Instance.new("Folder"); scenery.Name="LowpolyScenery"; scenery.Parent=level
 local origin=config.Origin
 local function part(name,pos,size,color,material,collide)
  local p=Instance.new("Part"); p.Name=name; p.Anchored=true
  p.Position=origin+pos; p.Size=size; p.Color=color; p.Material=material or Enum.Material.SmoothPlastic
  p.CanCollide=collide==true; p.CanTouch=false; p.CanQuery=collide==true; p.Parent=scenery
  return p
 end
 local function prop(name,x,y,z,yaw,scale)
  local model=Assets.Clone(name)
  if scale then model:ScaleTo(scale) end
  model:PivotTo(CFrame.new(origin+Vector3.new(x,y,z))*CFrame.Angles(0,yaw or 0,0)); model.Parent=scenery
  return model
 end
 local grass=(config.Theme=="coast" or config.Theme=="harbor") and Color3.fromRGB(176,173,117) or Color3.fromRGB(84,153,82)
 if config.Theme=="city" then grass=Color3.fromRGB(131,150,122) end
 local gap=config.Road.Gap/2
 part("RiverBed",Vector3.new(0,-19,0),Vector3.new(config.Road.Gap,4,208),Color3.fromRGB(98,108,104),Enum.Material.Slate,true)
 for _,side in ipairs({-1,1}) do
  local width=200-gap
  part("Mainland",Vector3.new(side*(gap+width/2),-7.5,0),Vector3.new(width,21,208),Color3.fromRGB(109,103,87),Enum.Material.Slate,true)
  part("GroundSurface",Vector3.new(side*(gap+width/2),3.3,0),Vector3.new(width,.7,208),grass,Enum.Material.Grass,true)
  for n=0,3 do prop("Road_Straight",side*(gap+16+n*32),3.328,0,math.pi/2,.8) end
  for _,z in ipairs({-12,12}) do prop("Road_Barrier",side*(gap+124),4,z,math.pi/2,.8) end
  prop("Street_Lamp",side*(gap+24),4,side*20,side<0 and 0 or math.pi,.8)
  prop("Traffic_Cone",side*(gap+3),4,side*11,0,.9)
  prop("Park_Bench",side*(gap+60),4,-side*26,side*math.pi/2)
  for i=1,4 do
   local x=side*(gap+18+i*27)
   prop(config.Theme=="forest" and "Tree_Pine" or "Tree_Round",x,3.65,70+(i%2)*10,0,1+(i%2)*.2)
   prop("Tree_Pine",x,3.65,-78+(i%2)*9,0,1.2)
  end
 end
 for _,side in ipairs({-1,1}) do
  for x=-190,190,42 do
   local hill=part("HorizonRidge",Vector3.new(x,7,side*124),Vector3.new(65,55,55),grass,Enum.Material.Grass)
   hill.Shape=Enum.PartType.Ball
  end
  for z=-80,80,40 do
   local hill=part("EndRidge",Vector3.new(side*218,5,z),Vector3.new(55,58,65),grass,Enum.Material.Grass)
   hill.Shape=Enum.PartType.Ball
  end
 end
 prop("Car_Red",-gap-76,4,-7,math.pi/2,.75)
 prop("Car_Blue",gap+90,4,27,-math.pi/2,.75)
 if config.Theme=="village" then
  prop("House_Cottage",-gap-55,4,43,math.pi,.8)
  prop("House_TwoStory",gap+65,4,-45,0,.7)
  prop("Shop_Corner",-gap-110,4,-45,0,.65)
  prop("Picket_Fence",-gap-40,4,27,0)
  prop("Bush",gap+35,4,35,0,1.3)
 elseif config.Theme=="forest" then
  prop("House_Cottage",-gap-90,4,-40,0,.8)
  prop("Wooden_Dock",gap+10,-6,37,-math.pi/2,.6)
  for i=1,4 do
   if i==1 then
    local island=prop("Island_Palm",0,-10,0,0,.19)
    island:SetAttribute("HeightScale",2)
    local pivot=island:GetPivot()
    for _,p in ipairs(island:GetDescendants()) do if p:IsA("BasePart") then
     local localPos=pivot:PointToObjectSpace(p.Position)
     p.Size=Vector3.new(p.Size.X,p.Size.Y*2,p.Size.Z)
     p.Position=pivot:PointToWorldSpace(Vector3.new(localPos.X,localPos.Y*2,localPos.Z))
    end end
   end
   prop("Tree_Pine",-gap-20-i*22,4,-28-i*5,0,1.5)
  end
 elseif config.Theme=="city" then
  for _,spec in ipairs({{"Apartment_Block",-gap-55,44,.75},{"Shop_Corner",-gap-110,-42,.8},{"Office_Tower",gap+65,45,.65},{"House_TwoStory",gap+115,-45,.8}}) do
   prop(spec[1],spec[2],4,spec[3],spec[3]>0 and math.pi or 0,spec[4])
  end
  prop("Fire_Hydrant",-gap-25,4,-21,0)
  local boat=prop("Boat_Speedboat",0,-11,-70,0,.8)
  boat:SetAttribute("DynamicMesh","Boat_Speedboat")
  local hull=part("MovingBoatHitbox",Vector3.new(0,-1,-70),Vector3.new(14,20,18),Color3.new(1,1,1),nil,true)
  hull.Transparency=1
  local mast=part("BoatClearanceMast",Vector3.new(0,-1,-70),Vector3.new(.35,20,.35),Color3.fromRGB(230,230,220))
  local flag=part("BoatClearanceFlag",Vector3.new(1.5,8,-70),Vector3.new(3,2,.12),Color3.fromRGB(235,150,40))
  local elapsed=0; local connection
  connection=game:GetService("RunService").Heartbeat:Connect(function(dt)
   if not level.Parent then connection:Disconnect(); return end
   elapsed+=dt; local started=scenery:GetAttribute("BoatCycleStart")
   local t=started and os.clock()-started or elapsed
   local z=-48+(t*20)%160
   boat:PivotTo(CFrame.new(origin+Vector3.new(0,-11,z)))
   hull.Position=origin+Vector3.new(0,-1,z); mast.Position=hull.Position; flag.Position=origin+Vector3.new(1.5,8,z)
  end)
 elseif config.Theme=="coast" then
  prop("Lighthouse",gap+45,4,48,0,.8)
  prop("Gas_Station",-gap-70,4,-49,0,.6)
  prop("Wooden_Dock",gap+8,-8,-35,-math.pi/2,.8)
  local plane=prop("Plane_Prop",0,48,-95,0,.65)
  plane:SetAttribute("DynamicMesh","Plane_Prop")
  plane:SetAttribute("PlaneFlying",true)
  local elapsed=0; local connection
  connection=game:GetService("RunService").Heartbeat:Connect(function(dt)
   if not level.Parent then connection:Disconnect(); return end
   elapsed=(elapsed+dt)%24
   local z,y,pitch
   if elapsed<7 then local t=elapsed/7; z=-95+70*t; y=48-28*t; pitch=.12
   elseif elapsed<13 then local t=(elapsed-7)/6; z=-25+48*(1-(1-t)^2); y=20; pitch=0
   elseif elapsed<17 then z=23;y=20;pitch=0
   else local t=(elapsed-17)/7; z=23+120*t; y=20+45*t*t; pitch=-.18 end
   plane:SetAttribute("PlaneFlying",elapsed<13 or elapsed>=17)
   plane:PivotTo(CFrame.new(origin+Vector3.new(0,y,z))*CFrame.Angles(pitch,0,0))
  end)
  for _,z in ipairs({-30,-10,10,30}) do prop("Bridge_Deck",0,20,z,0,.5) end
  prop("Bridge_Tower",0,-5,-34,0,.5)
  part("OverpassDeck",Vector3.new(0,19,0),Vector3.new(21,2,74),Color3.fromRGB(113,125,143),Enum.Material.Concrete,true)
  for _,z in ipairs({-34,34}) do part("OverpassPillar",Vector3.new(0,3,z),Vector3.new(8,30,4),Color3.fromRGB(123,134,143),Enum.Material.Concrete,true) end
 elseif config.Theme=="harbor" then
  prop("Lighthouse",gap+55,4,-55,0,.9)
  prop("Office_Tower",-gap-100,4,50,math.pi,.65)
  prop("Apartment_Block",-gap-48,4,-48,0,.7)
  prop("Shop_Corner",gap+105,4,45,math.pi,.85)
  prop("Wooden_Dock",gap+8,-10,34,-math.pi/2,.85)
  local tug=prop("Tugboat",0,-9,-35,0,.55)
  tug:SetAttribute("DynamicMesh","Tugboat")
  local speedboatA=prop("Boat_Speedboat",-23,-10,-90,0,.45)
  local speedboatB=prop("Boat_Speedboat",23,-10,90,math.pi,.4)
  speedboatA:SetAttribute("DynamicMesh","Boat_Speedboat")
  speedboatB:SetAttribute("DynamicMesh","Boat_Speedboat")
  prop("Plane_Prop",85,44,70,-math.pi/4,.8)
  local hull=part("BoatObstacle",Vector3.new(0,-6,-35),Vector3.new(11,10,26),Color3.fromRGB(255,191,60),Enum.Material.Metal,true)
  hull.Transparency=1
  local elapsed=0; local connection
  connection=game:GetService("RunService").Heartbeat:Connect(function(dt)
   if not level.Parent then connection:Disconnect(); return end
   elapsed+=dt
   local started=scenery:GetAttribute("BoatCycleStart")
   -- The tug reaches the bridge about 1.5 seconds after a test begins.
   local tugZ=-35+(started and math.clamp((os.clock()-started)*24,0,160) or 0)
   tug:PivotTo(CFrame.new(origin+Vector3.new(0,-9,tugZ)))
   hull.Position=origin+Vector3.new(0,-6,tugZ)
   speedboatA:PivotTo(CFrame.new(origin+Vector3.new(-23,-10,-90+(elapsed*18)%180)))
   speedboatB:PivotTo(CFrame.new(origin+Vector3.new(23,-10,90-(elapsed*15)%180))*CFrame.Angles(0,math.pi,0))
  end)
 end
 if config.Obstacle or config.Jump then
  local o=config.Obstacle or {Min=Vector3.new(-13.5,-10,-12),Max=Vector3.new(13.5,28,12),Label="BOAT LANE / JUMP GAP"}
  local boundary=part("KeepClear",(o.Min+o.Max)/2,o.Max-o.Min,Color3.fromRGB(255,159,61),Enum.Material.ForceField)
  boundary.Transparency=.92
  local box=Instance.new("SelectionBox"); box.Adornee=boundary; box.LineThickness=.06; box.Color3=Color3.fromRGB(255,185,78); box.SurfaceTransparency=1; box.Parent=boundary
  local bill=Instance.new("BillboardGui"); bill.Size=UDim2.fromOffset(250,35); bill.StudsOffset=Vector3.new(0,boundary.Size.Y/2+2,0); bill.MaxDistance=180; bill.Parent=boundary
  local text=Instance.new("TextLabel"); text.Size=UDim2.fromScale(1,1); text.BackgroundColor3=Color3.fromRGB(60,46,33); text.BackgroundTransparency=.15; text.TextColor3=Color3.fromRGB(255,209,115); text.Text=o.Label; text.Font=Enum.Font.FredokaOne; text.TextSize=14; text.Parent=bill
 end
 scenery:SetAttribute("Ready",true)
 return scenery
end
return Scene
