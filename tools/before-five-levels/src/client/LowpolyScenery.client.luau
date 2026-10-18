-- Draw the supplied Blender scenery geometry on each client. EditableMesh content
-- does not replicate from the server, so all scenery shares one client mesh.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local dataFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LowpolyMeshData")
local layout = require(ReplicatedStorage.Shared:WaitForChild("LevelConfig")).Resolve()
local scenery = workspace:WaitForChild("GeneratedLevel"):WaitForChild(layout.Name):WaitForChild("LowpolyScenery")

while not scenery:GetAttribute("Ready") do
	scenery:GetAttributeChangedSignal("Ready"):Wait()
end

local function render()
	local mesh = assert(AssetService:CreateEditableMesh(), "EditableMesh memory budget exhausted")
	local palette = require(dataFolder:WaitForChild("Palette"))
	local colorIds = {}
	for i, hex in ipairs(palette) do
		colorIds[i] = mesh:AddColor(Color3.fromHex(hex), 0)
	end

	local vertices = {}
	local faces = {}
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, model in ipairs(scenery:GetChildren()) do
		if model:IsA("Model") then
			local source = dataFolder:FindFirstChild(model.Name)
			if source then
				local base = model:GetPivot()
				for _, piece in ipairs(require(source)) do
					local offset = Vector3.new(piece.Offset[1], piece.Offset[2], piece.Offset[3])
					local start = #vertices
					for i = 1, #piece.Vertices, 3 do
						local point = base:PointToWorldSpace(Vector3.new(piece.Vertices[i], piece.Vertices[i+1], piece.Vertices[i+2]) + offset)
						vertices[#vertices+1] = point
						low = low:Min(point)
						high = high:Max(point)
					end
					for i = 1, #piece.Faces, 4 do
						faces[#faces+1] = {start + piece.Faces[i], start + piece.Faces[i+1], start + piece.Faces[i+2], piece.Faces[i+3]}
					end
				end
			end
		end
	end
	assert(#vertices > 0, "No Blender scenery geometry found")
	local center = (low + high) * 0.5
	local vertexIds = table.create(#vertices)
	for i, point in ipairs(vertices) do
		vertexIds[i] = mesh:AddVertex(point - center)
		if i % 1500 == 0 then task.wait() end
	end
	for i, face in ipairs(faces) do
		local id = mesh:AddTriangle(vertexIds[face[1]], vertexIds[face[2]], vertexIds[face[3]])
		local color = colorIds[face[4]]
		mesh:SetFaceColors(id, {color, color, color})
		if i % 1000 == 0 then task.wait() end
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {CollisionFidelity = Enum.CollisionFidelity.Box})
	part.Name = "BlenderSceneryMesh"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.new(1, 1, 1)
	part.CFrame = CFrame.new(center)
	part.Parent = scenery
	-- Keep server Parts as fallback until the original geometry is ready.
	for _, model in ipairs(scenery:GetChildren()) do
		if model:IsA("Model") and dataFolder:FindFirstChild(model.Name) then
			for _, child in ipairs(model:GetDescendants()) do
				if child:IsA("BasePart") then child.LocalTransparencyModifier = 1 end
			end
		end
	end
	print(string.format("Blender scenery ready: %d vertices, %d faces", #vertices, #faces))
end

local ok, err = pcall(render)
if not ok then warn("Blender scenery renderer: " .. tostring(err)) end
