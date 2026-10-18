-- Short Creator Store effects, verified to load in this place.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local group = SoundService:FindFirstChild("SFX") or Instance.new("SoundGroup")
group.Name = "SFX"
if not group.Parent then group.Volume = 0.5 end
group.Parent = SoundService

local sounds = {
	Click = {110948579458469, 0.42, 1},
	Joint = {17779566040, 0.28, 1.1},
	WoodPlace = {9114559697, 0.5, 1},
	SteelPlace = {9125670606, 0.34, 1.3},
	ConcretePlace = {9118628895, 0.4, 1},
	WoodBreak = {9120801590, 0.7, 1},
	SteelBreak = {9116546593, 0.55, 1},
	ConcreteBreak = {9118628895, 0.7, 0.75},
	Collapse = {9120829193, 0.4, 1},
	Fail = {97861773515321, 0.6, 1},
	Win = {9067124098, 0.65, 1},
	Purchase = {100813529228543, 0.5, 1},
}

local Sfx = {}

function Sfx.Play(name)
	if player:GetAttribute("SoundEnabled") == false then return end
	local definition = sounds[name]
	if not definition then return end
	local sound = Instance.new("Sound")
	sound.Name = "Bridge" .. name
	sound.SoundId = "rbxassetid://" .. definition[1]
	sound.Volume = definition[2]
	sound.PlaybackSpeed = definition[3]
	sound.SoundGroup = group
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 8)
end

return Sfx
