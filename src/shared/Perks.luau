--!strict
-- Colony Perk rules (Config.Perks): levels, prices, and what each level does. Pure; PerkService
-- spends the shards, RebirthReset, Refining, Pets and MonetizationService read the effects.
-- Covered by tests/Perks.spec.

local Config = require(script.Parent.Config)

local Settings = Config.Perks

local Perks = {}

export type Owned = { [string]: number }

function Perks.fresh(): Owned
	local owned: Owned = {}
	for _, id in Settings.Order do
		owned[id] = 0
	end
	return owned
end

-- A saved perks table checked into range (unknown ids dropped, levels clamped)
function Perks.clean(saved: any): Owned
	local owned = Perks.fresh()
	if type(saved) == "table" then
		for _, id in Settings.Order do
			local level = saved[id]
			if type(level) == "number" and level == level then
				owned[id] = math.clamp(math.floor(level), 0, #Settings.List[id].Costs)
			end
		end
	end
	return owned
end

function Perks.level(owned: Owned?, id: string): number
	return if owned then math.max(math.floor(owned[id] or 0), 0) else 0
end

function Perks.maxLevel(id: string): number
	return #Settings.List[id].Costs
end

-- Shards for the next level of a perk, nil at its last level
function Perks.nextCost(owned: Owned?, id: string): number?
	return Settings.List[id].Costs[Perks.level(owned, id) + 1]
end

-- The effect at the owned level (0 when not bought)
function Perks.effect(owned: Owned?, id: string): number
	local level = Perks.level(owned, id)
	return if level > 0 then Settings.List[id].Effect[math.min(level, #Settings.List[id].Effect)] else 0
end

-- Whether the colony perks panel is open at this rebirth count
function Perks.unlocked(rebirths: number?): boolean
	return (rebirths or 0) >= Settings.UnlockRebirths
end

-- Efficient Line: multiplier on the production line's rate
function Perks.lineMult(owned: Owned?): number
	return 1 + Perks.effect(owned, "efficientLine")
end

-- Offline Training: seconds added to the offline cap
function Perks.offlineBonus(owned: Owned?): number
	return Perks.effect(owned, "offlineTraining") * 60
end

-- Pet Bond: pet slots added
function Perks.petSlots(owned: Owned?): number
	return Perks.effect(owned, "petBond")
end

-- Station Memory: the level a station is rebuilt at after a rebirth (1 keeps nothing)
function Perks.keptStation(owned: Owned?, level: number): number
	local keep = Perks.effect(owned, "stationMemory")
	return math.max(1, 1 + math.floor((math.max(level, 1) - 1) * keep + 1e-9))
end

-- Head Start: the tier a pickaxe or backpack is rebuilt at after a rebirth, held to the
-- highest tier the player level allows (`evolveLevel(tier)` is Shared.Levels.evolveLevel)
function Perks.startTier(owned: Owned?, playerLevel: number, maxTier: number, evolveLevel: (number) -> number): number
	local tier = 1 + Perks.effect(owned, "headStart")
	tier = math.min(tier, maxTier)
	while tier > 1 and playerLevel < evolveLevel(tier) do
		tier -= 1
	end
	return tier
end

return Perks
