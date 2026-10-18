# Meteor Shift improvement pass — implementation plan

**Spec:** the game spec, "Meteor Shift — Game Spec (MVP)" v2. A copy for this pass lives at
`docs/plans/meteor-shift-spec.md`. Section numbers below (§5.3, §8.1 …) refer to it.
**Branch:** `improve-pass` (off `claude/eager-cannon-d2cki4`, which holds main + the Week 3 start).
**Checkpoint of the game before this pass:** `oldmain/` (git-ignored) and the local branch `oldmain`.

Weeks 1 and 2, the plot production line, the meteor fairness rules (§5.3) and most of Week 3
(shop, HUD, results panel, tutorial) are done. This pass adds Week 4 (meteor types with their
§8.1 guardrails, mineral index, rebirth, analytics, passes/products scaffolding), Week 5
(performance, balancing) and the remaining Week 3 mobile work.

## Global Constraints

Every task must respect these. Reviewers check them.

1. **Stack:** Rojo + Fusion 0.3 + Knit 1.7 in Luau, `--!strict` at the top of every new module. Knit and
   Fusion are vendored in `Packages/`; do not add packages. Services live in `src/server/Services`,
   controllers in `src/client/Controllers`, pure logic in `src/shared` (client-visible) or
   `src/server/Lib` (server-only). Match the surrounding style: tabs, a header comment explaining
   the module with spec section references, comment density like the existing files.
2. **The map is never generated at startup.** It lives in Workspace, saved in the place. The only
   runtime clones are the meteor (from `ServerStorage.Assets`) and a player's plot stations. New
   world objects needed by a feature (e.g. an in-world rebirth statue) are NOT to be created in code;
   open features from HUD buttons instead.
3. **All tuning numbers live in `src/shared/Config`**, never in gameplay code.
4. **Economy is inflated into millions and billions.** Every number shown to players goes through
   `Shared.Format` (`Format.number`, `Format.cash`) or `Shared.Price`. Core Shards stay scarce (tens to
   hundreds).
5. **No paid randomness, ever (§1 pillar 4, §9.4).** Nothing purchasable may change odds. 2x Ore doubles
   quantity only, never mineral odds.
6. **Server authority (§12.2).** The server owns all state and re-checks every purchase, price and
   eligibility; clients only request. Remote handlers type-check their arguments and reject silently.
7. **Health bars:** cluster and debris bars show only after the local player hits them, and only for that
   player; the core bar is shared. Do not change this.
8. **Profiles:** new saved keys go into `src/server/Lib/ProfileTemplate.luau` (they are reconciled into old
   profiles on load). Anything that changes the meaning of an existing key needs a migration in
   `DataService` and a `version` bump.
9. **Tests:** pure logic gets specs under `tests/` (Task 1 builds the harness) run in Studio through the
   Roblox Studio MCP `execute_luau` tool in the **Edit** datamodel. Rojo (`rojo serve`) is already running
   and syncing `src/` into the open place. Run the suite before committing.
10. **Studio:** the place `MeteorShiftMVP.rbxl` is open in Studio (studio id from `list_roblox_studios`).
    Do not edit instances in the place by hand or through `execute_luau` (other than running tests);
    everything goes through Rojo-synced files. Play-testing with `start_stop_play` is allowed for
    verification; always stop the play session before finishing. Play mode discards edits.
11. **Git:** commit on the current branch in logical steps with clear messages ending in
    `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`. Never push, never switch branches.
12. **README.md** stays accurate: update the Status section when a task adds player-visible behaviour.

---

### Task 1: Test harness for pure logic

Build a tiny test runner so pure modules can be checked from Studio.

- Add `tests/` at the repo root, mapped by `default.project.json` to `ServerStorage.Tests`
  (a `"ServerStorage": { "Tests": { "$path": "tests" } }` entry; ServerStorage has saved assets, so the
  service node must not get a `$path` and unknown instances must be kept).
- `tests/Runner.luau` (ModuleScript) returns a function `run(filter: string?) -> string` that:
  - Clones `ReplicatedStorage.Shared`, `ServerScriptService.Server.Lib` and the `tests` folder into a fresh
    Folder (so every run re-requires current sources instead of Studio's module cache), requires every
    ModuleScript named `*.spec` in the cloned tests folder, and runs its cases.
  - A spec module returns `function(t)` where `t` offers `t.test(name, fn)`, `t.eq(a, b, msg?)`,
    `t.near(a, b, eps, msg?)`, `t.ok(cond, msg?)`, and `t.shared` / `t.lib` (the cloned Shared and Lib
    folders to require from).
  - Returns a summary string: `"N passed, M failed"` followed by one line per failure with the spec, test
    name and message. Errors inside a test count as failures, never abort the run.
  - Destroys the cloned folder at the end.
- Because `Lib` modules require `ReplicatedStorage.Shared` directly, the runner must make that work for
  clones (simplest: specs for Lib modules are allowed to require the real `ServerScriptService.Server.Lib`
  modules through a clone that is parented where its `script.Parent` lookups still resolve; pick one
  approach, document it in the runner header).
- Initial specs: `tests/Format.spec.luau` (suffixes: 999 → "999", 1234 → "1.23K", 999950 → "1M",
  45.6e6 → "45.6M", 1.25e9 → "1.25B", negative numbers, NaN → "0"; `Format.time(125)` → "2:05"),
  `tests/MiningPower.spec.luau` (power(1)=1, power(4)≈1.953, floorPower, serverPower with floor,
  size split across nodes, shouldRescale at 15%), `tests/Refining.spec.luau` (a few `Refining.run`
  cases: rate-limited by the slower station, limited by hopper stock, stops when the collection post is
  full).
- How to run (put this in the README "Working on it" section):
  `require(game.ServerStorage.Tests.Runner)()` from the command bar or `execute_luau` (Edit).
- Commit: "Add a Studio test runner and specs for Format, MiningPower and Refining".

### Task 2: Server replication and hot-path performance (Week 5, §12.3)

Target: 20 players hitting nodes at once keeps the server heartbeat ≥ 55 FPS and remote traffic per
client under 10 KB/s.

- `PlayerStateService:Replicate(player)` currently runs on every ore gained (every hit), rebuilding and
  sending the whole state table and touching leaderstats. Change it to mark the player dirty and flush
  dirty players on a Heartbeat accumulator at `Config.Net.StateFlushInterval = 0.2` seconds. Add
  `PlayerStateService:ReplicateNow(player)` for callers where latency matters (purchases, rebirth, sells)
  and use it there (ShopService, UpgradeService, EconomyService, RefineryService deposit/collect).
  Leaderstats update only in the flush, and only when the formatted value changed.
- Create `src/shared/Config/Net.luau` for networking constants (`StateFlushInterval`, and move
  nothing else unless it is networking); register it in `Config/init.luau`.
- `ContributionService:_publish` sends a full table to every player every second, even between events.
  Keep the 1 s rate but skip players whose payload did not change since the last send (compare rank,
  rounded contribution, ore and the top-three names).
- Client effects (`MiningController`): sparks, floaters and ore fly-ins must be pooled or capped so a
  held mouse button with 20 players nearby never creates unbounded instances. Cap live floaters at
  `Config.Net.MaxFloaters = 24` (oldest removed first) and reuse spark emitters instead of creating parts
  per hit. Keep the look identical.
- Measure: add a Studio-only `ServerStorage.DevBench` BindableFunction (created in `Main.server.luau` next
  to `DevGrant`) `DevBench:Invoke(player, swings)` that calls `PlayerStateService:AddOre` `swings` times
  and reports elapsed ms and number of State sends. Record before/after numbers in the task report.
- Spec test: none required (no pure logic), but the suite from Task 1 must still pass.
- Commit per logical part.

### Task 3: Meteor types, schedule and ore by pickaxe tier — pure logic (§8.1)

Pure logic and config only; wiring is Task 4.

- `Config.Meteor.Types` becomes Iron, Ice and Crystal (Alien Boss and Seasonal are out of scope for this
  pass). Extend the `MeteorType` type with `RequiredTier`, `ShardMult`, `ActiveDuration`, `Twist`
  (`"None" | "Refreeze" | "Resonance"`), and keep existing look fields. Values from §8.1:

  | Id | DisplayName | Ore | RequiredTier | HpMult | ActiveDuration | ShardMult | Weight | Twist |
  |---|---|---|---|---|---|---|---|---|
  | Iron | Iron Meteor | iron | 1 | 1.0 | 150 | 1 | 60 | None |
  | Ice | Ice Meteor | frost | 3 | 1.1 | 150 | 1.5 | 25 | Refreeze |
  | Crystal | Crystal Meteor | crystal | 5 | 1.2 | 150 | 2 | 15 | Resonance |

  Ice look: pale blue crust (`Glacier`/`Ice` materials), cyan ore and glow. Crystal look: violet/pink crust
  (`Rock`), `Glass`/`Neon`-ish pink ore, magenta glow. Choose colours that read well; keep Iron unchanged.
- Twist tuning in `Config.Meteor.Twists`: `Refreeze = { IdleSeconds = 5, RegenPerSecond = 0.02 }`,
  `Resonance = { Window = 1.5, BonusPerExtra = 0.2, MaxBonus = 0.6 }` (Window = seconds a hitter keeps
  counting as "on" a node).
- `Config.Meteor.EligibleShare = 0.25`, `Config.Meteor.ConsolationMult = 1.25`,
  `Config.Meteor.TypeOrder = { "Iron", "Ice", "Crystal" }` (lowest to highest).
- Add `crystal` everywhere ore types are listed: `Home.OreOrder = { "iron", "frost", "crystal" }`,
  `Home.BarPrices.crystal = 3000`, `Home.OreNames.crystal = "Crystal"`.
- New pure module `src/shared/MeteorTypes.luau`:
  - `MeteorTypes.pick(activeTiers: {number}, roll: number): MeteorType` — weighted pick by `Weight` using
    `roll` in [0,1); a picked type is eligible only if at least `EligibleShare` of the active tiers meet its
    `RequiredTier`; otherwise it drops to the next type down in `TypeOrder` (repeat until eligible; Iron
    always is). With no active players, only Iron is eligible.
  - `MeteorTypes.oreFor(pickaxeTier, meteorType): (oreId: string, mult: number)` — the meteor's ore at
    ×1 if `pickaxeTier >= RequiredTier`, else the ore of the highest type in `TypeOrder` whose
    `RequiredTier <= pickaxeTier`, at ×`ConsolationMult`.
  - `MeteorTypes.missed(pickaxeTier, meteorType): { tier: number, ore: string, barPrice: number }?` —
    what an under-tier player missed (for the results hint), nil when they met the tier.
  - `MeteorTypes.resonanceMult(hittersOnNode: number): number` — `1 + min(BonusPerExtra × (n − 1), MaxBonus)`
    for n ≥ 1.
  - `MeteorTypes.refreezeHp(hp, maxHp, idleSeconds, dt): number` — regains `RegenPerSecond × maxHp × dt`
    once `idleSeconds >= IdleSeconds`, capped at maxHp; broken (hp ≤ 0) stays 0.
  - `MeteorTypes.shardPoolMult(meteorType, intervalSeconds, defaultInterval): number` — `ShardMult`, scaled
    down by `intervalSeconds / defaultInterval` when the interval is shorter than the default (§8.1
    guardrail, for private servers later).
- `tests/MeteorTypes.spec.luau` covering: eligibility fall-down (a lobby of 10 tier-1 players never gets
  Ice or Crystal whatever the roll; 3 of 10 at tier 3 allows Ice; 2 of 10 does not), weight boundaries,
  oreFor (tier 2 on Crystal → iron ×1.25, tier 4 on Crystal → frost ×1.25, tier 5 on Crystal → crystal ×1),
  missed, resonance cap, refreeze idle gate and cap, shard pool scaling.
- Commit: "Add Ice and Crystal meteor types with tier-gated ore (spec 8.1)".

### Task 4: Wire meteor types into the event (§5, §8.1)

- `MeteorService` uses `MeteorTypes.pick(ActivityService:GetActiveTiers(), math.random())` at the start of
  each countdown (the sky board already shows `typeName .. " incoming"`), and the per-type
  `ActiveDuration` for the cooling timer. Publish `requiredTier` in the State too.
- Ore per hit: `NodeService` computes ore per player via `MeteorTypes.oreFor(pickaxe.Tier, type)`. Change
  `TargetDef.Ore` to allow a resolver `OreFor: ((player) -> (string?, number))?` used when present;
  debris keeps its fixed iron ore. Ore gained must go to the right ore key in the backpack.
- Twists:
  - **Refreeze (Ice):** NodeService records the last hit time per target. MeteorService, while Active on an
    Ice meteor, ticks at 0.5 s and applies `MeteorTypes.refreezeHp` to every live crust node and the core
    (use a new `NodeService:Heal(id, hp)` that never exceeds max and marks the target dirty). Clients see
    it through the existing Hp attribute; add a subtle frost tint pulse on regenerating nodes client-side
    only if cheap (optional).
  - **Resonance (Crystal):** NodeService keeps, per target, the set of players who hit it within the last
    `Window` seconds. A hit's Mining Power (HP taken AND contribution) is multiplied by
    `MeteorTypes.resonanceMult(n)`. Supply it through a `TargetDef.PowerMult: ((player, hitters) -> number)?`
    so debris/Iron stay unchanged.
- Rewards: `RewardService.Compute` takes the meteor type's shard pool multiplier:
  `bonusPool = ShardBonusPerHitter × hitters × poolMult` (floor and top-three unchanged). Update its
  callers. Move `Compute` into a pure `src/server/Lib/Rewards.luau` so it can be spec-tested, and add
  `tests/Rewards.spec.luau` (floor for everyone who hit the core, pool split by contribution, top three,
  pool multiplier, nobody hit the core → no rewards).
- Results panel: `RewardService.Results` payload gains `missed` (from `MeteorTypes.missed`) and `oreType`.
  The HUD results panel shows, for under-tier players, a line like
  "Tier 5 pickaxe mines Crystal: $3K bars" (use `Format.cash`).
- Countdown board and HUD timer title show the type; colour the title with the type's `GlowColor`.
- The Ice and Crystal meteors reuse the same node pieces, recoloured by `paintCluster`; no place edits.
- Verify in a Studio play session: set `ServerStorage` attribute `DevFakeTiers` to `"5,5,5"` and
  `DevGrant` a tier-5 pickaxe is not possible directly, so also add to the Studio-only `DevGrant` hook an
  optional 5th argument `pickaxeTier` that sets the tier and restyles the tool. Force a type for testing
  with a Studio-only `ServerStorage` attribute `DevMeteorType` (e.g. `"Ice"`) read by the pick in Studio
  only. Document both in the README.
- Commit per logical part.

### Task 5: Mineral index (§8.2)

- `src/shared/Config/Index.luau`: pages for Iron, Ice and Crystal meteors. Each page has 4 minerals with
  `Id`, `Name`, `Odds` (chance per validated crust/core hit, e.g. 1/25, 1/120, 1/600, 1/2500), `RichOnly`
  (true for the rarest one per page: drops only from "rich" nodes) and a `Color`. Page reward:
  `CashBonus = 0.02` (each completed page adds +2% to bar sales, additive across pages), and a `Title`
  string (e.g. "Iron Prospector", "Frost Walker", "Crystal Seer"). Also `RichNodesPerMeteor = 3`.
  Décor rewards are out of scope (there is no décor system yet); note it in the header.
- Pure module `src/shared/MineralIndex.luau`: `roll(pageId, isRichNode, rng: () -> number): string?` — rolls
  each mineral of the page independently, rarest first, returns at most one mineral id per hit;
  `pageComplete(index, pageId): boolean`; `cashBonus(index): number` (1 + 0.02 × completed pages);
  `titles(index): {string}`. `tests/MineralIndex.spec.luau` with a deterministic rng.
- Drops follow §8.1/§8.2: only for players whose pickaxe tier meets the meteor's `RequiredTier`, at fixed
  odds that nothing purchasable changes (2x Ore never touches this). Debris never drops minerals.
- Server `IndexService`: listens to crust/core hits (add what's needed to `NodeService.Hit`, e.g. pass the
  target part so rich nodes can be recognised by a `Rich` attribute set by `MeteorService` on
  `RichNodesPerMeteor` random crust nodes, which also get a sparkle tint so players can spot them). On a
  drop, increments `profile.index[mineralId]` (count), fires a client signal
  `Discovered(mineralId, count, isNew)`, and when a page completes, announces
  "<name> completed the <page> page!" server-wide and sets the player's `Title` attribute to the best
  title. `EconomyService:SaleMultiplier` uses `MineralIndex.cashBonus(profile.index)`.
- Client `IndexController`: an "INDEX" HUD button (same style and column as the existing SHOP button,
  see `ShopController`) opens a Fusion panel with one tab per page, every mineral as a card (unknown ones
  shown as "???" silhouettes), the published odds on every card ("1 in 600, rich nodes only"), page
  progress, the page reward, and the current total bonus. A toast "New mineral: X!" on a new discovery,
  a small "+1 X" floater otherwise.
- Replicate `index` in the PlayerStateService state payload.
- Commit per logical part.

### Task 6: Rebirth — "Relocate the Colony" (§8.3)

- `src/shared/Config/Rebirth.luau`: `BaseCost = 10e6`, `CostGrowth = 10`, `CashMult = 2` (per rebirth,
  multiplicative). Pure helpers in `src/shared/Rebirth.luau`: `cost(rebirths)` ($10M, $100M, $1B…),
  `multiplier(rebirths)` (2^n). Spec test `tests/Rebirth.spec.luau`.
- `RebirthService`: `Client:Rebirth()` — checks `cash >= cost(rebirths)`; resets cash to 0, pickaxe tier and
  backpack tier to 1, empties the backpack; keeps stations, hopper, bins, carried bars, shards, index,
  décor and flags (§8.3 defaults). Increments `rebirths`, restyles the pickaxe (`ShopService:ApplyPickaxe`),
  replicates immediately, announces "<name> relocated the colony! (Rebirth N, ×M cash)" and fires a
  server signal `Reborn(player, rebirths)` for analytics.
- `EconomyService:SaleMultiplier` switches to `Rebirth.multiplier`. The "While you were away" value in
  `RefineryService:CatchUp` must include the sale multiplier (it currently shows base value only).
- Client `RebirthController`: a "REBIRTH" HUD button in the same column; a panel with the current and next
  cash multiplier, the cost with progress toward it (`Format.cash`), what resets and what is kept, and a
  confirm button that needs a second press ("Are you sure?") within 3 s. Disabled with the reason when
  unaffordable.
- Show the current cash multiplier in the HUD next to cash when above ×1.
- Commit per logical part.

### Task 7: Analytics events (§13)

- `AnalyticsService` (server, name it `TelemetryService` to avoid clashing with Roblox's
  `AnalyticsService`) wrapping Roblox `AnalyticsService` with pcall'd helpers: `custom(player, name, value?,
  fields?)`, `economy(player, flowType, currency, amount, endingBalance, transactionType, sku)`,
  `funnel(...)`. In Studio also `print` a compact line for each event so the log proves it fired.
- Required events (§13): `first_meteor_joined` (first validated hit on a crust node or core ever — set
  `flags.firstMeteor` there instead of in RewardService), `first_core_reward` (first shards received),
  `first_refinery_bought` (first refinery station upgrade; UpgradeService already sets the flag),
  `returned_offline_income` (CatchUp with bars > 0; include hours away and bars as fields/value). Each
  fires once per player lifetime, guarded by the profile flags.
- Also log: per event summary (players in server, players who hit ≥1 node, core hitters, cracked vs
  cooled, seconds to crack, meteor type) as a custom event; economy source/sink events for cash (sell =
  source, shop/upgrade = sink) and shards (core reward = source, purchases = sink); rebirths; a per-player
  "active actions per minute" custom event every 60 s counting swings, deposits, collects, sells and
  purchases (skip players with zero actions and log nothing for them).
- Tutorial funnel steps stay in TutorialService but go through the wrapper.
- Commit per logical part.

### Task 8: Game passes and developer products (§9) — scaffold, no real IDs

The place has no pass/product IDs yet, so everything is wired but off until IDs are filled in.

- `src/shared/Config/Monetization.luau`: passes `TwoXOre`, `BiggerBackpack`, `OfflineHours`, `AutoDeposit`,
  `VIP` with `Id = 0` (0 = not on sale), names and descriptions from §9.1; products `CallMeteor`,
  `Overclock` with `Id = 0`. Call a Meteor rules: only during Countdown with > 60 s left, sets the
  countdown to 30 s, cooldown 180 s after the previous event ends, cap 3 per rolling hour per server.
  Overclock: refinery ×2 speed for 30 min, online only. `VIPBarBonus = 0.1`. The Extra Refinery pass
  from §9.1 does not map onto the single production line; leave it out and say so in the header.
  Cash packs are out of scope.
- `MonetizationService`: resolves pass ownership on join (`UserOwnsGamePassAsync`, pcall'd, skipped when
  Id is 0) and on `PromptGamePassPurchaseFinished`; a Studio-only `ServerStorage` attribute
  `DevPasses = "TwoXOre,VIP"` grants passes for testing. Effects: 2x Ore doubles ore quantity per hit
  (never mineral odds), Bigger Backpack ×2 capacity, Offline Hours+ raises the offline cap to
  `Home.OfflineCapPass`, Auto-Deposit sends mined ore straight to the hopper (respecting hopper capacity,
  overflow to backpack), VIP adds +10% to bar sales and a chat tag if cheap. `ProcessReceipt` for products
  re-checks Call a Meteor availability and, if it became unavailable, grants the refund-equivalent
  (spec: "refunds via a grant of equivalent value") — for the scaffold, record a pending credit in the
  profile (`credits.callMeteor += 1`) that the player can use later, and announce who called a meteor.
  Receipts must be idempotent (store processed purchase ids in the profile, keep the last 50).
- `MeteorService` exposes `CanCallMeteor(): (boolean, reason)` and `CallMeteor(player)` implementing the
  rules above; the Studio-only dev button path stays as is.
- Client `StoreController`: a "STORE" HUD button; lists passes and products with descriptions; buttons
  prompt the purchase, or show "Owned", or "Not on sale yet" when Id is 0; the Call a Meteor button is
  disabled with the reason when unavailable (state published by the server).
- Pure rules in `src/shared/CallMeteor.luau` (`available(phase, secondsLeft, sinceLastEnd, callsInLastHour)
  -> (boolean, string?)`) with `tests/CallMeteor.spec.luau`.
- Commit per logical part.

### Task 9: Mobile controls and HUD layout pass (§10)

- On touch devices (`UserInputService.TouchEnabled and not KeyboardEnabled`), show a big round MINE button
  bottom-right (above the jump button area, never overlapping it) while a pickaxe is equipped. Holding it
  swings continuously at the pickaxe's speed, aiming at the nearest mineable target in range in front of
  the character (reuse `MiningController`'s candidate search; add a "nearest target" mode used when there
  is no pointer aim).
- HUD buttons (SHOP, INDEX, REBIRTH, STORE and any others) sit in one column with ≥ 44 px touch targets at
  the smallest HUD scale; nothing overlaps the Roblox top bar, the thumbstick area or the jump button at
  phone sizes (test 844×390 and 1334×750 viewports by reading positions in a play session, and at desktop
  1920×1080).
- Panels (shop, index, rebirth, store, results, while-you-were-away) fit inside a 844×390 viewport.
- Commit per logical part.

### Task 10: Economy pacing model and balancing (Week 5, §7.4)

- Pure module `src/shared/Pacing.luau` that simulates a player's first sessions from Config values:
  meteor cycles (countdown + active + end phases), ore per minute from swing speed and ore per hit with a
  trip-home overhead (`Config.Balance` holds these model assumptions: e.g. `HitsPerMinuteShare = 0.7`,
  `TripSeconds = 40`), refinery throughput, sells, and greedy purchases in the cheapest-useful-next order.
  Returns a timeline of purchases with timestamps and cash.
- `tests/Pacing.spec.luau` asserts the §7.4 checkpoints within tolerances: the Steel Pickaxe is affordable
  after the first meteor cycle (± one cycle); by 30 minutes the player owns Steel + Drill, backpack tier
  2–3 and a refinery upgrade, with cash in the tens of thousands; a level 1 line's 2-hour offline cap is
  worth roughly $9K at most. If the current Config misses a checkpoint, tune Config values (prices or
  rates, smallest change) until it passes, and list every changed number in the commit message and the
  README.
- Write `docs/balance.md` summarising the model, its assumptions and the resulting timeline.
- Commit: "Add an economy pacing model and tune early progression (spec 7.4)".

### Task 11: README and cleanup

- Update README Status (Week 4/5 sections), Layout (new modules and controllers, tests/), and Working on
  it (test runner, new Studio dev hooks: `DevGrant` tier arg, `DevMeteorType`, `DevPasses`, `DevBench`).
- Remove dead code found along the way, no behaviour changes.
- Commit: "Update the README for the improvement pass".
