# Meteor Shift — Game Spec (MVP)

**Status:** Draft v2 · 2026-09-27 (v2: inflated economy, millions → billions)
**Platform:** Roblox, built with Rojo + Luau
**Repo:** https://github.com/FullerPing/MeteorShift
**Source of truth:** Rimgaudas's design description (project thread "Meteor Shift game spec").

Anything marked **[A]** is an assumption: the design description is silent there, so a sensible default was picked. Every number in the tuning tables is a starting value to be balanced in Week 5, and lives in a config module, never in gameplay code.

> Naming: the design calls the game **Meteor Shift**; the project topic says "Meteor City". This spec uses Meteor Shift. **[A]**

---

## 1. Pitch and pillars

You live in a small crater-town mining colony. Every few minutes a meteor slams into the crater and the whole server rushes to mine it before it cools. In between, you haul ore home, run refineries, upgrade and decorate.

**The feel:** a server-wide gold rush every few minutes, with a calm, cozy base-building rhythm in between. "One more meteor."

**Pillars (use these to settle arguments):**

1. **The meteor is the game.** It must feel exciting from day one: countdown, streak, impact, shockwave, crowd rush, core crack, announcement.
2. **Nobody loses at the meteor.** Per-player drops (no stealing) and a participation floor on core rewards mean newcomers always get something.
3. **Home is calm and pays you back.** Refineries work while you're away (capped), which is the main reason to return.
4. **No paid randomness, ever.** Nothing purchasable changes odds. No lucky-meteor boosts, no ore crates.

---

## 2. Server and world

| Item | Value |
|---|---|
| Max players per server | **20** (design says 15–20; start at 20, drop to 16 if performance testing in Week 5 demands it) |
| World | One crater town: central impact crater, ring of player plots around it, town square with shops |
| Plots | 20 plots on a ring around the crater, ~20–30 s run from crater rim to the farthest plot **[A]** |
| Plot assignment | Free plot assigned on join; player's saved base is loaded onto it; plot cleared on leave **[A]** |

Reference point from the design: Build the Pyramid allows up to 50 players per server. We deliberately stay at 15–20 for performance and readability.

---

## 3. Core loop

```
 ┌──────────── countdown in the sky ────────────┐
 │  mine debris around town, upgrade, decorate  │
 └──────────────────────┬───────────────────────┘
                        ▼
            IMPACT (shockwave, knockback)
                        ▼
   METEOR EVENT: mine crust nodes → ore to backpack
   crack the core before it cools → Core Shards
                        ▼
   carry ore home → hopper → refineries → bars
                        ▼
      sell bars → cash → pickaxe / backpack / refineries
                        ▼
              next countdown (repeat)
```

Long-term: mineral index (collection), new meteor types, rebirth ("Relocate the Colony").

---

## 4. The first session

1. Player spawns in town with a **Basic Pickaxe** and an empty backpack. A countdown in the sky shows the next meteor.
2. **First meteor about two minutes away.** A new player's first wait is the server's current countdown; if that is more than 2:30 **[A]**, the tutorial points them at debris and the shop to fill time. (If analytics show many first-session players leaving before their first meteor, shorten the global countdown; see §15.)
3. Tutorial prompts: mine debris → watch the meteor land → run to the crater → mine a node → hit the core → collect shards → go home → drop ore in the hopper → watch the refinery make a bar → sell → buy something.
4. Goal of the first session: every new player gets a **core reward** and **buys their first upgrade** within ~10 minutes.

---

## 5. The meteor event (Week 1)

### 5.1 State machine (server-authoritative)

| State | Duration | What happens |
|---|---|---|
| `Countdown` | 4:00 between events **[A]** | Sky timer counts down. Last 10 s: meteor streak visible in the sky, rumble, camera shake ramp. |
| `Impact` | ~3 s | Meteor lands in the crater. **Shockwave: knockback only, no damage.** Crater area cleared of players by the push. |
| `Active` | **2:30 cooling timer** (design: 2–3 min) | Crust nodes are mineable. Core becomes vulnerable once enough crust is broken (5.3). |
| `CoreCracked` | ~5 s | Core break effect, rewards granted, top three announced. Event ends early. |
| `Cooled` | ~5 s | Timer ran out: meteor turns to inert rock, no core rewards. Ore already mined is kept. |
| `Cleanup` | ~5 s | Meteor removed, results panel shown, next `Countdown` starts. |

Full cycle ≈ 7 minutes. Interval and cooling timer are config values; private servers can change the interval (§12.4).

### 5.2 Meteor construction

- Built from **reusable node pieces**: a core model plus N crust nodes placed on attachment points around it. Variety comes from recoloring, materials and effects.
- **Crust nodes:** ~30–40 per meteor (keep it reasonable for performance). Each has HP.
- **Core:** one per meteor, large HP bar visible to everyone.

### 5.3 Node and core HP (mixed-progression lobbies)

A lobby is almost never in sync: a first-session player with the Basic Pickaxe (5 damage) mines next to a rebirth-5 veteran with the Cosmic Pick (2.8K damage). If node HP were raw damage, the veteran would do ~900× the newcomer's work per second and the newcomer's hits would be meaningless. So the event runs on **Mining Power** instead of raw damage. **[A]**

**Displayed damage vs. Mining Power.** Every hit still pops the big inflated damage number, and ore per hit still comes from your own pickaxe (that's where progression pays off: money). But node and core HP are measured in Mining Power, which grows slowly with tier:

```
power(tier)  = 1.25 ^ (tier − 1)      -- tier 1 = 1.0, tier 4 ≈ 2.0, tier 8 ≈ 4.8
powerPerSec  = power(tier) / swingTime
```

So a maxed veteran clears nodes about **8× faster** than a newcomer (4.8× power × faster swings), not ~900×. Veterans feel strong; newcomers visibly chip nodes.

**Sizing at impact:** HP is set from the *active* players only, so AFK players don't make the meteor impossible for everyone else.

```
active       = players with any input in the last 2 min (idle ones excluded)
serverPower  = sum over active players of powerPerSec
serverPower  = max(serverPower, floorPower)   -- floorPower = 4 basic players, so tiny lobbies still get a real meteor
crustHP      = serverPower × 70 s × type HP multiplier   (split evenly across crust nodes)
coreHP       = serverPower × 45 s × type HP multiplier
coreUnlock   = 60% of crust nodes broken (core glows and becomes hittable)
```

**Mid-event joins and leaves:** whenever the active set changes by more than 15%, the server rescales the *remaining* HP of every node and the core to the new serverPower, keeping the same percentage done. If half the lobby leaves, the meteor softens instead of cooling out of reach; if a crowd joins, it doesn't get trivially shredded. Rescales happen at most once every 10 s and never push a node back above what it had.

**Contribution** (5.5) is also counted in Mining Power, so a newcomer who mines the whole event earns a fair shard share next to a veteran.

With 2:30 on the clock this leaves ~35 s of slack if most of the active lobby participates, and a real risk of cooling if only a few do, which is the urgency the design asks for.

### 5.4 Mining and per-player drops

- Each swing on a node: server validates, deducts HP, and adds ore **directly to that player's backpack**. Drops are per-player, so nobody can steal them.
- Ore per hit = `pickaxe.orePerHit × (2 if 2x Ore pass)`, of the meteor's ore type at full rate if your pickaxe tier meets its required tier, otherwise a scaled share of it (§8.1).
- Visuals: ore chunks fly from the node to the player, rendered **only on that player's client**.
- **Full backpack:** hits still deal damage and count for contribution, but yield no ore; a "Backpack full" prompt suggests running home. This is the first bottleneck by design.
- Broken crust nodes don't respawn during the event.

### 5.5 Contribution tally (server-side)

- Every validated hit adds the hit's **Mining Power** (not its displayed damage) to the player's contribution for this event, so progression gaps don't shut newcomers out of shard rewards. Core hits count **×2** **[A]** so going for the core matters.
- Tally lives only on the server; clients get a throttled view (their own rank and the top three).

### 5.6 Core rewards (Core Shards)

When the core cracks, **every player who hit the core** gets Core Shards:

```
floor        = 5 shards                           (participation floor)
bonusPool    = 8 × numberOfCoreHitters × meteor type shard multiplier (§8.1)
shards_i     = floor + round(bonusPool × contribution_i / totalContribution)
top 3 bonus  = +10 / +6 / +3 shards, names announced server-wide
```

- The floor guarantees newcomers always get something.
- Contribution counts crust + core Mining Power (core ×2), so haulers who mined crust and then hit the core once still get a fair share.
- If the meteor cools before the core cracks: no shards, ore kept.

**Core Shards use [A]:** a second currency spent on higher-tier upgrades (4th+ refinery, top pickaxes, new refinery types) and on base décor. Never sold for Robux directly.

### 5.7 Debris (between meteors)

- Small rocks scattered around town, low HP (dies in 3–5 basic hits), respawn after 30–60 s.
- Yield Iron ore at roughly **one quarter** of meteor rate **[A]**, so debris is filler, not a replacement for the event.
- Debris is per-server (shared) but the ore is per-player like everything else.

### 5.8 Impact spectacle checklist

Sky countdown · streak with trail and glow · screen shake scaled by distance · shockwave ring and knockback · dust cloud · crowd-visible core glow · per-hit sparks and sound · core crack flash · top-three banner. All effects are client-side; the server only sends state changes.

---

## 6. The home loop (Week 2)

### 6.1 Base plot

- Contains a **hopper**, 6 refinery pads **[A]**, and décor slots. Selling happens in town, not on the plot **[A]**.
- Décor is placed on a grid and saved; the current rebirth policy resets placed décor.

### 6.2 Hopper

- Walk onto / interact with the hopper to deposit everything in your backpack.
- The hopper is also the offline-income "fuel tank": what's in it is what refineries can process while you're away.
- **Auto-Deposit** pass: ore goes straight home when mined; no trip needed.

| Hopper level | Capacity (ore) | Cost |
|---|---|---|
| 1 | 2,000 | free |
| 2 | 8,000 | $5K |
| 3 | 32,000 | $100K |
| 4 | 128,000 | $2M |
| 5 | 512,000 | $40M |
| 6 | 2M | $800M |
| 7 | 8M | $15B |

### 6.3 Refineries

Refineries turn **1 ore into 1 bar** of the same type **[A]**. Each refinery is upgraded in place; its level sets throughput. Refineries are deliberately slower than active mining, so ore backs up in the hopper and gets processed while you're offline.

| Level | Throughput (ore/s) | Upgrade cost |
|---|---|---|
| 1 | 0.25 | free |
| 2 | 0.75 | $1.5K |
| 3 | 2.5 | $20K |
| 4 | 8 | $250K |
| 5 | 25 | $3M + 25 shards |
| 6 | 80 | $40M + 60 shards |
| 7 | 250 | $500M + 150 shards |
| 8 | 800 | $6B + 400 shards |

A refinery processes any ore type **[A]** (one machine model, recolored per ore). Bars accumulate in the output bin (uncapped) and are collected on touch.

### 6.4 Offline income

- On leave: save hopper contents, refinery list, and `lastSeen`.
- On join: `elapsed = min(now − lastSeen, offlineCap)`; simulate refineries consuming hopper stock for `elapsed` seconds. Output is limited by both time and ore in the hopper.
- **Offline cap: 2 hours base [A]**, 8 hours with **Offline Hours+**.
- On return: a "While you were away" panel shows bars produced. This is the key retention moment and is logged (§13).

### 6.5 Selling

- Sell bars at the town Trading Post. Raw ore **cannot** be sold **[A]**, so refineries stay central.
- Each meteor type's bars are worth ~25× the previous type, so every new meteor is a visible jump in income:

| Bar | Base price |
|---|---|
| Iron | $5 |
| Frost (Ice meteor) | $120 |
| Crystal | $3K |
| Alien Alloy (boss) | $75K |
| Seasonal (e.g. Pumpkin) | priced at the player's current best bar ×2 during the event **[A]** |

Final sale price = `base × rebirthMultiplier × indexBonus × VIP bonus`.

## 7. Upgrades (Week 3)

**Economy shape [A]:** prices climb roughly ×10–13 per tier while income climbs through several multipliers at once (ore per hit, better meteors, refinery level and count, rebirth ×2 each). The result is the classic simulator snowball: hundreds in the first minutes, millions within the first few sessions, billions and beyond after rebirths. All numbers display with suffixes (§7.5).

### 7.1 Pickaxes

| Tier | Name | Damage | Swing (s) | Ore/hit | Cost |
|---|---|---|---|---|---|
| 1 | Basic Pickaxe | 5 | 0.6 | 1 | free |
| 2 | Steel Pickaxe | 12 | 0.55 | 2 | $750 |
| 3 | Drill Pick | 30 | 0.5 | 5 | $8K |
| 4 | Plasma Pick | 75 | 0.47 | 12 | $90K |
| 5 | Meteorite Pick | 180 | 0.44 | 30 | $1.2M + 25 shards |
| 6 | Nova Pick | 450 | 0.41 | 75 | $15M + 80 shards |
| 7 | Singularity Pick | 1.1K | 0.38 | 180 | $200M + 200 shards |
| 8 | Cosmic Pick | 2.8K | 0.35 | 450 | $3B + 500 shards |

Big damage numbers pop off every hit. Node HP runs on Mining Power, which grows only ~1.25× per tier (§5.3), so high damage never breaks the event or sidelines newcomers; the big numbers are for feel, and the real payoff of a better pickaxe is ore per hit. Tiers 5–8 can be recolors and new effects on the tier 3–4 models, keeping the asset list at 3–4 pickaxe models.

### 7.2 Backpacks

Capacity grows with ore per hit, so a full load always takes roughly 50–90 hits and the backpack stays the first bottleneck at every stage.

| Tier | Capacity (ore) | Cost |
|---|---|---|
| 1 | 50 | free |
| 2 | 150 | $500 |
| 3 | 400 | $6K |
| 4 | 1K | $70K |
| 5 | 2.5K | $900K |
| 6 | 6K | $12M + 40 shards |
| 7 | 15K | $150M + 120 shards |
| 8 | 40K | $2B + 300 shards |

**Bigger Backpack** pass: ×2 capacity at every tier.

### 7.3 Refinery slots

| Slot | Cost |
|---|---|
| 1 | free |
| 2 | $2K |
| 3 | $25K |
| 4 | $300K + 25 shards |
| 5 | $4M + 60 shards |
| 6 | $50M + 120 shards |
| +1 | **Extra Refinery** pass (7th pad) |

### 7.4 Rough pacing check **[A]**

- **First meteor:** basic kit mines ~100 ore/min; with trips home, one ~7 min cycle yields ~140 ore → **~$700**, enough for the Steel Pickaxe right after the first meteor.
- **First session (~30 min):** Steel + Drill + backpack tier 2–3 + a second refinery. Cash in the tens of thousands.
- **Sessions 2–4:** Ice meteors ($120 bars) + tier 4–5 gear push income past **$1M/hour**.
- **First rebirth** around $10M, then ×2 income per rebirth compounds into **billions** by rebirth 3–5.
- Offline: one level 1 refinery processes 900 ore/hour, so a full 2-hour cap early on is ~$9K, a meaningful "welcome back" at that stage. It scales with refinery level and bar type.

Week 5 balancing replaces this with a spreadsheet model driven by real telemetry.

### 7.5 Big numbers

- Display with suffixes: K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc (e.g. `$1.25B`), 3 significant digits.
- Cash counter animates up on every sale; "+$4.8M" floaters on sell; damage numbers on hits.
- Currencies are Luau numbers (doubles): exact to ~9 quadrillion, and beyond that the loss is invisible behind 3-digit suffix display. Prices beyond Dc are out of scope for MVP.
- One shared `Format.luau` module does all formatting so UI never prints raw numbers.
- **Core Shards stay small on purpose** (tens to hundreds): they are the scarce, cooperation-earned currency, which keeps them meaningful next to inflated cash.

## 8. Progression (Week 4 + post-MVP)

### 8.1 Meteor types

Every meteor type is the same event loop (§5) with four things swapped: **ore**, **required pickaxe tier**, **one twist mechanic**, and **multipliers**. That keeps each new type cheap: a recolor, a new effect, one small rule, and a config entry. **[A]**

| Type | Phase | Ore (bar price) | Required tier | Twist | HP × | Timer | Shard pool × |
|---|---|---|---|---|---|---|---|
| **Iron** | MVP (Week 1) | Iron ($5) | 1 | None, the baseline | 1.0 | 2:30 | 1 |
| **Ice** | MVP (Week 4) | Frost ($120) | 3 | **Refreeze:** a node nobody has hit for 5 s regains 2% HP/s, so the crowd has to spread out and keep pressure on | 1.1 | 2:30 | 1.5 |
| **Crystal** | post-MVP | Crystal ($3K) | 5 | **Resonance:** each extra player hitting the same node adds +20% Mining Power to everyone on it (max +60%), so grouping up pays | 1.2 | 2:30 | 2 |
| **Alien Boss** | post-MVP, **hourly** at a fixed minute past the hour | Alien Alloy ($75K) | 7 | **Weak points** open in waves on the core; each wave must be broken by at least 3 different players within 10 s, or it closes and heals | 3.0 | 4:00 | 4 |
| **Seasonal** (e.g. Halloween Pumpkin) | live ops | Seasonal ore + seasonal index minerals | 1 (everyone) | Theme twist per season (e.g. pumpkins drop candy décor tokens) | 1.0 | 2:30 | 1.5 |

**Mixed lobbies: nobody is locked out.**
- Every player can hit every node, the core and weak points on every meteor. Mining Power, contribution and Core Shards work the same for everyone (§5.3, §5.6), so a newcomer at an Alien Boss still helps crack it and still gets the floor plus their share of a 4× pool.
- **Your pickaxe scales what you get.** Everyone mines the meteor's own ore. If your tier meets the meteor's required tier, you mine at full speed. If not, speed and ore both scale with your pickaxe (`Config.Meteor.UnderTier`): on your own a crust node takes **15 s per tier short** (tier 1 on Ice: 30 s), and each meteor type above the best one your pickaxe mines at full speed pays **3×** the type below: to a tier 1 player an Ice meteor is worth 3 Iron meteors and a Crystal meteor 9 (one meteor = what you carry home from it at full speed, trips included). Each hit pays that multiple of a hit on your own ore, in the meteor's ore, until the meteor's worth is reached. Example: a tier 1 player with the Canvas Sack gets one Frost every 8 hits on an Ice meteor ($1.4K a meteor) and one Crystal every 67 hits on a Crystal meteor ($4.1K); a tier 3+ player mines Ice at full speed.
- The results panel tells under-tier players what they missed ("Tier 5 pickaxe mines Crystal at full speed: $3K bars"), which is the upgrade hook.

**Guardrails: an early player in a veteran lobby can't fast-track.** **[A]**
- **Mining speed is gated by your own pickaxe**, which is bought with cash. Being near veterans lets you mine a better ore than your tier, but it pays by your own pickaxe, 3× per meteor type above your best, so a whole Crystal meteor is worth 9 of a newcomer's Iron meteors: a big night, not the Plasma Pick (docs/balance.md, under-tier meteors).
- **Refineries are the real throttle.** Cash only comes from bars, and bars come out of your refineries at their own speed. Extra ore from a lucky lobby just waits in the hopper (and is capped by hopper size), so income can't spike much beyond what your refinery level allows.
- **Shards can't skip tiers.** Every shard price is paired with a cash price (§7), so a newcomer who stockpiles shards from Alien Boss events still has to earn the cash for each tier. Shard share is counted in Mining Power, where a newcomer has roughly 1/8 of a maxed veteran's weight, so they get the floor plus a modest share, not the lion's share.
- **Faster meteors pay less per meteor.** Call a Meteor is capped at 3 per hour per server, and in private servers with an interval under the default, the shard pool scales down in proportion (a 2-minute interval pays half), so a group can't farm shards for a friend by speeding up the schedule.
- **Telemetry check (Week 5):** compare time-to-tier for new players in mixed lobbies vs. beginner lobbies. If mixed lobbies are more than ~25% faster, lower the under-tier pay first (`UnderTier.TypeMult`, then `NodeSecondsPerTier`), then the shard pool multipliers.

**Schedule (which meteor comes next):**
- The server picks each regular meteor from weighted odds: Iron 60, Ice 25, Crystal 15. A type is only eligible if at least **25% of active players** meet its required tier; otherwise it drops to the next type down. A lobby of beginners gets mostly Iron; a lobby of veterans sees plenty of Crystal. **[A]**
- The Alien Boss replaces the regular meteor at its fixed hourly slot whatever the lobby, since it's the whole-server cooperation moment.
- Seasonal meteors replace a share of Iron slots during their event window.
- The next type is shown on the sky countdown from the start of each countdown.
- Players can't buy or influence the type. Call a Meteor brings the already-chosen next meteor early (§9.2).
- Rare minerals (index, §8.2) drop from any meteor type at fixed odds, only for players who meet that meteor's required tier.

### 8.2 Mineral index

- A collection book of minerals: each meteor type has 3–5 minerals, including rare ones found on specific nodes.
- Rare minerals drop at fixed, published odds that **no purchase, pass or product can change** (2x Ore doubles quantity only).
- Rewards for completing a page: a small permanent cash bonus (+2% **[A]**), a décor piece, a title.
- MVP (Week 4): Iron and Ice pages only.

### 8.3 Rebirth — "Relocate the Colony"

- **Requirement:** $10M for the first rebirth, ×10 for each one after ($100M, $1B, $10B…) **[A]**.
- **Resets:** all cash, pickaxe/backpack tiers, all carried and stored ore/bars, hopper/conveyor/collection upgrades, partial refining progress and décor.
- **Keeps:** refinery level, carried Core Shards, index discoveries and their bonuses/titles, passes and purchased value. Preferences and lifetime/tutorial history also remain intact.
- **Reward:** permanent **×2 cash multiplier per rebirth, multiplicative** (×2, ×4, ×8…) **[A]**. This is what drives the jump into billions; it's also the main inflation lever to tune.
- Tune early (economy risk in §16).

---

## 9. Monetization

### 9.1 Game passes

| Pass | Effect | Expected role |
|---|---|---|
| **2x Ore** | Double ore quantity per hit (not rarity) | likely top seller |
| **Bigger Backpack** | ×2 backpack capacity | likely top seller: first bottleneck |
| **Extra Refinery** | +1 refinery pad | offline-income value |
| **Offline Hours+** | Offline cap 2 h → 8 h | convenience |
| **Auto-Deposit** | Mined ore goes straight to your hopper | convenience |
| **VIP** | Chat tag, VIP lounge, +10% bar value, free daily décor **[A]** | status |

### 9.2 Developer products

- **Call a Meteor** — summons the *next scheduled* meteor early for the whole server; buyer is credited on screen ("Rimgaudas called a meteor!"), others can cheer (emote/button).
  - Only buyable during `Countdown` with more than 60 s left; sets the countdown to 30 s.
  - Cooldown: 3 min after the previous event ends **[A]**. Per-server cap: 3 per hour **[A]**.
  - The buy button is disabled (with the reason shown) when unavailable, so nobody pays for nothing. ProcessReceipt re-checks and refunds via a grant of equivalent value if a race still happens.
  - It cannot choose the meteor type or boost loot.
- **Refinery Overclock** — all your refineries ×2 speed for 30 min (online only **[A]**).
- **Cash packs** — scaled to the buyer's current income (e.g. "30 minutes of your earnings") so they stay relevant at every stage of the inflated economy **[A]**.

### 9.3 Cosmetics and private servers

- Pickaxe skins, mining effects, base themes — sold directly, never random.
- **Private servers:** the owner can set the meteor interval (2–10 min) and force the next meteor. Ore rewards are unchanged; below the default interval the shard pool scales down in proportion (§8.1).

### 9.4 Compliance

Nothing in the design is random-for-pay, so paid-random-item requirements shouldn't apply. **Rule:** no purchasable "lucky meteor" boosts, ore crates, or anything that changes odds. Any future product gets checked against this rule before it ships.

---

## 10. UI (Week 3)

- **Sky countdown**: big timer and next meteor type in the sky over the crater, plus a compact HUD timer.
- **HUD**: cash, Core Shards, backpack meter (turns red when full), current pickaxe.
- **Event HUD**: cooling timer, core HP bar, core lock indicator, your contribution rank.
- **Results panel**: your ore mined, shards earned (floor + bonus), top three.
- **Home panels**: hopper fill, refinery progress, "While you were away" summary.
- **Shop** (pickaxes, backpacks, refineries, décor), **Index**, **Rebirth**, **Store** (passes/products).
- Mobile-first layout: big mining button, joystick-friendly spacing. **[A]**

---

## 11. Tutorial (Week 3)

Arrow-guided steps, skippable, each step completes on the real action:
1. Mine a debris rock. 2. Watch the meteor land. 3. Run to the crater. 4. Mine a crust node. 5. Hit the core. 6. Collect your shards. 7. Go home and deposit ore. 8. Collect a bar. 9. Sell bars. 10. Buy an upgrade.

Each step completion is logged as an onboarding funnel step.

---

## 12. Technical design (Rojo + Luau)

### 12.1 Project layout **[A]**

```
default.project.json
src/
  shared/            -- ReplicatedStorage.Shared
    Config/          -- Meteors, Pickaxes, Backpacks, Refineries, Economy, Products
    Net.luau         -- remote definitions
    Format.luau      -- big-number suffix formatting
    Types.luau
  server/            -- ServerScriptService.Server
    Services/
      MeteorService       -- schedule + state machine
      NodeService         -- node HP, hit validation
      ContributionService -- per-event tally
      RewardService       -- core shards, announcements
      DebrisService
      DataService         -- player profiles
      PlotService
      RefineryService     -- online ticking + offline catch-up
      EconomyService      -- sell, purchase, currency
      ShopService
      MonetizationService -- passes, products, ProcessReceipt
      AnalyticsService    -- wrapper over Roblox AnalyticsService
  client/            -- StarterPlayerScripts.Client
    Controllers/
      MiningController, MeteorFXController, HUDController,
      ShopController, TutorialController
```

### 12.2 Authority and networking

- **Server owns all state**: node/core HP, backpack, currencies, contribution, rewards.
- **Client owns all effects**: streak, shockwave visuals, sparks, ore fly-ins, sounds.
- Mining remote: `Swing(nodeId)`. Server checks: node exists and alive, player within range (≤ 12 studs), swing rate ≤ pickaxe speed (with small tolerance), event state allows it. Reject silently otherwise.
- Node HP replication: batched updates at ~10 Hz for changed nodes only, not per hit.
- Shockwave: server broadcasts impact; each client applies knockback to its own character (the client owns its character's physics). No damage.

### 12.3 Performance targets (Week 5)

- 20 players hitting nodes at once: server heartbeat ≥ 55 FPS, remote traffic per client < 10 KB/s during events.
- ≤ 40 crust nodes, anchored parts only, no physics objects for ore (ore is visual, client-side).
- Throttle remotes; pool effect instances on the client.

### 12.4 Data (DataStore)

Use a session-locked profile library (e.g. ProfileStore) **[A]**. Profile schema v1:

```lua
{
  version = 1,
  cash = 0, shards = 0,
  pickaxeTier = 1, backpackTier = 1,
  backpack = { iron = 0, frost = 0 },       -- ore carried
  hopper   = { iron = 0, frost = 0 },
  refineries = { { level = 1 } },
  hopperLevel = 1,
  bars = { iron = 0, frost = 0 },
  decor = { },                               -- placed items, resets on rebirth
  index = { },                               -- discovered minerals
  rebirths = 0,
  lastSeen = 0,
  flags = { tutorialDone = false, firstMeteor = false,
            firstCoreReward = false, firstRefinery = false },
  stats = { meteorsJoined = 0, coresCracked = 0 },
}
```

Autosave every 60 s and on leave; migrations keyed by `version`.

---

## 13. Analytics (Week 4)

Use Roblox `AnalyticsService` (onboarding funnel, economy, custom events).

**Required by the design:**
| Event | When |
|---|---|
| `first_meteor_joined` | first time a player lands a hit on a meteor |
| `first_core_reward` | first shards received |
| `first_refinery_bought` | first paid refinery slot |
| `returned_offline_income` | join with offline output > 0 (include hours away and bars) |

**Also log [A]:**
- Per event: players in server, players who hit ≥ 1 node, players who hit the core, cracked vs cooled, time to crack.
- **Active actions per minute** (swings, deposits, sells, purchases, décor placements), so idle time in game doesn't hide low engagement.
- Tutorial funnel steps; economy source/sink events for cash and shards; pass/product purchases, including whether a Call a Meteor was followed by other purchases in that server within 10 min.

---

## 14. MVP plan (5 weeks)

| Week | Scope | Done when |
|---|---|---|
| **1 — Meteor loop** | Rojo project, countdown, streak + impact + knockback, node/core HP, per-player ore drops, contribution tally, core rewards + top-three, debris, placeholder backpack | 2+ test players can run a full event end to end and it already feels exciting |
| **2 — Home loop** | DataService + profiles, plot assignment, hopper, refineries, offline income, sell point | Ore goes home → bars → cash, and survives rejoin with correct offline output |
| **3 — Upgrades + UI** | Pickaxe/backpack/refinery purchases, selling UI, HUD, event HUD, results panel, tutorial | A new player finishes the tutorial and buys an upgrade unaided |
| **4 — Breadth** | Ice meteor + Frost ore, mineral index, rebirth, shop, passes/products, analytics events | All four required analytics events visible in the dashboard |
| **5 — Ship** | Balancing, 20-player load test, icon + thumbnails, launch | Perf targets met; launch checklist done |

**Assets:** one town + crater, meteor node pieces (core + 2–3 node shapes), 3–4 pickaxe models, 2 refinery machines, hopper, a small décor set. Variety via recolor and effects.

---

## 15. Launch and live ops

- **Thumbnails/icon:** test several; lead with a meteor mid-impact with a crowd running toward it.
- **Update rhythm:** weekly Saturday update; a new meteor type roughly every two weeks; seasonal event meteors. Meteors are cheap to produce, which is the biggest practical advantage.

### Success metrics
- **Event engagement:** share of server players who join each meteor, and whether it holds across the session. Decline → add variety sooner.
- **Returning players:** do players come back to collect refinery output?
- **Newcomer experience:** share of first-session players who get a core reward; if many leave before their first meteor lands, shorten the first countdown.
- **Purchase mix:** how often Call a Meteor is bought, and whether it lifts purchases by others in the same server.

### Decision points (~2 weeks live)
| Signal | Action |
|---|---|
| Players leave between meteors | Shorten the interval or add in-between activities |
| Retention good, sales low | Tighten the backpack bottleneck |
| Both weak | Improve impact spectacle and core rewards before adding content |

---

## 16. Risks

| Risk | Mitigation |
|---|---|
| Distinctiveness: meteor mining isn't unique | Win on polish and how the event feels (Pillar 1) |
| Performance with many players hitting nodes | Reasonable node counts, server-side HP, client-side effects, batched replication |
| Economy inflation from offline income + shared rewards | Cap offline hours, hopper as fuel limit, tune rebirth early, track sources/sinks |
| Newcomers outclassed by veterans | Mining Power compresses the tier gap to ~8×, participation floor, per-player drops, contribution in Mining Power |
| Idle players inflate session time | Measure active actions per minute, not just time in game |
| Call a Meteor spam | Cooldown + per-server cap + disabled button when unavailable |

---

## 17. Open questions (defaults already picked; change any)

1. **Server size:** 20 players by default. OK, or start at 16?
2. **Core Shards:** spent on high-tier upgrades and décor. Is that the intent?
3. **Rebirth (resolved):** needs $10M (×10 each time), gives ×2 cash per rebirth. Reset active cash/gear/resources, other station upgrades and décor; keep refinery level, Core Shards and index bonuses.
4. **Meteor interval:** 4:00 countdown + 2:30 event (~7 min cycle). Shorter?
5. **Rare minerals:** random drops at fixed odds that nothing purchasable changes. OK under the compliance rule?
