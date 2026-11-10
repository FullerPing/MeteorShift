# Compact world revision — updated 7 October 2026

APPROVED by self under the owner's latest direction. The current world keeps the compact 540 × 540 layout, scales town buildings to **0.5**, removes elevated mining access/staircases, and returns the doubled meteor to its original landing centre **(0, −1.25, 0)**. This supersedes the full-size buildings, raised centre Y35.4 and gallery/ascent design from the 6 October revision. The original gameplay, internal GUI protection, staged-only authoring and final QA gates remain.

## Current geometry

`WorldGeometry.Settings` is the source of the layout numbers below: MeteorScale = 2, BuildingScale = 0.5, BoundaryHalf = 270, StageOffset = (0, 0, 3000), LandingRadius = 125 and LoopRadius = 134. The playable square is **540 × 540**; the former large redesign was 1,020 × 1,020, so the current side length is approximately 0.529 of that layout.

The original crater opening radius 64 becomes **83.2**: diameter **166.4**, exactly 1.3 times the original diameter 128. Floor radius is **55.25**, floor Y is **−14.755**, and rim Y is 0. Four ground access ramps remain 24 studs wide. `Crater.MiningAccess` must be absent; `MiningAccess.luau` is now a rerunnable removal command.

Keep the verified **2× Core and NodePieces templates**. Original Core 28.349998 becomes approximately **56.699997 on every axis**, eight times the volume. Keep all 36 NodeSlots, HP, Basic Reach 12, rewards, odds and prices. Building scaling also scales local equipment mount offsets/display scales and the welcome monument; the spawn plaza, six 12 × 12 pads, paths and debris fields retain their current dimensions.

`Config.LandingFX.Crater.Center` and MeteorSpawn use **(0, −1.25, 0)**. This restores the original landing height while retaining the larger meteor. The doubled Core's lower face is approximately Y−29.6, below the Y−14.755 floor; lower shell geometry is also partially buried. Actual rotated bounds, visibility and ground-only access to every crust node and core remain unverified. Do not infer mining accessibility from bounding boxes or earlier elevated-access QA.

## Exact WorldGeometry zones

Coordinates are final local X,Z; entrance vectors are X,Y,Z. Actual interaction points remain grounded at their authored service height. Scene staging adds Z3000.

| Zone id | Centre X,Z | Footprint W × D | WorldGeometry entrance X,Y,Z | Path width |
|---|---|---|---|---:|
| Refinery | 0, −177 | 38 × 32 | 0, 3, −158.5 | 18 |
| GearHall | 128, −185 | 50 × 36 | 128, 0, −165.5 | 18 |
| Hatchery | −135, −185 | 64 × 36 | −135, 0, −165 | 18 |
| TradingPost | 60, −245 | 28 × 20 | 60, 0, −232 | 14 |
| Spawn | −20, −241 | 96 × 54 | −55, 0, −215 | 24 |
| Rebirth | −214, −55 | 36 × 36 | −196.5, 0, −55 | 18 |
| Museum | 214, −55 | 42 × 38 | 192, 0, −55 | 18 |
| RustWorks | −130, 185 | 100 × 92 | −130, 0, 139 | 18 |
| FrostYard | 130, 185 | 100 × 92 | 130, 0, 139 | 18 |
| VioletQuarry | −214, 77 | 92 × 96 | −168, 0, 77 | 18 |
| SulfurRidge | 214, 77 | 92 × 96 | 168, 0, 77 | 18 |

The six building models and separate Gear Hall counter use BuildingScale 0.5 at their compact centres. Town avenue Z−130 is 18 wide; spine X−55 is 24 wide; Trading branch Z−215 is 14 wide. Spawn pad centres are X−46/−20/6 and Z−257/−229. Welcome centre Z−265 is retained, with its monument/crest at half scale.

Loop centre radius is 134 and width is 18. Routes uses vertex radius `134 / cos(pi / 64)` so its straight segment inner edge remains radius 125. Only flat/noncolliding landing strips may approach it; upright effects respect cardinal corridors and obstacle exclusions. Boundary walls begin at ±270; cliffs remain outside the play area. The under-map kill plane is Y−70, and server boundary checks also enforce the authored bowl surface.

The Refinery footprint's nearest point is radius **161**, 36 studs beyond persistent landing parts and 44 beyond knockback. Its declared UsePoint radius is **158.5**. Rust/Frost have the nearest field footprint at approximately **160.378**. Knockback radius is **117**, with speed 110, lift 55 and zero damage retained. Radius **125** bounds persistent landing geometry; ballistic particles may travel farther. Shockwave height follows the ground/bowl/rim.

## Authoring and restoration

Use a verified staging binary with matching world sources for restoration. Existing legacy factories are not a complete current-world reconstruction recipe. Common loads fresh WorldGeometry/Config, but fresh settings do not automatically convert every legacy literal or full-size decoration.

Refinery now preflights ground at its compact target before replacing its owned model, then builds full-size art. Other legacy landmark builders can still create art at the earlier coordinates. A controlled rebuild must translate compatible art with CompactLayout and then apply SmallBuildings; a bare legacy factory replay does not reproduce this scene.

When refreshing spawn geometry, use **Routes → SpawnPolish → SmallBuildings**. Routes replaces SpawnPlaza; SpawnPolish recreates its original-size decorations; SmallBuildings then reapplies half-scale welcome geometry. SmallBuildings uses stored baselines, rather than compounding scale, and adjusts relative equipment mounts. The current PolishPass1 follows LandmarkScale for its dimensions and positions and ran successfully on the half-size models in Studio.

Crater uses the current original landing centre and shallow bowl. MiningAccess is removal-only and must not restore terraces or an ascent. RuntimeWalkingQA now exposes **14 ground destinations**, requires MiningAccess absent, and retires its former five elevated destinations. Lighting authoring stores an inactive profile; live Lighting/Terrain changes remain part of the controlled QA/swap workflow.

## Recorded checkpoints and superseded history

The current Edit checkpoint reported on 7 October has **1,173 authored parts**, **84 successful Edit routes / 0 failures** and **six clear forecourt probes / 0 collision failures**. Root verified that SmallBuildings plus CompactLayout reruns changed **0 part frames and 0 sizes**. The source suite passed **423 / 0**, and all **39 protected GUI hashes** remained unchanged. Edit save was confirmed at **07:35:58.313** on 7 October, without publishing. The four staged exports and their manifest at `assets/staging/map-redesign/manifest.json` passed disk-byte/signature and engine round-trip verification. These recorded checkpoints do not prove completed Play/phone/performance/mining QA.

The superseded full-size compact checkpoint had **1,410 parts**, 84 Edit routes and 96 ascent headroom samples passing, zero migration frame changes and model bounds inside ±270. It used full-size buildings, meteor centre Y35.4 and a constant-radius R80 ascent with four galleries. The old shrinking helix had previously failed pathfinding above its lower section. These elevated-access results remain history; they do not certify the current staircase-free world or partially buried meteor.

The pre-compact rollback is `assets/archive/before-compact/Map_Redesign.rbxm`: **88,377 bytes**, **1,417 parts**, SHA256 `beffeab892c707b96344963b9a3602f36b196b21ea904ba278eb94abe0d51e0d`. It restores the earlier stage, not the latest half-size scene. Original Map had 2,043 parts and original Assets remain preserved. `frozen-gui-before-compact.json` records 39 protected files; the owner's recent GUI changes supersede the initial redesign freeze baseline.

## Remaining acceptance and rollback

Keep PLAN's budgets: map ≤1,800 parts, server meteor ≤550 parts / 36 crust nodes, world equipment 18 models / ≤650 parts, enabled map lights ≤12, steady particles ≤260, and event landing parts ≤160. Preserve all remaining GUI, economy, timing, odds and monetization rules.

Recheck current ground-only static contracts, crater hole rays, actual part-corner footprints, persistent-effect clearance, interaction points, proportional equipment mounts and rerun idempotence after any rebuild. Actual Play must prove ground walking, Basic reach plus line of sight to **all 36 nodes and core**, Iron/Ice/Crystal bounds and landings, impact survival, interaction flows, phones and event/pet performance. Buried lower-node access is an explicit pending gate. The original critique rounds, pre-swap/post-swap QA and final save/export audit remain required.

If this geometry fails a gate, preserve the user's no-staircase direction and report the actual failure. Stop Play and restore a matching staged binary/world-source checkpoint when needed; never repair the staged scene by changing original Map or owner GUI. Restore temporary selectors/spawn/device state before saving Edit. Do not claim final completion or swap from the recorded Edit/source checks; publishing remains outside scope.
