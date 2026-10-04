--!strict
-- Player level (XP). Separate from gear: it is earned by taking part in meteors, survives
-- rebirth, and gates evolving (Shared.Levels, Server.ShopService). Tune here.

return {
	MaxLevel = 50,
	XpBase = 30, -- XP from level 1 to 2
	XpGrowth = 1.3, -- each level needs this many times the one before

	-- XP for one meteor you hit: (Participation + ShareBonus x your share of the top
	-- player's contribution) x the meteor type's mult x cracked/cooled mult. Debris and
	-- standing around pay nothing, so it can't be farmed idle.
	Participation = 40,
	ShareBonus = 60,
	TypeMult = { Iron = 1, Ice = 1.5, Crystal = 2 },
	CrackedMult = 1.25,
	CooledMult = 0.5,

	-- Player level needed to evolve the pickaxe or backpack TO this tier (index = tier).
	-- Levels outlast rebirth, so this only slows the first climb.
	-- Refinery clearance: the player level that refines each ore at full speed. A player
	-- ClearancePerLevel^levelsShort of full speed under it (never blocked, never a different
	-- price: the bar price is the same for everyone), so a lobby of mixed levels shares one
	-- meteor type and everyone is paid fairly for their level.
	OreLevel = { iron = 1, frost = 4, crystal = 6 },
	ClearancePerLevel = 0.35,

	EvolveLevel = { 1, 1, 1, 1, 5, 7, 9, 11 },
}
