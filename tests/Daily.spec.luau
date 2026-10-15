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

	t.test("the first day is remembered once and the summary says so, so no popup opens on it", function()
		local data = fresh()
		Daily.rollover(data, 20000, 1, 0, 7)
		t.eq(data.joined, 20000)
		t.eq(Daily.summary(data, 20000 * 86400 + 10, 10, 1e12).firstDay, true, "the day it started")
		Daily.rollover(data, 20001, 1, 0, 7)
		t.eq(data.joined, 20000, "kept on later days")
		t.eq(Daily.summary(data, 20001 * 86400, 10, 1e12).firstDay, false, "the next day")
		t.eq(Daily.summary(fresh(), 20000 * 86400, 10, 1e12).firstDay, true, "a profile that never rolled over counts as day one")
	end)

	t.test("the first claim of a new player cannot buy the early pickaxe tiers outright", function()
		local Gear = require(t.shared.Gear)
		-- every price from the first pickaxe up to tier 2 level 20
		local toTierTwoLevelTwenty = 0
		for level = 1, Gear.cap(1) - 1 do toTierTwoLevelTwenty += Gear.price("pickaxe", 1, level) or 0 end
		toTierTwoLevelTwenty += Gear.evolution("pickaxe", 1, Gear.cap(1)).cost
		for level = 1, 19 do toTierTwoLevelTwenty += Gear.price("pickaxe", 2, level) or 0 end
		-- a fresh profile earns roughly 25 cash a second; the ceiling is 5% of the first rebirth price (68000)
		local firstClaim = Daily.reward(1, 25, 68000 * Settings.CashCeilingShare).cash
		t.ok(firstClaim < toTierTwoLevelTwenty / 2, "day 1 pays " .. firstClaim .. " against " .. toTierTwoLevelTwenty .. " for tier 2 level 20")
		for day = 2, Settings.CycleLength do
			t.ok(Daily.reward(day, 25, 68000 * Settings.CashCeilingShare).cash >= Daily.reward(day - 1, 25, 68000 * Settings.CashCeilingShare).cash, "day " .. day .. " pays at least what the day before did")
		end
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

	t.test("summary lists every cycle day's reward for the grid", function()
		local data = fresh()
		Daily.rollover(data, 20000, 1, 0, 7)
		local view = Daily.summary(data, 20000 * 86400, 10, 1e12)
		t.eq(#view.days, Settings.CycleLength)
		for index, entry in view.days do
			local expected = Daily.reward(index, 10, 1e12)
			t.eq(entry.cash, expected.cash); t.eq(entry.shards, expected.shards)
			t.eq(entry.petXp, expected.petXp); t.eq(entry.shield, expected.shield)
		end
		t.eq(view.days[view.cycleDay].cash, view.reward.cash)
	end)

	t.test("a fresh profile gets the daily table with the start shield", function()
		local Template = require(t.lib.ProfileTemplate)
		t.eq(Template.version, 11)
		t.eq(Template.daily.shields, Settings.StartShields)
		t.eq(Template.daily.streak, 0)
		t.eq(Template.daily.weekly.id, "")
		local data = table.clone(Template.daily)
		data.quests, data.weekly = {}, { id = "", progress = 0, claimed = false }
		t.eq(Daily.rollover(data :: any, 20000, 1, 0, 1), true, "the template rolls over without error")
	end)
end
