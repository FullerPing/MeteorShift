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

## Verification

`Shared.Pacing` models the economy; `tests/Pacing.spec.luau`, `Levels.spec`, `Rebirth.spec`, `Hooks.spec`, `Perks.spec`, `Refining.spec`, `Rewards.spec`, `RebirthReset.spec` and the others check the rules. The rebirth cost list was tuned with the model to the lap targets above.

## Known limits

- The model is a greedy-purchase approximation, not a forecast; real telemetry replaces it.
- The Golden Node and shard crumbs add reward on top of the average.
- The Perks panel is built in code (`NativeMenus.Perks`) when no `ColonyPerks` prefab exists in StarterGui; the existing `.rbxmx` menus were not regenerated and still show their old copy until rebuilt in Studio (`tools/build-native-ui.luau`).
- Nothing was run in Studio; specs ran in a standalone Luau harness with Roblox stubs.
