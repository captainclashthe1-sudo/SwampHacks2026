--[[
	TruckLoadDemo  (Script)  —  walk up to any truck and press E to change its load

	Put this Script in ServerScriptService next to the TruckLoads ModuleScript.
	It adds a "Change load" prompt to every Truck_* model in the workspace (including ones that
	appear later), cycling Crates → Barrels → Logs → Hay → Apples → empty.
	Swap this for your own mission logic when you're ready; it only shows how to call TruckLoads.
]]

local TruckLoads = require(script.Parent:WaitForChild("TruckLoads"))

local function hook(truck)
	if truck:FindFirstChild("LoadPrompt", true) then
		return
	end
	local body
	for _, d in ipairs(truck:GetDescendants()) do
		if d:IsA("BasePart") and string.match(d.Name, "_Body$") then
			body = d
			break
		end
	end
	if not body then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LoadPrompt"
	prompt.ActionText = "Change load"
	prompt.ObjectText = "Truck"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function()
		TruckLoads.cycle(truck)
	end)
end

local function isTruck(inst)
	return inst:IsA("Model") and string.match(inst.Name, "^Truck_") ~= nil
end

for _, d in ipairs(workspace:GetDescendants()) do
	if isTruck(d) then
		hook(d)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if isTruck(d) then
		task.defer(hook, d)
	end
end)
