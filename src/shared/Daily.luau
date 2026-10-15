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
	joined: number?, -- the UTC day the first rollover ran: the day the player started
}
export type Resolution = { status: "claimable" | "claimed", streak: number, shieldsUsed: number, reset: boolean }
export type Reward = { cash: number, shards: number, petXp: number, shield: number }
export type QuestView = {
	slot: string, title: string, progress: number, target: number, claimed: boolean, ready: boolean, cash: number, shards: number,
}
export type Summary = {
	claimedToday: boolean, streak: number, cycleDay: number, shields: number, shieldCap: number,
	shieldsToUse: number, willReset: boolean, reward: Reward, days: { Reward }, quests: { QuestView }, weekly: QuestView?,
	bonus: { ready: boolean, claimed: boolean, cash: number, shards: number }, secondsLeft: number, anyReady: boolean,
	firstDay: boolean, -- still the day the player started: the menu does not open by itself yet
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
	if (data.joined or 0) == 0 then
		data.joined = today
		changed = true
	end
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
	local days: { Reward } = {}
	for index = 1, Settings.CycleLength do
		days[index] = Daily.reward(index, perSecond, ceiling)
	end
	local bonus = Daily.bonusReward(perSecond, ceiling)
	local bonusReady = not data.questBonusClaimed and allClaimed(data)
	if bonusReady then anyReady = true end
	return {
		claimedToday = claimed, streak = if claimed then data.streak else result.streak, cycleDay = cycleDay,
		shields = data.shields, shieldCap = Settings.ShieldCap, shieldsToUse = result.shieldsUsed, willReset = result.reset,
		reward = Daily.reward(cycleDay, perSecond, ceiling), days = days, quests = quests, weekly = weekly,
		bonus = { ready = bonusReady, claimed = data.questBonusClaimed, cash = bonus.cash, shards = bonus.shards },
		secondsLeft = DAY - math.floor(clean(now)) % DAY, anyReady = anyReady,
		firstDay = (data.joined or 0) == 0 or (data.joined or 0) >= today,
	}
end

return Daily
