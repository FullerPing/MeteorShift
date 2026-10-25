--!strict
-- Pets (Shared.Pets holds the rules; PetService runs them). Each pet has explicit perks
-- growing linearly from its own Min at level 1 to Max at level 10. The first perk is its
-- main role. Equipped perks add per role to its cap; rarer pets have more and stronger perks.
-- You equip Slots pets, plus one for the ExtraPetSlot pass.
--
-- How you get them, with no paid randomness (spec §9.4):
--   eggs      hatched with Core Shards, which are only earned in play. Odds are shown in the
--             shop and a pity count guarantees an Epic or better every Pity hatches. A
--             duplicate is another copy of the pet (it shares the level of the ones you have) that
--             can go out in its own slot.
--   passes    two fixed-price Robux pets (game passes, Config.Monetization), always the best
--             looking and the strongest in their role. They are not in any egg.
-- Nothing here changes mineral odds.
--
--   miner     mines for you while you are mining (a swing of yours in the last MinerWindow
--             seconds): every swing of your pickaxe it hits
--             the nearest target in reach with this share of your Mining Power and ore. Its
--             ore goes straight to the hopper. It never counts for the podium, the core
--             rewards or mineral drops, and it doesn't count toward the meteor's size.
--   hauler    moves this share of your backpack capacity to the hopper every second
--   pack      raises your backpack capacity by this share
--   swift     shortens your swing time by this share (Mining Power per second goes up)
--   merchant  raises what your bars sell for by this share
--   yield     raises the ore from each validated hit by this share, never mineral odds
--   sprint    raises walking speed from base 16 without overriding other speed changes
--   vault     raises hopper and collection post capacity, online and offline
--   crit      adds this many points to the pickaxe's critical-hit chance
--   scholar   raises all player XP gains (not pet XP)
--   shards    raises a cracked core's total shard payout, rounded down

local Pets = {}

export type Role = { Name: string, Cap: number, Text: string }
export type Perk = { Role: string, Min: number, Max: number }
export type Rarity = { Id: string, Name: string, Color: Color3 }
-- Own: the egg hatches only the pets that list it in their Eggs (its exclusives), never the shared pool
-- World: the world whose Hatchery has its stand (Config.Worlds; nil = World 1); it can only be hatched there
export type Egg = { Id: string, Name: string, Cost: number, Odds: { [string]: number }, Pity: number, PityFrom: string, MinRebirths: number?, Own: boolean?,
	World: number? }
export type Pet = {
	Id: string, Name: string, Rarity: string, Perks: { Perk }, Color: Color3, Blurb: string,
	Group: boolean?, -- the group reward (Pets.GroupReward): free for members of the game's Roblox group, never in an egg
	Pass: string?, -- Config.Monetization pass key: owning the pass gives the pet (not in any egg); the price is Config.Monetization.Passes[Pass].Robux, as PetsController shows it
	Eggs: { string }?, -- only these eggs hatch it (an egg's exclusives); nil: every egg with odds for its rarity
}

Pets.MaxLevel = 10
-- Fusing (owner feedback, 2026-10-23: "3 of each to combine; requires some hard to get thing"): Copies of one pet and
-- Relic Fragments (Config.Relics, only from duplicate relics and boss cores) make it Fused: two copies are used up and
-- every perk of that pet is multiplied by Mult (roles still stop at their caps). Pass and group pets never have copies.
Pets.Fuse = {
	Copies = 3,
	Mult = 1.5,
	Fragments = { common = 5, uncommon = 10, rare = 20, epic = 35, legendary = 60 } :: { [string]: number },
}
-- XP to go from level L to L + 1 is XpBase x XpGrowth^(L - 1); about 14K XP to max a pet
Pets.XpBase = 150
Pets.XpGrowth = 1.55
-- A miner pet only works while you are mining: it needs a validated swing of yours this recent,
-- so it adds to your play and can't farm while you stand idle.
Pets.MinerWindow = 15

-- XP every equipped pet earns per validated hit of yours (a pet's own hits give none)
Pets.XpPerHit = { Crust = 1, Core = 2, Debris = 0.2 } :: { [string]: number }

-- Pets you can have out at once: Base, plus PerRebirth for each rebirth, up to Max, plus one
-- more from rebirth ExtraAtRebirth on (the rank 4 unlock). The Pet Bond perk (Config.Perks) and
-- the ExtraPetSlot pass add to that.
Pets.Slots = { Base = 1, PerRebirth = 1, Max = 3, ExtraAtRebirth = 4 }

Pets.Roles = {
	-- 1.5 so a second miner adds to a maxed Solar Phoenix (its 1.0 alone used to fill the cap, leaving Drillbot's miner role idle)
	miner = { Name = "Miner", Cap = 1.50, Text = "Mines for you at %s of your pickaxe. Its ore goes straight to the hopper." },
	-- 0.03: two maxed haulers used to empty a backpack every ~17 s, so nobody walked ore to the Foundry any more
	hauler = { Name = "Hauler", Cap = 0.03, Text = "Carries %s of your backpack to the hopper every second." },
	pack = { Name = "Pack", Cap = 0.60, Text = "Expands your backpack by %s." },
	swift = { Name = "Swift", Cap = 0.30, Text = "Shortens your swing by %s." },
	merchant = { Name = "Merchant", Cap = 0.45, Text = "Bars sell for %s more." },
	yield = { Name = "Yield", Cap = 0.40, Text = "Each validated hit gives %s more ore." },
	sprint = { Name = "Sprint", Cap = 0.30, Text = "Walks %s faster." },
	vault = { Name = "Vault", Cap = 1.00, Text = "Expands your hopper and collection post by %s." },
	crit = { Name = "Crit", Cap = 0.15, Text = "Adds %s to your pickaxe's critical-hit chance." },
	scholar = { Name = "Scholar", Cap = 0.60, Text = "Gains %s more player XP." },
	shards = { Name = "Shards", Cap = 0.30, Text = "Cracked cores give %s more Core Shards, rounded down." },
} :: { [string]: Role }
Pets.RoleOrder = { "miner", "hauler", "pack", "swift", "merchant", "yield", "sprint", "vault", "crit", "scholar", "shards" }

-- Rarest last. Premium pets come from passes only.
Pets.Rarities = {
	common = { Id = "common", Name = "Common", Color = Color3.fromRGB(176, 186, 198) },
	uncommon = { Id = "uncommon", Name = "Uncommon", Color = Color3.fromRGB(120, 220, 140) },
	rare = { Id = "rare", Name = "Rare", Color = Color3.fromRGB(90, 170, 255) },
	epic = { Id = "epic", Name = "Epic", Color = Color3.fromRGB(190, 120, 255) },
	legendary = { Id = "legendary", Name = "Legendary", Color = Color3.fromRGB(255, 190, 60) },
	premium = { Id = "premium", Name = "Premium", Color = Color3.fromRGB(255, 110, 190) },
} :: { [string]: Rarity }
Pets.RarityOrder = { "common", "uncommon", "rare", "epic", "legendary", "premium" }

-- Eggs: Costs are fitted to shard income (Balance.ShardsPerMeteor per meteor cycle, about 3 a minute): a Meteor Egg
-- every ~5 minutes of play, a Crystal Egg every ~20 and an Aurora Egg every ~45 (tests/Pacing.spec). They used to
-- cost 30 / 120 / 250, which with tighter odds made eggs feel worthless (owner feedback, 2026-10-23).
-- Odds are percentages that add up to 100. Pity: after this many hatches without a
-- PityFrom-or-better pet, the next hatch is guaranteed one (the count resets on any such pet).
Pets.Eggs = {
	{ Id = "meteorEgg", Name = "Meteor Egg", Cost = 15,
		Odds = { common = 60, uncommon = 28, rare = 9.5, epic = 2.25, legendary = 0.25 }, Pity = 40, PityFrom = "epic" },
	{ Id = "crystalEgg", Name = "Crystal Egg", Cost = 60,
		Odds = { uncommon = 40, rare = 42, epic = 15.5, legendary = 2.5 }, Pity = 15, PityFrom = "epic" },
	-- Rebirth 2 unlock: Rare or better, a Legendary guaranteed every 25 hatches; below the Magma Egg, which costs more
	-- (earlier 10-hatch pity with 12% odds filled every slot with Meteor Drakes, the only Legendary, in a few thousand shards)
	{ Id = "auroraEgg", Name = "Aurora Egg", Cost = 135, MinRebirths = 2,
		-- owner, 2026-10-24: was epic 94 / legendary 6 with a 20-hatch pity, too good for its price
		Odds = { rare = 55, epic = 40, legendary = 5 }, Pity = 25, PityFrom = "legendary" },
	-- Late eggs (owner's design canvas, 2026-10-23), each with its own exclusive pets (Own): about 75 minutes and two hours
	-- of shard income
	{ Id = "magmaEgg", Name = "Magma Egg", Cost = 225, MinRebirths = 3, Own = true,
		Odds = { rare = 50, epic = 40, legendary = 10 }, Pity = 15, PityFrom = "legendary" },
	{ Id = "voidEgg", Name = "Void Egg", Cost = 360, MinRebirths = 5, Own = true,
		Odds = { epic = 70, legendary = 30 }, Pity = 6, PityFrom = "legendary" },
	-- Nebula Rift's only egg (owner, 2026-10-25): every Epic and Legendary that hatches anywhere, the Magma and Void
	-- exclusives included (they list it in their Eggs)
	{ Id = "nebulaEgg", Name = "Nebula Egg", Cost = 500, MinRebirths = 25, World = 2,
		Odds = { epic = 65, legendary = 35 }, Pity = 5, PityFrom = "legendary" },
} :: { Egg }

-- Each perk's Min is level 1 and Max is level 10. Keep catalog order stable: egg picks
-- choose within a rarity in this order. Premium pets are fixed passes, never egg prizes.
Pets.List = {
	-- Common
	{ Id = "pebblePup", Name = "Pebble Pup", Rarity = "common", Color = Color3.fromRGB(150, 150, 150), Blurb = "A grey pup who digs where you dig.",
		Perks = { { Role = "yield", Min = 0.05, Max = 0.10 } } },
	{ Id = "scrapSparrow", Name = "Scrap Sparrow", Rarity = "common", Color = Color3.fromRGB(190, 160, 110), Blurb = "Haggles with the odds and ends.",
		Perks = { { Role = "scholar", Min = 0.08, Max = 0.16 } } },
	{ Id = "dustBunny", Name = "Dust Bunny", Rarity = "common", Color = Color3.fromRGB(214, 200, 178), Blurb = "A ball of crater dust that stuffs your sack.",
		Perks = { { Role = "pack", Min = 0.06, Max = 0.12 } } },
	{ Id = "emberNewt", Name = "Ember Newt", Rarity = "common", Color = Color3.fromRGB(255, 120, 70), Blurb = "Warm toes, quick feet.",
		Perks = { { Role = "sprint", Min = 0.05, Max = 0.10 } } },
	-- Uncommon
	{ Id = "packMule", Name = "Pack Mule", Rarity = "uncommon", Color = Color3.fromRGB(190, 160, 120), Blurb = "Carries what your sack can't.",
		Perks = { { Role = "pack", Min = 0.15, Max = 0.30 } } },
	{ Id = "sparkHare", Name = "Spark Hare", Rarity = "uncommon", Color = Color3.fromRGB(255, 220, 90), Blurb = "Static in its fur. Quickens your swing.",
		Perks = { { Role = "swift", Min = 0.05, Max = 0.12 } } },
	{ Id = "geodeTurtle", Name = "Geode Turtle", Rarity = "uncommon", Color = Color3.fromRGB(150, 110, 200), Blurb = "Its shell is a geode. There is room inside.",
		Perks = { { Role = "vault", Min = 0.15, Max = 0.35 } } },
	-- Rare
	{ Id = "jetWisp", Name = "Jet Wisp", Rarity = "rare", Color = Color3.fromRGB(110, 220, 255), Blurb = "Hurries your pickaxe along.",
		Perks = { { Role = "swift", Min = 0.08, Max = 0.18 }, { Role = "sprint", Min = 0.06, Max = 0.15 } } },
	{ Id = "coinMagpie", Name = "Coin Magpie", Rarity = "rare", Color = Color3.fromRGB(255, 220, 100), Blurb = "Haggles for a better price.",
		Perks = { { Role = "merchant", Min = 0.08, Max = 0.20 } } },
	{ Id = "cargoMole", Name = "Cargo Mole", Rarity = "rare", Color = Color3.fromRGB(150, 120, 96), Blurb = "Digs your ore home for you.",
		Perks = { { Role = "hauler", Min = 0.006, Max = 0.015 }, { Role = "pack", Min = 0.08, Max = 0.18 } } },
	{ Id = "graniteGolem", Name = "Granite Golem", Rarity = "rare", Color = Color3.fromRGB(120, 130, 140), Blurb = "A walking boulder with room inside.",
		Perks = { { Role = "pack", Min = 0.20, Max = 0.38 }, { Role = "vault", Min = 0.25, Max = 0.60 } } },
	{ Id = "nebulaJelly", Name = "Nebula Jelly", Rarity = "rare", Color = Color3.fromRGB(200, 130, 255), Blurb = "Floats in from space and learns everything.",
		Perks = { { Role = "scholar", Min = 0.15, Max = 0.30 }, { Role = "shards", Min = 0.03, Max = 0.06 } } },
	{ Id = "magmaCrab", Name = "Magma Crab", Rarity = "rare", Eggs = { "magmaEgg" }, Color = Color3.fromRGB(230, 80, 40), Blurb = "Pinches cooling rock until it cracks.",
		Perks = { { Role = "crit", Min = 0.03, Max = 0.07 }, { Role = "yield", Min = 0.05, Max = 0.10 } } },
	-- Epic
	{ Id = "crystalStag", Name = "Crystal Stag", Rarity = "epic", Color = Color3.fromRGB(190, 130, 255), Blurb = "Antlers of living crystal. It breaks rock with them.",
		Perks = { { Role = "crit", Min = 0.04, Max = 0.10 }, { Role = "miner", Min = 0.12, Max = 0.25 } } },
	{ Id = "lodeWyrm", Name = "Lode Wyrm", Rarity = "epic", Color = Color3.fromRGB(255, 170, 70), Blurb = "A burrowing worm that tunnels your ore home.",
		Perks = { { Role = "hauler", Min = 0.008, Max = 0.02 }, { Role = "vault", Min = 0.35, Max = 0.80 } } },
	{ Id = "auroraOwl", Name = "Aurora Owl", Rarity = "epic", Color = Color3.fromRGB(120, 255, 210), Blurb = "Sees the best price in any light.",
		Perks = { { Role = "merchant", Min = 0.12, Max = 0.28 }, { Role = "shards", Min = 0.06, Max = 0.15 } } },
	{ Id = "frostYeti", Name = "Frost Yeti", Rarity = "epic", Eggs = { "magmaEgg", "nebulaEgg" }, Color = Color3.fromRGB(190, 230, 255), Blurb = "Hauls ice blocks for fun. Your ore is easy.",
		Perks = { { Role = "hauler", Min = 0.01, Max = 0.02 }, { Role = "pack", Min = 0.20, Max = 0.40 } } },
	{ Id = "quartzKitsune", Name = "Quartz Kitsune", Rarity = "epic", Eggs = { "voidEgg", "nebulaEgg" }, Color = Color3.fromRGB(255, 190, 230), Blurb = "Three crystal tails. Every trader trusts it.",
		Perks = { { Role = "merchant", Min = 0.15, Max = 0.30 }, { Role = "crit", Min = 0.03, Max = 0.08 } } },
	-- Legendary
	{ Id = "meteorDrake", Name = "Meteor Drake", Rarity = "legendary", Color = Color3.fromRGB(255, 130, 50), Blurb = "Born in a crater. It never stops digging.",
		Perks = { { Role = "miner", Min = 0.22, Max = 0.36 }, { Role = "yield", Min = 0.08, Max = 0.18 }, { Role = "shards", Min = 0.08, Max = 0.20 } } },
	{ Id = "galaxyGriffin", Name = "Galaxy Griffin", Rarity = "legendary", Eggs = { "magmaEgg", "nebulaEgg" }, Color = Color3.fromRGB(90, 80, 200), Blurb = "Half eagle, half night sky. Cores crack for it.",
		Perks = { { Role = "shards", Min = 0.10, Max = 0.20 }, { Role = "miner", Min = 0.20, Max = 0.32 }, { Role = "scholar", Min = 0.15, Max = 0.30 } } },
	{ Id = "voidLeviathan", Name = "Void Leviathan", Rarity = "legendary", Eggs = { "voidEgg", "nebulaEgg" }, Color = Color3.fromRGB(60, 40, 110), Blurb = "Swims between meteors. Swallows whole veins.",
		Perks = { { Role = "miner", Min = 0.25, Max = 0.38 }, { Role = "vault", Min = 0.40, Max = 0.90 }, { Role = "yield", Min = 0.06, Max = 0.12 } } }, -- miner under Drillbot's 0.40
	-- Group reward (Pets.GroupReward): free for joining the game's Roblox group, a Rare's strength, never in an egg
	{ Id = "cometFox", Name = "Comet Fox", Rarity = "rare", Group = true, Color = Color3.fromRGB(127, 182, 255), Blurb = "Our group's mascot. It leaves stardust behind your swing.",
		Perks = { { Role = "swift", Min = 0.06, Max = 0.14 }, { Role = "sprint", Min = 0.05, Max = 0.12 } } },
	-- Premium (game passes: fixed price, never random, the strongest miners)
	{ Id = "drillbot", Name = "Drillbot", Rarity = "premium", Pass = "Drillbot", Color = Color3.fromRGB(255, 176, 48), Blurb = "A little drill on legs. It keeps swinging while you do.",
		Perks = { { Role = "miner", Min = 0.25, Max = 0.40 }, { Role = "swift", Min = 0.08, Max = 0.20 }, { Role = "yield", Min = 0.10, Max = 0.20 } } },
	{ Id = "solarPhoenix", Name = "Solar Phoenix", Rarity = "premium", Pass = "SolarPhoenix", Color = Color3.fromRGB(255, 120, 60), Blurb = "A sun in feathers. It mines at the speed of light.",
		Perks = { { Role = "miner", Min = 0.50, Max = 1.00 }, { Role = "merchant", Min = 0.15, Max = 0.35 }, { Role = "scholar", Min = 0.15, Max = 0.35 } } },
} :: { Pet }

-- Join the game's Roblox group, get Pet once (PetService.GiveGroupPet). GroupId 0 would switch it off;
-- the id is the owner's group (from its URL).
Pets.GroupReward = { GroupId = 526085770, Pet = "cometFox" }

Pets.Starter = {} :: { string } -- pets every new profile starts with (none: eggs and passes)

return Pets
