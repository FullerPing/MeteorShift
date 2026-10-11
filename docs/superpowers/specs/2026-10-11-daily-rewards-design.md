# Daily rewards, quests and badges: design

Date: 2026-10-11. Status: awaiting owner review.

## Goal

Give players a reason to come back each day: a login streak with streak shields, a small daily and weekly quest
list, and Roblox Badges for milestones. Everything is free to earn. Rewards are sized to the player's income so
they stay meaningful in the inflated economy, and nothing here changes meteor, mineral or egg odds. The only
Robux item is the optional Streak Shield (9 Robux), a fixed, non-random product.

## Decisions already made by the owner

- Rewards are mixed and income-scaled: cash from `Shared.Income` (capped under the next rebirth cost) with Core
  Shards on streak milestones (day 3 and day 7) and a pet-XP bonus on day 7.
- Missing a day resets the streak to day 1, unless shields cover the gap.
- Every player gets **1 free shield**. More are sold as a **Streak Shield developer product, 9 Robux**. The owner
  creates the dashboard item later, so its id stays `0` (off sale) until then.

## Assumptions (change any)

- A day is a UTC day: `day = os.time() // 86400`.
- A shield covers one missed day. A gap of `m` missed days is covered when `shields >= m`; the shields are then
  spent and the streak continues. Otherwise the streak resets to day 1 and **no shields are spent**.
- Completing day 7 grants +1 shield. Shields are capped at 3 (`Config.Daily.ShieldCap`).
- The streak is a 7-day cycle: day 8 starts a new cycle at day 1 of the rewards, and the streak count keeps
  rising for display.
- Quest progress counts only while the player is in the server and only for the current UTC day (weekly: the
  UTC week starting Monday).

## Architecture

| Unit | Purpose | Depends on |
|---|---|---|
| `Shared/Config/Daily.luau` | Tuning: cycle rewards, quest pool, weekly quest, bonus, shield cap | none |
| `Shared/Daily.luau` | Pure rules: day keys, streak and shield resolution, quest picking, reward sizing, progress counting | Config.Daily, Shared.Income |
| `Shared/Config/Badges.luau` | Badge key to badge id (`0` = off) | none |
| `Server/Services/DailyService.luau` | Owns `profile.daily`: rollover on join, claim, quest progress from server signals, shield purchase credit, badge awards | DataService, PlayerStateService, RewardService, Shared.Daily |
| `Client/Controllers/DailyController.luau` + `NativeMenus/Daily.luau` | DAILY button with a dot, join popup, menu: streak row, shields, quests with Claim | Native UI, HudLayout |
| `Server/Lib/Badges.luau` | Awarding with pcall and per-session dedupe | `BadgeService` |

`DailyService` listens to existing signals instead of adding hooks to other services: `NodeService.Hit`,
`MeteorService.Ended`, `RewardService.ShardsAwarded` (core cracked), `EconomyService.BarsSold`,
`RefineryService.OreDeposited`, `RebirthService.Reborn`, `LevelService` (level gained), `PetService` (hatch) and
`IndexService` (page completed).

## Data (profile v9, additive)

```
daily = {
  day = 0,            -- last UTC day a rollover ran
  lastClaim = 0,      -- last UTC day the login reward was claimed
  streak = 0,         -- consecutive claimed days (display)
  shields = 1,        -- starts with the free shield
  quests = {},        -- today's quests: { id, progress, claimed }
  questBonusClaimed = false,
  week = 0, weekly = { id, progress, claimed },
}
```

New keys fill into old profiles automatically (ProfileTemplate rule), so v9 needs no migration beyond the
version bump and a one-time `shields = 1` default. `credits.streakShield` holds paid shields that could not be
added at purchase time (it should not happen: the grant is a plain increment).

## Rules

- **Rollover on join (and each UTC midnight for online players):** compare `today` with `daily.day`. A new day
  picks 3 daily quests deterministically from the pool using `today` and the player's level band, clears
  progress, and resets `questBonusClaimed`. A new week picks the weekly quest.
- **Login reward:** claimable once per UTC day. Resolve the gap against `lastClaim` using shields as above, then
  pay cycle day `((streak - 1) % 7) + 1`. Cash is `Income.grant(minutes * 60, lineIncome, floor, ceiling)` where
  the ceiling is `Rebirth.cost(rebirths) * Config.Daily.CashCeilingShare`. Day 3 adds shards, day 7 adds more
  shards, pet XP to equipped pets and a shield.
- **Quests:** each has a counter, a target, a reward (cash minutes plus shards) and a claim flag. The pool covers
  mining crust nodes, joining meteors, cracking a core, selling bars, depositing ore, hatching an egg and
  reaching a rebirth. A bonus pays when all three dailies are claimed. The weekly quest is longer (for example
  join 15 meteors) and pays more.
- **Server authority:** the client only asks to claim. The server checks the day, the progress and the claimed
  flag, saves, then pays through `PlayerStateService` and announces it through `RewardService:Bonus`.
- **Shield purchase:** `MonetizationService` gets a `StreakShield` product (`Robux = 9`, `Id = 0`) whose grant
  adds one shield up to the cap through `Purchases` like the other fixed grants (receipt saved before it is
  acknowledged). The Store lists it as "Not on sale yet" until the id is set; at the cap the card is disabled
  with the reason, so nobody pays for nothing.
- **Badges:** keys `firstMeteor`, `firstCore`, `firstRebirth`, `rebirth10`, `level25`, `level50`, `pageIron`,
  `pageIce`, `pageCrystal`, `legendaryPet`, `streak7`. Awarded once per player per session (Roblox dedupes the
  rest), wrapped in `pcall`, and skipped when the id is `0`.

## Client

A DAILY navigation button (with a notification dot when something is claimable) is added to `HudLayout` in the
same stack as SHOP/INDEX/REBIRTH/STORE, with the usual 44 px minimum and phone layouts. The menu is built the
same way as the other native menus (authored prefab when present, built in code otherwise, `tools/build-native-ui`
updated). It shows the 7 cycle days with the current one highlighted, the shield count with a "streak is safe"
note, today's three quests with progress bars and CLAIM buttons, the all-done bonus, and the weekly quest. On
join, a small popup offers the login reward once per day.

## Telemetry

`daily_claimed` (streak day, shields used), `quest_claimed` (id, daily or weekly), `streak_reset`,
`shield_bought`, and the badge keys awarded. Same pcall'd `TelemetryService` path as the other events.

## Testing

Pure specs in `tests/Daily.spec.luau`: day and week keys, gap and shield resolution (covered, partly covered,
none), cycle day and reward sizing (floor, ceiling, shard days), deterministic quest picking, progress
counting, bonus and weekly rules, and the shield cap. `Purchases.spec` and `Monetization` tests cover the new
product (id `0` is off sale, cap respected). `HudLayout`/`DailyLayout` specs cover the button on desktop,
landscape phone and compact layouts.

## Out of scope

Robux sales of anything except Streak Shields, a streak-restore purchase, seasonal events, cosmetics, codes.
