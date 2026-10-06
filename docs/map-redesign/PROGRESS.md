# Map redesign progress

## Shared runtime checkpoint — 6 October 2026

Verified the new Studio session in Edit: same place113476105600560,1417 staged parts, original Map intact. Shared-only RefineryService/UpgradeService now require the exact UsePoint and a living character within18studs for menu transactions/priority/upgrades/open; prompt remains14studs/E. Deposit/collect, upgrade costs, refining and multipliers are unchanged. World state exposes only aggregate Running. PlotService/HomeController and State.plotId are retired. PlotPresentation/spec were renamed ProductionPresentation with every test retained. Ten non-frozen world consumers select the Studio staging root. The frozen RefineryController's dormant PlotId listener and HUD/tutorial Map lookups remain reported follow-ups for runtime QA.

WorldBoundaryService enforces selected-map coordinates every0.25s (horizontal±510, kill planeY−70), only for MapRedesignOwned maps. WorldImpact evacuates the doubled52stud footprint to radius60 and raycasts actual collision surfaces, excluding active meteors. All36 staged angular probes found walkable ground (root targetY3.500006–17.112648). Real impact survival, walking/jumps and under-ground exploit QA remain pending.

RED: WorldMap3passed/3failed before access helper; Boundary0/1 missing; Impact0/1 missing. Fresh full scratch-clone suite **396passed/0failed**. All22 changed/new live sources match disk and compile.39 GUI hashes checked; only the approved TutorialController lookup differs. Native Ctrl+S confirmed **17:54:14.714 Saved new changes in "Craterworks: Meteor Mining" to Roblox.** No publishing, map/assets swap or final export changes.

Automatic review initially rejected the Studio migration for missing plot-removal authorization. The preserved user redesign attachment explicitly requests removing plots and plot-only runtime; that exact scope was checked, the same action retried and accepted. Automatic review exists despite filesystem permissions. Separate GitHub push approval remains pending; save-only computer-use scope does not authorize foreground QA.

Next: restore isolated doubled templates from staging binary; Studio-only template selector; shared conveyor/effects if needed; then staged Play/phone/performance/critique gates. Plot geometry and template retirement wait for validated swap. Goal remains active and incomplete. Older sections below are historical checkpoints, superseded by this section.

Updated 6 October 2026. Read PLAN.md, this file, Git status and the connected place before continuing.

## Execution resumed after permission change

Current source checkpoint: WorldEquipment, WorldGeometry, WorldMap and WorldEquipmentDisplay exist on disk and in Studio, with the new GearHallController. The four new specs are installed and the full scratch-clone runner passed **384/384**. RED evidence was 0/3 missing helpers; after implementation 17/3 exposed old geometry Config; the display spec separately failed 0/1 before its implementation, then passed 4/4. Config now uses knockback180, tutorial160, crater floor−44/opening160/centreY5.3, doubled landing dimensions and cardinal effect-free approaches. Mining reach, HP, counts, rates, durations, prices and odds are unchanged. The controller's actual Observe connection was inspected and supports Disconnect.

Studio reopened twice during this work. Current confirmed connection is `d43c85b7-4d75-4eaf-9e8a-d47c28b16436`, place113476105600560, Edit mode; staged art remains1417parts. All12 changed/new module sources were compared with disk in this session; they matched. Native Ctrl+S completed, observed Output **17:37:05.844 Saved new changes in "Craterworks: Meteor Mining" to Roblox.** on6October2026. Save only, no publishing. The save screenshot is not critique evidence. Full GUI manifest verification and local commit follow this checkpoint; staged runtime/phone/performance testing has not run.

Ruling: isolate the world display's Instance lifecycle in Shared.WorldEquipmentDisplay and leave GearHallController as State/Heartbeat wiring — actual EquipmentModels, mount translation, replacement/cleanup and collision budgets can be tested without mocking Knit or changing ScreenGuis — cost if wrong: runtime client QA must still prove connection/wiring and sign readability.

The existing clone runner initially saw pre-sync Config values immediately after disk edits. Readback then showed the new sources present; a guarded synchronization and new scratch clone passed380/380 before the display spec was added. Rojo is asynchronous; compare live Source with disk before running or claiming coverage. Do not duplicate modules when an automatic sync has already created them.

Next: test and implement shared-only Refinery/Upgrade services, remove PlotService/HomeController/plot State, connect world consumers to the Studio root selector, add boundary authority and impact ground-raycast, then staged Play QA. The original map/assets remain untouched, so do not play against the archived world with the new geometry Config. No stage is marked complete until all its runtime contracts are met.

The current environment has full filesystem/network access and no approval reviewer. The latest full redesign brief explicitly requests new world controllers/helpers/specs and runtime plot removal; it supersedes the initial building-only script restriction for this redesign. Resume Stage 2 under that brief, preserving every frozen GUI file and the original active map. The prior blocked audit below remains historical evidence, not a current stop condition. Computer-use scope remains saving only; foreground QA permission has not changed.

Ruling: keep the existing feature branch and scene isolation at Map_Redesign — it preserves the owner's open Studio/source relationship and the brief explicitly requires this staging root — cost if wrong: source/runtime changes remain reversible by checkpoint while original world assets remain archived.

Ruling: update the draft geometry spec's fallback centre from Y2 to Y5.3 before its RED run — the measured lowest meteor bound required Y5.3 and the saved scene/approved plan already use it — cost if wrong: runtime variant QA must reject a mismatched landing height. No acceptance assertion is removed.

## Current resumed-run audit — blocked, not complete

The third resumed goal turn rechecked the full brief, plan, Git, connected Edit place, frozen GUI hashes and all four staging export hashes. See `REQUIREMENTS-AUDIT.md` for the requirement-by-requirement evidence. Saved art checkpoint is `0049b90`; no scene or Source changes were made in this audit.

The same world-code and GitHub-push approvals remained unanswered through the resumed refinery/town polish (`2cc6e5d`), spawn/odds polish (`0049b90`) and this audit. Those first two turns made independent progress; they do not establish completion. The remaining runtime integration requires the rejected Source/ModuleScript actions. Further useful visual review is limited by stalled captures and the unanswered foreground-only computer-use question. The fresh blocked threshold is now satisfied; mark the goal blocked and preserve the full objective.

Authoritative read-only checks: staged map 1,417 anchored parts, zero scripts/meshes/previews; Refinery 145 parts, PrimaryPart Foundation, exactly one UsePoint, SharedRefinery true, no scripts/prompts/Humanoids. Original Map exists and Map_Old does not. Live Core remains 28.349998 studs per axis, Knockback radius 90, Tutorial radius 80; PlotStations and Map.Plots still exist. WorldGeometry, WorldEquipment and WorldMap are absent from Shared, and all three new specs are absent from Studio Tests. PlotService and its RefineryService/UpgradeService consumers still exist on disk.

The first Rust Yard close-view request also stalled and was explicitly cancelled (cell 601), producing no image. No capture/process is being awaited. There are still 13 mixed partial images and zero completed critique rounds. Do not repeat the same stalled requests without a relevant tool-state or permission change. Do not use save-only computer-use permission for screenshot focus/QA.

All 39 frozen GUI hashes were freshly checked: only the separately approved TutorialController world lookup differs; the panel/guide suffix still matches `01424D468C83D06980BD5B9FF751EDEB3407834BD973BE9E76536C3DAF05CF73`. All four binary byte counts and SHA256 values match the staging manifest. Latest place-save evidence remains 08:29:19.492 on 6 October; no publish, push, swap, old-map deletion or new runtime/profile test occurred.

## Checklist

- [x] Read the full pasted objective and inspect current Git/open place.
- [x] Preserve owner `docs/ff.md`; baseline HEAD9e66f0a.
- [x] Measure Edit geometry/meteor contracts and runtime render/frame baseline.
- [x] Full baseline runner360passed/0failed.
- [x] Record39frozen GUI file hashes.
- [x] Archive four existing repository exports with identicalSHA256.
- [x] Capture fresh actualStudio Map/Terrain/ServerAssets/Lighting binary buffers and rollback clones.
- [x] Owner approved TutorialController worldlookup only; panelremainsfrozen.
- [x] Write and self-review/approve PLAN.md withcoordinates, style,2×math,budgets,contracts,QA,rollback.
- [x] Write layout.svg; correct northern fields to clear maximum FX footprint.
- [x] Persist four freshStudio binary snapshots; verify transfer bytes, binary headers, SHA256 and engine deserialize roundtrip.
- [x] Commit protectedbaseline checkpoint c2bb2c1; owner confirmed Ctrl+S save.
- [ ] Push checkpoint; automatic approval review rejected twice, explicit payload/destination approval pending.
- [ ] Stage2 geometry/equipment specsRED→GREEN; shared-onlyservices andscaledtemplates.
- [ ] Stage3 complete Map_Redesign build andstaticQA.
- [x] Build isolated scene art for all zones;1417authoredparts,84Editroutes successful, exported/hash-verified checkpoint. Runtime features and visual QA still pending.
- [x] Commit staged geometry checkpoint a31aeb1 and save the current Edit place through File > Save to Roblox; fresh Output confirmed at00:29:55.808 on6October. No publishing.
- [x] Prepare inactive daylight LightingProfile; verify15liveproperties unchanged; regenerate four staging exports; save confirmed at00:42:40.976. Visual QA remains pending.
- [ ] Stage4 stagedPlay/gameplay/phone/path/performanceQA.
- [ ] Stage5 minimum3critique/fix rounds; allcategories4+tworoundsrunning.
- [ ] Stage6 controlledswap, post-swapQA, deleteMap_Old onlyaftergreen.
- [ ] Stage7 save/finalfourexports/README/tools/REPORT/finalcommitpush/completionaudit.

## Spawn polish checkpoint — 08:29 save

The previous goal turn made concrete progress (saved refinery/town repairs and native images). This continuation re-read the full objective/plan, current Git and Studio. World-code/push/foreground permissions remain pending; no required answer has arrived and no rejected action was retried.

SpawnPolish.luau adds47anchored, noncolliding/nonquerying decorative parts: pad frames,30oversized studs, floor/sign trim and a bevelled meteor crest. Its measured bounds stay inside X−68..28/Z−499..−426; all six spawn transforms and disabled states are unchanged. A second run held totalparts1417and all spawn CFrames equal. The crest was recoloured orange after a real image showed its grey body blending into the wall; the final colour still needs visual review.

Native capture intermittently recovered after saving. Five additional views were saved, plus the final odds44image: current count13JPEGs. The Trading Post camera at(110,24,2600) was inside Gear Hall and is unusable; a corrected camera(70,24,2600) gives a clear booth view. Gear boards and side-by-side hatchery eggs are visible. One Meteor Egg board initially rendered blank despite enabled/visible text; a later saved image shows both text blocks. Odds type increased28→44 with unchanged Config text. Engine bounds496×396/485×352 fit586.56×443.52. Phone readability and full daylight coverage remain unverified; zero completed critique rounds.

StaticQA passed84Editpaths/sixforecourtprobes,74jumpwaypoints pending real walking. Current1417authoredparts,145Refineryparts,8lights,0scripts/meshes/unanchoredparts, no previews. OriginalMap2043/liveAssets/Terrain/Lighting unchanged. Latest save **08:29:19.492** on6October2026. Map export85876bytes/SHA6d28ccf9656faa1a41ad685e1fd255f824434c8ba046230dfab7092b4b5f706e; other three staging binaries unchanged. No publishing.

Capture handles574,583and587were cancelled after stalls, including a no-camera-override diagnostic. No live capture/process is being awaited. Do not repeatedly restart the same request. The root cause is unproven; foreground-only computer use remains a pending question, separate from the existing save permission.

## Latest resumed checkpoint — 07:58 cleanup save

A new Studio connection (`855dc0ff-1333-4ce9-bced-616b9099ef09`) confirmed the previous saved map persisted. Six actual native JPEGs were captured with temporary daylight lighting; their partial review is in `critique/round-1/REVIEW.md`. This is zero complete rounds: Trading Post is obscured, several zones are missing and full daylight after-fix images are unavailable. Rebirth capture failed; the after-fix refinery request stalled and was terminated. No capture job remains live. One cropped original-lighting refinery after-fix image then succeeded immediately after saving brought Studio forward, but the next daylight batch stalled and was cancelled(cell561). Previews were restored/removed again. Foreground-only computer-use permission for MCP screenshots is now pending.

The first repairs now exist in the saved staged scene: furnace mouth/exposed conveyor, lower current-equipment boards, narrower tier cards, sign canvases matching physical faces, two fill lights, and a128×72Hatchery with side-by-side eggs/Config odds. Current totals are1370authoredparts/145Refineryparts,8lights,0scripts/meshes/unanchoredparts. OriginalMap2043parts and liveAssets/Terrain/Lighting remain unchanged.

A separate clearance assertion caught the conveyor front atZ−346.66064453125. Its rotated bounding box had been treated as axis-aligned. World-space part corners now determine placement: conveyorZ−348.4, entire visibleRefinerymaxZ−348; assertion passes. Hatchery-to-spawn-spinegap14. Final StaticQA passed84paths/sixfrontprobes;74jumpwaypoints and realwalking remain pending. No assertion was relaxed.

Before saving, all15Lightingproperties and the actual6originaleffects/1TerrainClouds were restored; meteor preview detached and317-part equipment preview destroyed. File > Save to Roblox completed at **07:50:01.309** on6October2026. No publishing. Four staging exports verified:Map84811,Assets73990,Refinery23070,Lighting4703bytes. See manifest/geometry-checkpoint.json. All39frozenGUIhashes were rechecked; onlyapprovedTutoriallookup differs and its panel suffix remains unchanged.

Polish checkpoint2cc6e5d is committed locally. World-code and push approvals are still pending; no new Source, runtime/profile fixtures or push occurred. The previous blocked audit below is historical. This resumed run made independent progress and starts a fresh blocked audit. Next permitted work is art/visual review if native capture recovers; Stage2runtime integration/newtests and finalswap remain gated.

## Next action

Stage2 remains gated by the pending world-code authorization. Once it arrives, synchronize the three draft specs, obtain actual RED results, implement helpers/controllers/services and update dimensions. Push local checkpoints only after the explicit GitHub payload/destination approval arrives. Staged art has now been built and exported; do not rebuild it from scratch.

### Historical blocked audit — previous run

The same world-code authorization and backup-push rejection remain unresolved across three consecutive goal turns: `01a10d5c-e5cb-7c72-b02d-9b40343b9abb` (baseline/tutorial), `01a10d92-afc3-7e71-b947-2f3e1339e361` (scene geometry/save), and `01a10dfb-6801-7be2-946d-dc2dfbe24390` (lighting). Authoritative recent turn records confirm the pending questions and automatic approval rejections. Independent scene/data work is now built, exported, saved and committed (`5a8f36d`); no runtime integration, full QA or swap can proceed within the currently approved boundary. The screenshot tool also produced no image on three attempts, with all request handles explicitly terminated; native computer use is allowed only for saving. No process is being awaited. Set the goal blocked after this checkpoint; completion remains unproven. Resume only when the world-code/push authorization or relevant external tool state changes, preserving the full objective.

Continuation ruling: independent staged scene geometry can proceed while the required world-code and push approvals are pending. Authoring commands create anchored art/collision parts, not Script or ModuleScript instances; they do not work around the rejected script edits. Build only owned groups under Map_Redesign at Z+3000. Runtime integration, new scripts, tests and final swap remain gated. Cost if wrong: rerun the owned geometry stages after Config.World becomes available; retain explicit matching dimensions in static checks.

Three new specs exist on disk: WorldGeometry.spec, WorldEquipment.spec, WorldMap.spec. Rojo is not syncing them into the open place. Automatic approval review rejected the explicit ModuleScript synchronization because it still applies the original building-only no-scripts instruction. A world-code/test authorization question is pending. **No RED test result exists yet. Do not claim the new specs ran.** The approved TutorialController panel suffix hash is recorded in tutorial-panel-baseline.json before any edit.

The separately approved TutorialController Deposit/Collect lookup is now changed on disk and in the saved place to TownSquare.Refinery.UsePoint. Exactly one UsePoint exists at that path. Disk panel/guide suffix remains byte-for-byte identical to its baseline hash. Studio's ScriptEditorService normalized CRLF to LF; a readback proved the entire suffix equal after newline normalization. No panel logic, layout, assets or visuals changed. The initial strict Studio byte comparison failed only on CRLF normalization (first difference was a line terminator); it was investigated, not treated as a gameplay test failure. The fresh6October save includes this edit.

## Evidence and decisions

### Earlier staged geometry checkpoint — before the latest polish

- `Workspace.Map_Redesign` is built at offset(0,0,3000); original Map still2043parts, no swap, Terrain/Lighting/liveAssets unchanged. Six staged spawn pads are disabled until staged runtime selection is ready, preventing accidental spawning into an unconnected town.
- Authored geometry1351parts,0MeshParts,0Scripts,0unanchoredparts. Refinery134parts,PrimaryPartFoundation,oneUsePoint,SharedRefinerytrue,0prompts/scripts/Humanoids. Visible footprintnearest348; UsePoint343; final refinery pivot(0,0.8,-380), stagedpivot(0,0.8,2620). Hopper/Conveyor/Refinery art reused from pristinePlotStations, stripped of scripts/prompts/liveBillboardGuis.
- Gear Hall has16Config-generatedtier cards and2current stands, but the18localmodels/liveSurfaceGui states are not connected yet. Hatchery2eggs/2Config-derivedoddsboards; museum6exhibits/12minerals; rebirthmonument; TradingPost.SellPoint+prompt; fourfields48directmineable roots with14-studaisles;24blocktrees;6enabledlights(shadowsfalse),1emitter at4/s,maximum16steadyparticles.
- Ground CSG collision closed the opening even withPreciseConvexDecomposition. Keep it visual-only;134primitivecollision proxies and40ground-onlyrays now leave the opening clear. FloorY-44, openingR160,4ramps24wide.
- Mining access236parts:4terraces,96ascentsegments,18wide, maximumslope16.890332°. Core+NodePieces are2x only in unparented scaled clones; originalCore remains28.349998. Seededpreview504parts/36nodes,Core56.699997,box99.553085×97.465607×100.099541. Preview is now detached and retained in `_G.MapRedesignGeometryPreview`; excluded from exports/authorbudgets. It must remain detached before gameplayQA/finalSave.
- Ruling: raise MeteorSpawn fromY2 toY5.3.3,456slot/piece/yaw combinations had minY-47.247726/maxY52.642014 atY2; newheightkeeps the worst bound above floor-44. Seededpreviewmin/maxY-41.857776/55.607831. Actualvariants, groundcontact and gameplay remain unverified.
- Candidate reach sampled2330positions: all36seedednodeswithinBasicbounding-box reach12 (worst3.559263), exposedcoreminimum0.428459. These are not walking/aiming results.
- StaticQA:84/84Editpaths successful from6spawns to3servicepoints, hatchery/rebirth/museum,4fieldentrances and4craterlandings;62jumpwaypoints must receive real walking/jump checks. Sixcharacter-sizedforecourtprobes clear. Initialprobe falselyhitTownAvenue becauseitassumedY0; corrected to raycast actualgroundheight. No assertions weakened.
- Fresh existingrunner360passed/0failed.39frozenhashes checked; onlyapprovedTutorialControllerlookup differs. Its panel/guide suffixSHA256 remains01424D468C83D06980BD5B9FF751EDEB3407834BD973BE9E76536C3DAF05CF73.
- Exports in`assets/staging/map-redesign/`:Map_Redesign76970bytes/1351parts;ServerAssets_Redesign73990bytes/119parts;Refinery_Redesign21615bytes/134parts;Lighting_Redesign4703bytes/0parts. Engine deserialize, rootattributes, canonicalbase64, binaryheader, diskbytes andSHA256 verified inmanifest.json. Primary finalexports remain unchanged.
- Relative display offsets now survive final map translation:18clone-and-translation checks passed. Template audit passed for113parts,36attachments,1light and1emitter; noSpecialMeshes/nonzeroPivotOffsets, particle rates/lifetimes unchanged. Runtime impact-clear teleport must raycast destination ground height; the old deep-bowlY+4 can strand a player below outer ground. Source fix remains pending world-code permission.
- Screenshot requests yielded no image and were terminated. No critique rounds/scores claimed. Staged art and the tutorial lookup are now saved, confirmed by fresh Studio Output at00:29:55.808. Computer-use save observations do not count as visual critique rounds.
- The daylight profile is inactive under Map_Redesign.Atmosphere:ClockTime14/Brightness2.5, density0.17, modestbloom, depthoff, sixeffects plusCloudSettingsdata.15liveLightingproperties stillmatch thepristinebaseline. Initially cloning Clouds into Workspace produced two Edit warnings at00:35:02; corrected by storing only data. Fresh validation found exactlyoneClouds, directlyunderoriginalTerrain, and zero in the staged map. The profile is saved; freshOutputconfirmed at00:42:40.976. Do not claim its look is verified.
- CaptureStagedTownGeometry_20261006 remained live without an image, was polled repeatedly and explicitly terminated(cell488). No capture job remains live and no critique evidence was produced. Do not keep retrying the same capture without a changed tool state/capability.

- Studio ID at discovery:b1f0a7a1-146e-4d11-9832-2a8e2cc1c226, place113476105600560. Last observedEdit after stopping initialPlay.
- Initial existingPlay was sampledread-only; noprofileQA orDataStoremutationsperformed. EditMap2043parts; runtimesample2543parts.
- ExistingRender view excludingShadows467188triangles/491draws; p50=27.6725ms,p95=29.1626ms,max=29.5884ms,72frames.
- Fresharchivebuffers:Map185912,Terrain1073893,ServerAssets96061,Lighting4932bytes. `_G.MapRedesignBackup` retains unparented actualEdit clones. TerrainVoxelcorner(-256,-64,-256); lightingFolderstorespropertiesattrs/effects/clouds.
- Screenshotrequest BeforeRedesignOverview didnotcomplete; itsfunctions cell375 was terminated afterrepeatedlive waits. No screenshot evidenceclaimed. CheckStudio statebefore retryingcapture; do not restartsceneauthoringbecauseof observationfailure.
- Ruling: preserve current checkout/branch and isolate world in Map_Redesign as requested; source freeze manifest protects owner UI. Current staging offset is Z+3000; the earlier +1600 proposal is superseded.
- Ruling: ownerexplicitlyapproved TutorialControllerworldtargets→sharedUsePoint only. FrozenRefineryController's dormantPlotIdlistenerstays andisreported; noUIexceptioninferred.
- The prior Edit API save failed as server-only. The owner subsequently confirmed “yes saved” and permitted computer use for saving only. The separate computer-use skill's @oai/sky native control works, despite disabled native APIs in CUA. File > Save to Roblox started at00:29:53.955 and completed at00:29:55.808 on6October2026. The place remains in Edit; nothing was published. Other computer use remains prohibited.
- Save persistence applies to parented staged art and the approved tutorial edit. Unparented scaled Assets and the detached preview are memory-only; their checkpoint export remains the restore source. Do not infer a completed runtime integration or final swap from the save.
- Automatic approval review rejected git push twice despite the active brief's checkpoint instruction; it requires explicit approval to disclose these assets to https://github.com/FullerPing/MeteorShift branch job-for-tomorrow. A concrete question is pending; no workaround attempted.
- Ruling: full rollback must use TerrainComplete captured from Terrain.MaxExtents, not the initial bounded Terrain snapshot — rays proved terrain at Z1100 outside the first capture; the full capture includes ~4,896,366 occupied cells, corner(-32000,-32000,-32000),1,303,071binarybytes — cost if wrong: full terrain restore requires exact stored corner.
- TerrainComplete transfer is complete and verified:1,303,071bytes, SHA2562c14d72a0caedc5ff7dd2554bf36c7eea18c77d81ef7e5c00c7f82ad0639ea76. All five fresh binary files are recorded in manifest.json; engine roundtrip and filesystem hashes are verified.
- Ruling: move staged-map offset to (0,0,3000) — the +1600 north edge overlapped old terrain; nine rays across the +3000 footprint found no terrain — cost if wrong: staticQA must catch any unsampled overlap before Play. Final zone coordinates are unchanged.
- Read-only EquipmentModels measurement:16-tier wall299parts; two current displays add at most71, worst total370parts versus650limit. No equipment source or GUI was changed.
- Ruling: move Rust/Frost field centres from (±270,235) to (±275,270) — their old footprints overlapped the310-stud effect extent; new nearest corner sqrt(225²+224²)=317.49 — cost if wrong: revise connector placement before build.
- Ruling: keep the owner-requested PLAN.md/PROGRESS.md as the persistent execution ledger rather than skill scratch scripts — native MCP calls are not shell test commands and the requested checklist is authoritative — cost if wrong: less automatic bookkeeping, offset by explicit evidence per stage.

## Requirements still unverified

Scene art, an inactive lighting profile and isolated2x templates exist. Runtime world controller/helpers/tests/services, authoritative kill plane, plot removal from live code/assets, newgeometryConfig/FX, lightingpreview/QA, pre-swap/post-swapPlayQA, walking/aiming/exploitproof, phones, stressperformance, critique rounds, finalfourcontractexports and push remain incomplete. Later runtime/final edits will need another save. No swap/deleteold/publish. Do not markgoalcomplete from the geometry checkpoint.

Cleanup save completed at07:58:13.871 after restoring/removing previews again. Native original-lighting refinery image is recorded separately; foreground-only computer-use authorization remains pending. The saved1370-part map and verified binary hashes are unchanged by these temporary reviews.
