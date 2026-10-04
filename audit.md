# Craftworks: Meteor Mining — production readiness audit

## 1. Audit record

| Field | Value |
|---|---|
| Date | October 4, 2026, Europe/Vilnius |
| Requested branch | `job-for-tomorrow` |
| Audited commit | `8dc1f8d49c14b20a3991f5d15d7f83fada8abc8b` |
| Repository | `FullerPing/MeteorShift` |
| Branch permalink | [Audited tree](https://github.com/FullerPing/MeteorShift/tree/8dc1f8d49c14b20a3991f5d15d7f83fada8abc8b) |
| Running Studio supplement | `Craterworks: Meteor Mining`, place `113476105600560`, already in Play mode |
| Deliverable | Review and recommendations; gameplay code, saved places, player profiles, and publication were not changed by this audit |

The newer `assets/marketing/craftworks/` artwork and `tools/build-craftworks-*` files were uncommitted when this audit began. They are **excluded** from the branch assessment. The title above follows the owner's current game name; the audited repository and connected Studio still use older names.

### Method and evidence labels

- **Confirmed:** directly established from committed source, decoded committed place contents, or an isolated reproduction of the actual module with fake engine/service boundaries.
- **Conditional defect:** the incorrect behavior is established, but its trigger depends on runtime conditions, device size, streaming, or a chosen release artifact.
- **Design risk:** the behavior is intentional or permissible, but has a quantified negative consequence that needs a product decision.
- **Validation gap:** insufficient evidence to certify a requirement; this is not a claim that the feature is broken.

Severity is separate from confidence:

| Priority | Meaning |
|---|---|
| P0 | Critical release blocker: destructive behavior in a release candidate or comparable catastrophic failure |
| P1 | Major release blocker affecting persistence, core progression, required capacity, or reproducible delivery |
| P2 | Material usability, balance, security, accessibility, or reliability issue; resolve before broad launch or the relevant paid-feature activation |
| P3 | Polish, documentation, discoverability, or longer-term product quality |

File references below use paths and line numbers from the audited commit. Binary-place references use exact DataModel paths because `.rbxl` files do not have useful source line numbers.

## 2. Executive assessment

**Verdict: not ready for an unrestricted production launch.** The project has a working game loop, server-owned money/inventory rules, responsive replacements for several menus, bounded effects, and a passing pure-logic suite. The remaining blockers are substantive rather than cosmetic.

The most urgent discovery is an **enabled, unguarded QA script embedded in `MeteorShift-backpack-foundry.rbxl`**. It overwrites every joining player's cash, shards, rebirth count, and carried bars. The same script exists in the current Studio server. Publishing that place unchanged would turn a test fixture into persistent player-data corruption. This audit did not establish whether that script is present in the currently published public version.

Persistence also has an unconditional in-memory fallback on a production DataStore startup failure, concurrent writes that can roll back a final save, and a shared save-abort flag that remains stuck after one lock-loss event. Saved places allow 30 players while the map has 20 plots; the connected Studio reports 60. Low-population meteor tuning makes the central shard reward unattainable for a solo Basic player.

There is no single demonstrated clean place artifact that contains all the branch's latest source and assets. Opening a file called “newest,” passing unit tests, and syncing code are not equivalent to validating a release candidate.

### Category assessment

| Category | Assessment | Main concern |
|---|---|---|
| UI / responsive layout | Needs corrections | Small portrait HUD and older scaled Index/offline panels |
| UX / onboarding | Needs corrections | Low-population guidance, results clarity, menu coordination |
| Economy / progression | Not validated for launch | Unwinnable small-lobby core, nonmonotonic debris value, stale pacing model |
| Models / map / plots | Useful art foundation; release integration incomplete | Saved-place divergence, capacity mismatch, streaming beacon recovery |
| Stability / persistence | Blocked | QA mutation, memory fallback, save race, incorrect save status |
| Security / server authority | Good baseline; incomplete context validation | Dead/unequipped mining accepted; movement trust and abuse testing incomplete |
| Monetization | Off sale; activation blocked pending validation | Replay safety, ownership failures, actual purchase value |
| Accessibility / input | Incomplete | Motion control, small touch targets, unverified gamepad focus |
| Performance / hardware | Not certified | Model/FX budgets exist, but no representative load/device benchmark |
| Audio / asset delivery | Partly implemented; delivery unverified | Cold-start permissions/loading and failure visibility |
| Retention / analytics | Needs real-session validation | Model assumptions and missing analytics delivery recovery |
| Build / QA / release operations | Blocked | No canonical release artifact or automated integration/release guard |

### Prioritized findings index

| ID | Priority | Category | Finding | Evidence type |
|---|---|---|---|---|
| A01 | P0 | Release / data integrity | Enabled saved-place QA fixture overwrites player progression | Confirmed artifact defect |
| A02 | P1 | Persistence | Production startup errors silently select unsaved profiles | Confirmed fault reproduction |
| A03 | P1 | Persistence | Older writes can undo final saves; release saves have no retry queue | Confirmed race reproduction / source |
| A04 | P1 | Persistence | Save-abort flag leaks across operations and players | Confirmed fault reproduction |
| A05 | P1 | Plots / capacity | More allowed players than plots; no waiting-player reassignment | Confirmed configuration / source |
| A06 | P1 | Build / release | No demonstrated canonical place matching the branch | Confirmed artifact divergence |
| A07 | P1 | Economy / gameplay | Solo Basic players cannot crack a meteor | Confirmed mathematical bound |
| A08 | P2 | Economy | Tier 5 purchase reduces between-event debris value | Confirmed calculation |
| A09 | P2 | Economy / QA | Balance model does not simulate current debris or reward rules | Confirmed divergence |
| A10 | P2 | Economy | Mixed-tier debris payouts bypass meteor under-tier safeguards | Confirmed behavior / design risk |
| A11 | P2 | Economy / progression | Individual upgrades depend on lobby type eligibility | Design risk |
| A12 | P2 | Onboarding | Failed meteors do not lead novices into the home loop | Conditional UX defect |
| A13 | P2 | UI / touch | Small portrait HUD overlaps movement and collapses foundry controls | Confirmed geometry |
| A14 | P2 | UI / touch | Index scales tabs and text below usable sizes | Confirmed geometry |
| A15 | P2 | UI / touch | Offline return dismissal is undersized | Confirmed geometry |
| A16 | P2 | UX / input | Modal stacking and mining guards are inconsistent | Source-confirmed; interaction validation needed |
| A17 | P2 | UX / feedback | Meteor results discard ore and eligibility explanations | Confirmed contract mismatch |
| A18 | P2 | Accessibility | Camera shake has no player setting | Confirmed feature gap |
| A19 | P2 | Security | Server accepts mining while dead and without an equipped pickaxe | Confirmed isolated reproduction |
| A20 | P2 | Reliability / UX | Lock recovery and failure messaging do not match actual failure modes | Confirmed source behavior |
| A21 | P2* | Purchases | Receipt replay safety fails after eviction or notification exception | Confirmed isolated reproductions |
| A22 | P2* | Entitlements | Ownership lookup failure can remove paid effects and offline value | Confirmed control flow |
| A23 | P2* | Purchase value | Overclock / extra offline hours can provide little or no benefit | Quantified design risk |
| A24 | P2 | Models / performance | Current model and FX envelope lacks production benchmarking | Validation gap |
| A25 | P2 | Streaming / UX | Own-plot beacon has no recovery when its pad streams in later | Conditional source defect |
| A26 | P2 | Assets / audio | Asset access and cold-start delivery are not validated as a release gate | Validation gap |
| A27 | P2 | QA / operations | Passing pure tests omit critical service and release failures | Confirmed coverage gap |
| A28 | P3 | Analytics | Failed lifetime milestone delivery is never retried | Confirmed failure behavior |
| A29 | P3 | UX / presentation | Navigation terminology, stats, and refinery affordances conflict | Confirmed polish issues |
| A30 | P3 | Retention / plots | Long-term goals and plot personalization remain thin or unvalidated | Design / validation gap |
| A31 | P3 | Brand / repository | Names, docs, assets, and scratch tooling lack a release-oriented organization | Confirmed inconsistency |

`*` A21–A23 are **dormant activation blockers**: every committed pass/product ID is zero. They are not claims that active customers are presently experiencing these defects. Fix or validate them before enabling sales.

## 3. Critical release, persistence, and capacity findings

### A01 — P0: a saved-place QA fixture overwrites progression on every join

**Evidence:** `MeteorShift-backpack-foundry.rbxl` → `ServerScriptService.Script`, enabled. Decoded committed source and the live Studio server contain the same 698-byte fixture. It waits for `PlayerStateService:Get(player)` and then executes:

```luau
data.bars = { iron = 23, frost = 2, crystal = 1 }
data.cash = 12345; data.shards = 17; data.rebirths = 2
states:ReplicateNow(player)
```

It subscribes to `Players.PlayerAdded` and also processes all existing players. There is no `RunService:IsStudio()` guard or explicit test-only environment check.

**Trigger / impact:** start or publish this saved place unchanged. New and returning players receive forced inventory and progression; ordinary autosave/release can persist those mutations over their legitimate data. This is a destructive release-artifact defect, not a harmless visual fixture.

**Recommended fix:** remove the fixture from the canonical release place, inventory all executable instances outside the approved source tree, and fail release validation on unexpected scripts or known QA markers. Keep QA fixtures external or guarded and disposable. Verify a clean re-opened/exported artifact before publication.

**Acceptance:** zero unauthorized executable instances; a returning profile is unchanged merely by joining; fresh profiles begin at the actual template values. Do not test this against a real customer's save.

### A02 — P1: production DataStore errors silently start an unsaved server

**Evidence:** `src/server/Services/DataService.luau:224–235` probes `GetAsync("__probe")` once. Any error leaves `store` nil. The fallback itself is not restricted to Studio; `:207` marks profiles as memory-only and `:135–137` reports memory saves as successful.

**Isolated reproduction:** with `RunService:IsStudio()` returning false and a thrown probe request, a new profile had `Memory = true`; `Save()` returned true; durable DataStore writes = **0**.

**Impact:** a transient production startup outage can create an entire server where progress never persists. Existing cloud records are not overwritten by this fallback, but players see temporary default progress and lose the progress earned on that server. Once products are activated, successful memory saves also cannot justify acknowledging a durable paid grant.

**Recommended fix:** restrict in-memory storage to an explicitly identified test environment. In production, retry/back off and fail closed with an accurate unavailable-save experience; disable economic/purchase mutation until durable profiles are loaded.

**Acceptance:** a failed production probe never admits an unsaved economic session or acknowledges a paid receipt.

### A03 — P1: save operations can complete out of order and undo a final save

**Evidence:** `DataService.luau:130–151` captures a full snapshot before yielding to `UpdateAsync`; `:249–255` spawns autosaves without per-profile serialization; `:213–221` removes the profile before a single release write. The write accepts a record with no lock, so an old in-flight write can run after release.

**Isolated reproduction:** pause an older `Save()` before provider commit with cash **100**; advance cash to **200** and call `_release()`; final record contains 200 and no lock. Resume the older operation: stored cash becomes **100**, and the old session lock is restored. The provider fixture only controls request completion order; the actual service functions are unchanged.

**Impact:** progress rollback and a re-created lock after the player leaves. Independently, a transient failure on the one release request has no retained profile/retry queue; shutdown iterates profiles still in memory and can miss ones already removed for release.

**Recommended fix:** serialize/coalesce writes per profile, reject stale revisions or released sessions, retain failed releases until durable completion, and track in-flight releases during shutdown. Apply bounded retry/backoff within shutdown limits.

**Acceptance:** paused autosave + final release cannot roll back newer data or re-lock a released profile; failed final writes have a controlled retry/recovery path.

### A04 — P1: the save-abort flag leaks across unrelated saves

**Evidence:** `DataService.luau:109` declares `local aborted = false` inside **claim()**, not **write()**. `write()` assigns `aborted = true` at `:143`, reads it at `:153`, and returns `ok and not aborted` at `:156` without a local declaration/reset.

**Isolated reproduction:** one player's lock-loss save returned false. A different player's subsequent successful write stored cash **123**, but its `Save()` also returned **false**. The shared flag stays true after the first aborted operation.

**Impact:** false save failures across players, misleading warnings, and paid receipts repeatedly returning `NotProcessedYet` despite successful later writes. This is not a syntax error, so the ordinary compile/pure test passes do not detect it.

**Recommended fix:** use a per-operation local outcome and validate callback retries/cancellation. Add same-player and cross-player save-status tests plus static type/lint checking.

**Acceptance:** each save reports only its own durable outcome; one lost lock cannot poison another player's save status.

### A05 — P1: player capacity exceeds available production plots

**Evidence:** all five inspected committed places have **20 plots** and serialized `Players.MaxPlayers = 30`. Connected Studio reports **60**, which is supplemental runtime configuration, not proof of the published dashboard limit. The spec explicitly calls for 20 players (`docs/plans/meteor-shift-spec.md:33–38`). `PlotService.luau:59–72` only warns when no plot is free; `:75–87` does not assign a freed plot to waiting players.

**Trigger / impact:** the 21st simultaneous player has no production line or useful home beacon. Depositing and collecting rely on the assigned physical stations. Even after a plot becomes free, an unassigned player is not automatically retried. The primary economy loop can remain unavailable until rejoin.

**Recommended fix:** align saved-place and Creator Dashboard capacity with guaranteed plot supply, or implement queued/retried assignment and a clear waiting/recovery state. Validate actual published capacity separately.

**Acceptance:** every admitted player receives a functional line; a full-server join followed by a departure recovers without rejoin.

### A06 — P1: the branch has no demonstrated canonical release place

**Evidence:** `default.project.json:4–34` synchronizes source/packages/tests but does not construct Map, Terrain, Lighting, StarterPack, or server art assets. `tools/map-art/README.md:5,19,25,43` names several different “latest” or authoritative places and explicitly says `.rbxm` exports are pre-pass backups.

Five saved places were decoded and compared against current committed source. None matched all five sampled modules: DataService, DebrisService, ShopController, RebirthController, LandingFXController. `MeteorShift-backpack-foundry.rbxl` matches DataService and LandingFX but retains older Debris/Shop/Rebirth sources and A01. `MeteorShift-newest.rbxl` also contains older sampled gameplay/UI sources.

**Impact:** a developer can open “newest,” publish a visually current but logically stale game, or build the Rojo project without the world required by service `WaitForChild` contracts. Old snapshots may remain useful backups, but are not verified release candidates.

**Recommended fix:** designate one canonical place/rebuild procedure, synchronize the target commit, remove QA, export fresh canonical world assets where appropriate, and record source/asset hashes plus the published version. Separate historical checkpoints from release inputs.

**Acceptance:** a clean machine can reproduce the complete game and verify source parity, scene contracts, startup, and a fresh-player production loop from documented inputs.

## 4. Economy, progression, and onboarding

### A07 — P1: a solo Basic player cannot crack the minimum meteor

**Evidence:** `Config/Meteor.luau:22–26,108` sets a four-Basic-player power floor and a 150-second Iron active timer. `MiningPower.luau:31–47` sizes 70 seconds of total crust and 45 seconds of core HP at that power. `MeteorService.luau:335` requires `ceil(0.6 × nodeCount)` broken nodes. The saved and live core both have **36 slots**, so 22 must break. `RewardService.luau:42` and `Lib/Rewards.luau:29` require a cracked core and core participation for shards.

The optimistic lower bound is `(70 × 0.6 + 45) × 4 = 348` Basic player-seconds. With the actual 22/36 rounding it is approximately **351.1 seconds**. Walking, unfinished nodes, missed swings, overshoot, and Ice healing only increase the required time. Even exploiting the allowed 20% faster swing cadence cannot bring solo completion inside 150 seconds.

| Basic miners | Optimistic lower bound, normal cadence | With 70% landed-hit share |
|---:|---:|---:|
| 1 | 348 s | 497 s |
| 2 | 174 s | 249 s |
| 3 | 116 s | 166 s |
| 4 | 87 s | 124 s |

**Impact:** fresh/private/small servers repeatedly cool without the central shard payoff. Two Basic miners also fail at normal cadence. Higher gear can eventually overcome the floor; the issue is the first-session experience.

**Recommended fix:** deliberately choose a small-lobby policy: lower the HP floor, scale the active timer, provide another earned shard path, and/or decouple onboarding from a crack. Validate one-, two-, three-, and four-player sessions using actual node/core rules.

**Acceptance:** the intended solo/newcomer path can earn its first shards within a documented, achievable session length.

### A08 — P2: a major pickaxe upgrade reverses debris earning power

**Evidence:** `DebrisOre.luau:9–10` pays Frost only for rock tiers 3–4, then returns to Iron at tier 5. `Config/Pickaxes.luau:21–22`, `Config/Debris.luau:11`, and `Config/Home.luau:107–109` determine these values:

| Homogeneous lobby gear | Debris ore | Base value per hit | Theoretical value per swing-second |
|---|---|---:|---:|
| Plasma, tier 4 | Frost | $360 | $765.96 |
| Meteorite, tier 5 | Iron | $37.50 | $85.23 |

**Trigger:** buy Meteorite for $1.2M + 25 shards and allow untouched/respawned rocks to reroll for the new lobby tier. Between-event value per swing-second falls **88.87%**. These values exclude travel, collection, refining bottlenecks, respawn contention, and multipliers; they describe the payout regression, not realized cash per second.

**Recommended fix:** make debris earning power monotonic across tiers or explicitly design and communicate the tradeoff. Test the complete gear/debris payout table.

### A09 — P2: the pacing model no longer represents the committed economy

**Evidence:** `Pacing.luau:76,128,235` and `docs/balance.md:7–10` value debris as Iron, while current tier 3–4 debris is Frost. `Pacing.luau:250–255` awards five shards for modeled events without checking actual core success or core participation. The simulator also assumes a homogeneous lobby and does not establish finite shared-rock availability or actual ore queue mix.

**Sensitivity check:** change only tier 3–4 debris valuation in an in-memory copy of the simulator, retaining all its other assumptions:

| Model output | Committed model | Frost valuation sensitivity |
|---|---:|---:|
| Plasma purchase | 1 h 53 m | 48 m |
| Meteorite purchase | 5 h 20 m | 2 h 30 m |
| Nova purchase | 7 h 08 m | 4 h 26 m |
| Lifetime sales at 1 h | $108,597 | $253,425 |
| Lifetime sales at 2 h | $495,536 | $954,732 |
| Lifetime sales at 4 h | $1,201,702 | $15,990,786 |

These are **illustrative model outputs, not live forecasts**. Their divergence demonstrates why existing passing pacing assertions cannot certify this branch. Also, `Config/Balance.luau:3–4` claims gameplay does not read its assumptions, while `MeteorTypes.luau:147–148` uses hit-share/trip assumptions for real under-tier caps.

**Recommended fix:** derive payouts from shared production rules; model crack/shard eligibility, finite rock supply, mixed-tier lobbies, trip durations, queue priorities, and early event completion. Rewrite `docs/balance.md` around current rules and validate against telemetry.

### A10 — P2 design risk: higher-tier debris grants unrestricted Frost to newcomers

**Evidence:** `DebrisService.luau:59–67,91–93` picks a rock tier from an active player's gear; ore comes from that **rock tier**, not the hitter's tier. `NodeService.luau:234–241` then pays the hitter's ordinary ore-per-hit at the debris multiplier. There is no debris counterpart of the meteor's under-tier valuation/cap.

**Impact:** a Basic player in a mixed lobby receives 0.25 Frost per hit on a cyan rock; four accepted hits bank one $120 Frost instead of $5 Iron. Higher HP does not offset the 24× ore-price difference. The rock is still harder for the newcomer, so this is a catch-up/balance decision rather than free instantaneous money.

**Recommended fix:** decide whether this is the intended catch-up system. If yes, expose and model it; if no, apply hitter-tier payout rules. Test mixed-tier sharing and rerolls.

### A11 — P2 design risk: buying better gear does not guarantee access to its event ore

**Evidence:** `MeteorTypes.luau:49–59,82–85`, `Config/Meteor.luau:54`, and `ActivityService.luau:45–50` require 25% of active players to meet a type's tier. One Drill or Meteorite player among seven Basic players cannot enable Ice or Crystal respectively; weighted picks fall back to an eligible lower type.

**Impact:** a large individual purchase can have little event payoff until other players catch up or the buyer changes servers. The homogeneous pacing model does not simulate that experience.

**Recommended fix:** test mixed lobbies and intentionally choose how individual upgrades pay off under server-wide gating. Communicate that gating, or give eligible individuals a reliable way to benefit without destabilizing newcomers.

### A12 — P2: failed-event tutorial recovery is not taught

**Evidence:** `Config/Tutorial.luau:20` says to keep hitting the core until it cracks; `TutorialController.luau:128–129,249–258` points to the core or next meteor/debris. It does not turn a cooled event into a deposit/refine/collect/sell objective.

**Impact:** combined with A07, novices can repeatedly follow impossible small-lobby crack guidance instead of learning how retained ore generates cash. **This is not a hardlock:** `TutorialService.luau:54–67,70–75,138–160` allows later deposit/collect/sell/purchase actions to complete preceding steps, and supports Skip.

**Recommended fix:** after a cooled event, explicitly lead the player home with their retained ore. Make the home loop available before requiring a successful core reward, while keeping server-authoritative out-of-order progress.

**Acceptance:** a fresh solo player receives a useful next action after the first failed meteor and completes a sale without guessing or skipping onboarding.

## 5. UI, UX, accessibility, and controls

### A13 — P2: the small portrait HUD overlaps movement and shrinks foundry controls

**Evidence:** `HudLayout.luau:155–179`, `HudView.luau:138–145`. At **320×568 touch with inset 58**, the short-portrait branch yields:

- Reserved thumbstick area: `x=0…220`, `y=348…568`.
- Training: `y=284.39…378.14`, intersecting movement.
- Foundry scale: `(348−2−284.3904)/322 = 0.19133`; the 82-unit collapsed summary renders **15.69 px high**.
- Collapsed wallet: `x=12…225.47`, `y=384.14…483.19`, also intersecting movement.

The same viewport is explicitly tested by the newer Shop/Rebirth layouts but is absent from the main HUD test set. These are source/formula results, not a physical-device screenshot.

**Recommended fix:** retain a minimum usable foundry/toggle target and choose which lower-priority cards relocate, scroll, or temporarily hide. Add this viewport with real insets and assert movement/jump clearance after final placement.

### A14 — P2: Index uses whole-panel scaling that defeats touch/readability standards

**Evidence:** `IndexController.luau:295–304,410,489` and `HudLayout.luau:367`. At **844×390 with inset 58**, the fixed 740×520 composition scales to `316/520 = 0.60769`:

| Element | Resulting size |
|---|---:|
| Page-tab height | 24.31 px |
| Tab text | 9.72 px |
| Odds / reward / eligibility text | 7.90 px |
| Mineral title | 10.94 px |

Close is enlarged at `IndexController.luau:474–477`, but the content is not.

**Recommended fix:** use the pixel-based responsive/scrolling pattern already present in Shop and Rebirth. Preserve readable text and at least the project's 44 px touch targets.

### A15 — P2: the returning-player popup has a small dismissal control

**Evidence:** `HUDController.luau:318–328,369–381` scales a 140×36 “Nice!” button with ordinary HUD scale. At 0.7 it is **25.2 px high**, and lacks the Escape/ButtonB dismissal pattern used elsewhere.

**Recommended fix:** fit this panel independently, preserve a 44 px dismissal, and share normal close behavior. Validate long away-time/bar counts and the smallest supported viewport.

### A16 — P2: primary menus do not coordinate state or mining consistently

**Evidence:** `HudView.luau:345–379` only closes Settings through its own buttons and keeps a private `opened` flag. It has no Escape/ButtonB handler or close-on-another-menu listener. Settings DisplayOrder is 10 (`HUDController.luau:298–301`); Shop/navigation is 20 (`ShopController.luau:448–456`), so another primary menu can cover it while `SettingsOpen` remains true.

Separately, `MiningController.luau:365,423,450,460` blocks Shop, Settings, and Refinery but omits Index, Rebirth, and Store. Mobile MINE clears `touchHolding` (`MobileControlsController.luau:79–91`), while direct tool input has a separate `pointerHolding` route.

**Impact:** hidden Settings can keep mining disabled after an overlaid menu closes, while other primary menus can permit continued held-tool mining. Dismissal and focus ownership differ by menu.

**Recommended fix:** introduce a common primary-menu coordinator and gameplay-input-blocked state; cancel both holding modes on transitions. Keep the compact backpack popup nonmodal by design. Reproduce stacking, held input, Escape, and ButtonB sequences before accepting the change.

### A17 — P2: condensed meteor notifications omit the reason and economic outcome

**Evidence:** `RewardService.luau:68–80` sends success state, retained ore/type, under-tier guidance, contribution/rank, and shard components. `HUDController.luau:424–434` renders only the shard/podium message from `HudMessages.luau:36–46`.

**Impact:** a cooled event can show only “0 shards received,” hiding the useful ore the player kept and why rewards were zero. Under-tier players also lose the explanation connecting an equipment upgrade to better mining. The user's requested removal of the old popup does not require deleting that information.

**Recommended fix:** keep the compact stacked notification design, but add appropriate ore/type and cooled/under-tier explanation, with a reviewable recent-results history or enough display time. Retain blue shard numbers and podium colors.

### A18 — P2: players cannot reduce camera shake

**Evidence:** `MeteorFXController.luau:364–376` applies camera rotation during trauma/rumble. `HudView.luau:351` exposes only Training Guide and Meteor Objective settings.

**Impact:** motion-sensitive players cannot disable the game's shake. Audio/effect intensity also has no dedicated in-game control; the absence of an audio slider is a product gap rather than a claim Roblox has no platform volume control.

**Recommended fix:** provide a clear shake/reduced-effects preference and honor it in the render path. Decide persistence and check current Roblox accessibility integration before selecting an API. Validate reduced visuals still communicate impact/core/refreeze state.

### A29 — P3: terminology and affordances do not always describe the actual action

| Issue | Evidence | Recommendation |
|---|---|---|
| Tutorial says SHOP; visible control says GEAR | `Config/Tutorial.luau:24`; `UI.luau:395` | Use the visible name consistently |
| Sell copy points to HUD bars, but the guide searches for a legacy Trading Post; when absent, the step has no world marker/beam | `Config/Tutorial.luau:23`; `TutorialController.luau:136–137`; `EconomyService.luau:78–84` | Teach the currently available sell route |
| Shop Damage is a display number, not node HP loss | `ShopController.luau:323`; `NodeService.luau:224–228,260–261` | Explain it or show meaningful mining power/speed alongside requested damage |
| Generic GEAR icon omits ordinary HUD identification of the equipped tier | Main HUD versus Shop ownership state; spec `:383` | Consider a compact current-equipment status |
| Foundry summary has separate unlabeled icon/body actions | `HudView.luau:138–145` | Add an affordance, tooltip, or tutorial explanation for management versus expansion |

These are presentation shortcomings, not reasons to remove the retained equipment models or requested stats.

## 6. Server security and recovery

### A19 — P2: mining validation omits alive/equipped context

**Evidence:** `NodeService.luau:191–241` validates target, swing cadence, root distance, and target-specific `CanHit`. It does not verify an alive Humanoid or an equipped pickaxe. The normal client does require an equipped tool (`MiningController.luau:423–444`), creating a client/server contract gap.

**Isolated reproduction:** the actual NodeService accepted a swing for a fake actor with `Humanoid.Health = 0` and no tool, reduced HP from 10 to 9, and awarded one ore.

**Recommended fix:** validate loaded gameplay state, alive/equipped context, and any intended line-of-sight restrictions on the server. Test malformed and spammed remotes as well as valid input.

Distance is useful but not complete movement protection: the client's owned character can move in ways the game does not intend. No server movement-history validation was found. Add conservative anomaly checks with explicit shockwave/respawn/legitimate-teleport allowances; do not impose simplistic thresholds that punish ordinary knockback or latency. [Roblox movement/network ownership guidance](https://create.roblox.com/docs/scripting/security/network-ownership), [client/server boundary guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary).

**Limit:** no exploit was attempted against live players or a published server. The isolated context defect is confirmed; broader autofarm/remote-flood resistance remains a validation gap.

### A20 — P2: session-lock recovery and error copy are misleading

**Evidence:** `DataService.luau:22–24` keeps foreign locks fresh for 30 minutes; `:177–190` retries eight times at five seconds, then uses the same “save still open…rejoin in a minute” kick for a foreign lock **or a DataStore error**. There is no handoff request or live-server liveness check.

**Impact:** a server crash or failed release can lock a player out far longer than one minute. An API outage gets a false diagnosis. A lock-lost active server also continues operating on its in-memory profile rather than stopping mutation, amplifying A04's confusing recovery.

**Recommended fix:** distinguish unavailable API, active foreign session, stale/dead session, and lost ownership. Use proven lease/handoff behavior and stop economic mutations when ownership is lost. Improve messages without weakening the protection against simultaneous writes.

**Acceptance:** rapid rejoin, server crash, failed final write, and forced lock loss have tested, understandable recovery paths with no duplicate ownership.

## 7. Monetization and policy readiness

Every committed game-pass and product ID is **0**. The store is off sale, which prevents current purchase prompts. The following issues become relevant when IDs are activated; they should not be described as presently affecting paying customers.

### A21 — P2 activation blocker: receipt grants are not fully replay-safe

**Evidence:** `MonetizationService.luau:183–200,216–228`; `Config/Monetization.luau:110–111` retains only 50 receipt IDs.

Two isolated failures were reproduced using the actual service and fake purchase/save/notice boundaries:

1. Grant an Overclock receipt, fail its save, then process 50 newer receipts successfully. The pending original ID is evicted although its grant persists. Retrying it adds another **1,800 seconds**.
2. Throw from `Notice:Fire` after `overclockLeft` is incremented but before the receipt is appended. The first call leaves 1,800 seconds and no remembered ID; retry leaves **3,600 seconds**.

Roblox can replay pending receipts on later purchases/rejoins and does not guarantee an order among pending receipts. [MarketplaceService ProcessReceipt](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt).

**Recommended fix:** make durable grant mutation and receipt recording replay-safe together, retain a durable PurchaseId ledger or equivalent scheme, and isolate notification/telemetry effects afterward. Test delayed acknowledgement, concurrent callbacks, exceptions at each boundary, and more than 50 newer receipts. Integrate with fixes for A02–A04.

### A22 — P2 activation blocker: ownership failures become definite nonownership

**Evidence:** `MonetizationService.luau:145–164` warns on `UserOwnsGamePassAsync` errors but still marks the session resolved with failed passes absent. No retry is scheduled. `WaitForPasses` at `:90–95` has a timeout. `RefineryService.luau:401–413` advances `lastSeen` before waiting and applies catch-up using the entitlement state then available.

**Impact:** an actual owner may lose their effect for the session. The extra offline processing interval is not retried after the free cap is applied and `lastSeen` moves forward; remaining hopper ore is retained and can refine later. The profile does not preserve a processing-time debt for unresolved offline entitlement.

**Recommended fix:** represent unknown versus unowned separately, retry transient errors, and preserve unapplied catch-up until reliable entitlement resolution. Test errors and responses later than the wait timeout.

### A23 — P2 design risk: products can give little or no practical benefit

**Evidence:** `Lib/Refining.luau:48–54`, `RefineryService.luau:439–446`, `Config/Home.luau:41–48,55–75,83–98`, `Config/Monetization.luau:82–83`.

- Starting Overclock: line output rises from `min(0.3,0.25)=0.25` to `min(0.3,0.5)=0.3` bars/s — **20%**, despite doubling the internal refinery rate.
- Refinery level 2 plus conveyor level 1: line output stays **0.3**, so the same product produces no extra bars.
- Overclock time drains with an empty hopper or full collector.
- Starting free offline cap produces up to 1,800 Iron bars ($9,000); the eight-hour pass is limited by 2,000 stock/bin capacity ($10,000). At a 0.75 bar/s line, that same stock/capacity lasts about 44.4 minutes, so more hours add nothing without capacity upgrades.

The descriptions refer to refinery speed and “up to” offline hours, so these are **quantified value/discoverability risks**, not an established false-advertising finding.

**Recommended fix:** show the buyer's actual current line gain, blockers, and idle-time behavior, or redesign the boost to affect meaningful throughput. Make capacity dependence clear before enabling sales.

### Policy implementation assessment

`PlayerPolicyService.luau:25–39` calls `PolicyService:GetPolicyInfoForPlayerAsync`. `Lib/PlayerPolicies.luau` normalizes responses, retries, conservatively defaults restricted actions on failure, and prevents departed-player callbacks from republishing stale policy. Current trading and paid odds modifiers are absent.

**No confirmed current paid-random-item violation was established.** However, activating a paid meteor trigger that creates access to random index rewards requires a product-specific review of direct/indirect paid randomness and integration of policy gates where applicable. Unchanged per-hit odds alone do not establish a universal exemption. [Roblox paid random items guidance](https://create.roblox.com/docs/production/monetization/paid-random-items).

## 8. Models, map, streaming, performance, and asset delivery

### A24 — P2 validation gap: the current visual envelope is not performance-certified

**Committed scene inventory:** `MeteorShift-backpack-foundry.rbxl` contains **1,949 Map BaseParts**, including **434 UnionOperations** and **75 MeshParts**, with **20 plots** and **60 debris roots**. Its production template has **384 descendants** per cloned line. Twenty occupied plots can therefore add 7,680 station descendants before other runtime content, although not all descendants are physical/rendered parts.

The 1,071 Map parts marked `MapArtOwned` in that file were anchored and had collision, touch, query, and shadow casting disabled. This is good practice. The running scene includes event/plot runtime objects, so its larger counts must not be confused with the saved baseline. All four live node-piece prototypes use `PreciseConvexDecomposition`, corroborated by `tools/map-art/ClosedMeteorPass.luau:44–45`.

**Source strengths:** `Config/Net.luau:7–20` limits snapshots/floaters/chunks/spark pools; `HomeController.luau:23–26` caps belt chunks and distances; `Config/LandingFX.luau:5–6,28` sets per-event/build budgets and mobile reductions. Streaming is enabled. Persistent CSG assets avoid the earlier ephemeral EditableMesh serialization problem.

**What is missing:** representative measurements of frame time, GPU time, draw calls, memory, join time, server frame cost, and cleanup over repeated events at the intended player cap. Pure part-budget tests are not those measurements. High-precision collision is justified by the no-gap crust, but still needs profiling at scale. [Roblox performance guidance](https://create.roblox.com/docs/performance-optimization/improve).

**Recommended fix:** benchmark an exact clean release artifact on a low-end physical phone and representative desktop, with 20 active miners, occupied plots, Iron/Ice/Crystal effects, repeated respawns, and a long-session soak. Establish device-specific budgets, then optimize the measured bottleneck. Do not replace all collision with boxes or disable streaming without gameplay tests.

**Hardware limit:** the previously reported instant black-screen/reboot is not diagnosed by this audit. No stress test or evidence attributes that operating-system failure to a specific game script, model, GPU, or power supply.

### A25 — P2 conditional defect: the own-plot beacon does not recover from late streaming

**Evidence:** `HomeController.luau:65–77` returns if the plot/pad is absent. `:334–341` reruns `showBeacon` only on initial startup and `PlotId` changes; later streamed plots are handled by `watchPlot`, not beacon reconstruction. A streamed-out/replaced pad also has no explicit beacon rebind.

**Trigger / impact:** PlotId arrives before its pad streams in, or the pad streams out/in under device memory pressure. The “YOUR PLOT” beacon can remain missing while the player's assignment is unchanged.

**Recommended fix:** retry/rebind when the relevant plot/pad appears and clear/recover on stream-out. Use bounded stream-aware requests only where needed. Validate outer-plot navigation and respawn on actual constrained clients. [Roblox streaming guidance](https://create.roblox.com/docs/workspace/streaming).

### A26 — P2 validation gap: cold-start asset permissions and recovery are not a release gate

**Evidence:** `Config/HudIcons.luau:5–25` depends on uploaded image IDs; `Config/Sounds.luau:20–34` uses external audio IDs; imported fern meshes/SurfaceAppearance remain part of the art pipeline. `Sfx.luau:101–116` preloads audio asynchronously and suppresses the preload error through `pcall`, without reporting failed IDs or retrying.

**Impact:** a development account/cache can conceal missing permissions, moderation changes, failed texture packs, or asset delivery problems. This audit did not establish that any current ID is invalid; the earlier authentication error alone is not evidence of an asset defect.

**Recommended fix:** run a clean-cache published client under a noncreator account, verify every critical HUD/model/audio asset, and record failures. Use bounded retry/fallback/reporting for critical content; avoid blocking the entire game on optional sound loads. Verify asset provenance and permissions in the intended owning experience.

### Map/model checks that passed or remain limited

- Saved-map decorations checked above were anchored and noninteractive; no unanchored Map BaseParts were found in the five decoded places.
- The current Studio read-only voxel check found **0 Grass cells inside radius 160** across 8,424 occupied samples, and **0 Fern instances inside radius 160**. This is current-scene evidence, not proof that every historical checkpoint has identical terrain.
- Saved/live meteor cores have 36 node slots. The existing coverage authoring check is documented in `tools/map-art/README.md:15`; its 145,800-ray assembly test was **not rerun** during this audit because it creates temporary geometry and the user's Play session was left running.
- No fresh player-height screenshot was obtained: the screen-capture request did not complete and was cancelled. This report therefore does not invent newly observed clipping, grass, model gaps, or visual composition defects.
- Lune warned about an unsupported `Terrain.VoxelGridAssetContentMap` property and could not read some newer mesh/collision properties. Binary inspection was read-only; no place was reserialized. Terrain correctness, asset loading, collision shape, and triangle/draw-call budgets require Studio/device checks beyond the parser inventory.
- Teleport has icon source files but no tracked controller/button/action. `assets/hud/teleport-icons/README.md:17` explicitly says the exports do not add a button. This is feature inventory, not proof that every production game needs teleportation.

## 9. QA, operations, analytics, and long-term quality

### A27 — P2: the passing suite is not a production integration gate

**Evidence:** `tests/Runner.luau:140–159` runs `*.spec` modules; tests primarily cover pure rules/layouts. The standalone `DebrisService.regression.luau` and ad hoc `.tmp` service fixtures are not automatically included by that naming filter. There is no committed `.github` CI workflow or documented clean release validation pipeline.

**Impact:** 248 passing specs coexist with A01–A04 and A07 because the relevant artifact, concurrent provider, and end-to-end progression paths are not covered. Compilation also does not substitute for strict type/lint analysis.

**Recommended fix:** create a reproducible automated gate covering pure specs, syntax/type checks, isolated service contracts and failures, executable-instance allowlisting, canonical source/asset parity, multiplayer smoke, and a fresh-profile economy loop. Keep physical-device and long-session performance checks as separate required evidence.

### A28 — P3: failed lifetime milestone logs disappear permanently

**Evidence:** `TelemetryService.luau:60–65,123–131` catches analytics errors but sets the saved milestone flag before delivery. A failed first meteor/core/refinery event is never retried; further errors for that method become silent after one warning.

**Impact:** outages can bias onboarding/retention dashboards and make first-session changes harder to evaluate. Gameplay completion should remain independent of whether telemetry succeeds.

**Recommended fix:** distinguish gameplay milestone state from telemetry delivery, add bounded retry/queueing, and verify ingestion in the actual dashboard. Add operational counters for save failures, lost locks, profile load duration, missing plots, receipt retries, and asset failures.

### A30 — P3 design/validation gap: long-term motivation is mostly numerical

**Evidence:** current content consists of three meteor types, eight pickaxe/backpack tiers, four station upgrade tracks, the mineral index, and repeated rebirths. The index's rarest drops require rich nodes at 1/2,500 odds (`Config/Index.luau`); only three crust nodes per event are rich. Expected acquisition is 2,500 eligible rich hits, not 2,500 events. The exact number of sessions depends on tier, targeting, lobby, and success.

Plots have useful production progression and stock presentation, but freeform décor/personalization rewards remain absent; `Lib/ProfileTemplate.luau:25` stores décor and the spec's décor promises are not a shipped system. No live retention evidence establishes that later numerical tiers, rare collection, and rebirth alone remain engaging through the modeled multi-hour progression.

**Recommended direction:** validate the current loop before adding scope. Consider visible intermediate collection/plot goals, tangible milestone rewards, and more choices in production or event participation. Keep these optional improvements separate from the release blockers. Measure first-sale, first-upgrade, first-shard, return behavior, and abandonment by lobby size/gear tier.

### A31 — P3: release documentation and repository organization are inconsistent

**Evidence:** README/repository use MeteorShift, branch marketing masters use Craterworks, and current owner branding is Craftworks. README still describes upgrade prompts/results/trading-post routes that current source has changed. The branch includes `.tmp` scripts, duplicated saved places, and a downloaded Lune executable/ZIP without a release-manifest convention.

**Impact:** ownership handoff, asset selection, reproduction, and release review become error-prone. Scratch tooling is useful as a checkpoint, but should not be mistaken for supported production input.

**Recommended fix:** align player-facing naming and docs with the chosen brand; designate canonical art/place inputs; put QA tooling under a maintained command structure; retain historical backups clearly; pin runtime/tool versions and licenses. Do not delete useful checkpoints until their purpose and recovery path are documented.

## 10. Verified strengths to preserve

- **Server-owned economy:** clients cannot submit sale prices, payout quantities, owned equipment tiers, or another player's inventory. Shop/upgrade prices and sequential tiers are rechecked before mutation.
- **Inventory separation:** carried bars, collector stock, hopper ore, and backpack ore are distinct; selling does not prematurely sell stored collector inventory.
- **Production rules:** queue validation, conservation, collector/hopper caps, priority ordering, and idle-capacity behavior have pure coverage.
- **Rebirth safeguards:** server affordability checks, two-press client confirmation/expiry, and actual reset rules retain refinery level, shards, index bonuses, purchased value, and relevant history. Fractional mining carry is reset.
- **Responsive progress:** Shop and Rebirth use pixel-sized controls/scrolling rather than uniformly shrinking their full composition. Preserve the retained models and requested pickaxe/backpack stats.
- **Backpack popup:** compact, nonmodal, explicit empty state, and actual inventory rows rather than undiscovered ore placeholders.
- **Mining/network budgets:** target IDs, range/cadence checks, batched HP/state, bounded floaters/chunks/sparks, and client effect cleanup provide a sensible baseline.
- **Plot presentation:** meaningful upgrade silhouettes, visible stock, input/output belt payloads, and capped nearby-only conveyor effects.
- **World art:** editable Blender sources, persistent CSG solids, reusable mineral/rock prototypes, and noninteractive decoration flags.
- **Policy baseline:** conservative normalized policy data and departed-player cleanup; current zero product IDs prevent accidental activation.
- **Tutorial resilience:** saved server-authoritative steps, explicit Skip, and later-action bypass prevent a strict dependency hardlock.
- **RichText hygiene:** notification formatting escapes dynamic text rather than treating names/messages as markup.

## 11. Verification performed

| Check | Result | What it does and does not establish |
|---|---|---|
| Git target / scope | HEAD `8dc1f8d` on `job-for-tomorrow`; tracked source clean at start | New uncommitted marketing excluded |
| Live source parity | 110 tracked source/spec files matched normalized bytes + rolling checksum | Establishes source parity in current Studio containers, not a published-release certificate |
| Studio pure suite | **248 passed, 0 failed** | Pure rules/layouts; temporary clones were removed by Runner; no player profile mutation |
| Syntax compile | **110 compiled, 0 failures** | Modules compiled without executing them; not static type analysis |
| Isolated economy slice | 75/75 pure checks; 22/22 refinery/queue; 12/12 policy plus service smoke | Overlaps the full suite; do not add these counts to 248 |
| DataStore startup failure fixture | Non-Studio memory profile, successful-looking save, 0 durable writes | Confirms A02 without calling real DataStores |
| Lock-loss status fixture | Unrelated successful write still reported false | Confirms A04 |
| Save completion-order fixture | Final cash 200 reverted to100; released lock restored | Confirms A03 under controlled provider ordering |
| Mining context fixture | Dead, unequipped actor accepted; HP10→9; 1 ore awarded | Confirms A19 without live remotes |
| Receipt replay fixtures | Evicted pending receipt and post-grant notice exception both duplicate grant | Confirms dormant A21 against actual service with fake boundaries |
| Saved-place inventory | Five committed places decoded read-only | Found source divergence and enabled QA script; parser limitations noted above |
| Current grass / fern check | 0 central Grass samples; 0 central Fern instances | Current Studio scene only |
| Small-screen layout arithmetic | Exact portrait/landscape branches reproduced | Confirms dimensions; not physical touch/gamepad usability |
| Screenshot / load benchmark | Not completed / not performed | No new rendered visual or performance certification |

Read-only or isolated evidence helpers are retained locally under `.tmp/audit-*` for this review. They are not part of the audited commit or production source. No real purchase, rebirth, save, currency grant, load stress, publication, branch mutation, or push was performed by the audit.

## 12. Release test matrix

| Area | Required scenarios | Exit evidence |
|---|---|---|
| Clean candidate | Rebuild/open canonical place; verify 110 sources plus packages/assets; inspect all executables; no QA markers | Source/asset manifest and clean re-opened file |
| Profiles | New/existing v1/v2; malformed record; future schema; API outage; rapid rejoin; crash/stale lock; lost ownership | No silent memory fallback, no data rollback, controlled failures |
| Saves | Concurrent autosave/purchase/release; provider retry/reordering; failed final write; shutdown with releases in flight | Monotonic durable revision and correct status |
| Capacity | 20 admissions; 21st attempt; freed-plot retry; actual dashboard cap | Every admitted player has a usable production line |
| First session | Solo / two / three / four Basic players, successful and cooled event, full backpack | Achievable first sale/upgrade/shard; useful tutorial recovery |
| Economy | All gear tiers; mixed lobbies; finite rock contention; queue mixes; rebirth with old offline work pending | Current model matches rules and calibrated telemetry |
| Purchases | IDs enabled only in a controlled candidate; save failure; exception after mutation; replay after50+ purchases; reconnect; concurrent receipts | Durable exactly-once value; entitlement uncertainty handled |
| UI / devices | 320×568, 360×640, 390×844, 844×390, 1024×768, 1920×1080; inset changes/notches; large text/numeric values | Readable content, required touch targets, movement/jump clearance |
| Input | Mouse hold+menu; multitouch; orientation change; tool unequip/death; keyboard; gamepad focus/scroll/return | Consistent blocking/release and reachable controls |
| Streaming | Plot absent initially; stream-out/in; far-plot travel; respawn; missing meteor descendants | Beacon/targets recover; no indefinite startup wait |
| Assets / audio | Cold cache, noncreator published client, permissions, failed optional downloads | Critical assets load or fall back; actionable failure reports |
| Performance | Intended max population, occupied plots, all meteor types, low/high graphics, physical low-end phone, repeated events, long soak | Agreed frame/memory/server/join-time budgets; no accumulation |
| Operations | Dashboard funnel/economy ingestion; saves/locks/receipt/asset errors; rollback/version traceability | Actionable metrics and tested recovery runbook |

Gamepad readiness is **unverified**, not proven broken: several menus support ButtonB, but no explicit initial `GuiService.SelectedObject` management/selection confinement/restoration was found. Validate platform settings and every menu before advertising console support. Localization expansion and visual/readability checks with actual users are also outstanding.

## 13. Recommended implementation order

### Wave 1 — protect data and establish a trustworthy release candidate

1. A01: remove/guard saved-place QA and introduce an executable allowlist.
2. A02–A04: fix durable profile initialization, serialized/revisioned saves, release retries, and operation-local status.
3. A05–A06: align capacity and produce one clean canonical artifact with source/asset parity.
4. Add the corresponding isolated failure and artifact checks to the repeatable QA gate (A27).

**Exit:** no destructive QA, no unsaved production sessions, no rollback/poisoned status, and every admitted player can use a line.

### Wave 2 — make the early game achievable and the model truthful

1. A07/A12: validate solo/small-lobby shard progression and failed-event onboarding.
2. A08–A11: choose consistent debris/tier/lobby rules and rebuild pacing from those rules.
3. A17/A29: explain event outcomes and align the tutorial with visible actions/stats.

**Exit:** observed first-sale/first-upgrade/first-shard sessions match an explicitly documented product target across lobby sizes.

### Wave 3 — mobile/input/accessibility and world reliability

1. A13–A16/A18: preserve touch/readability, coordinate menus and held inputs, and add reduced shake.
2. A19/A25: validate mining context and stream-aware guidance/recovery.
3. A24/A26: complete device/load/cold-asset checks and optimize measured bottlenecks.

**Exit:** physical-device and representative-load evidence supports the enabled platforms.

### Wave 4 — activate paid features only after value and replay validation

1. A21/A22: durable replay-safe grants and reliable entitlement/offline recovery.
2. A23: disclose or improve actual boost/capacity value.
3. Review policy applicability to the final paid products and verify analytics ingestion (A28).

**Exit:** paid value is accurately presented and survives failures/replays; only then set real IDs.

### Wave 5 — polish and retention work

Align branding/docs and consolidate supported tooling (A31), then evaluate tangible plot/collection goals using real retention data (A30). These improvements should not delay fixing the data and first-session blockers.

## 14. Production acceptance checklist

- [ ] No enabled QA or unexpected executable instances in the shipped place.
- [ ] Production cannot silently fall back to nonpersistent profiles.
- [ ] Saves are ordered/replay-safe, accurately reported, and recoverable on release/shutdown.
- [ ] Canonical source, world assets, player cap, and published version are traceable.
- [ ] Every admitted player receives a functional plot or an explicit controlled recovery state.
- [ ] Fresh solo/small-lobby progression and tutorial outcomes are achievable.
- [ ] Debris, meteor, equipment, queue, rebirth, and offline rules agree with the balance model.
- [ ] Supported touch/input/platform layouts pass real-device interaction tests.
- [ ] Streaming, critical assets, and event cleanup recover under representative conditions.
- [ ] Intended player/device performance envelope is measured rather than inferred from part counts.
- [ ] Paid features remain off sale until receipt, entitlement, policy, and value checks pass.
- [ ] Analytics/error signals and rollback procedures are verified against the actual release.

This checklist is a recommended release gate. The audit itself does not implement or mark these fixes as complete.
