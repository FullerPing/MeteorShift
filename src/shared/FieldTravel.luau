--!strict
-- Rules for teleporting to an ore field: which ids are valid and where on the field floor to land.
-- The server (DebrisService) measures the real floor and rocks; this only picks among candidate
-- offsets so the player never lands inside a rock.
local Debris = require(script.Parent.Config.Debris)

local FieldTravel = {}

-- Aisle points around the field's centre (x, z offsets in studs), nearest first. Rocks sit on a
-- 22-stud grid with 14-stud aisles, so the centre and the diagonals are normally clear.
FieldTravel.Offsets = {
	{ 0, 0 }, { 11, 11 }, { -11, 11 }, { 11, -11 }, { -11, -11 },
	{ 0, 22 }, { 0, -22 }, { 22, 0 }, { -22, 0 }, { 33, 11 }, { -33, 11 }, { 33, -11 }, { -33, -11 },
}

function FieldTravel.find(id: any): Debris.Field?
	if typeof(id) ~= "string" then return nil end
	for _, field in Debris.Fields do
		if field.Id == id then return field end
	end
	return nil
end

-- The first offset `isFree(dx, dz)` accepts, or the centre when every spot is blocked.
function FieldTravel.pick(isFree: (number, number) -> boolean): (number, number)
	for _, offset in FieldTravel.Offsets do
		if isFree(offset[1], offset[2]) then return offset[1], offset[2] end
	end
	return 0, 0
end

return FieldTravel
