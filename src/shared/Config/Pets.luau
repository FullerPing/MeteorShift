--!strict
-- Pets (Shared.Pets holds the rules; PetService runs them). Each pet has one role and levels
-- up from 1 to MaxLevel; its perk grows from the role's Min to its Max, times the pet's Power
-- (rarer pets are stronger and look better). You equip a few at a time (Slots).
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
-- Several pets of one role add up, to the role's cap.

local Pets = {}

export type Role = { Name: string, Min: number, Max: number, Cap: number, Text: string }
export type Rarity = { Id: string, Name: string, Color: Color3 }
export type Egg = { Id: string, Name: string, Cost: number, Odds: { [string]: number }, Pity: number, PityFrom: string }
export type Pet = {
	Id: string, Name: string, Role: string, Rarity: string, Power: number, Color: Color3, Blurb: string,
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

-- Pets you can have out at once: Base, plus PerRebirth for each rebirth, up to Max
Pets.Slots = { Base = 1, PerRebirth = 1, Max = 3 }

Pets.Roles = {
	miner = { Name = "Miner", Min = 0.25, Max = 0.40, Cap = 0.50, Text = "Mines for you at %s of your pickaxe. Its ore goes straight to the hopper." },
	hauler = { Name = "Hauler", Min = 0.01, Max = 0.025, Cap = 0.05, Text = "Carries %s of your backpack to the hopper every second." },
	pack = { Name = "Pack", Min = 0.15, Max = 0.30, Cap = 0.45, Text = "Expands your backpack by %s." },
	swift = { Name = "Swift", Min = 0.05, Max = 0.15, Cap = 0.225, Text = "Shortens your swing by %s." },
	merchant = { Name = "Merchant", Min = 0.05, Max = 0.15, Cap = 0.225, Text = "Bars sell for %s more." },
} :: { [string]: Role }
Pets.RoleOrder = { "miner", "hauler", "pack", "swift", "merchant" }

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
} :: { Egg }

-- A duplicate pet gives this much XP to the one you already own
Pets.DuplicateXp = 400

-- Power scales the role's whole perk range. Miner power stays below the paid miners'.
Pets.List = {
	-- Common
	{ Id = "pebblePup", Name = "Pebble Pup", Role = "miner", Rarity = "common", Power = 0.6, Color = Color3.fromRGB(150, 150, 150), Blurb = "A grey pup who digs where you dig." },
	{ Id = "scrapSparrow", Name = "Scrap Sparrow", Role = "merchant", Rarity = "common", Power = 0.8, Color = Color3.fromRGB(190, 160, 110), Blurb = "Haggles with the odds and ends." },
	-- Uncommon
	{ Id = "packMule", Name = "Pack Mule", Role = "pack", Rarity = "uncommon", Power = 1.0, Color = Color3.fromRGB(190, 160, 120), Blurb = "Carries what your sack can't." },
	{ Id = "sparkHare", Name = "Spark Hare", Role = "swift", Rarity = "uncommon", Power = 1.0, Color = Color3.fromRGB(255, 220, 90), Blurb = "Static in its fur. Quickens your swing." },
	-- Rare
	{ Id = "jetWisp", Name = "Jet Wisp", Role = "swift", Rarity = "rare", Power = 1.2, Color = Color3.fromRGB(110, 220, 255), Blurb = "Hurries your pickaxe along." },
	{ Id = "coinMagpie", Name = "Coin Magpie", Role = "merchant", Rarity = "rare", Power = 1.2, Color = Color3.fromRGB(255, 220, 100), Blurb = "Haggles for a better price." },
	{ Id = "cargoMole", Name = "Cargo Mole", Role = "hauler", Rarity = "rare", Power = 1.2, Color = Color3.fromRGB(150, 120, 96), Blurb = "Digs your ore home for you." },
	{ Id = "graniteGolem", Name = "Granite Golem", Role = "pack", Rarity = "rare", Power = 1.2, Color = Color3.fromRGB(120, 130, 140), Blurb = "A walking boulder with room inside." },
	-- Epic
	{ Id = "crystalStag", Name = "Crystal Stag", Role = "miner", Rarity = "epic", Power = 0.85, Color = Color3.fromRGB(190, 130, 255), Blurb = "Antlers of living crystal. It breaks rock with them." },
	{ Id = "lodeWyrm", Name = "Lode Wyrm", Role = "hauler", Rarity = "epic", Power = 1.5, Color = Color3.fromRGB(255, 170, 70), Blurb = "A burrowing worm that tunnels your ore home." },
	{ Id = "auroraOwl", Name = "Aurora Owl", Role = "merchant", Rarity = "epic", Power = 1.35, Color = Color3.fromRGB(120, 255, 210), Blurb = "Sees the best price in any light." },
	-- Legendary
	{ Id = "meteorDrake", Name = "Meteor Drake", Role = "miner", Rarity = "legendary", Power = 0.95, Color = Color3.fromRGB(255, 130, 50), Blurb = "Born in a crater. It never stops digging." },
	-- Premium (game passes: fixed price, never random, the strongest miners)
	{ Id = "drillbot", Name = "Drillbot", Role = "miner", Rarity = "premium", Power = 1.0, Pass = "Drillbot", Robux = 199, Color = Color3.fromRGB(255, 176, 48), Blurb = "A little drill on legs. It keeps swinging while you do." },
	{ Id = "solarPhoenix", Name = "Solar Phoenix", Role = "miner", Rarity = "premium", Power = 1.25, Pass = "SolarPhoenix", Robux = 399, Color = Color3.fromRGB(255, 120, 60), Blurb = "A sun in feathers. It mines at the speed of light." },
} :: { Pet }

Pets.Starter = {} :: { string } -- pets every new profile starts with (none: eggs and passes)

return Pets
