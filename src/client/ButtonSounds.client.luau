local Players=game:GetService("Players")
local player=Players.LocalPlayer
local gui=player:WaitForChild("PlayerGui")
local connected={}
local Sfx=require(script.Parent:WaitForChild("Sfx"))

local function connect(object)
 if not object:IsA("GuiButton") or connected[object] then return end
 connected[object]=true
 object.Activated:Connect(function()
  Sfx.Play("Click")
 end)
 object.Destroying:Connect(function() connected[object]=nil end)
end
for _,object in ipairs(gui:GetDescendants()) do connect(object) end
gui.DescendantAdded:Connect(connect)
