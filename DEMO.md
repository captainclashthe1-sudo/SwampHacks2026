# Bridge Builders: Disaster Edition â€” five-level demo

Open Place1 with Rojo connected to this project, then press Play in Studio. Choose PLAY, then an unlocked level. Progress and designs are retained while the player remains in this server session.

| Level | Map and challenge | Starting funds | Maximum speed | First completion reward |
| --- | --- | ---: | ---: | ---: |
| 1 | River Crossing â€” village, 64-stud river | $2,000 | 20 | $300 |
| 2 | Pinewood Ravine â€” raised crossing over the Pack 5 palm island, 72 studs | $1,800 | 28 | $450 |
| 3 | Canal Quarter â€” moving boat destroys low members, 80 studs | $2,500 | 36 | $600 |
| 4 | Lighthouse Reach â€” 96-stud span beneath an overpass | $3,000 | 54 | $850 |
| 5 | Harbor Leap â€” two arch ramps and a boat-lane jump | $2,600 | 78 | $1,500 |

## Playing

- Place joints, then connect them with Deck, Cable, or Arch. The road and deck are 24 studs wide; cables run along both edges.
- Normal scroll zooms. Ctrl + scroll changes joint height. Drag the Build/Test header to move the panel. UI scale and tutorial tips are in Settings.
- Switch to Test, enter the test vehicle (car on levels 1–3, Pack 4 truck on levels 4–5) with its E prompt, choose car speed, then Start Simulation. Reset restores the design without changing funds.
- On Level 5, use **Arch** from the left yellow bridge tile to **LAUNCH**, and from **LANDING** to the right yellow bridge tile. These two ramps are driveable. A speed of **78** was verified to clear the boat and land safely.
- Completing a level unlocks the next. Rewards pay once per level per session. Replays preserve the design and its remaining funds. Each level has a separate construction balance shown in the top HUD.

## Assets and audio

All 31 models from `Swamphacks_Lowpoly_Pack3/models` have Rojo geometry modules in `src/shared/LowpolyMeshData`. The active map renders the supplied triangle geometry on the client. Server parts provide a fallback while meshes load. The yellow test car keeps its previously uploaded Roblox mesh assets. The renderer releases the previous level's mesh when switching levels.

Run `python tools/export_lowpoly.py` followed by `python tools/export_additions.py` from the project root to regenerate the geometry and full extended color palette. The original `.glb` files remain the source assets.

The supplied MP3 files were uploaded to CaptainClashThe1's Roblox account:

| File | Roblox asset ID | Use |
| --- | --- | --- |
| menu_music.mp3 | 73287063387393 | Home, menus, finale |
| level1_music.mp3 | 104310727431376 | Levels 1 and 4 |
| level2_music.mp3 | 133630857767388 | Levels 2, 3, and 5 |

The Music setting controls the music SoundGroup. Asset IDs live in `src/shared/AudioConfig.luau`.

## Studio validation â€” October 17, 2026

A fresh sequential playthrough completed every level through the normal unlock chain:

| Level | Test design | Spent | Test speed | Result |
| --- | --- | ---: | ---: | --- |
| 1 | Short wood deck segments | $640 | 13.5 | Completed, +$300 |
| 2 | Raised wood deck over the island | $746 | 17 | Completed, +$450 |
| 3 | Raised steel deck over the canal | $2,096 | 21 | Completed, +$600 |
| 4 | Steel deck below the overpass | $2,400 | 25 | Completed, +$850 |
| 5 | Steel arch takeoff and landing ramps | $1,380 | 78 | Jumped, landed, completed, +$1,500 |

Additional checks: locked-level selection rejected; fixed obstacle placement rejected; Level 3 boat-lane placement allowed; duplicate Start rejected; forged ramp type rejected; slow harbor jump failed by falling into the river; Reset removed temporary copies and restored ramps without changing cash; replay completed with no second reward; music loaded; all map meshes rendered; no game-script errors appeared during the completed playthrough.

## Source layout and limits

`LevelConfig` defines the campaign and balance. `LevelGenerator` and `CampaignScenery` construct the maps. `CampaignServer` owns selection, unlocks, and per-level controllers. `BuildServer` owns construction and funds. `SimulationServer` owns movement, stress, failures, and completion. `GameUI`, `Client`, `Audio`, and `LowpolyScenery` handle the menus and local presentation.

This is a session-based demo: it does not save progress between server sessions. Tests were performed in Studio; the place has not been published or tested with several simultaneous players. Strength and deflection are gameplay approximations, with Roblox physics providing vehicle movement, flight, and falling debris. The car uses a server-applied takeoff velocity derived from the built ramp's slope and selected speed, then follows Roblox gravity in flight.

A pre-change source backup is in `tools/before-five-levels/src`.

## Latest update: geometry, obstacles, and balance

- Automatic wedge fills close rotated deck joins. Temporary joins follow bent deck endpoints during simulation and fall on collapse; they are included in Reset without charges/refunds.
- Pack 5 Island_Palm replaces Level 2 rocks. Pack 4 Truck_Orange is the vehicle on levels 4–5. Original GLB triangles and sampled embedded texture palette are used.
- MovingMeshes renders server-driven truck/boat/plane pivots. The canal boat has a visible clearance mast and a server collision hull; an overlapping temporary bridge member triggers collapse. Boat motion restarts on simulation start. The Level 4 plane descends, rolls out on the overpass, pauses, and takes off again.
- Cables use 16 noncollidable curved segments per member (8 per side), with exaggerated stretch and thinning; reaching/exceeding 100% demand/capacity releases the structure and cable segments.
- Vehicle creation uses generation guards. Character callbacks reject stale characters; teleports clear velocity. Reset detaches the seat weld before moving the character. Completed vehicles stop at the finish.

### Material rules

| Material | Cost/stud | Density scale | Bending | Compression | Tension | Stiffness scale |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Wood | 10 | 0.60 | 95 | 150 | 120 | 1 |
| Steel | 25 | 7.85 | 340 | 430 | 520 | 4 |
| Concrete | 8 | 2.40 | 85 | 600 | 60 | 2 |

Density ordering follows typical construction materials (wood roughly 500–600 kg/m³, steel roughly 8000, concrete 2400), as documented in [BC Carpenter training](https://bctradesmodules.gov.bc.ca/sites/bctradesmodules.gov.bc.ca/files/module_pdf/Carpentry_July2016_H1_pages41toend_0.pdf). Concrete's 10:1 compression/tension relationship follows [ACI's explanation of unreinforced concrete](https://www.concrete.org/frequentlyaskedquestions.aspx?faqid=666). Values are scaled gameplay inputs, not an engineering analysis. Costs are game currency balancing choices, not real market quotes. Concrete's increased price is intentional game balance; this is not a claim that concrete is universally pricier than steel.

Stress includes gravity, material self-weight, span squared for bending, supported live load, axial loading, bracing, and a length-dependent buckling reduction. Wood is light and cheap but weaker; steel is stiff and strong with much greater self-weight; concrete favors compression/arches and is poor in cable tension and bending. Cables remain an abstract tool that can use any selected material.

### Latest checks

- All five levels completed with the reduced budgets; normal unlock chain completed during the first test pass.
- Final Level 5 truck: 78 completed; 60 fell short. Requested 1000 was clamped to 78.
- Low Level 3 deck was accepted for construction, then failed with a boat-impact message; raised steel crossing passed with active collision checks.
- Concrete cable overload triggered failure at the first stress sample above 100%; 16 visible segments and 4% displayed stretch observed before failure.
- Rotated wood deck joins visually inspected without gaps. Island, corrected truck alignment, and plane landing visually inspected.
- Reset kept cash unchanged ($137 before/after the overload test). Nine rapid level switches left one vehicle and zero simulation copies. Respawn also left one vehicle and zero copies. Completed vehicle drift measured zero.
- No new game-script errors observed. Studio output still includes Roblox CorePackages/UIBlox warnings and an unrelated existing asset-type warning for asset 203785492.

Changed source files for this update: shared/LevelConfig.luau; shared/DeckJoins.luau; shared/LowpolyMeshData/{Palette,Truck_Orange,Island_Palm}.luau; server/{BuildServer,SimulationServer,CampaignServer,CampaignScenery}.luau; client/{init.client,LowpolyScenery.client,MovingMeshes.client}.luau; tools/export_additions.py; DEMO.md.

## Building quality-of-life update
- Stronger simulation-only sag: dead/live factors 1.1/1.6 and increased mid-member bending. Level 1 completed at 1.5 studs peak sag; level 5 still jumped and completed at 78 with 0.9 studs peak sag. Original Build objects stay anchored.
- Next Level detaches seat connections, freezes the character assembly across physics steps, then places it at the destination. Clicking the actual Next Level button after completion was verified to arrive at Level 2 (-62, 5.61, 644), unseated.
- Island height doubled vertically with unchanged horizontal geometry: top approximately Y=6.04 versus clearance top Y=7.
- Hold left mouse with Deck selected and sweep across existing joints/anchors. The stroke retains its starting material and serializes server requests; fast sweeps detect intermediate joints. Eight sections were created in the mouse test for $640.
- Clicking outside the build zone clears the selected endpoint. Verified glow hidden and selection-cleared status.
- Successful Beam/Arch placement shows red (-$amount) using the server-paid cost. Free joints and rejected purchases do not show charges. Verified (-$80) for dragged decks; arches return their aggregate PaidCost.
- White START/FINISH road lettering added on every map, near the vehicle start/finish and oriented toward approaching vehicles. Replaces old floating black signs.

## Cable mount and material ordering update
- Level 1 starts with $2,000.
- Current prices per stud: Concrete $8 < Wood $10 < Steel $25. Tensile capacities remain Concrete 60 < Wood 120 < Steel 520 (gameplay units). This supersedes the earlier expensive-concrete balance.
- Cables require existing decks at BOTH selected endpoints, including tower endpoints. A tower point must have a deck attached before it can serve as a cable endpoint.
- Cable mounts use the actual deck edge orientation, rather than a fixed world-Z offset. Simulation mounts follow the deflecting deck halves. Both cable strands remain noncollidable.
- Removing the last deck at an endpoint automatically removes and fully refunds dependent cables.
- Studio test: rejected unsupported cable without charging; accepted steel cable for $807 after decks existed; build mount error below 0.000002 studs; simulation endpoints overlap mounts by 0.01 studs to prevent visible seams. Angled-deck crossing completed. Removing both decks at an endpoint refunded $180 for the decks and $807 for the cable.
- Source changes: shared/CableMounts.luau, shared/LevelConfig.luau, server/BuildServer.luau, server/SimulationServer.luau.

## Tower and interior-joint cable correction
Fixed level anchors (including towers) are valid permanent cable mounts and remain protected from editing. A player joint may also attach a cable when it lies on an existing deck span, even when it is not an endpoint of that deck. Cable visuals project to the deck edges on either side of the joint; tower ends meet the tower crossbar/pylons. Interior mounts follow the appropriate bent deck half and contribute to its live-load/support checks. This supersedes the earlier requirement to add a player deck to tower points.
Studio verification: a new joint at (-8,4,0), halfway along a deck from (-16,4,0) to (0,4,0), accepted a cable from LeftTower_Top for $313. Deck ends at Z +/-11.88 and tower mounts at Z +/-12.88 touched the correct surfaces. Tower deletion was rejected. The crossing completed successfully with the cable in place.
