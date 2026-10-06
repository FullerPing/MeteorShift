--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local Boundary = require(ReplicatedStorage.Shared.WorldBoundary)

local WorldBoundaryService = Knit.CreateService({ Name = "WorldBoundaryService", Client = {} })

function WorldBoundaryService:KnitStart()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local map = WorldMap.find()
			if map and map:IsA("Model") then
				for _, player in Players:GetPlayers() do
					Boundary.enforce(map, player.Character)
				end
			end
		end
	end)
end

return WorldBoundaryService
