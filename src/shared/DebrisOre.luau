--!strict
-- Debris always drops the configured default ore (spec §5.7: filler at a quarter of the
-- meteor rate). The rock's tint shows how tough it is, not what it drops: dropping Frost
-- from cyan rocks paid any pickaxe about 6x an Iron meteor per swing, past the under-tier
-- guardrails (spec §8.1), so the ore no longer follows the tier.

local Debris = require(script.Parent.Config.Debris)

local DebrisOre = {}

function DebrisOre.forTier(_tier: number?): string
	return Debris.Ore
end

return DebrisOre
