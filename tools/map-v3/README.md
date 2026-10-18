# Map v3: Caldera Terraces (authoring stages)

Spec: `docs/design/caldera-map-v3.md`. Plan: `docs/plans/2026-10-18-caldera-map-v3.md`. Layout numbers live in `src/shared/WorldGeometry.luau`; footprints come from `plan.py` (exported to `PlanData.luau`).

These are Edit-time commands outside the Rojo tree, on top of the map-v2 grammar (`tools/map-v2/Common`, `Brick`, `Toon`). They author `Workspace.Map_Redesign` at offset zero; it is renamed `Map` at the swap.

## Running

1. Serve the tools folder: `python -m http.server 8123 --bind 127.0.0.1 --directory tools`.
2. Stop Play, then from Studio MCP `execute_luau` (Edit). Run long stages inside `task.spawn` and poll a `_G` flag; a single call that runs them all freezes Studio past the MCP timeout.
   ```luau
   local H = game:GetService("HttpService")
   local function L(n, ...) return assert(loadstring(H:GetAsync("http://127.0.0.1:8123/map-v2/" .. n .. ".luau", true), n))(...) end
   L("Common"); L("Brick"); L("Toon")
   L("../map-v3/Ground", L("../map-v3/Props", "lib"))
   L("../map-v3/Roads")
   L("../map-v3/Rampart", L)
   ```

## Stages

| Stage | Owns | Notes |
|---|---|---|
| `Props` | `Map_Redesign.Workbench`, `ServerStorage.MapArt.<prop>` (tag `PropBuilder`) | The 14 hero props, built at x 6000 and copied to MapArt. `L("../map-v3/Props", "lib")` returns the builders only (for `Ground`'s cliffs). |
| `Ground` | `Ground` | The v2 collision ground and grass plate (cloned from `SwapRollback.Map_v8`), a checker lawn on T0, T1/T2 as 5-stud rows clipped to 16-gon edges (apothems 260 and 370), cliff faces on every edge (open at avenue ramps and slide crossings), 15° ramps with kerbs on every avenue (the south one stops at T1), and the Crown plateau to the north wall. |
| `Roads` | `Roads` | `Ring` (the v2 ring, approaches and south plaza, cloned), `Express`, `Avenue_<angle>` (paving, navy edges, gold `FastStrip`, also up the ramps), `Slide_<angle>`. |
| `Rampart` | `Boundary` | map-v2 `Boundary` at ±540 with `noLawn`, lifted onto T2, kill plane left at `KillPlaneY`; a parapet and an invisible `CrownFence` on the Crown's north edge (the meadow is level with the wall top). |

## Slides

A slide's deck is a conveyor: an anchored part whose `AssemblyLinearVelocity` (40 studs/s downhill) carries whoever stands on it, with friction 0. A Humanoid keeps its footing on a frictionless slope, so friction alone would not move anyone. A walker needs about 8 studs under a deck, so the T2 slides start on a tower 16 above T2 (a 15° ramp along the edge leads up to it), and the north slide starts on the Crown. Measured in Play: 7.9 s (45° and 135°) and 8.6 s (north) from the top to the ring road. The Express and T1 stay walkable under them.

## Verified (18 October 2026, Studio, unsaved)

- Ray-cast every 6 studs over the whole map: no holes. Heights match the tiers except a sliver up to 5 studs wide at each T2 16-gon corner, where `tierAt`'s circle (T2 from r 372) is inside the polygon (its corner reaches r 377).
- Play: the character walks up the T0→T1 and T1→T2 ramps on a straight avenue and a diagonal one, and up a slide tower ramp, without jumping.
- Part counts: Ground 3,002, Roads 335, Boundary 820.
