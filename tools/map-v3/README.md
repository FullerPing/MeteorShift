# Map v3: Caldera Terraces (authoring stages)

The live `Workspace.Map` since 19 October 2026. Spec: `docs/design/caldera-map-v3.md`. Plan: `docs/plans/2026-10-18-caldera-map-v3.md`. Layout numbers live in `src/shared/WorldGeometry.luau`; footprints come from `plan.py` (exported to `PlanData.luau` with `python tools/map-v3/plan.py .tmp/caldera.dc.html --luau tools/map-v3/PlanData.luau`).

These are Edit-time commands outside the Rojo tree, on top of the map-v2 grammar (`tools/map-v2/Common`, `Brick`, `Toon`). They author `Workspace.Map_Redesign` at offset zero. The map was swapped by renaming it `Map`, so to rebuild a stage on the live map, rename `Map` to `Map_Redesign` for the run and back afterwards. Rollback: `ServerStorage.SwapRollback.Map_v8` (the v2 map) and `assets/archive/map-v2-2026-10-18/`.

## Running

1. Serve the tools folder: `python -m http.server 8123 --bind 127.0.0.1 --directory tools`.
2. Stop Play, then from Studio MCP `execute_luau` (Edit). Run long stages inside `task.spawn` and poll a `_G` flag; a single call that runs them all freezes Studio past the MCP timeout.
   ```luau
   local H = game:GetService("HttpService")
   local function L(n, ...) return assert(loadstring(H:GetAsync("http://127.0.0.1:8123/map-v2/" .. n .. ".luau", true), n))(...) end
   L("Common"); L("Brick"); L("Toon")
   local plan = L("../map-v3/PlanData")
   L("../map-v3/Ground", L("../map-v3/Props", "lib"))
   L("../map-v3/Roads")
   L("../map-v3/Rampart", L)
   L("../map-v3/Core")
   L("../map-v3/Fields", plan)
   local O = L("../map-v3/Overlap")
   L("../map-v3/Districts", plan, O)
   L("../map-v3/Scenery", plan, O)
   L("Surroundings", { lift = 32 })
   L("../map-v3/CraterDetail") -- after Core and Roads
   L("Backdrop")
   L("../map-v3/Dezfight", O) -- last: re-run it after rebuilding any stage
   return L("../map-v3/StaticQA")
   ```
   Shared modules are loaded as fresh clones (`A.config`, `A.world`); a plain `require` in Edit can return a stale cached copy.

## Stages

| Stage | Owns | Notes |
|---|---|---|
| `Props` | `Map_Redesign.Workbench`, `ServerStorage.MapArt.<prop>` (tag `PropBuilder`) | The 14 hero props, built at x 6000 and copied to MapArt (the Workbench was deleted at the swap). `L("../map-v3/Props", "lib")` returns the builders only, for `Ground`'s cliffs. |
| `Ground` | `Ground` | The v2 collision ground and grass plate (cloned from `SwapRollback.Map_v8`), a checker lawn on T0, T1/T2 as 5-stud rows clipped to 16-gon edges (apothems 260 and 370), cliff faces on every edge (open at avenue ramps and slide crossings), 15° ramps with kerbs on every avenue (the south one stops at T1), and the Crown plateau to the north wall. |
| `Roads` | `Roads` | `Ring` (the v2 ring, approaches and south plaza, cloned), `Express`, `Avenue_<angle>` (paving, navy edges, gold `FastStrip`, also up the ramps; each stops at `Avenues.stops` or the wall), `Slide_<angle>`. |
| `Rampart` | `Boundary` | map-v2 `Boundary` at ±540 with `noLawn`, lifted onto T2, kill plane left at `KillPlaneY`; a parapet on the Crown's north edge and an invisible `CrownFence` along the whole north wall (the Crown's meadow is level with the wall top). |
| `Core` | `Crater`, `CraterApron`, `TownSquare` | Cloned from the v2 map: the crater whole, the apron inside r 124, the Refinery and the six spawns in place, the Commissary, Gear Hall, Hatchery and both leaderboards turned onto their v3 zones. TradingPost and PickaxeShop are left out (their services treat them as optional). |
| `Fields` | `Debris`, `DebrisFields`, `Gates`, `Chutes` | One rock per plan rock (an archived rock of the field's look, tinted for the new fields), a `FieldFloor` per block (PlanData `block`) under its rocks (+2 studs; together they are the locked-field eject box; block 1's is the PrimaryPart) and one `Entrance`, per block the gate (FieldGate mesh facing out of its side, the avenue for the six tier fields; `Barrier` on locked fields; the `Rule` sign), force-field `Wall`s round every locked block (`Shared.FieldWalls`: open only at the gate; `FieldGateController` shows and hides them with the barrier) and the ore chute with its `UsePoint`. Asserts every entrance is outside each eject box and 3+ studs from each barrier. |
| `Districts` | `Districts.<cell>` (Atomic), `Crown` | Every non-field footprint by its tag or label (meshes from MapArt, Toon builders, a labelled box for anything unknown), dropping any that cuts into the town (the plan's two `board` rows are the real leaderboards) or an earlier district model, and the Crown's contract: `Lift` (SkyLift mesh, `Prompt`) at the north avenue's end on T2, `LiftTop`, `DivePad` with the Dive cannon, the Starfall Beacon. |
| `Scenery` | `Scenery.<band>_<wedge>` (Atomic) | The plan's 3,181 scatter rows thinned to about 55% (`KEEP`; lamps 50%, `LAMP_KEEP`; watch posts always kept), then any piece on a road or cutting into anything solid or an earlier piece dropped (1,601 placed) on the ground found by a ray; the owner's MapArt meshes (Tree, Pine tree, Blosom tree, LowPolyBushes, the crystal set, Big Stone); all non-colliding, query-free, no lights. |
| `CraterDetail` | `CraterDetail` | Visual only (non-colliding, CanQuery false, so gameplay rays see the old surfaces): hides the ring's 64 `Loop` boxes (still the walkable surface) and the 48 `StuddedRim` chords (still in the FX ground rays) and draws one CSG ring road annulus with the stud skin, white kerbs open at the approaches, avenues and south plaza, a gold dashed centre line, four seamless gold rim arcs with a navy lip, glowing fissures on the bowl floor and the slopes between the ramps, and Big Stone boulders on the apron. Re-run after Core or Roads. |
| `Overlap` | nothing (a library) | `depth(p, q)` (oriented-box penetration) and a spatial index; Districts, Scenery and StaticQA use it. |
| `Dezfight` | nothing new (moves parts) | The finishing pass: every visible pair of flush same-way faces found by `Coplanar` (exact overlap of the two rectangles, clipped in their plane; Ground, Roads, Boundary, Gates, Crown, Districts, TownSquare, Chutes, Crater, CraterApron, Scenery and CraterDetail; unions are skipped as candidates) (the z-fighting on cliff strata, terrace seams, avenue edges and crossings, ramp landings, prop trims, wall corners) is separated by moving the smaller part 0.12 studs out along the face. Run it after any stage rebuild. |
| `StaticQA` | nothing (read-only) | Counts per group, total, MeshParts, lights, emitters; fails on colliding decoration, on anything visible in front of a leaderboard screen, on a field wall cutting into a road, cliff, ramp, rampart, rock, chute, the Crown or the town, on a chute or entrance inside a walled field, on any visible flush faces left (z-fighting), on an eject box reaching avenue paving, and on a chute or entrance with no walk to an avenue (straight, one side-step, or round the terrace; Crown points walk to `LiftTop`). Gate barriers are `CanQuery = false`, so the walks can't see them. |

The map-v2 `Surroundings` (pass `{ lift = 32 }`) and `Backdrop` scale with `BoundaryHalf`; at 270 they reproduce v2.

## Slides

A slide's deck is a conveyor: an anchored part whose `AssemblyLinearVelocity` (40 studs/s downhill) carries whoever stands on it, with friction 0. A Humanoid keeps its footing on a frictionless slope, so friction alone would not move anyone. A walker needs about 8 studs under a deck, so the T2 slides start on a tower 16 above T2 (a 15° ramp along the edge leads up to it), and the north slide starts on the Crown. Anyone below rebirth 1 who climbs onto the Crown that way is put back at the lift's foot by `CrownService`.

Rebuilt 19 October 2026 for the avenue fields (Core, Fields, Districts, Scenery, Dezfight): StaticQA 0 failures, 16 walks, 11,409 parts; the exact Coplanar found 254 flush pairs the old 6x6 sampling missed (cliff turf at the 16-gon corners, Express and ring joints, crater rim, apron) and Dezfight cleared them (232 moved); Play: Frost Yard's eject from both blocks onto its entrance, ORE travel to Rust Works.

## Verified (18–19 October 2026, Studio)

- StaticQA: 0 failures; 16,254 parts after the swap (16,574 with the Workbench; 12,279 after the scenery was thinned and the overlaps cleared on 19 October), 7 lights, 6 emitters, 16 walks. Specs 704/704; Lune DebrisService harness 16/16.
- Ray-cast every 6 studs over the whole map: no holes. Heights match the tiers except a sliver up to 5 studs wide at each T2 16-gon corner, where `tierAt`'s circle (T2 from r 372) is inside the polygon (its corner reaches r 377).
- Play: walking up the T0→T1 and T1→T2 ramps on a straight and a diagonal avenue and a slide tower ramp without jumping; slides 7.9 s (45° and 135°) and 8.6 s (north) to the ring road, the Express and T1 walkable under them; spawn to the Rust Works entrance 4.8 s; ORE travel to an open field, refused for a locked one; a Rust rock broken; all 8 chutes take deposits (a far deposit gets the "move closer" notice); every level gate opening live at level 50 and Starfall after a real rebirth; the eject from Frost Yard and Halo Ledge onto their entrances; the avenue kerbs beside Rust and Frost are clear of the eject; a rebirth-0 player on the Crown is put back at the lift; the Dive from the real pad lands standing at r 110; three meteor impacts; console clean.
- Not verified here (the MCP session had no rendering viewport, so screenshots timed out and no ProximityPrompt was ever shown): the look of the map, pressing the Sky Lift prompt (its server rule was tested in Task 7), a meteor shockwave throw (analytically it can't reach T1: a throw's apex is at most 7.7 studs, the cliff is 16), phone frame rate, and whether the slide conveyors keep their velocity after the place is saved and reopened.
