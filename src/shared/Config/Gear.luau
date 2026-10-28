--!strict
-- One pickaxe and one backpack for the whole game. Each has a single level you raise with cash,
-- and a tier that caps how high it goes. Evolving to the next tier costs the tier's price in
-- Config.Pickaxes / Config.Backpacks (cash and, at the top, shards; a player level gates it) and
-- needs the level at the cap. Shared.Gear holds the rules; this only tunes them.
--
-- The level restarts at 1 with every tier, and tier t has LevelsPerTier x t levels (10, 20, 30...).
-- The tier tables (Config.Pickaxes, Config.Backpacks) give the value at level 1 of each tier, and
-- the levels in between grow geometrically to the next tier's value. Reach and Crit grow linearly
-- over the same span (Reach stops growing at ReachMax), so a tier's start matches the tier before it
-- plus one LevelsPerTier of progress. A tier's levels together cost the tier row's LevelCost, each level
-- LevelGrowth^(1 / tier) dearer than the one before (LevelGrowth over every LevelsPerTier of them).

local Gear = {}

Gear.LevelsPerTier = 10

Gear.LevelGrowth = 1.12

Gear.Pickaxe = {
	-- The lines the shop shows; every one of them follows the pickaxe's single level
	Stats = { "power", "speed", "reach", "crit" },
	Names = { power = "Power", speed = "Swing speed", reach = "Reach", crit = "Crit chance" },
	ReachPerLevel = 0.15, -- studs added to Config.Meteor.MineRange per level above 1
	ReachMax = 12, -- the most it adds (tier 8's last level), so a top pickaxe can't reach across the crater
	CritPerLevel = 0.003, -- crit chance per level above 1
	CritMult = 2, -- a crit lands this multiple of the hit's Mining Power
}

Gear.Backpack = {
	Stats = { "capacity" },
	Names = { capacity = "Capacity" },
}

return Gear
