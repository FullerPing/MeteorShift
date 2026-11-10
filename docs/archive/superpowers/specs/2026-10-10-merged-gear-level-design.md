# Merged gear level, redesigned upgrade menu, harder gear scaling

Date: 2026-10-10. Status: draft for review.

## Goal

The pickaxe has four stats (Power, Swing speed, Reach, Crit) bought one at a time, and only Power gates evolving. That makes Speed, Reach and Crit optional side purchases and gives the menu four rows to manage. Replace them with **one level per item** that raises everything together, evolve every 10 levels, and make gear a little more expensive. The backpack follows the same model (it has one stat, `capacity`, so its change is a rename plus the menu).

Decided with the owner:

- Evolving stays a **separate paid step** at the cap: press EVOLVE, pay the tier's cash and shards, meet the player-level gate (`Levels.evolveLevel`). Nothing about the evolve rules changes.
- Scaling is **slightly harder**: single price curve with base +50% over today's Power curve and growth 1.115 to 1.12.
- Rebirth keeps the gear tier (shipped earlier today, `RebirthReset.luau`); only the level resets.

## Model

Each item has one `level`, 1 to `Gear.cap(tier)` (= 10 x tier). The stored `pickaxeTier` and `backpackTier` stay: the level stops at the cap until the player evolves.

| Save field (before) | After |
|---|---|
| `pickaxeStats = { power, speed, reach, crit }` | `pickaxeLevel: number` |
| `backpackStats = { capacity }` | `backpackLevel: number` |

Everything the pickaxe does is derived from `pickaxeLevel` in `Gear.pickaxe(tier, level)`, using the formulas that exist now with the one level in place of each stat:

- Power: `Gear.power(level)`; Damage and Swing: `knot(...)` at `level`.
- Reach: `Config.Meteor.MineRange + ReachPerLevel x (level - 1)`; Crit chance: `CritPerLevel x (level - 1)`.
- Backpack capacity: `knot("backpack", "Capacity", level)`.

The Gate is the level itself: `Gear.evolution(...).ready = level >= Gear.cap(tier)`. `Config.Gear` drops `Gate` and the per-stat `Cost` tables; each of `Pickaxe` and `Backpack` keeps one `Cost = { Base, Growth }`. `Stats` and `Names` stay as display metadata for the shop's readout lines.

API changes in `Shared.Gear`:

- `price(kind, level)`, `canLevel(kind, tier, level)`, `bulk(kind, tier, level, cash, limit)`, `evolution(kind, tier, level)` take a level instead of a stat name and stats table.
- `freshPickaxeStats` / `freshBackpackStats` / `clean*Stats` are replaced by `levelsForTier(tier)` (already exists) and `cleanLevel(tier, saved)`.
- `ShopService:UpgradeStat(player, kind, stat)` becomes `UpgradeLevel(player, kind)`; the client remote `Upgrade(kind)` and the `Upgraded` signal carry `(kind, level)`. The remote keeps its request gate and server-side checks (cap, price, cash).

## Economy

- Pickaxe: `Cost = { Base = 45, Growth = 1.12 }` (was Power 30 / 1.115). Backpack: `Base = 37.5` (was 25), growth 1.12.
- Computed bundle cost (cash to take a fresh tier t-1 item to tier t, including the evolve price), pickaxe:

| Tier | Before | After | Change |
|---|---|---|---|
| 2 | 684 | 913 | +33% |
| 3 | 1,940 | 2,715 | +40% |
| 4 | 5,728 | 8,315 | +45% |
| 5 | 17,868 | 26,419 | +48% |
| 6 | 52,766 | 80,871 | +53% |
| 7 | 155,280 | 247,159 | +59% |
| 8 | 467,833 | 766,817 | +64% |

- The change is bigger than the headline +50% base because growth compounds. The owner picked "slightly harder"; if this reads as too steep, growth 1.118 is the knob to turn first. The plan recomputes the backpack column and the full-game gear total.
- The new level also carries Speed, Reach and Crit, which players used to buy separately (or skip). Maxed, a level-80 pickaxe has +11.85 studs reach and 23.7% crit for everyone. The plan reviews `ReachPerLevel` / `CritPerLevel` against `Pacing` before shipping; halving them is the likely adjustment.
- `Gear.bundleCost` uses the new curve (one level stream instead of the Gate stat), so `Pacing` follows automatically. The plan re-runs the `Pacing` model and re-checks the rebirth cost list tuned against it (`docs/design/economy-rework.md`).

## Migration (profile version 6 to 7)

In `DataService`'s migration chain, behind `data.version < 7`:

- `pickaxeLevel = clamp(old pickaxeStats.power, 1, cap(tier))`; `backpackLevel = clamp(old backpackStats.capacity, 1, cap(tier))`. Missing or invalid values fall back to `levelsForTier(tier)`.
- Speed, Reach and Crit levels above the tier's fresh level were paid for but no longer exist. Refund their cash at the **old** prices (the old `Base`/`Growth` constants live in the migration only), added to `data.cash`, and tell the player once with a toast on first join.
- Nothing else in the profile changes. The old `pickaxeStats` / `backpackStats` keys are set to nil.
- Dev hooks in `Main.server.luau` (`setGear`, `DevGrant`, `DevBench`) and `ProfileTemplate` move to the new fields.

## Rebirth

`RebirthReset.apply` keeps the tier (current behavior) and sets `pickaxeLevel` / `backpackLevel` to `levelsForTier(tier)`. Head Start stays a tier floor. (Whether Head Start is still worth its shard cost is a separate owner decision, not part of this change.)

## Menu

The GearShop keeps its two tabs (PICKAXE, BACKPACK), the showcase viewport with name and tier chip on the left, and the 1x / 10x / MAX amount toggle. The change is the right side:

- `UpgradePanel` is reused with two rows: LEVEL ("Lv. 7 / 10", with the levels the chosen amount adds) and EVOLVE. There are no per-stat rows.
- The level shows in the info panel ("Lv. 7 → 8"), and the evolve row's bar fills toward the tier cap.
- UPGRADE shows the price for 1x, 10x or MAX. At the cap it becomes EVOLVE and shows cash, shards and the player-level requirement, using the existing EVOLVE rules and notices.
- The `GearShop` prefab is generated from `NativeMenus/Shop.luau`; the plan regenerates it (`tools/build-native-ui.luau`, `assets/native-ui/GearShop.rbxmx`) and checks the phone sizes in `EquipmentShopLayout`.

## Other code that reads the stats

`PlayerStateService` (replication, `GetPickaxe`, capacity), `WorldEquipment`, `ShopController`, `EquipmentShopLayout` and the gear hall displays under `tools/map-v2` use the stat tables and move to the level. The replicated state carries `pickaxeLevel` / `backpackLevel`.

## Testing

- Rewrite `tests/Gear.spec.luau` (about 40 cases) for the single level: derived stats, price curve, caps, `bulk`, evolution readiness, `bundleCost`.
- New: migration cases (typical, capped, missing, with refund), rebirth keeps the tier and resets the level, `WorldEquipment` with levels.
- `Pacing.spec` and `RebirthReset.spec` updated; the full suite must pass in Studio (510 passing now).
- Play check in Studio: buy 1x / 10x / MAX, hit the cap, evolve, rebirth, rejoin with a migrated old profile, and the phone layouts.

## Out of scope

Head Start perk rework, new tiers or art, pet effects, pass/product changes.
