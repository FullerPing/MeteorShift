--!strict
local Geometry = require(script.Parent.WorldGeometry)
local Impact = {}

function Impact.destination(map: Instance, impact: Vector3, position: Vector3, clearance: number): Vector3?
	local flat = Vector3.new(position.X - impact.X, 0, position.Z - impact.Z)
	local scale = Geometry.Settings.MeteorScale
	if flat.Magnitude >= 26 * scale then return nil end
	local direction = if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis
	local target = impact + direction * (30 * scale)
	local surfaces: { Instance } = {}
	for _, name in { "Ground", "Roads" } do
		local surface = map:FindFirstChild(name)
		if surface then table.insert(surfaces, surface) end
	end
	local crater = map:FindFirstChild("Crater")
	if crater then
		for _, name in { "Bowl", "MiningAccess", "AccessRamps", "Rim" } do
			local surface = crater:FindFirstChild(name)
			if surface then table.insert(surfaces, surface) end
		end
	end
	if #surfaces == 0 then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = surfaces
	params.RespectCanCollide = true
	local origin = Vector3.new(target.X, math.max(position.Y, impact.Y) + 256, target.Z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -1024, 0), params)
	return if hit and hit.Normal.Y >= 0.65 then hit.Position + Vector3.new(0, clearance, 0) else nil
end

return Impact
