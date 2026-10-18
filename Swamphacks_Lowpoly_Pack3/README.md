# Swamphacks Lowpoly Pack

31 flat-shaded, low-poly models for Roblox, matching the chunky style of the reference shot, plus the first level map.

## What's in `models/`

| Group | Models | Notes |
|---|---|---|
| Vehicles | Car_Red, Car_Blue, Car_Yellow | Body + 4 separate wheels (Wheel_FL/FR/RL/RR), pivots at wheel centres so they can spin. Front faces Roblox's -Z (LookVector). ~1,460 tris. |
| Nature | Tree_Round, Tree_Pine, Bush, Rock_Large, Rock_Small, Grass_Tuft | Trees split into Trunk + Leaves parts. |
| Roads | Road_Straight, Road_Corner, Road_Intersection | 40 × 40 studs, snap on a 40-stud grid. Asphalt and Sidewalk are separate parts. Road is 30 studs wide, sidewalks 5 studs. |
| Boat | Boat_Speedboat | 7 m (26 studs). Origin sits on the waterline. Hull and outboard Motor are separate parts; the Motor pivots at its transom mount for steering. |
| Plane | Plane_Prop | Low-wing prop plane, 11 m (41 studs) wingspan, origin at the ground under the wheels. Propeller is a separate part spinning around its centre. |
| Bridge kit | Bridge_Tower, Bridge_Deck | Tower: art-deco suspension tower in international orange, 189 studs above the water, origin at water level. The road deck passes between its legs. Deck: one 40 × 40-stud segment with lanes, walkways, railings and truss; its road surface lines up with Road_Straight, so deck and road tiles chain together. |
| Water props | Wooden_Dock | 12 m pier, origin at the shore end. |
| Buildings | House_Cottage, House_TwoStory, Shop_Corner, Apartment_Block, Office_Tower, Gas_Station, Lighthouse | Front door faces the model's front (-Z in Roblox, same as the car), origin at ground centre. Sizes: cottage 33 × 30 studs, two-storey house with garage, corner shop with awning and a blank sign band (add a SurfaceGui for the name), 4-floor brick apartments with a rooftop water tower, 9-floor office tower (about 110 studs to the roof, 140 to the antenna tip), gas station with canopy, pumps, store and price sign (64 × 61 studs), red-and-white lighthouse. Lighthouse_Light is a separate part for Neon. |
| Street props | Street_Lamp, Traffic_Cone, Road_Barrier, Picket_Fence, Stop_Sign, Fire_Hydrant, Park_Bench | Street_Lamp_Bulb and Road_Barrier_Lights are separate parts so you can set them to Neon. |

Every model's origin sits at ground level, centred.

## Level 1: the bay crossing

Files are in `level1/`.

- City side (south): main street with an intersection and a cross street closed off by barriers at both ends. 17 buildings line the streets: houses, shops, apartments, two office towers and a gas station on the cross street. The red car starts here facing the bridge.
- Bridge: 10 deck segments (400 studs) between two cliffs, two towers standing in the water, main cables, suspenders and anchor blocks.
- Hill side (north): road climbs off the bridge, turns east along a ridge and ends at a barrier. Forested hills, rocks and beaches.
- Lighthouse on the north headland west of the bridge.
- Water: speedboat in the bay, a dock with a moored boat on the south-west beach, plane over the bay.
- Size: about 1000 × 1040 studs of land; the deck and roads are 50 studs above the water.

How to build it in Studio:

1. Import every `.glb` in `models/`, plus `level1/Level1_Terrain.glb` and `level1/Level1_Bridge_Cables.glb`.
2. Put the imported Models in a Folder named `LowpolyAssets` in ServerStorage. Keep the names as imported.
3. Paste `level1/BuildLevel1.lua` into the command bar and run it. It clones each asset into `workspace.Level1` at its spot, anchors it and adds a SpawnLocation on the sidewalk next to the red car. Running it again replaces the old copy.

The script works out each model's pivot from its bounding box, so it doesn't matter where the importer put the pivot. It warns if a model came in at the wrong scale.

`level1/Level1_Full.glb` is the whole level baked into one file, handy for a quick look or a single import. `level1_layout.json` lists every placement if you want to use it elsewhere.

On the terrain: set `Level1_Terrain_Water` to Transparency 0.2–0.3 (or Glass) and CanCollide off. For the land, try CollisionFidelity PreciseConvexDecomposition; if cars catch on the slopes, keep the mesh for looks and lay Roblox Terrain or invisible parts under the roads for driving.

## Importing into Roblox Studio

1. **File → Import 3D** (or the Import 3D button on the Home tab), pick one or more `.glb` files.
2. Units: the files are in meters. Studio converts at about 3.57 studs per meter, which gives a ~15.6-stud-long car and 40-stud road tiles. If your import comes in at another size, set the importer's scale/units so the road tile measures 40 studs.
3. Each `.glb` becomes a Model with MeshParts. Colours come from one embedded 512 × 512 palette texture (`palette.png`), so every part is textured on import.
4. After import:
   - Set `Street_Lamp_Bulb` and `Road_Barrier_Lights` Material to **Neon** (add a PointLight/SpotLight to the bulb for night scenes).
   - Set CollisionFidelity to **Box** on small props (cones, grass, hydrant) and **Hull** on rocks for cheaper physics. Leave **Default/PreciseConvexDecomposition** on road tiles so cars drive on the curbs correctly.
   - Grass_Tuft: CanCollide off.

## Recolouring

All models share `palette.png` (8 × 8 grid of flat colours). Edit a cell's colour and re-import to restyle everything that uses it, e.g. change the leaf greens for an autumn or swamp look.

## Rebuilding

`build.py` (original props), `buildings.py` and `level1.py` (vehicles, bridge kit, Level 1) generate everything with Blender's Python module (`pip install bpy`), so dimensions, colours and the layout are easy to change: `python3 level1.py` rebuilds every model, the level and the Luau script. `render.py` and `render_level.py` make the preview images.
