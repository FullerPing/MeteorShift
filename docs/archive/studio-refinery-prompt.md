# Prompt for the Studio AI: place the shared refinery

Copy everything below the line into the other AI instance (the one connected to Roblox Studio with the MeteorShift place open).

---

You are working in Roblox Studio on the MeteorShift place (a meteor-mining game). Your job is to build and place ONE shared refinery building in the town. Game code already exists and reads this building by name; you only create the model in the world. Do not edit, create or delete any scripts. Do not delete or move plots, the crater, debris, the fountain, the spawn or anything else that already exists.

## What the game code expects

- A Model named exactly `Refinery`, parented to `Workspace.Map.TownSquare` (create nothing else under that name). Set its `PrimaryPart`.
- Inside it, an anchored BasePart named exactly `UsePoint`: the spot a player walks up to. Put it on the building's front, about 3 studs above the ground, size about 6 x 1 x 6, `Transparency = 1`, `CanCollide = false`, `CanTouch = false`. Do NOT add a ProximityPrompt; the server creates it (named `UseRefinery`) on `UsePoint` at runtime.
- Do not name anything `ManageRefinery`, `Upgrade` or `Intake`, and do not put ProximityPrompts or Scripts anywhere in the model.
- Set the attribute `SharedRefinery = true` on the `Refinery` model (documentation only).

## What it is

Every player uses this one building to deposit their ore, collect their bars and open their refinery panel (a screen UI, nothing to build in 3D for that). It must read at a glance as the town's refinery: a chunky industrial building with a hopper on top or side, a conveyor, a furnace/smelter body with a chimney that has smoke or glow, and a big readable sign saying `REFINERY`. Match the existing look (dusty late-afternoon colours, basalt/metal materials, warm orange glow accents). Reuse art where you can: `ServerStorage.Assets.PlotStations` holds the per-plot production line (hopper, conveyor, refinery, collection post). Clone parts from it, strip any ProximityPrompts, BillboardGuis with live text and scripts from the clones, and arrange them into one larger structure (scaling up about 1.5x is fine). Keep it under about 300 parts, all `Anchored = true`. Decorative ParticleEmitters/PointLights are fine; keep them cheap.

## Where to put it

Measure first, then decide, and tell me the numbers you used.

1. Find the crater centre: `Workspace.Map.Crater.MeteorSpawn` (its Position, ignore Y).
2. Place the building on the town side, horizontal distance from MeteorSpawn between 95 and 120 studs. It must be OUTSIDE 80 studs on purpose (the tutorial counts "reached the crater" within 80 studs) and well outside the meteor impact zone and its knockback ring.
3. It must not touch or block: the roads/paths, the player spawn, the fountain/plaza centre, the plot pads and their fences (`Workspace.Map.Plots`), the debris rocks (`Workspace.Map.Debris`), or the mining area around the crater. Keep at least 12 studs of walkable clearance around the front where players stand.
4. Face the front (the side with `UsePoint`) toward the crater so players coming from the meteor run straight into it. Put the building on the ground (raycast down to find the surface); do not float or sink it.
5. Prefer a spot on or beside the town square plaza if one exists in that distance band; otherwise the nearest flat ground that satisfies everything above.

## Checks to do before you finish

- In Edit mode, confirm `Workspace.Map.TownSquare.Refinery` exists, has a `PrimaryPart`, contains exactly one part named `UsePoint`, and contains no Scripts, ProximityPrompts or Humanoids.
- Run a Play test: after the server starts there must be NO warning containing `[RefineryService]` in the output. Walk to `UsePoint`; a "Use refinery" prompt should appear within 14 studs. Press E: the refinery panel opens. (If you cannot open the panel, report what the output says.)
- Confirm players cannot walk through the building but can walk around it, and that a character standing at the front is not stuck.
- Confirm there is nothing new within 80 studs of `MeteorSpawn`, and that the building is not inside the impact knockback radius (90 studs, mostly visual).
- Check on a phone-sized viewport (about 844 x 390) that the sign is readable from 40 studs away.

## Finish

- Save the place (File > Save) so the model persists. Do not publish.
- If your tools allow it, also export the model to `assets/Refinery.rbxm` in the repository folder.
- Report back in plain text: the position (X, Y, Z) of `Refinery:GetPivot()`, the distance from `MeteorSpawn`, the part count, anything you reused from `PlotStations`, any check that failed, and anything you were unsure about.
