# Economy pacing model (spec 7.4)

`Shared.Pacing` (assumptions in `Config.Balance`, checks in `tests/Pacing.spec.luau`) simulates a fresh free player from Config alone. It is a check on early pacing, not a forecast: real telemetry (spec 13) replaces it.

## Model

- **Meteors:** Iron only. The first impact is `Meteor.FirstCountdown` (120 s) in, then one every full cycle: impact 3 s + active 150 s + end 5 s + cleanup 5 s + countdown 240 s = **403 s** (production timings, not the Studio countdown).
- **Mining:** the player mines the meteor while it is active and debris between meteors (`Debris.YieldFraction` = a quarter of a hit, `DebrisActivityShare` = 0.5 of that time). Ore rate = backpack / (fill time + `TripSeconds` 40 s), fill time = hits needed x swing / `HitsPerMinuteShare` 0.7. Ore goes to the hopper.
- **Line:** `min(conveyor, refinery)` bars per second, limited by hopper stock and collection post room, same as `Server.Lib.Refining`. Income in the long run = `min(ore supply, line rate)` x $5 per Iron bar.
- **Selling and shopping:** every 60 s the player sells the bars. Then greedily buys, among the next pickaxe, backpack, conveyor and refinery level they hold the shards for and that raise income, the one with the shortest payback (cost / income gained), saving up if it is out of reach. Hopper and collection post levels are never bought (they only matter offline). Core Shards come from the shard floor of each meteor (5 per event).
- No passes, no rebirth, no mineral index, no Ice or Crystal meteors. It covers the first sessions of a free player; a run is about 3,600 steps for two hours (a few milliseconds).

## Inflation factor

Every price in Config (pickaxes, backpacks, station upgrades, bar prices) is the spec's own from 7.1 to 7.3 and 6.5, so the factor between the spec's listed prices and the game's is **1**. The spec was already an inflated economy (millions and billions); nothing was deflated. The 7.4 dollar checkpoints therefore need no translation for inflation. What did not hold was the spec's own arithmetic (see below), and the time-based checkpoints are the primary targets.

## Checkpoints

| 7.4 checkpoint | Type | Target asserted | Model result |
|---|---|---|---|
| Steel Pickaxe affordable after about one meteor cycle | time | lifetime sales reach $750 between the first impact (2:00) and one cycle after the first cycle ends (15:26) | 11:00 (660 s) |
| By 30 min: Steel + Drill | time | pickaxe tier 3 owned at 30:00 | Steel 20:00, Drill 28:00 |
| By 30 min: backpack tier 2 or 3 | time | tier 2 to 3 at 30:00 | tier 2 at 12:00 |
| By 30 min: a refinery upgrade | time | refinery level 2+ at 30:00 | level 2 at 7:00 (conveyor level 2 at 16:00) |
| "Cash in the tens of thousands" in the first session | dollar, translated | total sales by 30 min at least $3K (covers the gear owned), by 60 min at least $10K | $3.8K at 30 min, $10.6K at 60 min, $24K at 2 h. Tens of thousands is a first-hour figure, not a 30-minute one: a level 1 line makes 15 bars a minute |
| Level 1 line, 2 h offline cap worth about $9K at most | dollar | $8K to $9.5K | $9,000 (0.25 ore/s x 7,200 s x $5) |
| Ice and Crystal push income past $1M/hour in sessions 2 to 4 | not modelled | | Iron-only income tops out near $750 a minute with tier 4 and refinery level 4 (10 h in); the free player's jump comes from the Drill Pick (Ice meteors, $120 bars) |
| First rebirth ($10M) | not modelled | | Never reached by Iron alone (about $350K sold in 10 h). It needs Ice and Crystal meteors, upgraded stations and the index bonus, so the model cannot say when it becomes affordable |

## Why the shipped numbers missed, and what changed

The spec's 7.4 assumed several refineries; the game has one production line whose level 1 makes 0.25 bars/s ($75 a minute). With the spec's prices a player would earn $2.2K in 30 minutes, when Steel + Drill + backpack 2 + a refinery upgrade cost $10.2K: the Drill Pick was 106 minutes away. The offline checkpoint pins the level 1 line (rate x price), so the early upgrades were repriced instead:

| Config | Old | New |
|---|---|---|
| `Pickaxes[3]` Drill Pick cost | $8,000 | $1,500 |
| `Home.Stations.refinery` level 2 cost | $1,500 | $400 |
| `Home.Stations.conveyor` level 2 cost | $1,200 | $300 |

Everything else (level 1 rates, bar prices, later tiers, shards, rebirth) is unchanged. The Drill Pick now costs about two Steel Pickaxes, but it unlocks Ice meteors, whose $120 bars carry the economy past the early game.

## Timeline (model, Iron only)

| Time | Event |
|---|---|
| 2:00 | first meteor impact |
| 7:00 | Refinery level 2 ($400) |
| 11:00 | lifetime sales reach $750 (Steel in reach) |
| 12:00 | Leather Pack ($500) |
| 16:00 | Conveyor level 2 ($300), line at 0.75 bars/s |
| 20:00 | Steel Pickaxe ($750) |
| 28:00 | Drill Pick ($1,500) |
| 1:57 | Refinery level 3 ($20K) |
| 2:47 | Conveyor level 3 ($15K) |
| 2:55 | Miner's Pack ($6K) |
| 4:39 | Reinforced Pack ($70K) |
| 10:13 | Refinery level 4 ($250K) |

The greedy order buys the line before Steel because a refinery upgrade pays back faster than a pickaxe while the line is the bottleneck. A player who buys Steel first is only slightly behind.
