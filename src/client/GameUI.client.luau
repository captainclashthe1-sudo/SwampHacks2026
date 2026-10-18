-- Cartoon HUD and menus adapted from the user's GameUI.client.lua for Bridge Builders.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local playerGui = player:WaitForChild("PlayerGui")
local bridgeActions = player:WaitForChild("PlayerScripts"):WaitForChild("BridgeUIActions")
local saveRemote=game:GetService("ReplicatedStorage"):WaitForChild("BridgeBuildRemotes"):WaitForChild("Action")
while player:GetAttribute("ProfileLoaded")~=true do player:GetAttributeChangedSignal("ProfileLoaded"):Wait() end

---------------------------------------------------------------------------------------------------
-- Theme
---------------------------------------------------------------------------------------------------
local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)

local function hex(h)
	return Color3.fromHex(h)
end

local THEME = {
	cream = hex("F6ECD6"),
	stitch = hex("D9C3A0"),
	tan = hex("E6CFAD"),
	brown = hex("6E4325"),
	brownText = hex("8A5A35"),
	switchOff = hex("BFA98A"),
	overlay = hex("2A1745"),
	buttons = {
		red = { face = hex("F0524A"), dark = hex("A8302B") },
		blue = { face = hex("2FA8F0"), dark = hex("1B67AD") },
		yellow = { face = hex("F7C628"), dark = hex("B98A0E") },
		green = { face = hex("8CD63A"), dark = hex("4C8F1B") },
	},
}

local REFERENCE_HEIGHT = 720 -- the UI is designed at this screen height and scaled from it

---------------------------------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------------------------------
local function new(class, props, children)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			obj[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	if props and props.Parent then
		obj.Parent = props.Parent
	end
	return obj
end

local function corner(px)
	return new("UICorner", { CornerRadius = UDim.new(0, px) })
end

local function round()
	return new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

local function stroke(color, thickness, mode)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function gradient(color)
	return new("UIGradient", {
		Color = ColorSequence.new(color:Lerp(WHITE, 0.25), color),
		Rotation = 90,
	})
end

-- White cartoon text with a dark outline
local function label(text, size, outline, props)
	local p = {
		BackgroundTransparency = 1,
		Text = text,
		Font = FONT,
		TextSize = size,
		TextColor3 = WHITE,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local l = new("TextLabel", p)
	if outline then
		stroke(outline, math.max(1.5, size / 11), Enum.ApplyStrokeMode.Contextual).Parent = l
	end
	return l
end

local function tween(obj, time, goal, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

---------------------------------------------------------------------------------------------------
-- Components
---------------------------------------------------------------------------------------------------

-- Chunky glossy button. Returns the holder frame and the clickable face.
local function makeButton(parent, text, colorName, size, onClick, props)
	local col = THEME.buttons[colorName]
	local holder = new("Frame", {
		Size = size,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	for k, v in pairs(props or {}) do
		holder[k] = v
	end
	local scale = new("UIScale", { Parent = holder })
	new("Frame", { -- the darker "thickness" under the button
		Name = "Base",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 5),
		BackgroundColor3 = col.dark,
		BorderSizePixel = 0,
		Parent = holder,
	}, { corner(14) })
	local face = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		AutoButtonColor = false,
		Text = "",
		Parent = holder,
	}, { corner(14), gradient(col.face), stroke(col.dark, 3) })
	new("Frame", { -- gloss highlight, top-left
		Size = UDim2.fromOffset(18, 7),
		Position = UDim2.fromOffset(10, 7),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = face,
	}, { round() })
	new("Frame", {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.fromOffset(32, 7),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = face,
	}, { round() })
	label(text, math.floor(size.Y.Offset * 0.5), col.dark, { Parent = face })

	face.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.04 })
	end)
	face.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
		face.Position = UDim2.fromOffset(0, 0)
	end)
	face.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, 3)
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.fromOffset(0, 0)
	end)
	face.Activated:Connect(function()
		if onClick then
			onClick()
		end
	end)
	return holder, face
end

-- Cream card with a stitched inner line and a title ribbon. Returns panel, content area.
local function makePanel(parent, title, w, h, ribbonColor)
	local col = THEME.buttons[ribbonColor or "red"]
	local panel = new("Frame", {
		Name = title .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = THEME.cream,
		Visible = false,
		Parent = parent,
	}, { corner(28), stroke(THEME.brown, 4) })
	new("UIScale", { Name = "Pop", Parent = panel })
	new("Frame", { -- stitched inner border
		Position = UDim2.fromOffset(11, 11),
		Size = UDim2.new(1, -22, 1, -22),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { corner(20), stroke(THEME.stitch, 2) })

	local ribbon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(math.max(190, math.floor(w * 0.56)), 54),
		BackgroundColor3 = WHITE,
		Parent = panel,
	}, { corner(16), gradient(col.face), stroke(col.dark, 3) })
	new("Frame", {
		Size = UDim2.fromOffset(20, 7),
		Position = UDim2.fromOffset(12, 8),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = ribbon,
	}, { round() })
	label(title, 28, col.dark, { Parent = ribbon })

	local content = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(30, 50),
		Size = UDim2.new(1, -60, 1, -80),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	return panel, content
end

-- Settings tile: title, icon, and an OFF/ON switch.
local function makeSwitchTile(parent, title, icon, initial, onChange, order)
	local tile = new("Frame", {
		Size = UDim2.fromOffset(120, 150),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	label(title, 22, THEME.brown, { Size = UDim2.new(1, 0, 0, 28), Parent = tile })
	label(icon, 40, nil, { Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 32), Parent = tile })

	local track = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(78, 22),
		BackgroundColor3 = THEME.switchOff,
		AutoButtonColor = false,
		Text = "",
		Parent = tile,
	}, { round(), stroke(THEME.brown, 2) })
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.2, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = THEME.cream,
		Parent = track,
	}, { round(), stroke(THEME.brown, 2) })
	label("OFF", 12, nil, {
		TextColor3 = THEME.brownText,
		Size = UDim2.fromOffset(30, 14),
		Position = UDim2.new(0.5, -40, 0, 124),
		Parent = tile,
	})
	label("ON", 12, nil, {
		TextColor3 = THEME.brownText,
		Size = UDim2.fromOffset(30, 14),
		Position = UDim2.new(0.5, 10, 0, 124),
		Parent = tile,
	})

	local on = initial
	local function render(animate)
		local goal = { Position = UDim2.fromScale(on and 0.8 or 0.2, 0.5) }
		local color = on and THEME.buttons.green.face or THEME.switchOff
		if animate then
			tween(knob, 0.15, goal)
			tween(track, 0.15, { BackgroundColor3 = color })
		else
			knob.Position = goal.Position
			track.BackgroundColor3 = color
		end
	end
	track.Activated:Connect(function()
		on = not on
		render(true)
		onChange(on,true)
	end)
	render(false)
	onChange(on,false)
	return tile
end

---------------------------------------------------------------------------------------------------
-- Screen setup: one ScreenGui, zero-size anchors that carry the global scale
---------------------------------------------------------------------------------------------------
local old = playerGui:FindFirstChild("GameUI")
if old then
	old:Destroy()
end

local gui = new("ScreenGui", {
	Name = "GameUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 10,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

local scalers = {}
local function anchor(name, sx, sy)
	local a = new("Frame", {
		Name = name,
		Position = UDim2.fromScale(sx, sy),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	table.insert(scalers, new("UIScale", { Parent = a }))
	return a
end

local overlay = new("TextButton", { -- dims the game and blocks clicks while a menu is open
	Name = "Overlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.overlay,
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
	Parent = gui,
})

local topCenter = anchor("TopCenter", 0.5, 0)
local topRight = anchor("TopRight", 1, 0)
local bottom = anchor("Bottom", 0.5, 1)
local center = anchor("Center", 0.5, 0.5)

local camera = workspace.CurrentCamera
local function rescale()
	local h = camera.ViewportSize.Y
	local w = camera.ViewportSize.X
	if w < 200 or h < 200 then return end
	local preference = math.clamp(tonumber(player:GetAttribute("BridgeUIScale")) or 1, 0.8, 1.3)
	local s = math.clamp(math.min(h / REFERENCE_HEIGHT, w / 720) * preference, 0.5,
		math.min(1.5, w / 690, h / 550))
	for _, sc in ipairs(scalers) do
		sc.Scale = s
	end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
player:GetAttributeChangedSignal("BridgeUIScale"):Connect(rescale)
rescale()

---------------------------------------------------------------------------------------------------
-- Menus
---------------------------------------------------------------------------------------------------
local panels = {}
local current = nil
local menu
local bar
local settings
local shopQuick
local garageQuick
local vehiclePreview

local function showPanel(panel)
 local previewMode=panel==panels.shop or panel==panels.garage
 if not previewMode and vehiclePreview then vehiclePreview.ReleaseAll() end
 player:SetAttribute("MenuOpen",panel~=nil)
	for _, p in pairs(panels) do
		p.Visible = false
	end
	if bar then
		bar.Visible = panel == nil and player:GetAttribute("LevelSelected") == true
	end
	local showQuick = panel == nil and player:GetAttribute("LevelSelected") == true
	if shopQuick then shopQuick.Visible = showQuick end
	if garageQuick then garageQuick.Visible = showQuick end
	if not panel then
		current = nil
		tween(overlay, 0.2, { BackgroundTransparency = 1 }).Completed:Connect(function()
			if not current then
				overlay.Visible = false
			end
		end)
		return
	end
	current = panel
	overlay.Visible = true
	tween(overlay, 0.2, { BackgroundTransparency = 0.45 })
	panel.Visible = true
 if previewMode and vehiclePreview then vehiclePreview.RefreshAll() end
	local pop = panel:FindFirstChild("Pop")
	pop.Scale = 0.7
	tween(pop, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Five-level demo campaign.
local home, homeContent = makePanel(center, "BRIDGE BUILDERS", 510, 425, "red")
panels.home = home
label("Five crossings. One final leap. Build your way to the harbor.", 19, nil, {
	TextColor3 = THEME.brownText,
	TextWrapped = true,
	Position = UDim2.fromOffset(0, 10),
	Size = UDim2.new(1, 0, 0, 55),
	Parent = homeContent,
})

local campaign=require(game:GetService("ReplicatedStorage").Shared.LevelConfig)
local levels,levelsContent=makePanel(center,"SELECT LEVEL",650,610,"blue")
panels.levels=levels
local levelCards={}
local levelMessage=label("Complete each crossing to unlock the next. Your progress is saved.",15,nil,{
 TextColor3=THEME.brownText,Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-16,0,36),TextWrapped=true,Parent=levelsContent})
for id,entry in ipairs(campaign.Campaign) do
 local card=new("Frame",{Position=UDim2.fromOffset(8,42+(id-1)*79),Size=UDim2.new(1,-16,0,70),BackgroundColor3=THEME.tan,Parent=levelsContent},{corner(14),stroke(THEME.brown,2)})
 local badge=label(tostring(id),30,THEME.brown,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(42,48),TextColor3=entry.Color,Parent=card})
 label(entry.Title:upper(),19,nil,{TextColor3=THEME.brown,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(60,8),Size=UDim2.fromOffset(325,25),Parent=card})
 local details=label("$"..entry.Funds.." funds  •  "..entry.MaxSpeed.." max speed",14,nil,{TextColor3=THEME.brownText,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(60,38),Size=UDim2.fromOffset(330,23),Parent=card})
 local play=makeButton(card,"PLAY","green",UDim2.fromOffset(115,44),function()
  if id>(player:GetAttribute("UnlockedLevel") or 1) then levelMessage.Text="Complete level "..(id-1).." to unlock this crossing."; return end
  levelMessage.Text="Loading "..entry.Title.."..."; bridgeActions:Fire("EnterLevel",id)
 end,{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-12,.5,0)})
 levelCards[id]={Button=play,Card=card,Details=details}
end
local function refreshLevels()
 local unlocked=player:GetAttribute("UnlockedLevel") or 1
 for id,card in ipairs(levelCards) do
  local open=id<=unlocked
  card.Card.BackgroundColor3=open and THEME.cream or THEME.tan
  local text=card.Button:FindFirstChildWhichIsA("TextLabel",true)
  if text then text.Text=open and (player:GetAttribute("CompletedLevel"..id) and "REPLAY" or "PLAY") or "LOCKED" end
  card.Button:SetAttribute("Locked",not open)
  local face=card.Button:FindFirstChild("Face")
  local shade=face and face:FindFirstChildOfClass("UIGradient")
  if shade then shade.Color=ColorSequence.new(open and THEME.buttons.green.face or Color3.fromRGB(171,164,147)) end
 end
end
player:GetAttributeChangedSignal("UnlockedLevel"):Connect(refreshLevels)
for id=1,5 do player:GetAttributeChangedSignal("CompletedLevel"..id):Connect(refreshLevels) end
refreshLevels()
local finale,finaleContent=makePanel(center,"DEMO COMPLETE",510,370,"yellow")
panels.finale=finale
label("YOU CLEARED THE HARBOR!",25,nil,{
 TextColor3=THEME.brown,Position=UDim2.fromOffset(10,18),Size=UDim2.new(1,-20,0,70),TextWrapped=true,Parent=finaleContent,
})
label("Five bridges built. Boat jump landed. Thanks for playing Bridge Builders!",20,nil,{
 TextColor3=THEME.brownText,Position=UDim2.fromOffset(25,91),Size=UDim2.new(1,-50,0,78),TextWrapped=true,Parent=finaleContent,
})
makeButton(finaleContent,"REPLAY LEVELS","green",UDim2.fromOffset(260,58),function() refreshLevels(); showPanel(levels) end,{
 AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,190),
})
player:GetAttributeChangedSignal("CampaignComplete"):Connect(function()
 if player:GetAttribute("CampaignComplete") and player:GetAttribute("LevelSelected") then showPanel(finale) end
end)
makeButton(levelsContent,"Back","yellow",UDim2.fromOffset(180,48),function() showPanel(player:GetAttribute("LevelSelected") and menu or home) end,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,454)})
bridgeActions.Event:Connect(function(action,value)
 if action=="LevelEntered" then showPanel(nil)
 elseif action=="ShowLevels" then refreshLevels(); showPanel(levels)
 elseif action=="LevelError" then levelMessage.Text=value or "Could not load level." end
end)
local homeNotice=label(player:GetAttribute("SaveAvailable") and "Progress saves automatically." or "Saving unavailable; progress is temporary.",16,nil,{TextColor3=THEME.brownText,Position=UDim2.fromOffset(10,316),Size=UDim2.new(1,-20,0,24),Parent=homeContent})
local shopCatalog=require(game:GetService("ReplicatedStorage").Shared.ShopCatalog)
vehiclePreview=require(script.Parent.VehiclePreview)
local shop,shopContent=makePanel(center,"TOKEN SHOP",700,730,"yellow")
panels.shop=shop
local tokenLabel=label("TOKENS  0",25,THEME.brown,{TextColor3=THEME.buttons.yellow.dark,Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-16,0,38),Parent=shopContent})
local shopMessage=label("Finish a level to earn tokens. Items are cosmetic.",15,nil,{TextColor3=THEME.brownText,Position=UDim2.fromOffset(6,39),Size=UDim2.new(1,-12,0,28),Parent=shopContent})
local shelf=new("ScrollingFrame",{Position=UDim2.fromOffset(0,72),Size=UDim2.new(1,0,1,-145),CanvasSize=UDim2.fromOffset(0,#shopCatalog.Items*100+12),ScrollBarThickness=7,ScrollBarImageColor3=THEME.brown,BackgroundTransparency=1,BorderSizePixel=0,Parent=shopContent})
local shopCards={}
local shopState={Tokens=0,Owned={}}
local function shopCall(action,id)
 local ok,result=pcall(function() return saveRemote:InvokeServer(action,{ItemId=id}) end)
 if not ok or type(result)~="table" then return {ok=false,message="Could not contact the shop."} end
 return result
end
local refreshShop
for index,item in ipairs(shopCatalog.Items) do
 local card=new("Frame",{Position=UDim2.fromOffset(5,(index-1)*100+3),Size=UDim2.new(1,-16,0,92),BackgroundColor3=THEME.tan,Parent=shelf},{corner(13),stroke(THEME.stitch,2)})
 local badge=new("Frame",{Position=UDim2.fromOffset(9,7),Size=UDim2.fromOffset(78,78),BackgroundColor3=item.Color,Parent=card},{corner(11),stroke(THEME.brown,2)})
 if item.Kind=="Vehicle" then
  vehiclePreview.Attach(badge,item.Mesh,item.Color)
 else
  new("ImageLabel",{Name="ItemImage",Size=UDim2.new(1,-4,1,-4),Position=UDim2.fromOffset(2,2),BackgroundTransparency=1,Image=item.Icon,ScaleType=Enum.ScaleType.Fit,Parent=badge})
 end
 label(item.Name,18,nil,{TextColor3=THEME.brown,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(99,16),Size=UDim2.fromOffset(310,28),Parent=card})
 label(item.Description,13,nil,{TextColor3=THEME.brownText,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(99,49),Size=UDim2.fromOffset(320,25),Parent=card})
 local button=makeButton(card,tostring(item.Price).." TOKENS","green",UDim2.fromOffset(142,45),function()
  local owned=shopState.Owned and shopState.Owned[item.Id]
  if owned and item.Kind~="Cosmetic" then shopMessage.Text="Owned! Customize it in the garage.";return end
  local result=shopCall(owned and "ShopEquip" or "ShopPurchase",item.Id)
  shopMessage.Text=result.message or "Shop request finished."
  if result.ok then Sfx.Play("Purchase"); refreshShop() end
 end,{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-9,.5,0)})
 shopCards[item.Id]={Button=button,Item=item}
end
refreshShop=function()
 local result=shopCall("ShopState")
 if not result.ok then shopMessage.Text=result.message or "Shop unavailable.";return end
 shopState=result
 tokenLabel.Text="TOKENS  "..tostring(result.Tokens or 0)
 for id,entry in pairs(shopCards) do
  local item=entry.Item
  local owned=result.Owned and result.Owned[id]
  local equipped=(item.Kind=="Vehicle" and result.Vehicle==id) or (item.Kind=="Paint" and result.Paint==id) or (item.Kind=="Trail" and result.Trail==id) or (item.Kind=="Cosmetic" and result.Cosmetic==id)
  local caption=entry.Button:FindFirstChildWhichIsA("TextLabel",true)
  if caption then caption.Text=equipped and "EQUIPPED" or owned and (item.Kind=="Cosmetic" and "EQUIP" or "OWNED") or tostring(item.Price).." TOKENS" end
 end
end
local garageRefresh
makeButton(shopContent,"GARAGE","blue",UDim2.fromOffset(170,42),function()
 garageRefresh();showPanel(panels.garage)
end,{Position=UDim2.fromOffset(13,592)})
makeButton(shopContent,"NO COSMETIC","blue",UDim2.fromOffset(170,42),function()
 local result=shopCall("ShopEquip","NoCosmetic");shopMessage.Text=result.message or "";if result.ok then refreshShop() end
end,{Position=UDim2.fromOffset(209,592)})
makeButton(shopContent,"BACK","yellow",UDim2.fromOffset(150,42),function()
 if player:GetAttribute("LevelSelected") then showPanel(nil) else showPanel(home) end
end,{Position=UDim2.fromOffset(445,592)})
-- The garage uses a fixed 3D viewport. Right-drag the model to orbit its camera.
local garage,garageContent=makePanel(center,"GARAGE",760,620,"blue")
panels.garage=garage
local garageStage=new("Frame",{Position=UDim2.fromOffset(9,48),Size=UDim2.fromOffset(350,420),BackgroundColor3=THEME.tan,ClipsDescendants=true,Active=true,Parent=garageContent},{corner(18),stroke(THEME.brown,2)})
local garageViewport
local orbitLastX
local garageMessage=label("Right-drag to rotate. Changes appear on the next car spawn.",15,nil,{TextColor3=THEME.brownText,TextWrapped=true,Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-16,0,38),Parent=garageContent})
local optionLabels={}
local optionKinds={"Vehicle","Paint","Trail"}
local optionTitles={Vehicle="CAR MODEL",Paint="PAINT",Trail="TRAIL"}
local function garageOptions(kind)
 local options={}
 if kind=="Trail" then table.insert(options,{Id="NoTrail",Name="None"}) end
 for _,item in ipairs(shopCatalog.Items) do
  if item.Kind==kind and (shopState.Owned[item.Id] or item.Id=="VehicleCar" or (kind=="Paint" and shopCatalog.DefaultPaint[shopState.Vehicle or "VehicleCar"]==item.Id)) then
   if kind~="Paint" or shopCatalog.Meshes[shopState.Vehicle or "VehicleCar"][item.Id] then table.insert(options,item) end
  end
 end
 return options
end
garageRefresh=function()
 refreshShop()
 local vehicle=shopState.Vehicle or "VehicleCar"
 local paint=shopState.Paint or shopCatalog.DefaultPaint[vehicle]
 local mesh=shopCatalog.Meshes[vehicle][paint] or shopCatalog.Meshes[vehicle][shopCatalog.DefaultPaint[vehicle]]
 if garageViewport then garageViewport:Destroy() end
 garageViewport=vehiclePreview.Attach(garageStage,mesh,(shopCatalog.ById[paint] or shopCatalog.ById[shopCatalog.DefaultPaint[vehicle]]).Color)
 garageViewport.Active=true
 vehiclePreview.SetTrail(garageViewport,shopState.Trail=="BlueTrail",shopCatalog.ById.BlueTrail.Color)
 for kind,readout in pairs(optionLabels) do
  local chosen=kind=="Vehicle" and vehicle or kind=="Paint" and paint or shopState.Trail or "NoTrail"
  local item=shopCatalog.ById[chosen]
  readout.Text=item and item.Name or "None"
 end
end
local function cycleGarage(kind,direction)
 local options=garageOptions(kind)
 if #options==0 then garageMessage.Text="Buy an option in the shop first.";return end
 local chosen=kind=="Vehicle" and shopState.Vehicle or kind=="Paint" and shopState.Paint or shopState.Trail or "NoTrail"
 local index=0
 for i,item in ipairs(options) do if item.Id==chosen then index=i;break end end
 local target=options[((index-1+direction)%#options)+1]
 local result=shopCall("ShopEquip",target.Id)
 garageMessage.Text=result.message or "Garage updated."
 if result.ok then garageRefresh() end
end
for i,kind in ipairs(optionKinds) do
 local y=75+(i-1)*122
 label(optionTitles[kind],18,nil,{TextColor3=THEME.brown,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(380,y),Size=UDim2.fromOffset(290,26),Parent=garageContent})
 local readout=label("",20,nil,{TextColor3=THEME.brownText,Position=UDim2.fromOffset(430,y+36),Size=UDim2.fromOffset(185,48),Parent=garageContent})
 optionLabels[kind]=readout
 makeButton(garageContent,"‹","yellow",UDim2.fromOffset(42,46),function() cycleGarage(kind,-1) end,{Position=UDim2.fromOffset(380,y+37)})
 makeButton(garageContent,"›","yellow",UDim2.fromOffset(42,46),function() cycleGarage(kind,1) end,{Position=UDim2.fromOffset(625,y+37)})
end
local InputService=game:GetService("UserInputService")
InputService.InputBegan:Connect(function(input)
 if not garage.Visible or input.UserInputType~=Enum.UserInputType.MouseButton2 then return end
 local point=InputService:GetMouseLocation()
 local pos,size=garageStage.AbsolutePosition,garageStage.AbsoluteSize
 if point.X>=pos.X and point.X<=pos.X+size.X and point.Y>=pos.Y and point.Y<=pos.Y+size.Y then
  orbitLastX=point.X
  if garageViewport then vehiclePreview.Rotate(garageViewport,0.25) end
 end
end)
InputService.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton2 then orbitLastX=nil end end)
game:GetService("RunService").RenderStepped:Connect(function()
 if not garage.Visible or not orbitLastX or not garageViewport then return end
 local x=InputService:GetMouseLocation().X
 if x~=orbitLastX then vehiclePreview.Rotate(garageViewport,-(x-orbitLastX)*0.012);orbitLastX=x end
end)
makeButton(garageContent,"SHOP","green",UDim2.fromOffset(180,48),function() refreshShop();showPanel(shop) end,{Position=UDim2.fromOffset(16,494)})
makeButton(garageContent,"BACK","yellow",UDim2.fromOffset(180,48),function()
 if player:GetAttribute("LevelSelected") then showPanel(nil) else showPanel(home) end
end,{Position=UDim2.fromOffset(480,494)})
local homeOptions={
 {"BASIC MODE","green",function() showPanel(levels) end},
 {"INFINITE MODE","blue",function() homeNotice.Text="Infinite Mode is coming soon." end},
 {"CREATE A LEVEL","yellow",function() homeNotice.Text="Create a Level is coming soon." end},
 {"SETTINGS","blue",function() showPanel(settings) end},
}
for index,option in ipairs(homeOptions) do
 makeButton(homeContent,option[1],option[2],UDim2.fromOffset(310,55),option[3],{
  AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,58+(index-1)*58)})
end

-- In-level pause menu.
local menuContent
menu, menuContent = makePanel(center, "Menu", 380, 580, "red")
panels.menu = menu
new("UIListLayout", {
	Padding = UDim.new(0, 10),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = menuContent,
})

-- Settings
local settingsContent
settings, settingsContent = makePanel(center, "Settings", 640, 440, "red")
panels.settings = settings
local function updateSetting(name,value)
 task.spawn(function()
  local ok,result=pcall(function() return saveRemote:InvokeServer("UpdateSettings",{Name=name,Value=value}) end)
  if not ok or not result.ok then warn("Setting did not sync: "..name) end
 end)
end
local tray = new("Frame", {
	Size = UDim2.new(1, 0, 0, 190),
	Position = UDim2.fromOffset(0, 10),
	BackgroundColor3 = THEME.tan,
	Parent = settingsContent,
}, { corner(18) })
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 18),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = tray,
})

local function soundGroup(name)
	local g = SoundService:FindFirstChild(name)
	if not g then
		g = new("SoundGroup", { Name = name, Volume = 0.5, Parent = SoundService })
	end
	return g
end
local sfx, music = soundGroup("SFX"), soundGroup("Music")
local sfxVolume, musicVolume = sfx.Volume > 0 and sfx.Volume or 0.5, music.Volume > 0 and music.Volume or 0.5

makeSwitchTile(tray, "Sound", "🔊", player:GetAttribute("SoundEnabled")~=false, function(on,changed)
	sfx.Volume = on and sfxVolume or 0
 if changed then updateSetting("SoundEnabled",on) end
end, 1)
makeSwitchTile(tray, "Music", "🎵", player:GetAttribute("MusicEnabled")~=false, function(on,changed)
	music.Volume = on and musicVolume or 0
 if changed then updateSetting("MusicEnabled",on) end
end, 2)
makeSwitchTile(tray, "Shadows", "🌤️", player:GetAttribute("ShadowsEnabled")~=false, function(on,changed)
	Lighting.GlobalShadows = on
 if changed then updateSetting("ShadowsEnabled",on) end
end, 3)
makeSwitchTile(tray, "Tips", "💡", player:GetAttribute("TutorialTipsEnabled") ~= false, function(on,changed)
	player:SetAttribute("TutorialTipsEnabled", on)
 if changed then updateSetting("TutorialTipsEnabled",on) end
end, 4)

label("UI SIZE", 21, nil, {
	TextColor3 = THEME.brown,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(30, 218),
	Size = UDim2.fromOffset(180, 48),
	Parent = settingsContent,
})
local sizeReadout = label("100%", 22, THEME.brown, {
	Position = UDim2.fromOffset(314, 218),
	Size = UDim2.fromOffset(90, 48),
	Parent = settingsContent,
})
local function adjustSize(delta)
	local nextSize = math.clamp(math.round(((tonumber(player:GetAttribute("BridgeUIScale")) or 1) + delta) * 10) / 10, 0.8, 1.3)
	player:SetAttribute("BridgeUIScale", nextSize)
	updateSetting("BridgeUIScale",nextSize)
	sizeReadout.Text = tostring(math.round(nextSize * 100)) .. "%"
end
makeButton(settingsContent, "−", "blue", UDim2.fromOffset(50, 42), function()
	adjustSize(-0.1)
end, {Position = UDim2.fromOffset(248, 221)})
makeButton(settingsContent, "+", "blue", UDim2.fromOffset(50, 42), function()
	adjustSize(0.1)
end, {Position = UDim2.fromOffset(420, 221)})
sizeReadout.Text = tostring(math.round((tonumber(player:GetAttribute("BridgeUIScale")) or 1) * 100)) .. "%"

makeButton(settingsContent, "Back", "green", UDim2.fromOffset(240, 58), function()
	showPanel(player:GetAttribute("LevelSelected") and menu or home)
end, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6) })

-- Leave confirm
local confirm, confirmContent = makePanel(center, "Leave?", 400, 260, "red")
panels.confirm = confirm
label("Leave the game?", 26, nil, {
	TextColor3 = THEME.brown,
	Size = UDim2.new(1, 0, 0, 60),
	Position = UDim2.fromOffset(0, 16),
	Parent = confirmContent,
})
makeButton(confirmContent, "Leave", "red", UDim2.fromOffset(140, 58), function()
	player:Kick("Thanks for playing!")
end, { Position = UDim2.new(0, 10, 1, -70) })
makeButton(confirmContent, "Stay", "blue", UDim2.fromOffset(140, 58), function()
	showPanel(menu)
end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 1, -70) })

-- Menu buttons
local BW = UDim2.fromOffset(300, 60)
makeButton(menuContent, "Continue", "blue", BW, function()
	showPanel(nil)
end, { LayoutOrder = 1 })
makeButton(menuContent, "Levels", "green", BW, function()
	showPanel(levels)
end, { LayoutOrder = 2 })
makeButton(menuContent, "Level Tip", "blue", BW, function()
	showPanel(nil)
	bridgeActions:Fire("ShowLevelTip")
end, { LayoutOrder = 3 })
makeButton(menuContent, "Settings", "yellow", BW, function()
	showPanel(settings)
end, { LayoutOrder = 4 })
makeButton(menuContent, "Respawn", "green", BW, function()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = 0
	end
	showPanel(nil)
end, { LayoutOrder = 5 })
makeButton(menuContent,"Main Menu","blue",BW,function() showPanel(home) end,{LayoutOrder=6})
makeButton(menuContent, "Leave", "red", BW, function()
	showPanel(confirm)
end, { LayoutOrder = 7 })

local function toggleMenu()
	if not player:GetAttribute("LevelSelected") then return end
	if current then
		showPanel(nil)
	else
		showPanel(menu)
	end
end
overlay.Activated:Connect(function() end) -- swallow clicks behind the panels

ContextActionService:BindAction("GameUI_ToggleMenu", function(_, state)
	if state == Enum.UserInputState.Begin then
		toggleMenu()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)

---------------------------------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------------------------------
-- Session cash earned by finishing the bridge.
local cashPill = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(0, 72),
	Size = UDim2.fromOffset(220, 56),
	BackgroundColor3 = THEME.cream,
	Visible = player:GetAttribute("LevelSelected") == true,
	Parent = topCenter,
}, { round(), stroke(THEME.brown, 3) })
local cashIcon = new("Frame", {
	Position = UDim2.fromOffset(-6, -6),
	Size = UDim2.fromOffset(68, 68),
	BackgroundColor3 = WHITE,
	Parent = cashPill,
}, { round(), gradient(THEME.buttons.red.face), stroke(THEME.buttons.red.dark, 3) })
label("$", 34, nil, { Parent = cashIcon })
local cashCount = label("$0", 27, nil, {
	TextColor3 = THEME.brown,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(74, 0),
	Size = UDim2.new(1, -80, 1, 0),
	Parent = cashPill,
})

local function setCash(n)
	local digits = tostring(math.floor(tonumber(n) or 0))
	cashCount.Text = "$" .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	local s = cashPill:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = cashPill })
	s.Scale = 1.15
	tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

local levelName=label("LEVEL 1 / RIVER CROSSING",16,nil,{
 TextColor3=THEME.brown,Position=UDim2.new(.5,-170,0,140),Size=UDim2.fromOffset(340,28),
 BackgroundColor3=THEME.cream,BackgroundTransparency=.1,Visible=player:GetAttribute("LevelSelected")==true,Parent=topCenter,
})
local function updateLevelName()
 local id=player:GetAttribute("ActiveLevelId") or 1
 levelName.Text="LEVEL "..id.." / "..campaign.Campaign[id].Title:upper()
end
player:GetAttributeChangedSignal("ActiveLevelId"):Connect(updateLevelName)
updateLevelName()

task.spawn(function()
	local stats = player:WaitForChild("leaderstats", 10)
	local value = stats and stats:WaitForChild("Cash", 5)
	if value then
		setCash(value.Value)
		value.Changed:Connect(setCash)
	end
end)
if player:GetAttribute("Cash") ~= nil then
	setCash(player:GetAttribute("Cash"))
end
player:GetAttributeChangedSignal("Cash"):Connect(function()
	setCash(player:GetAttribute("Cash") or 0)
end)

-- Menu button (top-right)
local menuBtn = makeButton(topRight, "", "yellow", UDim2.fromOffset(60, 60), toggleMenu, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(-16, 72),
})
for i = 0, 2 do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, (i - 1) * 11),
		Size = UDim2.fromOffset(28, 6),
		BackgroundColor3 = WHITE,
		Parent = menuBtn:FindFirstChild("Face"),
	}, { round(), stroke(THEME.buttons.yellow.dark, 2) })
end
shopQuick = makeButton(topRight, "$", "red", UDim2.fromOffset(60, 60), function()
	refreshShop()
	showPanel(shop)
end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(-16, 140) })
local garageFace
garageQuick, garageFace = makeButton(topRight, "", "blue", UDim2.fromOffset(60, 60), function()
	garageRefresh()
	showPanel(garage)
end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(-16, 208) })
new("Frame", {
	Position = UDim2.fromOffset(19, 21), Size = UDim2.fromOffset(22, 15),
	BackgroundColor3 = WHITE, Parent = garageFace,
}, { corner(6), stroke(THEME.buttons.blue.dark, 2) })
new("Frame", {
	Position = UDim2.fromOffset(11, 30), Size = UDim2.fromOffset(38, 14),
	BackgroundColor3 = WHITE, Parent = garageFace,
}, { corner(5), stroke(THEME.buttons.blue.dark, 2) })
for _, x in ipairs({16, 39}) do
	new("Frame", {
		Position = UDim2.fromOffset(x, 39), Size = UDim2.fromOffset(9, 9),
		BackgroundColor3 = THEME.buttons.blue.dark, Parent = garageFace,
	}, { round(), stroke(WHITE, 1) })
end

-- Bridge controls (bottom centre). The construction script owns the mode and server requests.
bar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromOffset(0, -18),
	Size = UDim2.fromOffset(600, 84),
	BackgroundColor3 = THEME.cream,
	Parent = bottom,
}, { corner(26), stroke(THEME.brown, 4) })
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = bar,
})

local controls = {}
for i, v in ipairs({
	{ "🔨 Build", "blue", "Build" },
	{ "🧪 Test", "green", "Test" },
	{ "▶ Start", "yellow", "Start" },
	{ "🔄 Reset", "red", "Reset" },
}) do
	controls[v[3]] = makeButton(bar, v[1], v[2], UDim2.fromOffset(132, 54), function()
		bridgeActions:Fire(v[3])
	end, { LayoutOrder = i })
end
local function updateControls()
	local selected = player:GetAttribute("LevelSelected") == true
	cashPill.Visible = selected
	levelName.Visible = selected
	bar.Visible = selected and current == nil
	menuBtn.Visible = selected
	shopQuick.Visible = selected and current == nil
	garageQuick.Visible = selected and current == nil
	local testing = player:GetAttribute("BridgeMode") == "Test"
	controls.Build.Visible = testing
	controls.Test.Visible = not testing
	controls.Start.Visible = testing
	controls.Reset.Visible = testing
	bar.Size = UDim2.fromOffset(testing and 470 or 172, 84)
end
player:GetAttributeChangedSignal("BridgeMode"):Connect(updateControls)
player:GetAttributeChangedSignal("LevelSelected"):Connect(updateControls)
updateControls()
if not player:GetAttribute("LevelSelected") then
	showPanel(home)
end
