# Map redesign authoring

These files are Edit-time commands, outside the Rojo source tree. They create anchored art and world SurfaceGuis. They do not create saved Script/LocalScript/ModuleScript instances, edit game Source, change profiles, save the place or publish it.

Run through Roblox Studio MCP with `datamodel_type = "Edit"`. Concatenate `Common.luau`, a newline, and one stage file into one `execute_luau` request. Read the returned result before continuing. Stop on an error; rerun the same owned stage after correcting its cause.

Order:

1. `Crater.luau`: ground, primitive collision, bowl, cardinal ramps and world timer contract.
2. `Routes.luau`: roads, six isolated spawn pads, boundary and inactive kill-plane marker.
3. `Refinery.luau`, `GearHall.luau`, `Hatchery.luau`, `TradingPost.luau`, `Rebirth.luau`, `Museum.luau`, `DebrisFields.luau`, `Scenery.luau`.
4. `MeteorPreview.luau`: pristine 2x templates in unparented `_G.MapRedesignScaledAssets` and a `PreviewOnly` geometry model in the staged crater.
5. `MiningAccess.luau`: four terraces and continuous ascent.
6. `Lighting.luau`: stores an inactive daylight profile under `Map_Redesign.Atmosphere.LightingProfile`; live Lighting and Terrain remain unchanged.
   For temporary Edit review, run PreviewLighting.luau alone and optionally Common.luau plus PreviewEquipment.luau. Equipment shows18staticmodels/317parts, without player state. RestoreLightingPreview.luau restores15properties and the actual original effects/Clouds; remove or detach all PreviewOnly geometry before save/export/Play or closing Studio.
   Common.luau plus PolishPass1.luau applies furnace/conveyor, current-board, tier-card, fill-light and world-sign repairs. Hatchery/Scenery contain the wider floor and side-by-side eggs/odds; rerun those owned stages before polishing when rebuilding. Conveyor placement measures world-space part corners, including rotation.

7. Common.luau plus SpawnPolish.luau:47noncollidingparts/30oversizedstuds inside the spawn footprint. Does not move or enable spawn pads. Run after Routes; rerun verifies the same1417totalparts. Hatchery.luau uses44px Config odds type with engine-fit assertions.
8. `StaticQA.luau` alone: contracts, budgets, 84 Edit pathfinding routes and forecourt collision probes. Its result explicitly leaves real walking/gameplay pending.
9. `ExportCheckpoint.luau` alone: serializes four unparented clones and verifies engine deserialize round-trips, including root attributes. Read chunked base64 from `_G.MapRedesignStageExportStrings`; validate length, canonical base64, binary header, disk bytes and SHA256 before writing the manifest.

Every stage owns only its named groups under `Workspace.Map_Redesign`, with offset `(0,0,3000)`. It refuses unowned replacements. `Routes` leaves staged spawns disabled. Nothing here swaps or deletes the original Map/Terrain/Lighting/Assets. Activate staged pads only when staged runtime selection is ready, and enable them during the final approved swap.

Meteor scaling uses the pristine `_G.MapRedesignBackup.assets`, falling back to unchanged `ServerStorage.Assets` before the swap. After final assets have been scaled or PlotStations removed, reload the verified original ServerAssets archive into an **unparented** backup first. The scale guard refuses compounded scaling.

Large concave ground CSG closes the crater with its collision hull. Keep the grass union visual-only. Invisible primitive row tiles and a rim annulus provide ground collision; 40 ground-only rays check the opening. Do not re-enable CSG collision.

The geometry preview has no node registration and cannot validate mining gameplay. Remove it before gameplay QA or a final save. It is excluded from checkpoint exports and authored-map counts. The kill plane is a marker until the boundary service is implemented. Gear Hall's cards/stands are mounts until the world client controller is implemented.

The lighting profile contains six effect instances and a `CloudSettings` data Folder. Never put a Clouds instance inside a staged Workspace folder: Studio requires it directly under Terrain and warns even though this is only a profile. At the QA-approved lighting swap, apply only the 15 supported Lighting property attributes, put Sky/Atmosphere/PostEffects directly under Lighting, and materialize the CloudSettings values as Clouds directly under Terrain. Ignore ownership/version/QA metadata when applying properties. Keep the original profile for rollback. The candidate is 14:00 daylight, brightness 2.5, atmosphere density 0.17, modest bloom and disabled depth of field; six native images cover a partial first review; full coverage and after-fix/runtime QA remain pending.

Gear mounts use **relative** `DisplayOffset` CFrames. Resolve a tier card with `card.CFrame * card:GetAttribute("DisplayOffset")`; resolve a current stand with `stand:GetPivot() * stand:GetAttribute("DisplayOffset")`. `DisplayBottomOffset` is local to the stand pivot and lets the controller rest equipment on its top. Never store/read an absolute staging frame for a final display; PivotTo does not transform CFrame attributes.

Runtime integration must also fix MeteorService's old impact-clear teleport height: keeping `root.Position.Y + 4` while moving a player from the Y-44 bowl to outsideR180 can strand them beneath the new ground. Raycast the destination surface and place them above it, retaining zero damage and existing knockback speed/lift. This source change is pending world-code permission.

See `docs/map-redesign/PLAN.md`, `PROGRESS.md`, and the staging manifest for current limits and incomplete gates. Final four contract exports remain unchanged until full pre-swap/post-swap QA passes.

## Runtime walking evidence

`RuntimeWalkingQA.luau` is the Play-time exception to the Edit commands above. Evaluate it **alone** through Studio MCP with `datamodel_type = "Play"` after starting the selected `DevWorldMap = "Map_Redesign"` test session. It installs `_G.MapRedesignWalkingQA` in that command's runtime context and creates no saved Script. Keep subsequent calls in the same context; on a client, the named player must be `Players.LocalPlayer`.

Read `return _G.MapRedesignWalkingQA.targets()` for the original 14 destination names used by StaticQA, plus `MiningStartLanding`, `LowerTerraceAscentJoin`, `MiddleTerraceAscentJoin`, `UpperTerraceAscentJoin`, and `CrownTerraceAscentJoin`. Mining destinations use the actual part's transformed top centre plus a three-stud root offset. They enable ascent and descent checks from the current character location. Start one route using the exact live player's `Name`, then poll at most ten seconds per call:

```luau
return _G.MapRedesignWalkingQA.start("EXACT_PLAYER_NAME", "Refinery")
```

```luau
return _G.MapRedesignWalkingQA.step(5)
```

Repeat `step(5)` until `finished = true`; `status()` is an immediate snapshot. The worker runs asynchronously between calls, including a 20-second path-computation watchdog, a 180-second route deadline, a 10-second waypoint deadline, and four seconds without meaningful progress before a stuck failure. It computes from the actual character position with radius 3, height 6, jumping enabled, and eight-stud waypoint spacing, then issues actual Humanoid `MoveTo` and waypoint jump actions. It never teleports, grants progression, or alters walking speed/jump power. Avoid manual movement during a route.

Capture `return _G.MapRedesignWalkingQA.status(true)` for complete waypoint records after each route. `pathComputed` reports only computation success; `walkedSuccess` requires observed arrivals at every waypoint, final actual root distance within four studs, and no observed health loss. Results include positions, health minimum, waypoint counts and timings, planned/issued/observed jumps, observed travel, blockage indices, and final distance. A computed route can still finish `failed` from timeout, stuck movement, health loss, respawn, or final distance. This measures locomotion only; it does not certify interactions, progression, performance, or all 84 spawn-to-target combinations.

`jumpActionsIssued` counts jump commands, which alone do not prove actual jumps. Report jump execution only when observed character state and motion support it; `actualJumpsObserved = 0` leaves that proof incomplete even when the walking route passes.

Use `return _G.MapRedesignWalkingQA.cancel()` to stop the original character's current route. Reloading the command cancels the previous tool before replacing it; collect its evidence first. Cleanup disconnects observers, destroys the temporary Path, cancels its movement target, and clears a still-pending jump only when the tool changed it. No persistent Humanoid tuning values are changed. Further routes begin from wherever the actual character ended; a respawn requires a new `start`.
