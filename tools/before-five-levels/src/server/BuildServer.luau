-- Server-authoritative construction for the existing River Crossing 01 level.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LevelConfig"))
local SimulationServer = require(script.Parent:WaitForChild("SimulationServer"))

local BuildServer = {}
local GRID = 2
local MIN_SEPARATION = 2
local MIN_BEAM_LENGTH = 2
local MAX_BEAM_LENGTH = 80
local MAX_JOINTS = 50
local MAX_BEAMS = 100
local ANCHOR_LEFT = "BridgeAnchor_Left"
local ANCHOR_RIGHT = "BridgeAnchor_Right"
local MATERIALS = {
	Wood = {Color = Color3.fromRGB(157, 103, 57), Material = Enum.Material.Wood},
	Steel = {Color = Color3.fromRGB(94, 145, 164), Material = Enum.Material.Metal},
	Concrete = {Color = Color3.fromRGB(168, 177, 180), Material = Enum.Material.Concrete},
}
local BUDGET = Config.Budget

local function cashValue(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

local function setCash(player, amount)
	local cash = cashValue(player)
	if cash then cash.Value = amount end
	player:SetAttribute("Cash", amount)
end

local level
local bounds
local anchors
local builds
local states = {}

local function reply(ok, message, extra)
	local response = extra or {}
	response.ok = ok
	response.message = message
	return response
end

local function dollars(amount)
	local digits = tostring(amount)
	return "$" .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function budgetSnapshot(state, player)
	local budget = state.Budget
	local cash = cashValue(player)
	if cash then budget.Remaining = cash.Value end
	return {
		Starting = budget.Starting,
		Spent = budget.Spent,
		Refunded = budget.Refunded,
		Remaining = budget.Remaining,
		PricePerStud = {
			Wood = BUDGET.PricePerStud.Wood,
			Steel = BUDGET.PricePerStud.Steel,
			Concrete = BUDGET.PricePerStud.Concrete,
		},
	}
end

local function finite(number)
	return type(number) == "number" and number == number and math.abs(number) < math.huge
end

local function finiteVector(value)
	return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
end

local function zoneCoordinates()
	return Vector3.new(bounds:GetAttribute("MinX"), bounds:GetAttribute("MinY"), bounds:GetAttribute("MinZ")),
		Vector3.new(bounds:GetAttribute("MaxX"), bounds:GetAttribute("MaxY"), bounds:GetAttribute("MaxZ"))
end

local function insideZone(position)
	local minimum, maximum = zoneCoordinates()
	return position.X >= minimum.X and position.X <= maximum.X
		and position.Y >= minimum.Y and position.Y <= maximum.Y
		and position.Z >= minimum.Z and position.Z <= maximum.Z
end

local function snap(number, origin)
	return origin + math.round((number - origin) / GRID) * GRID
end

local function snapPosition(position)
	local origin = Config.Origin
	return Vector3.new(snap(position.X, origin.X), snap(position.Y, origin.Y), snap(position.Z, origin.Z))
end

local function count(map)
	local total = 0
	for _ in pairs(map) do total += 1 end
	return total
end

local function stateFor(player)
	local state = states[player.UserId]
	if state then return state end
	local owned = Instance.new("Folder")
	owned.Name = tostring(player.UserId)
	owned:SetAttribute("OwnerUserId", player.UserId)
	owned.Parent = builds
	local jointsFolder = Instance.new("Folder")
	jointsFolder.Name = "Joints"
	jointsFolder.Parent = owned
	local beamsFolder = Instance.new("Folder")
	beamsFolder.Name = "Beams"
	beamsFolder.Parent = owned
	state = {
		Folder = owned, JointsFolder = jointsFolder, BeamsFolder = beamsFolder,
		Joints = {}, Beams = {},
		Budget = {Starting = BUDGET.Starting, Spent = 0, Refunded = 0, Remaining = (cashValue(player) and cashValue(player).Value or BUDGET.Starting)},
	}
	states[player.UserId] = state
	return state
end

local function anchorPosition(nodeId)
	local target = anchors:FindFirstChild(nodeId .. "Target")
	local attachment = target and target:FindFirstChild(nodeId)
	return attachment and attachment.WorldPosition
end

local function endpoint(state, nodeId)
	if type(nodeId) ~= "string" then return nil end
	local anchor = anchorPosition(nodeId)
	if anchor then return anchor end
	local joint = state.Joints[nodeId]
	return joint and joint.Position
end

local function tooClose(position)
	for _, target in ipairs(anchors:GetChildren()) do
		if target:GetAttribute("BuildKind") == "FixedAnchor"
			and (position - target.Position).Magnitude < MIN_SEPARATION then return true end
	end
	for _, owned in ipairs(builds:GetChildren()) do
		local jointsFolder = owned:FindFirstChild("Joints")
		if jointsFolder then
			for _, joint in ipairs(jointsFolder:GetChildren()) do
				if joint:IsA("BasePart") and (position - joint.Position).Magnitude < MIN_SEPARATION then
					return true
				end
			end
		end
	end
	return false
end

local function newJoint(player, state, position)
	local objectId = HttpService:GenerateGUID(false)
	local joint = Instance.new("Part")
	joint.Name = "Joint"
	joint.Shape = Enum.PartType.Ball
	joint.Size = Vector3.new(1.4, 1.4, 1.4)
	joint.Position = position
	joint.Color = Color3.fromRGB(255, 219, 92)
	joint.Material = Enum.Material.Neon
	joint.Anchored = true
	joint.CollisionGroup = "BridgeBuildParts"
	joint.CanCollide = false
	joint.CanTouch = false
	joint:SetAttribute("OwnerUserId", player.UserId)
	joint:SetAttribute("ObjectId", objectId)
	joint:SetAttribute("IsAnchor", false)
	joint:SetAttribute("BuildKind", "Joint")
	joint.Parent = state.JointsFolder
	state.Joints[objectId] = joint
	return objectId
end

local function createJoint(player, state, payload)
	local requested = payload.Position
	if not finiteVector(requested) then return reply(false, "Choose a valid point inside the build zone.") end
	if not insideZone(requested) then return reply(false, "Joint is outside the build zone.") end
	local position = snapPosition(requested)
	if not insideZone(position) then return reply(false, "Snapped joint is outside the build zone.") end
	if count(state.Joints) >= MAX_JOINTS then return reply(false, "Joint limit reached (50).") end
	if tooClose(position) then return reply(false, "Joint is too close to another joint or anchor (minimum 2 studs).") end
	local objectId = newJoint(player, state, position)
	return reply(true, "Joint placed at " .. tostring(position) .. ".", {ObjectId = objectId, Position = position})
end

local function createBeam(player, state, payload)
	local startId = payload.StartNodeId
	local endId = payload.EndNodeId
	local materialType = payload.MaterialType
	local material = MATERIALS[materialType]
	if not material then return reply(false, "Choose Wood, Steel, or Concrete.") end
	local role = payload.MemberRole or "Deck"
	if role ~= "Deck" and role ~= "Support" and role ~= "Arch" then return reply(false, "Invalid beam role.") end
	if type(startId) ~= "string" or type(endId) ~= "string" or startId == endId then
		return reply(false, "Choose two different joints or anchors.")
	end
	if count(state.Beams) >= MAX_BEAMS then return reply(false, "Beam limit reached (100).") end
	local startPosition = endpoint(state, startId)
	local endPosition = endpoint(state, endId)
	if not startPosition or not endPosition then return reply(false, "Choose your own joints or one of the fixed anchors.") end
	local length = (endPosition - startPosition).Magnitude
	if length < MIN_BEAM_LENGTH then return reply(false, "Beam must be at least 2 studs long.") end
	if length > MAX_BEAM_LENGTH then return reply(false, "Beam cannot be longer than 80 studs.") end
	for _, beam in pairs(state.Beams) do
		local a = beam:GetAttribute("StartNodeId")
		local b = beam:GetAttribute("EndNodeId")
		if (a == startId and b == endId) or (a == endId and b == startId) then
			return reply(false, "Those endpoints already have a beam.")
		end
	end
	local pricePerStud = BUDGET.PricePerStud[materialType]
	local cost = math.ceil(length * pricePerStud)
	local budget = state.Budget
	if cost > budget.Remaining then
		return reply(false, materialType .. " beam costs " .. dollars(cost) .. "; only " .. dollars(budget.Remaining) .. " remaining.")
	end
	local objectId = HttpService:GenerateGUID(false)
	local beam
	local created = pcall(function()
		beam = Instance.new("Part")
		beam.Name = role == "Deck" and "Beam" or role
		beam.Size = role == "Deck" and Vector3.new(Config.Road.Width, 0.65, length)
			or role == "Support" and Vector3.new(0.4, 0.4, length) or Vector3.new(0.9, 0.9, length)
		beam.CFrame = CFrame.lookAt((startPosition + endPosition) / 2, endPosition)
		if role == "Deck" then beam.CFrame *= CFrame.new(0, -beam.Size.Y / 2, 0) end
		if role == "Support" then
			beam.CFrame += Vector3.new(0, 0, -Config.Road.Width / 2)
		end
		beam.Color = material.Color
		beam.Material = material.Material
		beam.Anchored = true
		beam.CollisionGroup = "BridgeBuildParts"
		beam.CanCollide = role == "Deck"
		beam.CanTouch = false
		beam:SetAttribute("OwnerUserId", player.UserId)
		beam:SetAttribute("ObjectId", objectId)
		beam:SetAttribute("StartNodeId", startId)
		beam:SetAttribute("EndNodeId", endId)
		beam:SetAttribute("MaterialType", materialType)
		beam:SetAttribute("MemberRole", role)
		beam:SetAttribute("PaidCost", cost)
		beam:SetAttribute("BuildKind", "Beam")
		if role == "Support" then
			local parallel = beam:Clone()
			parallel.Name = "ParallelCable"
			parallel.CFrame += Vector3.new(0, 0, Config.Road.Width)
			parallel.Parent = beam
		end
		beam.Parent = state.BeamsFolder
	end)
	if not created then
		if beam then beam:Destroy() end
		return reply(false, "Beam could not be created. No funds were charged.")
	end
	state.Beams[objectId] = beam
	budget.Spent += cost
	budget.Remaining -= cost
	setCash(player, budget.Remaining)
	return reply(true, materialType .. " " .. role:lower() .. " placed: " .. dollars(cost) .. ".", {ObjectId = objectId, PaidCost = cost})
end

local function refundBeam(player, state, beamId, beam)
	local paid = beam:GetAttribute("PaidCost")
	local refund = type(paid) == "number" and math.max(0, paid) or 0
	state.Beams[beamId] = nil
	beam:Destroy()
	local budget = state.Budget
	budget.Refunded += refund
	budget.Remaining += refund
	setCash(player, budget.Remaining)
	return refund
end

local function createArch(player, state, payload)
	local startId, endId = payload.StartNodeId, payload.EndNodeId
	local materialType = payload.MaterialType
	if not MATERIALS[materialType] then return reply(false, "Choose Wood, Steel, or Concrete.") end
	if type(startId) ~= "string" or type(endId) ~= "string" or startId == endId then
		return reply(false, "Select two different arch endpoints.")
	end
	local first, last = endpoint(state, startId), endpoint(state, endId)
	if not first or not last then return reply(false, "Use your own joints or the fixed anchors.") end
	local horizontalSpan = (Vector3.new(first.X, 0, first.Z) - Vector3.new(last.X, 0, last.Z)).Magnitude
	if horizontalSpan < 16 or math.abs(first.Y - last.Y) > 2 then
		return reply(false, "An arch needs level endpoints at least 16 studs apart.")
	end
	if count(state.Joints) + 3 > MAX_JOINTS or count(state.Beams) + 4 > MAX_BEAMS then
		return reply(false, "Not enough joint or beam slots for an arch.")
	end
	local rise = math.min(8, math.floor(horizontalSpan / 8 / GRID) * GRID)
	local positions = {first}
	for index = 1, 3 do
		local fraction = index / 4
		local point = snapPosition(first:Lerp(last, fraction) - Vector3.new(0, rise * math.sin(math.pi * fraction), 0))
		if not insideZone(point) or tooClose(point) then
			return reply(false, "Arch rib would overlap a joint or leave the build zone.")
		end
		table.insert(positions, point)
	end
	table.insert(positions, last)
	local totalCost = 0
	for index = 1, 4 do
		local length = (positions[index + 1] - positions[index]).Magnitude
		if length < MIN_BEAM_LENGTH or length > MAX_BEAM_LENGTH then return reply(false, "Invalid arch segment length.") end
		totalCost += math.ceil(length * BUDGET.PricePerStud[materialType])
	end
	if totalCost > state.Budget.Remaining then
		return reply(false, materialType .. " arch costs " .. dollars(totalCost) .. "; only " .. dollars(state.Budget.Remaining) .. " remaining.")
	end
	local madeJoints, madeBeams = {}, {}
	local ok, failure = pcall(function()
		local nodeIds = {startId}
		for index = 2, 4 do
			local jointId = newJoint(player, state, positions[index])
			table.insert(madeJoints, jointId)
			table.insert(nodeIds, jointId)
		end
		table.insert(nodeIds, endId)
		for index = 1, 4 do
			local result = createBeam(player, state, {
				StartNodeId = nodeIds[index], EndNodeId = nodeIds[index + 1],
				MaterialType = materialType, MemberRole = "Arch",
			})
			if not result.ok then error(result.message) end
			table.insert(madeBeams, result.ObjectId)
		end
	end)
	if not ok then
		for _, beamId in ipairs(madeBeams) do refundBeam(player, state, beamId, state.Beams[beamId]) end
		for _, jointId in ipairs(madeJoints) do state.Joints[jointId]:Destroy(); state.Joints[jointId] = nil end
		return reply(false, "Arch could not be created: " .. tostring(failure))
	end
	return reply(true, materialType .. " arch placed for " .. dollars(totalCost) .. ". Add support beams to connect it to the deck.")
end

local function erase(player, state, payload)
	local objectId = payload.ObjectId
	if type(objectId) ~= "string" then return reply(false, "Anchors and level scenery cannot be erased.") end
	local beam = state.Beams[objectId]
	if beam then
		local refunded = refundBeam(player, state, objectId, beam)
		return reply(true, "Beam erased: " .. dollars(refunded) .. " refunded.", {RefundedAmount = refunded})
	end
	local joint = state.Joints[objectId]
	if not joint then return reply(false, "You can only erase your own joints and beams.") end
	local totalRefunded = 0
	for beamId, connected in pairs(state.Beams) do
		if connected:GetAttribute("StartNodeId") == objectId or connected:GetAttribute("EndNodeId") == objectId then
			totalRefunded += refundBeam(player, state, beamId, connected)
		end
	end
	state.Joints[objectId] = nil
	joint:Destroy()
	return reply(true, "Joint erased: " .. dollars(totalRefunded) .. " refunded for connected beams.", {RefundedAmount = totalRefunded})
end

function BuildServer.Handle(player, action, payload)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return reply(false, "Invalid player.") end
	if not level or not level.Parent then return reply(false, "Level is unavailable.") end
	if type(payload) ~= "table" then payload = {} end
	local state = stateFor(player)
	local currentCash = cashValue(player)
	if currentCash then state.Budget.Remaining = currentCash.Value end
	local response
	if action == "StartSimulation" or action == "ResetSimulation" or action == "SimulationStatus" then
		response = SimulationServer.Handle(player, action, state, payload)
		response.Simulation = SimulationServer.Snapshot(player)
	elseif SimulationServer.IsLocked(player) and (action == "Joint" or action == "Beam" or action == "Arch" or action == "Erase") then
		response = reply(false, "Reset the simulation before editing your bridge.")
	elseif action == "Budget" then
		response = reply(true, "Budget ready.")
	elseif action == "Joint" then
		response = createJoint(player, state, payload)
	elseif action == "Beam" then
		response = createBeam(player, state, payload)
	elseif action == "Arch" then
		response = createArch(player, state, payload)
	elseif action == "Erase" then
		response = erase(player, state, payload)
	else
		response = reply(false, "Unknown build action.")
	end
	response.Budget = budgetSnapshot(state, player)
	return response
end

function BuildServer.Start(existingLevel)
	pcall(function() PhysicsService:RegisterCollisionGroup("BridgeBuildParts") end)
	pcall(function() PhysicsService:RegisterCollisionGroup("BridgeSimulationLoad") end)
	PhysicsService:CollisionGroupSetCollidable("BridgeBuildParts", "BridgeSimulationLoad", false)
	level = existingLevel
	bounds = assert(level:FindFirstChild("BuildZone") and level.BuildZone:FindFirstChild("BuildZoneBounds"), "BuildZoneBounds missing")
	anchors = assert(level:FindFirstChild("BridgeAnchors"), "BridgeAnchors missing")
	assert(anchors.BridgeAnchor_LeftTarget:FindFirstChild(ANCHOR_LEFT), "Left anchor missing")
	assert(anchors.BridgeAnchor_RightTarget:FindFirstChild(ANCHOR_RIGHT), "Right anchor missing")
	builds = level:FindFirstChild("PlayerBuilds") or Instance.new("Folder")
	builds.Name = "PlayerBuilds"
	builds.Parent = level
	SimulationServer.Start(level)
	local remotes = ReplicatedStorage:FindFirstChild("BridgeBuildRemotes") or Instance.new("Folder")
	remotes.Name = "BridgeBuildRemotes"
	remotes.Parent = ReplicatedStorage
	local actionRemote = remotes:FindFirstChild("Action") or Instance.new("RemoteFunction")
	actionRemote.Name = "Action"
	actionRemote.Parent = remotes
	actionRemote.OnServerInvoke = BuildServer.Handle
	Players.PlayerRemoving:Connect(function(player)
		SimulationServer.Cleanup(player)
		local state = states[player.UserId]
		if state then
			state.Folder:Destroy()
			states[player.UserId] = nil
		end
	end)
end

return BuildServer
