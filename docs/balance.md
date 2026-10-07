# Economy pacing model

`Shared.Pacing` (assumptions in `Config.Balance`, checks in `tests/Pacing.spec.luau`) simulates a fresh free player from Config alone. An optional fixed-level equipped Drillbot provides a controlled pet comparison. It is a check on pacing, not a forecast: real telemetry (spec 13) replaces it.

## Targets

The economy follows the Roblox simulator rhythm: millions on day 1, billions within a few short sessions (15 to 45 minutes each).

| Target | Model |
|---|---|
| Steel Pickaxe in the first 5 minutes | 3:00 |
| First rebirth ($88K) 10 to 20 minutes in | 14:00 |
| Laps lengthen to the fourth rebirth, then hold | 14, 17, 19, 23, then about 25 minutes |
| Billions | rebirth 6 ($2.6B) at about 2 hours |
| A level 1 line's 2-hour offline cap, a meaningful welcome back | about $90K |

`tests/Pacing.spec.luau` asserts all of them.

## Model

- **Meteors:** the first impact is `Meteor.FirstCountdown` (90 s) in, then one every full cycle: impact 3 s + active 150 s + end 5 s + cleanup 5 s + countdown 180 s = **343 s**. The type is picked by `Meteor.Types` weights (Iron 60, Ice 25, Crystal 15) and every player mines it; the refinery's clearance by level (below) sets what the ore is worth per line-second. Ice's Refreeze twist and HP multiplier are ignored (they cost the crowd time, not the player's ore); so is Crystal's Resonance. Debris always drops Iron.
- **Mining:** the player mines the meteor while it is active and debris between meteors (`Debris.YieldFraction` = a quarter of a hit, `DebrisActivityShare` = 0.5 of that time). Ore rate = backpack / (fill time + `TripSeconds` 40 s), fill time = hits needed x swing / `HitsPerMinuteShare` 0.7. Ore per hit is flat per tier (1, 2, 3, 5, 7, 10, 14, 20) and the backpack tracks it, so a full load is 50 to 90 hits at every stage. Ore goes to the hopper.
- **Line:** `min(conveyor, refinery)` bars per second, limited by hopper stock and collection post room, same as `Server.Lib.Refining`. Conveyor and refinery rates are ore per second and follow what a player mines at that stage (0.25 at level 1 up to about 18).
- **Gear:** one pickaxe and one backpack (`Shared.Gear`). A tier is bought as a bundle: the Power (or Capacity) levels up to the tier's cap plus the evolve price (`Gear.bundleCost`). Speed, Reach and Crit levels are the player's own side budget and don't move income in the model.
- **Selling and shopping:** every 60 s the player sells the bars. Then greedily buys, among the next pickaxe, backpack, conveyor and refinery level they hold the shards for and that raise income, the one with the shortest payback, saving up if it is out of reach. Hopper and collection post levels are never bought (they only matter offline).
- **Shards:** `Balance.ShardsPerMeteor` = 10 per finished meteor on average (the 5-shard floor plus an average share of the bonus pool, over the meteors that crack; about 13 when one cracks). Shard prices start at the Meteorite Pick (15) and the line's level 5.
- **Rebirth (optional, `Options.rebirths`):** once cash covers `Rebirth.cost` the player relocates. Cash, pickaxe, backpack, hopper, conveyor and collection post reset; the refinery level, player level and shards stay; every sale pays `Rebirth.multiplier`. Meteor weights and clearance rules stay the same after rebirth.
- No mineral index or quantity passes. Pets are absent unless `Options.drillbotLevel` is supplied. A four-hour run is about 7,200 steps.

## Rebirth cost and multiplier

Rebirth costs come from an explicit list (`Config.Rebirth.Costs`) tuned in the model so the laps are 14, 17, 19, 23 and then about 25 minutes, and pay `CashMult`^n on bar sales (x5, x25, ...); past the 16 listed ranks Legacy ranks cost x2.3 more and pay x2. The old rule (every rank x5 on cost and multiplier, first rebirth $15M at 45 minutes) was replaced; see docs/economy-rework.md.

## Timeline (model)

Times are minutes. The first lap, from `Pacing.simulate` with the shopping rule (the shortest payback, among what the player's level allows):

| Time | Event |
|---|---|
| 1:30 | first meteor countdown ends |
| 2 | Refinery 2, Leather Pack (backpack 2) |
| 3 | Conveyor 2, Steel Pickaxe |
| 4 to 5 | Refinery 3, Conveyor 3, Backpack 3 and 4, Drill Pick, Plasma-tier gear within level gates |
| 7 | Conveyor 4 |
| 14 | first rebirth ($88K), then 17, 19, 23, 24, 25 minutes |

Every level gained also opens a Supply Crate (`Config.Hooks.SupplyCrate`): its expected cash, a few tens of seconds of the line's income, is part of the model.

## Ore clearance

Everyone mines every meteor type at their pickaxe's full rate and Iron/Ice/Crystal come up by weight alone (60/25/15), so no lobby is stuck on one type. What a player's **level** decides is how much of each hit's ore they collect (`Shared.Levels.oreYield`, `Config.Levels`):

- Iron is cleared at level 1, Frost at 12, Crystal at 24, Alien (boss, rebirth 3 and up) at 38. Max player level is 50.
- Under its clearance level an ore yields `0.4 ^ ((clear - level) / (clear - 1))` of a hit: 40% at level 1, rising geometrically to 100% at the clearance level. Nobody is blocked and the refinery always runs at full speed; the bar price is the same for everyone.
- XP (`Config.Levels`): `15 + 0.5 x level^2` to the next level, about 70 XP per meteor you take part in. Level 10 comes within the first hour, level 50 takes about 26 hours.
- Pickaxe/backpack tiers 5 to 8 and conveyor/refinery levels 5 to 8 need player level 10, 16, 24 and 34 (`EvolveLevel`). The hopper and collection post are not gated.

The model (`Pacing`) levels the player from finished meteors, weights each ore by its yield at the current level and applies the level gates to its purchases.

## Pet perks and clearance

The pet roster now uses explicit level 1 and level 10 values, interpolated linearly; [the pet brief](pets.md) lists every endpoint and role cap. Equipped values add per role before capping. Drillbot costs 99 Robux and Solar Phoenix 199 Robux as fixed game passes; eggs still cost earned Core Shards and keep their published odds and pity. No pet changes mineral odds.

- Yield multiplies the ore of every validated player hit after the existing meteor/debris and pass quantity multipliers. It preserves fractional ore for the existing inventory remainder. Mining Power and crit damage are separate.
- Scholar multiplies player XP in `LevelService:AddXp`, including per-hit XP and the cracked-core bonus. This reaches the clearance levels sooner, without changing the clearance formula, bar prices or tier evolution requirements. Pet XP and its 400-XP duplicate reward are unchanged.
- Shards multiplies the complete cracked-core payout and rounds down once. Contribution, podium ranking and mineral rolls keep their existing rules.
- Vault multiplies both hopper and collection post capacity by the same value, in live play and offline catch-up. It raises storage room without changing conveyor or refinery speed, and unequipping it never deletes existing stock.
- Miner still needs the owner's recent validated swing and sends its ore straight to the hopper. Hauler moves a share of the current backpack capacity per second; Pack raises that capacity. Swift shortens swings, Merchant raises bar-sale value, Crit adds absolute chance points, and Sprint raises base walking speed without overriding another system's speed change.

The pacing targets and timeline above describe the default pet-free run. The optional comparison equips a Drillbot from the start at level 5, with **Miner 31.6667%, Swift 13.3333% and Yield 14.4444%**, read from `Shared.Pets.bonuses`. Its level stays fixed through the run and rebirths; the model does not simulate obtaining it or pet XP growth. `Pacing.simulate(7200, { rebirths = 1, drillbotLevel = 5 })` selects that treatment, and `result.petBonuses` records the exact values.

| Treatment | First rebirth | Change from pet-free |
|---|---|---|
| No pets, `Pacing.simulate(7200, { rebirths = 1 })` | **45:00 (2,700 s)** | baseline |
| Equipped Drillbot level 5 | **58:00 (3,480 s)** | **13:00 longer (+28.9%)** |

Both runs buy the same 17 items for **$1,284,912** before first rebirth. The added supply changes their order and timing: Steel is bought at 10:00 without pets and 12:00 with Drillbot; Drill Pick at 12:00 and 18:00. In the 45:00 snapshots, taken before that tick's sale, the pet-free run has sold $15.510M and the Drillbot run $9.258M, despite the latter's higher projected income at that point ($1.007M/min versus $0.806M/min). The delay therefore does not come from buying more upgrades. The inherited shopping rule optimises income payback and does not promise the earliest rebirth.

Swift shortens both the owner's and miner pet's swing. Yield multiplies the owner's ore and the pet's ore, matching `NodeService:PetHit`. The miner supplies ore directly to the hopper at its configured share of ore per swing during the backpack-filling portion of each fill-and-trip cycle. This assumes repeated validated owner hits keep it active and a target remains in reach while filling; it is inactive for the entire 40-second trip home. The owner's 70% hit utilisation affects fill time, while the miner uses every swing during that active portion. Its hits grant no player XP, shards, mineral rolls or additional finished meteors. This is an optimistic supply estimate: targets and reach can interrupt a real miner, and the live service's 0.1-second scheduling tick can round its swing interval upward.

Prices, rates, storage capacities, meteor weights, clearance, the shopping rule and `Config.Balance` constants are unchanged. Refinery and conveyor throughput still cap extra pet ore, so the supply bonus does not translate directly into the same percentage reduction in rebirth time.

The comparison inherits two approximations of the original model. Swift and Yield change the blend of high-value meteor ore and cheap debris Iron: a faster fill benefits long debris fills proportionally more than short meteor fills, which can reduce bar value per line unit while throughput is capped. Also, the model averages all queued ore and stores its refining cost using the player's clearance **when it was mined**. A larger early backlog can retain that expensive cost after the player levels up; live refining uses current clearance on every tick. These approximations and the changed purchase schedule limit how directly the 13-minute model delay predicts live play. The pet-free baseline and these rules are preserved for this comparison; no balance numbers were retuned.

## What changed in this rebase

- Ore per hit 1 to 450 became 1 to 20 (flat per tier), and backpack capacity 50 to 40,000 became 50 to 1,800, so veterans mine more per hit but not hundreds of times more. Everything priced in cash was rescaled to keep the numbers big: bar prices x10 (Iron $50, Frost $1,200, Crystal $30,000) and line, backpack and pickaxe prices re-fitted to the pacing model.
- One pickaxe and one backpack replace the eight-item shop (see README, `Shared.Gear`). The bundle prices above include their stat levels.
- Debris no longer drops Frost (cyan rocks paid a Basic Pickaxe about 6x an Iron meteor per swing).
