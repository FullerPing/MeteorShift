--!strict
local Geometry = require(script.Parent.WorldGeometry)
local Boundary = {}

-- Called on the server; position and health are read from the actual character.
function Boundary.enforce(map: Model?, character: Model?): boolean
	if not map or map:GetAttribute("MapRedesignOwned") ~= true or not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return false end
	if Geometry.inside(map:GetPivot():PointToObjectSpace(root.Position)) then return false end
	humanoid.Health = 0
	return true
end

return Boundary
