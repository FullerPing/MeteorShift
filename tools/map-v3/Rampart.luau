-- Map v3 rampart. Load Common, Brick and Toon first; run after Ground. Builds the map-v2 castle rampart at +-540
-- (map-v2/Boundary with noLawn), lifts it onto T2 (its walls stood on Y0; T2 is Y32) and leaves the kill plane where
-- it was. The Crown's meadow is level with the lifted wall top, so a parapet and an invisible fence close its north
-- edge. Owns Map_Redesign.Boundary.
local A = assert(_G.MapRedesignArt, "Run Common first")
local T = assert(A.toon, "Run Toon first")
local L = assert(..., "Pass the stage loader L")
local G = A.geometry
local R = T.ramp
local result = L("Boundary", { noLawn = true })
local boundary = A.map.Boundary
local kill = boundary.KillPlane
local killCf = kill.CFrame
boundary:PivotTo(boundary:GetPivot() + Vector3.new(0, G.Tiers[3].y, 0))
kill.CFrame = killCf

local c = G.Crown
local z = c.z1 - 1.5
T.part(boundary, "CrownParapet", Vector3.new(c.x1 - c.x0, 3, 3), A.cf((c.x0 + c.x1) / 2, c.y + 1.5, z), R.stone[1])
T.part(boundary, "CrownParapetCap", Vector3.new(c.x1 - c.x0 + 1, .8, 3.8), A.cf((c.x0 + c.x1) / 2, c.y + 3.4, z), R.cream[2], nil, false)
local fence = A.part(boundary, "CrownFence", Vector3.new(c.x1 - c.x0, 20, 2), A.cf((c.x0 + c.x1) / 2, c.y + 10, c.z1 + 1), R.stone[1])
fence.Transparency = 1
result.boundaryParts = A.count(boundary)
return result
