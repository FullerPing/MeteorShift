--!strict
-- Profile schema v1 (spec §12.4). New keys added here are filled into old
-- profiles on load; anything that changes meaning needs a migration in DataService.

return {
	version = 1,
	cash = 0,
	shards = 0,
	pickaxeTier = 1,
	backpackTier = 1,
	backpack = {}, -- ore carried, by type
	hopper = {}, -- ore waiting to be refined, by type
	hopperLevel = 1,
	refineries = {
		{ level = 1, progress = 0, bin = {} },
	},
	bars = {}, -- bars carried, by type
	decor = {}, -- placed items, survives rebirth
	index = {}, -- discovered minerals
	rebirths = 0,
	lastSeen = 0,
	flags = {
		tutorialDone = false,
		firstMeteor = false,
		firstCoreReward = false,
		firstRefinery = false,
	},
	stats = {
		meteorsJoined = 0,
		coresCracked = 0,
		barsSold = 0,
	},
}
