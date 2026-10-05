# MeteorShift map redesign plan

APPROVED by self — 5 October 2026. Approval covers the measured design and staged implementation below; it does not waive QA, saving, exports or the final completion audit.

**Goal:** Replace the dusty plot town with an original, bright, studded simulator world for 30 players, a meteor at least twice as large in every linear dimension, and one shared economy hub. Keep the owner's GUI and all economy, odds and monetization rules.

**Execution:** Native execution in this checkout, using Roblox Studio MCP. The owner requested self-approval and continuous work. Keep the existing branch and user files; scene isolation is `Workspace.Map_Redesign`, not a second checkout that would disconnect the open place from source. Read this plan, PROGRESS.md, Git status and connected Studio state at every start.

## Baseline and protection

- Current branch `job-for-tomorrow`, HEAD `9e66f0a54cd0235fb1e1db19a4b46d6c4e3a0954`. The earlier UI work is now committed. `docs/ff.md` is an unrelated untracked owner file and remains untouched.
- Studio place 113476105600560, Craterworks: Meteor Mining. Re-list instances before future mutations.
- Fresh Edit test runner: **360 passed, 0 failed**.
- Edit Map: **2,043 BaseParts**, including **434 unions and 75 MeshParts**, **18 lights**, **22 emitters**, 2,390 descendants. Runtime sample had 2,543 parts; runtime meteor/effects are extra and must not be mistaken for authored map geometry.
- Runtime rendering sample: 527,887 total triangles / 579 total draw calls; excluding shadows, **467,188 triangles / 491 draws**. 72 RenderStepped samples: median **27.6725 ms**, p95 **29.1626 ms**, max **29.5884 ms** at 1375 × 659. This is one Studio view, not device certification.
- Core root is a 28.349998-stud cube/sphere Part with 64 total BaseParts including decorations. It has **36 NodeSlots**. Slot horizontal radius max 16.60306, Y range -11.23144 to 16.21294. Four union NodePieces are 20 × (8.2–8.8) × 20 with 10–12 descendants each.
- Conservative crust envelope across every slot and all four unrotated piece bounds: **50.23167 × 44.81177 × 50.31626**. Random yaw can change the exact assembled bounds; runtime QA samples rotations rather than treating this envelope as the final truth.
- Existing MeteorSpawn (0, -1.25, 0). Floor -11.35 / radius 42.5, opening 64, knockback 90, tutorial reach 80. Existing refinery pivot (-22, 0.6, -110) is unsafe for the enlarged effect radii and will be replaced only in the staged map.
- Existing four exports were copied with SHA256 verification to `assets/archive/before-redesign/`. Fresh Studio binary snapshots were also serialized and are being written under `assets/archive/before-redesign/studio-snapshot/`: Map 185,912 bytes, Terrain 1,073,893, ServerAssets 96,061, Lighting 4,932. Terrain capture covers voxel corners (-256,-64,-256) to (256,128,256); restoration uses the stored corner attribute.
- `frozen-gui-baseline.json` records 39 protected disk files. Keep UI/HudView/HudLayout/Config.Hud/EquipmentShopLayout, all internal-menu builders/exports/helpers, and named GUI controllers unchanged. The owner explicitly approved **only TutorialController's world-target lookup** changing from plot Intake/Bin to shared UsePoint; panel code remains byte-for-byte unchanged. A remaining dormant PlotId listener in the frozen RefineryController must be reported rather than silently edited.

## Layout and access

All coordinates below are final local world coordinates, X east / Z north-south. Ground top Y=0. The staged map is built at **offset (0,0,1600)** to avoid physical overlap with the original. The swap removes that offset. `layout.svg` depicts the final layout.

| Zone | Centre X,Z | Footprint / entrance |
|---|---|---|
| Meteor crater | 0,0 | Floor radius 90 at Y=-44; opening radius 160; four 24-stud access ramps at cardinal bearings |
| Mining access | 0,0 | 18-stud terraces/catwalks around the meteor; continuous ascent from floor to upper nodes; upper radial bridges if geometry QA proves they are needed |
| Outer path loop | 0,0 | Radius 320, at least 18 wide; four cardinal approaches and zone connectors |
| Shared Refinery | 0,-380 | 76 × 64; front faces +Z toward crater, UsePoint at (0,3,-343), 18-stud clear forecourt |
| Gear Hall | 140,-380 | 100 × 72; crater-facing open entrance centred (140,-341); PickaxeShop counter inside, two live stands and two eight-tier walls |
| Hatchery | -155,-380 | 100 × 72; entrance (-155,-340); Config-generated decorative egg/odds pedestals |
| Trading Post | 70,-460 | 56 × 40; entrance (70,-434), SellPoint near the front |
| Spawn plaza | -20,-458 | 96 × 64 with six 12 × 12 spawn pads and 24-wide avenue; no compulsory choke point |
| Rebirth monument | -360,-160 | 72 × 72; entrance (-325,-160), via west loop |
| Index museum | 360,-160 | 84 × 76; entrance (316,-160), via east loop |
| Rust Works debris | -275,270 | 100 × 92; nearest footprint radius317.49; entrance from north-west loop |
| Frost Yard debris | 275,270 | 100 × 92; nearest footprint radius317.49; entrance from north-east loop |
| Violet Quarry debris | -390,55 | 92 × 96; east entrance |
| Sulfur Ridge debris | 390,55 | 92 × 96; west entrance |
| Boundary | 0,0 | Playable square inside ±510; sealed 72-high walls/cliffs, collision roof caps, under-map kill plane at Y=-70 |

The town avenue is centred at Z=-326 and spans the hatchery/refinery/Gear Hall fronts; a 24-wide spine joins it to spawn and Trading Post. Each field has twelve spaced mineable rocks (48 total) with walkable aisles. Decorative ore colour does not change drops or odds. All entrance connectors are ≥18 wide; no path may be under14. Landmarks must face/advertise their entrance, not place a sign on a closed wall.

## Style guide

Original authored primitives, bevel wedges, unions already authored for this game and Config-generated equipment. No Creator Store art, copied brands or bought map kits.

Palette: grass (104,214,65), deep navy (24,37,61), stone (72,82,100), cyan (41,201,255), refinery ember (255,130,35), reward gold (255,215,54), violet (190,99,255), frost (130,232,255). Keep colour groups distinct: orange refinery, blue Gear Hall, pink/violet hatchery, gold rebirth, cyan museum. Use white/cream trim to separate saturated silhouettes.

Stud approach: native `TopSurface = Studs` on major block platforms, signs' backing blocks and props; selective oversized cylinder studs on landmark roofs/hero props. Avoid thousands of individual ground studs. Bevels are sparse wedge/chamfer trim, not a chamfer per brick. Neon is reserved for veins, furnace openings, crystal details and navigation highlights. Signs use native world SurfaceGuis with heavy outlined headings and a minimum of24px secondary type; internal ScreenGuis are frozen. Tall pickaxe/backpack, chimney/hopper, eggs, rebirth loop and museum crystal silhouettes should identify zones before text is readable.

Lighting: bright warm daylight, modest bloom, shorter haze, no heavy depth-of-field. Terrain grass and sprawling old terrain are excluded from the new look; authored low-cost block cliffs seal the map. Preserve old Terrain until pre-swap QA, then archive/replace it during the controlled swap, with rollback snapshots retained.

## 2× geometry mathematics

- Scale Core root and all descendant part sizes/local offsets, attachments, vein geometry, emitter dimensions/speeds and light ranges by **2.0** exactly from the captured originals. Scale all four NodePieces and descendants similarly. Store a version/scale attribute so reruns clone the pristine snapshot and never compound scaling. Keep 36 slots, HP computation, timing, yield, rewards and mining reach unchanged.
- Core size becomes **56.699996** in each axis; slot radius **33.20612**, Y range **-22.46288..32.42588**. Conservative shell envelope becomes **100.46334 × 89.62354 × 100.63252** before random yaw. Use MeteorSpawn (0,2,0) to place the lowest shell close to the -44 floor; verify no floating shell/support gaps with actual variants.
- Floor radius90, floorY=-44, opening160, rimY0. Radial walking-ring width is40+ beyond the shell radius (~50.3). Four ramp runs from radius90 to160 rise44 over70, approximately32.2°, with24-wide landings. Mining terraces use ≤30° segments,18-wide clear floor and low guard edges; reach QA uses the existing part-box distance with Basic Reach12 and mining ray visibility, not a rule increase.
- Knockback radius **180**; speed110/lift55 and zero damage retained. Tutorial reach **160**, intentionally inside the refinery forecourt radius343.
- Landing geometry uses twice the original dimensional values, then shifts upright cluster rings outside the enlarged160 opening: clusters at180/184/188, footprint12; crack/spoke radii52/84/106/128; upright-clear radius164; Ice sheet164 diameter, Crystal shimmer156; crystal circle170, rays to256; Ice fingers begin170, maximum length140 → **outermost310**. Other distances/heights/widths scale2; counts/timings/angles remain unchanged. A geometric spec must assert all interactive footprints and refinery nearest point are outside310 plus clearance.
- Refinery minimum footprint distance is **348** (380−32), ≥38 beyond the worst landing extent310 and168 beyond knockback180. UsePoint343 also clears both. No tall effect may overlap a path/interactive zone; preserve obstacle/corridor avoidance and update it for cardinal paths.
- Debris-field centre radii and exclusion radius live in geometry tuning; do not change HP/yield/respawn/ore rules.
- Scale visual streak/flash/dust/rings by2, spatial sound reach by2, and shake falloff distance by2 with a capped modest gain. Honour existing ReduceEffects and ReduceCameraShake. Assert FX part/emitter counts remain within budgets.

## Numeric budgets

| Budget | Limit |
|---|---:|
| Authored Map parts (excluding transient meteor and local equipment) | ≤1,800 |
| Authored Map MeshParts imported from external art | 0 |
| Shared Refinery parts | ≤180 |
| Server meteor at runtime | ≤550 parts,36 crust nodes |
| World equipment display models | 18 total (16 tier wall +2 current), Config-generated; ≤650 parts |
| Enabled map lights | ≤12, shadows off for decorative lights |
| Enabled map emitters | ≤16, aggregate steady rate≤65/s |
| Steady map particles (rate×maximum lifetime) | ≤260 |
| Existing Ice/Crystal landing parts | ≤160; existing reduced/mobile cap retained |
| Local pet models, including all previews | Existing40 total retained |
| Event view triangles excluding shadows | ≤500,000; target≤300,000 |
| Event view draw calls excluding shadows | ≤400; target≤300 |
| Desktop Studio frame-time sample, event +40 visual pets | p95≤33.3ms, target≤22ms; 300frames afterwarmup |
| Reduced/mobile Studio sample | p95≤33.3ms; simulator is layout/load evidence, not real hardware certification |

Measure multiple player-height views per zone, plus overview and event view. Record samples and exact load, not a single best camera. If any limit is missed, reduce authored geometry/terrain, visible lights, particle overdraw or update frequency and remeasure. Do not weaken tests/budgets to finish.

## Code and artifact boundaries

Create `Shared.WorldGeometry` (layout/2×constants +safe bounds), `Shared.WorldEquipment` (pure Config-generated unlocked/current/locked tier states +stats), `WorldEquipment.spec` and `WorldGeometry.spec`. Create a world-space client `GearHallController` that consumes State, generates18 EquipmentModels, rotates only the two live models, updates on tier/stat changes, draws SurfaceGui statistics/status, and destroys replaced geometry. Stand models remain local to the observer. Create boundary authority service to kill under/outside-map characters without changing profile/economy state.

Remove runtime plot allocation/presentation and template fallbacks from PlotService, RefineryService, UpgradeService, HomeController and relevant PlayerState fields. Prefer removing retired PlotService/HomeController files once all consumers are detached. Shared RefineryService keeps Deposit/Collect, priority, offline catch-up, server distance validation and per-player saved line semantics; upgrading retains identical costs. Shared production animations can use aggregate world activity and cheap decorative ore without displaying another player's private inventory.

Allowed world-related consumers: MeteorService, MeteorFXController, LandingFXController, DebrisService, ShopService, EconomyService, TutorialService, NodeHealthController, MiningController and PetVisualController. Use a Studio-only map-root selector for staged QA; keep public Map contracts at final swap. Frozen HUD reads Workspace.Map, so pre-swap staging cannot prove its world board/core-HP bindings; that coverage belongs to immediate post-swap QA. Never change the frozen HUD to make staging easier.

Authoring is split into rerunnable tools in `tools/map-redesign/`: common primitives/signs, terrain/crater/access, town/landmarks, debris/boundary, meteor-template scaling, contract/geometry QA, binary export/restore and swap. Author under Map_Redesign only; version stages and rebuild only their own containers. Contract exports remain `assets/Map.rbxm`, `Terrain.rbxm`, `ServerAssets.rbxm`, `Lighting.rbxm`.

## Stages and verification gates

- [ ] **1. Protected baseline and approved plan:** archive both repository assets and fresh Studio snapshots; frozen manifest; layout.svg; full baseline runner; review below; commit/push checkpoint. Do not include docs/ff.md.
- [ ] **2. Geometry and shared-only contracts:** failing pure geometry/equipment specs first; implement helpers; update dimensions/spec expectations; remove plot runtime and approved tutorial world lookup; full runner green; source/frozen review; export scaled templates; save/commit/push checkpoint.
- [ ] **3. Staged world:** build ground/bowl/ramps, roads, six spawns, shared refinery, Gear Hall, hatchery, Trading Post, rebirth, museum, four debris fields, atmosphere, sealed boundary/kill plane. Each stage is rerunnable and restricted to Map_Redesign. Static contracts, distances, collision/reach and numeric budgets; export staged checkpoint; save/commit/push.
- [ ] **4. Staged Play QA:** use opt-in memory profiles only; no saved progression fixtures. Every spawn→every interactive point pathfinding AND real walking; ascent/descent and jump tests; all36nodes +core reachable with Basic; Iron/Ice/Crystal twice-scale bounds, fit, no harmful shockwave; debris/refinery/Claim/selling/shop/pets/tutorial/rebirth/rejoin. Fully green runner, clean Output. Sample performance and phone320×568,390×844,844×390. Report frozen GUI issues.
- [ ] **5. Critique/fix:** screenshot every zone in at least3rounds. Score silhouette/landmarks, colour, studs, scale, density, signs, navigation, reward feel, performance1–5. Fix each score<4. Need all scores≥4 for2consecutive rounds; no self-awarded numbers without screenshots/measurements. Save/commit/push each completed round checkpoint.
- [ ] **6. Controlled swap:** only after gates4–5 pass, rename originalMap→Map_Old, stagedMap→Map, remove stagingoffset, replace archived Terrain/Lighting, apply scaled Assets. Run the complete contract/runtime/frozen/performance QA again. If broken and not quicklyrepairable, restoreMap_Old, originaltemplates/Terrain/Lighting and say so. Retain rollback until post-swap passes; then deleteMap_Old.
- [ ] **7. Delivery:** saveplace withoutpublishing, fourfinalbinary exports, README/restoration/tool docs, REPORT.md with finalcoordinates/counts/perf/assumptions/unverified/GUI followups/firstviews, finalcheckpointcommit/push. Audit every pastedobjective requirement againstcurrent evidence before markinggoalcomplete.

## QA implementation

Pure tests use the existing `ServerStorage.Tests.Runner` scratch-clone runner. New geometry tests must fail before implementation, covering2×Core/shell math, radius clearance, allentrance/path widths, boundedworld positions and staged→final translation. Equipment specs cover all8tiers for each kind, first/max tier, malformed/missingstate fallback, current/unlocked/lockedstates and immediate derived stats. Keep existing tests and expectations that still express valid rules; replace obsolete geometry literals with explicit2×/new-radius assertions rather than deletechecks.

Static world QA enumerates exact names and allBaseParts; tests oneUsePoint/PrimaryPart/SharedRefinery, no scripts/Humanoids/prompts in refineryEdit, oneActiveMeteor folder, PickaxeShop+ShopPoint, TradingPost.SellPoint+prompt,48directBasePartdebris roots,6enabledspawns,Atmosphere, and noPlots/PlotStations in finalroots. Include pathfinding AgentRadius3/Height6 and route clearance. Mining QA samples rotations and actualrandompieceplacements; prove reach12 plus lineof sightfromwalkablepositions for every live node, includingupper/lower nodes.

Play QA uses temporary opt-in DevMemoryStore, clearedbeforeSave. Runtime-only test manipulation may exercise devhooks, but no enabled Script may grantprofileprogression on join. Detect any warning/error in Output and resolve it; distinguish MCP/API diagnosticerrors fromgamewarnings. Real Marketplace tests are outside scope because allIDs0; no odds/economychanges.

## Rollback and save limitation

Before swap, oldMap is untouched and fresh unparented clones/binaryarchives preserveactualEdits. Swappedrollback usesMap_Old plusarchives; restoresource fromstagecheckpoint only for thischange'sfiles, never resetownerGUI/untrackedwork. TerrainRestoreCorner is encodedin itsTerrainRegionarchive. Lightingfolderholds cloned effects/cloudsandlightingproperties asattributes forrestore.

MCP can serializebinaryassets but the previous Edit saveattempt failed: `Game:SavePlace can only be called from a server script`. No computeruse is authorized. Do not savea Play/testDataModel as a workaround. Keep concretecheckpointassets/source before requestingmanualCtrl+S; recordsaveevidence whenreceived. Saving/pushing are explicitrequirements and cannot be silentlyclaimed.

## Self review

Checked every numbered objective against stages1–7; contracts retain exacthierarchy; allzones have anentrance and≥18path; refineryminimum348>310>180; 36slots/HP/rules unchanged; nativegeometrypart/light/particle/render/framebudgets arenumeric; allGUI paths frozen withoneowner-approvedworldlookup exception; original/backups retained; nofinalswap beforeQA; export/restore/save/push/report/threecritique rounds included. The dormant frozenRefineryControllerPlotId listener and stagedfrozenHUDbindings are explicitfollowups, not silentexceptions. **APPROVED by self.**
