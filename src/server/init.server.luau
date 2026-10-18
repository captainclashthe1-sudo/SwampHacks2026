local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.Shared.LevelConfig)
require(script.Environment).Apply()
local previous=workspace:FindFirstChild("GeneratedLevel")
if previous then previous:Destroy() end
local generated=Instance.new("Folder"); generated.Name="GeneratedLevel"; generated.Parent=workspace
local maps={}
for id=1,#Config.Campaign do
 local config=Config.ForLevel(id)
 maps[id]={Config=config,Model=require(script.LevelGenerator).Create(config,generated)}
 task.wait()
end
require(script.CampaignServer).Start(maps)
generated:SetAttribute("Ready",true)
print("Bridge Builders: five-level campaign ready")
