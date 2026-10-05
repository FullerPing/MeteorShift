--!strict
-- Replace only world geometry when the equipment tier or pet level changes.
local RS = game:GetService("ReplicatedStorage")
local Models = require(RS.Shared.EquipmentModels)
local PetModel = require(script.Parent.PetModel)
local Preview = {}
local function show(frame: ViewportFrame, model: Model?)
	for _, child in frame:GetChildren() do if child:IsA("WorldModel") or child:IsA("Camera") then child:Destroy() end end
	if not model then frame.CurrentCamera = nil; return end
	local world = Instance.new("WorldModel"); world.Parent = frame; model.Parent = world
	local bounds, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.CFrame = CFrame.lookAt(bounds.Position + Vector3.new(-.3, .1, -1).Unit * math.max(size.X, size.Y, size.Z) * 1.85, bounds.Position)
	camera.Parent, frame.CurrentCamera = frame, camera
end
function Preview.gear(frame: ViewportFrame, kind: string, tier: number)
	show(frame, if kind == "pickaxe" then Models.pickaxe(tier) else Models.backpack(tier))
end
function Preview.pet(frame: ViewportFrame, id: string, level: number)
	local visual = PetModel.clone(id, level)
	if visual then PetModel.reduce(visual, true) end
	show(frame, if visual then visual.model else nil)
end
function Preview.clear(frame: ViewportFrame) show(frame, nil) end
return Preview
