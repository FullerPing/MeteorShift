# Map redesign progress

Updated 5 October 2026. Read PLAN.md, this file, Git status and the connected place before continuing.

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
- [ ] Stage4 stagedPlay/gameplay/phone/path/performanceQA.
- [ ] Stage5 minimum3critique/fix rounds; allcategories4+tworoundsrunning.
- [ ] Stage6 controlledswap, post-swapQA, deleteMap_Old onlyaftergreen.
- [ ] Stage7 save/finalfourexports/README/tools/REPORT/finalcommitpush/completionaudit.

## Next action

Stage2: write and run failing geometry/equipment/map-selector specs, then implement the helpers. Push c2bb2c1 when the pending explicit GitHub payload/destination approval arrives. Four snapshots are verified on disk. Baseline runner360/360 and39frozen hashes passed after transfer.

Three new specs exist on disk: WorldGeometry.spec, WorldEquipment.spec, WorldMap.spec. Rojo is not syncing them into the open place. Automatic approval review rejected the explicit ModuleScript synchronization because it still applies the original building-only no-scripts instruction. A world-code/test authorization question is pending. **No RED test result exists yet. Do not claim the new specs ran.** The approved TutorialController panel suffix hash is recorded in tutorial-panel-baseline.json before any edit.

The separately approved TutorialController Deposit/Collect lookup is now changed on disk and in Studio Edit to TownSquare.Refinery.UsePoint. Exactly one UsePoint exists at that path. Disk panel/guide suffix remains byte-for-byte identical to its baseline hash. Studio's ScriptEditorService normalized CRLF to LF; a readback proved the entire suffix equal after newline normalization. No panel logic, layout, assets or visuals changed. The initial strict Studio byte comparison failed only on CRLF normalization (first difference was a line terminator); it was investigated, not treated as a gameplay test failure. This edit happened after the owner's confirmed save and requires a later save.

## Evidence and decisions

- Studio ID at discovery:b1f0a7a1-146e-4d11-9832-2a8e2cc1c226, place113476105600560. Last observedEdit after stopping initialPlay.
- Initial existingPlay was sampledread-only; noprofileQA orDataStoremutationsperformed. EditMap2043parts; runtimesample2543parts.
- ExistingRender view excludingShadows467188triangles/491draws; p50=27.6725ms,p95=29.1626ms,max=29.5884ms,72frames.
- Fresharchivebuffers:Map185912,Terrain1073893,ServerAssets96061,Lighting4932bytes. `_G.MapRedesignBackup` retains unparented actualEdit clones. TerrainVoxelcorner(-256,-64,-256); lightingFolderstorespropertiesattrs/effects/clouds.
- Screenshotrequest BeforeRedesignOverview didnotcomplete; itsfunctions cell375 was terminated afterrepeatedlive waits. No screenshot evidenceclaimed. CheckStudio statebefore retryingcapture; do not restartsceneauthoringbecauseof observationfailure.
- Ruling: preservecurrentcheckout/branch andisolateworldinMap_Redesign asrequested; sourcefreezemanifestprotectsownerUI. NewsceneatZ+1600 untilswap.
- Ruling: ownerexplicitlyapproved TutorialControllerworldtargets→sharedUsePoint only. FrozenRefineryController's dormantPlotIdlistenerstays andisreported; noUIexceptioninferred.
- Save remainsunproven. PriorEditAPIrejectedserver-onlysave; noPlay-snapshot workaround, computeruse orpublishing.
- Owner subsequently confirmed “yes saved” for this checkpoint and permits computer use for saving only. Other computer use remains prohibited.
- Automatic approval review rejected git push twice despite the active brief's checkpoint instruction; it requires explicit approval to disclose these assets to https://github.com/FullerPing/MeteorShift branch job-for-tomorrow. A concrete question is pending; no workaround attempted.
- Ruling: full rollback must use TerrainComplete captured from Terrain.MaxExtents, not the initial bounded Terrain snapshot — rays proved terrain at Z1100 outside the first capture; the full capture includes ~4,896,366 occupied cells, corner(-32000,-32000,-32000),1,303,071binarybytes — cost if wrong: full terrain restore requires exact stored corner.
- TerrainComplete transfer is complete and verified:1,303,071bytes, SHA2562c14d72a0caedc5ff7dd2554bf36c7eea18c77d81ef7e5c00c7f82ad0639ea76. All five fresh binary files are recorded in manifest.json; engine roundtrip and filesystem hashes are verified.
- Ruling: move staged-map offset to (0,0,3000) — the +1600 north edge overlapped old terrain; nine rays across the +3000 footprint found no terrain — cost if wrong: staticQA must catch any unsampled overlap before Play. Final zone coordinates are unchanged.
- Read-only EquipmentModels measurement:16-tier wall299parts; two current displays add at most71, worst total370parts versus650limit. No equipment source or GUI was changed.
- Ruling: move Rust/Frost field centres from (±270,235) to (±275,270) — their old footprints overlapped the310-stud effect extent; new nearest corner sqrt(225²+224²)=317.49 — cost if wrong: revise connector placement before build.
- Ruling: keep the owner-requested PLAN.md/PROGRESS.md as the persistent execution ledger rather than skill scratch scripts — native MCP calls are not shell test commands and the requested checklist is authoritative — cost if wrong: less automatic bookkeeping, offset by explicit evidence per stage.

## Requirements still unverified

No newmap,2×templates orworldequipmentcontrollerbuilt yet. No pre-swap/post-swapPlayQA, critique rounds, path/reach/exploitproof, stressperformance, newplaceSave, finalexportsorredesignpush. Do not markgoalcomplete fromthe baseline.
