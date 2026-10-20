# 03 — Economy, pacing, progression, monetization design, payer experience

Auditor: economy subagent (read-only; ran `Shared.Pacing.simulate` in Studio against a clone of Shared). Spot-checked by the lead:
- **C1 confirmed:** `CanUsePaidRandomItems` is defined but never called, and `PetService:Hatch` (`PetService.luau:103-121`) charges shards, then rolls.
- **C17 confirmed:** all 11 ids in `Config/Badges.luau` are 0.

"Sim" numbers model a free player (no pets or passes) who sells every 60 s, on a 283 s meteor cycle.

## Pacing table

| Milestone | Minutes (sim) | Source |
|---|---|---|
| First meteor lands | 1.55 | `Config/Meteor.luau:8,10` |
| First purchase (Line lv2, $2,800) | 4.0 | `Config/Home.luau:42` |
| Steel Pickaxe + Leather Pack | 5.0 | sim |
| **Drill Pick** | **8.0**, the bottom edge of the 8–10 window | `tests/Pacing.spec.luau:76-87` |
| Plasma Pick | 13.0 | sim |
| **First rebirth ($30K)** | **15.0** | `Config/Rebirth.luau:17` |
| Rebirths 2 / 3 / 4 / 5 | 31 / 51 / 75 / 97 | sim |
| Rebirths 6–10 | 120 → 201 (laps 18–23) | sim |
| Rebirth 16 (last listed rank) | 328 (5.5 h) | sim |
| Rebirth 17 (first Legacy rank) | 338; the lap **drops to 10 min** | `Config/Rebirth.luau:28` |
| Rebirths 20 / 25 / 30 | 377 / 478 / 630 (laps 15 / 20 / 40) | sim |
| Rebirths 35 / 40 / 41 | 15.4 h / 25.4 h / 28.3 h (laps 78 / 155 / 177 min) | sim |
| Gear tier 6 / 7 / 8 | ~R4 (75 min) / R9 (3 h) / R25 (8 h) | `Config/Levels.luau:37` |
| Player level 50 | ~24 h | `Config/Levels.luau:14` |
| No-rebirth player: nothing to buy | 19 → 61 min, then 61 → 170 min | sim (level gates) |
| 30-day player (2 h/day) | ~R46–48, 6–8 h laps, nothing new to unlock | extrapolated (C9) |

## Monetization catalogue

The "income ×" figures are the modelled long-run gain from `Pacing.expectedIncome`.

| Key | Kind | R$ | Id | Gives | Verdict |
|---|---|---|---|---|---|
| TwoXOre | pass | 149 | set | ore ×2 | **Weak**: ×1.05–1.2 typical, because the line caps it (C4) |
| TwoXCash | pass | 129 | set | sales ×2 | **Excellent**: a true ×2, and cheaper than 2x Ore |
| BiggerBackpack | pass | 99 | set | capacity ×2 | Weak: ×1.01–1.25 |
| OfflineHours | pass | – | **0** | offline cap 8 h | Near worthless as designed (C8) |
| AutoDeposit | pass | 129 | set | ore straight to the hopper | Good QoL |
| VIP | pass | 199 | set | +10 % sales + tag | **Poor**: 1/10 of 2x Cash at 1.5× the price (C5) |
| Drillbot | pass | 129 | set | miner, swift, yield pet | OK alone; wasted next to Phoenix (C14) |
| SolarPhoenix | pass | 249 | set | miner, merchant, scholar pet | Strong |
| StarterPack | product | 49 | set | 10 min income (cap 30 % of rebirth cost) + 20 min Overclock + pet XP | Weak at R0; the pet XP is usually lost (C12) |
| TipJar | product | 5 | **0** | session cosmetics | fine |
| PocketChange | product | 19 | set | 10 min income, cap 30 % | good, timing-sensitive (C11) |
| MiniOverclock | product | 19 | set | 10 min ×2 refinery | **Near worthless** once mining-limited (C4) |
| OreRush | product | 29 | set | 30 min ×2 ore | Weak (C4) |
| CashBundle | product | 59 | set | 60 min income, cap 80 % | Worse per R$ than Pocket mid-lap (C11) |
| CallMeteor | product | 19 | set | meteor in 30 s | Saves 30–90 s (C19) |
| Overclock | product | 39 | set | 30 min ×2 refinery | **Near worthless** once mining-limited (C4) |
| PetMax | product | 49 | set | equipped pets to level 10 | Great with 3 pets; **nothing** with 0 (C3 / D1) |
| PetSlot | product | 49 | set | +1 slot | Good; a 2nd buy gives nothing (C2 / D3) |
| BossMeteor | product | 99 | set | Alien boss call (R3+) | OK |
| Shards50 / 250 / 1000 | product | 19 / 69 / 199 | set | 2.6 / 3.6 / 5.0 shards per R$ | Clean ladder; dies late game (C13) |
| RebirthKeep | product | 99 | set | free rebirth, keep everything | The real whale sink |
| StreakShield | product | 9 | **0** | +1 shield | fine |
| Pickaxe / Backpack tier-ups ×14 | product | 5 → 259 | all set | one tier, no gate | Early tiers worth 1–3 min; T4+ is a level-gate skip |

## Findings

| ID | Sev | Area | Where | Finding | Fix | Conf. |
|---|---|---|---|---|---|---|
| C1 | **P0** | Roblox policy | `PetService.luau:103-121`, `PlayerPolicyService.luau:40`, `docs/guide/monetization.md:105` | Core Shards are sold for Robux (`Shards50/250/1000`, Starter Pack refunds) and eggs are **random** rolls paid in that same shard balance. Roblox's Paid Random Items policy covers random items bought with in-experience currency that can be bought with Robux. `Hatch` never calls the existing `CanUsePaidRandomItems` gate (it has zero callers), and the docs and CLAUDE.md say eggs use "earned" shards, but the code doesn't separate earned from bought. | Gate `Hatch` on `CanUsePaidRandomItems` (restricted regions: hatch disabled, or earned-shards-only via a split `shardsEarned` balance), keep odds displayed, fix the docs. Re-read the current policy text before launch. | high on code, medium-high on policy reading |
| C2 | P1 | Grants | `Purchases.luau:93-105` | `PetSlot` (a 2nd receipt grants nothing) and `StarterPack` ("one per player", but a 2nd receipt grants it all again) are enforced only by client card state. Same as D3. | Server fallback when the flag is already set. | high |
| C3 | P1 | Grants | `Purchases.luau:81-92` | PetMax sells for nothing with 0 equipped or all max. Same as D1. | Disable the card; bank the levels. | high |
| C4 | **P1** | Economy / payer value | `Config/Home.luau:55,60`, `Pacing.luau:225-243` | Income = min(mining, line). The line is tuned just above mining, so **2x Ore (×1.05–1.58), Bigger Backpack (×1.01–1.25), Overclock / Mini Overclock (×1.00 once mining-limited, from ~minute 8)** and the Efficient Line perk barely change income. Only the 2x Ore + Overclock combo hits ×2. | Make capped boosts also lift the other side (e.g. Overclock adds bar value), sell combos, and show a "line-limited" hint. | medium-high (model averages bursts) |
| C5 | P1 | Price ladder | `Config/Monetization.luau:59-115` | VIP 199 R$ for +10 % vs 2x Cash 129 R$ for +100 %; 2x Ore 149 R$ is priced above 2x Cash with a fraction of its effect. | Reprice (VIP ~99 or more perks); make 2x Cash the anchor. | high |
| C6 | P1 | Retention | `Config/Daily.luau:15,23-31` | The daily cash ceiling (2 % of the next rebirth cost) binds from day 1, so day 1 and day 7 pay the same ($600 at R0; $58M flat at R5 against $130M/min of income). The streak ramp is invisible. | Let the ceiling grow with the streak day (2 % → 15 %). | high |
| C7 | P1 | Shard sink | `Config/Perks.luau:21-27`, `RebirthReset.luau:26-27` | **Head Start** (600 shards total) only raises a gear-tier floor, but tiers already survive rebirth and players are at tier 4 by R1. Levels 1–3 can never apply. The largest shard sink is a dud. | Repurpose (keep gear levels, or a starting cash share). | high |
| C8 | P1 | Retention | `Lib/Refining.luau:86-106`, `RefineryService.luau:161-168` | Offline income refines **only the hopper stock left at logout**, which is near zero because line ≥ mining. Offline cash, the Welcome Back roll, Offline Training (350 shards) and the planned Offline Hours+ pass are near worthless; the spec assumes a full hopper. | Offline output = X % of ExpectedIncome up to the cap. | medium-high |
| C9 | P2 | Late game | `Config/Rebirth.luau:17-28` | Prices ×3 vs income ×5 per rank, so the shop is effectively free from ~R8. Legacy cost ×2.3 vs multiplier ×2 compounds laps ×1.15 per rank (10 → 177 min). The last unlock is at R4, the last gear tier ~R25. A 30-day player has 5–8 h laps and nothing to buy. | Legacy `CostGrowth` ~2.05; late unlocks every N ranks; a prestige layer. | high (30-day is extrapolated) |
| C10 | P2 | Pacing | `Config/Rebirth.luau:24-28` | The Legacy switch makes lap 17 (10 min) half of lap 16 (21 min); the comment's "same 5/3 ratio … gently" is wrong. | Smooth ranks 17–20; fix the comment. | high |
| C11 | P2 | Payer value | `Monetization.luau:402-406`, `MonetizationService.luau:217-224` | Mid-lap both cash packs hit their ceilings: 3 Pockets (57 R$) = 90 % of rebirth cost > 1 Bundle (59 R$) = 80 %. Right after a rebirth a pack is ~15× worse than later in the lap. | Size by rebirth-cost share; show a live quote on the card. | high |
| C12 | P2 | Payer value | `Purchases.luau:97-105` | Starter Pack at R0: $9K (1–7 min), Overclock ×1.0–1.32, pet XP lost because new players have no pets. | Bank the pet XP or swap it for ~30 fixed shards. | high |
| C13 | P2 | Shard economy | `Config/Perks.luau`, `Config/Pets.luau:86-97` | Perks total 2,024 shards; there are 12 egg pets. After that, shards only buy duplicate XP. Shards1000 (199 R$) becomes worthless for veterans (~20 h). | A repeatable shard sink. | med-high |
| C14 | P2 | Pass value | `Config/Pets.luau:59, 133-135` | Miner cap 1.0: Solar Phoenix maxes it alone, so Drillbot's (and Meteor Drake's) miner role adds nothing beside it. | Raise the cap or change Drillbot's role. | high |
| C15 | P3 | Exploit (small) | `RefineryService.luau:171` | Each rejoin rerolls the Welcome Back multiplier (EV +14.5 %), with no minimum time away. | Roll only after ≥ 15 min away. | high |
| C16 | P3 | Exploit (small) | `EconomyService.luau:54-66` | ExpectedIncome includes timed boosts, so buying Overclock or Ore Rush first inflates cash-pack, daily and code quotes (mostly clipped by ceilings). | Quote from passes only. | high |
| C17 | P2 | Launch | `Config/Badges.luau:4-16` | **All 11 badge ids are 0**, so no badge is awarded at launch. *(Confirmed.)* | Create them in Creator Hub. | high |
| C18 | P2 | Catalogue | `Config/Store.luau:32,40,43` | No auto-collect/auto-sell pass; nothing above 259 R$ except repeatables; dead Id-0 cards (see B8). | Hide Id-0; consider an auto-collect pass. | high (facts) |
| C19 | P2 | Product value | `Config/Meteor.luau:9`, `Monetization.luau:383-389` | Call a Meteor can only be bought with 60–120 s left and saves just 30–90 s. | A caller perk, or lower `SetCountdownTo`. | high |
| C20 | P3 | Copy | `Purchases.luau:130-154`, `Monetization.luau:248` | Tier-up description demands "level at its cap"; the code doesn't check (harmless). | Fix the copy. | high |
| C21 | P3 | Docs drift | various | `Rebirth.luau:4-5` says "ranks 1 to 8" (16 exist); rank 2's unlock text is missing (+1 pet slot); PetSlot copy says "up to four pets"; `monetization.md:115`, `economy.md:175, 183`, `Pacing.spec.luau:3` ("45 minutes"), `Config/Pets.luau:5` ("pass"), `Meteor.luau:78` ("hourly" vs 47 min), `Home.luau:10` points at an archived doc. | Sweep the docs. | high |
| C22 | P3 | Test fragility | `tests/Pacing.spec.luau:86` | The sim buys the Drill Pick at exactly 480 s, the spec's minimum. Any small price change fails it. | Re-fit to ~9 min. | high |
| C23 | P3 | Catalogue | `Monetization.luau:274, 337` | T4→T5 tier-up: pickaxe 49 vs backpack 39; every other tier is equal. | Align. | high |
| C24 | P3 | Payer UX | `RebirthService.luau:240` | A held Keep credit is always spent, even on a cheap rebirth (see B7). | Explicit toggle. | high |
| C25 | P3 | Content | `Config/Index.luau:35` | Alien (boss) ore has no Index page. | Add a page. | high |

## Checked and found solid
- **Number range:**
  - `Format` has 22 suffixes, up to about 1e65; that limit is reached only around R150.
  - Cash passes 2^53 around R15, which is harmless because rewards scale with income.
  - The Cash leaderstat is a StringValue, and no `%d` is used on cash.
- **Multipliers:**
  - The non-rebirth sale stack is capped near ×3.38.
  - Whale vs free is about ×9 with Overclock, ×4.5 without.
  - Ore boosts take the max of the two, never stacking to ×4.
- **No exploits found:**
  - No arbitrage.
  - Codes and daily claims are idempotent, and daily uses server time.
  - Tier-up refunds pay at the buyer's price.
  - Overstay shards are capped.
  - Receipts dedupe.
- **Config tables:**
  - They line up: 8 tiers everywhere, 7 days, 7 tier-ups per kind.
  - Prices and the 16 rebirth costs are monotonic.
  - There are no duplicate ids.
- **Catalogue coverage:** every pass and product sits in exactly one Store section or in `Elsewhere`.
- **Eggs:** odds sum to 100, pity works, and pass pets never come out of eggs.
