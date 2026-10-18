local player=game:GetService("Players").LocalPlayer
local camera=workspace.CurrentCamera
local gui=Instance.new("ScreenGui")
gui.Name="WindIndicator"
gui.ResetOnSpawn=false
gui.Parent=player:WaitForChild("PlayerGui")
local label=Instance.new("TextLabel")
label.AnchorPoint=Vector2.new(.5,0)
label.Position=UDim2.new(.5,0,0,64)
label.Size=UDim2.fromOffset(390,40)
label.BackgroundColor3=Color3.fromRGB(29,58,75)
label.BackgroundTransparency=.12
label.TextColor3=Color3.fromRGB(234,249,255)
label.Font=Enum.Font.FredokaOne
label.TextSize=21
label.Text="WIND  ➜  WEST TO EAST"
label.Parent=gui
Instance.new("UICorner",label).CornerRadius=UDim.new(0,14)
local folder=Instance.new("Folder")
folder.Name="LocalWindStreaks"
folder.Parent=camera
for i=1,8 do
 local part=Instance.new("Part")
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.Material=Enum.Material.Neon
 part.Color=Color3.fromRGB(187,238,255)
 part.Transparency=.4
 part.Size=Vector3.new(5,.12,.12)
 part.Parent=folder
 task.spawn(function()
  local run=game:GetService("RunService")
  local t=i*2.7
  while part.Parent do
   local dt=run.RenderStepped:Wait()
   t=(t+dt*13)%110
   local origin=Vector3.new(0,0,1950)
   part.Position=origin+Vector3.new(t-55,12+(i%4)*5,((i*17)%32)-16)
  end
 end)
end
local function update()
 local active=player:GetAttribute("ActiveLevelId")==4 and player:GetAttribute("LevelSelected")==true
 gui.Enabled=active
 for _,part in ipairs(folder:GetChildren()) do part.Transparency=active and .4 or 1 end
end
player:GetAttributeChangedSignal("ActiveLevelId"):Connect(update)
player:GetAttributeChangedSignal("LevelSelected"):Connect(update)
update()
