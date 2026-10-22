--!strict
-- Profile schema v14 (spec §12.4, with the plot production line instead of
-- refinery slots, one pickaxe and backpack with a single level each: Shared.Gear, and pets: Shared.Pets). New keys added here are filled into old
-- profiles on load; anything that changes meaning needs a migration in DataService.
-- (v12 was skipped: an unreleased trial build saved v12 profiles with a `trialFlag` key; v13 removes it.)
-- v14: rebirths re-counted for the x2 rebirth (Lib.RebirthMigration).

return {
	version = 14,
	cash = 0,
	shards = 0,
	-- The part of `shards` that came from Robux (shard packs, refunds paid in shards). Eggs are random, so where
	-- paid random items are restricted they can only be opened with the rest (Shared.ShardWallet)
	paidShards = 0,
	pickaxeTier = 1, -- evolution tier: caps the stat levels (Shared.Gear)
	backpackTier = 1,
	pickaxeLevel = 1, -- one level per item, 1 to the tier's cap; every tier starts over at 1 (Shared.Gear)
	backpackLevel = 1,
	-- Pets (Shared.Pets): owned ones with their level and XP, and the ones out (kept through rebirth)
	pets = { owned = {}, equipped = {}, hatches = {} }, -- hatches: per egg, hatches since the last Epic or better (pity)
	level = 1, -- player level (Shared.Levels): earned from meteors, kept through rebirth
	xp = 0,
	-- Colony Perks (Shared.Perks): level of each, bought with shards, kept through rebirth
	perks = { headStart = 0, stationMemory = 0, efficientLine = 0, offlineTraining = 0, petBond = 0 },
	-- Bar-sale cash earned beyond the cost of the next rebirth since it was first affordable
	-- (Shared.Rebirth.overstayShards); reset by a rebirth
	overflow = 0,
	backpack = {}, -- ore carried, by type
	-- Production line level (Shared.Line): hopper -> conveyor -> refinery -> collection post
	-- all upgrade together (v11; before that each station had its own level in `stations`)
	line = 1,
	hopper = {}, -- ore waiting, by type
	refinePriority = {}, -- ore preference; empty preserves the default order
	bin = {}, -- bars waiting at the collection post, by type
	progress = 0, -- fractional ore between production ticks
	bars = {}, -- bars carried, by type
	decor = {}, -- placed items; reset with active gameplay on rebirth
	index = {}, -- discovered minerals
	rebirths = 0,
	lastSeen = 0,
	tutorialStep = 1, -- next tutorial step (spec §11); flags.tutorialDone ends it
	flags = {
		tutorialDone = false,
		introSeen = false, -- the first-join "How to play" intro was closed (Shared/Intro)
		-- Lifetime analytics milestones (spec §13), set by TelemetryService when logged
		firstMeteor = false,
		firstCoreReward = false,
		firstRefinery = false,
	},
	-- Monetization (spec §9). Pass ownership comes from Roblox on every join and is
	-- not saved here.
	credits = {
		callMeteor = 0, -- Call a Meteor purchases that couldn't run yet, usable later
		bossMeteor = 0, -- the same for Call a Boss Meteor
		rebirthKeep = 0, -- Rebirth and Keep Everything purchases waiting for the next rebirth
		petMax = 0, -- Pet Max purchases made with no pet to level: applied to the next pet equipped below max
	},
	receipts = {}, -- all processed PurchaseIds; do not trim paid-grant idempotency history
	overclockLeft = 0, -- seconds of Refinery Overclock left, counted down while online
	oreBoostLeft = 0, -- Ore Rush seconds; online only, uses the larger ore multiplier
	stats = {
		meteorsJoined = 0,
		coresCracked = 0,
		barsSold = 0,
	},
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
		joined = 0, -- UTC day of the first rollover: the day the player started (the join popup waits a day)
	},
	-- Codes already redeemed (Shared.Codes, CodesService): code name -> true
	codes = {},
	-- Settings menu toggles the player changed (PlayerStateService.SETTINGS): name -> boolean; missing = default
	settings = {},
}
