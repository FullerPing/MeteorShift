# Economy pacing model (spec 7.4)

`Shared.Pacing` (assumptions in `Config.Balance`, checks in `tests/Pacing.spec.luau`) simulates a fresh free player from Config alone. It is a check on early pacing, not a forecast: real telemetry (spec 13) replaces it.

## Model

- **Meteors:** the first impact is `Meteor.FirstCountdown` (120 s) in, then one every full cycle: impact 3 s + active 150 s + end 5 s + cleanup 5 s + countdown 240 s = **403 s** (production timings, not the Studio countdown). Until the player's pickaxe meets Ice's tier (3) every meteor is Iron. From then on each meteor is worth its **expected value**: the type is picked by `Meteor.Types` weights (Iron 60, Ice 25, Crystal 15) and a type the pickaxe can't mine drops to the next one down, so at tier 3 or 4 Ice comes up 40% of the time (Ice's 25 plus Crystal's 15) and bars are worth 0.6 x $5 + 0.4 x $120 = $51 per meteor ore. **Assumption: the whole lobby holds the player's own pickaxe tier**, so the 25% eligibility rule is met exactly when the player's tier is. Ice's Refreeze twist and HP multiplier are ignored (they cost the crowd time, not the player's ore); so is Crystal's Resonance. Debris always drops iron.
- **Mining:** the player mines the meteor while it is active and debris between meteors (`Debris.YieldFraction` = a quarter of a hit, `DebrisActivityShare` = 0.5 of that time). Ore rate = backpack / (fill time + `TripSeconds` 40 s), fill time = hits needed x swing / `HitsPerMinuteShare` 0.7. Ore goes to the hopper.
- **Line:** `min(conveyor, refinery)` bars per second, limited by hopper stock and collection post room, same as `Server.Lib.Refining`. Income in the long run = `min(ore supply, line rate)` x the blended bar price of meteor ore and debris iron. The refinery's iron-first ordering is ignored (hopper ore is valued at its average).
- **Selling and shopping:** every 60 s the player sells the bars. Then greedily buys, among the next pickaxe, backpack, conveyor and refinery level they hold the shards for and that raise income, the one with the shortest payback (cost / income gained), saving up if it is out of reach. Hopper and collection post levels are never bought (they only matter offline). Core Shards come from the shard floor of each meteor (5 per event).
- No passes, no rebirth, no mineral index. It covers the first sessions of a free player; a four-hour run is about 7,200 steps (10 ms).

## Inflation factor

Every price in Config (pickaxes, backpacks, station upgrades, bar prices) is the spec's own from 7.1 to 7.3 and 6.5, so the factor between the spec's listed prices and the game's is **1**. The spec was already an inflated economy (millions and billions); nothing was deflated. The 7.4 dollar checkpoints therefore need no translation for inflation. What did not hold was the spec's own arithmetic (see below), and the time-based checkpoints are the primary targets.

## Checkpoints

| 7.4 checkpoint | Type | Target asserted | Model result |
|---|---|---|---|
| Steel Pickaxe affordable after about one meteor cycle | time | lifetime sales reach $750 between the first impact (2:00) and one cycle after the first cycle ends (15:26) | 11:00 (660 s) |
| By 30 min: Steel + Drill | time | pickaxe tier 3 owned by 35:00 (30:00 target, 5 min slack) | Steel 20:00, Drill 28:00, so it passes at 30:00 too, with two minutes to spare |
| By 30 min: backpack tier 2 or 3 | time | tier 2 to 3 at 30:00 | tier 2 at 12:00 |
| By 30 min: a refinery upgrade | time | refinery level 2+ at 30:00 | level 2 at 7:00 (conveyor level 2 at 16:00) |
| "Cash in the tens of thousands" in the first session | dollar, **deliberately not met at 30 min** | total sales by 30 min at least $3K (covers the gear owned), by 60 min at least $10K | $3.9K at 30 min, $109K at 60 min, $496K at 2 h. Tens of thousands at 30 min is not reachable: a level 1 line makes 15 bars a minute and the Drill Pick (Ice) only comes at 28:00. It arrives in the first hour |
| Plasma Pick within 2 to 3 h (added in review) | time | Plasma in reach (lifetime sales at least $90K) and bought by 3:00:00 | in reach at 57:00, bought at 1:53:00 (the greedy buys line upgrades first) |
| Level 1 line, 2 h offline cap worth about $9K at most | dollar | $8K to $9.5K | $9,000 (0.25 ore/s x 7,200 s x $5) |
| Ice and Crystal push income past $1M/hour in sessions 2 to 4 | reported, not asserted | | Income is $290K/hour at 1:00:00 and $434K/hour from 2:00:00 (Ice only), passing $1M/hour at 5:21 when Meteorite (tier 5) turns Crystal meteors on |
| First rebirth ($10M) | reported, not asserted | | Not run: sales are about $1.5M by 5 h and $4.9M by 6 h, so $10M lands around 6.5 h (the model is Iron/Ice/Crystal only, no index bonus or passes) |

## Why the shipped numbers missed, and what changed

The spec's 7.4 assumed several refineries; the game has one production line whose level 1 makes 0.25 bars/s ($75 a minute). With the spec's prices a player would earn $2.2K in 30 minutes, when Steel + Drill + backpack 2 + a refinery upgrade cost $10,750 (750 + 8,000 + 500 + 1,500): with the old prices the model buys the Drill Pick at **79 minutes** (lifetime sales reach its $8K at 62:00). To reproduce, set the three old costs below in a cloned `Config` and run `Pacing.simulate(8 * 3600)`; `result.purchases` lists the Drill Pick at 4,740 s. The offline checkpoint pins the level 1 line (rate x price), so the early upgrades were repriced instead:

| Config | Old | New |
|---|---|---|
| `Pickaxes[3]` Drill Pick cost | $8,000 | $1,500 |
| `Home.Stations.refinery` level 2 cost | $1,500 | $400 |
| `Home.Stations.conveyor` level 2 cost | $1,200 | $300 |

Everything else (level 1 rates, bar prices, later tiers, shards, rebirth) is unchanged. The Drill Pick now costs about two Steel Pickaxes, but it unlocks Ice meteors, whose $120 bars carry the economy past the early game.

## Timeline (model, with Ice and Crystal expected value)

Times are m:ss under an hour and h:mm:ss from an hour on.

| Time | Event |
|---|---|
| 2:00 | first meteor impact |
| 7:00 | Refinery level 2 ($400) |
| 11:00 | lifetime sales reach $750 (Steel in reach) |
| 12:00 | Leather Pack ($500) |
| 16:00 | Conveyor level 2 ($300), line at 0.75 bars/s |
| 20:00 | Steel Pickaxe ($750) |
| 28:00 | Drill Pick ($1,500), Ice meteors start |
| 40:00 | Refinery level 3 ($20K) |
| 47:00 | Conveyor level 3 ($15K) |
| 49:00 | Miner's Pack ($6K) |
| 1:00:00 | Reinforced Pack ($70K) |
| 1:41:00 | Refinery level 4 ($250K) |
| 1:53:00 | Plasma Pick ($90K) |
| 5:20:00 | Meteorite Pick ($1.2M + 25 shards), Crystal meteors start |
| 5:34:00 to 6:20:00 | Conveyor 4, Ore Hauler, Refinery 5, Conveyor 5 |
| 7:08:00 | Nova Pick ($15M + 80 shards) |

Drill to Plasma is a 60x price jump, but Ice bars ($120) make the gap a non-issue: income at the Drill is already $1.7K/min, so Plasma is in reach at 57:00 and the greedy only delays it by buying line upgrades first. No Plasma price change was needed.

The greedy order buys the line before Steel because a refinery upgrade pays back faster than a pickaxe while the line is the bottleneck. A player who buys Steel first is only slightly behind.
