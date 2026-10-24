--!strict
-- Daily streak, quests and shields (Shared.Daily rules, DailyService). Cash is a stretch of the player's own
-- expected income (Shared.Income) so a reward is as big as their setup is, capped under the next rebirth cost.
-- Nothing here is sold except Streak Shields (Config.Monetization) and nothing touches any odds.
-- CeilingMult raises the day's cash ceiling (CashCeilingShare of the next rebirth's cost): with one flat ceiling
-- every day paid the same once income outgrew it, so the streak's ramp was invisible
export type Day = { Minutes: number, Shards: number, PetXp: number, Shield: number, CeilingMult: number }
export type Quest = {
	Id: string, Event: string, Target: number, Title: string, Minutes: number, Shards: number,
	MinLevel: number?, MinRebirths: number?,
}

local Daily = {}

Daily.CycleLength = 7
Daily.CashFloor = 1000 -- a claim never pays less cash than this (the ceiling still wins)
Daily.CashCeilingShare = 0.02 -- of the next rebirth's cost (0.05 let one early quest buy a whole gear tier)
Daily.StartShields = 1
Daily.ShieldCap = 3 -- free shield gains stop here; shields you buy are kept above it
Daily.DailyCount = 3

-- Minutes of income, Core Shards, XP for each equipped pet, and free shields on each day of the cycle.
-- The first days are small on purpose: a new player earns about 25 cash a second, so the first claim must not
-- be able to buy the early pickaxe tiers outright (day 1 is about 40 seconds of play, not a skip).
Daily.Days = {
	{ Minutes = 0.5, Shards = 0, PetXp = 0, Shield = 0, CeilingMult = 1 },
	{ Minutes = 2, Shards = 0, PetXp = 0, Shield = 0, CeilingMult = 1.5 },
	{ Minutes = 4, Shards = 10, PetXp = 0, Shield = 0, CeilingMult = 2 },
	{ Minutes = 6, Shards = 0, PetXp = 0, Shield = 0, CeilingMult = 2.5 },
	{ Minutes = 10, Shards = 0, PetXp = 0, Shield = 0, CeilingMult = 3.5 },
	{ Minutes = 15, Shards = 0, PetXp = 0, Shield = 0, CeilingMult = 5 },
	{ Minutes = 30, Shards = 40, PetXp = 300, Shield = 1, CeilingMult = 7.5 },
} :: { Day }

-- Events: crustHit (a validated hit on a meteor crust node), meteorJoin (first hit of each meteor), coreCrack
-- (you shared in a cracked core), barsSold (bars), oreDeposited (ore), hatch (an egg). Titles state the target:
-- a %d in a title is filled from that quest's own Target below at load, so re-targeting a quest can never
-- desync its displayed text (the two number-free titles pass through string.format unchanged: Roblox's
-- string.format ignores arguments its format string does not use).
Daily.Quests = {
	{ Id = "crust150", Event = "crustHit", Target = 150, Title = "Break %d meteor crust nodes", Minutes = 6, Shards = 0 },
	{ Id = "crust400", Event = "crustHit", Target = 400, Title = "Break %d meteor crust nodes", Minutes = 12, Shards = 2, MinLevel = 8 },
	{ Id = "join2", Event = "meteorJoin", Target = 2, Title = "Join %d meteors", Minutes = 8, Shards = 0 },
	{ Id = "crack1", Event = "coreCrack", Target = 1, Title = "Help crack a meteor core", Minutes = 10, Shards = 3 },
	{ Id = "sell100", Event = "barsSold", Target = 100, Title = "Sell %d bars", Minutes = 6, Shards = 0 },
	{ Id = "deposit500", Event = "oreDeposited", Target = 500, Title = "Deposit %d ore in the Refinery", Minutes = 6, Shards = 0 },
	{ Id = "hatch1", Event = "hatch", Target = 1, Title = "Hatch an egg", Minutes = 8, Shards = 0, MinLevel = 8 },
} :: { Quest }

Daily.Weekly = {
	{ Id = "week15", Event = "meteorJoin", Target = 15, Title = "Join %d meteors this week", Minutes = 60, Shards = 20 },
	{ Id = "weekCores3", Event = "coreCrack", Target = 3, Title = "Help crack %d meteor cores this week", Minutes = 60, Shards = 20 },
} :: { Quest }

for _, def in Daily.Quests do
	def.Title = string.format(def.Title, def.Target)
end
for _, def in Daily.Weekly do
	def.Title = string.format(def.Title, def.Target)
end

-- Paid once all of today's quests are claimed
Daily.Bonus = { Minutes = 15, Shards = 5 }

return Daily
