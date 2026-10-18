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
}

export type Product = {
	Key: string,
	Id: number,
	Name: string,
	Description: string,
	Robux: number?,
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
		Description = "Double the ore from every hit. Never changes mineral odds.",
	} :: Pass,
	TwoXCash = {
		Key = "TwoXCash",
		Id = 2026760484,
		Name = "2x Cash",
		Robux = 129,
		Description = "Double the cash from every bar sale. Stacks with rebirth, index and VIP bonuses.",
	} :: Pass,
	BiggerBackpack = {
		Key = "BiggerBackpack",
		Id = 2025488489,
		Name = "Bigger Backpack",
		Robux = 99,
		Description = "×2 backpack capacity, on every backpack tier.",
	} :: Pass,
	OfflineHours = {
		Key = "OfflineHours",
		Id = 0,
		Name = "Offline Hours+",
		Description = "Your production line keeps working up to 8 hours while you're away, instead of 2.",
	} :: Pass,
	AutoDeposit = {
		Key = "AutoDeposit",
		Id = 2026682466,
		Name = "Auto-Deposit",
		Robux = 129,
		Description = "Mined ore goes straight into your hopper. When the hopper is full, it goes to your backpack.",
	} :: Pass,
	Drillbot = {
		Key = "Drillbot",
		Id = 2026256458,
		Name = "Drillbot Pet",
		Description = "A fixed pet: auto-mining 25–40%, faster swings 8–20%, and ore per hit +10–20%. Never random.",
		Robux = 129,
	} :: Pass,
	SolarPhoenix = {
		Key = "SolarPhoenix",
		Id = 2026178485,
		Name = "Solar Phoenix Pet",
		Description = "A fixed pet: auto-mining 50–100%, bar sales +15–35%, and player XP +15–35%. Never random.",
		Robux = 249,
	} :: Pass,
	VIP = {
		Key = "VIP",
		Id = 2027090469,
		Name = "VIP",
		Robux = 199,
		Description = "+10% bar value and a VIP chat tag.",
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
		Description = "Covers one missed day of your daily streak, so you don't lose it. Not random, no other effect.",
	} :: Product,
	TipJar = {
		Key = "TipJar",
		Id = 0,
		Name = "Tip Jar",
		Robux = 5,
		Description = "Thank you! Confetti and a Supporter tag for this session. No gameplay effect.",
	} :: Product,
	PocketChange = {
		Key = "PocketChange",
		Id = 3717721006,
		Name = "Pocket Change",
		Robux = 19,
		Description = "10 minutes of current line income. Minimum $2,000; capped at 30% of your next rebirth cost.",
	} :: Product,
	MiniOverclock = {
		Key = "MiniOverclock",
		Id = 3717721310,
		Name = "Mini Overclock",
		Robux = 19,
		Description = "Refinery ×2 speed for 10 minutes of play time. Adds to your Overclock time.",
	} :: Product,
	OreRush = {
		Key = "OreRush",
		Id = 3717656636,
		Name = "Ore Rush",
		Robux = 29,
		Description = "Ore per hit ×2 for 30 minutes of play time. Does not stack with the 2x Ore pass.",
	} :: Product,
	CashBundle = {
		Key = "CashBundle",
		Id = 3717721086,
		Name = "Cash Bundle",
		Robux = 59,
		Description = "60 minutes of current line income. Minimum $20,000; capped at 80% of your next rebirth cost.",
	} :: Product,
	CallMeteor = {
		Key = "CallMeteor",
		Id = 3717657480,
		Name = "Call a Meteor",
		Robux = 19,
		Description = "Brings the next meteor down in 30 seconds for the whole server. It can't choose the type or boost loot.",
	} :: Product,
	Overclock = {
		Key = "Overclock",
		Id = 3717721351,
		Name = "Refinery Overclock",
		Robux = 39,
		Description = "Your refinery runs ×2 speed for 30 minutes of play time (online only).",
	} :: Product,
	StarterPack = {
		Key = "StarterPack",
		Id = 3717709173,
		Name = "Starter Value Pack",
		Robux = 49,
		Description = "30 minutes of line income, three Mini Overclocks (30 minutes of ×2 refinery) and 1,500 XP for each equipped pet. One per player.",
	} :: Product,
	PetMax = {
		Key = "PetMax",
		Id = 3717721195,
		Name = "Level Up Pets to Max",
		Robux = 49,
		Description = "Takes every pet you currently have equipped straight to max level. A fixed grant, never a hatch.",
	} :: Product,
	PetSlot = {
		Key = "PetSlot",
		Id = 3717720944,
		Name = "Extra Pet Slot",
		Robux = 49,
		Description = "One extra equipped pet slot, permanently. Up to four pets with rebirth slots.",
	} :: Product,
	BossMeteor = {
		Key = "BossMeteor",
		Id = 3717656947,
		Name = "Call a Boss Meteor",
		Robux = 99,
		Description = "Brings the Alien boss meteor down in 30 seconds for the whole server. Needs rebirth 3 and the same calling limits.",
	} :: Product,
	Shards50 = {
		Key = "Shards50",
		Id = 3717688986,
		Name = "50 Core Shards",
		Robux = 19,
		Description = "50 Core Shards, added straight to your balance.",
	} :: Product,
	Shards250 = {
		Key = "Shards250",
		Id = 3717689098,
		Name = "250 Core Shards",
		Robux = 69,
		Description = "250 Core Shards, added straight to your balance.",
	} :: Product,
	Shards1000 = {
		Key = "Shards1000",
		Id = 3717689250,
		Name = "1,000 Core Shards",
		Robux = 199,
		Description = "1,000 Core Shards, added straight to your balance.",
	} :: Product,
	RebirthKeep = {
		Key = "RebirthKeep",
		Id = 3717690498,
		Name = "Rebirth and Keep Everything",
		Robux = 99,
		Description = "Your next rebirth keeps everything: cash, gear levels, production, ore and bars. The multiplier still goes up.",
	} :: Product,
	PickaxeT1 = {
		Key = "PickaxeT1",
		Id = 3717713942,
		Name = "Pickaxe T1 to T2",
		Robux = 5,
		Description = "Evolve your pickaxe to the next tier now. No cash, shards or player level needed; the pickaxe level must be at its cap.",
		Kind = "pickaxe",
		From = 1,
	} :: Product,
	PickaxeT2 = {
		Key = "PickaxeT2",
		Id = 3717691265,
		Name = "Pickaxe T2 to T3",
		Robux = 9,
		Description = "Evolve your pickaxe to the next tier now. No cash, shards or player level needed; the pickaxe level must be at its cap.",
		Kind = "pickaxe",
		From = 2,
	} :: Product,
	PickaxeT3 = {
		Key = "PickaxeT3",
		Id = 3717691317,
		Name = "Pickaxe T3 to T4",
		Robux = 19,
		Description = "Evolve your pickaxe to the next tier now. No cash, shards or player level needed; the pickaxe level must be at its cap.",
		Kind = "pickaxe",
		From = 3,
	} :: Product,
	PickaxeT4 = {
		Key = "PickaxeT4",
		Id = 3717691348,
		Name = "Pickaxe T4 to T5",
		Robux = 49,
		Description = "Evolve your pickaxe to the next tier now. No cash, shards or player level needed; the pickaxe level must be at its cap.",
		Kind = "pickaxe",
		From = 4,
	} :: Product,
	PickaxeT5 = {
		Key = "PickaxeT5",
		Id = 3717712309,
		Name = "Pickaxe T5 to T6",
		Robux = 89,
		Description = "Evolve your pickaxe to the next tier now. No cash, shards or player level needed; the pickaxe level must be at its cap.",
		Kind = "pickaxe",
		From = 5,
	} :: Product,
	PickaxeT6 = {
		Key = "PickaxeT6",
		Id = 3717712401,
		Name = "Pickaxe T6 to T7",
		Robux = 179,
		Description = "Evolve your pickaxe to the next tier now. No cash, shards or player level needed; the pickaxe level must be at its cap.",
		Kind = "pickaxe",
		From = 6,
	} :: Product,
	PickaxeT7 = {
		Key = "PickaxeT7",
		Id = 3717712495,
		Name = "Pickaxe T7 to T8",
		Robux = 259,
		Description = "Evolve your pickaxe to the next tier now. No cash, shards or player level needed; the pickaxe level must be at its cap.",
		Kind = "pickaxe",
		From = 7,
	} :: Product,
	BackpackT1 = {
		Key = "BackpackT1",
		Id = 3717714256,
		Name = "Backpack T1 to T2",
		Robux = 5,
		Description = "Evolve your backpack to the next tier now. No cash, shards or player level needed; the backpack level must be at its cap.",
		Kind = "backpack",
		From = 1,
	} :: Product,
	BackpackT2 = {
		Key = "BackpackT2",
		Id = 3717714331,
		Name = "Backpack T2 to T3",
		Robux = 9,
		Description = "Evolve your backpack to the next tier now. No cash, shards or player level needed; the backpack level must be at its cap.",
		Kind = "backpack",
		From = 2,
	} :: Product,
	BackpackT3 = {
		Key = "BackpackT3",
		Id = 3717714409,
		Name = "Backpack T3 to T4",
		Robux = 19,
		Description = "Evolve your backpack to the next tier now. No cash, shards or player level needed; the backpack level must be at its cap.",
		Kind = "backpack",
		From = 3,
	} :: Product,
	BackpackT4 = {
		Key = "BackpackT4",
		Id = 3717714516,
		Name = "Backpack T4 to T5",
		Robux = 39,
		Description = "Evolve your backpack to the next tier now. No cash, shards or player level needed; the backpack level must be at its cap.",
		Kind = "backpack",
		From = 4,
	} :: Product,
	BackpackT5 = {
		Key = "BackpackT5",
		Id = 3717714654,
		Name = "Backpack T5 to T6",
		Robux = 89,
		Description = "Evolve your backpack to the next tier now. No cash, shards or player level needed; the backpack level must be at its cap.",
		Kind = "backpack",
		From = 5,
	} :: Product,
	BackpackT6 = {
		Key = "BackpackT6",
		Id = 3717714797,
		Name = "Backpack T6 to T7",
		Robux = 179,
		Description = "Evolve your backpack to the next tier now. No cash, shards or player level needed; the backpack level must be at its cap.",
		Kind = "backpack",
		From = 6,
	} :: Product,
	BackpackT7 = {
		Key = "BackpackT7",
		Id = 3717714979,
		Name = "Backpack T7 to T8",
		Robux = 259,
		Description = "Evolve your backpack to the next tier now. No cash, shards or player level needed; the backpack level must be at its cap.",
		Kind = "backpack",
		From = 7,
	} :: Product,
}

-- Pass effects
Monetization.OreMult = 2 -- 2x Ore: ore quantity per hit
Monetization.CashMult = 2 -- 2x Cash: every bar sale (multiplies with rebirth, index, VIP and pets)
Monetization.BackpackMult = 2 -- Bigger Backpack: backpack capacity
Monetization.VIPBarBonus = 0.1 -- VIP: +10% bar sales (multiplies with rebirth and index)
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

-- Refinery Overclock (spec §9.2): online only, the offline catch-up ignores it
Monetization.Overclock = {
	SpeedMult = 2,
	Duration = 30 * 60, -- seconds of online time per purchase; purchases stack
}

Monetization.ShardPacks = { Shards50 = 50, Shards250 = 250, Shards1000 = 1000 } :: { [string]: number }
Monetization.MiniOverclock = { Duration = 10 * 60 }
-- Starter Value Pack: Overclocks of MiniOverclock.Duration, PetXp to each equipped pet, and the StarterPack cash pack.
-- Ad test (2026-10-18): 0 of 18 prompts bought when it was PocketChange + 2 Mini Overclocks (~57 R$ of items for 49);
-- now ~90 R$ of items for 49, and the Store quotes its cash before the prompt.
Monetization.StarterPack = { Overclocks = 3, PetXp = 1500 }
Monetization.OreRush = { Multiplier = 2, Duration = 30 * 60 }
Monetization.CashPacks = {
	PocketChange = { Minutes = 10, Floor = 2000, CeilingShare = 0.3 },
	CashBundle = { Minutes = 60, Floor = 20000, CeilingShare = 0.8 },
	StarterPack = { Minutes = 30, Floor = 5000, CeilingShare = 0.5 },
} :: { [string]: CashPack }

-- Processed PurchaseIds are retained permanently. The previous 50-id limit could
-- regrant an old receipt; history discarded by an earlier version cannot be restored.

-- How often the server re-checks Call a Meteor availability for the store buttons
Monetization.AvailabilityInterval = 1

return Monetization
