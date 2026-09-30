--!strict
-- Profile schema v2 (spec §12.4, with the plot production line instead of
-- refinery slots). New keys added here are filled into old
-- profiles on load; anything that changes meaning needs a migration in DataService.

return {
	version = 2,
	cash = 0,
	shards = 0,
	pickaxeTier = 1,
	backpackTier = 1,
	backpack = {}, -- ore carried, by type
	-- Plot production line: hopper -> conveyor -> refinery -> collection post
	stations = {
		hopper = 1,
		conveyor = 1,
		refinery = 1,
		collector = 1,
	},
	hopper = {}, -- ore waiting, by type
	bin = {}, -- bars waiting at the collection post, by type
	progress = 0, -- fractional ore between production ticks
	bars = {}, -- bars carried, by type
	decor = {}, -- placed items, survives rebirth
	index = {}, -- discovered minerals
	rebirths = 0,
	lastSeen = 0,
	tutorialStep = 1, -- next tutorial step (spec §11); flags.tutorialDone ends it
	flags = {
		tutorialDone = false,
		-- Lifetime analytics milestones (spec §13), set by TelemetryService when logged
		firstMeteor = false,
		firstCoreReward = false,
		firstRefinery = false,
	},
	-- Monetization (spec §9). Pass ownership comes from Roblox on every join and is
	-- not saved here.
	credits = {
		callMeteor = 0, -- Call a Meteor purchases that couldn't run yet, usable later
	},
	receipts = {}, -- the last Config.Monetization.ReceiptHistory processed PurchaseIds
	overclockLeft = 0, -- seconds of Refinery Overclock left, counted down while online
	stats = {
		meteorsJoined = 0,
		coresCracked = 0,
		barsSold = 0,
	},
}
