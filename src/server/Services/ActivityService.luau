--!strict
-- Who counts as active (spec §5.3): players with any input in the last 2 minutes.
-- Meteor HP is sized from active players only, so AFK players don't make the
-- meteor impossible for everyone else.
--
-- Clients ping on input (ActivityController, throttled); swings count too, and a
-- player who just joined starts out active.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local ActivityService = Knit.CreateService({
	Name = "ActivityService",
	Client = {},
})

local lastInput: { [Player]: number } = {}

function ActivityService:Touch(player: Player)
	lastInput[player] = os.clock()
end

function ActivityService:IsActive(player: Player): boolean
	local last = lastInput[player]
	return last ~= nil and os.clock() - last <= Config.Meteor.ActiveWindow
end

function ActivityService:GetActivePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if self:IsActive(player) then
			table.insert(list, player)
		end
	end
	return list
end

function ActivityService.Client:Ping(player: Player)
	self.Server:Touch(player)
end

function ActivityService:KnitStart()
	for _, player in Players:GetPlayers() do
		self:Touch(player)
	end
	Players.PlayerAdded:Connect(function(player)
		self:Touch(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastInput[player] = nil
	end)
end

return ActivityService
