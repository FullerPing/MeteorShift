# Map and world

The world is not built by code. The crater town, the meteor and node templates, the pickaxe, the lighting and the terrain are real instances saved in the Roblox place; Rojo syncs only scripts, and the one asset folder it syncs is `assets/native-ui` into StarterGui (`default.project.json:36-40`). Only the meteor (and a handful of client-side cosmetics) is cloned at runtime. This guide is the map-side tour: the authoring contract, what `Shared.WorldGeometry` models, what code clones, and which tools rebuild the place-side art. The live map is map v2 (cartoon-sim style since 8 October 2026, 540 × 540 play area — outer scenery "Crater Isle" added 9 October; some folder names still say "Main Street", there is no boulevard: [tools/map-v2/README.md](../../tools/map-v2/README.md) :3, `:11`).

## The authoring contract

The Rojo tree has no `Workspace` key at all (`default.project.json:3-41`): the only `ServerStorage` entry is `Tests` from `tests/` (`:18-22`). Editing the map means editing it in Studio and saving the place — `rojo serve` can never overwrite it. `assets/*.rbxm` are Studio exports of those same instances, kept in git as backups and restored with Studio's Insert from File (they are deliberately not wired into a Rojo project); the roster and where each instance is read at runtime:

| Backup | Instance it stands for | Where code reads the real one (by name) |
|---|---|---|
| `assets/Map.rbxm` | `Workspace.Map` — crater, town, roads, debris, boundary | `WorldMap.wait()/find()` look it up by name — `src/shared/WorldMap.luau:18-24` |
| `assets/ServerAssets.rbxm` | `ServerStorage.Assets` — `Meteor.Core` (with `NodeSlot` attachments and `Vein` parts), `NodePieces` rocks | `WorldMap.assets()` `src/shared/WorldMap.luau:14-16`; cloned in `MeteorService:_spawnMeteor` `src/server/Services/MeteorService.luau:366-373` (header `:6-8`) |
| `assets/Refinery.rbxm` | the authored `Map.TownSquare.Refinery` model (one `UsePoint`) | `WorldMap.refineryPoint` `src/shared/WorldMap.luau:26-31`; prompt wiring `src/server/Services/RefineryService.luau:218-243` |
| `assets/PetModels.rbxm` | `ReplicatedStorage.PetModels` (part-built models, one per pet id) | `PetModel.source` `src/client/PetModel.luau:15-19`, cloned at `:24`; preloaded `src/loading/LoadingScreen.client.luau:608`; rebuilt by `tools/build-pet-models.luau` (`:590` export note) |
| `assets/StarterPack.rbxm` | `StarterPack.Pickaxe` (the Basic Pickaxe tool) | `ShopService` watches StarterPack hand-outs and re-styles them (`src/server/Services/ShopService.luau:244-259`); safety-net clone of the template `:280-282`; the tier look is applied by `EquipmentModels.applyToTool` via `styleTool` (`:57-61`), not a saved `Tint` attribute (the old README claim) |
| `assets/Lighting.rbxm` | `Workspace.Lighting` + its `Atmosphere`, Bloom, Grade (the calm look) | no runtime loader — the place owns it; `AtmosphereController` reads the saved values at join (e.g. the Grade tint `src/client/Controllers/AtmosphereController.luau:40`) and blends moods over them (header `:1-8`) |
| `assets/Terrain.rbxm` | the outer mountains, stored as a TerrainRegion | no runtime reader; restore with `workspace.Terrain:PasteRegion(region, Vector3int16.new(-160, -32, -160), true)` (recipe from the legacy README, kept here when the README was slimmed). Peaks authored by `tools/terrain/author-mountains.luau` (header `:1-5`) |

Studio-only staging: with a `DevWorldMap = "Map_Redesign"` attribute on Workspace **and** `RunService:IsStudio()`, every lookup swaps to `Workspace.Map_Redesign` and `ServerStorage.Assets_Redesign` — nothing else changes (`src/shared/WorldMap.luau:6-16`). That is how the map tooling authors a new map beside the live one.

## The names code depends on

Gameplay finds world content by fixed instance paths, so renaming map instances breaks services. Contracts the current map satisfies (full list in [tools/map-v2/README.md](../../tools/map-v2/README.md) :50):

| Path under `Workspace.Map` | Read by |
|---|---|
| `Crater.MeteorSpawn` | the meteor is placed at this part's CFrame each impact (`MeteorService.luau:367`, `:374`); the tutorial's "reach the crater" step measures distance from it (`src/server/Services/TutorialService.luau:99`) |
| `Crater.ActiveMeteor` | parent of every live meteor model, destroyed at cleanup (`MeteorService.luau:514`, `:585-591`) |
| `Crater.SkyTimer.Board` | the HUD fills the saved sky board's title/time labels (`src/client/Controllers/HUDController.luau:341`) |
| attr `MapRedesignOwned` on `Map` | boundary enforcement only runs for the redesign map (`src/shared/WorldBoundary.luau:8`) |
| `TownSquare.Refinery` model + `Refinery.UsePoint` | `WorldMap.refineryPoint` requires exactly this shape or RefineryService refuses to start (`src/shared/WorldMap.luau:26-31`; `RefineryService.luau:220-222`); the 14-stud `UseRefinery` prompt is created at runtime on each point (`RefineryService.luau:226-239`), transactions re-check an 18-stud range (`src/shared/WorldMap.luau:48-57`, `RefineryService.luau:247-249`) |
| `TownSquare.Commissary.UsePoint` | optional second deposit point, same rules (`src/shared/WorldMap.luau:34-46`; `RefineryService.luau:225`, `:234`) |
| `TownSquare.Leaderboards.<Id>.Screen` | LeaderboardService waits for the folder and builds each board's SurfaceGui rows on the `Screen` part (`src/server/Services/LeaderboardService.luau:153-166`) |
| `GearHall.TierWalls` + `GearHall.CurrentStands` | local gear-hall displays mount equipment models and live stats on these (`src/shared/WorldEquipmentDisplay.luau:44`, `:64`; `GearHallController.luau:45`) |
| `Debris` (rock roots, attr `Field`) | DebrisService registers every BasePart in the folder, sizes HP, respawns and respawns-tint only `OreFleck` children (`src/server/Services/DebrisService.luau:2-3`, `:246-251`; tint `:109`) |
| `DebrisFields.<Id>.FieldFloor` | the field teleport lands on the measured floor top, at the first clear aisle offset (`DebrisService.luau:194-208`) |
| `PickaxeShop.ShopPoint` / `TradingPost.SellPoint` | optional in-world prompts; **the current map has neither**, shop and selling are HUD-only (`src/server/Services/ShopService.luau:10`, `:215-217`; `EconomyService.luau:110`, `:120-127`) |

`RebirthMonument.RebirthPoint` is an authoring contract comment only (`tools/map-v2/Rebirth.luau:3`); rebirth is claimed from the HUD, and no service reads that part.

## Shared.WorldGeometry — code's picture of the map

`src/shared/WorldGeometry.luau:1-2` says its own job: geometry and limits only, mining/economy rules live elsewhere. Groups, what they model, and who reads them (all cites in `src/shared/WorldGeometry.luau` unless noted):

| Group | Constants | Consumers |
|---|---|---|
| Scaling/staging | `MeteorScale = 2` (`:5`), `BuildingScale = 0.5` (`:6`), `StageOffset` zero (`:7`) | `MeteorScale` sizes every FX dimension and knockback push (`src/shared/WorldImpact.luau:7-10`; `src/client/Controllers/MeteorFXController.luau:26` via `MeteorVisualGeometry.build`); `BuildingScale` is read only by the retired `tools/map-redesign/SmallBuildings.luau:5` and pinned by `tests/WorldGeometry.spec.luau:60`; the `toStage`/`toFinal` pair (`:74-80`) is identity now the v2 map is authored in place (spec `:101-103`) |
| Boundary/kill | `BoundaryHalf = 270` (`:9`), `KillPlaneY = -70` (`:17`) | `Geometry.inside` (`:156-163`) gates `WorldBoundary.enforce` (`src/shared/WorldBoundary.luau:13-22`), run server-side every 0.25 s (`src/server/Services/WorldBoundaryService.luau:11-21`); the tools author a physical `Boundary.KillPlane` at the same Y (`tools/map-v2/Boundary.luau:101-103`) and `tools/map-v2/Roads.luau:6` asserts 270 |
| Ring road | `LoopRadius = 134` (`:10`), `PathWidth = 18` (`:18`) | `CharacterSpeed.onRoad` grants the 1.5× fast lane on this annulus (`src/shared/CharacterSpeed.luau:11`, `:15-21`, `:26`); `quarterAt` treats everything inside it as town (`src/shared/WorldGeometry.luau:99`) |
| Landing clearance | `LandingRadius = 125` (`:8`) | an authoring guard, not runtime: `tests/WorldGeometry.spec.luau:34`, `:49-51` keep zones and Ice fingers outside it; the tools assert the same (`tools/map-v2/DebrisFields.luau:289`, `Refinery.luau:169`) |
| South plaza/spawns | `SouthPlazaHalf = 40` (`:14`), `SpawnRowsZ`/`SpawnColumnsX` (`:15-16`), `MainPathWidth = 24` (`:19`), `CraterRampWidth = 24` (`:20`) | the roads stage places the six SpawnLocations from the row/column grid (`tools/map-v2/Roads.luau:91-92`) and paves the plaza/ring (`:24-29`); ramps and apron corridors use their widths (`tools/map-v2/Crater.luau:11`; `CraterApron.luau:12-13`); spec guards (`tests/WorldGeometry.spec.luau:89`, `:112-114`) |
| Town zones | `Zones` (`:24-36`): Spawn, Refinery, GearHall, Hatchery, Rebirth, TradingPost, two Leaderboards, Commissary — plus the four field zones appended as computed boxes (`:137-154`) | every map-v2 building stage centres itself on `Geometry.zone(id)` (`tools/map-v2/Common.luau:148` wrapper; Refinery `:9`, GearHall `:15`, Hatchery `:10`, Rebirth `:8`, Commissary `:9`, Leaderboards `:28`, `:39`); `footprintDistance` (`:57-61`) is the spec's landing-clearance yardstick (`tests/WorldGeometry.spec.luau:49-55`) |
| Quarters/fan | `Quarters` angles (`:41-46`), `Fan` distances (`:50`) | authoring only: Biomes decorates per quarter via `quarter`/`quarterAt` (`tools/map-v2/Biomes.luau:38-41`, `:91`, `:117`) and DebrisFields lays the 20-rock fans and asserts each rock stays in its quarter/fan (`tools/map-v2/DebrisFields.luau:191`, `:256-258`, `:312-313`). Runtime field gameplay never re-reads them — travel uses the authored `FieldFloor` and the offsets in `src/shared/FieldTravel.luau:11-14` (a 22-stud rock grid with 14-stud aisles, `:9-10`) |

**Hazard: moving map geometry in Studio without updating these numbers desyncs gameplay.** The crater's shape is believed twice over: `Config.LandingFX.Crater` (`src/shared/Config/LandingFX.luau:9-10` — floor Y −14.755, floor radius 55.25, opening 83.2, rim Y 0) drives both the crater art stage (`tools/map-v2/Crater.luau:10-11`) and the server's kill rule, which drops the floor linearly with radius and kills anyone under it minus 4 studs of tolerance (`src/shared/WorldBoundary.luau:14-21`). Re-sculpt the bowl in Studio and leave the config, and players walking the new floor start dying (or, once the floor drops below `KillPlaneY = -70`, only the flat kill plane catches them, `src/shared/WorldGeometry.luau:17`, `:162`). Same for the ring: move it and `CharacterSpeed.onRoad` pays the fast lane on the wrong strip (`src/shared/CharacterSpeed.luau:15-21`). Change layout numbers in `WorldGeometry`/`Config.LandingFX` and re-run `tests/WorldGeometry.spec.luau` (specs not run here: no Studio this session).

## What is cloned at runtime

- **The meteor, every event.** Schedule: first meteor 90 s after server start, then a 180 s cycle (`src/shared/Config/Meteor.luau:8-9`; Studio shortens the countdown to 25 s, `:34`). `MeteorService:_spawnMeteor` clones `Assets.Meteor.Core`, places it at `Crater.MeteorSpawn` with random yaw (`src/server/Services/MeteorService.luau:373-374`), recolours veins/lights/emitters per type (`:377-388`), then clones one random `NodePieces` rock onto each `NodeSlot` attachment (`:368`, `:394-399`, `:453-465`) — every slot is a mineable crust node, sized by server Mining Power (`:400`), and the core is the last node registered (`:496-512`). The whole model lives under `Crater.ActiveMeteor` until cleanup destroys it (`:514`, `:585-591`). Impact lasts 3 s (`src/shared/Config/Meteor.luau:10`), then Active, then cracked-or-cooled (`MeteorService.luau:593-646`); anyone inside the 117-stud shockwave is teleported clear by a raycast against the authored surfaces `Ground`/`Roads` and `Crater.Bowl/MiningAccess/AccessRamps/Rim` (`src/shared/Config/Meteor.luau:65-69`; `MeteorService.luau:542-554`; `src/shared/WorldImpact.luau:5-31`). The client-side streak/flash/shockwave share the same scale (`src/client/Controllers/MeteorFXController.luau:26`).
- **Pet followers and hatch previews** are client-side clones of `ReplicatedStorage.PetModels` models (`src/client/PetModel.luau:15-24`).
- **A pickaxe** when a spawn somehow has none: `ShopService` clones `StarterPack.Pickaxe` into the backpack as a safety net (`src/server/Services/ShopService.luau:268-285`).
- **What is *not* cloned:** debris rocks (authored in `Map.Debris`; the service only adds HP, respawn and fleck tint — `src/server/Services/DebrisService.luau:2-3`, `:109`); the refinery line (the plot-era `PlotStations` clone is gone — one saved line per player, and the shared Foundry is authored art: [tools/map-v2/README.md](../../tools/map-v2/README.md) :25, line model in [economy.md](economy.md)); leaderboard rows (built at runtime onto saved Screen parts, `LeaderboardService.luau:153-166`).

## Meteor field layout at a glance

The crater centrelines sit at the world origin (the doubled landing shell is partly buried at Y −1.25, `src/shared/Config/LandingFX.luau:9`), inside a 540 × 540 box (±270). The town fills the south; the ring road (radius 134) separates town from the four **ore-field quarters** — slices of the circle named in code `SulfurRidge` −20°..36°, `FrostYard` 36°..90°, `RustWorks` 90°..144°, `VioletQuarry` 144°..200° (`src/shared/WorldGeometry.luau:41-46`; angles are `atan2(z, x)`, comment `:37-40`). Each quarter holds one field: a gate 160 studs out on its centre line, a fan of rocks widening from there to 238, the ORE-travel landing spot at 172, and a landmark rectangle 250 out (`Fan`, `src/shared/WorldGeometry.luau:47-50`). The same four ids are the travel list and rewards in `Config.Debris.Fields` (`src/shared/Config/Debris.luau:27-39`) — a rock's `Field` attribute sets its hits and payout, filler rocks stay iron (`src/shared/DebrisField.luau:1-3`, `:14-21`). New players are parked in `RustWorks`, the softest field (`src/shared/Config/Tutorial.luau:36-39`; tutorial crater arrival counts within 83.2 studs of the crater centre, `:41-42`).

## Light, terrain and landing FX (place-owned, code-polished)

The calm look — low sun, warm light, the fog (`Atmosphere`), Bloom, Grade, `Terrain.Clouds` — is authored into the place by `tools/atmosphere/author-lighting.luau` (header `:1-5`) and saved like the map (`src/shared/Config/Atmosphere.luau:2-6`). `AtmosphereController` reads it once at join and blends meteor moods over it on each client — approach gloom tinted by the type's glow, impact dust, fade-out — writing Lighting only while the look changes (`src/client/Controllers/AtmosphereController.luau:1-8`; rules `src/shared/AtmosphereMood.luau:1-12`; tuning `Config.Atmosphere`). Ice and Crystal meteors additionally grow per-client crater scenes (sheets, crack lines, clusters, arcs) seeded by the event so everyone — even a mid-event joiner — sees the same scene at the same moment (rules `src/shared/LandingFX.luau:1-8`, seeding applied `src/client/Controllers/LandingFXController.luau:1563-1564`); budgets and the crater geometry they must avoid are in `src/shared/Config/LandingFX.luau` (160-part budget `:6`, crater `:8-15`, cardinal corridors `:17-19`), drawn by `LandingFXController` (named `src/shared/Config/LandingFX.luau:2`; core-crack listener `src/client/Controllers/SurfaceFXController.luau:483-487`, wiring in [architecture.md](architecture.md)'s MeteorService row). The mountains beyond the walls are real terrain (`tools/terrain/author-mountains.luau`, header `:1-5`), and the authored sea sits at Y −16, below the crater floor — raise it and the crater floods ([tools/map-v2/README.md](../../tools/map-v2/README.md) :59). Studio dev attributes for these effects (`DevLandingFX`, `DevMeteorApproachFX`) are catalogued in [dev-hooks.md](dev-hooks.md).

## Map tooling (authoring-time, never runtime)

All stages run in Studio **Edit** mode over a local HTTP file server and create anchored art — no saved scripts ([tools/map-v2/README.md](../../tools/map-v2/README.md) :13-27; full rebuild order `:24`). One-liners from each header:

| Script (in `tools/map-v2/`) | Owns / does |
|---|---|
| `Common.luau` | shared edit-time helpers, ownership and staged-map checks (`:1-4`); geometry asserts `:23` |
| `Brick.luau` / `Toon.luau` | the building grammars: local frames and toy-brick parts (`Brick :1-3`); cartoon shapes, ramps, props and hero-mesh fallbacks (`Toon :1-3`) |
| `Crater.luau` / `CraterApron.luau` | ground, crater, ramps, sky timer contracts (`Crater :1-3`); scorch splashes and fragments on the lawn ring (`CraterApron :1-5`) |
| `Roads.luau` | ring road, approaches, forecourts, the six spawn pads (`:1-3`; grid at `:91-92`) |
| `Refinery.luau` / `GearHall.luau` / `Hatchery.luau` / `TradingPost.luau` / `Rebirth.luau` / `Commissary.luau` / `Leaderboards.luau` | one zone stage each, centred on its `Geometry.zone` (`Refinery :1-4`, `GearHall :1-3`, `Hatchery :1-4`, `TradingPost :1-4`, `Rebirth :1-2`, `Commissary :1-4`, `Leaderboards :1-4`) |
| `DebrisFields.luau` / `Biomes.luau` | the four rock fans + landmarks (`DebrisFields :1-4`); per-quarter ground stripes and props (`Biomes :1-4`) |
| `Boundary.luau` / `Surroundings.luau` / `Backdrop.luau` | castle-rampart walls, lawn, kill plane (`Boundary :1-4`); island beach, lagoon, lighthouses (`Surroundings :1-3`); far mountains, Meteor Peak, sky islands (`Backdrop :1-4`) |
| `Scenery.luau` / `StudStyle.luau` / `StaticQA.luau` | rejection-sampled props (`Scenery :1-3`); stud textures on ground/roads/walls only (`StudStyle :1-2`); the read-only geometry/budget audit, Edit mode only (`StaticQA :1-3`) |

Budgets, style rules, contracts and rollback stages (the in-place `ServerStorage.SwapRollback.Map_v*` copies plus disk copies under `assets/archive/`) are all in [tools/map-v2/README.md](../../tools/map-v2/README.md) (`:40-47`, `:49-50`, `:62-63`). Two older tool sets remain on disk as history: `tools/map-redesign/` (superseded 8 October — its README header says so, `tools/map-redesign/README.md:1`) and `tools/map-art/` (the October map-model art pass brief, `tools/map-art/README.md:1-3`).

## History

The root README's "plot-era map" prose (twenty plot pads, `PlotStations` lines cloned onto claimed plots, town-square-only shopping — `README.md:163-173`) predates the crater redesign and is stale: no `PlotService` exists in `src/server/Services/` (git ls-files, verified 2026-10-18; [architecture.md](architecture.md) lists the 25 services without it), and the personal line is one saved level, not placed parts (see [economy.md](economy.md)). The redesign that replaced it is archived: plan in [docs/archive/map-redesign/PLAN.md](../archive/map-redesign/PLAN.md), the compact-world spec that supersedes it in [docs/archive/map-redesign/COMPACT-REVISION.md](../archive/map-redesign/COMPACT-REVISION.md), and the Studio prompt that placed the shared refinery in [docs/archive/studio-refinery-prompt.md](../archive/studio-refinery-prompt.md). The current map is map v2; its README is the living contract.

## Where to read next

- Service wiring and the meteor state machine's place in the bus: [architecture.md](architecture.md).
- Line levels, hopper and bar prices behind the refinery prompt: [economy.md](economy.md).
- Menu/HUD work on top of this world: the native-menus and HUD guides (being rebuilt in this wave).
- Studio dev attributes and the geometry specs: [dev-hooks.md](dev-hooks.md), [testing.md](testing.md).
