# Fixed purchases

`Config.Monetization` lists every pass and developer product. All IDs remain `0`, so the store says **Not on sale yet** and never requests Marketplace metadata or prompts a purchase. `Robux` records the intended Creator Dashboard price for the new catalog; after IDs are configured, the store reads the live regional price from Roblox.

Nothing bought with Robux rolls a pet, changes odds, grants Core Shards, buys an egg, or hatches one. Shard eggs keep their existing visible odds and pity rules.

## Creator Dashboard catalog

| Kind | Key | Name | Intended Robux | Fixed effect |
| --- | --- | --- | ---: | --- |
| Game pass | `Drillbot` | Drillbot Pet | 99 | Drillbot permanently; its three perks follow [pets.md](pets.md). |
| Game pass | `SolarPhoenix` | Solar Phoenix Pet | 199 | Solar Phoenix permanently; its three perks follow [pets.md](pets.md). |
| Game pass | `ExtraPetSlot` | Extra Pet Slot | 49 | One permanent extra equipped slot; up to four pets with rebirth slots. |
| Developer product | `TipJar` | Tip Jar | 5 | Confetti, a thank-you toast, and a Supporter chat tag for the current session; no gameplay benefit. |
| Developer product | `PocketChange` | Pocket Change | 10 | Ten minutes of current line income; minimum $2,000 and maximum 3% of the next rebirth cost. |
| Developer product | `PetTreat` | Pet Treat | 15 | 1,500 XP to each pet equipped when the server grants the purchase. |
| Developer product | `MiniOverclock` | Mini Overclock | 19 | Adds 600 seconds to the existing refinery ×2 online timer. |
| Developer product | `OreRush` | Ore Rush | 25 | Adds 1,800 seconds of ×2 ore per hit while online. |
| Developer product | `PetFeast` | Pet Feast | 29 | 6,000 XP to each pet equipped when the server grants the purchase. |
| Developer product | `CashBundle` | Cash Bundle | 39 | Sixty minutes of current line income; minimum $20,000 and maximum 8% of the next rebirth cost. |

Existing passes (`TwoXOre`, `BiggerBackpack`, `OfflineHours`, `AutoDeposit`, `VIP`) and products (`CallMeteor`, `Overclock`) remain in the catalog. Their prices were not specified by this change. The existing Overclock still adds 1,800 seconds; Call a Meteor keeps its server availability rules and grants a reusable credit when a call cannot run.

## Cash calculation

`Shared.Purchases.cashGrant` computes:

```text
floor(clamp(minutes × 60 × barsPerSecond × averageBarPrice × saleMultiplier,
            packFloor, nextRebirthCost × ceilingShare))
```

The server obtains `barsPerSecond` from `Refining.lineRate`, including an active online refinery Overclock. This estimates income from the current station levels, independent of live hopper stock and collection-post room. The sale multiplier comes from `EconomyService:SaleMultiplier`, including rebirth, mineral-index, VIP, and equipped merchant bonuses.

Before Frost reaches full clearance, the average bar price is the iron price. At level 4 and above, each meteor's schedule weight is multiplied by its ore's `Levels.clearance`; prices are averaged using those adjusted weights. This explicitly interprets the requested ore-weighted average as slower ore contributing less to the estimate. At current tuning, the average is about $1,014.83 at level 4 and $4,830 once Crystal clears at level 6. It does not alter meteor scheduling or mineral odds.

The ceiling takes precedence if a future rebirth-cost retune would put it below the floor. Whole cash rounds down after clamping. A single pack remains below its next rebirth cost, though earned cash already held by the player can combine with the grant.

## XP, boost time, and slots

Pet XP goes to the equipped loadout when the grant is applied, once per unique owned pet. Unequipped pets receive nothing. Empty loadouts and pets already at level 10 receive no useful XP; these purchases do not hatch a replacement or grant shards. Overflow carries through levels using the normal pet XP rule, and XP is zero at level 10.

Mini Overclock and Overclock add to the same `overclockLeft` timer. Ore Rush adds to `oreBoostLeft`. Both timers persist through saves and rebirths, count down while online, and retain their remaining time offline. Offline refinery catch-up ignores Overclock. Ore Rush and the 2x Ore pass use the larger multiplier, so owning both still gives ×2. The store disables Ore Rush for pass owners with **You own 2x Ore**; a receipt already purchased still receives its fixed timer grant.

Pass ownership comes from Roblox, never a saved profile flag. Profile loading preserves a possible extra slot until ownership resolves. PetService then validates the saved loadout against the owned Extra Pet Slot pass. Ownership-dependent consumers wait for the lookup to complete by default, including when Roblox answers slowly.

## Receipts and Studio checks

The server serializes product receipt transactions per player. A new receipt applies its fixed grant, appends the `PurchaseId` to the profile, calls `DataService:Save`, and only then returns `PurchaseGranted`. Missing profiles, unknown products, concurrent transactions, and failed saves return `NotProcessedYet`.

A failed save leaves both the grant and its receipt ID together in memory. The next retry saves again without granting twice. Processed IDs are retained permanently; the earlier implementation trimmed history to 50 IDs, and IDs discarded by that version cannot be recovered. Tip Jar cosmetics and purchase notices are sent after a successful save; pending effects survive save retries within the current server session. The Supporter attribute is session state and is never saved as a gameplay entitlement.

In Studio, `ServerStorage.DevProduct` is a runtime-only BindableFunction next to the other dev hooks:

```lua
game.ServerStorage.DevProduct:Invoke(game.Players:GetPlayers()[1], "PetTreat")
```

It uses the same grant and save path without a purchase receipt. Each invocation is a new grant, and returns success plus an optional error. If its save fails, the error says that the grant remains in memory; invoking again is another grant. For isolated acceptance checks, enable the temporary Studio-only `DevMemoryStore` attribute before starting the server. Never save profile-mutating QA scripts into the place.

`tests/Purchases.spec.luau` covers cash arithmetic and limits, catalog prices and off-sale IDs, exact pet XP, boost durations, unchanged shards and pity, duplicate receipts, failed-save retries, and receipt retention beyond the old history limit.
