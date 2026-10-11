# Handoff: improve the map models (art only)

> **Status (8 Oct 2026, late): done in Studio, unsaved.** Every stage after `Roads` was rebuilt in a cartoon-simulator style with the new `tools/map-v2/Toon.luau` (see the README's "Style rules"). 1,991 parts, StaticQA and specs pass, Play checks pass. Rollback: `ServerStorage.SwapRollback.Map_v3`. Still open: hero meshes in `ServerStorage.MapArt` (the stages use parts fallbacks), a spawn-plaza welcome arch (skipped to keep the view from the spawn to the Refinery clear), phones and real-device performance. The notes below describe the state before the pass.

**Goal:** make the buildings, ore fields, props and walls look much better. **Do not change** the layout, the crater/meteor, the HUD or any gameplay. The owner likes all three of those as they are; they dislike the actual models (too plain, boxy, repetitive).

## Read first
- `tools/map-v2/README.md`: layout, authoring order, contracts, rollback.
- `tools/map-v2/Common.luau` and `Brick.luau`: the helpers (`A.part`, `A.box`, `A.cylinder`, `A.studGrid`, `A.signOn`, `A.frameFor`).
- One stage per area: `GearHall`, `Hatchery`, `TradingPost`, `Rebirth`, `Refinery`, `DebrisFields`, `Scenery`, `Boundary`, `Surroundings`, `Backdrop`.
- `src/shared/WorldGeometry.luau`: zone footprints. Keep art inside its zone (`A.within` asserts it).

## Hard limits (a stage fails or the game breaks if broken)
- **Part budget 2,200 for the inner map (owner: 2,000-2,200 is fine), currently 1,638; the outer scenery (`Boundary`, `Surroundings`, `Backdrop`, i.e. everything beyond the playable area) has its own 1,400 (currently 1,257).** About 560 inner parts are free. The caps live in the tool asserts (`Roads`, `Boundary`, `Scenery`, `Surroundings`, `StaticQA`) and `docs/map-redesign/PLAN.md`. The per-building art caps inside each stage (Gear Hall 110, Hatchery 90, Trading Post and Rebirth 60, Refinery 180, fields 420, Scenery 520) are separate; raise the ones you need, but spend the budget where players look (buildings, fields), not on more scenery.
- 0 MeshParts, 0 scripts, everything anchored, at most 12 enabled lights (shadows off), at most 16 emitters.
- Gameplay contracts (names and attributes, see the README): `Refinery.UsePoint` (one, at most 180 parts), `PickaxeShop.ShopPoint`, `TradingPost.SellPoint` + prompt, `RebirthMonument.RebirthPoint`, `GearHall.TierWalls` (16 cards) and `CurrentStands` (2), Hatchery egg pedestals with `EggId` and their Config-driven `OddsCard` billboards (the Hatchery is now an open egg garden with an EGGS title, no building), 48 `Debris` roots with attr `Field`, `DebrisFields.<Id>.FieldFloor` + `Entrance`, six enabled spawns, `Boundary.KillPlane`.
- Keep the 14-stud aisles between ore rocks, the crater's four cardinal corridors free of upright props, and everything at least 129 studs from the crater centre.
- Each stage owns only its named groups and is re-runnable.

## Workflow that works
1. Serve tools: `python -m http.server 8123 --bind 127.0.0.1 --directory tools`. To push repo source into Studio when Rojo is not syncing, serve the repo root on another port and set `.Source` from `HttpService:GetAsync`.
2. Studio MCP, Edit mode, Play stopped. Rename `Workspace.Map` to `Map_Redesign` (the tools only find that name), run the stages (README order, then `StudStyle`, then `StaticQA`), rename back to `Map`.
3. Back up first: `ServerStorage.SwapRollback.Map_v2` already holds the pre-relayout map; clone `Map` again before a big change.
4. Look at it. Edit-mode `screen_capture` of a scripted camera comes out wrong. In Play, bind the camera every frame: `RunService:BindToRenderStep("cap", Enum.RenderPriority.Last.Value, function() cam.CameraType = Scriptable; cam.CFrame = _G.CapCF end)` and set `_G.CapCF`. Disable the ScreenGuis for clean shots. Foreground the Studio window with `SetForegroundWindow` first. Overhead view: `CFrame.lookAt(Vector3.new(0,560,0), Vector3.zero, Vector3.new(0,0,1))`. This view has screen-right = world **-X**.
5. Verify: `StaticQA` (84 routes, 0 failures), `Runner()` in Edit (484 passed), a Play walk, and a console with no errors.

## What to improve (owner's complaint: the models)
- Buildings read as flat boxes with a sign. Give each a distinct silhouette, depth (set-back windows, trim, awnings, props at the door), colour variety and brick detail. Gear Hall, Hatchery, Refinery, Rebirth and Trading Post first.
- The four ore fields share one template (floor plate, rocks, small landmark). Make each biome feel different and bigger.
- Props are generic (bushes, trees, benches). Use fewer, better-composed groups.
- Walls and surroundings: the stepped mountain ring and the sea islands are very plain.
- Review every zone from ground level, not only from above. Aim to raise anything that scores under 4/5 on silhouette, colour, studs, scale, signage and navigation.

## Not done or unknown
Phones, real-device performance, hands-on mining reach for all 36 crater nodes. Nothing is committed; the owner saves and publishes from Studio (the map lives in the place file, not git). Rojo may need reconnecting in Studio.
