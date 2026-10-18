--!strict
-- The opt-in staging root is Studio-only and shared by server/world clients.
local RunService = game:GetService("RunService")
local WorldMap = {}

function WorldMap.name(studio: boolean, override: any): string
	return if studio and override == "Map_Redesign" then "Map_Redesign" else "Map"
end

function WorldMap.assetName(studio: boolean, override: any): string
	return if WorldMap.name(studio, override) == "Map_Redesign" then "Assets_Redesign" else "Assets"
end

function WorldMap.assets(): Instance
	return game:GetService("ServerStorage"):WaitForChild(WorldMap.assetName(RunService:IsStudio(), workspace:GetAttribute("DevWorldMap")))
end

function WorldMap.find(): Instance?
	return workspace:FindFirstChild(WorldMap.name(RunService:IsStudio(), workspace:GetAttribute("DevWorldMap")))
end

function WorldMap.wait(): Instance
	return workspace:WaitForChild(WorldMap.name(RunService:IsStudio(), workspace:GetAttribute("DevWorldMap")))
end

function WorldMap.refineryPoint(root: Instance?): BasePart?
	local town = root and root:FindFirstChild("TownSquare")
	local refinery = town and town:FindFirstChild("Refinery")
	local point = refinery and refinery:FindFirstChild("UsePoint")
	return if refinery and refinery:IsA("Model") and point and point:IsA("BasePart") then point else nil
end

-- The Commissary in the north: a small outpost of the Foundry where ore can be deposited and bars claimed too
function WorldMap.commissaryPoint(root: Instance?): BasePart?
	local town = root and root:FindFirstChild("TownSquare")
	local commissary = town and town:FindFirstChild("Commissary")
	local point = commissary and commissary:FindFirstChild("UsePoint")
	return if commissary and commissary:IsA("Model") and point and point:IsA("BasePart") then point else nil
end

-- Every place the refinery can be used from: the Foundry first, then the Commissary when the map has one, then
-- the ore chute at each field (Map.Chutes.<FieldId>.UsePoint), by name
function WorldMap.refineryPoints(root: Instance?): { BasePart }
	local points = {}
	for _, point in { WorldMap.refineryPoint(root), WorldMap.commissaryPoint(root) } do table.insert(points, point) end
	local chutes = root and root:FindFirstChild("Chutes")
	if chutes then
		local found = {}
		for _, chute in chutes:GetChildren() do
			local point = chute:FindFirstChild("UsePoint")
			if point and point:IsA("BasePart") then table.insert(found, point) end
		end
		table.sort(found, function(a, b) return (a.Parent :: Instance).Name < (b.Parent :: Instance).Name end)
		table.move(found, 1, #found, #points + 1, points)
	end
	return points
end

-- The prompt is 14 studs; menu transactions retain four studs of movement tolerance.
function WorldMap.canUseRefinery(map: Instance?, character: Model?): boolean
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then return false end
	for _, point in WorldMap.refineryPoints(map) do
		if (root.Position - point.Position).Magnitude <= 18 then return true end
	end
	return false
end

return WorldMap
