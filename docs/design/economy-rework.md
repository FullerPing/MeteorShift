# Economy rework

Design record for the economy rework, with the numbers in Config and how to undo it.

## Revert

The state before the rework is the git tag `pre-economy-rework`, a snapshot of the whole working tree.

- Compare: `git diff pre-economy-rework -- src tests`
- Restore a file or folder: `git checkout pre-economy-rework -- src/shared/Config/Rebirth.luau`
- Restore everything: `git checkout pre-economy-rework -- src tests docs README.md`

Profiles are now version 6 (new `perks` and `overflow` fields); reverting the code does not rewrite saved data.

## Goals

- The first rebirth within 20 minutes (about 14); laps lengthen to the fourth rebirth and then stay near 25 minutes.
- Player level 50 is the cap and everything is paced around it.
- Underleveled means player level, not pickaxe tier; a low level still collects a share of the ore.
- Variable-ratio rewards on top of a fixed baseline, with floors, pity and no pay-to-win.

## The numbers

| Area | Rule | Config |
|---|---|---|
| Levels | XP to next = 15 + 0.5 x L^2, cap 50 | `Config.Levels` |
| Ore clearance | Iron 1, Frost 12, Crystal 24, Alien 38; underleveled yield 0.4 to 1 | `Config.Levels.OreLevel`, `Levels.oreYield` |
| Gates | gear and conveyor/refinery tiers 5 to 8 need level 10, 16, 24, 34 | `Config.Levels.EvolveLevel` |
| Bar prices | Iron 50, Frost 150, Crystal 450, Alien 1,800 | `Config.Home.BarPrices` |
| Rebirth | cash only; 16 listed costs, then x2.3 and x2 multiplier per Legacy rank | `Config.Rebirth` |
| Overstay shards | min(60, round(20 x log2(1 + overflow / cost))) | `Config.Rebirth.Overstay` |
| Meteors | countdown 180 s (cycle 343 s), first at 90 s; Alien boss every 10th from rebirth 3 | `Config.Meteor` |
| Offline | 2 h free, 8 h pass, Offline Training +40/80/120 min | `Config.Home`, `Config.Perks` |

## Hooks (`Config.Hooks`, `Shared.Hooks`)

- **Rich Vein** (4%, x8) and **Super Vein** (0.2%, x40) on a swing. Normal swings are scaled by `Hooks.oreBase()` so the average ore is unchanged; pets pay the plain average.
- **Golden Node**: one node a meteor; the breaker gets 20 hits of ore, contributors 4. It is extra on top of the average (not EV-neutral).
- **Golden Meteor** (2%): x5 ore, neutralised in `oreBase`.
- **Shard crumb**: 6% per broken crust node, 1 to 3 shards (extra).
- **Consolation**: a core at least half down when the meteor cools still pays the shard floor.
- **Supply Crate** on every level: cash worth about 15 to 50 seconds of line income, sometimes shards (up to 30), capped at 5% of the next rebirth cost.
- **Welcome back**: the offline catch-up pays x1 (80%), x1.5 (17%) or x3 (3%).
- **Mineral soft pity**: after 400 dry hits the odds of minerals you have not found rise by 1 each 100 hits, up to x3.

Nothing here is sold for Robux and none of it changes egg odds.

## Colony Perks (`Config.Perks`, `Shared.Perks`)

Bought with shards, permanent, panel open from rebirth 1 (PERKS button on the Rebirth panel).

| Perk | Levels | Shard costs |
|---|---|---|
| Head Start (gear starts 1 to 4 tiers up, within the level gate) | 4 | 40, 80, 160, 320 |
| Station Memory (keep 25/50/75/100% of hopper, conveyor, collector) | 4 | 30, 60, 120, 240 |
| Efficient Line (+4% line rate per level) | 5 | 25, 35, 49, 69, 96 |
| Offline Training (+40 min per level) | 3 | 50, 100, 200 |
| Pet Bond (+1 pet slot per level) | 2 | 100, 250 |

Pet slots are 1 plus 1 per rebirth to 3, one more at rebirth 4, plus the pass and Pet Bond. The Aurora Egg (250 shards, from rebirth 2) rolls Epic 88% / Legendary 12% with a pity of 10.

## Merged gear level and price inflation (2026-10-10)

Specs: `docs/archive/superpowers/specs/2026-10-10-merged-gear-level-design.md` and `2026-10-10-rebirth-price-inflation-design.md`.

- **One gear level.** The pickaxe's Power, Swing, Reach and Crit and the backpack's Capacity are read from a single level per item (`pickaxeLevel`, `backpackLevel`, profile v7). A level costs `Base x 1.12^(level-1)` (pickaxe base 45, backpack 37.5; was 30 / 25 at 1.115 on the gate stat alone). The bundle cost to reach a pickaxe tier rose +33% at tier 2 up to +64% at tier 8.
- **Rebirth keeps gear tiers**, and resets only the level. The model (`Shared.Pacing`) keeps the pickaxe and backpack tiers through a rebirth.
- **Price inflation.** Every cash price for gear and production upgrades is `Rebirth.priceMult(rebirths)` times dearer: x3 per rebirth to rank 16, then x1.2 per Legacy rank (cash sales stay x5 and x2). Shard prices and Robux cash packs do not inflate; the packs already pay minutes of income.
- **Refit costs.** `Config.Rebirth.Costs` was fitted again with the model so the laps run 13, 18, 23, 24 and then about 25 minutes (the aimed 16 and 20 for laps 2 and 3 settle a little higher).
- **Numbers.** `Format.number` now names suffixes up to the vigintillion (1e63) and clamps anything larger.

## Progression products (2026-10-10)

Owner decision: these are sold on purpose, so the old "never sells shards" rule is gone (`Config.Monetization`, `Shared.Purchases`, `MonetizationService`). Nothing here rolls randomness and eggs still show their odds.

| Product | Where it is sold | Effect |
|---|---|---|
| Shards 50 / 250 / 1,000 | Store | Adds that many Core Shards (`ShardPacks`). |
| Rebirth and Keep Everything | Rebirth menu ("Rebirth, keep everything" button, buys and rebirths in one tap) | Adds a credit (`credits.rebirthKeep`). The next rebirth skips the whole reset: cash, gear levels, production, ore and bars stay, the rebirth count and multipliers still go up (`RebirthReset.apply(data, now, true)`). The Rebirth panel says when a credit is ready, and the keep-everything button works even before the rebirth is affordable (a credit rebirths without the cash). |
| Call a Boss Meteor | Store | Call a Meteor that forces the Alien boss type (`MeteorService:CallMeteor(player, true)`). Same limits as Call a Meteor, and the buyer needs the boss rebirths (`Shared.CallMeteor.bossUnlocked`). If it can't run, the buyer gets a boss credit (`credits.bossMeteor`) to use from the Store. |
| Tier-ups (`PickaxeT1`-`T4`, `BackpackT1`-`T4`) | Gear shop only: **EVOLVE NOW R$ price** beside Evolve | Evolves that item one tier with no cash, shards or player level (`Purchases.gearSkip`). The item level must be at its tier cap. If the item already passed that tier by the time the receipt arrives, the buyer gets the cash and shards of that evolve at their rebirth price instead. |

Also sold (same day): **2x Cash** (pass, bar sales x2), **Starter Value Pack** (one per player), **Level Up Pets to Max** (every equipped pet) and **Extra Pet Slot**, which is now a product (`PetSlot`, saved as `flags.extraPetSlot`) instead of the old pass. Tier-ups cover tiers 1 to 7 for both items (14 products).

Ids: every product and pass the owner created in the dashboard is wired (see `tests/Purchases.spec`); Tip Jar, Pet Treat, Pet Feast and the Offline Hours+ pass have no dashboard entry yet and stay at `Id = 0` (off sale). The Store builds a card for any product its saved prefab lacks (`StoreController` clones one), so the prefab export does not have to be regenerated; `tools/build-native-ui.luau` includes them.

## Verification

`Shared.Pacing` models the economy; `tests/Pacing.spec.luau`, `Levels.spec`, `Rebirth.spec`, `Hooks.spec`, `Perks.spec`, `Refining.spec`, `Rewards.spec`, `RebirthReset.spec` and the others check the rules. The rebirth cost list was tuned with the model to the lap targets above.

## Known limits

- The model is a greedy-purchase approximation, not a forecast; real telemetry replaces it.
- The Golden Node and shard crumbs add reward on top of the average.
- The Perks panel is built in code (`NativeMenus.Perks`) when no `ColonyPerks` prefab exists in StarterGui; the existing `.rbxmx` menus were not regenerated and still show their old copy until rebuilt in Studio (`tools/build-native-ui.luau`).
- Nothing was run in Studio; specs ran in a standalone Luau harness with Roblox stubs.
