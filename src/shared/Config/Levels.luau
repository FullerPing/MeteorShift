--!strict
-- Player level (XP). Separate from gear: it is earned by taking part in meteors, survives
-- rebirth, and gates evolving (Shared.Levels, Server.ShopService). Tune here.

return {
	MaxLevel = 50,
	XpBase = 30, -- XP from level 1 to 2
	XpGrowth = 1.3, -- each level needs this many times the one before

	-- XP comes in as you play, never as a lump after the meteor: each validated hit on a crust
	-- node or the core, and a bonus when a core you hit is cracked. All times the meteor ore's
	-- TypeMult. Debris and standing around pay nothing, so it can't be farmed idle. A full
	-- meteor of hitting (about 140 crust hits, 20 core hits, then the crack) is about 70 XP.
	CrustHitXp = 0.25,
	CoreHitXp = 0.5,
	CrackBonusXp = 25,
	TypeMult = { iron = 1, frost = 1.5, crystal = 2 }, -- by ore id

	-- Refinery clearance: the player level that refines each ore at full speed. A player
	-- ClearancePerLevel^levelsShort of full speed under it (never blocked, never a different
	-- price: the bar price is the same for everyone), so a lobby of mixed levels shares one
	-- meteor type and everyone is paid fairly for their level.
	OreLevel = { iron = 1, frost = 4, crystal = 6 },
	ClearancePerLevel = 0.35,

	EvolveLevel = { 1, 1, 1, 1, 5, 7, 9, 11 },
}
