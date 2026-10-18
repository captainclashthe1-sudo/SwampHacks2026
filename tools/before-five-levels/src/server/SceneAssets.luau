local Assets = require(script.Parent:WaitForChild("LowpolyAssets"))

local SceneAssets = {}

local function support(parent, name, center, size, color, material)
	local ground = Instance.new("Part")
	ground.Name = name
	ground.Anchored = true
	ground.Size = size
	ground.Position = center
	ground.Material = material or Enum.Material.Grass
	ground.Color = color
	ground.CanTouch = false
	ground.Parent = parent
	return ground
end

function SceneAssets.Place(level, layout)
	local scenery = Instance.new("Folder")
	scenery.Name = "LowpolyScenery"
	scenery.Parent = level
	local top = layout.RoadTopY
	local centerZ = layout.Origin.Z
	local grass = Color3.fromRGB(84, 153, 82)
	local earth = Color3.fromRGB(107, 98, 79)
	local stone = Color3.fromRGB(112, 119, 114)
	local baseplate = workspace:FindFirstChild("Baseplate")
	local floorY = baseplate and baseplate.Position.Y + baseplate.Size.Y / 2 - 1 or layout.RiverCenter.Y - 5
	local west = baseplate and baseplate.Position.X - baseplate.Size.X / 2 or layout.Origin.X - 1024
	local east = baseplate and baseplate.Position.X + baseplate.Size.X / 2 or layout.Origin.X + 1024
	local depth = baseplate and baseplate.Size.Z or 2048
	local groundZ = baseplate and baseplate.Position.Z or centerZ
	local leftEdge = layout.LeftAnchor.X
	local rightEdge = layout.RightAnchor.X
	local surfaceY = top - 0.35 -- Keep the approach roads visible above the grass.
	local function groundLayer(name, x0, x1, highestY, color, material)
		local height = highestY - floorY
		if height <= 0 then return end
		support(scenery, name, Vector3.new((x0 + x1) / 2, floorY + height / 2, groundZ),
			Vector3.new(x1 - x0, height, depth), color, material)
	end
	-- Solid mainland reaches the baseplate. The river cuts through it under the bridge.
	groundLayer("LeftMainland", west, leftEdge, surfaceY - 0.65, earth, Enum.Material.Ground)
	groundLayer("RightMainland", rightEdge, east, surfaceY - 0.65, earth, Enum.Material.Ground)
	support(scenery, "LeftGrass", Vector3.new((west + leftEdge) / 2, surfaceY - 0.325, groundZ),
		Vector3.new(leftEdge - west, 0.65, depth), grass)
	support(scenery, "RightGrass", Vector3.new((rightEdge + east) / 2, surfaceY - 0.325, groundZ),
		Vector3.new(east - rightEdge, 0.65, depth), grass)
	-- Stepped rock banks lead from the road down to the waterline.
	for _, tier in ipairs({{0, 5, top - 5}, {5, 10, top - 10}, {10, 13, top - 15}}) do
		local inner, outer, height = tier[1], tier[2], tier[3]
		groundLayer("LeftRiverBank", leftEdge + inner, leftEdge + outer, height, stone, Enum.Material.Slate)
		groundLayer("RightRiverBank", rightEdge - outer, rightEdge - inner, height, stone, Enum.Material.Slate)
	end

	-- Rounded, staggered ridges close the horizon around the playable valley.
	local backdrop = Instance.new("Folder")
	backdrop.Name = "ValleyBackdrop"
	backdrop.Parent = scenery
	local function hill(name, position, size, color)
		local p = support(backdrop, name, position, size, color, Enum.Material.Grass)
		p.Shape = Enum.PartType.Ball
		p.CanCollide = false
		p.CanQuery = false
	end
	for x = -200, 200, 40 do
		local variant = math.floor((x + 200) / 40) % 3
		local rise = ({42, 53, 46})[variant + 1]
		for _, side in ipairs({-1, 1}) do
			hill("WoodedRidge", Vector3.new(layout.Origin.X + x, floorY + rise * 0.38, centerZ + side * 117),
				Vector3.new(70, rise, 54), Color3.fromRGB(57 + variant * 7, 120 + variant * 7, 69 + variant * 5))
		end
	end
	for _, side in ipairs({-1, 1}) do
		for z = -100, 100, 40 do
			hill("EndRidge", Vector3.new(layout.Origin.X + side * 209, floorY + 22, centerZ + z),
				Vector3.new(56, 54, 64), Color3.fromRGB(62, 128, 76))
		end
	end

	local placements = {
		{"Road_Straight", -90, 0, math.pi / 2},
		{"Road_Intersection", -130, 0, 0},
		{"Road_Straight", -50, 0, math.pi / 2},
		{"Road_Straight", 50, 0, math.pi / 2},
		{"Road_Straight", 90, 0, math.pi / 2},
		{"Road_Straight", 130, 0, math.pi / 2},
		{"Road_Corner", 170, 0, math.pi},
		{"Car_Red", -126, -8, math.pi / 2},
		{"Car_Blue", 118, 19, -math.pi / 2},
		{"Road_Barrier", -35, -10, math.pi / 2},
		{"Road_Barrier", 35, 10, math.pi / 2},
		{"Traffic_Cone", -36, 10, 0},
		{"Traffic_Cone", 36, -10, 0},
		{"Stop_Sign", -85, -18, 0},
		{"Street_Lamp", -74, 18, 0},
		{"Street_Lamp", 74, -18, math.pi},
		{"Fire_Hydrant", -76, -20, 0},
		{"Park_Bench", 76, 23, math.pi / 2},
		{"Picket_Fence", -75, 30, 0},
		{"Picket_Fence", 75, -30, 0},
		{"Tree_Round", -100, 32, 0},
		{"Tree_Round", 93, -34, 0},
		{"Tree_Round", -151, 48, 0},
		{"Tree_Round", 150, -48, 0},
		{"Tree_Pine", -118, -34, 0},
		{"Tree_Pine", 116, 36, 0},
		{"Tree_Pine", -154, -43, 0},
		{"Tree_Pine", 154, 43, 0},
		{"Bush", -95, -30, 0},
		{"Bush", 99, 31, 0},
		{"Bush", -143, 29, 0},
		{"Bush", 145, -30, 0},
		{"Rock_Large", -121, 29, 0},
		{"Rock_Small", 125, -28, 0},
		{"Grass_Tuft", -105, 26, 0},
		{"Grass_Tuft", 108, -24, 0},
	}
	-- A compact tree line hides the foot of the ridge and frames both approaches.
	for x = -170, 170, 28 do
		-- Leave the river channel between the two anchor banks clear.
		if math.abs(x) < math.abs(rightEdge - leftEdge) / 2 + 8 then continue end
		local stagger = math.floor((x + 170) / 28) % 2
		for _, side in ipairs({-1, 1}) do
			table.insert(placements, {stagger == 0 and "Tree_Pine" or "Tree_Round", x,
				side * (76 + stagger * 9), 0})
		end
	end
	for _, item in ipairs(placements) do
		local name, x, z, yaw = item[1], item[2], item[3], item[4]
		local model = Assets.Place(name, scenery, Vector3.new(layout.Origin.X + x, top, centerZ + z), yaw)
		if name == "Street_Lamp" then
			local bulb = model:FindFirstChild("Street_Lamp_Bulb")
			if bulb and bulb:IsA("BasePart") then
				bulb.Material = Enum.Material.Neon
				local light = Instance.new("PointLight")
				light.Range = 24
				light.Brightness = 0.7
				light.Parent = bulb
			end
		elseif name == "Road_Barrier" then
			local lights = model:FindFirstChild("Road_Barrier_Lights")
			if lights and lights:IsA("BasePart") then lights.Material = Enum.Material.Neon end
		end
	end
	scenery:SetAttribute("Ready", true)
	return scenery
end

return SceneAssets
