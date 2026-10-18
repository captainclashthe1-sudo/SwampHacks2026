-- Game-style strength rules layered on top of Roblox physics. This is not an engineering solver.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LevelConfig"))
local Assets = require(script.Parent:WaitForChild("LowpolyAssets"))

local SimulationServer = {}
local rules = Config.Simulation
local LEFT = "BridgeAnchor_Left"
local RIGHT = "BridgeAnchor_Right"
local level
local anchors
local copiesFolder
local carsFolder
local cars = {}
local sessions = {}

local function ensureCar(player)
	if cars[player.UserId] then return cars[player.UserId] end
	local layout = Config.Resolve()
	local start = CFrame.new(layout.VehicleStart + Vector3.new(10, 0, 0)) * CFrame.Angles(0, math.pi / 2, 0)
	local model = Assets.Clone("Car_Yellow")
	model.Name = "TestCar_" .. player.UserId
	model:ScaleTo(0.75)
	model:PivotTo(start)
	model:SetAttribute("OwnerUserId", player.UserId)
	local chassis = Instance.new("Part")
	chassis.Name = "PhysicsChassis"
	chassis.Size = Vector3.new(4.8, 1.5, 10)
	chassis.CFrame = start * CFrame.new(0, 1.7, 0)
	chassis.Transparency = 1
	chassis.Anchored = true
	chassis.CanCollide = false
	chassis.CollisionGroup = "BridgeSimulationLoad"
	chassis.CustomPhysicalProperties = PhysicalProperties.new(2, 0.8, 0)
	chassis:SetAttribute("OwnerUserId", player.UserId)
	chassis.Parent = model
	for _, x in ipairs({-1.8, 1.8}) do
		for _, z in ipairs({-3.7, 3.7}) do
			local wheel = Instance.new("Part")
			wheel.Name = "WheelCollider"
			wheel.Shape = Enum.PartType.Ball
			wheel.Size = Vector3.new(2, 2, 2)
			wheel.CFrame = start * CFrame.new(x, 1, z)
			wheel.Transparency = 1
			wheel.Anchored = false
			wheel.CanCollide = true
			wheel.CanTouch = false
			wheel.CollisionGroup = "BridgeSimulationLoad"
			wheel.CustomPhysicalProperties = PhysicalProperties.new(1, 0.9, 0)
			wheel.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = chassis
			weld.Part1 = wheel
			weld.Parent = chassis
		end
	end
	for _, visual in ipairs(model:GetDescendants()) do
		if visual:IsA("BasePart") and visual ~= chassis and visual.Name ~= "WheelCollider" then
			visual.Anchored = false
			visual.Massless = true
			visual.CanCollide = false
			visual.CanTouch = false
			visual.CanQuery = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = chassis
			weld.Part1 = visual
			weld.Parent = chassis
		end
	end
	local seat = Instance.new("Seat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 0.5, 2)
	-- The Blender car's front is local +Z; face the driver toward that front.
	seat.CFrame = start * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, math.pi, 0)
	seat.Transparency = 1
	seat.Anchored = false
	seat.CanCollide = false
	seat.Parent = model
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = chassis
	seatWeld.Part1 = seat
	seatWeld.Parent = chassis
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterCar"
	prompt.ActionText = "Enter car"
	prompt.ObjectText = "Yellow bridge test car"
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0.25
	prompt.RequiresLineOfSight = false
	prompt.Parent = chassis
	prompt.Triggered:Connect(function(requester)
		if requester ~= player or sessions[player.UserId] then return end
		local humanoid = requester.Character and requester.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not seat.Occupant then seat:Sit(humanoid) end
	end)
	model.Parent = carsFolder
	local car = {Model = model, Chassis = chassis, Seat = seat, Prompt = prompt, Start = start}
	cars[player.UserId] = car
	return car
end

local function reply(ok, message)
	return {ok = ok, message = message}
end

local function wallet(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local cash = stats:FindFirstChild("Cash")
	if not cash then
		cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = Config.Budget.Starting
		cash.Parent = stats
	end
	local wins = stats:FindFirstChild("Wins")
	if not wins then
		wins = Instance.new("IntValue")
		wins.Name = "Wins"
		wins.Parent = stats
	end
	player:SetAttribute("Cash", cash.Value)
	return cash, wins
end

local function anchorPart(nodeId)
	return anchors:FindFirstChild(nodeId .. "Target")
end

local function nodePosition(state, nodeId)
	local fixed = anchorPart(nodeId)
	if fixed then return fixed.Position end
	local joint = state.Joints[nodeId]
	return joint and joint.Position
end

local supportCount

local function supportRelianceFactor(material, count)
	return 1 + (material.SupportReliance or 0) / (1 + 2 * count)
end

local function routeFor(state)
	local adjacency = {}
	local degree = {}
	for _, beam in pairs(state.Beams) do
		if (beam:GetAttribute("MemberRole") or "Deck") ~= "Deck" then continue end
		local a = beam:GetAttribute("StartNodeId")
		local b = beam:GetAttribute("EndNodeId")
		if nodePosition(state, a) and nodePosition(state, b) then
			adjacency[a] = adjacency[a] or {}
			adjacency[b] = adjacency[b] or {}
			table.insert(adjacency[a], {Next = b, Beam = beam})
			table.insert(adjacency[b], {Next = a, Beam = beam})
			degree[a] = (degree[a] or 0) + 1
			degree[b] = (degree[b] or 0) + 1
		end
	end
	if not adjacency[LEFT] or not adjacency[RIGHT] then return nil end

	-- Prefer the connected route with the lowest peak stress, then the shortest length.
	local best = {[LEFT] = {Peak = 0, Length = 0}}
	local previous = {}
	local visited = {}
	while true do
		local current, currentScore
		for nodeId, score in pairs(best) do
			if not visited[nodeId] and (not currentScore or score.Peak < currentScore.Peak
				or (score.Peak == currentScore.Peak and score.Length < currentScore.Length)) then
				current, currentScore = nodeId, score
			end
		end
		if not current or current == RIGHT then break end
		visited[current] = true
		for _, link in ipairs(adjacency[current] or {}) do
			local nextId = link.Next
			local beam = link.Beam
			local length = (nodePosition(state, current) - nodePosition(state, nextId)).Magnitude
			local material = beam:GetAttribute("MaterialType")
			local properties = rules.Materials[material]
			local strength = properties and properties.Bend
			if strength then
				local connectionFactor = 1
				if current ~= LEFT and current ~= RIGHT and (degree[current] or 0) <= 2 then connectionFactor += 0.1 end
				if nextId ~= LEFT and nextId ~= RIGHT and (degree[nextId] or 0) <= 2 then connectionFactor += 0.1 end
				local bracing = supportCount(state, current) + supportCount(state, nextId)
				local stress = rules.LoadWeight * (length / rules.ReferenceSpan) ^ 2 * connectionFactor
					* supportRelianceFactor(properties, bracing) / (1 + 0.3 * math.min(bracing, 3))
				local candidate = {Peak = math.max(currentScore.Peak, stress / strength), Length = currentScore.Length + length}
				local old = best[nextId]
				if not old or candidate.Peak < old.Peak
					or (candidate.Peak == old.Peak and candidate.Length < old.Length) then
					best[nextId] = candidate
					previous[nextId] = {From = current, Beam = beam, Stress = stress, Strength = strength}
				end
			end
		end
	end
	if not previous[RIGHT] then return nil end
	local reversed = {}
	local nodeId = RIGHT
	while nodeId ~= LEFT do
		local step = previous[nodeId]
		if not step then return nil end
		table.insert(reversed, {
			From = step.From, To = nodeId, Beam = step.Beam,
			Stress = step.Stress, Strength = step.Strength,
			FromPosition = nodePosition(state, step.From), ToPosition = nodePosition(state, nodeId),
		})
		nodeId = step.From
	end
	local route = {}
	for index = #reversed, 1, -1 do table.insert(route, reversed[index]) end
	return route
end

local function restoreOriginals(session)
	for _, saved in ipairs(session.Hidden) do
		local part = saved.Part
		if part and part.Parent then
			part.Transparency = saved.Transparency
			part.CanCollide = saved.CanCollide
			part.CanQuery = saved.CanQuery
		end
	end
end

local function cleanup(player)
	local session = sessions[player.UserId]
	if not session then return end
	sessions[player.UserId] = nil
	if session.Connection then session.Connection:Disconnect() end
	if session.Drive then session.Drive:Destroy() end
	if session.DriveAttachment then session.DriveAttachment:Destroy() end
	for _, attachment in ipairs(session.AnchorAttachments) do attachment:Destroy() end
	if session.Root then session.Root:Destroy() end
	restoreOriginals(session)
	local car = cars[player.UserId]
	if car and car.Model.Parent then
		local occupant = car.Seat.Occupant
		if occupant then
			occupant.Sit = false
			local root = occupant.Parent and occupant.Parent:FindFirstChild("HumanoidRootPart")
			if root then root.CFrame = CFrame.new(Config.Resolve().SpawnSurface + Vector3.new(0, 4, 0)) end
		end
		car.Chassis.Anchored = true
		car.Chassis.AssemblyLinearVelocity = Vector3.zero
		car.Chassis.AssemblyAngularVelocity = Vector3.zero
		car.Model:PivotTo(car.Start)
		car.Prompt.Enabled = true
	end
end

local function makeAttachment(part, worldPosition)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	-- RigidConstraint aligns both position and orientation, so both ends need the same world frame.
	attachment.WorldCFrame = CFrame.new(worldPosition)
	return attachment
end

local function makeStressMeter(beam)
	local meter = Instance.new("BillboardGui")
	meter.Name = "StressMeter"
	meter.Adornee = beam
	meter.AlwaysOnTop = true
	meter.MaxDistance = 150
	meter.Size = UDim2.fromOffset(100, 31)
	meter.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	meter.Parent = beam
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(19, 29, 37)
	background.BackgroundTransparency = 0.1
	background.BorderSizePixel = 0
	background.Parent = meter
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Position = UDim2.fromOffset(3, 19)
	fill.Size = UDim2.fromOffset(0, 8)
	fill.BackgroundColor3 = Color3.fromRGB(75, 224, 136)
	fill.BorderSizePixel = 0
	fill.Parent = background
	local label = Instance.new("TextLabel")
	label.Name = "Percent"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -6, 0, 17)
	label.Position = UDim2.fromOffset(3, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "0% stress"
	label.Parent = background
	return fill, label
end

local function makeJointMeter(joint)
	local meter = Instance.new("BillboardGui")
	meter.Name = "JointForceMeter"
	meter.Adornee = joint
	meter.AlwaysOnTop = true
	meter.MaxDistance = 130
	meter.Size = UDim2.fromOffset(156, 24)
	meter.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	meter.Parent = joint
	local label = Instance.new("TextLabel")
	label.Name = "ForceLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(19, 29, 37)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(255, 220, 124)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.Text = "G ↓0.0   Load ↓0.0"
	label.Parent = meter
	return label
end

local function supportReachable(state, fromNode, blockedNode, seen)
	if anchorPart(fromNode) then return true end
	if fromNode == blockedNode or seen[fromNode] then return false end
	seen[fromNode] = true
	for _, beam in pairs(state.Beams) do
		if (beam:GetAttribute("MemberRole") or "Deck") ~= "Deck" then
			local a, b = beam:GetAttribute("StartNodeId"), beam:GetAttribute("EndNodeId")
			local nextNode = a == fromNode and b or b == fromNode and a or nil
			if nextNode and supportReachable(state, nextNode, blockedNode, seen) then return true end
		end
	end
	return false
end

supportCount = function(state, nodeId)
	if anchorPart(nodeId) then return 0 end
	local count = 0
	for _, beam in pairs(state.Beams) do
		if (beam:GetAttribute("MemberRole") or "Deck") ~= "Deck" then
			local a, b = beam:GetAttribute("StartNodeId"), beam:GetAttribute("EndNodeId")
			local nextNode = a == nodeId and b or b == nodeId and a or nil
			if nextNode and supportReachable(state, nextNode, nodeId, {}) then count += 1 end
		end
	end
	return count
end

local function makeVisuals(state, session)
	session.VisualJoints = {}
	session.VisualBeams = {}
	local loadBearing = {}
	for _, step in ipairs(session.Route) do loadBearing[step.From] = true; loadBearing[step.To] = true end
	for _ = 1, 100 do
		local changed = false
		for _, beam in pairs(state.Beams) do
			local a, b = beam:GetAttribute("StartNodeId"), beam:GetAttribute("EndNodeId")
			if loadBearing[a] and not loadBearing[b] then loadBearing[b] = true; changed = true end
			if loadBearing[b] and not loadBearing[a] then loadBearing[a] = true; changed = true end
		end
		if not changed then break end
	end
	for nodeId, original in pairs(state.Joints) do
		local visual = original:Clone()
		visual.Name = "DeflectingJoint"
		visual.Anchored = true
		visual.CollisionGroup = "Default"
		visual.CanCollide = false
		visual.CanQuery = false
		visual.Parent = session.Root
		local mass, stiffness, count = 0, 0, 0
		for _, beam in pairs(state.Beams) do
			if beam:GetAttribute("StartNodeId") == nodeId or beam:GetAttribute("EndNodeId") == nodeId then
				local material = rules.Materials[beam:GetAttribute("MaterialType")]
				if material then
					local role = beam:GetAttribute("MemberRole") or "Deck"
					local roleWeight = role == "Deck" and 1 or role == "Arch" and 0.7 or 0.25
					mass += 0.5 * material.Density * beam.Size.Z / rules.ReferenceSpan * roleWeight
					stiffness += material.Stiffness * roleWeight
					count += roleWeight
				end
			end
		end
		local meter = makeJointMeter(visual)
		session.VisualJoints[nodeId] = {
			Part = visual, Meter = meter, Rest = original.Position, Sag = 0,
			LoadBearing = loadBearing[nodeId] == true,
			Mass = mass, Stiffness = math.max(0.75, stiffness / math.max(count, 0.1) + 0.45 * supportCount(state, nodeId)),
		}
		session.CopiedNodes[nodeId].Transparency = 1
		session.CopiedNodes[nodeId].CanCollide = false
	end
	for beamId, original in pairs(state.Beams) do
		local role = original:GetAttribute("MemberRole") or "Deck"
		local visual = original:Clone()
		visual.Name = "DeflectingBeam"
		visual.Anchored = true
		visual.CollisionGroup = "Default"
		visual.CanCollide = role == "Deck"
		visual.CanQuery = false
		visual.Parent = session.Root
		local parallel = visual:FindFirstChild("ParallelCable")
		if parallel then parallel.CanQuery = false end
		local second
		if role == "Deck" then
			second = visual:Clone()
			second.Name = "DeflectingBeamSecondHalf"
			second.Parent = session.Root
		end
		session.VisualBeams[beamId] = {First = visual, Second = second, Parallel = parallel}
		session.CopiedBeams[beamId].Transparency = 1
		session.CopiedBeams[beamId].CanCollide = false
		local copiedParallel = session.CopiedBeams[beamId]:FindFirstChild("ParallelCable")
		if copiedParallel then copiedParallel.Transparency = 1; copiedParallel.CanCollide = false end
	end
end

local function makeRecords(state, session)
	local records = {}
	for beamId, original in pairs(state.Beams) do
		local copied = session.CopiedBeams[beamId]
		local visual = session.VisualBeams[beamId]
		local a, b = original:GetAttribute("StartNodeId"), original:GetAttribute("EndNodeId")
		local first, last = nodePosition(state, a), nodePosition(state, b)
		local role = original:GetAttribute("MemberRole") or "Deck"
		local materialName = original:GetAttribute("MaterialType")
		local material = rules.Materials[materialName]
		if copied and visual and first and last and material then
			copied.CustomPhysicalProperties = PhysicalProperties.new(material.Density, 0.6, 0.2)
			local fill, label = makeStressMeter(visual.First)
			table.insert(records, {
				Id = beamId, Part = copied, Visual = visual.First, VisualSecond = visual.Second, VisualParallel = visual.Parallel,
				FirstId = a, LastId = b,
				First = first, Last = last, Length = (last - first).Magnitude,
				Role = role, MaterialName = materialName, Material = material,
				SupportCount = role == "Deck" and supportCount(state, a) + supportCount(state, b) or 0,
				Cable = session.CableLinks[beamId],
				Fill = fill, Label = label,
			})
		end
	end
	session.Records = records
end

local function makeCopies(player, state, session)
	local root = Instance.new("Folder")
	root.Name = tostring(player.UserId)
	root:SetAttribute("OwnerUserId", player.UserId)
	session.Root = root
	local copiedNodes = {}
	local copiedBeams = {}
	session.CableLinks = {}
	for nodeId, original in pairs(state.Joints) do
		local joint = original:Clone()
		joint.Name = "SimulationJoint"
		joint.Anchored = false
		joint.CanCollide = false
		joint.CanQuery = false
		joint.Parent = root
		copiedNodes[nodeId] = joint
	end
	session.CopiedNodes = copiedNodes
	for beamId, original in pairs(state.Beams) do
		local beam = original:Clone()
		beam.Name = "SimulationBeam"
		local isCable = original:GetAttribute("MemberRole") == "Support"
		beam.Anchored = isCable
		beam.CollisionGroup = "Default"
		beam.CanCollide = not isCable and original.CanCollide
		beam.CanQuery = false
		beam.Parent = root
		copiedBeams[beamId] = beam
	end
	session.CopiedBeams = copiedBeams
	for beamId, original in pairs(state.Beams) do
		local beam = copiedBeams[beamId]
		local role = original:GetAttribute("MemberRole") or "Deck"
		local cableEnds = {}
		for _, nodeId in ipairs({original:GetAttribute("StartNodeId"), original:GetAttribute("EndNodeId")}) do
			local fixed = anchorPart(nodeId)
			local node = fixed or copiedNodes[nodeId]
			if node then
				local point = nodePosition(state, nodeId)
				local onNode = makeAttachment(node, point)
				if fixed then table.insert(session.AnchorAttachments, onNode) end
				if role == "Support" then
					table.insert(cableEnds, node)
				else
					local onBeam = makeAttachment(beam, point)
					local constraint = Instance.new("RigidConstraint")
					constraint.Name = "BridgeConnection"
					constraint.Attachment0 = onBeam
					constraint.Attachment1 = onNode
					constraint.Parent = beam
					table.insert(session.Constraints, constraint)
				end
			end
		end
		if role == "Support" and #cableEnds == 2 then
			local ropes = {}
			for _, side in ipairs({-1, 1}) do
				local offset = Vector3.new(0, 0, side * Config.Road.Width / 2)
				local first = makeAttachment(cableEnds[1], nodePosition(state, original:GetAttribute("StartNodeId")) + offset)
				local last = makeAttachment(cableEnds[2], nodePosition(state, original:GetAttribute("EndNodeId")) + offset)
				if anchorPart(original:GetAttribute("StartNodeId")) then table.insert(session.AnchorAttachments, first) end
				if anchorPart(original:GetAttribute("EndNodeId")) then table.insert(session.AnchorAttachments, last) end
				local rope = Instance.new("RopeConstraint")
				rope.Name = "TensionCable"
				rope.Attachment0 = first
				rope.Attachment1 = last
				rope.Length = original.Size.Z * 1.005
				rope.Thickness = 0.25
				rope.Visible = false
				rope.Parent = beam
				table.insert(ropes, rope)
				table.insert(session.Constraints, rope)
			end
			session.CableLinks[beamId] = {
				Rope = ropes[1], Ropes = ropes, RestLength = original.Size.Z,
			}
		end
	end
	makeVisuals(state, session)
	makeRecords(state, session)
	for _, original in pairs(state.Joints) do
		table.insert(session.Hidden, {Part = original, Transparency = original.Transparency, CanCollide = original.CanCollide, CanQuery = original.CanQuery})
	end
	for _, original in pairs(state.Beams) do
		table.insert(session.Hidden, {Part = original, Transparency = original.Transparency, CanCollide = original.CanCollide, CanQuery = original.CanQuery})
		local parallel = original:FindFirstChild("ParallelCable")
		if parallel then
			table.insert(session.Hidden, {Part = parallel, Transparency = parallel.Transparency, CanCollide = parallel.CanCollide, CanQuery = parallel.CanQuery})
		end
	end
	for _, saved in ipairs(session.Hidden) do
		saved.Part.Transparency = 1
		saved.Part.CanCollide = false
		saved.Part.CanQuery = false
	end
	root.Parent = copiesFolder
	for _, part in pairs(copiedNodes) do pcall(function() part:SetNetworkOwner(nil) end) end
	for _, part in pairs(copiedBeams) do pcall(function() part:SetNetworkOwner(nil) end) end

	local car = assert(cars[player.UserId], "Test car is missing")
	local load = car.Chassis
	car.Prompt.Enabled = false
	load.Anchored = false
	pcall(function() load:SetNetworkOwner(nil) end)
	local driveAttachment = Instance.new("Attachment")
	driveAttachment.Parent = load
	local drive = Instance.new("VectorForce")
	drive.Name = "TestLoadDrive"
	drive.Attachment0 = driveAttachment
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.ApplyAtCenterOfMass = true
	drive.Parent = load
	session.Load = load
	session.Drive = drive
	session.DriveAttachment = driveAttachment
end

local function burst(session, position)
	local marker = Instance.new("Part")
	marker.Name = "BreakFlash"
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(3, 3, 3)
	marker.Position = position
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 72, 40)
	marker.Transparency = 0.2
	marker.Parent = session.Root
	local light = Instance.new("PointLight")
	light.Color = marker.Color
	light.Range = 16
	light.Brightness = 4
	light.Parent = marker
	task.delay(0.5, function() if marker.Parent then marker:Destroy() end end)
end

local function stopMotion(session)
	if session.Connection then session.Connection:Disconnect(); session.Connection = nil end
	if session.Drive then session.Drive.Force = Vector3.zero end
end

local function breakBridge(player, session, record, ratio)
	session.Phase = "Collapsing"
	session.BrokenCount += 1
	session.Message = string.format("%s %s broke at %d%% stress.", record.MaterialName, record.Role:lower(), math.floor(ratio * 100))
	local copied = record.Visual
	if copied then
		copied.Color = Color3.fromRGB(255, 70, 55)
		copied.Material = Enum.Material.Neon
		burst(session, copied.Position)
	end
	-- Transfer the bent display pose to the temporary physics copy before release.
	for _, constraint in ipairs(session.Constraints) do constraint:Destroy() end
	for nodeId, joint in pairs(session.VisualJoints) do
		local physical = session.CopiedNodes[nodeId]
		physical.Position = joint.Part.Position
		physical.Transparency = 0
		joint.Part:Destroy()
	end
	for _, member in ipairs(session.Records) do
		member.Part.CFrame = member.Visual.CFrame
		member.Part.Size = member.Visual.Size
		member.Part.Transparency = 0
		member.Part.CanCollide = member.Role == "Deck"
		member.Part.Anchored = false
		local parallel = member.Part:FindFirstChild("ParallelCable")
		if parallel and member.VisualParallel then
			parallel.CFrame = member.VisualParallel.CFrame
			parallel.Size = member.VisualParallel.Size
			parallel.Transparency = 0
			parallel.Anchored = false
		end
		if member.VisualSecond then
			local second = member.Part:Clone()
			second.Name = "FallingBeamSecondHalf"
			local secondParallel = second:FindFirstChild("ParallelCable")
			if secondParallel then secondParallel:Destroy() end
			second.CFrame = member.VisualSecond.CFrame
			second.Size = member.VisualSecond.Size
			second.Parent = session.Root
			pcall(function() second:SetNetworkOwner(nil) end)
		end
		member.Visual:Destroy()
		if member.VisualSecond then member.VisualSecond:Destroy() end
	end
	stopMotion(session)
	task.delay(1.5, function()
		if sessions[player.UserId] == session then
			session.Phase = "Failed"
			session.Message = "Failed: " .. session.Message
		end
	end)
end

local function supportDistances(session, step)
	local distances = {}
	local frontier = {}
	for _, nodeId in ipairs({step.From, step.To}) do
		if nodeId ~= LEFT and nodeId ~= RIGHT then distances[nodeId] = 0; table.insert(frontier, nodeId) end
	end
	for depth = 1, 6 do
		local nextFrontier = {}
		for _, nodeId in ipairs(frontier) do
			for _, record in ipairs(session.Records) do
				if record.Role ~= "Deck" then
					local nextId = record.FirstId == nodeId and record.LastId or record.LastId == nodeId and record.FirstId or nil
					if nextId and distances[nextId] == nil then
						distances[nextId] = depth
						table.insert(nextFrontier, nextId)
					end
				end
			end
		end
		frontier = nextFrontier
		if #frontier == 0 then break end
	end
	return distances
end

local function updateStress(player, session, step, loadPosition)
	local distances = supportDistances(session, step)
	local travel = Vector3.new(step.ToPosition.X - step.FromPosition.X, 0, step.ToPosition.Z - step.FromPosition.Z)
	local fromLoad = Vector3.new(loadPosition.X - step.FromPosition.X, 0, loadPosition.Z - step.FromPosition.Z)
	local progressOnBeam = math.clamp(fromLoad:Dot(travel) / math.max(travel:Dot(travel), 0.01), 0, 1)
	local peak = 0
	local gravityFactor = math.max(0, workspace.Gravity / rules.GravityReference)
	local liveWeight = rules.LoadWeight * gravityFactor
	for _, record in ipairs(session.Records) do
		local liveFactor = 0
		if record.Role == "Deck" then
			if record.Id == step.Beam:GetAttribute("ObjectId") then
				liveFactor = 0.8 + 0.2 * (1 - math.abs(progressOnBeam * 2 - 1))
			elseif record.FirstId == step.From or record.LastId == step.From
				or record.FirstId == step.To or record.LastId == step.To then
				local nearFinish = record.FirstId == step.To or record.LastId == step.To
				liveFactor = 0.12 + 0.1 * (nearFinish and progressOnBeam or 1 - progressOnBeam)
			end
		else
			local distance = math.min(distances[record.FirstId] or math.huge, distances[record.LastId] or math.huge)
			if distance < math.huge then liveFactor = 0.48 / (1 + 0.25 * distance) end
		end
		local material = record.Material
		local span = record.Length / rules.ReferenceSpan
		local selfWeight = material.Density * record.Length * 0.28 * gravityFactor
		local supportFactor = 1 / (1 + 0.3 * math.min(record.SupportCount, 3))
		local roleBending = record.Role == "Deck" and 1 or record.Role == "Arch" and 0.14 or 0
		local bendDemand = liveWeight * liveFactor * span ^ 2 * supportFactor * roleBending
			+ selfWeight * span / material.Stiffness * (record.Role == "Support" and 0.05 or 1)
		if record.Role == "Deck" then
			bendDemand *= supportRelianceFactor(material, record.SupportCount)
		end
		local slope = math.abs(record.Last.Y - record.First.Y) / math.max(record.Length, 0.01)
		local axialDemand = liveWeight * liveFactor * (record.Role == "Arch" and 0.75 or 0.45)
			* (1 + slope * 0.3) + selfWeight
		local compressionCapacity = material.Compression * math.min(1, math.sqrt(rules.ReferenceSpan / record.Length))
			* (0.8 + 0.2 * material.Stiffness)
		local tensionDemand = record.Role == "Support" and axialDemand
			or record.Role == "Arch" and axialDemand * 0.15 or axialDemand * 0.5
		local compressionDemand = record.Role == "Support" and 0 or axialDemand
		local ratio = math.max(bendDemand / material.Bend, compressionDemand / compressionCapacity,
			tensionDemand / material.Tension)
		if record.Cable then
			local cable = record.Cable
			for _, rope in ipairs(cable.Ropes) do
				rope.Length = cable.RestLength * (1.005 + 0.06 * math.clamp(ratio, 0, 1))
			end
			record.Visual:SetAttribute("StretchPercent", math.floor((cable.Rope.Length / cable.RestLength - 1) * 100 + 0.5))
		end
		peak = math.max(peak, ratio)
		local percent = math.floor(ratio * 100 + 0.5)
		record.Part:SetAttribute("StressPercent", percent)
		record.Visual:SetAttribute("StressPercent", percent)
		record.Fill.Size = UDim2.fromOffset(math.floor(94 * math.clamp(ratio, 0, 1)), 8)
		record.Fill.BackgroundColor3 = ratio >= 0.85 and Color3.fromRGB(255, 84, 72)
			or ratio >= 0.55 and Color3.fromRGB(255, 196, 68) or Color3.fromRGB(75, 224, 136)
		record.Label.Text = string.format("%s %d%%", record.MaterialName, percent)
		if ratio >= 1 then
			session.PeakStress = math.max(session.PeakStress, percent)
			breakBridge(player, session, record, ratio)
			return true
		end
	end
	session.PeakStress = math.max(session.PeakStress, math.floor(peak * 100 + 0.5))
	return false
end

local function updateDeflection(session, loadPosition, elapsed)
	local left, right = anchorPart(LEFT).Position, anchorPart(RIGHT).Position
	local centerX = (left.X + right.X) / 2
	local halfSpan = math.max(math.abs(right.X - left.X) / 2, 1)
	local gravityFactor = math.max(0, workspace.Gravity / rules.GravityReference)
	local smoothing = math.clamp(elapsed * 5, 0, 1)
	local largest = 0
	for _, joint in pairs(session.VisualJoints) do
		local shape = math.max(0, 1 - ((joint.Rest.X - centerX) / halfSpan) ^ 2)
		local distance = Vector3.new(joint.Rest.X - loadPosition.X, 0, joint.Rest.Z - loadPosition.Z).Magnitude
		local influence = math.max(0, 1 - distance / 24)
		local gravitySag = rules.DeadSagScale * joint.Mass * shape * gravityFactor / joint.Stiffness
		local loadSag = joint.LoadBearing and rules.LiveSagScale * (rules.LoadWeight / 100)
			* influence * shape * gravityFactor / joint.Stiffness or 0
		local desired = math.min(rules.MaxJointSag, gravitySag + loadSag)
		joint.Sag += (desired - joint.Sag) * smoothing
		joint.Part.Position = joint.Rest - Vector3.new(0, joint.Sag, 0)
		joint.Part:SetAttribute("DeflectionStuds", joint.Sag)
		joint.Part:SetAttribute("GravitySag", gravitySag)
		joint.Part:SetAttribute("LoadSag", loadSag)
		joint.Meter.Text = string.format("G ↓%.1f   Load ↓%.1f", gravitySag, loadSag)
		largest = math.max(largest, joint.Sag)
	end
	for _, record in ipairs(session.Records) do
		local firstJoint = session.VisualJoints[record.FirstId]
		local lastJoint = session.VisualJoints[record.LastId]
		local first = firstJoint and firstJoint.Part.Position or record.First
		local last = lastJoint and lastJoint.Part.Position or record.Last
		if record.VisualSecond then
			local ratio = math.clamp((record.Visual:GetAttribute("StressPercent") or 0) / 100, 0, 1)
			local span = record.Length / rules.ReferenceSpan
			local midSag = math.min(2.5, 0.18 * span ^ 2 * (0.5 + 0.5 * ratio)
				* gravityFactor / record.Material.Stiffness)
			local middle = (first + last) / 2 - Vector3.new(0, midSag, 0)
			largest = math.max(largest, math.max(0, ((record.First.Y + record.Last.Y) / 2) - middle.Y))
			for _, segment in ipairs({{record.Visual, first, middle}, {record.VisualSecond, middle, last}}) do
				local part, a, b = segment[1], segment[2], segment[3]
				local length = (b - a).Magnitude
				if length > 0.01 then
					part.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -part.Size.Y / 2, 0)
					part.Size = Vector3.new(part.Size.X, part.Size.Y, length + 0.12)
				end
			end
		else
			local length = (last - first).Magnitude
			if length > 0.01 then
				record.Visual.CFrame = CFrame.lookAt((first + last) / 2, last)
				if record.Cable then
					record.Visual.CFrame += Vector3.new(0, 0, -Config.Road.Width / 2)
					local ratio = math.clamp((record.Visual:GetAttribute("StressPercent") or 0) / 100, 0, 1)
					local thickness = 0.4 - 0.08 * ratio
					record.Visual.Size = Vector3.new(thickness, thickness, math.max(length, record.Cable.Rope.Length))
					if record.VisualParallel then
						record.VisualParallel.CFrame = record.Visual.CFrame + Vector3.new(0, 0, Config.Road.Width)
						record.VisualParallel.Size = record.Visual.Size
					end
				else
					record.Visual.Size = Vector3.new(record.Visual.Size.X, record.Visual.Size.Y, length + 0.12)
				end
			end
		end
	end
	session.CurrentDeflection = largest
	session.PeakDeflection = math.max(session.PeakDeflection, largest)
end

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function completeLevel(player, session)
	if session.Phase ~= "Running" then return end
	local cash, wins = wallet(player)
	local reward = Config.Progression.CompletionCash
	cash.Value += reward
	wins.Value += 1
	player:SetAttribute("Cash", cash.Value)
	player:SetAttribute("LevelComplete", true)
	session.Reward = reward
	session.Phase = "Completed"
	session.Progress = 100
	session.Message = string.format("LEVEL COMPLETE! Finish reached. +$%d Cash earned.", reward)
	stopMotion(session)
end

local function tickSession(player, session)
	if sessions[player.UserId] ~= session or session.Phase ~= "Running" then return end
	local load = session.Load
	local now = os.clock()
	if not load or not load.Parent then
		session.Phase = "Failed"; session.Message = "Failed: test car disappeared."; stopMotion(session); return
	end
	if load.Position.Y < Config.Resolve().RiverCenter.Y + 3 then
		session.Phase = "Failed"; session.Message = "Failed: test car fell into the river."; stopMotion(session); return
	end
	if now - session.StartedAt > rules.TimeLimit then
		session.Phase = "Failed"; session.Message = "Failed: test timed out."; stopMotion(session); return
	end
	local layout = Config.Resolve()
	local step = session.Route[session.StepIndex]
	if not step and load.Position.X >= layout.VehicleFinish.X - 1 then
		if math.abs(load.Position.Z - layout.VehicleFinish.Z) <= layout.PlatformSize.Z / 2 - 2
			and load.Position.Y > layout.RoadTopY - 2 then
			completeLevel(player, session)
		else
			session.Phase = "Failed"; session.Message = "Failed: the car missed the finish lane."; stopMotion(session)
		end
		return
	end
	local target = step and step.ToPosition or layout.VehicleFinish
	local remaining = horizontal(target - load.Position)
	if step and remaining.Magnitude < 2.7 then
		session.StepIndex += 1
		step = session.Route[session.StepIndex]
		remaining = horizontal((step and step.ToPosition or layout.VehicleFinish) - load.Position)
	end
	if step and now - session.LastStressAt >= rules.StressUpdateInterval then
		local elapsed = session.LastStressAt == -math.huge and rules.StressUpdateInterval or now - session.LastStressAt
		session.LastStressAt = now
		updateDeflection(session, load.Position, elapsed)
		if updateStress(player, session, step, load.Position) then return end
	end
	local direction = remaining.Magnitude > 0.01 and remaining.Unit or Vector3.zero
	local speedScale = session.CarSpeed / rules.BridgeSpeed
	local desired = direction * (step and session.CarSpeed or rules.Speed * speedScale)
	local velocity = horizontal(load.AssemblyLinearVelocity)
	local force = (desired - velocity) * load.AssemblyMass * 30
	local limit = load.AssemblyMass * 300
	if force.Magnitude > limit then force = force.Unit * limit end
	session.Drive.Force = force
	if horizontal(load.Position - session.LastProgressPosition).Magnitude > 1.5 then
		session.LastProgressPosition = load.Position
		session.LastProgressAt = now
	elseif now - session.LastProgressAt > rules.StuckTime then
		session.Phase = "Failed"; session.Message = "Failed: the car got stuck."; stopMotion(session); return
	end
	session.Progress = math.clamp(math.floor((load.Position.X - layout.VehicleStart.X) /
		(layout.VehicleFinish.X - layout.VehicleStart.X) * 100), 0, 99)
end

function SimulationServer.Start(existingLevel)
	level = existingLevel
	anchors = assert(level:FindFirstChild("BridgeAnchors"), "BridgeAnchors missing")
	copiesFolder = Instance.new("Folder")
	copiesFolder.Name = "SimulationCopies"
	copiesFolder.Parent = level
	carsFolder = Instance.new("Folder")
	carsFolder.Name = "TestCars"
	carsFolder.Parent = level
	local function prepare(player)
		wallet(player)
		task.spawn(function()
			local ok, errorMessage = pcall(ensureCar, player)
			if not ok then warn("Could not create test car: " .. tostring(errorMessage)) end
		end)
	end
	Players.PlayerAdded:Connect(prepare)
	for _, player in ipairs(Players:GetPlayers()) do prepare(player) end
end

function SimulationServer.IsLocked(player)
	return sessions[player.UserId] ~= nil
end

function SimulationServer.Snapshot(player)
	local session = sessions[player.UserId]
	local car = cars[player.UserId]
	local seated = car and car.Seat.Occupant == (player.Character and player.Character:FindFirstChildOfClass("Humanoid"))
	if not session then return {Phase = "Ready", Message = seated and "Seated. Connect both anchors, then start the car test." or "Walk to the yellow car and press E to enter before starting.", Progress = 0, BrokenCount = 0, Seated = seated == true, CarReady = car ~= nil, Cash = player:GetAttribute("Cash") or 0, Reward = 0, CarSpeed = rules.BridgeSpeed} end
	return {Phase = session.Phase, Message = session.Message, Progress = session.Progress,
		BrokenCount = session.BrokenCount, PeakStress = session.PeakStress,
		Deflection = math.floor(session.CurrentDeflection * 10 + 0.5) / 10,
		PeakDeflection = math.floor(session.PeakDeflection * 10 + 0.5) / 10,
		Seated = seated == true, CarReady = car ~= nil,
		Cash = player:GetAttribute("Cash") or 0, Reward = session.Reward or 0, CarSpeed = session.CarSpeed}
end

function SimulationServer.Handle(player, action, state, payload)
	if action == "SimulationStatus" then return reply(true, SimulationServer.Snapshot(player).Message) end
	if action == "ResetSimulation" then
		cleanup(player)
		return reply(true, "Simulation reset. The original bridge is ready to edit.")
	end
	if action ~= "StartSimulation" then return reply(false, "Unknown simulation action.") end
	if sessions[player.UserId] then return reply(false, "Reset the current simulation before starting another.") end
	local car = cars[player.UserId]
	if not car then return reply(false, "The test car is still loading.") end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or car.Seat.Occupant ~= humanoid then return reply(false, "Enter your yellow car before starting the simulation.") end
	local route = routeFor(state)
	if not route then return reply(false, "Connect your bridge from the left anchor to the right anchor first.") end
	local requestedSpeed = payload and payload.CarSpeed
	if type(requestedSpeed) ~= "number" or requestedSpeed ~= requestedSpeed or requestedSpeed == math.huge or requestedSpeed == -math.huge then
		requestedSpeed = rules.BridgeSpeed
	end
	local carSpeed = math.clamp(math.round(requestedSpeed / rules.CarSpeedStep) * rules.CarSpeedStep, rules.MinCarSpeed, rules.MaxCarSpeed)
	local session = {
		Phase = "Running", Message = "Driving the test car across your bridge...", Progress = 0, BrokenCount = 0,
		CarSpeed = carSpeed,
		Route = route, StepIndex = 1, Hidden = {}, AnchorAttachments = {}, Constraints = {}, PeakStress = 0,
		CurrentDeflection = 0, PeakDeflection = 0,
		LastStressAt = -math.huge,
		StartedAt = os.clock(), LastProgressAt = os.clock(), LastProgressPosition = car.Chassis.Position,
	}
	sessions[player.UserId] = session
	local ok, errorMessage = pcall(makeCopies, player, state, session)
	if not ok then
		cleanup(player)
		warn("Simulation setup failed: " .. tostring(errorMessage))
		return reply(false, "Simulation setup failed. Original bridge restored.")
	end
	session.Connection = RunService.Heartbeat:Connect(function() tickSession(player, session) end)
	return reply(true, session.Message)
end

function SimulationServer.Cleanup(player)
	cleanup(player)
	local car = cars[player.UserId]
	if car then
		cars[player.UserId] = nil
		car.Model:Destroy()
	end
end

return SimulationServer
