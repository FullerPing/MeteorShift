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
	local view: any = nil
	local boundHall: Instance? = nil
	local latest: any = nil
	local queued = false
	local function unmount()
		if view then view:destroy(); view = nil end
		boundHall = nil
	end
	local function reconcile()
		local hall = town:FindFirstChild("GearHall")
		if not Display.ready(hall) then unmount(); return end
		if view and boundHall == hall and view:intact() then return end
		unmount()
		boundHall = hall
		view = Display.mount(hall :: Instance)
		view:update(latest)
	end
	local function schedule()
		if queued then return end
		queued = true
		-- Normal tier replacement finishes before the deferred integrity check.
		task.defer(function() queued = false; reconcile() end)
	end
	-- Keep State even while the hall is streamed out; re-entry displays the latest tier.
	Knit.GetService("PlayerStateService").State:Observe(function(state)
		latest = state
		reconcile()
		if view then view:update(state) end
	end)
	town.DescendantAdded:Connect(schedule)
	town.DescendantRemoving:Connect(function(descendant)
		if boundHall then
			local walls, stands = boundHall:FindFirstChild("TierWalls"), boundHall:FindFirstChild("CurrentStands")
			if descendant == boundHall or descendant == walls or descendant == stands
				or (walls and descendant:IsDescendantOf(walls)) or (stands and descendant:IsDescendantOf(stands)) then unmount() end
		end
		schedule()
	end)
	RunService.Heartbeat:Connect(function(dt) if view then view:step(dt) end end)
	schedule()
end

return GearHallController
