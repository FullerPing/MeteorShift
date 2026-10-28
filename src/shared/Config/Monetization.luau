--!strict
-- Fixed game passes and repeatable developer products. MonetizationService grants
-- them on the server and saves each PurchaseId before acknowledging a receipt.
-- StoreController lists them behind the HUD's STORE button. Robux is the intended
-- Creator Dashboard price; live store prices come from Roblox's regional pricing.
--
-- Id = 0 means "not on sale yet": nothing is prompted, nothing is looked up, and the
-- store shows "Not on sale yet". Fill in the real ids from the Creator Dashboard to
-- switch a pass or product on.
--
-- Not here, on purpose:
-- * The Extra Refinery pass (§9.1, "+1 refinery pad") is left out: every plot runs a
--   single production line with one refinery since the Round 3 rework, so there is
--   no second pad for it to add.
--
-- Nothing here changes meteor or mineral odds. 2x Ore doubles the ore quantity per hit
-- only; Ore Rush uses the larger multiplier with that pass. Cash packs are capped at a
-- share of the next rebirth cost; pet XP grants go only to the current equipped loadout.
-- Core Shards are sold as fixed packs (ShardPacks) and eggs still show their odds. The
-- progression products (owner decision, 2026-10-10):
-- * Tier-ups (PickaxeT2 ...): evolve one gear tier at once, with no cash, shards or player
--   level needed. Sold only inside the gear shop, next to Evolve (Product.Kind / From,
--   GearOrder), never in the Store.
-- * Boss Meteor: Call a Meteor that forces the Alien boss type (needs the boss rebirths).
-- * Rebirth Keep: a credit that makes the next rebirth keep everything.
-- * Pet Max: every equipped pet to max level. Pet Slot: the permanent extra pet slot (a
--   product, saved as flags.extraPetSlot, now that the pass is gone). Starter Pack: one per
--   player (flags.starterPack).
-- * 2x Cash pass: bar sales x2 (CashMult).

export type Pass = {
	Key: string,
	Id: number,
	Name: string,
	Description: string,
	Robux: number?,
	Highlights: { string }?, -- the offer preview's lines (OfferController); Description stands in when absent
}

export type Product = {
	Key: string,
	Id: number,
	Name: string,
	Description: string,
	Robux: number?,
	Highlights: { string }?, -- the offer preview's lines (OfferController); Description stands in when absent
	Kind: string?, -- tier-ups: "pickaxe" or "backpack"
	From: number?, -- tier-ups: the tier it evolves from (T2 gives tier 3)
}

export type CashPack = { Minutes: number, Floor: number, CeilingShare: number }

local Monetization = {}

-- In store order
Monetization.PassOrder = { "TwoXOre", "TwoXCash", "BiggerBackpack", "OfflineHours", "AutoDeposit", "VIP", "Drillbot", "SolarPhoenix" }

Monetization.Passes = {
	TwoXOre = {
		Key = "TwoXOre",
		Id = 2026934474,
		Name = "2x Ore",
		Robux = 149,
		Description = "Double ore from every hit.",
		Highlights = { "x2 ore from every hit", "Your backpack fills twice as fast" },
	} :: Pass,
	TwoXCash = {
		Key = "TwoXCash",
		Id = 2026760484,
		Name = "2x Cash",
		Robux = 129,
		Description = "Double cash from every bar sale.",
		Highlights = { "x2 cash from every bar you sell", "Offline bars sell for x2 too" },
	} :: Pass,
	BiggerBackpack = {
		Key = "BiggerBackpack",
		Id = 2025488489,
		Name = "Bigger Backpack",
		Robux = 99,
		Description = "×2 backpack capacity.",
	} :: Pass,
	OfflineHours = {
		Key = "OfflineHours",
		Id = 0,
		Name = "Offline Hours+",
		Description = "Your line works up to 8 hours while you're away, instead of 2.",
	} :: Pass,
	AutoDeposit = {
		Key = "AutoDeposit",
		Id = 2026682466,
		Name = "Auto-Deposit",
		Robux = 129,
		Description = "Mined ore goes straight into your hopper.",
	} :: Pass,
	Drillbot = {
		Key = "Drillbot",
		Id = 2026256458,
		Name = "Drillbot Pet",
		Description = "Auto-mines, swings faster and adds ore per hit.",
		Robux = 129,
	} :: Pass,
	SolarPhoenix = {
		Key = "SolarPhoenix",
		Id = 2026178485,
		Name = "Solar Phoenix Pet",
		Description = "Auto-mines and boosts bar sales and XP.",
		Robux = 249,
	} :: Pass,
	VIP = {
		Key = "VIP",
		Id = 2027090469,
		Name = "VIP",
		Robux = 199,
		Description = "+25% bar value and a VIP chat tag.",
	} :: Pass,
}

Monetization.ProductOrder = {
	"StarterPack", "TipJar", "PocketChange", "MiniOverclock", "OreRush", "CashBundle", "CallMeteor", "Overclock",
	"PetMax", "PetSlot", "BossMeteor", "Shards50", "Shards250", "Shards1000", "RebirthKeep", "StreakShield",
}

-- Tier-up products, sold in the gear shop only (not in ProductOrder). Id = 0 stays off sale and hidden.
Monetization.GearOrder = {
	"PickaxeT1", "PickaxeT2", "PickaxeT3", "PickaxeT4", "PickaxeT5", "PickaxeT6", "PickaxeT7",
	"BackpackT1", "BackpackT2", "BackpackT3", "BackpackT4", "BackpackT5", "BackpackT6", "BackpackT7",
}

Monetization.Products = {
	StreakShield = {
		Key = "StreakShield",
		Id = 0, -- the owner adds the Creator Dashboard item; 0 keeps it off sale
		Name = "Streak Shield",
		Robux = 9,
		Description = "Saves your daily streak for one missed day.",
	} :: Product,
	TipJar = {
		Key = "TipJar",
		Id = 0,
		Name = "Tip Jar",
		Robux = 5,
		Description = "Thank you! Confetti and a Supporter tag.",
	} :: Product,
	PocketChange = {
		Key = "PocketChange",
		Id = 3717721006,
		Name = "Pocket Change",
		Robux = 19,
		Description = "10 minutes of line income (up to 25% of your next rebirth).",
	} :: Product,
	MiniOverclock = {
		Key = "MiniOverclock",
		Id = 3717721310,
		Name = "Mini Overclock",
		Robux = 19,
		Description = "Overclock for 10 minutes: refinery ×2 speed, bars +50%.",
	} :: Product,
	OreRush = {
		Key = "OreRush",
		Id = 3717656636,
		Name = "Ore Rush",
		Robux = 29,
		Description = "Ore per hit ×2 for 30 minutes. Doesn't stack with 2x Ore.",
	} :: Product,
	CashBundle = {
		Key = "CashBundle",
		Id = 3717721086,
		Name = "Cash Bundle",
		Robux = 59,
		Description = "60 minutes of line income (up to 90% of your next rebirth).",
	} :: Product,
	CallMeteor = {
		Key = "CallMeteor",
		Id = 3717657480,
		Name = "Call a Meteor",
		Robux = 19,
		Description = "The next meteor lands in 30 seconds, for everyone.",
	} :: Product,
	Overclock = {
		Key = "Overclock",
		Id = 3717721351,
		Name = "Refinery Overclock",
		Robux = 39,
		Description = "Overclock for 30 minutes: refinery ×2 speed, bars +50%.",
	} :: Product,
	StarterPack = {
		Key = "StarterPack",
		Id = 3717709173,
		Name = "Starter Value Pack",
		Robux = 49,
		Description = "20 minutes of Overclock, 1,500 XP per equipped pet and 10 minutes of line income.",
		Highlights = { "20 min of Overclock", "1,500 XP per equipped pet (or 30 Shards)", "10 min of line income" },
	} :: Product,
	PetMax = {
		Key = "PetMax",
		Id = 3717721195,
		Name = "Level Up Pets to Max",
		Robux = 49,
		Description = "Your equipped pets jump to max level.",
	} :: Product,
	PetSlot = {
		Key = "PetSlot",
		Id = 3717720944,
		Name = "Extra Pet Slot",
		Robux = 49,
		Description = "One more equipped pet slot.",
	} :: Product,
	BossMeteor = {
		Key = "BossMeteor",
		Id = 3717656947,
		Name = "Call a Boss Meteor",
		Robux = 99,
		Description = "The Alien boss meteor lands in 30 seconds. Needs rebirth 3.",
	} :: Product,
	Shards50 = {
		Key = "Shards50",
		Id = 3717688986,
		Name = "50 Core Shards",
		Robux = 19,
		Description = "50 Core Shards.",
	} :: Product,
	Shards250 = {
		Key = "Shards250",
		Id = 3717689098,
		Name = "250 Core Shards",
		Robux = 69,
		Description = "250 Core Shards.",
	} :: Product,
	Shards1000 = {
		Key = "Shards1000",
		Id = 3717689250,
		Name = "1,000 Core Shards",
		Robux = 199,
		Description = "1,000 Core Shards.",
	} :: Product,
	RebirthKeep = {
		Key = "RebirthKeep",
		Id = 3717690498,
		Name = "Rebirth and Keep Everything",
		Robux = 99,
		Description = "Rebirth without losing anything.",
	} :: Product,
	PickaxeT1 = {
		Key = "PickaxeT1",
		Id = 3717713942,
		Name = "Pickaxe T1 to T2",
		Robux = 5,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "pickaxe",
		From = 1,
	} :: Product,
	PickaxeT2 = {
		Key = "PickaxeT2",
		Id = 3717691265,
		Name = "Pickaxe T2 to T3",
		Robux = 9,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "pickaxe",
		From = 2,
	} :: Product,
	PickaxeT3 = {
		Key = "PickaxeT3",
		Id = 3717691317,
		Name = "Pickaxe T3 to T4",
		Robux = 19,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "pickaxe",
		From = 3,
	} :: Product,
	PickaxeT4 = {
		Key = "PickaxeT4",
		Id = 3717691348,
		Name = "Pickaxe T4 to T5",
		Robux = 49,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "pickaxe",
		From = 4,
	} :: Product,
	PickaxeT5 = {
		Key = "PickaxeT5",
		Id = 3717712309,
		Name = "Pickaxe T5 to T6",
		Robux = 89,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "pickaxe",
		From = 5,
	} :: Product,
	PickaxeT6 = {
		Key = "PickaxeT6",
		Id = 3717712401,
		Name = "Pickaxe T6 to T7",
		Robux = 179,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "pickaxe",
		From = 6,
	} :: Product,
	PickaxeT7 = {
		Key = "PickaxeT7",
		Id = 3717712495,
		Name = "Pickaxe T7 to T8",
		Robux = 259,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "pickaxe",
		From = 7,
	} :: Product,
	BackpackT1 = {
		Key = "BackpackT1",
		Id = 3717714256,
		Name = "Backpack T1 to T2",
		Robux = 5,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "backpack",
		From = 1,
	} :: Product,
	BackpackT2 = {
		Key = "BackpackT2",
		Id = 3717714331,
		Name = "Backpack T2 to T3",
		Robux = 9,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "backpack",
		From = 2,
	} :: Product,
	BackpackT3 = {
		Key = "BackpackT3",
		Id = 3717714409,
		Name = "Backpack T3 to T4",
		Robux = 19,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "backpack",
		From = 3,
	} :: Product,
	BackpackT4 = {
		Key = "BackpackT4",
		Id = 3717714516,
		Name = "Backpack T4 to T5",
		Robux = 39,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "backpack",
		From = 4,
	} :: Product,
	BackpackT5 = {
		Key = "BackpackT5",
		Id = 3717714654,
		Name = "Backpack T5 to T6",
		Robux = 89,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "backpack",
		From = 5,
	} :: Product,
	BackpackT6 = {
		Key = "BackpackT6",
		Id = 3717714797,
		Name = "Backpack T6 to T7",
		Robux = 179,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "backpack",
		From = 6,
	} :: Product,
	BackpackT7 = {
		Key = "BackpackT7",
		Id = 3717714979,
		Name = "Backpack T7 to T8",
		Robux = 259,
		Description = "Evolve to the next tier now. Needs max level.",
		Kind = "backpack",
		From = 7,
	} :: Product,
}

-- Pass effects
Monetization.OreMult = 2 -- 2x Ore: ore quantity per hit
Monetization.CashMult = 2 -- 2x Cash: every bar sale (multiplies with rebirth, index, VIP and pets)
Monetization.BackpackMult = 2 -- Bigger Backpack: backpack capacity
Monetization.VIPBarBonus = 0.25 -- VIP: +25% bar sales (multiplies with rebirth and index; +10% was a tenth of 2x Cash at a higher price)
Monetization.VIPTag = "[VIP]"
Monetization.VIPTagColor = "#FFCF37"
Monetization.SupporterTag = "[Supporter]"
Monetization.SupporterTagColor = "#76E8B3"
-- Offline Hours+ raises the offline cap to Config.Home.OfflineCapPass

-- Call a Meteor rules (spec §9.2), checked by Shared.CallMeteor
Monetization.CallMeteor = {
	MinSecondsLeft = 60, -- only buyable during Countdown with more than this left
	SetCountdownTo = 30, -- the countdown jumps to this many seconds
	Cooldown = 180, -- seconds after the previous CALLED meteor's event ends (its Active phase)
	HourlyCap = 3, -- calls per server per rolling window
	CapWindow = 3600, -- the rolling window, seconds
}

-- Refinery Overclock (spec §9.2): online only, the offline catch-up ignores it. Speed alone did nothing once mining,
-- not the line, held income back (audit C4), so bars sold while it runs are worth BarBonus more as well.
Monetization.Overclock = {
	SpeedMult = 2,
	BarBonus = 0.5,
	Duration = 30 * 60, -- seconds of online time per purchase; purchases stack
}

Monetization.ShardPacks = { Shards50 = 50, Shards250 = 250, Shards1000 = 1000 } :: { [string]: number }
-- A one-off product bought again after it is owned (stale UI, two prompts) pays these Core Shards instead of
-- nothing: about its Robux at the Shards250 rate
Monetization.RepeatRefundShards = { PetSlot = 175 } :: { [string]: number }
Monetization.MiniOverclock = { Duration = 10 * 60 }
-- Starter Value Pack: Overclocks of MiniOverclock.Duration, PetXp to each equipped pet (ShardsWithoutPets Core Shards
-- instead when none is equipped: one Meteor Egg), and the StarterPack cash pack
Monetization.StarterPack = { Overclocks = 2, PetXp = 1500, ShardsWithoutPets = 30 }
Monetization.OreRush = { Multiplier = 2, Duration = 30 * 60 }
Monetization.CashPacks = {
	-- The ceilings bind mid-lap, so they set the value: the Bundle (about 3x the Robux) pays 3.6x the Pocket's cap
	-- and still never a whole rebirth. At 0.3 / 0.8 three Pocket Changes beat one Cash Bundle.
	PocketChange = { Minutes = 10, Floor = 2000, CeilingShare = 0.25 },
	CashBundle = { Minutes = 60, Floor = 20000, CeilingShare = 0.9 },
	StarterPack = { Minutes = 10, Floor = 2000, CeilingShare = 0.3 },
} :: { [string]: CashPack }

-- Processed PurchaseIds are retained permanently. The previous 50-id limit could
-- regrant an old receipt; history discarded by an earlier version cannot be restored.

-- How often the server re-checks Call a Meteor availability for the store buttons
Monetization.AvailabilityInterval = 1

return Monetization
