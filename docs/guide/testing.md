# Testing

MeteorShift has no build, lint or CLI test step — "Everything runs through Rojo and Roblox Studio"
(`CLAUDE.md:9`). The suite is a tiny harness (`tests/Runner.luau`, 147 lines) plus one pure spec per
logic module; it exists because the game's rules live in pure `Shared.*` / `Lib.*` modules that can
be tested headless inside Studio. The profile specs' subject matter is [profile-schema.md](profile-schema.md),
the pacing model's is [economy.md](economy.md), the catalog rules' are [monetization.md](monetization.md),
the datamodel mapping is [architecture.md](architecture.md)'s "Repo shape", and the Play-mode `Dev*`
hooks beside this Edit-mode suite are [dev-hooks.md](dev-hooks.md)'s.

## How to run

- Serve the tree: `rojo serve` in the repo root, connected from the Rojo plugin in Studio; the map
  below lives in that mapping (`CLAUDE.md:11`).
- `tests/` maps to `ServerStorage.Tests` (`default.project.json:20-22`), so the Runner is one
  command-bar (or Studio MCP `execute_luau`) line in **Edit mode** (`CLAUDE.md:12`):

  ```lua
  require(game.ServerStorage.Tests.Runner)()      -- every spec
  require(game.ServerStorage.Tests.Runner)("MenuFit")  -- one spec: substring filter
  ```

  The filter matches any part of the spec name (`tests/Runner.luau:121`). The Runner returns a
  string — `"%d passed, %d failed"` followed by one `spec > case: message` line per failure
  (`tests/Runner.luau:92-96`) — it does not raise, so read the returned text.
- Only ModuleScripts whose name ends in `.spec` are picked up (`tests/Runner.luau:119`). The one
  exception in `tests/` is `tests/DebrisService.regression.luau`, a Lune script run from the repo
  root with engine boundaries replaced — it is not part of the Runner suite (its header `:1-2`).
- While it runs, the Runner clones `Shared`, `Server.Lib` and the tests folder into a scratch
  Folder under `ReplicatedStorage` and destroys it when done (`tests/Runner.luau:100-115, 141`).

## The spec contract

A spec is a ModuleScript named `<Name>.spec` directly under `tests/` that returns
`function(t) ... end` and calls `t.test(name, fn)` once per case (`tests/Runner.luau:32-36`,
`CLAUDE.md:17`). The canonical small example is `tests/MenuFit.spec.luau`: header comment,
`return function(t: any)`, one `require(t.shared.MenuFit)` (`:5-6`), then cases.

| Call | Contract | Cite |
|---|---|---|
| `t.test(name, fn)` | runs `fn` under `pcall`; records pass/fail with the error message | `tests/Runner.luau:51-58` |
| `t.eq(a, b, msg?)` | fails unless `a ~= b` is false — **strict `~=`** — with b read as expected, a as got | `tests/Runner.luau:60-64` |
| `t.near(a, b, eps, msg?)` | numbers only; fails when `\|a − b\| > eps` | `tests/Runner.luau:66-70` |
| `t.ok(cond, msg?)` | fails on any falsy value | `tests/Runner.luau:72-76` |
| `t.shared`, `t.lib` | the fresh clones of `ReplicatedStorage.Shared` and `ServerScriptService.Server.Lib` | `tests/Runner.luau:105-111, 125-126` |

The trap in `t.eq`: line 61 compares with `~=`, and Luau `~=` on tables is **reference** identity —
so `t.eq({}, {})` on two fresh tables ALWAYS fails no matter how equal their contents are. Compare
scalars (`t.near(rect.w, natural.X, 0.01)` in `tests/MenuFit.spec.luau:24`) or single members, never
whole tables. A module that explodes at require or mid-body is reported as a `(require)` or
`(module)` failure, not skipped (`tests/Runner.luau:128-132`).

## Why requires go through the clones

Roblox caches a `require` result per ModuleScript instance for the whole session, and a Rojo edit
on disk does NOT invalidate that cache — requiring the real `ReplicatedStorage.Shared` would
silently keep testing whatever this Studio session first required (`tests/Runner.luau:4-12`). A
clone is a different instance, so it re-executes current Source every run; that is what `t.shared`
and `t.lib` hand you (`tests/Runner.luau:10-12, 32-36`, `CLAUDE.md:17`). Two caveats the header
records: Lib modules that require `Config` by absolute path still resolve against the *real*
Shared, and anything the session already required the long way stays stale until the session
restarts — only clone-hood guarantees freshness (`tests/Runner.luau:20-30`). And never "fix" this
by replacing the real `ReplicatedStorage.Shared` with a clone: that breaks Rojo sync for the
folder; restart Studio instead (`CLAUDE.md:51`).

## Where logic must live to be testable

Logic worth testing is a pure module in `src/shared` (or `src/server/Lib`) with a
`tests/<Name>.spec.luau` next to the others (`CLAUDE.md:17`). Consequences the suite leans on:

- Controllers and services cannot be `require`d from specs, so even "what the player sees" checks
  are asserted at the data layer the controller prints verbatim (`tests/Consistency.spec.luau:4-5`).
- Functions that mutate real Instances (`applyToTool`, stud-texturing) stay out of headless specs
  and are verified in Studio; the pure half is still specced (`tests/EquipmentModels.spec.luau:6-7`,
  `tests/StudSkin.spec.luau:3-5`).
- Menu geometry lives in pure `Shared.*Layout` modules; change numbers there and update the spec,
  not the controller (`CLAUDE.md:18`). `Shared.MenuFit` is the shared shrink-on-small-screens layer
  (virtual larger screen, smaller draw — `tests/MenuFit.spec.luau:2-3`) that several layouts build
  on (`tests/RebirthLayout.spec.luau:7`, `tests/RefineryLayout.spec.luau:6`).

The pairing, each row proven by the spec's own require line:

| Layout module | Spec(s) | Require line |
|---|---|---|
| `src/shared/EquipmentShopLayout.luau` | `tests/EquipmentShopLayout.spec.luau`, `tests/EquipmentShopScreen.spec.luau` | `:5` and `:4` |
| `src/shared/PetsLayout.luau` | `tests/PetsLayout.spec.luau` | `:6` |
| `src/shared/StoreLayout.luau` | `tests/StoreLayout.spec.luau` | `:5` |
| `src/shared/RebirthLayout.luau` | `tests/RebirthLayout.spec.luau` | `:5` |
| `src/shared/RefineryLayout.luau` | `tests/RefineryLayout.spec.luau` | `:5` |
| `src/shared/IndexLayout.luau` | `tests/IndexLayout.spec.luau` | `:5` |
| `src/shared/HudLayout.luau` | `tests/HudLayout.spec.luau` (HUD buttons + `Shared.Aim`) | `:8` |
| `src/shared/MenuFit.luau` | `tests/MenuFit.spec.luau` | `:6` |

## Rules the suite enforces by design

- **Store exactly-one placement.** Every pass and product in `Config.Monetization` must appear in
  exactly one `Config.Store.Sections` entry or in `Config.Store.Elsewhere` — the `seen` map fails a
  double-listing (`tests/StoreLayout.spec.luau:19`) and the `PassOrder`/`ProductOrder` sweeps fail a
  missing one (`tests/StoreLayout.spec.luau:8-25`, esp. `:23-24`).
- **The catalog mirror.** `tests/Purchases.spec.luau` pins the other half: the `LIVE`/`PASSES`
  tables of dashboard ids and Robux prices (`:22-35`) must equal `Config.Monetization` exactly —
  anything absent from the tables must have `Id = 0` (`:61`, `:48`) — and tier-ups are gear-shop
  cards only (`:71-81`). So adding a product means editing both files (`CLAUDE.md:19`).
- **The pacing re-fit.** `Shared.Pacing` simulates a fresh player from Config and
  `tests/Pacing.spec.luau` asserts the progression targets — first rebirth inside 10–20 minutes
  (`:84-89`), ~6-minute cycle (`:15-20`), laps that lengthen then hold level (`:91-103`), no
  purchase ever overspends (`:169-173`). Any change to prices, income or rebirth costs must be
  re-fitted until this spec passes (`CLAUDE.md:20`).
- **No mirrored numbers.** `tests/Consistency.spec.luau` asserts every duplicated player-visible
  number equals its Config source at the data layer (`:2-6`).

## What the suite covers

75 `*.spec.luau` files carrying 677 `t.test` cases, plus the Lune regression (counted against the
tree 2026-10-18). ★ marks the specs added on 2026-10-18 by the consistency/hardening pass (git
add dates). Cite = the header or first-test line the one-liner came from.

### Economy and progression

| Spec | Guards | Cite |
|---|---|---|
| Pacing | model determinism + the rebirth-ladder targets above | `tests/Pacing.spec.luau:2-5` |
| Price | rebirth-inflated cash rounds identically server and client | `tests/Price.spec.luau:2` |
| Rebirth | cost/multiplier shape read from `Config.Rebirth`, never retune-brittle values | `tests/Rebirth.spec.luau:2-5` |
| Gear | one pickaxe + one backpack, level restarts at 1 each tier | `tests/Gear.spec.luau:2-3` |
| GearMigration | the v6→v7 stat-merge and v7→v8 per-tier restart conversions | `tests/GearMigration.spec.luau:2-3` |
| Levels | XP curve, awards, meteor XP, evolve gates | `tests/Levels.spec.luau:2` |
| Line | the production line's single level | `tests/Line.spec.luau:2` |
| Refining | `Lib.Refining`'s line sim (online tick + offline catch-up share it) | `tests/Refining.spec.luau:2-5` |
| RefineryQueue | saved refine priority and live contents | `tests/RefineryQueue.spec.luau:2` |
| Rewards | Core Shard payout when a core cracks (floor, per-hitter, top-three) | `tests/Rewards.spec.luau:2-4` |
| Income ★ | cash-grant clamp rails: never negative, ceiling beats floor | `tests/Income.spec.luau:2-6` |
| DebrisField | what a rock pays by the ore field it stands in | `tests/DebrisField.spec.luau:2` |
| DebrisOre | every debris tier drops Iron, cyan rocks included | `tests/DebrisOre.spec.luau:2` |
| MiningPower | the hidden stat node/core HP runs on | `tests/MiningPower.spec.luau:2-4` |
| MiningReach | swing distance to a box + the upward crown reach | `tests/MiningReach.spec.luau:2-3` |
| Perks | Colony Perk levels, prices, effects from `Config.Perks` | `tests/Perks.spec.luau:2` |
| Daily | daily streak/quest rules from `Config.Daily` | `tests/Daily.spec.luau:4` |
| Hooks | engagement-hook rules from `Config.Hooks` | `tests/Hooks.spec.luau:2` |
| Leaderboards | leaderboard rules and DataStore keys | `tests/Leaderboards.spec.luau:4` |
| Format | every player-facing number/suffix ladder (`Format.number/cash/time`) | `tests/Format.spec.luau:2-3` |
| MineralIndex | mineral rolls, page rewards, titles, published odds text | `tests/MineralIndex.spec.luau:2-6` |
| DebrisService.regression | *Lune, not Runner*: real DebrisService behind fake boundaries | `tests/DebrisService.regression.luau:1-2` |

### Layout and menus

| Spec | Guards | Cite |
|---|---|---|
| MenuFit | virtual-screen shrink: menus keep natural size, stay on screen | `tests/MenuFit.spec.luau:2-3` |
| HudLayout | 44 px buttons, no overlaps, under the top bar (with `Shared.Aim`) | `tests/HudLayout.spec.luau:2-5` |
| EquipmentShopLayout | roomy window → the 760×501 frame; small → one 560 column | `tests/EquipmentShopLayout.spec.luau:2-3` |
| EquipmentShopScreen | every gear-screen control inside the scroll area, no overlaps | `tests/EquipmentShopScreen.spec.luau:2` |
| PetsLayout | pets menu fits every screen; lists ordered; perk lines match Config | `tests/PetsLayout.spec.luau:2-3` |
| RebirthLayout | wide frame on roomy windows; only the body scrolls | `tests/RebirthLayout.spec.luau:2-3` |
| RefineryLayout | three cards + refining order inside the panel, touch-sized | `tests/RefineryLayout.spec.luau:2-3` |
| IndexLayout | index panel/ribbon/lip on screen; grid scrolls, never shrinks | `tests/IndexLayout.spec.luau:2-3` |
| MenuPalette | text contrast (WCAG definition) on what it draws over | `tests/MenuPalette.spec.luau:2` |
| HudMessages | ordinary notices can't inject rich-text markup | `tests/HudMessages.spec.luau:4` |
| HudResources | carried-bar rows from Config fixtures | `tests/HudResources.spec.luau:2-3` |
| ProductionPresentation | workshop presentation never changes gameplay quantities | `tests/ProductionPresentation.spec.luau:2` |
| Intro | the first-join intro's five pages and who sees it | `tests/Intro.spec.luau:2` |

### Monetization and policy

| Spec | Guards | Cite |
|---|---|---|
| Purchases | product arithmetic, receipt idempotency, the catalog-mirror tables | `tests/Purchases.spec.luau:2-3` |
| StoreLayout | section/Elsewhere exactly-one rule + phone card geometry | `tests/StoreLayout.spec.luau:2, 8` |
| PlayerPolicies | policy cache, validation, player lifecycle (deterministic queue) | `tests/PlayerPolicies.spec.luau:2-3` |
| RequestGate | remote admission gates before payload validation | `tests/RequestGate.spec.luau:2` |
| CallMeteor | when Call a Meteor may be bought (phase, cooldown, hourly cap) | `tests/CallMeteor.spec.luau:2-5` |
| Badges | `Lib.Badges` + `Config.Badges` keys hand out awards | `tests/Badges.spec.luau:4` |
| Codes | code rules from `Config.Codes` | `tests/Codes.spec.luau:4` |

### Profile and data

| Spec | Guards | Cite |
|---|---|---|
| ProfileTemplate ★ | saved-shape pins: positive-integer version, key list, deep copies, reset drops no key | `tests/ProfileTemplate.spec.luau:2-7` |
| RebirthReset | rebirth empties the loop, retains permanent rewards | `tests/RebirthReset.spec.luau:2` |
| ProfileLoadMessage | load failures explain the retry without over-claiming | `tests/ProfileLoadMessage.spec.luau:2` |
| AdminGive | `/give` hands out and never takes away | `tests/AdminGive.spec.luau:2-3` |
| Admins | only listed user ids get admin on a live server | `tests/Admins.spec.luau:6` |
| Net | `Config.Net` limits (State flush 0.2 s, floater caps) | `tests/Net.spec.luau:2-4` |
| Telemetry | `Lib.Telemetry` custom fields for AnalyticsService | `tests/Telemetry.spec.luau:2-4` |
| LoadingProgress | progress reporting available before startup completes | `tests/LoadingProgress.spec.luau:3-4` |

### Meteor, world and movement

| Spec | Guards | Cite |
|---|---|---|
| Aim ★ | MINE-button target choice; gates inclusive, server re-checks range anyway | `tests/Aim.spec.luau:2-5` |
| Phase ★ | the six-phase wire contract, frozen at runtime | `tests/Phase.spec.luau:2-4` |
| MeteorTypes | next-type weights + Ice/Crystal twist math | `tests/MeteorTypes.spec.luau:2-4` |
| MeteorIcon ★ | typeId → HUD icon via `Config.HudIcons`, generic fallback | `tests/MeteorIcon.spec.luau:2-4` |
| MeteorVisualGeometry | spectacle dimensions from hand-derived fixtures | `tests/MeteorVisualGeometry.spec.luau:2-3` |
| AtmosphereMood | mood blend strength per meteor phase | `tests/AtmosphereMood.spec.luau:2-5` |
| LandingFX | Ice/Crystal landing effects' clock, layout, rules | `tests/LandingFX.spec.luau:2-4` |
| CompactLandingFX | persistent landing geometry honours the 125-stud contract | `tests/CompactLandingFX.spec.luau:2-4` |
| ImpactFX | every meteor type, boss included, has its landing flavour | `tests/ImpactFX.spec.luau:6` |
| StudSkin ★ | which runtime parts take the stud texture (pure half only) | `tests/StudSkin.spec.luau:2-5` |
| SurfaceLayout | one event lays out one deterministic spoke scene | `tests/SurfaceLayout.spec.luau:7` |
| FieldTravel | the four ore fields are the only valid travel targets | `tests/FieldTravel.spec.luau:7` |
| CharacterSpeed | walkspeed composes from the base multiplier | `tests/CharacterSpeed.spec.luau:6` |
| WorldBoundary | the authoritative world boundary | `tests/WorldBoundary.spec.luau:4` |
| WorldEquipment | world displays: identity from Config, numbers from State | `tests/WorldEquipment.spec.luau:2` |
| WorldEquipmentDisplay | display over real authored models and mounts | `tests/WorldEquipmentDisplay.spec.luau:2` |
| WorldGeometry | access and effect clearance as geometric contracts | `tests/WorldGeometry.spec.luau:2` |
| WorldImpact | grounded-impact evacuation | `tests/WorldImpact.spec.luau:4` |
| WorldMap | world-root selection; staged templates only in Studio | `tests/WorldMap.spec.luau:4, 7` |

### Pets

| Spec | Guards | Cite |
|---|---|---|
| Pets | perks by level, XP, slots, saved-data checks | `tests/Pets.spec.luau:2` |
| PetEffects | quantity multipliers stay separate from odds and XP sources | `tests/PetEffects.spec.luau:2` |
| PetIntegration | Vault perk multiplies both station capacities, defaults unchanged | `tests/PetIntegration.spec.luau:7` |
| PetVisuals | client bounds work even when replicated attributes arrive apart | `tests/PetVisuals.spec.luau:2` |

### Cross-cutting

| Spec | Guards | Cite |
|---|---|---|
| EquipmentModels ★ | structural invariants of the shop/worn gear builders (MeshArt or fallback) | `tests/EquipmentModels.spec.luau:2-7` |
| Consistency ★ | no player-visible number may drift from its Config source | `tests/Consistency.spec.luau:2-6` |
| Sounds | every `Config.Sounds`/`Music`/`RewardFX` entry is playable as configured | `tests/Sounds.spec.luau:2` |

## When you change things

- **Add a saved field** → the key list in `tests/ProfileTemplate.spec.luau:27-31` must grow or the
  spec fails; the full five-site choreography (template, version, migration, `RebirthReset`, both
  specs) is in [profile-schema.md](profile-schema.md).
- **Add a product or pass** → `tests/Purchases.spec.luau`'s `LIVE`/`PASSES` tables (or leave it at
  `Id = 0`) *and* its exactly-one Store section placement — [monetization.md](monetization.md) owns
  the catalog rules; the pet-menu price flow is guarded by [pets.md](pets.md)'s consistency rule.
- **Change layout numbers** → edit the `Shared.*Layout` module and its spec, not the controller
  (`CLAUDE.md:18`); the menu workflow around the authored ScreenGuis belongs to the native-UI guide
  (`docs/guide/native-ui.md`).
- **Change prices, income or rebirth costs** → re-fit `Config.Rebirth.Costs` with `Shared.Pacing`
  until `tests/Pacing.spec.luau` passes (`CLAUDE.md:20`); the balance story is [economy.md](economy.md).

## Doc references have their own runner

Not Luau, but part of the same "run it, don't assume it" habit: from the repo root,
`node tools/check-docs.cjs` (Node, no dependencies) checks every relative markdown link and every
whitespace-free backticked `src/`/`tests/`/`tools/`/`docs/`/`assets/` path in README.md, CLAUDE.md
and docs/*.md (docs/archive is skipped), exiting 1 with one line per broken reference (`tools/check-docs.cjs:8-19`).

---

*Cite hygiene: every `file:line` above was opened on 2026-10-18 against the working tree; the suite
counts (75 specs / 677 cases) and the ★ set (8 specs with 2026-10-18 git add dates) are command
counts, not file cites. The specs themselves were not run here — this session had no Studio.*
