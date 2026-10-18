-- Client-visible representations of the supplied Blender pack.
-- EditableMesh content created on the server does not replicate to players.
local AssetService = game:GetService("AssetService")
local ServerStorage = game:GetService("ServerStorage")
local imported = require(script.Parent:WaitForChild("LowpolyAssetIds"))
local Assets = {}
local templates = Instance.new("Folder")
templates.Name = "BridgeLowpolyTemplates"
templates.Parent = ServerStorage
local loading = {}
local IMPORT_SCALE = 3.5

local C = {
	red = Color3.fromHex("#D9443A"), blue = Color3.fromHex("#3A7BD9"), yellow = Color3.fromHex("#F2B83A"),
	dark = Color3.fromHex("#2B2B30"), glass = Color3.fromHex("#2F4C6B"), white = Color3.fromHex("#F2F2EE"),
	green = Color3.fromHex("#45A84F"), pine = Color3.fromHex("#2F8A3C"), light = Color3.fromHex("#6CC05A"),
	brown = Color3.fromHex("#7A4E2D"), wood = Color3.fromHex("#C48A55"), gray = Color3.fromHex("#9AA0A7"),
	road = Color3.fromHex("#4A4D55"), orange = Color3.fromHex("#F27A21"), metal = Color3.fromHex("#BCC1C7"),
}
local function piece(m, n, s, p, color, shape, rotation)
	local x = Instance.new("Part")
	x.Name, x.Size, x.Color = n, s, color
	x.Shape = shape or Enum.PartType.Block
	x.CFrame = CFrame.new(p) * (rotation or CFrame.new())
	x.Material = Enum.Material.SmoothPlastic
	x.Anchored, x.CanCollide, x.CanTouch, x.CanQuery = true, false, false, false
	x.Parent = m
	return x
end
local function box(m,n,x,y,z,px,py,pz,c,r) return piece(m,n,Vector3.new(x,y,z),Vector3.new(px,py,pz),c,nil,r) end
local function ball(m,n,x,y,z,px,py,pz,c) return piece(m,n,Vector3.new(x,y,z),Vector3.new(px,py,pz),c,Enum.PartType.Ball) end
local function tube(m,n,d,l,px,py,pz,c,r) return piece(m,n,Vector3.new(d,l,d),Vector3.new(px,py,pz),c,Enum.PartType.Cylinder,r) end
local wheelAxis = CFrame.Angles(0,0,math.pi/2)

local function car(m,name)
	local paint = name == "Car_Red" and C.red or name == "Car_Blue" and C.blue or C.yellow
	box(m,name.."_Body",6.4,2.1,14.5,0,2,0,paint)
	box(m,"Hood",6.2,.45,4,0,3.2,-5,paint)
	box(m,"Trunk",6.2,.5,3,0,3.2,5.6,paint)
	box(m,"Cabin",5.6,2,6.6,0,3.9,.35,paint)
	box(m,"Roof",5.7,.38,6.3,0,5.05,.35,paint)
	box(m,"Windshield",5.05,1.65,.15,0,4.03,-3.01,C.glass)
	box(m,"RearWindow",5.05,1.65,.15,0,4.03,3.72,C.glass)
	for _,x in ipairs({-2.87,2.87}) do
		box(m,"SideWindow",.13,1.55,2.35,x,4.02,-1.2,C.glass)
		box(m,"SideWindow",.13,1.55,2.15,x,4.02,1.65,C.glass)
		for _,z in ipairs({-4.82,4.82}) do
			tube(m,"Wheel",2.45,.7,x,1.35,z,C.dark,wheelAxis)
			tube(m,"Hubcap",1.25,.76,x,1.35,z,C.white,wheelAxis)
		end
	end
	box(m,"FrontBumper",6.5,.45,.36,0,1.45,-7.48,C.gray)
	box(m,"RearBumper",6.5,.45,.36,0,1.45,7.48,C.gray)
	for _,x in ipairs({-2.25,2.25}) do
		box(m,"Headlight",.9,.55,.13,x,2.5,-7.34,C.white)
		box(m,"Taillight",.9,.55,.13,x,2.5,7.34,C.red)
	end
end
local function tree(m,round)
	tube(m,"Trunk",1.25,round and 10 or 9,0,round and 5 or 4.5,0,C.brown)
	if round then
		ball(m,"Crown",14.5,12,12,0,13.2,0,C.green)
		ball(m,"CrownHighlight",9,7,8,-1.5,16.3,0,C.light)
	else
		for i=1,3 do
			local d=14.2-i*2.4
			ball(m,"PineBough",d,5.8,d,0,6+i*3.7,0,C.pine)
		end
	end
end
local function road(m,name)
	box(m,"RoadSurface",40,.8,40,0,.4,0,C.road)
	local function stripe(x,z,sx,sz) box(m,"RoadMarking",sx,.04,sz,x,.83,z,C.yellow) end
	if name ~= "Road_Intersection" then for z=-15,15,10 do stripe(0,z,.38,4.6) end end
	if name ~= "Road_Straight" then for x=-15,15,10 do stripe(x,0,4.6,.38) end end
end
local function build(m,name)
	if name:match("^Car_") then car(m,name)
	elseif name=="Tree_Round" or name=="Tree_Pine" then tree(m,name=="Tree_Round")
	elseif name:match("^Road_") and name~="Road_Barrier" then road(m,name)
	elseif name=="Bush" then
		ball(m,"Bush",6.5,3.4,5.1,0,1.8,0,C.green)
		ball(m,"Leaves",3.5,2.6,3.6,-1.5,2.3,.5,C.light)
	elseif name=="Grass_Tuft" then
		for i=1,5 do box(m,"GrassBlade",.3,2.2-i*.2,.27,math.sin(i*2.3)*.48,1,math.cos(i*2.3)*.48,C.green,CFrame.Angles(0,i*1.25,.18)) end
	elseif name=="Rock_Large" or name=="Rock_Small" then
		local big=name=="Rock_Large"
		ball(m,"Rock",big and 10 or 5.2,big and 5.2 or 2,big and 8 or 3.1,0,big and 2.6 or 1,0,C.gray)
	elseif name=="Park_Bench" then
		for _,z in ipairs({-.45,.25}) do box(m,"SeatSlat",6,.22,.38,0,1.85,z,C.wood) end
		for y=2.35,3.15,.4 do box(m,"BackSlat",6,.25,.22,0,y,.84,C.wood) end
		for _,x in ipairs({-2.4,2.4}) do box(m,"BenchLeg",.33,1.8,.33,x,.9,0,C.dark) end
	elseif name=="Picket_Fence" then
		for _,y in ipairs({1.3,3.1}) do box(m,"FenceRail",9.2,.32,.26,0,y,0,C.white) end
		for x=-4,4,1 do box(m,"Picket",.45,4.4,.32,x,2.2,0,C.white) end
	elseif name=="Road_Barrier" then
		for _,x in ipairs({-3,3}) do box(m,"BarrierLeg",.38,3.5,.6,x,1.75,0,C.gray) end
		box(m,"BarrierPanel",7.1,1.25,.4,0,3,0,C.orange)
		for x=-2.5,2.5,2.5 do box(m,"Stripe",.65,1.28,.05,x,3,-.23,C.white,CFrame.Angles(0,0,.3)) end
	elseif name=="Fire_Hydrant" then
		tube(m,"HydrantBody",1.15,1.9,0,1.15,0,C.red)
		ball(m,"HydrantCap",1.25,.65,1.25,0,2.35,0,C.red)
		tube(m,"HydrantCross",.65,2,0,1.5,0,C.red,wheelAxis)
	elseif name=="Stop_Sign" then
		tube(m,"SignPost",.16,8,0,4,0,C.metal)
		ball(m,"StopPlate",2.6,2.6,.22,0,7.6,0,C.red)
		box(m,"StopBar",1.5,.25,.04,0,7.6,-.13,C.white)
	elseif name=="Street_Lamp" then
		tube(m,"LampPost",.4,18.6,0,9.3,0,C.dark)
		box(m,"LampArm",.3,.3,4.5,0,18.3,2.2,C.dark)
		box(m,"LampHead",1.5,.5,1.1,0,18,4.7,C.metal)
		box(m,"LampLight",1.25,.06,.9,0,17.72,4.7,C.white)
	elseif name=="Traffic_Cone" then
		box(m,"ConeBase",1.8,.18,1.8,0,.1,0,C.dark)
		tube(m,"Cone",.95,2.15,0,1.25,0,C.orange)
		tube(m,"ReflectiveBand",1,.35,0,1.55,0,C.white)
	else error("Unknown low-poly asset: "..name) end
end
local function buildImported(m, name)
	for _,info in ipairs(imported[name]) do
		local p = AssetService:CreateMeshPartAsync(Content.fromAssetId(assert(tonumber(info.mesh:match("%d+")))))
		local cf = info.cf
		p.Name = info.name
		p.Size = Vector3.new(info.size[1], info.size[2], info.size[3]) * IMPORT_SCALE
		p.CFrame = CFrame.new(cf[1] * IMPORT_SCALE, cf[2] * IMPORT_SCALE, cf[3] * IMPORT_SCALE,
			cf[4], cf[5], cf[6], cf[7], cf[8], cf[9], cf[10], cf[11], cf[12])
		p.TextureID = info.texture
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Parent = m
	end
end
local function template(name)
	local existing=templates:FindFirstChild(name)
	if existing then return existing end
	if loading[name] then
		while loading[name] do task.wait() end
		return assert(templates:FindFirstChild(name), "Imported model failed to load: "..name)
	end
	loading[name]=true
	local ok,result=pcall(function()
	local m=Instance.new("Model")
	m.Name=name
	local pivot=Instance.new("Part")
	pivot.Name="ModelPivot"
	pivot.Size=Vector3.new(.1,.1,.1)
	pivot.Transparency=1
	pivot.Anchored,pivot.CanCollide,pivot.CanTouch,pivot.CanQuery=true,false,false,false
	pivot.Parent=m
	m.PrimaryPart=pivot
	if imported[name] then buildImported(m,name) else build(m,name) end
	m.Parent=templates
	return m
	end)
	loading[name]=nil
	if not ok then error(result) end
	return result
end
function Assets.Clone(name) return template(name):Clone() end
function Assets.Place(name,parent,position,yaw)
	local m=Assets.Clone(name)
	m:PivotTo(CFrame.new(position)*CFrame.Angles(0,yaw or 0,0))
	m.Parent=parent
	return m
end
return Assets
