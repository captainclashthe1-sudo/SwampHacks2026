local Players=game:GetService("Players")
local SoundService=game:GetService("SoundService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local audio=require(ReplicatedStorage.Shared.AudioConfig)
local group=SoundService:FindFirstChild("Music") or Instance.new("SoundGroup")
group.Name="Music"; group.Volume=.5; group.Parent=SoundService
local music=Instance.new("Sound")
music.Name="BridgeCampaignMusic"; music.Looped=true; music.Volume=.35; music.SoundGroup=group; music.Parent=SoundService
local revision=0
local function refresh()
 revision+=1; local token=revision
 local id=player:GetAttribute("LevelSelected") and not player:GetAttribute("MenuOpen") and (player:GetAttribute("ActiveLevelId") or 1) or nil
 local target=id and audio.Levels[id] or audio.Menu
 if music.SoundId==target then return end
 TweenService:Create(music,TweenInfo.new(.25),{Volume=0}):Play()
 task.wait(.25)
 if token~=revision then return end
 music:Stop(); music.SoundId=target; music:Play()
 TweenService:Create(music,TweenInfo.new(.5),{Volume=.35}):Play()
end
for _,name in ipairs({"ActiveLevelId","LevelSelected","MenuOpen"}) do player:GetAttributeChangedSignal(name):Connect(refresh) end
refresh()
