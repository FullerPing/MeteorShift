--!strict
-- Pets (Shared.Pets holds the rules; PetService runs them). Each pet has one role and levels
-- up from 1 to MaxLevel; its perk grows from the role's Min to its Max. You equip a few at a
-- time (Slots). Pets are never random: the Drillbot is a fixed-price game pass (199 Robux, the
-- `Drillbot` pass in Config.Monetization), the others cost Core Shards, and nothing here
-- changes mineral odds (spec §9.4).
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
export type Pet = {
	Id: string, Name: string, Role: string, Cost: number, Color: Color3, Blurb: string,
	Pass: string?, -- Config.Monetization pass key: owning the pass gives the pet (no shard price)
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
	miner = { Name = "Miner", Min = 0.25, Max = 0.40, Cap = 0.40, Text = "Mines for you at %s of your pickaxe. Its ore goes straight to the hopper." },
	hauler = { Name = "Hauler", Min = 0.01, Max = 0.025, Cap = 0.05, Text = "Carries %s of your backpack to the hopper every second." },
	pack = { Name = "Pack", Min = 0.15, Max = 0.30, Cap = 0.30, Text = "Expands your backpack by %s." },
	swift = { Name = "Swift", Min = 0.05, Max = 0.15, Cap = 0.15, Text = "Shortens your swing by %s." },
	merchant = { Name = "Merchant", Min = 0.05, Max = 0.15, Cap = 0.15, Text = "Bars sell for %s more." },
} :: { [string]: Role }
Pets.RoleOrder = { "miner", "hauler", "pack", "swift", "merchant" }

-- Cost is in Core Shards (a pass pet has none: Pass and Robux instead)
Pets.List = {
	{ Id = "drillbot", Name = "Drillbot", Role = "miner", Cost = 0, Pass = "Drillbot", Robux = 199, Color = Color3.fromRGB(255, 176, 48), Blurb = "A little drill on legs. It keeps swinging while you do." },
	{ Id = "cargoMole", Name = "Cargo Mole", Role = "hauler", Cost = 25, Color = Color3.fromRGB(150, 120, 96), Blurb = "Digs your ore home for you." },
	{ Id = "packMule", Name = "Pack Mule", Role = "pack", Cost = 40, Color = Color3.fromRGB(190, 160, 120), Blurb = "Carries what your sack can't." },
	{ Id = "jetWisp", Name = "Jet Wisp", Role = "swift", Cost = 60, Color = Color3.fromRGB(110, 220, 255), Blurb = "Hurries your pickaxe along." },
	{ Id = "coinMagpie", Name = "Coin Magpie", Role = "merchant", Cost = 80, Color = Color3.fromRGB(255, 220, 100), Blurb = "Haggles for a better price." },
} :: { Pet }

Pets.Starter = {} :: { string } -- pets every new profile starts with (none: the Drillbot is a pass)

return Pets
