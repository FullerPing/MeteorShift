# Daily Rewards, Quests and Badges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A free daily login streak with streak shields, a daily and weekly quest list, a Streak Shield product (9 Robux, off sale until the owner adds the id), and Roblox Badges for milestones.

**Architecture:** All rules are pure and tested in `Shared/Daily.luau` (tuning in `Shared/Config/Daily.luau`). One thin Knit service, `DailyService`, owns `profile.daily`, listens to existing server signals for quest progress and badges, and publishes a per-player `Summary` property. The client gets one native menu (`DailyMenu`) plus entry points that do not touch `HudLayout`: a "Daily rewards" row in Settings, a ready dot on the gear, and a once-per-session popup.

**Tech Stack:** Luau (strict), Knit 1.7, Rojo, the in-Studio test runner (`require(game.ServerStorage.Tests.Runner)("<filter>")`).

**Spec:** `docs/archive/superpowers/specs/2026-10-11-daily-rewards-design.md`

## Global Constraints

- UTC day key is `math.floor(os.time() / 86400)`; weeks start Monday.
- 1 free shield at the start; a shield covers one missed day; a gap needing more shields than owned resets the streak to day 1 and spends none.
- Free shield gains (day-7 reward) are capped at `Config.Daily.ShieldCap` = 3. Paid shields are **not** capped (changed from the spec: nobody should pay for nothing). Update the spec in Task 7.
- Streak Shield product: key `StreakShield`, `Robux = 9`, `Id = 0` (off sale) until the owner adds the dashboard item.
- Cash rewards use `Shared.Income.grant` and are capped at `Rebirth.cost(rebirths) * Config.Daily.CashCeilingShare` (0.05).
- No Robux sale other than Streak Shield, nothing here changes meteor, mineral or egg odds.
- Badge ids live in `Config.Badges`; `0` means off. Awards are `pcall`'d.
- Code style: tabs, `--!strict`, comment density like the surrounding files; every new module under `src/shared` that holds rules gets a `tests/<Name>.spec.luau`.
- Commit trailer on every commit: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Never replace `ReplicatedStorage.Shared` with a clone in Studio (breaks Rojo sync). After editing files, wait a few seconds for Rojo before running the suite.

## Review Focus

1. A saved `lastClaim` in the future (clock moved back, dev offset removed): behave as "already claimed", never a negative or reset streak (Task 1 test).
2. Income of `0`, `NaN`, `inf` or negative, or a ceiling below the floor: the reward must be a finite whole number and never exceed the ceiling (Task 1 test).
3. Two claim requests in the same instant: the second must pay nothing (Task 4 service guard, plus the pure `resolve` test that a same-day claim is `claimed`).
4. A profile saved before v9 (no `daily`) or with a half-filled `daily` (no weekly id): rollover must fill it without error (Task 1 and Task 2 tests).
5. A saved quest id that no longer exists in config: it must be skipped everywhere (progress, summary, claim) without erroring (Task 1 test).

---

## File Structure

| File | Responsibility |
|---|---|
| `src/shared/Config/Daily.luau` (new) | All tuning: cycle rewards, quest pool, weekly pool, bonus, caps |
| `src/shared/Daily.luau` (new) | Pure rules: day/week keys, streak + shield resolution, quest picking, progress, claims, rewards, summary |
| `src/shared/Config/Badges.luau` (new) | Badge key -> badge id (`0` = off) |
| `src/shared/Config/init.luau` (modify) | Register `Daily` and `Badges` |
| `src/server/Lib/Badges.luau` (new) | Pure `pick` + `award` (pcall, per-session dedupe) |
| `src/server/Lib/ProfileTemplate.luau` (modify) | Schema v9: `daily` table |
| `src/server/Services/DailyService.luau` (new) | Rollover, claims, progress listeners, badge awards, telemetry, `Summary` property |
| `src/server/Services/LevelService.luau`, `IndexService.luau`, `PetService.luau` (modify) | Add server signals `LeveledUp`, `PageCompleted`, `EggHatched` |
| `src/shared/Config/Monetization.luau`, `src/shared/Purchases.luau`, `src/shared/Config/Store.luau`, `src/server/Services/MonetizationService.luau` (modify) | Streak Shield product |
| `src/client/NativeMenus/Daily.luau` (new) | Builds the `DailyMenu` ScreenGui |
| `src/client/Controllers/DailyController.luau` (new) | Binds the menu, claims, join popup, `DailyReady` attribute |
| `src/client/NativeHudMenus.luau` + 7 controllers that list menu flags (modify) | `DailyOpen` flag, Settings row, gear dot |
| `tests/Daily.spec.luau`, `tests/Badges.spec.luau` (new); `tests/Purchases.spec.luau`, `tests/ProfileTemplate` checks (modify) | Coverage |

---

### Task 1: Daily config and pure rules

**Files:**
- Create: `src/shared/Config/Daily.luau`
- Create: `src/shared/Daily.luau`
- Modify: `src/shared/Config/init.luau`
- Test: `tests/Daily.spec.luau`

**Interfaces:**
- Produces (used by Tasks 2, 4, 6): `Config.Daily`; `Daily.dayKey(now)`, `Daily.weekKey(day)`, `Daily.cycleDay(streak)`, `Daily.resolve(lastClaim, streak, shields, today) -> Resolution`, `Daily.reward(cycleDay, perSecond, ceiling) -> Reward`, `Daily.questReward(id, perSecond, ceiling)`, `Daily.bonusReward(perSecond, ceiling)`, `Daily.pickQuests(day, level, rebirths, seed)`, `Daily.rollover(data, today, level, rebirths, seed) -> boolean`, `Daily.addProgress(data, event, amount) -> boolean`, `Daily.findEntry(data, slot)`, `Daily.claimQuest(data, slot) -> string?` (quest id when claimed), `Daily.claimBonus(data) -> boolean`, `Daily.claimLogin(data, today) -> Resolution`, `Daily.addFreeShield(data, count) -> number`, `Daily.summary(data, now, perSecond, ceiling) -> Summary`.

- [ ] **Step 1: Write the failing test**

Create `tests/Daily.spec.luau`:

```lua
--!strict
return function(t: any)
	local module = t.shared:FindFirstChild("Daily")
	t.test("daily rules exist", function() t.ok(module, "Shared.Daily missing") end)
	if not module then return end
	local Daily = require(module)
	local Config = require(t.shared.Config)
	local Settings = Config.Daily

	local function fresh(): any
		return { day = 0, lastClaim = 0, streak = 0, shields = 1, quests = {}, questBonusClaimed = false, week = 0,
			weekly = { id = "", progress = 0, claimed = false } }
	end

	t.test("config is consistent", function()
		t.eq(#Settings.Days, Settings.CycleLength)
		local seen = {}
		for _, def in Settings.Quests do
			t.ok(not seen[def.Id], def.Id .. " repeats")
			seen[def.Id] = true
			t.ok(def.Target >= 1 and def.Minutes > 0, def.Id .. " target or reward")
			t.ok(string.find(def.Title, tostring(def.Target), 1, true) ~= nil or def.Target == 1, def.Id .. " title shows its target")
		end
		for _, def in Settings.Weekly do
			t.ok(not seen[def.Id], def.Id .. " repeats")
			seen[def.Id] = true
		end
		t.ok(#Settings.Quests >= Settings.DailyCount)
	end)

	t.test("day and week keys follow UTC and weeks start on Monday", function()
		t.eq(Daily.dayKey(0), 0)
		t.eq(Daily.dayKey(86399), 0)
		t.eq(Daily.dayKey(86400), 1)
		t.eq(Daily.dayKey(-5), 0, "a negative clock reads as day 0")
		t.eq(Daily.dayKey(0 / 0), 0)
		-- day 4 is Monday 5 January 1970; day 3 is the Sunday before it
		t.eq(Daily.weekKey(3), 0)
		t.eq(Daily.weekKey(4), 1)
		t.eq(Daily.weekKey(10), 1)
		t.eq(Daily.weekKey(11), 2)
	end)

	t.test("the cycle day wraps every seven claims", function()
		t.eq(Daily.cycleDay(1), 1)
		t.eq(Daily.cycleDay(7), 7)
		t.eq(Daily.cycleDay(8), 1)
		t.eq(Daily.cycleDay(15), 1)
		t.eq(Daily.cycleDay(0), 1)
	end)

	t.test("resolve: first claim, next day, same day", function()
		local first = Daily.resolve(0, 0, 1, 100)
		t.eq(first.status, "claimable"); t.eq(first.streak, 1); t.eq(first.shieldsUsed, 0)
		local nextDay = Daily.resolve(100, 4, 1, 101)
		t.eq(nextDay.status, "claimable"); t.eq(nextDay.streak, 5); t.eq(nextDay.shieldsUsed, 0); t.eq(nextDay.reset, false)
		local same = Daily.resolve(101, 5, 1, 101)
		t.eq(same.status, "claimed"); t.eq(same.streak, 5)
	end)

	t.test("resolve: shields cover missed days, otherwise the streak resets and no shield is spent", function()
		local covered = Daily.resolve(100, 4, 1, 102) -- one missed day, one shield
		t.eq(covered.streak, 5); t.eq(covered.shieldsUsed, 1); t.eq(covered.reset, false)
		local short = Daily.resolve(100, 4, 1, 103) -- two missed days, one shield
		t.eq(short.streak, 1); t.eq(short.shieldsUsed, 0); t.eq(short.reset, true)
		local two = Daily.resolve(100, 4, 2, 103)
		t.eq(two.streak, 5); t.eq(two.shieldsUsed, 2)
		local long = Daily.resolve(100, 40, 3, 100 + 400)
		t.eq(long.reset, true); t.eq(long.shieldsUsed, 0)
	end)

	t.test("resolve: a claim day in the future (clock moved back) reads as already claimed", function()
		local result = Daily.resolve(500, 9, 1, 100)
		t.eq(result.status, "claimed"); t.eq(result.streak, 9); t.eq(result.reset, false)
	end)

	t.test("reward sizing: floor, ceiling, shard days, hostile income", function()
		local one = Daily.reward(1, 100, 1e12)
		t.eq(one.cash, math.floor(Settings.Days[1].Minutes * 60 * 100))
		t.eq(one.shards, 0)
		t.eq(Daily.reward(1, 0, 1e12).cash, Settings.CashFloor, "no income pays the floor")
		t.eq(Daily.reward(1, 100, 50).cash, 50, "the ceiling wins, even below the floor")
		for _, bad in { 0 / 0, math.huge, -math.huge, -10 } do
			local cash = Daily.reward(3, bad, 1e12).cash
			t.ok(cash == cash and cash >= 0 and cash < math.huge and cash == math.floor(cash), "finite whole cash for " .. tostring(bad))
		end
		t.eq(Daily.reward(3, 1, 1e12).shards, Settings.Days[3].Shards)
		local seventh = Daily.reward(7, 1, 1e12)
		t.eq(seventh.shield, 1); t.ok(seventh.petXp > 0 and seventh.shards > 0)
		t.eq(Daily.reward(99, 1, 1e12).shards, Settings.Days[7].Shards, "an out-of-range day pays the last one")
	end)

	t.test("quests are deterministic, distinct, and respect level gates", function()
		local a = Daily.pickQuests(20000, 1, 0, 42)
		local b = Daily.pickQuests(20000, 1, 0, 42)
		t.eq(#a, Settings.DailyCount)
		for i = 1, #a do t.eq(a[i], b[i]) end
		local seen = {}
		for _, id in a do t.ok(not seen[id], "distinct"); seen[id] = true end
		for _, id in a do
			for _, def in Settings.Quests do
				if def.Id == id then t.ok((def.MinLevel or 1) <= 1, id .. " is gated above level 1") end
			end
		end
		local different = false
		for day = 20001, 20010 do
			local other = Daily.pickQuests(day, 50, 5, 42)
			for i = 1, #other do if other[i] ~= a[i] then different = true end end
		end
		t.ok(different, "other days give other quests")
	end)

	t.test("rollover fills a fresh or half-filled profile and keeps today's progress", function()
		local data = fresh()
		t.eq(Daily.rollover(data, 20000, 1, 0, 7), true)
		t.eq(#data.quests, Settings.DailyCount)
		t.ok(data.weekly.id ~= "", "a weekly quest was picked")
		t.eq(data.day, 20000); t.eq(data.week, Daily.weekKey(20000))
		data.quests[1].progress = 3
		t.eq(Daily.rollover(data, 20000, 1, 0, 7), false, "same day changes nothing")
		t.eq(data.quests[1].progress, 3)
		data.questBonusClaimed = true
		t.eq(Daily.rollover(data, 20001, 1, 0, 7), true)
		t.eq(data.questBonusClaimed, false); t.eq(data.quests[1].progress, 0)
		local half = fresh(); half.day = 20000; half.week = Daily.weekKey(20000); half.weekly.id = ""
		t.eq(Daily.rollover(half, 20000, 1, 0, 7), true, "a missing weekly id is picked even on the same day")
		t.ok(half.weekly.id ~= "")
	end)

	t.test("progress counts by event, caps at the target, and ignores claimed or unknown quests", function()
		local data = fresh()
		Daily.rollover(data, 20000, 1, 0, 7)
		data.quests = { { id = "crust150", progress = 0, claimed = false }, { id = "gone", progress = 0, claimed = false },
			{ id = "sell100", progress = 0, claimed = true } }
		t.eq(Daily.addProgress(data, "crustHit", 1), true)
		t.eq(data.quests[1].progress, 1)
		t.eq(Daily.addProgress(data, "crustHit", 1e9), true)
		t.eq(data.quests[1].progress, 150, "capped at the target")
		t.eq(Daily.addProgress(data, "crustHit", 1), false, "nothing left to count")
		t.eq(Daily.addProgress(data, "barsSold", 500), false, "a claimed quest does not count")
		t.eq(Daily.addProgress(data, "crustHit", 0 / 0), false)
		t.eq(Daily.addProgress(data, "crustHit", -3), false)
		t.eq(data.quests[2].progress, 0, "an unknown quest id is skipped")
	end)

	t.test("claiming a quest needs its target and pays once; the bonus needs all of them", function()
		local data = fresh()
		Daily.rollover(data, 20000, 1, 0, 7)
		data.quests = { { id = "join2", progress = 1, claimed = false }, { id = "crack1", progress = 1, claimed = false } }
		t.eq(Daily.claimQuest(data, "d1"), nil, "target not reached")
		data.quests[1].progress = 2
		t.eq(Daily.claimQuest(data, "d1"), "join2")
		t.eq(Daily.claimQuest(data, "d1"), nil, "second claim pays nothing")
		t.eq(Daily.claimBonus(data), false, "the second quest is open")
		t.eq(Daily.claimQuest(data, "d2"), "crack1")
		t.eq(Daily.claimBonus(data), true)
		t.eq(Daily.claimBonus(data), false, "the bonus pays once")
		t.eq(Daily.claimQuest(data, "d9"), nil)
		t.eq(Daily.claimQuest(data, "zzz"), nil)
	end)

	t.test("claimLogin updates the streak and spends shields only when they cover the gap", function()
		local data = fresh()
		local first = Daily.claimLogin(data, 100)
		t.eq(first.status, "claimable"); t.eq(data.streak, 1); t.eq(data.lastClaim, 100); t.eq(data.shields, 1)
		local again = Daily.claimLogin(data, 100)
		t.eq(again.status, "claimed"); t.eq(data.streak, 1, "a second claim the same day changes nothing")
		Daily.claimLogin(data, 102) -- one missed day, one shield
		t.eq(data.streak, 2); t.eq(data.shields, 0)
		Daily.claimLogin(data, 105) -- two missed days, no shields
		t.eq(data.streak, 1); t.eq(data.shields, 0)
	end)

	t.test("free shields stop at the cap", function()
		local data = fresh()
		data.shields = Settings.ShieldCap - 1
		t.eq(Daily.addFreeShield(data, 1), 1); t.eq(data.shields, Settings.ShieldCap)
		t.eq(Daily.addFreeShield(data, 1), 0, "at the cap"); t.eq(data.shields, Settings.ShieldCap)
		data.shields = Settings.ShieldCap + 4 -- paid shields above the cap are kept
		t.eq(Daily.addFreeShield(data, 1), 0); t.eq(data.shields, Settings.ShieldCap + 4)
	end)

	t.test("summary describes what a claim would do", function()
		local data = fresh()
		Daily.rollover(data, 20000, 1, 0, 7)
		local now = 20000 * 86400 + 3600
		local before = Daily.summary(data, now, 10, 1e12)
		t.eq(before.claimedToday, false); t.eq(before.cycleDay, 1); t.ok(before.anyReady); t.eq(before.secondsLeft, 86400 - 3600)
		Daily.claimLogin(data, 20000)
		local after = Daily.summary(data, now, 10, 1e12)
		t.eq(after.claimedToday, true); t.eq(after.cycleDay, 1); t.eq(after.anyReady, false)
		t.eq(#after.quests, Settings.DailyCount)
		t.eq(after.quests[1].slot, "d1")
		t.ok(after.weekly ~= nil and after.weekly.slot == "w")
	end)
end
```

- [ ] **Step 2: Run the test to verify it fails**

In Studio Edit mode (`studio_id` from `list_roblox_studios`), `execute_luau` with `return require(game.ServerStorage.Tests.Runner)("Daily")`.
Expected: failures including `Shared.Daily missing`.

- [ ] **Step 3: Write the config**

Create `src/shared/Config/Daily.luau`:

```lua
--!strict
-- Daily streak, quests and shields (Shared.Daily rules, DailyService). Cash is a stretch of the player's own
-- expected income (Shared.Income) so a reward is as big as their setup is, capped under the next rebirth cost.
-- Nothing here is sold except Streak Shields (Config.Monetization) and nothing touches any odds.
export type Day = { Minutes: number, Shards: number, PetXp: number, Shield: number }
export type Quest = {
	Id: string, Event: string, Target: number, Title: string, Minutes: number, Shards: number,
	MinLevel: number?, MinRebirths: number?,
}

local Daily = {}

Daily.CycleLength = 7
Daily.CashFloor = 500 -- a claim never pays less cash than this (the ceiling still wins)
Daily.CashCeilingShare = 0.05 -- of the next rebirth's cost
Daily.StartShields = 1
Daily.ShieldCap = 3 -- free shield gains stop here; shields you buy are kept above it
Daily.DailyCount = 3

-- Minutes of income, Core Shards, XP for each equipped pet, and free shields on each day of the cycle
Daily.Days = {
	{ Minutes = 10, Shards = 0, PetXp = 0, Shield = 0 },
	{ Minutes = 15, Shards = 0, PetXp = 0, Shield = 0 },
	{ Minutes = 20, Shards = 10, PetXp = 0, Shield = 0 },
	{ Minutes = 25, Shards = 0, PetXp = 0, Shield = 0 },
	{ Minutes = 30, Shards = 0, PetXp = 0, Shield = 0 },
	{ Minutes = 40, Shards = 0, PetXp = 0, Shield = 0 },
	{ Minutes = 60, Shards = 40, PetXp = 300, Shield = 1 },
} :: { Day }

-- Events: crustHit (a validated hit on a meteor crust node), meteorJoin (first hit of each meteor), coreCrack
-- (you shared in a cracked core), barsSold (bars), oreDeposited (ore), hatch (an egg). Titles state the target.
Daily.Quests = {
	{ Id = "crust150", Event = "crustHit", Target = 150, Title = "Break 150 meteor crust nodes", Minutes = 6, Shards = 0 },
	{ Id = "crust400", Event = "crustHit", Target = 400, Title = "Break 400 meteor crust nodes", Minutes = 12, Shards = 2, MinLevel = 8 },
	{ Id = "join2", Event = "meteorJoin", Target = 2, Title = "Join 2 meteors", Minutes = 8, Shards = 0 },
	{ Id = "crack1", Event = "coreCrack", Target = 1, Title = "Help crack a meteor core", Minutes = 10, Shards = 3 },
	{ Id = "sell100", Event = "barsSold", Target = 100, Title = "Sell 100 bars", Minutes = 6, Shards = 0 },
	{ Id = "deposit500", Event = "oreDeposited", Target = 500, Title = "Deposit 500 ore in the Refinery", Minutes = 6, Shards = 0 },
	{ Id = "hatch1", Event = "hatch", Target = 1, Title = "Hatch an egg", Minutes = 8, Shards = 0, MinLevel = 8 },
} :: { Quest }

Daily.Weekly = {
	{ Id = "week15", Event = "meteorJoin", Target = 15, Title = "Join 15 meteors this week", Minutes = 60, Shards = 20 },
	{ Id = "weekCores3", Event = "coreCrack", Target = 3, Title = "Help crack 3 meteor cores this week", Minutes = 60, Shards = 20 },
} :: { Quest }

-- Paid once all of today's quests are claimed
Daily.Bonus = { Minutes = 15, Shards = 5 }

return Daily
```

- [ ] **Step 4: Register the config**

In `src/shared/Config/init.luau`, add `Daily = require(script.Daily),` after the `Leaderboards = LeaderboardsConfig,` line (inside the returned table).

- [ ] **Step 5: Write the rules**

Create `src/shared/Daily.luau`:

```lua
--!strict
-- Rules for the daily streak, the quests and the shields (Config.Daily). Pure: the clock, the player's income and
-- the profile come in as arguments, so DailyService stays thin and tests/Daily.spec covers all of it.

local Config = require(script.Parent.Config)
local DailyConfig = require(script.Parent.Config.Daily)
local Income = require(script.Parent.Income)

local Settings = Config.Daily
local Daily = {}

export type Entry = { id: string, progress: number, claimed: boolean }
export type Data = {
	day: number, lastClaim: number, streak: number, shields: number,
	quests: { Entry }, questBonusClaimed: boolean, week: number, weekly: Entry,
}
export type Resolution = { status: "claimable" | "claimed", streak: number, shieldsUsed: number, reset: boolean }
export type Reward = { cash: number, shards: number, petXp: number, shield: number }
export type QuestView = {
	slot: string, title: string, progress: number, target: number, claimed: boolean, ready: boolean, cash: number, shards: number,
}
export type Summary = {
	claimedToday: boolean, streak: number, cycleDay: number, shields: number, shieldCap: number,
	shieldsToUse: number, willReset: boolean, reward: Reward, quests: { QuestView }, weekly: QuestView?,
	bonus: { ready: boolean, claimed: boolean, cash: number, shards: number }, secondsLeft: number, anyReady: boolean,
}

local DAY = 86400

local function clean(value: number): number
	if value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end
	return value
end

local function questDef(id: string): DailyConfig.Quest?
	for _, def in Settings.Quests do
		if def.Id == id then return def end
	end
	for _, def in Settings.Weekly do
		if def.Id == id then return def end
	end
	return nil
end

function Daily.dayKey(now: number): number
	return math.floor(clean(now) / DAY)
end

-- Weeks start on Monday: day 0 (1 January 1970) was a Thursday
function Daily.weekKey(day: number): number
	return math.floor((day + 3) / 7)
end

function Daily.cycleDay(streak: number): number
	return (math.max(streak, 1) - 1) % Settings.CycleLength + 1
end

-- What claiming on `today` would do. A claim day in the future (the clock moved back) reads as claimed.
function Daily.resolve(lastClaim: number, streak: number, shields: number, today: number): Resolution
	if lastClaim > 0 and lastClaim >= today then
		return { status = "claimed", streak = streak, shieldsUsed = 0, reset = false }
	end
	if lastClaim <= 0 then
		return { status = "claimable", streak = 1, shieldsUsed = 0, reset = false }
	end
	local missed = today - lastClaim - 1
	if missed <= 0 then
		return { status = "claimable", streak = streak + 1, shieldsUsed = 0, reset = false }
	end
	if shields >= missed then
		return { status = "claimable", streak = streak + 1, shieldsUsed = missed, reset = false }
	end
	return { status = "claimable", streak = 1, shieldsUsed = 0, reset = true }
end

function Daily.reward(cycleDay: number, perSecond: number, ceiling: number): Reward
	local entry = Settings.Days[cycleDay] or Settings.Days[#Settings.Days]
	return {
		cash = Income.grant(entry.Minutes * 60, clean(perSecond), Settings.CashFloor, clean(ceiling)),
		shards = entry.Shards, petXp = entry.PetXp, shield = entry.Shield,
	}
end

function Daily.questReward(id: string, perSecond: number, ceiling: number): { cash: number, shards: number }?
	local def = questDef(id)
	if not def then return nil end
	return { cash = Income.grant(def.Minutes * 60, clean(perSecond), Settings.CashFloor, clean(ceiling)), shards = def.Shards }
end

function Daily.bonusReward(perSecond: number, ceiling: number): { cash: number, shards: number }
	local bonus = Settings.Bonus
	return { cash = Income.grant(bonus.Minutes * 60, clean(perSecond), Settings.CashFloor, clean(ceiling)), shards = bonus.Shards }
end

-- Park-Miller: every product stays below 2^53
local function step(state: number): number
	return (state * 48271) % 2147483647
end
local function seeded(a: number, b: number): number
	return (math.floor(a) * 7919 + math.floor(b) * 104729) % 2147483646 + 1
end

-- The day's quests for a player: deterministic in (day, seed), distinct, and only ones their level and rebirths allow
function Daily.pickQuests(day: number, level: number, rebirths: number, seed: number): { string }
	local pool: { string } = {}
	for _, def in Settings.Quests do
		if level >= (def.MinLevel or 1) and rebirths >= (def.MinRebirths or 0) then
			table.insert(pool, def.Id)
		end
	end
	local state = seeded(day, seed)
	local picked: { string } = {}
	for _ = 1, math.min(Settings.DailyCount, #pool) do
		state = step(state)
		table.insert(picked, table.remove(pool, math.floor(state / 65536) % #pool + 1) :: string)
	end
	return picked
end

local function pickWeekly(week: number): string
	local state = step(seeded(week, 0))
	return Settings.Weekly[math.floor(state / 65536) % #Settings.Weekly + 1].Id
end

-- Starts a new day's quests (and a new week's) when the profile is behind. Returns true when anything changed.
function Daily.rollover(data: Data, today: number, level: number, rebirths: number, seed: number): boolean
	local changed = false
	if data.day ~= today then
		data.day = today
		data.quests = {}
		for _, id in Daily.pickQuests(today, level, rebirths, seed) do
			table.insert(data.quests, { id = id, progress = 0, claimed = false })
		end
		data.questBonusClaimed = false
		changed = true
	end
	local week = Daily.weekKey(today)
	if data.week ~= week or data.weekly.id == "" then
		data.week = week
		data.weekly = { id = pickWeekly(week), progress = 0, claimed = false }
		changed = true
	end
	return changed
end

local function bump(entry: Entry, event: string, amount: number): boolean
	local def = questDef(entry.id)
	if not def or def.Event ~= event or entry.claimed or entry.progress >= def.Target then
		return false
	end
	entry.progress = math.min(def.Target, entry.progress + amount)
	return true
end

function Daily.addProgress(data: Data, event: string, amount: number): boolean
	if amount ~= amount or amount <= 0 then return false end
	local changed = false
	for _, entry in data.quests do
		if bump(entry, event, amount) then changed = true end
	end
	if bump(data.weekly, event, amount) then changed = true end
	return changed
end

-- "d1".."dN" are today's quests in order, "w" is the weekly one
function Daily.findEntry(data: Data, slot: string): Entry?
	if slot == "w" then
		return data.weekly
	end
	local digits = string.match(slot, "^d(%d+)$")
	local index = if digits then tonumber(digits) else nil
	return if index then data.quests[index] else nil
end

local function ready(entry: Entry): boolean
	local def = questDef(entry.id)
	return def ~= nil and not entry.claimed and entry.progress >= def.Target
end

-- Marks a finished quest claimed and returns its id; nil when it is unknown, unfinished or already claimed
function Daily.claimQuest(data: Data, slot: string): string?
	local entry = Daily.findEntry(data, slot)
	if not entry or not ready(entry) then return nil end
	entry.claimed = true
	return entry.id
end

local function allClaimed(data: Data): boolean
	local seen = false
	for _, entry in data.quests do
		if questDef(entry.id) then
			seen = true
			if not entry.claimed then return false end
		end
	end
	return seen
end

function Daily.claimBonus(data: Data): boolean
	if data.questBonusClaimed or not allClaimed(data) then return false end
	data.questBonusClaimed = true
	return true
end

-- Applies a login claim to the profile. Returns the resolution; a "claimed" status changed nothing.
function Daily.claimLogin(data: Data, today: number): Resolution
	local result = Daily.resolve(data.lastClaim, data.streak, data.shields, today)
	if result.status == "claimable" then
		data.streak = result.streak
		data.shields -= result.shieldsUsed
		data.lastClaim = today
	end
	return result
end

-- Free shields only fill up to the cap; shields above it (bought ones) are kept. Returns how many were added.
function Daily.addFreeShield(data: Data, count: number): number
	local added = math.max(0, math.min(count, Settings.ShieldCap - data.shields))
	data.shields += added
	return added
end

local function view(slot: string, entry: Entry, def: DailyConfig.Quest, perSecond: number, ceiling: number): QuestView
	local pay = Daily.questReward(def.Id, perSecond, ceiling) :: { cash: number, shards: number }
	return {
		slot = slot, title = def.Title, progress = entry.progress, target = def.Target, claimed = entry.claimed,
		ready = ready(entry), cash = pay.cash, shards = pay.shards,
	}
end

-- Everything the menu shows, from the profile and the server's view of the player's income
function Daily.summary(data: Data, now: number, perSecond: number, ceiling: number): Summary
	local today = Daily.dayKey(now)
	local result = Daily.resolve(data.lastClaim, data.streak, data.shields, today)
	local claimed = result.status == "claimed"
	local cycleDay = Daily.cycleDay(if claimed then data.streak else result.streak)
	local quests: { QuestView } = {}
	local anyReady = not claimed
	for index, entry in data.quests do
		local def = questDef(entry.id)
		if def then
			local item = view("d" .. index, entry, def, perSecond, ceiling)
			table.insert(quests, item)
			if item.ready then anyReady = true end
		end
	end
	local weekly: QuestView? = nil
	local weeklyDef = questDef(data.weekly.id)
	if weeklyDef then
		weekly = view("w", data.weekly, weeklyDef, perSecond, ceiling)
		if (weekly :: QuestView).ready then anyReady = true end
	end
	local bonus = Daily.bonusReward(perSecond, ceiling)
	local bonusReady = not data.questBonusClaimed and allClaimed(data)
	if bonusReady then anyReady = true end
	return {
		claimedToday = claimed, streak = if claimed then data.streak else result.streak, cycleDay = cycleDay,
		shields = data.shields, shieldCap = Settings.ShieldCap, shieldsToUse = result.shieldsUsed, willReset = result.reset,
		reward = Daily.reward(cycleDay, perSecond, ceiling), quests = quests, weekly = weekly,
		bonus = { ready = bonusReady, claimed = data.questBonusClaimed, cash = bonus.cash, shards = bonus.shards },
		secondsLeft = DAY - math.floor(clean(now)) % DAY, anyReady = anyReady,
	}
end

return Daily
```

- [ ] **Step 6: Run the tests to verify they pass**

Run `return require(game.ServerStorage.Tests.Runner)("Daily")` in Edit mode.
Expected: `N passed, 0 failed`. If a failure names the `summary` test's last assertions, fix the assertion, not the rules: the summary test intentionally only asserts shape.

- [ ] **Step 7: Commit**

```bash
git add src/shared/Config/Daily.luau src/shared/Daily.luau src/shared/Config/init.luau tests/Daily.spec.luau
git commit -m "Add the daily streak, quest and shield rules with tests

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Profile v9 and badges (config + library)

**Files:**
- Create: `src/shared/Config/Badges.luau`
- Create: `src/server/Lib/Badges.luau`
- Modify: `src/shared/Config/init.luau`
- Modify: `src/server/Lib/ProfileTemplate.luau`
- Test: `tests/Badges.spec.luau`; extend `tests/Daily.spec.luau`

**Interfaces:**
- Consumes: `Config.Daily.StartShields` (Task 1).
- Produces: `Config.Badges` (`{ [string]: number }`), `Badges.pick(ids, key, done) -> number?`, `Badges.award(player, key)`; profile `daily` table.

- [ ] **Step 1: Write the failing tests**

Create `tests/Badges.spec.luau`:

```lua
--!strict
return function(t: any)
	local module = t.lib:FindFirstChild("Badges")
	t.test("badge library exists", function() t.ok(module, "Lib.Badges missing") end)
	if not module then return end
	local Badges = require(module)
	local Config = require(t.shared.Config)

	t.test("pick returns an id only when it is on and not yet given", function()
		local ids = { firstMeteor = 123, off = 0, bad = -4, fraction = 1.5 }
		t.eq(Badges.pick(ids, "firstMeteor", {}), 123)
		t.eq(Badges.pick(ids, "firstMeteor", { firstMeteor = true }), nil, "given this session")
		t.eq(Badges.pick(ids, "off", {}), nil, "id 0 is off")
		t.eq(Badges.pick(ids, "bad", {}), nil)
		t.eq(Badges.pick(ids, "fraction", {}), nil)
		t.eq(Badges.pick(ids, "missing", {}), nil)
	end)

	t.test("every shipped badge key is a known one and ids start off", function()
		local keys = { "firstMeteor", "firstCore", "firstRebirth", "rebirth10", "level25", "level50", "pageIron", "pageIce",
			"pageCrystal", "legendaryPet", "streak7" }
		for _, key in keys do t.ok(Config.Badges[key] ~= nil, key .. " missing from Config.Badges") end
		for key, id in Config.Badges do
			t.ok(table.find(keys, key), key .. " is not a known badge key")
			t.ok(type(id) == "number" and id >= 0 and id == math.floor(id), key .. " id")
		end
	end)
end
```

Append to `tests/Daily.spec.luau` inside the returned function (before the final `end`):

```lua
	t.test("a fresh profile gets the daily table with the start shield", function()
		local Template = require(t.lib.ProfileTemplate)
		t.eq(Template.version, 9)
		t.eq(Template.daily.shields, Settings.StartShields)
		t.eq(Template.daily.streak, 0)
		t.eq(Template.daily.weekly.id, "")
		local data = table.clone(Template.daily)
		data.quests, data.weekly = {}, { id = "", progress = 0, claimed = false }
		t.eq(Daily.rollover(data :: any, 20000, 1, 0, 1), true, "the template rolls over without error")
	end)
```

- [ ] **Step 2: Run to verify failure**

Run `Runner("Badges")` and `Runner("Daily")`. Expected: `Lib.Badges missing` and version mismatch failures.

- [ ] **Step 3: Badge config**

Create `src/shared/Config/Badges.luau`:

```lua
--!strict
-- Roblox Badge ids by key (DailyService awards them). 0 means the badge does not exist yet: nothing is awarded.
-- Create each badge in Creator Hub > Badges, then paste its id here.
return {
	firstMeteor = 0, -- first hit on a meteor
	firstCore = 0, -- first shared core crack
	firstRebirth = 0,
	rebirth10 = 0,
	level25 = 0,
	level50 = 0,
	pageIron = 0, -- completed a mineral index page
	pageIce = 0,
	pageCrystal = 0,
	legendaryPet = 0, -- owns a Legendary pet
	streak7 = 0, -- claimed day 7 of the daily streak
} :: { [string]: number }
```

In `src/shared/Config/init.luau` add `Badges = require(script.Badges),` after the `Daily` line.

- [ ] **Step 4: Badge library**

Create `src/server/Lib/Badges.luau`:

```lua
--!strict
-- Roblox Badges (Config.Badges). `pick` is the pure rule; `award` asks Roblox once per player per session and
-- never throws: a badge failing must not break gameplay.
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Badges = {}

local given: { [Player]: { [string]: boolean } } = {}

-- The badge id to award for `key`, or nil when the badge is off, unknown or already given this session
function Badges.pick(ids: { [string]: number }, key: string, done: { [string]: boolean }): number?
	local id = ids[key]
	if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) or done[key] then
		return nil
	end
	return id
end

function Badges.award(player: Player, key: string)
	local done = given[player]
	if not done then
		done = {}
		given[player] = done
	end
	local id = Badges.pick(Config.Badges, key, done)
	if not id then return end
	done[key] = true
	task.spawn(function()
		local ok, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		if not ok then
			warn("[Badges] could not award " .. key .. ": " .. tostring(err))
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	given[player] = nil
end)

return Badges
```

- [ ] **Step 5: Profile v9**

In `src/server/Lib/ProfileTemplate.luau` change the header comment `Profile schema v8` to `Profile schema v9`, change `version = 8,` to `version = 9,`, and add after the `stats = { ... },` block (before the closing `}`):

```lua
	-- Daily streak, quests and shields (Shared.Daily). `day` is the UTC day the quests were picked for.
	daily = {
		day = 0,
		lastClaim = 0, -- UTC day of the last login claim
		streak = 0,
		shields = 1, -- Config.Daily.StartShields; DataService fills it into old profiles
		quests = {}, -- { id, progress, claimed } for today
		questBonusClaimed = false,
		week = 0,
		weekly = { id = "", progress = 0, claimed = false },
	},
```

Check `src/server/Services/DataService.luau` for any code that compares `version` against a hard-coded 8 (`grep -n "version" src/server/Services/DataService.luau`). If a migration list keys on the old version, add a no-op step for 8 to 9 (new keys fill through `reconcile`).

- [ ] **Step 6: Run to verify**

Run `Runner("Badges")`, `Runner("Daily")`, then the full `Runner()` (expect all passing; if a profile-version test elsewhere expects 8, update it to 9).

- [ ] **Step 7: Commit**

```bash
git add src/shared/Config/Badges.luau src/server/Lib/Badges.luau src/shared/Config/init.luau src/server/Lib/ProfileTemplate.luau tests/Badges.spec.luau tests/Daily.spec.luau
git commit -m "Add badge config and library and the v9 profile daily table

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Server signals for level-ups, completed pages and hatches

**Files:**
- Modify: `src/server/Services/LevelService.luau`
- Modify: `src/server/Services/IndexService.luau`
- Modify: `src/server/Services/PetService.luau`

**Interfaces:**
- Produces: `LevelService.LeveledUp: Signal (player, level)`, `IndexService.PageCompleted: Signal (player, pageId)`, `PetService.EggHatched: Signal (player, eggId, petId, duplicate)`.

- [ ] **Step 1: LevelService**

Add `local Signal = require(ReplicatedStorage.Packages.Signal)` below the `Knit` require. After the `LevelService = Knit.CreateService({...})` block add:

```lua
LevelService.LeveledUp = Signal.new() -- (player, level) after a level is gained
```

In `LevelService:AddXp`, after `self.Client.LevelUp:Fire(player, data.level)` add:

```lua
		self.LeveledUp:Fire(player, data.level)
```

- [ ] **Step 2: IndexService**

Open `src/server/Services/IndexService.luau`. If it does not require Signal, add `local Signal = require(ReplicatedStorage.Packages.Signal)` next to its other requires (it already has `ReplicatedStorage`). After the `Knit.CreateService` block add `IndexService.PageCompleted = Signal.new() -- (player, pageId) when a first find completes a page`. In `IndexService:Award`, inside the `if isNew and MineralIndex.pageComplete(...)` block, after `applyTitle(player, data.index)` add `self.PageCompleted:Fire(player, page.Id)`.

- [ ] **Step 3: PetService**

`PetService` already imports Signal (it defines `PetService.PetBought`). Add below that line: `PetService.EggHatched = Signal.new() -- (player, eggId, petId, duplicate) after a hatch`. In `PetService:Hatch`, after `self.Client.Hatched:Fire(player, eggId, petId, duplicate)` add `self.EggHatched:Fire(player, eggId, petId, duplicate)`.

- [ ] **Step 4: Verify they load**

Wait for Rojo, then in Edit mode run `return require(game.ServerStorage.Tests.Runner)()`. Expected: all passing (these are services; no spec changes). Check the Studio output for script errors with `get_console_output`.

- [ ] **Step 5: Commit**

```bash
git add src/server/Services/LevelService.luau src/server/Services/IndexService.luau src/server/Services/PetService.luau
git commit -m "Expose level-up, completed-page and hatch signals on the server

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: DailyService

**Files:**
- Create: `src/server/Services/DailyService.luau`

**Interfaces:**
- Consumes: everything from Tasks 1 to 3, `PlayerStateService:Get/AddCash/AddShards/ReplicateNow`, `EconomyService:ExpectedIncome(player).perSecond`, `RewardService:Bonus(player, kind, text)`, `TelemetryService:custom(player, name, value, fields)`, `Rebirth.cost`, `Pets.addXp`, `Pets.def`.
- Produces (client): `DailyService.Summary` property (per player, `Daily.Summary`), `DailyService.Notice` signal `(text)`, methods `ClaimLogin() -> boolean`, `ClaimQuest(slot: string) -> boolean`, `ClaimBonus() -> boolean`.

Services are auto-registered by `Knit.AddServices(script.Parent.Services)`; no registration step.

- [ ] **Step 1: Create the service**

Create `src/server/Services/DailyService.luau`:

```lua
--!strict
-- Daily streak, quests and badges (Config.Daily, Shared.Daily, Config.Badges). The rules are pure; this service owns
-- profile.daily: it rolls the quests over on join and at each UTC midnight, counts progress from the other services'
-- server signals, pays claims, awards Roblox Badges and publishes a Summary the Daily menu draws.
-- Studio only: ServerStorage attribute DevDayOffset (a number of days) moves this service's clock for testing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Daily = require(ReplicatedStorage.Shared.Daily)
local Format = require(ReplicatedStorage.Shared.Format)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)
local Badges = require(script.Parent.Parent.Lib.Badges)

local DailyService = Knit.CreateService({
	Name = "DailyService",
	Client = {
		Summary = Knit.CreateProperty(nil), -- per player: Shared.Daily.Summary
		Notice = Knit.CreateSignal(), -- (text)
	},
})

local PlayerStateService
local EconomyService
local RewardService
local TelemetryService

local PUBLISH_INTERVAL = 1 -- seconds between summary sends; hits arrive many times a second
local dirty: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}
local joinedThisMeteor: { [Player]: boolean } = {}

local function now(): number
	local offset = if RunService:IsStudio() then ServerStorage:GetAttribute("DevDayOffset") else nil
	return os.time() + (if type(offset) == "number" then offset * 86400 else 0)
end

local function context(player: Player): (any, number, number)
	local data = PlayerStateService:Get(player)
	if not data then return nil, 0, 0 end
	local perSecond = EconomyService:ExpectedIncome(player).perSecond
	local ceiling = Rebirth.cost(data.rebirths) * Config.Daily.CashCeilingShare
	return data, perSecond, ceiling
end

function DailyService:Publish(player: Player)
	local data = PlayerStateService:Get(player)
	if not data then return end
	dirty[player] = nil
	local _, perSecond, ceiling = context(player)
	Daily.rollover(data.daily, Daily.dayKey(now()), data.level, data.rebirths, player.UserId)
	self.Client.Summary:SetFor(player, Daily.summary(data.daily, now(), perSecond, ceiling))
end

local function markDirty(player: Player)
	dirty[player] = true
end

-- Adds cash, shards and pet XP, then says so in the reward feed
local function pay(player: Player, data: any, label: string, cash: number, shards: number, petXp: number?)
	if cash > 0 then PlayerStateService:AddCash(player, cash) end
	if shards > 0 then PlayerStateService:AddShards(player, shards) end
	if petXp and petXp > 0 then
		for _, petId in data.pets.equipped do
			local entry = data.pets.owned[petId]
			if entry then Pets.addXp(entry, petXp) end
		end
	end
	local parts = {}
	if cash > 0 then table.insert(parts, "+" .. Format.cash(cash)) end
	if shards > 0 then table.insert(parts, "+" .. shards .. " ◆") end
	if petXp and petXp > 0 then table.insert(parts, "+" .. petXp .. " pet XP") end
	RewardService:Bonus(player, "daily", label .. ": " .. table.concat(parts, " and "))
end

local function gate(player: Player): boolean
	local allowed, stamp = RequestGate.check(lastRequest[player], os.clock(), 0.3)
	lastRequest[player] = stamp
	return allowed
end

function DailyService:ClaimLogin(player: Player): boolean
	local data, perSecond, ceiling = context(player)
	if not data then return false end
	Daily.rollover(data.daily, Daily.dayKey(now()), data.level, data.rebirths, player.UserId)
	local result = Daily.claimLogin(data.daily, Daily.dayKey(now()))
	if result.status ~= "claimable" then return false end
	local cycleDay = Daily.cycleDay(result.streak)
	local reward = Daily.reward(cycleDay, perSecond, ceiling)
	Daily.addFreeShield(data.daily, reward.shield)
	pay(player, data, "Day " .. cycleDay .. " streak", reward.cash, reward.shards, reward.petXp)
	if result.shieldsUsed > 0 then
		self.Client.Notice:Fire(player, string.format("A streak shield covered %d missed day%s.", result.shieldsUsed, if result.shieldsUsed == 1 then "" else "s"))
	elseif result.reset then
		self.Client.Notice:Fire(player, "Your streak started over. Claim every day to build it back up!")
	end
	TelemetryService:custom(player, "daily_claimed", result.streak, { if result.reset then "reset" elseif result.shieldsUsed > 0 then "shield" else "kept" })
	if cycleDay == Config.Daily.CycleLength then Badges.award(player, "streak7") end
	PlayerStateService:ReplicateNow(player)
	self:Publish(player)
	return true
end

function DailyService:ClaimQuest(player: Player, slot: string): boolean
	local data, perSecond, ceiling = context(player)
	if not data then return false end
	local id = Daily.claimQuest(data.daily, slot)
	if not id then return false end
	local reward = Daily.questReward(id, perSecond, ceiling) :: { cash: number, shards: number }
	pay(player, data, "Quest complete", reward.cash, reward.shards)
	TelemetryService:custom(player, "quest_claimed", 1, { if slot == "w" then "weekly" else "daily", id })
	PlayerStateService:ReplicateNow(player)
	self:Publish(player)
	return true
end

function DailyService:ClaimBonus(player: Player): boolean
	local data, perSecond, ceiling = context(player)
	if not data or not Daily.claimBonus(data.daily) then return false end
	local reward = Daily.bonusReward(perSecond, ceiling)
	pay(player, data, "All daily quests done", reward.cash, reward.shards)
	TelemetryService:custom(player, "quest_claimed", 1, { "bonus", "all" })
	PlayerStateService:ReplicateNow(player)
	self:Publish(player)
	return true
end

function DailyService.Client:ClaimLogin(player: Player): boolean
	if not gate(player) then return false end
	return self.Server:ClaimLogin(player)
end

function DailyService.Client:ClaimQuest(player: Player, slot: any): boolean
	if not gate(player) or type(slot) ~= "string" or #slot > 8 then return false end
	return self.Server:ClaimQuest(player, slot)
end

function DailyService.Client:ClaimBonus(player: Player): boolean
	if not gate(player) then return false end
	return self.Server:ClaimBonus(player)
end

-- Counts `amount` of `event` toward the player's quests; the summary follows within PUBLISH_INTERVAL
local function progress(player: Player, event: string, amount: number)
	local data = PlayerStateService:Get(player)
	if data and Daily.addProgress(data.daily, event, amount) then
		markDirty(player)
	end
end

function DailyService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	EconomyService = Knit.GetService("EconomyService")
	RewardService = Knit.GetService("RewardService")
	TelemetryService = Knit.GetService("TelemetryService")
end

function DailyService:KnitStart()
	local DataService = Knit.GetService("DataService")
	local NodeService = Knit.GetService("NodeService")
	local MeteorService = Knit.GetService("MeteorService")
	local LevelService = Knit.GetService("LevelService")
	local IndexService = Knit.GetService("IndexService")
	local PetService = Knit.GetService("PetService")
	local RebirthService = Knit.GetService("RebirthService")
	local RefineryService = Knit.GetService("RefineryService")

	local function publish(player: Player)
		local ok, err = pcall(function() self:Publish(player) end)
		if not ok then warn("[DailyService] could not publish for " .. player.Name .. ": " .. tostring(err)) end
	end
	DataService.ProfileLoaded:Connect(function(player)
		task.defer(publish, player)
	end)
	for _, player in Players:GetPlayers() do
		if PlayerStateService:Get(player) then task.defer(publish, player) end
	end
	Players.PlayerRemoving:Connect(function(player)
		dirty[player], lastRequest[player], joinedThisMeteor[player] = nil, nil, nil
	end)

	-- Quest progress. Hits are validated by NodeService before the signal fires.
	NodeService.Hit:Connect(function(player: Player, kind: string)
		if kind ~= "Crust" and kind ~= "Core" then return end
		if kind == "Crust" then progress(player, "crustHit", 1) end
		if not joinedThisMeteor[player] then
			joinedThisMeteor[player] = true
			progress(player, "meteorJoin", 1)
			Badges.award(player, "firstMeteor")
		end
	end)
	MeteorService.Landed:Connect(function()
		table.clear(joinedThisMeteor)
	end)
	RewardService.ShardsAwarded:Connect(function(player: Player)
		progress(player, "coreCrack", 1)
		Badges.award(player, "firstCore")
	end)
	EconomyService.BarsSold:Connect(function(player: Player, bars: number)
		progress(player, "barsSold", bars)
	end)
	RefineryService.OreDeposited:Connect(function(player: Player, ore: number)
		progress(player, "oreDeposited", ore)
	end)
	PetService.EggHatched:Connect(function(player: Player)
		progress(player, "hatch", 1)
	end)

	-- Badges
	RebirthService.Reborn:Connect(function(player: Player, rebirths: number)
		if rebirths >= 1 then Badges.award(player, "firstRebirth") end
		if rebirths >= 10 then Badges.award(player, "rebirth10") end
	end)
	LevelService.LeveledUp:Connect(function(player: Player, level: number)
		if level >= 25 then Badges.award(player, "level25") end
		if level >= 50 then Badges.award(player, "level50") end
	end)
	IndexService.PageCompleted:Connect(function(player: Player, pageId: string)
		Badges.award(player, "page" .. pageId)
	end)
	PetService.PetBought:Connect(function(player: Player, petId: string)
		local def = Pets.def(petId)
		if def and def.Rarity == "legendary" then Badges.award(player, "legendaryPet") end
	end)

	-- One loop sends dirty summaries and notices a new UTC day for players who stay online past midnight
	task.spawn(function()
		while true do
			task.wait(PUBLISH_INTERVAL)
			local today = Daily.dayKey(now())
			for _, player in Players:GetPlayers() do
				local data = PlayerStateService:Get(player)
				if data and (dirty[player] or data.daily.day ~= today) then
					publish(player)
				end
			end
		end
	end)
end

return DailyService
```

- [ ] **Step 2: Check the service starts**

Wait for Rojo. Start Play (standing permission), then `get_console_output`. Expected: no `[DailyService]` warnings and no red errors mentioning DailyService. Stop Play when done.

- [ ] **Step 3: Drive a claim end to end**

While in Play, from the **Client** datamodel via `execute_luau`:

```lua
local rf = game.ReplicatedStorage.Packages.Knit.Services.DailyService.RF
return { first = rf.ClaimLogin:InvokeServer(), second = rf.ClaimLogin:InvokeServer() }
```

Expected: `first = true` (or `false` if the 0.3 s request gate swallowed it: wait 0.5 s and retry), `second = false`. Then from the Server datamodel read `game.ServerStorage.DevGrant:Invoke(game.Players:GetPlayers()[1])` and check `daily.streak == 1`, `daily.lastClaim` equals today's day key, and that cash/shards went up. Set `game.ServerStorage:SetAttribute("DevDayOffset", 1)` and claim again: `daily.streak == 2`. Offset 3: streak resets to 1 and a notice fires. Stop Play and clear the attribute.

- [ ] **Step 4: Commit**

```bash
git add src/server/Services/DailyService.luau
git commit -m "Add DailyService: streak claims, quests, badges and the summary property

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Streak Shield product

**Files:**
- Modify: `src/shared/Config/Monetization.luau`
- Modify: `src/shared/Purchases.luau`
- Modify: `src/shared/Config/Store.luau`
- Modify: `src/server/Services/MonetizationService.luau`
- Test: `tests/Purchases.spec.luau`

**Interfaces:**
- Consumes: `data.daily.shields` (Task 2).
- Produces: product key `StreakShield` (`Id = 0`, `Robux = 9`); `Purchases.grant(data, "StreakShield")` adds one shield, uncapped.

- [ ] **Step 1: Write the failing tests**

In `tests/Purchases.spec.luau`, in the test titled `products without a dashboard entry have the intended prices and stay off sale`, change `for key, price in { TipJar = 5 } do` to `for key, price in { TipJar = 5, StreakShield = 9 } do`. Add a new test at the end of the returned function:

```lua
	t.test("Streak Shield adds one shield above the free cap and needs no cash", function()
		local data: any = { daily = { shields = Config.Daily.ShieldCap } }
		local result = Purchases.grant(data, "StreakShield")
		t.ok(result ~= nil, "the grant exists")
		t.eq(data.daily.shields, Config.Daily.ShieldCap + 1)
		Purchases.grant(data, "StreakShield")
		t.eq(data.daily.shields, Config.Daily.ShieldCap + 2, "bought shields are not capped")
	end)
```

If the spec file names the module differently, use the local that the existing `Purchases.grant(...)` calls in that file use.

- [ ] **Step 2: Run to verify failure**

`Runner("Purchases")`. Expected: `StreakShield` is nil in Products, and the grant returns nil.

- [ ] **Step 3: Add the product**

In `src/shared/Config/Monetization.luau`, add to `Monetization.Products` (next to `TipJar`):

```lua
	StreakShield = {
		Key = "StreakShield",
		Id = 0, -- the owner adds the Creator Dashboard item; 0 keeps it off sale
		Name = "Streak Shield",
		Robux = 9,
		Description = "Covers one missed day of your daily streak, so you don't lose it. Not random, no other effect.",
	} :: Product,
```

Add `"StreakShield"` to the end of `Monetization.ProductOrder`.

- [ ] **Step 4: Grant rule**

In `src/shared/Purchases.luau`, in `Purchases.grant`, add before the final `else`:

```lua
	elseif key == "StreakShield" then
		data.daily.shields = (data.daily.shields or 0) + 1
```

- [ ] **Step 5: Store listing and notice**

In `src/shared/Config/Store.luau`, add `"StreakShield"` to the `Keys` of the `boosts` section: `Keys = { "Overclock", "MiniOverclock", "StreakShield" },`.

In `src/server/Services/MonetizationService.luau`, in the notice chain, add before `elseif grant.shards and grant.shards > 0 then`:

```lua
	elseif key == "StreakShield" then
		effect.notice = "Streak Shield added: it covers one missed day of your streak."
```

Also check `StoreController` and `Purchases.luau` for any per-key switch that must know the new key (`grep -n "PetSlot" src/client/Controllers/StoreController.luau src/shared/*.luau`); products with no special rule fall through to the generic card, so normally nothing else is needed.

- [ ] **Step 6: Run to verify**

`Runner("Purchases")`, `Runner("StoreLayout")`, then the full `Runner()`. Expected: all pass (the StoreLayout spec checks every key appears in exactly one section).

- [ ] **Step 7: Commit**

```bash
git add src/shared/Config/Monetization.luau src/shared/Purchases.luau src/shared/Config/Store.luau src/server/Services/MonetizationService.luau tests/Purchases.spec.luau
git commit -m "Add the Streak Shield product (9 Robux, off sale until its id is set)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Daily menu, controller and entry points

**Files:**
- Create: `src/client/NativeMenus/Daily.luau`
- Create: `src/client/Controllers/DailyController.luau`
- Modify: `src/client/NativeHudMenus.luau`
- Modify (add `"DailyOpen"` after `"PetsOpen"` in the menu-flag lists): `src/client/Controllers/CustomHudController.luau`, `FastWalkController.luau`, `FeedbackController.luau`, `FieldTravelController.luau`, `MeteorFXController.luau`, `OfferController.luau`, `src/client/ExactNavButton.luau`

**Interfaces:**
- Consumes: `DailyService.Summary` (observed), `ClaimLogin/ClaimQuest/ClaimBonus`, `Notice`.
- Produces: player attributes `DailyOpen` (menu open) and `DailyReady` (something to claim); a `DailyMenu` ScreenGui.

No automated test covers the client (no GUI harness in the repo); verification is the Play checks in Step 7.

- [ ] **Step 1: The menu**

Create `src/client/NativeMenus/Daily.luau`:

```lua
--!strict
-- Authoring for the Daily Rewards panel (Config.Daily): the 7-day streak with a CLAIM button and shield count,
-- today's quests, the all-done bonus and the weekly quest. DailyController binds everything by name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Daily = {}

Daily.QUEST_SLOTS = { "Quest1", "Quest2", "Quest3", "Weekly", "Bonus" }

local function questRow(body: ScrollingFrame, name: string, order: number)
	local row = NativeUI.create("Frame", {
		Name = name, LayoutOrder = order, Size = UDim2.new(1, -8, 0, 78), BackgroundColor3 = NativeUI.CARD,
		BorderSizePixel = 0, ZIndex = 4,
	}, body)
	NativeUI.surface(row, 4, .8)
	local title = NativeUI.text(row, "Title", "", UDim2.fromOffset(12, 6), UDim2.new(1, -130, 0, 24))
	title.TextSize, title.TextScaled = 18, true
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 11, MaxTextSize = 18 }, title)
	NativeUI.text(row, "Progress", "", UDim2.fromOffset(12, 32), UDim2.new(1, -130, 0, 18), true).TextColor3 = NativeUI.MUTED
	NativeUI.text(row, "Reward", "", UDim2.fromOffset(12, 52), UDim2.new(1, -130, 0, 18), true).TextColor3 = NativeUI.HUD_GOLD
	local claim = NativeUI.button(row, "Claim", "CLAIM", UDim2.new(1, -118, 0, 17), UDim2.fromOffset(106, 44), NativeUI.GREEN)
	claim.TextSize = 16
end

function Daily.build(): ScreenGui
	local gui = NativeUI.menu("DailyMenu", "Daily Rewards", NativeUI.ORANGE, 430, 600)
	gui.DisplayOrder = 28
	local panel = gui:WaitForChild("Panel") :: Frame
	panel.Size = UDim2.new(0, 430, 0.92, 0)
	NativeUI.create("UISizeConstraint", { MaxSize = Vector2.new(430, 620), MinSize = Vector2.new(280, 300) }, panel)
	local title = panel:WaitForChild("Title") :: TextLabel
	title.TextScaled = true
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 18, MaxTextSize = 28 }, title)

	local body = NativeUI.create("ScrollingFrame", {
		Name = "Body", Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 1, -74),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = NativeUI.MUTED,
		VerticalScrollBarInset = Enum.ScrollBarInset.Always, ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, ZIndex = 4,
	}, panel)
	NativeUI.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)

	-- The streak card: seven day chips, what today pays, CLAIM and the shield line
	local streak = NativeUI.create("Frame", {
		Name = "StreakCard", LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 226), BackgroundColor3 = NativeUI.CARD,
		BorderSizePixel = 0, ZIndex = 4,
	}, body)
	NativeUI.surface(streak, 4, .8)
	NativeUI.text(streak, "Heading", "", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 28))
	local days = NativeUI.create("Frame", { Name = "Days", Position = UDim2.fromOffset(8, 40), Size = UDim2.new(1, -16, 0, 74), BackgroundTransparency = 1, ZIndex = 4 }, streak)
	NativeUI.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, days)
	for index, entry in Config.Daily.Days do
		local chip = NativeUI.create("Frame", { Name = "Day" .. index, LayoutOrder = index, Size = UDim2.new(1 / Config.Daily.CycleLength, -4, 1, 0), BackgroundColor3 = NativeUI.PANEL, BorderSizePixel = 0, ZIndex = 4 }, days)
		NativeUI.surface(chip, 4, .85)
		local number = NativeUI.text(chip, "Number", tostring(index), UDim2.fromOffset(0, 4), UDim2.new(1, 0, 0, 24))
		number.TextXAlignment, number.TextSize = Enum.TextXAlignment.Center, 20
		local prize = if entry.Shards > 0 then "+" .. entry.Shards .. "◆" else "$"
		if entry.Shield > 0 then prize ..= "\n+shield" end
		local label = NativeUI.text(chip, "Prize", prize, UDim2.fromOffset(0, 30), UDim2.new(1, 0, 1, -32), true)
		label.TextXAlignment, label.TextYAlignment, label.TextWrapped, label.TextSize = Enum.TextXAlignment.Center, Enum.TextYAlignment.Top, true, 11
	end
	local reward = NativeUI.text(streak, "Reward", "", UDim2.fromOffset(12, 122), UDim2.new(1, -24, 0, 22), true)
	reward.TextSize, reward.TextColor3 = 15, NativeUI.HUD_GOLD
	local claim = NativeUI.button(streak, "Claim", "CLAIM", UDim2.new(0.5, 0, 0, 150), UDim2.fromOffset(200, 44), NativeUI.GREEN)
	claim.AnchorPoint, claim.TextSize = Vector2.new(0.5, 0), 20
	local shields = NativeUI.text(streak, "Shields", "", UDim2.new(0, 12, 1, -28), UDim2.new(1, -24, 0, 22), true)
	shields.TextSize, shields.TextColor3 = 14, NativeUI.MUTED

	local header = NativeUI.text(body, "QuestHeader", "TODAY'S QUESTS", UDim2.new(), UDim2.new(1, -8, 0, 26))
	header.LayoutOrder = 2
	for order, name in Daily.QUEST_SLOTS do
		questRow(body, name, 2 + order)
	end
	local footer = NativeUI.text(body, "Footer", "", UDim2.new(), UDim2.new(1, -8, 0, 24), true)
	footer.LayoutOrder, footer.TextSize, footer.TextColor3 = 20, 14, NativeUI.MUTED
	return gui
end

return Daily
```

- [ ] **Step 2: The controller**

Create `src/client/Controllers/DailyController.luau`:

```lua
--!strict
-- Daily Rewards menu (Config.Daily, Shared.Daily). Opens from the "Daily rewards" row in Settings, and once a session
-- on its own when there is a claim waiting. Sets the DailyReady attribute (something to claim) for the gear's dot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Sfx = require(script.Parent.Parent.Sfx)
local RewardFX = require(script.Parent.Parent.RewardFX)
local DailyMenu = require(script.Parent.Parent.NativeMenus.Daily)
local player = Players.LocalPlayer
local DailyController = Knit.CreateController({ Name = "DailyController" })

local OTHER_MENUS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "PetsOpen", "SettingsOpen", "RefineryOpen", "HatchOpen", "IntroOpen", "BackpackOpen", "PerksOpen" }

local function otherMenuOpen(): boolean
	for _, name in OTHER_MENUS do
		if player:GetAttribute(name) == true then return true end
	end
	return false
end

local function clock(seconds: number): string
	return string.format("%dh %02dm", seconds // 3600, seconds % 3600 // 60)
end

local function rewardText(cash: number, shards: number, extra: string?): string
	local parts = { "+" .. Format.cash(cash) }
	if shards > 0 then table.insert(parts, "+" .. shards .. " ◆") end
	if extra then table.insert(parts, extra) end
	return table.concat(parts, "  ")
end

function DailyController:KnitStart()
	local DailyService = Knit.GetService("DailyService")
	local HUDController = Knit.GetController("HUDController")
	local gui = NativeUI.getOrBuild("DailyMenu", DailyMenu.build)
	local panel = gui:WaitForChild("Panel") :: Frame
	local body = panel:WaitForChild("Body") :: ScrollingFrame
	local streak = body:WaitForChild("StreakCard") :: Frame
	local summary: any = nil
	local busy = false
	local popupShown = false

	local function update()
		local s = summary
		if not s then return end
		;(streak:WaitForChild("Heading") :: TextLabel).Text = string.format("Day %d streak  ·  next reset in %s", s.streak, clock(s.secondsLeft))
		for index = 1, Config.Daily.CycleLength do
			local chip = (streak:WaitForChild("Days") :: Frame):FindFirstChild("Day" .. index) :: Frame?
			if chip then
				local done = index < s.cycleDay or (index == s.cycleDay and s.claimedToday)
				chip.BackgroundColor3 = if done then NativeUI.GREEN elseif index == s.cycleDay then NativeUI.ORANGE else NativeUI.PANEL
			end
		end
		;(streak:WaitForChild("Reward") :: TextLabel).Text = (if s.claimedToday then "Claimed today. Back tomorrow for: " else "Today pays: ")
			.. rewardText(s.reward.cash, s.reward.shards, if s.reward.petXp > 0 then "+" .. s.reward.petXp .. " pet XP" else nil)
		local claim = streak:WaitForChild("Claim") :: TextButton
		NativeUI.enable(claim, not s.claimedToday and not busy, NativeUI.GREEN)
		claim.Text = if s.claimedToday then "CLAIMED" else "CLAIM"
		local note = if s.willReset then " Your streak will start over."
			elseif s.shieldsToUse > 0 then " A shield will cover your missed days."
			else ""
		;(streak:WaitForChild("Shields") :: TextLabel).Text = string.format("Streak shields: %d. Each covers one missed day.%s", s.shields, note)

		local rows: { [string]: any } = { Quest1 = s.quests[1], Quest2 = s.quests[2], Quest3 = s.quests[3], Weekly = s.weekly }
		for _, name in DailyMenu.QUEST_SLOTS do
			local row = body:FindFirstChild(name) :: Frame?
			if not row then continue end
			local quest = rows[name]
			if name == "Bonus" then
				row.Visible = true
				;(row:FindFirstChild("Title") :: TextLabel).Text = "All three daily quests"
				;(row:FindFirstChild("Progress") :: TextLabel).Text = if s.bonus.claimed then "Bonus claimed" else "Claim all three to unlock"
				;(row:FindFirstChild("Reward") :: TextLabel).Text = rewardText(s.bonus.cash, s.bonus.shards)
				local claimBonus = row:FindFirstChild("Claim") :: TextButton
				NativeUI.enable(claimBonus, s.bonus.ready and not busy, NativeUI.GREEN)
				claimBonus.Text = if s.bonus.claimed then "DONE" else "CLAIM"
			elseif quest then
				row.Visible = true
				;(row:FindFirstChild("Title") :: TextLabel).Text = (if name == "Weekly" then "WEEKLY: " else "") .. quest.title
				;(row:FindFirstChild("Progress") :: TextLabel).Text = string.format("%s / %s", Format.number(quest.progress), Format.number(quest.target))
				;(row:FindFirstChild("Reward") :: TextLabel).Text = rewardText(quest.cash, quest.shards)
				local claimQuest = row:FindFirstChild("Claim") :: TextButton
				NativeUI.enable(claimQuest, quest.ready and not busy, NativeUI.GREEN)
				claimQuest.Text = if quest.claimed then "DONE" else "CLAIM"
			else
				row.Visible = false
			end
		end
		;(body:WaitForChild("Footer") :: TextLabel).Text = "Quests and the streak reset at midnight UTC."
		player:SetAttribute("DailyReady", s.anyReady == true)
	end

	-- Calls the server, then refreshes; `celebrate` plays the reward burst when it paid
	local function request(call: () -> boolean)
		if busy then return end
		busy = true
		update()
		task.spawn(function()
			local ok, paid = pcall(call)
			if ok and paid then
				Sfx.play("Upgrade", nil, nil, 1.1)
				RewardFX.burst(Config.RewardFX.Colors.Rebirth, 0.8)
			end
			busy = false
			update()
		end)
	end
	;(streak:WaitForChild("Claim") :: TextButton).Activated:Connect(function()
		request(function() return DailyService:ClaimLogin() end)
	end)
	for _, name in DailyMenu.QUEST_SLOTS do
		local row = body:WaitForChild(name) :: Frame
		;(row:WaitForChild("Claim") :: TextButton).Activated:Connect(function()
			if name == "Bonus" then
				request(function() return DailyService:ClaimBonus() end)
			else
				local slot = if name == "Weekly" then "w" else "d" .. string.sub(name, 6)
				request(function() return DailyService:ClaimQuest(slot) end)
			end
		end)
	end

	player:SetAttribute("DailyOpen", false)
	NativeUI.bindOpen(gui, "DailyOpen", function()
		player:SetAttribute("DailyOpen", false)
	end)
	DailyService.Summary:Observe(function(value)
		summary = value
		update()
		-- once per session, when something is waiting and nothing else is on screen
		if value and value.anyReady and not popupShown then
			popupShown = true
			task.spawn(function()
				local waited = 0
				while (player:GetAttribute("LoadingDone") ~= true or otherMenuOpen()) and waited < 30 do
					task.wait(1)
					waited += 1
				end
				if not otherMenuOpen() and summary and summary.anyReady then
					player:SetAttribute("DailyOpen", true)
				end
			end)
		end
	end)
	DailyService.Notice:Connect(function(message: string)
		HUDController:Toast(message)
	end)
	-- the countdown in the heading
	task.spawn(function()
		while true do
			task.wait(30)
			if summary then summary.secondsLeft = math.max(0, summary.secondsLeft - 30) end
			if gui.Enabled then update() end
		end
	end)
end

return DailyController
```

If `Config.RewardFX.Colors.Rebirth` or `Sfx.play("Upgrade", ...)` differ from what `PerksController` uses, copy the exact calls from `src/client/Controllers/PerksController.luau` (they are the ones used there).

- [ ] **Step 3: Menu flag lists**

Run from the repo root (Git Bash):

```bash
grep -n '"PetsOpen",' src/client/Controllers/CustomHudController.luau src/client/Controllers/FastWalkController.luau src/client/Controllers/FeedbackController.luau src/client/Controllers/FieldTravelController.luau src/client/Controllers/MeteorFXController.luau src/client/Controllers/OfferController.luau src/client/ExactNavButton.luau src/client/NativeHudMenus.luau
```

In each match, change `"PetsOpen",` to `"PetsOpen", "DailyOpen",` (use Edit, not sed, so line endings are preserved: `NativeHudMenus.luau` has two lists, `SETTINGS_BLOCKERS` and `BACKPACK_BLOCKERS`, change both). Re-run the grep for `"DailyOpen"` to confirm 9 hits.

- [ ] **Step 4: Settings row and gear dot**

In `src/client/NativeHudMenus.luau`, directly after the `for index, preference in PREFERENCES do ... end` loop (before `if player:GetAttribute("SettingsOpen") == nil then`), add:

```lua
	-- Daily rewards: a row at the top of Settings and a dot on the gear while something is waiting. Built here, not in
	-- the saved Settings prefab, so places that already have one get it too.
	local dailyRow = preferences:FindFirstChild("OpenDaily") :: TextButton?
	if not dailyRow then
		local source = preferences:WaitForChild(PREFERENCES[1].name) :: TextButton
		local copy = source:Clone()
		copy.Name, copy.LayoutOrder = "OpenDaily", 0
		local label = copy:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then label.Text = "Daily rewards" end
		local value = copy:FindFirstChild("State")
		if value and value:IsA("TextLabel") then
			value.Text, value.BackgroundColor3 = "OPEN", UI.ORANGE
		end
		copy.Parent = preferences
		dailyRow = copy
	end
	local dot = Instance.new("Frame")
	dot.Name, dot.Size, dot.AnchorPoint, dot.Position = "DailyDot", UDim2.fromOffset(12, 12), Vector2.new(1, 0), UDim2.new(1, -2, 0, 2)
	dot.BackgroundColor3, dot.BorderSizePixel, dot.ZIndex, dot.Visible = Color3.fromRGB(255, 80, 80), 0, 10, false
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	dot.Parent = openSettings
	local function updateDailyDot() dot.Visible = player:GetAttribute("DailyReady") == true end
	player:GetAttributeChangedSignal("DailyReady"):Connect(updateDailyDot)
	updateDailyDot()
	;(dailyRow :: TextButton).Activated:Connect(function()
		player:SetAttribute("SettingsOpen", false)
		player:SetAttribute("DailyOpen", true)
	end)
```

- [ ] **Step 5: Run the suite**

Wait for Rojo, then `return require(game.ServerStorage.Tests.Runner)()` in Edit mode. Expected: all passing (layout specs are unaffected: `HudLayout` was not changed).

- [ ] **Step 6: Play check (menu and entry points)**

Start Play. In the Client datamodel confirm `game.Players.LocalPlayer.PlayerGui:FindFirstChild("DailyMenu")` exists and `get_console_output` shows no errors from DailyController or NativeHudMenus. With `screen_capture` check: (a) after loading finishes the Daily menu pops up once, showing 7 chips, a CLAIM button and 3 quests plus the weekly and bonus rows; (b) pressing CLAIM pays and the chip turns green; (c) closing it and opening Settings shows the "Daily rewards" row first, and the red dot on the gear appears only while something is claimable; (d) repeat at a phone viewport by `execute_luau` (Edit) is not available, so check the layout through the 0.92 height and `UISizeConstraint` only and note that an on-device phone check was not run. Stop Play.

- [ ] **Step 7: Commit**

```bash
git add src/client/NativeMenus/Daily.luau src/client/Controllers/DailyController.luau src/client/NativeHudMenus.luau src/client/Controllers/CustomHudController.luau src/client/Controllers/FastWalkController.luau src/client/Controllers/FeedbackController.luau src/client/Controllers/FieldTravelController.luau src/client/Controllers/MeteorFXController.luau src/client/Controllers/OfferController.luau src/client/ExactNavButton.luau
git commit -m "Add the Daily Rewards menu with a Settings row, a ready dot and a join popup

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Docs and final verification

**Files:**
- Modify: `docs/archive/superpowers/specs/2026-10-11-daily-rewards-design.md`
- Modify: `README.md`

- [ ] **Step 1: Update the spec to match what was built**

In the spec: change the "Shield purchase" bullet to say paid shields are not capped (only free gains stop at `ShieldCap`); change the "Client" section's first sentence to say the entry points are a "Daily rewards" row in Settings, a ready dot on the gear and a once-per-session popup, with a dedicated nav tile left for later because `HudLayout` has five hand-tuned layouts; remove the `DailyLayout` mention under Testing.

- [ ] **Step 2: README**

Add a short `**Daily rewards (Shared.Daily, Config.Daily, DailyService)**` block to the Status area of `README.md` covering: the streak and shields, quests, badges (`Config.Badges` ids are `0` until created), the Streak Shield product (id `0` until the owner adds it), the entry points, the Studio `DevDayOffset` attribute, and profile v9. Add `DailyService` to the "Server services" list and `DailyController` to the "Client controllers" list.

- [ ] **Step 3: Full verification**

`return require(game.ServerStorage.Tests.Runner)()` in Edit mode: expected `N passed, 0 failed` with N greater than 572. Run `git status` and confirm only intended files changed.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/archive/superpowers/specs/2026-10-11-daily-rewards-design.md
git commit -m "Document daily rewards, quests, badges and the Streak Shield

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

## Owner follow-ups (not code)

- Create the badges in Creator Hub and paste the ids into `src/shared/Config/Badges.luau`.
- Create the Streak Shield developer product (9 Robux) and paste its id into `Config.Monetization.Products.StreakShield.Id`, then update the `Purchases.spec` expectation (the product moves from "off sale" to the live table).
- Decide whether a dedicated DAILY nav tile is wanted; it needs a position and icon in all five `HudLayout` layouts.
