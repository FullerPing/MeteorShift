--!strict
-- Game passes and developer products (spec §9). MonetizationService applies them,
-- StoreController lists them behind the HUD's STORE button.
--
-- Id = 0 means "not on sale yet": nothing is prompted, nothing is looked up, and the
-- store shows "Not on sale yet". Fill in the real ids from the Creator Dashboard to
-- switch a pass or product on.
--
-- Not here, on purpose:
-- * The Extra Refinery pass (§9.1, "+1 refinery pad") is left out: every plot runs a
--   single production line with one refinery since the Round 3 rework, so there is
--   no second pad for it to add.
-- * Cash packs (§9.2) are out of scope for now.
--
-- No paid randomness, ever (§9.4): nothing here may change odds. 2x Ore doubles the
-- ore quantity per hit only; mineral index odds are never touched.

export type Pass = {
	Key: string,
	Id: number,
	Name: string,
	Description: string,
}

export type Product = {
	Key: string,
	Id: number,
	Name: string,
	Description: string,
}

local Monetization = {}

-- In store order
Monetization.PassOrder = { "TwoXOre", "BiggerBackpack", "OfflineHours", "AutoDeposit", "VIP", "Drillbot", "SolarPhoenix" }

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
		Description = "A pet drone that mines for you at 25% of your pickaxe (40% at max level), ore straight to your hopper. A fixed price, never random. Set the pass price to 199 Robux on Roblox.",
	} :: Pass,
	SolarPhoenix = {
		Key = "SolarPhoenix",
		Id = 0,
		Name = "Solar Phoenix Pet",
		Description = "The best miner pet: 31% of your pickaxe (50% at max level), ore straight to your hopper. A fixed price, never random. Set the pass price to 399 Robux on Roblox.",
	} :: Pass,
	VIP = {
		Key = "VIP",
		Id = 0,
		Name = "VIP",
		Description = "+10% bar value and a VIP chat tag.",
	} :: Pass,
}

Monetization.ProductOrder = { "CallMeteor", "Overclock" }

Monetization.Products = {
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

-- Receipts remembered per profile so ProcessReceipt stays idempotent
Monetization.ReceiptHistory = 50

-- How often the server re-checks Call a Meteor availability for the store buttons
Monetization.AvailabilityInterval = 1

return Monetization
