# Map redesign report — incomplete checkpoint

Updated 6 October 2026. This records staged geometry, not a completed redesign.

The original town remains active. Workspace.Map_Redesign contains the new world at offset (0, 0, 3000). No swap, old-map deletion or publishing has occurred. The original Map still has 2,043 parts; live Assets, Terrain and Lighting remain unchanged.

## Built and measured

| Item | Current evidence |
|---|---|
| Authored staged map | 1,351 parts; no MeshParts or Scripts; all anchored |
| Refinery | 134 parts; PrimaryPart Foundation; one UsePoint; SharedRefinery true; no Scripts, prompts or Humanoids |
| Refinery pivot | Staged (0, 0.800000012, 2620); intended final (0, 0.800000012, -380) |
| Horizontal crater distances | Pivot 380; nearest visible footprint 348; UsePoint 343 |
| Reused refinery art | Hopper, Conveyor and Refinery from pristine PlotStations; scripts, prompts and live BillboardGuis stripped |
| Crater | Floor Y -44, radius 90; opening radius 160; four 24-stud approach ramps; 40 ground-only rays clear |
| Mining access | 236 parts; four 18-stud terraces; 96-segment ascent; maximum slope 16.890332°; top Y 60 |
| Isolated meteor | Core 56.699997 per axis; 36 slots; NodePieces 2×; seeded preview 504 parts, 99.553085 × 97.465607 × 100.099541 |
| Meteor landing | Spawn Y 5.3; 3,456 slot/piece/yaw bounds measured; seeded vertical bounds -41.857776 to 55.607831 |
| Gear Hall | 16 Config-derived tier cards and two current-stand mounts; live models/controller pending |
| Hatchery and museum | Two decorative eggs with Config odds boards; six exhibits showing all 12 minerals |
| Debris | Four yards, 48 mineable roots, 14-stud aisles; nearest pad distance 317.491732 |
| Spawn and boundary | Six isolated staging pads; 80-stud sealed wall geometry; kill-plane marker at Y -70, authority pending |
| Decoration | 24 trees; six lights with shadows off; one emitter at 4/s, at most 16 steady particles |

The 504-part geometry preview is now detached and retained only in memory. Checkpoint exports exclude it. Staging spawn pads remain disabled until the staged runtime is connected.

## Checks and limits

The existing Edit runner passed 360/360. The three new world specs have not run because synchronization was rejected; this result does not include them. Of 39 frozen GUI file hashes, only the approved TutorialController world lookup differs. Its panel and guide suffix hash is unchanged.

All 84 Edit pathfinding routes succeeded from six staging pads to service points, zone entrances and crater landings. Their 62 jump waypoints still need real walking and jump checks. Six character-sized probes found no blocked refinery forecourt positions.

Among 2,330 candidate standing positions, all 36 seeded crust nodes have positions within the Basic Pickaxe's 12-stud bounding-box range. The worst minimum distance was 3.559263. This does not prove collision-free standing, aiming or reach across live variants.

The template audit verified 113 parts, 36 attachments, one light and one emitter against pristine data: doubled sizes, local positions, attachment offsets, light range and particle dimensions/speeds/acceleration; unchanged particle rates and lifetimes. There are no SpecialMeshes or nonzero pivot offsets in those trees. All 18 Gear Hall mount offsets passed a clone-and-translation check.

Large concave CSG collision closed the crater opening. The union is now visual-only; 134 invisible primitive proxies provide ground collision. Initial forecourt probes assumed Y 0 and falsely intersected the raised avenue; they now use raycast surface heights. Assertions were preserved.

Screenshot requests produced no image before termination. No screenshot critique scores or completed rounds are claimed. The existing impact-clear teleport also needs a destination-ground raycast: retaining the player's deep-bowl Y plus four studs could strand them beneath outer ground. That source fix remains pending authorization.

## Checkpoint and remaining work

Three staging exports passed engine deserialize, byte count, canonical base64, binary header, disk readback and SHA256 checks. See assets/staging/map-redesign/manifest.json. Map_Redesign is 72,794 bytes; ServerAssets_Redesign is 73,990 bytes; Refinery_Redesign is 21,615 bytes. Final contract exports remain untouched. The baseline place save is confirmed; later staged edits still need a confirmed save.

Remaining work: implement and test world helpers/controllers/services, connect equipment and boundary authority, update geometry Config and FX/sound/shake, remove plot runtime, prepare lighting, complete staged Play/phone/variant/gameplay/rejoin/exploit/performance QA, and perform at least three screenshot critique rounds. Only then swap, repeat QA, delete the old map, save and export the final four assets.

Automatic approval review rejected creating world test ModuleScripts under the initial no-scripts rule, and rejected pushing backups to the configured GitHub destination. Explicit world-code and push questions remain pending. No workaround was attempted. The owner permits computer use only for saving; native app control is unavailable in the exposed tool.

## Assumptions and GUI follow-ups

- Equipment estimates: 299 parts for 16 tier models plus at most 71 for the current pair, against a 650-part limit. Runtime and rendering cost remain unmeasured.
- Rebirth and Index displays are decorative; existing HUD actions remain available.
- Preserve the frozen RefineryController's dormant PlotId listener and report its status after plot removal. Frozen HUD bindings to Workspace.Map require post-swap verification.
- Economy, mineral odds, monetization, mining reach and HP are unchanged.

## What to inspect first

Inspect the staged town near Z 2660: orange Refinery in the centre, violet Hatchery to the west and blue Gear Hall to the east. Check the crater ascent around Z 3000 next, then west Rebirth, east Museum and the four debris yards. Keep staging pads disabled until runtime selection is connected.
