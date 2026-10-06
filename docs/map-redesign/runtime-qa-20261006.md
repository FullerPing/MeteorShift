# Staged runtime QA — 6 October 2026

This is partial evidence for Stage 4, not a completed QA gate. Original Map, Assets, Terrain and Lighting have not been swapped. Tests ran in Studio place 113476105600560, connection d43c85b7-4d75-4eaf-9e8a-d47c28b16436, using Map_Redesign at Z+3000 and DevMemoryStore. No saved profile-grant Script was created.

## Failures found and repairs

- Run 1: MeteorService still needed ServerStorage for DevMeteorType. Restored its import. Initial Gear Hall mounts were incomplete during streaming; added readiness validation and deferred streaming reconciliation. The previous one-time mount could leave a partial display. RED: display spec 4 passed / 2 failed; GREEN full suite 399 / 0.
- The world crit board omitted equipped pet crit. Added the finite pet bonus with the same clamp as gameplay. RED 8 / 1, GREEN full suite 400 / 0. Removed remaining non-frozen PetVisual and LandingFX plot branches.
- Run 2: a character held at town position (0,-12,2657) survived the old rectangular kill check. Added the analytic bowl/town surface threshold, preserving a four-stud join margin. RED boundary 4 / 2. Run 3 repeated the real probe: health 0 and character dead. Legitimate full crater navigation remains pending.
- Scaled spectacle geometry now comes from MeteorVisualGeometry: linear dimensions/speeds, impact/core shake falloff and meteor sound reach doubled. Counts, lifetimes, timings, gameplay impulses and settings gates remain unchanged. Native Fire's size cap required one flame emitter instead. RED missing helper 0 / 1; full suite after these changes 411 / 0. Appearance, attenuation and loaded performance remain pending.
- Review found local equipment loss could leave surviving authored mounts with missing displays. The new integrity regression actually failed 6 / 1 before implementation. Final verification is recorded in PROGRESS.md after the fix.

## Run 4 gameplay evidence

- Device simulator: discovered iphone_14, landscape left, requested resolution 844×390, ActualResolution. Client camera reported 750×369. The one successful native MCP image was 844×390; this does not certify the other requested phone sizes.
- All 18 local Gear Hall models appeared (317 parts at Basic), with no server LocalEquipment folder. Current pickaxe rotation changed its look-vector dot to 0.98163855 over 0.5 seconds.
- At root position (0.0311,4.3784,2665.1960), 8.3112 studs from UsePoint, keyboard E opened RefineryMenu and set RefineryOpen. Prompt is UseRefinery, E, zero hold, 14-stud range, enabled; no RefineryService warning.
- Deposit button click moved 20 iron ore from the memory profile into the hopper. The immediate readback showed 19 hopper / 1 bin and Running=true; UI feedback said “Deposited 20 ore.”
- Claim mouse input did not produce a verified claim; that tool request stalled and was cancelled. The normal public Claim request subsequently returned 20, with 20 iron bars and an empty bin. Claim button interaction itself still needs confirmation.
- Actual navigation reached Trading Post (69.5736,4.5304,2574.6990), 8.8429 studs from SellPoint, health 100. After centring the camera with MCP, E triggered SellBars. Server readback: bars empty, barsSold=20, cash=1000. Camera baseline was restored. The first E attempt before centring did not sell.
- A deposit request from 107.7789 studs away returned zero. Because the backpack was empty at this point, this is consistent with the distance gate but is not an independent proof of rejection with stocked ore.
- Existing DevGear changed only this memory-session profile to pickaxe 4 / backpack 6. State immediately replaced the two current models, retained exactly 18 total, displayed Plasma Pick / Cargo Rig (capacity 900), and labelled lower/current/higher tiers UNLOCKED/CURRENT/LOCKED.
- Actual navigation reached the shop at (139.5022,5.3504,2624.8340), 8.9225 studs from ShopPoint, health 100. E set ShopOpen=true. No shop UI code was changed.

## Observation limits and cleanup

The frozen HUD warned at HUDController line 332 while waiting for original Map.Crater.SkyTimer. Staged MeteorService populates the selected map; the frozen HUD still reads original Map. This remains a pre-swap clean-output gap, not a passed check. Telemetry prints and Assistant camera-reset diagnostics were also present. All 39 protected hashes were checked; only the separately approved TutorialController world lookup differs.

One screenshot showed the refinery panel; the next request stalled and was terminated (cell 103). A following mouse request also stalled and was terminated (cell 104). These do not provide additional images or successful input evidence. No capture request remains live.

After run 4, Play was stopped. Edit restoration verified DevWorldMap and DevMemoryStore absent; original spawn enabled; all six staged spawns disabled; simulator default, landscape right, FitToWindow; camera viewport 1352×659. No runtime profile, temporary camera or QA fixture persists into the place save.

Remaining gates: every spawn/interactive route and jump, all 36 live nodes plus core with Basic across Iron/Ice/Crystal, shockwave survival, stocked distant request rejection, Claim button, production upgrades, pets, fresh tutorial, rebirth/rejoin, all phone sizes, event/40-pet performance, complete screenshot critique rounds, controlled swap and repeated QA, final exports and push approval.
