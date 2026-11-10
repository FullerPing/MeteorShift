# Map v3 "Caldera Terraces" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 540-stud map v2 with the 1080-stud tiered "Caldera Terraces" map: 8 gated fields on 4 tiers, avenues up, slides down, a chute at every field, about 3,500 placed footprints.

**Architecture:**
- **Gameplay rules first.** The rules (gates, chutes, roads, Dive arc) are pure `Shared` modules with specs, wired into existing services through hooks that already exist (`NodeService` `CanHit`, `WorldMap.refineryPoints`, `CharacterSpeed.onRoad`).
- **The world is authored in Studio Edit mode as `Workspace.Map_Redesign`.** New `tools/map-v3` stages build it from one generated data file, `tools/map-v3/PlanData.luau`, which `tools/map-v3/plan.py` writes. They reuse the map-v2 grammars (`Common`, `Brick`, `Toon`) and clone the unchanged contract models from the archived map.
- **One swap at the end.**

**Tech Stack:** Luau `--!strict`, Knit, Rojo, Roblox Studio MCP (`execute_luau`), Python 3.9 (plan generator, local HTTP server for tool loading).

**Spec:** `docs/design/caldera-map-v3.md`, plus the positions in `tools/map-v3/plan.py`. Visual reference: the Claude Design canvas "MeteorShift Map Redesign", boards "Caldera v2 · …".

## Global Constraints
- Every Luau file starts `--!strict`. Tuning numbers live in `src/shared/Config`; rules live in sibling `Shared.*` modules (CLAUDE.md).
- Specs return `function(t)`, require from `t.shared` / `t.lib`, and run with `require(game.ServerStorage.Tests.Runner)("<Name>")` in Studio Edit mode.
- The server re-validates every action. Gate state is computed on the server from `level` and `rebirths`, never from a client value.
- Map contracts kept by name: `Map` attribute `MapRedesignOwned`, `Crater.MeteorSpawn / ActiveMeteor / SkyTimer.Board / AccessRamps`, `TownSquare.Refinery` (one `UsePoint`), `TownSquare.Leaderboards.<Id>.Screen`, `GearHall.TierWalls` + `CurrentStands`, `Debris` roots with attribute `Field`, `DebrisFields.<Id>.FieldFloor` + `Entrance`, `Boundary.KillPlane`, six enabled `SpawnLocation`s, the `Ground` and `Roads` folders (shockwave landing raycast).
- Unchanged values: `Config.LandingFX.Crater`, `LoopRadius = 134`, `PathWidth = 18`, `SpawnRowsZ = { -153, -148 }`, `SpawnColumnsX = { -18, 0, 18 }`, Refinery at (0, −177), `KillPlaneY = -70`.
- New values: `BoundaryHalf = 540`, Express r 280 / width 16, avenues every 45°, 24 wide, from r 143. Tier radii 250/266/360/372, Y 0/16/32, Crown x −150..150, z 400..530, Y 56.
- Never replace `ReplicatedStorage.Shared` with a clone. Long `execute_luau` work yields with `task.wait()` per chunk. Scripts that rewrite Luau keep LF.
- Map stages run in Edit mode only, build into `Map_Redesign`, and refuse to replace instances they don't own (map-v2 `Common` ownership checks).

## Review Focus
1. **Mining a locked field by any route** (pet hits, a swing from the field edge, mining while standing on a slide end) must be refused. `NodeService` checks `CanHit` on `Swing` and `PetHit`. Task 2 pins pets.
2. **Getting onto a locked field floor** (ORE travel, jump/slide momentum, a shockwave throw) must push the player back to the gate within 1 s. Task 2 pins ORE travel; Task 13 has the walk-through.
3. **A field opening mid-session** (level-up, rebirth) must unlock without a rejoin: the gate on the client, the travel list and the hits. Tasks 2 and 3 read the live State.
4. **Streaming:** gate and chute models that stream in after the controller starts must still get their per-player state. Task 3 handles `DescendantAdded`.
5. **The 1.5× boost must cover only the roads.** It must not apply on cliff tops above the Express, or on the Crown where the north avenue ends. Task 5 pins the north-avenue cut-off.

## Models in `ServerStorage.MapArt` (done 2026-10-18)
`T.mesh` clones these and scales each to the height the stage asks for. Every model's pivot sits at the middle of its footprint on the ground, and its LookVector is its front.

**Hero props.** `tools/map-v3/Props.luau` builds them from parts in the map-v2 toon style. Copies are tagged `PropBuilder`; rerun it after editing, and it never replaces the owner's art.

| Name | Parts | Notes |
|---|---|---|
| `OreChute` | 13 | "DEPOSIT" sign on the front; the Fields stage adds the `UsePoint` 3 studs in front |
| `FieldGate` | 16 | 30-wide arch; the blank `Panel` gets the field name, and the stage adds `Barrier` + `Sign.Rule` |
| `CliffSegment` | 21 | 60 × 16, front = downhill, ends flush to tile |
| `SlideTube`, `SlideEnd` | 10, 22 | 40-long tileable half-pipe; foam bowl with its mouth at the back |
| `SkyLift`, `DiveCannon` | 27, 20 | lettered "SKY LIFT" and "METEOR DIVE" |
| `StarfallBeacon` | 34 | about 110 tall, with one PointLight |
| `Windmill`, `Lighthouse`, `House`, `MarketStall`, `Crane`, `Tent` | 26, 30, 27, 25, 41, 7 | the Lighthouse has one PointLight |

**Scenery (the owner's).** The Scenery stage maps each slot to one of these and tints it per biome:

| Slot | MapArt name | Parts |
|---|---|---|
| round tree | `Tree` | 10 meshes |
| pine | `Pine tree` | 2 |
| blossom tree | `Blosom tree (too big)` (scale it down) | 2 |
| ash tree (Ember) | `Tree` recoloured charcoal/ember | 10 |
| bush | `LowPolyBushes` | 1 |
| crystal | one random child MeshPart of `CRYSTAL.obj…`; the 15 pieces come in mixed colours, so pick ones that suit each biome | 1 |
| boulder | `Big Stone (Lowpoly)` | 1 |

Don't scatter the old `low poly bush` (403 parts) or `Crystals` (4 PointLights).

Not needed: the Refinery, Gear Hall, Hatchery, Commissary, Leaderboards, crater, rocks and pet models are reused from the archived map.

---

### Task 1: Field gates in Config and `Shared.FieldGate`

**Files:**
- Create: `src/shared/FieldGate.luau`
- Modify: `src/shared/Config/Debris.luau` (the `Field` type gains `Unlock`; four new fields)
- Test: `tests/FieldGate.spec.luau` (new), `tests/FieldTravel.spec.luau:8` (count 4 → 8)

**Interfaces:**
- Produces:
  - `export type Unlock = { Level: number? , Rebirths: number? }`
  - `Debris.Field.Unlock: Unlock?`
  - `FieldGate.isOpen(field: Debris.Field, level: number, rebirths: number): boolean`
  - `FieldGate.label(field: Debris.Field): string`

- [ ] **Step 1: Write the failing spec** `tests/FieldGate.spec.luau`
```lua
local Gate = require(t.shared.FieldGate)
local find = require(t.shared.FieldTravel).find
t.test("rust is open to a new player", function() t.ok(Gate.isOpen(find("RustWorks"), 1, 0)) end)
t.test("level gates", function()
	t.ok(not Gate.isOpen(find("VioletQuarry"), 11, 0)); t.ok(Gate.isOpen(find("VioletQuarry"), 12, 0))
	t.ok(Gate.isOpen(find("GlassScar"), 40, 0)); t.ok(not Gate.isOpen(find("GlassScar"), 39, 5))
end)
t.test("rebirth gates ignore level", function()
	t.ok(not Gate.isOpen(find("Starfall"), 50, 0)); t.ok(Gate.isOpen(find("Starfall"), 1, 1))
	t.ok(not Gate.isOpen(find("HaloLedge"), 50, 2)); t.ok(Gate.isOpen(find("HaloLedge"), 1, 3))
end)
t.test("labels", function()
	t.eq(Gate.label(find("RustWorks")), "Open"); t.eq(Gate.label(find("FrostYard")), "Level 5"); t.eq(Gate.label(find("HaloLedge")), "Rebirth 3")
end)
t.test("ladder order is the design's", function()
	local ids = {}; for _, f in require(t.shared.Config).Debris.Fields do table.insert(ids, f.Id) end
	t.eq(table.concat(ids, ","), "RustWorks,FrostYard,VioletQuarry,SulfurRidge,EmberShelf,GlassScar,Starfall,HaloLedge")
end)
```
- [ ] **Step 2: Run `Runner("FieldGate")`.** Expect a FAIL with "FieldGate" missing.
- [ ] **Step 3: Add `Unlock` to `Config.Debris.Fields` and add the four new fields.** Use the spec's table values and colours: Ember `(255,106,78)`, Glass `(111,240,224)`, Starfall `(255,143,200)`, Halo `(255,213,74)`. Order the fields as in the test. Implement `FieldGate`. A field with no `Unlock` is open; `Rebirths` is checked before `Level`.
- [ ] **Step 4: Run `Runner("FieldGate")` and `Runner("FieldTravel")`** (after changing its count to 8), then `Runner()` for everything. Expect all PASS.
- [ ] **Step 5: Commit** `feat(map-v3): field unlock ladder in Config.Debris + Shared.FieldGate`

### Task 2: Server enforcement of locked fields

**Files:**
- Modify: `src/server/Services/DebrisService.luau` (`_track` register def, `TravelTo`, new `_ejectLoop` started in `KnitStart`)
- Test: `tests/DebrisService.regression.luau` (add a case)

**Interfaces:**
- Consumes: `FieldGate.isOpen` (Task 1); `PlayerStateService:Get(player)` → `{ level, rebirths, ... }`.
- Produces: `DebrisService:IsFieldOpen(player: Player, id: string): boolean`, for server callers. The client (Task 3) uses `FieldGate` on its State snapshot instead.

- [ ] **Step 1: Write the failing regression case.** For a player whose data is `{ level = 1, rebirths = 0 }`, following the file's existing fake-player pattern:
  - `TravelTo` to `"GlassScar"` returns false.
  - `IsFieldOpen(player, "RustWorks")` is true.
  - `NodeService:PetHit(player, <a GlassScar rock id>, 1)` returns false.
- [ ] **Step 2: Run it.** Expect a FAIL, because `IsFieldOpen` is nil.
- [ ] **Step 3: Implement.**
  - `IsFieldOpen` reads the server profile.
  - `_track` passes `CanHit = function(player) return self:IsFieldOpen(player, field) end`, but only for rocks whose `Field` is a gated field. Filler rocks pass no `CanHit`.
  - `TravelTo` returns false when the field is closed.
  - `_ejectLoop`, every 0.5 s: for each player whose root is over a closed field's `FieldFloor` box (grown by 2 studs in X/Z, any Y up to floor + 40), `PivotTo` the field's `Entrance` part CFrame + 4 studs up.
- [ ] **Step 4: Run the regression and `Runner()`.** Expect all PASS. Then in Play with `DevLevel` set to 1, a swing at a Violet rock does nothing, and ORE → Violet is refused.
- [ ] **Step 5: Commit** `feat(map-v3): server refuses hits, travel and presence on locked fields`

### Task 3: Client gates and the ORE list show locks

**Files:**
- Create: `src/client/Controllers/FieldGateController.luau`
- Modify: `src/client/Controllers/FieldTravelController.luau` (row text and colour for locked fields)

**Interfaces:**
- Consumes: the State snapshot's `level` and `rebirths` (same source as the HUD level badge); `FieldGate.isOpen` / `label`.
- Map contract it reads: `Map.Gates.<FieldId>` is a Model with a `Barrier` part and a `Sign` part with a SurfaceGui `TextLabel` named `Rule`.

- [ ] **Step 1: Implement the controller.**
  - On every State change, and on `Map.Gates` `DescendantAdded` (streaming), set each barrier's `CanCollide` and `Transparency` (0.35 when closed; 1 and non-colliding when open).
  - Set `Rule.Text` to `FieldGate.label` when closed, or "OPEN" when open.
  - The client-only collision is cosmetic; Task 2 is the authority.
- [ ] **Step 2: Implement the travel list.** Closed rows show `"<Name> · <label>"`, use the disabled colour already used in that file, and don't call `TravelTo`.
- [ ] **Step 3: Verify in Play.**
  - At level 1, the Frost gate is solid with "Level 5".
  - `DevLevel` 5 opens it within one State flush, without a rejoin.
  - The ORE list greys out Violet and the fields after it.
- [ ] **Step 4: Commit** `feat(map-v3): per-player gate barriers and locked ORE rows`

### Task 4: Chutes are refinery points

**Files:**
- Modify: `src/shared/WorldMap.luau` (`refineryPoints`)
- Test: `tests/WorldMap.spec.luau`

**Interfaces:**
- Produces: `WorldMap.refineryPoints(root)` returns the Refinery point, then the Commissary point, then every `Map.Chutes.<Name>.UsePoint` (BasePart), sorted by name.

- [ ] **Step 1: Write the failing case.** Build a fake root (Folder) with `TownSquare.Refinery` (Model + UsePoint) and `Chutes.RustWorks` / `Chutes.FrostYard` (Models + UsePoints). Expect 3 points; the first is the Refinery's; the order of the rest is FrostYard, RustWorks.
- [ ] **Step 2: Run `Runner("WorldMap")`.** Expect a FAIL with count 1.
- [ ] **Step 3: Implement** in `refineryPoints` only. `RefineryService` already hangs the prompt on every point it returns (`RefineryService.luau:225`), and `canUseRefinery` already loops over them.
- [ ] **Step 4: Run `Runner()`.** Expect all PASS.
- [ ] **Step 5: Commit** `feat(map-v3): every Map.Chutes UsePoint is a deposit point`

### Task 5: Geometry for the 1080 map and the fast lanes

**Files:**
- Modify: `src/shared/WorldGeometry.luau` (rewrite the Settings below the scaling block; delete `Quarters`, `Fan`, `quarter`, `quarterAt`, `fanCoords`, `fanHalf`, `inFan`, `onLandmark`, `fieldZone`)
- Modify: `src/shared/CharacterSpeed.luau` (`onRoad`)
- Test: `tests/WorldGeometry.spec.luau` (replace the compact-layout and fan cases), `tests/CharacterSpeed.spec.luau`, `tests/WorldBoundary.spec.luau` (boundary values)

**Interfaces:**
- Produces:
  - `Settings.BoundaryHalf = 540`
  - `Settings.Tiers = { { id = "T0", inner = 0, outer = 250, y = 0 }, { id = "T1", inner = 266, outer = 360, y = 16 }, { id = "T2", inner = 372, outer = math.huge, y = 32 } }`
  - `Settings.Crown = { x0 = -150, x1 = 150, z0 = 400, z1 = 530, y = 56 }`
  - `Settings.ExpressRadius = 280`, `Settings.ExpressWidth = 16`
  - `Settings.Avenues = { width = 24, from = 143, angles = { 0, 45, 90, 135, 180, 225, 270, 315 } }`, with the north avenue ending at `Crown.z0`
  - `WorldGeometry.tierAt(x: number, z: number): string` ("T0", "T1", "T2", "Crown" or "Cliff")
  - `Zones` keeps the town ids, at the plan's positions (Task 6 generates the numbers; copy them in by hand once)

- [ ] **Step 1: Write the failing cases.**
  - `CharacterSpeed.onRoad(0, -134)`, `onRoad(280, 0)` and `onRoad(300 * cos 45°, 300 * sin 45°)` are true.
  - `onRoad(0, 450)` is false (the Crown, past the north avenue's end), and so is `onRoad(200, 50)` (the middle of a T0 slice).
  - `tierAt(0, -150)` is "T0", `tierAt(0, 300)` is "T1", `tierAt(0, 465)` is "Crown", `tierAt(0, 258)` is "Cliff".
  - `BoundaryHalf` is 540.
  - Every `Zones` entry still clears `LandingRadius + 4` and the walls.
- [ ] **Step 2: Run `Runner("WorldGeometry")` and `Runner("CharacterSpeed")`.** Expect a FAIL.
- [ ] **Step 3: Implement.** `onRoad` is true on either ring (same margin rule as today) or within `width/2 + RoadMargin` of an avenue's centre line, between `from` and the avenue's end.
- [ ] **Step 4: Run `Runner()`.** Expect all PASS. `WorldBoundary` keeps its crater kill rule untouched.
- [ ] **Step 5: Commit** `feat(map-v3): 1080 geometry, tiers, Express ring and avenue fast lanes`

### Task 6: Plan data for the Studio stages

**Files:**
- Modify: `tools/map-v3/plan.py` (add `--luau <path>`)
- Create (generated, committed): `tools/map-v3/PlanData.luau`

**Interfaces:**
- Produces: `PlanData.luau` returns `{ footprints = { { tag: string, label: string, kind: string, cell: string, x: number, z: number, w: number, d: number, yaw: number, color: string, band: string, field: string? } }, scenery = { same shape } }`.
  - `yaw` is the item's `rot` in degrees, so a box faces the crater.
  - `field` is set for `kind == "rock" | "gate" | "chute"`, from the cell-to-field mapping: T0-WSW → RustWorks, T0-ESE → FrostYard, T1-WNW → VioletQuarry, T1-ENE → SulfurRidge, T2-WNW → EmberShelf, T2-ENE → GlassScar, Crown rocks with x < 0 → Starfall, x > 0 → HaloLedge.

- [ ] **Step 1: Add the export.** Write numbers with 2 decimals, LF endings. Keep the script's existing self-checks; the export runs only after they pass.
- [ ] **Step 2: Run** `python tools/map-v3/plan.py .tmp/caldera.dc.html --luau tools/map-v3/PlanData.luau`. Expected output: `OK: 309 designed footprints + 3181 scenery`.
- [ ] **Step 3: Verify in Studio.** Load the file over the tools HTTP server; `#footprints == 309` and `#scenery == 3181`. Every one of the 8 field ids has at least 6 rocks and exactly 1 chute.
- [ ] **Step 4: Commit** `feat(map-v3): plan generator exports PlanData.luau`

### Task 7: Sky Lift and Meteor Dive

**Files:**
- Create: `src/shared/DiveArc.luau`, `src/server/Services/CrownService.luau`
- Modify: `src/shared/Config/init.luau` + new `src/shared/Config/Crown.luau` (`LiftRebirths = 1`, `DiveApex = 60`, `DiveTarget = Vector3.new(0, 4, 96)`, `PromptRange = 10`)
- Test: `tests/DiveArc.spec.luau`

**Interfaces:**
- Produces:
  - `DiveArc.velocity(from: Vector3, to: Vector3, apex: number, gravity: number): Vector3` is the launch velocity of a ballistic arc that peaks `apex` studs above `from` and lands on `to`.
  - Map contract: `Map.Crown.Lift.Prompt` (BasePart), `Map.Crown.LiftTop` (BasePart), `Map.Crown.DivePad` (BasePart).

- [ ] **Step 1: Write the failing spec.** For `from` (−30, 60, 475), `to` (0, 4, 96), apex 60 and gravity 196.2, simulate in steps of 1/240 s. The path reaches y ≥ from.Y + 59.5 and lands within 3 studs of `to` in X/Z.
- [ ] **Step 2: Run `Runner("DiveArc")`.** Expect a FAIL.
- [ ] **Step 3: Implement `DiveArc`, then `CrownService`.**
  - The lift's ProximityPrompt checks `rebirths >= Config.Crown.LiftRebirths` on the server, then `PivotTo(LiftTop.CFrame + 4 up)`.
  - When the Dive pad is touched by a Humanoid's root, at most once every 2 s per player, the service sets the root's `AssemblyLinearVelocity` to `DiveArc.velocity(root.Position, Config.Crown.DiveTarget, Config.Crown.DiveApex, workspace.Gravity)`.
- [ ] **Step 4: Run `Runner()`.** Expect all PASS. In Play, rebirth 0 is refused at the lift; after `DevGrant` rebirth 1 the lift works, and the Dive lands on the north terrace rim.
- [ ] **Step 5: Commit** `feat(map-v3): Crown lift (Rebirth 1) and Meteor Dive`

### Task 8: Stage `Ground` and `Roads`

**Files:**
- Create: `tools/map-v3/Ground.luau`, `tools/map-v3/Roads.luau`, `tools/map-v3/README.md`
- Reuse: `tools/map-v2/Common.luau`, `Brick.luau`, `Toon.luau` (loaded first, as in map-v2's README); `tools/map-v2/Boundary.luau` (already reads `G.BoundaryHalf`; its budget assert of 2,700 is raised to 20,000 here)

**Interfaces:**
- Consumes: `WorldGeometry.Settings` (Task 5).
- Produces:
  - Under `Map_Redesign`: `Ground` (the T0 disc and T1/T2 rings as 16-sided slab segments, plus T2 fill to the walls), `Cliffs` (48 `CliffSegment`s), `Crown` (plateau), and `Roads`:
    - `Ring`, `Express`
    - `Avenue_<angle>`, each with a gold `FastStrip` and, where an avenue crosses a cliff, a ramp at most 18° steep
    - `Slide_<angle>`, smooth plastic and friction 0 (`CustomPhysicalProperties`)
    - six `SpawnLocation`s at the contract grid
  - `Boundary` at ±540.

- [ ] **Step 1: Write both stages in the map-v2 style:** an ownership check, then chunked creation with `task.wait()`.
- [ ] **Step 2: Run them.** Serve `tools` (`python -m http.server 8123 --bind 127.0.0.1 --directory tools`), then `L("Common"); L("Brick"); L("Toon"); L("../map-v3/Ground"); L("../map-v3/Roads"); L("Boundary")` in Edit mode.
- [ ] **Step 3: Verify.**
  - Screenshots from (0, 300, −700) looking at the origin, and top-down from (0, 900, 0), match the canvas master plan.
  - The character walks up every ramp without jumping.
  - A slide from T2 reaches the ring road in under 10 s.
- [ ] **Step 4: Commit** `feat(map-v3): ground, cliffs, crown, roads, slides, boundary stages`

### Task 9: Stage `Core`: reuse the contract models

**Files:**
- Create: `tools/map-v3/Core.luau`

**Interfaces:**
- Consumes: `ServerStorage.SwapRollback.Map_v8`; positions from `WorldGeometry.Zones` (Task 5).
- Produces in `Map_Redesign`:
  - `Crater` (cloned whole, untouched)
  - `CraterApron` (cloned; drop children outside r 124)
  - `TownSquare.Refinery` (cloned, same pivot)
  - `TownSquare.Commissary` (cloned, pivoted to the T0-ENE slice)
  - `TownSquare.Leaderboards.<Id>` (pivoted to the plan's two boards)
  - `GearHall` and `Hatchery` (cloned, pivoted to the T0-SSE and T0-SSW slices, facing the crater)

- [ ] **Step 1: Implement.** Pivot each clone so its front faces the origin. Keep `TierWalls` and `CurrentStands` intact.
- [ ] **Step 2: Verify.** Contract paths resolve under `Map_Redesign`; `WorldMap.refineryPoints(Map_Redesign)` returns 2 points before the chutes exist; part count is printed.
- [ ] **Step 3: Commit** `feat(map-v3): core contract models placed from the archived map`

### Task 10: Stage `Fields`

**Files:**
- Create: `tools/map-v3/Fields.luau`

**Interfaces:**
- Consumes: `PlanData.footprints` with `field` set (Task 6); the rock templates (each root with `RockChunk` + `OreFleck` children) from `SwapRollback.Map_v8.Debris`.
- Produces:
  - `Map_Redesign.Debris`: one rock root per plan rock, with attribute `Field = <id>`, sized to the footprint and at its tier's Y.
  - `DebrisFields.<Id>`: `FieldFloor` (a thin, invisible, non-colliding box under the field's rocks), `Entrance` (at the gate, facing out).
  - `Gates.<Id>`: `FieldGate` mesh or fallback, plus a `Barrier` and a `Sign.Rule` for Task 3. Rust Works has no barrier.
  - `Chutes.<Id>`: `OreChute` mesh or fallback, plus a `UsePoint` 3 studs in front.

- [ ] **Step 1: Implement.** Rock templates are picked by a seeded `Random(<field index>)`.
- [ ] **Step 2: Verify.**
  - In Play (`DevMemoryStore`), ORE travel lands on each open field.
  - A Rust rock breaks in 4 hits.
  - Depositing works at every chute.
  - Task 2's eject fires on a locked field.
- [ ] **Step 3: Commit** `feat(map-v3): eight fields, gates and chutes from PlanData`

### Task 11: Stage `Districts`: designed footprints

**Files:**
- Create: `tools/map-v3/Districts.luau`

**Interfaces:**
- Consumes: `PlanData.footprints` without `field`.
- Produces: one Model per plan cell (`Districts.<cell>`) with `ModelStreamingMode = Atomic`.
  - Each footprint is built by its `tag`/`label` through `T.mesh(parent, <MapArt name>, cf, height, fallback)` or the Toon builders: `T.box` buildings with door and windows facing the crater, `T.tree`, `T.lamp`, `T.crate`, `T.banner`, `T.planter`.
  - Heights: buildings 14–24, props 2–8, the Beacon 120, the Lookouts 40.
  - The Crown contents sit at Y 56, and `Crown.Lift` / `LiftTop` / `DivePad` match Task 7's contract.

- [ ] **Step 1: Implement.** One builder function per tag; anything unknown gets a labelled `T.box` so nothing is silently skipped.
- [ ] **Step 2: Verify.** Screenshots of the town, each T1 slice and the Crown, side by side with the canvas footprint board; every label from the plan is present (count check printed).
- [ ] **Step 3: Commit** `feat(map-v3): districts and crown built from PlanData`

### Task 12: Stage `Scenery`, outer scenery, `StaticQA`

**Files:**
- Create: `tools/map-v3/Scenery.luau`, `tools/map-v3/StaticQA.luau`
- Reuse: `tools/map-v2/Surroundings.luau`, `tools/map-v2/Backdrop.luau`, re-run at the new `BoundaryHalf`. Move `Backdrop`'s fixed sky-island positions (`Backdrop.luau:117`) out by ×2.

**Interfaces:**
- Consumes: `PlanData.scenery`.
- Produces:
  - `Map_Redesign.Scenery.<band>_<wedge>` models (Atomic): every piece is non-colliding and query-free, and uses MapArt scenery meshes when present.
  - `StaticQA` prints parts per top-level model, total parts, MeshParts, lights and emitters. It asserts no scenery `CanCollide`, and that every chute and gate `Entrance` is reachable by a straight raycast-free walk from the nearest avenue.

- [ ] **Step 1: Implement and run** `Scenery` in chunks of 200 with `task.wait()`.
- [ ] **Step 2: Run `StaticQA`.** Expected: 0 failures, total parts reported (target ≤ 20,000), lights ≤ 24, emitters ≤ 32.
- [ ] **Step 3: Commit** `feat(map-v3): scenery, outer scenery and static QA`

### Task 13: Play QA, swap, docs

**Files:**
- Modify: `docs/guide/map-and-world.md`, `tools/map-v3/README.md`, `CLAUDE.md` (the map paragraph points at map-v3), `src/shared/Config/Tutorial.luau` (only if the tutorial's crater/field distances change)

- [ ] **Step 1: Walk through it in Play with `DevWorldMap = "Map_Redesign"` and `DevMemoryStore`.**
  - spawn → Rust in ≤ 12 s
  - every chute deposits
  - every gate refuses, then opens with `DevLevel` / `DevGrant`
  - the slides, lift and Dive work
  - a meteor lands, and the shockwave throws players onto T0 ground
  - console clean
  - a phone-sized window (Device emulator) holds 30+ FPS on the town view
- [ ] **Step 2: Run `require(game.ServerStorage.Tests.Runner)()`.** Expect 0 failed.
- [ ] **Step 3: Swap.** `Map` is already archived as `SwapRollback.Map_v8`. Delete `Map_Redesign.Workbench` (the prop preview at x 6000), then delete `Workspace.Map`, rename `Map_Redesign` to `Map`, clear `DevWorldMap`, and check that `Map:GetAttribute("MapRedesignOwned")` is true.
- [ ] **Step 4: Owner action.** The owner saves the place (Ctrl+S in Edit mode). Do not publish.
- [ ] **Step 5: Update the docs** to the new contracts and stages, then commit `feat(map-v3): swap to Caldera Terraces; docs`.

## Done when
- All specs pass, and StaticQA has 0 failures.
- The Play walk-through list is all ticked.
- The owner has saved the place.
- `SwapRollback.Map_v8` and `assets/archive/map-v2-2026-10-18/` still restore the old map.
