local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Factory=require(script.Parent.BuildServer)
local SaveService=require(script.Parent.SaveService)
local Shop=require(script.Parent.ShopServer)
local Campaign={}

function Campaign.Start(maps)
 local controllers={}
 local switching={}
 local loading={}
 local saving={}
 local canSave={}
 local settingsKeys={SoundEnabled=true,MusicEnabled=true,ShadowsEnabled=true,TutorialTipsEnabled=true,BridgeUIScale=true}
 local function capture(player)
  local levels={}
  local active=player:GetAttribute("ActiveLevelId") or 1
  for id,controller in ipairs(controllers) do levels[tostring(id)]=controller.Export(player,id==active) end
  local completedLevels={}
  for id=1,#maps do completedLevels[id]=player:GetAttribute("CompletedLevel"..id)==true end
  local settings={}
  for name in pairs(settingsKeys) do settings[name]=player:GetAttribute(name) end
  local seenTips={}
  for id=1,#maps do seenTips[id]=player:GetAttribute("SeenLevelTip"..id)==true end
  return {Version=1,Levels=levels,Completed=completedLevels,SeenTips=seenTips,Unlocked=player:GetAttribute("UnlockedLevel") or 1,
   ActiveLevel=player:GetAttribute("ActiveLevelId") or 1,Settings=settings,Shop=Shop.Export(player),SeenBuildTutorial=player:GetAttribute("SeenBuildTutorial")==true}
 end
 local function save(player)
  if loading[player] or not canSave[player] then return false,"Saving is unavailable in this session." end
  if switching[player] then return false,"Finish loading the level before saving." end
  if saving[player] then return false,"A save is already in progress." end
  saving[player]=true
  local profile=capture(player)
  local ok,err=SaveService.Write(player,profile)
  saving[player]=nil
  player:SetAttribute("SaveAvailable",ok)
  if not ok then return false,"Save failed. "..tostring(err) end
  player:SetAttribute("LastSavedAt",os.time())
  return true,"Progress saved."
 end
 local function completed(player,id)
  if player:GetAttribute("CompletedLevel"..id) then return false end
  player:SetAttribute("CompletedLevel"..id,true)
  player:SetAttribute("UnlockedLevel",math.max(player:GetAttribute("UnlockedLevel") or 1,math.min(#maps,id+1)))
  if id==#maps then player:SetAttribute("CampaignComplete",true) end
  Shop.Award(player,maps[id].Config.Progression.CompletionTokens)
  return true
 end
 for id,entry in ipairs(maps) do controllers[id]=Factory.new(entry.Model,entry.Config,completed) end
 local function teleport(player,id)
  if not player.Parent or player:GetAttribute("ActiveLevelId")~=id then return end
  local character=player.Character
  local hum=character and character:FindFirstChildOfClass("Humanoid")
  if not character or not hum then return end
  local seat=hum.SeatPart
  local weld=seat and seat:FindFirstChild("SeatWeld")
  if weld then weld:Destroy() end
  hum.Sit=false
  local root=character:FindFirstChild("HumanoidRootPart")
  if not root then return end
  local wasAnchored=root.Anchored
  root.Anchored=true
  root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero
  -- Keep the assembly fixed across a physics step so stale client/seat motion cannot undo arrival.
  game:GetService("RunService").Heartbeat:Wait()
  if player.Character~=character or player:GetAttribute("ActiveLevelId")~=id then root.Anchored=wasAnchored;return end
  character:PivotTo(CFrame.new(maps[id].Config.Resolve().SpawnSurface+Vector3.new(0,4,-6)))
  player.RespawnLocation=maps[id].Model:FindFirstChild("StartSpawn")
  game:GetService("RunService").Heartbeat:Wait()
  if root.Parent then
   root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
   root.Anchored=wasAnchored
  end
 end
 local function selectLevel(player,id)
  if loading[player] then return {ok=false,message="Your save is loading."} end
  if type(id)~="number" or id%1~=0 or not controllers[id] then return {ok=false,message="Choose a valid level."} end
  if id>(player:GetAttribute("UnlockedLevel") or 1) then return {ok=false,message="Complete the previous level to unlock this one."} end
  if switching[player] then return {ok=false,message="Level is loading."} end
  switching[player]=true
  local old=player:GetAttribute("ActiveLevelId")
  if old and controllers[old] then controllers[old].Leave(player) end
  player:SetAttribute("ActiveLevelId",id)
  local budget=controllers[id].Select(player)
  player:SetAttribute("LevelSelected",true)
  local firstTip=player:GetAttribute("SeenLevelTip"..id)~=true
  player:SetAttribute("SeenLevelTip"..id,true)
  local firstTutorial=id==1 and player:GetAttribute("SeenBuildTutorial")~=true
  if firstTutorial then player:SetAttribute("SeenBuildTutorial",true) end
  teleport(player,id)
  switching[player]=nil
  return {ok=true,message=maps[id].Config.Hint,LevelId=id,Budget=budget,FirstTip=firstTip,FirstTutorial=firstTutorial}
 end
 local remotes=ReplicatedStorage:FindFirstChild("BridgeBuildRemotes") or Instance.new("Folder")
 remotes.Name="BridgeBuildRemotes"; remotes.Parent=ReplicatedStorage
 local action=remotes:FindFirstChild("Action") or Instance.new("RemoteFunction")
 action.Name="Action"; action.Parent=remotes
 action.OnServerInvoke=function(player,name,payload)
  payload=type(payload)=="table" and payload or {}
  if name=="SaveProgress" then
   local ok,message=save(player)
   return {ok=ok,message=message}
  end
  if name=="ShopState" then return Shop.Snapshot(player) end
  if name=="ShopPurchase" then
   if loading[player] or saving[player] then return {ok=false,message="Your profile is busy."} end
   return Shop.Purchase(player,payload.ItemId)
  end
  if name=="ShopEquip" then
   if loading[player] or saving[player] then return {ok=false,message="Your profile is busy."} end
   return Shop.Equip(player,payload.ItemId)
  end
  if name=="UpdateSettings" then
   local setting,value=payload.Name,payload.Value
   if not settingsKeys[setting] then return {ok=false,message="Unknown setting."} end
   if setting=="BridgeUIScale" then
    if type(value)~="number" or value<.8 or value>1.3 then return {ok=false,message="Invalid UI size."} end
   elseif type(value)~="boolean" then return {ok=false,message="Invalid setting."} end
   player:SetAttribute(setting,value)
   return {ok=true,message="Setting updated."}
  end
  if loading[player] then return {ok=false,message="Your save is loading."} end
  if name=="SelectLevel" then return selectLevel(player,payload.LevelId) end
  if switching[player] then return {ok=false,message="Level is loading."} end
  local id=player:GetAttribute("ActiveLevelId") or 1
  return controllers[id].Handle(player,name,payload)
 end
 local function prepare(player)
  loading[player]=true
  player:SetAttribute("ProfileLoaded",false)
  player:SetAttribute("SaveAvailable",false)
  player:SetAttribute("UnlockedLevel",1)
  player:SetAttribute("SeenBuildTutorial",false)
  for id=1,#maps do player:SetAttribute("SeenLevelTip"..id,false) end
  player:SetAttribute("ActiveLevelId",1)
  for name in pairs(settingsKeys) do player:SetAttribute(name,name=="BridgeUIScale" and 1 or true) end
  local profile,available=SaveService.Load(player)
  canSave[player]=available
  local shopData=profile and profile.Shop
  if profile and not shopData and type(profile.Completed)=="table" then
   local legacyTokens=0
   for id,entry in ipairs(maps) do if profile.Completed[id]==true then legacyTokens+=entry.Config.Progression.CompletionTokens end end
   shopData={Tokens=legacyTokens}
  end
  Shop.Load(player,shopData)
  if profile then
   player:SetAttribute("SeenBuildTutorial",profile.SeenBuildTutorial==true or (type(profile.Completed)=="table" and profile.Completed[1]==true))
   local unlocked=math.clamp(tonumber(profile.Unlocked) or 1,1,#maps)
   player:SetAttribute("UnlockedLevel",unlocked)
   if type(profile.Completed)=="table" then
    for id=1,#maps do player:SetAttribute("CompletedLevel"..id,profile.Completed[id]==true) end
   end
   for id=1,#maps do
    local seen=type(profile.SeenTips)=="table" and profile.SeenTips[id]
    if seen==nil and type(profile.Completed)=="table" then seen=profile.Completed[id] end
    player:SetAttribute("SeenLevelTip"..id,seen==true)
   end
   player:SetAttribute("CampaignComplete",player:GetAttribute("CompletedLevel"..#maps)==true)
   if type(profile.Settings)=="table" then
    for name in pairs(settingsKeys) do
     local value=profile.Settings[name]
     if name=="BridgeUIScale" then
      if type(value)=="number" and value>=.8 and value<=1.3 then player:SetAttribute(name,value) end
     elseif type(value)=="boolean" then player:SetAttribute(name,value) end
    end
   end
   if type(profile.Levels)=="table" then
    for id,controller in ipairs(controllers) do
     local data=profile.Levels[tostring(id)]
     if data and not controller.Import(player,data) then warn("Bridge Builders rejected invalid bridge save for level "..id.." user "..player.UserId) end
    end
   end
   local active=tonumber(profile.ActiveLevel)
   if active and active%1==0 and active>=1 and active<=unlocked then player:SetAttribute("ActiveLevelId",active) end
  end
  player:SetAttribute("SaveAvailable",available)
  loading[player]=nil
  player:SetAttribute("ProfileLoaded",true)
  local active=player:GetAttribute("ActiveLevelId") or 1
  controllers[active].Select(player)
  player.CharacterAdded:Connect(function(character)
   character:WaitForChild("HumanoidRootPart")
   Shop.ApplyCosmetic(player)
   if player.Character~=character or not player.Parent then return end
   local id=player:GetAttribute("ActiveLevelId") or 1
   controllers[id].Leave(player)
   controllers[id].Select(player)
   task.defer(teleport,player,id)
  end)
  if player.Character then teleport(player,active) end
 end
 Players.PlayerAdded:Connect(prepare)
 Players.PlayerRemoving:Connect(function(player)
  switching[player]=nil
  if canSave[player] then save(player) end
  for _,controller in ipairs(controllers) do controller.Remove(player) end
  Shop.Remove(player)
  loading[player]=nil;saving[player]=nil;canSave[player]=nil
 end)
 game:BindToClose(function()
  for _,player in ipairs(Players:GetPlayers()) do if canSave[player] then save(player) end end
 end)
 task.spawn(function()
  while true do
   task.wait(120)
   for _,player in ipairs(Players:GetPlayers()) do if canSave[player] and not saving[player] then task.spawn(save,player) end end
  end
 end)
 for _,player in ipairs(Players:GetPlayers()) do prepare(player) end
 local elapsed=0
 game:GetService("RunService").Heartbeat:Connect(function(dt)
  elapsed+=dt; if elapsed<.5 then return end; elapsed=0
  for _,player in ipairs(Players:GetPlayers()) do
   local id=player:GetAttribute("ActiveLevelId") or 1
   local character=player.Character
   local root=character and character:FindFirstChild("HumanoidRootPart")
   local hum=character and character:FindFirstChildOfClass("Humanoid")
   if root and hum and hum.Health>0 and not hum.Sit and root.Position.Y<maps[id].Config.Resolve().RiverCenter.Y+1 then
    root.AssemblyLinearVelocity=Vector3.zero
    teleport(player,id)
   end
  end
 end)
end
return Campaign
