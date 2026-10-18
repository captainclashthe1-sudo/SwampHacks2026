-- The environment is generated from Rojo source so every playtest has the same backdrop.
local Lighting = game:GetService("Lighting")
local Terrain = workspace.Terrain

local Environment = {}

local function effect(className, name)
	local item = Lighting:FindFirstChild(name)
	if item and not item:IsA(className) then item:Destroy(); item = nil end
	if not item then
		item = Instance.new(className)
		item.Name = name
		item.Parent = Lighting
	end
	return item
end

function Environment.Apply()
	Lighting.ClockTime = 16.2
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = 0.1
	Lighting.Ambient = Color3.fromRGB(105, 111, 127)
	Lighting.OutdoorAmbient = Color3.fromRGB(166, 178, 190)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 235, 204)
	Lighting.EnvironmentDiffuseScale = 0.65
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35

	-- Six coordinated image faces from Roblox's documented skybox example.
	local sky = effect("Sky", "Sky")
	sky.SkyboxBk = "rbxassetid://162001887"
	sky.SkyboxDn = "rbxassetid://161998893"
	sky.SkyboxFt = "rbxassetid://162001897"
	sky.SkyboxLf = "rbxassetid://162001904"
	sky.SkyboxRt = "rbxassetid://162001919"
	sky.SkyboxUp = "rbxassetid://162001926"
	sky.SunAngularSize = 11
	sky.CelestialBodiesShown = true

	local atmosphere = effect("Atmosphere", "Atmosphere")
	atmosphere.Color = Color3.fromRGB(210, 225, 236)
	atmosphere.Decay = Color3.fromRGB(153, 175, 193)
	atmosphere.Density = 0.23
	atmosphere.Offset = 0.12
	atmosphere.Glare = 0.18
	atmosphere.Haze = 1.1

	local color = effect("ColorCorrectionEffect", "BridgeColorGrade")
	color.Brightness = 0.01
	color.Contrast = 0.08
	color.Saturation = 0.08
	color.TintColor = Color3.fromRGB(255, 247, 238)
	color.Enabled = true

	local bloom = effect("BloomEffect", "Bloom")
	bloom.Intensity = 0.15
	bloom.Size = 24
	bloom.Threshold = 1.8
	bloom.Enabled = true
	local rays = effect("SunRaysEffect", "SunRays")
	rays.Intensity = 0.045
	rays.Spread = 0.75
	rays.Enabled = true
	local depth = Lighting:FindFirstChildWhichIsA("DepthOfFieldEffect")
	if depth then depth.Enabled = false end

	local clouds = Terrain:FindFirstChild("BridgeClouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Name = "BridgeClouds"
		clouds.Parent = Terrain
	end
	clouds.Cover = 0.24
	clouds.Density = 0.35
	clouds.Color = Color3.fromRGB(255, 242, 225)

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Material = Enum.Material.Grass
		baseplate.Color = Color3.fromRGB(84, 153, 82)
	end
end

return Environment
