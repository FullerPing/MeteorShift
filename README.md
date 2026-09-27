# MeteorShift

A Roblox game based on the mechanic of mining meteors and other debris around a centralised town.

Every few minutes a meteor slams into the crater in the middle of town and the whole server rushes to mine it before it cools. Crack the core together to earn Core Shards. Between meteors, mine debris around town.

## Status

Weeks 1 and 2 of the MVP plan are in, plus a round of polish on the plots and the meteor. See the spec in the project thread "Meteor Shift game spec".

**Week 1, the meteor event**
- Sky countdown and HUD timer, streak in the sky for the last 10 s, rumble and camera shake
- Impact with shockwave: knockback only, no damage
- Meteor assembled from reusable node pieces: 36 crust nodes around a core
- Node and core HP sized from the server's total mining power at impact
- Per-player ore drops straight into your backpack
- Core unlocks when 60% of the crust is broken, cooling timer of 2:30
- Server-side contribution tally (core hits count double), core rewards with a 5-shard floor, a contribution share and +10/+6/+3 for the top three, announced to the server
- Debris rocks in town that respawn, yielding ore at a quarter of the meteor rate

**Week 2, the home loop**
- Saved profiles (schema v1) with a session lock, autosave every 60 s, save on leave and shutdown
- A free plot on join, with your name on the sign and a "YOUR PLOT" beacon
- Hopper: step on the green DROP ORE pad to empty your backpack into it (2,000 ore at level 1)
- Refineries turn 1 ore into 1 bar over time (0.25 ore/s at level 1); step on a bin to collect all bars
- Offline income: refineries keep working on your hopper for up to 2 hours while you're away, with a "While you were away" panel on return
- Sell bars at the Trading Post counter (Iron bar = $5)

**Round 3, plots and meteor polish**
- Plots start empty. When you join, a production line is placed on your plot: hopper, conveyor, refinery, collection post. It is removed when you leave.
- Ore rides the conveyor while the line runs. The line makes min(conveyor rate, refinery rate) bars per second and stops when the collection post is full.
- All four stations are upgradable from a prompt on each (F): hopper and collection post raise capacity, conveyor and refinery raise speed. Higher levels also cost Core Shards.
- Bigger plots (52 x 52) on a wider ring, with the outer wall pushed out and reshaped into a natural slope
- New meteor look: a dark core with glowing veins and embers, crust made of ore clusters with metal crystals and glowing bits
- Health bars over meteor clusters, the core and debris rocks (shown when damaged or when you are close)
- Profiles migrate from schema v1 to v2 (station levels, one hopper and one collection post)

## Layout

```
default.project.json   Rojo project (code only)
Packages/              Knit 1.7, Fusion 0.3, Comm, Promise, Signal, Option (vendored)
src/shared/            ReplicatedStorage.Shared: Config, Format, Phase
src/server/            ServerScriptService.Server: Knit services
src/client/            StarterPlayerScripts.Client: Knit controllers, Fusion HUD
assets/                Studio exports of everything built in Studio (see below)
```

Server services: `MeteorService` (schedule and state machine), `NodeService` (HP, swing validation, ore drops), `ContributionService`, `RewardService`, `DebrisService`, `DataService` (profiles), `PlayerStateService` (gameplay rules over the profile), `PlotService`, `RefineryService` (the production line, offline catch-up), `UpgradeService` (station upgrades), `EconomyService` (selling). `src/server/Lib` holds the profile template and the pure refinery simulation.

Client controllers: `MiningController`, `MeteorFXController`, `HUDController`, `HomeController`, `NodeHealthController`.

All tuning numbers live in `src/shared/Config`.

## The map lives in the place, not in code

Nothing builds the world at runtime. The crater town, plots, debris rocks, sky countdown board, meteor node pieces and the pickaxe are real instances saved in the place:

| Instance | What it is |
|---|---|
| `Workspace.Map` | Ground, crater, town square (Trading Post with sell counter, Pickaxe Shop, spawn), 20 empty plot pads with signs, roads, debris rocks, trees, boundary cliffs |
| `ServerStorage.Assets` | Meteor core (with `NodeSlot` attachments and glowing `Vein` parts), the ore cluster pieces, and `PlotStations` (the production line template) |
| `StarterPack.Pickaxe` | The Basic Pickaxe tool |

Two things are cloned at runtime from `ServerStorage.Assets`: the meteor when it lands, and a player's production line (`PlotStations`) when they claim a plot. The plot pads themselves stay in Workspace.

`default.project.json` only syncs code, so Rojo never touches the map. Edit the map in Studio and save the place. `assets/*.rbxm` are Studio exports of the same instances, kept in git as a backup; use Studio's *Insert from File* to restore them. `assets/Terrain.rbxm` holds the terrain as a TerrainRegion; restore it with `workspace.Terrain:PasteRegion(region, Vector3int16.new(-160, -32, -160), true)`. (Rojo 7.6 can't read the newest Studio binary format, so they aren't wired into a Rojo project.)

## Working on it

1. Open the saved place in Studio.
2. `rojo serve` in this folder, then connect from the Rojo plugin.
3. Play. Unpublished places can't use DataStores, so profiles are kept in memory for that play session only. In Studio the countdown is shortened to 25 s (`Config.Meteor.StudioCountdown`, set it to `nil` for the real 2:00 / 4:00 timings), and a **[Studio] Meteor now** button skips to the last 10 s. **[Studio] Away 1 hour** runs an hour of offline refining so you can check the "While you were away" panel.
