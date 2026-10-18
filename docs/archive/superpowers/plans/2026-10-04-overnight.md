# MeteorShift overnight implementation plan

> For agentic workers: use the executing-plans and parallel-agents skills. The root worker coordinates Studio, integration, commits and pushes; workers have disjoint source ownership.

Goal: deliver the full pet perk makeover, deterministic purchases, authored pet visuals, Studio verification and remaining audits on `job-for-tomorrow`.

Architecture: retain Knit services as the authority and Fusion menus as views. Put arithmetic in pure Shared modules with specs; keep the authored world and pet models in the saved place with binary exports. Loadout attributes drive bounded local pet rendering.

Tech stack: Roblox Studio, Rojo 7.6, strict Luau, Knit, Fusion, Git.

Spec: the complete master prompt is `docs/master-prompt.md`; the user-supplied attachment `goal-objective.md` adds permission to proceed and confirms the halved pet prices.

## Global constraints

- Work only on `job-for-tomorrow`; commit finished parts and push to origin. No PR and no publishing.
- No Robux randomness, shards, eggs, odds changes or random rewards. Monetization IDs remain zero.
- Preserve pet IDs, names, rarity, colours, blurbs, egg/pity/duplicate rules, and all art prose.
- The server validates/throttles requests; tests are never skipped to obtain green.
- No new scratch files in the repository or `.tmp`. Saved places contain no profile-mutating QA fixtures.
- Do not change live player DataStores. Runtime verification uses explicitly isolated Studio memory profiles, with the opt-in cleared before saving.

## Review focus

- A saved fourth equipped pet survives loading until the extra-slot entitlement is known, then the validated slot count is enforced.
- A receipt retry after a failed save grants once; concurrent receipt delivery cannot duplicate grants.
- Sprint restores its own adjustment when removed and preserves independently changed WalkSpeed values.
- Vault capacity agrees across deposits, auto-deposit, State, live simulation and offline catch-up.
- Phone menus preserve readable content and 44 px controls; missing models and leaving players never leak visual instances.

## 1. Baseline and cleanup

- [x] Inspect branch, repository, objective and Studio.
- [x] Run a fresh Studio baseline: 267 passed, 0 failed. Earlier stale-session runs were 255/2 and 265/2.
- [x] Remove `ServerScriptService.Script`, a saved `HUD_QA` join fixture granting bars/cash/shards/rebirths.
- [x] Verify the initial code sync and save/reopen the cleaned place: Save Output 07:26:49; later 137-source captured manifest matched. Final save after the new HUD and clearing DevMemoryStore remains in the completion audit.

## 2. Pet rules and integration (Part A)

- [x] Write exact endpoint/cap/rarity/egg/pity/clean/arithmetic specs, observe red, implement Config.Pets and Shared.Pets, observe green.
- [x] Apply `Pets.oreYield` to validated player hits; `Pets.playerXp` in AddXp; `Pets.coreShards` once to the cracked-core payout; `Pets.vaultCapacity` through optional Refining capacity multipliers.
- [x] Publish all eleven bonuses and loadout attributes; apply server sprint without fighting other speed changes.
- [x] Replace single-role pet cards with every perk at the owned level and rarity accents.
- [x] Preserve artwork sentences while updating perk and price documentation; run Studio specs, review and commit/push Part A.

Interfaces: `Pets.perksOf(def, level)` returns ordered `{role, value}` entries; `Pets.slots(rebirths, extraSlot?)` and `Pets.clean(saved, rebirths, extraSlot?)` take an optional boolean. Arithmetic helpers take a base amount and a capped role bonus. `Refining.hopperCapacity`/`collectorCapacity` accept an optional capacity multiplier; `Refining.run` takes it as the fourth argument.

## 3. Deterministic purchases (Part B)

- [x] Write cash formula, boost, treat/feast, idempotency and save-failure specs; observe red and implement Shared.Purchases.
- [x] Add the seven requested products and ExtraPetSlot pass, all IDs zero, intended prices and honest descriptions.
- [x] Extend the receipt grant/save/acknowledgement flow and Studio DevProduct hook; preserve CallMeteor and Overclock.
- [x] Reconcile/count down oreBoostLeft online, use max(pass, timed boost), disable OreRush for pass owners, implement cosmetic session supporter effects.
- [x] Verify off-sale store states and pure receipt-retry/grant rules; exercise Pet Treat's 1,500 XP through DevProduct; update docs and commit/push Part B. Live Marketplace receipts remain unverified because all IDs are zero.

Assumption: after Frost clearance, cash-pack average price uses meteor weights multiplied by each ore's clearance; until then it uses iron only. The ceiling takes precedence over the floor when needed. Receipt IDs are retained permanently; previously discarded historical IDs cannot be reconstructed.

## 4. Visuals and authored models (Part C)

- [x] Implement tested visual budget/loadout/hatch timing helpers, PetVisualController and HatchController.
- [x] Author all fourteen pets from the exact art prose with deterministic Edit-only generator. Validate both looks, hierarchy, part limits and disabled collisions before replacing the folder.
- [x] Execute generator in Edit, save and export `assets/PetModels.rbxm` (52,373 bytes); document conventions in `docs/pet-models.md`; all 14 × 2 clone checks passed.
- [x] Verify pure loadout/culling/missing-asset/40-model/hatch-timing rules and review working/level-10 code; observe duplicate name/perks after the Sibling fix; commit/push Part C. Full runtime and cross-client coverage remain in Part D.

Interfaces: Player `Pets`, `PetLevels`, `PetSlots`; `PetService.Client.Working(userId, role, targetPosition?)` with an optional world destination on working events; client `ReduceEffects` and `HatchOpen`. `Level10` contains a complete replacement geometry set, included in the saved part count.

## 5. Studio acceptance (Part D)

- [x] Fresh full runner after the three UI layering fixes: 347/0; after the landscape layout: 349/0, including HudLayout 30/0 and two added regressions. The captured 137-source manifest matched after reopen. The subsequently requested simulator-style GUI still requires another final run/source check.
- [ ] Partial runtime acceptance: Iron cracked in 83 seconds, 23 shards, level 4; miner hopper ore, DevProduct Pet Treat and duplicate Scrap Sparrow overlay were observed. Complete the remaining gameplay/perk/clearance/menu matrix and record the limits in the report.
- [ ] Partial phone/rejoin acceptance: all menus inspected at 320×568 and 390×844 before the latest changes. The native 844×390 landscape HUD preview matches its stack/top-right controls/bottom strip and clears the joystick. Final menus after the simulator-style GUI and remaining leave/rejoin/cross-client coverage are not yet recorded as complete.
- [x] Edit structural and fixture scan: 94-part shared refinery grounded on the Plaza, all 14 pet models structurally valid, and the one scanned Script contained no profile-mutating fixture.
- [ ] Stop Play, remove test-created runtime state, clear the currently true saved DevMemoryStore opt-in, and save without publishing. Record final Save UI evidence.
- [x] Push the established A–C work/verification fixes: 0c6bae2 pushed successfully. Final leftovers/documentation push remains pending.

## 6. Leftovers (Part E, after A–D)

- [x] A13: test 320×568 movement/jump clearance and keep foundry toggle 44 px; initial implementation included in the passing runner. New user layout steering follows below.
- [x] A14: pixel/scroll Index with readable content and 44 px targets; independent IndexLayout run 6/0, included in the full green suite.
- [x] A17: implement meteor reason, kept ore, actual shards and XP outcome copy/specs. Final new-layout notification display remains runtime acceptance.
- [x] A18: implement reduced shake/effects settings and effect hooks; include in the passing full suite. Final settings interaction remains phone acceptance.
- [x] A20: distinct DataStore unavailable/foreign-lock/transient messages with unchanged lock guarantees; included in the full green suite.
- [x] Model equipped Drillbot level 5 in Shared.Pacing and report the honest 45→58 minute first-rebirth change without retuning; specs passed in the full green suite. Five free rebirths measured at 45/72/98/124/150 minutes.
- [x] Implement the supplied landscape mobile HUD reference (Gear/Index/Rebirth stack left, Settings/Store upper right, wallet/production/bars/backpack strip bottom); sync, pass the fresh runner 349/0 and HudLayout 30/0, and verify the native 844×390 HUD preview. Full menu acceptance remains in Part D.
- [ ] Latest user steering: adapt the simulator-style screenshot to MeteorShift with colourful outlined tiles, deep navy/cyan/amber/lime and white stroked Fredoka headings across shared UI/HudView/Shop/Refinery/Tutorial. Preserve game features, then sync, run final checks and inspect the remaining menus/phone sizes.

## Completion audit

- [ ] Final documentation check after the new GUI style: pet/purchase/balance/model docs and current README are updated; all 17 monetization IDs are zero. Recheck wording against the completed user-directed layout and styling.
- [ ] All changed Luau, docs and model export committed and pushed; no PR or publish.
- [x] Draft `docs/overnight-report.md` records established evidence, assumptions, verification limits and all 8 passes/9 products with exact configured prices; unspecified legacy prices are owner decisions.
- [ ] Replace the report's final layout/test/runtime/save/push pending fields with observed evidence before completion.
- [ ] Compare each master-prompt requirement with authoritative evidence before marking the goal complete.

Interpretations: compare rarity strength only where a role is present. Paid pets can tie an earned pet at level 1 (the supplied Drillbot/Jet Wisp swift values both start at 8%); they exceed earned pets at level 10 for their roles. Existing production upgrades remain in the Refinery, reflecting the user's later explicit UI request.
