--!strict
-- Pets (Shared.Pets holds the rules; PetService runs them). Each pet has explicit perks
-- growing linearly from its own Min at level 1 to Max at level 10. The first perk is its
-- main role. Equipped perks add per role to its cap; rarer pets have more and stronger perks.
-- You equip Slots pets, plus one for the ExtraPetSlot pass.
--
-- How you get them, with no paid randomness (spec §9.4):
--   eggs      hatched with Core Shards, which are only earned in play. Odds are shown in the
--             shop and a pity count guarantees an Epic or better every Pity hatches. A
--             duplicate pays DuplicateXp to the pet you already have.
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
export type Egg = { Id: string, Name: string, Cost: number, Odds: { [string]: number }, Pity: number, PityFrom: string, MinRebirths: number? }
export type Pet = {
	Id: string, Name: string, Rarity: string, Perks: { Perk }, Color: Color3, Blurb: string,
	Pass: string?, -- Config.Monetization pass key: owning the pass gives the pet (not in any egg)
	Robux: number?, -- the pass price, shown in the shop (the pass itself is priced on Roblox)
}

Pets.MaxLevel = 10
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
	miner = { Name = "Miner", Cap = 1.00, Text = "Mines for you at %s of your pickaxe. Its ore goes straight to the hopper." },
	hauler = { Name = "Hauler", Cap = 0.06, Text = "Carries %s of your backpack to the hopper every second." },
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

-- Eggs: Odds are percentages that add up to 100. Pity: after this many hatches without a
-- PityFrom-or-better pet, the next hatch is guaranteed one (the count resets on any such pet).
Pets.Eggs = {
	{ Id = "meteorEgg", Name = "Meteor Egg", Cost = 30,
		Odds = { common = 55, uncommon = 28, rare = 12, epic = 4.5, legendary = 0.5 }, Pity = 30, PityFrom = "epic" },
	{ Id = "crystalEgg", Name = "Crystal Egg", Cost = 120,
		Odds = { uncommon = 38, rare = 40, epic = 18, legendary = 4 }, Pity = 12, PityFrom = "epic" },
	-- Rebirth 2 unlock: nothing below Epic, and a Legendary is guaranteed every 10 hatches
	{ Id = "auroraEgg", Name = "Aurora Egg", Cost = 250, MinRebirths = 2,
		Odds = { epic = 88, legendary = 12 }, Pity = 10, PityFrom = "legendary" },
} :: { Egg }

-- A duplicate pet gives this much XP to the one you already own
Pets.DuplicateXp = 400

-- Each perk's Min is level 1 and Max is level 10. Keep catalog order stable: egg picks
-- choose within a rarity in this order. Premium pets are fixed passes, never egg prizes.
Pets.List = {
	-- Common
	{ Id = "pebblePup", Name = "Pebble Pup", Rarity = "common", Color = Color3.fromRGB(150, 150, 150), Blurb = "A grey pup who digs where you dig.",
		Perks = { { Role = "yield", Min = 0.05, Max = 0.10 } } },
	{ Id = "scrapSparrow", Name = "Scrap Sparrow", Rarity = "common", Color = Color3.fromRGB(190, 160, 110), Blurb = "Haggles with the odds and ends.",
		Perks = { { Role = "scholar", Min = 0.08, Max = 0.16 } } },
	-- Uncommon
	{ Id = "packMule", Name = "Pack Mule", Rarity = "uncommon", Color = Color3.fromRGB(190, 160, 120), Blurb = "Carries what your sack can't.",
		Perks = { { Role = "pack", Min = 0.15, Max = 0.30 } } },
	{ Id = "sparkHare", Name = "Spark Hare", Rarity = "uncommon", Color = Color3.fromRGB(255, 220, 90), Blurb = "Static in its fur. Quickens your swing.",
		Perks = { { Role = "swift", Min = 0.05, Max = 0.12 } } },
	-- Rare
	{ Id = "jetWisp", Name = "Jet Wisp", Rarity = "rare", Color = Color3.fromRGB(110, 220, 255), Blurb = "Hurries your pickaxe along.",
		Perks = { { Role = "swift", Min = 0.08, Max = 0.18 }, { Role = "sprint", Min = 0.06, Max = 0.15 } } },
	{ Id = "coinMagpie", Name = "Coin Magpie", Rarity = "rare", Color = Color3.fromRGB(255, 220, 100), Blurb = "Haggles for a better price.",
		Perks = { { Role = "merchant", Min = 0.08, Max = 0.20 } } },
	{ Id = "cargoMole", Name = "Cargo Mole", Rarity = "rare", Color = Color3.fromRGB(150, 120, 96), Blurb = "Digs your ore home for you.",
		Perks = { { Role = "hauler", Min = 0.012, Max = 0.03 }, { Role = "pack", Min = 0.08, Max = 0.18 } } },
	{ Id = "graniteGolem", Name = "Granite Golem", Rarity = "rare", Color = Color3.fromRGB(120, 130, 140), Blurb = "A walking boulder with room inside.",
		Perks = { { Role = "pack", Min = 0.20, Max = 0.38 }, { Role = "vault", Min = 0.25, Max = 0.60 } } },
	-- Epic
	{ Id = "crystalStag", Name = "Crystal Stag", Rarity = "epic", Color = Color3.fromRGB(190, 130, 255), Blurb = "Antlers of living crystal. It breaks rock with them.",
		Perks = { { Role = "crit", Min = 0.04, Max = 0.10 }, { Role = "miner", Min = 0.12, Max = 0.25 } } },
	{ Id = "lodeWyrm", Name = "Lode Wyrm", Rarity = "epic", Color = Color3.fromRGB(255, 170, 70), Blurb = "A burrowing worm that tunnels your ore home.",
		Perks = { { Role = "hauler", Min = 0.015, Max = 0.0375 }, { Role = "vault", Min = 0.35, Max = 0.80 } } },
	{ Id = "auroraOwl", Name = "Aurora Owl", Rarity = "epic", Color = Color3.fromRGB(120, 255, 210), Blurb = "Sees the best price in any light.",
		Perks = { { Role = "merchant", Min = 0.12, Max = 0.28 }, { Role = "shards", Min = 0.06, Max = 0.15 } } },
	-- Legendary
	{ Id = "meteorDrake", Name = "Meteor Drake", Rarity = "legendary", Color = Color3.fromRGB(255, 130, 50), Blurb = "Born in a crater. It never stops digging.",
		Perks = { { Role = "miner", Min = 0.22, Max = 0.36 }, { Role = "yield", Min = 0.08, Max = 0.18 }, { Role = "shards", Min = 0.08, Max = 0.20 } } },
	-- Premium (game passes: fixed price, never random, the strongest miners)
	{ Id = "drillbot", Name = "Drillbot", Rarity = "premium", Pass = "Drillbot", Robux = 99, Color = Color3.fromRGB(255, 176, 48), Blurb = "A little drill on legs. It keeps swinging while you do.",
		Perks = { { Role = "miner", Min = 0.25, Max = 0.40 }, { Role = "swift", Min = 0.08, Max = 0.20 }, { Role = "yield", Min = 0.10, Max = 0.20 } } },
	{ Id = "solarPhoenix", Name = "Solar Phoenix", Rarity = "premium", Pass = "SolarPhoenix", Robux = 199, Color = Color3.fromRGB(255, 120, 60), Blurb = "A sun in feathers. It mines at the speed of light.",
		Perks = { { Role = "miner", Min = 0.50, Max = 1.00 }, { Role = "merchant", Min = 0.15, Max = 0.35 }, { Role = "scholar", Min = 0.15, Max = 0.35 } } },
} :: { Pet }

Pets.Starter = {} :: { string } -- pets every new profile starts with (none: eggs and passes)

return Pets
