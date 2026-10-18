-- Server-authoritative construction for the existing River Crossing 01 level.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SimulationFactory = require(script.Parent:WaitForChild("SimulationServer"))
local DeckJoins=require(ReplicatedStorage.Shared.DeckJoins)
local CableMounts=require(ReplicatedStorage.Shared.CableMounts)
local Factory = {}
function Factory.new(existingLevel, Config, onComplete)
local SimulationServer = SimulationFactory.new(existingLevel, Config, onComplete)

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

local function blocked(position)
 local p=position-Config.Origin
 if Config.Jump and p.X>Config.Jump.MinX and p.X<Config.Jump.MaxX then return true end
 local o=Config.Obstacle
 return o and not o.AllowBuild and p.X>o.Min.X and p.X<o.Max.X and p.Y>o.Min.Y and p.Y<o.Max.Y and p.Z>o.Min.Z and p.Z<o.Max.Z
end
local function insideZone(position)
	local minimum, maximum = zoneCoordinates()
	return not blocked(position) and position.X >= minimum.X and position.X <= maximum.X
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
		Undo = {}, Redo = {},
		Budget = {Starting = BUDGET.Starting, Spent = 0, Refunded = 0, Remaining = BUDGET.Starting},
	}
	states[player.UserId] = state
	return state
end

local HISTORY_LIMIT = 30
local updateJoins
local function snapshot(state)
	local copy = {Joints = {}, Beams = {}, Budget = table.clone(state.Budget)}
	for id, part in pairs(state.Joints) do copy.Joints[id] = part:Clone() end
	for id, part in pairs(state.Beams) do copy.Beams[id] = part:Clone() end
	return copy
end

local function pushHistory(stack, value)
	table.insert(stack, value)
	if #stack > HISTORY_LIMIT then table.remove(stack, 1) end
end

local function restore(player, state, saved)
	for _, part in pairs(state.Beams) do part:Destroy() end
	for _, part in pairs(state.Joints) do part:Destroy() end
	state.Joints, state.Beams = {}, {}
	for id, part in pairs(saved.Joints) do
		local copy = part:Clone()
		copy.Parent = state.JointsFolder
		state.Joints[id] = copy
	end
	for id, part in pairs(saved.Beams) do
		local copy = part:Clone()
		copy.Parent = state.BeamsFolder
		state.Beams[id] = copy
	end
	state.Budget = table.clone(saved.Budget)
	setCash(player, state.Budget.Remaining)
	updateJoins(state)
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

local function cableDeck(state,id)
 return CableMounts.Find(state.Beams,id,endpoint(state,id))
end
local function validCableMount(state,id)
 return anchorPosition(id)~=nil or cableDeck(state,id)~=nil
end
local function cablePosition(state,id,side)
 local width=id:find("Tower",1,true) and Config.Tower.HalfWidth*2 or Config.Road.Width
 return CableMounts.Position(cableDeck(state,id),endpoint(state,id),side,width)
end
updateJoins = function(state)
 local folder=state.Folder:FindFirstChild("DeckJoins") or Instance.new("Folder")
 folder.Name="DeckJoins"; folder.Parent=state.Folder
 local sections={}
 for _,beam in pairs(state.Beams) do
  local role=beam:GetAttribute("MemberRole")
  if role=="Deck" or role=="ArchRamp" then
   for _,key in ipairs({"StartNodeId","EndNodeId"}) do
    local id=beam:GetAttribute(key); sections[id]=sections[id] or {}
    table.insert(sections[id],{Part=beam,Point=endpoint(state,id)})
   end
  end
 end
 DeckJoins.Update(folder,sections,"BridgeBuildParts")
 for _,cable in pairs(state.Beams) do if cable:GetAttribute("MemberRole")=="Support" then
  local a,b=cable:GetAttribute("StartNodeId"),cable:GetAttribute("EndNodeId")
  for _,side in ipairs({-1,1}) do
   local visual=side==-1 and cable or cable:FindFirstChild("ParallelCable")
   if visual then
    local first=cablePosition(state,a,side)
    local last=cablePosition(state,b,side)
    visual.CFrame=CFrame.lookAt((first+last)/2,last)
    visual.Size=Vector3.new(.4,.4,math.max(.05,(last-first).Magnitude))
   end
  end
 end end
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

local function createBeam(player, state, payload, allowRamp)
	local startId = payload.StartNodeId
	local endId = payload.EndNodeId
	local materialType = payload.MaterialType
	local material = MATERIALS[materialType]
	if not material then return reply(false, "Choose Wood, Steel, or Concrete.") end
	local role = payload.MemberRole or "Deck"
	if role == "ArchRamp" and not allowRamp then return reply(false, "Use the Arch tool to build a jump ramp.") end
	if role ~= "Deck" and role ~= "Support" and role ~= "Arch" and role ~= "ArchRamp" then return reply(false, "Invalid beam role.") end
	if type(startId) ~= "string" or type(endId) ~= "string" or startId == endId then
		return reply(false, "Choose two different joints or anchors.")
	end
	if count(state.Beams) >= MAX_BEAMS then return reply(false, "Beam limit reached (100).") end
	local startPosition = endpoint(state, startId)
	local endPosition = endpoint(state, endId)
	if not startPosition or not endPosition then return reply(false, "Choose your own joints or one of the fixed anchors.") end
 if role=="Support" and (not validCableMount(state,startId) or not validCableMount(state,endId)) then
  return reply(false,"Choose a fixed tower or a joint on a deck span for each cable end.")
 end
	local length = (endPosition - startPosition).Magnitude
 for index=1,math.ceil(length*2)-1 do
  if blocked(startPosition:Lerp(endPosition,index/math.ceil(length*2))) then return reply(false,"Keep the marked obstacle area clear.") end
 end
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
		beam.Size = (role == "Deck" or role == "ArchRamp") and Vector3.new(Config.Road.Width, 0.65, length)
			or role == "Support" and Vector3.new(0.4, 0.4, length) or Vector3.new(0.9, 0.9, length)
		beam.CFrame = CFrame.lookAt((startPosition + endPosition) / 2, endPosition)
		if role == "Deck" or role == "ArchRamp" then beam.CFrame *= CFrame.new(0, -beam.Size.Y / 2, 0) end
		if role == "Support" then
			beam.CFrame += Vector3.new(0, 0, -Config.Road.Width / 2)
		end
		beam.Color = material.Color
		beam.Material = material.Material
		beam.Anchored = true
		beam.CollisionGroup = "BridgeBuildParts"
		beam.CanCollide = role == "Deck" or role == "ArchRamp"
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
 updateJoins(state)
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
 updateJoins(state)
	local budget = state.Budget
	budget.Refunded += refund
	local previousRemaining = budget.Remaining
	budget.Remaining = math.min(BUDGET.Starting, budget.Remaining + refund)
 local credited = budget.Remaining - previousRemaining
 setCash(player, budget.Remaining)
 -- Removing a deck also removes/refunds cables whose deck mount would disappear.
 local orphaned={}
 for id,cable in pairs(state.Beams) do
  if cable:GetAttribute("MemberRole")=="Support" and (not validCableMount(state,cable:GetAttribute("StartNodeId")) or not validCableMount(state,cable:GetAttribute("EndNodeId"))) then
   table.insert(orphaned,{id,cable})
  end
 end
 for _,entry in ipairs(orphaned) do if state.Beams[entry[1]] then credited+=refundBeam(player,state,entry[1],entry[2]) end end
 return credited
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
	local ramp = false
	if Config.Jump then
		local leftTip = (startId == ANCHOR_LEFT and last or endId == ANCHOR_LEFT and first)
		local rightTip = (startId == ANCHOR_RIGHT and last or endId == ANCHOR_RIGHT and first)
		local originX = Config.Origin.X
		ramp = (leftTip and leftTip.X >= originX + Config.Jump.MinX - 12 and leftTip.X <= originX + Config.Jump.MinX
			and leftTip.Y >= Config.Origin.Y + Config.Road.TopY + 4)
			or (rightTip and rightTip.X >= originX + Config.Jump.MaxX and rightTip.X <= originX + Config.Jump.MaxX + 12
			and rightTip.Y >= Config.Origin.Y + Config.Road.TopY + 4) or false
	end
	if horizontalSpan < 16 or (not ramp and math.abs(first.Y - last.Y) > 2) then
		return reply(false, "An arch needs level endpoints at least 16 studs apart.")
	end
	if count(state.Joints) + 3 > MAX_JOINTS or count(state.Beams) + 4 > MAX_BEAMS then
		return reply(false, "Not enough joint or beam slots for an arch.")
	end
	local rise = math.min(8, math.floor(horizontalSpan / 8 / GRID) * GRID)
	local positions = {first}
	for index = 1, 3 do
		local fraction = index / 4
		local point
  if ramp then
   -- Quadratic arch rises gently at the bank and more steeply at the jump lip.
   local low,high = first.Y<last.Y and first or last, first.Y<last.Y and last or first
   local t=first==low and fraction or 1-fraction
   point=low:Lerp(high,t); point=Vector3.new(point.X,low.Y+(high.Y-low.Y)*t*t,point.Z)
  else point=snapPosition(first:Lerp(last,fraction)-Vector3.new(0,rise*math.sin(math.pi*fraction),0)) end
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
				MaterialType = materialType, MemberRole = ramp and "ArchRamp" or "Arch",
			}, ramp)
			if not result.ok then error(result.message) end
			table.insert(madeBeams, result.ObjectId)
		end
	end)
	if not ok then
		for _, beamId in ipairs(madeBeams) do refundBeam(player, state, beamId, state.Beams[beamId]) end
		for _, jointId in ipairs(madeJoints) do state.Joints[jointId]:Destroy(); state.Joints[jointId] = nil end
		return reply(false, "Arch could not be created: " .. tostring(failure))
	end
	return reply(true, ramp and "Driveable arch ramp ready. Build the other ramp, then enter the car." or materialType .. " arch placed for " .. dollars(totalCost) .. ". Add supports to connect it to the deck.", {PaidCost=totalCost})
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
	elseif SimulationServer.IsLocked(player) and (action == "Joint" or action == "Beam" or action == "Arch" or action == "Erase" or action == "Undo" or action == "Redo") then
		response = reply(false, "Reset the simulation before editing your bridge.")
	elseif action == "Budget" then
		response = reply(true, "Budget ready.")
	elseif action == "Undo" or action == "Redo" then
		local source = action == "Undo" and state.Undo or state.Redo
		local target = action == "Undo" and state.Redo or state.Undo
		if #source == 0 then
			response = reply(false, "Nothing to " .. action:lower() .. ".")
		else
			local current = snapshot(state)
			local saved = table.remove(source)
			restore(player, state, saved)
			pushHistory(target, current)
			response = reply(true, action == "Undo" and "Last build change undone." or "Build change restored.")
		end
	elseif action == "Joint" then
		local before = snapshot(state)
		response = createJoint(player, state, payload)
		if response.ok then pushHistory(state.Undo, before); state.Redo = {} end
	elseif action == "Beam" then
		local before = snapshot(state)
		response = createBeam(player, state, payload)
		if response.ok then pushHistory(state.Undo, before); state.Redo = {} end
	elseif action == "Arch" then
		local before = snapshot(state)
		response = createArch(player, state, payload)
		if response.ok then pushHistory(state.Undo, before); state.Redo = {} end
	elseif action == "Erase" then
		local before = snapshot(state)
		response = erase(player, state, payload)
		if response.ok then pushHistory(state.Undo, before); state.Redo = {} end
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

end

function BuildServer.Select(player)
 local state=stateFor(player)
 SimulationServer.Prepare(player)
 setCash(player,state.Budget.Remaining)
 return budgetSnapshot(state,player)
end
function BuildServer.Leave(player)
 local state=states[player.UserId]
 if state then local cash=cashValue(player); if cash then state.Budget.Remaining=cash.Value end end
 SimulationServer.Cleanup(player)
end
function BuildServer.Remove(player)
 SimulationServer.Cleanup(player)
 local state=states[player.UserId]
 if state then state.Folder:Destroy(); states[player.UserId]=nil end
end

-- Only plain data leaves the server. Simulation parts are never part of a save.
function BuildServer.Export(player,isActive)
 local state=states[player.UserId]
 if not state then return nil end
 if isActive then local cash=cashValue(player);if cash then state.Budget.Remaining=cash.Value end end
 local joints,beams={},{}
 for id,part in pairs(state.Joints) do
  local p=part.Position-Config.Origin
  table.insert(joints,{Id=id,Position={p.X,p.Y,p.Z}})
 end
 for id,part in pairs(state.Beams) do
  table.insert(beams,{Id=id,Start=part:GetAttribute("StartNodeId"),Finish=part:GetAttribute("EndNodeId"),Material=part:GetAttribute("MaterialType"),Role=part:GetAttribute("MemberRole"),Cost=part:GetAttribute("PaidCost")})
 end
 table.sort(joints,function(a,b) return a.Id<b.Id end)
 table.sort(beams,function(a,b) return a.Id<b.Id end)
 return {Joints=joints,Beams=beams,Budget={Spent=state.Budget.Spent,Refunded=state.Budget.Refunded,Remaining=state.Budget.Remaining}}
end

function BuildServer.Import(player,data)
 if type(data)~="table" or type(data.Joints)~="table" or type(data.Beams)~="table" or #data.Joints>MAX_JOINTS or #data.Beams>MAX_BEAMS then return false end
 local state=stateFor(player)
 if next(state.Joints) or next(state.Beams) then return false end
 local map={}
 local function clear()
  for _,part in pairs(state.Beams) do part:Destroy() end
  for _,part in pairs(state.Joints) do part:Destroy() end
  state.Beams={};state.Joints={}
  state.Budget={Starting=BUDGET.Starting,Spent=0,Refunded=0,Remaining=BUDGET.Starting}
  updateJoins(state)
 end
 for _,item in ipairs(data.Joints) do
  local p=item.Position
  if type(item.Id)~="string" or map[item.Id] or type(p)~="table" or not finite(p[1]) or not finite(p[2]) or not finite(p[3]) then clear();return false end
  local world=Config.Origin+Vector3.new(p[1],p[2],p[3])
  if not insideZone(world) or (snapPosition(world)-world).Magnitude>.05 then clear();return false end
  map[item.Id]=newJoint(player,state,world)
 end
 -- Older Level 5 saves used permanent jump markers. Turn those endpoints into
 -- ordinary editable joints so existing ramps survive removal of the markers.
 if Config.Jump then
  for _,spec in ipairs({{"JumpLaunch",Config.Jump.MinX-0.5},{"JumpLanding",Config.Jump.MaxX+0.5}}) do
   local used=false
   for _,beam in ipairs(data.Beams) do
    if beam.Start==spec[1] or beam.Finish==spec[1] then used=true;break end
   end
   if used then
    if count(state.Joints)>=MAX_JOINTS then clear();return false end
    map[spec[1]]=newJoint(player,state,Config.Origin+Vector3.new(spec[2],12,0))
   end
  end
 end
 -- Decks first, then cables: cable mounts depend on existing deck spans.
 local ordered={}
 for _,item in ipairs(data.Beams) do table.insert(ordered,item) end
 table.sort(ordered,function(a,b) return a.Role~="Support" and b.Role=="Support" end)
 state.Budget.Remaining=1000000
 for _,item in ipairs(ordered) do
  if type(item.Start)~="string" or type(item.Finish)~="string" or type(item.Material)~="string" or type(item.Role)~="string"
   or not finite(item.Cost) or item.Cost<0 or item.Cost>100000 then clear();return false end
  local result=createBeam(player,state,{StartNodeId=map[item.Start] or item.Start,EndNodeId=map[item.Finish] or item.Finish,MaterialType=item.Material,MemberRole=item.Role},true)
  if not result.ok then clear();return false end
  state.Beams[result.ObjectId]:SetAttribute("PaidCost",item.Cost)
 end
 local budget=data.Budget
 if type(budget)~="table" or not finite(budget.Remaining) or not finite(budget.Spent) or not finite(budget.Refunded)
  or budget.Remaining<0 or budget.Remaining>100000 or budget.Spent<0 or budget.Spent>100000 or budget.Refunded<0 or budget.Refunded>100000 then clear();return false end
 local remaining=budget.Remaining
 if Config.Id==5 then
  remaining=math.min(remaining,math.max(0,BUDGET.Starting-math.max(0,budget.Spent-budget.Refunded)))
 end
 state.Budget={Starting=BUDGET.Starting,Spent=budget.Spent,Refunded=budget.Refunded,Remaining=remaining}
 return true
end
BuildServer.Start(existingLevel)
return BuildServer
end
return Factory
