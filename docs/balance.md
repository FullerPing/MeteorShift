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

- **Meteors:** the first impact is `Meteor.FirstCountdown` (120 s) in, then one every full cycle: impact 3 s + active 150 s + end 5 s + cleanup 5 s + countdown 240 s = **403 s**. The type is picked by `Meteor.Types` weights (Iron 60, Ice 25, Crystal 15) and every player mines it; the refinery's clearance by level (below) sets what the ore is worth per line-second. Ice's Refreeze twist and HP multiplier are ignored (they cost the crowd time, not the player's ore); so is Crystal's Resonance. Debris always drops Iron.
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

## Refinery clearance

Everyone mines every meteor type at their pickaxe's full rate and Iron/Ice/Crystal come up by weight alone (60/25/15), so no lobby is stuck on one type. What a player's **level** decides is how fast their refinery handles each ore (`Shared.Levels.clearance`, `Config.Levels`):

- Iron is cleared at level 1, Frost at 4, Crystal at 6.
- Under its level an ore is refined at `0.35^levelsShort` of the line's speed (it costs `1 / that` line time per ore). The bar price is the same for everyone and nobody is blocked.
- At level 1 each ore pays about the same per line-second as Iron (Frost 24x the price at 0.35^3, Crystal 600x at 0.35^5 are both about 3x Iron per line unit); each level cleared multiplies that ore's pay by 2.86 until it is cleared. So the early game matches the old curve, and levels are the climb that replaces pickaxe-gated meteors.
- XP (`Config.Levels`): 30 to level 2, x1.3 per level; about 70 XP per meteor you take part in (per hit, plus a bonus when a core you hit cracks). About level 4 at 10 to 15 minutes, level 6 at 30 minutes. Evolving to tier 5+ needs level 5, 7, 9, 11 (`EvolveLevel`).

The model (`Pacing`) levels the player from finished meteors (70 XP each), mixes the three ores by weight, and tracks the line time each ore costs. Mining quantity (pickaxe, backpack) only matters once the line is faster than the ore supply.

## Pet perks and clearance

The pet roster now uses explicit level 1 and level 10 values, interpolated linearly; [the pet brief](pets.md) lists every endpoint and role cap. Equipped values add per role before capping. Drillbot costs 99 Robux and Solar Phoenix 199 Robux as fixed game passes; eggs still cost earned Core Shards and keep their published odds and pity. No pet changes mineral odds.

- Yield multiplies the ore of every validated player hit after the existing meteor/debris and pass quantity multipliers. It preserves fractional ore for the existing inventory remainder. Mining Power and crit damage are separate.
- Scholar multiplies player XP in `LevelService:AddXp`, including per-hit XP and the cracked-core bonus. This reaches Frost clearance at level 4 and Crystal clearance at level 6 sooner, without changing the clearance formula, bar prices or tier evolution requirements. Pet XP and its 400-XP duplicate reward are unchanged.
- Shards multiplies the complete cracked-core payout and rounds down once. Contribution, podium ranking and mineral rolls keep their existing rules.
- Vault multiplies both hopper and collection post capacity by the same value, in live play and offline catch-up. It raises storage room without changing conveyor or refinery speed, and unequipping it never deletes existing stock.
- Miner still needs the owner's recent validated swing and sends its ore straight to the hopper. Hauler moves a share of the current backpack capacity per second; Pack raises that capacity. Swift shortens swings, Merchant raises bar-sale value, Crit adds absolute chance points, and Sprint raises base walking speed without overriding another system's speed change.

The pacing targets and timeline above still describe the existing free-player model. This pass changes no `Config.Balance` numbers and does not yet include pets in `Shared.Pacing`; the later Drillbot-at-level-5 comparison will report its effect without retuning the economy.

## What changed in this rebase

- Ore per hit 1 to 450 became 1 to 20 (flat per tier), and backpack capacity 50 to 40,000 became 50 to 1,800, so veterans mine more per hit but not hundreds of times more. Everything priced in cash was rescaled to keep the numbers big: bar prices x10 (Iron $50, Frost $1,200, Crystal $30,000) and line, backpack and pickaxe prices re-fitted to the pacing model.
- One pickaxe and one backpack replace the eight-item shop (see README, `Shared.Gear`). The bundle prices above include their stat levels.
- Debris no longer drops Frost (cyan rocks paid a Basic Pickaxe about 6x an Iron meteor per swing).
