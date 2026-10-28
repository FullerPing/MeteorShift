# Rebirth price inflation

Date: 2026-10-10. Status: draft; executes after [merged gear level](2026-10-10-merged-gear-level-design.md).

## Goal

Each rebirth already multiplies bar sales by 5 (`Config.Rebirth.CashMult`). Add a matching inflation: every cash price for gear and production gets **3x per rebirth**. A player's real gain per rebirth is 5/3 (about 1.67x), but income and prices both read as huge numbers, which the owner wants because it makes progress feel fast.

Decided with the owner:

- "Everything" means all cash prices of upgrades the player buys with cash: gear levels and evolves, and the four production stations.
- The huge numbers are the point, so the number format has to keep up.

## Rule

`Rebirth.priceMult(rebirths) = PriceGrowth ^ rebirths` for the listed ranks (`Config.Rebirth.PriceGrowth = 3`), then x `Legacy.PriceGrowth` per rank past the last listed rank, mirroring `multiplier`.

- `Legacy.PriceGrowth = 1.2`, so the Legacy ranks keep the same 5/3 ratio against `Legacy.MultGrowth = 2` (2 / 1.2).
- It is a pure function in `Shared.Rebirth` next to `cost` and `multiplier`; it reads the saved `rebirths`, which is already replicated to the client in the state table.

## What is scaled

| Price | Where | Change |
|---|---|---|
| Gear level price, evolve cash | `Shared.Gear` (`price`, `bulk`, `evolution`, `bundleCost`) | a trailing `priceMult: number?` (default 1) multiplies the cash result |
| Station upgrade cash | `UpgradeService:BuyStation`, `RefineryController` (buy button, MAX count, affordability checks) | `Home.Stations[id].Levels[n].Cost x priceMult` |
| Shown prices | `Price.text` callers in `ShopController`, `RefineryController` | pass the scaled value |

Not scaled, and why:

- **Rebirth cost list** (`Config.Rebirth.Costs`): it is already its own tuned table. It is retuned (below), not multiplied.
- **Core Shards prices** (colony perks, eggs, the shard part of an evolve): shards are not cash and do not inflate with the cash multiplier.
- **Cash products** (`PocketChange`, `CashBundle`): they already pay minutes of current income, capped at a share of the next rebirth cost (`Purchases.cashGrant`, `Monetization.CashPacks`), so they follow the economy with no change. Their fixed `Floor` is a floor only.
- **Level-gated unlocks** (player level, XP): unchanged.

Server and client both compute the price from the same function and the same `rebirths`; the server's check is the authority, as today.

## Retuning the rebirth costs

Inflation slows income growth inside a lap (upgrades cost more than the income that pays for them), so with the current `Costs` list laps would stretch past the 13 / 16 / 20 / 24 / 25 minute targets. The plan:

1. Add `priceMult` to `Shared.Pacing` (gear and station candidate costs) so the model sees the inflation.
2. Re-run the model in Studio and fit a new `Costs` list so laps return to the same targets; `tests/Pacing.spec` holds them.
3. Document the change next to the existing tuning notes in `Config.Rebirth` and `docs/design/economy-rework.md`.

The fit is computed, not guessed; the spec fixes the targets, not the list.

## Big numbers

`Shared.Format.number` stops at `Dc` (1e33) and prints larger values as a count of `Dc` ("48213Dc"). The new economy passes 1e33 in the late ranks. The plan extends the suffix table (Ud, Dd, Td, ...) to cover the range the retuned costs reach plus the Legacy ranks, with a test that `Format.number` never prints a four-digit value past the table. Cash and shard text elsewhere already goes through `Format`.

## Player-facing text

- The Rebirth panel's rules line says "Prices and income rise with each rebirth (cash x5, prices x3)".
- The Rebirth panel's next-rebirth preview shows the new price factor.

## Testing

- `tests/Rebirth.spec`: `priceMult` at ranks 0, 1, 16 and a Legacy rank; monotonic; ratio to `multiplier` is 5/3 throughout.
- `tests/Gear.spec` / shop: scaled `price`, `bulk` and `bundleCost`; `priceMult = 1` is identical to unscaled.
- Station upgrade: server charges the scaled price; a player at rank 2 cannot buy at the base price.
- `tests/Pacing.spec`: laps within the targets with the retuned `Costs`.
- `tests/Format.spec`: new suffixes, rounding at suffix boundaries.
- Full suite in Studio, then a Play check at rank 0 and at a rebirthed profile (prices shown equal prices charged).

## Out of scope

Shard prices, Robux products, pet and perk balance, new unlocks.
