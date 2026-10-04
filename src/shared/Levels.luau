--!strict
-- Player level rules (Config.Levels): XP needed per level, awarding XP, the XP a meteor
-- pays, and the level an evolution needs. Pure, covered by tests/Levels.spec.

local Config = require(script.Parent.Config)

local Settings = Config.Levels

local Levels = {}

export type Progress = { level: number, xp: number }

-- XP to go from `level` to the next; nil at the max level
function Levels.xpToNext(level: number): number?
	if level >= Settings.MaxLevel then
		return nil
	end
	return math.floor(Settings.XpBase * Settings.XpGrowth ^ (level - 1) + 0.5)
end

-- Total XP from level 1 to reach `level`
function Levels.xpFor(level: number): number
	local total = 0
	for l = 1, math.min(level, Settings.MaxLevel) - 1 do
		total += Levels.xpToNext(l) :: number
	end
	return total
end

-- Adds XP in place, carrying overflow into levels. Returns the levels gained.
function Levels.addXp(progress: Progress, amount: number): number
	if amount ~= amount or amount <= 0 then
		return 0
	end
	local gained = 0
	progress.xp += amount
	while true do
		local needed = Levels.xpToNext(progress.level)
		if not needed or progress.xp < needed then
			break
		end
		progress.xp -= needed
		progress.level += 1
		gained += 1
	end
	if not Levels.xpToNext(progress.level) then
		progress.xp = 0
	end
	return gained
end

-- XP one meteor pays a player who hit it. `share` is their contribution over the top
-- player's (0 to 1); `contribution <= 0` means they never landed a hit.
function Levels.meteorXp(oreName: string, share: number, cracked: boolean): number
	local typeMult = (Settings.TypeMult :: { [string]: number })[oreName] or 1
	local result = if cracked then Settings.CrackedMult else Settings.CooledMult
	return (Settings.Participation + Settings.ShareBonus * math.clamp(share, 0, 1)) * typeMult * result
end

-- Player level needed to evolve to `tier`
function Levels.evolveLevel(tier: number): number
	local list = Settings.EvolveLevel
	return list[math.clamp(tier, 1, #list)] or 1
end

-- A saved level/XP checked into range (bad or missing data becomes level 1)
function Levels.clean(level: any, xp: any): Progress
	local l = if type(level) == "number" and level == level then math.clamp(math.floor(level), 1, Settings.MaxLevel) else 1
	local x = if type(xp) == "number" and xp == xp then math.max(xp, 0) else 0
	local progress = { level = l, xp = 0 }
	Levels.addXp(progress, x)
	return progress
end

return Levels
