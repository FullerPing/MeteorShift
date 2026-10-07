--!strict
-- One pickaxe and one backpack for the whole game. Each has stats you level up with cash,
-- and a tier that caps how high they go. Evolving to the next tier costs the tier's price
-- in Config.Pickaxes / Config.Backpacks (cash only; a player level gates it) and needs the Gate stat at
-- the cap. Shared.Gear holds the rules; this only tunes them.
--
-- A stat level runs 1 to LevelsPerTier x tiers, across the whole game. Tier t caps it at
-- LevelsPerTier x t, so the first level of tier t is LevelsPerTier x (t - 1) + 1. The
-- tier tables (Config.Pickaxes, Config.Backpacks) give the value at that first level of
-- each tier, and the levels in between grow geometrically to the next tier's value.
-- Reach and Crit are linear in their level and carry across tiers.

local Gear = {}

Gear.LevelsPerTier = 10

export type StatCost = { Base: number, Growth: number } -- cash for level L to L+1 = Base x Growth^(L-1)

Gear.Pickaxe = {
	Stats = { "power", "speed", "reach", "crit" },
	Names = { power = "Power", speed = "Swing speed", reach = "Reach", crit = "Crit chance" },
	-- Evolving needs this stat at its tier cap
	Gate = "power",
	Cost = {
		power = { Base = 30, Growth = 1.115 },
		speed = { Base = 40, Growth = 1.115 },
		reach = { Base = 20, Growth = 1.11 },
		crit = { Base = 40, Growth = 1.11 },
	} :: { [string]: StatCost },
	ReachPerLevel = 0.15, -- studs added to Config.Meteor.MineRange per level above 1
	CritPerLevel = 0.003, -- crit chance per level above 1
	CritMult = 2, -- a crit lands this multiple of the hit's Mining Power
}

Gear.Backpack = {
	Stats = { "capacity" },
	Names = { capacity = "Capacity" },
	Gate = "capacity",
	Cost = {
		capacity = { Base = 25, Growth = 1.115 },
	} :: { [string]: StatCost },
}

return Gear
