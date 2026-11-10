# MeteorShift — full game audit (2026-10-20)

This is a blind audit of the code in branch `local-llm-work` at `e9c947d` plus the uncommitted working tree, and of the place open in Studio.
It covers gameplay, server events, remotes and security, scaling, UX, UI, the first-time experience, economy, pacing, monetization and the payer experience.
Nothing in the game was changed.

## How it was done

Each of the three subagents audited one slice, read-only:
- server
- client
- economy, run in the `Shared.Pacing` simulator

The lead audited persistence and receipts, and also:
- ran the spec suite,
- inspected the saved place,
- did a 60 s Play session.

The lead re-read every P0 and P1 in code or checked it in Studio, with these exceptions:
- C4 (boost cap) and C8 (offline income) come from the `Shared.Pacing` model.
- B4 (gamepad) needs a real controller.

| File | Scope | Findings |
|---|---|---|
| [01-server-gameplay-security.md](01-server-gameplay-security.md) | services, remotes, events, exploits, scaling | A1–A18 |
| [02-client-ux-ui.md](02-client-ux-ui.md) | controllers, menus, HUD, FTUE, mobile/console, client perf | B1–B20 |
| [03-economy-pacing-monetization.md](03-economy-pacing-monetization.md) | Config, pacing table, catalogue, payer value, retention | C1–C25 |
| [04-persistence-purchases-runtime.md](04-persistence-purchases-runtime.md) | DataService, receipts, place inventory, Play run, tests | D1–D8 |

## Verdict

**The foundations are solid.**
- Saves, receipts and server validation hold up.
  - Receipts are idempotent and saved before Roblox is told.
  - Saves are serialized.
  - Every remote is typed, rate-limited and re-validated on the server.
- The test suite passes, 711 of 711.
- The tutorial can't soft-lock.
- Nothing from the previous audit's P0 and P1 list is still open.

**What stands between this and a confident launch** is a short list:
- one policy question (paid random eggs),
- a few "paid and got nothing" products,
- purchase feedback that is invisible while a menu is open,
- boosts whose value is mostly eaten by the production-line cap.

Beyond those, the late game and retention numbers need tuning before players reach them, which is around day 3.

## Highest-priority issues

De-duplicated across sections (IDs in brackets).

| # | Sev | Issue | Why it matters | Fix (short) | Refs |
|---|---|---|---|---|---|
| 1 | **P0** | **Eggs are random items bought with shards that are sold for Robux, and there's no `PolicyService` gate** | Roblox Paid Random Items policy and the compliance questionnaire; restricted regions. `CanUsePaidRandomItems` exists with zero callers. | Gate `Hatch` on the policy (or an earned-only shard balance for restricted players); fix the docs' "earned shards only" claim. | C1 |
| 2 | **P1** | **PetMax charges for nothing** with no pets equipped or all already max | Direct "paid, got nothing" case; new players have no pets. | Disable the card; server fallback (bank the levels or credit). | D1, C3 |
| 3 | **P1** | **One-off products are enforced only by the client**: a 2nd `PetSlot` grants nothing, a 2nd `StarterPack` grants again | Same as above, plus the "one per player" promise is broken. | Server-side fallback grant when the flag is already set. | D3, C2 |
| 4 | **P1** | **Purchase and notice toasts draw under every open menu** (`MeteorHUD` DisplayOrder 0, menus 20–100) | A payer buying in the Store sees no confirmation; credit refusals and hatch-equip failures are invisible. | Toasts in a ScreenGui with DisplayOrder ≥ 110, or echo into the Store subtitle. | B1, B6 |
| 5 | **P1** | **Boosts are capped by the production line**: 2x Ore (149 R$) gives ~+5–20 %, Overclock and Mini Overclock ~0 % after minute 8 | Paid items that visibly do almost nothing lead to refunds, reviews and churn among payers. | Let capped boosts lift the other side, sell combos, show a "line-limited" hint. | C4 |
| 6 | **P1** | **Inverted pass ladder**: VIP 199 R$ for +10 %, 2x Cash 129 R$ for +100 %; the 2x passes aren't even in the Store | Lost conversion; the flagship passes are only on hiding HUD icons. | Reprice VIP / 2x Ore; put both 2x passes in Store › Passes. | C5, B3 |
| 7 | **P1** | **A second purchase during a save is deferred until a rejoin** (`processing` returns NotProcessedYet) | A quick double-buy looks like a stolen purchase. | Wait (bounded) for the first receipt instead of rejecting. | D2 |
| 8 | **P1** | **Copy says "sell at the Trading Post"; the live map has none** | Core-loop confusion for new and returning players. | "Tap SELL on your HUD" in 4 strings. | B2 |
| 9 | **P1** | **Offline earnings are near zero by design** (only the hopper left at logout is refined) | The main "come back" hook, the Welcome Back roll, Offline Training and the Offline Hours+ pass are hollow. | Offline output as a share of expected income, up to the cap. | C8 |
| 10 | **P1** | **Daily streak cash is flat** (the ceiling binds from day 1) | The 7-day ramp is invisible; a weaker D2–D7 retention hook. | Ceiling grows with the streak day. | C6 |
| 11 | **P1** | **Head Start perk (600 shards) does nothing** for real players | The biggest shard sink is a trap; feels like a scam. | Repurpose it. | C7 |
| 12 | P1 (console) | **Gamepad: menus never select a control; Dimmers are selectable and close on A** | Console players can't drive menus; the first-join Intro has no focus. | Set `SelectedObject` on open, `Selectable = false` on Dimmers. | B4 |
| 13 | P2 | Background loops die forever on one error, including the **refinery tick** (stops Overclock countdowns) and the **Crown / locked-field ejects** | One bad profile freezes refining, or opens the gates, for the whole server until restart. | A `safeLoop` helper with pcall. | A1, A2 |
| 14 | P2 | Shard farming: one core tap earns the 5-shard floor, and every alt adds 8 to the pool | Undercuts shard packs and egg pacing. | Minimum contribution share; pool sized by power. | A3 |
| 15 | P2 | Network volume: full State snapshot ~5×/s while mining; pet FX `FireAll` on every hit | Bandwidth and lag as the 60-slot server fills. | Hot/cold snapshot split; pet FX by distance. | A5, A6 |
| 16 | P2 | Client perf: "Reduce effects" ignored by LandingFX and FieldFX (124 rocks, each with a light and 2 emitters, rewritten every frame); closed menus re-render at 5 Hz | Low-end mobile frame rate. | Honour the setting; distance cull; skip closed menus. | B11, B13 |
| 17 | P2 | Paid Keep Everything credit spent by one tap or by any normal rebirth | Robux consumable wasted by a mis-tap. | Two-press arm; explicit "use credit". | B7, C24 |
| 18 | P2 | Late game: shop effectively free from ~R8; Legacy laps compound to 3 h+ by R40; no unlocks after R4 / R25 | Heavy-player churn around day 3; shard packs worthless for veterans. | Legacy cost growth ~2.05; late unlocks; a repeatable shard sink. | C9, C10, C13 |
| 19 | P2 | Launch checklist: all **11 badge ids are 0**; Id-0 items show as dead "NOT ON SALE YET" cards; settings aren't saved | Looks unfinished; no badges at launch; settings reset every join. | Create badges; hide Id-0 cards; save settings in the profile. | C17, B8, C18, B5 |
| 20 | P2 | Uncommitted schema bump to **v12** (`trialFlag`, read by nothing) in the working tree | Publishing makes v12 permanent for every profile. | Revert or commit on purpose before the next publish. | D5 |

## Suggested order of work
1. **Before any publish:**
   - #20: revert or commit the v12 change.
   - Remove the junk part and the attributes from the place (D7).
2. **Payer-safety pass (about a day):** #2, #3, #4, #7, #17. All are small and local to `Purchases`, `MonetizationService`, `StoreController`, `HUDController` and `RebirthController`. Add `Purchases.spec` cases.
3. **Policy:** #1. Decide on the gate versus split balances, and confirm against the current Roblox policy text.
4. **Quick copy and launch fixes:**
   - #8 (copy),
   - #19 (badges, Id-0 cards),
   - #6 (Store placement and pricing),
   - #11.
5. **Robustness:** #13 (`safeLoop`), then A12–A14 (small correctness fixes).
6. **Economy re-fit with `Shared.Pacing`:** #5, #9, #10, #18. Each changes numbers, so re-run `tests/Pacing.spec` after each (CLAUDE.md requires it). C22 notes the Drill Pick spec sits on its 480 s edge.
7. **Scale and perf:** #15 and #16, measured with the MicroProfiler and network stats in a full test server.

## Evidence summary
- **Spec suite:** 711 passed, 0 failed (Studio Edit mode).
- **Place:**
  - No stray scripts outside the Rojo-managed folders.
  - 11.5k parts, StreamingEnabled on, MaxPlayers 60 (saved value).
- **Play (`DevMemoryStore`):**
  - Clean start, profile loaded, telemetry funnel fired.
  - 0 game-code errors or warnings during a meteor.
- **Simulator:** `Shared.Pacing` run for 30 h of play (economy auditor).
- **Previous audit (`audit.md`, deleted in the working tree):** these items are now fixed:
  - its persistence findings A02–A04,
  - the solo crack problem (A07: `FloorPlayers = 1`),
  - plot capacity (A05: plots were removed),
  - the stray QA fixture (A01).

## Not covered / limits
- No real device, console or full server was used. B4, B11, B13, A5 and A6 are mechanism-level and need measurement.
- Policy readings (C1) should be checked against Roblox's current published text.
- Art, map aesthetics, audio and the authoring pipelines (`blender/`, `tools/`) were not audited.
- Owner decisions listed in CLAUDE.md were respected (huge numbers, sold shards, tier-ups, boss meteor and Keep, Id 0 off sale). They're only flagged where the *value* or the *grant* is broken.
