--[[
	TruckLoads  (ModuleScript)  —  put different cargo in the pickup trucks' beds

	Put this ModuleScript in ServerScriptService (or ReplicatedStorage if client code needs it too).
	The load models (Load_Crates, Load_Barrels, Load_Logs, Load_Hay, Load_Apples) must be imported
	into the same LowpolyAssets folder as the other models (ServerStorage or ReplicatedStorage).

	    local TruckLoads = require(game.ServerScriptService.TruckLoads)
	    TruckLoads.set(truck, "Load_Logs")   -- put logs in the bed (replaces any current load)
	    TruckLoads.set(truck, nil)           -- empty the bed
	    TruckLoads.cycle(truck)              -- next load in the list, then empty, then round again
	    TruckLoads.random(truck)             -- any load
	    TruckLoads.get(truck)                -- "Load_Logs" or nil

	`truck` is a Truck_Orange / Truck_Blue model (any model whose body part is named "..._Body").
	The load is a child Model called "Load", welded to the body, Massless and non-colliding so it
	rides along without changing how the truck drives. The truck also gets a "Load" attribute
	with the load's name, handy for delivery missions.
]]

local TruckLoads = {}

TruckLoads.LOADS = { "Load_Crates", "Load_Barrels", "Load_Logs", "Load_Hay", "Load_Apples" }

-- Folder that holds the imported load models. Leave nil to look for a "LowpolyAssets" folder
-- in ServerStorage, then ReplicatedStorage.
TruckLoads.Assets = nil

-- Measured from the models: offset from the truck body's centre to the middle of the bed floor (studs)
local BED_OFFSET = Vector3.new(0.000, -1.982, 5.429)

-- Each load: offset from its bounding-box centre to its origin (the bed-floor point), and its size
local INFO = {
	["Load_Crates"] = { origin = Vector3.new(-0.000, -2.821, 0.000), size = Vector3.new(6.397, 5.643, 6.611) },
	["Load_Barrels"] = { origin = Vector3.new(-0.000, -1.429, 0.000), size = Vector3.new(5.157, 2.857, 6.415) },
	["Load_Logs"] = { origin = Vector3.new(-0.000, -1.857, -0.007), size = Vector3.new(6.250, 3.750, 6.697) },
	["Load_Hay"] = { origin = Vector3.new(-0.000, -1.848, 0.004), size = Vector3.new(6.214, 3.768, 6.651) },
	["Load_Apples"] = { origin = Vector3.new(-0.000, -1.439, 0.000), size = Vector3.new(6.397, 2.878, 6.611) },
}

local function assetsFolder()
	if TruckLoads.Assets then
		return TruckLoads.Assets
	end
	local ok, serverStorage = pcall(function()
		return game:GetService("ServerStorage")
	end)
	local folder = ok and serverStorage and serverStorage:FindFirstChild("LowpolyAssets")
	if not folder then
		folder = game:GetService("ReplicatedStorage"):FindFirstChild("LowpolyAssets")
	end
	return folder
end

local function findBody(truck)
	for _, d in ipairs(truck:GetDescendants()) do
		if d:IsA("BasePart") and string.match(d.Name, "_Body$") then
			return d
		end
	end
	return nil
end

function TruckLoads.get(truck)
	local load = truck:FindFirstChild("Load")
	return load and load:GetAttribute("LoadType") or nil
end

function TruckLoads.clear(truck)
	local old = truck:FindFirstChild("Load")
	if old then
		old:Destroy()
	end
	truck:SetAttribute("Load", nil)
end

function TruckLoads.set(truck, loadName)
	TruckLoads.clear(truck)
	if loadName == nil then
		return nil
	end
	local info = INFO[loadName]
	if not info then
		warn("TruckLoads: unknown load " .. tostring(loadName))
		return nil
	end
	local body = findBody(truck)
	if not body then
		warn("TruckLoads: " .. truck.Name .. " has no part named ..._Body")
		return nil
	end
	local folder = assetsFolder()
	local template = folder and folder:FindFirstChild(loadName)
	if not template then
		warn("TruckLoads: import " .. loadName .. " into the LowpolyAssets folder")
		return nil
	end

	local load = template:Clone()
	load.Name = "Load"
	load:SetAttribute("LoadType", loadName)
	local cf = load:GetBoundingBox()
	load.WorldPivot = CFrame.new(cf.Position + info.origin)
	load:PivotTo(body.CFrame * CFrame.new(BED_OFFSET))
	for _, p in ipairs(load:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = body.Anchored
			p.CanCollide = false
			p.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = p
			weld.Parent = p
		end
	end
	load.Parent = truck
	truck:SetAttribute("Load", loadName)
	return load
end

function TruckLoads.cycle(truck)
	local current = TruckLoads.get(truck)
	local index = current and table.find(TruckLoads.LOADS, current)
	local nextName
	if not index then
		nextName = TruckLoads.LOADS[1]
	elseif index < #TruckLoads.LOADS then
		nextName = TruckLoads.LOADS[index + 1]
	end
	return TruckLoads.set(truck, nextName)
end

function TruckLoads.random(truck)
	return TruckLoads.set(truck, TruckLoads.LOADS[math.random(1, #TruckLoads.LOADS)])
end

return TruckLoads
