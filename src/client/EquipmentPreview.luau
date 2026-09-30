--!strict
-- Real equipment geometry with local lighting and no image asset dependencies.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Models = require(ReplicatedStorage.Shared.EquipmentModels)
local UI = require(script.Parent.UI)

return function(scope: UI.Scope, kind: string, tier: number, props: { [any]: any })
	local model = if kind == "pickaxe" then Models.pickaxe(tier) else Models.backpack(tier)
	local bounds, size = model:GetBoundingBox()
	local center = bounds.Position
	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local camera = scope:New("Camera")({
		FieldOfView = 34,
		CFrame = CFrame.lookAt(center + Vector3.new(-0.3, 0.1, -1).Unit * radius * 3.7, center),
	})
	local world = scope:New("WorldModel")({ [Fusion.Children] = { model } })
	local base: { [any]: any } = {
		Name = "EquipmentPreview", BackgroundTransparency = 1, BorderSizePixel = 0,
		Ambient = Color3.fromRGB(195, 201, 220), LightColor = Color3.fromRGB(255, 240, 216),
		LightDirection = Vector3.new(1, -1, 2), CurrentCamera = camera,
		[Fusion.Children] = { world, camera },
	}
	for key, value in props do base[key] = value end
	return scope:New("ViewportFrame")(base)
end
