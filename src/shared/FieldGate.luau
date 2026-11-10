--!strict
-- Which ore fields a player may mine: a field's Unlock (Config.Debris) is a player level or a number of rebirths.
-- Level survives rebirth (Lib.RebirthReset), so an opened gate never closes again.
local Debris = require(script.Parent.Config.Debris)

local FieldGate = {}

function FieldGate.isOpen(field: Debris.Field, level: number, rebirths: number): boolean
	local unlock = field.Unlock
	if not unlock then return true end
	if unlock.Rebirths then return rebirths >= unlock.Rebirths end
	return level >= (unlock.Level or 1)
end

-- What the gate's sign says while it is closed
function FieldGate.label(field: Debris.Field): string
	local unlock = field.Unlock
	if unlock and unlock.Rebirths then return "Rebirth " .. unlock.Rebirths end
	if unlock and unlock.Level then return "Level " .. unlock.Level end
	return "Open"
end

return FieldGate
