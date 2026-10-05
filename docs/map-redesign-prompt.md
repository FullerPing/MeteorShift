# Map redesign + 2x meteor (headless)

You know the whole game. Branch `job-for-tomorrow` only, never publish, never open a PR. No time or token limit; the only goal is a great map. If a rate limit or crash stops you, restart as soon as it refreshes and continue.

## Do
1. **Full map redesign in a simulator/tycoon style**: chunky, bright, saturated, lots of visible studs, bevelled blocky props, clear landmarks and big readable signs. Original art only. Mobile-friendly budgets.
2. **Meteor at least 2x as big** (all linear dimensions): scale `Assets.Meteor.Core` (NodeSlots, Veins, lights, emitters) and `NodePieces`, enlarge the crater so the crust (~47 studs now) fits with a walking ring, keep every node reachable with a Basic Pickaxe (terraces/ramps, not rule changes), and update the geometry numbers (`Config.LandingFX.Crater` and its radii/diameters, `Meteor.Knockback.Radius`, `Tutorial.CraterRadius`, debris radii) and the specs that encode them. HP does not change. Scale impact FX, shake and sound too, and check Iron, Ice and Crystal.
3. **Remove plots** and everything plot-only (pads, signs, beacons, `PlotStations`, plot fallbacks in `PlotService`/`RefineryService`/`UpgradeService`/`HomeController`). The shared Refinery is the economy hub: make it a landmark outside the knockback and landing radii, facing the crater, keeping its `UsePoint`.
4. **Live equipment shop ("Gear Hall")**: counter named `PickaxeShop` (opens the existing shop), two stands that show the local player's current pickaxe and backpack (`Shared.EquipmentModels`), rotating and updating the moment the tier changes, with world SurfaceGui stats from State, plus a tier wall of all 8 pickaxes and 8 backpacks marked unlocked/current/locked. New world-space client controller only; pure helper for the states with a spec; everything generated from Config.
5. Other zones: spawn plaza with several spawn pads, hatchery (egg pedestals with odds boards generated from `Config.Pets.Eggs`, decor only), rebirth monument, Index museum, 3-4 themed debris fields, sealed boundary with kill plane. Paths at least 14 studs wide (pets follow), sized for 30 players.

## Hard rules
- **Frozen: all GUI** (the owner just changed it): `UI`, `HudView`, `HudLayout`, `Config.Hud`, `EquipmentShopLayout`, and the Shop/Refinery/Store/Index/Rebirth/Settings/HUD/tutorial-panel controllers. Check `git status`/`git diff` and never discard uncommitted work. If something needs a GUI change, put it in the report.
- Keep the map contracts the code uses: `Map.Crater.MeteorSpawn`, `Crater.ActiveMeteor`, `Map.Debris`, `TownSquare.Refinery` (+`UsePoint`), `PickaxeShop`, `TradingPost.SellPoint`, `Map.Atmosphere`, spawns, the `Assets` templates.
- No economy, odds or monetization changes. Never skip or weaken a test.

## How to run it
- Keep `docs/map-redesign/PLAN.md` and `PROGRESS.md` (checklist, next action). On every start read them, `git status` and the open place, then continue from the first unchecked item; stages must be re-runnable.
- **Plan first, then approve it yourself**: measure the current world (crater, Core and NodeSlot sizes, parts/triangles/lights/emitters, frame time), then write a plan with the layout (coordinates, footprints, `layout.svg`), style guide (palette, stud approach), the 2x maths, numeric budgets, code change list, test plan and rollback. Review it like a sceptical second engineer; only when it covers every contract, has no frozen file, every zone has an entrance and a path, the Refinery is outside the new radii, and budgets are numeric, write `APPROVED by self` at the top and start.
- Back up `assets/Map.rbxm`, `Terrain.rbxm`, `ServerAssets.rbxm`, `Lighting.rbxm` to `assets/archive/before-redesign/` first. **Build under `Workspace.Map_Redesign`, never in place**; swap (old to `Map_Old`, new to `Map`) only after QA passes, re-run QA, then delete `Map_Old`. Save the place (never publish), commit and push a checkpoint after every stage.

## QA before the swap (Studio, Play)
Test runner fully green; empty Output; pathfinding and walking from every spawn to every interactive point, ramps jump-tested, nobody can leave or get stuck; Iron/Ice/Crystal meteors at 2x (reachable nodes, survivable shockwave, effects fit the crater); debris, refinery, selling, shop, pets, tutorial from a fresh profile, rebirth, rejoin; phone sizes 320x568, 390x844, 844x390; performance at event time with many pets and effects, inside budget; exploit check (can't stand under/outside the map or reach the crater from outside); no leftover plot references or QA fixtures that change player data in any Script.

## Polish
At least three critique-and-fix rounds with screenshots of every zone, scoring 1-5 on silhouette/landmarks, colour, stud consistency, scale, density, signage, navigation, reward feel and performance; fix anything under 4; stop when everything is 4+ two rounds in a row.

## Finish
Export the four `.rbxm` assets, update the README (plots gone, 2x meteor, Gear Hall, restore steps) and `tools/` docs if authoring changed, and write `docs/map-redesign/REPORT.md` (built, final numbers, assumptions, unverified items, GUI follow-ups, what to look at first). If the swap breaks the game and you can't fix it fast, roll back to `Map_Old` and say so.
