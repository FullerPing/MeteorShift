--!strict
-- The opt-in staging root is Studio-only and shared by server/world clients.
local RunService = game:GetService("RunService")
local WorldMap = {}

function WorldMap.name(studio: boolean, override: any): string
	return if studio and override == "Map_Redesign" then "Map_Redesign" else "Map"
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

-- The prompt is 14 studs; menu transactions retain four studs of movement tolerance.
function WorldMap.canUseRefinery(map: Instance?, character: Model?): boolean
	local point = WorldMap.refineryPoint(map)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return point ~= nil and root ~= nil and root:IsA("BasePart")
		and humanoid ~= nil and humanoid.Health > 0
		and (root.Position - point.Position).Magnitude <= 18
end

return WorldMap
