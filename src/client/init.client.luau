-- Mouse-driven bridge tools. All mutations are requested from the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local Sfx = require(script:WaitForChild("Sfx"))
local mouse = player:GetMouse()
local playerScripts = player:WaitForChild("PlayerScripts")
local oldUIActions = playerScripts:FindFirstChild("BridgeUIActions")
if oldUIActions then oldUIActions:Destroy() end
local uiActions = Instance.new("BindableEvent")
uiActions.Name = "BridgeUIActions"
uiActions.Parent = playerScripts
local CampaignConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LevelConfig"))
local Config=CampaignConfig.ForLevel(player:GetAttribute("ActiveLevelId") or 1)
local layout = Config.Resolve()
local remote = ReplicatedStorage:WaitForChild("BridgeBuildRemotes"):WaitForChild("Action")
local level = workspace:WaitForChild("GeneratedLevel"):WaitForChild(layout.Name)
local builds = level:WaitForChild("PlayerBuilds")
local anchors = level:WaitForChild("BridgeAnchors")
local GRID = 2
local selectedTool = "Joint"
local selectedMaterial = "Wood"
local serverBudget
local simulationSnapshot
local deckDrag=nil
local selectedStart = nil
local selectedObject = nil
local selectedHeight = layout.RoadTopY
local lastGuiClickAt = -math.huge
local buildMode = true
local levelSelected = player:GetAttribute("LevelSelected") == true
local rightDragging = false
local lastDragPointer
local cameraFocus = layout.Origin + Vector3.new(0, -2, 0)
local cameraYaw = 0
local cameraPitch = math.rad(55)
local cameraDistance = 85
local MAX_BUILD_ZOOM = 120
local function clampBuildCameraFocus(position)
	local reach = Config.Road.Gap / 2 + Config.Road.Length + 18
	local origin = layout.Origin
	return Vector3.new(
		math.clamp(position.X, origin.X - reach, origin.X + reach),
		math.clamp(position.Y, layout.ZoneMin.Y - 14, layout.ZoneMax.Y + 24),
		math.clamp(position.Z, origin.Z - 58, origin.Z + 58)
	)
end
player.CameraMaxZoomDistance = 90
local savedHumanoid
local savedWalkSpeed
local savedJumpPower
local savedJumpHeight

local oldGui = player.PlayerGui:FindFirstChild("BridgeBuilderGui")
if oldGui then oldGui:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "BridgeBuilderGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(330, 410)
panel.Position = UDim2.fromOffset(18, 110)
panel.BackgroundColor3 = Color3.fromRGB(21, 32, 44)
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 9)
corner.Parent = panel

local CREAM = Color3.fromRGB(246, 236, 214)
local BROWN = Color3.fromRGB(110, 67, 37)
local TAN = Color3.fromRGB(230, 207, 173)
local BLUE = Color3.fromRGB(47, 168, 240)
local GREEN = Color3.fromRGB(140, 214, 58)
local RED = Color3.fromRGB(240, 82, 74)
local YELLOW = Color3.fromRGB(247, 198, 40)
local function stylePanel(frame, rounder)
	frame.BackgroundColor3 = CREAM
	rounder.CornerRadius = UDim.new(0, 24)
	local border = Instance.new("UIStroke")
	border.Color = BROWN
	border.Thickness = 3
	border.Parent = frame
	local inner = Instance.new("Frame")
	inner.Name = "StitchedBorder"
	inner.Position = UDim2.fromOffset(8, 8)
	inner.Size = UDim2.new(1, -16, 1, -16)
	inner.BackgroundTransparency = 1
	inner.ZIndex = 0
	inner.Parent = frame
	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0, 18)
	innerCorner.Parent = inner
	local stitch = Instance.new("UIStroke")
	stitch.Color = Color3.fromRGB(217, 195, 160)
	stitch.Thickness = 1.5
	stitch.Parent = inner
end
stylePanel(panel, corner)
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local function textLabel(name, value, y, height, parent)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromOffset(12, y)
	label.Size = UDim2.fromOffset(306, height)
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextColor3 = BROWN
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 16
	label.Parent = parent or panel
	return label
end

local function button(name, value, x, y, width, parent)
	local item = Instance.new("TextButton")
	item.Name = name
	item.Position = UDim2.fromOffset(x, y)
	item.Size = UDim2.fromOffset(width, 32)
	item.BackgroundColor3 = BLUE
	item.BorderSizePixel = 0
	item.Text = value
	item.TextColor3 = Color3.new(1, 1, 1)
	item.Font = Enum.Font.FredokaOne
	item.TextSize = 15
	item.Parent = parent or panel
	local rounding = Instance.new("UICorner")
	rounding.CornerRadius = UDim.new(0, 10)
	rounding.Parent = item
	local border = Instance.new("UIStroke")
	border.Color = BROWN
	border.Thickness = 2
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = item
	return item
end

local buildTitle = textLabel("Title", "BRIDGE BUILDER", 9, 27)
buildTitle.Font = Enum.Font.FredokaOne
buildTitle.TextColor3 = RED
buildTitle.TextSize = 22
buildTitle.Active = true
local jointButton = button("JointButton", "Joint", 12, 41, 58)
local beamButton = button("BeamButton", "Deck", 74, 41, 58)
local supportButton = button("SupportButton", "Cable", 136, 41, 58)
local archButton = button("ArchButton", "Arch", 198, 41, 58)
local selectButton = button("DeleteButton", "Delete", 260, 41, 58)
for _, toolButton in ipairs({jointButton, beamButton, supportButton, archButton, selectButton}) do toolButton.TextSize = 12 end
textLabel("MaterialTitle", "Beam material", 83, 20)
local woodButton = button("WoodButton", "Wood", 12, 107, 94)
local steelButton = button("SteelButton", "Steel", 118, 107, 94)
local concreteButton = button("ConcreteButton", "Concrete", 224, 107, 94)
local cancelButton = button("CancelButton", "Cancel / Esc", 12, 148, 144)
local undoButton = button("UndoButton", "Undo", 162, 148, 75)
local redoButton = button("RedoButton", "Redo", 243, 148, 75)
local testButton = button("TestModeButton", "Test Mode  (B to return)", 12, 188, 306)
local budgetTitle = textLabel("BudgetTitle", "MONEY & MATERIALS", 228, 20)
budgetTitle.Font = Enum.Font.FredokaOne
budgetTitle.TextColor3 = RED
local budgetTotals = textLabel("BudgetTotals", "Loading funds...", 252, 25)
local budgetBalance = textLabel("BudgetBalance", "", 278, 25)
local priceLabel = textLabel("MaterialPrice", "", 304, 25)
local heightLabel = textLabel("HeightLabel", "", 331, 25)
local status = textLabel("Status", "Select a tool to build.", 359, 42)
status.TextColor3 = Color3.fromRGB(76, 143, 27)

local tipPanel = Instance.new("Frame")
tipPanel.Name = "TutorialTip"
tipPanel.Size = UDim2.fromOffset(265, 108)
tipPanel.Position = UDim2.fromOffset(400, 110)
tipPanel.BackgroundColor3 = CREAM
tipPanel.BorderSizePixel = 0
tipPanel.Visible = false
tipPanel.Parent = gui
local tipCorner = Instance.new("UICorner")
tipCorner.CornerRadius = UDim.new(0, 17)
tipCorner.Parent = tipPanel
local tipBorder = Instance.new("UIStroke")
tipBorder.Color = BROWN
tipBorder.Thickness = 2
tipBorder.Parent = tipPanel
local tipTitle = Instance.new("TextLabel")
tipTitle.Name = "Title"
tipTitle.Position = UDim2.fromOffset(14, 10)
tipTitle.Size = UDim2.new(1, -28, 0, 28)
tipTitle.BackgroundTransparency = 1
tipTitle.Font = Enum.Font.FredokaOne
tipTitle.TextSize = 20
tipTitle.TextColor3 = RED
tipTitle.TextXAlignment = Enum.TextXAlignment.Left
tipTitle.Parent = tipPanel
local tipBody = Instance.new("TextLabel")
tipBody.Name = "Body"
tipBody.Position = UDim2.fromOffset(14, 38)
tipBody.Size = UDim2.new(1, -28, 1, -48)
tipBody.BackgroundTransparency = 1
tipBody.Font = Enum.Font.FredokaOne
tipBody.TextSize = 15
tipBody.TextColor3 = BROWN
tipBody.TextWrapped = true
tipBody.TextXAlignment = Enum.TextXAlignment.Left
tipBody.TextYAlignment = Enum.TextYAlignment.Top
tipBody.Parent = tipPanel
local tipScale = Instance.new("UIScale")
tipScale.Parent = tipPanel
local TIP_TEXT = {
	Joint = {"JOINT", "Click in the build zone to place a joint. Ctrl + wheel sets its height."},
	Beam = {"DECK", "Click two joints or fixed points to connect a drivable deck."},
	Support = {"CABLE", "Connect two points. Cables carry tension and the car passes through them."},
	Arch = {"ARCH", "Connect level points to brace the deck. On Level 5, connect an anchor to your raised ramp-tip joint."},
	Delete = {"DELETE", "Click your piece to remove it. The Delete key also works."},
	Wood = {"WOOD", "Light and cheap, but bends more under load."},
	Steel = {"STEEL", "Stiff and strong when braced; heavy spans need support."},
	Concrete = {"CONCRETE", "Strong in compression, but heavy and weaker in bending."},
}
local tipSequence = 0
local function presentTip(title, body, force)
	if not levelSelected or (not force and player:GetAttribute("TutorialTipsEnabled") == false) then return end
	tipSequence += 1
	local sequence = tipSequence
	tipTitle.Text = title
	tipBody.Text = body
	tipPanel.Visible = true
	task.spawn(function()
		for _ = 1, 3 do
			if tipSequence ~= sequence then return end
			tipBorder.Color = Color3.fromRGB(255, 199, 45)
			task.wait(0.12)
			tipBorder.Color = BROWN
			task.wait(0.12)
		end
	end)
	task.delay(7, function()
		if tipSequence == sequence then tipPanel.Visible = false end
	end)
end
local function showTip(name)
	local entry = TIP_TEXT[name]
	if entry then presentTip(entry[1] .. " TIP", entry[2], false) end
end
local function showLevelTip(force,tutorial,onClose)
	if not levelSelected or (not force and player:GetAttribute("TutorialTipsEnabled") == false) then return end
	local overlay = gui:FindFirstChild("LevelTipOverlay")
	if overlay then overlay:Destroy() end
	overlay = Instance.new("Frame")
	overlay.Name = "LevelTipOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(16, 27, 39)
	overlay.BackgroundTransparency = 0.36
	overlay.ZIndex = 20
	overlay.Parent = gui
	local card = Instance.new("Frame")
	card.Name = "LevelTipCard"
	card.AnchorPoint = Vector2.new(.5, .5)
	card.Position = UDim2.fromScale(.5, .5)
	card.Size = UDim2.new(.78, 0, 0, 230)
	card.SizeConstraint = Enum.SizeConstraint.RelativeXX
	card.BackgroundColor3 = CREAM
	card.ZIndex = 21
	card.Parent = overlay
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(530, 230)
	limit.MinSize = Vector2.new(280, 230)
	limit.Parent = card
	local rounding = Instance.new("UICorner")
	rounding.CornerRadius = UDim.new(0, 22)
	rounding.Parent = card
	local border = Instance.new("UIStroke")
	border.Color = BROWN
	border.Thickness = 3
	border.Parent = card
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundColor3 = RED
	title.Size = UDim2.new(1, 0, 0, 52)
	title.Text = tutorial and "HOW TO BUILD" or "LEVEL " .. Config.Id .. " TIP"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 27
	title.ZIndex = 22
	title.Parent = card
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 20)
	titleCorner.Parent = title
	local body = Instance.new("TextLabel")
	body.Name = "TipText"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(25, 68)
	body.Size = UDim2.new(1, -50, 0, 86)
	body.Text = tutorial and "Place joints, then choose Deck and click two joints to connect them. Press Test, enter the car, and start the drive." or Config.Hint
	body.TextColor3 = BROWN
	body.Font = Enum.Font.FredokaOne
	body.TextSize = 22
	body.TextWrapped = true
	body.ZIndex = 22
	body.Parent = card
	local close = Instance.new("TextButton")
	close.Name = "GotIt"
	close.AnchorPoint = Vector2.new(.5, 0)
	close.Position = UDim2.new(.5, 0, 0, 166)
	close.Size = UDim2.fromOffset(180, 48)
	close.BackgroundColor3 = GREEN
	close.Text = "GOT IT"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 22
	close.ZIndex = 22
	close.Parent = card
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 14)
	closeCorner.Parent = close
	close.Activated:Connect(function()
		overlay:Destroy()
		if onClose then onClose() end
	end)
end
player:GetAttributeChangedSignal("TutorialTipsEnabled"):Connect(function()
	if player:GetAttribute("TutorialTipsEnabled") == false then
		tipSequence += 1
		tipPanel.Visible = false
	end
end)

local testPanel = Instance.new("Frame")
testPanel.Name = "SimulationPanel"
testPanel.Size = UDim2.fromOffset(330, 438)
testPanel.Position = UDim2.fromOffset(18, 110)
testPanel.BackgroundColor3 = Color3.fromRGB(21, 32, 44)
testPanel.BorderSizePixel = 0
testPanel.Active = true
testPanel.Visible = false
testPanel.Parent = gui
local testCorner = Instance.new("UICorner")
testCorner.CornerRadius = UDim.new(0, 9)
testCorner.Parent = testPanel
stylePanel(testPanel, testCorner)
local testPanelScale = Instance.new("UIScale")
testPanelScale.Parent = testPanel
local testTitle = textLabel("Title", "STRUCTURE TEST", 10, 26, testPanel)
testTitle.Font = Enum.Font.FredokaOne
testTitle.TextColor3 = RED
testTitle.TextSize = 22
testTitle.Active = true
local startButton = button("StartSimulationButton", "Start Simulation", 12, 42, 146, testPanel)
local resetButton = button("ResetSimulationButton", "🔄 Reset", 170, 42, 148, testPanel)
local testState = textLabel("TestState", "Ready to test.", 83, 26, testPanel)
local testProgress = textLabel("TestProgress", "Progress: 0%", 111, 24, testPanel)
local testStress = textLabel("TestStress", "Peak stress: 0%", 138, 24, testPanel)
local testDeflection = textLabel("TestDeflection", "Bridge sag: 0 studs", 164, 24, testPanel)
local testStatus = textLabel("TestStatus", "Walk to the test vehicle and press E to enter.", 190, 55, testPanel)
testStatus.TextColor3 = Color3.fromRGB(76, 143, 27)
local testReward = textLabel("TestReward", "Reach FINISH to earn Tokens.", 254, 40, testPanel)
testReward.TextColor3 = BROWN
local speedDown = button("CarSpeedDown", "−", 12, 303, 42, testPanel)
local speedLabel = textLabel("CarSpeed", "", 307, 27, testPanel)
speedLabel.Position = UDim2.fromOffset(62, 307)
speedLabel.Size = UDim2.fromOffset(195, 27)
speedLabel.TextXAlignment = Enum.TextXAlignment.Center
local speedUp = button("CarSpeedUp", "+", 276, 303, 42, testPanel)
local selectedCarSpeed = Config.Simulation.BridgeSpeed
local function updateSpeedLabel()
	speedLabel.Text = string.format("CAR SPEED  %.1f", selectedCarSpeed)
end
updateSpeedLabel()
local returnButton = button("ReturnToBuildButton", "Return to Build  (B)", 12, 349, 306, testPanel)

local nextLevelButton=button("NextLevelButton","Next level",12,393,306,testPanel)
nextLevelButton.Visible=false
local panelLocation = Vector2.new(18, 110)
local function positionPanels()
	local viewport = workspace.CurrentCamera.ViewportSize
	if viewport.X < 200 or viewport.Y < 200 then return end
	local widest = math.max(panel.Size.X.Offset * panelScale.Scale, testPanel.Size.X.Offset * testPanelScale.Scale)
	local tallest = math.max(panel.Size.Y.Offset * panelScale.Scale, testPanel.Size.Y.Offset * testPanelScale.Scale)
	panelLocation = Vector2.new(
		math.clamp(panelLocation.X, 8, math.max(8, viewport.X - widest - 8)),
		math.clamp(panelLocation.Y, 8, math.max(8, viewport.Y - tallest - 8))
	)
	local position = UDim2.fromOffset(panelLocation.X, panelLocation.Y)
	panel.Position = position
	testPanel.Position = position
	local tipWidth = tipPanel.Size.X.Offset * tipScale.Scale
	local tipHeight = tipPanel.Size.Y.Offset * tipScale.Scale
	local tipX = panelLocation.X + panel.Size.X.Offset * panelScale.Scale + 16
	local tipY = panelLocation.Y
	if tipX + tipWidth > viewport.X - 8 then
		tipX = math.max(8, viewport.X - tipWidth - 8)
		tipY = panelLocation.Y - tipHeight - 10
		if tipY < 8 then tipY = math.min(viewport.Y - tipHeight - 8, panelLocation.Y + tallest + 10) end
	end
	tipPanel.Position = UDim2.fromOffset(tipX, tipY)
end

local function dragHint(parent)
	local hint = Instance.new("TextLabel")
	hint.Name = "DragHint"
	hint.Position = UDim2.fromOffset(250, 12)
	hint.Size = UDim2.fromOffset(65, 20)
	hint.BackgroundTransparency = 1
	hint.Text = "MOVE"
	hint.TextColor3 = BROWN
	hint.Font = Enum.Font.FredokaOne
	hint.TextSize = 12
	hint.Active = true
	hint.Parent = parent
	return hint
end
local buildDragHint = dragHint(panel)
local testDragHint = dragHint(testPanel)
local dragging = false
local dragStart
local dragOrigin
local dragTouch
local function beginDrag(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	dragging = true
	dragTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
	dragStart = Vector2.new(input.Position.X, input.Position.Y)
	dragOrigin = panelLocation
	lastGuiClickAt = os.clock()
end
for _, handle in ipairs({buildTitle, testTitle, buildDragHint, testDragHint}) do
	handle.InputBegan:Connect(beginDrag)
end
UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= dragTouch then return end
	local pointer = Vector2.new(input.Position.X, input.Position.Y)
	panelLocation = dragOrigin + pointer - dragStart
	positionPanels()
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input == dragTouch then
		dragging = false
		dragTouch = nil
	end
end)

local function updateUISizing()
	local viewport = workspace.CurrentCamera.ViewportSize
	if viewport.X < 200 or viewport.Y < 200 then return end
	local preference = math.clamp(tonumber(player:GetAttribute("BridgeUIScale")) or 1, 0.8, 1.3)
	local requested = 1.14 * preference
	local availableHeight = math.max(240, viewport.Y - 132)
	local scale = math.min(requested, availableHeight / panel.Size.Y.Offset, (viewport.X - 36) / panel.Size.X.Offset)
	panelScale.Scale = scale
	testPanelScale.Scale = math.min(requested, availableHeight / testPanel.Size.Y.Offset, (viewport.X - 36) / testPanel.Size.X.Offset)
	tipScale.Scale = math.min(scale, 1.1)
	positionPanels()
end
player:GetAttributeChangedSignal("BridgeUIScale"):Connect(updateUISizing)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateUISizing)
updateUISizing()

local function money(amount)
	local digits = tostring(math.floor(amount))
	return "$" .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function setStatus(message, ok)
	status.Text = message
	status.TextColor3 = ok and Color3.fromRGB(76, 143, 27) or Color3.fromRGB(168, 48, 43)
end

local selectionHighlight = Instance.new("Highlight")
selectionHighlight.Name = "BuildSelection"
selectionHighlight.FillColor = Color3.fromRGB(74, 220, 255)
selectionHighlight.FillTransparency = 0.78
selectionHighlight.OutlineColor = Color3.fromRGB(126, 244, 255)
selectionHighlight.OutlineTransparency = 0
selectionHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
selectionHighlight.Enabled = false
selectionHighlight.Parent = workspace.CurrentCamera
local hoverBox = Instance.new("SelectionBox")
hoverBox.Name = "BuildHoverBox"
hoverBox.Color3 = Color3.fromRGB(255, 226, 88)
hoverBox.LineThickness = 0.05
hoverBox.SurfaceTransparency = 1
hoverBox.Parent = workspace.CurrentCamera
local function ownedObjectFromPart(part, owned)
	while part and part ~= owned do
		if part:GetAttribute("ObjectId") then return part end
		part = part.Parent
	end
	return nil
end

local function memberScreenDistance(part, pointer, camera)
	local half = part.Size.Z / 2
	local first, firstVisible = camera:WorldToViewportPoint(part.CFrame:PointToWorldSpace(Vector3.new(0, 0, -half)))
	local last, lastVisible = camera:WorldToViewportPoint(part.CFrame:PointToWorldSpace(Vector3.new(0, 0, half)))
	if not firstVisible or not lastVisible or first.Z <= 0 or last.Z <= 0 then return math.huge end
	local a = Vector2.new(first.X, first.Y)
	local span = Vector2.new(last.X, last.Y) - a
	local fraction = math.clamp((pointer - a):Dot(span) / math.max(span:Dot(span), 0.001), 0, 1)
	return (pointer - (a + span * fraction)).Magnitude
end

local function hoverPartWithinTwoPixels()
	local owned = builds:FindFirstChild(tostring(player.UserId))
	if not owned then return nil end
	local target = mouse.Target
	if target and target:IsDescendantOf(owned) and ownedObjectFromPart(target, owned) then return target end
	local camera = workspace.CurrentCamera
	local pointer = Vector2.new(mouse.X, mouse.Y)
	local best, bestDistance = nil, 2
	local joints = owned:FindFirstChild("Joints")
	if joints then
		for _, joint in ipairs(joints:GetChildren()) do
			local point, visible = camera:WorldToViewportPoint(joint.Position)
			if visible and point.Z > 0 then
				local distance = (pointer - Vector2.new(point.X, point.Y)).Magnitude
				if distance <= bestDistance then best, bestDistance = joint, distance end
			end
		end
	end
	local beams = owned:FindFirstChild("Beams")
	if beams then
		for _, beam in ipairs(beams:GetChildren()) do
			for _, visual in ipairs({beam, beam:FindFirstChild("ParallelCable")}) do
				if visual and visual:IsA("BasePart") then
					local distance = memberScreenDistance(visual, pointer, camera)
					if distance <= bestDistance then best, bestDistance = visual, distance end
				end
			end
		end
	end
	return best
end

local function selectObject(part)
	selectedObject = part
	selectionHighlight.Adornee = part
	selectionHighlight.Enabled = part ~= nil
	if part then setStatus(part.Name .. " selected. Press Delete to remove it.", true) end
end

local function updateButtons()
	for _, pair in ipairs({{jointButton, "Joint"}, {beamButton, "Beam"}, {supportButton, "Support"}, {archButton, "Arch"}, {selectButton, "Delete"}}) do
		pair[1].BackgroundColor3 = selectedTool == pair[2] and GREEN or TAN
		pair[1].TextColor3 = selectedTool == pair[2] and Color3.new(1, 1, 1) or BROWN
	end
	woodButton.BackgroundColor3 = selectedMaterial == "Wood" and Color3.fromRGB(135, 91, 51) or TAN
	steelButton.BackgroundColor3 = selectedMaterial == "Steel" and BLUE or TAN
	concreteButton.BackgroundColor3 = selectedMaterial == "Concrete" and Color3.fromRGB(143, 151, 154) or TAN
	for _, materialButton in ipairs({woodButton, steelButton, concreteButton}) do
		materialButton.TextColor3 = materialButton.BackgroundColor3 == TAN and BROWN or Color3.new(1, 1, 1)
	end
	if serverBudget then
		budgetTotals.Text = "Spent " .. money(serverBudget.Spent) .. "    Refunded " .. money(serverBudget.Refunded)
		budgetBalance.Text = "Total money " .. money(serverBudget.Remaining)
		priceLabel.Text = selectedMaterial .. ": " .. money(serverBudget.PricePerStud[selectedMaterial]) .. " per stud"
	end
	heightLabel.Text = "Joint height: " .. tostring(selectedHeight) .. "  •  Ctrl + wheel"
end

local function applyBudget(budget)
	if type(budget) ~= "table" or type(budget.PricePerStud) ~= "table" then return end
	serverBudget = budget
	updateButtons()
end

local lastSoundPhase = nil
local lastBrokenCount = 0
local function showSimulation(snapshot)
	if type(snapshot) ~= "table" then return end
	if (snapshot.BrokenCount or 0) > lastBrokenCount then
		Sfx.Play((snapshot.BreakMaterial or "Wood") .. "Break")
		Sfx.Play("Collapse")
	end
	if snapshot.Phase == "Failed" and lastSoundPhase ~= "Failed" then
		Sfx.Play("Fail")
	elseif snapshot.Phase == "Completed" and lastSoundPhase ~= "Completed" then
		Sfx.Play("Win")
	end
	lastSoundPhase = snapshot.Phase
	lastBrokenCount = snapshot.BrokenCount or 0
	simulationSnapshot = snapshot
	testState.Text = snapshot.Phase == "Completed" and "LEVEL COMPLETE" or
		("State: " .. tostring(snapshot.Phase) .. (snapshot.Seated and "  •  In car" or "  •  Enter test vehicle"))
	testProgress.Text = "Progress: " .. tostring(snapshot.Progress or 0) .. "%   Broken beams: " .. tostring(snapshot.BrokenCount or 0)
	testStress.Text = "Peak stress: " .. tostring(snapshot.PeakStress or 0) .. "%  •  Beam meters show load"
	testDeflection.Text = "Bridge sag: " .. tostring(snapshot.Deflection or 0) .. " studs   Peak: " .. tostring(snapshot.PeakDeflection or 0)
	testStatus.Text = snapshot.Message or ""
	nextLevelButton.Visible=snapshot.Phase=="Completed"
 nextLevelButton.Text=Config.Id==5 and "Demo complete! Level select" or "Next level →"
	testReward.Text = snapshot.Phase == "Completed" and ((snapshot.Reward or 0)>0 and ("Reward earned: +" .. tostring(snapshot.Reward) .. " Tokens") or "Replay complete • reward already claimed")
		or "Reach FINISH to earn " .. tostring(Config.Progression.CompletionTokens) .. " Tokens."
	testStatus.TextColor3 = (snapshot.Phase == "Failed" or snapshot.Phase == "Collapsing")
		and Color3.fromRGB(168, 48, 43) or Color3.fromRGB(76, 143, 27)
	local canStart = snapshot.Phase == "Ready" and snapshot.Seated == true
	startButton.Active = canStart
	startButton.AutoButtonColor = canStart
	startButton.BackgroundColor3 = canStart and GREEN or TAN
	startButton.TextColor3 = canStart and Color3.new(1, 1, 1) or BROWN
	local canSetSpeed = snapshot.Phase == "Ready"
	for _, speedButton in ipairs({speedDown, speedUp}) do
		speedButton.Active = canSetSpeed
		speedButton.AutoButtonColor = canSetSpeed
		speedButton.BackgroundColor3 = canSetSpeed and BLUE or TAN
	end
	if not canSetSpeed and snapshot.CarSpeed then
		selectedCarSpeed = snapshot.CarSpeed
		updateSpeedLabel()
	end
end

local oldSpendingOverlay=player.PlayerGui:FindFirstChild("BridgeSpendingOverlay")
if oldSpendingOverlay then oldSpendingOverlay:Destroy() end
local spendingOverlay=Instance.new("ScreenGui")
spendingOverlay.Name="BridgeSpendingOverlay"
spendingOverlay.ResetOnSpawn=false
spendingOverlay.IgnoreGuiInset=true
spendingOverlay.DisplayOrder=100
spendingOverlay.Parent=player.PlayerGui
local popupSequence=0
local function showSpending(amount)
 if type(amount)~="number" or amount<=0 then return end
 popupSequence+=1
 local label=Instance.new("TextLabel")
 label.Name="SpendingPopup";label.BackgroundTransparency=1;label.Size=UDim2.fromOffset(220,34)
 label.AnchorPoint=Vector2.new(.5,.5);label.Position=UDim2.new(.5,0,.5,((popupSequence-1)%3)*34)
 label.Text=string.format("(-$%d)",amount);label.TextColor3=Color3.fromRGB(215,45,45)
 label.TextStrokeColor3=Color3.fromRGB(255,245,222);label.TextStrokeTransparency=.25
 label.Font=Enum.Font.FredokaOne;label.TextSize=26;label.ZIndex=40;label.Parent=spendingOverlay
 local tween=game:GetService("TweenService"):Create(label,TweenInfo.new(1.6),{Position=label.Position-UDim2.fromOffset(0,28),TextTransparency=1,TextStrokeTransparency=1})
 tween:Play();tween.Completed:Once(function() label:Destroy() end)
end
local function invokeServer(action, payload, skipSimulationDisplay)
	local transportOk, response = pcall(function() return remote:InvokeServer(action, payload or {}) end)
	if not transportOk or type(response) ~= "table" then return nil end
	applyBudget(response.Budget)
 if response.ok and (action=="Beam" or action=="Arch") then showSpending(response.PaidCost) end
	if response.ok then
		if action == "Joint" then
			Sfx.Play("Joint")
		elseif action == "Beam" or action == "Arch" then
			local material = (payload and payload.MaterialType) or selectedMaterial
			Sfx.Play(material .. "Place")
		elseif action == "Erase" or action == "Undo" or action == "Redo" then
			Sfx.Play("Joint")
	end
	end
	if not skipSimulationDisplay then showSimulation(response.Simulation) end
	return response
end

local function selectTool(tool)
 deckDrag=nil
	selectedTool = tool
	selectedStart = nil
	selectObject(nil)
	updateButtons()
	setStatus(tool .. " tool selected.", true)
	showTip(tool)
end
local function onButton(item, callback)
	item.MouseButton1Click:Connect(function()
		lastGuiClickAt = os.clock()
		callback()
	end)
end
onButton(jointButton, function() selectTool("Joint") end)
onButton(beamButton, function() selectTool("Beam") end)
onButton(supportButton, function() selectTool("Support") end)
onButton(archButton, function() selectTool("Arch") end)
onButton(selectButton, function() selectTool("Delete") end)
onButton(woodButton, function() selectedMaterial = "Wood"; updateButtons(); setStatus("Wood selected.", true); showTip("Wood") end)
onButton(steelButton, function() selectedMaterial = "Steel"; updateButtons(); setStatus("Steel selected.", true); showTip("Steel") end)
onButton(concreteButton, function() selectedMaterial = "Concrete"; updateButtons(); setStatus("Concrete selected.", true); showTip("Concrete") end)
onButton(cancelButton, function() selectedStart = nil; selectObject(nil); updateButtons(); setStatus("Selection cancelled.", true) end)
updateButtons()

local function sinkMovement()
	return Enum.ContextActionResult.Sink
end

local function setCharacterMovement(enabled)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if enabled then
		if humanoid == savedHumanoid then
			humanoid.WalkSpeed = savedWalkSpeed
			humanoid.JumpPower = savedJumpPower
			humanoid.JumpHeight = savedJumpHeight
		end
	else
		if humanoid ~= savedHumanoid then
			savedHumanoid = humanoid
			savedWalkSpeed = humanoid.WalkSpeed
			savedJumpPower = humanoid.JumpPower
			savedJumpHeight = humanoid.JumpHeight
		end
		humanoid:Move(Vector3.zero)
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
end

local function setBuildMode(enabled)
 deckDrag=nil
	if enabled and not buildMode then
		local response = invokeServer("ResetSimulation", {})
		if not response or not response.ok then
			testStatus.Text = response and response.message or "Could not reset simulation."
			return
		end
	end
	buildMode = enabled
	gui.Enabled = levelSelected
	player:SetAttribute("BridgeMode", enabled and "Build" or "Test")
	selectedStart = nil
	selectObject(nil)
	rightDragging = false
	lastDragPointer = nil
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local camera = workspace.CurrentCamera
	if enabled then
		setCharacterMovement(false)
		panel.Visible = true
		testPanel.Visible = false
		positionPanels()
		ContextActionService:BindActionAtPriority("BridgeBuildMovement", sinkMovement, false, 3000,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Q, Enum.KeyCode.E)
		camera.CameraType = Enum.CameraType.Scriptable
		setStatus("Build Mode. Press B to test.", true)
	else
		tipSequence += 1
		tipPanel.Visible = false
		setCharacterMovement(true)
		panel.Visible = false
		testPanel.Visible = true
		ContextActionService:UnbindAction("BridgeBuildMovement")
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
	end
	updateButtons()
end
onButton(testButton, function() setBuildMode(false) end)
local function changeCarSpeed(direction)
	if simulationSnapshot and simulationSnapshot.Phase ~= "Ready" then return end
	local rules = Config.Simulation
	selectedCarSpeed = math.clamp(selectedCarSpeed + direction * rules.CarSpeedStep, rules.MinCarSpeed, rules.MaxCarSpeed)
	updateSpeedLabel()
end
onButton(speedDown, function() changeCarSpeed(-1) end)
onButton(speedUp, function() changeCarSpeed(1) end)
local function requestStartSimulation()
	local response = invokeServer("StartSimulation", {CarSpeed = selectedCarSpeed})
	if not response then testStatus.Text = "Simulation request failed. Check Studio output."
	elseif not response.ok then testStatus.Text = response.message end
end
local function requestResetSimulation()
	local response = invokeServer("ResetSimulation", {})
	if not response then testStatus.Text = "Reset request failed. Check Studio output."
	elseif response.ok then testStatus.Text = response.message end
end
onButton(startButton, requestStartSimulation)
onButton(resetButton, requestResetSimulation)
onButton(returnButton, function() setBuildMode(true) end)
local selectingLevel=false
local function enterLevel(id)
 if selectingLevel then return end
 selectingLevel=true
 deckDrag=nil
 local response=invokeServer("SelectLevel",{LevelId=id},true)
 if response and response.ok then
  Config=CampaignConfig.ForLevel(id); layout=Config.Resolve()
  level=workspace.GeneratedLevel:WaitForChild(layout.Name)
  builds=level:WaitForChild("PlayerBuilds"); anchors=level:WaitForChild("BridgeAnchors")
  selectedStart=nil; selectObject(nil); selectedHeight=layout.RoadTopY
  selectedCarSpeed=Config.Simulation.BridgeSpeed; updateSpeedLabel()
  simulationSnapshot=nil; lastSoundPhase=nil; lastBrokenCount=0; nextLevelButton.Visible=false
  cameraFocus=layout.Origin+Vector3.new(0,0,0); cameraDistance=math.max(85,Config.Road.Gap+25)
  levelSelected=true; player:SetAttribute("LevelSelected",true)
  setBuildMode(true); setStatus(Config.Hint,true)
  invokeServer("SimulationStatus",{})
  uiActions:Fire("LevelEntered",id)
  if response.FirstTutorial then
   showLevelTip(false,true,function() if response.FirstTip then showLevelTip(false) end end)
  elseif response.FirstTip then showLevelTip(false) end
 else setStatus(response and response.message or "Level could not load.",false); uiActions:Fire("LevelError",response and response.message) end
 selectingLevel=false
end
onButton(nextLevelButton,function()
 if Config.Id<5 then enterLevel(Config.Id+1) else uiActions:Fire("ShowLevels") end
end)
uiActions.Event:Connect(function(action,value)
	if action == "EnterLevel" then
		enterLevel(tonumber(value) or 1)
	elseif not levelSelected then return
	elseif action == "Build" then setBuildMode(true)
	elseif action == "Test" then setBuildMode(false)
	elseif action == "ShowLevelTip" then showLevelTip(true)
	elseif action == "Start" and not buildMode then requestStartSimulation()
	elseif action == "Reset" and not buildMode then requestResetSimulation() end
end)
setBuildMode(true)
player.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	if buildMode and humanoid then setCharacterMovement(false) end
end)

local function snap(value, origin)
	return origin + math.round((value - origin) / 2) * 2
end

local function inside(position)
	return position.X >= layout.ZoneMin.X and position.X <= layout.ZoneMax.X
		and position.Y >= layout.ZoneMin.Y and position.Y <= layout.ZoneMax.Y
		and position.Z >= layout.ZoneMin.Z and position.Z <= layout.ZoneMax.Z
end

local function pointerRay()
	return workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
end

local function planePoint()
	local ray = pointerRay()
	if math.abs(ray.Direction.Y) < 0.0001 then return nil end
	-- Pick X/Z on a fixed plane so scrolling moves the joint vertically in world space.
	local distance = (layout.RoadTopY - ray.Origin.Y) / ray.Direction.Y
	if distance <= 0 then return nil end
	local basePoint = ray.Origin + ray.Direction * distance
	return Vector3.new(basePoint.X, selectedHeight, basePoint.Z)
end

local function snapped(position)
	return Vector3.new(snap(position.X, layout.Origin.X), snap(position.Y, layout.Origin.Y), snap(position.Z, layout.Origin.Z))
end

local ghost = Instance.new("Part")
ghost.Name = "JointPreview"
ghost.Shape = Enum.PartType.Ball
ghost.Size = Vector3.new(1.4, 1.4, 1.4)
ghost.Anchored = true
ghost.CanCollide = false
ghost.CanTouch = false
ghost.CanQuery = false
ghost.Material = Enum.Material.Neon
ghost.Transparency = 1
ghost.Parent = workspace.CurrentCamera

-- A local-only light marks the first endpoint while a beam is unfinished.
local endpointGlow = Instance.new("Part")
endpointGlow.Name = "SelectedEndpointGlow"
endpointGlow.Shape = Enum.PartType.Ball
endpointGlow.Size = Vector3.new(2.8, 2.8, 2.8)
endpointGlow.Color = Color3.fromRGB(88, 245, 255)
endpointGlow.Material = Enum.Material.Neon
endpointGlow.Anchored = true
endpointGlow.CanCollide = false
endpointGlow.CanTouch = false
endpointGlow.CanQuery = false
endpointGlow.CastShadow = false
endpointGlow.Transparency = 1
endpointGlow.Parent = workspace.CurrentCamera
local endpointLight = Instance.new("PointLight")
endpointLight.Color = endpointGlow.Color
endpointLight.Brightness = 2.5
endpointLight.Range = 12
endpointLight.Enabled = false
endpointLight.Parent = endpointGlow

local function selectedEndpointPosition()
	local fixed = selectedStart and anchors:FindFirstChild(selectedStart .. "Target")
	if fixed then return fixed.Position end
	for _, owned in ipairs(builds:GetChildren()) do
		local joints = owned:FindFirstChild("Joints")
		if joints then
			for _, joint in ipairs(joints:GetChildren()) do
				if joint:GetAttribute("ObjectId") == selectedStart then return joint.Position end
			end
		end
	end
	return nil
end
RunService.RenderStepped:Connect(function(deltaTime)
	local camera = workspace.CurrentCamera
	if buildMode then
		local forward = Vector3.new(-math.sin(cameraYaw), 0, -math.cos(cameraYaw))
		local right = Vector3.new(math.cos(cameraYaw), 0, -math.sin(cameraYaw))
		local direction = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += forward end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= forward end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += right end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= right end
		if UserInputService:IsKeyDown(Enum.KeyCode.E) then direction += Vector3.yAxis end
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) then direction -= Vector3.yAxis end
		if direction.Magnitude > 0 then
			cameraFocus += direction.Unit * math.max(25, cameraDistance * 0.6) * deltaTime
		end
		cameraFocus = clampBuildCameraFocus(cameraFocus)
		local offset = Vector3.new(
			math.sin(cameraYaw) * math.cos(cameraPitch),
			math.sin(cameraPitch),
			math.cos(cameraYaw) * math.cos(cameraPitch)
		) * cameraDistance
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(cameraFocus + offset, cameraFocus)
	end
	hoverBox.Adornee = buildMode and levelSelected and not player:GetAttribute("MenuOpen") and hoverPartWithinTwoPixels() or nil
	if ghost.Parent ~= workspace.CurrentCamera then ghost.Parent = workspace.CurrentCamera end
	local point = buildMode and selectedTool == "Joint" and not rightDragging and planePoint()
	if point then
		ghost.Position = snapped(point)
		ghost.Color = inside(point) and inside(ghost.Position) and Color3.fromRGB(94, 245, 166) or Color3.fromRGB(255, 98, 98)
		ghost.Transparency = 0.5
	else
		ghost.Transparency = 1
	end
	if endpointGlow.Parent ~= workspace.CurrentCamera then endpointGlow.Parent = workspace.CurrentCamera end
	local selectedPosition = buildMode and selectedTool ~= "Joint" and selectedStart and selectedEndpointPosition()
	if selectedPosition then
		endpointGlow.Position = selectedPosition
		endpointGlow.Transparency = 0.35
		endpointLight.Enabled = true
	else
		endpointGlow.Transparency = 1
		endpointLight.Enabled = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not buildMode then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local controlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		if selectedTool == "Joint" and controlHeld then
			selectedHeight = math.clamp(selectedHeight + (input.Position.Z > 0 and GRID or -GRID), layout.ZoneMin.Y, layout.ZoneMax.Y)
			updateButtons()
		else
			cameraDistance = math.clamp(cameraDistance - input.Position.Z * 8, 35, MAX_BUILD_ZOOM)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseMovement and rightDragging then
		local pointer = UserInputService:GetMouseLocation()
		local movement = pointer - (lastDragPointer or pointer)
		lastDragPointer = pointer
		cameraYaw -= movement.X * 0.005
		cameraPitch = math.clamp(cameraPitch + movement.Y * 0.005, math.rad(8), math.rad(82))
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightDragging = false
		lastDragPointer = nil
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

local function callServer(action, payload)
	local response = invokeServer(action, payload)
	if not response then
		setStatus("Build request failed. Check Studio output.", false)
		return nil
	end
	setStatus(response.message or "No response.", response.ok == true)
	return response
end

local lastHistoryAction, lastHistoryAt = nil, -math.huge
local function requestHistory(action)
	if not buildMode or not levelSelected or player:GetAttribute("MenuOpen") or UserInputService:GetFocusedTextBox() then return end
	local now = os.clock()
	if lastHistoryAction == action and now - lastHistoryAt < 0.18 then return end
	lastHistoryAction, lastHistoryAt = action, now
	local response = callServer(action, {})
	if response and response.ok then
		deckDrag = nil
		selectedStart = nil
		selectObject(nil)
		updateButtons()
	end
end
onButton(undoButton, function() requestHistory("Undo") end)
onButton(redoButton, function() requestHistory("Redo") end)
ContextActionService:BindActionAtPriority("BridgeHistoryKeys", function(_, inputState, input)
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	local controlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	if not controlHeld then return Enum.ContextActionResult.Pass end
	if input.KeyCode == Enum.KeyCode.Z then requestHistory("Undo") else requestHistory("Redo") end
	return Enum.ContextActionResult.Sink
end, false, 3100, Enum.KeyCode.Z, Enum.KeyCode.Y)
local undoHeld, redoHeld = false, false
RunService.RenderStepped:Connect(function()
	local controlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	local undoNow = controlHeld and UserInputService:IsKeyDown(Enum.KeyCode.Z)
	local redoNow = controlHeld and UserInputService:IsKeyDown(Enum.KeyCode.Y)
	if undoNow and not undoHeld then requestHistory("Undo") end
	if redoNow and not redoHeld then requestHistory("Redo") end
	undoHeld, redoHeld = undoNow, redoNow
end)

local function screenDistance(point)
	local view, visible = workspace.CurrentCamera:WorldToViewportPoint(point)
	if not visible or view.Z <= 0 then return math.huge end
	return (Vector2.new(view.X, view.Y) - Vector2.new(mouse.X, mouse.Y)).Magnitude
end

local function clickedEndpoint()
	local owned = builds:FindFirstChild(tostring(player.UserId))
	local joints = owned and owned:FindFirstChild("Joints")
	local target = mouse.Target
	if target and joints and target:IsDescendantOf(joints) and target:GetAttribute("BuildKind") == "Joint" then
		return target:GetAttribute("ObjectId"), target
	end
	local nearestJoint, nearestJointDistance = nil, 24
	if joints then
		for _, joint in ipairs(joints:GetChildren()) do
			local distance = screenDistance(joint.Position)
			if distance < nearestJointDistance then nearestJoint, nearestJointDistance = joint, distance end
		end
	end
	if target and target:GetAttribute("AnchorId") and not nearestJoint then
		return target:GetAttribute("AnchorId"), target
	end
	local bestId, bestPart, bestScore = nil, nil, 1
	for _, target in ipairs(anchors:GetChildren()) do
		local nodeId = target:GetAttribute("AnchorId")
		if nodeId then
			local radius = (nodeId == "BridgeAnchor_Left" or nodeId == "BridgeAnchor_Right") and 38 or 27
			local score = screenDistance(target.Position) / radius
			if score < bestScore then bestId, bestPart, bestScore = nodeId, target, score end
		end
	end
	if nearestJoint and nearestJointDistance / 26 < bestScore then
		bestId, bestPart = nearestJoint:GetAttribute("ObjectId"), nearestJoint
	end
	return bestId, bestPart
end

local function pointerOverGui()
 local point=UserInputService:GetMouseLocation()
 for _,item in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(point.X,point.Y)) do
  if item.Visible and (item:IsA("GuiButton") or item.Active) then return true end
 end
 return false
end
local function beginDeckDrag(nodeId)
 local stroke={Last=nodeId,Material=selectedMaterial,Level=Config.Id,Pointer=Vector2.new(mouse.X,mouse.Y),Seen={[nodeId]=true}}
 deckDrag=stroke
 task.spawn(function()
  while deckDrag==stroke and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
   task.wait(.025)
   if deckDrag~=stroke or not buildMode or selectedTool~="Beam" or Config.Id~=stroke.Level or player:GetAttribute("MenuOpen") then break end
   local current=Vector2.new(mouse.X,mouse.Y)
   local previous=stroke.Pointer;stroke.Pointer=current
   if pointerOverGui() or (current-previous).Magnitude<1 then continue end
   local candidates={}; local owned=builds:FindFirstChild(tostring(player.UserId))
   local function candidate(part,id)
    if not id or stroke.Seen[id] then return end
    local v,visible=workspace.CurrentCamera:WorldToViewportPoint(part.Position)
    if not visible then return end
    local p=Vector2.new(v.X,v.Y);local delta=current-previous
    local t=math.clamp((p-previous):Dot(delta)/math.max(delta:Dot(delta),.01),0,1)
    if (p-(previous+delta*t)).Magnitude<=16 then table.insert(candidates,{Id=id,T=t}) end
   end
   if owned and owned:FindFirstChild("Joints") then for _,part in ipairs(owned.Joints:GetChildren()) do candidate(part,part:GetAttribute("ObjectId")) end end
   for _,part in ipairs(anchors:GetChildren()) do candidate(part,part:GetAttribute("AnchorId")) end
   table.sort(candidates,function(a,b) return a.T<b.T end)
   for _,item in ipairs(candidates) do
    if deckDrag~=stroke or not buildMode or Config.Id~=stroke.Level then break end
    stroke.Seen[item.Id]=true
    local response=callServer("Beam",{StartNodeId=stroke.Last,EndNodeId=item.Id,MaterialType=stroke.Material,MemberRole="Deck"})
    if not response or not response.ok then deckDrag=nil;break end
    stroke.Last=item.Id;selectedStart=item.Id;selectObject(nil);updateButtons()
   end
  end
 end)
end
UserInputService.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 then deckDrag=nil end
end)
local function clickedOwnedObject()
	local owned = builds:FindFirstChild(tostring(player.UserId))
	if not owned then return nil end
	local pointer = Vector2.new(mouse.X, mouse.Y)
	local camera = workspace.CurrentCamera
	local beams = owned:FindFirstChild("Beams")
	local cable, cableDistance = nil, 14
	if beams then
		for _, beam in ipairs(beams:GetChildren()) do
			if beam:GetAttribute("MemberRole") == "Support" then
				for _, visual in ipairs({beam, beam:FindFirstChild("ParallelCable")}) do
					if visual and visual:IsA("BasePart") then
						local distance = memberScreenDistance(visual, pointer, camera)
						if distance < cableDistance then cable, cableDistance = beam, distance end
					end
				end
			end
		end
	end
	if cable then return cable end
	local joints = owned:FindFirstChild("Joints")
	local nearest, bestDistance = nil, 20
	if joints then
		for _, joint in ipairs(joints:GetChildren()) do
			local distance = screenDistance(joint.Position)
			if distance < bestDistance then nearest, bestDistance = joint, distance end
		end
	end
	if nearest then return nearest end
	local target = mouse.Target
	if target and target:IsDescendantOf(owned) then
		local object = ownedObjectFromPart(target, owned)
		if object then return object end
	end
	bestDistance = 15
	if beams then
		for _, beam in ipairs(beams:GetChildren()) do
			local distance = memberScreenDistance(beam, pointer, camera)
			if distance < bestDistance then nearest, bestDistance = beam, distance end
		end
	end
	return nearest
end

local function deleteAtPointer()
	local picked = clickedOwnedObject()
	if not picked then
		setStatus("Aim at one of your joints or members to delete it.", false)
		return
	end
	local objectId = picked:GetAttribute("ObjectId")
	local response = callServer("Erase", {ObjectId = objectId})
	if response and response.ok then
		if selectedStart == objectId then selectedStart = nil end
		selectObject(nil)
		updateButtons()
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not levelSelected or player:GetAttribute("MenuOpen") then return end
	if input.KeyCode == Enum.KeyCode.B and not UserInputService:GetFocusedTextBox() then
		setBuildMode(not buildMode)
		return
	end
	if not buildMode then return end
	local controlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	if controlHeld and not UserInputService:GetFocusedTextBox()
		and (input.KeyCode == Enum.KeyCode.Z or input.KeyCode == Enum.KeyCode.Y) then
		requestHistory(input.KeyCode == Enum.KeyCode.Y and "Redo" or "Undo")
		return
	end
	if (input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Backspace)
		and not UserInputService:GetFocusedTextBox() then
		deleteAtPointer()
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 and not processed then
		rightDragging = true
		lastDragPointer = UserInputService:GetMouseLocation()
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		selectedStart = nil
		selectObject(nil)
		updateButtons()
		setStatus("Selection cancelled.", true)
		return
	end
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if os.clock() - lastGuiClickAt < 0.2 then return end
	-- Some Studio input paths do not mark GUI clicks as processed.
	local pointer = UserInputService:GetMouseLocation()
	local panelPosition = panel.AbsolutePosition
	local panelSize = panel.AbsoluteSize
	if pointer.X >= panelPosition.X and pointer.X <= panelPosition.X + panelSize.X
		and pointer.Y >= panelPosition.Y and pointer.Y <= panelPosition.Y + panelSize.Y then return end
 if selectedTool == "Delete" then
  deleteAtPointer()
	return
	end
 local endpointId=clickedEndpoint()
 local areaPoint=planePoint()
 if not endpointId and (not areaPoint or not inside(areaPoint)) then
  deckDrag=nil;selectedStart=nil;selectObject(nil);updateButtons();setStatus("Selection cleared.",true);return
	end
	if selectedTool == "Joint" then
		local point = planePoint()
		if not point then setStatus("Aim at the build zone.", false); return end
		callServer("Joint", {Position = point})
	elseif selectedTool == "Beam" or selectedTool == "Support" or selectedTool == "Arch" then
		local nodeId = endpointId
		if not nodeId then
			setStatus("Click a joint, yellow tile, or tower point.", false)
			return
		end
		if not selectedStart then
			selectedStart = nodeId
			updateButtons()
			setStatus("First endpoint selected.", true)
   if selectedTool=="Beam" then beginDeckDrag(nodeId) end
		else
			if nodeId == selectedStart then if selectedTool=="Beam" then beginDeckDrag(nodeId) end; return end
			local response = callServer(selectedTool == "Arch" and "Arch" or "Beam", {
				StartNodeId = selectedStart, EndNodeId = nodeId, MaterialType = selectedMaterial,
				MemberRole = selectedTool == "Support" and "Support" or "Deck",
			})
			if response and response.ok then
				selectedStart = nil
    if selectedTool=="Beam" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then beginDeckDrag(nodeId) end
				selectObject(nil)
				updateButtons()
			end
		end
	end
end)

callServer("Budget", {})

task.spawn(function()
	while gui.Parent do
		if not buildMode then
			local response = invokeServer("SimulationStatus", {}, true)
			if not response then testStatus.Text = "Could not read simulation status." end
			if response and response.Simulation then
				showSimulation(response.Simulation)
			end
		end
		task.wait(0.35)
	end
end)
