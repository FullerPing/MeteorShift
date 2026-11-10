--!strict
-- Relics (Shared.Relics, RelicService): rare finds that give a small permanent boost, kept forever (rebirth too).
-- Owner feedback (2026-10-23): "relics that give permanent boosts". Each relic adds to one pet role (Config.Pets.Roles)
-- on top of the pets' capped total, so it reaches every system that reads PlayerStateService:GetPetBonuses.
-- A relic you already own turns into Relic Fragments, the rare material pet fusing costs (Config.Pets.Fuse).
-- Roles with pet visuals (miner, hauler) are left out: a relic has no body to work with.
export type Relic = { Id: string, Name: string, Role: string, Value: number, Blurb: string }

local Relics = {}

-- Chances per roll (Shared.Relics.roll): every player who shares a cracked core rolls once, a boss (Alien) core
-- rolls at BossChance, and each ore-field rock broken rolls at RockChance
Relics.CoreChance = 0.03
Relics.BossChance = 0.25
Relics.RockChance = 0.0008
Relics.DuplicateFragments = 5 -- a relic found again
Relics.BossFragments = 3 -- every player who shares a cracked boss core, relic or not

Relics.List = {
	{ Id = "luckyHorseshoe", Name = "Lucky Horseshoe", Role = "crit", Value = 0.02, Blurb = "Bent from a meteor's iron. Your crits come easier." },
	{ Id = "ancientPick", Name = "Ancient Pick Head", Role = "yield", Value = 0.05, Blurb = "Older than the crater. Every hit gives a little more." },
	{ Id = "merchantScale", Name = "Merchant's Scale", Role = "merchant", Value = 0.05, Blurb = "It always tips your way." },
	{ Id = "starCompass", Name = "Star Compass", Role = "sprint", Value = 0.05, Blurb = "Points to the next meteor, so you hurry." },
	{ Id = "sageLens", Name = "Sage's Lens", Role = "scholar", Value = 0.10, Blurb = "See what the rock is teaching you." },
	{ Id = "shardPrism", Name = "Shard Prism", Role = "shards", Value = 0.05, Blurb = "Splits a core's light into more shards." },
	{ Id = "deepSatchel", Name = "Deep Satchel", Role = "pack", Value = 0.10, Blurb = "There is always room for one more ore." },
	{ Id = "cometHeart", Name = "Comet Heart", Role = "swift", Value = 0.03, Blurb = "Still warm. Your swing keeps its beat." },
	{ Id = "vaultKey", Name = "Vault Key", Role = "vault", Value = 0.15, Blurb = "Opens a little more room at the hopper." },
} :: { Relic }

return Relics
