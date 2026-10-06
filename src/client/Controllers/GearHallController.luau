--!strict
-- Local equipment and world SurfaceGui presentation only; existing shop UI is frozen.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(RS.Packages.Knit)
local WorldMap = require(RS.Shared.WorldMap)
local Display = require(RS.Shared.WorldEquipmentDisplay)
local GearHallController = Knit.CreateController({ Name = "GearHallController" })

function GearHallController:KnitStart()
	local map = WorldMap.wait()
	local town = map:WaitForChild("TownSquare")
	local hall = town:FindFirstChild("GearHall")
	-- The archived town has no Gear Hall; pre-swap QA selects Map_Redesign explicitly.
	if not hall then return end
	local view = Display.mount(hall)
	local observer = Knit.GetService("PlayerStateService").State:Observe(function(state) view:update(state) end)
	local heartbeat = RunService.Heartbeat:Connect(function(dt) view:step(dt) end)
	hall.AncestryChanged:Connect(function()
		if not hall:IsDescendantOf(workspace) then
			heartbeat:Disconnect()
			observer:Disconnect()
			view:destroy()
		end
	end)
end

return GearHallController
