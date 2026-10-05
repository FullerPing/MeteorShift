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
-- No paid randomness, ever (§9.4): nothing here may change odds. 2x Ore doubles the
-- ore quantity per hit only; Ore Rush uses the larger multiplier with that pass.
-- Nothing sells Core Shards, eggs or hatches. Cash packs are capped below the next
-- rebirth cost; pet XP grants go only to the current equipped loadout.

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
}

export type CashPack = { Minutes: number, Floor: number, CeilingShare: number }

local Monetization = {}

-- In store order
Monetization.PassOrder = { "TwoXOre", "BiggerBackpack", "OfflineHours", "AutoDeposit", "VIP", "Drillbot", "SolarPhoenix", "ExtraPetSlot" }

Monetization.Passes = {
	TwoXOre = {
		Key = "TwoXOre",
		Id = 0,
		Name = "2x Ore",
		Description = "Double the ore from every hit. Never changes mineral odds.",
	} :: Pass,
	BiggerBackpack = {
		Key = "BiggerBackpack",
		Id = 0,
		Name = "Bigger Backpack",
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
		Id = 0,
		Name = "Auto-Deposit",
		Description = "Mined ore goes straight into your hopper. When the hopper is full, it goes to your backpack.",
	} :: Pass,
	Drillbot = {
		Key = "Drillbot",
		Id = 0,
		Name = "Drillbot Pet",
		Description = "A fixed pet: auto-mining 25–40%, faster swings 8–20%, and ore per hit +10–20%. Never random.",
		Robux = 99,
	} :: Pass,
	SolarPhoenix = {
		Key = "SolarPhoenix",
		Id = 0,
		Name = "Solar Phoenix Pet",
		Description = "A fixed pet: auto-mining 50–100%, bar sales +15–35%, and player XP +15–35%. Never random.",
		Robux = 199,
	} :: Pass,
	ExtraPetSlot = {
		Key = "ExtraPetSlot",
		Id = 0,
		Name = "Extra Pet Slot",
		Description = "One extra equipped pet slot, permanently. Up to four pets with rebirth slots.",
		Robux = 49,
	} :: Pass,
	VIP = {
		Key = "VIP",
		Id = 0,
		Name = "VIP",
		Description = "+10% bar value and a VIP chat tag.",
	} :: Pass,
}

Monetization.ProductOrder = { "TipJar", "PocketChange", "PetTreat", "MiniOverclock", "OreRush", "PetFeast", "CashBundle", "CallMeteor", "Overclock" }

Monetization.Products = {
	TipJar = {
		Key = "TipJar",
		Id = 0,
		Name = "Tip Jar",
		Robux = 5,
		Description = "Thank you! Confetti and a Supporter tag for this session. No gameplay effect.",
	} :: Product,
	PocketChange = {
		Key = "PocketChange",
		Id = 0,
		Name = "Pocket Change",
		Robux = 10,
		Description = "10 minutes of current line income. Minimum $2,000; capped at 3% of your next rebirth cost.",
	} :: Product,
	PetTreat = {
		Key = "PetTreat",
		Id = 0,
		Name = "Pet Treat",
		Robux = 15,
		Description = "1,500 XP to each pet you currently have equipped. A fixed grant, never a hatch.",
	} :: Product,
	MiniOverclock = {
		Key = "MiniOverclock",
		Id = 0,
		Name = "Mini Overclock",
		Robux = 19,
		Description = "Refinery ×2 speed for 10 minutes of play time. Adds to your Overclock time.",
	} :: Product,
	OreRush = {
		Key = "OreRush",
		Id = 0,
		Name = "Ore Rush",
		Robux = 25,
		Description = "Ore per hit ×2 for 30 minutes of play time. Does not stack with the 2x Ore pass.",
	} :: Product,
	PetFeast = {
		Key = "PetFeast",
		Id = 0,
		Name = "Pet Feast",
		Robux = 29,
		Description = "6,000 XP to each pet you currently have equipped. A fixed grant, never a hatch.",
	} :: Product,
	CashBundle = {
		Key = "CashBundle",
		Id = 0,
		Name = "Cash Bundle",
		Robux = 39,
		Description = "60 minutes of current line income. Minimum $20,000; capped at 8% of your next rebirth cost.",
	} :: Product,
	CallMeteor = {
		Key = "CallMeteor",
		Id = 0,
		Name = "Call a Meteor",
		Description = "Brings the next meteor down in 30 seconds for the whole server. It can't choose the type or boost loot.",
	} :: Product,
	Overclock = {
		Key = "Overclock",
		Id = 0,
		Name = "Refinery Overclock",
		Description = "Your refinery runs ×2 speed for 30 minutes of play time (online only).",
	} :: Product,
}

-- Pass effects
Monetization.OreMult = 2 -- 2x Ore: ore quantity per hit
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

Monetization.MiniOverclock = { Duration = 10 * 60 }
Monetization.OreRush = { Multiplier = 2, Duration = 30 * 60 }
Monetization.PetXp = { PetTreat = 1500, PetFeast = 6000 } :: { [string]: number }
Monetization.CashPacks = {
	PocketChange = { Minutes = 10, Floor = 2000, CeilingShare = 0.03 },
	CashBundle = { Minutes = 60, Floor = 20000, CeilingShare = 0.08 },
} :: { [string]: CashPack }

-- Processed PurchaseIds are retained permanently. The previous 50-id limit could
-- regrant an old receipt; history discarded by an earlier version cannot be restored.

-- How often the server re-checks Call a Meteor availability for the store buttons
Monetization.AvailabilityInterval = 1

return Monetization
