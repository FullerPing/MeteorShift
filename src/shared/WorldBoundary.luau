--!strict
local Geometry = require(script.Parent.WorldGeometry)
local Crater = require(script.Parent.Config).LandingFX.Crater
local Boundary = {}

-- Called on the server; position and health are read from the actual character.
function Boundary.enforce(map: Model?, character: Model?): boolean
	if not map or map:GetAttribute("MapRedesignOwned") ~= true or not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return false end
	local position = map:GetPivot():PointToObjectSpace(root.Position)
	if Geometry.inside(position) then
		-- The authored bowl rises linearly from its flat floor to the town slab.
		-- Four studs of tolerance cover collision thickness and angled fan joins.
		local radius = Vector2.new(position.X, position.Z).Magnitude
		local slope = math.clamp((radius - Crater.FloorRadius) / (Crater.OpeningRadius - Crater.FloorRadius), 0, 1)
		local floor = Crater.FloorY + (Crater.RimY - Crater.FloorY) * slope
		if position.Y >= floor - 4 then return false end
	end
	humanoid.Health = 0
	return true
end

return Boundary
