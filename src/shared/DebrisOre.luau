--!strict
-- DebrisService colours tiers 3 and 4 cyan: their drops match that Frost appearance.
-- Other debris keeps the configured default ore.

local Debris = require(script.Parent.Config.Debris)

local DebrisOre = {}

function DebrisOre.forTier(tier: number?): string
	return if tier == 3 or tier == 4 then "frost" else Debris.Ore
end

return DebrisOre
