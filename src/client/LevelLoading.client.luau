local Players=game:GetService("Players")
local ContentProvider=game:GetService("ContentProvider")
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui")
gui.Name="LevelLoading"
gui.IgnoreGuiInset=true
gui.ResetOnSpawn=false
gui.DisplayOrder=1000
gui.Parent=player:WaitForChild("PlayerGui")
local shade=Instance.new("Frame")
shade.Size=UDim2.fromScale(1,1)
shade.BackgroundColor3=Color3.fromRGB(28,43,56)
shade.Parent=gui
local title=Instance.new("TextLabel")
title.AnchorPoint=Vector2.new(.5,.5)
title.Position=UDim2.fromScale(.5,.46)
title.Size=UDim2.fromOffset(440,72)
title.BackgroundTransparency=1
title.Text="BRIDGE BUILDERS"
title.TextColor3=Color3.fromRGB(255,245,219)
title.TextSize=38
title.Font=Enum.Font.FredokaOne
title.Parent=shade
local status=Instance.new("TextLabel")
status.AnchorPoint=Vector2.new(.5,.5)
status.Position=UDim2.fromScale(.5,.55)
status.Size=UDim2.fromOffset(440,40)
status.BackgroundTransparency=1
status.Text="Loading the level..."
status.TextColor3=Color3.fromRGB(135,215,247)
status.TextSize=20
status.Font=Enum.Font.FredokaOne
status.Parent=shade
local generation=0
local function load()
 generation+=1
 local mine=generation
 gui.Enabled=true
 local id=player:GetAttribute("ActiveLevelId") or 1
 status.Text="Loading level "..id.."..."
 task.spawn(function()
  local level=workspace:WaitForChild("GeneratedLevel"):WaitForChild("Level"..id)
  local scenery=level:WaitForChild("LowpolyScenery")
  while mine==generation and not scenery:GetAttribute("Ready") do task.wait(.1) end
  if mine~=generation then return end
  status.Text="Loading buildings and scenery..."
  local assets={}
  for _,item in ipairs(scenery:GetDescendants()) do
   if item:IsA("MeshPart") or item:IsA("Decal") or item:IsA("Texture") then table.insert(assets,item) end
  end
  if #assets>0 then
   local ok,err=pcall(ContentProvider.PreloadAsync,ContentProvider,assets)
   if not ok then warn("Scenery preload: "..tostring(err)) end
  end
  while mine==generation and player:GetAttribute("SceneryReadyLevel")~=id do task.wait(.1) end
  if mine==generation then gui.Enabled=false end
 end)
end
player:GetAttributeChangedSignal("ActiveLevelId"):Connect(load)
load()
