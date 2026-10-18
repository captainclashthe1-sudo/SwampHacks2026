--[[
	GameUI  (LocalScript)  —  cartoon-style HUD + menus for the Swamphacks game

	Put this LocalScript in StarterPlayer > StarterPlayerScripts. It builds everything in code,
	so there is nothing else to set up. No image uploads needed: icons are emoji, buttons are
	Frames with gradients and strokes, and text uses the FredokaOne font.

	What it makes
	  HUD      apple counter (top-left), menu button (top-right), Car / Boat / Plane bar (bottom)
	  Menu     Continue · Settings · Respawn · Leave        (open with the menu button or the M key)
	  Settings Sound · Music · Shadows switches + Back
	  Leave    "Leave the game?" confirm

	Hooking it up to your game
	  Apples:   keeps in sync with leaderstats.Apples (IntValue) or a player attribute "Apples".
	  Vehicles: the bar fires ReplicatedStorage.VehicleRequest (RemoteEvent) with "Car" | "Boat" | "Plane"
	            if that RemoteEvent exists. Create it and handle OnServerEvent to spawn vehicles.
	  Sound:    the switches set the Volume of SoundGroups named "SFX" and "Music" in SoundService.
	            Put your sounds in those groups.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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

local topLeft = anchor("TopLeft", 0, 0)
local topRight = anchor("TopRight", 1, 0)
local bottom = anchor("Bottom", 0.5, 1)
local center = anchor("Center", 0.5, 0.5)

local camera = workspace.CurrentCamera
local function rescale()
	local h = camera.ViewportSize.Y
	local s = math.clamp(h / REFERENCE_HEIGHT, 0.55, 1.5)
	for _, sc in ipairs(scalers) do
		sc.Scale = s
	end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

---------------------------------------------------------------------------------------------------
-- Menus
---------------------------------------------------------------------------------------------------
local panels = {}
local current = nil

local function showPanel(panel)
	for _, p in pairs(panels) do
		p.Visible = false
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

-- Main menu
local menu, menuContent = makePanel(center, "Menu", 380, 430, "red")
panels.menu = menu
new("UIListLayout", {
	Padding = UDim.new(0, 16),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = menuContent,
})

-- Settings
local settings, settingsContent = makePanel(center, "Settings", 540, 380, "red")
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
makeButton(menuContent, "Settings", "yellow", BW, function()
	showPanel(settings)
end, { LayoutOrder = 2 })
makeButton(menuContent, "Respawn", "green", BW, function()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = 0
	end
	showPanel(nil)
end, { LayoutOrder = 3 })
makeButton(menuContent, "Leave", "red", BW, function()
	showPanel(confirm)
end, { LayoutOrder = 4 })

local function toggleMenu()
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
-- Apple counter (top-left, below the Roblox top bar)
local applePill = new("Frame", {
	Position = UDim2.fromOffset(16, 72),
	Size = UDim2.fromOffset(150, 56),
	BackgroundColor3 = THEME.cream,
	Parent = topLeft,
}, { round(), stroke(THEME.brown, 3) })
local appleIcon = new("Frame", {
	Position = UDim2.fromOffset(-6, -6),
	Size = UDim2.fromOffset(68, 68),
	BackgroundColor3 = WHITE,
	Parent = applePill,
}, { round(), gradient(THEME.buttons.red.face), stroke(THEME.buttons.red.dark, 3) })
label("🍎", 34, nil, { Parent = appleIcon })
local appleCount = label("0", 30, THEME.brown, {
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(74, 0),
	Size = UDim2.new(1, -80, 1, 0),
	Parent = applePill,
})

local function setApples(n)
	appleCount.Text = tostring(n)
	local s = applePill:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = applePill })
	s.Scale = 1.15
	tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

task.spawn(function()
	local stats = player:WaitForChild("leaderstats", 10)
	local value = stats and stats:WaitForChild("Apples", 5)
	if value then
		setApples(value.Value)
		value.Changed:Connect(setApples)
	end
end)
if player:GetAttribute("Apples") ~= nil then
	setApples(player:GetAttribute("Apples"))
end
player:GetAttributeChangedSignal("Apples"):Connect(function()
	setApples(player:GetAttribute("Apples") or 0)
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

-- Vehicle bar (bottom centre)
local bar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromOffset(0, -18),
	Size = UDim2.fromOffset(470, 84),
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

local function requestVehicle(kind)
	local remote = ReplicatedStorage:FindFirstChild("VehicleRequest")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(kind)
	else
		warn("GameUI: add a RemoteEvent named VehicleRequest to ReplicatedStorage to spawn a " .. kind)
	end
end
for i, v in ipairs({ { "🚗 Car", "blue", "Car" }, { "🚤 Boat", "green", "Boat" }, { "✈️ Plane", "yellow", "Plane" } }) do
	makeButton(bar, v[1], v[2], UDim2.fromOffset(138, 54), function()
		requestVehicle(v[3])
	end, { LayoutOrder = i })
end
