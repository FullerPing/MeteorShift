# MeteorShift

A Roblox game based on the mechanic of mining meteors and other debris around a centralised town.

Every few minutes a meteor slams into the crater in the middle of town and the whole server rushes to mine it before it cools. Crack the core together to earn Core Shards. Between meteors, mine debris around town.

## Status

The overnight pet update gives every pet explicit level 1–10 perks across eleven capped roles, including ore yield, sprint, vault capacity, crit, player XP and cracked-core shards. Player State publishes all bonuses; replicated loadouts drive bounded local pet followers. [Pets](docs/pets.md) retains the full art brief and exact perks, and [pet model conventions](docs/pet-models.md) describe the authored assets.

The Gear Shop has Pickaxe, Backpack and Pets; production upgrades live in the shared Refinery beside Deposit / Claim. Pet cards list every perk at the owned level, with rarity accents. Eggs still cost earned Core Shards, retain their shown odds and pity, and never use Robux.

Fixed micro-purchases and Extra Pet Slot are configured but off sale: every monetization ID remains zero. Drillbot and Solar Phoenix use the reduced 99/199 Robux intended prices. [Purchase rules](docs/purchases.md) covers the full catalog, bounded cash grants, online timers and save-before-acknowledgement receipt flow. No purchase grants shards, eggs, random pets or changed mineral odds.

For isolated Studio acceptance checks, temporarily set `ServerStorage.DevMemoryStore = true` **before** starting Play. This uses session memory instead of every live DataStore; clear the attribute in Edit before saving. The Studio-only `DevProduct` BindableFunction invokes the real fixed grant/save path. It does not represent a Marketplace purchase. No enabled join fixture may change player progression in a saved place.

Weeks 1 to 3 of the MVP plan are in, plus a round of polish on the plots and the meteor, and the improvement pass on top: Week 4 (meteor types, mineral index, rebirth, analytics, passes and products) and Week 5 (performance, mobile controls, economy pacing). Every game pass and developer product id is still 0, so nothing is on sale yet. The spec is copied to `docs/plans/meteor-shift-spec.md`; the pass is planned in `docs/plans/2026-09-27-improvement-pass.md`.

Sound effects use Pro Sound Effects ids tuned in `Config/Sounds.luau` and played through `client/Sfx.luau` (pooled, per-name cooldown and cap): pickaxe hits, node break, core crack, meteor impact, sell, purchase and UI clicks.

**Week 1, the meteor event**
- Sky countdown and HUD timer, streak in the sky for the last 10 s, rumble and camera shake
- Impact with shockwave: knockback only, no damage
- Meteor assembled from reusable node pieces: 36 crust nodes around a core
- Node and core HP run on a hidden Mining Power stat (1.25× per pickaxe tier), so a maxed veteran mines ~8× faster than a newcomer instead of ~900×. Hits still pop the big damage number, and ore per hit still comes from your pickaxe
- HP is sized at impact from players with input in the last 2 minutes (AFK players don't count), never smaller than 1 Basic Pickaxe (HP scales with power, so a solo player cracks a meteor in the same time as a crowd). If the active crowd's power shifts by more than 15% mid-event, the remaining HP rescales, keeping the same percent done (at most every 10 s)
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

**Week 3, upgrades and UI**
- Shop with Pickaxe, Backpack and Pets tabs (the gear tabs are one screen each: a large preview of what you hold, a row per stat with +1 and +10 buy buttons showing the price, and an Evolve banner with the Power progress bar, player-level need and price; it scrolls on phones), opened from the SHOP button or the Pickaxe Shop in town. You keep **one pickaxe and one backpack for the whole game** (`Shared.Gear`, tuning in `Config.Gear`): each stat levels up with cash (pickaxe: Power, Swing speed, Reach, Crit chance; backpack: Capacity), and the tier caps how high the stats go (10 levels per tier). Evolving to the next tier needs the Power (or Capacity) stat at the cap and costs the tier's cash and Core Shards (`Config.Pickaxes`, `Config.Backpacks`). Evolving restyles the tool and keeps your levels; the other stats can lag behind. Power is Mining Power per hit (HP and contribution, 1.25x per tier's worth of levels), Reach is the mine range in studs, Crit is a server-rolled chance for double Mining Power with a bigger damage number. Ore per hit is flat per tier (1 to 20), so progression is in the line, the ore type and the stats, not in hundreds of times more ore. Profiles migrate from v2 to v3: everyone starts at the first level of the tier they owned. Production upgrades are in the Refinery panel alongside Deposit and Claim
- Your pickaxe tool is renamed after the tier you own; parts in it with a `Tint` attribute take the tier's colour
- HUD shows your pickaxe, the cash counter counts up to the new total, and a "+$" floater rises off it on every sale
- Tutorial (spec §11): 10 steps from "Mine a debris rock" to "Buy an upgrade", each completed by the real action on the server, with a step card, a marker over the target and a beam from you to it. Doing a later step's action first also completes the steps before it, so joining mid-event never gets you stuck. Skippable, saved in the profile (`tutorialStep`), and each step is logged as an onboarding funnel step

**Player level (Shared.Levels, Config.Levels)**
- XP arrives as you play (`LevelService`): each validated hit on a crust node pays a little, a core hit a bit more, and a core you hit that then cracks pays a bonus, all times the meteor ore's multiplier (Frost 1.5, Crystal 2). Debris and idling pay nothing. A full meteor of hitting is about 70 XP. The level and an XP bar sit in the wallet card (bottom-left); the level survives rebirth. Each ore has a clearance level (Iron 1, Frost 4, Crystal 6); under it your refinery handles that ore at 0.35^levelsShort speed (the refinery panel shows the % and the level), never blocked, same bar price for everyone. Evolving a pickaxe or backpack to tier 5 and up also needs a player level (`Config.Levels.EvolveLevel`), checked by `ShopService:Evolve`; the Evolve card shows "NEEDS LEVEL n". `Levels.clearance` is the rule, `Refining.run` applies it, `Pacing` models it. `tests/Levels.spec` checks an average player isn't held back through tier 6.

**Pets (Shared.Pets, Config.Pets, PetService)**
- 14 pets in six rarities (Common to Legendary from eggs, Premium from passes); see [the pet roster and art brief](docs/pets.md). You put out a few at a time (1 slot, +1 per rebirth, up to 3; the 49 Robux Extra Pet Slot pass adds one, up to 4). Each pet has explicit perks that interpolate linearly from its level 1 values to level 10. Equipped values add per role to eleven independent caps; pets gain XP on your own validated hits, and rebirth keeps them. The Pets cards show every perk at the owned level with rarity accents
- **Eggs** (Pets tab, Core Shards only, so no paid randomness): Meteor Egg 30 shards (Common 55 / Uncommon 28 / Rare 12 / Epic 4.5 / Legendary 0.5 %, Epic or better guaranteed every 30th hatch) and Crystal Egg 120 shards (Uncommon 38 / Rare 40 / Epic 18 / Legendary 4 %, guaranteed every 12th). The odds show on the cards. A duplicate gives 400 XP to the pet you own. **Passes** (fixed price, not in an egg): Drillbot 99 Robux and Solar Phoenix 199 Robux, each with three perks and the strongest level 10 values for their roles (set the pass ids in `Config.Monetization`; owning one gives the pet on join and on purchase)
- **Miner** (Drillbot 25% to 40%, Solar Phoenix 50% to 100%, egg miners below them): while you are mining (a validated swing of yours in the last 15 s) it hits the nearest target in your reach every swing with that share of your pickaxe's Mining Power and ore. Its ore goes straight to the hopper; it never counts for the podium, core rewards, mineral drops or the meteor's size
- **Hauler** moves a share of current backpack capacity to the hopper every second; **Pack** raises backpack capacity; **Swift** shortens swings; **Merchant** raises bar-sale value. **Yield** multiplies ore from validated hits, **Sprint** raises walking speed without fighting another system's changes, **Vault** raises hopper and collection-post capacity online and offline, **Crit** adds critical-hit chance points, **Scholar** raises player XP, and **Shards** raises the complete cracked-core payout, rounded down once. Exact per-pet endpoints and role caps are in `Config.Pets` and [docs/pets.md](docs/pets.md); pet and product effects preserve mineral odds
- Every observer sees replicated equipped IDs and levels. Clients render local followers from `ReplicatedStorage.PetModels`, use the complete `Level10` look when available, cull beyond 150 studs and keep a total budget of 40 pet models including hatch previews. Missing assets render nothing. Hatches queue a rarity reveal with the name, perks and duplicate XP; Escape or tap closes it, and the full-screen input block ends within 2 seconds. [Model conventions](docs/pet-models.md) covers the authored assets
- Profiles migrate from v3 to v4 (pets table; a Drillbot already saved is kept). Studio: `DevPet:Invoke(player, "packMule", 10)` gives a pet at a level

**Shared refinery**
- If a model named `Refinery` is saved in `Workspace.Map.TownSquare` (with a `UsePoint` part), it replaces the plot production lines: its prompt opens your refinery panel. Use the panel's Deposit button to move backpack ore to your hopper and Claim to collect finished bars; the server requires a living character near the refinery for these actions. Each player still has their own saved stock and station levels. The plots stay as empty pads and no line is cloned onto them. Without the model everything works as before, on the plots. Sell All stays in the HUD. `docs/studio-refinery-prompt.md` is the brief for building and placing the model in Studio

**Week 4: meteor types (spec §8.1)**
- Ice (Frost ore) and Crystal (Crystal ore, bars sell at $30,000) meteors fall alongside Iron. Each countdown picks the next type from weighted odds (Iron 60, Ice 25, Crystal 15), and every player mines whatever falls: how fast your refinery handles an ore depends on your player level (clearance, see the Player level section), so mixed-level lobbies are fair. The sky board and HUD timer name it from the start of the countdown, with the title in the type's glow colour (Iron orange, Ice cyan, Crystal magenta). Types and twists are in `Config.Meteor`, the rules in `Shared.MeteorTypes`
- Everyone mines the meteor's own ore at their pickaxe's normal rate, with its normal Mining Power and quantity effects. Refinery clearance is full from player level 1 for Iron, 4 for Frost and 6 for Crystal; below that, ore costs more line time but retains its full bar price. Debris always drops Iron whatever its tint (cyan rocks once dropped Frost, which paid a Basic Pickaxe about 6x an Iron meteor per swing). [Economy assumptions](docs/balance.md) explains the clearance model
- Ice twist, Refreeze: a node or core nobody has hit for 5 s regains 2% of its HP per second (never past full); its health bar turns frost blue while it refreezes. Crystal twist, Resonance: each extra player who hit the same node in the last 1.5 s adds +20% Mining Power (HP and contribution) to everyone on it, up to +60%
- The shard bonus pool is multiplied by the type (Ice ×1.5, Crystal ×2), and equipped Shards perks multiply each player's complete cracked-core payout. The results panel reports why the event ended (cracked or cooled), the ore kept, actual shards and player XP earned

**Week 4: mineral index (spec §8.2)**
- Iron, Ice and Crystal pages, four minerals each. Every hit on a meteor's crust or core can drop one mineral of that meteor's page at fixed odds (1 in 25, 120, 600 and 2,500), only if your own pickaxe meets the meteor's tier; debris never drops minerals and nothing you can buy changes the odds. The rarest mineral of each page only drops from rich nodes: three crust nodes per meteor with gold ore that sparkle
- The INDEX button (under SHOP; hidden while the shop is open and, on narrow screens, while the tutorial card sits under SHOP) opens the book: a tab per page, every mineral as a card ("???" until found) with its odds, the page's progress, reward and which pickaxes can find it, and your total bonus and title. A new find pops "New mineral: X!" and lights the button; a repeat find floats "+1 X"
- A completed page is announced to the server and adds +2% to bar sales (additive across pages) and a title (Iron Prospector, Frost Walker, Crystal Seer), kept in your `Title` attribute. Décor rewards wait for a décor system. Pages and odds are in `Config.Index`, the rules in `Shared.MineralIndex`

**Week 4: rebirth, "Relocate the Colony" (spec §8.3)**
- The REBIRTH button (under INDEX; green once you can afford it, hidden while the shop or index is open and, on narrow screens, while the tutorial card sits in the column) opens a panel with your cash multiplier now and after the rebirth, the cost with your progress toward it, and what resets and what you keep. The confirm button needs a second press ("ARE YOU SURE?") within 3 s, and says how much cash is missing while you can't afford it
- The first rebirth costs $15M, each one after ×5 ($75M, $375M, $1.9B, ...). It resets all cash to $0, the pickaxe and backpack to tier 1 with their stat levels, hopper/conveyor/collection upgrades to level 1, all carried and stored ore/bars, partial refining progress and décor. Refinery level, carried Core Shards and mineral-index discoveries, bonuses and titles are kept. Purchased value, receipt history, preferences and lifetime/tutorial history remain intact. Every rebirth multiplies bar sales by 5 for good (×5, ×25, ×125, ..., multiplicative; equal to the cost growth, so each rebirth takes about as long as the last); index bonuses continue to stack. Tuning is in `Config.Rebirth`, price/multiplier rules in `Shared.Rebirth`, and inventory rules in `Server.Lib.RebirthReset`.

**Week 4: analytics (spec §13)**
- `TelemetryService` logs to Roblox AnalyticsService (every call pcall'd; in Studio each event also prints a `[Telemetry] ...` line). Once per player, guarded by profile flags: `first_meteor_joined` (first hit on a crust node or the core), `first_core_reward` (first shards) and `first_refinery_bought` (first refinery upgrade). On every join whose offline catch-up made bars: `returned_offline_income` (value = bars, field = hours away)
- Per meteor event: players in the server, node hitters, core hitters, cracked vs cooled and seconds to crack, by meteor type. Economy sources and sinks for cash (selling; shop, station upgrades, rebirth) and shards (core rewards; purchases). Rebirths. `active_actions_per_minute` per player every 60 s (swings, deposits, collects, sells, purchases; players with none log nothing). Tutorial funnel steps. Tuning is in `Config.Telemetry`, the pure helpers in `Server.Lib.Telemetry`

**Week 4: passes and products (spec §9, scaffold)**
- The STORE button lists 2x Ore, Bigger Backpack, Offline Hours+, Auto-Deposit, VIP, Drillbot Pet (99 Robux), Solar Phoenix Pet (199) and Extra Pet Slot (49), plus Tip Jar (5), Pocket Change (10), Pet Treat (15), Mini Overclock (19), Ore Rush (25), Pet Feast (29), Cash Bundle (39), Call a Meteor and Refinery Overclock. Every id in `Config.Monetization` is 0 for now: cards show the intended price where specified and "Not on sale yet", and nothing is prompted. Fill in ids from the Creator Dashboard to enable items; existing pass, Call a Meteor and Refinery Overclock prices remain the owner's decision. [Purchase rules](docs/purchases.md) gives the exact catalog and grants. Extra Refinery is left out because each player has one production line
- Pass effects: 2x Ore doubles the ore from every hit and never touches mineral odds; Bigger Backpack doubles backpack capacity; Offline Hours+ raises the offline cap from 2 to 8 hours; Auto-Deposit puts mined ore straight into your hopper and the rest into your backpack once the hopper is full; VIP adds +10% to bar sales and a [VIP] chat tag. Ownership is checked on join and when a pass is bought in game
- Call a Meteor brings the next meteor down in 30 s for everyone and names the buyer. It is only on sale during the countdown with more than 60 s left, at least 3 minutes after the previous called meteor's event ended (ordinary meteors don't start the cooldown), and 3 times per server per rolling hour; otherwise the button is disabled with the reason. If a race still makes it fail, the buyer gets a Call a Meteor credit to spend from the store later. Refinery Overclock doubles refinery speed for 30 minutes of play time (not offline); Mini Overclock adds 10 minutes to the same timer. Ore Rush adds 30 online minutes of ×2 ore and uses the larger multiplier with the 2x Ore pass; the store disables it for pass owners with "You own 2x Ore". Pet Treat and Pet Feast give fixed XP to equipped pets; cash packs have floors and ceilings below the next rebirth price; Tip Jar grants session cosmetics. No product grants shards, eggs, random pets or altered odds. Receipts are granted once, retained permanently and acknowledged only after the profile is saved; a failed-save retry does not grant twice. History trimmed by earlier versions cannot be reconstructed. Purchases are logged as `pass_bought` / `product_bought`
- Rules are in `Shared.CallMeteor`, tuning in `Config.Monetization`, the effects in `MonetizationService`

**Week 5: performance (spec §12.3)**
- Player State is batched: `PlayerStateService` marks a player dirty and sends every dirty State once per `Config.Net.StateFlushInterval` (0.2 s), so 20 players swinging cost a handful of snapshots per second, not one per swing. `ContributionService` skips standings that didn't change
- Client effects are capped and pooled: spark emitters are reused, and live floaters and ore chunks have limits (`Config.Net`). `DevBench` (below) measures the ore path

**Week 5: mobile controls and HUD layout (spec §10)**
- On touch-only devices a big round MINE button sits above Roblox's jump button while a pickaxe is in your hands. Hold it to swing continuously at the pickaxe's speed at the nearest mineable target in reach and in front of you; the server still checks range and swing speed on every swing (`Shared.Aim`, `MobileControlsController`, tuning in `Config.Hud`)
- Desktop keeps the wallet bottom left, Gear/Rebirth/Store on the left, Index on the right, meteor clock top centre, objective top right, training above the foundry and backpack bottom right. Landscape phones follow the supplied mobile mockup: Gear/Index/Rebirth stack on the left, Settings and Store sit at the top right, and wallet → production/bars → backpack form one bottom strip between movement controls. Narrow portrait and cramped landscape screens use the compact layout. Internal menus use editable native StarterGui controls with direct controller bindings; the main HUD and tutorial still use Fusion. The controls keep the existing game state and actions. Transparent icon exports and their provenance are in `assets/hud`; configured IDs are in `Config.HudIcons`.
- Tap the backpack icon to open a compact list directly above it, aligned to both backpack edges. It shows only ores currently carried, displays Empty for no ore, and keeps camera controls available. The height fits up to three rows; additional ore types scroll. Tap the foundry summary to expand hopper/storage meters, carried bar counts and sale values, and a Sell All button. Sales use the server's existing rebirth, index and VIP multipliers and leave raw ore and collection-post stock intact. The gear toggles training guidance and meteor objectives for the current session. Small screens reflow the cards above movement controls, with at least 44 px navigation and close targets; transient notices reserve their own space.
- The pickaxe equips automatically on spawn; the stock Roblox tool slot is hidden to keep the foundry clear. Equipment still opens the upgrade shop. Gear, Index, Rebirth and Store clone the owner's `StarterGui/MY index button` design; Index keeps its authored icon, while the other icons come from `Config.HudIcons` pending owner selection.
- One layout decides where the SHOP, INDEX, REBIRTH and STORE buttons go (`Shared.HudLayout`): desktop navigation uses side columns; roomy landscape phones use the supplied left stack and top-right actions; cramped or portrait screens use a compact row. Every button stays at least 44 px and clears Roblox controls, the clock, the joystick, jump and MINE. Training stays centred above the bottom strip and hides while foundry details are expanded.
- The simulator style uses the owner's blue studded navigation tiles and simple internal menus: charcoal studded backings, bright studded header bars, modest rectangular cards, thick dark outlines and white outlined Fredoka headings and actions. Menu surfaces use a passive tiled image (`rbxassetid://6927295847`) behind their content. Secondary copy keeps a plain readable font. Gear models, inventory quantities, affordability, refinery transactions and progression remain driven by the existing game state. [docs/native-ui.md](docs/native-ui.md) covers the editable prefabs, exact navigation layers and rebuild workflow.
- The shop, index, rebirth and store panels scale to fit below the top bar (844x390 included) and their close buttons stay at least 44 px

**Week 5: economy pacing (docs/balance.md)**
- `Shared.Pacing` simulates a fresh free player (and optionally their rebirths) from Config and `tests/Pacing.spec.luau` asserts the targets: Steel in the first minutes, the Drill Pick by 15 minutes, the Meteorite Pick by 30, the first rebirth ($15M) 40 to 60 minutes in, then a steady rebirth every half hour or so. An optional equipped Drillbot fixed at level 5 changes the measured first rebirth from 45 to 58 minutes under the preserved model and shopping policy. Assumptions and the frozen-clearance backlog limitation are documented in [docs/balance.md](docs/balance.md); no balance constants were retuned
- The economy is inflated to the Roblox simulator rhythm: millions on day 1, billions within a few short sessions. Ore per hit is flat per tier (1 to 20), bar prices are Iron $50, Frost $1,200 and Crystal $30,000, the line makes 0.25 ore/s at level 1 and about 18 at the top, and rebirth costs and pays x5 each time

## Layout

```
default.project.json   Rojo project (code and editable StarterGui exports)
Packages/              Knit 1.7, Fusion 0.3, Comm, Promise, Signal, Option (vendored)
src/shared/            ReplicatedStorage.Shared: Config/, Format, Phase, Price, MiningPower, Gear, Pets, Levels, Pacing,
                       MeteorTypes, MineralIndex, Rebirth, CallMeteor, HudLayout, Aim, EquipmentModels,
                       AtmosphereMood
src/server/            ServerScriptService.Server: Knit services, Lib/, Main.server.luau (Studio dev hooks)
src/client/            StarterPlayerScripts.Client: Knit controllers, Fusion HUD/tutorial, UI.luau (shared styles),
                       NativeUI/NativeMenus (native menu bindings and authoring), EquipmentPreview (shop viewports)
tests/                 ServerStorage.Tests: Runner.luau and one *.spec.luau per pure-logic module
docs/                  balance.md (economy pacing model), native-ui.md (editable menu workflow), plans/ (spec and plan)
assets/                Studio exports of everything built in Studio (see below)
```

`Config` is a folder of tables collected by `Config/init.luau`: Meteor, Index, Pickaxes, Backpacks, Gear, Pets, Levels, Debris, Home (stations), Tutorial, Net, Rebirth, Telemetry, Monetization, Hud, Balance, Atmosphere and LandingFX. All tuning numbers live there.

Server services: `MeteorService` (schedule and state machine), `NodeService` (HP, swing validation, ore drops), `ContributionService`, `RewardService`, `DebrisService`, `ActivityService` (who counts as active), `DataService` (profiles), `PlayerStateService` (gameplay rules over the profile, batched State replication), `LevelService` (player XP), `PetService` (eggs, pet XP and active perks), `PlotService`, `RefineryService` (the production line, offline catch-up), `UpgradeService` (station upgrades), `ShopService` (pickaxes and backpacks), `EconomyService` (selling), `TutorialService`, `IndexService` (mineral drops and index rewards), `RebirthService` (rebirths), `TelemetryService` (analytics), `MonetizationService` (game passes and developer products). `src/server/Lib` holds the profile template, the pure refinery simulation (`Refining`), the shard reward math (`Rewards`) and the analytics helpers (`Telemetry`).

Client controllers: `MiningController`, `MeteorFXController`, `HUDController`, `HomeController`, `NodeHealthController`, `ShopController`, `PetVisualController`, `HatchController`, `TutorialController`, `ActivityController`, `IndexController`, `RebirthController`, `StoreController`, `MobileControlsController`, `AtmosphereController`, `LandingFXController`.

Services announce what players do through server-side signals (`NodeService.Hit`, `MeteorService.Landed`, `RewardService.ShardsAwarded`, `RefineryService.OreDeposited` / `BarsCollected`, `EconomyService.BarsSold`, `ShopService.ItemBought`, `UpgradeService.StationUpgraded`, `MeteorService.Ended`, `RefineryService.CaughtUp`, `RebirthService.Reborn`). The tutorial and `TelemetryService` listen to them.

## Player policy checks

`PlayerPolicyService` calls Roblox's `PolicyService:GetPolicyInfoForPlayerAsync(player)` on join, with up to three attempts. Its cached policy starts restricted while loading and stays restricted if the lookup fails. This is independent of profile loading and does not delay joining or normal gameplay.

Server code can use `Knit.GetService("PlayerPolicyService"):GetPolicyInfo(player)` for a copy of the policy summary, `:CanUsePaidRandomItems(player)` before granting a paid random outcome, and `:CanTradePaidItems(player)` for both players before transferring a paid item. The summary contains `Status` (`loading`, `ready`, or `unavailable`), `ArePaidRandomItemsRestricted`, and `IsPaidItemTradingAllowed`. Clients can observe the service's `Policy` property to display the same eligibility; server checks must still enforce any restricted action.

The current store has deterministic passes/products and no player-to-player item trading. Mining, free mineral discoveries, earned shards and selling bars remain available. Any future paid random item or paid-item trading feature must call the relevant server check when performing the action. Policy information is kept only for the current player session, not saved in profiles.

## The map lives in the place, not in code

Nothing builds the world at runtime. The crater town, plots, debris rocks, sky countdown board, meteor node pieces and the pickaxe are real instances saved in the place:

| Instance | What it is |
|---|---|
| `Workspace.Map` | Ground, crater, town square (plaza, fountain and spawn), 20 empty plot pads with signs, roads, debris rocks, trees, boundary cliffs |
| `ServerStorage.Assets` | Meteor core (with `NodeSlot` attachments and glowing `Vein` parts), the ore cluster pieces, and `PlotStations` (the production line template) |
| `StarterPack.Pickaxe` | The Basic Pickaxe tool (mark the parts to recolour per tier with a `Tint` attribute) |

Shopping and selling are in the HUD, so the town square holds only the plaza, its fountain and the spawn. A `PickaxeShop` or `TradingPost` model saved back into `Workspace.Map.TownSquare` would still open the shop or sell bars through its ProximityPrompt.

Two things are cloned at runtime from `ServerStorage.Assets`: the meteor when it lands, and a player's production line (`PlotStations`) when they claim a plot. The plot pads themselves stay in Workspace.

The mountains outside the play area are terrain. `tools/terrain/author-mountains.luau` added 113 rounded peaks in three rings: one just past the boundary ridge, one filling the gaps in the older mountain ring, and a far skyline the haze softens. To rebuild them, run it from the command bar with Play stopped, then save the place. It only adds terrain, so running it again changes nothing.

`default.project.json` syncs code and `assets/native-ui/*.rbxmx` into StarterGui; it does not map Workspace, so Rojo never touches the map. Edit the map in Studio and save the place. `assets/*.rbxm` are Studio exports of the same instances, kept in git as a backup; use Studio's *Insert from File* to restore them. `assets/Terrain.rbxm` holds the terrain as a TerrainRegion; restore it with `workspace.Terrain:PasteRegion(region, Vector3int16.new(-160, -32, -160), true)`. (Rojo 7.6 can't read the newest Studio binary format, so these map exports aren't wired into a Rojo project.)

## Fog, atmosphere and lighting

The calm look is saved in the place, like the map: `Lighting` (a low late-afternoon sun at 17:12, warm light and cool shadows), its `Atmosphere` (the fog: density 0.38, haze 2, dusty amber), `Bloom`, `Grade` (colour correction) and `SunRays`, plus `Terrain.Clouds`. `Workspace.Map.Atmosphere` holds the local effects: ground mist pooling in the crater, a mist band at the foot of the boundary cliffs, embers drifting up out of the crater and dust motes over the town square, about 220 particles alive at once. `tools/atmosphere/author-lighting.luau` authored all of it; run it from the command bar to rebuild it, then save the place.

During a meteor, `AtmosphereController` blends moods on top of the saved values on each client, and leaves Lighting alone between events:
- Approach, the last 25 s of the countdown: the light dims, clouds gather and darken, and the haze takes on the meteor type's glow colour (Iron orange, Ice cyan, Crystal magenta).
- Impact: brown dust thickens the fog and settles over 12 s, and the approach gloom lifts over 8 s.
- While the meteor is down, a faint glow of its colour stays in the haze, fading out once the core cracks or the meteor cools.

Tuning is in `Config.Atmosphere`, the rules in `Shared.AtmosphereMood`. In Studio, setting the boolean attribute `DevMeteorApproachFX` on ReplicatedStorage to `false` turns the approach mood off.

## Ice and Crystal landing effects

When an Ice or Crystal meteor lands, `LandingFXController` grows effects around the crater on each client. Iron meteors get none.
- Ice: a glaze spreads over the crater floor, glowing cracks race out to a ring of ice spikes, frost creeps outward while the meteor cools, and snow and mist settle. Nodes that refreeze grow rime.
- Crystal: energy spokes and a ring of light run out to glowing crystals that keep growing while the meteor is down, arcs link them to a gem floating above the core, small crystals sprout as players break the crust, and the arcs brighten as it breaks.
- When the core cracks the effects shatter; when the meteor cools they wither and sink.

The scene is seeded by the event, so everyone sees the same one, and a player who joins mid-event sees it at the same moment. The pieces never collide or block mining, and stay off the paths, the spawn, the fountain and the mining area. Tuning is in `Config.LandingFX`, the layout and rules in `Shared.LandingFX`. In Studio, setting the boolean attribute `DevLandingFX` on ReplicatedStorage to `false` turns them off.

## Working on it

1. Open the saved place in Studio.
2. `rojo serve` in this folder, then connect from the Rojo plugin.
3. Run the specs from the command bar or `execute_luau` in Edit mode (no Play needed): `require(game.ServerStorage.Tests.Runner)()`. Pass a name (or part of one) to run only matching specs, e.g. `require(game.ServerStorage.Tests.Runner)("Pacing")`. Pure-logic modules (Format, MiningPower, Refining, Rewards, Telemetry, MeteorTypes, MineralIndex, Rebirth, CallMeteor, HudLayout, Pacing, Net, AtmosphereMood, LandingFX) have a `<Name>.spec` under `tests/`, synced to `ServerStorage.Tests`. The runner requires fresh clones of `Shared` and `Server.Lib`, so edits show up without restarting Studio.
4. Play. Unpublished places can't use DataStores, so profiles are kept in memory for that play session only (the tutorial starts from step 1 every time). In Studio the countdown is shortened to 25 s (`Config.Meteor.StudioCountdown`, set it to `nil` for the real 2:00 / 4:00 timings).

Studio-only dev hooks (none exist in a live server). Set `Workspace.DevHudHelpersVisible` to `true` before Play to show two helper buttons on the HUD:
- **[Studio] Meteor now** skips to the last 10 s of the countdown.
- **[Studio] Away 1 hour** runs an hour of offline refining, to check the "While you were away" panel.

Command bar hooks, all `BindableFunction`s in `ServerStorage` (`local p = game.Players:GetPlayers()[1]`):
- `DevGrant:Invoke(p, cash, ore, shards, pickaxeTier)`: every argument after the player is optional. `pickaxeTier` sets your pickaxe tier (restyling the tool), e.g. `DevGrant:Invoke(p, nil, nil, nil, 5)` for a tier-5 pickaxe that mines Crystal. Use it to test the shop, and `DevGrant:Invoke(p, 10e6)` to afford a rebirth.
- `DevMineral:Invoke(p, "starfallIron")` adds one mineral through the real path (toast, page announcement, title); a page id (`"Iron"`) adds one of every mineral on that page.
- `DevBench:Invoke(p, 1000)` measures the ore hot path: it gains ore 1000 times (into a borrowed, empty top-tier backpack; yours comes back afterwards) and returns the elapsed ms and how many State snapshots went out. State is batched, so expect one.
- `DevMeteor:Invoke("Crystal")` brings a meteor of that type (Iron, Ice or Crystal) down soon: during a countdown it lands in 10 s; if a meteor is down, that one ends early (it cools) and yours lands 10 s into the next countdown.
- `DevLevel:Invoke(p, level)` sets your player level (1 to 50).
- `DevGear:Invoke(p, 5, 8)` sets your pickaxe tier and backpack tier (1 to 8 each; `nil` leaves one as is), with stat levels at the first level of the tier, and restyles the pickaxe. It returns their names.

The same in chat while playing (Studio only; the reply shows as a notice): `/meteor crystal`, `/pickaxe 5`, `/backpack 8`.

String attributes on `ServerStorage` (set them before the play session unless noted):
- `DevFakeTiers`, e.g. `1,1,1,8`: each number adds a pretend active player with that pickaxe tier, so you can test meteor sizing solo. The meteor model's `ServerPower` attribute shows what it is sized for. 
- `DevMeteorType` (`Iron`, `Ice` or `Crystal`): forces the type. It is read when each countdown starts, so set it before the session or it applies from the next countdown.
- `DevPasses`, e.g. `TwoXOre,VIP`: grants those passes. Setting it during play grants them to everyone in the session.

For isolating pre-landing rendering/audio issues, set the boolean attribute `DevMeteorApproachFX` on **ReplicatedStorage** to `false`. This Studio-only control disables the approach fireball, fire, light, trail, smoke, looping rumble and approach camera shake. The countdown, landing effects and gameplay still run. Set it to `true` or remove the attribute to restore approach effects on the next countdown. Disabling effects is a diagnostic step; it does not establish or repair the cause of a whole-PC crash.

## Polished map

Open `MeteorShift-map-polished.rbxl` for the October 1 map art pass, including town buildings, twenty plot entrances, production machinery, landscape landmarks and original Blender rock meshes. Editable Blender assets are in `assets/map-art/`; authoring instructions and validation are in [tools/map-art/README.md](tools/map-art/README.md). The map is saved in the place and is not rebuilt by Rojo at runtime.
