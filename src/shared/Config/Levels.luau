--!strict
-- Player level (XP). Separate from gear: it is earned by taking part in meteors, survives
-- rebirth, and gates evolving (Shared.Levels, Server.ShopService) and ore yield. Tune here.
--
-- Levels run 1 to 50 and everything unlocks somewhere on that road (docs/design/economy-rework.md):
-- tiers 5 and 6 at 10 / 14 (later tiers open by rebirths), Frost cleared at 12, Crystal at 24, Alien at 38. At a
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
	TypeMult = { iron = 1, frost = 1.5, crystal = 2, alien = 3, quartz = 2, nebula = 1, solar = 1.5, eclipse = 2 }, -- by ore id

	-- Ore clearance: the player level that mines each ore at its full yield. Under it a hit
	-- yields UnderLevelFloor of its ore at level 1, rising geometrically to 1 at the clearance
	-- level (Shared.Levels.oreYield). Nobody is locked out and the refinery never slows down:
	-- the bar price is the same for everyone, the fraction just keeps a newcomer in a
	-- Crystal meteor from outrunning the levels that earn it.
	OreLevel = { iron = 1, frost = 12, crystal = 24, alien = 38, quartz = 1, nebula = 1, solar = 12, eclipse = 24 },
	UnderLevelFloor = 0.4,

	-- What evolving the pickaxe or backpack to each tier needs, and buying the same-numbered production
	-- line level (Shared.Line): a player level (EvolveLevel, tiers with no entry need none) or, from
	-- tier 7, a rebirth count (EvolveRebirths). Prices don't rise with rebirths, so the late tiers are
	-- gated by rank: each is priced for the income of the rank that opens it (2026-10-22, tiers 9-16
	-- added; tiers 7 and 8 used to need levels 24 and 34, hours after the rebirths they were priced for).
	-- Owner, 2026-10-24: tier 4 opens at the first rebirth and tier 8 at rebirth 10, then one tier every 2 rebirths;
	-- 2026-10-25: every 3 rebirths from rebirth 10 (tiers 9-16 at 13, 16, ... 34, re-priced for those ranks)
	EvolveLevel = { 1, 1, 1 },
	EvolveRebirths = { [4] = 1, [5] = 3, [6] = 5, [7] = 7, [8] = 10, [9] = 13, [10] = 16, [11] = 19, [12] = 22, [13] = 25,
		[14] = 28, [15] = 31, [16] = 34 },
}
