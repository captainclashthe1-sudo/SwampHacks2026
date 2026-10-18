-- Cartoon HUD and menus adapted from the user's GameUI.client.lua for Bridge Builders.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local bridgeActions = player:WaitForChild("PlayerScripts"):WaitForChild("BridgeUIActions")

---------------------------------------------------------------------------------------------------
-- Theme
---------------------------------------------------------------------------------------------------
local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)

local function hex(h)
	return Color3.fromHex(h)
end

local THEME = {
	cream = hex("F6ECD6"),
	stitch = hex("D9C3A0"),
	tan = hex("E6CFAD"),
	brown = hex("6E4325"),
	brownText = hex("8A5A35"),
	switchOff = hex("BFA98A"),
	overlay = hex("2A1745"),
	buttons = {
		red = { face = hex("F0524A"), dark = hex("A8302B") },
		blue = { face = hex("2FA8F0"), dark = hex("1B67AD") },
		yellow = { face = hex("F7C628"), dark = hex("B98A0E") },
		green = { face = hex("8CD63A"), dark = hex("4C8F1B") },
	},
}

local REFERENCE_HEIGHT = 720 -- the UI is designed at this screen height and scaled from it

---------------------------------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------------------------------
local function new(class, props, children)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			obj[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	if props and props.Parent then
		obj.Parent = props.Parent
	end
	return obj
end

local function corner(px)
	return new("UICorner", { CornerRadius = UDim.new(0, px) })
end

local function round()
	return new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

local function stroke(color, thickness, mode)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function gradient(color)
	return new("UIGradient", {
		Color = ColorSequence.new(color:Lerp(WHITE, 0.25), color),
		Rotation = 90,
	})
end

-- White cartoon text with a dark outline
local function label(text, size, outline, props)
	local p = {
		BackgroundTransparency = 1,
		Text = text,
		Font = FONT,
		TextSize = size,
		TextColor3 = WHITE,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local l = new("TextLabel", p)
	if outline then
		stroke(outline, math.max(1.5, size / 11), Enum.ApplyStrokeMode.Contextual).Parent = l
	end
	return l
end

local function tween(obj, time, goal, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

---------------------------------------------------------------------------------------------------
-- Components
---------------------------------------------------------------------------------------------------

-- Chunky glossy button. Returns the holder frame and the clickable face.
local function makeButton(parent, text, colorName, size, onClick, props)
	local col = THEME.buttons[colorName]
	local holder = new("Frame", {
		Size = size,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	for k, v in pairs(props or {}) do
		holder[k] = v
	end
	local scale = new("UIScale", { Parent = holder })
	new("Frame", { -- the darker "thickness" under the button
		Name = "Base",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 5),
		BackgroundColor3 = col.dark,
		BorderSizePixel = 0,
		Parent = holder,
	}, { corner(14) })
	local face = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		AutoButtonColor = false,
		Text = "",
		Parent = holder,
	}, { corner(14), gradient(col.face), stroke(col.dark, 3) })
	new("Frame", { -- gloss highlight, top-left
		Size = UDim2.fromOffset(18, 7),
		Position = UDim2.fromOffset(10, 7),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = face,
	}, { round() })
	new("Frame", {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.fromOffset(32, 7),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = face,
	}, { round() })
	label(text, math.floor(size.Y.Offset * 0.5), col.dark, { Parent = face })

	face.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.04 })
	end)
	face.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
		face.Position = UDim2.fromOffset(0, 0)
	end)
	face.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, 3)
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.fromOffset(0, 0)
	end)
	face.Activated:Connect(function()
		if onClick then
			onClick()
		end
	end)
	return holder, face
end

-- Cream card with a stitched inner line and a title ribbon. Returns panel, content area.
local function makePanel(parent, title, w, h, ribbonColor)
	local col = THEME.buttons[ribbonColor or "red"]
	local panel = new("Frame", {
		Name = title .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = THEME.cream,
		Visible = false,
		Parent = parent,
	}, { corner(28), stroke(THEME.brown, 4) })
	new("UIScale", { Name = "Pop", Parent = panel })
	new("Frame", { -- stitched inner border
		Position = UDim2.fromOffset(11, 11),
		Size = UDim2.new(1, -22, 1, -22),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { corner(20), stroke(THEME.stitch, 2) })

	local ribbon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(math.max(190, math.floor(w * 0.56)), 54),
		BackgroundColor3 = WHITE,
		Parent = panel,
	}, { corner(16), gradient(col.face), stroke(col.dark, 3) })
	new("Frame", {
		Size = UDim2.fromOffset(20, 7),
		Position = UDim2.fromOffset(12, 8),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = ribbon,
	}, { round() })
	label(title, 28, col.dark, { Parent = ribbon })

	local content = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(30, 50),
		Size = UDim2.new(1, -60, 1, -80),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	return panel, content
end

-- Settings tile: title, icon, and an OFF/ON switch.
local function makeSwitchTile(parent, title, icon, initial, onChange, order)
	local tile = new("Frame", {
		Size = UDim2.fromOffset(120, 150),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	label(title, 22, THEME.brown, { Size = UDim2.new(1, 0, 0, 28), Parent = tile })
	label(icon, 40, nil, { Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 32), Parent = tile })

	local track = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(78, 22),
		BackgroundColor3 = THEME.switchOff,
		AutoButtonColor = false,
		Text = "",
		Parent = tile,
	}, { round(), stroke(THEME.brown, 2) })
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.2, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = THEME.cream,
		Parent = track,
	}, { round(), stroke(THEME.brown, 2) })
	label("OFF", 12, nil, {
		TextColor3 = THEME.brownText,
		Size = UDim2.fromOffset(30, 14),
		Position = UDim2.new(0.5, -40, 0, 124),
		Parent = tile,
	})
	label("ON", 12, nil, {
		TextColor3 = THEME.brownText,
		Size = UDim2.fromOffset(30, 14),
		Position = UDim2.new(0.5, 10, 0, 124),
		Parent = tile,
	})

	local on = initial
	local function render(animate)
		local goal = { Position = UDim2.fromScale(on and 0.8 or 0.2, 0.5) }
		local color = on and THEME.buttons.green.face or THEME.switchOff
		if animate then
			tween(knob, 0.15, goal)
			tween(track, 0.15, { BackgroundColor3 = color })
		else
			knob.Position = goal.Position
			track.BackgroundColor3 = color
		end
	end
	track.Activated:Connect(function()
		on = not on
		render(true)
		onChange(on)
	end)
	render(false)
	onChange(on)
	return tile
end

---------------------------------------------------------------------------------------------------
-- Screen setup: one ScreenGui, zero-size anchors that carry the global scale
---------------------------------------------------------------------------------------------------
local old = playerGui:FindFirstChild("GameUI")
if old then
	old:Destroy()
end

local gui = new("ScreenGui", {
	Name = "GameUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 10,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

local scalers = {}
local function anchor(name, sx, sy)
	local a = new("Frame", {
		Name = name,
		Position = UDim2.fromScale(sx, sy),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	table.insert(scalers, new("UIScale", { Parent = a }))
	return a
end

local overlay = new("TextButton", { -- dims the game and blocks clicks while a menu is open
	Name = "Overlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.overlay,
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
	Parent = gui,
})

local topCenter = anchor("TopCenter", 0.5, 0)
local topRight = anchor("TopRight", 1, 0)
local bottom = anchor("Bottom", 0.5, 1)
local center = anchor("Center", 0.5, 0.5)

local camera = workspace.CurrentCamera
local function rescale()
	local h = camera.ViewportSize.Y
	local w = camera.ViewportSize.X
	if w < 200 or h < 200 then return end
	local preference = math.clamp(tonumber(player:GetAttribute("BridgeUIScale")) or 1, 0.8, 1.3)
	local s = math.clamp(math.min(h / REFERENCE_HEIGHT, w / 720) * preference, 0.5,
		math.min(1.5, w / 690, h / 550))
	for _, sc in ipairs(scalers) do
		sc.Scale = s
	end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
player:GetAttributeChangedSignal("BridgeUIScale"):Connect(rescale)
rescale()

---------------------------------------------------------------------------------------------------
-- Menus
---------------------------------------------------------------------------------------------------
local panels = {}
local current = nil
local menu
local bar

local function showPanel(panel)
	for _, p in pairs(panels) do
		p.Visible = false
	end
	if bar then
		bar.Visible = panel == nil and player:GetAttribute("LevelSelected") == true
	end
	if not panel then
		current = nil
		tween(overlay, 0.2, { BackgroundTransparency = 1 }).Completed:Connect(function()
			if not current then
				overlay.Visible = false
			end
		end)
		return
	end
	current = panel
	overlay.Visible = true
	tween(overlay, 0.2, { BackgroundTransparency = 0.45 })
	panel.Visible = true
	local pop = panel:FindFirstChild("Pop")
	pop.Scale = 0.7
	tween(pop, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- The opening screen and the single playable level.
local home, homeContent = makePanel(center, "BRIDGE BUILDERS", 510, 390, "red")
panels.home = home
label("DISASTER EDITION", 27, THEME.brown, {
	Position = UDim2.fromOffset(0, 16),
	Size = UDim2.new(1, 0, 0, 44),
	Parent = homeContent,
})
label("Build a crossing. Test its strength. Drive to the finish.", 19, nil, {
	TextColor3 = THEME.brownText,
	TextWrapped = true,
	Position = UDim2.fromOffset(0, 74),
	Size = UDim2.new(1, 0, 0, 60),
	Parent = homeContent,
})
local hero = new("Frame", {
	Position = UDim2.fromOffset(34, 142),
	Size = UDim2.new(1, -68, 0, 60),
	BackgroundColor3 = THEME.buttons.blue.face,
	ClipsDescendants = true,
	Parent = homeContent,
}, { corner(15), stroke(THEME.buttons.blue.dark, 2) })
new("Frame", {Position = UDim2.fromScale(0, 0.34), Size = UDim2.new(0.39, 0, 0, 20), BackgroundColor3 = THEME.buttons.yellow.face, Parent = hero}, {corner(4)})
new("Frame", {Position = UDim2.fromScale(0.61, 0.34), Size = UDim2.new(0.39, 0, 0, 20), BackgroundColor3 = THEME.buttons.yellow.face, Parent = hero}, {corner(4)})
new("Frame", {Position = UDim2.fromScale(0.36, 0.22), Size = UDim2.new(0.28, 0, 0, 5), BackgroundColor3 = THEME.brown, Parent = hero})

local levels, levelsContent = makePanel(center, "SELECT LEVEL", 540, 470, "blue")
panels.levels = levels
local levelCard = new("Frame", {
	Position = UDim2.fromOffset(10, 14),
	Size = UDim2.new(1, -20, 0, 298),
	BackgroundColor3 = THEME.tan,
	Parent = levelsContent,
}, {corner(20), stroke(THEME.brown, 2)})
local preview = new("Frame", {
	Position = UDim2.fromOffset(16, 16),
	Size = UDim2.new(1, -32, 0, 146),
	BackgroundColor3 = hex("79C76B"),
	ClipsDescendants = true,
	Parent = levelCard,
}, {corner(14), stroke(THEME.brown, 2)})
new("Frame", {Position = UDim2.fromScale(0.42, 0), Size = UDim2.fromScale(0.16, 1), BackgroundColor3 = hex("168DB5"), Parent = preview})
new("Frame", {Position = UDim2.fromScale(0, 0.39), Size = UDim2.fromScale(0.42, 0.24), BackgroundColor3 = hex("565763"), Parent = preview})
new("Frame", {Position = UDim2.fromScale(0.58, 0.39), Size = UDim2.fromScale(0.42, 0.24), BackgroundColor3 = hex("565763"), Parent = preview})
new("Frame", {Position = UDim2.fromScale(0.4, 0.28), Size = UDim2.fromScale(0.025, 0.48), BackgroundColor3 = THEME.buttons.red.face, Parent = preview})
new("Frame", {Position = UDim2.fromScale(0.575, 0.28), Size = UDim2.fromScale(0.025, 0.48), BackgroundColor3 = THEME.buttons.red.face, Parent = preview})
label("LEVEL 1  •  RIVER CROSSING", 24, THEME.brown, {
	Position = UDim2.fromOffset(14, 172), Size = UDim2.new(1, -28, 0, 36), Parent = levelCard,
})
label("Build the bridge and drive safely across.", 17, nil, {
	TextColor3 = THEME.brownText, TextWrapped = true,
	Position = UDim2.fromOffset(30, 207), Size = UDim2.new(1, -60, 0, 34), Parent = levelCard,
})
makeButton(levelCard, "PLAY LEVEL 1", "green", UDim2.fromOffset(230, 50), function()
	bridgeActions:Fire("EnterLevel")
	showPanel(nil)
end, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 242)})
makeButton(levelsContent, "Back", "yellow", UDim2.fromOffset(180, 48), function()
	showPanel(player:GetAttribute("LevelSelected") and menu or home)
end, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 322)})
makeButton(homeContent, "PLAY", "green", UDim2.fromOffset(250, 64), function()
	showPanel(levels)
end, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 222)})

-- In-level pause menu.
local menuContent
menu, menuContent = makePanel(center, "Menu", 380, 500, "red")
panels.menu = menu
new("UIListLayout", {
	Padding = UDim.new(0, 16),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = menuContent,
})

-- Settings
local settings, settingsContent = makePanel(center, "Settings", 640, 440, "red")
panels.settings = settings
local tray = new("Frame", {
	Size = UDim2.new(1, 0, 0, 190),
	Position = UDim2.fromOffset(0, 10),
	BackgroundColor3 = THEME.tan,
	Parent = settingsContent,
}, { corner(18) })
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 18),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = tray,
})

local function soundGroup(name)
	local g = SoundService:FindFirstChild(name)
	if not g then
		g = new("SoundGroup", { Name = name, Volume = 0.5, Parent = SoundService })
	end
	return g
end
local sfx, music = soundGroup("SFX"), soundGroup("Music")
local sfxVolume, musicVolume = sfx.Volume > 0 and sfx.Volume or 0.5, music.Volume > 0 and music.Volume or 0.5

makeSwitchTile(tray, "Sound", "🔊", true, function(on)
	sfx.Volume = on and sfxVolume or 0
end, 1)
makeSwitchTile(tray, "Music", "🎵", true, function(on)
	music.Volume = on and musicVolume or 0
end, 2)
makeSwitchTile(tray, "Shadows", "🌤️", Lighting.GlobalShadows, function(on)
	Lighting.GlobalShadows = on
end, 3)
makeSwitchTile(tray, "Tips", "💡", player:GetAttribute("TutorialTipsEnabled") ~= false, function(on)
	player:SetAttribute("TutorialTipsEnabled", on)
end, 4)

label("UI SIZE", 21, nil, {
	TextColor3 = THEME.brown,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(30, 218),
	Size = UDim2.fromOffset(180, 48),
	Parent = settingsContent,
})
local sizeReadout = label("100%", 22, THEME.brown, {
	Position = UDim2.fromOffset(314, 218),
	Size = UDim2.fromOffset(90, 48),
	Parent = settingsContent,
})
local function adjustSize(delta)
	local nextSize = math.clamp(math.round(((tonumber(player:GetAttribute("BridgeUIScale")) or 1) + delta) * 10) / 10, 0.8, 1.3)
	player:SetAttribute("BridgeUIScale", nextSize)
	sizeReadout.Text = tostring(math.round(nextSize * 100)) .. "%"
end
makeButton(settingsContent, "−", "blue", UDim2.fromOffset(50, 42), function()
	adjustSize(-0.1)
end, {Position = UDim2.fromOffset(248, 221)})
makeButton(settingsContent, "+", "blue", UDim2.fromOffset(50, 42), function()
	adjustSize(0.1)
end, {Position = UDim2.fromOffset(420, 221)})
sizeReadout.Text = tostring(math.round((tonumber(player:GetAttribute("BridgeUIScale")) or 1) * 100)) .. "%"

makeButton(settingsContent, "Back", "green", UDim2.fromOffset(240, 58), function()
	showPanel(menu)
end, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6) })

-- Leave confirm
local confirm, confirmContent = makePanel(center, "Leave?", 400, 260, "red")
panels.confirm = confirm
label("Leave the game?", 26, nil, {
	TextColor3 = THEME.brown,
	Size = UDim2.new(1, 0, 0, 60),
	Position = UDim2.fromOffset(0, 16),
	Parent = confirmContent,
})
makeButton(confirmContent, "Leave", "red", UDim2.fromOffset(140, 58), function()
	player:Kick("Thanks for playing!")
end, { Position = UDim2.new(0, 10, 1, -70) })
makeButton(confirmContent, "Stay", "blue", UDim2.fromOffset(140, 58), function()
	showPanel(menu)
end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 1, -70) })

-- Menu buttons
local BW = UDim2.fromOffset(300, 60)
makeButton(menuContent, "Continue", "blue", BW, function()
	showPanel(nil)
end, { LayoutOrder = 1 })
makeButton(menuContent, "Levels", "green", BW, function()
	showPanel(levels)
end, { LayoutOrder = 2 })
makeButton(menuContent, "Settings", "yellow", BW, function()
	showPanel(settings)
end, { LayoutOrder = 3 })
makeButton(menuContent, "Respawn", "green", BW, function()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = 0
	end
	showPanel(nil)
end, { LayoutOrder = 4 })
makeButton(menuContent, "Leave", "red", BW, function()
	showPanel(confirm)
end, { LayoutOrder = 5 })

local function toggleMenu()
	if not player:GetAttribute("LevelSelected") then return end
	if current then
		showPanel(nil)
	else
		showPanel(menu)
	end
end
overlay.Activated:Connect(function() end) -- swallow clicks behind the panels

ContextActionService:BindAction("GameUI_ToggleMenu", function(_, state)
	if state == Enum.UserInputState.Begin then
		toggleMenu()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)

---------------------------------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------------------------------
-- Session cash earned by finishing the bridge.
local cashPill = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(0, 72),
	Size = UDim2.fromOffset(220, 56),
	BackgroundColor3 = THEME.cream,
	Parent = topCenter,
}, { round(), stroke(THEME.brown, 3) })
local cashIcon = new("Frame", {
	Position = UDim2.fromOffset(-6, -6),
	Size = UDim2.fromOffset(68, 68),
	BackgroundColor3 = WHITE,
	Parent = cashPill,
}, { round(), gradient(THEME.buttons.red.face), stroke(THEME.buttons.red.dark, 3) })
label("💰", 34, nil, { Parent = cashIcon })
local cashCount = label("$0", 27, THEME.brown, {
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(74, 0),
	Size = UDim2.new(1, -80, 1, 0),
	Parent = cashPill,
})

local function setCash(n)
	local digits = tostring(math.floor(tonumber(n) or 0))
	cashCount.Text = "$" .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	local s = cashPill:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = cashPill })
	s.Scale = 1.15
	tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

task.spawn(function()
	local stats = player:WaitForChild("leaderstats", 10)
	local value = stats and stats:WaitForChild("Cash", 5)
	if value then
		setCash(value.Value)
		value.Changed:Connect(setCash)
	end
end)
if player:GetAttribute("Cash") ~= nil then
	setCash(player:GetAttribute("Cash"))
end
player:GetAttributeChangedSignal("Cash"):Connect(function()
	setCash(player:GetAttribute("Cash") or 0)
end)

-- Menu button (top-right)
local menuBtn = makeButton(topRight, "", "yellow", UDim2.fromOffset(60, 60), toggleMenu, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(-16, 72),
})
for i = 0, 2 do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, (i - 1) * 11),
		Size = UDim2.fromOffset(28, 6),
		BackgroundColor3 = WHITE,
		Parent = menuBtn:FindFirstChild("Face"),
	}, { round(), stroke(THEME.buttons.yellow.dark, 2) })
end

-- Bridge controls (bottom centre). The construction script owns the mode and server requests.
bar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromOffset(0, -18),
	Size = UDim2.fromOffset(600, 84),
	BackgroundColor3 = THEME.cream,
	Parent = bottom,
}, { corner(26), stroke(THEME.brown, 4) })
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = bar,
})

local controls = {}
for i, v in ipairs({
	{ "🔨 Build", "blue", "Build" },
	{ "🧪 Test", "green", "Test" },
	{ "▶ Start", "yellow", "Start" },
	{ "↻ Reset", "red", "Reset" },
}) do
	controls[v[3]] = makeButton(bar, v[1], v[2], UDim2.fromOffset(132, 54), function()
		bridgeActions:Fire(v[3])
	end, { LayoutOrder = i })
end
local function updateControls()
	local selected = player:GetAttribute("LevelSelected") == true
	bar.Visible = selected and current == nil
	menuBtn.Visible = selected
	local testing = player:GetAttribute("BridgeMode") == "Test"
	controls.Build.Visible = testing
	controls.Test.Visible = not testing
	controls.Start.Visible = testing
	controls.Reset.Visible = testing
	bar.Size = UDim2.fromOffset(testing and 470 or 172, 84)
end
player:GetAttributeChangedSignal("BridgeMode"):Connect(updateControls)
player:GetAttributeChangedSignal("LevelSelected"):Connect(updateControls)
updateControls()
if not player:GetAttribute("LevelSelected") then
	showPanel(home)
end
