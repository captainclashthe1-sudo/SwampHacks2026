local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog=require(ReplicatedStorage.Shared.ShopCatalog)
local Shop={}
local states={}

local function stateFor(player)
 local state=states[player.UserId]
 if state then return state end
 state={Tokens=0,Owned={VehicleCar=true},Vehicle="VehicleCar",Paint="PaintYellow",Trail=nil,Cosmetic=nil}
 states[player.UserId]=state
 return state
end

local function sync(player,state)
 player:SetAttribute("Tokens",state.Tokens)
 local paints=Catalog.Meshes[state.Vehicle] or Catalog.Meshes.VehicleCar
 local paint=paints[state.Paint] and state.Paint or Catalog.DefaultPaint[state.Vehicle]
 player:SetAttribute("EquippedVehicle",state.Vehicle=="VehicleCar" and nil or paints[paint])
 player:SetAttribute("EquippedPaint",paint)
 player:SetAttribute("EquippedTrail",state.Trail)
 player:SetAttribute("EquippedCosmetic",state.Cosmetic)
end

function Shop.ApplyCosmetic(player)
 local character=player.Character
 if not character then return end
 local old=character:FindFirstChild("ShopCosmetic")
 if old then old:Destroy() end
 local choice=stateFor(player).Cosmetic
 if not choice then return end
 local folder=Instance.new("Folder")
 folder.Name="ShopCosmetic";folder.Parent=character
 if choice=="HardHat" then
  local head=character:FindFirstChild("Head")
  if not head then return end
  for _,spec in ipairs({{"Crown",Vector3.new(2.1,.62,2.1),.77},{"Brim",Vector3.new(2.7,.12,2.7),.48}}) do
   local part=Instance.new("Part")
   part.Name=spec[1];part.Size=spec[2]
   part.Material=Enum.Material.SmoothPlastic;part.Color=Catalog.ById.HardHat.Color
   part.CFrame=head.CFrame*CFrame.new(0,spec[3],0)
   part.CanCollide=false;part.CanTouch=false;part.Massless=true;part.Parent=folder
   local weld=Instance.new("WeldConstraint");weld.Part0=head;weld.Part1=part;weld.Parent=part
  end
 elseif choice=="Sparkles" then
  local root=character:FindFirstChild("HumanoidRootPart")
  if not root then return end
  local effect=Instance.new("Sparkles");effect.SparkleColor=Catalog.ById.Sparkles.Color;effect.Parent=root
  folder.Destroying:Connect(function() effect:Destroy() end)
 end
end

function Shop.Load(player,data)
 local state=stateFor(player)
 local legacy={CarRed={"VehicleCar","PaintRed"},CarBlue={"VehicleCar","PaintBlue"},
  TruckOrange={"VehicleTruck","PaintOrange"},TruckBlue={"VehicleTruck","PaintBlue"},
  MotorbikeBlue={"VehicleMotorbike","PaintBlue"},MotorbikeLime={"VehicleMotorbike","PaintLime"},
  SportsRed={"VehicleSports","PaintRed"},SportsYellow={"VehicleSports","PaintYellow"}}
 if type(data)=="table" then
  local tokens=data.Tokens
  if type(tokens)=="number" and tokens==tokens and tokens>=0 and tokens<=10000000 then state.Tokens=math.floor(tokens) end
  if type(data.Owned)=="table" then
   for id,owned in pairs(data.Owned) do if owned==true then
    if Catalog.ById[id] then state.Owned[id]=true end
    if legacy[id] then for _,replacement in ipairs(legacy[id]) do state.Owned[replacement]=true end end
   end end
  end
  local vehicle=legacy[data.Vehicle] and legacy[data.Vehicle][1] or data.Vehicle
  if type(vehicle)=="string" and state.Owned[vehicle] and Catalog.ById[vehicle] and Catalog.ById[vehicle].Kind=="Vehicle" then state.Vehicle=vehicle end
  local paint=legacy[data.Vehicle] and legacy[data.Vehicle][2] or data.Paint
  if type(paint)=="string" and Catalog.Meshes[state.Vehicle][paint] and (state.Owned[paint] or Catalog.DefaultPaint[state.Vehicle]==paint) then state.Paint=paint
  else state.Paint=Catalog.DefaultPaint[state.Vehicle] end
  if data.Trail=="BlueTrail" and state.Owned.BlueTrail then state.Trail="BlueTrail" end
  if data.Cosmetic=="BlueTrail" and state.Owned.BlueTrail then state.Trail="BlueTrail" end
  if type(data.Cosmetic)=="string" and state.Owned[data.Cosmetic] and Catalog.ById[data.Cosmetic].Kind=="Cosmetic" then state.Cosmetic=data.Cosmetic end
 end
 sync(player,state)
 Shop.ApplyCosmetic(player)
end

function Shop.Export(player)
 local state=stateFor(player)
 local owned={}
 for id,value in pairs(state.Owned) do if value then owned[id]=true end end
 return {Tokens=state.Tokens,Owned=owned,Vehicle=state.Vehicle,Paint=state.Paint,Trail=state.Trail,Cosmetic=state.Cosmetic}
end

function Shop.Snapshot(player)
 local state=stateFor(player)
 return {ok=true,Tokens=state.Tokens,Owned=Shop.Export(player).Owned,Vehicle=state.Vehicle,Paint=state.Paint,Trail=state.Trail,Cosmetic=state.Cosmetic}
end

function Shop.Award(player,amount)
 if type(amount)~="number" or amount<0 then return end
 local state=stateFor(player)
 state.Tokens+=math.floor(amount)
 sync(player,state)
end

function Shop.Purchase(player,id)
 local item=Catalog.ById[id]
 if not item then return {ok=false,message="That item is not in the shop."} end
 local state=stateFor(player)
 if state.Owned[id] then return {ok=false,message="You already own this item."} end
 if state.Tokens<item.Price then return {ok=false,message="You need "..(item.Price-state.Tokens).." more tokens."} end
 state.Tokens-=item.Price;state.Owned[id]=true
 sync(player,state)
 return {ok=true,message=item.Name.." purchased!",State=Shop.Snapshot(player)}
end

function Shop.Equip(player,id)
 local state=stateFor(player)
 if id=="DefaultVehicle" then state.Vehicle="VehicleCar";state.Paint=Catalog.DefaultPaint.VehicleCar
 elseif id=="NoCosmetic" then state.Cosmetic=nil
 elseif id=="NoTrail" then state.Trail=nil
 else
  local item=Catalog.ById[id]
  if not item then return {ok=false,message="Unknown garage item."} end
  if not state.Owned[id] and not (item.Kind=="Paint" and Catalog.DefaultPaint[state.Vehicle]==id) then return {ok=false,message="Buy this item before equipping it."} end
  if item.Kind=="Vehicle" then
   state.Vehicle=id
   if not Catalog.Meshes[id][state.Paint] or (not state.Owned[state.Paint] and Catalog.DefaultPaint[id]~=state.Paint) then state.Paint=Catalog.DefaultPaint[id] end
  elseif item.Kind=="Paint" then
   if not Catalog.Meshes[state.Vehicle][id] then return {ok=false,message="That paint is not available for this vehicle."} end
   state.Paint=id
  elseif item.Kind=="Trail" then state.Trail=id
  else state.Cosmetic=id end
 end
 sync(player,state)
 Shop.ApplyCosmetic(player)
 return {ok=true,message="Garage updated. Vehicle changes appear on the next car spawn.",State=Shop.Snapshot(player)}
end

function Shop.Remove(player)
 states[player.UserId]=nil
end

return Shop
