# Pets guide

Everything about pets: how they hatch, what each role does and where the server applies it, how slots
grow, what the paid parts are, and what the pet spec already guards. Tuning numbers live in
`src/shared/Config/Pets.luau`; the rules that read them live in `src/shared/Pets.luau` (pure, covered
by `tests/Pets.spec.luau`); the server that runs them is `src/server/Services/PetService.luau`. Every
number below cites a `file:line` opened when this page was written (2026-10-18) — when a number here
and its source disagree, **the code wins**.

## The hatch loop

Core Shards — earned by cracking meteors (see [economy.md](economy.md)) — buy egg hatches at the
Hatchery in the world, never in a menu.

| Step | What happens | Source |
|---|---|---|
| The plinth | one ProximityPrompt per egg at `Map.TownSquare.Hatchery.<eggId>`, "Hatch (N shards)", 0.25 s hold, 12-stud range; a missing stand warns | `src/server/Services/PetService.luau:257-284` |
| Gates | the egg must exist, the rebirths gate must be met, and the shard balance must cover the cost (shortfall notice otherwise) | `src/server/Services/PetService.luau:104-118` |
| The roll | shards are deducted, then two uniform rolls: one lands in the egg's odds, one picks inside the rarity (catalog order is the pick order) | `src/server/Services/PetService.luau:119-120`, `src/shared/Pets.luau:109-138`, order rule `src/shared/Config/Pets.luau:99-100` |
| Pity | each egg keeps a counter of hatches since the last `PityFrom`-or-better pet; on the egg's Pity-th such hatch the pool is PityFrom-or-better only; any such pet resets it | `src/shared/Pets.luau:113-137`, saved under `pets.hatches` (`src/server/Services/PetService.luau:121`), repaired on load (`src/shared/Pets.luau:252-259`) |
| Outcome | a new pet arrives at level 1; a duplicate is one more copy of the pet you own (`copies` on its saved entry, sharing that pet's level). Either way it goes out if a slot is free, and each copy out adds its perks again, up to the role caps | `PetService:Hatch`, `Shared.Pets.copies` / `outCount` |
| Throttle | client Equip/Unequip/Hatch requests are throttled to one per 0.15 s | `src/server/Services/PetService.luau:227-234,236-255` |

### Eggs (`src/shared/Config/Pets.luau:86-94`)

| Egg | Cost (shards) | Odds (%) | Pity | Gate |
|---|---|---|---|---|
| Meteor Egg | 15 | Common 60 · Uncommon 28 · Rare 9.5 · Epic 2.25 · Legendary 0.25 | Epic+ every 40 | — |
| Crystal Egg | 60 | Uncommon 40 · Rare 42 · Epic 15.5 · Legendary 2.5 | Epic+ every 15 | — |
| Aurora Egg | 135 | Epic 94 · Legendary 6 | Legendary every 20 | 2 rebirths (`src/shared/Config/Pets.luau:92`) |
| Magma Egg | 225 | Rare 50 · Epic 40 · Legendary 10 (only Magma Crab, Frost Yeti, Galaxy Griffin) | Legendary every 15 | 3 rebirths |
| Void Egg | 360 | Epic 70 · Legendary 30 (only Quartz Kitsune, Void Leviathan) | Legendary every 6 | 5 rebirths |

The group pet can also be claimed at the group stand by the spawn (`TownSquare.GroupPetStand`, `GroupStandController`), the same claim as the Pets menu's JOIN GROUP button.

Fusing (`Config.Pets.Fuse`, `Pets.canFuse` / `Pets.fuse`, `PetService:Fuse`): three copies of a pet plus Relic
Fragments by rarity (5 / 10 / 20 / 35 / 60) make it Fused (★): two copies are used up and all its perks are x1.5,
still stopped at each role's cap. Pass and group pets never fuse. The FUSE button sits in the pet's detail column.

Hatchery signs: `PetService:_writeSign` rewrites each stand's odds card and price from Config (`Pets.eggSign`) when
the server starts, so changing an egg in `Config/Pets.luau` updates its sign. The Magma and Void stands
(`Map.TownSquare.Hatchery.magmaEgg` / `voidEgg`) are recoloured copies of the Aurora stand until their egg meshes land.

Egg exclusives: a pet with `Eggs = { ... }` hatches only from those eggs, and an egg with `Own = true` hatches only
its exclusives (`Pets.eggPets(rarity, egg)`); every other egg draws from the shared pool of its rarities.

Pass pets are never egg prizes: `Pets.eggPets` skips any pet with a `Pass` key
(`src/shared/Pets.luau:89-98`) and no egg names the premium rarity in its odds.

### The odds policy (do not break)

- No purchase can roll a pet or move an odds number. Pass pets are fixed entitlements; every store
  item is a fixed grant (`src/shared/Config/Pets.luau:7-13`, `src/shared/Config/Monetization.luau:16-19,40-41`,
  policy §9.4 Compliance in [meteor-shift-spec.md](../design/meteor-shift-spec.md)).
- Quantity bonuses never touch a roll or its odds (`src/shared/Pets.luau:66-67`); nothing about pets
  changes mineral odds (`src/shared/Config/Pets.luau:13`).
- Eggs cost Core Shards and never direct Robux (owner decision). Core Shards themselves are also sold
  in fixed packs — `Shards50/250/1000` (`src/shared/Config/Monetization.luau:19-20,210-230,392`) — so
  "shards are earn-only" is no longer literally true; the invariant is that packs buy shards, never a
  roll, and eggs always show their odds.

## Rarity and the perk model

Six rarities, rarest last (`src/shared/Config/Pets.luau:74-82`): Common (grey), Uncommon (green),
Rare (blue), Epic (purple), Legendary (gold), Premium (pink — pass pets only).

Each perk grows **linearly** from its own Min at level 1 to its Max at level 10 and clamps outside
1-10 (`src/shared/Pets.luau:39-46`). Equipped pets add their perks per role and the sum is capped per
role (`src/shared/Pets.luau:179-200`); the first perk is the pet's main role
(`src/shared/Config/Pets.luau:2-4`). Perk counts follow rarity — Common 1, Uncommon 1, Rare 1-2,
Epic 2, Legendary 3, Premium 3 (`tests/Pets.spec.luau:258-273`).

| Role | Cap | What it does | Applied at |
|---|---|---|---|
| Miner | 100% | while your own validated swing landed within 15 s (`src/shared/Config/Pets.luau:47-48`, `src/shared/Pets.luau:52-55`), one hit per swing on the nearest target in reach at this share of your pickaxe Power and ore, straight to the hopper; counts for nothing else — no podium, core rewards, mineral drops, `Hit`, tutorial or meteor size (`src/server/Services/NodeService.luau:219-224`) | tick `src/server/Services/PetService.luau:211-224`, hit `src/server/Services/NodeService.luau:224-239` |
| Hauler | 3% | share of backpack capacity moved to the hopper each second (carries don't bank when there's nothing to carry) | `src/server/Services/PetService.luau:199-209` |
| Pack | 60% | backpack capacity | `src/server/Services/PlayerStateService.luau:127-132` |
| Swift | 30% | swing time cut (raises Mining Power per second) | `src/server/Services/PlayerStateService.luau:118-121` |
| Merchant | 45% | bar sale value | `src/server/Services/EconomyService.luau:48-49` |
| Yield | 40% | ore from each validated player hit, never mineral odds | `src/server/Services/NodeService.luau:246,263,339` |
| Sprint | 30% | walk speed on top of the base, without overriding other speed changes | `src/server/Services/PlayerStateService.luau:166` |
| Vault | 100% | hopper and collection-post capacity, online and offline catch-up | `src/server/Services/PlayerStateService.luau:134-141,231-252`, `src/server/Services/RefineryService.luau:111,168,174` |
| Crit | +15 pts | points added to the pickaxe's crit chance | `src/server/Services/PlayerStateService.luau:122` |
| Scholar | 60% | player XP from every source through `LevelService:AddXp`; **pet XP is unchanged** | `src/server/Services/LevelService.luau:62-67` |
| Shards | 30% | a cracked core's shard payout, multiplied then rounded down once | `src/shared/Pets.luau:76-78`, `src/server/Services/RewardService.luau:58` |

Caps and role display text: `src/shared/Config/Pets.luau:58-70`. Two monotonic invariants are spec-
pinned: the strongest level-10 value of a role never falls as rarity rises
(`tests/Pets.spec.luau:312-330`), and a paid pet ties or beats every free pet at level 1 and strictly
beats it at level 10 for each shared role (`tests/Pets.spec.luau:287-310`).

## Roster and look

14 pets in catalog order (the order also fixes egg picks, `src/shared/Config/Pets.luau:99-100`);
exact perks at `src/shared/Config/Pets.luau:101-136`, both endpoints pinned by
`tests/Pets.spec.luau:8-43`. No profile starts with pets (`src/shared/Config/Pets.luau:138`).
Look text is the owner's art direction, not code-enforced; per-pet mesh briefs live in
`tools/blender-assets/pets.py` and conventions in [pet-models.md](../art-pipeline/pet-models.md).

| Pet | Rarity | Perks Lv1 → Lv10 | Look direction |
|---|---|---|---|
| Pebble Pup | Common | Yield 5→10% | knee-high pup of rounded grey pebbles, matte; digs grey chips when you mine |
| Scrap Sparrow | Common | Scholar 8→16% | tan scrap-metal sparrow, bolt eye; metal "ting" on bar sales |
| Pack Mule | Uncommon | Pack 15→30% | sandy robot mule; panniers grow bigger at Lv10 |
| Spark Hare | Uncommon | Swift 5→12% | yellow hare with blue-white sparks; a spark jumps to your pickaxe on a swing |
| Jet Wisp | Rare | Swift 8→18%, Sprint 6→15% | cyan teardrop spirit with flame tails; flares when you swing |
| Coin Magpie | Rare | Merchant 8→20% | magpie with a coin in its beak; coin glint on sales |
| Cargo Mole | Rare | Hauler 0.6→1.5%, Pack 8→18% | mole in a hard hat with a satchel; hops ore toward the hopper |
| Granite Golem | Rare | Pack 20→38%, Vault 25→60% | boulder golem; chest hatch glows when the backpack nears full |
| Crystal Stag | Epic | Crit 4→10%, Miner 12→25% | violet crystal deer; antler flash and shard burst when it mines |
| Lode Wyrm | Epic | Hauler 0.8→2%, Vault 35→80% | copper burrowing worm; drags glowing ore along a light tunnel |
| Aurora Owl | Epic | Merchant 12→28%, Shards 6→15% | teal-mint owl; aurora ripple across feathers on sales |
| Meteor Drake | Legendary | Miner 22→36%, Yield 8→18%, Shards 8→20% | lava-cracked dragon with its own point light; meteor-streak arrival |
| Comet Fox | Rare (group reward) | Swift 6→14%, Sprint 5→12% | free once for joining the Roblox group (`Config.Pets.GroupReward`, group 526085770); never in an egg |
| Drillbot | Premium | Miner 25→40%, Swift 8→20%, Yield 10→20% | steel drone with a drill nose; assembles on arrival |
| Solar Phoenix | Premium | Miner 50→100%, Merchant 15→35%, Scholar 15→35% | gold-and-fire phoenix, the only pet with a halo ring |

Look rules that the client actually depends on (`src/client/PetModel.luau`): every saved model in
`ReplicatedStorage.PetModels` needs a `Body` part (`src/client/PetModel.luau:37-42`), a `PetColor`
attribute for tinting (`:43`, colours match `Config.Pets.List[...].Color`; the mesh meta sets both,
`tools/blender-assets/pets.py:11-23`), and a `Level10` folder whose children replace the base look at
level 10 (`src/client/PetModel.luau:21-36`). Rarity visual ladder (brief): Common plain and matte →
Uncommon second material plus a small animated part → Rare glow or particles → Epic a trail or halo →
Legendary those plus a light and a spawn flourish → Premium unique materials, a constant effect and a
signature idle. "Working" FX (flame breath, tunnel, coin glint, …) are named parts the client hides or
shows per role (`src/client/PetModel.luau:10-13`, fed by `PetService.Client.Working`, throttled to one
per 0.25 s per role, `src/server/Services/PetService.luau:59-67`).

## XP, levels and the paid max

- Max level is 10 (`src/shared/Config/Pets.luau:42`). XP from L to L+1 = `XpBase × XpGrowth^(L-1)`
  with 150 and 1.55 (`src/shared/Config/Pets.luau:43-45`, applied `src/shared/Pets.luau:149-154`) —
  about 14K total to max, and the spec keeps that sum between 8,000 and 30,000
  (`tests/Pets.spec.luau:156-162`). Overflow carries across levels; a maxed pet keeps 0 XP
  (`src/shared/Pets.luau:156-177`).
- Pets level on **your** validated hits only: every equipped pet earns the hit's XP — Crust 1, Core 2,
  Debris 0.2 (`src/shared/Config/Pets.luau:50-51`, awarded in
  `src/server/Services/PetService.luau:164-180`, wired to `NodeService.Hit` at `:311`); a miner pet's
  own hits grant none. Duplicates add 400 XP (`src/shared/Config/Pets.luau:96-97`).
- **Pet Max** is a sold 49-Robux product: "Level Up Pets to Max" takes every pet *currently equipped*
  straight to level 10 — a fixed grant, never a hatch (product `src/shared/Config/Monetization.luau:189-195`,
  grant `src/shared/Purchases.luau:81-89`, `Leveled` signal fires per pet
  `src/server/Services/MonetizationService.luau:265-266,294-296`). The Starter Value Pack grants 1,500
  XP to each equipped pet (`src/shared/Config/Monetization.luau:395`, applied
  `src/shared/Purchases.luau:104`); pet XP grants reach the equipped loadout only
  (`src/shared/Config/Monetization.luau:18`). The owner sells the max-level skip on purpose — wire and
  polish it, don't re-litigate it.

## Slots

`Pets.slots` (formula `src/shared/Pets.luau:140-147`, constants
`src/shared/Config/Pets.luau:53-56`): `min(1 + rebirths, 3)`, plus one more from rebirth 4 on, plus
one from the Extra Pet Slot product, plus the Pet Bond perk's bonus — up to 7 with everything
(`tests/Pets.spec.luau:91-105`).

- **Pet Bond** is a Colony Perk (bought with Core Shards, like all perks —
  `src/server/Services/PerkService.luau:2`): ranks cost 100 and 250 and add +1 and +2 slots
  (`src/shared/Config/Perks.luau:49-55`, read via `src/shared/Perks.luau:70-73`).
- **Extra Pet Slot** is a 49-Robux product (`src/shared/Config/Monetization.luau:196-202`), saved as
  the single boolean `flags.extraPetSlot` and read by
  `src/server/Services/MonetizationService.luau:135-138`.
- Equipping past the cap is refused server-side with a notice naming the ways to get more
  (`src/server/Services/PetService.luau:69-85`); while a purchase's entitlement is unresolved the
  saved extra slot is preserved but not activated (`src/server/Services/PlayerStateService.luau:94-101`).

## The two pass pets (Drillbot, Solar Phoenix)

Premium pets are fixed game-pass entitlements — the opposite of randomness — and their price is not
duplicated anywhere: it *derives* from Monetization through the pet's `Pass` key, as the type comment
on `src/shared/Config/Pets.luau:39` says ("the price is `Config.Monetization.Passes[Pass].Robux`, as
PetsController shows it").

- Live: Drillbot 129 Robux (`src/shared/Config/Monetization.luau:91-97`), Solar Phoenix 249 Robux
  (`src/shared/Config/Monetization.luau:98-104`). Both are in the store order
  (`src/shared/Config/Monetization.luau:54`). An `Id = 0` means off sale
  (`src/shared/Config/Monetization.luau:7-9`) — never invent ids.
- Grant flow: `PetService:SyncPassPets` gives every owned-pass pet at level 1 and equips it when a
  slot is free (`src/server/Services/PetService.luau:139-161`), called once the profile *and* pass
  ownership resolve on join, and again on every purchase
  (`src/server/Services/PetService.luau:292-310`, signals at
  `src/server/Services/MonetizationService.luau:75-76`). Ownership check is `HasPass`
  (`:112-115` on that file).
- Client display reads the same table: an unfound premium card shows "A game pass pet: R$ N, a fixed
  price" (`src/client/Controllers/PetsController.luau:140-142`), the gold action button reads "GET
  FOR R$ N" or "NOT ON SALE YET" (`src/client/Controllers/PetsController.luau:353,359-361`), and the
  click prompts the game pass by id (`:405-407`). `tests/Pets.spec.luau:80-89` pins this flow so no
  hard-coded price can creep back in.
- Being paid does not make them random or egg drops, and their perks stay ahead of every free pet at
  both endpoints — both pinned (`tests/Pets.spec.luau:287-310`). The full pass/product catalogue lives
  in [monetization.md](monetization.md).

## Menus and hatch UI (pointers)

- The Pets menu has MY PETS / PET INDEX / BOOSTS tabs (BOOSTS: every role with your capped total, the cap, what it does and the pets giving it, from `PetsLayout.boostRows`), drawn on the Gear Shop's cartoon-light frame on roomy
  windows and via `Shared.PetsLayout` + MenuFit on small ones
  (`src/client/Controllers/PetsController.luau:1-5,64-65`); a missing pet's card says which eggs can
  drop it and lists that egg's odds for the rarity (`:143-145`). Menu rebuild/layout workflow is in
  [native-ui.md](native-ui.md).
- The hatch reveal is its own menu (`src/client/NativeMenus/Hatch.luau:1-13`): queued client-side so
  it can't hold gameplay input for more than two seconds, with SKIP during the wobble, then EQUIP and
  AGAIN — AGAIN hatches the same egg again through the server
  (`src/client/Controllers/HatchController.luau:2,164-166`).
- Followers and previews clone from `ReplicatedStorage.PetModels` per level
  (`src/client/PetModel.luau:15-27`); the server publishes the loadout as `Pets`, `PetLevels` and
  `PetSlots` player attributes (`src/server/Services/PlayerStateService.luau:154-157`) which the
  visuals controller watches (`src/client/Controllers/PetVisualController.luau:85,98-99`).

## What `tests/Pets.spec.luau` already pins

Edit pets and the spec's first to tell you. The load-bearing guarantees, by test:

- exact level-1/level-10 perks for all 14 pets (`:8-43`); linear interpolation and clamping (`:62-78`);
  the 11 role caps and display text (`:45-60`)
- premium pets keep pass keys priced by Monetization (`:80-89`) — see the B0 note above
- slots: the rebirth ladder (`:91-99`), Pet Bond on top (`:101-105`), ExtraPetSlot (`:107-114`)
- miner-window timestamp validation (`:116-130`); XP overflow, max-level stop (`:132-154`); total-to-
  max inside 8K-30K (`:156-162`)
- bonus summation, single-count and cap behaviour (`:164-203`)
- `clean()` — unknown pets dropped, levels fixed, loadout trimmed to slots, the fourth slot only with
  the product validated, pity counts repaired (`:205-242`)
- catalog integrity: unique ids, 14 pets, per-rarity perk counts (`:244-273`)
- every egg's odds sum to 100 and name rarities that have pets; costs and pity positive (`:275-285`)
- paid pets never in eggs and stronger than free pets at shared roles (`:287-310`); level-10 strength
  monotone in rarity (`:312-330`)
- roll bands, deterministic catalog picks, the meteor/crystal costs-odds-pity pin, and duplicate copies (`copies`, `outCount`, clean never puts out more copies than owned)
  (`:332-369`); the pity guarantee and reset (`:371-381`); a 20,000-hatch simulation with no drought
  past pity and odds within ±3 pts (`:383-402`); Solar Phoenix's exact 50→100% miner (`:404-409`)

Note for egg edits: the per-egg cost/odds pin (`:343-369`, "both eggs…") predates the Aurora Egg and
covers only meteorEgg/crystalEgg — the generic tests (`:275-285`) are what watch Aurora.

## Related

- Shard income, bar prices and the sale multiplier chain: [economy.md](economy.md)
- Passes and products (Pet Max, Extra Pet Slot, the two pet passes): [monetization.md](monetization.md)
- Service/signal architecture: [architecture.md](architecture.md)
- Authored models: [pet-models.md](../art-pipeline/pet-models.md) and [blender-asset-briefs.md](../art-pipeline/blender-asset-briefs.md)
