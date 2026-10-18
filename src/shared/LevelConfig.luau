-- System 1 layout. Change Origin to move the entire level. For a new level,
-- adjust Road, BuildZone, and Marker values; Resolve derives all world points.
local Config = {
	Name = "River Crossing 01",
	Origin = Vector3.new(0, 0, 0),
	Road = {
		Length = 36,
		Width = 24,
		Thickness = 2,
		TopY = 4,
		Gap = 64,
	},
	BuildZone = {
		BottomY = -8,
		TopY = 28,
		HalfWidth = 12,
	},
	Tower = {
		HalfWidth = 13,
		MidHeight = 14,
		TopHeight = 24,
		CapHeight = 26,
	},
	River = {
		Thickness = 0.4,
		SurfaceY = -12,
	},
	Budget = {
		Starting = 10000,
		PricePerStud = {
			Wood = 10,
			Steel = 25,
			Concrete = 8,
		},
	},
	Simulation = {
		-- Game balance values, not real-world engineering units.
		LoadWeight = 100,
		ReferenceSpan = 16,
		-- Gameplay units: bending, axial load, buckling, and self-weight are approximations.
		Materials = {
			Wood = {Density = 0.6, Bend = 95, Compression = 150, Tension = 120, Stiffness = 1},
			-- Steel stays stiff and strong once braced, but unsupported deck spans take extra bending load.
			Steel = {Density = 7.85, Bend = 340, Compression = 430, Tension = 520, Stiffness = 4, SupportReliance = 0.35},
			Concrete = {Density = 3.3, Bend = 70, Compression = 600, Tension = 42, Stiffness = 1.6},
		},
		StressUpdateInterval = 0.1,
		-- Visible elastic deflection of the temporary test deck, in studs.
		GravityReference = 196.2,
		DeadSagScale = 1.4,
		LiveSagScale = 2.2,
		MaxJointSag = 5.5,
		Speed = 10,
		BridgeSpeed = 13.5,
		MinCarSpeed = 8,
		MaxCarSpeed = 20,
		CarSpeedStep = 0.5,
		TimeLimit = 55,
		StuckTime = 5,
	},
	Progression = {
		CompletionTokens = 500,
	},
	Markers = {
		OffsetFromRoadCenter = 10,
		-- The entire test car is clear of the right bridge anchor at this point.
		FinishOffsetFromRoadCenter = 8,
		SpawnOffsetFromRoadCenter = 8,
		SpawnSize = Vector3.new(6, 1, 6),
	},
}

local function resolve(Config)
	local road = Config.Road
	local origin = Config.Origin
	local halfGap = road.Gap / 2
	local centerDistance = halfGap + road.Length / 2
	local leftX = -centerDistance
	local rightX = centerDistance
	local platformCenterY = road.TopY - road.Thickness / 2
	local localZoneMin = Vector3.new(-halfGap, Config.BuildZone.BottomY, -Config.BuildZone.HalfWidth)
	local localZoneMax = Vector3.new(halfGap, Config.BuildZone.TopY, Config.BuildZone.HalfWidth)
	return {
		Name = Config.Name,
		Origin = origin,
		PlatformSize = Vector3.new(road.Length, road.Thickness, road.Width),
		LeftPlatform = origin + Vector3.new(leftX, platformCenterY, 0),
		RightPlatform = origin + Vector3.new(rightX, platformCenterY, 0),
		RoadTopY = origin.Y + road.TopY,
		RiverSize = Vector3.new(road.Gap, Config.River.Thickness, road.Width),
		RiverCenter = origin + Vector3.new(0, Config.River.SurfaceY - Config.River.Thickness / 2, 0),
		LeftAnchor = origin + Vector3.new(-halfGap, road.TopY, 0),
		RightAnchor = origin + Vector3.new(halfGap, road.TopY, 0),
		LeftTowerMid = origin + Vector3.new(-halfGap, Config.Tower.MidHeight, 0),
		LeftTowerTop = origin + Vector3.new(-halfGap, Config.Tower.TopHeight, 0),
		RightTowerMid = origin + Vector3.new(halfGap, Config.Tower.MidHeight, 0),
		RightTowerTop = origin + Vector3.new(halfGap, Config.Tower.TopHeight, 0),
		ZoneMin = origin + localZoneMin,
		ZoneMax = origin + localZoneMax,
		VehicleStart = origin + Vector3.new(leftX - Config.Markers.OffsetFromRoadCenter, road.TopY, 0),
		VehicleFinish = origin + Vector3.new(rightX + Config.Markers.FinishOffsetFromRoadCenter, road.TopY, 0),
		SpawnSurface = origin + Vector3.new(leftX - Config.Markers.SpawnOffsetFromRoadCenter, road.TopY, 0),
		SpawnSize = Config.Markers.SpawnSize,
	}
end

local Campaign = {
 {Title="River Crossing", Theme="village", Gap=64, Funds=1100, Speed=13.5, MaxSpeed=20, Weight=80, Reward=300,
  Hint="Short wooden deck sections make a good first crossing.", Color=Color3.fromRGB(100,176,96)},
 {Title="Pinewood Ravine", Theme="forest", Gap=72, Funds=1200, Speed=17, MaxSpeed=28, Weight=95, Reward=450,
  Hint="Build above the island. Brace raised spans to carry the load.", Color=Color3.fromRGB(49,114,98),
  Obstacle={Min=Vector3.new(-10,-10,-12), Max=Vector3.new(10,7,12), Label="ISLAND CLEARANCE"}},
 {Title="Canal Quarter", Theme="city", Gap=80, Funds=1300, Speed=21, MaxSpeed=36, Weight=115, Reward=600,
  Hint="The boat crosses during testing. Low bridge members can be struck!", Color=Color3.fromRGB(105,137,166),
  Obstacle={Min=Vector3.new(-14,-10,-12), Max=Vector3.new(14,9,12), Label="MOVING BOAT / BUILD AT YOUR RISK", AllowBuild=true}},
 {Title="Lighthouse Reach", Theme="coast", Gap=96, Funds=1500, Speed=21, MaxSpeed=46, Weight=190, Reward=850,
  Hint="The loaded truck is heavy. West-to-east wind pushes the bridge during testing; brace the long span with steel or arches.", Color=Color3.fromRGB(214,164,93), WindStrength=28,
  Obstacle={Min=Vector3.new(-12,13,-12), Max=Vector3.new(12,30,12), Label="LOW OVERPASS"}},
 {Title="Harbor", Theme="harbor", Gap=80, Funds=900, Speed=78, MaxSpeed=78, Weight=165, Reward=1500,
  Hint="Sometimes a bridge just require a leap of faith", Color=Color3.fromRGB(207,105,87), Jump=true},
}
local function clone(value)
 if type(value)~="table" then return value end
 local copy={} for key,item in pairs(value) do copy[key]=clone(item) end return copy
end
function Config.ForLevel(id)
 local entry=assert(Campaign[id], "Invalid level")
 local result=clone(Config)
 result.Id=id; result.Name="Level"..id; result.Title=entry.Title; result.Theme=entry.Theme
 result.VehicleMesh=id>=4 and "Truck_Orange" or "Car_Yellow"
 result.Hint=entry.Hint; result.ThemeColor=entry.Color; result.Obstacle=entry.Obstacle
 result.Origin=Vector3.new(0,0,(id-1)*650)
 result.Road.Gap=entry.Gap; result.Budget.Starting=entry.Funds
 result.Simulation.BridgeSpeed=entry.Speed; result.Simulation.Speed=entry.Speed
 result.Simulation.MaxCarSpeed=entry.MaxSpeed; result.Simulation.MinCarSpeed=entry.Jump and 40 or 8
 result.Simulation.CarSpeedStep=entry.Jump and 2 or 0.5
 result.Simulation.LoadWeight=entry.Weight
	result.Simulation.WindStrength=entry.WindStrength or 0
 result.Simulation.DeadSagScale=1.1; result.Simulation.LiveSagScale=1.6
 result.Progression.CompletionTokens=entry.Reward
 result.Jump=entry.Jump and {MinX=-13.5, MaxX=13.5} or nil
 result.Resolve=function() return resolve(result) end
 return result
end
Config.Campaign=Campaign
Config.Resolve=function() return Config.ForLevel(1).Resolve() end
return Config
