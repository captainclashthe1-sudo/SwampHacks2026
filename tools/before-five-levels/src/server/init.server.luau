-- Re-running this generator replaces only Workspace.GeneratedLevel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LevelConfig"))
local layout = Config.Resolve()
require(script:WaitForChild("Environment")).Apply()

-- Keep the existing baseplate below the river so lower bridge joints stay visible.
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate.Position = Vector3.new(baseplate.Position.X, layout.RiverCenter.Y - baseplate.Size.Y / 2 - 4, baseplate.Position.Z)
end

local previous = workspace:FindFirstChild("GeneratedLevel")
if previous then previous:Destroy() end

local generated = Instance.new("Folder")
generated.Name = "GeneratedLevel"
local level = Instance.new("Model")
level.Name = layout.Name
level.Parent = generated

local function folder(name)
	local item = Instance.new("Folder")
	item.Name = name
	item.Parent = level
	return item
end

local function part(name, size, position, color, material, parent, canCollide, canQuery)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.Position = position
	item.Color = color
	item.Material = material
	item.Anchored = true
	item.CanCollide = canCollide
	item.CanTouch = false
	item.CanQuery = canQuery
	item.Parent = parent
	return item
end

local roadColor = Color3.fromRGB(70, 75, 82)
part("LeftPlatform", layout.PlatformSize, layout.LeftPlatform, roadColor, Enum.Material.Concrete, level, true, true)
part("RightPlatform", layout.PlatformSize, layout.RightPlatform, roadColor, Enum.Material.Concrete, level, true, true)
-- Collision surfaces follow every decorative road tile on both banks.
local leftRoadStart = layout.LeftPlatform.X - layout.PlatformSize.X / 2
local leftRoadEnd = layout.Origin.X - 150
part("LeftApproach", Vector3.new(leftRoadStart - leftRoadEnd, layout.PlatformSize.Y, layout.PlatformSize.Z),
	Vector3.new((leftRoadEnd + leftRoadStart) / 2, layout.LeftPlatform.Y, layout.LeftPlatform.Z),
	roadColor, Enum.Material.Concrete, level, true, true)
local rightRoadStart = layout.RightPlatform.X + layout.PlatformSize.X / 2
local rightRoadEnd = layout.Origin.X + 190
part("RightApproach", Vector3.new(rightRoadEnd - rightRoadStart, layout.PlatformSize.Y, layout.PlatformSize.Z),
	Vector3.new((rightRoadStart + rightRoadEnd) / 2, layout.RightPlatform.Y, layout.RightPlatform.Z),
	roadColor, Enum.Material.Concrete, level, true, true)

-- The playable valley is enclosed without putting visible walls in the camera view.
-- All four sides reach below the river and well above the player's jump height.
local limits = folder("PlayerBoundaries")
local center = layout.Origin
local halfX, halfZ = 190, 104
local wallBottom, wallTop = layout.RiverCenter.Y - 16, layout.RoadTopY + 80
local wallHeight = wallTop - wallBottom
local wallY = (wallBottom + wallTop) / 2
for _, spec in ipairs({
	{"West", Vector3.new(2, wallHeight, halfZ * 2 + 4), center + Vector3.new(-halfX, wallY, 0)},
	{"East", Vector3.new(2, wallHeight, halfZ * 2 + 4), center + Vector3.new(halfX, wallY, 0)},
	{"North", Vector3.new(halfX * 2 + 4, wallHeight, 2), center + Vector3.new(0, wallY, -halfZ)},
	{"South", Vector3.new(halfX * 2 + 4, wallHeight, 2), center + Vector3.new(0, wallY, halfZ)},
}) do
	local wall = part(spec[1] .. "InvisibleBoundary", spec[2], spec[3], roadColor,
		Enum.Material.SmoothPlastic, limits, true, false)
	wall.Transparency = 1
	wall.CastShadow = false
end

local river = part("RiverVisual", layout.RiverSize, layout.RiverCenter, Color3.fromRGB(40, 122, 192), Enum.Material.Glass, level, false, false)
-- The channel ends at the wooded valley backdrop instead of continuing to the horizon.
river.Size = Vector3.new(river.Size.X, river.Size.Y, 208)
river.Transparency = 0.32
river.CastShadow = false

local anchors = folder("BridgeAnchors")
local function anchor(name, position, markerName)
	-- The Attachment's WorldPosition is the exact bridge connection point.
	local target = part(name .. "Target", Vector3.new(0.2, 0.2, 0.2), position, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, anchors, false, true)
	target.Transparency = 1
	target:SetAttribute("BuildKind", "FixedAnchor")
	target:SetAttribute("AnchorId", name)
	local point = Instance.new("Attachment")
	point.Name = name
	point.Parent = target
	local marker = part(markerName, Vector3.new(1.5, 0.15, 1.5), position + Vector3.new(0, 0.2, 0), Color3.fromRGB(255, 202, 77), Enum.Material.Neon, anchors, false, true)
	marker.Transparency = 0.1
	marker:SetAttribute("AnchorId", name)
	local hitbox = part(name .. "Hitbox", Vector3.new(3.5, 0.6, 3.5),
		position + Vector3.new(0, 0.45, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic,
		anchors, false, true)
	hitbox.Transparency = 1
	hitbox:SetAttribute("AnchorId", name)
end
anchor("BridgeAnchor_Left", layout.LeftAnchor, "LeftAnchorMarker")
anchor("BridgeAnchor_Right", layout.RightAnchor, "RightAnchorMarker")

-- Permanent suspension towers stand over the two existing yellow road anchors.
local towers = folder("BridgeTowers")
local towerColor = Color3.fromRGB(198, 77, 56)
local towerAccent = Color3.fromRGB(241, 145, 93)
local function tower(side, foot, middle, top)
	local model = Instance.new("Model")
	model.Name = side .. "Tower"
	model.Parent = towers
	local height = Config.Tower.CapHeight - layout.RoadTopY
	for _, zOffset in ipairs({-Config.Tower.HalfWidth, Config.Tower.HalfWidth}) do
		part("Pylon", Vector3.new(1.5, height, 1.5),
			foot + Vector3.new(0, height / 2, zOffset), towerColor, Enum.Material.Metal, model, false, false)
		part("PylonStripe", Vector3.new(1.55, 0.45, 1.55),
			foot + Vector3.new(0, Config.Tower.MidHeight - layout.RoadTopY, zOffset),
			towerAccent, Enum.Material.Metal, model, false, false)
	end
	for _, y in ipairs({Config.Tower.MidHeight, Config.Tower.TopHeight, Config.Tower.CapHeight}) do
		part("Crossbar", Vector3.new(1.8, 1, Config.Tower.HalfWidth * 2 + 1.7),
			Vector3.new(foot.X, Config.Origin.Y + y, foot.Z), towerColor, Enum.Material.Metal, model, false, false)
	end
	for _, connector in ipairs({{side .. "Tower_Mid", middle}, {side .. "Tower_Top", top}}) do
		local nodeId, position = connector[1], connector[2]
		local target = part(nodeId .. "Target", Vector3.new(1.5, 1.5, 1.5), position,
			Color3.fromRGB(255, 206, 95), Enum.Material.Neon, anchors, false, true)
		target.Shape = Enum.PartType.Ball
		target:SetAttribute("BuildKind", "FixedAnchor")
		target:SetAttribute("AnchorId", nodeId)
		local attachment = Instance.new("Attachment")
		attachment.Name = nodeId
		attachment.Parent = target
	end
end
tower("Left", layout.LeftAnchor, layout.LeftTowerMid, layout.LeftTowerTop)
tower("Right", layout.RightAnchor, layout.RightTowerMid, layout.RightTowerTop)

local zone = folder("BuildZone")
local zoneSize = layout.ZoneMax - layout.ZoneMin
local zoneCenter = (layout.ZoneMin + layout.ZoneMax) / 2
local bounds = part("BuildZoneBounds", zoneSize, zoneCenter, Color3.fromRGB(53, 235, 213), Enum.Material.SmoothPlastic, zone, false, false)
bounds.Transparency = 1
for _, axis in ipairs({"X", "Y", "Z"}) do
	bounds:SetAttribute("Min" .. axis, layout.ZoneMin[axis])
	bounds:SetAttribute("Max" .. axis, layout.ZoneMax[axis])
end

local edgeColor = Color3.fromRGB(64, 241, 214)
local thickness = 0.16
local function edge(name, size, position)
	local item = part(name, size, position, edgeColor, Enum.Material.Neon, zone, false, false)
	item.Transparency = 0.12
end
for _, y in ipairs({layout.ZoneMin.Y, layout.ZoneMax.Y}) do
	for _, z in ipairs({layout.ZoneMin.Z, layout.ZoneMax.Z}) do
		edge("X Boundary Edge", Vector3.new(zoneSize.X, thickness, thickness), Vector3.new(zoneCenter.X, y, z))
	end
	for _, x in ipairs({layout.ZoneMin.X, layout.ZoneMax.X}) do
		edge("Z Boundary Edge", Vector3.new(thickness, thickness, zoneSize.Z), Vector3.new(x, y, zoneCenter.Z))
	end
end
for _, x in ipairs({layout.ZoneMin.X, layout.ZoneMax.X}) do
	for _, z in ipairs({layout.ZoneMin.Z, layout.ZoneMax.Z}) do
		edge("Vertical Boundary Edge", Vector3.new(thickness, zoneSize.Y, thickness), Vector3.new(x, zoneCenter.Y, z))
	end
end

local function label(parent, text, offset, color, width)
	-- A visible, non-blocking sign works in Studio and during play.
	local signWidth = width or 7
	local sign = part(text:gsub(" ", "") .. "Sign", Vector3.new(signWidth, 2.5, 0.25), parent.Position + offset, Color3.fromRGB(19, 32, 45), Enum.Material.SmoothPlastic, parent, false, false)
	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = face.Name .. "Label"
		gui.Face = face
		gui.CanvasSize = Vector2.new(512, 160)
		gui.LightInfluence = 0
		gui.Parent = sign
		local textLabel = Instance.new("TextLabel")
		textLabel.Name = "Text"
		textLabel.Size = UDim2.fromScale(1, 1)
		textLabel.BackgroundTransparency = 1
		textLabel.TextColor3 = color
		textLabel.TextScaled = true
		textLabel.Font = Enum.Font.GothamBold
		textLabel.Text = text
		textLabel.Parent = gui
	end
end

local markers = folder("Markers")
local function positionMarker(name, position, sign)
	local target = part(name, Vector3.new(0.3, 0.3, 0.3), position, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, markers, false, true)
	target.Transparency = 1
	label(target, sign, Vector3.new(0, 4, 0), Color3.new(1, 1, 1))
end
positionMarker("VehicleStart", layout.VehicleStart, "START")
positionMarker("VehicleFinish", layout.VehicleFinish, "FINISH")
local zoneSign = part("BuildZoneLabelPoint", Vector3.new(0.2, 0.2, 0.2), Vector3.new(zoneCenter.X, layout.ZoneMax.Y, zoneCenter.Z), edgeColor, Enum.Material.SmoothPlastic, markers, false, false)
zoneSign.Transparency = 1
label(zoneSign, "BUILD ZONE", Vector3.new(0, 2, 0), edgeColor, 11)

-- An existing spawn outside this generated folder is never moved or deleted.
local existingSpawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
if existingSpawn then
	local p = existingSpawn.Position
	local roadMinX = layout.LeftPlatform.X - layout.PlatformSize.X / 2
	local roadMaxX = layout.LeftPlatform.X + layout.PlatformSize.X / 2
	local roadMinZ = layout.LeftPlatform.Z - layout.PlatformSize.Z / 2
	local roadMaxZ = layout.LeftPlatform.Z + layout.PlatformSize.Z / 2
	local safe = p.X >= roadMinX and p.X <= roadMaxX and p.Z >= roadMinZ and p.Z <= roadMaxZ and p.Y - existingSpawn.Size.Y / 2 >= layout.RoadTopY - 0.1
	if not safe then
		warn("Existing SpawnLocation is unsuitable for River Crossing 01; position: " .. tostring(p))
	end
else
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StartSpawn"
	spawn.Size = layout.SpawnSize
	spawn.Position = layout.SpawnSurface + Vector3.new(0, layout.SpawnSize.Y / 2, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.CastShadow = false
	spawn.Color = roadColor
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Parent = level
	for _, visual in ipairs(spawn:GetDescendants()) do
		if visual:IsA("Decal") then visual.Transparency = 1 end
	end
end

generated.Parent = workspace

require(script:WaitForChild("BuildServer")).Start(level)

-- Decorative Blender models are generated from Rojo-tracked mesh data.
task.spawn(function()
	local ok, errorMessage = pcall(function()
		require(script:WaitForChild("SceneAssets")).Place(level, layout)
	end)
	if not ok then warn("Lowpoly scenery failed: " .. tostring(errorMessage)) end
end)
