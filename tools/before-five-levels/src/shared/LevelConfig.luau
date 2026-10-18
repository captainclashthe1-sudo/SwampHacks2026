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
			Concrete = 7,
		},
	},
	Simulation = {
		-- Game balance values, not real-world engineering units.
		LoadWeight = 100,
		ReferenceSpan = 16,
		-- Gameplay units: bending, axial load, buckling, and self-weight are approximations.
		Materials = {
			Wood = {Density = 0.7, Bend = 145, Compression = 210, Tension = 175, Stiffness = 1},
			-- Steel stays stiff and strong once braced, but unsupported deck spans take extra bending load.
			Steel = {Density = 2.8, Bend = 360, Compression = 430, Tension = 520, Stiffness = 2.8, SupportReliance = 1},
			Concrete = {Density = 3.2, Bend = 115, Compression = 500, Tension = 75, Stiffness = 1.4},
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
		CompletionCash = 500,
	},
	Markers = {
		OffsetFromRoadCenter = 10,
		-- The entire test car is clear of the right bridge anchor at this point.
		FinishOffsetFromRoadCenter = 8,
		SpawnOffsetFromRoadCenter = 8,
		SpawnSize = Vector3.new(6, 1, 6),
	},
}

function Config.Resolve()
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

return Config
