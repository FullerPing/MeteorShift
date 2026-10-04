--!strict
-- Player level (XP). Separate from gear: it is earned by taking part in meteors, survives
-- rebirth, and gates evolving (Shared.Levels, Server.ShopService). Tune here.

return {
	MaxLevel = 50,
	XpBase = 80, -- XP from level 1 to 2
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
	EvolveLevel = { 1, 1, 1, 1, 3, 4, 5, 7 },
}
