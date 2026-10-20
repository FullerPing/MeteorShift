# 01 — Server gameplay, remotes / security, server events, scaling

Auditor: server subagent (read-only), spot-checked by lead (A1 and A12 re-read and confirmed).
Scope: `src/server/**` except DataService and the receipt path (see `04-…`), plus the shared rule modules they call.

**Headline:** no P0. Every client remote is rate-limited (`RequestGate` or a local throttle), type-checks its
arguments, reads amounts and prices from the server profile, and never yields between check and mutation.
The open problems are (1) background loops that die permanently on one error, (2) reward farming (one tap, alts,
mixed lobbies), and (3) network volume as the server fills up.

| ID | Sev | Area | Where | Finding | Fix | Conf. |
|---|---|---|---|---|---|---|
| A1 | P2 | Robustness | `RefineryService.luau:322-357` | Online production tick is a bare `while true` with no `pcall`. One throwing profile (e.g. `Line.station(id, nil)`, already guarded against in `PlayerStateService.luau:221`, so it has happened) kills refining **and** the Overclock / Ore Rush countdowns for the whole server until restart. | `pcall` each player step like `PetService.luau:334`. | high (mechanism) |
| A2 | P2 | Robustness | `ContributionService:149`, `DebrisService:310` (locked-field eject), `CrownService:111` (Crown eject), `TutorialService:101`, `LeaderboardService:172`, `WorldBoundaryService:12`, `DailyService:241`, `MonetizationService:509`, `TelemetryService:450` | Same pattern. Several of these **enforce gates** (Crown / locked-field eject, boundary kill): one error and the gate is open until restart. | One `safeLoop(name, interval, fn)` helper that pcalls each pass. | high (mechanism), low–med (likelihood) |
| A3 | P2 | Rewards / alts | `Lib/Rewards.luau:43-47, 70-74`, `ContributionService:67-74` | One core tap = `HitCore`, which earns the 5-shard floor plus a share. The bonus pool is `8 × #hitters`, so every alt that taps once adds 8 shards to the pool (mostly to the main) and pockets 5. Last-second joiners and auto-clickers get the floor too. | Minimum core contribution share (2–5 %) for the floor and pool; size the pool by core Mining Power, not head count. | high |
| A4 | P2 | Economy | `DebrisService:90-102, 184-195`, `Shared/DebrisField.luau:26-31` | Debris rock HP is sized from a **random** active player's pickaxe, but the cash paid is the **breaker's** own income-per-second × seconds. A veteran in a newcomer lobby one-shots soft rocks for 3–9 s of their income per swing. The comment at :182 claims the opposite. Not in Pacing. | Pay `cash × min(1, rockMaxHp / (Hits × breakerPower))`, or size rocks for the strongest active pickaxe. | medium (size unmeasured) |
| A5 | P2 | Scaling | `PetService:59-67, 311-314`, `LevelService:70`, `NodeService:356` | Pet "Working" FX are `FireAll` on every hit: up to ~20 events/s per mining player, so at 20–30 miners each client gets hundreds of events/s for cosmetics. | Fire only to players within ~150 studs, or replicate a role+time attribute. | high (mechanism), medium (volume) |
| A6 | P2 | Scaling | `PlayerStateService:257-297, 381`, `RefineryService:351` | The whole State snapshot (pets, mineral index, hopper/bin/bars, line stats; ~1.5–3 KB) is rebuilt and sent ~5×/s while mining, plus 1×/s just because line `progress` moved. `PetBackpackFraction` (replicated to everyone) changes at 5 Hz. | Split into a hot snapshot (backpack, cash, progress) and a cold one sent on change. | medium (size estimated) |
| A7 | P3 | Exploit | `NodeService:279`, `Config/Meteor.luau:60` | `SwingTolerance = 0.8` is accepted on **every** swing: a modified client gets a permanent +25 % to power, ore, XP and contribution. | Token bucket: allow single-swing jitter, hold the average to 1/Swing. | high |
| A8 | P3 | Exploit | `NodeService:303`, `WorldMap.luau:60-67`, `CrownService:55` | Reach, refinery proximity and the dive pad trust the client-owned `HumanoidRootPart.Position`; teleporting passes. | Genre-typical. Optional cheap speed sanity check. | high |
| A9 | P3 | Meteor sizing | `ActivityService:74-87` | Any `Ping` keeps a player "active" for 120 s and joiners start active, so AFK or anti-idle players inflate meteor HP without adding power. | Count validated swings only. | high |
| A10 | P3 | Fairness | `MeteorService:346-360, 477-481` | One hit on the Golden Node earns the full assist lumps. | Minimum power share. | high |
| A11 | P3 | Events | `MeteorService:483-491` | `_crustBonuses` runs before `CrustBroken += 1` and the unlock check; a throw leaves the core locked and the event cools. | Count, hide and unlock first; pcall the bonuses. | medium |
| A12 | P3 | Rewards | `LevelService.luau:72-76` | Gaining several levels at once (crack XP) opens **one** Supply Crate; the header promises one per level. *(Lead confirmed.)* | Loop `gained` times. | high |
| A13 | P3 | Data | `PlayerStateService:127-132, 371-379, 431-447`, `RefineryService:111-119` | Capacities are fractional, so backpack, hopper, bin, bars and `barsSold` collect fractions like 0.4 ore. | `math.floor` capacity or space. | high |
| A14 | P3 | Stats | `RewardService.luau:77-79` | `coresCracked += 1` also counts consolation rewards on cooled meteors (badges and telemetry read it). | `if reward and cracked`. | high |
| A15 | P3 | Gates | `DebrisService.luau:230` | If `Map.Gates` is missing, every level and rebirth field gate opens (fail-open). Present today. | Fail closed on v3 maps. | high |
| A16 | P3 | Monetization | `PetService.luau:149-159` | Pass pets (Drillbot, Solar Phoenix) are never taken back after a refunded or revoked pass. | In `SyncPassPets`, once passes have resolved, drop pass pets whose pass isn't owned. | high |
| A17 | P3 | Admin | `Lib/Admins.luau:7-9`, `AdminGive.luau:41-47, 139` | The admin list is one hard-coded id `3245458673 = "FullPinger"`, the same account the Studio test session ran as, so it's the owner. `/give all cash 1e308` passes as finite and can overflow to `inf` with multipliers. | Confirm the id; cap gifts at ~1e30. | med / high |
| A18 | P3 | Memory | `LeaderboardService:28, 119-121`; `ShopService:260, 286`, `PlayerStateService:482`, `TutorialService:163` | `saved[board][userId]` is never cleared; per-character connections are never disconnected. These only matter over a 24 h server if the place doesn't destroy Player/Character on leave. | Clear on leave; enable `PlayerCharacterDestroyBehavior`. | medium |

## Checked and found solid
- **Remote validation:**
  - `Swing` rejects non-integer, NaN and infinite ids.
  - Shop and Upgrade clamp `count` and handle NaN.
  - `SetPriority` checks for a dense array of known ids.
  - `TravelTo`, Codes, Daily, Perk, Pet and the Telemetry menu inputs are type- and length-checked.
  - `SetFastWalk` takes only a boolean.
- **Affordability:** Evolve, Upgrade, BuyLine, Hatch, Perk and Rebirth re-check against the profile with no yield before charging.
- **Signals:** no server listener on any server→client signal. The only client→server signal (`MenuOpened`) is whitelisted and capped.
- **Studio gates:** every Dev* hook and attribute checks `IsStudio()`. On a live server, chat commands go through `Admins.can`.
- **Meteor state machine:**
  - `_runEvent` is pcall'd with cleanup, and events can't overlap.
  - A player who leaves mid-event drops out and HP rescales; 0 players falls back to the floor size.
  - Calls are allowed only during Countdown, with a cooldown and an hourly cap.
- **Codes and daily rewards:** codes are marked redeemed before paying out, and daily claims are idempotent.
- **Credits and offline time:** the Keep Everything credit is spent before the reset, and offline catch-up uses `lastSeen` correctly.
- **DataStore budget:** leaderboards make about 2 SetAsync per player per minute, well inside the limits.
