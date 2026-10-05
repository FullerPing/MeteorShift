# Map redesign progress

Updated 6 October 2026. Read PLAN.md, this file, Git status and the connected place before continuing.

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
- [x] Build isolated scene art for all zones;1351authoredparts,84Editroutes successful, exported/hash-verified checkpoint. Runtime features and visual QA still pending.
- [x] Commit staged geometry checkpoint a31aeb1 and save the current Edit place through File > Save to Roblox; fresh Output confirmed at00:29:55.808 on6October. No publishing.
- [x] Prepare inactive daylight LightingProfile; verify15liveproperties unchanged; regenerate four staging exports; save confirmed at00:42:40.976. Visual QA remains pending.
- [ ] Stage4 stagedPlay/gameplay/phone/path/performanceQA.
- [ ] Stage5 minimum3critique/fix rounds; allcategories4+tworoundsrunning.
- [ ] Stage6 controlledswap, post-swapQA, deleteMap_Old onlyaftergreen.
- [ ] Stage7 save/finalfourexports/README/tools/REPORT/finalcommitpush/completionaudit.

## Next action

Stage2 remains gated by the pending world-code authorization. Once it arrives, synchronize the three draft specs, obtain actual RED results, implement helpers/controllers/services and update dimensions. Push local checkpoints only after the explicit GitHub payload/destination approval arrives. Staged art has now been built and exported; do not rebuild it from scratch.

### Blocked audit — threshold met

The same world-code authorization and backup-push rejection remain unresolved across three consecutive goal turns: `01a10d5c-e5cb-7c72-b02d-9b40343b9abb` (baseline/tutorial), `01a10d92-afc3-7e71-b947-2f3e1339e361` (scene geometry/save), and `01a10dfb-6801-7be2-946d-dc2dfbe24390` (lighting). Authoritative recent turn records confirm the pending questions and automatic approval rejections. Independent scene/data work is now built, exported, saved and committed (`5a8f36d`); no runtime integration, full QA or swap can proceed within the currently approved boundary. The screenshot tool also produced no image on three attempts, with all request handles explicitly terminated; native computer use is allowed only for saving. No process is being awaited. Set the goal blocked after this checkpoint; completion remains unproven. Resume only when the world-code/push authorization or relevant external tool state changes, preserving the full objective.

Continuation ruling: independent staged scene geometry can proceed while the required world-code and push approvals are pending. Authoring commands create anchored art/collision parts, not Script or ModuleScript instances; they do not work around the rejected script edits. Build only owned groups under Map_Redesign at Z+3000. Runtime integration, new scripts, tests and final swap remain gated. Cost if wrong: rerun the owned geometry stages after Config.World becomes available; retain explicit matching dimensions in static checks.

Three new specs exist on disk: WorldGeometry.spec, WorldEquipment.spec, WorldMap.spec. Rojo is not syncing them into the open place. Automatic approval review rejected the explicit ModuleScript synchronization because it still applies the original building-only no-scripts instruction. A world-code/test authorization question is pending. **No RED test result exists yet. Do not claim the new specs ran.** The approved TutorialController panel suffix hash is recorded in tutorial-panel-baseline.json before any edit.

The separately approved TutorialController Deposit/Collect lookup is now changed on disk and in the saved place to TownSquare.Refinery.UsePoint. Exactly one UsePoint exists at that path. Disk panel/guide suffix remains byte-for-byte identical to its baseline hash. Studio's ScriptEditorService normalized CRLF to LF; a readback proved the entire suffix equal after newline normalization. No panel logic, layout, assets or visuals changed. The initial strict Studio byte comparison failed only on CRLF normalization (first difference was a line terminator); it was investigated, not treated as a gameplay test failure. The fresh6October save includes this edit.

## Evidence and decisions

### Current staged geometry checkpoint

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
