# MeteorShift map art pass

## Expanded mining area — October 2

The latest place is `MeteorShift-expanded-mining-pass.rbxl`. The exact live pre-change save is `MeteorShift-pre-expansion-20261002.rbxl`.

- Bowl and rim enlarged 25%; floor diameter 68 to 85 studs, terrain opening radius 64.
- Meteor core enlarged 50% to 28.35 studs. The same 36 targets are redistributed over the visible dome and lower skirt, with overlapping fractured CSG roots. Breaking targets removes their covering geometry; no permanent crust shell was added.
- Middle ring moved from radius 128 to 150, with plaza and plot paths reconnected.
- Mineable ore rocks increased from 30 to 60, placed between radius 78 and 135 away from paths and landmarks.
- Ground inside radius 160 is bare soil. Grass under paving and plants in the mining field were removed. Native terrain and bowl parts provide collision; the invisible legacy Ground union is inactive because its approximate physics hull spanned the opening.

To recreate this adjustment, open a duplicate of the pre-expansion save with Play stopped. Run `Common.luau` + `ExpandedMiningPass.luau`, then `Common.luau` + `TerrainPass.luau`, then `Common.luau` + `GeologyCommon.luau` + `ClosedMeteorPass.luau`. The expansion and meteor stages intentionally refuse a second application to prevent cumulative scaling. Run the earlier `OrePass` before these final stages; running it afterward would replace the closed crust roots. `LandscapePass` respects the expanded clear radius.

`ExpandedMiningCheck.luau` checks soil, paving, the crater collider and scene dimensions. `MeteorCoverageCheck.luau` assembles ten temporary arrangements and tests 145,800 rays over the visible meteor, plus core access after a 22-node opening. It removes its clones afterward. `ExpandedMiningRuntimeCheck.luau` is a temporary server Script for local Play; stop Play to remove it before saving. It extends the earlier runtime checks with all 60 ore registrations, a physical fall onto the crater floor, 22 accepted crust breaks, core unlock/targeting and an accepted core hit. Never save QA scripts into the place.

## Terrain and geology follow-up — October 1

The latest visual pass is `MeteorShift-terrain-geology-pass.rbxl`; the exact pre-pass backup is `MeteorShift-pre-terrain-pass-20261001.rbxl`. See `gpt-improvement-pass-id.md` for current verification, asset credits and future gameplay ideas.

Rebuild this follow-up on a duplicate of the polished place, in Edit mode: run `Common.luau` + `TerrainPass.luau`, then `Common.luau` + `GeologyCommon.luau` + decoded `assets/map-art/geology/mineral-geometry.json` + `OrePass.luau`, then `Common.luau` + `LandscapePass.luau`. The landscape stage requires the sanitized FernBush prototype in `ServerStorage.ArtImports`; it uses a single MeshPart from Creator Store model 7979002756 by TheLegoGuy137. Inspect any imported model before placing copies. No imported scripts are needed.

`blender_minerals.py` rebuilds the separate original mineral workshop. Its three source hulls become saved CSG solids. `GeologyRuntimeCheck.luau` is a temporary server-side QA Script for an unpublished local Play session; it must not be saved into the place. It validates three meteor assemblies and their recoloring/hiding, debris mining/respawn, assigned plot stations and the deposit/refine/collect/sell loop.

Open `MeteorShift-map-polished.rbxl` for the finished map. The original working places were preserved. `MeteorShift-map-pass.rbxl` is an earlier checkpoint without the final Blender conversion. Rojo synchronizes code only; these authoring scripts deliberately live outside its tree.

## Changes

- Timber framing, framed windows, awnings, equipment displays and trade details on both town buildings; plaza paving, planters and meteor statue detail.
- Foundry bracing, hopper ribs, belt machinery, furnace straps and bars, chimney cap, pressure gauge, pipes and collector trim on the production template.
- Road curbs, numbered entries and fences on all twenty plots, fuller tree silhouettes, crater shelves and mineral seams, cliff talus and debris ore splinters.
- A mining derrick, survey shelter and parked ore wagon as distinct landmarks.
- Extra meteor node mineral geometry and core veins that follow the existing event recoloring conventions.
- Three original Blender rock variants, each 68 source triangles, supply convex hulls for 126 rock roots across the crater, rubble, wagon, mineable debris and meteor templates. Hulls are stored as persistent Roblox CSG solids; no runtime EditableMesh builder or external upload is needed.
- Renamed the original `TownSquare.Shop` to `PickaxeShop` and supplied an invisible prompt point so ShopService and the tutorial can find the physical shop.

## Rebuild or edit

Work on a duplicate of the saved place, with Play stopped. Execute `Common.luau` plus one stage file as a single command, in order: `Town`, `Stations`, `Landscape`, `Meteor`, `Landmarks`, `BlenderMeshes`. For the last stage insert `local geometry = game:GetService("HttpService"):JSONDecode(...)` between Common and the stage, using the contents of `assets/map-art/stone-geometry.json` as a Luau long string. Do not run authoring scripts on a live server.

Groups carry `MapArtOwned`; a stage only replaces its own named groups. Tree resizing uses `ArtOriginalSize` to avoid cumulative scaling. Blender conversion computes supporting planes from the exported vertex cloud and subtracts their outer half-spaces from a block to create a single UnionOperation per variant. It preserves root transforms, bounds, material, attributes, child parts and physical flags. The convex hull can omit small concave chips present in the source mesh. Run the Blender stage again after replacing any earlier art groups.

`assets/map-art/MeteorShift-stone-workshop.blend` contains the editable source scene. The three `.obj` exports and `stone-geometry.json` contain the same geometry. `blender_rocks.py` rebuilds the workshop in a separate Blender scene while keeping the user's existing scene. Existing `assets/*.rbxm` exports are pre-pass backups; the polished place is authoritative for this pass.

## Validation

- Existing Studio suite: 114 passed, zero failures.
- All twenty plot pads/sign hierarchies retained; production template pivot remains identity. Added decorative geometry is anchored, noncolliding, nonqueryable, nontouchable and does not cast shadows. Existing lights remain at 18; none added.
- Visual inspection of town façades, full-map layout, a cloned production line, mining landmarks and the crater at player height.
- Play: server started, a 90-part production line was assigned, and all 30 debris roots registered mining targets. Service smoke: deposited 20 ore, refined and collected 20 bars, sold for 100 cash; four valid hits broke a Blender-derived debris root, all its child flecks hid, and it respawned successfully. Meteor events spawned and ended normally.
- Tests used an unpublished place with in-memory profiles. Temporary preview/smoke instances were removed by stopping Play. The temporary meteor approach FX override was restored to nil before the final save.

This was an art and compatibility pass, not a performance benchmark or published multiplayer test. Meteor approach FX were disabled only during the production/mining smoke check; live FX and long-session hardware stability were not assessed. A direct MCP command-bar Knit lookup used a separate require context and failed; the actual runtime Script smoke used the running services successfully.

Reopening the initial mesh checkpoint exposed a serialization limitation: `CreateDataModelContentAsync` returns ephemeral, DataModel-scoped content that is not retained by a local place save. The final conversion uses saved CSG solids instead. The intermediate `MeteorShift-map-pass.rbxl` predates the entire Blender conversion and remains a valid primitive-only checkpoint.

The final 793,764-byte place was reopened through a byte-for-byte verification copy. All 122 landscape solids, three prototype solids, twenty plots and the physical shop prompt survived; the matching crater view retained the full rock geometry. Each rock hull uses 60 supporting planes. Four additional solids remain in the meteor node templates. Save timestamp: October 1, 2026, 20:14 Europe/Vilnius.

The reopened place also passed a second runtime smoke with the persistent solids: 30 mineable debris roots, assigned stations, four accepted mining hits and a broken rock, 21 ore deposited/refined/collected and 105 cash from selling. Its console contained no runtime errors or missing-shop warning. Play was stopped and temporary overrides cleared afterward.
