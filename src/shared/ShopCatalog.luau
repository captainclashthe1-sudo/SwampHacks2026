-- Purchases are cosmetic: vehicle choice never changes the level's load rules.
local Catalog={
 {Id="VehicleCar",Name="Classic Car",Kind="Vehicle",Price=0,Mesh="Car_Yellow",Color=Color3.fromRGB(242,192,45),Description="Your starter ride. Always available."},
 {Id="VehicleTruck",Name="Hauler",Kind="Vehicle",Price=850,Mesh="Truck_Orange",Color=Color3.fromRGB(242,122,33),Description="A sturdy look for heavy crossings."},
 {Id="VehicleMotorbike",Name="Motorbike",Kind="Vehicle",Price=550,Mesh="Motorbike_Blue",Color=Color3.fromRGB(46,118,217),Description="A slim ride for daring builders."},
 {Id="VehicleSports",Name="Sports Car",Kind="Vehicle",Price=1250,Mesh="Sports_Red",Color=Color3.fromRGB(224,61,55),Description="Low, sleek, and ready for the finish."},
 {Id="PaintRed",Name="Crimson Paint",Kind="Paint",Price=175,Color=Color3.fromRGB(224,61,55),Description="Paint any vehicle's body crimson."},
 {Id="PaintBlue",Name="Ocean Paint",Kind="Paint",Price=175,Color=Color3.fromRGB(46,118,217),Description="Paint any vehicle's body ocean blue."},
 {Id="PaintLime",Name="Lime Paint",Kind="Paint",Price=200,Color=Color3.fromRGB(148,211,49),Description="Paint any vehicle's body lime green."},
 {Id="PaintYellow",Name="Sunburst Paint",Kind="Paint",Price=200,Color=Color3.fromRGB(242,192,45),Description="Paint any vehicle's body sunny yellow."},
 {Id="PaintOrange",Name="Worksite Paint",Kind="Paint",Price=175,Color=Color3.fromRGB(242,122,33),Description="Paint any vehicle's body worksite orange."},
 {Id="BlueTrail",Name="River Trail",Kind="Trail",Price=400,Color=Color3.fromRGB(47,168,240),Icon="rbxthumb://type=Asset&id=6829693244&w=150&h=150",Description="A blue trail behind your test vehicle."},
 {Id="HardHat",Name="Builder Hard Hat",Kind="Cosmetic",Price=250,Color=Color3.fromRGB(247,198,40),Icon="rbxthumb://type=Asset&id=14999566699&w=150&h=150",Description="Wear a bright construction helmet."},
 {Id="Sparkles",Name="Victory Sparkles",Kind="Cosmetic",Price=600,Color=Color3.fromRGB(247,198,40),Icon="rbxthumb://type=Asset&id=132299390247149&w=150&h=150",Description="Add glowing sparkles to your character."},
}
local meshes={}
for vehicle,base in pairs({VehicleCar="Car_Yellow",VehicleTruck="Truck_Orange",VehicleMotorbike="Motorbike_Blue",VehicleSports="Sports_Red"}) do
 meshes[vehicle]={}
 for _,paint in ipairs({"PaintRed","PaintBlue","PaintLime","PaintYellow","PaintOrange"}) do meshes[vehicle][paint]=base end
end
local defaults={VehicleCar="PaintYellow",VehicleTruck="PaintOrange",VehicleMotorbike="PaintBlue",VehicleSports="PaintRed"}
local byId={}
for _,item in ipairs(Catalog) do byId[item.Id]=item end
return {Items=Catalog,ById=byId,Meshes=meshes,DefaultPaint=defaults}
