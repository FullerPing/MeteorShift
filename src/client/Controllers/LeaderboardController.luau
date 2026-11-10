--!strict
-- Makes the leaderboards scrollable. LeaderboardService builds each board's SurfaceGui ("Board") on its Screen part in
-- the map, but Roblox only gives input to a SurfaceGui inside PlayerGui, so the scrolling list ignored the wheel and
-- touch in a live game. Each Board that arrives is moved into PlayerGui and adorned to its Screen; the server keeps
-- writing the same rows (the instances still replicate), and each player scrolls their own copy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)

local LeaderboardController = Knit.CreateController({ Name = "LeaderboardController" })

function LeaderboardController:KnitStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local map = WorldMap.wait()
	local moved: { [Instance]: SurfaceGui } = {} -- screen part -> its board, so a re-streamed screen replaces the old one

	local function adopt(gui: Instance)
		if not (gui:IsA("SurfaceGui") and gui.Name == "Board") then return end
		local screen = gui.Parent
		if not (screen and screen:IsA("BasePart") and screen.Name == "Screen") then return end
		if moved[screen] and moved[screen] ~= gui then moved[screen]:Destroy() end
		moved[screen] = gui
		gui.Adornee = screen
		gui.Name = "LeaderboardBoard"
		gui.Parent = playerGui
	end

	map.DescendantAdded:Connect(function(item) task.defer(adopt, item) end)
	for _, item in map:GetDescendants() do adopt(item) end
end

return LeaderboardController
