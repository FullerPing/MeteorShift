# MeteorShift

A Roblox game based on the mechanic of mining meteors and other debris around a centralised town.

Every few minutes a meteor slams into the crater in the middle of town and the whole server rushes to mine it before it cools. Crack the core together to earn Core Shards. Between meteors, mine debris around town.

## Status

Week 1 of the MVP plan (the meteor event loop) is in. See the spec in the project thread "Meteor Shift game spec".

- Sky countdown and HUD timer, streak in the sky for the last 10 s, rumble and camera shake
- Impact with shockwave: knockback only, no damage
- Meteor assembled from reusable node pieces: 36 crust nodes around a core
- Node and core HP sized from the server's total mining power at impact
- Per-player ore drops straight into your backpack (50 ore placeholder backpack)
- Core unlocks when 60% of the crust is broken, cooling timer of 2:30
- Server-side contribution tally (core hits count double), core rewards with a 5-shard floor, a contribution share and +10/+6/+3 for the top three, announced to the server
- Debris rocks in town that respawn, yielding ore at a quarter of the meteor rate
- Ore Silo in the town square as a temporary drop-off until plots get hoppers in Week 2

## Layout

```
default.project.json   Rojo project (code only)
Packages/              Knit 1.7, Fusion 0.3, Comm, Promise, Signal, Option (vendored)
src/shared/            ReplicatedStorage.Shared: Config, Format, Phase
src/server/            ServerScriptService.Server: Knit services
src/client/            StarterPlayerScripts.Client: Knit controllers, Fusion HUD
assets/                Studio exports of everything built in Studio (see below)
```

Server services: `MeteorService` (schedule and state machine), `NodeService` (HP, swing validation, ore drops), `ContributionService`, `RewardService`, `DebrisService`, `PlayerStateService` (in-memory placeholder until the Week 2 DataService), `SiloService`.

Client controllers: `MiningController`, `MeteorFXController`, `HUDController`.

All tuning numbers live in `src/shared/Config`.

## The map lives in the place, not in code

Nothing builds the world at runtime. The crater town, plots, debris rocks, sky countdown board, meteor node pieces and the pickaxe are real instances saved in the place:

| Instance | What it is |
|---|---|
| `Workspace.Map` | Ground, crater, town square (Ore Silo, Trading Post, Pickaxe Shop, spawn), 20 plots, roads, debris rocks, trees, boundary cliffs |
| `ServerStorage.Assets` | Meteor core (with `NodeSlot` attachments) and the crust node pieces |
| `StarterPack.Pickaxe` | The Basic Pickaxe tool |

The only thing spawned at runtime is the meteor itself, cloned from `ServerStorage.Assets` when it lands.

`default.project.json` only syncs code, so Rojo never touches the map. Edit the map in Studio and save the place. `assets/*.rbxm` are Studio exports of the same instances, kept in git as a backup; use Studio's *Insert from File* to restore them. (Rojo 7.6 can't read the newest Studio binary format, so they aren't wired into a Rojo project.)

## Working on it

1. Open the saved place in Studio.
2. `rojo serve` in this folder, then connect from the Rojo plugin.
3. Play. In Studio the countdown is shortened to 25 s (`Config.Meteor.StudioCountdown`, set it to `nil` for the real 2:00 / 4:00 timings), and a **[Studio] Meteor now** button skips to the last 10 s.
