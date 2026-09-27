--!strict
-- Tells the server this player is not AFK (spec §5.3). Any keyboard, mouse, touch or
-- gamepad input counts; pings are throttled so an active player sends one every
-- PING_INTERVAL seconds at most.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ActivityController = Knit.CreateController({
	Name = "ActivityController",
})

local PING_INTERVAL = 15

function ActivityController:KnitStart()
	local ActivityService = Knit.GetService("ActivityService")
	local lastPing = 0

	local function onInput()
		local now = os.clock()
		if now - lastPing >= PING_INTERVAL then
			lastPing = now
			task.spawn(ActivityService.Ping, ActivityService)
		end
	end

	UserInputService.InputBegan:Connect(onInput)
	UserInputService.InputChanged:Connect(onInput)
end

return ActivityController
