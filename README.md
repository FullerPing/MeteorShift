# MeteorShift

A Roblox game based on the mechanic of mining meteors and other debris around a centralised town.

Every few minutes a meteor slams into the crater in the middle of town and the whole server rushes to mine it before it cools. Crack the core together to earn Core Shards. Between meteors, mine debris around town.

## Status

Weeks 1 and 2 of the MVP plan are in, plus a round of polish on the plots and the meteor. Week 3 (upgrades and UI) is under way. See the spec in the project thread "Meteor Shift game spec".

**Week 1, the meteor event**
- Sky countdown and HUD timer, streak in the sky for the last 10 s, rumble and camera shake
- Impact with shockwave: knockback only, no damage
- Meteor assembled from reusable node pieces: 36 crust nodes around a core
- Node and core HP run on a hidden Mining Power stat (1.25× per pickaxe tier), so a maxed veteran mines ~8× faster than a newcomer instead of ~900×. Hits still pop the big damage number, and ore per hit still comes from your pickaxe
- HP is sized at impact from players with input in the last 2 minutes (AFK players don't count), never smaller than 4 Basic Pickaxes. If the active crowd's power shifts by more than 15% mid-event, the remaining HP rescales, keeping the same percent done (at most every 10 s)
- Contribution for shards counts Mining Power, so newcomers earn a fair share on top of the 5-shard floor
- Per-player ore drops straight into your backpack
- Core unlocks when 60% of the crust is broken, cooling timer of 2:30
- Server-side contribution tally (core hits count double), core rewards with a 5-shard floor, a contribution share and +10/+6/+3 for the top three, announced to the server
- Debris rocks in town that respawn, yielding ore at a quarter of the meteor rate. Each rock is sized for a random active player's pickaxe (about 4 hits for them), so a lone veteran still gets rocks worth hitting next to newcomers. Rocks for tier 3+ pickaxes have glowing tinted flecks, and untouched rocks re-pick every minute

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
- Health bars over meteor clusters and debris rocks appear only after you hit them, and only on your screen. The core has a big shared bar everyone sees once it is exposed.
- Profiles migrate from schema v1 to v2 (station levels, one hopper and one collection post)

**Week 3, upgrades and UI (in progress)**
- Shop with Pickaxes, Backpacks and Plot tabs, opened from the SHOP button or the Pickaxe Shop in town. Every tier is listed; only the next one can be bought (cash, plus Core Shards at the top tiers), and the server re-checks the price. The Plot tab buys the same station upgrades as the prompts on your plot.
- Your pickaxe tool is renamed after the tier you own; parts in it with a `Tint` attribute take the tier's colour
- HUD shows your pickaxe, the cash counter counts up to the new total, and a "+$" floater rises off it on every sale
- Tutorial (spec §11): 10 steps from "Mine a debris rock" to "Buy an upgrade", each completed by the real action on the server, with a step card, a marker over the target and a beam from you to it. Doing a later step's action first also completes the steps before it, so joining mid-event never gets you stuck. Skippable, saved in the profile (`tutorialStep`), and each step is logged as an onboarding funnel step
- Still to do this week: tutorial and shop polish from playtests

**Meteor types (spec §8.1, in progress)**
- Ice (tier 3 pickaxe, frost ore) and Crystal (tier 5, crystal ore, bars sell at $3,000) meteors fall alongside Iron. Each countdown picks the next type from weighted odds (Iron 60, Ice 25, Crystal 15), but a type only comes up when at least 25% of active players' pickaxes meet its tier, otherwise it drops to the next type down. The sky board and HUD timer name it from the start of the countdown, with the title in the type's glow colour (Iron orange, Ice cyan, Crystal magenta). Types, tier gates and twists are in `Config.Meteor`, the rules in `Shared.MeteorTypes`
- Your own pickaxe decides your ore: the meteor's ore if it meets the meteor's tier, otherwise the best ore it can mine at ×1.25. Debris still drops iron
- Ice twist, Refreeze: a node or core nobody has hit for 5 s regains 2% of its HP per second (never past full); its health bar turns frost blue while it refreezes. Crystal twist, Resonance: each extra player who hit the same node in the last 1.5 s adds +20% Mining Power (HP and contribution) to everyone on it, up to +60%
- The shard bonus pool is multiplied by the type (Ice ×1.5, Crystal ×2). The results panel names the ore your pickaxe mined and, when it was under the meteor's tier, what a better one mines there ("Tier 5 pickaxe mines Crystal: $3K bars")

**Mineral index (spec §8.2)**
- Iron, Ice and Crystal pages, four minerals each. Every hit on a meteor's crust or core can drop one mineral of that meteor's page at fixed odds (1 in 25, 120, 600 and 2,500), only if your own pickaxe meets the meteor's tier; debris never drops minerals and nothing you can buy changes the odds. The rarest mineral of each page only drops from rich nodes: three crust nodes per meteor with gold ore that sparkle
- The INDEX button (under SHOP; hidden while the shop is open and, on narrow screens, while the tutorial card sits under SHOP) opens the book: a tab per page, every mineral as a card ("???" until found) with its odds, the page's progress, reward and which pickaxes can find it, and your total bonus and title. A new find pops "New mineral: X!" and lights the button; a repeat find floats "+1 X"
- A completed page is announced to the server and adds +2% to bar sales (additive across pages) and a title (Iron Prospector, Frost Walker, Crystal Seer), kept in your `Title` attribute. Décor rewards wait for a décor system. Pages and odds are in `Config.Index`, the rules in `Shared.MineralIndex`

**Rebirth, "Relocate the Colony" (spec §8.3)**
- The REBIRTH button (under INDEX; green once you can afford it, hidden while the shop or index is open and, on narrow screens, while the tutorial card sits in the column) opens a panel with your cash multiplier now and after the rebirth, the cost with your progress toward it, and what resets and what you keep. The confirm button needs a second press ("ARE YOU SURE?") within 3 s, and says how much cash is missing while you can't afford it
- The first rebirth costs $10M, each one after ×10 ($100M, $1B, ...). It resets cash to $0, the pickaxe and backpack to tier 1 and empties the backpack; the production line with its ore and bars, carried bars, Core Shards, the mineral index, décor and flags are kept. Every rebirth doubles bar sales for good (×2, ×4, ×8, ..., multiplicative), is announced to the server and the HUD shows the multiplier under your cash. The "While you were away" value now includes your sale multipliers. Tuning is in `Config.Rebirth`, the rules in `Shared.Rebirth`

**Analytics (spec §13)**
- `TelemetryService` logs to Roblox AnalyticsService (every call pcall'd; in Studio each event also prints a `[Telemetry] ...` line). Once per player, guarded by profile flags: `first_meteor_joined` (first hit on a crust node or the core), `first_core_reward` (first shards) and `first_refinery_bought` (first refinery upgrade). On every join whose offline catch-up made bars: `returned_offline_income` (value = bars, field = hours away)
- Per meteor event: players in the server, node hitters, core hitters, cracked vs cooled and seconds to crack, by meteor type. Economy sources and sinks for cash (selling; shop, station upgrades, rebirth) and shards (core rewards; purchases). Rebirths. `active_actions_per_minute` per player every 60 s (swings, deposits, collects, sells, purchases; players with none log nothing). Tutorial funnel steps. Tuning is in `Config.Telemetry`, the pure helpers in `Server.Lib.Telemetry`

**Passes and products (spec §9, scaffold)**
- The STORE button (under REBIRTH) lists the game passes (2x Ore, Bigger Backpack, Offline Hours+, Auto-Deposit, VIP) and developer products (Call a Meteor, Refinery Overclock) with what they do. Every id in `Config.Monetization` is 0 for now, which means not on sale: the button says "Not on sale yet" and nothing is prompted. Fill in the ids from the Creator Dashboard to switch each one on. Extra Refinery is left out (the plot has one production line) and cash packs come later
- Pass effects: 2x Ore doubles the ore from every hit and never touches mineral odds; Bigger Backpack doubles backpack capacity; Offline Hours+ raises the offline cap from 2 to 8 hours; Auto-Deposit puts mined ore straight into your hopper and the rest into your backpack once the hopper is full; VIP adds +10% to bar sales and a [VIP] chat tag. Ownership is checked on join and when a pass is bought in game
- Call a Meteor brings the next meteor down in 30 s for everyone and names the buyer. It is only on sale during the countdown with more than 60 s left, at least 3 minutes after the previous called meteor's event ended (ordinary meteors don't start the cooldown), and 3 times per server per rolling hour; otherwise the button is disabled with the reason. If a race still makes it fail, the buyer gets a Call a Meteor credit to spend from the store later. Refinery Overclock doubles refinery speed for 30 minutes of play time (not offline). Receipts are granted once (the last 50 purchase ids are kept in the profile) and only confirmed once the profile is saved. Purchases are logged as `pass_bought` / `product_bought`
- Rules are in `Shared.CallMeteor`, tuning in `Config.Monetization`, the effects in `MonetizationService`

**Mobile controls and HUD layout (spec §10)**
- On touch-only devices a big round MINE button sits above Roblox's jump button while a pickaxe is in your hands. Hold it to swing continuously at the pickaxe's speed at the nearest mineable target in reach and in front of you; the server still checks range and swing speed on every swing (`Shared.Aim`, `MobileControlsController`, tuning in `Config.Hud`)
- One layout decides where the SHOP, INDEX, REBIRTH and STORE buttons go (`Shared.HudLayout`): a column on the right for mouse users, one row along the top right on touch, every button at least 44 px, clear of the Roblox top bar, the clock, the thumbstick area, the jump button and MINE. The tutorial card stays centred under the clock on touch
- The shop, index, rebirth and store panels scale to fit below the top bar (844x390 included) and their close buttons stay at least 44 px

**Economy pacing (spec §7.4, Week 5)**
- `Shared.Pacing` simulates a fresh free player (Iron meteors, no passes or rebirth) from Config and `tests/Pacing.spec.luau` asserts the §7.4 checkpoints; assumptions in `Config.Balance`, results and the inflation factor (1: Config prices are the spec's) in `docs/balance.md`
- The level 1 line makes $75 a minute, so the shipped prices put the Drill Pick at 79 minutes in the model (reproduction in `docs/balance.md`) instead of 30. From the Drill on the model adds Ice (and, at tier 5, Crystal) meteors as expected value; Plasma lands at 1:53 (in reach at 0:57). Tuning, old to new: Drill Pick cost $8,000 to $1,500; Refinery level 2 cost $1,500 to $400; Conveyor level 2 cost $1,200 to $300

## Layout

```
default.project.json   Rojo project (code only)
Packages/              Knit 1.7, Fusion 0.3, Comm, Promise, Signal, Option (vendored)
src/shared/            ReplicatedStorage.Shared: Config, Format, Phase, Price, MiningPower, Pacing, MeteorTypes, MineralIndex, Rebirth, CallMeteor, HudLayout, Aim
src/server/            ServerScriptService.Server: Knit services
src/client/            StarterPlayerScripts.Client: Knit controllers, Fusion HUD, shared UI styles (UI.luau)
assets/                Studio exports of everything built in Studio (see below)
```

Server services: `MeteorService` (schedule and state machine), `NodeService` (HP, swing validation, ore drops), `ContributionService`, `RewardService`, `DebrisService`, `DataService` (profiles), `PlayerStateService` (gameplay rules over the profile), `PlotService`, `RefineryService` (the production line, offline catch-up), `UpgradeService` (station upgrades), `ShopService` (pickaxes and backpacks), `EconomyService` (selling), `TutorialService`, `IndexService` (mineral drops and index rewards), `RebirthService` (rebirths), `TelemetryService` (analytics), `MonetizationService` (game passes and developer products). `src/server/Lib` holds the profile template, the pure refinery simulation, the shard reward math and the analytics helpers.

Client controllers: `MiningController`, `MeteorFXController`, `HUDController`, `HomeController`, `NodeHealthController`, `ShopController`, `TutorialController`, `ActivityController`, `IndexController`, `RebirthController`, `StoreController`, `MobileControlsController`.

Services announce what players do through server-side signals (`NodeService.Hit`, `MeteorService.Landed`, `RewardService.ShardsAwarded`, `RefineryService.OreDeposited` / `BarsCollected`, `EconomyService.BarsSold`, `ShopService.ItemBought`, `UpgradeService.StationUpgraded`, `MeteorService.Ended`, `RefineryService.CaughtUp`, `RebirthService.Reborn`). The tutorial and `TelemetryService` listen to them.

All tuning numbers live in `src/shared/Config`.

## The map lives in the place, not in code

Nothing builds the world at runtime. The crater town, plots, debris rocks, sky countdown board, meteor node pieces and the pickaxe are real instances saved in the place:

| Instance | What it is |
|---|---|
| `Workspace.Map` | Ground, crater, town square (Trading Post with sell counter, Pickaxe Shop, spawn), 20 empty plot pads with signs, roads, debris rocks, trees, boundary cliffs |
| `ServerStorage.Assets` | Meteor core (with `NodeSlot` attachments and glowing `Vein` parts), the ore cluster pieces, and `PlotStations` (the production line template) |
| `StarterPack.Pickaxe` | The Basic Pickaxe tool (mark the parts to recolour per tier with a `Tint` attribute) |

The Pickaxe Shop (`Workspace.Map.TownSquare.PickaxeShop`) opens the shop through its saved ProximityPrompt; if it has none, one is added on a part named `ShopPoint` inside it. Without either, the shop still opens from the HUD button.

Two things are cloned at runtime from `ServerStorage.Assets`: the meteor when it lands, and a player's production line (`PlotStations`) when they claim a plot. The plot pads themselves stay in Workspace.

`default.project.json` only syncs code, so Rojo never touches the map. Edit the map in Studio and save the place. `assets/*.rbxm` are Studio exports of the same instances, kept in git as a backup; use Studio's *Insert from File* to restore them. `assets/Terrain.rbxm` holds the terrain as a TerrainRegion; restore it with `workspace.Terrain:PasteRegion(region, Vector3int16.new(-160, -32, -160), true)`. (Rojo 7.6 can't read the newest Studio binary format, so they aren't wired into a Rojo project.)

## Working on it

1. Open the saved place in Studio.
2. `rojo serve` in this folder, then connect from the Rojo plugin.
3. Pure-logic modules (Format, MiningPower, Refining, ...) have specs under `tests/`, synced to `ServerStorage.Tests`. Run them from the command bar or `execute_luau` in Edit mode: `require(game.ServerStorage.Tests.Runner)()`.
4. Play. Unpublished places can't use DataStores, so profiles are kept in memory for that play session only. In Studio the countdown is shortened to 25 s (`Config.Meteor.StudioCountdown`, set it to `nil` for the real 2:00 / 4:00 timings), and a **[Studio] Meteor now** button skips to the last 10 s. **[Studio] Away 1 hour** runs an hour of offline refining so you can check the "While you were away" panel. To test the shop, call the `DevGrant` hook from the command bar: `game.ServerStorage.DevGrant:Invoke(game.Players:GetPlayers()[1], cash, ore, shards, pickaxeTier)`; every argument after the player is optional, and `pickaxeTier` sets your pickaxe tier (restyling the tool), e.g. `DevGrant:Invoke(player, nil, nil, nil, 5)` for a tier-5 pickaxe that mines Crystal. To measure the ore hot path, `game.ServerStorage.DevBench:Invoke(game.Players:GetPlayers()[1], 1000)` gains ore 1000 times (into a borrowed, empty top-tier backpack; yours comes back afterwards) and returns the elapsed ms and how many State snapshots went out; State is batched, so expect one. To test the mineral index, `game.ServerStorage.DevMineral:Invoke(game.Players:GetPlayers()[1], "starfallIron")` adds one mineral through the real path (toast, page announcement, title), and a page id (`"Iron"`) adds one of every mineral on that page. To test a rebirth, grant cash with `DevGrant` (e.g. `DevGrant:Invoke(player, 10e6)`) and use the REBIRTH button. Profiles are in memory in Studio, so every play session starts the tutorial from step 1. To test meteor sizing solo, set a `DevFakeTiers` string attribute on ServerStorage during play (e.g. `1,1,1,8`): each number adds a pretend active player with that pickaxe tier; the meteor model's `ServerPower` attribute shows what it is sized for. Pretend players count toward the meteor type's tier gate too, so `5,5,5` lets Ice and Crystal come up. To force a type, set a `DevMeteorType` string attribute on ServerStorage (`Iron`, `Ice` or `Crystal`, Studio only); it is read when each countdown starts, so set it before the play session or it applies from the next countdown. To test game passes, set a `DevPasses` string attribute on ServerStorage (Studio only), e.g. `TwoXOre,VIP`; setting it during play grants them to everyone in the session.
