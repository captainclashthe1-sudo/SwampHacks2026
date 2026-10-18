local Assets=require(script.Parent.LowpolyAssets)
-- Level maps adapted from the Pack 5 bay-crossing map (tools/build_level_maps.py, Shared.LevelMaps).
local Maps=require(game:GetService("ReplicatedStorage").Shared.LevelMaps)
local Scene={}
local BOX_BOTTOM=Maps.BoxBottom
local TERRAIN_STYLE={
 turf={Color3.fromRGB(95,174,78),Enum.Material.Grass},
 sand={Color3.fromRGB(226,206,147),Enum.Material.Sand},
 cliff={Color3.fromRGB(142,129,116),Enum.Material.Slate},
 seabed={Color3.fromRGB(201,183,132),Enum.Material.Sand},
}
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
  -- Client-rendered building geometry has no authoritative collision. A
  -- simple invisible footprint keeps players outside even while it streams in.
  if name:match("^House_") or name:match("^Shop_") or name=="Gas_Station" or name=="Lighthouse"
   or name=="Apartment_Block" or name=="Office_Tower" then
   local cf,size=model:GetBoundingBox()
   local wall=Instance.new("Part")
   wall.Name="BuildingCollision"
   wall.Size=Vector3.new(math.max(2,size.X*.84),math.max(5,size.Y*.85),math.max(2,size.Z*.84))
   wall.CFrame=cf
   wall.Transparency=1;wall.Anchored=true;wall.CanCollide=true;wall.CanQuery=false;wall.CanTouch=false
   wall.Parent=model
  end
  return model
 end
 local gap=config.Road.Gap/2
 local map=config.Id and Maps.Get(config.Id)
 if map then
  -- One water surface for the whole map; the river widens away from the crossing.
  local river=level:FindFirstChild("RiverVisual")
  if river then
   river.Size=Vector3.new(1040,river.Size.Y,650)
   river.Position=Vector3.new(origin.X,river.Position.Y,origin.Z)
  end
  -- Terrain: the client draws Maps.TerrainPiece(id). These blocks are its collision
  -- inside the play area, and a coarse stand-in everywhere until the client mesh is ready.
  local terrain=Instance.new("Model"); terrain.Name="MapTerrain_L"..config.Id
  local pivot=Instance.new("Part"); pivot.Name="ModelPivot"; pivot.Size=Vector3.new(.1,.1,.1); pivot.Transparency=1
  pivot.Anchored=true; pivot.CanCollide=false; pivot.CanTouch=false; pivot.CanQuery=false
  pivot.Position=origin; pivot.Parent=terrain; terrain.PrimaryPart=pivot
  for _,b in ipairs(Maps.Boxes(config.Id)) do
   local style=TERRAIN_STYLE[b[6]] or TERRAIN_STYLE.turf
   local p=Instance.new("Part"); p.Name=b[7] and "TerrainCollision" or "TerrainFallback"; p.Anchored=true
   p.Size=Vector3.new(b[2]-b[1],b[5]-BOX_BOTTOM,b[4]-b[3])
   p.Position=origin+Vector3.new((b[1]+b[2])/2,(b[5]+BOX_BOTTOM)/2,(b[3]+b[4])/2)
   p.Color=style[1]; p.Material=style[2]; p.CastShadow=false
   p.CanCollide=b[7]; p.CanQuery=b[7]; p.CanTouch=false; p.Parent=terrain
  end
  terrain.Parent=scenery
  for i,item in ipairs(map.Props) do
   prop(item[1],item[2],item[3],item[4],math.rad(item[5]),item[6])
   if i%40==0 then task.wait() end
  end
 else
  -- Levels without a generated map keep the original block landscape.
  local grass=(config.Theme=="coast" or config.Theme=="harbor") and Color3.fromRGB(176,173,117) or Color3.fromRGB(84,153,82)
  if config.Theme=="city" then grass=Color3.fromRGB(131,150,122) end
  part("RiverBed",Vector3.new(0,-19,0),Vector3.new(config.Road.Gap,4,208),Color3.fromRGB(98,108,104),Enum.Material.Slate,true)
  for _,side in ipairs({-1,1}) do
   local width=200-gap
   part("Mainland",Vector3.new(side*(gap+width/2),-7.5,0),Vector3.new(width,21,208),Color3.fromRGB(109,103,87),Enum.Material.Slate,true)
   part("GroundSurface",Vector3.new(side*(gap+width/2),3.3,0),Vector3.new(width,.7,208),grass,Enum.Material.Grass,true)
   for n=0,3 do prop("Road_Straight",side*(gap+16+n*32),3.328,0,math.pi/2,.8) end
  end
 end
 if config.Theme=="forest" then
  local island=prop("Island_Palm",0,-10,0,0,.19)
  island:SetAttribute("HeightScale",2)
  local pivot=island:GetPivot()
  for _,p in ipairs(island:GetDescendants()) do if p:IsA("BasePart") then
   local localPos=pivot:PointToObjectSpace(p.Position)
   p.Size=Vector3.new(p.Size.X,p.Size.Y*2,p.Size.Z)
   p.Position=pivot:PointToWorldSpace(Vector3.new(localPos.X,localPos.Y*2,localPos.Z))
  end end
 elseif config.Theme=="city" then
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
