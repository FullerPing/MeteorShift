# Monetization

Everything MeteorShift sells is one row in `src/shared/Config/Monetization.luau` — eight game passes and thirty developer products — and every purchase is a **fixed grant**: a known amount of cash, Core Shards, timer seconds, XP, a credit, a tier, or a permanent flag. Nothing on the Robux path rolls a pet, rerolls mineral odds, or hatches an egg (`Monetization.luau:16-20`, `src/shared/Purchases.luau:2-4`). This guide is the catalog, where each item is sold, how receipts are granted, and the policy rules the store is built around. It supersedes the old purchases guide (now archived at `docs/archive/purchases.md`); the structural plumbing behind it is in [architecture.md](architecture.md).

## Ground rules of the catalog

- **`Id = 0` means not on sale.** Nothing is prompted, nothing is looked up from Roblox, and the store card shows **NOT ON SALE YET** (`Monetization.luau:7-9`; `src/client/Controllers/StoreController.luau:31`, `:138`, `:142`, `:144`). Fill a real id in from the Creator Dashboard to switch an item on — ids are never invented (`Monetization.luau:128` comment; CLAUDE.md "Owner decisions").
- **`Robux` is the intended price, not the live one.** For items with an id the store reads the live regional price via `GetProductInfoAsync` (`Monetization.luau:4-5`; `StoreController.luau:197-209`, loaded per card at `:297`). `Robux` is the display fallback: it is the card's seed price with no id (`StoreController.luau:223`, rendered at `:176`) and the quoted price on off-sale cards and buttons, whose button text still reads NOT ON SALE YET (`:31`, `:180`). A live lookup in flight shows LOADING PRICE (`:175`).
- **The prices below are a snapshot.** They duplicate `Config.Monetization` for readability — the file is the source of truth; re-read it (and its cites) after any dashboard change.

## Game passes (8, in store order `Monetization.luau:54`)

Ownership comes from Roblox, never a profile flag: it is resolved on join with a pcall'd `UserOwnsGamePassAsync` per pass and when `PromptGamePassPurchaseFinished` fires (`src/server/Services/MonetizationService.luau:194-214`, `:478-484`). Consumers that must not act before ownership resolves call `WaitForPasses` (`:117-124`). All line cites in this table are `src/shared/Config/Monetization.luau`.

| Key | Id | Intended R$ | Fixed effect (effect site) | Cite |
|---|---:|---:|---|---|
| `TwoXOre` | 2026934474 | 149 | Ore quantity per hit ×2; mineral odds never touched (`MonetizationService.luau:130-133`) | `:57-63`, `OreMult :367` |
| `TwoXCash` | 2026760484 | 129 | Every bar sale ×2, stacking with rebirth/index/VIP/pet multipliers (`MonetizationService.luau:141-144`) | `:64-70`, `CashMult :368` |
| `BiggerBackpack` | 2025488489 | 99 | Backpack capacity ×2 on every tier (`MonetizationService.luau:146-148`) | `:71-77`, `BackpackMult :369` |
| `OfflineHours` | 0 — off sale | — | Offline catch-up cap raised to `Config.Home.OfflineCapPass` (`MonetizationService.luau:151-155`) | `:78-83` |
| `AutoDeposit` | 2026682466 | 129 | Mined ore goes straight to the hopper, overflowing into the backpack (`MonetizationService.luau:157-159`) | `:84-90` |
| `VIP` | 2027090469 | 199 | +10% bar sales (`MonetizationService.luau:161-163`) and a [VIP] chat tag (`:177`; tag text `Monetization.luau:371-372`) | `:105-111`, `VIPBarBonus :370` |
| `Drillbot` | 2026256458 | 129 | The fixed Drillbot pet permanently (`src/shared/Config/Pets.luau:132-133`) | `:91-97` |
| `SolarPhoenix` | 2026178485 | 249 | The fixed Solar Phoenix pet permanently (`Pets.luau:134-135`) | `:98-104` |

The Extra Pet Slot **pass** is gone: the slot is now a product saved as `flags.extraPetSlot` (`Monetization.luau:26-27`; `tests/Purchases.spec.luau:53` asserts `Passes.ExtraPetSlot` is nil). The Extra Refinery pass was deliberately never added — one production line means no second pad to sell (`Monetization.luau:11-14`).

## Developer products (30)

`ProductOrder` (`Monetization.luau:114-117`) lists the 16 store products; `GearOrder` (`:120-123`) lists the 14 tier-ups, which are **not** store cards (`tests/Purchases.spec.luau:71-81`). Grants are pure and fixed in `src/shared/Purchases.luau:71-124`. All line cites in this table are `src/shared/Config/Monetization.luau`.

| Key | Id | Intended R$ | Fixed grant | Cite |
|---|---:|---:|---|---|
| `StarterPack` | 3717709173 | 49 | Cash pack (below) + 2 Mini Overclocks + 1,500 XP per equipped pet; one per player, flagged `flags.starterPack` (`Purchases.luau:97-105`) | `:182-188`, `StarterPack :395` |
| `TipJar` | 0 — off sale | 5 | Session cosmetics only: confetti, toast, [Supporter] attribute (`MonetizationService.luau:307-310`); the grant changes no profile value (`Purchases.luau:73-74`, `tests/Purchases.spec.luau:128-137`) | `:133-139` |
| `PocketChange` | 3717721006 | 19 | Cash pack: 10 min of line income, floor and share below (`:398`) | `:140-146` |
| `MiniOverclock` | 3717721310 | 19 | +10 min on the same `overclockLeft` timer as Overclock (`Purchases.luau:106-108`, `MiniOverclock :393`) | `:147-153` |
| `OreRush` | 3717656636 | 29 | +30 min of ×2 ore per hit; with the 2x Ore pass the larger multiplier wins, never ×4 (`Purchases.luau:42-46`, `OreRush :396`) | `:154-160` |
| `CashBundle` | 3717721086 | 59 | Cash pack: 60 min of line income (`:399`) | `:161-167` |
| `CallMeteor` | 3717657480 | 19 | Credit `credits.callMeteor`, spent via `UseCallMeteorCredit` (`MonetizationService.luau:380-395`) | `:168-174` |
| `Overclock` | 3717721351 | 39 | +30 min online of ×2 refinery speed; offline catch-up ignores it (`Purchases.luau:106-108`, `Overclock :387-390`) | `:175-181` |
| `PetMax` | 3717721195 | 49 | Every **equipped** pet to `Pets.MaxLevel`; unequipped pets untouched, no hatch, pity unchanged (`Purchases.luau:81-92`) | `:189-195` |
| `PetSlot` | 3717720944 | 49 | Permanent extra equipped slot, saved `flags.extraPetSlot` (`Purchases.luau:93-94`, read at `MonetizationService.luau:136-139`) | `:196-202` |
| `BossMeteor` | 3717656947 | 99 | Credit `credits.bossMeteor`; needs the scheduled boss's rebirths (`src/shared/CallMeteor.luau:45-46`; `Meteor.Boss.MinRebirths = 3`, `src/shared/Config/Meteor.luau:80`) | `:203-209` |
| `Shards50` | 3717688986 | 19 | +50 Core Shards straight to the balance (`Purchases.luau:117-119`, `ShardPacks :392`) | `:210-216` |
| `Shards250` | 3717689098 | 69 | +250 Core Shards | `:217-223` |
| `Shards1000` | 3717689250 | 199 | +1,000 Core Shards | `:224-230` |
| `RebirthKeep` | 3717690498 | 99 | Credit `credits.rebirthKeep`; the next rebirth keeps everything (`MonetizationService.luau:35-36`, spent in `Lib.RebirthReset`) | `:231-237` |
| `StreakShield` | 0 — off sale | 9 | +1 daily streak shield above the free cap, bought shields uncapped (`Purchases.luau:95-96`, `tests/Purchases.spec.luau:326-332`) | `:126-132` |

**Tier-ups** (`Monetization.GearOrder`) evolve one gear tier instantly — no cash, shards or player level, but the level must be at its cap. If the item already passed that tier, the receipt instead pays back that evolve's cash and shards at the buyer's rebirth price (`Purchases.gearSkip`, `Purchases.luau:130-154`). Cites and intended prices, `src/shared/Config/Monetization.luau`:

| Tier-up | R$ | Cite | | Tier-up | R$ | Cite |
|---|---:|---|---|---|---:|---|
| `PickaxeT1` T1→T2 | 5 | `:238-246` | | `BackpackT1` T1→T2 | 5 | `:301-309` |
| `PickaxeT2` T2→T3 | 9 | `:247-255` | | `BackpackT2` T2→T3 | 9 | `:310-318` |
| `PickaxeT3` T3→T4 | 19 | `:256-264` | | `BackpackT3` T3→T4 | 19 | `:319-327` |
| `PickaxeT4` T4→T5 | 49 | `:265-273` | | `BackpackT4` T4→T5 | 39 | `:328-336` |
| `PickaxeT5` T5→T6 | 89 | `:274-282` | | `BackpackT5` T5→T6 | 89 | `:337-345` |
| `PickaxeT6` T6→T7 | 179 | `:283-291` | | `BackpackT6` T6→T7 | 179 | `:346-354` |
| `PickaxeT7` T7→T8 | 259 | `:292-300` | | `BackpackT7` T7→T8 | 259 | `:355-363` |

Cash packs (`Monetization.CashPacks`, `Monetization.luau:397-401`): PocketChange and StarterPack are 10 minutes of income with floor 2,000 and a ceiling of 30% of the next rebirth cost; CashBundle is 60 minutes, floor 20,000, ceiling 80%.

## Where each thing is sold — the Store rule

Every pass and product must appear in **exactly one** `Config.Store.Sections` entry **or** in `Config.Store.Elsewhere` — two tests enforce it, so adding a product means touching both the catalog and the store config (CLAUDE.md "Testing conventions"):

- `tests/StoreLayout.spec.luau:8-25` walks `Elsewhere` and every section's `Keys`, fails on a key in two sections (`:19`) and on any `PassOrder`/`ProductOrder` key with no section (`:23-24`); `:27-34` checks section ids are unique and tab captions ≤ 8 chars.
- `tests/Purchases.spec.luau:71-81` additionally pins that tier-ups are in `GearOrder` only, never a store card, and that store products carry no `Kind`.

`Config.Store.Sections` (`src/shared/Config/Store.luau:28-44`) renders as one scrolling page of titled sections — featured banner, passes, shards, meteors, cash, boosts, pets, support (`:30`-`:43`) — with a tab per section on the left (`src/client/NativeMenus/Store.luau:1-6`). `Config.Store.Elsewhere` (`Store.luau:22-26`) lists the three exceptions and where they live instead:

- `TwoXOre`, `TwoXCash` — round offer tiles in the game (`OfferController`: header `src/client/Controllers/OfferController.luau:1-8`, `OFFERS :29-32`). The same controller also sells the one-per-player `StarterPack` there, hiding any offer once owned or while its id is 0 (`:4-6`, `:127`); the tiles are placed by `HudLayout.offerSlots` and can be moved or hidden as "Offers" in `Config.HudEdit`.
  Each tile wears its Robux price on a gold tag (`src/client/RobuxPrice.luau`: live `GetProductInfoAsync` price, `Robux` from Config until it answers), and a tap opens a quick preview (`src/client/NativeMenus/OfferPreview.luau`) listing the definition's `Highlights` (else its `Description`) with a BUY button that opens the Roblox prompt.
- `RebirthKeep` — a button in the Rebirth menu (`src/client/Controllers/RebirthController.luau:80-81`, priced and prompted at `:128-134`, `:182-184`; the live dashboard price replaces the intended one once loaded, `:193-195`; buying it rebirths as soon as the receipt lands, `pendingKeep` `:82`, `:190-191`).
- Tier-ups (`Kind` set) — the gear shop's **EVOLVE NOW** button on the current tier's evolve row (`src/client/Controllers/ShopController.luau:68-71`, label with the Robux price `:102-109`); the same receipts run through MonetizationService, which re-fires `ShopService` signals so the shop reacts (`MonetizationService.luau:285-297`).

Inside the Store itself: cards are authored in `NativeMenus/Store.luau` and bound by name in `StoreController` (the native-menu workflow is [native-ui.md](native-ui.md)); `buttonState` decides BUY / OWNED / NOT ON SALE YET / UNAVAILABLE / USE CREDIT (`StoreController.luau:21`, `:31`, `:128-146`) — owned passes read `owned` (`:129`), one-off products read `flags` via `State.purchased` (`:131-133`), Ore Rush disables for 2x Ore owners with "You own 2x Ore" (`:134`, `:164`, `:179`), and meteor products fall back to USE CREDIT when a credit is banked (`:135-140`). A card with `Id = 0` never prompts (`:66`).

Call a Meteor keeps availability rules (`Monetization.CallMeteor`, `Monetization.luau:378-384`: only during a countdown with more than 60 s left, jumps it to 30 s, 180 s cooldown after a called meteor's event, 3 calls per server per rolling hour): the server publishes availability so the button can disable with the reason (`MonetizationService.luau:69`, `:432-439`, refreshed every `AvailabilityInterval` `:509-514`, `Monetization.luau:407`). If a purchase still races the window closed, the buyer keeps a credit instead of losing money (`MonetizationService.luau:233-254`).

## Server flow: how a purchase is granted

**Passes.** On join `_resolve` asks Roblox per non-zero pass id; in-game purchases land on `PromptGamePassPurchaseFinished` (`MonetizationService.luau:194-214`, `:478-484`). Effects are pulled from the service (`OreMult`, `CashMult`, `BackpackMult`, `OfflineCap`, `HasAutoDeposit`, `VIPMult`, `RefinerySpeedMult`, `:130-168`), never read off a client. In Studio the `DevPasses` string attribute grants passes for testing (`:97-110`, `:502-506`).

**Products.** `ProcessReceipt` routes into `_processReceipt` (`MonetizationService.luau:318-355`, installed at `:486-493`):

1. No player, no loaded profile, unknown product id, or a transaction already processing for that player → `NotProcessedYet` (`:319-331`) — Roblox will retry.
2. `Purchases.receipt` dedupes by `PurchaseId`: processed ids are kept in the profile **permanently** (`Monetization.luau:403-404`), the grant runs once, then `DataService:Save` must succeed **before** `PurchaseGranted` is returned (`src/shared/Purchases.luau:158-170`; save call `MonetizationService.luau:342-344`, ack `:347-352`). A failed save keeps grant and id together in memory, so the retry saves without granting twice (`Purchases.luau:156-157`, `tests/Purchases.spec.luau:293-313`; ids older than 75 newer purchases still dedupe, `:315-324`). History trimmed by the old 50-id version cannot be recovered (`Monetization.luau:403-404`).
3. Cosmetic and notice effects fire only after the save (`_finishProduct`, `:305-316`); a side-effect throw is contained so it can't make the receipt retry and call a meteor twice (`:283-300`).
4. Cash amounts are computed server-side from `EconomyService:ExpectedIncome` (`:219-224`, `src/server/Services/EconomyService.luau:54`); `Purchases.grant` refuses a missing or non-finite cash amount, so a client can never quote its own payout (`Purchases.luau:76-78`, `:98-100`, `tests/Purchases.spec.luau:147`, `:222`).

The cash quote itself: `Purchases.cashGrant` = `Income.grant` — `floor(clamp(minutes × 60 × barsPerSecond × averageBarPrice × saleMultiplier, floor, ceiling))` (`Purchases.luau:38-40`, `src/shared/Income.luau:9-12`; the ceiling wins if it sits below the floor, `Income.luau:8`, `tests/Purchases.spec.luau:99`). `averageBarPrice` weights each meteor type by `Weight × Levels.oreYield(level, ore)`, so slower-than-cleared ore contributes less to the estimate (`Purchases.luau:24-36`; clearance levels iron/frost/crystal/alien at levels 1/12/24/38, `src/shared/Config/Levels.luau:32`; the spec pins the level-1 and full-clearance quotes, `tests/Purchases.spec.luau:102-117`). The ceiling is a share of the next rebirth cost (`MonetizationService.luau:223`), so one pack can never buy a rebirth by itself (`tests/Purchases.spec.luau:88-98`).

**Studio testing.** `ServerStorage.DevProduct` (Studio-only BindableFunction, `MonetizationService.luau:359-377`, installed `:495-501`) runs the same grant-and-save path without inventing a receipt; combined with the `DevMemoryStore` attribute it gives isolated acceptance checks. Both are covered in the dev-hooks guide. Analytics: `pass_bought` / `product_bought` per grant and `purchase_prompt` per closed prompt (`src/server/Services/TelemetryService.luau:355`, `:359`, `:250`).

## Player policy and paid randomness

Roblox policy is resolved in the background per session, independent of profile loading (`src/server/Services/PlayerPolicyService.luau:1-4`, `:48-57`). The cached summary starts restricted while loading and stays restricted if the lookup fails — one initial attempt plus two retries at 1 s and 3 s, then `unavailable` (`src/server/Lib/PlayerPolicies.luau:21`, `:23-29`, `:54-72`; the conservative default is what clients see first, `PlayerPolicyService.luau:17-21`). Servers use `:CanUsePaidRandomItems(player)` before any paid random outcome and `:CanTradePaidItems(player)` for both sides before any paid-item transfer (`PlayerPolicyService.luau:40-46`; both require `Status == "ready"`, `PlayerPolicies.luau:93-101`). The summary is session-only — the cache is an in-memory table dropped on leave, never saved to a profile (`PlayerPolicies.luau:46`, `:84-85`). Clients may observe the `Policy` property for display, but server checks still enforce (`PlayerPolicyService.luau:16-22`, `:31-33`).

The store as built matches that posture, and that is the product policy:

- **Eggs cost earned Core Shards only, never Robux.** Every egg has a shard `Cost` (Meteor 30 / Crystal 120 / Aurora 250, `src/shared/Config/Pets.luau:86-95`) and the server charges `data.shards` (`src/server/Services/PetService.luau:102-119`, charged at `:114-119`). No product touches an egg, and eggs keep their published odds and pity rules (`Pets.luau:84-85`).
- **No product changes mineral odds or grants a random pet.** 2x Ore doubles quantity only; cash packs are bounded income estimates; shard packs add fixed shards (`Monetization.luau:16-20`, `Purchases.luau:2-4`). Paid randomness is therefore not used anywhere — if it is ever introduced, the policy check above is mandatory.
- **Premium pets are fixed passes, never egg prizes** (`Pets.luau:100`, `:131`).

## Sold on purpose (owner decisions — not bugs)

CLAUDE.md's "Owner decisions" and `Monetization.luau:20-29` record these as deliberate pay-for-progress choices; wire and polish them, don't re-litigate or shrink them:

- **Core Shards as fixed packs** (`Shards50/250/1000`, `Monetization.luau:210-230`) — sold as fixed amounts, never random.
- **Gear tier-ups** — EVOLVE NOW in the gear shop skips the cash/shards/level requirement at the tier cap (table above; `ShopController.luau:102-109`).
- **The forced Alien boss meteor** (`BossMeteor`, `Monetization.luau:203-209`) — same calling limits as Call a Meteor, gated by the scheduled boss's `MinRebirths` (`Meteor.luau:80`).
- **"Rebirth and Keep Everything"** (`RebirthKeep`, `Monetization.luau:231-237`) — the next rebirth keeps cash, gear, production, ore and bars; the multiplier still resets and climbs (`:236`; `MonetizationService.luau:35-36`).
- **Pet max level** (`PetMax`, `Monetization.luau:189-195`) — equipped pets straight to `Pets.MaxLevel` (`Pets.luau:42`).
- **The Starter Value Pack** (`StarterPack`, `Monetization.luau:182-188`) — one per player, `flags.starterPack`.

## Premium pet pricing flows from Monetization

The `drillbot` and `solarPhoenix` rows in `Config.Pets` carry **no price field** — they carry `Pass = "Drillbot"` / `Pass = "SolarPhoenix"` (`src/shared/Config/Pets.luau:132-135`), and the Pets menu reads the price through that key: `Config.Monetization.Passes[def.Pass]` and its `Robux` (`src/client/Controllers/PetsController.luau:140-142`, premium card styling `:300`, `:308-309`). The old duplicate Robux mirror in `Pets.luau` was deleted deliberately — if a premium pet price looks wrong, fix `Monetization.luau`, never add a number back to `Pets.luau`.

## Guards

`tests/Purchases.spec.luau` pins the whole catalog: off-sale items keep their intended prices and `Id = 0` (`:37-43`), live pass ids and prices with `OfflineHours` the sole uncreated pass (`:45-55`), every live product id exactly once and everything else off sale (`:57-69`), plus the grant arithmetic, receipt idempotency and retry behaviour cited above. `tests/StoreLayout.spec.luau` pins the Sections/Elsewhere coverage rule. Changing prices, ids or the section map without updating these specs fails the Runner (`tests/Runner.luau`).

## Where to read next

- Multipliers, income and rebirth math: the economy guide (being rebuilt alongside this wave — see `Shared.Pacing` and the economy-rework record in the docs archive).
- Pet roster, egg odds and perks: [pets.md](pets.md).
- Dev hooks (`DevProduct`, `DevPasses`, `DevMemoryStore`): the dev-hooks guide.
- How services, receipts and the state snapshot fit together: [architecture.md](architecture.md); native menu authoring: [native-ui.md](native-ui.md).
