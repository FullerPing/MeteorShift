# Economy pacing model

`Shared.Pacing` (assumptions in `Config.Balance`, checks in `tests/Pacing.spec.luau`) simulates a fresh free player from Config alone. It is a check on pacing, not a forecast: real telemetry (spec 13) replaces it.

## Targets

The economy follows the Roblox simulator rhythm: millions on day 1, billions within a few short sessions (15 to 45 minutes each).

| Target | Model |
|---|---|
| Steel Pickaxe in the first 5 to 10 minutes | 0:05 |
| Drill Pick (Ice meteors pay) by 15 minutes | 0:10 |
| Meteorite Pick (Crystal meteors pay) by 30 minutes | 0:24 |
| First rebirth ($15M) 40 to 60 minutes in | 0:47 |
| A rebirth at a steady pace after that (each within 45 minutes of the last) | 1:17, 1:44, 2:17, 2:44 |
| Billions | rebirth 4 ($1.9B) at 2:17, about 4 to 6 sessions |
| A level 1 line's 2-hour offline cap, a meaningful welcome back | about $90K |

`tests/Pacing.spec.luau` asserts all of them.

## Model

- **Meteors:** the first impact is `Meteor.FirstCountdown` (120 s) in, then one every full cycle: impact 3 s + active 150 s + end 5 s + cleanup 5 s + countdown 240 s = **403 s**. Until the player's pickaxe meets Ice's tier (3) every meteor is Iron. From then on each meteor is worth its **expected value**: the type is picked by `Meteor.Types` weights (Iron 60, Ice 25, Crystal 15) and a type the pickaxe can't mine drops to the next one down. **Assumption: the whole lobby holds the player's own pickaxe tier.** Ice's Refreeze twist and HP multiplier are ignored (they cost the crowd time, not the player's ore); so is Crystal's Resonance. Debris always drops Iron.
- **Mining:** the player mines the meteor while it is active and debris between meteors (`Debris.YieldFraction` = a quarter of a hit, `DebrisActivityShare` = 0.5 of that time). Ore rate = backpack / (fill time + `TripSeconds` 40 s), fill time = hits needed x swing / `HitsPerMinuteShare` 0.7. Ore per hit is flat per tier (1, 2, 3, 5, 7, 10, 14, 20) and the backpack tracks it, so a full load is 50 to 90 hits at every stage. Ore goes to the hopper.
- **Line:** `min(conveyor, refinery)` bars per second, limited by hopper stock and collection post room, same as `Server.Lib.Refining`. Conveyor and refinery rates are ore per second and follow what a player mines at that stage (0.25 at level 1 up to about 18).
- **Gear:** one pickaxe and one backpack (`Shared.Gear`). A tier is bought as a bundle: the Power (or Capacity) levels up to the tier's cap plus the evolve price (`Gear.bundleCost`). Speed, Reach and Crit levels are the player's own side budget and don't move income in the model.
- **Selling and shopping:** every 60 s the player sells the bars. Then greedily buys, among the next pickaxe, backpack, conveyor and refinery level they hold the shards for and that raise income, the one with the shortest payback, saving up if it is out of reach. Hopper and collection post levels are never bought (they only matter offline).
- **Shards:** `Balance.ShardsPerMeteor` = 10 per finished meteor on average (the 5-shard floor plus an average share of the bonus pool, over the meteors that crack; about 13 when one cracks). Shard prices start at the Meteorite Pick (15) and the line's level 5.
- **Rebirth (optional, `Options.rebirths`):** once cash covers `Rebirth.cost` the player relocates. Cash, pickaxe, backpack, hopper, conveyor and collection post reset; the refinery level and shards stay; every sale pays `Rebirth.multiplier`. The model assumes the lobby falls back to the player's new (tier 1) pickaxe, which is pessimistic: a real lobby has other players.
- No passes, no mineral index. A four-hour run is about 7,200 steps (10 ms).

## Rebirth cost and multiplier

Rebirth costs `BaseCost` x `CostGrowth`^n ($15M, $75M, $375M, $1.9B, $9.4B) and pays `CashMult`^n on bar sales (x5, x25, x125, ...). They are equal on purpose: with equal growth each rebirth takes about as long as the last (about 30 minutes in the model). With the old x10 cost and x2 multiplier the second rebirth was 2:25 in and the third out of reach, because every rebirth made the next one five times slower.

## Timeline (model)

Times are m:ss under an hour and h:mm:ss from an hour on. Prices are the bundles above.

| Time | Event |
|---|---|
| 2:00 | first meteor impact |
| 0:03 to 0:05 | Refinery 2 ($800), Leather Pack ($1K), Conveyor 2, Steel Pickaxe ($1.3K) |
| 0:10 | Drill Pick ($6.2K), Ice meteors start paying |
| 0:11 to 0:12 | Refinery 3, Conveyor 3, Miner's Pack, Reinforced Pack |
| 0:19 | Plasma Pick ($30K) |
| 0:24 | Meteorite Pick ($152K + 15 shards), Crystal meteors start paying |
| 0:25 to 0:26 | Refinery 5, Conveyor 5 |
| 0:39 | Cargo Rig ($540K) |
| 0:47 | first rebirth ($15M), income about $800K/min before it |

The line, not mining, caps income from the Drill on: ore supply is 0.3 ore/s with the starter kit and about 10 ore/s with the best, and each line level is priced to follow it.

## Under-tier meteors

A pickaxe below an Ice or Crystal meteor's tier mines the meteor's own ore at its own pickaxe's worth (`Shared.MeteorTypes`, `Config.Meteor.UnderTier`). Each meteor type up from the best one your pickaxe mines at full speed pays `TypeMult` (3) times the one below: to a tier 1 or 2 pickaxe an Ice meteor is worth 3 Iron meteors and a Crystal meteor 9; to a tier 3 or 4, Crystal is worth 3 Ice meteors.

- **Your own meteor** is what you bring home from it at full speed, trips included (`MeteorTypes.meteorHaul`, pinned to `Pacing.oreRate` by `tests/Pacing.spec`).
- **Per hit** each crust hit pays the same multiple of a hit on your own ore, in the meteor's ore; fractions add up over hits and stay banked for the session. A full backpack no longer spends the allowance on ore that is dropped.
- **Per meteor** pay stops at that multiple of your own meteor (`underTierCap`).
- **Speed:** on your own a crust node takes 15 s per tier short (`NodeSecondsPerTier`).

What one under-tier meteor pays, with the backpack tier matching the pickaxe tier:

| Pickaxe | Backpack | Own meteor | Ice pays | Crystal pays |
|---|---|---|---|---|
| Basic | Canvas Sack (50) | 90 Iron, $4.5K | 11 Frost, $13.6K | 1.4 Crystal, $40.7K |
| Steel | Leather Pack (150) | 227 Iron, $11K | 28 Frost, $34K | 3.4 Crystal, $102K |
| Drill | Miner's Pack (250) | 377 Frost, $452K | full speed | 45 Crystal, $1.36M |
| Plasma | Reinforced Pack (400) | 640 Frost, $768K | full speed | 77 Crystal, $2.3M |

The 2x Ore pass doubles all of it, as it does all mining.

## What changed in this rebase

- Ore per hit 1 to 450 became 1 to 20 (flat per tier), and backpack capacity 50 to 40,000 became 50 to 1,800, so veterans mine more per hit but not hundreds of times more. Everything priced in cash was rescaled to keep the numbers big: bar prices x10 (Iron $50, Frost $1,200, Crystal $30,000) and line, backpack and pickaxe prices re-fitted to the pacing model.
- One pickaxe and one backpack replace the eight-item shop (see README, `Shared.Gear`). The bundle prices above include their stat levels.
- Debris no longer drops Frost (cyan rocks paid a Basic Pickaxe about 6x an Iron meteor per swing).
