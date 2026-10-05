# Map redesign + 2x meteor: headless worker prompt

You are the engineer who knows MeteorShift (Roblox, Rojo + Luau, Knit, Fusion; the game is now called "Craterworks: Meteor Mining" in Studio) and has full access to Roblox Studio and the repository `FullerPing/MeteorShift`, branch `job-for-tomorrow` only. This is a headless, unattended job. There is no limit on time or tokens. The only thing that matters is that the owner wakes up to a great map. Nobody will answer questions: decide, write the decision down, continue.

## 1. Mission

1. Redesign the entire map for a **simulator / tycoon look**: chunky, bright, saturated, toy-like, readable at a glance, lots of visible **studs** and bevelled blocky props, with clear landmarks and zones. It must feel like a front-page Roblox simulator, not a moody diorama.
2. Make the **meteor at least 2x as big** (every linear dimension x2, so the crater, the nodes, the effects and the surrounding arena all grow with it).
3. Plots are no longer used. Remove them and everything that exists only for them. The shared **Refinery** is the centre of the economy.
4. Add a **live equipment shop**: a physical shop building where players see their own pickaxe and backpack, in their current tier, on display stands that update live as they upgrade, plus a wall that shows every tier and which ones they have unlocked.
5. Keep the game fully working: tutorial, meteor loop, debris, refinery, shop, pets, rebirth.

## 2. Operating mode (read this twice)

You will run for a long time and may be interrupted by rate limits, crashes or restarts. When limits refresh or you are restarted, **start again immediately and continue**. To make that safe:

- Keep two files in `docs/map-redesign/`: `PLAN.md` (the approved plan, never lose it) and `PROGRESS.md` (a checklist of every stage and sub-step with `[ ]` / `[x]`, timestamps, and a "next action" line). Update `PROGRESS.md` after every sub-step and commit it. **On every start, read `PROGRESS.md`, `git status`, `git log -5`, and inspect the open place in Studio, then continue from the first unchecked item.** Never redo a finished stage; verify it still holds, then move on.
- Every stage must be idempotent and re-runnable: name everything stably, build under a dedicated parent, and clean up that parent before rebuilding a half-finished stage.
- **Never build in place on the live `Workspace.Map`.** Build the new world under `Workspace.Map_Redesign` (and terrain edits only after a backup, see below). Only when the whole redesign passes the QA gates do you swap: rename the old model to `Map_Old`, rename the new one to `Map`, re-run QA, and only after a clean re-run delete `Map_Old`.
- Back up before anything destructive: copy the current `assets/Map.rbxm`, `assets/Terrain.rbxm`, `assets/ServerAssets.rbxm` and `assets/Lighting.rbxm` to `assets/archive/before-redesign/` (commit them). If a backup already exists, do not overwrite it.
- Save the place (never publish) and commit a checkpoint after every stage. Keep the last 3 place/model checkpoints in `assets/redesign-checkpoints/` and delete older ones. Push after every stage (`git push -u origin job-for-tomorrow`, retry on network errors with growing waits). Never open a pull request. Add only files you meant to change; scratch output goes outside the repo.
- If Studio, the network or the Rojo sync is unavailable, wait with backoff (30 s, 1 min, 2 min, up to 10 min) and retry. Do not spin and do not give up.

## 3. Phase 0: study (no edits yet)

1. Read `README.md` (map sections), `docs/balance.md`, `audit.md`, `docs/pets.md`, `docs/pet-models.md`, `tools/map-art/README.md`, `tools/atmosphere/`, and these code files: `MeteorService`, `NodeService`, `DebrisService`, `PlotService`, `RefineryService`, `UpgradeService`, `ShopService`, `EconomyService`, `TutorialService`, `src/shared/Config/Meteor.luau`, `LandingFX.luau`, `Debris.luau`, `Tutorial.luau`, `Shared.LandingFX`, `Shared.EquipmentModels`, `LandingFXController`, `MiningController`, `TutorialController`, `HomeController`, `PetVisualController`, and the specs that depend on map geometry (`tests/LandingFX.spec.luau`, `tests/MineralIndex.spec.luau`, `tests/MiningPower.spec.luau`).
2. **Freeze list (do not touch).** The owner has just made GUI changes. Run `git status`, `git diff` and `git log` and treat every file the owner changed or that is part of the HUD and menus as frozen: `src/client/UI.luau`, `src/client/HudView.luau`, `src/shared/HudLayout.luau`, `src/shared/Config/Hud.luau`, `src/shared/EquipmentShopLayout.luau`, and the Shop, Refinery, Store, Index, Rebirth, Settings, Tutorial-panel and HUD controllers. Also keep every uncommitted change in the working tree exactly as it is (never reset, stash, checkout or clean over it). If a map change seems to require a GUI change, find another way, and if there is none, write it in `REPORT.md` as a follow-up and leave the GUI alone.
3. **Contracts the code depends on** (the new map must provide all of them with the same names and types): `Workspace.Map.Crater.MeteorSpawn` (a BasePart at the crater centre), `Map.Crater.ActiveMeteor` (an empty Folder or Model the server parents the meteor into), `Map.Debris` (the debris rocks DebrisService finds and respawns; read its code for the expected children and attributes), `Map.TownSquare` with the `Refinery` model (a PrimaryPart and a `UsePoint` part, no scripts or prompts; the server creates the `UseRefinery` prompt), optional `Map.TownSquare.PickaxeShop` and `TradingPost.SellPoint` (the server and the tutorial look for these names), `Map.Atmosphere`, spawn locations, `ServerStorage.Assets.Meteor.Core` (with `NodeSlot` attachments and `Vein` parts) and `ServerStorage.Assets.NodePieces`. Search the whole `src/` and `tests/` for `Map`, `TownSquare`, `Crater`, `MeteorSpawn`, `PickaxeShop`, `TradingPost`, `Plots`, `PlotStations` and list every dependency in `PLAN.md`.
4. **Measure the current world in Studio** and record it in `PLAN.md`: ground extent, crater opening radius, floor radius and depth, the Core's size and the radius and height of every `NodeSlot`, the current Refinery position (it was placed at about (-22, 0.6, -110), 112 studs from `MeteorSpawn`), spawn positions, the debris field extents, instance and part counts, triangle count, the number of lights and particle emitters, `StreamingEnabled`, and the current frame time and memory in Play.
5. Run the project's test runner in Studio and record the baseline (every spec should pass in Studio).

## 4. Phase 1: plan, then approve it yourself

Write `docs/map-redesign/PLAN.md` before touching the world. It must contain:

1. **Vision and style guide**: the exact palette (a small set of saturated colours with named roles: ground, paths, building bodies, roofs, trims, accents, ore colours, hazard colours), the material rules, the stud rules, the prop vocabulary and the silhouette rules (see section 6).
2. **A top-down layout** with coordinates and footprints for every zone (section 7), the walking paths between them, the crater arena, the debris fields, the boundary, and all spawn positions. Include an ASCII or SVG diagram (save SVG to `docs/map-redesign/layout.svg`).
3. **Meteor 2x spec**: the exact new sizes and radii (section 8) with the maths.
4. **Budgets**: maximum parts, triangles, lights, emitters, textures, unique meshes, and the target frame time on a mid-range phone (aim for a comfortable 60 fps on desktop and 30+ on low-end mobile; justify your budget numbers from the Phase 0 measurements).
5. **Code change list** (section 9), **test plan** (section 10), **risk list** and **rollback plan**.
6. **Stage order** with a checkbox for each stage; copy it to `PROGRESS.md`.

**Self-approval gate.** When the plan is written, review it as if you were a different, sceptical engineer. Tick every box below in `PLAN.md` with one line of evidence each. If any box cannot be ticked, fix the plan and review again. Only then write `APPROVED by self: <date and time>` at the top of `PLAN.md`, commit it and start Phase 2.

- [ ] Every code contract in 3.3 is provided by the layout, with names.
- [ ] No frozen GUI file is in the change list.
- [ ] Every zone has a purpose, a footprint, an entrance and a walking path that is at least 14 studs wide.
- [ ] The crater arena fits the 2x meteor with room to stand (section 8) and the Refinery is outside the knockback and landing-FX radii.
- [ ] Budgets are numeric and justified; the plan stays inside them.
- [ ] A rollback exists and the old map is backed up.
- [ ] Every stage can be resumed after an interruption without redoing work.
- [ ] The test plan covers meteor types, tutorial, refinery, shop, pets, mobile and performance.

## 5. Phase 2 onward: stages (suggested order, adjust in the plan)

1. Backups and the `Map_Redesign` shell with the required contract objects in place (so the game can already run on it).
2. Terrain and ground: a flat, readable base, the enlarged crater, the boundary.
3. Crater arena and the 2x meteor template (section 8).
4. Town hub: plaza, spawn, paths, Refinery district.
5. Gear Hall, the live equipment shop (section 9.3).
6. Remaining zones (section 7).
7. Debris fields and decoration.
8. Lighting and atmosphere restyle.
9. Code changes (section 9): plots removal, meteor scale numbers, LandingFX numbers, the gear display controller.
10. Studio QA gates (section 10), fix loops, polish loops (section 11).
11. Swap `Map_Redesign` into `Map`, re-run QA, remove `Map_Old`, export assets, documentation, report.

## 6. Style guide: "simulator / tycoon"

- Chunky proportions and thick bevelled edges; props are simple blocky shapes with obvious readable silhouettes (stairs, crates, barrels, signposts, pipes, conveyor segments, glowing ore chunks, banners, scoreboards, lanterns).
- **Studs**: ground, paths, platforms, building floors and walls get a visible stud texture or surface. Find the approach that renders correctly today in Studio (`Material.Plastic` with stud surfaces, or tiled stud `Texture` instances) and use it consistently. Ground tiles read as large studded baseplate sections in two or three alternating tones, paths are a lighter studded strip, platforms are raised studded slabs. Check the cost of the approach on mobile before committing to it.
- Saturated, cheerful colours with strong value contrast between ground, paths, buildings and accents. Use colour for zone identity (for example: refinery district warm orange and steel, Gear Hall blue and gold, hatchery pink and cream, crater dark basalt with glowing ore). Never use colour alone to carry meaning (ore types also get shapes and signs).
- Every building has a big, clear sign (readable at 60 studs, `SurfaceGui` text with a heavy font and outline) and an obvious entrance. Everything interactive has a clear highlight and a ProximityPrompt-friendly spot.
- Lots of life: banners, string lights, floating ore crystals on pedestals, spinning gears, steam from the refinery chimney, conveyor belts that move (use `Beam`/texture scrolling or looping tweens only if cheap), idle animated props, ambient sounds that exist in `Config.Sounds` only (do not invent asset ids).
- Lighting: brighter, cleaner and bluer-sky than the old late-afternoon fog, but the meteor glow and event effects must still pop. Keep the particle budget in mind (the old setup kept about 220 alive). Update `tools/atmosphere/author-lighting.luau` if you change the authored look, or document why not.
- Original art only. Do not reuse copyrighted assets, brand names or other games' designs. Prefer parts and the existing Blender meshes in `assets/map-art/`; you may author new meshes with the existing tooling in `tools/map-art/`.
- Keep it performant: anchored parts, `CanCollide` off on decoration and small props, `CanTouch` and `CanQuery` off where unused, `CastShadow` off on small props, `CollisionFidelity` Box for big meshes, reuse meshes and textures, no per-frame scripts on decoration (use tweens or none).

## 7. Zones

Design these (names are suggestions; keep the contract names from 3.3 where they apply). Everything is walkable, symmetrical enough to read, and sized for a full server (assume up to 30 players at once and their pets, pets follow at the owner's side so keep paths wide):

1. **Crater arena** (centre): section 8. Terraced seating rings and wide ramps around the rim so spectators and late joiners can watch; clear approach corridors; nothing tall inside the knockback radius except decor that is part of the crater wall.
2. **Spawn plaza**: a big bright studded plaza with a fountain or ore monument, the spawn pads (several, not one, so a full server doesn't stack), a welcome sign, and signposts to every zone.
3. **Refinery district**: the existing `Refinery` model (keep its `UsePoint` and name) moved to a prominent spot outside the crater and landing-FX radii, facing the crater, with a queue area, a conveyor decor line, a "SELL" counter that is the existing `TradingPost.SellPoint` if the server expects one (read `EconomyService`), and a clear floor marker at the use point. This is the most important building: make it a landmark.
4. **Gear Hall**: section 9.3.
5. **Hatchery**: two egg pedestals (Meteor Egg, Crystal Egg) in a cosy dome or pavilion, with large boards that show the egg prices and odds exactly as in `Config.Pets.Eggs` (generate the text from the config values, never hard-code) and a pet showcase wall of the 14 pets (use `ReplicatedStorage.PetModels` previews if present; otherwise empty plinths with name plates). It is decor plus signage only; the real hatching stays in the existing GUI. If a ProximityPrompt that opens the existing shop is possible without touching GUI code (`ShopService.Open`), add it and note it.
6. **Rebirth monument**: a grand statue or portal ("Relocate the Colony") that shows the current rebirth cost and multiplier from `Config.Rebirth` on a sign; decor only.
7. **Mineral Index museum**: a small gallery with plinths per page of `Config.Index`; decor with name plates.
8. **Debris fields**: three to four themed fields around the arena (iron field, frost field, crystal field) so the world has destinations between meteors. Keep the `Map.Debris` structure DebrisService needs and add new rocks the same way. Spread them so no field is within 40 studs of the Refinery or spawn.
9. **Boundary**: a themed wall or cliff ring with an invisible collision wall above it and a kill plane below the world, no gaps, nothing walkable beyond it.
10. **Landmarks and flavour**: a scoreboard wall, benches, planters, lamp posts, trees made of blocks, a skyline silhouette (distant cliffs or towers), a few easter eggs.

Remove: `Map.Plots` and everything plot-only (pads, signs, fences, beacons, `PlotStations` usage). Keep `ServerStorage.Assets.PlotStations` only if you need parts from it (the refinery art came from it); otherwise delete it and say so in the report.

## 8. The 2x meteor

"2x as big" means every linear dimension doubles: the Core, the crust nodes and node pieces, the crater that holds them, the landing and exit effects, the knockback and the arena. Hit points do not change (they come from `MiningPower.size`, not from geometry), so the event lasts the same time.

1. Scale `ServerStorage.Assets.Meteor.Core` uniformly by 2 (its `Size`, every `NodeSlot` attachment position, `Vein` parts, lights, emitters and their sizes and ranges) and scale every piece in `ServerStorage.Assets.NodePieces` by 2. Keep names, attributes and the number of `NodeSlot`s unless nodes look sparse on the doubled surface; if you add slots, keep the total under 48, update nothing else by hand (HP per node follows `#slots` automatically) and run the meteor and mining specs.
2. Everything must stay mineable: the server accepts a hit when the player's root is within the pickaxe's `Reach` of the node (`Config.Meteor.MineRange` is 12 and the pickaxe `Reach` stat sets the real limit; read `NodeService`). Measure, from walkable ground, the distance to every node slot and to the Core and make sure every one can be reached by a Basic Pickaxe with normal Reach. Do this with terraces, ramps and platforms built into the crater floor, or by shaping node slot heights, not by changing mining rules. Record the numbers in `PLAN.md` and re-check them in Play.
3. The old crater (from `Config.LandingFX.Crater`): floor radius 42.5, opening radius 64, floor Y -11.35, crust reaching about 23.5 at floor level, line start radius 26, vertical clear radius 66. With the meteor doubled the crust reaches about 47, so the floor must be at least about 47 plus about 14 of walking ring, and the opening must grow with it. Pick the new numbers from your measurements, build the crater to match, then update `Config.LandingFX` (`Crater`, `Sheet.Diameter` and `StartDiameter`, cluster radii and footprints, `LineStartRadius`, `VerticalClearRadius`, corridor widths, `Exit.ShatterScale`) and the other geometry-dependent numbers (`Meteor.Knockback.Radius` and `Tutorial.CraterRadius`, and any radius in `DebrisService` or `Config.Debris`) by the same factor or by the measured need. Update `tests/LandingFX.spec.luau` and any other spec that encodes the old geometry so it asserts the new geometry, never by weakening it.
4. The impact: the approach streak, impact flash, dust, shockwave, camera shake and sound must all read as 2x. Scale the visuals; check them in Play for each type (use the Studio dev hooks `DevSpawn` / `DevMeteorType` to bring Iron, Ice and Crystal meteors down on demand).
5. The Refinery, spawn plaza and every zone entrance must sit outside the knockback radius and the landing-FX radius (and outside the new `Tutorial.CraterRadius`, or update the tutorial radius consistently).
6. Check shockwave knockback does not throw players out of the world or into the boundary, and that nothing blocks the corridors.

## 9. Code and content changes (non-GUI only)

1. **Plots removal.** Make `PlotService` unnecessary: remove plot claiming, plot signs, beacons, `PlotStations` cloning and the "no Refinery model, fall back to plots" paths in `RefineryService`, `PlotService`, `UpgradeService` and `HomeController`, keeping everything the shared Refinery and the offline catch-up need (hopper, collection post, production tick, upgrades). The Production tab in the Shop already buys station upgrades through `UpgradeService`; keep that working. Remove dead code, dead remotes and dead specs, update `README.md` (the plot sections are obsolete) and `docs/`. If a frozen client file must change to stay compatible, make the smallest possible edit, list it in `REPORT.md`, and prefer making the server tolerate the old client call instead.
2. **Meteor scale numbers** (section 8) and the specs.
3. **Gear Hall: the live equipment shop.**
   - Geometry: a bright, open, two-storey-looking hall (the upper floor can be a balcony) at its own prominent location. The counter is a model named `PickaxeShop` under `Map.TownSquare` so the existing server-created prompt opens the shop (read `ShopService` for the exact behaviour). Give it a clear floor marker.
   - **Two display stands** (named `PickaxeStand` and `BackpackStand`, each with an anchor part) at the entrance. A new client controller (for example `src/client/Controllers/GearDisplayController.luau`, world-space only, no HUD or menu code) renders the **local player's** current pickaxe and backpack on them using `Shared.EquipmentModels` (`pickaxe(tier)` and `backpack(tier)`), slowly rotating, with a soft spotlight. Read the player's tier from the existing State property (`pickaxeTier`, `backpackTier`) and update the models the moment it changes; show a short burst of sparkles on a change. A `SurfaceGui` (world sign, not HUD) on each stand shows the name, the tier and the main stats from State (Power, Swing, Reach, Crit; Capacity), formatted with `Shared.Format`.
   - A **tier wall**: all 8 pickaxe tiers and all 8 backpack tiers as static models on a wall, each with a name plate and a glow state: unlocked (full colour and glow), current (highlighted frame), locked (dimmed with a padlock). Driven by the same State. Generate every name and number from `Config.Pickaxes` and `Config.Backpacks`, never hard-code.
   - Everything the controller renders is local to the player and removed on leave; cap work to the player being within 80 studs of the hall; no per-frame work when far away.
   - Write a pure helper in `Shared` for which tiers are locked, current or unlocked, with a spec.
4. **Spawn handling**: multiple spawn pads, facing the plaza, no spawn inside an interaction zone; keep whatever the server expects for respawn.
5. **Tutorial**: the tutorial looks up town parts by name; make sure the arrows and targets still resolve on the new map and that the "reach the crater" radius matches the new crater.

## 10. Studio QA gates (all must pass before the swap)

Run in Play with a real server and client, and with a local server of two players where you can. Capture screenshots of every zone and the crater at each meteor phase into `docs/map-redesign/screens/` and look at them critically.

1. **Tests**: the project's test runner passes completely in Studio.
2. **Output**: no warnings or errors in the Output window during a full session (fix the cause of every one).
3. **Navigation**: using `PathfindingService` (and by actually walking), a player can get from every spawn to every interactive point (Refinery, SELL, Gear Hall, hatchery, museum, monument, every debris field, the crater floor, the rim seating) with no gaps, no traps and no unreachable decoration that blocks a path. Jump-test every ramp and stair at default Humanoid settings. Nobody can leave the map or get stuck.
4. **Meteor loop** for Iron, Ice and Crystal at 2x: lands, cools or cracks, rewards, cleans up; every node and the core is reachable with a Basic Pickaxe; shockwave is survivable; all landing and exit effects (`LandingFXController`) still fit the crater (nothing floats, nothing clips into walls).
5. **Systems**: debris mine and respawn, refinery deposit, collect and clearance, selling, the shop (all tabs), pets visible and following (with the new wider paths), the tutorial from a fresh profile to the end, rebirth, rejoin.
6. **Mobile**: emulate 320 x 568, 390 x 844 and 844 x 390. The map must be readable, prompts reachable, no on-screen overlap caused by world signs.
7. **Performance**: record part, instance and triangle counts, lights, emitters, draw-call proxies, memory and frame time in the crater at event time with a full server's worth of pets and effects (simulate with bots or the dev fake-tier hooks). Stay inside the plan's budgets; if you are over, optimise (merge, instance meshes, drop shadows, trim particles) rather than raise the budget.
8. **Security and exploits**: players cannot stand inside or under the map, reach the crater from outside the arena, climb the boundary, or farm an unreachable spot; the server's reach check is the only authority and is untouched.
9. **Consistency**: no leftover plot objects, no references to `Plots` or `PlotStations` in code or place, no stray test fixtures in the place (search every Script for QA code that changes player data).

## 11. Polish loops

After the gates pass, run at least three critique-and-fix rounds. In each round, look at fresh screenshots of every zone and score it 1 to 5 against this rubric, write the scores and the fixes into `PROGRESS.md`, and fix everything below 4: silhouette and landmark clarity, colour harmony, stud and material consistency, scale and proportion (does a 5-stud-tall character feel right in it), density (not empty, not cluttered), signage legibility, navigation clarity, "tycoon fun" (does it look rewarding), performance. Stop only when every score is 4 or higher in two rounds in a row.

## 12. Finish

1. Swap `Map_Redesign` into `Map`, re-run the gates, then remove `Map_Old`. Save the place without publishing.
2. Export `assets/Map.rbxm`, `assets/Terrain.rbxm`, `assets/ServerAssets.rbxm`, `assets/Lighting.rbxm` (restore with the commands in the README); keep the pre-redesign backups in `assets/archive/before-redesign/`.
3. Update the README (map section, plots gone, 2x meteor, Gear Hall, how to restore), `docs/balance.md` if numbers changed, `tools/map-art/README.md` and `tools/atmosphere/` if you changed the authoring.
4. Write `docs/map-redesign/REPORT.md`: what was built, final numbers (crater radii, meteor scale, budgets measured), every assumption, anything that could not be verified, follow-ups that need a GUI change (blocked by the freeze), and what the owner should look at first.
5. Commit and push everything to `origin/job-for-tomorrow`.

## 13. Never

Never publish the place. Never touch frozen GUI files or discard the owner's uncommitted work. Never change economy numbers, odds, or monetization. Never skip or weaken a test. Never leave the game in a state where the server cannot start: if the swap breaks something you cannot fix quickly, roll back to `Map_Old` and say so in the report.
