--!strict
-- Player level (XP). Separate from gear: it is earned by taking part in meteors, survives
-- rebirth, and gates evolving (Shared.Levels, Server.ShopService) and ore yield. Tune here.
--
-- Levels run 1 to 50 and everything unlocks somewhere on that road (docs/economy-rework.md):
-- tiers 5 to 8 at 10 / 16 / 24 / 34, Frost cleared at 12, Crystal at 24, Alien at 38. At a
-- full meteor of hitting (about 70 XP) level 10 is about 20 minutes in and level 50 about a
-- day of play.

return {
	MaxLevel = 50,

	-- XP to go from level L to L + 1 is XpFlat + XpQuad × L² (a gentle curve: ~37 XP at level 5,
	-- ~140 at 20, ~1,240 at 49). Level 50 is about 21K XP in total.
	XpFlat = 15,
	XpQuad = 0.5,

	-- XP comes in as you play, never as a lump after the meteor: each validated hit on a crust
	-- node or the core, and a bonus when a core you hit is cracked. All times the meteor ore's
	-- TypeMult. Debris and standing around pay nothing, so it can't be farmed idle. A full
	-- meteor of hitting (about 140 crust hits, 20 core hits, then the crack) is about 70 XP.
	CrustHitXp = 0.25,
	CoreHitXp = 0.5,
	CrackBonusXp = 25,
	TypeMult = { iron = 1, frost = 1.5, crystal = 2, alien = 3 }, -- by ore id

	-- Ore clearance: the player level that mines each ore at its full yield. Under it a hit
	-- yields UnderLevelFloor of its ore at level 1, rising geometrically to 1 at the clearance
	-- level (Shared.Levels.oreYield). Nobody is locked out and the refinery never slows down:
	-- the bar price is the same for everyone, the fraction just keeps a newcomer in a
	-- Crystal meteor from outrunning the levels that earn it.
	OreLevel = { iron = 1, frost = 12, crystal = 24, alien = 38 },
	UnderLevelFloor = 0.4,

	-- Player level needed to evolve the pickaxe or backpack to each tier, and to buy the
	-- same-numbered conveyor and refinery level.
	EvolveLevel = { 1, 1, 1, 1, 10, 16, 24, 34 },
}
