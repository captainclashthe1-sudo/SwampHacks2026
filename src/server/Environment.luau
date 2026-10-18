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
	Lighting.ClockTime = 14.25
	Lighting.Brightness = 3
	Lighting.ExposureCompensation = 0.12
	Lighting.Ambient = Color3.fromRGB(142, 160, 179)
	Lighting.OutdoorAmbient = Color3.fromRGB(191, 210, 225)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 242, 220)
	Lighting.EnvironmentDiffuseScale = 0.78
	Lighting.EnvironmentSpecularScale = 0.55
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.55

	-- Roblox's built-in daytime sky; the old image faces depicted a sunset.
	local sky = effect("Sky", "Sky")
	sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
	sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
	sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
	sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
	sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
	sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
	sky.SunAngularSize = 8
	sky.CelestialBodiesShown = true

	local atmosphere = effect("Atmosphere", "Atmosphere")
	atmosphere.Color = Color3.fromRGB(198, 228, 255)
	atmosphere.Decay = Color3.fromRGB(128, 178, 218)
	atmosphere.Density = 0.18
	atmosphere.Offset = 0.18
	atmosphere.Glare = 0.12
	atmosphere.Haze = 0.6

	local color = effect("ColorCorrectionEffect", "BridgeColorGrade")
	color.Brightness = 0.02
	color.Contrast = 0.11
	color.Saturation = 0.18
	color.TintColor = Color3.fromRGB(255, 252, 244)
	color.Enabled = true

	local bloom = effect("BloomEffect", "Bloom")
	bloom.Intensity = 0.13
	bloom.Size = 24
	bloom.Threshold = 2
	bloom.Enabled = true
	local rays = effect("SunRaysEffect", "SunRays")
	rays.Intensity = 0.035
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
	clouds.Cover = 0.18
	clouds.Density = 0.27
	clouds.Color = Color3.fromRGB(255, 255, 250)

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Material = Enum.Material.Grass
		baseplate.Color = Color3.fromRGB(84, 153, 82)
	end
end

return Environment
