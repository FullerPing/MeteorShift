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
- [ ] Commit/push protectedbaseline checkpoint; recordsave limitation/evidence.
- [ ] Stage2 geometry/equipment specsRED→GREEN; shared-onlyservices andscaledtemplates.
- [ ] Stage3 complete Map_Redesign build andstaticQA.
- [ ] Stage4 stagedPlay/gameplay/phone/path/performanceQA.
- [ ] Stage5 minimum3critique/fix rounds; allcategories4+tworoundsrunning.
- [ ] Stage6 controlledswap, post-swapQA, deleteMap_Old onlyaftergreen.
- [ ] Stage7 save/finalfourexports/README/tools/REPORT/finalcommitpush/completionaudit.

## Next action

Commit/push the protected baseline checkpoint after rerunning the baseline runner and frozen-file checks. All four fresh snapshots are on disk in `assets/archive/before-redesign/studio-snapshot/`; their manifest records bytes and SHA256. Then start tests-first geometry/equipment work.

## Evidence and decisions

- Studio ID at discovery:b1f0a7a1-146e-4d11-9832-2a8e2cc1c226, place113476105600560. Last observedEdit after stopping initialPlay.
- Initial existingPlay was sampledread-only; noprofileQA orDataStoremutationsperformed. EditMap2043parts; runtimesample2543parts.
- ExistingRender view excludingShadows467188triangles/491draws; p50=27.6725ms,p95=29.1626ms,max=29.5884ms,72frames.
- Fresharchivebuffers:Map185912,Terrain1073893,ServerAssets96061,Lighting4932bytes. `_G.MapRedesignBackup` retains unparented actualEdit clones. TerrainVoxelcorner(-256,-64,-256); lightingFolderstorespropertiesattrs/effects/clouds.
- Screenshotrequest BeforeRedesignOverview didnotcomplete; itsfunctions cell375 was terminated afterrepeatedlive waits. No screenshot evidenceclaimed. CheckStudio statebefore retryingcapture; do not restartsceneauthoringbecauseof observationfailure.
- Ruling: preservecurrentcheckout/branch andisolateworldinMap_Redesign asrequested; sourcefreezemanifestprotectsownerUI. NewsceneatZ+1600 untilswap.
- Ruling: ownerexplicitlyapproved TutorialControllerworldtargets→sharedUsePoint only. FrozenRefineryController's dormantPlotIdlistenerstays andisreported; noUIexceptioninferred.
- Save remainsunproven. PriorEditAPIrejectedserver-onlysave; noPlay-snapshot workaround, computeruse orpublishing.
- Ruling: move Rust/Frost field centres from (±270,235) to (±275,270) — their old footprints overlapped the310-stud effect extent; new nearest corner sqrt(225²+224²)=317.49 — cost if wrong: revise connector placement before build.
- Ruling: keep the owner-requested PLAN.md/PROGRESS.md as the persistent execution ledger rather than skill scratch scripts — native MCP calls are not shell test commands and the requested checklist is authoritative — cost if wrong: less automatic bookkeeping, offset by explicit evidence per stage.

## Requirements still unverified

No newmap,2×templates orworldequipmentcontrollerbuilt yet. No pre-swap/post-swapPlayQA, critique rounds, path/reach/exploitproof, stressperformance, newplaceSave, finalexportsorredesignpush. Do not markgoalcomplete fromthe baseline.
