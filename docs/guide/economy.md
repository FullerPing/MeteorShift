# Economy guide

How MeteorShift's money works: what ore is worth, what upgrades cost, what a rebirth does, and the
pacing model that keeps the whole curve honest. Every number below cites a `file:line` opened when
this page was written (2026-10-18) or says "see <file>" — when a number here and its source ever
disagree, **the code wins**. Config is the only home for tuning values; rules that read Config
live in the `Shared.*` modules named alongside.

This page replaces [docs/archive/balance.md](../archive/balance.md) (the pacing notes) and
[docs/archive/economy-rework.md](../archive/economy-rework.md) (the rework design record). For the
shape of the saved profile itself, read `src/server/Lib/ProfileTemplate.luau`.

## The loop

| Stage | What runs | Numbers |
|---|---|---|
| Meteors land | one shared crater event; first 90 s after server start, then one per cycle | first 90 s, countdown 120 s, impact 3 s, end phases 5 s, cleanup 5 s (`src/shared/Config/Meteor.luau:8-14`), Iron cooling 150 s (`src/shared/Config/Meteor.luau:121`); cycle = their sum, 283 s (`src/shared/Pacing.luau:133-139`) |
| Mining | validated swings put ore in the backpack | ore per hit flat 1→20 and swing 0.6→0.35 s across the 8 pickaxe tiers (`src/shared/Config/Pickaxes.luau:22-29`); server hopper drop at `src/server/Services/NodeService.luau:246` |
| Clearance | a hit's ore scales by **player level**, never blocks | 40%→100% under an ore's clearance level (`src/shared/Config/Levels.luau:32-33`, formula `src/shared/Levels.luau:74-81`, applied at mine time `src/server/Services/MeteorService.luau:425-428`) |
| Hauling | walk home, dump the backpack into the hopper | backpacks 50→1,800 ore (`src/shared/Config/Backpacks.luau:16-23`) |
| The line | one upgrade level raises hopper → conveyor → refinery → collection post together (`src/shared/Config/Home.luau:2-4`) | bars/s = min(conveyor, refinery) (`src/server/Lib/Refining.luau:40-42`); station rates and capacities per level `src/shared/Config/Home.luau:46-67` |
| Selling | bars sell at the Trading Post; raw ore never sells (`src/server/Services/EconomyService.luau:2`) | value = bar stock × sale multiplier (`src/server/Services/EconomyService.luau:81`) |
| Spending | cash buys gear tiers/levels and line levels; Core Shards buy eggs and Colony Perks, not production (`src/shared/Config/Home.luau:39`) | gear bundle `src/shared/Gear.luau:143-157`, line `src/shared/Line.luau:40-46` |

## Bar economy

Every ore refines at full speed at the same bar price for everyone — the level gate scales the
*quantity* of ore at the moment it is mined, not the price (`src/server/Lib/Refining.luau:53-56`).

| Bar | $ per bar | Source |
|---|---|---|
| Iron | 50 | `src/shared/Config/Home.luau:84` |
| Frost | 150 | `src/shared/Config/Home.luau:85` |
| Crystal | 450 | `src/shared/Config/Home.luau:86` |
| Alien | 1800 | `src/shared/Config/Home.luau:87` |

Each type is worth about 3× the one below, the Alien boss 4× Crystal, so no meteor is filler for a
veteran (`src/shared/Config/Home.luau:81-82`). The multiplier on every sale is
`rebirth × mineral-index × VIP pass × Merchant pet × cash-pass`
(`src/server/Services/EconomyService.luau:40-50`).

## Player level, XP and clearance

- Cap 50 (`src/shared/Config/Levels.luau:11`). XP from level L to L+1 = `XpFlat + XpQuad × L²`
  with 15 / 0.5 (`src/shared/Config/Levels.luau:15-16`, applied `src/shared/Levels.luau:15-20`) —
  about 21K XP total to 50 (`src/shared/Config/Levels.luau:14` comment).
- XP comes from playing, never idling: 0.25 per crust hit, 0.5 per core hit, 25 crack bonus, all ×
  the ore's type multiplier (Frost 1.5, Crystal 2, Alien 3) — a full meteor of hitting ≈ 70 XP
  (`src/shared/Config/Levels.luau:22-25`, the same 70 feeds the model at `src/shared/Pacing.luau:109`).
- Clearance level per ore — Iron 1, Frost 12, Crystal 24, Alien 38 (`src/shared/Config/Levels.luau:32`).
  Under it a hit yields `0.4^((clear−level)/(clear−1))` of a hit — 40% at level 1, 100% at the
  clearance level (`src/shared/Config/Levels.luau:33`, `src/shared/Levels.luau:74-81`). Nobody is
  locked out; the fraction just keeps newcomers from outrunning the levels that earn the ore.
- Pickaxe/backpack tiers 5-8 and line levels 5-8 need player level 10, 16, 24, 34
  (`src/shared/Config/Levels.luau:37`; line gate via `src/shared/Line.luau:48-50`).
- Player level and XP survive rebirth — `RebirthReset.apply` never assigns them
  (`src/server/Lib/RebirthReset.luau:17-37`; `src/server/Lib/ProfileTemplate.luau:16`).
- Pickaxe *tier* requirements are separate from clearance: Ice needs tier 3, Crystal and Alien tier 5
  (`src/shared/Config/Meteor.luau:140,162,184`).

## Meteor cadence and Core Shards

Scheduled weights Iron 60 / Ice 25 / Crystal 15 (`src/shared/Config/Meteor.luau:123,145,167`);
the Alien boss is never weighted in — it replaces every 10th meteor once someone on the server has
3 rebirths (`src/shared/Config/Meteor.luau:80`). Shards come only from finished (or half-down,
cooled) cores: 5 floor per hitter, an 8-per-hitter bonus pool split by Mining Power share, 10/6/3
podium bonuses (`src/shared/Config/Meteor.luau:49-51`), a 6% crust-node crumb of 1-3
(`src/shared/Config/Hooks.luau:27`) and the consolation rule (`src/shared/Config/Hooks.luau:31`).
The pacing model averages that to 14 shards per meteor (`src/shared/Config/Balance.luau:13`).
Gear never asks for shards: every pickaxe and backpack row carries `Shards = 0`
(`src/shared/Config/Pickaxes.luau:22-29`, `src/shared/Config/Backpacks.luau:16-23`).

## Production line and gear costs

- One line upgrade, levels 1-8: `Costs[n]` buys level n (level 2 = $2,800) times the rebirth price
  inflation (`src/shared/Config/Home.luau:40-43`, `src/shared/Line.luau:40-46`). Each level sets
  hopper (2,000→1.9B ore), conveyor (0.3→260 ore/s), refinery (0.25→235 ore/s) and collection post
  (same table as the hopper) together, over 16 levels (`src/shared/Config/Home.luau`).
- One pickaxe, one backpack, 16 tiers each (tiers 9-16 added 2026-10-22, no models yet: they show tier 8's
  model in their own colour, `EquipmentModels`). A tier's levels together
  cost its row's `LevelCost`, each `LevelGrowth^(1/tier)` dearer than the last (`Shared.Gear.price`); evolving
  costs its row's `Cost`. Tier cap = 10 × tier levels. Reach stops growing at `ReachMax` (+12 studs).
- Gates (`Config.Levels`): tiers 5 and 6 need player level 10 and 14; tiers 7-16 (and the same-numbered
  line levels) need rebirths 4, 6, ... 22. Prices don't rise with rebirths, so each tier is priced for the
  income of the rank that opens it: its evolve about 2 minutes of that income, its levels 2-3 more, the line
  level 1.5 (fitted with `Shared.Pacing` together with the rebirth costs; `tests/Pacing.spec` checks every
  tier is bought within a lap of opening). The model then rebirths about every 14 minutes, a lap that buys a
  new tier running ~18 and the one after ~11. The R$ tier-up products stop at tier 8 (no ids for 8→9 and up).
- Every cash price goes through `src/shared/Price.luau:26-28`, which applies the rebirth
  multiplier below.

## Offline income

| Cap | Value | Source |
|---|---|---|
| Free | 2 h | `src/shared/Config/Home.luau:73` |
| Offline Training perk | +40/80/120 min | `src/shared/Config/Perks.luau:42-48` |
| Offline Hours+ pass | 8 h (takes the better of pass vs free+training) | `src/shared/Config/Home.luau:74`, combined `src/server/Services/MonetizationService.luau:151-154`, enforced `src/server/Services/RefineryService.luau:166` |

The catch-up then rolls a Welcome Back bonus on the bars it made: ×1 (80%), ×1.5 (17%), ×3 (3%)
(`src/shared/Config/Hooks.luau:48`). The model sizes the level-1 line's 2-hour cap at just under
$95K and the spec pins it there (`tests/Pacing.spec.luau:175-178`; `src/shared/Pacing.luau:456-463`).

## Rebirth

- Costs are an explicit 16-rank list fitted with the pacing model — first rebirth $34K
  (`src/shared/Config/Rebirth.luau:14`, read via `src/shared/Rebirth.luau:24-31`); beyond rank 16
  each cost ×2.05 ("Legacy", `src/shared/Config/Rebirth.luau:25`). Cash-only gate
  (`src/server/Services/RebirthService.luau:49-55`).
- Each rebirth pays **×2 on every bar sale** (`CashMult`, multiplicative via `Rebirth.multiplier`),
  and cash prices do **not** rise (`PriceGrowth = 1`, `Rebirth.priceMult`), so a rebirth is a plain ×2
  (owner, 2026-10-22; it used to be ×5 sales with ×3 prices). Legacy ranks keep ×2 with costs ×2.05.
- Unlocks per rank (Perks panel, Aurora Egg, Alien boss, extra pet slot) are listed in
  `src/shared/Config/Rebirth.luau:35-40`.
- Overstay shards reward cash you earned *after* the rebirth was affordable:
  `min(60, round(20 × log2(1 + overflow/cost)))` (`src/shared/Config/Rebirth.luau:27-31`,
  `src/shared/Rebirth.luau:53-59`; tracked on every sale `src/server/Services/EconomyService.luau:84-87`,
  paid at rebirth `src/server/Services/RebirthService.luau:58`).

### What survives a rebirth (`src/server/Lib/RebirthReset.luau:17-37`)

| Fate | What | Cite |
|---|---|---|
| Survives | pickaxe and backpack **tiers**; anything the function never assigns — shards, pets, Colony Perks, mineral index, player level/XP, credits | `src/server/Lib/RebirthReset.luau:26-27` (tiers), keys absent from `:17-37` |
| Partially survives | production line level — Station Memory keeps that share of it (`src/shared/Perks.luau:76-79`); Head Start adds starting cash, a share of the next rebirth's cost (`Perks.startCash`) | `src/server/Lib/RebirthReset.luau:33,26-27` |
| Resets | cash; gear stat levels back to 1 inside the kept tier (`src/shared/Gear.luau:36-38`); carried ore, hopper stock, bars, bins, decor; overflow | `src/server/Lib/RebirthReset.luau:23,28-32,34-36` |

**Rebirth and Keep Everything** is a paid option: a purchased credit rebirths without the cash and
skips the whole reset (`src/server/Lib/RebirthReset.luau:18-22`, spent in
`src/server/Services/RebirthService.luau:50-62`). The product definition is in
`src/shared/Config/Monetization.luau:231` — no ids or prices belong in this doc; see the
monetization guide and that Config file. The old "the refinery level stays" claim from the
pre-rework docs is long dead — the line resets except for Station Memory.

## Colony Perks (shards, permanent)

Bought with Core Shards, unlocked at rebirth 1, kept through every rebirth
(`src/shared/Config/Perks.luau:4-16`). Their economic roles: Head Start and Station Memory act at
rebirth (cited above); Efficient Line multiplies line rate (`src/shared/Perks.luau:61-63`,
applied `src/server/Lib/Refining.luau:40-42`); Offline Training extends the offline cap (cited
above); Pet Bond adds pet slots; Lucky Strike (+1-5% crit chance) and Heavy Hitter (+25-100% crit damage)
add to the pickaxe in `PlayerStateService:GetPickaxe`, so meteor sizing counts them; Field Expert (+10-40%)
multiplies ore-field cash and XP (`DebrisService`); Shard Sense (+5-20%) multiplies a player's core shards
(`RewardService:Finish`). Levels and shard costs: `src/shared/Config/Perks.luau`.

## Engagement hooks (income flavour)

All small, random, and floor-ed; none is sold for Robux and none touches mineral or egg odds
(`src/shared/Config/Hooks.luau:6-12`). Ore jackpots are EV-neutral — normal swings are scaled down
by exactly what they add (`src/shared/Config/Hooks.luau:8-10`, `src/shared/Hooks.luau:26-28`):

| Hook | Tuning | Extra? |
|---|---|---|
| Rich Vein 4% ×8 / Super Vein 0.2% ×40 | `src/shared/Config/Hooks.luau:16-17` | no (EV-neutral) |
| Golden Meteor 2% ×5 | `src/shared/Config/Hooks.luau:24` | no (EV-neutral) |
| Golden Node: breaker 20 hits, contributors 4 | `src/shared/Config/Hooks.luau:21` | yes, on top |
| Supply Crate per level: 80% cash of 15-50 line-seconds, up to a 30-shard band; floor $100, ceiling 5% of next rebirth cost | `src/shared/Config/Hooks.luau:37-45` | yes |
| Mineral soft pity after 400 dry hits, step 100, ×3 max | `src/shared/Config/Hooks.luau:52` | odds relief only |

## The Foreman's quest line (the long-term goal)

`Config.Quests.Line`: 22 steps, one at a time, never reset (not even by rebirth), from "Join 3 meteors" to
"Reach rebirth 10". Event steps count from the moment they start (meteorJoin, coreCrack, crustHit, barsSold,
oreDeposited, hatch, fieldRock with an optional Field); state steps (level, rebirths, pickaxeTier, backpackTier,
petsOwned, line) read the profile, so a step already passed is claimable at once. Each pays its Shards plus Minutes
of expected income (`Income.grant`, floor `CashFloor`, capped at `CashCeilingShare` of the next rebirth cost).
Rules: `src/shared/Quests.luau` (tests/Quests.spec); service: `QuestService` (profile `quest = { step, progress }`);
UI: the Quests menu (`NativeMenus/Quests`, opened by the Foreman's prompt beside the spawn or by the HUD tracker above
the backpack card, `QuestController`). Studio: `ServerStorage.DevQuest:Invoke(player, step, count?)`.

## Relics and Relic Fragments (permanent boosts)

`Config.Relics`: nine relics, each a small permanent boost to one pet role (crit, yield, merchant, sprint, scholar,
shards, pack, swift, vault), added on top of the pets' capped totals in `PlayerStateService:GetPetBonuses`, so
every system that reads pet bonuses sees them. `RelicService` rolls a find for each player who shares a cracked core
(`CoreChance` 3%; a boss core `BossChance` 25% plus `BossFragments` 3) and for each ore-field rock (`RockChance`
0.08%). A duplicate becomes `DuplicateFragments` Relic Fragments, the rare material pet fusing costs. Kept through
rebirth (profile `relics`). Shown in the Pets menu's BOOSTS tab. Studio: `ServerStorage.DevRelic`.

## Shared.Pacing — the model, and the spec that keeps it honest

`src/shared/Pacing.luau` simulates a fresh **free** player from Config alone (header `:1-49`): it
mines meteors and debris, walks home, refines at min(conveyor, refinery), sells on a timer and
greedily buys the income upgrade with the shortest payback (`:24-27`). Player level grows from
finished meteors at 70 XP each (`:109-114`); rebirth keeps gear tiers, resets the line
(`:433-436`). Behavioural assumptions (70% hit rate, 40 s trips, sell every 60 s…) are *not* game
rules — they live in `src/shared/Config/Balance.luau:10-17`. An optional fixed-level Drillbot
treatment exists for pet comparisons (`src/shared/Pacing.luau:141-148`, asserted in
`tests/Pacing.spec.luau:186-194`). `Pacing.expectedIncome` is not just a model: the live server
uses it to size cash packs and field-rocks (`src/shared/Pacing.luau:225-243`,
`src/server/Services/EconomyService.luau:52-66`, `src/shared/Config/Debris.luau:33-34`).

`tests/Pacing.spec.luau` asserts windows, not point numbers — a fitted curve drifts inside them:

| Assertion | Window / rule | Cite |
|---|---|---|
| Cycle length | 5-7 minutes | `tests/Pacing.spec.luau:15-20` |
| Steel Pickaxe in reach | within a cycle of the first meteor | `tests/Pacing.spec.luau:68-73` |
| Drill Pick / Meteorite Pick | by 15 min / by 30 min | `tests/Pacing.spec.luau:75-82` |
| **First rebirth** | **10-20 minutes in** — CLAUDE.md's "~15 min" is the middle of this window, not a number the spec computes | `tests/Pacing.spec.luau:84-89` |
| Laps | grow through lap 4; laps 5-8 hold 18-32 min | `tests/Pacing.spec.luau:91-103` |
| Rebirth pace | every rebirth ≤ 30 min after the last | `tests/Pacing.spec.luau:105-112` |
| Price inflation | post-rebirth purchases cost `Price.scaled(base, priceMult(n))` | `tests/Pacing.spec.luau:114-132` |
| Gear tiers survive rebirth | never fall | `tests/Pacing.spec.luau:134-141` |
| Offline cap | level-1 line, 2 h ⇒ >$80K and ≤$95K | `tests/Pacing.spec.luau:175-178` |

The fitted lap targets (first ~13 min, then ~18/23/24 and about 25) are recorded in
`src/shared/Config/Rebirth.luau:7-10` — treat them as the last fit's output, not promises.
**Project rule (CLAUDE.md):** any change to prices, income or rebirth costs must be re-fitted until
`tests/Pacing.spec.luau` passes again. Big numbers are intentional; `Format` names suffixes out to
1e63 so they always render (`src/shared/Format.luau:9-14`).

## Design rationale (kept from the rework record)

- **Underleveled is a fraction, not a wall.** Clearance scales yield 40%→100% and every hit counts;
  the refinery and prices never change by level (cited above).
- **A rebirth is a plain ×2.** Sales double and cash prices stay put (`CashMult = 2`, `PriceGrowth = 1`
  in `src/shared/Config/Rebirth.luau`), so the rebirth costs alone set the pace: laps of about 15, 11,
  13, 15 and then 14-15 minutes (`tests/Pacing.spec`).
- **Variable-ratio rewards sit on a fixed baseline** with floors, pity and no paid randomness —
  the hooks house rules are law in this economy (`src/shared/Config/Hooks.luau:6-12`).
- **A field pays about 1.5x the meteors, never many times more.** The line refines every ore into a
  bar at the same speed, so a field is worth its ore's *bar price* per second (or its cash, which skips
  the line). Mined nonstop, every field pays about 1.2-1.7x the player's expected income (Rust Works'
  quick rocks about 0.9-1.2x); `tests/DebrisField.spec` measures each field against
  `Pacing.expectedIncome` along the road and keeps it between 0.9x and 2x (owner, 2026-10-22: Halo
  Ledge had been paying ~13x). `Shared.Pacing` models meteors only, so a field farmer rebirths
  somewhat faster than its laps.

## History

- The full pre-rework tree is still one command away behind the git tag `pre-economy-rework`
  (present in the repo; verified 2026-10-18). Its revert recipe and the old ×5-per-rank rule are
  preserved in [docs/archive/economy-rework.md](../archive/economy-rework.md); the retired pacing
  notes and the 2026-10-10 merge/inflation design specs sit in `docs/archive/` (specs under
  `docs/archive/superpowers/specs/`).
- Debris dropped Frost in the pre-rework build; it now always drops Iron
  (`src/shared/Config/Debris.luau:24`), with ore-field rocks as the only off-meteor Frost/Crystal/Alien
  (`Config.Debris.Fields`; their multipliers were cut 2026-10-22, see the field rule above).
- Pets interact with this economy (Yield, Swift, Miner, Merchant, Scholar, Vault) — see the pet
  guide at [pets.md](pets.md); eggs cost earned shards only.
