--!strict
-- Mining combo (Config.Hooks.Combo): hits that follow each other within Window seconds build a
-- count, and every Step hits add Bonus to a hit's ore, up to MaxSteps. Pure; NodeService keeps
-- each player's count, MiningController shows it and Shared.Pacing models a backpack fill.
-- Covered by tests/Combo.spec.

local Config = require(script.Parent.Config)

local Settings = Config.Hooks.Combo

local Combo = {}

-- The count after a hit at `now`, given the count and the time of the hit before (nil for none)
function Combo.next(count: number, last: number?, now: number): number
	if last and now - last <= Settings.Window then
		return count + 1
	end
	return 1
end

-- Ore multiplier of a hit at combo `count` (the first hits pay 1)
function Combo.mult(count: number): number
	return 1 + math.min(math.floor(count / Settings.Step), Settings.MaxSteps) * Settings.Bonus
end

-- Hits it takes, starting from no combo, to gather `capacity` ore at `perHit` ore a hit before the combo
function Combo.fillHits(capacity: number, perHit: number): number
	local top = Settings.Step * Settings.MaxSteps -- from this hit on every hit pays the top multiplier
	local hits, ore = 0, 0
	while ore < capacity and hits < top do
		hits += 1
		ore += perHit * Combo.mult(hits)
	end
	if ore < capacity then
		hits += (capacity - ore) / (perHit * Combo.mult(top))
	end
	return hits
end

return Combo
