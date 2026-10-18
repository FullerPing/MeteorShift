# MeteorShift overnight worker: master prompt

You are the engineer who already knows this project (Roblox, Rojo + Luau, Knit, Fusion) and has full access to Roblox Studio and the repository. You are working alone overnight on `FullerPing/MeteorShift`, branch `job-for-tomorrow` only. Nobody will answer questions: pick the sensible option, write it down in the docs, keep going. Commit small and often, push after each finished part (`git push -u origin job-for-tomorrow`, retry on network errors), never open a pull request, never publish the place, and keep scratch files out of the repo (`.tmp/` is for nothing new).

## 0. Catch up first (20 minutes at most)

You have not seen the newest changes. Run `git pull origin job-for-tomorrow`, then `git log --oneline c0ba585..HEAD` and read the diff of each commit plus these files: `README.md`, `docs/balance.md`, `docs/pets.md`, `audit.md`. The newest changes, in order:

1. **Player level (XP)**: `src/shared/Config/Levels.luau`, `src/shared/Levels.luau`, `src/server/Services/LevelService.luau`. XP arrives per validated crust hit, core hit and a cracked-core bonus (not as a lump after a meteor). Level survives rebirth, shown as "LV n" with an XP bar in the HUD wallet card, and gates evolving to tier 5 and up.
2. **Refinery clearance**: each ore refines at full speed from a level (iron 1, frost 4, crystal 6) and at 0.35 per level short under it (`Levels.clearance`, applied in `Server.Lib.Refining.run`). The old under-tier meteor rules and the 25% eligibility rule are gone: every meteor type comes up by weight and everyone mines every type. `Shared.Pacing` models it.
3. **Gear shop**: one screen per gear (Pickaxe, Backpack) with +1 and +10 buy buttons (`Gear.bulk`) and an evolve banner. Pets and the old Production cards remain carousels.
4. **Audit fixes** in `DataService` (per-profile write ordering, per-save abort flag, live servers fail closed with no DataStore) and `NodeService` (the server requires an alive humanoid holding the pickaxe). Every menu now blocks mining. The welcome-back popup has a 44 px button and closes on Escape.
5. **Pets**: 14 pets in six rarities (`Config.Pets`, `Shared.Pets`, `PetService`), shard eggs with shown odds and pity (Meteor Egg 30 shards, Crystal Egg 120), duplicate pets give 400 XP, two Robux game-pass pets (Drillbot 199, Solar Phoenix 399, ids still 0 in `Config.Monetization`). Art descriptions are in `docs/pets.md`.

Then check the repo and Studio agree: sync the code into Studio the way you normally do, open the place, and run the project's test runner in Studio (`ServerStorage.Tests`, see `tests/Runner.luau`) to get a baseline. Note how many pass and which fail before you change anything. Fix anything that is only broken by the new commits being out of sync with the place.

## 1. Rules that must never be broken

- **No paid randomness.** Nothing bought with Robux may roll anything or change odds. Eggs cost Core Shards, which are earned only in play. Never sell shards, eggs or hatches, and never make a product that turns Robux into shards. Odds stay visible on the egg cards.
- Robux items are fixed price and specific. Mineral index odds are never changed by a pet or product.
- The server is the authority: validate and throttle every remote, never trust client numbers.
- `--!strict` Luau, match the surrounding style (tabs, comment density, naming). Every pure rule gets a spec. Update the README and `docs/` whenever behaviour changes.
- Never skip or disable a test to get green. If a spec fails because the design deliberately changed, rewrite it to assert the new design.
- Do not publish, do not change player data stores, and never leave Studio-only test fixtures (scripts that change cash, shards, rebirths or bars) inside the saved place. Audit item A01 is exactly that bug: search every `Script` in `ServerScriptService`, `Workspace` and `ServerStorage` for a QA fixture that mutates profiles on join and remove it.

## 2. Part A: pets makeover (the main job)

Keep every pet's id, name, rarity, colour, blurb and the way pets are obtained. Change what they DO. The old model had five roles and one perk per pet; the new model gives every pet explicit perks with exact level 1 and level 10 values and more perk types.

### A1. Perk types ("roles") and caps

Equipped pets' perks add per role, to the role's cap. Values are fractions (0.05 is 5%).

| Role | Effect | Cap |
|---|---|---|
| miner | Auto-mines at this share of your pickaxe's Mining Power and ore. Same rules as today (only while you swung in the last `MinerWindow` seconds, ore straight to the hopper, never counts for the podium, core rewards, mineral drops or meteor size). | 1.00 |
| hauler | Moves this share of your backpack capacity to the hopper every second (current behaviour). | 0.06 |
| pack | Backpack capacity +share (current). | 0.60 |
| swift | Swing time reduced by the share (current). | 0.30 |
| merchant | Bar sales +share (current, via `EconomyService`). | 0.45 |
| yield | NEW. Ore per hit +share (multiplies the ore of every validated hit, in `NodeService` next to the pass multiplier). | 0.40 |
| sprint | NEW. Walk speed +share, applied server-side to the character's Humanoid from the base 16 on spawn and whenever the equipped pets change; never fight other WalkSpeed changes. | 0.30 |
| vault | NEW. Hopper capacity AND collection post capacity +share, live and in the offline catch-up. | 1.00 |
| crit | NEW. Adds to the pickaxe's crit chance (absolute: 0.04 is +4 points), in `PlayerStateService:GetPickaxe`. | 0.15 |
| scholar | NEW. Player XP gained +share, in `LevelService:AddXp` (the single place XP is added). | 0.60 |
| shards | NEW. Core shards from a cracked core +share, rounded down, where shards are awarded (`RewardService:Finish`). | 0.30 |

Each role has a display name and one text line with `%s` for the value, shown in the shop. Per-role min and max leave the role table (they are now per pet).

### A2. Per-pet perks

Replace `Role`, `Power` and `Range` on each pet with `Perks = { { Role = "...", Min = x, Max = y } }`: Min at pet level 1, Max at level 10, linear between. The first perk is the main one. Keep `Id`, `Name`, `Rarity`, `Color`, `Blurb`, `Pass`, `Robux`.

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
| Drillbot (pass, 199 Robux) | premium | miner 25% to 40%; swift 8% to 20%; yield 10% to 20% |
| Solar Phoenix (pass, 399 Robux) | premium | miner 50% to 100%; merchant 15% to 35%; scholar 15% to 35% |

Perks per rarity: common 1, uncommon 1, rare 1 or 2, epic 2, legendary 3, premium 3. The strongest level 10 value per role must not fall as rarity rises (a spec checks it; these numbers satisfy it). Paid pets are always the strongest for their roles. The Solar Phoenix keeps its 50% to 100% miner perk exactly.

### A3. Code

- `Config.Pets`: new role table (name, text, cap), `Perks` per pet, new types, updated header.
- `Shared.Pets`: add `perksOf(def, level)` returning `{ {role, value} }`; `bonuses(saved)` returns all 11 roles, each capped; `perk(role, level)` may stay for tests. Keep `slots`, `xpToNext`, `addXp`, `clean`, `roll`, eggs and pity exactly as they work. Remove `Power` and `Range`.
- Apply each new role where A1 says. For vault, `Server.Lib.Refining` reads station levels only: add an optional capacity multiplier or scale in callers, and keep `RefineryService` offline catch-up consistent. State must publish all bonuses.
- Shop (`ShopController`): each pet card lists all its perks with current values at the pet's level, with the rarity colour as accent. Egg cards unchanged. No phone layout regressions.
- Specs: rewrite `tests/Pets.spec.luau` for the new model (perk counts per rarity, the table above asserted exactly at level 1 and 10, caps, monotonic strength by rarity per role, paid pets best, clean still repairs saves, roll and pity unchanged) and add specs for the pure arithmetic of yield, scholar, shards and vault.
- No profile schema change is needed. Update `docs/pets.md` (keep all art descriptions word for word, add perk lines), README and `docs/balance.md`.

## 3. Part B: micro-purchases

Add repeatable developer products and one pass, all with `Id = 0` in `Config.Monetization` (not on sale until the owner fills ids), clear names and descriptions, listed in `StoreController` like the others. Extend the existing receipt flow: idempotent by processed `PurchaseId`, grant, `DataService:Save`, and only then `PurchaseGranted`; if the profile is missing or the save fails return `NotProcessedYet`. Do not break `CallMeteor` or `Overclock`.

5 to 20 Robux:

| Key | Price | What it does |
|---|---|---|
| TipJar | 5 | Thank-you only: confetti, a toast and a "Supporter" tag for the session. No gameplay effect. |
| PocketChange | 10 | Cash worth 10 minutes of current line income (formula below). |
| PetTreat | 15 | 1,500 XP to each equipped pet. |
| MiniOverclock | 19 | Refinery x2 for 10 minutes of play time (adds 600 s to `overclockLeft`). |

20 to 50 Robux:

| Key | Price | What it does |
|---|---|---|
| OreRush | 25 | Ore per hit x2 for 30 minutes of play time (new profile field `oreBoostLeft`, counted down online like `overclockLeft`; does not stack with the 2x Ore pass, the larger multiplier applies; the store disables it for pass owners with "You own 2x Ore"). |
| PetFeast | 29 | 6,000 XP to each equipped pet. |
| CashBundle | 39 | Cash worth 60 minutes of current line income. |
| ExtraPetSlot | 49 | Game pass: one extra pet slot, permanent (`Pets.slots` +1 for owners; the store and shop say so). |

Cash formula (pure function in `Shared`, with a spec): `grant = clamp(minutes * 60 * barsPerSecond * averageBarPrice * saleMultiplier, floor, ceiling)`; `barsPerSecond` is `Refining.lineRate`; `averageBarPrice` is the iron price until Frost is cleared and the ore-weighted average otherwise (Levels clearance and meteor weights); floor $2,000 (PocketChange) or $20,000 (CashBundle); ceiling 3% or 8% of the current rebirth cost. A cash pack can never buy a rebirth by itself.

Add a Studio-only `DevProduct` BindableFunction next to the existing dev hooks that runs the grant path without a receipt. Specs for every pure rule and for grant idempotency. Update README and the `Config.Monetization` header.

## 4. Part C: pet visuals (code and models, you have Studio)

1. **Replicated loadout.** The server sets Player attributes `Pets` (comma-separated equipped ids) and `PetLevels` (matching levels), updated on every loadout or level change.
2. **`PetVisualController`** (new client controller). For every player, render their equipped pets near their character from `ReplicatedStorage.PetModels` (one Model per pet id). A missing model renders nothing and never errors. Clone locally, anchored parts moved with `PivotTo` each `RenderStepped`, offsets: slot 1 behind-left, slot 2 behind-right, slot 3 above the shoulder, smoothed, ground pets trot and flyers hover, working animation when their perk fires, at most 3 pets per player (4 with the extra slot pass), cull beyond 150 studs, never more than 40 pet models in total, destroy on leave or unequip. Tint parts named `Body` from the `PetColor` attribute when present, and swap in a child folder `Level10` at pet level 10 when it exists. Honour "Reduce effects" (Part E item 4) once it exists.
3. **Hatch overlay.** Replace the hatch toast with a client overlay: 1.5 s egg wobble, a flash in the rarity colour, pet name and perks, "Duplicate: +400 XP" when applicable. Escape or tap closes it, 44 px touch targets, never blocks more than 2 s, queue multiple hatches.
4. **Build the 14 pet models in Studio** into `ReplicatedStorage.PetModels`, following `docs/pets.md` exactly (the art descriptions are the brief): one Model per pet id, `PrimaryPart`, a `Body` part, a `Level10` folder with the upgraded look, no scripts, no colliders, unanchored, under 300 parts (Legendary and Premium up to 400), rarer pets visibly better (see the rarity ladder in the doc), Premium pets best, lights and particle emitters only on Rare and above. Name parts sensibly so animation can find them (`Head`, `Tail`, `Wings`, `Drill`, `Halo` where they exist). Save the place without publishing and export the folder to `assets/PetModels.rbxm`.
5. Write `docs/pet-models.md`: a short technical brief of the conventions above, linking to `docs/pets.md` instead of repeating the art.

## 5. Part D: Studio verification

Do this after A, B and C are in. Use Play mode with the real server and a client (a local server with 2 players if you can):

- Run the project test runner in Studio; every spec must pass (the eight Lune-only failures do not occur in Studio).
- Play-test and fix what you find: spawn, mine debris, a meteor, crust, core and a crack (XP per hit and the crack bonus, the HUD level bar, level-ups), the refinery (shared model deposit, collect, clearance percentages for each ore at levels 1, 4 and 6), sell, the gear screens (+1 and +10, evolve gating by level), eggs (hatch, pity count, duplicate XP), each pet perk actually working and showing in State, the sprint pet's walk speed, the miner pet (still needs your swing, ore to the hopper), store buttons in "Not on sale yet", the dev product hook, rebirth (level and pets kept), leaving and rejoining (profile load, no errors), and the phone emulator at 320 x 568, 390 x 844 and 844 x 390 for every menu.
- Read the Output window for warnings and errors during all of that and fix their causes.
- Check the QA fixture issue from the rules section.

## 6. Part E: leftover fixes (only after A to D are pushed)

In order, stop when time runs out:

1. Audit A13: the 320 x 568 portrait HUD overlap. Add the viewport to `tests/HudLayout.spec.luau`, assert movement and jump clearance, and adjust `Shared.HudLayout` so lower-priority cards move or hide instead of overlapping, keeping a 44 px foundry toggle.
2. Audit A14: make the Index panel pixel-based and scrolling like the Shop (readable text, 44 px targets).
3. Audit A17: meteor notifications state the reason and the economic outcome (cooled or cracked, shards earned, XP earned).
4. Audit A18: add "Reduce camera shake" and "Reduce effects" toggles to the HUD settings (player attributes like the other settings), honoured by every shake and by pet and hatch effects.
5. Audit A20 (partial): clearer Kick messages for an unavailable DataStore versus a save still open on another server, without weakening the session lock.
6. Add pets to `Shared.Pacing` (model an equipped Drillbot at level 5) and report in `docs/balance.md` how first-rebirth time changes; do not retune other numbers.

## 7. Definition of done

- The Studio test runner passes completely, Play-testing found no unresolved errors, and every changed `.luau` file is committed and pushed to `origin/job-for-tomorrow`.
- README, `docs/pets.md`, `docs/balance.md`, `docs/pet-models.md` and Config header comments describe the final behaviour. Nothing in the repo is random-for-Robux. All `Config.Monetization` ids are 0.
- The place is saved (not published) and `assets/PetModels.rbxm` is exported.
- Finish with `docs/overnight-report.md`: what was done, what was skipped and why, every assumption, anything you could not verify, and the exact list of Creator Dashboard items the owner must create (passes and developer products with the intended Robux prices).
