--!strict
-- One pickaxe and one backpack for the whole game. Each has a single level you raise with cash,
-- and a tier that caps how high it goes. Evolving to the next tier costs the tier's price in
-- Config.Pickaxes / Config.Backpacks (cash and, at the top, shards; a player level gates it) and
-- needs the level at the cap. Shared.Gear holds the rules; this only tunes them.
--
-- The level restarts at 1 with every tier, and tier t has LevelsPerTier x t levels (10, 20, 30...).
-- The tier tables (Config.Pickaxes, Config.Backpacks) give the value at level 1 of each tier, and
-- the levels in between grow geometrically to the next tier's value. Reach and Crit grow linearly
-- over the same span, so a tier's start matches the tier before it plus one LevelsPerTier of
-- progress. A tier's levels cost about what LevelsPerTier levels did, spread over more steps.

local Gear = {}

Gear.LevelsPerTier = 10

export type StatCost = { Base: number, Growth: number } -- cash for level L to L+1 = Base x Growth^(L-1)

Gear.Pickaxe = {
	-- The lines the shop shows; every one of them follows the pickaxe's single level
	Stats = { "power", "speed", "reach", "crit" },
	Names = { power = "Power", speed = "Swing speed", reach = "Reach", crit = "Crit chance" },
	Cost = { Base = 45, Growth = 1.12 } :: StatCost,
	ReachPerLevel = 0.15, -- studs added to Config.Meteor.MineRange per level above 1
	CritPerLevel = 0.003, -- crit chance per level above 1
	CritMult = 2, -- a crit lands this multiple of the hit's Mining Power
}

Gear.Backpack = {
	Stats = { "capacity" },
	Names = { capacity = "Capacity" },
	Cost = { Base = 37.5, Growth = 1.12 } :: StatCost,
}

return Gear
