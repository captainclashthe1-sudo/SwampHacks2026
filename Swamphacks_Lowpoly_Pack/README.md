# Swamphacks Lowpoly Pack

19 flat-shaded, low-poly models for Roblox, matching the chunky style of the reference shot.

## What's in `models/`

| Group | Models | Notes |
|---|---|---|
| Vehicles | Car_Red, Car_Blue, Car_Yellow | Body + 4 separate wheels (Wheel_FL/FR/RL/RR), pivots at wheel centres so they can spin. Front faces Roblox's -Z (LookVector). ~1,460 tris. |
| Nature | Tree_Round, Tree_Pine, Bush, Rock_Large, Rock_Small, Grass_Tuft | Trees split into Trunk + Leaves parts. |
| Roads | Road_Straight, Road_Corner, Road_Intersection | 40 × 40 studs, snap on a 40-stud grid. Asphalt and Sidewalk are separate parts. Road is 30 studs wide, sidewalks 5 studs. |
| Street props | Street_Lamp, Traffic_Cone, Road_Barrier, Picket_Fence, Stop_Sign, Fire_Hydrant, Park_Bench | Street_Lamp_Bulb and Road_Barrier_Lights are separate parts so you can set them to Neon. |

Every model's origin sits at ground level, centred.

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

`build.py` generates everything procedurally with Blender's Python module (`pip install bpy`), so dimensions, colours and new variants are easy to change: `python3 build.py`. `render.py` makes the preview images.
