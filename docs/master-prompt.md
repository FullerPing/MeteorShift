# MeteorShift overnight worker: master prompt

You are an autonomous engineer working alone overnight in the repository `FullerPing/MeteorShift` (Roblox, Rojo + Luau, Knit services and controllers, Fusion UI). Nobody will answer questions, so make the sensible choice, write it down in the docs, and keep going. Work on branch `job-for-tomorrow` only. Commit small and often with clear messages, push after each finished part (`git push -u origin job-for-tomorrow`, retry on network errors with backoff), and never open a pull request. Do not touch `.rbxl` or `.rbxm` place files, do not publish anything, and do not add scratch files to the repo (put them in a temp directory outside it).

## 0. Orient first (30 minutes at most)

1. Read `README.md`, `docs/balance.md`, `docs/pets.md`, `audit.md` (sections 1 to 3 and the index), `src/shared/Config/Pets.luau`, `src/shared/Pets.luau`, `src/server/Services/PetService.luau`, `src/server/Services/PlayerStateService.luau`, `src/server/Services/NodeService.luau`, `src/server/Services/MonetizationService.luau`, `src/shared/Config/Monetization.luau`, `src/client/Controllers/ShopController.luau`, `src/client/Controllers/StoreController.luau`, `src/client/Controllers/HUDController.luau`, `tests/Pets.spec.luau`.
2. Verification tooling: Studio is not available. Use Lune. If `lune` is not on the PATH, download the Linux release of Lune v0.10.5 from `https://github.com/lune-org/lune/releases` and unzip it outside the repo. `tests/Runner.luau` runs every `tests/*.spec.luau`; write a small Lune script outside the repo that loads modules with a virtual Instance harness (the specs only need `t.shared` to resolve `src/shared` and the other `src` folders as modules; `Server.Lib` modules are covered the same way). Eight specs fail under Lune only because they need Roblox types (`LandingFX` x5, `MineralIndex` x1, `PlotPresentation` and `RefineryQueue` fail to load). Those eight are expected; everything else must pass before every commit. Also syntax-check every `.luau` file you change (Lune can parse them with `luau.load`).
3. Baseline: note the current number of passing specs before you change anything. It must never go down except where you deliberately replace a test, and then it must go back up.

## 1. Rules that must never be broken

- **No paid randomness.** Nothing bought with Robux may change odds or roll anything. Eggs cost Core Shards, which are earned only in play. Never sell shards, eggs or hatches for Robux, and never make a product that converts Robux into shards. Odds stay shown on the egg cards.
- Robux items are fixed price and specific. Never random.
- No change to mineral index odds from any pet or product.
- The server is the authority: validate every client request, throttle every remote, never trust a number from the client.
- Strict Luau (`--!strict`). Match the surrounding code's style, comment density, tabs and naming.
- Every pure rule gets a spec. Update the README and `docs/` when behaviour changes.
- Never skip or disable a test to get green. If a spec fails because the design deliberately changed, rewrite it to assert the new design.

## 2. Part A: pets makeover (the main job)

Keep every pet's id, name, rarity, colour, blurb text and the way pets are obtained (shard eggs, plus the two game-pass pets). Change what they DO. The old model had five roles and one perk per pet. The new model gives every pet explicit perks with exact level 1 and level 10 values, in a larger set of perk types.

### A1. Perk types ("roles") and caps

The perks of equipped pets add up per role, to the role's cap. Values are fractions (0.05 is 5%).

| Role | Effect | Cap |
|---|---|---|
| miner | Auto-mines for you at this share of your pickaxe's Mining Power and ore. Same rules as today: only while you swung in the last `MinerWindow` seconds, ore goes straight to the hopper, never counts for the podium, core rewards, mineral drops or meteor size. | 1.00 |
| hauler | Moves this share of your backpack capacity to the hopper every second (current behaviour). | 0.06 |
| pack | Backpack capacity +share (current behaviour). | 0.60 |
| swift | Swing time reduced by the share (current behaviour). | 0.30 |
| merchant | Bar sales +share (current behaviour, via `EconomyService`). | 0.45 |
| yield | NEW. Ore per hit +share (multiplies the ore quantity of every validated hit; applies in `NodeService` next to the pass multiplier). | 0.40 |
| sprint | NEW. Walk speed +share, applied server-side to the character's Humanoid (base 16) on spawn and whenever the equipped pets change. Never fight other WalkSpeed changes: compute from the base value. | 0.30 |
| vault | NEW. Hopper capacity AND collection post capacity +share (live and in the offline catch-up). | 1.00 |
| crit | NEW. Adds to the pickaxe's crit chance (absolute, so 0.04 is +4 percentage points). Applied in `PlayerStateService:GetPickaxe`. | 0.15 |
| scholar | NEW. Player XP gained +share (applied in `LevelService:AddXp`, which is the single place XP is added). | 0.60 |
| shards | NEW. Core shards from a cracked core +share, rounded down, applied where shards are awarded (`RewardService:Finish`). | 0.30 |

Each role has a display name and one line of text with a `%s` for the value, shown in the shop. Move per-role min and max out of the role table (they are now per pet).

### A2. Per-pet perks

Replace `Role`, `Power` and `Range` on each pet with `Perks = { { Role = "...", Min = x, Max = y }, ... }`: Min at pet level 1, Max at level 10, linear in between (`Pets.perk`). The first perk is the pet's main perk. Keep `Id`, `Name`, `Rarity`, `Color`, `Blurb`, `Pass`, `Robux`.

| Pet | Rarity | Perks (level 1 to level 10) |
|---|---|---|
| Pebble Pup | common | yield 5% to 10% |
| Scrap Sparrow | common | scholar 8% to 16% |
| Pack Mule | uncommon | pack 15% to 30% |
| Spark Hare | uncommon | swift 5% to 12% |
| Jet Wisp | rare | swift 8% to 18%; sprint 6% to 15% |
| Cargo Mole | rare | hauler 1.2% to 3%; pack 8% to 18% |
| Coin Magpie | rare | merchant 8% to 20% |
| Granite Golem | rare | pack 20% to 38%; vault 25% to 60% |
| Crystal Stag | epic | crit 4% to 10%; miner 12% to 25% |
| Aurora Owl | epic | merchant 12% to 28%; shards 6% to 15% |
| Lode Wyrm | epic | hauler 1.5% to 3.75%; vault 35% to 80% |
| Meteor Drake | legendary | miner 22% to 36%; yield 8% to 18%; shards 8% to 20% |
| Drillbot (game pass, 199 Robux) | premium | miner 25% to 40%; swift 8% to 20%; yield 10% to 20% |
| Solar Phoenix (game pass, 399 Robux) | premium | miner 50% to 100%; merchant 15% to 35%; scholar 15% to 35% |

Per rarity the number of perks is: common 1, uncommon 1, rare 1 or 2, epic 2, legendary 3, premium 3. The strongest level 10 value per role must not decrease as rarity goes up (checked by a spec; the numbers above satisfy it). Premium pets are always the strongest for their roles and must look and feel best. The Solar Phoenix keeps its 50% to 100% miner perk exactly.

### A3. Code changes

- `Config.Pets`: new role table (name, text, cap), new `Perks` per pet, new types. Update the header comment.
- `Shared.Pets`: `perk(role, level)` stays for tests but pets use `perksOf(def, level)` returning `{ {role, value} }`; `bonuses(saved)` returns one total per role for all 11 roles, each capped; keep `slots`, `xpToNext`, `addXp`, `clean`, `roll`, eggs and pity exactly as they work today. Remove `Power` and `Range`. `Bonuses` type has all 11 keys.
- Apply every new role where listed in A1: `NodeService` (yield, and the miner pet already exists), `PlayerStateService` (`GetPickaxe` for crit and swift, `GetCapacity` for pack, `GetHopperCapacity` and the collection post capacity for vault, State must publish all bonuses), `LevelService` (scholar), `RewardService` (shards), `EconomyService` (merchant), a new small handler for sprint (a `PetService` method that sets Humanoid WalkSpeed from base on `CharacterAdded` and on equip changes). Refinery capacity checks live in `Server.Lib.Refining` and read station levels only; add an optional capacity multiplier to the pure functions or have callers scale the result, and keep the offline catch-up in sync (`RefineryService`). Keep every existing spec passing.
- Shop (`ShopController`): each pet card lists all of the pet's perks with their current values (level of the pet), coloured by rarity (`Config.Pets.Rarities[...].Color` as the accent). Egg cards unchanged. No layout regressions on phones.
- Specs: rewrite `tests/Pets.spec.luau` for the new model: every pet has the right perk counts for its rarity; the table above is asserted exactly for level 1 and level 10; per-role cap behaviour; monotonic strength by rarity per role; paid pets best; bonuses add to caps; clean/migration still repairs saved data (a saved pet keeps its level); roll and pity specs unchanged. Add specs for the pure parts of yield, scholar, shards and vault arithmetic.
- Profile: no schema change is needed (pets store id, level, xp). Do not change the profile version unless required.
- Docs: rewrite `docs/pets.md` with the new perk lists (keep all art descriptions word for word and add the perk lines), and update the README Pets section and `docs/balance.md` (note that pets are not in the pacing model and list the largest effects).

## 3. Part B: micro-purchases (Robux)

Add repeatable developer products and one extra pass. Every one has `Id = 0` in `Config.Monetization` (not on sale until the owner fills in ids from the Creator Dashboard), a clear name and description, and is listed in `StoreController` like the existing ones (Id 0 shows "Not on sale yet"). Extend the existing `MonetizationService` receipt flow. Receipts must stay idempotent (the processed `PurchaseId` list in the profile); grant, save the profile (`DataService:Save`) and only then return `PurchaseGranted`. If the profile is not loaded or the save fails return `NotProcessedYet`. Do not break `CallMeteor` or `Overclock`.

5 to 20 Robux (developer products):

| Key | Price | What it does |
|---|---|---|
| TipJar | 5 | A thank-you only: a short confetti burst, a toast, and a "Supporter" tag for the session next to the VIP tag area. No gameplay effect. |
| PocketChange | 10 | Cash worth 10 minutes of your current line income (see formula below). |
| PetTreat | 15 | 1,500 XP to each equipped pet. |
| MiniOverclock | 19 | Refinery x2 for 10 minutes of play time (adds 600 seconds to the existing `overclockLeft`; stacks with Overclock like Overclock stacks with itself). |

20 to 50 Robux:

| Key | Price | What it does |
|---|---|---|
| OreRush | 25 | Ore per hit x2 for 30 minutes of play time (new profile field `oreBoostLeft`, counted down while online like `overclockLeft`; does not stack with the 2x Ore pass: the larger multiplier applies; the store disables the button with "You own 2x Ore" for pass owners). |
| PetFeast | 29 | 6,000 XP to each equipped pet. |
| CashBundle | 39 | Cash worth 60 minutes of your current line income (formula below). |
| ExtraPetSlot | 49 | A game pass: one extra pet slot, permanent (`Pets.slots` gains a `+1` when the pass is owned; the slot cap rises by one for owners; shop text says so). |

Cash formula (pure function in `Shared`, with a spec): `grant = clamp(minutes * 60 * barsPerSecond * averageBarPrice * saleMultiplier, floor, ceiling)` where `barsPerSecond` is the line rate (`Refining.lineRate`), `averageBarPrice` is `Home.BarPrices.iron` for a player who has not yet cleared Frost and the ore-weighted average otherwise (use Shared.Levels clearance and the meteor weights), `floor` is $2,000 for PocketChange and $20,000 for CashBundle, and the ceiling is 3% (PocketChange) or 8% (CashBundle) of the player's current rebirth cost (`Shared.Rebirth.cost`). A cash pack must never buy a rebirth by itself.

Rules: nothing here is random; none of it changes mineral odds; the pass and product ids stay 0 until the owner sets them; add Studio-only helpers where the existing dev hooks live (`DevPasses` attribute already exists for passes; add a `DevProduct` BindableFunction that runs the grant path without a receipt). Specs for every pure rule and for the idempotency of the grant path (use the pattern the existing monetization specs use, or add a small fake). Update the README monetization section and `Config.Monetization` header comment, and note the new products in `docs/balance.md`.

## 4. Part C: pet visuals and hatching (code only; the models come later from Studio)

1. **Replicated loadout.** The server sets a Player attribute `Pets` to the comma-separated equipped pet ids and `PetLevels` to matching levels, updated whenever the loadout or a level changes.
2. **`PetVisualController`** (new client controller). For every player in the server render that player's equipped pets near their character, using models from `ReplicatedStorage.PetModels` named by pet id. If a model does not exist, render nothing (no errors, no placeholder). Rules: clone locally (no server cost), unanchored parts set anchored and moved with `PivotTo` each `RenderStepped`, followers trot or hover at fixed offsets (slot 1 behind-left, slot 2 behind-right, slot 3 above-left shoulder), smooth with lerp, cap at 3 pets per player (4 with the extra slot pass), cull pets of players farther than 150 studs, never create more than 40 pet models in total, destroy on leave or unequip. Tint by the `PetColor` attribute if the model has parts named `Body`. If the model has an attribute `MaxLevelLook` swap in the child folder `Level10` at level 10 when it exists. Honour the "Reduce effects" setting from Part D item 4 if it exists by then; until then no special handling is needed.
3. **Hatch overlay.** Replace the toast for hatching with a small client overlay (`PetHatchController` or inside the shop controller): a 1.5 second egg wobble, a flash in the rarity colour, the pet name and perks, a "Duplicate: +400 XP" line when it was a duplicate. Escape or tap closes it, 44 px minimum touch targets, no blocking for more than 2 seconds, queue multiple hatches. Pure UI plumbing only; the server result is already authoritative.
4. Write `docs/pet-models.md`: a short technical brief for whoever builds the models in Studio (folder `ReplicatedStorage.PetModels`, one Model per pet id, `PrimaryPart`, `Body` part, optional `Level10` folder, part budget, no scripts, no colliders). Do not duplicate the art descriptions; link to `docs/pets.md`.

## 5. Part D: leftover fixes, only after A, B and C are finished and pushed

Do these in order and stop when time runs out. Each is small and safe:

1. Audit A13 (`audit.md`): the 320 x 568 portrait HUD overlap. Add the viewport to `tests/HudLayout.spec.luau`, assert movement and jump clearance, and adjust `Shared.HudLayout` so lower-priority cards move or hide instead of overlapping, keeping a 44 px minimum for the foundry toggle.
2. Audit A14: make the Index panel pixel-based and scrolling like the Shop (readable text, 44 px targets), keeping its behaviour.
3. Audit A17: meteor notifications should say the reason and the economic outcome (cooled vs cracked, shards earned, XP earned).
4. Audit A18: add "Reduce camera shake" and "Reduce effects" toggles to the HUD settings panel (stored as player attributes like the other settings), honoured by every camera shake and by pet and hatch effects.
5. Audit A20 (partial): clearer Kick messages that distinguish an unavailable DataStore from a save still open on another server, without weakening the session lock.
6. Add pets to `Shared.Pacing`: model an equipped miner pet (use the Drillbot at level 5 as the assumption) and report in `docs/balance.md` how first-rebirth time changes; do not retune other numbers.

## 6. Definition of done

- All specs except the eight expected Lune-only failures pass, and the number of passing specs is higher than the baseline.
- Every changed `.luau` file parses.
- `README.md`, `docs/pets.md`, `docs/balance.md`, `docs/pet-models.md` and `Config` header comments describe the final behaviour.
- Nothing in the repo is random-for-Robux. `Config.Monetization` ids are all 0.
- Commits are pushed to `origin/job-for-tomorrow`. Finish by writing `docs/overnight-report.md` listing what was done, what was skipped and why, every assumption you made, anything you could not test without Studio, and the exact list of Creator Dashboard items the owner must create (passes and developer products with the intended Robux prices).
