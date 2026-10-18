# MeteorShift overnight report

**Draft, 5 October 2026.** Work is on `job-for-tomorrow`. A fresh full Studio run passed **349/0 after the new landscape HUD layout**, including **30/0 HudLayout checks**. The native 844 × 390 HUD preview matches that layout. The user's subsequent simulator-style GUI reference is now being adapted to MeteorShift, so post-style tests, remaining menu/runtime acceptance, clearing the saved test flag, final Save UI evidence and the final push are **pending root verification**. This draft distinguishes observed evidence from checks still in progress.

## Changes

- **Pet rules:** all fourteen original pets retain their IDs, names, rarities, colours, blurbs and acquisition methods. Explicit level 1 and level 10 perks interpolate linearly across eleven capped roles. Yield, Sprint, Vault, Crit, Scholar and Shards join Miner, Hauler, Pack, Swift and Merchant. The server applies the arithmetic to validated hits, character speed, storage, player XP and complete cracked-core payouts. State publishes all bonuses; shop cards list every owned-level perk. Eggs keep their shard prices, visible odds, pity and duplicate XP. The complete roster and unchanged art brief are in [pets.md](pets.md).
- **Purchases:** seven fixed developer products and Extra Pet Slot were added; Drillbot and Solar Phoenix use the authorised 99/199 Robux prices. All monetization IDs remain zero. Products grant specific cash, XP, online boost time or session cosmetics. No Robux purchase grants shards, eggs, hatches, random pets or altered mineral odds. Existing Call a Meteor and Refinery Overclock behavior remains. [purchases.md](purchases.md) records the grant and receipt rules.
- **Ownership and persistence:** a saved possible fourth pet survives profile reconciliation until pass ownership resolves, then the server validates the loadout. Ownership-dependent consumers wait for resolution rather than an arbitrary default timeout. Product transactions grant once, retain the receipt ID permanently and save before acknowledging; retries after failed saves do not grant again. `oreBoostLeft` defaults safely on older profiles, persists with remaining boost time, and counts down online. A Studio-only `DevProduct` hook exercises the fixed grant/save path without Marketplace receipts.
- **Visuals:** local followers use replicated equipped IDs and matching levels, ground/flying motion, working cues, a complete level-10 replacement look and owner cleanup. Selection culls beyond 150 studs and limits followers plus hatch previews to forty models, including during replacement. Missing assets render nothing. Queued hatches reveal name, perks, rarity and duplicate XP; Escape/tap closes them, and the full-screen input blocker ends within two seconds. All fourteen authored models and their upgraded looks were exported to [PetModels.rbxm](../assets/PetModels.rbxm); conventions are in [pet-models.md](pet-models.md).
- **Cleanup and validation:** the saved `ServerScriptService.Script` / `HUD_QA` join fixture that granted progression was removed. Runtime acceptance uses the Studio-only opt-in memory store rather than live profile stores. Server changes include ownership-ready synchronization, a miner requiring a real recent validated swing, and validation/throttling for menu mutations.
- **Leftovers:** the 320 × 568 HUD layout, readable pixel/scroll Index, meteor outcome wording, reduced shake/effects settings, clearer profile-load errors and optional Drillbot pacing treatment are implemented and undergoing final acceptance. Index controls are at least 44 px; its layout specs passed independently. Profile-load copy distinguishes an unavailable store, an exact active session lock, and a transient read failure without weakening locking. Final integrated UI/runtime verdicts remain below.
- **Landscape user steering:** the supplied mobile reference is implemented with Gear/Index/Rebirth stacked left, Settings/Store at upper right, and a wallet/production/bars/backpack bottom strip between movement controls. Two regression specs were added; the full runner passed 349/0 and the native 844 × 390 HUD preview matched the arrangement with joystick clearance. Full menu acceptance remains pending.
- **Latest visual steering:** the user then requested a simulator-style GUI adapted to MeteorShift: colourful outlined tiles, deep navy surfaces, cyan/amber/lime accents, and white Fredoka headings with strokes. Shared UI styles, HudView, Shop, Refinery and Tutorial work are in progress. This changes presentation without adding game features or changing the pet, purchase or economy rules; post-style inspection and verification remain pending.
- **Documentation:** README now describes the multi-perk pets, three-tab Gear Shop, explicit shared-refinery Deposit/Claim actions, level-based clearance, current prices, permanent receipts and the measured pacing comparison. Existing art prose is retained in the pet brief.

Parts A–C have been pushed in `d1ac453`, `6fd5faf` and `0c6bae2`. The final leftovers/documentation commit and push are **pending root completion**.

## Observed verification

| Check | Observed evidence |
|---|---|
| Initial synchronized Studio runner | **267 passed, 0 failed**. Earlier stale-session failures were resolved by refreshing code before the baseline. |
| Full runner before three layering fixes | **347 passed, 0 failed**. This earlier run preceded those fixes. |
| Full runner after three layering fixes | Fresh full Studio runner: **347 passed, 0 failed** after all three fixes were synchronized. |
| Full runner after landscape layout | Fresh full Studio runner: **349 passed, 0 failed**, with two additional regressions and **30 passed, 0 failed** in HudLayout. This predates the new simulator-style GUI work. |
| Studio source audit | **137 Studio source hashes matched the captured disk manifest**, including after reopening the same place. The three UI fixes and subsequent landscape layout were synchronized for their passing fresh runs. The final source audit after the simulator-style GUI changes is pending. |
| Strict declarations and review | Root confirmed all **21 then-current changed Luau files** were strict; the final source review by the pet-visuals worker found no actionable issue. Later GUI changes still need their own final check. |
| Index layout | Fresh Edit-mode runner: **6 passed, 0 failed**, including the requested phone sizes, scrolling and 44 px controls. Phone menu inspections at 320 × 568 and 390 × 844 are recorded separately below. |
| Model export | `assets/PetModels.rbxm` exists at **52,373 bytes**. Root reported all **14 × 2** base/upgraded clone checks passing. |
| Pacing tests-first | New treatment initially produced **14 passed, 3 failed**; implementation reached **16 passed, 1 failed**. The remaining test had invented a requirement that the pet must rebirth earlier. It was rewritten to check a deterministic changed time, matching the actual task, and the corrected suite passed in the **347/0** full runs, including after the three layering fixes. |
| First-rebirth comparison | Fresh cloned Studio model: pet-free **2,700 s / 45:00**; fixed equipped Drillbot level 5 **3,480 s / 58:00**. Difference: **+780 s / 13:00 / 28.9% longer**, without a balance retune. |
| Five pet-free rebirths | Fresh cloned Studio model: **2,700, 4,320, 5,880, 7,440 and 9,000 s**, or **45, 72, 98, 124 and 150 minutes**. |
| Isolated Iron-core Play check | With high-tier gear and active Solar Phoenix + Jet Wisp, Iron cracked **83 seconds after impact** after **49 manual core hits**. The player received **23 shards** and ended at **level 4 with 27.7625 current-level XP**. Miner ore accumulated in the hopper to **1,999 ore** during manual mining. This check preceded the latest notification changes and does not verify their final displayed XP text. |
| Studio fixed-product check | The existing `DevProduct` hook applied Pet Treat's **1,500 pet-XP grant**. This exercises the fixed grant path, not a live Marketplace receipt. |
| Duplicate hatch overlay | A duplicate **Scrap Sparrow granted +400 XP**; its overlay name and perks were visible after the `Sibling` UI layering fix. Final hatch dismissal/input acceptance remains part of the root runtime verdict. |
| Runtime Output in that Iron check | Root reported **no GameOutput warnings**. A tooling `Knit.GetService` context error was resolved by evaluating after Knit startup. |
| Earlier save/reopen check | Save Output recorded **07:26:49**; reopening confirmed **14 pet models and the shared refinery**, with no saved `HUD_QA` or receipt-test scripts. The final save after leftovers remains pending. |
| Final Edit refinery structure | **94 parts**, PrimaryPart **Foundation**, one **6 × 1 × 6 UsePoint**, anchored/transparent/noncolliding/nontouching; shared mode, humanoid prompt requirements and all anchored building parts were confirmed. No forbidden content or scripts were found in the refinery. |
| Refinery placement and ground | Pivot **(-22, 0.6, -110)**; meteor **(0, -1.25, 0)**; center distance **112.1784 studs** and closest building surface **99.1784 studs**, exceeding the checked 90/80 thresholds. Foundation bottom **Y = 0.6000000387** aligns with the downward ray hit at **Y = 0.599999249** on `Workspace.Map.TownSquare.Plaza`. UsePoint **(-22.9805813, 3.5999999, -99.6058426)** is three studs above the pavement. |
| Final Edit pet-model structure | All **14 models** retained the previously checked counts, with Body, Level10 and PrimaryPart present; no scripts, collisions or touch; saved parts unanchored. |
| Final Edit QA scan | Root scanned **one Script** and found **no profile-mutating fixtures**. The saved `DevMemoryStore` attribute was still **true** at this inspection and must be cleared before the final save. |
| Final runner/source checks after simulator-style GUI | **PENDING — root will insert results for the latest visual work.** The latest completed full run was 349/0 after the landscape layout. |
| Full runtime acceptance and Output review | **PENDING — root will record covered actions and any remaining issues.** The isolated Iron check above does not establish all meteor types, every perk or every menu path. |
| Phone emulator: 320 × 568 | **All menus inspected before the new landscape HUD change.** Root's final interaction/acceptance verdict is pending. |
| Phone emulator: 390 × 844 | **All menus inspected before the new landscape HUD change.** Root's final interaction/acceptance verdict is pending. |
| Phone emulator: 844 × 390 | **Native HUD preview verified:** left nav stack, Settings/Store upper right, bottom strip and joystick clearance. **Final menu inspections and acceptance after the new GUI style remain pending.** |
| Final saved place and saved test flags | **PENDING — clear/remove `DevMemoryStore`, finish the new GUI style, save without publishing, and record Save UI evidence and place path.** The Edit fixture scan above is clean. |
| Final leftovers/docs commit and push | **PENDING — root will insert commit and push evidence.** |
| Existing A–C push | Root confirmed **`0c6bae2` pushed successfully to `origin/job-for-tomorrow`**, containing the earlier pet rules and purchase commits. |

## Assumptions and limits

1. **Cash packs estimate station income.** `Refining.lineRate` includes an active online Overclock. Cash value uses the normal sale multiplier, including rebirth, index, VIP and Merchant; it is independent of current hopper stock and collection-post room. Before Frost is fully cleared, average bar price is Iron. From level 4, meteor weights are multiplied by ore clearance before prices are averaged. This is the selected interpretation of the requested ore-weighted average, documented in [purchases.md](purchases.md).
2. **Cash ceilings take precedence.** Whole cash rounds down after clamping. Pocket Change has a $2,000 floor and 3% of next-rebirth cost ceiling; Cash Bundle has a $20,000 floor and 8% ceiling. If future tuning puts a ceiling below its floor, the ceiling wins. A single grant is less than the complete rebirth cost; cash already held can combine with it.
3. **Fixed grants use the current loadout.** Pet Treat/Feast grant once per unique equipped owned pet at grant time. Empty loadouts and level-10 pets receive no useful XP; no substitute egg, shards or random outcome is given. Tip Jar's Supporter tag is session-only and cosmetics fire after a successful save.
4. **Online timers add duration.** Mini Overclock adds 600 s to the existing timer; ordinary Overclock adds 1,800 s. Ore Rush adds 1,800 s to its own timer. Remaining durations survive saves/rebirth and pause offline; offline refinery catch-up ignores Overclock. Ore Rush and the 2x Ore pass use the larger multiplier, never ×4. A previously purchased receipt still grants its duration even if the store would now disable the button.
5. **Historical receipts have a limit.** New processed receipt IDs are never trimmed. IDs already discarded by the old fifty-entry history cannot be reconstructed. A failed save retains both grant and receipt ID together in current-server memory; a retry saves without applying a second grant.
6. **Supplied rarity endpoints remain exact.** Rarity comparisons apply where a role exists. Some paid and earned perks tie at level 1 in the supplied table; paid pets exceed earned pets at level 10 for their roles. Pet IDs, egg order, pity, duplicate XP and art prose stay unchanged.
7. **The pacing treatment is controlled.** Drillbot is already equipped at fixed level 5 from the start; acquiring it and pet XP growth are excluded. Its bonuses are Miner 31.6667%, Swift 13.3333% and Yield 14.4444%. A target stays in reach throughout backpack filling, repeated owner hits keep Miner active, and the forty-second trip is inactive. Miner grants no player XP, shards or mineral rolls. Live target interruptions and the 0.1-second miner scheduling tick can lower supply.
8. **The slower pacing result is reported, not tuned away.** Both treatments buy the same seventeen items for $1,284,912, but timing and ore blend differ. The inherited model stores queued ore's clearance cost at mining time and never reprices it when the player levels up; live refining uses current clearance each tick. Extra early ore can retain expensive clearance in the averaged backlog, while projected income ignores that retained cost. The greedy policy maximises income payback rather than minimising rebirth time. These preserved approximations limit live interpretation of the thirteen-minute delay; [balance.md](balance.md) contains the comparison. No economy constants, prices, rates or shopping rules were retuned.
9. **Optional art audio follows the sound configuration.** Quiet native/approved sounds are used where available; missing optional sound IDs do not invent assets. Destination cues use visible world targets or refinery intake positions and can fall back when that geometry is absent.

Live Marketplace receipts and real ownership lookups are **not verified**: all **17 monetization IDs** are zero and all items remain off sale. The Studio hook exercises the grant/save path but does not represent a purchase. A two-client local-server run is **not yet available/verified**; replication and cross-client visual behavior still need that coverage. All menus were inspected at 320 × 568 and 390 × 844 before the newest layout/style changes. The landscape layout then passed 349/0 and its native 844 × 390 HUD preview was checked. Simulator-style GUI completion, final phone/menu acceptance, complete Play acceptance, the next final test run and final Save UI evidence remain pending. Native QA focus was previously stopped by the user's Escape input; resumed checks must record actual evidence rather than infer completion. The saved `DevMemoryStore` opt-in still needs clearing before the final save.

Publishing, a pull request and live profile-store QA are excluded by the task. No alternative prices were invented for existing catalog items.

## Creator Dashboard catalog

Create or connect the following items, then set their IDs in `Config.Monetization`. **All current IDs are 0.** Numeric prices below are the intended catalogue prices; the live store reads Roblox's regional price once IDs are configured. **Owner decision** means this change supplied no intended price and the owner must choose one before enabling the item.

### Game passes

| Key | Exact name | Intended Robux | Effect |
|---|---|---:|---|
| `TwoXOre` | 2x Ore | Owner decision | ×2 ore quantity; mineral odds unchanged. |
| `BiggerBackpack` | Bigger Backpack | Owner decision | ×2 backpack capacity. |
| `OfflineHours` | Offline Hours+ | Owner decision | Offline production cap rises from two to eight hours. |
| `AutoDeposit` | Auto-Deposit | Owner decision | Mined ore enters the hopper, with backpack overflow. |
| `VIP` | VIP | Owner decision | +10% bar-sale value and VIP chat tag. |
| `Drillbot` | Drillbot Pet | **99** | Permanent fixed Drillbot with Miner, Swift and Yield perks. |
| `SolarPhoenix` | Solar Phoenix Pet | **199** | Permanent fixed Solar Phoenix with Miner, Merchant and Scholar perks. |
| `ExtraPetSlot` | Extra Pet Slot | **49** | One permanent additional equipped slot, up to four with rebirth slots. |

### Developer products

| Key | Exact name | Intended Robux | Effect |
|---|---|---:|---|
| `TipJar` | Tip Jar | **5** | Thank-you confetti/toast and session Supporter tag; no gameplay benefit. |
| `PocketChange` | Pocket Change | **10** | Ten minutes of estimated current line income, floor $2,000, ceiling 3% of next-rebirth cost. |
| `PetTreat` | Pet Treat | **15** | 1,500 XP to each currently equipped pet. |
| `MiniOverclock` | Mini Overclock | **19** | Adds ten online minutes of ×2 refinery speed. |
| `OreRush` | Ore Rush | **25** | Adds thirty online minutes of ×2 ore; does not stack with 2x Ore. |
| `PetFeast` | Pet Feast | **29** | 6,000 XP to each currently equipped pet. |
| `CashBundle` | Cash Bundle | **39** | Sixty minutes of estimated current line income, floor $20,000, ceiling 8% of next-rebirth cost. |
| `CallMeteor` | Call a Meteor | Owner decision | Brings the next meteor down in thirty seconds, subject to unchanged server rules; failed calls grant a reusable credit. |
| `Overclock` | Refinery Overclock | Owner decision | Adds thirty online minutes of ×2 refinery speed. |

There are **eight passes and nine developer products**. Extra Refinery remains excluded because each player has one production line. Eggs remain purchases with earned Core Shards, never Creator Dashboard Robux products.
